:- module(lexer_dcg, [
    char_code_token//1,
    quoted_atom_body//1,
    string_body//1,
    line_comment_dcg//1,
    block_comment_iso_dcg//1,
    block_comment_nested_dcg//1,
    escape_sequence//1
]).

/** <module> DCGs for Non-Regular Patterns & Escape Sequences

Pure DCGs for:
  - Character code literals (0'c)
  - ISO string & quoted atom bodies with escape decoding
  - Non-nested & nested block comments
*/

:- use_module(library(dcgs)).
:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(dif)).
:- use_module(library(format), [format_//2]).
:- use_module(library(lists), [append/3, member/2]).
:- use_module(library(reif)).
:- use_module(lexer_regex, [digits_to_int/3]).

%% char_code_token(-Code)//
% Matches 0'c, 0'\escape, or 0''
char_code_token(Code) -->
    "0'",
    char_code_target(Code).

% Mandatory cut for correctness: backslash denotes an escape sequence, not literal backslash
char_code_target(Code) -->
    "\\",
    !,
    escape_sequence(C),
    { char_code(C, Code) }.
char_code_target(Code) -->
    [C],
    { char_code(C, Code) }.

%% quoted_atom_body(-Chars)//
% Mandatory cut: ISO doubled single quotes escape to a single quote
quoted_atom_body(['\''|Cs]) -->
    "''",
    !,
    quoted_atom_body(Cs).
% Mandatory cut: backslash initiates an escape sequence or line continuation
quoted_atom_body(Cs) -->
    "\\",
    !,
    escape_or_continue(Cs0),
    quoted_atom_body(Cs1),
    { append(Cs0, Cs1, Cs) }.
quoted_atom_body([C|Cs]) -->
    [C],
    { dif(C, '\'') },
    !,
    quoted_atom_body(Cs).
quoted_atom_body([]) --> [].

%% string_body(-Chars)//
% Mandatory cut: ISO doubled double quotes escape to a single double quote
string_body(['"'|Cs]) -->
    "\"\"",
    !,
    string_body(Cs).
% Mandatory cut: backslash initiates an escape sequence or line continuation
string_body(Cs) -->
    "\\",
    !,
    escape_or_continue(Cs0),
    string_body(Cs1),
    { append(Cs0, Cs1, Cs) }.
string_body([C|Cs]) -->
    [C],
    { dif(C, '"') },
    !,
    string_body(Cs).
string_body([]) --> [].

escape_or_continue([]) -->
    "\r\n",
    !.
escape_or_continue([]) -->
    "\n",
    !.
escape_or_continue([C]) -->
    escape_sequence(C).

%% escape_sequence(-Char)//
% Mandatory cut for correctness: commit to single-character escape once matched.
escape_sequence(C) -->
    [Esc],
    { member(C, [ '\a', '\b', '\r', '\f', '\t', '\n', '\v',
                  '\'', '\"', '`', '\\' ]),
      char_to_esc(C, Esc)
    },
    !.
escape_sequence(C) -->
    "x",
    hex_digits(Digits),
    "\\",
    !,
    { digits_to_int(Digits, 16, Code),
      char_code(C, Code) }.
escape_sequence(C) -->
    oct_digits(Digits),
    "\\",
    !,
    { digits_to_int(Digits, 8, Code),
      char_code(C, Code) }.

%% char_to_esc(+Char, -EscChar)
% Derives the source escape character from the unescaped character value.
char_to_esc(C, Esc) :-
    phrase(format_("~q", [C]), Chars),
    if_(Chars = ['\'', '\\', Esc0, '\''],
        Esc = Esc0,
        if_(Chars = ['\'', Esc0, '\''],
            Esc = Esc0,
            Chars = [Esc]
        )
    ).

% -------------------------------------------------------------------------
% Character Escape Digits (Hex & Octal)
% -------------------------------------------------------------------------
% Note: These DCG rules are NOT used for top-level numeric tokens (e.g. 0x...,
% 0o..., which are matched via regex in lexer_regex.pl).
% They are used exclusively inside escape_sequence//1 for ISO escape sequences
% embedded inside quoted atoms ('...'), strings ("..."), and character literals
% (0'c):
%   - Hexadecimal escape: \x<hex_digits>\
%   - Octal escape:       \<oct_digits>\
% Operating directly on the DCG difference list avoids regex context-switching
% inside character-by-character string/atom loops.

hex_digits([D|Ds]) -->
    hex_digit(D),
    hex_digits_rest(Ds).

% Mandatory cut for correctness: greedily consume consecutive hex digits,
% preventing spurious backtracking on partial digit prefixes before the closing '\'.
hex_digits_rest([D|Ds]) -->
    hex_digit(D),
    !,
    hex_digits_rest(Ds).
hex_digits_rest([]) --> [].

hex_digit(D) --> [D], { hex_digit_char(D) }.

hex_digit_char(D) :-
    char_code(D, Code),
    ( Code in 0'0..0'9
    ; Code in 0'a..0'f
    ; Code in 0'A..0'F
    ).

oct_digits([D|Ds]) -->
    oct_digit(D),
    oct_digits_rest(Ds).

% Mandatory cut for correctness: greedily consume consecutive octal digits,
% preventing spurious backtracking on partial digit prefixes before the closing '\'.
oct_digits_rest([D|Ds]) -->
    oct_digit(D),
    !,
    oct_digits_rest(Ds).
oct_digits_rest([]) --> [].

oct_digit(D) --> [D], { char_code(D, Code), Code in 0'0..0'7 }.

%% line_comment_dcg(-Content)//
line_comment_dcg(Content) -->
    "%",
    line_comment_body(Content).

line_comment_body([]) --> [].
line_comment_body([]) --> "\r\n", !.
line_comment_body([]) --> "\n", !.
line_comment_body([C|Cs]) -->
    [C],
    line_comment_body(Cs).

%% block_comment_iso_dcg(-Content)//
block_comment_iso_dcg(Content) -->
    "/*",
    block_comment_iso_body(Content).

block_comment_iso_body([]) --> "*/", !.
block_comment_iso_body([C|Cs]) -->
    [C],
    block_comment_iso_body(Cs).

%% block_comment_nested_dcg(-Content)//
block_comment_nested_dcg(Content) -->
    "/*",
    block_comment_nested_body(1, Content).

block_comment_nested_body(0, []) --> [].
block_comment_nested_body(Depth, ['*','/'|Cs]) -->
    "*/",
    !,
    { Depth1 #= Depth - 1 },
    block_comment_nested_body(Depth1, Cs).
block_comment_nested_body(Depth, ['/','*'|Cs]) -->
    "/*",
    !,
    { Depth1 #= Depth + 1 },
    block_comment_nested_body(Depth1, Cs).
block_comment_nested_body(Depth, [C|Cs]) -->
    [C],
    block_comment_nested_body(Depth, Cs).
