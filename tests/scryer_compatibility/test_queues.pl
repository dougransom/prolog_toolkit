:- module(test_queues, [
    run_queues_tests/0,
    run_queues_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_queues_case/4
]).

/** <module> Scryer Compatibility: Queues (library(queues))

Tests queue/1, queue_head/3, queue_last/3, list_queue/2, and queue_length/2.
*/

:- use_module(library(format)).
:- use_module(library(queues)).
:- use_module(compat_framework).

% Predicates for native Scryer execution
test_queue_ops(L, Len) :-
    queue(Q0),
    queue_last(a, Q0, Q1),
    queue_last(b, Q1, Q2),
    queue_head(z, Q2, Q3),
    list_queue(L, Q3),
    queue_length(Q3, Len).

test_queue_head_dequeue(H, RemList) :-
    list_queue([10, 20, 30], Q0),
    queue_head(H, Q1, Q0),
    list_queue(RemList, Q1).

test_queues_case(queue_build, "build queue with queue_last, queue_head, list_queue, queue_length",
    ":- use_module(library(queues)).\ntest_queue_ops(L, Len) :-\n    queue(Q0),\n    queue_last(a, Q0, Q1),\n    queue_last(b, Q1, Q2),\n    queue_head(z, Q2, Q3),\n    list_queue(L, Q3),\n    queue_length(Q3, Len).",
    ["test_queue_ops(List, Length)."]).

test_queues_case(queue_dequeue, "dequeue with queue_head",
    ":- use_module(library(queues)).\ntest_queue_head_dequeue(H, RemList) :-\n    list_queue([10, 20, 30], Q0),\n    queue_head(H, Q1, Q0),\n    list_queue(RemList, Q1).",
    ["test_queue_head_dequeue(Elem, Rest)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_queues:test_queues_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_queues, OutFile),
    generate_scryer_out(OutFile).

run_queues_tests(OutFile) :-
    format("~n--- Module Compatibility: library(queues) ---~n", []),
    run_compat_tests_from_file(test_queues:test_queues_case, OutFile).
run_queues_tests :-
    default_scryer_out_path(test_queues, OutFile),
    run_queues_tests(OutFile).
