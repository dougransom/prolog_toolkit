:- module(prolog_attributed_tokens, [
    create_attributed_token/4,
    create_attributed_token/5,
    is_attributed_token/1,
    get_token_class/2,
    get_token_value/2,
    get_token_span/2,
    get_token_op/2,
    set_token_op/2,
    lifted_tokens_to_attributed/2,
    lifted_tokens_to_attributed/3,
    chars_to_attributed_tokens/2,
    chars_to_attributed_tokens/3
]).

:- use_module(library(atts)).
:- use_module(library(lists)).
:- use_module(library(si)).

:- use_module(prolog_token).
:- use_module(prolog_lifted_lexer).
:- use_module(prolog_operator_table).

/** <module> Attributed Token Stream for Scryer Prolog

This module attaches first-class attributes to Prolog variables representing tokens.
Instead of embedding tokens in static wrapper tuples, each token is a variable carrying
fine-grained attributes:

- `token_class(Class)`: atom, integer, float, var, string, open, close, comma, end, etc.
- `token_value(Val)`: token character content or numeric value
- `token_span(Span)`: source span `span(StartPos, EndPos)`
- `token_op(OpSpec)`: operator metadata `op(Type, Priority)` if the token is an operator

=== Benefits of Attributed Tokens ===
1. **Extensibility**: Tools (LSP, linters, semantic actions) can attach additional
   attributes (e.g. syntax highlighting class, diagnostic messages) without breaking
   grammar rules expecting a fixed tuple format.
2. **Lazy Operator Resolution**: An atom token can be created without immediately knowing
   its operator table precedence. When operator precedence is unified, reactive parser
   nodes waiting on `token_op` wake up and resolve.
3. **Purity**: Retains Scryer Prolog's pure logical variable semantics and `library(atts)`.
*/

:- attribute
    tok_class/1,
    tok_val/1,
    tok_span/1,
    tok_op/1.

verify_attributes(Var, Other, Goals) :-
    % Merge token attributes if two token variables unify
    (   get_atts(Var, tok_class(C)) ->
        (   var(Other) ->
            put_atts(Other, tok_class(C)),
            Goals = []
        ;   Goals = []
        )
    ;   Goals = []
    ).

%!  create_attributed_token(-TokVar, +Class, +Value, +Span) is det.
%
%   Initializes TokVar with tok_class, tok_val, and tok_span attributes.
create_attributed_token(TokVar, Class, Value, Span) :-
    put_atts(TokVar, tok_class(Class)),
    put_atts(TokVar, tok_val(Value)),
    put_atts(TokVar, tok_span(Span)).

%!  create_attributed_token(-TokVar, +Class, +Value, +Span, +OpMetadata) is det.
%
%   Initializes TokVar with class, value, span, and operator metadata attributes.
create_attributed_token(TokVar, Class, Value, Span, OpMetadata) :-
    create_attributed_token(TokVar, Class, Value, Span),
    put_atts(TokVar, tok_op(OpMetadata)).

%!  is_attributed_token(@Term) is semidet.
%
%   True if Term is a variable with a tok_class attribute.
is_attributed_token(Var) :-
    var(Var),
    get_atts(Var, tok_class(_)).

%!  get_token_class(@TokVar, -Class) is semidet.
get_token_class(TokVar, Class) :-
    var(TokVar),
    get_atts(TokVar, tok_class(Class)).

%!  get_token_value(@TokVar, -Value) is semidet.
get_token_value(TokVar, Value) :-
    var(TokVar),
    get_atts(TokVar, tok_val(Value)).

%!  get_token_span(@TokVar, -Span) is semidet.
get_token_span(TokVar, Span) :-
    var(TokVar),
    get_atts(TokVar, tok_span(Span)).

%!  get_token_op(@TokVar, -OpSpec) is semidet.
get_token_op(TokVar, OpSpec) :-
    var(TokVar),
    get_atts(TokVar, tok_op(OpSpec)).

%!  set_token_op(+TokVar, +OpSpec) is det.
set_token_op(TokVar, OpSpec) :-
    var(TokVar),
    put_atts(TokVar, tok_op(OpSpec)).

%!  lifted_tokens_to_attributed(+LiftedTokens, -AttributedTokens) is det.
%
%   Converts a list of lifted tokens (from prolog_lifted_tokens) to attributed
%   token variables using the default operator table.
lifted_tokens_to_attributed(LiftedTokens, AttributedTokens) :-
    prolog_default_operator_table(OpTable),
    lifted_tokens_to_attributed(LiftedTokens, OpTable, AttributedTokens).

%!  lifted_tokens_to_attributed(+LiftedTokens, +OpTable, -AttributedTokens) is det.
%
%   Converts lifted tokens to attributed tokens using OpTable to annotate operator metadata.
lifted_tokens_to_attributed([], _, []).
lifted_tokens_to_attributed([Tok|Toks], OpTable, [AttrTok|AttrToks]) :-
    lifted_to_attr_single(Tok, OpTable, AttrTok),
    lifted_tokens_to_attributed(Toks, OpTable, AttrToks).

lifted_to_attr_single(Tok, OpTable, AttrTok) :-
    prolog_token_type(Tok, Type),
    prolog_token_value(Tok, Val),
    prolog_token_span(Tok, Span),
    create_attributed_token(AttrTok, Type, Val, Span),
    % Check if token is an operator in OpTable
    (   Type = atom,
        prolog_is_operator(OpTable, Val, OpType, OpPriority) ->
        set_token_op(AttrTok, op(OpType, OpPriority))
    ;   true
    ).

%!  chars_to_attributed_tokens(+Chars, -AttributedTokens) is semidet.
%
%   Direct convenience predicate: scans Chars using prolog_lifted_tokenize
%   and produces a list of attributed token variables.
chars_to_attributed_tokens(Chars, AttributedTokens) :-
    chars_to_attributed_tokens(Chars, [], AttributedTokens).

%!  chars_to_attributed_tokens(+Chars, +Options, -AttributedTokens) is semidet.
chars_to_attributed_tokens(Chars, Options, AttributedTokens) :-
    prolog_lifted_tokenize(Options, Chars, LiftedTokens),
    (   member(operators(OpTable), Options) ->
        true
    ;   prolog_default_operator_table(OpTable)
    ),
    lifted_tokens_to_attributed(LiftedTokens, OpTable, AttributedTokens).
