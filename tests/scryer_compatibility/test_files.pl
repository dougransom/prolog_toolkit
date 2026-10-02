:- module(test_files, [
    run_files_tests/0,
    run_files_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_files_case/4
]).

/** <module> Scryer Compatibility: Files and Directories (library(files))

Tests path_segments/2, file_exists/1, and directory_exists/1.
*/

:- use_module(library(files)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_path_segment_parse(Segments) :-
    path_segments("src/prolog_parser.pl", Segments).

test_path_segment_generate(Path) :-
    path_segments(Path, ["src", "lib", "test.pl"]).

test_dir_and_file_exist(DirOk, FileOk) :-
    (   directory_exists(".") -> DirOk = true ; DirOk = false ),
    (   file_exists("Makefile") -> FileOk = true ; FileOk = false ).

test_files_case(path_segments_parse, "path_segments/2 decomposes path into segment list",
    ":- use_module(library(files)).\ntest_path_segment_parse(Segments) :-\n    path_segments(\"src/prolog_parser.pl\", Segments).",
    ["test_path_segment_parse(S)."]).

test_files_case(path_segments_gen, "path_segments/2 reconstructs path string from segments",
    ":- use_module(library(files)).\ntest_path_segment_generate(Path) :-\n    path_segments(Path, [\"src\", \"lib\", \"test.pl\"]).",
    ["test_path_segment_generate(P)."]).

test_files_case(files_exist, "directory_exists/1 and file_exists/1 query filesystem entities",
    ":- use_module(library(files)).\ntest_dir_and_file_exist(DirOk, FileOk) :-\n    (   directory_exists(\".\") -> DirOk = true ; DirOk = false ),\n    (   file_exists(\"Makefile\") -> FileOk = true ; FileOk = false ).",
    ["test_dir_and_file_exist(D, F)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_files:test_files_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_files, OutFile),
    generate_scryer_out(OutFile).

run_files_tests(OutFile) :-
    format("~n--- Module Compatibility: library(files) ---~n", []),
    run_compat_tests_from_file(test_files:test_files_case, OutFile).
run_files_tests :-
    default_scryer_out_path(test_files, OutFile),
    run_files_tests(OutFile).
