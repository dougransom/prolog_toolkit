:- module(lexer_rules, [
    grammar_rule/2,
    char_to_esc/2,
    is_graphic_char/1
]).

:- use_module(library(charsio)).
:- use_module(library(reif)).

%% char_to_esc(?Char, ?EscChar)
% Maps unescaped characters to their single-character escape codes.
user:term_expansion(char_to_esc(Esc), char_to_esc(C, Esc)) :-
    read_from_chars(['"', '\\', Esc, '"', '.'], [C]).

char_to_esc('a').
char_to_esc('b').
char_to_esc('r').
char_to_esc('f').
char_to_esc('t').
char_to_esc('n').
char_to_esc('v').
char_to_esc('\'').
char_to_esc('\"').
char_to_esc('`').
char_to_esc('\\').

%% is_graphic_char(?Char)
% True if Char is an ISO Prolog graphic character.
is_graphic_char(C) :- memberd_t(C, "#$&*+-./:<=>?@^~\\", true).

/** <module> Shared DCG Grammar Rules for Prolog Lexical Analysis

Defines textbook BNF DCG rules as facts:
  grammar_rule(node, (Head --> Body)).
  grammar_rule(helper, (Head --> Body)).

- Node rules: token rules transformed by dcg_node_rule/2 to wrap the head
  in node(Payload, Span) and the body in span(Body, Span).
- Helper rules: syntactic sub-rules transformed by dcg_helper_rule/2 to rewrite
  terminal sequences [C] to [annot(C, _, _, _, _)].
*/

% -------------------------------------------------------------------------
% 1. Token Node Rules
% -------------------------------------------------------------------------

% Delimiters
grammar_rule(node, ( scan_token(close) --> [')'] )).
grammar_rule(node, ( scan_token(open_list) --> ['['] )).
grammar_rule(node, ( scan_token(close_list) --> [']'] )).
grammar_rule(node, ( scan_token(open_curly) --> ['{'] )).
grammar_rule(node, ( scan_token(close_curly) --> ['}'] )).
grammar_rule(node, ( scan_token(comma) --> [','] )).
grammar_rule(node, ( scan_token(bar) --> ['|'] )).
% Delimiters (end is handled specifically with layout lookahead in lexers)

% ISO Solo character atoms
grammar_rule(node, ( scan_token(atom("!")) --> ['!'] )).
grammar_rule(node, ( scan_token(atom(";")) --> [';'] )).

% Quoted atom & string
grammar_rule(node, ( scan_token(atom(Content)) -->
    ['\''],
    quoted_atom_body(Content),
    ['\'']
)).
grammar_rule(node, ( scan_token(string(Content)) -->
    ['"'],
    string_body(Content),
    ['"']
)).

% Character code constant: 0'c
grammar_rule(node, ( scan_token(integer(Code)) -->
    "0'",
    char_code_target(Code)
)).

% Radix integers
grammar_rule(node, ( scan_token(integer(Val)) --> hex_integer(Val) )).
grammar_rule(node, ( scan_token(integer(Val)) --> oct_integer(Val) )).
grammar_rule(node, ( scan_token(integer(Val)) --> bin_integer(Val) )).

% Numbers: Floats & Decimals
grammar_rule(node, ( scan_token(float(Val)) --> float_number(Val) )).
grammar_rule(node, ( scan_token(integer(Val)) --> dec_integer(Val) )).

% Identifiers
grammar_rule(node, ( scan_token(var(Name)) --> var_ident(Name) )).
grammar_rule(node, ( scan_token(atom(Name)) --> name_ident(Name) )).
grammar_rule(node, ( scan_token(atom(Name)) --> graphic_ident(Name) )).

% Parentheses (open vs open_ct)
grammar_rule(node, ( scan_paren(open) --> ['('] )).
grammar_rule(node, ( scan_paren(open_ct) --> ['('] )).

% Comments
grammar_rule(node, ( scan_comment(comment(line, Content)) -->
    line_comment_rule(Content)
)).
grammar_rule(node, ( scan_comment(comment(block, Content)) -->
    block_comment_iso_rule(Content)
)).
grammar_rule(node, ( scan_nested_comment(comment(block, Content)) -->
    block_comment_nested_rule(Content)
)).

% -------------------------------------------------------------------------
% 2. Syntactic Helper Rules
% -------------------------------------------------------------------------

% --- Character Code Target ---
grammar_rule(helper, ( char_code_target(Code) -->
    "\\",
    !,
    escape_sequence(C),
    { char_code(C, Code) }
)).
grammar_rule(helper, ( char_code_target(Code) -->
    [C],
    { char_code(C, Code) }
)).

% --- Quoted Atom Body ---
grammar_rule(helper, ( quoted_atom_body(['\''|Cs]) -->
    "''",
    !,
    quoted_atom_body(Cs)
)).
grammar_rule(helper, ( quoted_atom_body(Cs) -->
    "\\",
    !,
    escape_or_continue(Cs0),
    quoted_atom_body(Cs1),
    { append(Cs0, Cs1, Cs) }
)).
grammar_rule(helper, ( quoted_atom_body([C|Cs]) -->
    [C],
    { dif(C, '\'') },
    !,
    quoted_atom_body(Cs)
)).
grammar_rule(helper, ( quoted_atom_body([]) --> [] )).

% --- String Body ---
grammar_rule(helper, ( string_body(['"'|Cs]) -->
    "\"\"",
    !,
    string_body(Cs)
)).
grammar_rule(helper, ( string_body(Cs) -->
    "\\",
    !,
    escape_or_continue(Cs0),
    string_body(Cs1),
    { append(Cs0, Cs1, Cs) }
)).
grammar_rule(helper, ( string_body([C|Cs]) -->
    [C],
    { dif(C, '"') },
    !,
    string_body(Cs)
)).
grammar_rule(helper, ( string_body([]) --> [] )).

% --- Escape Sequences & Continuations ---
grammar_rule(helper, ( escape_or_continue([]) --> "\r\n", ! )).
grammar_rule(helper, ( escape_or_continue([]) --> "\n", ! )).
grammar_rule(helper, ( escape_or_continue([C]) --> escape_sequence(C) )).

grammar_rule(helper, ( escape_sequence(C) -->
    [Esc],
    { char_to_esc(C, Esc) },
    !
)).
grammar_rule(helper, ( escape_sequence(C) -->
    "x",
    esc_hex_digits(Digits),
    "\\",
    !,
    { digits_to_int(Digits, 16, Code),
      char_code(C, Code) }
)).
grammar_rule(helper, ( escape_sequence(C) -->
    esc_oct_digits(Digits),
    "\\",
    !,
    { digits_to_int(Digits, 8, Code),
      char_code(C, Code) }
)).

grammar_rule(helper, ( esc_hex_digits([D|Ds]) -->
    esc_hex_digit(D),
    esc_hex_digits_rest(Ds)
)).
grammar_rule(helper, ( esc_hex_digits_rest([D|Ds]) -->
    esc_hex_digit(D),
    !,
    esc_hex_digits_rest(Ds)
)).
grammar_rule(helper, ( esc_hex_digits_rest([]) --> [] )).
grammar_rule(helper, ( esc_hex_digit(D) -->
    [D],
    { memberd_t(D, "0123456789abcdefABCDEF", true) }
)).

grammar_rule(helper, ( esc_oct_digits([D|Ds]) -->
    esc_oct_digit(D),
    esc_oct_digits_rest(Ds)
)).
grammar_rule(helper, ( esc_oct_digits_rest([D|Ds]) -->
    esc_oct_digit(D),
    !,
    esc_oct_digits_rest(Ds)
)).
grammar_rule(helper, ( esc_oct_digits_rest([]) --> [] )).
grammar_rule(helper, ( esc_oct_digit(D) -->
    [D],
    { memberd_t(D, "01234567", true) }
)).

% --- Radix Integers ---
grammar_rule(helper, ( hex_integer(Val) -->
    "0",
    ("x" ; "X"),
    hex_digits(Digits),
    { dif(Digits, []), digits_to_int(Digits, 16, Val) }
)).
grammar_rule(helper, ( hex_digits([D|Ds]) --> hex_digit(D), !, hex_digits(Ds) )).
grammar_rule(helper, ( hex_digits([]) --> [] )).
grammar_rule(helper, ( hex_digit(D) --> [D], { memberd_t(D, "0123456789abcdefABCDEF", true) } )).

grammar_rule(helper, ( oct_integer(Val) -->
    "0",
    ("o" ; "O"),
    oct_digits(Digits),
    { dif(Digits, []), digits_to_int(Digits, 8, Val) }
)).
grammar_rule(helper, ( oct_digits([D|Ds]) --> oct_digit(D), !, oct_digits(Ds) )).
grammar_rule(helper, ( oct_digits([]) --> [] )).
grammar_rule(helper, ( oct_digit(D) --> [D], { memberd_t(D, "01234567", true) } )).

grammar_rule(helper, ( bin_integer(Val) -->
    "0",
    ("b" ; "B"),
    bin_digits(Digits),
    { dif(Digits, []), digits_to_int(Digits, 2, Val) }
)).
grammar_rule(helper, ( bin_digits([D|Ds]) --> bin_digit(D), !, bin_digits(Ds) )).
grammar_rule(helper, ( bin_digits([]) --> [] )).
grammar_rule(helper, ( bin_digit(D) --> [D], { memberd_t(D, "01", true) } )).

% --- Floats & Decimal Integers ---
grammar_rule(helper, ( float_number(Val) -->
    dec_digits(D1),
    ".",
    dec_digits(D2),
    { dif(D1, []), dif(D2, []) },
    opt_exponent(Exp),
    { append([D1, ".", D2, Exp], FloatChars),
      number_chars(Val, FloatChars) }
)).
grammar_rule(helper, ( opt_exponent(Exp) -->
    ("e" ; "E"),
    opt_sign(Sign),
    dec_digits(Ds),
    { dif(Ds, []), append([['e'], Sign, Ds], Exp) },
    !
)).
grammar_rule(helper, ( opt_exponent([]) --> [] )).
grammar_rule(helper, ( opt_sign(['+']) --> "+", ! )).
grammar_rule(helper, ( opt_sign(['-']) --> "-", ! )).
grammar_rule(helper, ( opt_sign([]) --> [] )).

grammar_rule(helper, ( dec_integer(Val) -->
    dec_digits(Ds),
    { dif(Ds, []), number_chars(Val, Ds) }
)).
grammar_rule(helper, ( dec_digits([D|Ds]) --> dec_digit(D), !, dec_digits(Ds) )).
grammar_rule(helper, ( dec_digits([]) --> [] )).
grammar_rule(helper, ( dec_digit(D) --> [D], { char_type(D, decimal_digit) } )).

% --- Identifiers ---
grammar_rule(helper, ( var_ident([C|Cs]) -->
    [C],
    { ( char_type(C, upper) ; C = '_' ) },
    ident_chars(Cs)
)).

grammar_rule(helper, ( name_ident([C|Cs]) -->
    [C],
    { char_type(C, lower) },
    ident_chars(Cs)
)).

grammar_rule(helper, ( ident_chars([C|Cs]) -->
    [C],
    { ( char_type(C, alphanumeric) ; C = '_' ) },
    !,
    ident_chars(Cs)
)).
grammar_rule(helper, ( ident_chars([]) --> [] )).

grammar_rule(helper, ( graphic_ident([C|Cs]) -->
    [C],
    { is_graphic_char(C) },
    graphic_chars(Cs)
)).
grammar_rule(helper, ( graphic_chars([C|Cs]) -->
    [C],
    { is_graphic_char(C) },
    !,
    graphic_chars(Cs)
)).
grammar_rule(helper, ( graphic_chars([]) --> [] )).

% --- Comments ---
grammar_rule(helper, ( line_comment_rule(Content) -->
    "%",
    line_comment_body(Content)
)).
grammar_rule(helper, ( line_comment_body([]) --> "\r\n", ! )).
grammar_rule(helper, ( line_comment_body([]) --> "\n", ! )).
grammar_rule(helper, ( line_comment_body([C|Cs]) -->
    [C],
    line_comment_body(Cs)
)).
grammar_rule(helper, ( line_comment_body([]) --> [] )).

grammar_rule(helper, ( block_comment_iso_rule(Content) -->
    "/*",
    block_comment_iso_body(Content)
)).
grammar_rule(helper, ( block_comment_iso_body([]) --> "*/", ! )).
grammar_rule(helper, ( block_comment_iso_body([C|Cs]) -->
    [C],
    block_comment_iso_body(Cs)
)).

grammar_rule(helper, ( block_comment_nested_rule(Content) -->
    "/*",
    block_comment_nested_body(0, Content)
)).
grammar_rule(helper, ( block_comment_nested_body(0, []) --> "*/", ! )).
grammar_rule(helper, ( block_comment_nested_body(Depth, ['*','/'|Cs]) -->
    "*/", !,
    { Depth #> 0, Depth1 #= Depth - 1 },
    block_comment_nested_body(Depth1, Cs)
)).
grammar_rule(helper, ( block_comment_nested_body(Depth, ['/','*'|Cs]) -->
    "/*", !,
    { Depth1 #= Depth + 1 },
    block_comment_nested_body(Depth1, Cs)
)).
grammar_rule(helper, ( block_comment_nested_body(Depth, [C|Cs]) -->
    [C],
    block_comment_nested_body(Depth, Cs)
)).
