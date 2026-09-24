/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Term I/O (read_term, read_term_ex, write_canonical)

   Pure ISO Prolog term input/output and extended provenance-tracking term reading:
   - iso_read_term/2,3 & prolog_read_term/2,3
   - read_term_ex/2,3,4 & prolog_read_term_ex/2,3,4
   - read_term_ex_from_chars/2,3,4 & prolog_read_term_ex_from_chars/2,3,4
   - write_canonical/1,2 & term_to_canonical_chars/2
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(term_io, [
    % ISO-compatible read_term
    iso_read_term/2,
    iso_read_term/3,
    prolog_read_term/2,
    prolog_read_term/3,
    iso_read_term_from_chars/2,
    iso_read_term_from_chars/3,
    prolog_read_term_from_chars/2,
    prolog_read_term_from_chars/3,

    % Extended read_term with provenance & attributed variables
    read_term_ex/2,
    read_term_ex/3,
    read_term_ex/4,
    prolog_read_term_ex/2,
    prolog_read_term_ex/3,
    prolog_read_term_ex/4,
    read_term_ex_from_chars/2,
    read_term_ex_from_chars/3,
    read_term_ex_from_chars/4,
    prolog_read_term_ex_from_chars/2,
    prolog_read_term_ex_from_chars/3,
    prolog_read_term_ex_from_chars/4,

    % Canonical term serialization
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
:- use_module(prolog_lifted_lexer).
:- use_module(prolog_operator_table).
:- use_module(prolog_parser).
:- use_module(prolog_expander).
:- use_module(prolog_provenance).
:- use_module('../../parser_experiments/src/annotate_position', [
    span_start/2,
    span_end/2,
    combine_spans/3
]).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   read_term_from_chars/2,3 (ISO Mode)
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

prolog_read_term_from_chars(Chars, Term) :-
    iso_read_term_from_chars(Chars, Term, []).

prolog_read_term_from_chars(Chars, Term, Options) :-
    iso_read_term_from_chars(Chars, Term, Options).

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
    (   phrase(parse_term(OpT, 1200, Term, _, V0, VFinal), Tokens, TokensRest) ->
        verify_tokens_rest(TokensRest),
        var_state_bindings(VFinal, VarNames, Variables, Singletons),
        apply_term_options(Options, VarNames, Variables, Singletons)
    ;   lookup_option(Options, syntax_errors, error, SyntaxOpt),
        if_(SyntaxOpt = error,
            throw(error(syntax_error(failed_to_parse_term), Options)),
            fail
        )
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
   iso_read_term/2,3 & prolog_read_term/2,3
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% iso_read_term(?Arg1, ?Arg2)
%  Supports both:
%    iso_read_term(-Term, +Options)  [reads from current_input]
%    iso_read_term(+Stream, -Term)   [empty options]
iso_read_term(Arg1, Arg2) :-
    (   list_si(Arg2) ->
        current_input(Stream),
        iso_read_term(Stream, Arg1, Arg2)
    ;   iso_read_term(Arg1, Arg2, [])
    ).

%% iso_read_term(+Stream, -Term, +Options)
iso_read_term(Stream, Term, Options) :-
    read_statement_chars(Stream, Chars),
    if_(Chars = [],
        ( Term = end_of_file, apply_empty_options(Options) ),
        iso_read_term_from_chars(Chars, Term, Options)
    ).

prolog_read_term(Arg1, Arg2) :-
    iso_read_term(Arg1, Arg2).

prolog_read_term(Stream, Term, Options) :-
    iso_read_term(Stream, Term, Options).

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
   read_term_ex/2,3,4 & read_term_ex_from_chars/2,3,4
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% read_term_ex(-Term, +Options)
read_term_ex(Term, Options) :-
    current_input(Stream),
    read_term_ex(Stream, Term, Options).

%% read_term_ex(+Stream, -Term, +Options)
read_term_ex(Stream, Term, Options) :-
    lookup_option(Options, source, stream(Stream), Source),
    read_term_ex(Source, Stream, Term, Options).

%% read_term_ex(+Source, +Stream, -Term, +Options)
read_term_ex(Source, Stream, Term, Options) :-
    read_statement_chars(Stream, Chars),
    if_(Chars = [],
        handle_empty_ex(Source, Term, Options),
        read_term_ex_from_chars(Source, Chars, Term, Options)
    ).

prolog_read_term_ex(Term, Options) :-
    read_term_ex(Term, Options).
prolog_read_term_ex(Stream, Term, Options) :-
    read_term_ex(Stream, Term, Options).
prolog_read_term_ex(Source, Stream, Term, Options) :-
    read_term_ex(Source, Stream, Term, Options).

%% read_term_ex_from_chars(+Chars, -Term)
read_term_ex_from_chars(Chars, Term) :-
    read_term_ex_from_chars(chars, Chars, Term, []).

read_term_ex_from_chars(Arg1, Arg2, Arg3) :-
    (   list_si(Arg3) ->
        lookup_option(Arg3, source, chars, Source),
        read_term_ex_from_chars(Source, Arg1, Arg2, Arg3)
    ;   read_term_ex_from_chars(Arg1, Arg2, Arg3, [])
    ).

%% read_term_ex_from_chars(+Source, +Chars, -Term, +Options)
read_term_ex_from_chars(Source, Chars, TermOut, Options) :-
    if_(Chars = [],
        handle_empty_ex(Source, TermOut, Options),
        ( phrase(lifted_tokens([source(Source)|Options], Tokens), Chars),
          if_(Tokens = [],
              handle_empty_ex(Source, TermOut, Options),
              parse_tokens_to_term_ex(Tokens, Source, TermOut, Options)
          )
        )
    ).

prolog_read_term_ex_from_chars(Chars, Term) :-
    read_term_ex_from_chars(Chars, Term).
prolog_read_term_ex_from_chars(Arg1, Arg2, Arg3) :-
    read_term_ex_from_chars(Arg1, Arg2, Arg3).
prolog_read_term_ex_from_chars(Source, Chars, Term, Options) :-
    read_term_ex_from_chars(Source, Chars, Term, Options).

handle_empty_ex(Source, TermOut, Options) :-
    ZeroPos = pos(1, 1, 0, Source),
    ZeroSpan = span(ZeroPos, ZeroPos),
    create_term_provenance_var(Source, ZeroSpan, source_term(end_of_file), TermProvVar),
    unify_term_result(end_of_file, TermProvVar, TermOut),
    apply_empty_options(Options),
    apply_empty_options_ex(Options, TermProvVar).

unify_term_result(Term, TermProvVar, TermOut) :-
    (   nonvar(TermOut), TermOut = term_ex(T, P) ->
        T = Term, P = TermProvVar
    ;   TermOut = Term
    ).

apply_empty_options_ex([], _).
apply_empty_options_ex([Opt|Opts], TermProvVar) :-
    if_(Opt = term_provenance(ProvOut),
        ProvOut = TermProvVar,
        if_(Opt = tokens(ToksOut),
            ToksOut = [],
            if_(Opt = token_attributed_variables(VarsOut),
                VarsOut = [],
                true
            )
        )
    ),
    apply_empty_options_ex(Opts, TermProvVar).

parse_tokens_to_term_ex(Tokens, Source, TermOut, Options) :-
    default_operator_table(DefaultOpT),
    lookup_option(Options, operator_table, DefaultOpT, OpT),
    initial_var_state(V0),

    % 1. Annotate tokens with provenance attributed variables
    tokens_annotate_provenance(Tokens, Source, AnnotatedTokens),
    extract_token_attributed_vars(AnnotatedTokens, TokenAttrVars),

    % 2. Compute overall term span from tokens
    compute_term_span(Tokens, Source, TermSpan),

    % 3. Parse term using Pratt precedence climbing
    (   phrase(parse_term(OpT, 1200, RawTerm, _, V0, VFinal), Tokens, TokensRest) ->
        verify_tokens_rest(TokensRest),
        var_state_bindings_ex(VFinal, VarNames, Variables, Singletons, VarDetails),

        % 4. Attach variable provenance if enabled (default true in read_term_ex)
        lookup_option(Options, variables_provenance, true, VarProvEnabled),
        if_(VarProvEnabled = true,
            attach_variables_provenance(VarDetails, Source, Options),
            true
        ),

        % 5. Handle macro expansion if requested
        lookup_option(Options, expand, none, ExpandMode),
        if_(ExpandMode = none,
            ( FinalTerm = RawTerm,
              ExpansionInfo = source_term(RawTerm)
            ),
            ( lookup_option(Options, expander_options, [expand_mode(ExpandMode)], ExpOptions),
              prolog_initial_expander_state(ExpOptions, ExpState0),
              prolog_expand_term_lineage(ExpOptions, RawTerm, ExpandedTerms, MacrosUsed, ExpState0, _),
              if_(ExpandedTerms = [SingleTerm],
                  FinalTerm = SingleTerm,
                  FinalTerm = ExpandedTerms
              ),
              if_(MacrosUsed = [],
                  ExpansionInfo = source_term(RawTerm),
                  ExpansionInfo = expanded(RawTerm, MacrosUsed)
              )
            )
        ),

        % 6. Create term provenance attributed variable
        create_term_provenance_var(Source, TermSpan, ExpansionInfo, TermProvVar),

        % 7. Unify Term result (supports term_ex(Term, Prov) or plain Term)
        unify_term_result(FinalTerm, TermProvVar, TermOut),

        % 8. Apply options
        apply_term_options(Options, VarNames, Variables, Singletons),
        apply_term_options_ex(Options, TermProvVar, AnnotatedTokens, Tokens, TokenAttrVars, TermSpan)
    ;   % Parse failure handling
        lookup_option(Options, syntax_errors, error, SyntaxOpt),
        if_(SyntaxOpt = error,
            throw(error(syntax_error(failed_to_parse_term), Options)),
            fail
        )
    ).

compute_term_span([FirstTok|Rest], _Source, Span) :-
    token_span(FirstTok, FirstSpan),
    last_token_span([FirstTok|Rest], LastSpan),
    combine_spans(FirstSpan, LastSpan, Span).
compute_term_span([], Source, span(pos(1, 1, 0, Source), pos(1, 1, 0, Source))).

last_token_span([Tok], Span) :-
    !,
    token_span(Tok, Span).
last_token_span([Tok1, Tok2|Rest], Span) :-
    token_type(Tok2, Type),
    if_(Type = end,
        token_span(Tok1, Span),
        last_token_span([Tok2|Rest], Span)
    ).

extract_token_attributed_vars([], []).
extract_token_attributed_vars([token_ex(_, _, _, _, AttrVar)|Rest], [AttrVar|VarsRest]) :-
    extract_token_attributed_vars(Rest, VarsRest).

apply_term_options_ex([], _, _, _, _, _).
apply_term_options_ex([Opt|Opts], TermProvVar, AnnotatedToks, RawToks, TokenAttrVars, TermSpan) :-
    if_(Opt = term_provenance(ProvOut),
        ProvOut = TermProvVar,
        if_(Opt = tokens(ToksOut),
            ToksOut = AnnotatedToks,
            if_(Opt = raw_tokens(RawToksOut),
                RawToksOut = RawToks,
                if_(Opt = token_attributed_variables(VarsOut),
                    VarsOut = TokenAttrVars,
                    if_(Opt = term_position(PosOut),
                        PosOut = TermSpan,
                        if_(Opt = subterm_positions(SubtermPosOut),
                            SubtermPosOut = TermSpan,
                            true
                        )
                    )
                )
            )
        )
    ),
    apply_term_options_ex(Opts, TermProvVar, AnnotatedToks, RawToks, TokenAttrVars, TermSpan).

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
