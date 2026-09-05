:- module(position, [
    pos_line/2,
    pos_col/2,
    pos_offset/2,
    pos_source/2,
    span_start/2,
    span_end/2,
    combine_spans/3,
    advance_pos/3
]).

/** <module> Position & Source Span Coordinates

Representations:
  - pos(Line, Col, Offset, SourceDesc)
  - span(StartPos, EndPos)
*/

:- use_module(library(clpz)).
:- use_module(library(dif)).

pos_line(pos(L, _, _, _), L).
pos_col(pos(_, C, _, _), C).
pos_offset(pos(_, _, O, _), O).
pos_source(pos(_, _, _, S), S).

span_start(span(Start, _), Start).
span_end(span(_, End), End).

combine_spans(span(Start1, _), span(_, End2), span(Start1, End2)).

%% advance_pos(+PosIn, +Chars, -PosOut)
% Advances source coordinates across a sequence of characters.
advance_pos(Pos, [], Pos).
advance_pos(pos(L0, _, O0, S), ['\n'|Cs], PosOut) :-
    L1 #= L0 + 1,
    O1 #= O0 + 1,
    advance_pos(pos(L1, 1, O1, S), Cs, PosOut).
advance_pos(pos(L0, C0, O0, S), [C|Cs], PosOut) :-
    dif(C, '\n'),
    C1 #= C0 + 1,
    O1 #= O0 + 1,
    advance_pos(pos(L0, C1, O1, S), Cs, PosOut).
