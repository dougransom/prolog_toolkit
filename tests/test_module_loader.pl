:- module(test_module_loader, [
    run/0
]).

:- use_module(library(charsio)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(si)).
:- use_module('../src/prolog_toolkit').
:- use_module(testing).

test("search path resolution for library modules", (
    init_loader_state(State0),
    State0 = loader_state(_, SearchPaths, _),
    resolve_module_path(".", SearchPaths, library(lists), ResolvedLists),
    append(_, "reference/scryer-prolog/src/lib/lists.pl", ResolvedLists),

    resolve_module_path(".", SearchPaths, library(http/http_open), ResolvedHttp),
    append(_, "reference/scryer-prolog/src/lib/http/http_open.pl", ResolvedHttp)
)).

test("custom search path registration", (
    init_loader_state(State0),
    add_search_path(State0, custom, "my_libs/sub", State1),
    State1 = loader_state(_, SearchPaths, _),
    member(path(custom, "my_libs/sub"), SearchPaths)
)).

test("load module file and extract metadata", (
    init_loader_state(State0),
    load_module_file("reference/scryer-prolog/src/lib/http/http_open.pl", State0, _StateOut, ModInfo),
    module_info_name(ModInfo, http_open),
    module_info_exports(ModInfo, [http_open/3]),
    module_info_statements(ModInfo, Stmts),
    length(Stmts, 10)
)).

test("operator export propagation from library module", (
    init_loader_state(State0),
    load_module_file("reference/scryer-prolog/src/lib/atts.pl", State0, _StateOut, ModInfo),
    module_info_name(ModInfo, atts),
    module_info_ops(ModInfo, ExportedOps),
    member(op(1199, fx, attribute), ExportedOps)
)).

run :-
    run_tests,
    halt.

:- initialization(run).
