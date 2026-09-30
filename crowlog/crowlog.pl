:- module(crowlog, [
    crowlog_interpret/2,
    crowlog_interpret/3,
    crowlog_clause/3,
    crowlog_clause/4,
    extract_meta_span/2
]).

/** <module> Crowlog: Source-Provenance Prolog Meta-Interpreter

Crowlog is an execution and debugging engine that executes parsed Prolog clauses
while tracking source positions, choice points, and derivation trees.

Isolation & Sandboxing Principle:
- Modules loaded by the host to implement Crowlog (e.g. charsio, files, os)
  are NOT implicitly exposed to interpreted programs.
- As much as possible, library modules must be explicitly loaded in Crowlog
  via consult/1 or [library(...)] and interpreted in the in-memory KB.

Host engine absorbs only a minimal, explicit set of primitives:
- Core ISO primitives: unification (=, \=, ==, \==), dif/2, true, fail, false,
  control constructs (',', ';', '->', '*->', '!'), negation (\+), meta-call (call/1..N),
  arithmetic (is, <, >, =<, >=, =:=, =\=), and metalogical tests
  (var/1, nonvar/1, atom/1, integer/1, float/1, compound/1, atomic/1,
   functor/3, arg/3, =../2, atom_chars/2, number_chars/2).
- Delimited control: reset/3 and shift/1 (via library(cont)).
- Pure conditionals: native interpretation of reified if_/3.
*/

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

%% crowlog_interpret(+Goal, +KB)
%  Interprets Goal against in-memory knowledge base KB.
crowlog_interpret(Goal, KB) :-
    crowlog_interpret(Goal, KB, _DerivationTree).

%% crowlog_interpret(+Goal, +KB, -Derivation)
%  Interprets Goal and constructs an explicit proof derivation tree.
%  Dispatches deterministically via reified goal classification without procedural cuts.
crowlog_interpret(Goal, KB, Derivation) :-
    goal_shape(Goal, Shape),
    crowlog_interpret_shape(Shape, KB, Derivation).

crowlog_interpret_shape(true, _, proof(true)).
crowlog_interpret_shape(conjunction(A, B), KB, proof(conjunction(TreeA, TreeB))) :-
    crowlog_interpret(A, KB, TreeA),
    crowlog_interpret(B, KB, TreeB).
crowlog_interpret_shape(disjunction(A, B), KB, proof(disjunction(Tree))) :-
    (   crowlog_interpret(A, KB, Tree)
    ;   crowlog_interpret(B, KB, Tree)
    ).
crowlog_interpret_shape(if_then_else(Cond, Then, Else), KB, proof(if_then_else(BranchTree))) :-
    (   crowlog_interpret(Cond, KB, CondTree) ->
        crowlog_interpret(Then, KB, ThenTree),
        BranchTree = then(CondTree, ThenTree)
    ;   crowlog_interpret(Else, KB, ElseTree),
        BranchTree = else(ElseTree)
    ).
crowlog_interpret_shape(if_then(Cond, Then), KB, proof(if_then(CondTree, ThenTree))) :-
    crowlog_interpret(Cond, KB, CondTree),
    crowlog_interpret(Then, KB, ThenTree).
crowlog_interpret_shape(if_reif(Cond, Then, Else), KB, proof(if_reif(T, BranchTree))) :-
    reified_call(Cond, T),
    if_(T = true,
        (   crowlog_interpret(Then, KB, ThenTree),
            BranchTree = then(ThenTree)
        ),
        (   crowlog_interpret(Else, KB, ElseTree),
            BranchTree = else(ElseTree)
        )).
crowlog_interpret_shape(phrase(GRBody, S0, S), KB, proof(step(phrase(GRBody, S0, S), builtin, SubTree))) :-
    interpret_call(call(GRBody, S0, S), 3, KB, SubTree).
crowlog_interpret_shape(call(CallGoal, Arity), KB, proof(step(CallGoal, builtin, SubTree))) :-
    interpret_call(CallGoal, Arity, KB, SubTree).
crowlog_interpret_shape(negation(Goal), KB, proof(negation(Goal))) :-
    \+ crowlog_interpret(Goal, KB, _).
crowlog_interpret_shape(reset(Goal, Ball, Cont), KB, proof(reset(Goal))) :-
    reset(crowlog_interpret(Goal, KB, _), Ball, Cont).
crowlog_interpret_shape(shift(Ball), _, proof(shift(Ball))) :-
    shift(Ball).
crowlog_interpret_shape(builtin(Goal), _, proof(step(Goal, builtin, proof(builtin)))) :-
    crowlog_call_builtin(Goal).
crowlog_interpret_shape(user_clause(Goal), KB, proof(step(Goal, Span, BodyTree))) :-
    crowlog_clause(Goal, Body, KB, Span),
    crowlog_interpret(Body, KB, BodyTree).

interpret_call(CallGoal, 1, KB, SubTree) :-
    arg(1, CallGoal, SubGoal),
    crowlog_interpret(SubGoal, KB, SubTree).
interpret_call(CallGoal, Arity, KB, SubTree) :-
    Arity > 1,
    CallGoal =.. [call, Closure|Args],
    (   var(Closure) ->
        throw(error(instantiation_error, call/Arity))
    ;   number(Closure) ->
        throw(error(type_error(callable, Closure), call/Arity))
    ;   Closure = [_|_] ->
        throw(error(type_error(callable, Closure), call/Arity))
    ;   atom(Closure) ->
        ConstructedGoal =.. [Closure|Args],
        crowlog_interpret(ConstructedGoal, KB, SubTree)
    ;   compound(Closure) ->
        Closure =.. [CF|CArgs],
        append(CArgs, Args, AllArgs),
        ConstructedGoal =.. [CF|AllArgs],
        crowlog_interpret(ConstructedGoal, KB, SubTree)
    ;   throw(error(type_error(callable, Closure), call/Arity))
    ).

reified_call(true, true).
reified_call(false, false).
reified_call(fail, false).
reified_call(Cond, T) :-
    dif(Cond, true),
    dif(Cond, false),
    dif(Cond, fail),
    call(Cond, T).

%% goal_shape(+Goal, -Shape)
%  Classifies Goal into its execution shape using pure reified tests.
goal_shape(Goal, Shape) :-
    (   var(Goal) ->
        throw(error(instantiation_error, call/1))
    ;   number(Goal) ->
        throw(error(type_error(callable, Goal), call/1))
    ;   Goal = [_|_] ->
        throw(error(type_error(callable, Goal), call/1))
    ;   functor(Goal, F, A),
        if_(F = true,
            if_(A = 0, Shape = true, goal_shape_compound(Goal, F, A, Shape)),
            goal_shape_compound(Goal, F, A, Shape))
    ).

goal_shape_compound(Goal, F, A, Shape) :-
    if_(F = (','),
        if_(A = 2,
            (   arg(1, Goal, G1),
                arg(2, Goal, G2),
                Shape = conjunction(G1, G2)
            ),
            goal_shape_other(Goal, F, A, Shape)),
        goal_shape_other(Goal, F, A, Shape)).

goal_shape_other(Goal, F, A, Shape) :-
    if_(F = (';'),
        if_(A = 2,
            (   arg(1, Goal, G1),
                arg(2, Goal, G2),
                is_arrow_t(G1, ArrowT),
                if_(ArrowT = true,
                    (   arg(1, G1, Cond),
                        arg(2, G1, Then),
                        Shape = if_then_else(Cond, Then, G2)
                    ),
                    Shape = disjunction(G1, G2))
            ),
            goal_shape_control(Goal, F, A, Shape)),
        goal_shape_control(Goal, F, A, Shape)).

is_arrow_t(Term, T) :-
    functor(Term, F, A),
    if_(F = (->),
        if_(A = 2, T = true, T = false),
        T = false).

goal_shape_control(Goal, F, A, Shape) :-
    if_(F = (->),
        if_(A = 2,
            (   arg(1, Goal, Cond),
                arg(2, Goal, Then),
                Shape = if_then(Cond, Then)
            ),
            goal_shape_ext(Goal, F, A, Shape)),
        goal_shape_ext(Goal, F, A, Shape)).

goal_shape_ext(Goal, F, A, Shape) :-
    if_(F = if_,
        if_(A = 3,
            (   arg(1, Goal, C),
                arg(2, Goal, T),
                arg(3, Goal, E),
                Shape = if_reif(C, T, E)
            ),
            goal_shape_phrase(Goal, F, A, Shape)),
        goal_shape_phrase(Goal, F, A, Shape)).

goal_shape_phrase(Goal, F, A, Shape) :-
    if_(F = phrase,
        if_(A = 2,
            (   arg(1, Goal, GRBody),
                arg(2, Goal, S0),
                Shape = phrase(GRBody, S0, [])
            ),
            if_(A = 3,
                (   arg(1, Goal, GRBody),
                    arg(2, Goal, S0),
                    arg(3, Goal, S),
                    Shape = phrase(GRBody, S0, S)
                ),
                goal_shape_call(Goal, F, A, Shape)
            )
        ),
        goal_shape_call(Goal, F, A, Shape)).

goal_shape_call(Goal, F, A, Shape) :-
    if_(F = call,
        (   A >= 1 ->
            Shape = call(Goal, A)
        ;   goal_shape_meta(Goal, F, A, Shape)
        ),
        goal_shape_meta(Goal, F, A, Shape)).

goal_shape_meta(Goal, F, A, Shape) :-
    if_(F = (\+),
        if_(A = 1,
            (   arg(1, Goal, NegG),
                Shape = negation(NegG)
            ),
            goal_shape_delimited(Goal, F, A, Shape)),
        goal_shape_delimited(Goal, F, A, Shape)).

goal_shape_delimited(Goal, F, A, Shape) :-
    if_(F = reset,
        if_(A = 3,
            (   arg(1, Goal, RG),
                arg(2, Goal, Ball),
                arg(3, Goal, Cont),
                Shape = reset(RG, Ball, Cont)
            ),
            goal_shape_shift(Goal, F, A, Shape)),
        goal_shape_shift(Goal, F, A, Shape)).

goal_shape_shift(Goal, F, A, Shape) :-
    if_(F = shift,
        if_(A = 1,
            (   arg(1, Goal, Ball),
                Shape = shift(Ball)
            ),
            goal_shape_atomic_or_builtin(Goal, Shape)),
        goal_shape_atomic_or_builtin(Goal, Shape)).

goal_shape_atomic_or_builtin(Goal, Shape) :-
    crowlog_builtin_t(Goal, BuiltinT),
    if_(BuiltinT = true,
        Shape = builtin(Goal),
        Shape = user_clause(Goal)).

%% crowlog_builtin_t(@Goal, -Truth)
%  Pure reified identification of predicates absorbed directly by the host engine.
crowlog_builtin_t(Goal, T) :-
    functor(Goal, Name, Arity),
    builtins_spec_list(Builtins),
    memberd_t(b(Name, Arity), Builtins, T).

builtins_spec_list([
    b('=', 2), b('\\=', 2), b('==', 2), b('\\==', 2), b(dif, 2), b(is, 2),
    b('<', 2), b('>', 2), b('=<', 2), b('>=', 2), b('=:=', 2), b('=\\=', 2),
    b(var, 1), b(nonvar, 1), b(atom, 1), b(integer, 1), b(float, 1), b(compound, 1), b(atomic, 1),
    b(functor, 3), b(arg, 3), b('=..', 2), b(atom_chars, 2), b(number_chars, 2),
    b(length, 2), b(append, 3), b(member, 2),
    % CLP(Z) Constraints
    b('#=', 2), b('#\\=', 2), b('#<', 2), b('#>', 2), b('#=<', 2), b('#>=', 2),
    b(in, 2), b(ins, 2), b(label, 1), b(labeling, 2)
]).

crowlog_call_builtin(Goal) :-
    call(Goal).

%% crowlog_clause(+Head, -Body, +KB, -Span)
%  Looks up a clause in the knowledge base list KB.
%  KB entries can be:
%  - clause(Head :- Body, Meta)
%  - clause(Head, Meta)   % Fact
crowlog_clause(Head, Body, [Clause|_], Span) :-
    match_clause(Clause, Head, Body, Span).
crowlog_clause(Head, Body, [_|Rest], Span) :-
    crowlog_clause(Head, Body, Rest, Span).

crowlog_clause(Head, Body, KB) :-
    crowlog_clause(Head, Body, KB, _).

match_clause(clause(ClauseTerm, Meta), Head, Body, Span) :-
    is_rule_t(ClauseTerm, RuleT),
    if_(RuleT = true,
        (   arg(1, ClauseTerm, H),
            arg(2, ClauseTerm, B),
            copy_term(clause_info(H, B, Meta), clause_info(Head, Body, MetaCopy)),
            extract_meta_span(MetaCopy, Span)
        ),
        (   H = ClauseTerm,
            Body = true,
            copy_term(clause_info(H, Meta), clause_info(Head, MetaCopy)),
            extract_meta_span(MetaCopy, Span)
        )).

is_rule_t(Term, T) :-
    functor(Term, F, A),
    if_(F = (:-),
        if_(A = 2, T = true, T = false),
        T = false).

extract_meta_span(Meta, Span) :-
    is_meta_t(Meta, MetaT),
    if_(MetaT = true,
        (   arg(1, Meta, Items),
            meta_span(Items, Span)
        ),
        Span = Meta).

is_meta_t(Term, T) :-
    functor(Term, F, A),
    if_(F = meta,
        if_(A = 1, T = true, T = false),
        T = false).

meta_span([], no_span).
meta_span([Item|Rest], Span) :-
    is_span_item_t(Item, SpanT),
    if_(SpanT = true,
        arg(1, Item, Span),
        meta_span(Rest, Span)).

is_span_item_t(Term, T) :-
    functor(Term, F, A),
    if_(F = span,
        if_(A = 1, T = true, T = false),
        T = false).
