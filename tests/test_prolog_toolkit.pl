:- module(test_prolog_toolkit, [
    run/0
]).

:- use_module(library(format)).
:- use_module(library(charsio)).
:- use_module(library(dif)).
:- use_module(library(si)).
:- use_module('../src/prolog_toolkit').
:- use_module(testing).

test("version string is list of chars", (
    prolog_toolkit_version(V),
    list_si(V),
    V = "0.1.0.dev1"
)).

test("parse simple term via parser_experiments pipeline", (
    default_stream_parse("test_src", "hello(world).", AST),
    nonvar(AST)
)).

test("tokenize simple term via parser_experiments pipeline", (
    default_pipeline_tokens("test_src", "foo(123).", Tokens),
    nonvar(Tokens)
)).

test("tokenize via native ISO lexer", (
    tokenize([], "parent(alice, bob).", Tokens),
    Tokens = [atom("parent", _), open_ct(_), atom("alice", _), comma(_), atom("bob", _), close(_), end(_)],
    token_value(atom("parent", _), "parent"),
    token_type(open_ct(_), open_ct)
)).

test("clause_tokens via native ISO lexer", (
    clause_tokens([], Tokens, "fact. rule :- body.", Rest),
    Tokens = [atom("fact", _), end(_)],
    dif(Rest, [])
)).

test("tokenize via phrase(tokens(Tokens), Chars)", (
    phrase(tokens(Tokens), "member(X, [1, 2])."),
    Tokens = [atom("member", _), open_ct(_), var("X", _), comma(_), open_list(_), integer(1, _), comma(_), integer(2, _), close_list(_), close(_), end(_)]
)).

test("lazy stream via phrase(lazy_tokens(Tokens), Chars)", (
    phrase(lazy_tokens(Tokens), "a b c."),
    Tokens = [atom("a", _)|_]
)).

test("unlifted tokens via phrase(unlifted_tokens(Tokens), Chars)", (
    phrase(unlifted_tokens(Tokens), "foo(X, 42)."),
    Tokens = [atom("foo"), open_ct, var("X"), comma, integer(42), close, end],
    token_type(atom("foo"), atom),
    token_value(atom("foo"), "foo"),
    token_type(open_ct, open_ct),
    token_value(integer(42), 42)
)).

test("lifted tokens via phrase(lifted_tokens(Tokens), Chars)", (
    phrase(lifted_tokens(Tokens), "foo(X, 42)."),
    Tokens = [atom("foo", _), open_ct(_), var("X", _), comma(_), integer(42, _), close(_), end(_)],
    token_type(atom("foo", _), atom),
    token_value(atom("foo", _), "foo"),
    token_type(open_ct(_), open_ct),
    token_value(integer(42, _), 42)
)).

test("unlifted and lifted token conversion round-trip", (
    phrase(lifted_tokens(Tokens), "bar(1)."),
    Tokens = [BarLifted, OpenCtLifted, OneLifted, CloseLifted, EndLifted],
    unlift_token(BarLifted, atom("bar")),
    unlift_token(OpenCtLifted, open_ct),
    unlift_token(OneLifted, integer(1)),
    unlift_token(CloseLifted, close),
    unlift_token(EndLifted, end),
    token_span(BarLifted, Span),
    lift_token(atom("bar"), Span, BarLifted)
)).

test("unlifted_tokenize convenience wrapper", (
    unlifted_tokenize("baz.", [atom("baz"), end])
)).

test("canonical prolog_* lexer predicates", (
    prolog_tokenize([], "parent(alice, bob).", Tokens),
    Tokens = [atom("parent", _), open_ct(_), atom("alice", _), comma(_), atom("bob", _), close(_), end(_)],
    prolog_token_value(atom("parent", _), "parent"),
    prolog_token_type(open_ct(_), open_ct),
    prolog_clause_tokens([], ClauseToks, "a. b.", Rest),
    ClauseToks = [atom("a", _), end(_)],
    dif(Rest, []),
    phrase(prolog_tokens(_Toks), "x + 1."),
    phrase(prolog_lazy_tokens(LazyToks), "y - 2."),
    LazyToks = [atom("y", _)|_],
    phrase(prolog_unlifted_tokens(UnliftedToks), "z."),
    UnliftedToks = [atom("z"), end],
    prolog_unlifted_tokenize("ok.", [atom("ok"), end])
)).

test("canonical prolog_* parser and operator table predicates", (
    prolog_default_operator_table(OpTable),
    prolog_is_operator(OpTable, ":-", 1200, xfx),
    phrase(prolog_tokens(Tokens), "member(X, [1, 2])."),
    phrase(prolog_parse_clause(OpTable, Stmt, _), Tokens),
    Stmt = clause(member(_X, [1, 2]), _)
)).

run :-
    run_tests,
    halt.

:- initialization(run).
