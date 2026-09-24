/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Spike: Incremental Parsing & Reactive AST Hole Patching
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- use_module(library(format)).
:- use_module(library(lists)).

:- use_module('../src/prolog_reactive_parser').
:- use_module('../src/prolog_reactive_ast').
:- use_module('../src/prolog_parser', [prolog_initial_var_state/1]).
:- use_module(testing).

run_test(Name, Goal) :-
    (   catch(Goal, E, (format("FAIL: ~s (exception: ~w)~n", [Name, E]), fail)) ->
        format("OK: ~s~n", [Name])
    ;   format("FAIL: ~s~n", [Name]),
        halt(1)
    ).

% Semantic action: counts total goals in finalized clause body
count_body_goals(rule, [_Head, BodyNode], [total_goals(Count)]) :-
    count_goals_in_body(BodyNode, Count).

count_goals_in_body(ast_node(Term, _), Count) :-
    !,
    count_goals_in_body(Term, Count).
count_goals_in_body((G1, G2), Count) :-
    !,
    count_goals_in_body(G1, C1),
    count_goals_in_body(G2, C2),
    Count is C1 + C2.
count_goals_in_body(_, 1).

% 1. Single Hole Patching with Variable Sharing
test_single_hole_patching :-
    % Outer context: render_widget(ID, Size) :- compute_layout(Size, Bounds), <HOLE>, draw_box(Bounds).
    prolog_initial_var_state(V0),

    % Parse Head: render_widget(ID, Size)
    reactive_parse_subterm("render_widget(ID, Size)", [], V0, HeadNode, V1),

    % Parse Goal 1: compute_layout(Size, Bounds)
    reactive_parse_subterm("compute_layout(Size, Bounds)", [], V1, Goal1Node, V2),

    % Create AST Hole for the middle goal currently being edited by developer
    create_ast_hole(HoleNode, "body_goal_2", [description("User typing here")]),

    % Parse Goal 3: draw_box(Bounds)
    reactive_parse_subterm("draw_box(Bounds)", [], V2, Goal3Node, V3),

    % Build partial body: (Goal1 , (HoleNode , Goal3))
    lazy_ast_node(SubBody, [HoleNode, Goal3Node], infix(','), []),
    lazy_ast_node(BodyNode, [Goal1Node, SubBody], infix(','), []),

    % Build partial rule
    reactive_build_rule(HeadNode, BodyNode, [semantic_action(user:count_body_goals)], RuleAST),

    % VERIFICATION 1: Partial AST state before patching
    is_lazy_ast_node(RuleAST),
    is_lazy_ast_node(BodyNode),
    is_lazy_ast_node(SubBody),
    is_lazy_ast_node(HoleNode),
    ast_node_metadata(HoleNode, HoleMeta),
    member(hole_id("body_goal_2"), HoleMeta),

    % VERIFICATION 2: Patching only the hole
    % Developer finishes typing: "apply_theme(dark, Bounds)"
    % We parse ONLY the 24 characters of the hole within V3 context:
    reactive_parse_subterm("apply_theme(dark, Bounds)", [], V3, PatchedGoalNode, _VFinal),

    % Patch the hole by unification!
    HoleNode = PatchedGoalNode,

    % VERIFICATION 3: Reactive cascade resolution
    % The entire rule AST must now be nonvar and fully resolved!
    nonvar(RuleAST),
    nonvar(BodyNode),
    nonvar(SubBody),

    % RuleAST structure must contain the patched goal in place
    RuleAST = ast_node((Head :- Body), RuleMeta),
    member(clause_type(rule), RuleMeta),
    member(total_goals(3), RuleMeta),

    % Extract variables and verify exact identity sharing across goals:
    % Bounds in compute_layout must be IDENTICAL to Bounds in apply_theme and draw_box
    Head = ast_node(render_widget(ast_node(_ID, _), ast_node(Size, _)), _),
    Body = ast_node((ast_node(compute_layout(ast_node(Size1, _), ast_node(Bounds1, _)), _) ,
                     ast_node((ast_node(apply_theme(ast_node(dark, _), ast_node(Bounds2, _)), _) ,
                               ast_node(draw_box(ast_node(Bounds3, _)), _)), _)), _),

    Size == Size1,
    Bounds1 == Bounds2,
    Bounds2 == Bounds3,
    var(Bounds1), var(Size).

% 2. Multiple Holes with Out-of-Order Patching
test_multi_hole_out_of_order :-
    % pipeline(In, Out) :- <HOLE_1>, <HOLE_2>.
    prolog_initial_var_state(V0),
    reactive_parse_subterm("pipeline(In, Out)", [], V0, HeadNode, V1),

    create_ast_hole(Hole1, "stage_1", [stage(1)]),
    create_ast_hole(Hole2, "stage_2", [stage(2)]),

    lazy_ast_node(BodyNode, [Hole1, Hole2], infix(','), []),
    reactive_build_rule(HeadNode, BodyNode, [], RuleAST),

    is_lazy_ast_node(RuleAST),

    % Patch Hole 2 FIRST
    reactive_parse_subterm("step_b(Mid, Out)", [], V1, Patch2, V2),
    Hole2 = Patch2,

    % RuleAST must STILL be lazy because Hole 1 is still pending
    is_lazy_ast_node(RuleAST),
    is_lazy_ast_node(BodyNode),

    % Now patch Hole 1 SECOND
    reactive_parse_subterm("step_a(In, Mid)", [], V2, Patch1, _),
    Hole1 = Patch1,

    % Now RuleAST must resolve completely!
    nonvar(RuleAST),
    RuleAST = ast_node((_ :- ast_node((ast_node(step_a(ast_node(_In1, _), ast_node(Mid1, _)), _) ,
                                       ast_node(step_b(ast_node(Mid2, _), ast_node(_Out1, _)), _)), _)), _),

    Mid1 == Mid2,
    var(Mid1).

main :-
    run_test("single_hole_patching", test_single_hole_patching),
    run_test("multi_hole_out_of_order", test_multi_hole_out_of_order),
    format("All incremental AST patching spike tests passed successfully!~n", []),
    exit_test_process.

:- initialization(main).
