:- module(test_uuid, [
    run_uuid_tests/0,
    run_uuid_tests/1,
    generate_scryer_out/0,
    generate_scryer_out/1,
    test_uuid_case/4
]).

/** <module> Scryer Compatibility: UUID Generation & Conversion (library(uuid))

Tests uuid_string/2 bidirectional conversions between byte lists and hex strings.
*/

:- use_module(library(format)).
:- use_module(library(uuid)).
:- use_module(compat_framework).

% Native Scryer predicates
test_uuid_to_bytes(Bytes) :-
    uuid_string(Bytes, "61ae692e-eaf6-4199-8dd3-9f01db70a20b").

test_bytes_to_uuid(String) :-
    Bytes = [97,174,105,46,234,246,65,153,141,211,159,1,219,112,162,11],
    uuid_string(Bytes, String).

test_uuid_case(uuid_to_bytes, "uuid_string/2 parses UUID string to byte list",
    ":- use_module(library(uuid)).\ntest_uuid_to_bytes(Bytes) :-\n    uuid_string(Bytes, \"61ae692e-eaf6-4199-8dd3-9f01db70a20b\").",
    ["test_uuid_to_bytes(B)."]).

test_uuid_case(bytes_to_uuid, "uuid_string/2 formats byte list to UUID string",
    ":- use_module(library(uuid)).\ntest_bytes_to_uuid(String) :-\n    Bytes = [97,174,105,46,234,246,65,153,141,211,159,1,219,112,162,11],\n    uuid_string(Bytes, String).",
    ["test_bytes_to_uuid(S)."]).

generate_scryer_out(OutFile) :-
    generate_scryer_out_file(test_uuid:test_uuid_case, OutFile).
generate_scryer_out :-
    default_scryer_out_path(test_uuid, OutFile),
    generate_scryer_out(OutFile).

run_uuid_tests(OutFile) :-
    format("~n--- Module Compatibility: library(uuid) ---~n", []),
    run_compat_tests_from_file(test_uuid:test_uuid_case, OutFile).
run_uuid_tests :-
    default_scryer_out_path(test_uuid, OutFile),
    run_uuid_tests(OutFile).
