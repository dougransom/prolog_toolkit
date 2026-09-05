/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Core Entry Point

   A pure, ISO-compliant lexical and syntactic analysis toolkit
   for the Prolog language in Scryer Prolog.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(prolog_toolkit, [
    prolog_toolkit_version/1,

    % Lifted DCG Lexical Analyzer API (with source spans)
    tokens//1,
    tokens//2,
    clause_tokens//1,
    clause_tokens//2,
    token//1,
    token//2,
    lifted_tokens//1,
    lifted_tokens//2,
    lifted_clause_tokens//1,
    lifted_clause_tokens//2,
    lifted_token//1,
    lifted_token//2,
    lazy_tokens//1,
    lazy_tokens//2,

    % Unlifted DCG Lexical Analyzer API (pure chars without spans)
    unlifted_tokens//1,
    unlifted_tokens//2,
    unlifted_clause_tokens//1,
    unlifted_clause_tokens//2,
    unlifted_token//1,
    unlifted_token//2,
    unlifted_tokenize/2,
    unlifted_tokenize/3,

    % Procedural wrappers
    tokenize/2,
    tokenize/3,
    lifted_tokenize/2,
    lifted_tokenize/3,
    scan_token/4,
    clause_tokens/4,
    lazy_tokenize/2,
    lazy_tokenize/3,

    % Token Accessors & Converters
    token_type/2,
    token_value/2,
    token_span/2,
    lift_token/3,
    unlift_token/2,

    % Position & Span Coordinates
    pos_line/2,
    pos_col/2,
    pos_offset/2,
    pos_source/2,
    span_start/2,
    span_end/2,
    combine_spans/3,

    % Re-exported from parser_experiments pipeline (temporary direct reference)
    pipeline_stream_parse/5,
    default_stream_parse/3,
    lazy_pipeline_tokens/5,
    default_pipeline_tokens/3,
    format_diagnostic/2
]).

:- use_module(library(charsio)).
:- use_module(library(dcgs)).
:- use_module(library(reif)).
:- use_module(library(si)).

:- use_module(token).
:- use_module('../../parser_experiments/src/annotate_position', [
    pos_line/2,
    pos_col/2,
    pos_offset/2,
    pos_source/2,
    span_start/2,
    span_end/2,
    combine_spans/3,
    advance_pos/3
]).
:- use_module(lexer).
:- use_module(streaming_lexer).

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   NOTE: Dependency Architecture & Roadmap

   Eventually, the streaming lexical and syntactic pipeline will be consumed
   as an external package from `parser_experiments` via bakage:
     :- use_module(pkg(parser_experiments)).

   For now, we reference it directly via relative file path:
     ../../parser_experiments/src/parser_experiments

   We will refactor these imports later once parser_experiments is packaged
   and installed via bakage.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */
:- use_module('../../parser_experiments/src/parser_experiments', [
    pipeline_stream_parse/5,
    default_stream_parse/3,
    lazy_pipeline_tokens/5,
    default_pipeline_tokens/3,
    format_diagnostic/2
]).

%% prolog_toolkit_version(?Version:chars) is semidet.
%
%  True when Version unifies with the current version string
%  represented as a list of characters.
prolog_toolkit_version("0.1.0.dev1").
