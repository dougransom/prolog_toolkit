/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Module Loader & Search Path Resolver

   Pure ISO and Scryer-compatible module loader supporting:
   - `:- use_module(library(...))`
   - `:- use_module(pkg(...))`
   - Relative imports (`use_module(file)`)
   - Configurable search paths (`library`, `pkg`, etc.)
   - Cyclic import avoidance via module registry caching
   - Dynamic operator export propagation into importing modules
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(module_loader, [
    init_loader_state/1,
    init_loader_state/2,
    add_search_path/4,
    resolve_module_path/4,
    load_module_file/4,
    parse_module_chars/6,
    module_info_name/2,
    module_info_exports/2,
    module_info_ops/2,
    module_info_statements/2
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(files)).
:- use_module(library(lists)).
:- use_module(library(os)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(token).
:- use_module(lexer).
:- use_module(operator_table).
:- use_module(iso_parser).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Loader State Data Structure
   loader_state(LoadedModules, SearchPaths, BaseOpTable)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% init_loader_state(-State)
%  Initializes loader state with standard search paths and default operator table.
init_loader_state(State) :-
    init_loader_state([], State).

%% init_loader_state(+Options, -State)
%  Options can include:
%    - library_path(PathChars)
%    - pkg_path(PathChars)
init_loader_state(Options, loader_state([], SearchPaths, BaseOpTable)) :-
    default_operator_table(BaseOpTable),
    default_search_paths(Options, SearchPaths).

default_search_paths(Options, SearchPaths) :-
    (   member(library_path(LibPath), Options) ->
        op_chars(LibPath, LibChars),
        SearchPaths1 = [path(library, LibChars)]
    ;   % Default to local reference directory if available
        SearchPaths1 = [path(library, "reference/scryer-prolog/src/lib")]
    ),
    (   member(pkg_path(PkgPath), Options) ->
        op_chars(PkgPath, PkgChars),
        SearchPaths = [path(pkg, PkgChars)|SearchPaths1]
    ;   SearchPaths = [path(pkg, "pkg")|SearchPaths1]
    ).

%% add_search_path(+State0, +Alias, +DirPath, -StateOut)
add_search_path(loader_state(Loaded, Paths0, OpT), Alias, DirPath, loader_state(Loaded, PathsOut, OpT)) :-
    op_chars(DirPath, DirChars),
    PathsOut = [path(Alias, DirChars)|Paths0].

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Path Resolution
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% resolve_module_path(+CurrentDir, +SearchPaths, +ModuleSpec, -ResolvedPath)
resolve_module_path(_CurrentDir, SearchPaths, library(Lib), ResolvedPath) :- !,
    member(path(library, BaseDir), SearchPaths),
    spec_to_subpath(Lib, SubPath),
    join_dir_file(BaseDir, SubPath, Candidate),
    ensure_pl_extension(Candidate, ResolvedPath),
    file_exists(ResolvedPath).
resolve_module_path(_CurrentDir, SearchPaths, pkg(Pkg), ResolvedPath) :- !,
    member(path(pkg, BaseDir), SearchPaths),
    spec_to_subpath(Pkg, SubPath),
    join_dir_file(BaseDir, SubPath, Candidate),
    ensure_pl_extension(Candidate, ResolvedPath),
    file_exists(ResolvedPath).
resolve_module_path(CurrentDir, _SearchPaths, RelSpec, ResolvedPath) :-
    spec_to_subpath(RelSpec, SubPath),
    join_dir_file(CurrentDir, SubPath, Candidate),
    ensure_pl_extension(Candidate, ResolvedPath).

spec_to_subpath(A/B, SubPath) :- !,
    spec_to_subpath(A, SubA),
    spec_to_subpath(B, SubB),
    append(SubA, "/", Temp),
    append(Temp, SubB, SubPath).
spec_to_subpath(AtomOrChars, SubPath) :-
    op_chars(AtomOrChars, SubPath).

join_dir_file(".", File, File) :- !.
join_dir_file("", File, File) :- !.
join_dir_file(Dir, File, Out) :-
    (   append(_, "/", Dir) ->
        append(Dir, File, Out)
    ;   append(Dir, "/", DirSlash),
        append(DirSlash, File, Out)
    ).

ensure_pl_extension(Path, Path) :-
    append(_, ".pl", Path), !.
ensure_pl_extension(Path, Out) :-
    append(Path, ".pl", Out).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Module Loading
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% load_module_file(+FilePath, +State0, -StateOut, -ModuleInfo)
load_module_file(FilePath, State0, StateOut, ModuleInfo) :-
    op_chars(FilePath, PathChars),
    State0 = loader_state(Loaded0, SearchPaths, BaseOpTable),
    (   find_loaded_module(Loaded0, PathChars, CachedInfo) ->
        ModuleInfo = CachedInfo,
        StateOut = State0
    ;   read_file_to_chars(PathChars, Chars),
        file_directory(PathChars, CurrentDir),
        % Mark as currently loading with empty info to prevent infinite recursion
        StateTemp = loader_state([loaded(PathChars, loading)|Loaded0], SearchPaths, BaseOpTable),
        parse_module_chars(Chars, PathChars, CurrentDir, StateTemp, State1, ModuleInfo),
        State1 = loader_state(Loaded1, Paths1, BaseOpT1),
        % Replace temporary loading entry with fully parsed ModuleInfo
        replace_loaded_entry(Loaded1, PathChars, CleanLoaded),
        StateOut = loader_state([loaded(PathChars, ModuleInfo)|CleanLoaded], Paths1, BaseOpT1)
    ).

find_loaded_module([loaded(P, Info)|Rest], Path, ModInfo) :-
    if_(P = Path,
        ( dif(Info, loading), ModInfo = Info ),
        find_loaded_module(Rest, Path, ModInfo)
    ).

replace_loaded_entry([], _, []).
replace_loaded_entry([loaded(P, Info)|Rest], Path, Out) :-
    if_(P = Path,
        replace_loaded_entry(Rest, Path, Out),
        ( Out = [loaded(P, Info)|RestOut],
          replace_loaded_entry(Rest, Path, RestOut) )
    ).

file_directory(Path, Dir) :-
    (   append(DirPrefix, [C|FileName], Path),
        C = 0'/,
        \+ member(0'/, FileName) ->
        ( DirPrefix == [] -> Dir = "/" ; Dir = DirPrefix )
    ;   Dir = "."
    ).

read_file_to_chars(Path, Chars) :-
    open(Path, read, Stream),
    read_stream_chars(Stream, Chars),
    close(Stream).

read_stream_chars(Stream, Chars) :-
    get_n_chars(Stream, 4096, Chunk),
    (   Chunk == [] ->
        Chars = []
    ;   Chars = [C|Rest],
        Chunk = [C|ChunkRest],
        read_stream_chars_chunk(ChunkRest, Stream, Rest)
    ).

read_stream_chars_chunk([], Stream, Rest) :- !,
    read_stream_chars(Stream, Rest).
read_stream_chars_chunk([C|Cs], Stream, [C|Rest]) :-
    read_stream_chars_chunk(Cs, Stream, Rest).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Parse Module Characters
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_module_chars(Chars, SourceName, CurrentDir, State0, StateOut, ModuleInfo) :-
    phrase(tokens(Tokens), Chars),
    State0 = loader_state(_, _, BaseOpTable),
    parse_module_tokens(Tokens, SourceName, CurrentDir, BaseOpTable, State0, StateOut, [], Statements, unknown, ModName, [], Exports, []),
    extract_exported_ops(Exports, ExportedOps),
    ModuleInfo = module_info(ModName, Exports, ExportedOps, Statements).

parse_module_tokens([], _Source, _Dir, _OpTable, State, State, Stmts, Stmts, Name, Name, Exps, Exps, _Ops).
parse_module_tokens([EndTok], _Source, _Dir, _OpTable, State, State, Stmts, Stmts, Name, Name, Exps, Exps, _Ops) :-
    token_type(EndTok, end), !.
parse_module_tokens(Tokens, Source, Dir, OpTable0, State0, StateOut, StmtsAcc, StmtsFinal, Name0, NameFinal, Exps0, ExpsFinal, LocalOps0) :-
    phrase(parse_clause(OpTable0, Stmt, OpTable1), Tokens, TokensRest), !,
    handle_parsed_statement(Stmt, Dir, OpTable1, OpTable2, State0, State1, Name0, Name1, Exps0, Exps1, LocalOps0, LocalOps1),
    parse_module_tokens(TokensRest, Source, Dir, OpTable2, State1, StateOut, [Stmt|StmtsAcc], StmtsFinal, Name1, NameFinal, Exps1, ExpsFinal, LocalOps1).

handle_parsed_statement(directive(module(Name, Exports), _), _Dir, OpTable0, OpTableOut, State, State, _, Name, _, Exports, Ops, Ops) :- !,
    import_exported_ops(Exports, OpTable0, OpTableOut).
handle_parsed_statement(directive(use_module(Spec), _), Dir, OpTable0, OpTableOut, State0, StateOut, N, N, E, E, Ops, Ops) :- !,
    import_module_ops(Spec, Dir, OpTable0, OpTableOut, State0, StateOut).
handle_parsed_statement(directive(use_module(Spec, Imports), _), Dir, OpTable0, OpTableOut, State0, StateOut, N, N, E, E, Ops, Ops) :- !,
    extract_exported_ops(Imports, SpecifiedOps),
    (   dif(SpecifiedOps, []) ->
        import_module_ops(Spec, Dir, OpTable0, OpTableOut, State0, StateOut)
    ;   OpTableOut = OpTable0,
        StateOut = State0
    ).
handle_parsed_statement(directive(op(P, S, O), _), _Dir, OpTable0, OpTableOut, State, State, N, N, E, E, Ops0, [op(P, S, O)|Ops0]) :- !,
    add_operator(OpTable0, P, S, O, OpTableOut).
handle_parsed_statement(_, _Dir, OpTable, OpTable, State, State, N, N, E, E, Ops, Ops).

import_module_ops(Spec, CurrentDir, OpTable0, OpTableOut, State0, StateOut) :-
    State0 = loader_state(_, SearchPaths, _),
    (   catch((
            resolve_module_path(CurrentDir, SearchPaths, Spec, PathChars),
            load_module_file(PathChars, State0, State1, SubModInfo),
            module_info_ops(SubModInfo, ExportedOps),
            import_exported_ops(ExportedOps, OpTable0, OpTable1)
        ), _, fail) ->
        OpTableOut = OpTable1,
        StateOut = State1
    ;   % If resolution fails or file not found, proceed without crashing or backtracking
        OpTableOut = OpTable0,
        StateOut = State0
    ).

import_exported_ops([], T, T).
import_exported_ops([op(P, S, O)|Rest], T0, TOut) :- !,
    add_operator(T0, P, S, O, T1),
    import_exported_ops(Rest, T1, TOut).
import_exported_ops([_|Rest], T0, TOut) :-
    import_exported_ops(Rest, T0, TOut).

extract_exported_ops([], []).
extract_exported_ops([op(P, S, O)|Rest], [op(P, S, O)|OpsRest]) :- !,
    extract_exported_ops(Rest, OpsRest).
extract_exported_ops([_|Rest], OpsRest) :-
    extract_exported_ops(Rest, OpsRest).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Accessors
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

module_info_name(module_info(Name, _, _, _), Name).
module_info_exports(module_info(_, Exports, _, _), Exports).
module_info_ops(module_info(_, _, Ops, _), Ops).
module_info_statements(module_info(_, _, _, Statements), Statements).
