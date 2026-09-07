/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Operator Precedence Table

   Pure ISO Prolog operator precedence table management with per-module
   scoping and dynamic operator declarations (op/3).
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(operator_table, [
    default_operator_table/1,
    add_operator/5,
    lookup_infix_op/6,
    lookup_prefix_op/5,
    lookup_postfix_op/5,
    is_operator/4,
    op_chars/2
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

%% default_operator_table(-OpTable)
%  Initializes standard ISO Prolog operator table (0..1200 scale).
default_operator_table(op_table(Ops)) :-
    Ops = [
        % Clauses and Rules (1200)
        op(1200, xfx, ":-"),
        op(1200, xfx, "-->"),
        op(1200,  fx, ":-"),
        op(1200,  fx, "?-"),

        % Directive Specifiers (1150)
        op(1150,  fx, "dynamic"),
        op(1150,  fx, "discontiguous"),
        op(1150,  fx, "initialization"),
        op(1150,  fx, "multifile"),
        op(1150,  fx, "module"),

        % Control Constructs (1100, 1050, 1000)
        op(1100, xfy, ";"),
        op(1100, xfy, "|"),
        op(1050, xfy, "->"),
        op(1050, xfy, "*->"),
        op(1000, xfy, ","),

        % Negation (900)
        op( 900,  fy, "\\+"),
        op( 900,  fy, "not"),

        % Comparison & Unification (700)
        op( 700, xfx, "="),
        op( 700, xfx, "\\="),
        op( 700, xfx, "=="),
        op( 700, xfx, "\\=="),
        op( 700, xfx, "@<"),
        op( 700, xfx, "@=<"),
        op( 700, xfx, "@>"),
        op( 700, xfx, "@>="),
        op( 700, xfx, "=.."),
        op( 700, xfx, "=:="),
        op( 700, xfx, "=\\="),
        op( 700, xfx, "<"),
        op( 700, xfx, "=<"),
        op( 700, xfx, ">"),
        op( 700, xfx, ">="),
        op( 700, xfx, "is"),

        % Module Qualification (600)
        op( 600, xfy, ":"),

        % Arithmetic Additive & Bitwise (500)
        op( 500, yfx, "+"),
        op( 500, yfx, "-"),
        op( 500, yfx, "/\\"),
        op( 500, yfx, "\\/"),

        % Arithmetic Multiplicative (400)
        op( 400, yfx, "*"),
        op( 400, yfx, "/"),
        op( 400, yfx, "//"),
        op( 400, yfx, "div"),
        op( 400, yfx, "rem"),
        op( 400, yfx, "mod"),
        op( 400, yfx, "<<"),
        op( 400, yfx, ">>"),

        % Power & Bitwise Negation (200)
        op( 200, xfx, "**"),
        op( 200, xfy, "^"),
        op( 200,  fy, "-"),
        op( 200,  fy, "+"),
        op( 200,  fy, "\\")
    ].

%% op_chars(+Op, -Chars)
%  Normalizes Op (atom, chars) into a list of characters.
op_chars(Op, Chars) :-
    (   atom_si(Op) ->
        atom_chars(Op, Chars)
    ;   Chars = Op
    ).

% Base case: empty operator list
add_operator(Table0, _, _, [], Table0) :- !.
% Single operator registration: Op is an atom or character list (e.g. "div").
% Cut commits to single operator registration, preventing a chars string
% from being mistakenly decomposed as a list of separate operator names.
add_operator(op_table(Ops0), Prec, Spec, Op, op_table(OpsOut)) :-
    ( atom_si(Op) ; chars_si(Op) ), !,
    op_chars(Op, Chars),
    if_(Prec #= 0,
        remove_matching_op(Ops0, Spec, Chars, OpsOut),
        ( remove_matching_op(Ops0, Spec, Chars, CleanOps),
          OpsOut = [op(Prec, Spec, Chars)|CleanOps] )
    ).
% Batch operator registration: Op is a list of multiple operators: [+, -, *].
add_operator(Table0, Prec, Spec, [Op|Ops], TableOut) :- !,
    add_operator(Table0, Prec, Spec, Op, Table1),
    add_operator(Table1, Prec, Spec, Ops, TableOut).

remove_matching_op([], _, _, []).
remove_matching_op([op(P, S, C)|Rest], Spec, Chars, Out) :-
    if_(S = Spec,
        if_(C = Chars,
            remove_matching_op(Rest, Spec, Chars, Out),
            ( Out = [op(P, S, C)|OutRest],
              remove_matching_op(Rest, Spec, Chars, OutRest) )
        ),
        ( Out = [op(P, S, C)|OutRest],
          remove_matching_op(Rest, Spec, Chars, OutRest) )
    ).

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
