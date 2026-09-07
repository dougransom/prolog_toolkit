/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Term I/O (read_term, write_canonical)

   Pure ISO Prolog term input/output:
   - read_term/2,3 with variables, variable_names, and singletons options
   - read_term_from_chars/2,3
   - write_canonical/1,2
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(term_io, [
    iso_read_term/2,
    iso_read_term/3,
    iso_read_term_from_chars/2,
    iso_read_term_from_chars/3,
    iso_write_canonical/1,
    iso_write_canonical/2,
    term_to_canonical_chars/2
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(token).
:- use_module(lexer).
:- use_module(operator_table).
:- use_module(iso_parser).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   read_term_from_chars/2,3
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% iso_read_term_from_chars(+Chars, -Term)
iso_read_term_from_chars(Chars, Term) :-
    iso_read_term_from_chars(Chars, Term, []).

%% iso_read_term_from_chars(+Chars, -Term, +Options)
iso_read_term_from_chars(Chars, Term, Options) :-
    if_(Chars = [],
        ( Term = end_of_file,
          apply_empty_options(Options)
        ),
        ( phrase(tokens(Tokens), Chars),
          if_(Tokens = [],
              ( Term = end_of_file, apply_empty_options(Options) ),
              parse_tokens_to_term(Tokens, Term, Options)
          )
        )
    ).

apply_empty_options([]).
apply_empty_options([Opt|Opts]) :-
    (   Opt = variable_names(VNs) -> VNs = []
    ;   Opt = variables(Vs) -> Vs = []
    ;   Opt = singletons(S) -> S = []
    ;   true
    ),
    apply_empty_options(Opts).

parse_tokens_to_term(Tokens, Term, Options) :-
    (   member(operator_table(OpT), Options) -> true
    ;   default_operator_table(OpT)
    ),
    initial_var_state(V0),
    (   phrase(parse_term(OpT, 1200, Term, _, V0, VFinal), Tokens, TokensRest) ->
        (   TokensRest = [EndTok|_] ->
            ( token_type(EndTok, end) -> true
            ; throw(error(syntax_error(unexpected_token_after_term), EndTok))
            )
        ;   TokensRest = [] -> true
        ;   TokensRest = [BadTok|_],
            throw(error(syntax_error(unexpected_token_after_term), BadTok))
        ),
        var_state_bindings(VFinal, VarNames, Variables, Singletons),
        apply_term_options(Options, VarNames, Variables, Singletons)
    ;   throw(error(syntax_error(failed_to_parse_term), Options))
    ).

apply_term_options([], _, _, _).
apply_term_options([Opt|Opts], VNs, Vs, Sing) :-
    (   Opt = variable_names(VNsOut) -> VNsOut = VNs
    ;   Opt = variables(VsOut) -> VsOut = Vs
    ;   Opt = singletons(SingOut) -> SingOut = Sing
    ;   true
    ),
    apply_term_options(Opts, VNs, Vs, Sing).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   iso_read_term/2,3
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% iso_read_term(+Stream, -Term)
iso_read_term(Stream, Term) :-
    iso_read_term(Stream, Term, []).

%% iso_read_term(+Stream, -Term, +Options)
iso_read_term(Stream, Term, Options) :-
    read_statement_chars(Stream, Chars),
    if_(Chars = [],
        ( Term = end_of_file, apply_empty_options(Options) ),
        iso_read_term_from_chars(Chars, Term, Options)
    ).

read_statement_chars(Stream, Chars) :-
    get_char(Stream, C),
    (   C == end_of_file ->
        Chars = []
    ;   read_statement_chars_rest(C, Stream, Chars)
    ).

read_statement_chars_rest('.', Stream, ['.']) :-
    % Peek next char to see if full stop
    peek_char(Stream, NextC),
    ( NextC == end_of_file ; char_type(NextC, whitespace) ), !.
read_statement_chars_rest(C, Stream, [C|Cs]) :-
    get_char(Stream, NextC),
    (   NextC == end_of_file ->
        Cs = []
    ;   read_statement_chars_rest(NextC, Stream, Cs)
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   iso_write_canonical/1,2 & term_to_canonical_chars/2
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% iso_write_canonical(+Term)
iso_write_canonical(Term) :-
    term_to_canonical_chars(Term, Chars),
    format("~s", [Chars]).

%% iso_write_canonical(+Stream, +Term)
iso_write_canonical(Stream, Term) :-
    term_to_canonical_chars(Term, Chars),
    format(Stream, "~s", [Chars]).

%% term_to_canonical_chars(+Term, -Chars)
term_to_canonical_chars(Term, Chars) :-
    phrase(canonical_term(Term), Chars).

canonical_term(Var) -->
    { var(Var) }, !,
    format_("~q", [Var]).
canonical_term(Int) -->
    { integer(Int) }, !,
    format_("~d", [Int]).
canonical_term(Float) -->
    { float(Float) }, !,
    format_("~w", [Float]).
canonical_term([]) --> !,
    "[]".
canonical_term([Head|Tail]) --> !,
    ".(",
    canonical_term(Head),
    ",",
    canonical_term(Tail),
    ")".
canonical_term(Atom) -->
    { atom(Atom) }, !,
    canonical_atom(Atom).
canonical_term(Compound) -->
    { functor(Compound, Functor, _Arity),
      Compound =.. [Functor|Args]
    },
    canonical_atom(Functor),
    "(",
    canonical_args(Args),
    ")".

canonical_args([]) --> [].
canonical_args([Arg]) --> !,
    canonical_term(Arg).
canonical_args([Arg1, Arg2|Rest]) -->
    canonical_term(Arg1),
    ",",
    canonical_args([Arg2|Rest]).

canonical_atom(Atom) -->
    { atom_chars(Atom, Chars) },
    (   { needs_quoting(Chars) } ->
        format_("~q", [Atom])
    ;   format_("~s", [Chars])
    ).

needs_quoting([]) :- !.
needs_quoting([C|Cs]) :-
    (   char_type(C, lower) ->
        \+ all_alphanumeric_or_underscore(Cs)
    ;   true
    ).

all_alphanumeric_or_underscore([]).
all_alphanumeric_or_underscore([C|Cs]) :-
    ( char_type(C, alphanumeric) ; C = '_' ),
    all_alphanumeric_or_underscore(Cs).
