/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Unit Tests: Term I/O (iso_read_term & read_term_ex with Attributed Variables)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module('../src/prolog_toolkit').

run_test(Name, Goal) :-
    (   catch(Goal, E, (format("FAIL: ~s (exception: ~w)~n", [Name, E]), fail)) ->
        format("OK: ~s~n", [Name])
    ;   format("FAIL: ~s~n", [Name]),
        halt(1)
    ).

% 1. Standard ISO read_term options
test_iso_read_term_options :-
    iso_read_term_from_chars("foo(X, Y, X, _Z).", Term, [
        variable_names(VNs),
        variables(Vs),
        singletons(Sing)
    ]),
    Term = foo(A, B, A, _C),
    VNs = ['X' = A, 'Y' = B, '_Z' = _C],
    Vs = [A, B, _C],
    Sing = ['Y' = B].

% 2. Extended read_term_ex: Token provenance as attributed variables
test_read_term_ex_tokens_provenance :-
    read_term_ex_from_chars(file("my_script.pl"), "bar(A, 42).", Term, [
        tokens(Toks),
        token_attributed_variables(TVars)
    ]),
    Term = bar(_, 42),
    length(TVars, NumVars),
    NumVars > 0,
    % Verify every token attributed variable carries token provenance
    maplist(verify_token_attr_var(file("my_script.pl")), TVars),
    % Verify tokens list structure
    Toks = [token_ex(atom, [b,a,r], _, file("my_script.pl"), _) | _].

verify_token_attr_var(ExpectedSource, Var) :-
    is_provenance_var(Var),
    get_provenance(Var, Prov),
    provenance_source(Prov, ExpectedSource),
    provenance_type(Prov, _),
    provenance_span(Prov, _).

% 3. Extended read_term_ex: Variable provenance as attributed variables
test_read_term_ex_variable_provenance :-
    read_term_ex_from_chars(toplevel, "test_call(Alpha, Beta, Alpha).", Term, []),
    Term = test_call(Alpha, Beta, Alpha),
    is_provenance_var(Alpha),
    get_provenance(Alpha, var_provenance('Alpha', AlphaSpans, toplevel)),
    length(AlphaSpans, 2),
    is_provenance_var(Beta),
    get_provenance(Beta, var_provenance('Beta', BetaSpans, toplevel)),
    length(BetaSpans, 1).

% 4. Extended read_term_ex: Term provenance with file, toplevel, URL source
test_read_term_ex_term_provenance_url :-
    read_term_ex_from_chars(url("https://example.org/module.pl"), "hello(world).", Term, [
        term_provenance(TProv)
    ]),
    Term = hello(world),
    is_provenance_var(TProv),
    provenance_source(TProv, url("https://example.org/module.pl")),
    provenance_expansion(TProv, source_term(hello(world))).

% 5. Macro expansion lineage tracking: DCG rules
test_read_term_ex_macro_lineage_dcg :-
    read_term_ex_from_chars(file("grammar.pl"), "greeting --> [hello], name.", Term, [
        expand(pure_dcg),
        term_provenance(TProv)
    ]),
    % Term is transformed into a DCG clause
    Term = (greeting(_, _) :- _),
    provenance_expansion(TProv, expanded((greeting --> [hello], name), Macros)),
    Macros = [macro(dcg, (greeting --> [hello], name))].

% 6. Macro expansion lineage tracking: Rewrite rules with source location
test_read_term_ex_macro_lineage_rules :-
    read_term_ex_from_chars(file("macro.pl"), "special_const.", Term, [
        expand(rules([rule(special_const, 999, location("macro.pl", 15))])),
        term_provenance(TProv)
    ]),
    Term = 999,
    provenance_expansion(TProv, expanded(special_const, [macro(rule(special_const, 999), location("macro.pl", 15))])).

% 7. Convenient term_ex/2 wrapper for binding Term and Prov simultaneously
test_read_term_ex_wrapper :-
    read_term_ex_from_chars(file("foo.pl"), "calc(1 + 2).", term_ex(Term, Prov), []),
    Term = calc(1 + 2),
    is_provenance_var(Prov),
    provenance_source(Prov, file("foo.pl")).

% 8. Error handling with syntax_errors option
test_read_term_ex_syntax_errors :-
    % syntax_errors(fail) should fail rather than throw
    \+ read_term_ex_from_chars(chars, "bad(.", _, [syntax_errors(fail)]),
    % syntax_errors(error) should throw syntax_error
    catch(read_term_ex_from_chars(chars, "bad(.", _, [syntax_errors(error)]), error(syntax_error(_), _), true).

main :-
    format("=== Running Term I/O & read_term_ex Tests ===~n", []),
    run_test("ISO read_term options (variable_names, variables, singletons)", test_iso_read_term_options),
    run_test("read_term_ex token provenance as attributed variables", test_read_term_ex_tokens_provenance),
    run_test("read_term_ex variable provenance with occurrence spans", test_read_term_ex_variable_provenance),
    run_test("read_term_ex term provenance with URL source origin", test_read_term_ex_term_provenance_url),
    run_test("read_term_ex DCG macro expansion lineage tracking", test_read_term_ex_macro_lineage_dcg),
    run_test("read_term_ex rewrite rule macro lineage with location metadata", test_read_term_ex_macro_lineage_rules),
    run_test("read_term_ex term_ex(Term, Prov) wrapper", test_read_term_ex_wrapper),
    run_test("read_term_ex syntax_errors options (fail, error)", test_read_term_ex_syntax_errors),
    format("=== All Term I/O Tests Passed ===~n", []),
    halt(0).

:- initialization(main).
