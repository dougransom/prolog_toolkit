/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - ISO Term & Clause Parser

   A pure Pratt / Operator Precedence Climbing parser for ISO Prolog.
   Produces homoiconic Prolog terms wrapped in clause/directive statement
   envelopes with source line, file, and span provenance.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(iso_parser, [
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
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(operator_table).
:- use_module(token).

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

extract_bindings([], [], [], []).
extract_bindings([entry(NameChars, Var, Count)|Rest], [Name = Var|VNs], [Var|Vs], Singletons) :-
    atom_chars(Name, NameChars),
    (   Count #= 1,
        \+ member(NameChars, ["_", "_dummy"]),
        \+ ( NameChars = [0'_|_] ) ->
        Singletons = [Name = Var | SingRest]
    ;   Singletons = SingRest
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
parse_primary_token(var, NameChars, _Tok, _OpTable, _MaxPrec, Var, 0, V0, VOut) --> !,
    { lookup_var(V0, NameChars, Var, VOut) }.

% Integers & Floats
parse_primary_token(integer, IntVal, _Tok, _OpTable, _MaxPrec, IntVal, 0, V, V) --> !.
parse_primary_token(float, FloatVal, _Tok, _OpTable, _MaxPrec, FloatVal, 0, V, V) --> !.

% String (double quotes -> list of chars)
parse_primary_token(string, Chars, _Tok, _OpTable, _MaxPrec, Chars, 0, V, V) --> !.

% Parenthesized expression: ( Expr )
parse_primary_token(open, _, _Tok, OpTable, _MaxPrec, Term, 0, V0, VOut) --> !,
    parse_term(OpTable, 1200, Term, _, V0, V1),
    [CloseTok],
    { token_type(CloseTok, close) -> VOut = V1
    ; throw(error(syntax_error(expected_closing_parenthesis), CloseTok))
    }.

parse_primary_token(open_ct, _, _Tok, OpTable, _MaxPrec, Term, 0, V0, VOut) --> !,
    parse_term(OpTable, 1200, Term, _, V0, V1),
    [CloseTok],
    { token_type(CloseTok, close) -> VOut = V1
    ; throw(error(syntax_error(expected_closing_parenthesis), CloseTok))
    }.

% List expressions: [ ... ]
parse_primary_token(open_list, _, _Tok, OpTable, _MaxPrec, List, 0, V0, VOut) --> !,
    parse_list_contents(OpTable, List, V0, VOut).

% Curly bracket expressions: { ... }
parse_primary_token(open_curly, _, _Tok, OpTable, _MaxPrec, CurlyTerm, 0, V0, VOut) --> !,
    (   [CloseTok], { token_type(CloseTok, close_curly) } ->
        { CurlyTerm = '{}', VOut = V0 }
    ;   parse_term(OpTable, 1200, Inner, _, V0, V1),
        [CloseTok],
        { token_type(CloseTok, close_curly) ->
            CurlyTerm = {}(Inner),
            VOut = V1
        ;   throw(error(syntax_error(expected_closing_curly_bracket), CloseTok))
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
    \+ member(Type, [close, close_list, close_curly, comma, bar, end]).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Infix and Postfix Parsing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_infix_postfix(OpTable, MaxPrec, Left0, LeftPrec, FinalTerm, FinalPrec, V0, VOut) -->
    (   peek_token(Tok),
        { is_operator_token(Tok, OpChars) } ->
        (   % Infix operator
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
        ;   % Postfix operator
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
    (   Type = atom -> token_value(Tok, OpChars)
    ;   Type = comma -> OpChars = ","
    ;   Type = bar -> OpChars = "|"
    ;   fail
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Argument Lists and List Parsing
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

% Comma-separated arguments inside foo(Arg1, Arg2, ...)
parse_args(OpTable, [Arg|Args], V0, VOut) -->
    parse_term(OpTable, 999, Arg, _, V0, V1),
    (   [CommaTok], { token_type(CommaTok, comma) } ->
        parse_args(OpTable, Args, V1, VOut)
    ;   [CloseTok], { token_type(CloseTok, close) } ->
        { Args = [], VOut = V1 }
    ;   [BadTok],
        { throw(error(syntax_error(expected_comma_or_close_paren), BadTok)) }
    ).

% List contents inside [ ... ]
parse_list_contents(_OpTable, [], V, V) -->
    [CloseTok], { token_type(CloseTok, close_list) }, !.
parse_list_contents(OpTable, [Elem|Tail], V0, VOut) -->
    parse_term(OpTable, 999, Elem, _, V0, V1),
    parse_list_rest(OpTable, Tail, V1, VOut).

parse_list_rest(OpTable, [Elem|Tail], V0, VOut) -->
    [CommaTok], { token_type(CommaTok, comma) }, !,
    parse_term(OpTable, 999, Elem, _, V0, V1),
    parse_list_rest(OpTable, Tail, V1, VOut).
parse_list_rest(OpTable, Tail, V0, VOut) -->
    [BarTok], { token_type(BarTok, bar) }, !,
    parse_term(OpTable, 999, Tail, _, V0, V1),
    [CloseTok],
    { token_type(CloseTok, close_list) -> VOut = V1
    ; throw(error(syntax_error(expected_closing_bracket), CloseTok))
    }.
parse_list_rest(_OpTable, [], V, V) -->
    [CloseTok], { token_type(CloseTok, close_list) }, !.

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
    { token_type(EndTok, end) ->
        token_span(EndTok, EndSpan),
        combine_token_spans(StartSpan, EndSpan, StatementSpan),
        var_state_bindings(VFinal, VarNames, Variables, Singletons),
        build_statement(Term, StatementSpan, VarNames, Variables, Singletons, Options, Statement),
        update_optable_if_op_decl(Term, OpTable0, OpTableOut)
    ; throw(error(syntax_error(expected_full_stop_end), EndTok))
    }.

combine_token_spans(none, _, none) :- !.
combine_token_spans(_, none, none) :- !.
combine_token_spans(span(Start, _), span(_, End), span(Start, End)).

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
    (   nonvar(Term), Term = (:- Goal) ->
        Statement = directive(Goal, Meta)
    ;   nonvar(Term), Term = (?- Goal) ->
        Statement = query(Goal, Meta)
    ;   Statement = clause(Term, Meta)
    ),
    apply_term_options(Options, VarNames, Variables, Singletons).

extract_file_line(span(pos(Line, _, _, File), _), File, Line) :- !.
extract_file_line(_, unknown, 0).

apply_term_options([], _, _, _).
apply_term_options([Opt|Opts], VNs, Vs, Sing) :-
    (   Opt = variable_names(VNsOut) -> VNsOut = VNs
    ;   Opt = variables(VsOut) -> VsOut = Vs
    ;   Opt = singletons(SingOut) -> SingOut = Sing
    ;   true
    ),
    apply_term_options(Opts, VNs, Vs, Sing).

update_optable_if_op_decl(Term, OpTable0, OpTableOut) :-
    (   nonvar(Term), Term = (:- op(Prec, Spec, Op)) ->
        add_operator(OpTable0, Prec, Spec, Op, OpTableOut)
    ;   nonvar(Term), Term = (:- module(_, Exports)) ->
        import_exported_ops(Exports, OpTable0, OpTableOut)
    ;   OpTableOut = OpTable0
    ).

import_exported_ops([], T, T).
import_exported_ops([op(P, S, O)|Rest], T0, TOut) :- !,
    add_operator(T0, P, S, O, T1),
    import_exported_ops(Rest, T1, TOut).
import_exported_ops([_|Rest], T0, TOut) :-
    import_exported_ops(Rest, T0, TOut).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Program Parsing (Sequence of Statements until EOF)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_program(OpTable, Statements, FinalOpTable) -->
    parse_program(OpTable, [], Statements, FinalOpTable).

parse_program(OpTable, _Options, [], OpTable) --> [].
parse_program(OpTable0, Options, [Stmt|Stmts], FinalOpTable) -->
    parse_clause(OpTable0, Options, Stmt, OpTable1),
    parse_program(OpTable1, Options, Stmts, FinalOpTable).
