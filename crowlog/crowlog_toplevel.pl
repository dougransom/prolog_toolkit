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
    initial_toplevel_state/1
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
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module('../../parser_experiments/src/annotate_position', [
    pos_line/2,
    pos_col/2
]).
:- use_module('../src/prolog_lexer', [
    prolog_tokens//1,
    clause_tokens//1
]).
:- use_module('../src/prolog_operator_table', [
    prolog_default_operator_table/1
]).
:- use_module('../src/prolog_reactive_parser', [
    prolog_parse_program//3,
    prolog_parse_term//6,
    prolog_initial_var_state/1,
    prolog_var_state_bindings/4
]).
:- use_module('crowlog.pl').

%% initial_toplevel_state(-State)
%  Initializes an empty toplevel state with default operators and options.
initial_toplevel_state(state(kb([]), ops(OpT), opts([tree(false), trace(false)]))) :-
    prolog_default_operator_table(OpT).

%% crowlog_toplevel
%  Starts the interactive Crowlog REPL on standard input/output streams.
crowlog_toplevel :-
    initial_toplevel_state(State0),
    crowlog_toplevel(State0).

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
    phrase(toplevel_banner_, BannerChars),
    format(OutStream, "~s", [BannerChars]),
    flush_output(OutStream),
    crowlog_loop(InStream, OutStream, State0, StateFinal).

%% crowlog_loop(+InStream, +OutStream, +State0, -StateFinal)
%  Main REPL evaluation loop reading from InStream and writing to OutStream.
crowlog_loop(InStream, OutStream, State0, StateFinal) :-
    phrase(toplevel_prompt_, PromptChars),
    format(OutStream, "~s", [PromptChars]),
    flush_output(OutStream),
    catch(
        read_term(InStream, Goal0, [variable_names(VarNames0)]),
        ReadError,
        Goal0 = error(ReadError)
    ),
    if_(Goal0 = error(ReadErr),
        (   format(OutStream, "Syntax error: ~q~n", [ReadErr]),
            flush_output(OutStream),
            crowlog_loop(InStream, OutStream, State0, StateFinal)
        ),
        (   Goal = Goal0,
            VarNames = VarNames0,
            if_(Goal = end_of_file,
                (   phrase(toplevel_exit_, ExitChars),
                    format(OutStream, "~s", [ExitChars]),
                    flush_output(OutStream),
                    StateFinal = State0
                ),
                if_(Goal = halt,
                    (   phrase(toplevel_exit_, ExitChars),
                        format(OutStream, "~s", [ExitChars]),
                        flush_output(OutStream),
                        StateFinal = State0
                    ),
                    (   handle_toplevel_input(InStream, OutStream, Goal, VarNames, State0, State1),
                        flush_output(OutStream),
                        crowlog_loop(InStream, OutStream, State1, StateFinal)
                    )))
        )).

%% handle_toplevel_input(+InStream, +OutStream, +Goal, +VarNames, +State0, -State1)
%  Routes toplevel commands or executes standard queries.
handle_toplevel_input(_, OutStream, help, _, State, State) :-
    phrase(toplevel_help_, Chars),
    format(OutStream, "~s", [Chars]).
handle_toplevel_input(_, OutStream, listing, _, State, State) :-
    State = state(kb(KB), _, _),
    phrase(listing_clauses_(KB), Chars),
    format(OutStream, "~s", [Chars]).
handle_toplevel_input(_, OutStream, listing(Spec), _, State, State) :-
    State = state(kb(KB), _, _),
    phrase(listing_clauses_matching_(Spec, KB), Chars),
    format(OutStream, "~s", [Chars]).
handle_toplevel_input(_, OutStream, tree, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(tree(true), Opts0, Opts1),
    phrase(toplevel_opt_changed_(tree(true)), Chars),
    format(OutStream, "~s", [Chars]).
handle_toplevel_input(_, OutStream, notree, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(tree(false), Opts0, Opts1),
    phrase(toplevel_opt_changed_(tree(false)), Chars),
    format(OutStream, "~s", [Chars]).
handle_toplevel_input(_, OutStream, trace, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(trace(true), Opts0, Opts1),
    phrase(toplevel_opt_changed_(trace(true)), Chars),
    format(OutStream, "~s", [Chars]).
handle_toplevel_input(_, OutStream, notrace, _, state(KB, Ops, Opts0), state(KB, Ops, Opts1)) :-
    set_opt(trace(false), Opts0, Opts1),
    phrase(toplevel_opt_changed_(trace(false)), Chars),
    format(OutStream, "~s", [Chars]).
handle_toplevel_input(_, OutStream, consult(File), _, State0, State1) :-
    crowlog_consult(File, State0, State1, MsgChars),
    format(OutStream, "~s", [MsgChars]).
handle_toplevel_input(_, OutStream, [File|Files], _, State0, State1) :-
    consult_files([File|Files], State0, State1, MsgChars),
    format(OutStream, "~s", [MsgChars]).
handle_toplevel_input(InStream, OutStream, Goal, VarNames, State, State) :-
    dif(Goal, help),
    dif(Goal, listing),
    dif(Goal, listing(_)),
    dif(Goal, tree),
    dif(Goal, notree),
    dif(Goal, trace),
    dif(Goal, notrace),
    dif(Goal, consult(_)),
    dif(Goal, [_|_]),
    crowlog_eval_query_interactive(InStream, OutStream, Goal, VarNames, State).

%% crowlog_eval_query_interactive(+InStream, +OutStream, +Goal, +VarNames, +State)
%  Interactively executes Goal with on-demand backtracking prompt.
crowlog_eval_query_interactive(InStream, OutStream, Goal, VarNames, State) :-
    State = state(kb(KB), _, opts(Opts)),
    catch(
        (   crowlog_interpret(Goal, KB, Derivation),
            phrase(answer_display_(VarNames, Derivation, Opts), AnsChars),
            format(OutStream, "~s", [AnsChars]),
            prompt_user_backtrack(InStream, OutStream, Action),
            if_(Action = next,
                fail,
                true)
        ;   phrase(toplevel_false_, FalseChars),
            format(OutStream, "~s", [FalseChars])
        ),
        Error,
        (   phrase(toplevel_error_(Error), ErrChars),
            format(OutStream, "~s", [ErrChars])
        )
    ).

%% crowlog_eval_query(+Goal, +VarNames, +State0, -Derivation)
%  Non-interactive query execution, returning the first derivation tree.
crowlog_eval_query(Goal, _, state(kb(KB), _, _), Derivation) :-
    crowlog_interpret(Goal, KB, Derivation).

prompt_user_backtrack(InStream, OutStream, Action) :-
    flush_output(OutStream),
    get_char(InStream, C),
    if_(C = end_of_file,
        (   format(OutStream, "~n", []),
            flush_output(OutStream),
            Action = stop
        ),
        if_(C = (';'),
            (   format(OutStream, ";~n", []),
                flush_output(OutStream),
                Action = next
            ),
            if_(C = ' ',
                (   format(OutStream, ";~n", []),
                    flush_output(OutStream),
                    Action = next
                ),
                (   format(OutStream, "~n", []),
                    flush_output(OutStream),
                    Action = stop
                )))).

answer_display_(VarNames, Derivation, Opts) -->
    { if_(memberd_t(tree(true), Opts), ShowTree = true, ShowTree = false),
      if_(VarNames = [], IsEmpty = true, IsEmpty = false) },
    show_tree_(ShowTree, Derivation),
    show_answer_(IsEmpty, VarNames).

show_tree_(true, Derivation) --> derivation_tree_(Derivation).
show_tree_(false, _) --> [].

show_answer_(true, _) --> format_("true", []).
show_answer_(false, VarNames) --> print_bindings_(VarNames).

print_bindings_([]) --> [].
print_bindings_([Name = Val|Rest]) -->
    { name_chars(Name, Chars) },
    format_("~s = ~q", [Chars, Val]),
    binding_separator_(Rest).

binding_separator_([]) --> [].
binding_separator_([_|_]=Rest) -->
    format_(",~n", []),
    print_bindings_(Rest).

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
    if_(atom_t(Name),
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
    format_clause_(ClauseTerm, Meta),
    listing_clauses_(Rest).
listing_clauses_([Other|Rest]) -->
    { dif(Other, clause(_, _)) },
    listing_clauses_(Rest).

listing_clauses_matching_(_, []) --> [].
listing_clauses_matching_(Spec, [clause(ClauseTerm, Meta)|Rest]) -->
    { clause_head(ClauseTerm, Head),
      functor(Head, Name, Arity),
      if_((Spec = Name ; Spec = Name/Arity),
          Matches = true,
          Matches = false) },
    match_clause_emit_(Matches, ClauseTerm, Meta),
    listing_clauses_matching_(Spec, Rest).
listing_clauses_matching_(Spec, [Other|Rest]) -->
    { dif(Other, clause(_, _)) },
    listing_clauses_matching_(Spec, Rest).

match_clause_emit_(true, Term, Meta) --> format_clause_(Term, Meta).
match_clause_emit_(false, _, _) --> [].

clause_head((H :- _), H).
clause_head(H, H) :- dif(H, (_ :- _)).

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
    format_("~n=== Crowlog: Source-Provenance Prolog REPL ===~n\
Type 'help.' for commands, or 'halt.' to exit.~n~n", []).

toplevel_help_ -->
    format_("~nCrowlog Toplevel Commands:~n\
  consult('file.pl'). / ['file.pl'].   Load clauses into KB~n\
  listing.                             List all loaded clauses with spans~n\
  listing(pred). / listing(pred/N).    List clauses for predicate~n\
  tree. / notree.                      Toggle derivation tree display~n\
  trace. / notrace.                    Toggle step execution tracing~n\
  help.                                Display this help text~n\
  halt.                                Exit Crowlog~n~n", []).

toplevel_exit_ -->
    format_("~nExiting Crowlog.~n", []).

toplevel_false_ -->
    format_("false.~n", []).

toplevel_error_(Error) -->
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

crowlog_loop_chars(Chars0, State0, OutChars, StateFinal) :-
    phrase(skip_layout_, Chars0, Chars1),
    if_(Chars1 = [],
        (   phrase(toplevel_exit_, ExitChars),
            OutChars = ExitChars,
            StateFinal = State0
        ),
        (   State0 = state(kb(_), ops(OpT0), opts(_)),
            if_(phrase(clause_tokens(Tokens), Chars1, CharsRest),
                (   prolog_initial_var_state(V0),
                    if_(phrase(prolog_parse_term(OpT0, 1200, Goal, _, V0, VFinal), Tokens, _),
                        (   prolog_var_state_bindings(VFinal, VarNames, _, _),
                            if_(Goal = halt,
                                (   phrase(toplevel_prompt_, PromptChars),
                                    phrase(toplevel_exit_, ExitChars),
                                    append(PromptChars, ExitChars, OutChars),
                                    StateFinal = State0
                                ),
                                if_(Goal = end_of_file,
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
                                    )))
                        ),
                        (   phrase(toplevel_prompt_, PromptChars),
                            phrase(format_("Syntax error: failed to parse term.~n", []), ErrChars),
                            append(PromptChars, ErrChars, HeaderChars),
                            crowlog_loop_chars(CharsRest, State0, TailChars, StateFinal),
                            append(HeaderChars, TailChars, OutChars)
                        ))
                ),
                (   phrase(toplevel_exit_, ExitChars),
                    OutChars = ExitChars,
                    StateFinal = State0
                ))
        )).

handle_toplevel_input_chars(help, _, CharsRest, State, OutChars, CharsRest, State) :-
    phrase(toplevel_help_, OutChars).
handle_toplevel_input_chars(listing, _, CharsRest, State, OutChars, CharsRest, State) :-
    State = state(kb(KB), _, _),
    phrase(listing_clauses_(KB), OutChars).
handle_toplevel_input_chars(listing(Spec), _, CharsRest, State, OutChars, CharsRest, State) :-
    State = state(kb(KB), _, _),
    phrase(listing_clauses_matching_(Spec, KB), OutChars).
handle_toplevel_input_chars(tree, _, CharsRest, state(KB, Ops, Opts0), OutChars, CharsRest, state(KB, Ops, Opts1)) :-
    set_opt(tree(true), Opts0, Opts1),
    phrase(toplevel_opt_changed_(tree(true)), OutChars).
handle_toplevel_input_chars(notree, _, CharsRest, state(KB, Ops, Opts0), OutChars, CharsRest, state(KB, Ops, Opts1)) :-
    set_opt(tree(false), Opts0, Opts1),
    phrase(toplevel_opt_changed_(tree(false)), OutChars).
handle_toplevel_input_chars(trace, _, CharsRest, state(KB, Ops, Opts0), OutChars, CharsRest, state(KB, Ops, Opts1)) :-
    set_opt(trace(true), Opts0, Opts1),
    phrase(toplevel_opt_changed_(trace(true)), OutChars).
handle_toplevel_input_chars(notrace, _, CharsRest, state(KB, Ops, Opts0), OutChars, CharsRest, state(KB, Ops, Opts1)) :-
    set_opt(trace(false), Opts0, Opts1),
    phrase(toplevel_opt_changed_(trace(false)), OutChars).
handle_toplevel_input_chars(consult(File), _, CharsRest, State0, OutChars, CharsRest, State1) :-
    crowlog_consult(File, State0, State1, OutChars).
handle_toplevel_input_chars([File|Files], _, CharsRest, State0, OutChars, CharsRest, State1) :-
    consult_files([File|Files], State0, State1, OutChars).
handle_toplevel_input_chars(Goal, VarNames, CharsIn, State, OutChars, CharsOut, State) :-
    dif(Goal, help),
    dif(Goal, listing),
    dif(Goal, listing(_)),
    dif(Goal, tree),
    dif(Goal, notree),
    dif(Goal, trace),
    dif(Goal, notrace),
    dif(Goal, consult(_)),
    dif(Goal, [_|_]),
    crowlog_eval_query_chars(Goal, VarNames, CharsIn, State, OutChars, CharsOut).

crowlog_eval_query_chars(Goal, VarNames, CharsIn, State, OutChars, CharsOut) :-
    State = state(kb(KB), _, opts(Opts)),
    catch(
        findall(Deriv, crowlog_interpret(Goal, KB, Deriv), Derivs),
        Error,
        Derivs = exception(Error)
    ),
    if_(Derivs = exception(Err),
        (   phrase(toplevel_error_(Err), OutChars),
            CharsOut = CharsIn
        ),
        if_(Derivs = [],
            (   phrase(toplevel_false_, OutChars),
                CharsOut = CharsIn
            ),
            render_solutions_chars(Derivs, VarNames, Opts, CharsIn, OutChars, CharsOut))).

render_solutions_chars([], _, _, CharsIn, OutChars, CharsIn) :-
    phrase(toplevel_false_, OutChars).
render_solutions_chars([Deriv|Rest], VarNames, Opts, CharsIn, OutChars, CharsOut) :-
    phrase(answer_display_(VarNames, Deriv, Opts), AnsChars),
    phrase(skip_layout_, CharsIn, CharsTrimmed),
    if_(CharsTrimmed = [';'|CharsAfterSemi],
        (   phrase(format_(";~n", []), SemiChars),
            render_solutions_chars(Rest, VarNames, Opts, CharsAfterSemi, RestOutChars, CharsOut),
            append(AnsChars, SemiChars, Prefix),
            append(Prefix, RestOutChars, OutChars)
        ),
        (   phrase(format_("~n", []), NLChars),
            append(AnsChars, NLChars, OutChars),
            CharsOut = CharsTrimmed
        )).

skip_layout_ --> [C], { layout_char_t(C, true) }, skip_layout_.
skip_layout_ --> [].

layout_char_t(C, T) :-
    if_(C = ' ', T = true,
    if_(C = '\t', T = true,
    if_(C = '\n', T = true,
    if_(C = '\r', T = true,
    T = false)))).
