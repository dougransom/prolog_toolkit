:- module(prolog_lifted_lexer, [
    % Canonical Prolog Lifted Lexer API
    prolog_lifted_tokens//1,
    prolog_lifted_tokens//2,
    prolog_lifted_clause_tokens//1,
    prolog_lifted_clause_tokens//2,
    prolog_lifted_token//1,
    prolog_lifted_token//2,
    prolog_lifted_tokenize/2,
    prolog_lifted_tokenize/3,
    prolog_annotated_skip_layout/6,
    prolog_annotated_scan_single_token/5,

    % Backward-compatibility aliases
    lifted_tokens//1,
    lifted_tokens//2,
    lifted_clause_tokens//1,
    lifted_clause_tokens//2,
    lifted_token//1,
    lifted_token//2,
    lifted_tokenize/2,
    lifted_tokenize/3,
    annotated_skip_layout/6,
    annotated_scan_single_token/5
]).

/** <module> Lifted DCG Lexical Analyzer

Tokenizes character streams into lifted tokens with source spans.
Derives annotated DCG rules from prolog_lexer_rules:grammar_rule/2 using
parser_experiments:dcg_annotator (dcg_node_rule/2 and dcg_helper_rule/2).
Runs directly on the annotated stream ([annot/5]).
*/

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dcgs)).
:- use_module(library(dif)).
:- use_module(library(lists), [append/2, append/3, member/2]).
:- use_module(library(reif)).
:- use_module('../../parser_experiments/src/stream_annotator', [
    annotated_seq//3,
    default_annot_step/3
]).
:- use_module('../../parser_experiments/src/annotate_position', [
    init_position_state/2,
    annotate_position_pos/2,
    advance_pos/3
]).
:- use_module('../../parser_experiments/src/dcg_annotator', [
    dcg_node_rule/2,
    dcg_helper_rule/2,
    span//2,
    consumed_last/3
]).
:- use_module(prolog_token).
:- use_module(prolog_lexer_regex, [digits_to_int/3, prolog_digits_to_int/3]).
:- use_module(prolog_lexer_rules, [
    grammar_rule/2,
    char_to_esc/2,
    is_graphic_char/1
]).

% Expand shared DCG rules into annotated DCG rules on [annot/5]
user:term_expansion(import_lifted_rules, ExpandedRules) :-
    findall(AnnotRule,
            ( ( grammar_rule(node, Rule0), dcg_node_rule(Rule0, AnnotRule) )
            ; ( grammar_rule(helper, Rule0), dcg_helper_rule(Rule0, AnnotRule) )
            ),
            ExpandedRules).

import_lifted_rules.

%% lifted_tokens(-Tokens)//
% Tokenizes plain characters into lifted tokens with source spans.
lifted_tokens(Tokens) -->
    lifted_tokens([], Tokens).

%% lifted_tokens(+Options, -Tokens)//
% Tokenizes plain characters with Options into lifted tokens with source spans.
lifted_tokens(Options, Tokens, CharsIn, CharsOut) :-
    init_position_state("<input>", State0),
    phrase(annotated_seq(default_annot_step, State0, AnnotatedStream), CharsIn, CharsOut),
    annotated_tokens(Options, Tokens, AnnotatedStream, []).

%% lifted_tokenize(+Chars, -Tokens)
% Convenience wrapper for phrase(lifted_tokens(Tokens), Chars).
lifted_tokenize(Chars, Tokens) :-
    phrase(lifted_tokens([], Tokens), Chars).

%% lifted_tokenize(+Options, +Chars, -Tokens)
% Convenience wrapper for phrase(lifted_tokens(Options, Tokens), Chars).
lifted_tokenize(Options, Chars, Tokens) :-
    phrase(lifted_tokens(Options, Tokens), Chars).

%% lifted_clause_tokens(-Tokens)//
% Scans lifted tokens up to and including the next full stop end(_) token.
lifted_clause_tokens(Tokens) -->
    lifted_clause_tokens([], Tokens).

%% lifted_clause_tokens(+Options, -Tokens)//
% Scans lifted tokens with Options up to and including the next full stop end(_) token.
lifted_clause_tokens(Options, Tokens, CharsIn, CharsOut) :-
    init_position_state("<input>", State0),
    phrase(annotated_seq(default_annot_step, State0, AnnotatedStream), CharsIn),
    annotated_clause_tokens(Options, Tokens, AnnotatedStream, RestAnnotated),
    annotated_stream_to_chars(RestAnnotated, CharsOut).

%% lifted_token(-Token)//
% Scans a single lifted token with source span.
lifted_token(Token) -->
    lifted_token([], Token).

%% lifted_token(+Options, -Token)//
% Scans a single lifted token with Options and source span.
lifted_token(Options, Token, CharsIn, CharsOut) :-
    init_position_state("<input>", State0),
    phrase(annotated_seq(default_annot_step, State0, AnnotatedStream), CharsIn),
    annotated_skip_layout(AnnotatedStream, true, Options, StreamAfterLayout, LayoutBefore, _),
    dif(StreamAfterLayout, []),
    annotated_scan_single_token(LayoutBefore, Options, Token, StreamAfterLayout, RestAnnotated),
    annotated_stream_to_chars(RestAnnotated, CharsOut).

% -------------------------------------------------------------------------
% Annotated Stream Processors (Direct Execution on annot/5)
% -------------------------------------------------------------------------

annotated_tokens(Options, Tokens, StreamIn, StreamOut) :-
    annotated_tokens_step(true, Options, Tokens, StreamIn, StreamOut).

annotated_tokens_step(_, Options, [], [], []) :-
    if_(memberd_t(comments(CommentsOut), Options),
        CommentsOut = [],
        true
    ).
annotated_tokens_step(LayoutBefore0, Options, Tokens, [Item|RestItems], StreamOut) :-
    annotated_skip_layout([Item|RestItems], LayoutBefore0, Options, NonLayoutStream, LayoutBefore1, Comments),
    if_(NonLayoutStream = [],
        ( if_(memberd_t(comments(CommentsOut), Options), CommentsOut = Comments, true),
          Tokens = [],
          StreamOut = []
        ),
        ( annotated_scan_single_token(LayoutBefore1, Options, Token, NonLayoutStream, RestStream),
          annotated_tokens_step(false, Options, RestTokens, RestStream, StreamOut),
          Tokens = [Token|RestTokens]
        )
    ).

annotated_clause_tokens(Options, Tokens, StreamIn, StreamOut) :-
    annotated_clause_step(true, Options, Tokens, StreamIn, StreamOut).

annotated_clause_step(_, _, [], [], []).
annotated_clause_step(LayoutBefore0, Options, Tokens, [Item|RestItems], StreamOut) :-
    annotated_skip_layout([Item|RestItems], LayoutBefore0, Options, NonLayoutStream, LayoutBefore1, _),
    if_(NonLayoutStream = [],
        ( Tokens = [], StreamOut = [] ),
        ( annotated_scan_single_token(LayoutBefore1, Options, Token, NonLayoutStream, RestStream),
          if_(Token = end(_),
              ( Tokens = [Token],
                StreamOut = RestStream
              ),
              ( annotated_clause_step(false, Options, RestTokens, RestStream, StreamOut),
                Tokens = [Token|RestTokens]
              )
          )
        )
    ).

% -------------------------------------------------------------------------
% Single Lifted Token Scanner (Runs annot_scan_token Directly on annot/5)
% -------------------------------------------------------------------------

% Lookahead test for statement full stop: '.' must be followed by layout, line comment '%',
% block comment opener '/*', or end-of-file.
is_full_stop_lookahead([], true).
is_full_stop_lookahead([annot('/', _, _, _, _), annot('*', _, _, _, _)|_], true) :- !.
is_full_stop_lookahead([annot(C, _, _, _, _)|_], Truth) :-
    memberd_t(C, [' ', '\t', '\r', '\n', '\v', '\f', '%'], Truth).

% Deterministic lookahead dispatch:
% 1. Full stop (.): must be followed by layout/comment or EOF to terminate a clause;
%    otherwise, treat as part of a graphic token (e.g. '...').
% 2. Open parenthesis ((): distinguished by preceding layout into open vs open_ct.
% 3. All other tokens: standard BNF scanner rule match.
annotated_scan_single_token(LayoutBefore, _Options, LiftedToken, StreamIn, StreamOut) :-
    (   StreamIn = [annot('.', L, Col, Off, Src)|AfterDot],
        is_full_stop_lookahead(AfterDot, true) ->
        StreamOut = AfterDot,
        StartPos = pos(L, Col, Off, Src),
        advance_pos(StartPos, ['.'], EndPos),
        LiftedToken = end(span(StartPos, EndPos))
    ;   StreamIn = [annot('(', _, _, _, _)|_] ->
        if_(LayoutBefore = true, ParenType = open, ParenType = open_ct),
        phrase(annot_scan_paren(node(ParenType, BaseSpan)), StreamIn, StreamOut),
        half_open_span(BaseSpan, StreamIn, StreamOut, Span),
        lift_token(ParenType, Span, LiftedToken)
    ;   phrase(annot_scan_token(node(UnliftedToken, BaseSpan)), StreamIn, StreamOut),
        half_open_span(BaseSpan, StreamIn, StreamOut, Span),
        lift_token(UnliftedToken, Span, LiftedToken)
    ).

% -------------------------------------------------------------------------
% Layout & Comment Stripping on Annotated Stream
% -------------------------------------------------------------------------

annotated_skip_layout([], LayoutBefore, _, [], LayoutBefore, []).
annotated_skip_layout([annot('%', _, _, _, _)|Cs], _LayoutBefore0, Options, StreamOut, LayoutBeforeOut, [CommentToken|RestComments]) :-
    phrase(annot_scan_comment(node(comment(line, Content), BaseSpan)), [annot('%', _, _, _, _)|Cs], Rest),
    half_open_span(BaseSpan, [annot('%', _, _, _, _)|Cs], Rest, Span),
    lift_token(comment(line, Content), Span, CommentToken),
    annotated_skip_layout(Rest, true, Options, StreamOut, LayoutBeforeOut, RestComments).
annotated_skip_layout([annot('/', _, _, _, _), annot('*', _, _, _, _)|Cs], _LayoutBefore0, Options, StreamOut, LayoutBeforeOut, [CommentToken|RestComments]) :-
    if_(memberd_t(comments_nesting(true), Options),
        phrase(annot_scan_nested_comment(node(comment(block, Content), BaseSpan)), [annot('/', _, _, _, _), annot('*', _, _, _, _)|Cs], Rest),
        phrase(annot_scan_comment(node(comment(block, Content), BaseSpan)), [annot('/', _, _, _, _), annot('*', _, _, _, _)|Cs], Rest)
    ),
    half_open_span(BaseSpan, [annot('/', _, _, _, _), annot('*', _, _, _, _)|Cs], Rest, Span),
    lift_token(comment(block, Content), Span, CommentToken),
    annotated_skip_layout(Rest, true, Options, StreamOut, LayoutBeforeOut, RestComments).
annotated_skip_layout([annot(C, L, Col, Off, Src)|Cs], LayoutBefore0, Options, StreamOut, LayoutBeforeOut, CommentsOut) :-
    dif(C, '%'),
    dif([annot(C, L, Col, Off, Src)|Cs], [annot('/', _, _, _, _), annot('*', _, _, _, _)|_]),
    if_(memberd_t(C, [' ', '\t', '\r', '\n', '\v', '\f']),
        annotated_skip_layout(Cs, true, Options, StreamOut, LayoutBeforeOut, CommentsOut),
        ( StreamOut = [annot(C, L, Col, Off, Src)|Cs],
          LayoutBeforeOut = LayoutBefore0,
          CommentsOut = []
        )
    ).

half_open_span(span(StartPos, LastItemPos), StreamIn, StreamOut, span(StartPos, EndPos)) :-
    if_(StreamOut = [annot(_, L, Col, Off, Src)|_],
        EndPos = pos(L, Col, Off, Src),
        ( consumed_last(StreamIn, StreamOut, annot(LastChar, _, _, _, _)),
          advance_pos(LastItemPos, [LastChar], EndPos)
        )
    ).

annotated_stream_to_chars([], []).
annotated_stream_to_chars([annot(C, _, _, _, _)|Rest], [C|CharsRest]) :-
    annotated_stream_to_chars(Rest, CharsRest).

%% Canonical prolog_* predicate definitions
prolog_lifted_tokens(Tokens) --> lifted_tokens(Tokens).
prolog_lifted_tokens(Options, Tokens) --> lifted_tokens(Options, Tokens).
prolog_lifted_clause_tokens(Tokens) --> lifted_clause_tokens(Tokens).
prolog_lifted_clause_tokens(Options, Tokens) --> lifted_clause_tokens(Options, Tokens).
prolog_lifted_token(Token) --> lifted_token(Token).
prolog_lifted_token(Options, Token) --> lifted_token(Options, Token).
prolog_lifted_tokenize(Chars, Tokens) :- lifted_tokenize(Chars, Tokens).
prolog_lifted_tokenize(Options, Chars, Tokens) :- lifted_tokenize(Options, Chars, Tokens).
prolog_annotated_skip_layout(In, LayoutBefore0, Options, Out, LayoutBeforeOut, Comments) :-
    annotated_skip_layout(In, LayoutBefore0, Options, Out, LayoutBeforeOut, Comments).
prolog_annotated_scan_single_token(LayoutBefore, Options, Token, StreamIn, StreamOut) :-
    annotated_scan_single_token(LayoutBefore, Options, Token, StreamIn, StreamOut).
