:- module(test_scryer_lib, [
    run/0
]).

:- use_module(library(atts)).
:- op(1199, fx, attribute).
:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(iso_ext), [maplist/3]).
:- use_module(library(lists)).
:- use_module(library(terms)).
:- use_module('../src/prolog_token').
:- use_module('../src/prolog_lexer').
:- use_module('../src/prolog_operator_table').
:- use_module('../src/prolog_parser').
:- use_module(testing).

native_read_all(Stream, Terms) :-
    catch(read_term(Stream, Term, []), Error, (format("Native read error: ~q~n", [Error]), Term = error_reading)),
    (   Term == end_of_file ->
        Terms = []
    ;   Term == error_reading ->
        fail
    ;   Terms = [Term|Rest],
        native_read_all(Stream, Rest)
    ).

our_read_all(FilePath, OpTable0, Terms) :-
    open(FilePath, read, Stream),
    get_n_chars(Stream, 200000, Chars),
    close(Stream),
    phrase(tokens(Tokens), Chars), !,
    parse_our_statements(Tokens, OpTable0, Terms), !.

parse_our_statements([], _, []).
parse_our_statements([Tok], _, []) :-
    token_type(Tok, end), !.
parse_our_statements(Tokens, OpTable0, [Term|TermsRest]) :-
    phrase(parse_clause(OpTable0, Stmt, OpTable1), Tokens, TokensRest), !,
    statement_raw_term(Stmt, Term),
    parse_our_statements(TokensRest, OpTable1, TermsRest).

statement_raw_term(directive(G, _), (:- G)) :- !.
statement_raw_term(query(G, _), (?- G)) :- !.
statement_raw_term(clause(C, _), C) :- !.

assert_isomorphic_terms([], []).
assert_isomorphic_terms([T1|R1], [T2|R2]) :-
    copy_term(T1, C1),
    copy_term(T2, C2),
    numbervars(C1, 0, _),
    numbervars(C2, 0, _),
    C1 == C2,
    assert_isomorphic_terms(R1, R2).

test_isomorphic_file(FilePath, OpTable) :-
    open(FilePath, read, S),
    native_read_all(S, NativeTerms),
    close(S),
    our_read_all(FilePath, OpTable, OurTerms), !,
    length(NativeTerms, N1),
    length(OurTerms, N2),
    (   N1 = N2 ->
        true
    ;   format("Length mismatch for ~s: Native ~d vs Ours ~d~n", [FilePath, N1, N2]),
        fail
    ),
    assert_isomorphic_terms(NativeTerms, OurTerms), !.

test("isomorphism with Scryer native parser: terms.pl", (
    default_operator_table(OpT),
    test_isomorphic_file("reference/scryer-prolog/src/lib/terms.pl", OpT)
)).

test("isomorphism with Scryer native parser: assoc.pl", (
    default_operator_table(OpT),
    test_isomorphic_file("reference/scryer-prolog/src/lib/assoc.pl", OpT)
)).

test("isomorphism with Scryer native parser: lists.pl", (
    default_operator_table(OpT),
    test_isomorphic_file("reference/scryer-prolog/src/lib/lists.pl", OpT)
)).

test("isomorphism with Scryer native parser: http/http_open.pl", (
    default_operator_table(OpT),
    test_isomorphic_file("reference/scryer-prolog/src/lib/http/http_open.pl", OpT)
)).

test("isomorphism with Scryer native parser: dcgs.pl", (
    default_operator_table(OpT),
    test_isomorphic_file("reference/scryer-prolog/src/lib/dcgs.pl", OpT)
)).

test("isomorphism with Scryer native parser: dif.pl", (
    default_operator_table(OpT0),
    add_operator(OpT0, 1199, fx, "attribute", OpT),
    test_isomorphic_file("reference/scryer-prolog/src/lib/dif.pl", OpT)
)).

run :-
    run_tests,
    exit_test_process.

:- initialization(run).
