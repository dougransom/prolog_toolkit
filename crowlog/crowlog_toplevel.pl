:- module(crowlog_toplevel, [
    crowlog_toplevel/0,
    crowlog_toplevel/1,
    crowlog_eval_query/4,
    crowlog_consult/3,
    print_derivation_tree/1,
    derivation_tree_chars/2,
    derivation_tree_//1,
    initial_toplevel_state/1
]).

/** <module> Crowlog Toplevel (REPL)

An interactive toplevel for the Crowlog meta-interpreter with source provenance,
derivation tree inspection, and on-demand backtracking.

Commands:
- consult(File) or [File]: load Prolog clauses into the in-memory KB
- listing or listing(Pred): display loaded clauses
- tree / notree: toggle printing derivation proof trees with source spans
- trace / notrace: toggle step tracing
- halt: exit Crowlog
*/

:- use_module(library(charsio)).
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(format)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module('../src/prolog_toolkit').
:- use_module('crowlog').

%% initial_toplevel_state(-State)
%  Initializes an empty toplevel state with default operators and options.
initial_toplevel_state(state(kb([]), ops(OpT), opts([tree(false), trace(false)]))) :-
    prolog_default_operator_table(OpT).

%% crowlog_toplevel
%  Starts the interactive Crowlog REPL on the standard terminal.
crowlog_toplevel :-
    initial_toplevel_state(State0),
    crowlog_toplevel(State0).

%% crowlog_toplevel(+Init)
%  Starts Crowlog with an initial State or a list of files to consult.
crowlog_toplevel(state(KB, Ops, Opts)) :-
    format("~n=== Crowlog: Source-Provenance Prolog REPL ===~n", []),
    format("Type 'help.' for commands, or 'halt.' to exit.~n~n", []),
    toplevel_loop(state(KB, Ops, Opts)).
crowlog_toplevel(Files) :-
    if_(Files = [_|_],
        (   initial_toplevel_state(State0),
            consult_files(Files, State0, State1),
            crowlog_toplevel(State1)
        ),
        (   initial_toplevel_state(State0),
            crowlog_toplevel(State0)
        )).

toplevel_loop(State0) :-
    format("crowlog ?- ", []),
    read_term(Goal, [variable_names(VarNames)]),
    if_(Goal = end_of_file,
        format("~nExiting Crowlog.~n", []),
        if_(Goal = halt,
            format("~nExiting Crowlog.~n", []),
            (   handle_toplevel_input(Goal, VarNames, State0, State1),
                toplevel_loop(State1)
            ))).

%% handle_toplevel_input(+Goal, +VarNames, +State0, -State1)
%  Routes toplevel commands or executes standard queries.
handle_toplevel_input(help, _, State, State) :-
    print_help.
handle_toplevel_input(listing, _, State, State) :-
    State = state(kb(KB), _, _),
    listing_clauses(KB).
handle_toplevel_input(listing(Spec), _, State, State) :-
    State = state(kb(KB), _, _),
    listing_clauses_matching(Spec, KB).
handle_toplevel_input(tree, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(tree(true), Opts0, Opts1),
    format("% Derivation tree display enabled.~n", []).
handle_toplevel_input(notree, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(tree(false), Opts0, Opts1),
    format("% Derivation tree display disabled.~n", []).
handle_toplevel_input(trace, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(trace(true), Opts0, Opts1),
    format("% Execution tracing enabled.~n", []).
handle_toplevel_input(notrace, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(trace(false), Opts0, Opts1),
    format("% Execution tracing disabled.~n", []).
handle_toplevel_input(consult(File), _, State0, State1) :-
    crowlog_consult(File, State0, State1).
handle_toplevel_input([File|Files], _, State0, State1) :-
    consult_files([File|Files], State0, State1).
handle_toplevel_input(Goal, VarNames, State, State) :-
    dif(Goal, help),
    dif(Goal, listing),
    dif(Goal, listing(_)),
    dif(Goal, tree),
    dif(Goal, notree),
    dif(Goal, trace),
    dif(Goal, notrace),
    dif(Goal, consult(_)),
    dif(Goal, [_|_]),
    crowlog_eval_query_interactive(Goal, VarNames, State).

%% crowlog_eval_query_interactive(+Goal, +VarNames, +State)
%  Interactively executes Goal with on-demand backtracking prompt.
crowlog_eval_query_interactive(Goal, VarNames, State) :-
    State = state(kb(KB), _, opts(Opts)),
    (   crowlog_interpret(Goal, KB, Derivation),
        display_answer(VarNames, Derivation, Opts),
        prompt_user_backtrack(Action),
        if_(Action = next,
            fail,
            true)
    ;   format("false.~n", [])
    ).

%% crowlog_eval_query(+Goal, +VarNames, +State0, -Derivation)
%  Non-interactive query execution, returning the first derivation tree.
crowlog_eval_query(Goal, _, state(kb(KB), _, _), Derivation) :-
    crowlog_interpret(Goal, KB, Derivation).

prompt_user_backtrack(Action) :-
    get_single_char(C),
    if_(C = (';'),
        (   format(";~n", []),
            Action = next
        ),
        if_(C = ' ',
            (   format(";~n", []),
                Action = next
            ),
            (   format("~n", []),
                Action = stop
            ))).

display_answer(VarNames, Derivation, Opts) :-
    if_(memberd_t(tree(true), Opts),
        print_derivation_tree(Derivation),
        true),
    if_(VarNames = [],
        format("true", []),
        print_bindings(VarNames)).

print_bindings([]).
print_bindings([Name = Val|Rest]) :-
    format("~s = ~q", [Name, Val]),
    if_(Rest = [],
        true,
        (   format(",~n", []),
            print_bindings(Rest)
        )).

%% print_derivation_tree(+Tree)
%  Pretty-prints a Crowlog proof tree with source locations.
print_derivation_tree(Tree) :-
    phrase(derivation_tree_(Tree), Chars),
    format("~s", [Chars]).

%% derivation_tree_chars(+Tree, -Chars)
%  Renders a Crowlog derivation tree to a list of characters.
derivation_tree_chars(Tree, Chars) :-
    phrase(derivation_tree_(Tree), Chars).

derivation_tree_(Tree) -->
    format_("~n  --- Derivation Tree ---~n", []),
    derivation_tree_indent_(Tree, 2).

derivation_tree_indent_(proof(step(Goal, Span, BodyTree)), Indent) -->
    indent_spaces_(Indent),
    { format_span(Span, SpanChars) },
    format_("|- ~q  (~s)~n", [Goal, SpanChars]),
    { Indent1 is Indent + 2 },
    derivation_tree_indent_(BodyTree, Indent1).
derivation_tree_indent_(proof(conjunction(TreeA, TreeB)), Indent) -->
    derivation_tree_indent_(TreeA, Indent),
    derivation_tree_indent_(TreeB, Indent).
derivation_tree_indent_(proof(true), Indent) -->
    indent_spaces_(Indent),
    format_("|- true~n", []).
derivation_tree_indent_(proof(builtin), _) --> [].
derivation_tree_indent_(Other, Indent) -->
    { dif(Other, proof(step(_, _, _))),
      dif(Other, proof(conjunction(_, _))),
      dif(Other, proof(true)),
      dif(Other, proof(builtin)) },
    indent_spaces_(Indent),
    format_("|- ~q~n", [Other]).

indent_spaces_(N) -->
    { length(Spaces, N),
      maplist(=(' '), Spaces) },
    format_("~s", [Spaces]).

format_span(span(P1, P2), Chars) :-
    pos_line(P1, L1), pos_col(P1, C1),
    pos_line(P2, L2), pos_col(P2, C2),
    phrase(format_("~d:~d - ~d:~d", [L1, C1, L2, C2]), Chars).
format_span(builtin, "builtin").
format_span(no_span, "no_span").
format_span(Other, Chars) :-
    dif(Other, span(_, _)),
    dif(Other, builtin),
    dif(Other, no_span),
    phrase(format_("~q", [Other]), Chars).

%% crowlog_consult(+FileSpec, +State0, -State1)
%  Parses and loads clauses from FileSpec into the KB.
crowlog_consult(FileSpec, state(kb(KB0), ops(OpT0), opts(Opts)), state(kb(KB1), ops(OpT1), opts(Opts))) :-
    file_spec_chars(FileSpec, PathChars),
    read_file_to_chars(PathChars, Chars),
    phrase(prolog_tokens(Tokens), Chars),
    phrase(prolog_parse_program(OpT0, Clauses, OpT1), Tokens),
    append(KB0, Clauses, KB1),
    length(Clauses, N),
    format("% Consulted ~s (~d clauses)~n", [PathChars, N]).

consult_files([], State, State).
consult_files([File|Rest], State0, State2) :-
    crowlog_consult(File, State0, State1),
    consult_files(Rest, State1, State2).

file_spec_chars(File, Chars) :-
    if_(atom(File),
        atom_chars(File, Chars),
        Chars = File).

read_file_to_chars(Path, Chars) :-
    open(Path, read, Stream),
    read_stream_chars(Stream, Chars),
    close(Stream).

read_stream_chars(Stream, Chars) :-
    get_n_chars(Stream, 4096, Chunk),
    if_(Chunk = [],
        Chars = [],
        (   Chars = [C|Rest],
            Chunk = [C|ChunkRest],
            read_stream_chars_chunk(ChunkRest, Stream, Rest)
        )).

read_stream_chars_chunk([], Stream, Rest) :-
    read_stream_chars(Stream, Rest).
read_stream_chars_chunk([C|Cs], Stream, [C|Rest]) :-
    read_stream_chars_chunk(Cs, Stream, Rest).

listing_clauses([]).
listing_clauses([clause(ClauseTerm, Meta)|Rest]) :-
    format_clause(ClauseTerm, Meta),
    listing_clauses(Rest).
listing_clauses([_|Rest]) :-
    listing_clauses(Rest).

listing_clauses_matching(_, []).
listing_clauses_matching(Spec, [clause(ClauseTerm, Meta)|Rest]) :-
    clause_head(ClauseTerm, Head),
    functor(Head, Name, Arity),
    if_((Spec = Name ; Spec = Name/Arity),
        format_clause(ClauseTerm, Meta),
        true),
    listing_clauses_matching(Spec, Rest).
listing_clauses_matching(Spec, [_|Rest]) :-
    listing_clauses_matching(Spec, Rest).

clause_head((H :- _), H).
clause_head(H, H) :- dif(H, (_ :- _)).

format_clause(Term, Meta) :-
    extract_meta_span(Meta, Span),
    format_span(Span, SpanChars),
    format("~q.  % [~s]~n", [Term, SpanChars]).

set_opt(Opt, [], [Opt]).
set_opt(Opt, [O|Rest], Out) :-
    functor(Opt, Name, _),
    functor(O, OName, _),
    if_(Name = OName,
        Out = [Opt|Rest],
        (   Out = [O|Tail],
            set_opt(Opt, Rest, Tail)
        )).

print_help :-
    format("~nCrowlog Toplevel Commands:~n\
  consult('file.pl'). / ['file.pl'].   Load clauses into KB~n\
  listing.                             List all loaded clauses with spans~n\
  listing(pred). / listing(pred/N).    List clauses for predicate~n\
  tree. / notree.                      Toggle derivation tree display~n\
  trace. / notrace.                    Toggle step execution tracing~n\
  help.                                Display this help text~n\
  halt.                                Exit Crowlog~n~n", []).
