:- module(lexer_regex, [
    var_re_match/3,
    name_atom_re_match/3,
    graphic_atom_re_match/3,
    hex_int_re_match/4,
    oct_int_re_match/4,
    bin_int_re_match/4,
    dec_int_re_match/3,
    float_re_match/3,
    layout_re_match/3,
    digits_to_int/3
]).

/** <module> Regular Expression Lexical Matchers

Uses `pure_regex` to match ISO Prolog regular lexical patterns.
*/

:- use_module(library(charsio)).
:- use_module(library(clpz)).
:- use_module(library(reif)).
:- use_module('../../pure_regexp/src/pure_regex', [
    re_match/3,
    re_match_groups/5
]).

% Variables: [A-Z_][a-zA-Z0-9_]*
var_re_match(Input, Match, Rest) :-
    re_match("[A-Z_][a-zA-Z0-9_]*", Input, Rest),
    phrase(var_chars(Match), Input, Rest).

var_chars([]) --> [].
var_chars([C|Cs]) --> [C], var_chars(Cs).

% Name atoms: [a-z][a-zA-Z0-9_]*
name_atom_re_match(Input, Match, Rest) :-
    re_match("[a-z][a-zA-Z0-9_]*", Input, Rest),
    phrase(var_chars(Match), Input, Rest).

% Graphic atoms: [#$&*+\-./:<=>?@^~\\]+
graphic_atom_re_match(Input, Match, Rest) :-
    re_match("[#$&*+\\-./:<=>?@^~\\\\]+", Input, Rest),
    phrase(var_chars(Match), Input, Rest).

% Hexadecimal integer: 0[xX]([0-9a-fA-F]+)
hex_int_re_match(Input, Match, Digits, Rest) :-
    re_match_groups("0[xX]([0-9a-fA-F]+)", Input, Match, [Digits], Rest).

% Octal integer: 0[oO]([0-7]+)
oct_int_re_match(Input, Match, Digits, Rest) :-
    re_match_groups("0[oO]([0-7]+)", Input, Match, [Digits], Rest).

% Binary integer: 0[bB]([01]+)
bin_int_re_match(Input, Match, Digits, Rest) :-
    re_match_groups("0[bB]([01]+)", Input, Match, [Digits], Rest).

% Float: [0-9]+\.[0-9]+([eE][+-]?[0-9]+)?
float_re_match(Input, Match, Rest) :-
    re_match("[0-9]+\\.[0-9]+([eE][+-]?[0-9]+)?", Input, Rest),
    phrase(var_chars(Match), Input, Rest).

% Decimal integer: [0-9]+
dec_int_re_match(Input, Match, Rest) :-
    re_match("[0-9]+", Input, Rest),
    phrase(var_chars(Match), Input, Rest).

% Layout / whitespace: [ \t\r\n\v\f]+
layout_re_match(Input, Match, Rest) :-
    re_match("[ \t\r\n\v\f]+", Input, Rest),
    phrase(var_chars(Match), Input, Rest).

%% digits_to_int(+Digits, +Base, -Value)
digits_to_int(Digits, Base, Value) :-
    digits_to_int(Digits, Base, 0, Value).

digits_to_int([], _, Acc, Acc).
digits_to_int([C|Cs], Base, Acc, Value) :-
    char_digit_value(C, DigitVal),
    Acc1 #= Acc * Base + DigitVal,
    digits_to_int(Cs, Base, Acc1, Value).

char_digit_value(C, V) :-
    char_code(C, Code),
    char_code_digit(Code, V).

char_code_digit(Code, V) :-
    Code in 0'0..0'9,
    V #= Code - 0'0.
char_code_digit(Code, V) :-
    Code in 0'a..0'z,
    V #= Code - 0'a + 10.
char_code_digit(Code, V) :-
    Code in 0'A..0'Z,
    V #= Code - 0'A + 10.
