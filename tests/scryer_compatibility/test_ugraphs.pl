:- module(test_ugraphs, [
    run_ugraphs_tests/0,
    run_ugraphs_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_ugraphs_case/4
]).

/** <module> Scryer Compatibility: Unweighted Graphs (library(ugraphs))

Tests graph construction, topological sort, transitive closure, reachability, and transposition.
*/

:- use_module(library(format)).
:- use_module(library(ugraphs)).
:- use_module(compat_framework).

% Native Scryer predicates
test_graph_construction(G, V, E) :-
    vertices_edges_to_ugraph([1, 2, 3, 4], [1-2, 1-3, 2-4, 3-4], G),
    vertices(G, V),
    edges(G, E).

test_graph_top_sort(Order) :-
    vertices_edges_to_ugraph([a, b, c, d], [a-b, a-c, b-d, c-d], G),
    top_sort(G, Order).

test_graph_transitive_closure(Closure) :-
    vertices_edges_to_ugraph([1, 2, 3], [1-2, 2-3], G),
    transitive_closure(G, Closure).

test_graph_reachable(Reach) :-
    vertices_edges_to_ugraph([1, 2, 3, 4], [1-2, 2-3, 4-1], G),
    reachable(1, G, Reach).

test_graph_transpose(Transposed) :-
    vertices_edges_to_ugraph([1, 2, 3], [1-2, 2-3], G),
    transpose_ugraph(G, Transposed).

test_ugraphs_case(ugraph_construct, "vertices_edges_to_ugraph/3, vertices/2, and edges/2",
    ":- use_module(library(ugraphs)).\ntest_graph_construction(G, V, E) :-\n    vertices_edges_to_ugraph([1, 2, 3, 4], [1-2, 1-3, 2-4, 3-4], G),\n    vertices(G, V),\n    edges(G, E).",
    ["test_graph_construction(G, V, E)."]).

test_ugraphs_case(ugraph_top_sort, "top_sort/2 calculates topological ordering of DAG",
    ":- use_module(library(ugraphs)).\ntest_graph_top_sort(Order) :-\n    vertices_edges_to_ugraph([a, b, c, d], [a-b, a-c, b-d, c-d], G),\n    top_sort(G, Order).",
    ["test_graph_top_sort(Ord)."]).

test_ugraphs_case(ugraph_closure, "transitive_closure/2 finds all reachable paths",
    ":- use_module(library(ugraphs)).\ntest_graph_transitive_closure(Closure) :-\n    vertices_edges_to_ugraph([1, 2, 3], [1-2, 2-3], G),\n    transitive_closure(G, Closure).",
    ["test_graph_transitive_closure(C)."]).

test_ugraphs_case(ugraph_reachable, "reachable/3 computes vertex reachability set",
    ":- use_module(library(ugraphs)).\ntest_graph_reachable(Reach) :-\n    vertices_edges_to_ugraph([1, 2, 3, 4], [1-2, 2-3, 4-1], G),\n    reachable(1, G, Reach).",
    ["test_graph_reachable(R)."]).

test_ugraphs_case(ugraph_transpose, "transpose_ugraph/2 reverses all directed edges",
    ":- use_module(library(ugraphs)).\ntest_graph_transpose(Transposed) :-\n    vertices_edges_to_ugraph([1, 2, 3], [1-2, 2-3], G),\n    transpose_ugraph(G, Transposed).",
    ["test_graph_transpose(T)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_ugraphs:test_ugraphs_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_ugraphs, OutFile),
    generate_scryer_out(OutFile).

run_ugraphs_tests(OutFile) :-
    format("~n--- Module Compatibility: library(ugraphs) ---~n", []),
    run_compat_tests_from_file(test_ugraphs:test_ugraphs_case, OutFile).
run_ugraphs_tests :-
    default_scryer_out_path(test_ugraphs, OutFile),
    run_ugraphs_tests(OutFile).
