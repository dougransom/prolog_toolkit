:- module(test_stdio, [
    run/0
]).

/** <module> Standard I/O and Subprocess Integration Tests for Crowlog

Executes the Crowlog toplevel as an external spawned subprocess with connected
operating system streams (stdin, stdout, pipes, EOF, exit status codes).
*/

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(process)).
:- use_module(library(reif)).
:- use_module('../testing').
:- use_module('test_toplevel', [chars_contains_all/2]).

%% exec_crowlog(+Args, +InputChars, -OutputChars, -ExitCode)
exec_crowlog(Args, InputChars, OutputChars, ExitCode) :-
    prolog_executable(Exe),
    append(["-f", "-t", "crowlog_toplevel", "crowlog/crowlog_toplevel.pl"|Args], FullArgs),
    process_create(Exe, FullArgs, [
        stdin(pipe(InStream)),
        stdout(pipe(OutStream)),
        stderr(null),
        process(P)
    ]),
    format(InStream, "~s", [InputChars]),
    close(InStream),
    read_stream_chars(OutStream, OutputChars),
    close(OutStream),
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

%% ============================================================================
%% Subprocess Standard I/O Test Cases
%% ============================================================================

test("stdio: interactive query and clean halt", (
    exec_crowlog([], "A is 1 + 2.\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "=== Crowlog: Source-Provenance Prolog REPL ===",
        "A = 3",
        "Exiting Crowlog."
    ])
)).

test("stdio: EOF on stdin terminates process cleanly with code 0", (
    exec_crowlog([], "true = true.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "crowlog ?- ",
        "true",
        "Exiting Crowlog."
    ])
)).

test("stdio: multi-solution backtracking across OS pipe (;)", (
    exec_crowlog([], "member(X, [first, second, third]).\n;\n;\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "X = first",
        "X = second",
        "X = third"
    ])
)).

test("stdio: CLI file argument consulted on startup", (
    exec_crowlog(["tests/fixtures/sample_kb.pl"], "parent(pam, Who).\n;\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "% Consulted tests/fixtures/sample_kb.pl",
        "Who = bob"
    ])
)).

test("stdio: runtime error reporting does not crash process", (
    exec_crowlog([], "1 is X.\ntrue.\nhalt.\n", Output, Code),
    Code =:= 0,
    chars_contains_all(Output, [
        "instantiation_error",
        "true",
        "Exiting Crowlog."
    ])
)).

run :-
    format("~n=== Running Crowlog Standard I/O Integration Tests ===~n", []),
    run_tests,
    exit_test_process.

:- initialization(run).
