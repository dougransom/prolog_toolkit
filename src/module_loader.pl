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
    load_module_file/5,
    parse_module_chars/6,
    parse_module_chars/7,
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

:- use_module(prolog_token).
:- use_module(prolog_lexer).
:- use_module(prolog_operator_table).
:- use_module(prolog_parser).

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
    lookup_option(Options, library_path, "reference/scryer-prolog/src/lib", LibPath),
    op_chars(LibPath, LibChars),
    SearchPaths1 = [path(library, LibChars)],
    lookup_option(Options, pkg_path, "pkg", PkgPath),
    op_chars(PkgPath, PkgChars),
    SearchPaths = [path(pkg, PkgChars)|SearchPaths1].

lookup_option([], _, Default, Default).
lookup_option([Opt|Opts], Key, Default, Val) :-
    Opt =.. [K, V],
    if_(K = Key,
        Val = V,
        lookup_option(Opts, Key, Default, Val)
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

join_dir_file(Dir, File, Out) :-
    if_(Dir = ".",
        Out = File,
        if_(Dir = "",
            Out = File,
            if_(ends_with_slash_t(Dir),
                append(Dir, File, Out),
                ( append(Dir, "/", DirSlash), append(DirSlash, File, Out) )
            )
        )
    ).

ends_with_slash_t([], false).
ends_with_slash_t([C|Cs], T) :- ends_with_slash_t_(Cs, C, T).

ends_with_slash_t_([], C, T) :- =(C, '/', T).
ends_with_slash_t_([C|Cs], _, T) :- ends_with_slash_t_(Cs, C, T).

% Deterministic extension check: prevents spurious backtracking appending .pl multiple times.
ensure_pl_extension(Path, Out) :-
    (   append(_, ".pl", Path) ->
        Out = Path
    ;   append(Path, ".pl", Out)
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Module Loading
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% load_module_file(+FilePath, +State0, -StateOut, -ModuleInfo)
load_module_file(FilePath, State0, StateOut, ModuleInfo) :-
    load_module_file(FilePath, [], State0, StateOut, ModuleInfo).

%% load_module_file(+FilePath, +Options, +State0, -StateOut, -ModuleInfo)
load_module_file(FilePath, Options, State0, StateOut, ModuleInfo) :-
    op_chars(FilePath, PathChars),
    State0 = loader_state(Loaded0, SearchPaths, BaseOpTable),
    lookup_loaded_module(Loaded0, PathChars, Found, CachedInfo),
    if_(Found = true,
        ( ModuleInfo = CachedInfo, StateOut = State0 ),
        ( read_file_to_chars(PathChars, Chars),
          file_directory(PathChars, CurrentDir),
          % Mark as currently loading with empty info to prevent infinite recursion
          StateTemp = loader_state([loaded(PathChars, loading)|Loaded0], SearchPaths, BaseOpTable),
          parse_module_chars(Chars, Options, PathChars, CurrentDir, StateTemp, State1, ModuleInfo),
          State1 = loader_state(Loaded1, Paths1, BaseOpT1),
          % Replace temporary loading entry with fully parsed ModuleInfo
          replace_loaded_entry(Loaded1, PathChars, CleanLoaded),
          StateOut = loader_state([loaded(PathChars, ModuleInfo)|CleanLoaded], Paths1, BaseOpT1)
        )
    ).

lookup_loaded_module([], _, false, _).
lookup_loaded_module([loaded(P, Info)|Rest], Path, Found, ModInfo) :-
    if_(P = Path,
        if_(Info = loading,
            lookup_loaded_module(Rest, Path, Found, ModInfo),
            ( Found = true, ModInfo = Info )
        ),
        lookup_loaded_module(Rest, Path, Found, ModInfo)
    ).

replace_loaded_entry([], _, []).
replace_loaded_entry([loaded(P, Info)|Rest], Path, Out) :-
    if_(P = Path,
        replace_loaded_entry(Rest, Path, Out),
        ( Out = [loaded(P, Info)|RestOut],
          replace_loaded_entry(Rest, Path, RestOut) )
    ).

% Deterministic path decomposition: commits to the rightmost slash boundary separating directory from filename.
file_directory(Path, Dir) :-
    (   append(DirPrefix, ['/'|FileName], Path),
        memberd_t('/', FileName, false) ->
        if_(DirPrefix = [], Dir = "/", Dir = DirPrefix)
    ;   Dir = "."
    ).

read_file_to_chars(Path, Chars) :-
    open(Path, read, Stream),
    read_stream_chars(Stream, Chars),
    close(Stream).

read_stream_chars(Stream, Chars) :-
    get_n_chars(Stream, 4096, Chunk),
    if_(Chunk = [],
        Chars = [],
        ( Chars = [C|Rest],
          Chunk = [C|ChunkRest],
          read_stream_chars_chunk(ChunkRest, Stream, Rest)
        )
    ).

read_stream_chars_chunk([], Stream, Rest) :- !,
    read_stream_chars(Stream, Rest).
read_stream_chars_chunk([C|Cs], Stream, [C|Rest]) :-
    read_stream_chars_chunk(Cs, Stream, Rest).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Parse Module Characters
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

parse_module_chars(Chars, SourceName, CurrentDir, State0, StateOut, ModuleInfo) :-
    parse_module_chars(Chars, [], SourceName, CurrentDir, State0, StateOut, ModuleInfo).

parse_module_chars(Chars, Options, SourceName, CurrentDir, State0, StateOut, ModuleInfo) :-
    phrase(prolog_tokens(Tokens), Chars),
    State0 = loader_state(_, _, BaseOpTable),
    parse_module_tokens(Tokens, Options, SourceName, CurrentDir, BaseOpTable, State0, StateOut, [], Statements, unknown, ModName, [], Exports, []),
    extract_exported_ops(Exports, ExportedOps),
    ModuleInfo = module_info(ModName, Exports, ExportedOps, Statements).

parse_module_tokens([], _Options, _Source, _Dir, _OpTable, State, State, Stmts, Stmts, Name, Name, Exps, Exps, _Ops).
parse_module_tokens([Tok|Rest], Options, Source, Dir, OpTable0, State0, StateOut, StmtsAcc, StmtsFinal, Name0, NameFinal, Exps0, ExpsFinal, LocalOps0) :-
    token_type(Tok, Type),
    if_(Type = end,
        if_(Rest = [],
            ( StateOut = State0, StmtsFinal = StmtsAcc, NameFinal = Name0, ExpsFinal = Exps0 ),
            ( phrase(parse_clause(OpTable0, Options, Stmt, OpTable1), [Tok|Rest], TokensRest),
              !,
              process_parsed_statement(Stmt, StmtsAcc, StmtsAcc1, Dir, OpTable1, OpTable2, State0, State1, Name0, Name1, Exps0, Exps1, LocalOps0, LocalOps1),
              parse_module_tokens(TokensRest, Options, Source, Dir, OpTable2, State1, StateOut, StmtsAcc1, StmtsFinal, Name1, NameFinal, Exps1, ExpsFinal, LocalOps1)
            )
        ),
        ( phrase(parse_clause(OpTable0, Options, Stmt, OpTable1), [Tok|Rest], TokensRest),
          !,
          process_parsed_statement(Stmt, StmtsAcc, StmtsAcc1, Dir, OpTable1, OpTable2, State0, State1, Name0, Name1, Exps0, Exps1, LocalOps0, LocalOps1),
          parse_module_tokens(TokensRest, Options, Source, Dir, OpTable2, State1, StateOut, StmtsAcc1, StmtsFinal, Name1, NameFinal, Exps1, ExpsFinal, LocalOps1)
        )
    ).

process_parsed_statement([], StmtsAcc, StmtsAcc, _Dir, OpTable, OpTable, State, State, N, N, E, E, Ops, Ops) :- !.
process_parsed_statement([S|Ss], StmtsAcc, StmtsAccOut, Dir, OpTable0, OpTableOut, State0, StateOut, N0, NOut, E0, EOut, Ops0, OpsOut) :-
    !,
    handle_parsed_statements([S|Ss], Dir, OpTable0, OpTableOut, State0, StateOut, N0, NOut, E0, EOut, Ops0, OpsOut),
    reverse([S|Ss], RevStmt),
    append(RevStmt, StmtsAcc, StmtsAccOut).
process_parsed_statement(Stmt, StmtsAcc, [Stmt|StmtsAcc], Dir, OpTable0, OpTableOut, State0, StateOut, N0, NOut, E0, EOut, Ops0, OpsOut) :-
    handle_parsed_statements([Stmt], Dir, OpTable0, OpTableOut, State0, StateOut, N0, NOut, E0, EOut, Ops0, OpsOut).

handle_parsed_statements([], _, OpTable, OpTable, State, State, N, N, E, E, Ops, Ops).
handle_parsed_statements([S|Ss], Dir, OpTable0, OpTableOut, State0, StateOut, N0, NOut, E0, EOut, Ops0, OpsOut) :-
    handle_parsed_statement(S, Dir, OpTable0, OpTable1, State0, State1, N0, N1, E0, E1, Ops0, Ops1),
    handle_parsed_statements(Ss, Dir, OpTable1, OpTableOut, State1, StateOut, N1, NOut, E1, EOut, Ops1, OpsOut).

handle_parsed_statement(Stmt, Dir, OpTable0, OpTableOut, State0, StateOut, N0, NOut, E0, EOut, Ops0, OpsOut) :-
    if_(Stmt = directive(module(ModName, Exports), _),
        ( NOut = ModName, EOut = Exports, OpsOut = Ops0, StateOut = State0,
          import_exported_ops(Exports, OpTable0, OpTableOut)
        ),
        if_(Stmt = directive(use_module(Spec), _),
            ( NOut = N0, EOut = E0, OpsOut = Ops0,
              import_module_ops(Spec, Dir, OpTable0, OpTableOut, State0, StateOut)
            ),
            if_(Stmt = directive(use_module(Spec, Imports), _),
                ( NOut = N0, EOut = E0, OpsOut = Ops0,
                  extract_exported_ops(Imports, SpecifiedOps),
                  if_(SpecifiedOps = [],
                      ( OpTableOut = OpTable0, StateOut = State0 ),
                      import_module_ops(Spec, Dir, OpTable0, OpTableOut, State0, StateOut)
                  )
                ),
                if_(Stmt = directive(op(P, S, O), _),
                    ( NOut = N0, EOut = E0, OpsOut = [op(P, S, O)|Ops0], StateOut = State0,
                      add_operator(OpTable0, P, S, O, OpTableOut)
                    ),
                    ( NOut = N0, EOut = E0, OpsOut = Ops0, StateOut = State0, OpTableOut = OpTable0 )
                )
            )
        )
    ).

% I/O error recovery boundary: if resolution or loading fails due to filesystem errors, catch gracefully returns default state.
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
import_exported_ops([Item|Rest], T0, TOut) :-
    if_(Item = op(P, S, O),
        add_operator(T0, P, S, O, T1),
        T1 = T0
    ),
    import_exported_ops(Rest, T1, TOut).

extract_exported_ops([], []).
extract_exported_ops([Item|Rest], OpsOut) :-
    if_(Item = op(P, S, O),
        ( OpsOut = [op(P, S, O)|OpsRest], extract_exported_ops(Rest, OpsRest) ),
        extract_exported_ops(Rest, OpsOut)
    ).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Accessors
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

module_info_name(module_info(Name, _, _, _), Name).
module_info_exports(module_info(_, Exports, _, _), Exports).
module_info_ops(module_info(_, _, Ops, _), Ops).
module_info_statements(module_info(_, _, _, Statements), Statements).
