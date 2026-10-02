/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Module Tools & Macro Expansion
   
   Pure ISO Prolog helpers for:
   - Concise batch operator specification (op_spec/3, operator_group/3)
   - Macro expansion of operator groups into canonical op/3 lists
   - Module export filtering (separating predicate indicators from operators)
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(module_tools, [
    expand_operator_specs/2,
    expand_operator_spec/2,
    extract_exported_operators/2,
    extract_exported_predicates/2,
    module_exports_partition/3
]).

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(prolog_operator_table, [
    expand_operator_specs/2,
    expand_operator_spec/2,
    op_chars/2
]).

%% extract_exported_operators(+Exports, -Operators)
%  Extracts and expands all operator declarations (both single op/3 and op_spec/3 groups)
%  from a module header export list.
extract_exported_operators([], []).
extract_exported_operators([Item|Rest], OpsOut) :-
    (   is_operator_spec(Item) ->
        expand_operator_spec(Item, Expanded),
        append(Expanded, OpsRest, OpsOut),
        extract_exported_operators(Rest, OpsRest)
    ;   extract_exported_operators(Rest, OpsOut)
    ).

%% extract_exported_predicates(+Exports, -Predicates)
%  Extracts all Name/Arity and Name//Arity predicate indicators from a module header export list.
extract_exported_predicates([], []).
extract_exported_predicates([Item|Rest], PredsOut) :-
    (   is_predicate_indicator(Item) ->
        PredsOut = [Item|PredsRest],
        extract_exported_predicates(Rest, PredsRest)
    ;   extract_exported_predicates(Rest, PredsOut)
    ).

%% module_exports_partition(+Exports, -Predicates, -Operators)
%  Partitions a module export list into predicate indicators and expanded operators.
module_exports_partition(Exports, Predicates, Operators) :-
    list_si(Exports),
    extract_exported_predicates(Exports, Predicates),
    extract_exported_operators(Exports, Operators).

is_operator_spec(op(_, _, _)).
is_operator_spec(op_spec(_, _, _)).
is_operator_spec(operator_group(_, _, _)).
is_operator_spec(ops(_, _, _)).

is_predicate_indicator(Name/Arity) :-
    atom_si(Name),
    integer_si(Arity),
    Arity #>= 0.
is_predicate_indicator(Name//Arity) :-
    atom_si(Name),
    integer_si(Arity),
    Arity #>= 0.
