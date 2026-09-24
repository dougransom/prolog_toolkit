:- module(prolog_reactive_parser, [
    % Canonical Prolog Parser API
    prolog_parse_term//6,
    prolog_parse_clause//3,
    prolog_parse_clause//4,
    prolog_parse_raw_clause//4,
    prolog_parse_program//3,
    prolog_parse_program//4,
    prolog_initial_var_state/1,
    prolog_var_state_bindings/4,
    prolog_var_state_bindings_ex/5,

    % Reactive Attributed Parser API
    reactive_parse_clause//2,
    reactive_parse_clause//3,
    reactive_parse_term//4,
    reactive_parse_term//6,
    reactive_chars_to_ast/2,
    reactive_chars_to_ast/3,
    create_ast_hole/3,
    reactive_parse_subterm/5,
    reactive_build_rule/4,
    ast_to_raw_term/2,

    % Backward-compatibility aliases
    parse_term//6,
    parse_clause//3,
    parse_clause//4,
    parse_raw_clause//4,
    parse_program//3,
    parse_program//4,
    initial_var_state/1,
    var_state_bindings/4,
    var_state_bindings_ex/5
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(prolog_operator_table).
:- use_module(prolog_token).
:- use_module(prolog_attributed_tokens).
:- use_module(prolog_reactive_ast).
:- use_module(prolog_expander, [
    prolog_expand_statement/5,
    prolog_initial_expander_state/2
]).

/** <module> Unified Reactive & ISO Prolog Parser

This module combines pure Pratt / Operator Precedence Climbing parsing with
lazy reactive AST construction on Scryer Prolog's `library(atts)`.

It serves as the single unified parser for the toolkit, supporting both:
1. Standard Homoiconic Prolog terms (`clause/2`, `directive/2`, `query/2`) for
   runtime I/O (`term_io.pl`) and module loading (`module_loader.pl`).
2. Reactive Attributed ASTs (`ast_node/2` with lazy dataflow propagation and
   syntax hole patching) for IDEs, linters, and incremental parsers.
*/

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Variable State Tracking (Variable Names, Singletons, Variables, Spans)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

prolog_initial_var_state(var_state([])).
initial_var_state(State) :- prolog_initial_var_state(State).

lookup_var(V0, NameChars, Var, V1) :-
    lookup_var(V0, NameChars, Var, no_span, V1).

lookup_var(var_state(Map0), NameChars, Var, Span, var_state(Map1)) :-
    if_(NameChars = "_",
        Map1 = [anon_entry(Var, [Span])|Map0],
        update_var_map(Map0, NameChars, Var, Span, Map1)
    ).

update_var_map([], Name, Var, Span, [entry(Name, Var, 1, [Span])]).
update_var_map([E|Rest], Name, Var, Span, Out) :-
    if_(E = entry(N, V, Count, Spans),
        if_(N = Name,
            ( Var = V,
              Count1 #= Count + 1,
              Out = [entry(N, V, Count1, [Span|Spans])|Rest]
            ),
            ( Out = [E|Rest1],
              update_var_map(Rest, Name, Var, Span, Rest1)
            )
        ),
        ( Out = [E|Rest1],
          update_var_map(Rest, Name, Var, Span, Rest1)
        )
    ).

prolog_var_state_bindings(var_state(Map), VarNames, Variables, Singletons) :-
    extract_bindings(Map, VarNames, Variables, Singletons).
var_state_bindings(State, VNs, Vs, Sing) :-
    prolog_var_state_bindings(State, VNs, Vs, Sing).

prolog_var_state_bindings_ex(var_state(Map), VarNames, Variables, Singletons, Details) :-
    extract_bindings_ex(Map, VarNames, Variables, Singletons, Details).
var_state_bindings_ex(State, VNs, Vs, Sing, Details) :-
    prolog_var_state_bindings_ex(State, VNs, Vs, Sing, Details).

singleton_t(Count, NameChars, Truth) :-
    if_(Count #= 1,
        if_(NameChars = ['_'|_], Truth = false, Truth = true),
        Truth = false
    ).

extract_bindings([], [], [], []).
extract_bindings([E|Rest], VNs, Vs, Singletons) :-
    if_(E = entry(NameChars, Var, Count, _Spans),
        ( atom_chars(Name, NameChars),
          VNs = [Name = Var|VNRest],
          Vs = [Var|VRest],
          if_(singleton_t(Count, NameChars),
              Singletons = [Name = Var|SingRest],
              Singletons = SingRest
          ),
          extract_bindings(Rest, VNRest, VRest, SingRest)
        ),
        extract_bindings(Rest, VNs, Vs, Singletons)
    ).

extract_bindings_ex([], [], [], [], []).
extract_bindings_ex([E|Rest], VNs, Vs, Singletons, Details) :-
    if_(E = entry(NameChars, Var, Count, Spans),
        ( atom_chars(Name, NameChars),
          VNs = [Name = Var|VNRest],
          Vs = [Var|VRest],
          Details = [var_detail(NameChars, Var, Count, Spans)|DetailRest],
          if_(singleton_t(Count, NameChars),
              Singletons = [Name = Var|SingRest],
              Singletons = SingRest
          ),
          extract_bindings_ex(Rest, VNRest, VRest, SingRest, DetailRest)
        ),
        if_(E = anon_entry(Var, Spans),
            ( Details = [anon_var_detail(Var, Spans)|DetailRest],
              extract_bindings_ex(Rest, VNs, Vs, Singletons, DetailRest)
            ),
            extract_bindings_ex(Rest, VNs, Vs, Singletons, Details)
        )
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Token Inspection Helpers (Attributed Tokens & Standard Lifted Tokens)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

token_class(Tok, Class) :-
    (   is_attributed_token(Tok) ->
        get_token_class(Tok, Class)
    ;   token_type(Tok, Class)
    ).

token_val(Tok, Val) :-
    (   is_attributed_token(Tok) ->
        get_token_value(Tok, Val)
    ;   token_value(Tok, Val)
    ).

token_source_span(Tok, Span) :-
    (   is_attributed_token(Tok) ->
        get_token_span(Tok, Span)
    ;   token_span(Tok, Span)
    ).

peek_tok(Tok), [Tok] --> [Tok].

can_be_operand_tok(Tok) :-
    token_class(Tok, Class),
    memberd_t(Class, [close, close_list, close_curly, comma, bar, end], false).

is_op_tok(Tok, OpChars) :-
    token_class(Tok, Class),
    if_(Class = atom,
        token_val(Tok, OpChars),
        if_(Class = comma,
            OpChars = ",",
            if_(Class = bar,
                OpChars = "|",
                fail
            )
        )
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Convenience Entry Points for Reactive Scanning & Parsing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

reactive_chars_to_ast(Chars, ClauseAST) :-
    reactive_chars_to_ast(Chars, [], ClauseAST).

reactive_chars_to_ast(Chars, Options, ClauseAST) :-
    chars_to_attributed_tokens(Chars, Options, AttrTokens),
    if_(memberd_t(operators(OpTable), Options),
        true,
        prolog_default_operator_table(OpTable)
    ),
    phrase(reactive_parse_clause(OpTable, ClauseAST), AttrTokens).

reactive_parse_clause(Arg1, Arg2) -->
    (   { nonvar(Arg1), ( Arg1 = op_table(_) ; Arg1 = table(_) ) } ->
        reactive_parse_clause(Arg1, Arg2, _)
    ;   { prolog_default_operator_table(OpTable) },
        reactive_parse_clause(OpTable, Arg1, Arg2)
    ).

reactive_parse_clause(OpTable, ClauseAST, VarBindings) -->
    { prolog_initial_var_state(V0) },
    reactive_parse_term(OpTable, 1200, TermNode, _, V0, V1),
    [EndTok],
    { token_class(EndTok, end),
      prolog_var_state_bindings(V1, VNs, Vs, Singletons),
      VarBindings = [variable_names(VNs), variables(Vs), singletons(Singletons)],
      wrap_clause_ast(TermNode, ClauseAST)
    }.

wrap_clause_ast(TermNode, ClauseAST) :-
    TermNode = ast_node(Term, Meta),
    wrap_ast_term(Term, Meta, TermNode, ClauseAST).

wrap_ast_term((Head :- Body), Meta, TermNode, ClauseAST) :-
    lazy_ast_node(ClauseAST, [TermNode], rule(Head, Body), [clause_type(rule)|Meta]).
wrap_ast_term((Head --> Body), Meta, TermNode, ClauseAST) :-
    lazy_ast_node(ClauseAST, [TermNode], dcg_rule(Head, Body), [clause_type(dcg)|Meta]).
wrap_ast_term((:- Directive), Meta, TermNode, ClauseAST) :-
    lazy_ast_node(ClauseAST, [TermNode], directive(Directive), [clause_type(directive)|Meta]).
wrap_ast_term(Term, Meta, TermNode, ClauseAST) :-
    dif(Term, (_ :- _)),
    dif(Term, (_ --> _)),
    dif(Term, (:- _)),
    lazy_ast_node(ClauseAST, [TermNode], fact(TermNode), [clause_type(fact)|Meta]).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Core Term Parser (Pratt / Operator Precedence Climbing)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

reactive_parse_term(OpTable, MaxPrec, TermNode, PrecOut) -->
    { prolog_initial_var_state(V0) },
    reactive_parse_term(OpTable, MaxPrec, TermNode, PrecOut, V0, _).

reactive_parse_term(OpTable, MaxPrec, TermNode, PrecOut, V0, VOut) -->
    reactive_parse_prefix_or_primary(OpTable, MaxPrec, Left0, LeftPrec, V0, V1),
    reactive_parse_infix_postfix(OpTable, MaxPrec, Left0, LeftPrec, TermNode, PrecOut, V1, VOut).

reactive_parse_prefix_or_primary(OpTable, MaxPrec, Node, PrecOut, V0, VOut) -->
    [Tok],
    { token_class(Tok, Class) },
    parse_primary_class(Class, Tok, OpTable, MaxPrec, Node, PrecOut, V0, VOut).

parse_primary_class(var, Tok, _OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    { token_val(Tok, NameChars),
      token_source_span(Tok, Span),
      lookup_var(V0, NameChars, ProgVar, Span, VOut),
      lazy_ast_node(Node, [], var_leaf(ProgVar), [name(NameChars), span(Span), type(var)])
    }.
parse_primary_class(integer, Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { token_val(Tok, IntVal),
      token_source_span(Tok, Span),
      lazy_ast_node(Node, [IntVal], literal, [span(Span), type(integer)])
    }.
parse_primary_class(float, Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { token_val(Tok, FloatVal),
      token_source_span(Tok, Span),
      lazy_ast_node(Node, [FloatVal], literal, [span(Span), type(float)])
    }.
parse_primary_class(string, Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { token_val(Tok, Chars),
      token_source_span(Tok, Span),
      lazy_ast_node(Node, [Chars], literal, [span(Span), type(string)])
    }.
parse_primary_class(open, _Tok, OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    reactive_parse_term(OpTable, 1200, InnerNode, _, V0, V1),
    [CloseTok],
    { token_class(CloseTok, close),
      VOut = V1,
      Node = InnerNode
    }.
parse_primary_class(open_ct, _Tok, OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    reactive_parse_term(OpTable, 1200, InnerNode, _, V0, V1),
    [CloseTok],
    { token_class(CloseTok, close),
      VOut = V1,
      Node = InnerNode
    }.
parse_primary_class(open_list, _Tok, OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    parse_list_elements(OpTable, Node, V0, VOut).
parse_primary_class(open_curly, Tok, OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    { token_source_span(Tok, StartSpan) },
    (   peek_tok(CloseTok),
        { token_class(CloseTok, close_curly) } ->
        [CloseTok],
        { token_source_span(CloseTok, EndSpan),
          combine_token_spans(StartSpan, EndSpan, CurlySpan),
          lazy_ast_node(Node, [], compound('{}'), [span(CurlySpan), type(curly)]),
          VOut = V0
        }
    ;   reactive_parse_term(OpTable, 1200, InnerNode, _, V0, V1),
        [CloseTok],
        { token_class(CloseTok, close_curly),
          token_source_span(CloseTok, EndSpan),
          combine_token_spans(StartSpan, EndSpan, CurlySpan),
          lazy_ast_node(Node, [InnerNode], compound('{}'), [span(CurlySpan), type(curly)]),
          VOut = V1
        }
    ).
parse_primary_class(bar, Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { token_source_span(Tok, Span),
      lazy_ast_node(Node, ['|'], literal, [span(Span), type(atom)]) }.
parse_primary_class(comma, Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { token_source_span(Tok, Span),
      lazy_ast_node(Node, [','], literal, [span(Span), type(atom)]) }.
parse_primary_class(atom, Tok, OpTable, MaxPrec, Node, PrecOut, V0, VOut) -->
    { token_val(Tok, NameChars),
      token_source_span(Tok, Span)
    },
    (   peek_tok(NextTok),
        { token_class(NextTok, open_ct) } ->
        [NextTok],
        parse_reactive_args(OpTable, ArgNodes, V0, V1),
        [CloseTok],
        { token_class(CloseTok, close),
          atom_chars(Functor, NameChars),
          lazy_ast_node(Node, ArgNodes, compound(Functor), [span(Span)]),
          PrecOut = 0,
          VOut = V1
        }
    ;   % Negative number check: "-" followed immediately by integer or float
        { NameChars = "-" },
        peek_tok(NumTok),
        { token_class(NumTok, integer), token_val(NumTok, IntVal) } ->
        [NumTok],
        { NegInt is -IntVal,
          token_source_span(NumTok, NumSpan),
          combine_token_spans(Span, NumSpan, FullSpan),
          lazy_ast_node(Node, [NegInt], literal, [span(FullSpan), type(integer)]),
          PrecOut = 0,
          VOut = V0
        }
    ;   { NameChars = "-" },
        peek_tok(NumTok),
        { token_class(NumTok, float), token_val(NumTok, FloatVal) } ->
        [NumTok],
        { NegFloat is -FloatVal,
          token_source_span(NumTok, NumSpan),
          combine_token_spans(Span, NumSpan, FullSpan),
          lazy_ast_node(Node, [NegFloat], literal, [span(FullSpan), type(float)]),
          PrecOut = 0,
          VOut = V0
        }
    ;   { prolog_lookup_prefix_op(OpTable, NameChars, OpPrec, _Fixity, RightMaxPrec),
          OpPrec #=< MaxPrec
        },
        peek_tok(NextTok),
        { can_be_operand_tok(NextTok) } ->
        reactive_parse_term(OpTable, RightMaxPrec, OperandNode, _, V0, VOut),
        { atom_chars(OpAtom, NameChars),
          lazy_ast_node(Node, [OperandNode], prefix(OpAtom), [span(Span), op(OpPrec)]),
          PrecOut = OpPrec
        }
    ;   { atom_chars(Atom, NameChars),
          lazy_ast_node(Node, [Atom], literal, [span(Span), type(atom)]),
          PrecOut = 0,
          VOut = V0
        }
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   List Parsing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_list_elements(_OpTable, Node, V, V) -->
    [CloseTok],
    { token_class(CloseTok, close_list),
      lazy_ast_node(Node, [], list, [type(list)])
    }.
parse_list_elements(OpTable, Node, V0, VOut) -->
    reactive_parse_term(OpTable, 999, HeadNode, _, V0, V1),
    parse_list_tail(OpTable, HeadNode, Node, V1, VOut).

parse_list_tail(OpTable, HeadNode, Node, V0, VOut) -->
    [Tok],
    { token_class(Tok, Class) },
    parse_list_tail_on_class(Class, OpTable, HeadNode, Node, V0, VOut).

parse_list_tail_on_class(comma, OpTable, HeadNode, Node, V0, VOut) -->
    reactive_parse_term(OpTable, 999, NextHead, _, V0, V1),
    parse_list_tail(OpTable, NextHead, TailNode, V1, VOut),
    { lazy_ast_node(Node, [HeadNode, TailNode], compound('[|]'), [type(list)]) }.
parse_list_tail_on_class(bar, OpTable, HeadNode, Node, V0, VOut) -->
    reactive_parse_term(OpTable, 1200, TailNode, _, V0, V1),
    [CloseTok],
    { token_class(CloseTok, close_list),
      lazy_ast_node(Node, [HeadNode, TailNode], compound('[|]'), [type(list)]),
      VOut = V1
    }.
parse_list_tail_on_class(close_list, _OpTable, HeadNode, Node, V0, V0) -->
    { lazy_ast_node(EmptyList, [], list, [type(list)]),
      lazy_ast_node(Node, [HeadNode, EmptyList], compound('[|]'), [type(list)])
    }.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Infix and Postfix Precedence Climbing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

reactive_parse_infix_postfix(OpTable, MaxPrec, Left0, LeftPrec, FinalTerm, FinalPrec, V0, VOut) -->
    (   peek_tok(Tok),
        { is_op_tok(Tok, OpChars) } ->
        (   % Infix operator
            { prolog_lookup_infix_op(OpTable, OpChars, Prec, _Fixity, LeftMaxPrec, RightMaxPrec),
              Prec #=< MaxPrec,
              LeftPrec #=< LeftMaxPrec
            },
            [Tok],
            peek_tok(NextTok),
            { can_be_operand_tok(NextTok) } ->
            reactive_parse_term(OpTable, RightMaxPrec, RightNode, _, V0, V1),
            { atom_chars(OpAtom, OpChars),
              token_source_span(Tok, OpSpan),
              lazy_ast_node(Left1, [Left0, RightNode], infix(OpAtom), [span(OpSpan), op(Prec)])
            },
            reactive_parse_infix_postfix(OpTable, MaxPrec, Left1, Prec, FinalTerm, FinalPrec, V1, VOut)
        ;   % Postfix operator
            { prolog_lookup_postfix_op(OpTable, OpChars, Prec, _Fixity, LeftMaxPrec),
              Prec #=< MaxPrec,
              LeftPrec #=< LeftMaxPrec
            } ->
            [Tok],
            { atom_chars(OpAtom, OpChars),
              token_source_span(Tok, OpSpan),
              lazy_ast_node(Left1, [Left0], postfix(OpAtom), [span(OpSpan), op(Prec)])
            },
            reactive_parse_infix_postfix(OpTable, MaxPrec, Left1, Prec, FinalTerm, FinalPrec, V0, VOut)
        ;   { FinalTerm = Left0, FinalPrec = LeftPrec, VOut = V0 }
        )
    ;   { FinalTerm = Left0, FinalPrec = LeftPrec, VOut = V0 }
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Argument Lists
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_reactive_args(OpTable, [Arg|Args], V0, VOut) -->
    reactive_parse_term(OpTable, 999, Arg, _, V0, V1),
    (   peek_tok(CommaTok),
        { token_class(CommaTok, comma) } ->
        [CommaTok],
        parse_reactive_args(OpTable, Args, V1, VOut)
    ;   { Args = [], VOut = V1 }
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   AST Unwrapping: ast_node/2 -> Pure Homoiconic Prolog Terms
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  ast_to_raw_term(+Node, -RawTerm) is det.
%
%   Strips reactive `ast_node/2` wrappers recursively to yield standard
%   executable Prolog terms and clauses with zero attribute overhead.
ast_to_raw_term(Node, Raw) :-
    (   var(Node) ->
        Raw = Node
    ;   Node = ast_node(Inner, _Meta) ->
        ast_to_raw_term(Inner, Raw)
    ;   Node = var_leaf(V) ->
        Raw = V
    ;   Node = '[|]'(H, T) ->
        ast_to_raw_term(H, HRaw),
        ast_to_raw_term(T, TRaw),
        Raw = [HRaw|TRaw]
    ;   Node = [H|T] ->
        ast_to_raw_term(H, HRaw),
        ast_to_raw_term(T, TRaw),
        Raw = [HRaw|TRaw]
    ;   Node = '{}'(Inner) ->
        ast_to_raw_term(Inner, InnerRaw),
        Raw = {InnerRaw}
    ;   atomic(Node) ->
        Raw = Node
    ;   compound(Node) ->
        Node =.. [F|Args],
        maplist(ast_to_raw_term, Args, RawArgs),
        Raw =.. [F|RawArgs]
    ;   Raw = Node
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Statement and Clause Parsing (Canonical & Backward Compatibility)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

prolog_parse_term(OpTable, Precedence, Term, Arg4, Arg5, Arg6) -->
    parse_term(OpTable, Precedence, Term, Arg4, Arg5, Arg6).

parse_term(OpTable, Precedence, Term, Arg4, Arg5, Arg6) -->
    (   { nonvar(Arg4), Arg4 = var_state(_) } ->
        % Mode: (OpTable, Precedence, Term, VarStateIn, VarStateOut, Span)
        reactive_parse_term(OpTable, Precedence, TermNode, _, Arg4, Arg5),
        { ast_to_raw_term(TermNode, Term),
          ast_node_metadata(TermNode, Meta),
          ( member(span(Arg6), Meta) -> true ; Arg6 = no_span )
        }
    ;   % Mode: (OpTable, Precedence, Term, PrecOut, VarStateIn, VarStateOut)
        reactive_parse_term(OpTable, Precedence, TermNode, Arg4, Arg5, Arg6),
        { ast_to_raw_term(TermNode, Term) }
    ).

prolog_parse_term(OpTable, Precedence, Term, PrecOut, VarStateIn, VarStateOut, Span) -->
    reactive_parse_term(OpTable, Precedence, TermNode, PrecOut, VarStateIn, VarStateOut),
    { ast_to_raw_term(TermNode, Term),
      ast_node_metadata(TermNode, Meta),
      ( member(span(Span), Meta) -> true ; Span = no_span )
    }.

parse_term(OpTable, Precedence, Term, PrecOut, VarStateIn, VarStateOut, Span) -->
    prolog_parse_term(OpTable, Precedence, Term, PrecOut, VarStateIn, VarStateOut, Span).

prolog_parse_clause(OpTable0, Statement, OpTableOut) -->
    prolog_parse_clause(OpTable0, [], Statement, OpTableOut).

parse_clause(OpTable0, Statement, OpTableOut) -->
    prolog_parse_clause(OpTable0, Statement, OpTableOut).

prolog_parse_clause(OpTable0, Options, Statement, OpTableOut) -->
    prolog_parse_raw_clause(OpTable0, Options, RawStatement, OpTable1),
    { if_(has_expansion_option_t(Options),
          ( prolog_initial_expander_state(Options, ExpState0),
            prolog_expand_statement(Options, RawStatement, ExpandedStmts, ExpState0, _),
            update_optable_from_statements(ExpandedStmts, OpTable1, OpTableOut),
            (   ExpandedStmts = [Single] ->
                Statement = Single
            ;   Statement = ExpandedStmts
            )
          ),
          ( Statement = RawStatement,
            OpTableOut = OpTable1
          )
      )
    }.

parse_clause(OpTable0, Options, Statement, OpTableOut) -->
    prolog_parse_clause(OpTable0, Options, Statement, OpTableOut).

prolog_parse_raw_clause(OpTable0, Options, Statement, OpTableOut) -->
    peek_tok(FirstTok),
    { token_source_span(FirstTok, StartSpan),
      prolog_initial_var_state(V0)
    },
    reactive_parse_term(OpTable0, 1200, TermNode, _, V0, VFinal),
    [EndTok],
    { token_class(EndTok, EndClass),
      if_(EndClass = end,
          ( token_source_span(EndTok, EndSpan),
            combine_token_spans(StartSpan, EndSpan, StatementSpan),
            prolog_var_state_bindings(VFinal, VarNames, Variables, Singletons),
            if_(is_reactive_ast_format_t(Options),
                ( wrap_clause_ast(TermNode, Statement),
                  OpTableOut = OpTable0
                ),
                ( ast_to_raw_term(TermNode, RawTerm),
                  build_statement(RawTerm, StatementSpan, VarNames, Variables, Singletons, Options, Statement),
                  update_optable_if_op_decl(RawTerm, OpTable0, OpTableOut)
                )
            )
          ),
          throw(error(syntax_error(expected_full_stop_end), EndTok))
      )
    }.

parse_raw_clause(OpTable0, Options, Statement, OpTableOut) -->
    prolog_parse_raw_clause(OpTable0, Options, Statement, OpTableOut).

is_reactive_ast_format_t([], false).
is_reactive_ast_format_t([Opt|Opts], Truth) :-
    if_(Opt = ast_format(Format),
        if_(Format = reactive, Truth = true, is_reactive_ast_format_t(Opts, Truth)),
        is_reactive_ast_format_t(Opts, Truth)
    ).

build_statement(Term, Span, VarNames, Variables, Singletons, Options, Statement) :-
    extract_file_line(Span, File, Line),
    Meta = meta([
        file(File),
        line(Line),
        span(Span),
        variable_names(VarNames),
        variables(Variables),
        singletons(Singletons)
    ]),
    if_(Term = (:- Goal),
        Statement = directive(Goal, Meta),
        if_(Term = (?- Goal),
            Statement = query(Goal, Meta),
            Statement = clause(Term, Meta)
        )
    ),
    apply_term_options(Options, VarNames, Variables, Singletons).

extract_file_line(Span, File, Line) :-
    if_(Span = span(pos(Line0, _, _, File0), _),
        ( File = File0, Line = Line0 ),
        ( File = unknown, Line = 0 )
    ).

apply_term_options([], _, _, _).
apply_term_options([Opt|Opts], VNs, Vs, Sing) :-
    if_(Opt = variable_names(VNsOut),
        VNsOut = VNs,
        if_(Opt = variables(VsOut),
            VsOut = Vs,
            if_(Opt = singletons(SingOut),
                SingOut = Sing,
                true
            )
        )
    ),
    apply_term_options(Opts, VNs, Vs, Sing).

combine_token_spans(Span1, Span2, Out) :-
    if_(Span1 = none,
        Out = none,
        if_(Span2 = none,
            Out = none,
            ( Span1 = span(Start, _),
              Span2 = span(_, End),
              Out = span(Start, End)
            )
        )
    ).

has_expansion_option_t([], false).
has_expansion_option_t([Opt|Opts], Truth) :-
    if_(Opt = expand_mode(M),
        if_(M = none,
            has_expansion_option_t(Opts, Truth),
            Truth = true
        ),
        if_(Opt = expand_rules(_),
            Truth = true,
            has_expansion_option_t(Opts, Truth)
        )
    ).

update_optable_if_op_decl(Term, OpTable0, OpTableOut) :-
    if_(Term = (:- op(Prec, Spec, Op)),
        add_operator(OpTable0, Prec, Spec, Op, OpTableOut),
        if_(Term = (:- module(_, Exports)),
            import_exported_ops(Exports, OpTable0, OpTableOut),
            OpTableOut = OpTable0
        )
    ).

import_exported_ops([], T, T).
import_exported_ops([Item|Rest], T0, TOut) :-
    if_(Item = op(P, S, O),
        add_operator(T0, P, S, O, T1),
        T1 = T0
    ),
    import_exported_ops(Rest, T1, TOut).

update_optable_from_statements([], T, T).
update_optable_from_statements([Stmt|Rest], T0, TOut) :-
    update_optable_from_single_statement(Stmt, T0, T1),
    update_optable_from_statements(Rest, T1, TOut).

update_optable_from_single_statement(Stmt, T0, T1) :-
    if_(Stmt = directive(op(Prec, Spec, Op), _),
        add_operator(T0, Prec, Spec, Op, T1),
        if_(Stmt = directive(module(_, Exports), _),
            import_exported_ops(Exports, T0, T1),
            T1 = T0
        )
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Program Parsing (Sequence of Statements until EOF)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

prolog_parse_program(OpTable, Statements, FinalOpTable) -->
    prolog_parse_program(OpTable, [], Statements, FinalOpTable).

parse_program(OpTable, Statements, FinalOpTable) -->
    prolog_parse_program(OpTable, Statements, FinalOpTable).

prolog_parse_program(OpTable0, Options, Statements, FinalOpTable) -->
    { prolog_initial_expander_state(Options, ExpState0) },
    parse_program_loop(OpTable0, Options, Statements, FinalOpTable, ExpState0, _).

parse_program(OpTable0, Options, Statements, FinalOpTable) -->
    prolog_parse_program(OpTable0, Options, Statements, FinalOpTable).

parse_program_loop(OpTable, _Options, [], OpTable, ExpState, ExpState) --> [].
parse_program_loop(OpTable0, Options, Statements, FinalOpTable, ExpState0, ExpStateFinal) -->
    prolog_parse_raw_clause(OpTable0, Options, RawStatement, OpTable1),
    { if_(has_expansion_option_t(Options),
          ( prolog_expand_statement(Options, RawStatement, ExpandedStmts, ExpState0, ExpState1),
            update_optable_from_statements(ExpandedStmts, OpTable1, OpTable2)
          ),
          ( ExpandedStmts = [RawStatement],
            OpTable2 = OpTable1,
            ExpState1 = ExpState0
          )
      ),
      append(ExpandedStmts, RestStmts, Statements)
    },
    parse_program_loop(OpTable2, Options, RestStmts, FinalOpTable, ExpState1, ExpStateFinal).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Incremental Parsing & AST Holes
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%!  create_ast_hole(-HoleNode, +HoleID, +Metadata) is det.
%
%   Creates an unbound lazy AST node representing an unparsed or dirty code region.
create_ast_hole(HoleNode, HoleID, Metadata) :-
    lazy_ast_node(HoleNode, [_PendingHoleVal], raw_term, [hole_id(HoleID)|Metadata]).

%!  reactive_parse_subterm(+Chars, +Options, +VarStateIn, -SubNode, -VarStateOut) is semidet.
%
%   Incrementally parses a subterm or sub-goal from Chars within an existing
%   VarState context, allowing variables in the subterm to bind with variables
%   already defined in the outer clause.
reactive_parse_subterm(Chars, Options, V0, SubNode, VOut) :-
    chars_to_attributed_tokens(Chars, Options, AttrTokens),
    if_(memberd_t(operators(OpTable), Options),
        true,
        prolog_default_operator_table(OpTable)
    ),
    phrase(reactive_parse_term(OpTable, 1200, SubNode, _, V0, VOut), AttrTokens).

%!  reactive_build_rule(+HeadNode, +BodyNode, +Metadata, -RuleAST) is det.
%
%   Constructs a reactive rule AST node depending on HeadNode and BodyNode.
reactive_build_rule(HeadNode, BodyNode, Metadata, RuleAST) :-
    lazy_ast_node(RuleAST, [HeadNode, BodyNode], rule, [clause_type(rule)|Metadata]).
