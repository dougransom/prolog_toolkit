:- module(test_sgml, [
    run_sgml_tests/0,
    run_sgml_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_sgml_case/4
]).

/** <module> Scryer Compatibility: SGML / HTML / XML Parsing (library(sgml))

Tests load_html/3 and load_xml/3 to parse markup into element/3 AST trees.
*/

:- use_module(library(sgml)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_html_parse(DOM) :-
    load_html("<html><head><title>Scryer</title></head><body><p>Text</p></body></html>", DOM, []).

test_xml_parse(DOM) :-
    load_xml("<root id=\"1\"><item>Hello</item></root>", DOM, []).

test_sgml_case(html_parsing, "load_html/3 parses HTML string into structured DOM representation",
    ":- use_module(library(sgml)).\ntest_html_parse(DOM) :-\n    load_html(\"<html><head><title>Scryer</title></head><body><p>Text</p></body></html>\", DOM, []).",
    ["test_html_parse(D)."]).

test_sgml_case(xml_parsing, "load_xml/3 parses XML string with attributes and child elements",
    ":- use_module(library(sgml)).\ntest_xml_parse(DOM) :-\n    load_xml(\"<root id=\\\"1\\\"><item>Hello</item></root>\", DOM, []).",
    ["test_xml_parse(D)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_sgml:test_sgml_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_sgml, OutFile),
    generate_scryer_out(OutFile).

run_sgml_tests(OutFile) :-
    format("~n--- Module Compatibility: library(sgml) ---~n", []),
    run_compat_tests_from_file(test_sgml:test_sgml_case, OutFile).
run_sgml_tests :-
    default_scryer_out_path(test_sgml, OutFile),
    run_sgml_tests(OutFile).
