:- module(test_iso_parser, [
    run/0
]).

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(si)).
:- use_module('../src/prolog_toolkit').
:- use_module(testing).

test("parse plain atom and integers", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "point(10, 20)."),
    phrase(parse_clause(OpT, Stmt, _), Toks),
    Stmt = clause(point(10, 20), Meta),
    nonvar(Meta)
)).

test("parse quoted atom and string", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "msg('hello world', \"sample text\")."),
    phrase(parse_clause(OpT, Stmt, _), Toks),
    Stmt = clause(msg('hello world', "sample text"), _)
)).

test("parse solo character atoms cut and semicolon", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "step :- !, (a ; b)."),
    phrase(parse_clause(OpT, Stmt, _), Toks),
    Stmt = clause((step :- !, (a ; b)), _)
)).

test("parse arithmetic precedence and left associativity (yfx)", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "res(1 + 2 * 3, 10 - 4 - 2)."),
    phrase(parse_clause(OpT, Stmt, _), Toks),
    Stmt = clause(res(+(1, *(2, 3)), -(-(10, 4), 2)), _)
)).

test("parse right associativity (xfy) for comma and semicolon", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "goal :- a, b, c."),
    phrase(parse_clause(OpT, Stmt, _), Toks),
    Stmt = clause((goal :- (a, (b, c))), _)
)).

test("parse lists and list tails", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "lists([1, 2, 3], [H|T], [])."),
    phrase(parse_clause(OpT, Stmt, _), Toks),
    Stmt = clause(lists([1, 2, 3], [_H|_T], []), _)
)).

test("parse curly bracket terms", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "dcg_call --> { write(ok) }, [word]."),
    phrase(parse_clause(OpT, Stmt, _), Toks),
    Stmt = clause(-->(dcg_call, ( {}(write(ok)), [word] )), _)
)).

test("parse directives and queries", (
    default_operator_table(OpT),
    phrase(tokens(Toks1), ":- use_module(library(lists))."),
    phrase(parse_clause(OpT, Stmt1, _), Toks1),
    Stmt1 = directive(use_module(library(lists)), _),

    phrase(tokens(Toks2), "?- length(L, 3)."),
    phrase(parse_clause(OpT, Stmt2, _), Toks2),
    Stmt2 = query(length(_L, 3), _)
)).

test("variable tracking: names, singletons, variables", (
    default_operator_table(OpT),
    phrase(tokens(Toks), "foo(X, Y) :- bar(X, Z), Z > 0."),
    phrase(parse_clause(OpT, [variable_names(VNs), singletons(Sing), variables(Vs)], Stmt, _), Toks),
    Stmt = clause((foo(X, Y) :- bar(X, Z), Z > 0), Meta),
    nonvar(Meta),
    VNs = ['X'=X, 'Y'=Y, 'Z'=Z],
    Sing = ['Y'=Y],
    Vs = [X, Y, Z]
)).

test("dynamic operator declaration in program parse", (
    default_operator_table(OpT),
    phrase(tokens(Toks), ":- op(700, xfx, <=>). alpha <=> beta."),
    phrase(parse_program(OpT, Stmts, FinalOpT), Toks),
    Stmts = [directive(op(700, xfx, <=>), _), clause(Term, _)],
    Term =.. ['<=>', alpha, beta],
    is_operator(FinalOpT, '<=>', 700, xfx)
)).

test("term_io: iso_read_term_from_chars and iso_write_canonical", (
    iso_read_term_from_chars("tree(leaf, node(X, [1, 2])).", Term, [variable_names(VNs)]),
    Term = tree(leaf, node(X, [1, 2])),
    VNs = ['X'=X],
    term_to_canonical_chars(Term, Chars),
    Chars = "tree(leaf,node(_A,.(1,.(2,[]))))"
)).

run :-
    run_tests,
    halt.

:- initialization(run).
