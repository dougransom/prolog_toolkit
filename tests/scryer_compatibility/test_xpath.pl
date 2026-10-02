:- module(test_xpath, [
    run_xpath_tests/0,
    run_xpath_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_xpath_case/4
]).

/** <module> Scryer Compatibility: XPath DOM Querying (library(xpath))

Tests xpath/3 and xpath_chk/3 for extracting elements, text, and attributes from DOM trees.
*/

:- use_module(library(sgml)).
:- use_module(library(xpath)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_xpath_text(Title) :-
    load_html("<html><head><title>Scryer XPath Test</title></head><body><a href=\"target.html\">Link</a></body></html>", DOM, []),
    xpath(DOM, //title(text), Title).

test_xpath_attribute(Href) :-
    load_html("<html><head><title>Scryer</title></head><body><a href=\"target.html\">Link</a></body></html>", DOM, []),
    xpath_chk(DOM, //a(@href), Href).

test_xpath_case(xpath_text_query, "xpath/3 retrieves nested element text content",
    ":- use_module(library(sgml)).\n:- use_module(library(xpath)).\ntest_xpath_text(Title) :-\n    load_html(\"<html><head><title>Scryer XPath Test</title></head><body><a href=\\\"target.html\\\">Link</a></body></html>\", DOM, []),\n    xpath(DOM, //title(text), Title).",
    ["test_xpath_text(T)."]).

test_xpath_case(xpath_attr_query, "xpath_chk/3 extracts attribute values deterministically",
    ":- use_module(library(sgml)).\n:- use_module(library(xpath)).\ntest_xpath_attribute(Href) :-\n    load_html(\"<html><head><title>Scryer</title></head><body><a href=\\\"target.html\\\">Link</a></body></html>\", DOM, []),\n    xpath_chk(DOM, //a(@href), Href).",
    ["test_xpath_attribute(H)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_xpath:test_xpath_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_xpath, OutFile),
    generate_scryer_out(OutFile).

run_xpath_tests(OutFile) :-
    format("~n--- Module Compatibility: library(xpath) ---~n", []),
    run_compat_tests_from_file(test_xpath:test_xpath_case, OutFile).
run_xpath_tests :-
    default_scryer_out_path(test_xpath, OutFile),
    run_xpath_tests(OutFile).
