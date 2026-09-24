:- module(prolog_reactive_parser, [
    reactive_parse_clause//2,
    reactive_parse_clause//3,
    reactive_parse_term//4,
    reactive_parse_term//6,
    reactive_chars_to_ast/2,
    reactive_chars_to_ast/3
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(prolog_operator_table).
:- use_module(prolog_attributed_tokens).
:- use_module(prolog_reactive_ast).
:- use_module(prolog_parser, [
    prolog_initial_var_state/1,
    prolog_var_state_bindings/4
]).

/** <module> Reactive Attributed Prolog Parser

This module parses streams of attributed tokens into Reactive Abstract Syntax Tree (AST)
nodes built on `library(atts)`.

=== Key Ideas ===

1. **Attributed Token Ingestion**:
   Grammar rules consume attributed token variables that carry positions, spans,
   values, and operator metadata directly as first-class attributes.

2. **Lazy AST Generation**:
   Every grammar production creates an unbound logical variable with an `ast_node/4`
   attribute and registers its child dependencies.
   - Operands and literals form lazy leaf nodes.
   - Operator expressions form lazy binary or unary nodes.
   - Clauses and rules form lazy rule nodes.

3. **Automatic Span Merging & Semantic Propagation**:
   As child AST nodes are parsed and unified, `verify_attributes/3` fires automatically,
   merging child token spans (`span(StartPos, EndPos)`) and triggering any reactive
   semantic actions (such as type constraints or constant folding).

4. **Program Variable Preservation**:
   Source variables (`X`, `_Tail`) are tracked in the clause variable state and embedded
   as `var_leaf(ProgVar)` AST leaf nodes, preserving first-class logical variables
   without blocking the resolution of the surrounding tree.
*/

%!  reactive_chars_to_ast(+Chars, -ClauseAST) is semidet.
%
%   Scans and parses Chars into a reactive AST node using the default operator table.
reactive_chars_to_ast(Chars, ClauseAST) :-
    reactive_chars_to_ast(Chars, [], ClauseAST).

%!  reactive_chars_to_ast(+Chars, +Options, -ClauseAST) is semidet.
%
%   Scans and parses Chars into a reactive AST node with Options.
reactive_chars_to_ast(Chars, Options, ClauseAST) :-
    chars_to_attributed_tokens(Chars, Options, AttrTokens),
    (   member(operators(OpTable), Options) ->
        true
    ;   prolog_default_operator_table(OpTable)
    ),
    phrase(reactive_parse_clause(OpTable, ClauseAST), AttrTokens).

%!  reactive_parse_clause(-ClauseAST, -VarBindings)// is semidet.
%
%   Parses an attributed token stream into a reactive clause AST and extracts variable bindings.
reactive_parse_clause(ClauseAST, VarBindings) -->
    { prolog_default_operator_table(OpTable) },
    reactive_parse_clause(OpTable, ClauseAST, VarBindings).

%!  reactive_parse_clause(+OpTable, -ClauseAST)// is semidet.
reactive_parse_clause(OpTable, ClauseAST) -->
    reactive_parse_clause(OpTable, ClauseAST, _).

%!  reactive_parse_clause(+OpTable, -ClauseAST, -VarBindings)// is semidet.
reactive_parse_clause(OpTable, ClauseAST, VarBindings) -->
    { prolog_initial_var_state(V0) },
    reactive_parse_term(OpTable, 1200, TermNode, _, V0, V1),
    [EndTok],
    { get_token_class(EndTok, end),
      prolog_var_state_bindings(V1, VNs, Vs, Singletons),
      VarBindings = [variable_names(VNs), variables(Vs), singletons(Singletons)],
      % Package into reactive clause AST node
      wrap_clause_ast(TermNode, ClauseAST)
    }.

wrap_clause_ast(TermNode, ClauseAST) :-
    % Inspect resolved or lazy structure of TermNode
    (   TermNode = ast_node((Head :- Body), Meta) ->
        lazy_ast_node(ClauseAST, [TermNode], rule(Head, Body), [clause_type(rule)|Meta])
    ;   TermNode = ast_node((Head --> Body), Meta) ->
        lazy_ast_node(ClauseAST, [TermNode], dcg_rule(Head, Body), [clause_type(dcg)|Meta])
    ;   TermNode = ast_node((:- Directive), Meta) ->
        lazy_ast_node(ClauseAST, [TermNode], directive(Directive), [clause_type(directive)|Meta])
    ;   lazy_ast_node(ClauseAST, [TermNode], fact(TermNode), [clause_type(fact)])
    ).

%!  reactive_parse_term(+OpTable, +MaxPrec, -TermNode, -PrecOut)// is semidet.
reactive_parse_term(OpTable, MaxPrec, TermNode, PrecOut) -->
    { prolog_initial_var_state(V0) },
    reactive_parse_term(OpTable, MaxPrec, TermNode, PrecOut, V0, _).

%!  reactive_parse_term(+OpTable, +MaxPrec, -TermNode, -PrecOut, +V0, -VOut)// is semidet.
reactive_parse_term(OpTable, MaxPrec, TermNode, PrecOut, V0, VOut) -->
    reactive_parse_prefix_or_primary(OpTable, MaxPrec, Left0, LeftPrec, V0, V1),
    reactive_parse_infix_postfix(OpTable, MaxPrec, Left0, LeftPrec, TermNode, PrecOut, V1, VOut).

% --- Primary and Prefix Expressions ---

reactive_parse_prefix_or_primary(OpTable, MaxPrec, Node, PrecOut, V0, VOut) -->
    [Tok],
    { is_attributed_token(Tok) },
    parse_primary_tok(Tok, OpTable, MaxPrec, Node, PrecOut, V0, VOut).

parse_primary_tok(Tok, _OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    { get_token_class(Tok, var),
      get_token_value(Tok, NameChars),
      get_token_span(Tok, Span),
      lookup_var_reactive(V0, NameChars, ProgVar, Span, VOut),
      lazy_ast_node(Node, [], var_leaf(ProgVar), [name(NameChars), span(Span), type(var)])
    }.

parse_primary_tok(Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { get_token_class(Tok, integer),
      get_token_value(Tok, IntVal),
      get_token_span(Tok, Span),
      lazy_ast_node(Node, [IntVal], literal, [span(Span), type(integer)])
    }.

parse_primary_tok(Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { get_token_class(Tok, float),
      get_token_value(Tok, FloatVal),
      get_token_span(Tok, Span),
      lazy_ast_node(Node, [FloatVal], literal, [span(Span), type(float)])
    }.

parse_primary_tok(Tok, _OpTable, _MaxPrec, Node, 0, V, V) -->
    { get_token_class(Tok, string),
      get_token_value(Tok, Chars),
      get_token_span(Tok, Span),
      lazy_ast_node(Node, [Chars], literal, [span(Span), type(string)])
    }.

% Parentheses: ( Expr )
parse_primary_tok(Tok, OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    { ( get_token_class(Tok, open) ; get_token_class(Tok, open_ct) ) },
    reactive_parse_term(OpTable, 1200, InnerNode, _, V0, V1),
    [CloseTok],
    { get_token_class(CloseTok, close),
      VOut = V1,
      Node = InnerNode
    }.

% List expressions: [ ... ]
parse_primary_tok(Tok, OpTable, _MaxPrec, Node, 0, V0, VOut) -->
    { get_token_class(Tok, open_list) },
    parse_list_elements(OpTable, Node, V0, VOut).

% Atom or Prefix Operator or Functor Call
parse_primary_tok(Tok, OpTable, MaxPrec, Node, PrecOut, V0, VOut) -->
    { get_token_class(Tok, atom),
      get_token_value(Tok, NameChars),
      get_token_span(Tok, Span)
    },
    (   % Case 1: Compound functor call: foo(Arg1, Arg2, ...)
        peek_tok(NextTok),
        { get_token_class(NextTok, open_ct) } ->
        [NextTok],
        parse_reactive_args(OpTable, ArgNodes, V0, V1),
        [CloseTok],
        { get_token_class(CloseTok, close),
          atom_chars(Functor, NameChars),
          lazy_ast_node(Node, ArgNodes, compound(Functor), [span(Span)]),
          PrecOut = 0,
          VOut = V1
        }
    ;   % Case 2: Prefix Operator: op Arg
        { prolog_lookup_prefix_op(OpTable, NameChars, OpPrec, _Fixity, RightMaxPrec),
          OpPrec #=< MaxPrec
        },
        peek_tok(NextTok),
        { can_be_operand_tok(NextTok) } ->
        reactive_parse_term(OpTable, RightMaxPrec, OperandNode, _, V0, VOut),
        { atom_chars(OpAtom, NameChars),
          lazy_ast_node(Node, [OperandNode], prefix(OpAtom), [span(Span), op(OpPrec)]),
          PrecOut = OpPrec
        }
    ;   % Case 3: Standalone Atom
        { atom_chars(Atom, NameChars),
          lazy_ast_node(Node, [Atom], literal, [span(Span), type(atom)]),
          PrecOut = 0,
          VOut = V0
        }
    ).

% --- List Parsing ---

parse_list_elements(_OpTable, Node, V, V) -->
    [CloseTok],
    { get_token_class(CloseTok, close_list),
      lazy_ast_node(Node, [], list, [type(list)])
    }.
parse_list_elements(OpTable, Node, V0, VOut) -->
    reactive_parse_term(OpTable, 999, HeadNode, _, V0, V1),
    parse_list_tail(OpTable, HeadNode, Node, V1, VOut).

parse_list_tail(OpTable, HeadNode, Node, V0, VOut) -->
    [Tok],
    (   { get_token_class(Tok, comma) } ->
        reactive_parse_term(OpTable, 999, NextHead, _, V0, V1),
        parse_list_tail(OpTable, NextHead, TailNode, V1, VOut),
        { lazy_ast_node(Node, [HeadNode, TailNode], compound('[|]'), [type(list)]) }
    ;   { get_token_class(Tok, bar) } ->
        reactive_parse_term(OpTable, 1200, TailNode, _, V0, V1),
        [CloseTok],
        { get_token_class(CloseTok, close_list),
          lazy_ast_node(Node, [HeadNode, TailNode], compound('[|]'), [type(list)]),
          VOut = V1
        }
    ;   { get_token_class(Tok, close_list) },
        { lazy_ast_node(EmptyList, [], list, [type(list)]),
          lazy_ast_node(Node, [HeadNode, EmptyList], compound('[|]'), [type(list)]),
          VOut = V0
        }
    ).

% --- Infix and Postfix Parsing ---

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
              get_token_span(Tok, OpSpan),
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
              get_token_span(Tok, OpSpan),
              lazy_ast_node(Left1, [Left0], postfix(OpAtom), [span(OpSpan), op(Prec)])
            },
            reactive_parse_infix_postfix(OpTable, MaxPrec, Left1, Prec, FinalTerm, FinalPrec, V0, VOut)
        ;   { FinalTerm = Left0, FinalPrec = LeftPrec, VOut = V0 }
        )
    ;   { FinalTerm = Left0, FinalPrec = LeftPrec, VOut = V0 }
    ).

% --- Argument Lists ---

parse_reactive_args(OpTable, [Arg|Args], V0, VOut) -->
    reactive_parse_term(OpTable, 999, Arg, _, V0, V1),
    (   peek_tok(CommaTok),
        { get_token_class(CommaTok, comma) } ->
        [CommaTok],
        parse_reactive_args(OpTable, Args, V1, VOut)
    ;   { Args = [], VOut = V1 }
    ).

% --- Helper Predicates ---

peek_tok(Tok), [Tok] --> [Tok].

can_be_operand_tok(Tok) :-
    get_token_class(Tok, Class),
    \+ member(Class, [close, close_list, close_curly, comma, bar, end]).

is_op_tok(Tok, OpChars) :-
    get_token_class(Tok, Class),
    (   Class = atom ->
        get_token_value(Tok, OpChars)
    ;   Class = comma ->
        OpChars = ","
    ;   Class = bar ->
        OpChars = "|"
    ;   false
    ).

lookup_var_reactive(var_state(Map0), NameChars, Var, Span, var_state(Map1)) :-
    (   NameChars = "_" ->
        Map1 = [anon_entry(Var, [Span])|Map0]
    ;   lookup_named_var(Map0, NameChars, Var, Span, Map1)
    ).

lookup_named_var([], NameChars, Var, Span, [entry(NameChars, Var, [Span])]).
lookup_named_var([entry(Name, ExistingVar, Spans)|Rest], NameChars, Var, Span, Result) :-
    (   Name == NameChars ->
        Var = ExistingVar,
        Result = [entry(Name, Var, [Span|Spans])|Rest]
    ;   lookup_named_var(Rest, NameChars, Var, Span, SubRest),
        Result = [entry(Name, ExistingVar, Spans)|SubRest]
    ).
lookup_named_var([anon_entry(V, S)|Rest], NameChars, Var, Span, [anon_entry(V, S)|SubRest]) :-
    lookup_named_var(Rest, NameChars, Var, Span, SubRest).
