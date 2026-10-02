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

:- use_module(library(arithmetic)).
:- use_module(library(assoc)).
:- use_module(library(atts)).
:- use_module(library(between)).
:- use_module(library(charsio)).
:- use_module(library(clpb)).
:- use_module(library(clpz)).
:- use_module(library(cont)).
:- use_module(library(crypto)).
:- use_module(library(csv)).
:- use_module(library(dcgs)).
:- use_module(library(debug)).
:- use_module(library(diag)).
:- use_module(library(dif)).
:- use_module(library(error)).
:- use_module(library(files)).
:- use_module(library(format)).
:- use_module(library(freeze)).
:- use_module(library(gensym)).
:- use_module(library(iso_ext)).
:- use_module(library(lambda)).
:- use_module(library(lists)).
:- use_module(library(ordsets)).
:- use_module(library(os)).
:- use_module(library(pairs)).
:- use_module(library(pio)).
:- use_module(library(process)).
:- use_module(library(queues)).
:- use_module(library(random)).
:- use_module(library(reif)).
:- use_module(library(sgml)).
:- use_module(library(si)).
:- use_module(library(simplex)).
:- use_module(library(terms)).
:- use_module(library(time)).
:- use_module(library(ugraphs)).
:- use_module(library(uuid)).
:- use_module(library(when)).
:- use_module(library(xpath)).
:- use_module(substrate).

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
crowlog_interpret_shape(cut, _, proof(cut)).
crowlog_interpret_shape(fail, _, _) :- fail.
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
crowlog_interpret_shape(findall(Template, SubGoal, List), KB, proof(step(findall(Template, SubGoal, List), builtin, proof(builtin)))) :-
    findall(Template, crowlog_interpret(SubGoal, KB, _), List).
crowlog_interpret_shape(catch(Goal, Catcher, Recover), KB, proof(catch(Tree))) :-
    catch(crowlog_interpret(Goal, KB, Tree),
          Catcher,
          crowlog_interpret(Recover, KB, Tree)).
crowlog_interpret_shape(module_qualified(_M, SubGoal), KB, Derivation) :-
    crowlog_interpret(SubGoal, KB, Derivation).
crowlog_interpret_shape(builtin(Goal), _, proof(step(Goal, builtin, proof(builtin)))) :-
    crowlog_call_builtin(Goal).
crowlog_interpret_shape(user_clause(Goal), KB, Derivation) :-
    crowlog_interpret_clauses(KB, Goal, KB, Derivation).

clause_head_functor_arity(clause(ClauseTerm, _), F, A) :-
    (   nonvar(ClauseTerm), ClauseTerm = (Head :- _) ->
        functor(Head, F, A)
    ;   functor(ClauseTerm, F, A)
    ).

crowlog_interpret_clauses([Clause|RestClauses], Goal, KB, Derivation) :-
    (   (   var(Goal) -> true
        ;   functor(Goal, GF, GA),
            clause_head_functor_arity(Clause, GF, GA)
        ),
        copy_term(Clause, clause(ClauseTerm, Meta)),
        match_clause_term(ClauseTerm, Meta, Goal, Body, Span),
        (   split_at_cut(Body, Before, After) ->
            crowlog_interpret(Before, KB, BeforeTree),
            !,
            crowlog_interpret(After, KB, AfterTree),
            Derivation = proof(step(Goal, Span, proof(conjunction(BeforeTree, proof(conjunction(proof(cut), AfterTree))))))
        ;   crowlog_interpret(Body, KB, BodyTree),
            Derivation = proof(step(Goal, Span, BodyTree))
        )
    ;   crowlog_interpret_clauses(RestClauses, Goal, KB, Derivation)
    ).
crowlog_interpret_clauses([], Goal, KB, Derivation) :-
    crowlog_lib_clause(Goal, Body),
    (   split_at_cut(Body, Before, After) ->
        crowlog_interpret(Before, KB, BeforeTree),
        !,
        crowlog_interpret(After, KB, AfterTree),
        Derivation = proof(step(Goal, default, proof(conjunction(BeforeTree, proof(conjunction(proof(cut), AfterTree))))))
    ;   crowlog_interpret(Body, KB, BodyTree),
        Derivation = proof(step(Goal, default, BodyTree))
    ).

split_at_cut_t(Goal, Before, After, Truth) :-
    (   split_at_cut(Goal, Before, After) ->
        Truth = true
    ;   Truth = false
    ).

split_at_cut(Goal, Before, After) :-
    (   nonvar(Goal), Goal = (!) ->
        Before = true, After = true
    ;   nonvar(Goal), Goal = (G1, G2) ->
        (   nonvar(G1), G1 = (!) ->
            Before = true, After = G2
        ;   split_at_cut(G1, SubBefore, SubAfter) ->
            Before = SubBefore,
            After = (SubAfter, G2)
        ;   split_at_cut(G2, SubBefore, After) ->
            Before = (G1, SubBefore)
        ;   fail
        )
    ;   fail
    ).

match_clause_term(ClauseTerm, Meta, Goal, Body, Span) :-
    is_rule_t(ClauseTerm, RuleT),
    if_(RuleT = true,
        (   arg(1, ClauseTerm, Goal),
            arg(2, ClauseTerm, Body),
            extract_meta_span(Meta, Span)
        ),
        (   Goal = ClauseTerm,
            Body = true,
            extract_meta_span(Meta, Span)
        )).

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
    ;   construct_called_goal(Closure, Args, ConstructedGoal) ->
        crowlog_interpret(ConstructedGoal, KB, SubTree)
    ;   throw(error(type_error(callable, Closure), call/Arity))
    ).

construct_called_goal(Closure, Args, Goal) :-
    (   Closure = M:SubClosure ->
        construct_called_goal(SubClosure, Args, SubGoal),
        Goal = M:SubGoal
    ;   atom(Closure) ->
        Goal =.. [Closure|Args]
    ;   compound(Closure) ->
        Closure =.. [CF|CArgs],
        append(CArgs, Args, AllArgs),
        Goal =.. [CF|AllArgs]
    ;   fail
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
            if_(F = (!),
                if_(A = 0, Shape = cut, goal_shape_compound(Goal, F, A, Shape)),
                if_(F = fail,
                    if_(A = 0, Shape = fail, goal_shape_compound(Goal, F, A, Shape)),
                    if_(F = false,
                        if_(A = 0, Shape = fail, goal_shape_compound(Goal, F, A, Shape)),
                        goal_shape_compound(Goal, F, A, Shape)))))
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
        =(A, 2, T),
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
            goal_shape_module(Goal, F, A, Shape)),
        goal_shape_module(Goal, F, A, Shape)).

goal_shape_module(Goal, F, A, Shape) :-
    if_(F = (:),
        if_(A = 2,
            (   arg(1, Goal, M),
                arg(2, Goal, SubGoal),
                Shape = module_qualified(M, SubGoal)
            ),
            goal_shape_findall(Goal, F, A, Shape)),
        goal_shape_findall(Goal, F, A, Shape)).

goal_shape_findall(Goal, F, A, Shape) :-
    if_(F = findall,
        if_(A = 3,
            (   arg(1, Goal, Templ),
                arg(2, Goal, SubG),
                arg(3, Goal, List),
                Shape = findall(Templ, SubG, List)
            ),
            goal_shape_catch(Goal, F, A, Shape)),
        goal_shape_catch(Goal, F, A, Shape)).

goal_shape_catch(Goal, F, A, Shape) :-
    if_(F = catch,
        if_(A = 3,
            (   arg(1, Goal, SubG),
                arg(2, Goal, Catcher),
                arg(3, Goal, Recover),
                Shape = catch(SubG, Catcher, Recover)
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
    default_substrate(SubstrateID),
    substrate_absorbs_predicate_t(SubstrateID, Goal, T).

builtins_spec_list(Builtins) :-
    default_substrate(SubstrateID),
    substrate_absorbed_predicates(SubstrateID, Builtins).

wrap_lambda_modules(Term, Wrapped) :-
    (   var(Term) ->
        Wrapped = Term
    ;   compound(Term) ->
        Term =.. [F|Args],
        map_lambda_args(Args, WrappedArgs),
        WrappedTerm =.. [F|WrappedArgs],
        atom_chars(F, FChars),
        (   (   FChars = ['\\']
            ;   FChars = ['+', '\\']
            ;   FChars = ['^']
            ) ->
            Wrapped = lambda:WrappedTerm
        ;   Wrapped = WrappedTerm
        )
    ;   Wrapped = Term
    ).

map_lambda_args([], []).
map_lambda_args([A|As], [W|Ws]) :-
    wrap_lambda_modules(A, W),
    map_lambda_args(As, Ws).

crowlog_call_builtin('$skip_max_list'(A, B, C, D)) :-
    !,
    '$skip_max_list'(A, B, C, D).
crowlog_call_builtin('$is_partial_string'(A)) :-
    !,
    '$is_partial_string'(A).
crowlog_call_builtin('$first_non_octet'(A, B)) :-
    !,
    '$first_non_octet'(A, B).
crowlog_call_builtin(must_be(Type, Value)) :-
    !,
    (   Type = assoc ->
        (   Value == t -> true
        ;   compound(Value), functor(Value, t, 5) -> true
        ;   type_error(assoc, Value)
        )
    ;   must_be(Type, Value)
    ).
crowlog_call_builtin(can_be(Type, Value)) :-
    !,
    (   Type = assoc ->
        (   Value == t -> true
        ;   compound(Value), functor(Value, t, 5) -> true
        ;   var(Value) -> true
        ;   type_error(assoc, Value)
        )
    ;   can_be(Type, Value)
    ).
crowlog_call_builtin(Goal) :-
    wrap_lambda_modules(Goal, WrappedGoal),
    call(WrappedGoal).

%% crowlog_clause(+Head, -Body, +KB, -Span)
%  Looks up a clause in the knowledge base list KB or library definitions.
%  KB entries can be:
%  - clause(Head :- Body, Meta)
%  - clause(Head, Meta)   % Fact
crowlog_clause(Head, Body, KB, Span) :-
    crowlog_kb_clause(Head, Body, KB, Span).
crowlog_clause(Head, Body, _, default) :-
    crowlog_lib_clause(Head, Body).

crowlog_kb_clause(Head, Body, [Clause|_], Span) :-
    match_clause(Clause, Head, Body, Span).
crowlog_kb_clause(Head, Body, [_|Rest], Span) :-
    crowlog_kb_clause(Head, Body, Rest, Span).

crowlog_lib_clause(maplist(_, []), true).
crowlog_lib_clause(maplist(Cont, [X|Xs]), (call(Cont, X), maplist(Cont, Xs))).
crowlog_lib_clause(maplist(_, [], []), true).
crowlog_lib_clause(maplist(Cont, [X|Xs], [Y|Ys]), (call(Cont, X, Y), maplist(Cont, Xs, Ys))).
crowlog_lib_clause(maplist(_, [], [], []), true).
crowlog_lib_clause(maplist(Cont, [X|Xs], [Y|Ys], [Z|Zs]), (call(Cont, X, Y, Z), maplist(Cont, Xs, Ys, Zs))).
crowlog_lib_clause(maplist(_, [], [], [], []), true).
crowlog_lib_clause(maplist(Cont, [X1|X1s], [X2|X2s], [X3|X3s], [X4|X4s]), (call(Cont, X1, X2, X3, X4), maplist(Cont, X1s, X2s, X3s, X4s))).
crowlog_lib_clause(foldl(_, [], A, A), true).
crowlog_lib_clause(foldl(G, [X|Xs], A0, A), (call(G, X, A0, A1), foldl(G, Xs, A1, A))).
crowlog_lib_clause(foldl(_, [], [], A, A), true).
crowlog_lib_clause(member(X, [X|_]), true).
crowlog_lib_clause(member(X, [_|Xs]), member(X, Xs)).
crowlog_lib_clause(append([], Ys, Ys), true).
crowlog_lib_clause(append([X|Xs], Ys, [X|Zs]), append(Xs, Ys, Zs)).
crowlog_lib_clause(length([], 0), true).
crowlog_lib_clause(length([_|Xs], N), (length(Xs, N0), N is N0 + 1)).
crowlog_lib_clause(include(_, [], []), true).
crowlog_lib_clause(include(Goal, [X|Xs], Ys), (if_(call(Goal, X), Ys = [X|Zs], Ys = Zs), include(Goal, Xs, Zs))).
crowlog_lib_clause(exclude(_, [], []), true).
crowlog_lib_clause(exclude(Goal, [X|Xs], Ys), (if_(call(Goal, X), Ys = Zs, Ys = [X|Zs]), exclude(Goal, Xs, Zs))).
crowlog_lib_clause(Term =.. List, (
    (   var(Term) ->
        List = [Name|Args],
        length(Args, Arity),
        functor(Term, Name, Arity),
        get_univ_args(1, Arity, Term, Args)
    ;   functor(Term, Name, Arity),
        get_univ_args(1, Arity, Term, Args),
        List = [Name|Args]
    )
)).
crowlog_lib_clause(get_univ_args(I, Arity, Term, Args), (
    (   I > Arity ->
        Args = []
    ;   arg(I, Term, Arg),
        I1 is I + 1,
        Args = [Arg|RestArgs],
        get_univ_args(I1, Arity, Term, RestArgs)
    )
)).
crowlog_lib_clause(atom_concat(A, B, AB), (
    (   var(A) ->
        (   var(AB) ->
            throw(error(instantiation_error, atom_concat/3))
        ;   atom_chars(AB, ABChars),
            append(AChars, BChars, ABChars),
            atom_chars(A, AChars),
            atom_chars(B, BChars)
        )
    ;   var(B) ->
        (   var(AB) ->
            throw(error(instantiation_error, atom_concat/3))
        ;   atom_chars(A, AChars),
            atom_chars(AB, ABChars),
            append(AChars, BChars, ABChars),
            atom_chars(B, BChars)
        )
    ;   atom_chars(A, AChars),
        atom_chars(B, BChars),
        append(AChars, BChars, ABChars),
        atom_chars(AB, ABChars)
    )
)).
crowlog_lib_clause(atom_length(Atom, Length), (
    atom_chars(Atom, Chars),
    length(Chars, Length)
)).
crowlog_lib_clause(sub_atom(Atom, Before, Length, After, SubAtom), (
    atom_chars(Atom, Chars),
    append(BeforeChars, RestChars, Chars),
    append(SubChars, AfterChars, RestChars),
    length(BeforeChars, Before),
    length(SubChars, Length),
    length(AfterChars, After),
    atom_chars(SubAtom, SubChars)
)).
crowlog_lib_clause(succ(I, S), (
    (   integer(S) ->
        S > 0, I is S - 1
    ;   integer(I) ->
        I >= 0, S is I + 1
    ;   throw(error(instantiation_error, succ/2))
    )
)).
crowlog_lib_clause(forall(Generate, Test), \+ (Generate, \+ Test)).
crowlog_lib_clause(between(Low, High, Value), (
    Low =< High,
    (   Value = Low
    ;   Low1 is Low + 1,
        between(Low1, High, Value)
    )
)).
crowlog_lib_clause(*(_), true).
crowlog_lib_clause(pairs_keys_values([], [], []), true).
crowlog_lib_clause(pairs_keys_values([K-V|Pairs], [K|Keys], [V|Values]), pairs_keys_values(Pairs, Keys, Values)).
crowlog_lib_clause(pairs_keys([], []), true).
crowlog_lib_clause(pairs_keys([K-_|Pairs], [K|Keys]), pairs_keys(Pairs, Keys)).
crowlog_lib_clause(pairs_values([], []), true).
crowlog_lib_clause(pairs_values([_-V|Pairs], [V|Values]), pairs_values(Pairs, Values)).
crowlog_lib_clause(queue_new(queue([], [])), true).
crowlog_lib_clause(queue_head(queue([X|H], T), X, queue(H, T)), true).
crowlog_lib_clause(queue_tail(queue(H, T), X, queue(H, [X|T])), true).
crowlog_lib_clause(queue_head_tail(queue([Head|H], T), Head, Tail, queue(H, [Tail|T])), true).
crowlog_lib_clause(is_queue(queue(H, T)), (lists:list_si(H), lists:list_si(T))).

crowlog_clause(Head, Body, KB) :-
    crowlog_clause(Head, Body, KB, _).

match_clause(clause(ClauseTerm, Meta), Head, Body, Span) :-
    is_rule_t(ClauseTerm, RuleT),
    if_(RuleT = true,
        (   arg(1, ClauseTerm, H),
            arg(2, ClauseTerm, B),
            (   var(Head) -> true
            ;   functor(Head, HF, HA),
                functor(H, HF, HA)
            ),
            copy_term(clause_info(H, B, Meta), clause_info(Head, Body, MetaCopy)),
            extract_meta_span(MetaCopy, Span)
        ),
        (   H = ClauseTerm,
            (   var(Head) -> true
            ;   functor(Head, HF, HA),
                functor(H, HF, HA)
            ),
            Body = true,
            copy_term(clause_info(H, Meta), clause_info(Head, MetaCopy)),
            extract_meta_span(MetaCopy, Span)
        )).

is_rule_t(Term, T) :-
    functor(Term, F, A),
    if_(F = (:-),
        =(A, 2, T),
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
        =(A, 1, T),
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
        =(A, 1, T),
        T = false).
