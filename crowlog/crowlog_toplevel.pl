:- module(crowlog_toplevel, [
    crowlog_toplevel/0,
    crowlog_toplevel/1,
    crowlog_session/4,
    crowlog_toplevel_string/2,
    crowlog_toplevel_string/4,
    crowlog_eval_query/4,
    crowlog_consult/3,
    crowlog_consult/4,
    print_derivation_tree/1,
    derivation_tree_chars/2,
    derivation_tree_//1,
    toplevel_banner_//0,
    toplevel_prompt_//0,
    toplevel_help_//0,
    initial_toplevel_state/1,
    answer_display_//3,
    filter_display_bindings/2,
    print_bindings_//1,
    read_statement_from_stream/3
]).

/** <module> Crowlog Toplevel (REPL)

An interactive toplevel for the Crowlog meta-interpreter with source provenance,
derivation tree inspection, on-demand backtracking, and decoupled I/O streams.

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
:- use_module(library(os)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module('../src/prolog_lexer').
:- use_module('../src/prolog_operator_table', [
    prolog_default_operator_table/1
]).
:- use_module('../src/prolog_reactive_parser').
:- use_module('crowlog.pl').

%% initial_toplevel_state(-State)
%  Initializes an empty toplevel state with default operators and options.
initial_toplevel_state(state(kb([]), ops(OpT), opts([tree(false), trace(false)]))) :-
    prolog_default_operator_table(OpT).

%% crowlog_toplevel
%  Starts the interactive Crowlog REPL on standard input/output streams.
crowlog_toplevel :-
    (   catch(argv(RawArgs), _, RawArgs = []) ->
        true
    ;   RawArgs = []
    ),
    filter_toplevel_cli_args(RawArgs, Args),
    if_(Args = [],
        (   initial_toplevel_state(State0),
            crowlog_toplevel(State0),
            halt(0)
        ),
        (   initial_toplevel_state(State0),
            consult_files(Args, State0, State1, MsgChars),
            format("~s", [MsgChars]),
            flush_output,
            crowlog_toplevel(State1),
            halt(0)
        )).

filter_toplevel_cli_args([], []).
filter_toplevel_cli_args([Arg|Rest], Out) :-
    file_spec_chars(Arg, ArgChars),
    is_toplevel_script_arg_t(ArgChars, ScriptT),
    if_(ScriptT = true,
        filter_toplevel_cli_args(Rest, Out),
        (   Out = [Arg|Tail],
            filter_toplevel_cli_args(Rest, Tail)
        )).

is_toplevel_script_arg_t(Chars, Truth) :-
    if_(Chars = "--",
        Truth = true,
        (   chars_contains_t(Chars, "crowlog_toplevel", C1),
            if_(C1 = true,
                Truth = true,
                (   chars_contains_t(Chars, "bin/crowlog", C2),
                    if_(C2 = true, Truth = true, Truth = false)
                ))
        )).

chars_contains_t(Chars, Sub, Truth) :-
    (   chars_contains(Chars, Sub) ->
        Truth = true
    ;   Truth = false
    ).

chars_contains(Chars, Sub) :-
    append(_, Rest, Chars),
    append(Sub, _, Rest).

%% crowlog_toplevel(+Init)
%  Starts Crowlog with an initial State or a list of files to consult on standard streams.
crowlog_toplevel(state(KB, Ops, Opts)) :-
    current_input(InStream),
    current_output(OutStream),
    crowlog_session(InStream, OutStream, state(KB, Ops, Opts), _).
crowlog_toplevel(Files) :-
    if_(Files = [_|_],
        (   initial_toplevel_state(State0),
            consult_files(Files, State0, State1, MsgChars),
            format("~s", [MsgChars]),
            flush_output,
            crowlog_toplevel(State1)
        ),
        (   initial_toplevel_state(State0),
            crowlog_toplevel(State0)
        )).

%% crowlog_session(+InStream, +OutStream, +State0, -StateFinal)
%  Executes a Crowlog REPL session over the given input and output streams.
crowlog_session(InStream, OutStream, State0, StateFinal) :-
    read_stream_chars(InStream, InChars),
    crowlog_toplevel_string(InChars, State0, OutChars, StateFinal),
    format(OutStream, "~s", [OutChars]),
    flush_output(OutStream).

%% crowlog_loop(+InStream, +OutStream, +State0, -StateFinal)
%  Main REPL evaluation loop reading from InStream and writing to OutStream.
crowlog_loop(InStream, OutStream, State0, StateFinal) :-
    crowlog_session(InStream, OutStream, State0, StateFinal).

read_statement_from_stream(InStream, Lookahead, Chars) :-
    if_(Lookahead = char(C),
        C0 = C,
        get_non_layout_char(InStream, C0)
    ),
    if_(C0 = end_of_file,
        Chars = end_of_file,
        (   Chars = [C0|Rest],
            if_(C0 = (';'),
                Rest = [],
                if_(C0 = ('.'),
                    Rest = [],
                    read_statement_body(InStream, Rest)
                )
            )
        )).

read_statement_body(InStream, Chars) :-
    get_char(InStream, C),
    if_(C = end_of_file,
        Chars = [],
        (   Chars = [C|Rest],
            if_(C = ('.'),
                Rest = [],
                read_statement_body(InStream, Rest)
            )
        )).

%% handle_toplevel_input(+InStream, +OutStream, +Goal, +VarNames, +State0, -State1, -Lookahead)
%  Routes toplevel commands or executes standard queries.
handle_toplevel_input(InStream, OutStream, Goal, VarNames, State0, State1, Lookahead) :-
    is_toplevel_command_t(Goal, IsCmd),
    if_(IsCmd = true,
        (   dispatch_toplevel_command(Goal, State0, State1, MsgChars),
            format(OutStream, "~s", [MsgChars]),
            Lookahead = none
        ),
        (   State1 = State0,
            crowlog_eval_query_interactive(InStream, OutStream, Goal, VarNames, State0, Lookahead)
        )).

is_toplevel_command_t(Goal, Truth) :-
    (   var(Goal) ->
        Truth = false
    ;   if_(Goal = help, Truth = true,
        if_(Goal = listing, Truth = true,
        if_(Goal = listing(_), Truth = true,
        if_(Goal = tree, Truth = true,
        if_(Goal = notree, Truth = true,
        if_(Goal = trace, Truth = true,
        if_(Goal = notrace, Truth = true,
        if_(Goal = consult(_), Truth = true,
        if_(Goal = [_|_], Truth = true,
        Truth = false)))))))))
    ).

dispatch_toplevel_command(help, State, State, OutChars) :-
    phrase(toplevel_help_, OutChars).
dispatch_toplevel_command(listing, State, State, OutChars) :-
    State = state(kb(KB), _, _),
    phrase(listing_clauses_(KB), OutChars).
dispatch_toplevel_command(listing(Spec), State, State, OutChars) :-
    State = state(kb(KB), _, _),
    phrase(listing_clauses_matching_(Spec, KB), OutChars).
dispatch_toplevel_command(tree, state(KB, Ops, opts(Opts0)), state(KB, Ops, opts(Opts1)), OutChars) :-
    set_opt(tree(true), Opts0, Opts1),
    phrase(toplevel_opt_changed_(tree(true)), OutChars).
dispatch_toplevel_command(notree, state(KB, Ops, opts(Opts0)), state(KB, Ops, opts(Opts1)), OutChars) :-
    set_opt(tree(false), Opts0, Opts1),
    phrase(toplevel_opt_changed_(tree(false)), OutChars).
dispatch_toplevel_command(trace, state(KB, Ops, opts(Opts0)), state(KB, Ops, opts(Opts1)), OutChars) :-
    set_opt(trace(true), Opts0, Opts1),
    phrase(toplevel_opt_changed_(trace(true)), OutChars).
dispatch_toplevel_command(notrace, state(KB, Ops, opts(Opts0)), state(KB, Ops, opts(Opts1)), OutChars) :-
    set_opt(trace(false), Opts0, Opts1),
    phrase(toplevel_opt_changed_(trace(false)), OutChars).
dispatch_toplevel_command(consult(File), State0, State1, OutChars) :-
    crowlog_consult(File, State0, State1, OutChars).
dispatch_toplevel_command([File|Files], State0, State1, OutChars) :-
    consult_files([File|Files], State0, State1, OutChars).

%% crowlog_eval_query_interactive(+InStream, +OutStream, +Goal, +VarNames, +State, -Lookahead)
%  Interactively executes Goal with deterministic vs choicepoint-aware answer formatting.
crowlog_eval_query_interactive(InStream, OutStream, Goal, VarNames, State, Lookahead) :-
    State = state(kb(KB), _, opts(Opts)),
    catch(
        findall(ans(Deriv, VarNames), crowlog_interpret(Goal, KB, Deriv), Solutions),
        Error,
        Solutions = exception(Error)
    ),
    if_(Solutions = exception(Err),
        (   phrase(toplevel_error_(Err), ErrChars),
            format(OutStream, "~s", [ErrChars]),
            flush_output(OutStream),
            Lookahead = none
        ),
        if_(Solutions = [],
            (   phrase(toplevel_false_, FalseChars),
                format(OutStream, "~s", [FalseChars]),
                flush_output(OutStream),
                Lookahead = none
            ),
            render_interactive_solutions(InStream, OutStream, Solutions, Opts, Lookahead))).

render_interactive_solutions(_, OutStream, [ans(SingleDeriv, SingleVarNames)], Opts, none) :-
    phrase(answer_display_(SingleVarNames, SingleDeriv, Opts), AnsChars),
    format(OutStream, "~s.~n", [AnsChars]),
    flush_output(OutStream).
render_interactive_solutions(InStream, OutStream, [ans(Deriv1, VarNames1), ans(Deriv2, VarNames2)|More], Opts, Lookahead) :-
    phrase(answer_display_(VarNames1, Deriv1, Opts), AnsChars),
    format(OutStream, "~s", [AnsChars]),
    flush_output(OutStream),
    prompt_user_backtrack(InStream, OutStream, Action),
    if_(Action = next,
        render_interactive_solutions(InStream, OutStream, [ans(Deriv2, VarNames2)|More], Opts, Lookahead),
        (   if_(Action = stop(char(C)),
                Lookahead = char(C),
                Lookahead = none
            )
        )).

%% crowlog_eval_query(+Goal, +VarNames, +State0, -Derivation)
%  Non-interactive query execution, returning the first derivation tree.
crowlog_eval_query(Goal, _, state(kb(KB), _, _), Derivation) :-
    crowlog_interpret(Goal, KB, Derivation).

prompt_user_backtrack(InStream, OutStream, Action) :-
    flush_output(OutStream),
    get_non_layout_char(InStream, C),
    if_(C = (';'),
        (   format(OutStream, ";~n", []),
            flush_output(OutStream),
            Action = next
        ),
        (   format(OutStream, ".~n", []),
            flush_output(OutStream),
            if_(C = ('.'),
                Action = stop(none),
                if_(C = end_of_file,
                    Action = stop(none),
                    Action = stop(char(C))
                )
            )
        )).

get_non_layout_char(InStream, C) :-
    get_char(InStream, C0),
    if_(C0 = end_of_file,
        C = end_of_file,
        (   layout_char_t(C0, LayoutT),
            if_(LayoutT = true,
                get_non_layout_char(InStream, C),
                C = C0)
        )).

answer_display_(VarNames, Derivation, Opts) -->
    { memberd_t(tree(true), Opts, ShowTree),
      filter_display_bindings(VarNames, DisplayBindings),
      if_(DisplayBindings = [], IsEmpty = true, IsEmpty = false) },
    show_tree_(ShowTree, Derivation),
    show_answer_(IsEmpty, DisplayBindings).

filter_display_bindings(VarNames, DisplayBindings) :-
    filter_bindings_aux(VarNames, DisplayBindings).

filter_bindings_aux([], []).
filter_bindings_aux([Name = Val|Rest], Out) :-
    name_to_chars(Name, NameChars),
    write_term_to_chars(Val, [quoted(true)], ValChars),
    var_redundant_t(Val, NameChars, ValChars, RedundantT),
    if_(RedundantT = true,
        filter_bindings_aux(Rest, Out),
        (   Out = [NameChars = ValChars|Tail],
            filter_bindings_aux(Rest, Tail)
        )).

name_to_chars(Name, Chars) :-
    (   atom(Name) ->
        atom_chars(Name, Chars)
    ;   Chars = Name
    ).

var_redundant_t(Val, NameChars, ValChars, T) :-
    (   var(Val) ->
        if_(NameChars = ValChars, T = true, T = false)
    ;   T = false
    ).

show_tree_(true, Derivation) --> derivation_tree_(Derivation).
show_tree_(false, _) --> [].

show_answer_(true, _) --> "true".
show_answer_(false, Bindings) --> print_bindings_(Bindings).

print_bindings_([]) --> [].
print_bindings_([NameChars = ValChars|Rest]) -->
    seq_(NameChars),
    " = ",
    seq_(ValChars),
    print_bindings_rest_(Rest).

print_bindings_rest_([]) --> [].
print_bindings_rest_([NameChars = ValChars|Rest]) -->
    ",\n",
    seq_(NameChars),
    " = ",
    seq_(ValChars),
    print_bindings_rest_(Rest).

seq_([]) --> [].
seq_([E|Es]) --> [E], seq_(Es).

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
derivation_tree_indent_(proof(disjunction(Tree)), Indent) -->
    derivation_tree_indent_(Tree, Indent).
derivation_tree_indent_(proof(if_then_else(then(C, T))), Indent) -->
    derivation_tree_indent_(C, Indent),
    derivation_tree_indent_(T, Indent).
derivation_tree_indent_(proof(if_then_else(else(E))), Indent) -->
    derivation_tree_indent_(E, Indent).
derivation_tree_indent_(proof(if_then(C, T)), Indent) -->
    derivation_tree_indent_(C, Indent),
    derivation_tree_indent_(T, Indent).
derivation_tree_indent_(proof(if_reif(_, then(T))), Indent) -->
    derivation_tree_indent_(T, Indent).
derivation_tree_indent_(proof(if_reif(_, else(E))), Indent) -->
    derivation_tree_indent_(E, Indent).
derivation_tree_indent_(proof(negation(Goal)), Indent) -->
    indent_spaces_(Indent),
    format_("|- \\+ ~q~n", [Goal]).
derivation_tree_indent_(proof(reset(Goal)), Indent) -->
    indent_spaces_(Indent),
    format_("|- reset(~q)~n", [Goal]).
derivation_tree_indent_(proof(shift(Ball)), Indent) -->
    indent_spaces_(Indent),
    format_("|- shift(~q)~n", [Ball]).
derivation_tree_indent_(proof(true), Indent) -->
    indent_spaces_(Indent),
    format_("|- true~n", []).
derivation_tree_indent_(proof(builtin), _) --> [].

indent_spaces_(0) --> [].
indent_spaces_(N) -->
    { N > 0, N1 is N - 1 },
    " ",
    indent_spaces_(N1).

format_span(span(P1, P2), Chars) :-
    !,
    (   pos_coords(P1, L1, C1),
        pos_coords(P2, L2, C2) ->
        phrase(format_("~d:~d - ~d:~d", [L1, C1, L2, C2]), Chars)
    ;   phrase(format_("~w - ~w", [P1, P2]), Chars)
    ).
format_span(builtin, "builtin") :- !.
format_span(no_span, "no_span") :- !.
format_span(Other, Chars) :-
    phrase(format_("~q", [Other]), Chars).

pos_coords(pos(L, C, _, _), L, C).
pos_coords(pos(L, C, _), L, C).
pos_coords(pos(L, C), L, C).
pos_coords(pos_state(L, C, _, _), L, C).
pos_coords(annot(_, L, C, _, _), L, C).

%% crowlog_consult(+FileSpec, +State0, -State1)
%  Parses and loads clauses from FileSpec into the KB, printing confirmation.
crowlog_consult(FileSpec, State0, State1) :-
    crowlog_consult(FileSpec, State0, State1, MsgChars),
    format("~s", [MsgChars]).

%% crowlog_consult(+FileSpec, +State0, -State1, -MsgChars)
%  Parses and loads clauses from FileSpec into the KB, returning confirmation chars.
crowlog_consult(FileSpec, state(kb(KB0), ops(OpT0), opts(Opts)), state(kb(KB1), ops(OpT1), opts(Opts)), MsgChars) :-
    file_spec_chars(FileSpec, PathChars),
    read_file_to_chars(PathChars, Chars),
    phrase(prolog_tokens(Tokens), Chars),
    phrase(prolog_parse_program(OpT0, Clauses, OpT1), Tokens),
    append(KB0, Clauses, KB1),
    length(Clauses, N),
    phrase(toplevel_consult_msg_(PathChars, N), MsgChars).

consult_files([], State, State, "").
consult_files([File|Rest], State0, State2, MsgChars) :-
    crowlog_consult(File, State0, State1, MsgChars1),
    consult_files(Rest, State1, State2, MsgChars2),
    append(MsgChars1, MsgChars2, MsgChars).

file_spec_chars(File, Chars) :-
    name_chars(File, Chars).

name_chars(Name, Chars) :-
    atom_t(Name, AtomT),
    if_(AtomT = true,
        atom_chars(Name, Chars),
        Chars = Name).

atom_t(Term, T) :-
    (  atom(Term) -> T = true
    ;  T = false
    ).

read_file_to_chars(Path, Chars) :-
    open(Path, read, Stream),
    read_stream_chars(Stream, Chars),
    close(Stream).

read_chunk_size(4096).

read_stream_chars(Stream, Chars) :-
    read_chunk_size(ChunkSize),
    get_n_chars(Stream, ChunkSize, Chunk),
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

listing_clauses_([]) --> [].
listing_clauses_([clause(ClauseTerm, Meta)|Rest]) -->
    !,
    format_clause_(ClauseTerm, Meta),
    listing_clauses_(Rest).
listing_clauses_([_|Rest]) -->
    listing_clauses_(Rest).

listing_clauses_matching_(_, []) --> [].
listing_clauses_matching_(Spec, [clause(ClauseTerm, Meta)|Rest]) -->
    !,
    { clause_head(ClauseTerm, Head),
      functor(Head, Name, Arity),
      spec_match_t(Spec, Name, Arity, Matches) },
    match_clause_emit_(Matches, ClauseTerm, Meta),
    listing_clauses_matching_(Spec, Rest).
listing_clauses_matching_(Spec, [_|Rest]) -->
    listing_clauses_matching_(Spec, Rest).

spec_match_t(Spec, Name, Arity, Truth) :-
    if_(Spec = Name,
        Truth = true,
        if_(Spec = Name/Arity, Truth = true, Truth = false)).

match_clause_emit_(true, Term, Meta) --> format_clause_(Term, Meta).
match_clause_emit_(false, _, _) --> [].

clause_head((H :- _), Head) :- !, Head = H.
clause_head(H, H).

format_clause_(Term, Meta) -->
    { extract_meta_span(Meta, Span),
      format_span(Span, SpanChars) },
    format_("~q.  % [~s]~n", [Term, SpanChars]).

set_opt(Opt, [], [Opt]).
set_opt(Opt, [O|Rest], Out) :-
    functor(Opt, Name, _),
    functor(O, OName, _),
    if_(Name = OName,
        Out = [Opt|Rest],
        (   Out = [O|Tail],
            set_opt(Opt, Rest, Tail)
        )).

toplevel_prompt_ --> "crowlog ?- ".

toplevel_banner_ -->
    format_("~n=== Crowlog: Source-Provenance Prolog REPL ===~n", []),
    format_("Type 'help.' for commands, or 'halt.' to exit.~n~n", []).

toplevel_help_ -->
    format_("~nCrowlog Toplevel Commands:~n", []),
    format_("  consult('file.pl'). / ['file.pl'].   Load clauses into KB~n", []),
    format_("  listing.                             List all loaded clauses with spans~n", []),
    format_("  listing(pred). / listing(pred/N).    List clauses for predicate~n", []),
    format_("  tree. / notree.                      Toggle derivation tree display~n", []),
    format_("  trace. / notrace.                    Toggle step execution tracing~n", []),
    format_("  help.                                Display this help text~n", []),
    format_("  halt.                                Exit Crowlog~n~n", []).

toplevel_exit_ -->
    format_("~nExiting Crowlog.~n", []).

toplevel_false_ -->
    format_("false.~n", []).

toplevel_error_(error(Err, Ctx)) -->
    format_("   error(~q, ~q).~n", [Err, Ctx]).
toplevel_error_(error(Err)) -->
    format_("   error(~q).~n", [Err]).
toplevel_error_(Error) -->
    { dif(Error, error(_, _)),
      dif(Error, error(_)) },
    format_("   error(~q).~n", [Error]).

toplevel_opt_changed_(tree(true)) -->
    format_("% Derivation tree display enabled.~n", []).
toplevel_opt_changed_(tree(false)) -->
    format_("% Derivation tree display disabled.~n", []).
toplevel_opt_changed_(trace(true)) -->
    format_("% Execution tracing enabled.~n", []).
toplevel_opt_changed_(trace(false)) -->
    format_("% Execution tracing disabled.~n", []).

toplevel_consult_msg_(PathChars, N) -->
    format_("% Consulted ~s (~d clauses)~n", [PathChars, N]).

%% ============================================================================
%% In-Memory Pure Chars Session Driver
%% ============================================================================

%% crowlog_toplevel_string(+InputChars, -OutputChars)
crowlog_toplevel_string(InputChars, OutputChars) :-
    initial_toplevel_state(State0),
    crowlog_toplevel_string(InputChars, State0, OutputChars, _).

%% crowlog_toplevel_string(+InputChars, +State0, -OutputChars, -StateFinal)
crowlog_toplevel_string(InputChars, State0, OutputChars, StateFinal) :-
    phrase(toplevel_banner_, BannerChars),
    crowlog_loop_chars(InputChars, State0, LoopChars, StateFinal),
    append(BannerChars, LoopChars, OutputChars).

parse_query_from_chars(Chars, OpT, Goal, VarNames, CharsRest) :-
    phrase(clause_tokens(Tokens), Chars, CharsRest),
    prolog_initial_var_state(V0),
    phrase(prolog_parse_term(OpT, 1200, GoalNode, _, V0, VFinal), Tokens, TokRest),
    is_end_tok_rest(TokRest),
    ast_to_raw_term(GoalNode, Goal),
    prolog_var_state_bindings(VFinal, VarNames, _, _).

is_end_tok_rest([end(_)]).
is_end_tok_rest([end]).

is_halt_t(Goal, Truth) :-
    (   var(Goal) ->
        Truth = false
    ;   =(Goal, halt, Truth)
    ).

is_eof_t(Goal, Truth) :-
    (   var(Goal) ->
        Truth = false
    ;   =(Goal, end_of_file, Truth)
    ).

crowlog_loop_chars(Chars0, State0, OutChars, StateFinal) :-
    phrase(skip_layout_, Chars0, Chars1),
    if_(Chars1 = [],
        (   phrase(toplevel_exit_, ExitChars),
            OutChars = ExitChars,
            StateFinal = State0
        ),
        (   State0 = state(kb(_), ops(OpT0), opts(_)),
            (   parse_query_from_chars(Chars1, OpT0, Goal, VarNames, CharsRest)
            ->  is_halt_t(Goal, HaltT),
                if_(HaltT = true,
                    (   phrase(toplevel_prompt_, PromptChars),
                        phrase(toplevel_exit_, ExitChars),
                        append(PromptChars, ExitChars, OutChars),
                        StateFinal = State0
                    ),
                    (   is_eof_t(Goal, EofT),
                        if_(EofT = true,
                            (   phrase(toplevel_prompt_, PromptChars),
                                phrase(toplevel_exit_, ExitChars),
                                append(PromptChars, ExitChars, OutChars),
                                StateFinal = State0
                            ),
                            (   phrase(toplevel_prompt_, PromptChars),
                                handle_toplevel_input_chars(Goal, VarNames, CharsRest, State0, StepOutChars, CharsNext, State1),
                                append(PromptChars, StepOutChars, HeaderChars),
                                crowlog_loop_chars(CharsNext, State1, TailChars, StateFinal),
                                append(HeaderChars, TailChars, OutChars)
                            )
                        )
                    ))
            ;   phrase(toplevel_prompt_, PromptChars),
                phrase(format_("   error(syntax_error(cannot_parse_term), toplevel:query).~n", []), ErrChars),
                append(PromptChars, ErrChars, HeaderChars),
                skip_past_dot(Chars1, CharsRest),
                crowlog_loop_chars(CharsRest, State0, TailChars, StateFinal),
                append(HeaderChars, TailChars, OutChars)
            )
        )).

skip_past_dot([], []).
skip_past_dot(['.'|Rest], Rest) :- !.
skip_past_dot([_|Rest], Out) :-
    skip_past_dot(Rest, Out).

handle_toplevel_input_chars(Goal, VarNames, CharsIn, State0, OutChars, CharsOut, State1) :-
    is_toplevel_command_t(Goal, IsCmd),
    if_(IsCmd = true,
        (   dispatch_toplevel_command(Goal, State0, State1, OutChars),
            CharsOut = CharsIn
        ),
        (   State1 = State0,
            crowlog_eval_query_chars(Goal, VarNames, CharsIn, State0, OutChars, CharsOut)
        )).

crowlog_eval_query_chars(Goal, VarNames, CharsIn, State, OutChars, CharsOut) :-
    State = state(kb(KB), _, opts(Opts)),
    catch(
        findall(ans(Deriv, VarNames), crowlog_interpret(Goal, KB, Deriv), Solutions),
        Error,
        Solutions = exception(Error)
    ),
    if_(Solutions = exception(Err),
        (   phrase(toplevel_error_(Err), OutChars),
            CharsOut = CharsIn
        ),
        if_(Solutions = [],
            (   phrase(toplevel_false_, OutChars),
                CharsOut = CharsIn
            ),
            render_solutions_chars(Solutions, Opts, CharsIn, OutChars, CharsOut))).

render_solutions_chars([], _, CharsIn, OutChars, CharsIn) :-
    phrase(toplevel_false_, OutChars).
render_solutions_chars([ans(Deriv, VarNames)], Opts, CharsIn, OutChars, CharsOut) :-
    phrase(answer_display_(VarNames, Deriv, Opts), AnsChars),
    phrase(format_(".~n", []), DotChars),
    append(AnsChars, DotChars, OutChars),
    CharsOut = CharsIn.
render_solutions_chars([ans(Deriv, VarNames), NextAns|Rest], Opts, CharsIn, OutChars, CharsOut) :-
    phrase(answer_display_(VarNames, Deriv, Opts), AnsChars),
    phrase(skip_layout_, CharsIn, CharsTrimmed),
    if_(head_is_semi_t(CharsTrimmed),
        (   CharsTrimmed = [';'|CharsAfterSemi],
            phrase(format_(";~n", []), SemiChars),
            render_solutions_chars([NextAns|Rest], Opts, CharsAfterSemi, RestOutChars, CharsOut),
            append(AnsChars, SemiChars, Prefix),
            append(Prefix, RestOutChars, OutChars)
        ),
        (   phrase(format_(".~n", []), DotChars),
            append(AnsChars, DotChars, OutChars),
            CharsOut = CharsTrimmed
        )).

head_is_semi_t([], false).
head_is_semi_t([C|_], Truth) :-
    =(C, ';', Truth).

skip_layout_ --> " ", !, skip_layout_.
skip_layout_ --> "\t", !, skip_layout_.
skip_layout_ --> "\n", !, skip_layout_.
skip_layout_ --> "\r", !, skip_layout_.
skip_layout_ --> [].

layout_char_t(C, T) :-
    if_(C = ' ', T = true,
    if_(C = '\t', T = true,
    if_(C = '\n', T = true,
    if_(C = '\r', T = true,
    T = false)))).
