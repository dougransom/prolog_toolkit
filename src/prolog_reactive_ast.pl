:- module(prolog_reactive_ast, [
    lazy_ast_node/3,
    lazy_ast_node/4,
    is_lazy_ast_node/1,
    ast_node_status/2,
    ast_node_deps/2,
    ast_node_constructor/2,
    ast_node_metadata/2,
    ast_node_subscribers/2,
    resolve_ast_node/1,
    construct_ast_term/4
]).

:- use_module(library(atts)).
:- use_module(library(lists)).
:- use_module(library(si)).

/** <module> Reactive Attributed AST Engine for Prolog

This module implements a reactive Abstract Syntax Tree (AST) construction engine
built on top of Scryer Prolog's attributed variables (library(atts)).

=== Key Ideas ===

1. **AST Nodes as Attributed Variables**:
   Every pending AST node is represented as an unbound logical variable carrying
   an attributed state:
   ==
   ast_node(State, Deps, Constructor, Metadata)
   ==
   - `State`: `lazy` (pending resolution) or `resolved`.
   - `Deps`: A list of child nodes or tokens required to construct the final term.
   - `Constructor`: A declarative descriptor (e.g. `infix(+)`, `compound(foo)`,
     `literal`, `clause(Head, Body)`) defining how the finalized term is assembled.
   - `Metadata`: Association list or open terms holding spans, type annotations,
     token classifications, or semantic action hooks.

2. **Inverted Dependency Tracking (Subscribers)**:
   Variables in `Deps` carry an attribute:
   ==
   ast_subscribers(ListOfParentVars)
   ==
   When a parent node is created, it registers itself in the subscriber list
   of each of its unresolved children.

3. **Dataflow Propagation via `verify_attributes/3`**:
   When any child node unifies with a concrete term (or another variable):
   - The engine's `verify_attributes/3` hook fires deterministically.
   - It iterates through all subscribed parent nodes.
   - Each parent checks if all its dependencies are now ready.
   - When all children are ready, the parent's `Constructor` executes,
     spans are merged, semantic actions fire, and the parent node unifies
     with the finalized term.
   - This unification cascades upward to grandparent nodes automatically.

4. **Program Variable Safety**:
   Variables that appear in the source code being parsed (e.g. `X` in `foo(X, 1)`)
   are regular logical variables without an `ast_node` attribute. The dependency
   checker treats them as ready leaves rather than unresolved lazy nodes, preserving
   first-class logical variables in the resulting AST.

5. **Rational Tree (Cyclic AST) Safety**:
   Because Scryer Prolog handles rational trees natively, circular grammar
   productions and cyclic terms do not cause infinite loops.
*/

:- attribute ast_node/4, ast_subscribers/1.

%!  lazy_ast_node(-Node, +Deps, +Constructor) is det.
%
%   Convenience predicate to create a lazy AST node with empty metadata `[]`.
lazy_ast_node(Node, Deps, Constructor) :-
    lazy_ast_node(Node, Deps, Constructor, []).

%!  lazy_ast_node(-Node, +Deps, +Constructor, +Metadata) is det.
%
%   Creates a reactive AST node `Node` depending on `Deps`.
%   If all dependencies are already ready, the node is constructed and bound immediately.
%   Otherwise, `Node` remains an unbound attributed variable and subscribes to its
%   unresolved dependencies.
lazy_ast_node(Node, Deps, Constructor, Metadata) :-
    (   all_deps_ready(Deps) ->
        build_and_bind_node(Node, Deps, Constructor, Metadata)
    ;   put_atts(Node, ast_node(lazy, Deps, Constructor, Metadata)),
        subscribe_to_unresolved_deps(Deps, Node)
    ).

%!  is_lazy_ast_node(@Term) is semidet.
%
%   True if Term is an unbound variable with an unresolved lazy AST node attribute.
is_lazy_ast_node(Var) :-
    var(Var),
    get_atts(Var, ast_node(lazy, _, _, _)).

%!  ast_node_status(@Node, -Status) is semidet.
%
%   Inspects the current status of Node (`lazy` or `resolved`).
ast_node_status(Node, Status) :-
    (   var(Node) ->
        (   get_atts(Node, ast_node(S, _, _, _)) ->
            Status = S
        ;   Status = free_var
        )
    ;   Status = resolved
    ).

%!  ast_node_deps(@Node, -Deps) is semidet.
%
%   Inspects the dependencies list of a lazy AST node.
ast_node_deps(Node, Deps) :-
    var(Node),
    get_atts(Node, ast_node(_, Deps, _, _)).

%!  ast_node_constructor(@Node, -Constructor) is semidet.
%
%   Inspects the constructor descriptor of a lazy AST node.
ast_node_constructor(Node, Constructor) :-
    var(Node),
    get_atts(Node, ast_node(_, _, Constructor, _)).

%!  ast_node_metadata(@Node, -Metadata) is semidet.
%
%   Inspects the metadata of a lazy AST node.
ast_node_metadata(Node, Metadata) :-
    var(Node),
    get_atts(Node, ast_node(_, _, _, Metadata)).

%!  ast_node_subscribers(@Var, -Subscribers) is semidet.
%
%   Inspects the list of subscriber parent nodes waiting on Var.
ast_node_subscribers(Var, Subscribers) :-
    var(Var),
    (   get_atts(Var, ast_subscribers(Subs)) ->
        Subscribers = Subs
    ;   Subscribers = []
    ).

%!  resolve_ast_node(+Node) is semidet.
%
%   Forces an explicit check on Node to see if its dependencies are ready,
%   and if so, constructs and binds it immediately.
resolve_ast_node(Node) :-
    (   nonvar(Node) ->
        true
    ;   get_atts(Node, ast_node(lazy, Deps, Constructor, Metadata)),
        all_deps_ready(Deps) ->
        build_and_bind_node(Node, Deps, Constructor, Metadata)
    ;   false
    ).

% --- Dependency Resolution & Subscription Logic ---

%!  all_deps_ready(+Deps) is semidet.
%
%   True if every dependency in Deps is ready. A dependency is ready if it is
%   a concrete term, or a free logical variable that is NOT an unresolved lazy node.
all_deps_ready([]).
all_deps_ready([D|Ds]) :-
    nonvar(D),
    all_deps_ready(Ds).

subscribe_to_unresolved_deps([], _).
subscribe_to_unresolved_deps([D|Ds], ParentNode) :-
    (   var(D) ->
        add_parent_subscriber(D, ParentNode)
    ;   true
    ),
    subscribe_to_unresolved_deps(Ds, ParentNode).

add_parent_subscriber(ChildVar, ParentNode) :-
    (   get_atts(ChildVar, ast_subscribers(CurrentSubs)) ->
        (   member_var_eq(ParentNode, CurrentSubs) ->
            true
        ;   put_atts(ChildVar, ast_subscribers([ParentNode|CurrentSubs]))
        )
    ;   put_atts(ChildVar, ast_subscribers([ParentNode]))
    ).

member_var_eq(Var, [H|T]) :-
    (   Var == H ->
        true
    ;   member_var_eq(Var, T)
    ).

% --- verify_attributes Hook ---

%!  verify_attributes(-Var, +Other, -Goals) is det.
%
%   Scryer Prolog hook invoked when an attributed variable unifies.
verify_attributes(Var, Other, Goals) :-
    % 1. Handle subscriber notification or propagation
    (   get_atts(Var, ast_subscribers(Subs)) ->
        (   var(Other) ->
            % Unifying two variables: merge subscriber lists onto Other
            merge_subscribers_on_var(Other, Subs),
            Goals1 = []
        ;   % Unified with a non-variable term: wake up subscribers
            Goals1 = [notify_all_subscribers(Subs)]
        )
    ;   Goals1 = []
    ),
    % 2. Handle AST node merging when two lazy nodes unify
    (   get_atts(Var, ast_node(State, Deps, Constructor, Metadata)) ->
        (   var(Other) ->
            (   get_atts(Other, ast_node(OtherState, OtherDeps, OtherConstructor, OtherMeta)) ->
                % Both were lazy nodes: merge dependencies and metadata
                merge_deps(Deps, OtherDeps, MergedDeps),
                merge_metadata(Metadata, OtherMeta, MergedMeta),
                put_atts(Other, ast_node(OtherState, MergedDeps, OtherConstructor, MergedMeta)),
                Goals = Goals1
            ;   put_atts(Other, ast_node(State, Deps, Constructor, Metadata)),
                Goals = Goals1
            )
        ;   Goals = Goals1
        )
    ;   Goals = Goals1
    ).

merge_subscribers_on_var(Var, NewSubs) :-
    (   get_atts(Var, ast_subscribers(ExistingSubs)) ->
        union_var_eq(NewSubs, ExistingSubs, Merged),
        put_atts(Var, ast_subscribers(Merged))
    ;   put_atts(Var, ast_subscribers(NewSubs))
    ).

union_var_eq([], Acc, Acc).
union_var_eq([X|Xs], Acc, Result) :-
    (   member_var_eq(X, Acc) ->
        union_var_eq(Xs, Acc, Result)
    ;   union_var_eq(Xs, [X|Acc], Result)
    ).

merge_deps(D1, D2, Merged) :-
    append(D1, D2, Merged).

merge_metadata(M1, M2, Merged) :-
    (   list_si(M1), list_si(M2) ->
        append(M1, M2, Merged)
    ;   Merged = M1
    ).

notify_all_subscribers([]).
notify_all_subscribers([Parent|Parents]) :-
    (   var(Parent),
        get_atts(Parent, ast_node(lazy, Deps, Constructor, Metadata)) ->
        (   all_deps_ready(Deps) ->
            build_and_bind_node(Parent, Deps, Constructor, Metadata)
        ;   true
        )
    ;   true
    ),
    notify_all_subscribers(Parents).

% --- Term Construction Engine ---

build_and_bind_node(Node, Deps, Constructor, Metadata) :-
    % Collect resolved child values
    resolve_dep_values(Deps, Values),
    % Automatically derive/merge child spans into metadata if available
    merge_child_spans(Values, Metadata, MergedMetadata),
    % Execute any reactive semantic actions registered in Metadata
    run_semantic_actions(MergedMetadata, Values, Constructor, FinalMetadata),
    % Construct the finalized AST term
    construct_ast_term(Constructor, Values, FinalMetadata, Term),
    % Unify Node with the finalized term (this triggers verify_attributes on its subscribers!)
    Node = Term.

run_semantic_actions([], _, _, []).
run_semantic_actions([M|Ms], Values, Constructor, ResultMeta) :-
    (   M = semantic_action(Action) ->
        (   catch(call(Action, Constructor, Values, NewMetaItems), _, NewMetaItems = []) ->
            true
        ;   NewMetaItems = []
        ),
        run_semantic_actions(Ms, Values, Constructor, RestMeta),
        append(NewMetaItems, RestMeta, ResultMeta)
    ;   ResultMeta = [M|RestMeta],
        run_semantic_actions(Ms, Values, Constructor, RestMeta)
    ).

resolve_dep_values([], []).
resolve_dep_values([D|Ds], [V|Vs]) :-
    V = D,
    resolve_dep_values(Ds, Vs).

%!  construct_ast_term(+Constructor, +Values, +Metadata, -FinalTerm) is det.
%
%   Constructs the concrete AST term according to the Constructor recipe.
construct_ast_term(infix(Op), [Left, Right], Meta, ast_node(Term, Meta)) :-
    !,
    Term =.. [Op, Left, Right].
construct_ast_term(prefix(Op), [Arg], Meta, ast_node(Term, Meta)) :-
    !,
    Term =.. [Op, Arg].
construct_ast_term(postfix(Op), [Arg], Meta, ast_node(Term, Meta)) :-
    !,
    Term =.. [Op, Arg].
construct_ast_term(compound(Functor), Args, Meta, ast_node(Term, Meta)) :-
    !,
    Term =.. [Functor|Args].
construct_ast_term(rule, [Head, Body], Meta, ast_node((Head :- Body), Meta)) :-
    !.
construct_ast_term(rule(Head, Body), _, Meta, ast_node((Head :- Body), Meta)) :-
    !.
construct_ast_term(clause, [Head, Body], Meta, ast_node((Head :- Body), Meta)) :-
    !.
construct_ast_term(clause(Head, Body), _, Meta, ast_node((Head :- Body), Meta)) :-
    !.
construct_ast_term(fact, [Head], Meta, ast_node(Head, Meta)) :-
    !.
construct_ast_term(fact(Head), _, Meta, ast_node(Head, Meta)) :-
    !.
construct_ast_term(dcg_rule, [Head, Body], Meta, ast_node((Head --> Body), Meta)) :-
    !.
construct_ast_term(dcg_rule(Head, Body), _, Meta, ast_node((Head --> Body), Meta)) :-
    !.
construct_ast_term(directive, [Body], Meta, ast_node((:- Body), Meta)) :-
    !.
construct_ast_term(directive(Body), _, Meta, ast_node((:- Body), Meta)) :-
    !.
construct_ast_term(list, Elements, Meta, ast_node(Elements, Meta)) :-
    !.
construct_ast_term(literal, [Val], Meta, ast_node(Val, Meta)) :-
    !.
construct_ast_term(prog_var(V), _, Meta, ast_node(V, [type(var)|Meta])) :-
    !.
construct_ast_term(var_leaf(V), _, Meta, ast_node(V, [type(var)|Meta])) :-
    !.
construct_ast_term(custom(Pred), Values, Meta, Term) :-
    !,
    call(Pred, Values, Meta, Term).
construct_ast_term(raw_term, [Term], _, Term) :-
    !.
construct_ast_term(Constructor, Values, Meta, ast_node(custom(Constructor, Values), Meta)).

% --- Span Merging Helper ---

merge_child_spans(Values, Metadata, FinalMetadata) :-
    collect_spans(Values, Spans),
    (   Spans = [FirstSpan|_],
        last_element(Spans, LastSpan) ->
        extract_span_endpoints(FirstSpan, LastSpan, MergedSpan),
        FinalMetadata = [MergedSpan|Metadata]
    ;   FinalMetadata = Metadata
    ).

last_element([X], X) :- !.
last_element([_|Xs], Last) :-
    last_element(Xs, Last).

collect_spans([], []).
collect_spans([V|Vs], Spans) :-
    (   V = ast_node(_, Meta),
        member(span(Start, End), Meta) ->
        Spans = [span(Start, End)|RestSpans],
        collect_spans(Vs, RestSpans)
    ;   collect_spans(Vs, Spans)
    ).

extract_span_endpoints(span(Start, _), span(_, End), span(Start, End)).
