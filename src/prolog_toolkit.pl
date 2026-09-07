/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
   Prolog Language Toolkit - Core Entry Point

   A pure, ISO-compliant lexical and syntactic analysis toolkit
   for the Prolog language in Scryer Prolog.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - */

:- module(prolog_toolkit, [
    prolog_toolkit_version/1,

    % Canonical Prolog Lexer API (Lifted with source spans)
    prolog_tokens//1,
    prolog_tokens//2,
    prolog_clause_tokens//1,
    prolog_clause_tokens//2,
    prolog_clause_tokens/4,
    prolog_token//1,
    prolog_token//2,
    prolog_tokenize/2,
    prolog_tokenize/3,
    prolog_scan_token/4,

    prolog_lifted_tokens//1,
    prolog_lifted_tokens//2,
    prolog_lifted_clause_tokens//1,
    prolog_lifted_clause_tokens//2,
    prolog_lifted_token//1,
    prolog_lifted_token//2,
    prolog_lifted_tokenize/2,
    prolog_lifted_tokenize/3,

    prolog_lazy_tokens//1,
    prolog_lazy_tokens//2,
    prolog_lazy_tokenize/2,
    prolog_lazy_tokenize/3,

    % Canonical Prolog Unlifted Lexer API (pure chars without spans)
    prolog_unlifted_tokens//1,
    prolog_unlifted_tokens//2,
    prolog_unlifted_clause_tokens//1,
    prolog_unlifted_clause_tokens//2,
    prolog_unlifted_token//1,
    prolog_unlifted_token//2,
    prolog_unlifted_tokenize/2,
    prolog_unlifted_tokenize/3,

    % Canonical Prolog Token Accessors & Converters
    prolog_token_type/2,
    prolog_token_value/2,
    prolog_token_span/2,
    prolog_lift_token/3,
    prolog_unlift_token/2,

    % Canonical Prolog Operator Precedence Table API
    prolog_default_operator_table/1,
    prolog_add_operator/5,
    prolog_lookup_infix_op/6,
    prolog_lookup_prefix_op/5,
    prolog_lookup_postfix_op/5,
    prolog_is_operator/4,
    prolog_op_chars/2,

    % Canonical Prolog Parser API
    prolog_parse_term//6,
    prolog_parse_clause//3,
    prolog_parse_clause//4,
    prolog_parse_program//3,
    prolog_parse_program//4,
    prolog_initial_var_state/1,
    prolog_var_state_bindings/4,

    % Backward-compatibility aliases: Lexer
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
    unlifted_tokens//1,
    unlifted_tokens//2,
    unlifted_clause_tokens//1,
    unlifted_clause_tokens//2,
    unlifted_token//1,
    unlifted_token//2,
    unlifted_tokenize/2,
    unlifted_tokenize/3,
    tokenize/2,
    tokenize/3,
    lifted_tokenize/2,
    lifted_tokenize/3,
    scan_token/4,
    clause_tokens/4,
    lazy_tokenize/2,
    lazy_tokenize/3,

    % Backward-compatibility aliases: Tokens
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

    % Backward-compatibility aliases: Operator Table
    default_operator_table/1,
    add_operator/5,
    lookup_infix_op/6,
    lookup_prefix_op/5,
    lookup_postfix_op/5,
    is_operator/4,

    % Backward-compatibility aliases: Parser
    parse_term//6,
    parse_clause//3,
    parse_clause//4,
    parse_program//3,
    parse_program//4,

    % Module Loader & Search Path Resolver API
    init_loader_state/1,
    init_loader_state/2,
    add_search_path/4,
    resolve_module_path/4,
    load_module_file/4,
    parse_module_chars/6,
    module_info_name/2,
    module_info_exports/2,
    module_info_ops/2,
    module_info_statements/2,

    % Term I/O (read_term, canonical formatting)
    iso_read_term/2,
    iso_read_term/3,
    iso_read_term_from_chars/2,
    iso_read_term_from_chars/3,
    iso_write_canonical/1,
    iso_write_canonical/2,
    term_to_canonical_chars/2,

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

:- use_module(prolog_token).
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
:- use_module(prolog_lexer).
:- use_module(prolog_streaming_lexer).
:- use_module(prolog_operator_table).
:- use_module(prolog_parser).
:- use_module(module_loader).
:- use_module(term_io).

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
