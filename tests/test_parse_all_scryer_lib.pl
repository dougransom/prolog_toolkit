:- module(test_parse_all_scryer_lib, [
    run/0
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(files)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(time)).
:- use_module('../src/prolog_toolkit').
:- use_module('../src/module_loader').

run :-
    format("=== Testing Parsing Across Scryer Standard Library ===~n", []),
    LibDir = "reference/scryer-prolog/src/lib",
    find_pl_files(LibDir, Files),
    length(Files, TotalFiles),
    format("Discovered ~d Prolog library source files in ~s.~n~n", [TotalFiles, LibDir]),
    init_loader_state([library_path(LibDir)], BaseLoaderState),
    parse_all_files(Files, BaseLoaderState, 0, Passed, 0, Failed),
    format("~n=== Parsing Summary ===~n", []),
    format("Total files:  ~d~n", [TotalFiles]),
    format("Passed:       ~d~n", [Passed]),
    format("Failed:       ~d~n", [Failed]),
    if_(Failed #= 0,
        ( format("All Scryer standard library files parsed successfully!~n", []), halt(0) ),
        ( format("Parsing failures encountered!~n", []), halt(1) )
    ).

find_pl_files(Dir, AllFiles) :-
    directory_files(Dir, Entries),
    sort(Entries, Sorted),
    collect_pl_files(Sorted, Dir, AllFiles).

collect_pl_files([], _, []).
collect_pl_files([Entry|Entries], Dir, Out) :-
    (   ( Entry = "." ; Entry = ".." ) ->
        collect_pl_files(Entries, Dir, Out)
    ;   append(Dir, "/", Prefix),
        append(Prefix, Entry, Path),
        (   directory_exists(Path) ->
            find_pl_files(Path, SubFiles),
            collect_pl_files(Entries, Dir, Rest),
            append(SubFiles, Rest, Out)
        ;   (   append(_, ".pl", Entry) ->
                Out = [Path|Rest],
                collect_pl_files(Entries, Dir, Rest)
            ;   collect_pl_files(Entries, Dir, Out)
            )
        )
    ).

parse_all_files([], _, Passed, Passed, Failed, Failed).
parse_all_files([File|Files], State0, PassAcc, PassFinal, FailAcc, FailFinal) :-
    format("Parsing ~s ... ", [File]), flush_output,
    catch((
        % Load module file with full dependency resolution & DCG expansion
        load_module_file(File, [expand_mode(pure_dcg)], State0, _State1, ModInfo),
        module_info_statements(ModInfo, Stmts),
        length(Stmts, StmtCount),
        format("OK (~d statements)~n", [StmtCount]), flush_output,
        PassAcc1 #= PassAcc + 1,
        FailAcc1 #= FailAcc
    ), Error, (
        format("FAILED!~n  Error: ~q~n", [Error]), flush_output,
        PassAcc1 #= PassAcc,
        FailAcc1 #= FailAcc + 1
    )),
    parse_all_files(Files, State0, PassAcc1, PassFinal, FailAcc1, FailFinal).

:- initialization(run).
