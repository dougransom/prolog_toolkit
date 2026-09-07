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

%% lift_token(?UnliftedToken, ?Span, ?LiftedToken)
% Bidirectionally converts between an unlifted token and a lifted token with Span.
lift_token(var(Name), Span, var(Name, Span)).
lift_token(atom(Name), Span, atom(Name, Span)).
lift_token(integer(Val), Span, integer(Val, Span)).
lift_token(float(Val), Span, float(Val, Span)).
lift_token(string(Chars), Span, string(Chars, Span)).
lift_token(open, Span, open(Span)).
lift_token(open_ct, Span, open_ct(Span)).
lift_token(close, Span, close(Span)).
lift_token(open_list, Span, open_list(Span)).
lift_token(close_list, Span, close_list(Span)).
lift_token(open_curly, Span, open_curly(Span)).
lift_token(close_curly, Span, close_curly(Span)).
lift_token(comma, Span, comma(Span)).
lift_token(bar, Span, bar(Span)).
lift_token(end, Span, end(Span)).
lift_token(comment(Kind, Content), Span, comment(Kind, Content, Span)).

%% unlift_token(+LiftedToken, -UnliftedToken)
% Strips the source span from a lifted token.
unlift_token(Lifted, Unlifted) :-
    lift_token(Unlifted, _, Lifted).

token_span(var(_, S), S).
token_span(atom(_, S), S).
token_span(integer(_, S), S).
token_span(float(_, S), S).
token_span(string(_, S), S).
token_span(open(S), S).
token_span(open_ct(S), S).
token_span(close(S), S).
token_span(open_list(S), S).
token_span(close_list(S), S).
token_span(open_curly(S), S).
token_span(close_curly(S), S).
token_span(comma(S), S).
token_span(bar(S), S).
token_span(end(S), S).
token_span(comment(_, _, S), S).

%% Canonical prolog_* predicate definitions
prolog_token_type(Tok, Type) :- token_type(Tok, Type).
prolog_token_value(Tok, Val) :- token_value(Tok, Val).
prolog_token_span(Tok, Span) :- token_span(Tok, Span).
prolog_lift_token(Unlifted, Span, Lifted) :- lift_token(Unlifted, Span, Lifted).
prolog_unlift_token(Lifted, Unlifted) :- unlift_token(Lifted, Unlifted).
