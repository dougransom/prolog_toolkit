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

:- use_module(prolog_token).
:- use_module(prolog_lexer).
:- use_module(prolog_operator_table).
:- use_module(prolog_parser).

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
    if_(Opt = variable_names(VNs),
        VNs = [],
        if_(Opt = variables(Vs),
            Vs = [],
            if_(Opt = singletons(S),
                S = [],
                true
            )
        )
    ),
    apply_empty_options(Opts).

parse_tokens_to_term(Tokens, Term, Options) :-
    default_operator_table(DefaultOpT),
    lookup_option(Options, operator_table, DefaultOpT, OpT),
    initial_var_state(V0),
    % Deterministic term parse: commits on first valid term AST and throws syntax error on failure
    (   phrase(parse_term(OpT, 1200, Term, _, V0, VFinal), Tokens, TokensRest) ->
        verify_tokens_rest(TokensRest),
        var_state_bindings(VFinal, VarNames, Variables, Singletons),
        apply_term_options(Options, VarNames, Variables, Singletons)
    ;   throw(error(syntax_error(failed_to_parse_term), Options))
    ).

verify_tokens_rest([]).
verify_tokens_rest([EndTok|_]) :-
    token_type(EndTok, Type),
    if_(Type = end,
        true,
        throw(error(syntax_error(unexpected_token_after_term), EndTok))
    ).

lookup_option([], _, Default, Default).
lookup_option([Opt|Opts], Key, Default, Val) :-
    Opt =.. [K, V],
    if_(K = Key,
        Val = V,
        lookup_option(Opts, Key, Default, Val)
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
    if_(C = end_of_file,
        Chars = [],
        read_statement_chars_rest(C, Stream, Chars)
    ).

% Commit to full stop if followed by whitespace or EOF to cleanly segment statements at the stream boundary.
read_statement_chars_rest('.', Stream, ['.']) :-
    peek_char(Stream, NextC),
    ( NextC == end_of_file ; char_type(NextC, whitespace) ), !.
read_statement_chars_rest(C, Stream, [C|Cs]) :-
    get_char(Stream, NextC),
    if_(NextC = end_of_file,
        Cs = [],
        read_statement_chars_rest(NextC, Stream, Cs)
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
    { integer_si(Int) }, !,
    format_("~d", [Int]).
canonical_term(Float) -->
    { float(Float) }, !,
    format_("~w", [Float]).
canonical_term([]) --> !,
    "[]".
canonical_term([Head|Tail]) --> !,
    "'.'(",
    canonical_term(Head),
    ",",
    canonical_term(Tail),
    ")".
canonical_term(Atom) -->
    { atom_si(Atom) }, !,
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
    { atom_chars(Atom, Chars),
      if_(needs_quoting_t(Chars),
          Fmt = "~q",
          Fmt = "~a") },
    format_(Fmt, [Atom]).

needs_quoting_t([], true).
needs_quoting_t([C|Cs], Truth) :-
    if_(char_type_lower_t(C),
        ( all_alphanumeric_or_underscore_t(Cs, Alnum),
          if_(Alnum = true, Truth = false, Truth = true)
        ),
        Truth = true
    ).

% Wraps non-reified engine builtin char_type/2 into binary truth predicate
char_type_lower_t(C, Truth) :-
    (   char_type(C, lower) ->
        Truth = true
    ;   Truth = false
    ).

all_alphanumeric_or_underscore_t([], true).
all_alphanumeric_or_underscore_t([C|Cs], Truth) :-
    if_(alphanumeric_or_underscore_t(C),
        all_alphanumeric_or_underscore_t(Cs, Truth),
        Truth = false
    ).

% Wraps non-reified engine builtin char_type/2 into binary truth predicate
alphanumeric_or_underscore_t(C, Truth) :-
    if_(C = '_',
        Truth = true,
        (   char_type(C, alphanumeric) ->
            Truth = true
        ;   Truth = false
        )
    ).
