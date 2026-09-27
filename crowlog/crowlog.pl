:- module(crowlog, [
    crowlog_interpret/2,
    crowlog_interpret/3,
    crowlog_clause/3,
    crowlog_clause/4
]).

/** <module> Crowlog: Source-Provenance Prolog Meta-Interpreter

Crowlog is an execution and debugging engine that executes parsed Prolog clauses
while tracking source positions, choice points, and derivation trees.

Host engine absorbs:
- Core ISO primitives: unification (=), true, fail, control constructs (',', ';', '->', '*->', '!'),
  arithmetic (is, <, >, =<, >=, =:=, =\=), and metalogical tests (var/1, nonvar/1, atom/1, etc.).
- Delimited control: reset/3 and shift/1 (via library(cont)).
*/

:- use_module(library(charsio)).
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
crowlog_interpret(true, _, proof(true)) :- !.
crowlog_interpret((A, B), KB, proof(conjunction(TreeA, TreeB))) :- !,
    crowlog_interpret(A, KB, TreeA),
    crowlog_interpret(B, KB, TreeB).
crowlog_interpret((A ; B), KB, proof(disjunction(Tree))) :- !,
    (   crowlog_interpret(A, KB, Tree)
    ;   crowlog_interpret(B, KB, Tree)
    ).
crowlog_interpret((Cond -> Then ; Else), KB, proof(if_then_else(BranchTree))) :- !,
    (   crowlog_interpret(Cond, KB, CondTree) ->
        crowlog_interpret(Then, KB, ThenTree),
        BranchTree = then(CondTree, ThenTree)
    ;   crowlog_interpret(Else, KB, ElseTree),
        BranchTree = else(ElseTree)
    ).
crowlog_interpret((Cond -> Then), KB, proof(if_then(CondTree, ThenTree))) :- !,
    crowlog_interpret(Cond, KB, CondTree),
    crowlog_interpret(Then, KB, ThenTree).
crowlog_interpret(\+ Goal, KB, proof(negation(Goal))) :- !,
    \+ crowlog_interpret(Goal, KB, _).
crowlog_interpret(reset(Goal, Ball, Cont), KB, proof(reset(Goal))) :- !,
    reset(crowlog_interpret(Goal, KB, _), Ball, Cont).
crowlog_interpret(shift(Ball), _, proof(shift(Ball))) :- !,
    shift(Ball).
crowlog_interpret(Goal, KB, proof(step(Goal, Span, BodyTree))) :-
    (   crowlog_builtin(Goal) ->
        crowlog_call_builtin(Goal),
        Span = builtin,
        BodyTree = proof(builtin)
    ;   crowlog_clause(Goal, Body, KB, Span),
        crowlog_interpret(Body, KB, BodyTree)
    ).

%% crowlog_builtin(@Goal)
%  Identifies predicates absorbed directly by the host engine.
crowlog_builtin(Goal) :-
    functor(Goal, Functor, Arity),
    builtin_spec(Functor, Arity).

builtin_spec(=, 2).
builtin_spec(\=, 2).
builtin_spec(==, 2).
builtin_spec(\==, 2).
builtin_spec(dif, 2).
builtin_spec(is, 2).
builtin_spec(<, 2).
builtin_spec(>, 2).
builtin_spec(=<, 2).
builtin_spec(>=, 2).
builtin_spec(=:=, 2).
builtin_spec(=\=, 2).
builtin_spec(var, 1).
builtin_spec(nonvar, 1).
builtin_spec(atom, 1).
builtin_spec(integer, 1).
builtin_spec(float, 1).
builtin_spec(compound, 1).
builtin_spec(atomic, 1).
builtin_spec(functor, 3).
builtin_spec(arg, 3).
builtin_spec(=.., 2).
builtin_spec(atom_chars, 2).
builtin_spec(number_chars, 2).
builtin_spec(length, 2).
builtin_spec(append, 3).
builtin_spec(member, 2).

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

match_clause(clause((H :- B), Meta), Head, Body, Span) :- !,
    copy_term(clause_info(H, B, Meta), clause_info(Head, Body, MetaCopy)),
    extract_meta_span(MetaCopy, Span).
match_clause(clause(H, Meta), Head, true, Span) :-
    copy_term(clause_info(H, Meta), clause_info(Head, MetaCopy)),
    extract_meta_span(MetaCopy, Span).

extract_meta_span(meta(Items), Span) :- !,
    meta_span(Items, Span).
extract_meta_span(Span, Span).

meta_span([], no_span).
meta_span([Item|Rest], Span) :-
    (   Item = span(Span0) ->
        Span = Span0
    ;   meta_span(Rest, Span)
    ).

crowlog_clause(Head, Body, KB) :-
    crowlog_clause(Head, Body, KB, _).
