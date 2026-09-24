/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Term & Token Provenance (Attributed Variables)

   Provides provenance tracking for tokens, variables, and terms using
   Scryer Prolog's library(atts).
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(prolog_provenance, [
    % Attributed variable primitives
    put_provenance/2,
    get_provenance/2,
    is_provenance_var/1,
    make_provenance_var/2,

    % Token provenance
    create_token_provenance_var/5,
    tokens_annotate_provenance/3,

    % Term provenance & Macro lineage
    create_term_provenance_var/4,
    record_macro_expansion/4,

    % Accessors
    provenance_source/2,
    provenance_span/2,
    provenance_expansion/2,
    provenance_type/2,
    provenance_value/2,

    % Variable provenance annotation
    attach_variables_provenance/3
]).

:- use_module(library(atts)).
:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(prolog_token).

:- attribute provenance/1.

verify_attributes(Var, Other, []) :-
    get_atts(Var, provenance(Pa)), !,
    (   var(Other) ->
        (   get_atts(Other, provenance(Pb)) ->
            merge_provenance(Pb, Pa, PMerged),
            put_atts(Other, provenance(PMerged))
        ;   put_atts(Other, provenance(Pa))
        )
    ;   true
    ).
verify_attributes(_, _, []).

merge_provenance(var_provenance(Name, Spans1, Source), var_provenance(_, Spans2, _), var_provenance(Name, MergedSpans, Source)) :-
    append(Spans1, Spans2, MergedSpans), !.
merge_provenance(P1, _P2, P1).

put_provenance(Var, Prov) :-
    put_atts(Var, provenance(Prov)).

get_provenance(Var, Prov) :-
    get_atts(Var, provenance(Prov)).

is_provenance_var(Var) :-
    var(Var),
    get_provenance(Var, _).

make_provenance_var(Prov, Var) :-
    put_provenance(Var, Prov).

create_token_provenance_var(Type, Value, Span, Source, Var) :-
    make_provenance_var(token_provenance(Type, Value, Span, Source), Var).

create_term_provenance_var(Source, Span, Expansion, Var) :-
    make_provenance_var(term_provenance(Source, Span, Expansion), Var).

provenance_source(token_provenance(_, _, _, Source), Source).
provenance_source(term_provenance(Source, _, _), Source).
provenance_source(var_provenance(_, _, Source), Source).
provenance_source(Var, Source) :-
    var(Var),
    get_provenance(Var, Prov),
    provenance_source(Prov, Source).

provenance_span(token_provenance(_, _, Span, _), Span).
provenance_span(term_provenance(_, Span, _), Span).
provenance_span(var_provenance(_, Span, _), Span).
provenance_span(Var, Span) :-
    var(Var),
    get_provenance(Var, Prov),
    provenance_span(Prov, Span).

provenance_expansion(term_provenance(_, _, Expansion), Expansion).
provenance_expansion(Var, Expansion) :-
    var(Var),
    get_provenance(Var, Prov),
    provenance_expansion(Prov, Expansion).

provenance_type(token_provenance(Type, _, _, _), Type).
provenance_type(Var, Type) :-
    var(Var),
    get_provenance(Var, Prov),
    provenance_type(Prov, Type).

provenance_value(token_provenance(_, Value, _, _), Value).
provenance_value(Var, Value) :-
    var(Var),
    get_provenance(Var, Prov),
    provenance_value(Prov, Value).

record_macro_expansion(Source, Span, ExpansionInfo, Var) :-
    create_term_provenance_var(Source, Span, ExpansionInfo, Var).

tokens_annotate_provenance([], _Source, []).
tokens_annotate_provenance([Tok|Toks], Source, [AnnotatedTok|AnnotatedRest]) :-
    token_type(Tok, Type),
    token_value(Tok, Value),
    token_span(Tok, Span),
    create_token_provenance_var(Type, Value, Span, Source, AttrVar),
    AnnotatedTok = token_ex(Type, Value, Span, Source, AttrVar),
    tokens_annotate_provenance(Toks, Source, AnnotatedRest).

attach_variables_provenance([], _Source, _Options).
attach_variables_provenance([Detail|Details], Source, Options) :-
    if_(Detail = var_detail(NameChars, Var, _Count, Spans),
        ( atom_chars(NameAtom, NameChars),
          put_provenance(Var, var_provenance(NameAtom, Spans, Source))
        ),
        if_(Detail = anon_var_detail(Var, Spans),
            put_provenance(Var, var_provenance('_', Spans, Source)),
            true
        )
    ),
    attach_variables_provenance(Details, Source, Options).
