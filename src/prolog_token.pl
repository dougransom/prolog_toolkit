:- module(prolog_token, [
    % Canonical Prolog Token API
    prolog_token_type/2,
    prolog_token_value/2,
    prolog_token_span/2,
    prolog_lift_token/3,
    prolog_unlift_token/2,

    % Backward-compatibility aliases
    token_type/2,
    token_value/2,
    token_span/2,
    lift_token/3,
    unlift_token/2
]).

:- use_module(library(lists)).

/** <module> Token Specification & Accessors

Option 3A Token Functors (Lifted):
  - var(NameChars, Span)
  - atom(NameChars, Span)
  - integer(IntValue, Span)
  - float(FloatValue, Span)
  - string(StringChars, Span)
  - open(Span)
  - open_ct(Span)
  - close(Span)
  - open_list(Span)
  - close_list(Span)
  - open_curly(Span)
  - close_curly(Span)
  - comma(Span)
  - bar(Span)
  - end(Span)
  - comment(Kind, ContentChars, Span)  % Kind = line | block

Unlifted Token Functors:
  - var(NameChars)
  - atom(NameChars)
  - integer(IntValue)
  - float(FloatValue)
  - string(StringChars)
  - open, open_ct, close
  - open_list, close_list
  - open_curly, close_curly
  - comma, bar, end
  - comment(Kind, ContentChars)
*/

% Lifted tokens
token_type(var(_, _), var).
token_type(atom(_, _), atom).
token_type(integer(_, _), integer).
token_type(float(_, _), float).
token_type(string(_, _), string).
token_type(open(_), open).
token_type(open_ct(_), open_ct).
token_type(close(_), close).
token_type(open_list(_), open_list).
token_type(close_list(_), close_list).
token_type(open_curly(_), open_curly).
token_type(close_curly(_), close_curly).
token_type(comma(_), comma).
token_type(bar(_), bar).
token_type(end(_), end).
token_type(comment(_, _, _), comment).

% Unlifted tokens
token_type(var(_), var).
token_type(atom(_), atom).
token_type(integer(_), integer).
token_type(float(_), float).
token_type(string(_), string).
token_type(open, open).
token_type(open_ct, open_ct).
token_type(close, close).
token_type(open_list, open_list).
token_type(close_list, close_list).
token_type(open_curly, open_curly).
token_type(close_curly, close_curly).
token_type(comma, comma).
token_type(bar, bar).
token_type(end, end).
token_type(comment(_, _), comment).

% Lifted token values
token_value(var(V, _), V).
token_value(atom(V, _), V).
token_value(integer(V, _), V).
token_value(float(V, _), V).
token_value(string(V, _), V).
token_value(open(_), '(').
token_value(open_ct(_), '(').
token_value(close(_), ')').
token_value(open_list(_), '[').
token_value(close_list(_), ']').
token_value(open_curly(_), '{').
token_value(close_curly(_), '}').
token_value(comma(_), ',').
token_value(bar(_), '|').
token_value(end(_), '.').
token_value(comment(_, Content, _), Content).

% Unlifted token values
token_value(var(V), V).
token_value(atom(V), V).
token_value(integer(V), V).
token_value(float(V), V).
token_value(string(V), V).
token_value(open, '(').
token_value(open_ct, '(').
token_value(close, ')').
token_value(open_list, '[').
token_value(close_list, ']').
token_value(open_curly, '{').
token_value(close_curly, '}').
token_value(comma, ',').
token_value(bar, '|').
token_value(end, '.').
token_value(comment(_, Content), Content).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Token Lifting & Span Macros
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

append_token_span(Atom, Span, Lifted) :-
    atom(Atom),
    Lifted =.. [Atom, Span].
append_token_span(Term, Span, Lifted) :-
    compound(Term),
    Term =.. [Functor|Args],
    append(Args, [Span], NewArgs),
    Lifted =.. [Functor|NewArgs].

generate_token_lift_and_span([], [], []).
generate_token_lift_and_span([T|Ts], [lift_token(T, Span, Lifted)|Lifts], [token_span(Lifted, Span)|Spans]) :-
    append_token_span(T, Span, Lifted),
    generate_token_lift_and_span(Ts, Lifts, Spans).

% Batch macro: generates contiguous lift_token/3 and token_span/2 definitions
term_expansion(define_token_shapes(Shapes), AllClauses) :-
    generate_token_lift_and_span(Shapes, LiftClauses, SpanClauses),
    append(LiftClauses, SpanClauses, AllClauses).

% Individual macro rules (e.g. lift_token_m, token_span_m)
term_expansion(lift_token_m(Unlifted, Span), lift_token(Unlifted, Span, Lifted)) :-
    append_token_span(Unlifted, Span, Lifted).
term_expansion(token_span_m(Unlifted), token_span(Lifted, Span)) :-
    append_token_span(Unlifted, Span, Lifted).

%% lift_token(?UnliftedToken, ?Span, ?LiftedToken)
%  Bidirectionally converts between an unlifted token and a lifted token with Span.
%  Generated via define_token_shapes/1 macro expansion.

%% token_span(+LiftedToken, -Span)
%  Extracts source span from a lifted token.
%  Generated via define_token_shapes/1 macro expansion.

define_token_shapes([
    var(_),
    atom(_),
    integer(_),
    float(_),
    string(_),
    open,
    open_ct,
    close,
    open_list,
    close_list,
    open_curly,
    close_curly,
    comma,
    bar,
    end,
    comment(_, _)
]).

%% unlift_token(+LiftedToken, -UnliftedToken)
% Strips the source span from a lifted token.
unlift_token(Lifted, Unlifted) :-
    lift_token(Unlifted, _, Lifted).

%% Canonical prolog_* predicate definitions
prolog_token_type(Tok, Type) :- token_type(Tok, Type).
prolog_token_value(Tok, Val) :- token_value(Tok, Val).
prolog_token_span(Tok, Span) :- token_span(Tok, Span).
prolog_lift_token(Unlifted, Span, Lifted) :- lift_token(Unlifted, Span, Lifted).
prolog_unlift_token(Lifted, Unlifted) :- unlift_token(Lifted, Unlifted).
