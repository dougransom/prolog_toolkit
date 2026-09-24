/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Unit Tests: Reactive Attributed Tokens & Reactive Parser
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- use_module(library(format)).
:- use_module(library(lists)).

:- use_module('../src/prolog_toolkit').
:- use_module(testing).

run_test(Name, Goal) :-
    (   catch(Goal, E, (format("FAIL: ~s (exception: ~w)~n", [Name, E]), fail)) ->
        format("OK: ~s~n", [Name])
    ;   format("FAIL: ~s~n", [Name]),
        halt(1)
    ).

% 1. Attributed Token Scanning
test_scan_attributed_tokens :-
    chars_to_attributed_tokens("calc(X) :- X = 42 + 10.", Toks),
    length(Toks, Len),
    Len > 0,
    % First token must be atom 'calc' with span
    [Tok1|Rest] = Toks,
    get_token_class(Tok1, atom),
    get_token_value(Tok1, [c,a,l,c]),
    get_token_span(Tok1, span(pos(1, 1, 0, _), pos(1, 5, 4, _))),
    % Find '+' operator token and verify its operator metadata
    member(PlusTok, Rest),
    get_token_class(PlusTok, atom),
    get_token_value(PlusTok, "+"),
    get_token_op(PlusTok, op(500, yfx)).

% 2. Parsing a Fact into a Reactive AST Node
test_parse_reactive_fact :-
    reactive_chars_to_ast("likes(john, pizza).", ClauseAST),
    nonvar(ClauseAST),
    ClauseAST = ast_node(ast_node(likes(ast_node(john, _), ast_node(pizza, _)), _), Meta),
    member(clause_type(fact), Meta).

% 3. Parsing Expressions with Infix Precedence: 1 + 2 * 3.
test_parse_reactive_expression_precedence :-
    reactive_chars_to_ast("val(1 + 2 * 3).", ClauseAST),
    nonvar(ClauseAST),
    ClauseAST = ast_node(ast_node(val(ast_node(ast_node(1, _) + ast_node(ast_node(2, _) * ast_node(3, _), _), _)), _), _).

% 4. Parsing Clauses with Variable Sharing
test_parse_reactive_clause_with_variables :-
    reactive_chars_to_ast("ancestor(X, Y) :- parent(X, Z), ancestor(Z, Y).", ClauseAST),
    nonvar(ClauseAST),
    ClauseAST = ast_node((Head :- Body), Meta),
    member(clause_type(rule), Meta),
    % Head: ancestor(X, Y)
    Head = ast_node(ancestor(ast_node(VarX, _), ast_node(VarY, _)), _),
    % Body: (parent(X, Z) , ancestor(Z, Y))
    Body = ast_node((ast_node(parent(ast_node(VarX2, _), ast_node(VarZ, _)), _) ,
                     ast_node(ancestor(ast_node(VarZ2, _), ast_node(VarY2, _)), _)), _),
    % Variables with same name must share the exact same logical variable
    VarX == VarX2,
    VarY == VarY2,
    VarZ == VarZ2,
    % They must be unbound variables
    var(VarX), var(VarY), var(VarZ).

% 5. Parsing List Expressions
test_parse_reactive_list :-
    reactive_chars_to_ast("items([1, 2, 3]).", ClauseAST),
    nonvar(ClauseAST),
    ClauseAST = ast_node(ast_node(items(ast_node('[|]'(ast_node(1, _), _), _)), _), _).

% 6. DCG Rule Parsing
test_parse_reactive_dcg_rule :-
    reactive_chars_to_ast("digit --> \"0\".", ClauseAST),
    nonvar(ClauseAST),
    ClauseAST = ast_node((ast_node(digit, _) --> ast_node("0", _)), Meta),
    member(clause_type(dcg), Meta).

main :-
    run_test("scan_attributed_tokens", test_scan_attributed_tokens),
    run_test("parse_reactive_fact", test_parse_reactive_fact),
    run_test("parse_reactive_expression_precedence", test_parse_reactive_expression_precedence),
    run_test("parse_reactive_clause_with_variables", test_parse_reactive_clause_with_variables),
    run_test("parse_reactive_list", test_parse_reactive_list),
    run_test("parse_reactive_dcg_rule", test_parse_reactive_dcg_rule),
    format("All reactive parser tests passed successfully!~n", []),
    exit_test_process.

:- initialization(main).
