:- module(test_stdio, [
    run/0
]).

/** <module> Standard I/O and Subprocess Integration Tests for Crowlog

Executes the Crowlog toplevel as an external spawned subprocess with connected
operating system streams (stdin, stdout, pipes, EOF, exit status codes).
*/

:- use_module(library(charsio)).
:- use_module(library(dcgs)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(process)).
:- use_module(library(reif)).
:- use_module('../testing', [exit_test_process/0]).

chars_contains(Chars, Sub) :-
    append(_, Rest, Chars),
    append(Sub, _, Rest).

chars_contains_all(Chars, Substrings) :-
    maplist(chars_contains(Chars), Substrings).

%% exec_crowlog(+Args, +InputChars, -OutputChars, -ExitCode)
exec_crowlog(Args, InputChars, OutputChars, ExitCode) :-
    prolog_executable(Exe),
    FullArgs = ["-f", "-t", "crowlog_toplevel", "crowlog/crowlog_toplevel.pl", "--"|Args],
    process_create(Exe, FullArgs, [
        stdin(pipe(InStream)),
        stdout(pipe(OutStream)),
        stderr(pipe(ErrStream)),
        process(P)
    ]),
    maplist(put_char(InStream), InputChars),
    flush_output(InStream),
    close(InStream),
    read_stream_chars(OutStream, OutputChars),
    close(OutStream),
    read_stream_chars(ErrStream, ErrChars),
    close(ErrStream),
    (   ErrChars \= [] ->
        format("Stderr: ~s~n", [ErrChars])
    ;   true
    ),
    process_wait(P, exit(ExitCode)).

prolog_executable("/home/doug/code/scryer-prolog/target/release/scryer-prolog").

read_chunk_size(4096).

read_stream_chars(Stream, Chars) :-
    read_chunk_size(ChunkSize),
    get_n_chars(Stream, ChunkSize, Chunk),
    if_(Chunk = [],
        Chars = [],
        (   Chars = [C|Rest],
            Chunk = [C|ChunkRest],
            read_stream_chars_chunk(ChunkRest, Stream, Rest)
        )).

read_stream_chars_chunk([], Stream, Rest) :-
    read_stream_chars(Stream, Rest).
read_stream_chars_chunk([C|Cs], Stream, [C|Rest]) :-
    read_stream_chars_chunk(Cs, Stream, Rest).

run_test(Name, Goal) :-
    (   catch(Goal, E, (format("FAIL (~s): exception: ~w~n", [Name, E]), flush_output, fail)) ->
        format("OK: ~s~n", [Name]),
        flush_output
    ;   format("FAIL: ~s~n", [Name]),
        flush_output,
        halt(1)
    ).

%% ============================================================================
%% Subprocess Standard I/O Test Cases
%% ============================================================================

test_interactive_query :-
    exec_crowlog([], "A is 1 + 2.\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "=== Crowlog: Source-Provenance Prolog REPL ===",
        "A = 3",
        "Exiting Crowlog."
    ]).

test_eof_termination :-
    exec_crowlog([], "true = true.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "crowlog ?- ",
        "true",
        "Exiting Crowlog."
    ]).

test_unbound_var_in_list :-
    exec_crowlog([], "X = [Y].\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "X = [Y]",
        "Exiting Crowlog."
    ]),
    \+ chars_contains(Output, "Y = ").

test_backtracking_pipe :-
    exec_crowlog([], "member(X, [first, second, third]).\n;\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "X = first",
        "X = second"
    ]).

test_consult_cli_arg :-
    exec_crowlog(["tests/fixtures/sample_kb.pl"], "parent(pam, Who).\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "% Consulted tests/fixtures/sample_kb.pl",
        "Who = bob"
    ]).

test_runtime_error_resilience :-
    exec_crowlog([], "1 is X.\ntrue.\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "instantiation_error",
        "true",
        "Exiting Crowlog."
    ]).

test_incomplete_dot_term_exit :-
    exec_crowlog([], "A=.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "=== Crowlog: Source-Provenance Prolog REPL ===",
        "Syntax error: failed to parse term.",
        "Exiting Crowlog."
    ]).

test_syntax_error_recovery_stdio :-
    exec_crowlog([], "A=:\n.\nA = 42.\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "Syntax error: failed to parse term.",
        "A = 42",
        "Exiting Crowlog."
    ]).

test_unbound_variable_query_stdio :-
    exec_crowlog([], "X.\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "instantiation_error",
        "Exiting Crowlog."
    ]).

test_multiline_query_stdio :-
    exec_crowlog([], "append([1],\n  [2],\n  Res\n).\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "Res = [1, 2]",
        "Exiting Crowlog."
    ]).

run :-
    format("~n=== Running Crowlog Standard I/O Integration Tests ===~n", []),
    flush_output,
    run_test("stdio: interactive query and clean halt", test_interactive_query),
    run_test("stdio: EOF on stdin terminates process cleanly with code 0", test_eof_termination),
    run_test("stdio: unbound variable in compound term (X = [Y])", test_unbound_var_in_list),
    run_test("stdio: multi-solution backtracking across OS pipe (;)", test_backtracking_pipe),
    run_test("stdio: CLI file argument consulted on startup", test_consult_cli_arg),
    run_test("stdio: runtime error reporting does not crash process", test_runtime_error_resilience),
    run_test("stdio: incomplete term ending in dot (A=.)", test_incomplete_dot_term_exit),
    run_test("stdio: syntax error recovery across lines (A=: . then A = 42)", test_syntax_error_recovery_stdio),
    run_test("stdio: unbound variable query (X.) reports error", test_unbound_variable_query_stdio),
    run_test("stdio: multiline query formatting (append)", test_multiline_query_stdio),
    format("~n=== All 10 Crowlog Stdio Integration Tests Passed Successfully ===~n", []),
    flush_output,
    exit_test_process.

:- initialization(run).


