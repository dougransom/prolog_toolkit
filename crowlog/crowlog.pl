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
    functor(Goal, Name, Arity),
    builtins_spec_list(Builtins),
    memberd_t(b(Name, Arity), Builtins, T).

builtins_spec_list([
    b('=', 2), b('\\=', 2), b('==', 2), b('\\==', 2), b(dif, 2), b(freeze, 2), b(is, 2),
    b('<', 2), b('>', 2), b('=<', 2), b('>=', 2), b('=:=', 2), b('=\\=', 2),
    b('@<', 2), b('@>', 2), b('@=<', 2), b('@>=', 2), b(compare, 3),
    b(var, 1), b(nonvar, 1), b(atom, 1), b(integer, 1), b(float, 1), b(number, 1), b(compound, 1), b(atomic, 1),
    b(ground, 1), b(callable, 1),
    b(functor, 3), b(arg, 3), b('=..', 2), b(atom_chars, 2), b(number_chars, 2),
    b(char_code, 2), b(atom_length, 2), b(sub_atom, 5), b(atom_concat, 3), b(copy_term, 2),
    b(term_variables, 2), b(numbervars, 3),
    b(length, 2), b(append, 3), b(member, 2),
    b(sort, 2), b(sort, 4), b(keysort, 2),
    b(acyclic_term, 1),
    b('$skip_max_list', 4), b('$is_partial_string', 1), b('$first_non_octet', 2),
    b(throw, 1),
    % I/O and Formatting
    b(format, 1), b(format, 2), b(format, 3), b(format_, 4),
    b(portray_clause, 1), b(portray_clause, 2),
    b(write, 1), b(write_term, 2), b(nl, 0),
    % Character Stream & Term Conversion (library(charsio))
    b(read_from_chars, 2), b(read_term_from_chars, 3), b(write_term_to_chars, 3),
    b(char_type, 2), b(chars_utf8bytes, 2), b(chars_base64, 3),
    % Safe Type Tests (library(si))
    b(atom_si, 1), b(integer_si, 1), b(float_si, 1), b(number_si, 1),
    b(atomic_si, 1), b(list_si, 1), b(chars_si, 1),
    % ISO Extensions (library(iso_ext))
    b(succ, 2), b(bb_put, 2), b(bb_b_put, 2), b(bb_get, 2),
    b(copy_term_nat, 2), b(countall, 2), b(partial_string, 1),
    % Unique Symbol Generation (library(gensym))
    b(gensym, 2), b(reset_gensym, 1),
    % Arithmetic Iteration (library(between))
    b(between, 3), b(numlist, 3),
    % Error handling primitives (library(error))
    b(domain_error, 2), b(type_error, 2), b(instantiation_error, 1), b(representation_error, 1),
    b(must_be, 2), b(can_be, 2),
    % Common List utilities (library(lists))
    b(reverse, 2), b(select, 3), b(nth0, 3), b(nth1, 3), b(nth0, 4), b(nth1, 4),
    b(sum_list, 2), b(max_list, 2), b(min_list, 2),
    b(maplist, 2), b(maplist, 3), b(maplist, 4), b(maplist, 5), b(maplist, 6), b(maplist, 7), b(maplist, 8),
    b(foldl, 4), b(foldl, 5), b(foldl, 6), b(foldl, 7), b(foldl, 8),
    b(include, 3), b(exclude, 3), b(partition, 4), b(partition, 5), b(convlist, 3),
    % Lambda expressions (library(lambda))
    b('^', 3), b('^', 4), b('^', 5), b('^', 6),
    b('\\', 1), b('\\', 2), b('\\', 3), b('\\', 4),
    b('+\\', 2), b('+\\', 3), b('+\\', 4), b('+\\', 5),
    % Reification and indexing dif (library(reif))
    b('=', 3), b(',', 3), b(';', 3), b(cond_t, 3), b(dif, 3),
    b(memberd_t, 3), b(tfilter, 3), b(tmember, 2), b(tmember_t, 3), b(tpartition, 4),
    % Pairs utilities (library(pairs))
    b(pairs_keys_values, 3), b(pairs_values, 2), b(pairs_keys, 2),
    b(group_pairs_by_key, 2), b(transpose_pairs, 2), b(map_list_to_pairs, 3),
    % Association trees (library(assoc))
    b(empty_assoc, 1), b(assoc_to_list, 2), b(is_assoc, 1),
    b(min_assoc, 3), b(max_assoc, 3), b(gen_assoc, 3),
    b(get_assoc, 3), b(get_assoc, 5), b(list_to_assoc, 2),
    b(map_assoc, 2), b(map_assoc, 3), b(put_assoc, 4),
    b(del_assoc, 4), b(del_min_assoc, 4), b(del_max_assoc, 4),
    % Ordered sets (library(ordsets))
    b(is_ordset, 1), b(list_to_ord_set, 2), b(ord_add_element, 3), b(ord_del_element, 3),
    b(ord_selectchk, 3), b(ord_intersect, 2), b(ord_intersect, 3), b(ord_intersection, 2),
    b(ord_intersection, 3), b(ord_intersection, 4), b(ord_disjoint, 2), b(ord_subtract, 3),
    b(ord_union, 2), b(ord_union, 3), b(ord_union, 4), b(ord_subset, 2),
    b(ord_empty, 1), b(ord_memberchk, 2), b(ord_symdiff, 3), b(ord_seteq, 2),
    % Queues (library(queues))
    b(queue, 1), b(queue, 2), b(queue_head, 3), b(queue_head_list, 3),
    b(queue_last, 3), b(queue_last_list, 3), b(list_queue, 2), b(queue_length, 2),
    % Unweighted Graphs (library(ugraphs))
    b(add_edges, 3), b(add_vertices, 3), b(complement, 2), b(compose, 3),
    b(del_edges, 3), b(del_vertices, 3), b(edges, 2), b(neighbors, 3),
    b(neighbours, 3), b(reachable, 3), b(top_sort, 2), b(top_sort, 3),
    b(transitive_closure, 2), b(transpose_ugraph, 2), b(vertices, 2),
    b(vertices_edges_to_ugraph, 3), b(ugraph_union, 3), b(connect_ugraph, 3),
    % CSV Parsing and Serialization (library(csv))
    b(parse_csv, 3), b(parse_csv, 4), b(write_csv, 2), b(write_csv, 3),
    % Pseudo-random number generation (library(random))
    b(maybe, 0), b(random, 1), b(random_integer, 3), b(set_random, 1),
    % Time & Benchmarking (library(time))
    b(format_time, 4), b(max_sleep_time, 1), b(sleep, 1), b(statistics, 2),
    % Cryptographic Primitives (library(crypto))
    b(hex_bytes, 2), b(crypto_data_hash, 3), b(crypto_n_random_bytes, 2),
    % UUID Generation and Formatting (library(uuid))
    b(uuid_string, 2), b(uuidv4, 1), b(uuidv4_string, 1),
    % CLP(B) Boolean Constraints (library(clpb))
    b(sat, 1), b(taut, 2), b(sat_count, 2), b(weighted_maximum, 3),
    % Files and Directories (library(files))
    b(directory_files, 2), b(file_size, 2), b(file_exists, 1), b(directory_exists, 1),
    b(path_canonical, 2), b(path_segments, 2), b(working_directory, 2),
    % Operating System Environment (library(os))
    b(getenv, 2), b(setenv, 2), b(unsetenv, 1), b(pid, 1), b(shell, 1), b(shell, 2),
    % Pure I/O (library(pio))
    b(phrase_from_file, 2), b(phrase_from_file, 3), b(phrase_from_stream, 2),
    b(phrase_to_file, 2), b(phrase_to_file, 3), b(phrase_to_stream, 2),
    % Linear Programming / Simplex (library(simplex))
    b(assignment, 2), b(constraint, 3), b(constraint, 4), b(constraint_add, 4),
    b(gen_state, 1), b(maximize, 3), b(minimize, 3), b(objective, 2),
    b(shadow_price, 3), b(transportation, 4), b(variable_value, 3),
    % Extended Arithmetic (library(arithmetic))
    b(expmod, 4), b(lcm, 3), b(lsb, 2), b(msb, 2),
    b(number_to_rational, 2), b(number_to_rational, 3),
    b(popcount, 2), b(rational_numerator_denominator, 3),
    % Coroutining / Delay (library(when))
    b(when, 2),
    % Declarative Debugging (library(debug))
    b(*, 1),
    % HTML and XML Parsing (library(sgml))
    b(load_html, 3), b(load_xml, 3),
    % XPath DOM Querying (library(xpath))
    b(xpath, 3), b(xpath_chk, 3),
    % WAM Diagnostics (library(diag))
    b(wam_instructions, 2), b(inlined_instructions, 2),
    % External Process Management (library(process))
    b(process_create, 3), b(process_id, 2), b(process_release, 1),
    b(process_wait, 2), b(process_wait, 3), b(process_kill, 1),
    % CLP(Z) Constraints
    b('#=', 2), b('#\\=', 2), b('#<', 2), b('#>', 2), b('#=<', 2), b('#>=', 2),
    b(in, 2), b(ins, 2), b(label, 1), b(labeling, 2)
]).

wrap_lambda_modules(Term, Wrapped) :-
    (   var(Term) ->
        Wrapped = Term
    ;   compound(Term) ->
        functor(Term, F, Arity),
        atom_chars(F, FChars),
        (   FChars = ['\\'], Arity =:= 1 ->
            arg(1, Term, Sub),
            wrap_lambda_modules(Sub, WSub),
            LambdaHead =.. [F, WSub],
            Wrapped = lambda:LambdaHead
        ;   FChars = ['+', '\\'], Arity =:= 2 ->
            arg(1, Term, GV),
            arg(2, Term, Sub),
            wrap_lambda_modules(Sub, WSub),
            LambdaHead =.. [F, GV, WSub],
            Wrapped = lambda:LambdaHead
        ;   FChars = ['^'], Arity =:= 2 ->
            arg(1, Term, V),
            arg(2, Term, Sub),
            wrap_lambda_modules(Sub, WSub),
            LambdaHead =.. [F, V, WSub],
            Wrapped = lambda:LambdaHead
        ;   Term =.. [F|Args],
            map_lambda_args(Args, WrappedArgs),
            Wrapped =.. [F|WrappedArgs]
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
crowlog_lib_clause(foldl(G, [X|Xs], [Y|Ys], A0, A), (call(G, X, Y, A0, A1), foldl(G, Xs, Ys, A1, A))).
crowlog_lib_clause(include(_, [], []), true).
crowlog_lib_clause(include(Goal, [X|Xs], Ys), (if_(call(Goal, X), Ys = [X|Zs], Ys = Zs), include(Goal, Xs, Zs))).
crowlog_lib_clause(exclude(_, [], []), true).
crowlog_lib_clause(exclude(Goal, [X|Xs], Ys), (if_(call(Goal, X), Ys = Zs, Ys = [X|Zs]), exclude(Goal, Xs, Zs))).

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
