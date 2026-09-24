/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Unit Tests: Reactive Attributed AST Engine
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- use_module(library(format)).
:- use_module(library(lists)).

:- use_module('../src/prolog_reactive_ast').
:- use_module(testing).

run_test(Name, Goal) :-
    (   catch(Goal, E, (format("FAIL: ~s (exception: ~w)~n", [Name, E]), fail)) ->
        format("OK: ~s~n", [Name])
    ;   format("FAIL: ~s~n", [Name]),
        halt(1)
    ).

% 1. Immediate resolution when dependencies are already ready
test_immediate_resolution :-
    lazy_ast_node(Leaf1, [10], literal, [id(l1)]),
    lazy_ast_node(Leaf2, [20], literal, [id(l2)]),
    lazy_ast_node(Root, [Leaf1, Leaf2], infix(+), [id(root)]),
    % Root should immediately be concrete term: ast_node(ast_node(10, _)+ast_node(20, _), _)
    nonvar(Root),
    Root = ast_node(ast_node(10, [id(l1)]) + ast_node(20, [id(l2)]), [id(root)]).

% 2. Out-of-order resolution across multi-level tree
test_lazy_out_of_order_resolution :-
    % Root: Left + Right
    lazy_ast_node(Root, [Left, Right], infix(+), [id(root)]),
    is_lazy_ast_node(Root),
    ast_node_status(Root, lazy),

    % Left: A * B
    lazy_ast_node(Left, [A, B], infix(*), [id(left)]),
    is_lazy_ast_node(Left),

    % Right is bound first (out of order)
    lazy_ast_node(Right, [100], literal, [id(r)]),
    nonvar(Right),
    % Root still waiting on Left
    is_lazy_ast_node(Root),

    % Now bind B in Left
    lazy_ast_node(B, [3], literal, [id(b)]),
    nonvar(B),
    % Left still waiting on A
    is_lazy_ast_node(Left),
    is_lazy_ast_node(Root),

    % Finally bind A in Left -> triggers cascade: Left resolves, which resolves Root!
    lazy_ast_node(A, [2], literal, [id(a)]),
    nonvar(A),
    nonvar(Left),
    nonvar(Root),
    Root = ast_node(ast_node(ast_node(2, [id(a)]) * ast_node(3, [id(b)]), [id(left)]) + ast_node(100, [id(r)]), [id(root)]).

% 3. Program variables (free logical variables) are preserved in ASTs
test_program_variables_in_ast :-
    % In source: foo(X, 42). X is a free logical variable in an AST leaf node.
    lazy_ast_node(Arg1, [], var_leaf(ProgVar), [name("X")]),
    lazy_ast_node(Arg2, [42], literal, [id(lit42)]),
    lazy_ast_node(Call, [Arg1, Arg2], compound(foo), [id(call)]),
    % Call resolves immediately because both Arg1 and Arg2 are ready AST terms
    nonvar(Call),
    Call = ast_node(foo(ast_node(ProgVar, [type(var), name("X")]), ast_node(42, [id(lit42)])), [id(call)]),
    % ProgVar remains an unbound logical variable
    var(ProgVar).

% 4. Multi-level 4-stage cascading resolution
test_multi_level_cascade :-
    lazy_ast_node(N4, [N3], prefix(-), [level(4)]),
    lazy_ast_node(N3, [N2], prefix(-), [level(3)]),
    lazy_ast_node(N2, [N1], prefix(-), [level(2)]),
    lazy_ast_node(N1, [Leaf], literal, [level(1)]),
    is_lazy_ast_node(N4),
    is_lazy_ast_node(N3),
    is_lazy_ast_node(N2),
    is_lazy_ast_node(N1),
    % Binding the leaf unifies Leaf and cascades all 4 levels automatically!
    Leaf = 42,
    nonvar(N1),
    nonvar(N2),
    nonvar(N3),
    nonvar(N4),
    N4 = ast_node(- ast_node(- ast_node(- ast_node(42, [level(1)]), [level(2)]), [level(3)]), [level(4)]).

% 5. Span metadata merging across children
test_metadata_and_span_merging :-
    lazy_ast_node(Left, [1], literal, [span(pos(1, 1, 0, file("a.pl")), pos(1, 2, 1, file("a.pl")))]),
    lazy_ast_node(Right, [2], literal, [span(pos(1, 5, 4, file("a.pl")), pos(1, 6, 5, file("a.pl")))]),
    lazy_ast_node(Root, [Left, Right], infix(+), [rule(add)]),
    nonvar(Root),
    Root = ast_node(_, Meta),
    member(span(pos(1, 1, 0, file("a.pl")), pos(1, 6, 5, file("a.pl"))), Meta),
    member(rule(add), Meta).

% 6. Lazy node variable aliasing & merging
test_variable_aliasing_and_unification :-
    lazy_ast_node(Node1, [X], prefix(\+), [meta(1)]),
    lazy_ast_node(Node2, [Y], prefix(\+), [meta(2)]),
    % Unify the two lazy node variables
    Node1 = Node2,
    is_lazy_ast_node(Node1),
    ast_node_metadata(Node1, Meta),
    member(meta(1), Meta),
    member(meta(2), Meta),
    % Now bind X and Y
    X = true,
    Y = true,
    resolve_ast_node(Node1),
    nonvar(Node1).

% 7. Rational tree (cycle) compatibility
test_rational_tree_compatibility :-
    % Construct a cyclic lazy node: Node depends on itself
    lazy_ast_node(CycleNode, [CycleNode], compound(cycle), [id(cycle)]),
    is_lazy_ast_node(CycleNode),
    % Scryer handles rational trees without infinite recursion:
    CycleNode = ast_node(cycle(CycleNode), [id(cycle)]),
    nonvar(CycleNode).

% 8. Reactive semantic action: constant folding and type inference
fold_arithmetic(infix(+), [ast_node(L, _), ast_node(R, _)], NewMeta) :-
    (   integer(L), integer(R) ->
        Val is L + R,
        NewMeta = [inferred_type(integer), folded(Val)]
    ;   NewMeta = [inferred_type(number)]
    ).

test_reactive_semantic_action :-
    lazy_ast_node(Left, [10], literal, [type(integer)]),
    lazy_ast_node(Right, [RVal], literal, [type(integer)]),
    lazy_ast_node(AddNode, [Left, Right], infix(+), [semantic_action(user:fold_arithmetic)]),
    is_lazy_ast_node(AddNode),
    % Now bind RVal = 32 -> triggers semantic action reactively!
    RVal = 32,
    nonvar(AddNode),
    AddNode = ast_node(_, Meta),
    member(folded(42), Meta),
    member(inferred_type(integer), Meta).

main :-
    run_test("immediate_resolution", test_immediate_resolution),
    run_test("lazy_out_of_order_resolution", test_lazy_out_of_order_resolution),
    run_test("program_variables_in_ast", test_program_variables_in_ast),
    run_test("multi_level_cascade", test_multi_level_cascade),
    run_test("metadata_and_span_merging", test_metadata_and_span_merging),
    run_test("variable_aliasing_and_unification", test_variable_aliasing_and_unification),
    run_test("rational_tree_compatibility", test_rational_tree_compatibility),
    run_test("reactive_semantic_action", test_reactive_semantic_action),
    format("All reactive AST tests passed successfully!~n", []),
    exit_test_process.

:- initialization(main).
