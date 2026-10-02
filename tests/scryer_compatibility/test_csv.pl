:- module(test_csv, [
    run_csv_tests/0,
    run_csv_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_csv_case/4
]).

/** <module> Scryer Compatibility: CSV Parsing (library(csv))

Tests phrase(parse_csv(Data), Chars) with default options and custom separators.
*/

:- use_module(library(csv)).
:- use_module(library(dcgs)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_csv_header(Data) :-
    phrase(parse_csv(Data), "col1,col2,col3\none,2,three\nfour,5,six\n").

test_csv_no_header_semicolon(Data) :-
    phrase(parse_csv(Data, [with_header(false), token_separator(';')]), "a;10\nb;20\n").

test_csv_case(csv_parse_header, "parse_csv//1 with default header and comma separator",
    ":- use_module(library(csv)).\n:- use_module(library(dcgs)).\ntest_csv_header(Data) :-\n    phrase(parse_csv(Data), \"col1,col2,col3\\none,2,three\\nfour,5,six\\n\").",
    ["test_csv_header(Data)."]).

test_csv_case(csv_parse_options, "parse_csv//2 with custom options (no header, semicolon separator)",
    ":- use_module(library(csv)).\n:- use_module(library(dcgs)).\ntest_csv_no_header_semicolon(Data) :-\n    phrase(parse_csv(Data, [with_header(false), token_separator(';')]), \"a;10\\nb;20\\n\").",
    ["test_csv_no_header_semicolon(Data)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_csv:test_csv_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_csv, OutFile),
    generate_scryer_out(OutFile).

run_csv_tests(OutFile) :-
    format("~n--- Module Compatibility: library(csv) ---~n", []),
    run_compat_tests_from_file(test_csv:test_csv_case, OutFile).
run_csv_tests :-
    default_scryer_out_path(test_csv, OutFile),
    run_csv_tests(OutFile).
