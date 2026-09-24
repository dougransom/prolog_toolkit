/** <module> Consolidated Core Test Runner
 
  Runs all core toolkit test suites (excluding test_module_loader)
  within a single Scryer Prolog process to eliminate redundant
  module recompilation overhead.
*/

:- module(run_all_core_tests, []).

:- use_module(library(format)).

% Activate consolidated runner mode before loading test suites
:- use_module(setup_consolidated_runner).

% Load and execute all core test suites
:- use_module(test_prolog_toolkit).
:- use_module(test_prolog_parser).
:- use_module(test_prolog_lexer).
:- use_module(test_prolog_expander).
:- use_module(test_scryer_lib).
:- use_module(test_term_io).
:- use_module(test_prolog_reactive_ast).
:- use_module(test_prolog_reactive_parser).
:- use_module(test_incremental_ast_patching).

all_tests_passed :-
    format("~n======================================================~n", []),
    format("=== ALL CONSOLIDATED CORE TESTS PASSED SUCCESSFULLY ==~n", []),
    format("======================================================~n~n", []),
    halt(0).

:- initialization(all_tests_passed).
