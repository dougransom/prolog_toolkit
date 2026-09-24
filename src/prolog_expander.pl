/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Term & Goal Expander

   Pure, modular macro and syntax expansion for ISO Prolog terms and statements.
   Supports:
   - expand_mode(none)      : Pass-through (raw AST)
   - expand_mode(pure_dcg)  : Pure ISO DCG rule translation (-->)
   - expand_mode(host)      : Delegation to host Prolog expand_term/2
   - expand_mode(delegate(Closure)) : Custom user-defined expansion hook
   - expand_mode(rules(Rules))      : Local user term_expansion rules
   - expand_mode(chained(Modes))    : Sequential chaining of expanders
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(prolog_expander, [
    prolog_initial_expander_state/2,
    prolog_expand_term/4,
    prolog_expand_term/5,
    prolog_expand_term_lineage/6,
    prolog_expand_statement/4,
    prolog_expand_statement/5,
    prolog_dcg_expand_rule/2
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

%% prolog_initial_expander_state(+Options, -State)
%  Initializes expander state: expander_state(Mode, LocalRules)
prolog_initial_expander_state(Options, expander_state(Mode, Rules)) :-
    if_(memberd_t(expand_mode(M), Options),
        Mode = M,
        Mode = none
    ),
    if_(memberd_t(expand_rules(R), Options),
        Rules = R,
        Rules = []
    ).

%% prolog_expand_term(+Options, +RawTerm, -ExpandedTerms, +StateIn, -StateOut)
prolog_expand_term(Options, RawTerm, ExpandedTerms, StateIn, StateOut) :-
    prolog_expand_term_lineage(Options, RawTerm, ExpandedTerms, _MacrosUsed, StateIn, StateOut).

%% prolog_expand_term(+Options, +RawTerm, -ExpandedTerms, -StateOut)
prolog_expand_term(Options, RawTerm, ExpandedTerms, StateOut) :-
    prolog_initial_expander_state(Options, State0),
    prolog_expand_term(Options, RawTerm, ExpandedTerms, State0, StateOut).

%% prolog_expand_term_lineage(+Options, +RawTerm, -ExpandedTerms, -MacrosUsed, +StateIn, -StateOut)
prolog_expand_term_lineage(Options, RawTerm, ExpandedTerms, MacrosUsed, StateIn, StateOut) :-
    StateIn = expander_state(Mode, Rules0),
    expand_by_mode_lineage(Mode, Options, RawTerm, Terms1, MacrosUsed, Rules0, Rules1),
    StateOut = expander_state(Mode, Rules1),
    flatten_terms(Terms1, ExpandedTerms).

expand_by_mode_lineage(none, _Options, Term, [Term], [], Rules, Rules).
expand_by_mode_lineage(pure_dcg, _Options, Term, Expanded, Macros, Rules, Rules) :-
    if_(Term = (Head --> Body),
        ( prolog_dcg_expand_rule((Head --> Body), Clause),
          Expanded = [Clause],
          Macros = [macro(dcg, (Head --> Body))]
        ),
        ( Expanded = [Term], Macros = [] )
    ).
expand_by_mode_lineage(host, _Options, Term, Expanded, Macros, Rules, Rules) :-
    catch(expand_term(Term, Res), _, Res = Term),
    if_(Res = Term,
        if_(Term = (_Head --> _Body),
            ( prolog_dcg_expand_rule(Term, Clause),
              Expanded = [Clause],
              Macros = [macro(dcg, Term)]
            ),
            ( Expanded = [Term], Macros = [] )
        ),
        ( wrap_list(Res, Expanded), Macros = [macro(host_term_expansion, expand_term/2)] )
    ).
expand_by_mode_lineage(delegate(Closure), _Options, Term, Expanded, Macros, Rules, Rules) :-
    catch(call(Closure, Term, Res), _, Res = Term),
    if_(Res = Term,
        Macros = [],
        Macros = [macro(delegate(Closure), Closure)]
    ),
    wrap_list(Res, Expanded).
expand_by_mode_lineage(rules(LocalRules), _Options, Term, Expanded, Macros, Rules0, RulesOut) :-
    append(Rules0, LocalRules, AllRules),
    apply_rules_expansion_lineage(AllRules, Term, Res, Macros, AllRules, RulesOut),
    wrap_list(Res, Expanded).
expand_by_mode_lineage(chained([]), _Options, Term, [Term], [], Rules, Rules).
expand_by_mode_lineage(chained([Mode|Modes]), Options, Term, Expanded, Macros, Rules0, RulesOut) :-
    expand_by_mode_lineage(Mode, Options, Term, Terms1, Macros1, Rules0, Rules1),
    expand_chained_list_lineage(Terms1, Modes, Options, Expanded, MacrosRest, Rules1, RulesOut),
    append(Macros1, MacrosRest, Macros).

wrap_list([], []) :- !.
wrap_list([H|T], [H|T]) :- !.
wrap_list(Term, [Term]).

expand_chained_list_lineage([], _Modes, _Options, [], [], Rules, Rules).
expand_chained_list_lineage([T|Ts], Modes, Options, Out, Macros, Rules0, RulesOut) :-
    expand_by_mode_lineage(chained(Modes), Options, T, Exp1, Mac1, Rules0, Rules1),
    expand_chained_list_lineage(Ts, Modes, Options, ExpRest, MacRest, Rules1, RulesOut),
    append(Exp1, ExpRest, Out),
    append(Mac1, MacRest, Macros).

%% apply_rules_expansion_lineage(+Rules, +TermIn, -TermOut, -Macros, +RulesIn, -RulesOut)
apply_rules_expansion_lineage([], Term, Term, [], Rules, Rules).
apply_rules_expansion_lineage([Rule|Rest], Term, Out, Macros, RulesIn, RulesOut) :-
    if_(Rule = rule(Head, Replacement, Meta),
        ( RuleHead = Head, RuleRepl = Replacement, RuleMeta = Meta ),
        if_(Rule = rule(Head, Replacement),
            ( RuleHead = Head, RuleRepl = Replacement, RuleMeta = none ),
            ( RuleHead = not_a_rule, RuleRepl = not_a_rule, RuleMeta = none )
        )
    ),
    (   subsumes_term(RuleHead, Term) ->
        copy_term(rule(RuleHead, RuleRepl), rule(Term, Out)),
        Macros = [macro(rule(RuleHead, RuleRepl), RuleMeta)],
        RulesOut = RulesIn
    ;   apply_rules_expansion_lineage(Rest, Term, Out, Macros, RulesIn, RulesOut)
    ).

flatten_terms([], []).
flatten_terms([[]|Ts], Out) :-
    !,
    flatten_terms(Ts, Out).
flatten_terms([[H|T]|Ts], Out) :-
    !,
    flatten_terms([H|T], FlatHead),
    flatten_terms(Ts, FlatTail),
    append(FlatHead, FlatTail, Out).
flatten_terms([T|Ts], [T|FlatTail]) :-
    flatten_terms(Ts, FlatTail).

%% prolog_expand_statement(+Options, +StatementIn, -StatementsOut, +StateIn, -StateOut)
prolog_expand_statement(Options, StatementIn, StatementsOut, StateIn, StateOut) :-
    if_(StatementIn = clause(Term, Meta),
        ( prolog_expand_term(Options, Term, ExpandedTerms, StateIn, StateOut),
          wrap_expanded_terms(ExpandedTerms, Meta, StatementsOut)
        ),
        if_(StatementIn = directive(Goal, Meta),
            ( if_(memberd_t(expand_directives(true), Options),
                  expand_directive_goal(Options, Goal, Meta, StatementsOut, StateIn, StateOut),
                  ( StatementsOut = [directive(Goal, Meta)],
                    StateOut = StateIn
                  )
              )
            ),
            ( StatementsOut = [StatementIn],
              StateOut = StateIn
            )
        )
    ).

expand_directive_goal(Options, Goal, Meta, StatementsOut, StateIn, StateOut) :-
    prolog_expand_term(Options, (:- Goal), Terms1, StateIn, State1),
    if_(Terms1 = [(:- Goal)],
        ( prolog_expand_term(Options, Goal, Terms2, State1, StateOut),
          wrap_expanded_directive_goals(Terms2, Meta, StatementsOut)
        ),
        ( wrap_expanded_terms(Terms1, Meta, StatementsOut),
          StateOut = State1
        )
    ).

wrap_expanded_directive_goals([], _, []).
wrap_expanded_directive_goals([T|Ts], Meta, [Stmt|Stmts]) :-
    if_(T = (:- Goal),
        Stmt = directive(Goal, Meta),
        Stmt = directive(T, Meta)
    ),
    wrap_expanded_directive_goals(Ts, Meta, Stmts).

%% prolog_expand_statement(+Options, +StatementIn, -StatementsOut, -StateOut)
prolog_expand_statement(Options, StatementIn, StatementsOut, StateOut) :-
    prolog_initial_expander_state(Options, State0),
    prolog_expand_statement(Options, StatementIn, StatementsOut, State0, StateOut).

wrap_expanded_terms([], _, []).
wrap_expanded_terms([Term|Terms], Meta, [Stmt|Stmts]) :-
    if_(Term = (:- Goal),
        Stmt = directive(Goal, Meta),
        if_(Term = (?- Goal),
            Stmt = query(Goal, Meta),
            Stmt = clause(Term, Meta)
        )
    ),
    wrap_expanded_terms(Terms, Meta, Stmts).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Pure ISO DCG Rule Expansion (-->)

   Translates:
     Head --> Body
   or:
     (Head, Pushback) --> Body
   into a Prolog clause:
     NewHead :- NewBody.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

%% prolog_dcg_expand_rule(+DCGRule, -Clause)
prolog_dcg_expand_rule(( NonTerminal, Terminals --> GRBody ), ( Head :- Body )) :-
    !,
    dcg_non_terminal(NonTerminal, S0, S, Head),
    dcg_body(GRBody, S0, S1, Goal1),
    dcg_terminals(Terminals, S, S1, Goal2),
    combine_goals(Goal1, Goal2, Body).
prolog_dcg_expand_rule(( NonTerminal --> GRBody ), Clause) :-
    dcg_non_terminal(NonTerminal, S0, S, Head),
    dcg_body(GRBody, S0, S, Body),
    if_(Body = true,
        Clause = Head,
        Clause = (Head :- Body)
    ).

dcg_non_terminal(NonTerminal, S0, S, Goal) :-
    NonTerminal =.. NonTerminalUniv,
    append(NonTerminalUniv, [S0, S], GoalUniv),
    Goal =.. GoalUniv.

dcg_terminals(Terminals, S0, S, S0 = List) :-
    append(Terminals, S, List).

dcg_body(Var, S0, S, phrase(Var, S0, S)) :-
    var(Var),
    !.
dcg_body([], S0, S, S0 = S) :- !.
dcg_body([T|Ts], S0, S, Goal) :-
    !,
    dcg_terminals([T|Ts], S0, S, Goal).
dcg_body(( GRFirst, GRSecond ), S0, S, ( First, Second )) :-
    !,
    dcg_body(GRFirst, S0, S1, First),
    dcg_body(GRSecond, S1, S, Second).
dcg_body(( GREither ; GROr ), S0, S, ( Either ; Or )) :-
    !,
    dcg_body(GREither, S0, S, Either),
    dcg_body(GROr, S0, S, Or).
dcg_body(( GREither '|' GROr ), S0, S, ( Either ; Or )) :-
    !,
    dcg_body(GREither, S0, S, Either),
    dcg_body(GROr, S0, S, Or).
dcg_body({Goal}, S0, S, Body) :-
    !,
    combine_goals(Goal, S0 = S, Body).
dcg_body(call(Cont), S0, S, call(Cont, S0, S)) :- !.
dcg_body(phrase(Body), S0, S, phrase(Body, S0, S)) :- !.
dcg_body(phrase(Body, Arg), S0, S, phrase(Body, Arg, S0, S)) :- !.
dcg_body(!, S0, S, ( !, S0 = S )) :- !.
dcg_body(( GRIf -> GRThen ), S0, S, ( If -> Then )) :-
    !,
    dcg_body(GRIf, S0, S1, If),
    dcg_body(GRThen, S1, S, Then).
dcg_body(NonTerminal, S0, S, Goal) :-
    dcg_non_terminal(NonTerminal, S0, S, Goal).

combine_goals(true, G, G) :- !.
combine_goals(G, true, G) :- !.
combine_goals(G1, G2, (G1, G2)).
