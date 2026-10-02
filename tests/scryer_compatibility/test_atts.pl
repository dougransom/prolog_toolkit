:- module(test_atts, [
    run_atts_tests/0,
    run_atts_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_atts_case/4
]).

/** <module> Scryer Compatibility: Attributed Variables (library(atts))

Tests term_attributed_variables/2 to collect attributed variables from terms.
*/

:- use_module(library(atts)).
:- use_module(library(freeze)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_attributed_vars(AttVars) :-
    freeze(X, X = 1),
    _Y = 2,
    term_attributed_variables(t(X, _Y, _Z), AttVars).

test_atts_case(term_attributed_vars, "term_attributed_variables/2 extracts all attributed variables from a term",
    ":- use_module(library(atts)).\n:- use_module(library(freeze)).\ntest_attributed_vars(AttVars) :-\n    freeze(X, X = 1),\n    _Y = 2,\n    term_attributed_variables(t(X, _Y, _Z), AttVars).",
    ["test_attributed_vars(AVs)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_atts:test_atts_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_atts, OutFile),
    generate_scryer_out(OutFile).

run_atts_tests(OutFile) :-
    format("~n--- Module Compatibility: library(atts) ---~n", []),
    run_compat_tests_from_file(test_atts:test_atts_case, OutFile).
run_atts_tests :-
    default_scryer_out_path(test_atts, OutFile),
    run_atts_tests(OutFile).
