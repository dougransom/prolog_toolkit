/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Operator Precedence Table

   Pure ISO Prolog operator precedence table management with per-module
   scoping and dynamic operator declarations (op/3).
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(prolog_operator_table, [
    % Canonical Prolog Operator Table API
    prolog_default_operator_table/1,
    prolog_add_operator/5,
    prolog_lookup_infix_op/6,
    prolog_lookup_prefix_op/5,
    prolog_lookup_postfix_op/5,
    prolog_is_operator/4,
    prolog_op_chars/2,
    prolog_import_exported_ops/3,
    prolog_expand_operator_specs/2,
    prolog_expand_operator_spec/2,

    % Backward-compatibility aliases
    default_operator_table/1,
    default_operator_specs/1,
    add_operator/3,
    add_operator/5,
    lookup_infix_op/6,
    lookup_prefix_op/5,
    lookup_postfix_op/5,
    is_operator/4,
    op_chars/2,
    import_exported_ops/3,
    expand_operator_specs/2,
    expand_operator_spec/2
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

%% default_operator_table(-OpTable)
%  Initializes standard ISO Prolog operator table (0..1200 scale)
%  expanded from concise, structured operator group specifications.
prolog_default_operator_table(op_table(Ops)) :-
    default_operator_specs(Specs),
    expand_operator_specs(Specs, Ops).
default_operator_table(Table) :-
    prolog_default_operator_table(Table).

%% default_operator_specs(-Specs)
%  Standard ISO/IEC 13211-1 built-in operator specifications grouped by precedence and fixity.
%  Library-specific operators (e.g. CLP, XPath, Lambda) are excluded and dynamically
%  imported upon use_module/1,2.
default_operator_specs([
    % Clauses and Rules (1200)
    op_spec(1200, xfx, [":-", "-->"]),
    op_spec(1200,  fx, [":-", "?-"]),

    % Directive Specifiers (1150)
    op_spec(1150,  fx, ["dynamic", "discontiguous", "initialization", "multifile", "module"]),

    % Control Constructs (1100, 1050, 1000)
    op_spec(1100, xfy, [";", "|"]),
    op_spec(1050, xfy, ["->", "*->"]),
    op_spec(1000, xfy, [","]),

    % Negation (900)
    op_spec( 900,  fy, ["\\+", "not"]),

    % Comparison & Unification (700)
    op_spec( 700, xfx, ["=", "\\=", "==", "\\==", "@<", "@=<", "@>", "@>=", "=..", "=:=", "=\\=", "<", "=<", ">", ">=", "is"]),
    op_spec( 700,  fx, ["non_counted_backtracking"]),

    % Module Qualification (600)
    op_spec( 600, xfy, [":"]),

    % Arithmetic Additive & Bitwise (500)
    op_spec( 500, yfx, ["+", "-", "/\\", "\\/"]),

    % Arithmetic Multiplicative (400)
    op_spec( 400, yfx, ["*", "/", "//", "rdiv", "div", "rem", "mod", "<<", ">>"]),

    % Power & Bitwise Negation (200)
    op_spec( 200, xfx, ["**"]),
    op_spec( 200, xfy, ["^"]),
    op_spec( 200,  fy, ["-", "+", "\\"])
]).

%% expand_operator_specs(+Specs, -ExpandedOps)
%  Expands structured operator specifications (op_spec/3, operator_group/3, or op/3)
%  into a canonical flat list of op(Prec, Fixity, OpChars).
prolog_expand_operator_specs(Specs, ExpandedOps) :-
    phrase(expand_specs(Specs), ExpandedOps).
expand_operator_specs(Specs, ExpandedOps) :-
    prolog_expand_operator_specs(Specs, ExpandedOps).

%% expand_operator_spec(+Spec, -ExpandedOps)
%  Expands a single operator specification group into a list of op/3 terms.
prolog_expand_operator_spec(Spec, ExpandedOps) :-
    phrase(expand_spec(Spec), ExpandedOps).
expand_operator_spec(Spec, ExpandedOps) :-
    prolog_expand_operator_spec(Spec, ExpandedOps).

expand_specs([]) --> [].
expand_specs([Spec|Specs]) -->
    expand_spec(Spec),
    expand_specs(Specs).

expand_spec(op_spec(Prec, Fixity, Names)) -->
    expand_op_names(Names, Prec, Fixity).
expand_spec(operator_group(Prec, Fixity, Names)) -->
    expand_op_names(Names, Prec, Fixity).
expand_spec(ops(Prec, Fixity, Names)) -->
    expand_op_names(Names, Prec, Fixity).
expand_spec(op(Prec, Fixity, Name)) -->
    expand_single_or_list_op(Name, Prec, Fixity).

expand_single_or_list_op(Name, Prec, Fixity) -->
    { chars_si(Name) },
    !,
    { op_chars(Name, Chars) },
    [op(Prec, Fixity, Chars)].
expand_single_or_list_op(Name, Prec, Fixity) -->
    { atom_si(Name) },
    !,
    { op_chars(Name, Chars) },
    [op(Prec, Fixity, Chars)].
expand_single_or_list_op(Names, Prec, Fixity) -->
    { list_si(Names) },
    expand_op_names(Names, Prec, Fixity).

expand_op_names([], _, _) --> [].
expand_op_names([Name|Names], Prec, Fixity) -->
    { op_chars(Name, Chars) },
    [op(Prec, Fixity, Chars)],
    expand_op_names(Names, Prec, Fixity).

%% op_chars(+Op, -Chars)
%  Normalizes Op (atom, chars) into a list of characters.
prolog_op_chars(Op, Chars) :-
    (   atom_si(Op) ->
        atom_chars(Op, Chars)
    ;   Chars = Op
    ).
op_chars(Op, Chars) :-
    prolog_op_chars(Op, Chars).

%% add_operator(+Table0, +SpecGroup, -TableOut)
%  Adds an operator group specification to the table.
add_operator(Table0, op_spec(Prec, Spec, Names), TableOut) :-
    add_operator(Table0, Prec, Spec, Names, TableOut).
add_operator(Table0, operator_group(Prec, Spec, Names), TableOut) :-
    add_operator(Table0, Prec, Spec, Names, TableOut).
add_operator(Table0, ops(Prec, Spec, Names), TableOut) :-
    add_operator(Table0, Prec, Spec, Names, TableOut).

% Base case: empty operator list
add_operator(Table0, _, _, [], Table0) :- !.
% Single operator registration: Op is an atom or character list (e.g. "div").
% Cut commits to single operator registration, preventing a chars string
% from being mistakenly decomposed as a list of separate operator names.
add_operator(op_table(Ops0), Prec, Spec, Op, op_table(OpsOut)) :-
    ( atom_si(Op) ; chars_si(Op) ), !,
    op_chars(Op, Chars),
    remove_matching_op(Ops0, Spec, Chars, CleanOps),
    if_(Prec #= 0,
        OpsOut = CleanOps,
        OpsOut = [op(Prec, Spec, Chars)|CleanOps]
    ).
% Batch operator registration: Op is a list of multiple operators: [+, -, *].
add_operator(Table0, Prec, Spec, [Op|Ops], TableOut) :- !,
    add_operator(Table0, Prec, Spec, Op, Table1),
    add_operator(Table1, Prec, Spec, Ops, TableOut).

prolog_import_exported_ops([], T, T).
prolog_import_exported_ops([Item|Rest], T0, TOut) :-
    if_(Item = op(P, S, O),
        prolog_add_operator(T0, P, S, O, T1),
        T1 = T0
    ),
    prolog_import_exported_ops(Rest, T1, TOut).

import_exported_ops(Exports, T0, TOut) :-
    prolog_import_exported_ops(Exports, T0, TOut).

remove_matching_op(Ops0, Spec, Chars, OpsOut) :-
    tfilter(op_differs_t(Spec, Chars), Ops0, OpsOut).

op_differs_t(Spec, Chars, op(_, S, C), Truth) :-
    dif(S-C, Spec-Chars, Truth).

%% lookup_infix_op(+Table, +OpName, -Prec, -Fixity, -LeftMaxPrec, -RightMaxPrec)
lookup_infix_op(op_table(Ops), OpName, Prec, Fixity, LeftMaxPrec, RightMaxPrec) :-
    op_chars(OpName, Chars),
    member(op(Prec, Fixity, Chars), Ops),
    infix_fixity_precedences(Fixity, Prec, LeftMaxPrec, RightMaxPrec).

infix_fixity_precedences(yfx, Prec, Prec, R) :- R #= Prec - 1.
infix_fixity_precedences(xfy, Prec, L, Prec) :- L #= Prec - 1.
infix_fixity_precedences(xfx, Prec, L, R)    :- L #= Prec - 1, R #= Prec - 1.

%% lookup_prefix_op(+Table, +OpName, -Prec, -Fixity, -RightMaxPrec)
lookup_prefix_op(op_table(Ops), OpName, Prec, Fixity, RightMaxPrec) :-
    op_chars(OpName, Chars),
    member(op(Prec, Fixity, Chars), Ops),
    prefix_fixity_precedence(Fixity, Prec, RightMaxPrec).

prefix_fixity_precedence(fx, Prec, R) :- R #= Prec - 1.
prefix_fixity_precedence(fy, Prec, Prec).

%% lookup_postfix_op(+Table, +OpName, -Prec, -Fixity, -LeftMaxPrec)
lookup_postfix_op(op_table(Ops), OpName, Prec, Fixity, LeftMaxPrec) :-
    op_chars(OpName, Chars),
    member(op(Prec, Fixity, Chars), Ops),
    postfix_fixity_precedence(Fixity, Prec, LeftMaxPrec).

postfix_fixity_precedence(xf, Prec, L) :- L #= Prec - 1.
postfix_fixity_precedence(yf, Prec, Prec).

%% is_operator(+Table, ?OpName, ?Prec, ?Fixity)
is_operator(op_table(Ops), OpName, Prec, Fixity) :-
    member(op(Prec, Fixity, Chars), Ops),
    op_chars(OpName, Chars).

%% Canonical prolog_* predicate aliases
prolog_add_operator(T0, Prec, Fixity, Name, T1) :- add_operator(T0, Prec, Fixity, Name, T1).
prolog_lookup_infix_op(Table, OpName, Prec, Fixity, LeftMaxPrec, RightMaxPrec) :-
    lookup_infix_op(Table, OpName, Prec, Fixity, LeftMaxPrec, RightMaxPrec).
prolog_lookup_prefix_op(Table, OpName, Prec, Fixity, RightMaxPrec) :-
    lookup_prefix_op(Table, OpName, Prec, Fixity, RightMaxPrec).
prolog_lookup_postfix_op(Table, OpName, Prec, Fixity, LeftMaxPrec) :-
    lookup_postfix_op(Table, OpName, Prec, Fixity, LeftMaxPrec).
prolog_is_operator(Table, OpName, Prec, Fixity) :-
    is_operator(Table, OpName, Prec, Fixity).
