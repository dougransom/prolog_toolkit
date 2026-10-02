:- module(test_crypto, [
    run_crypto_tests/0,
    run_crypto_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_crypto_case/4
]).

/** <module> Scryer Compatibility: Cryptographic Primitives (library(crypto))

Tests hex_bytes/2 and crypto_data_hash/3.
*/

:- use_module(library(crypto)).
:- use_module(library(format)).
:- use_module(compat_framework).

% Native Scryer predicates
test_hex_conversion(Bytes, Hex) :-
    hex_bytes("501ACE", Bytes),
    hex_bytes(Hex, [80, 26, 206]).

test_sha256_hash(Hash) :-
    crypto_data_hash("prolog", Hash, [algorithm(sha256)]).

test_crypto_case(hex_bytes_bidirectional, "hex_bytes/2 converts bidirectionally between hex strings and byte lists",
    ":- use_module(library(crypto)).\ntest_hex_conversion(Bytes, Hex) :-\n    hex_bytes(\"501ACE\", Bytes),\n    hex_bytes(Hex, [80, 26, 206]).",
    ["test_hex_conversion(B, H)."]).

test_crypto_case(sha256_hashing, "crypto_data_hash/3 computes sha256 hash",
    ":- use_module(library(crypto)).\ntest_sha256_hash(Hash) :-\n    crypto_data_hash(\"prolog\", Hash, [algorithm(sha256)]).",
    ["test_sha256_hash(H)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_crypto:test_crypto_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_crypto, OutFile),
    generate_scryer_out(OutFile).

run_crypto_tests(OutFile) :-
    format("~n--- Module Compatibility: library(crypto) ---~n", []),
    run_compat_tests_from_file(test_crypto:test_crypto_case, OutFile).
run_crypto_tests :-
    default_scryer_out_path(test_crypto, OutFile),
    run_crypto_tests(OutFile).
