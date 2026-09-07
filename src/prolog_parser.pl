/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - ISO Term & Clause Parser

   A pure Pratt / Operator Precedence Climbing parser for ISO Prolog.
   Produces homoiconic Prolog terms wrapped in clause/directive statement
   envelopes with source line, file, and span provenance.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(prolog_parser, [
    % Canonical Prolog Parser API
    prolog_parse_term//6,
    prolog_parse_clause//3,
    prolog_parse_clause//4,
    prolog_parse_program//3,
    prolog_parse_program//4,
    prolog_initial_var_state/1,
    prolog_var_state_bindings/4,

    % Backward-compatibility aliases
    parse_term//6,
    parse_clause//3,
    parse_clause//4,
    parse_program//3,
    parse_program//4,
    initial_var_state/1,
    var_state_bindings/4
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

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Variable State Tracking (Variable Names, Singletons, Variables)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

initial_var_state(var_state([])).

lookup_var(var_state(Map0), NameChars, Var, var_state(Map1)) :-
    if_(NameChars = "_",
        ( Map1 = Map0 ),  % Anonymous variable: fresh, not tracked
        update_var_map(Map0, NameChars, Var, Map1)
    ).

update_var_map([], Name, Var, [entry(Name, Var, 1)]).
update_var_map([entry(N, V, Count)|Rest], Name, Var, Out) :-
    if_(N = Name,
        ( Var = V,
          Count1 #= Count + 1,
          Out = [entry(N, V, Count1)|Rest]
        ),
        ( Out = [entry(N, V, Count)|Rest1],
          update_var_map(Rest, Name, Var, Rest1)
        )
    ).

var_state_bindings(var_state(Map), VarNames, Variables, Singletons) :-
    extract_bindings(Map, VarNames, Variables, Singletons).

singleton_t(Count, NameChars, Truth) :-
    if_(Count #= 1,
        if_(NameChars = ['_'|_], Truth = false, Truth = true),
        Truth = false
    ).

extract_bindings([], [], [], []).
extract_bindings([entry(NameChars, Var, Count)|Rest], [Name = Var|VNs], [Var|Vs], Singletons) :-
    atom_chars(Name, NameChars),
    if_(singleton_t(Count, NameChars),
        Singletons = [Name = Var | SingRest],
        Singletons = SingRest
    ),
    extract_bindings(Rest, VNs, Vs, SingRest).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Token Inspection Helpers
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

token_info(Tok, Type, Val, Span) :-
    token_type(Tok, Type),
    token_value(Tok, Val),
    token_span(Tok, Span).

peek_token(Tok), [Tok] --> [Tok].

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Core Term Parser (Pratt / Operator Precedence Climbing)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% parse_term(+OpTable, +MaxPrec, -Term, -PrecOut, +VarState0, -VarStateOut)//
parse_term(OpTable, MaxPrec, Term, PrecOut, V0, VOut) -->
    parse_prefix_or_primary(OpTable, MaxPrec, Left0, LeftPrec, V0, V1),
    parse_infix_postfix(OpTable, MaxPrec, Left0, LeftPrec, Term, PrecOut, V1, VOut).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Primary and Prefix Expressions
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_prefix_or_primary(OpTable, MaxPrec, Term, PrecOut, V0, VOut) -->
    [Tok],
    { token_info(Tok, Type, Val, _Span) },
    parse_primary_token(Type, Val, Tok, OpTable, MaxPrec, Term, PrecOut, V0, VOut).

% Variables
parse_primary_token(var, NameChars, _Tok, _OpTable, _MaxPrec, Var, 0, V0, VOut) -->
    { lookup_var(V0, NameChars, Var, VOut) }.

% Constant Literals
parse_primary_token(integer, IntVal, _Tok, _OpTable, _MaxPrec, IntVal, 0, V, V) --> [].
parse_primary_token(float, FloatVal, _Tok, _OpTable, _MaxPrec, FloatVal, 0, V, V) --> [].

% String (double quotes -> list of chars)
parse_primary_token(string, Chars, _Tok, _OpTable, _MaxPrec, Chars, 0, V, V) --> [].

% Parenthesized expression: ( Expr )
parse_primary_token(open, _, _Tok, OpTable, _MaxPrec, Term, 0, V0, VOut) -->
    parse_term(OpTable, 1200, Term, _, V0, V1),
    [CloseTok],
    { token_type(CloseTok, CloseType),
      if_(CloseType = close,
          VOut = V1,
          throw(error(syntax_error(expected_closing_parenthesis), CloseTok))
      )
    }.

parse_primary_token(open_ct, _, _Tok, OpTable, _MaxPrec, Term, 0, V0, VOut) -->
    parse_term(OpTable, 1200, Term, _, V0, V1),
    [CloseTok],
    { token_type(CloseTok, CloseType),
      if_(CloseType = close,
          VOut = V1,
          throw(error(syntax_error(expected_closing_parenthesis), CloseTok))
      )
    }.

% List expressions: [ ... ]
parse_primary_token(open_list, _, _Tok, OpTable, _MaxPrec, List, 0, V0, VOut) -->
    parse_list_contents(OpTable, List, V0, VOut).

% Curly bracket expressions: { ... }
parse_primary_token(open_curly, _, _Tok, OpTable, _MaxPrec, CurlyTerm, 0, V0, VOut) -->
    (   [CloseTok], { token_type(CloseTok, close_curly) } ->
        { CurlyTerm = '{}', VOut = V0 }
    ;   parse_term(OpTable, 1200, Inner, _, V0, V1),
        [CloseTok],
        { token_type(CloseTok, CloseType),
          if_(CloseType = close_curly,
              ( CurlyTerm = '{}'(Inner), VOut = V1 ),
              throw(error(syntax_error(expected_closing_curly_bracket), CloseTok))
          )
        }
    ).

% Atom or Functor Call or Prefix Operator
parse_primary_token(atom, NameChars, _Tok, OpTable, MaxPrec, Term, PrecOut, V0, VOut) -->
    % Check if followed immediately by open_ct -> Functor call: foo(Arg1, ...)
    (   [NextTok], { token_type(NextTok, open_ct) } ->
        parse_args(OpTable, Args, V0, VOut),
        { atom_chars(Atom, NameChars),
          Term =.. [Atom|Args],
          PrecOut = 0
        }
    ;   % Negative number check: "-" followed immediately by integer or float
        { NameChars = "-" },
        peek_token(NumTok),
        { token_type(NumTok, integer), token_value(NumTok, IntVal) } ->
        [NumTok],
        { Term is -IntVal, PrecOut = 0, VOut = V0 }
    ;   { NameChars = "-" },
        peek_token(NumTok),
        { token_type(NumTok, float), token_value(NumTok, FloatVal) } ->
        [NumTok],
        { Term is -FloatVal, PrecOut = 0, VOut = V0 }
    ;   % Prefix operator check
        { lookup_prefix_op(OpTable, NameChars, OpPrec, _Fixity, RightMaxPrec),
          OpPrec #=< MaxPrec
        },
        peek_token(NextTok),
        { can_be_operand(NextTok) } ->
        parse_term(OpTable, RightMaxPrec, Operand, _, V0, VOut),
        { atom_chars(OpAtom, NameChars),
          Term =.. [OpAtom, Operand],
          PrecOut = OpPrec
        }
    ;   % Standalone atom
        { atom_chars(Atom, NameChars),
          Term = Atom,
          PrecOut = 0,
          VOut = V0
        }
    ).

can_be_operand(Tok) :-
    token_type(Tok, Type),
    memberd_t(Type, [close, close_list, close_curly, comma, bar, end], false).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Infix and Postfix Parsing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

% Pratt precedence climbing loop: greedily shifts operator tokens whose precedence
% satisfies LeftPrec #=< LeftMaxPrec and Prec #=< MaxPrec.
parse_infix_postfix(OpTable, MaxPrec, Left0, LeftPrec, FinalTerm, FinalPrec, V0, VOut) -->
    (   peek_token(Tok),
        { is_operator_token(Tok, OpChars) } ->
        (   % Infix operator commit when followed by valid operand
            { lookup_infix_op(OpTable, OpChars, Prec, _Fixity, LeftMaxPrec, RightMaxPrec),
              Prec #=< MaxPrec,
              LeftPrec #=< LeftMaxPrec
            },
            [Tok],
            peek_token(NextTok),
            { can_be_operand(NextTok) } ->
            parse_term(OpTable, RightMaxPrec, Right, _, V0, V1),
            { atom_chars(OpAtom, OpChars),
              Left1 =.. [OpAtom, Left0, Right]
            },
            parse_infix_postfix(OpTable, MaxPrec, Left1, Prec, FinalTerm, FinalPrec, V1, VOut)
        ;   % Postfix operator commit
            { lookup_postfix_op(OpTable, OpChars, Prec, _Fixity, LeftMaxPrec),
              Prec #=< MaxPrec,
              LeftPrec #=< LeftMaxPrec
            } ->
            [Tok],
            { atom_chars(OpAtom, OpChars),
              Left1 =.. [OpAtom, Left0]
            },
            parse_infix_postfix(OpTable, MaxPrec, Left1, Prec, FinalTerm, FinalPrec, V0, VOut)
        ;   { FinalTerm = Left0, FinalPrec = LeftPrec, VOut = V0 }
        )
    ;   { FinalTerm = Left0, FinalPrec = LeftPrec, VOut = V0 }
    ).

is_operator_token(Tok, OpChars) :-
    token_type(Tok, Type),
    if_(Type = atom,
        token_value(Tok, OpChars),
        if_(Type = comma,
            OpChars = ",",
            if_(Type = bar,
                OpChars = "|",
                false
            )
        )
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Argument Lists and List Parsing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

% Comma-separated arguments inside foo(Arg1, Arg2, ...)
parse_args(OpTable, [Arg|Args], V0, VOut) -->
    parse_term(OpTable, 999, Arg, _, V0, V1),
    [NextTok],
    { token_type(NextTok, NextType) },
    parse_args_rest(NextType, NextTok, OpTable, Args, V1, VOut).

parse_args_rest(comma, _Tok, OpTable, Args, V0, VOut) -->
    parse_args(OpTable, Args, V0, VOut).
parse_args_rest(close, _Tok, _OpTable, [], V, V) --> [].
parse_args_rest(Other, Tok, _OpTable, _, _, _) -->
    { dif(Other, comma), dif(Other, close),
      throw(error(syntax_error(expected_comma_or_close_paren), Tok)) }.

% List contents inside [ ... ]
parse_list_contents(OpTable, List, V0, VOut) -->
    peek_token(Tok),
    { token_type(Tok, Type) },
    parse_list_head(Type, Tok, OpTable, List, V0, VOut).

parse_list_head(close_list, Tok, _OpTable, [], V, V) -->
    [Tok].
parse_list_head(Other, _Tok, OpTable, [Elem|Tail], V0, VOut) -->
    { dif(Other, close_list) },
    parse_term(OpTable, 999, Elem, _, V0, V1),
    parse_list_rest(OpTable, Tail, V1, VOut).

parse_list_rest(OpTable, Tail, V0, VOut) -->
    [NextTok],
    { token_type(NextTok, NextType) },
    parse_list_next(NextType, NextTok, OpTable, Tail, V0, VOut).

parse_list_next(comma, _Tok, OpTable, [Elem|Tail], V0, VOut) -->
    parse_term(OpTable, 999, Elem, _, V0, V1),
    parse_list_rest(OpTable, Tail, V1, VOut).
parse_list_next(bar, _Tok, OpTable, Tail, V0, VOut) -->
    parse_term(OpTable, 999, Tail, _, V0, V1),
    [CloseTok],
    { token_type(CloseTok, CloseType),
      if_(CloseType = close_list,
          VOut = V1,
          throw(error(syntax_error(expected_closing_bracket), CloseTok))
      )
    }.
parse_list_next(close_list, _Tok, _OpTable, [], V, V) --> [].
parse_list_next(Other, Tok, _OpTable, _, _, _) -->
    { dif(Other, comma), dif(Other, bar), dif(Other, close_list),
      throw(error(syntax_error(expected_comma_bar_or_close_bracket), Tok)) }.

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Statement and Clause Parsing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% parse_clause(+OpTable0, -Statement, -OpTableOut)//
parse_clause(OpTable0, Statement, OpTableOut) -->
    parse_clause(OpTable0, [], Statement, OpTableOut).

%% parse_clause(+OpTable0, +Options, -Statement, -OpTableOut)//
parse_clause(OpTable0, Options, Statement, OpTableOut) -->
    peek_token(FirstTok),
    { token_span(FirstTok, StartSpan) },
    { initial_var_state(V0) },
    parse_term(OpTable0, 1200, Term, _, V0, VFinal),
    [EndTok],
    { token_type(EndTok, EndType),
      if_(EndType = end,
          ( token_span(EndTok, EndSpan),
            combine_token_spans(StartSpan, EndSpan, StatementSpan),
            var_state_bindings(VFinal, VarNames, Variables, Singletons),
            build_statement(Term, StatementSpan, VarNames, Variables, Singletons, Options, Statement),
            update_optable_if_op_decl(Term, OpTable0, OpTableOut)
          ),
          throw(error(syntax_error(expected_full_stop_end), EndTok))
      )
    }.

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

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Program Parsing (Sequence of Statements until EOF)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_program(OpTable, Statements, FinalOpTable) -->
    parse_program(OpTable, [], Statements, FinalOpTable).

parse_program(OpTable, _Options, [], OpTable) --> [].
parse_program(OpTable0, Options, [Stmt|Stmts], FinalOpTable) -->
    parse_clause(OpTable0, Options, Stmt, OpTable1),
    parse_program(OpTable1, Options, Stmts, FinalOpTable).

%% Canonical prolog_* predicate definitions
prolog_parse_term(OpTable, Precedence, Term, VarStateIn, VarStateOut, Span) -->
    parse_term(OpTable, Precedence, Term, VarStateIn, VarStateOut, Span).
prolog_parse_clause(OpTable0, Stmt, OpTableOut) -->
    parse_clause(OpTable0, Stmt, OpTableOut).
prolog_parse_clause(OpTable0, Options, Stmt, OpTableOut) -->
    parse_clause(OpTable0, Options, Stmt, OpTableOut).
prolog_parse_program(OpTable, Statements, FinalOpTable) -->
    parse_program(OpTable, Statements, FinalOpTable).
prolog_parse_program(OpTable, Options, Statements, FinalOpTable) -->
    parse_program(OpTable, Options, Statements, FinalOpTable).
prolog_initial_var_state(State) :- initial_var_state(State).
prolog_var_state_bindings(State, VarNames, Variables, Singletons) :-
    var_state_bindings(State, VarNames, Variables, Singletons).
