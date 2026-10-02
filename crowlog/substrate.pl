:- module(substrate, [
    default_substrate/1,
    substrate_spec/2,
    substrate_absorbs_predicate_t/3,
    substrate_absorbs_module_t/3,
    substrate_absorbed_modules/2,
    substrate_absorbed_predicates/2,
    substrate_emit_abstract_form/3
]).

/** <module> Declarative Host Substrate & Compiler Target Specification

Defines the explicit boundary between predicates and modules absorbed by the
host environment (or backend runtime) and those that are compiled or interpreted
by Crowlog.

A compiler writer targeting a new platform (e.g., Python VM, WASM, WAM bytecode)
can declare a new substrate_spec/2, specify minimal absorbed native hooks, and
emit an abstract form to bootstrap a full Prolog system.
*/

:- use_module(library(lists)).
:- use_module(library(reif)).
:- use_module(library(si)).

%% default_substrate(-SubstrateID)
%  Default host substrate environment for Crowlog running under Scryer Prolog.
default_substrate(scryer_host).

%% substrate_spec(?SubstrateID, ?SubstrateSpec)
%  Declarative specification of a target substrate.
%  substrate(AbsorbedModules, AbsorbedPredicates, Emitter, Hooks)
substrate_spec(minimal_core, substrate(
    [
        charsio, error, iso_ext
    ],
    [
        % Minimal unifier & term reflection substrate
        b('=', 2), b('\\=', 2), b('==', 2), b('\\==', 2), b(dif, 2),
        b(var, 1), b(nonvar, 1), b(atom, 1), b(integer, 1), b(float, 1),
        b(compound, 1), b(atomic, 1), b(functor, 3), b(arg, 3),
        b(copy_term, 2), b(term_variables, 2),
        b(atom_chars, 2), b(number_chars, 2), b(char_code, 2),
        b(true, 0), b(fail, 0), b(false, 0), b(',', 2), b(';', 2),
        b('!', 0), b('->', 2), b('*->', 2), b('\\+', 1),
        b(call, 1), b(call, 2), b(call, 3), b(call, 4), b(call, 5),
        b(catch, 3), b(throw, 1),
        b(is, 2), b('<', 2), b('>', 2), b('=<', 2), b('>=', 2),
        b('=:=', 2), b('=\\=', 2)
    ],
    abstract_ast,
    []
)).

substrate_spec(scryer_host, substrate(
    [
        % Intrinsics & Engine Modules only (foreign, C/Rust, or OS dependent)
        atts, charsio, clpb, clpz, cont, crypto, dcgs, diag, dif, error, files,
        format, freeze, iso_ext, loader, os, pio, process, random, sgml,
        time, when
    ],
    [
        % 1. Core Unification, Comparison & Metalogical
        b('=', 2), b('\\=', 2), b('==', 2), b('\\==', 2), b(dif, 2), b(freeze, 2), b(is, 2),
        b('<', 2), b('>', 2), b('=<', 2), b('>=', 2), b('=:=', 2), b('=\\=', 2),
        b('@<', 2), b('@>', 2), b('@=<', 2), b('@>=', 2), b(compare, 3),
        b(var, 1), b(nonvar, 1), b(atom, 1), b(integer, 1), b(float, 1), b(number, 1),
        b(compound, 1), b(atomic, 1), b(ground, 1), b(callable, 1),
        b(functor, 3), b(arg, 3), b(atom_chars, 2), b(number_chars, 2),
        b(char_code, 2), b(copy_term, 2),
        b(term_variables, 2), b(acyclic_term, 1),
        b(sort, 2), b(sort, 4), b(keysort, 2),
        b(throw, 1),
        % 2. Pure Control & Dynamic Dispatch
        b(true, 0), b(fail, 0), b(false, 0), b(',', 2), b(';', 2),
        b('!', 0), b('->', 2), b('*->', 2), b('\\+', 1),
        b(call, 1), b(call, 2), b(call, 3), b(call, 4), b(call, 5),
        b(call, 6), b(call, 7), b(call, 8),
        b(catch, 3), b(reset, 3), b(shift, 1),
        b(must_be, 2), b(can_be, 2), b(type_error, 2), b(domain_error, 2),
        b(instantiation_error, 1), b(representation_error, 1),
        % 3. Engine Hooks & Special VM Primitives
        b('$skip_max_list', 4), b('$is_partial_string', 1), b('$first_non_octet', 2),
        % 4. I/O and Formatting
        b(format, 1), b(format, 2), b(format, 3), b(format_, 4),
        b(portray_clause, 1), b(portray_clause, 2),
        b(write, 1), b(write_term, 2), b(nl, 0),
        % 5. Character Stream & Term Conversion (library(charsio))
        b(read_from_chars, 2), b(read_term_from_chars, 3), b(write_term_to_chars, 3),
        b(char_type, 2), b(chars_utf8bytes, 2), b(chars_base64, 3),
        % 6. ISO Extensions & Low-level VM (library(iso_ext))
        b(bb_put, 2), b(bb_b_put, 2), b(bb_get, 2),
        b(copy_term_nat, 2), b(countall, 2), b(partial_string, 1),
        % 7. Pseudo-random number generation (library(random))
        b(maybe, 0), b(random, 1), b(random_integer, 3), b(set_random, 1),
        % 8. Time & Benchmarking (library(time))
        b(format_time, 4), b(max_sleep_time, 1), b(sleep, 1), b(statistics, 2),
        % 9. Cryptographic Primitives (library(crypto))
        b(hex_bytes, 2), b(crypto_data_hash, 3), b(crypto_n_random_bytes, 2),
        % 10. CLP(B) Boolean Constraints (library(clpb))
        b(sat, 1), b(taut, 2), b(sat_count, 2), b(weighted_maximum, 3),
        % 11. Files and Directories (library(files))
        b(directory_files, 2), b(file_size, 2), b(file_exists, 1), b(directory_exists, 1),
        b(path_canonical, 2), b(path_segments, 2), b(working_directory, 2),
        % 12. Operating System Environment (library(os))
        b(getenv, 2), b(setenv, 2), b(unsetenv, 1), b(pid, 1), b(shell, 1), b(shell, 2),
        % 13. Pure I/O (library(pio))
        b(phrase_from_file, 2), b(phrase_from_file, 3), b(phrase_from_stream, 2),
        b(phrase_to_file, 2), b(phrase_to_file, 3), b(phrase_to_stream, 2),
        % 14. Coroutining / Delay (library(when))
        b(when, 2),
        % 15. HTML and XML Parsing (library(sgml))
        b(load_html, 3), b(load_xml, 3),
        % 16. WAM Diagnostics (library(diag))
        b(wam_instructions, 2), b(inlined_instructions, 2),
        % 17. Attributed Variables (library(atts))
        b(term_attributed_variables, 2),
        % 18. CLP(Z) Constraints (library(clpz))
        b('#=', 2), b('#\\=', 2), b('#<', 2), b('#>', 2), b('#=<', 2), b('#>=', 2),
        b(in, 2), b(ins, 2), b(label, 1), b(labeling, 2)
    ],
    abstract_ast,
    []
)).

%% substrate_absorbed_modules(+SubstrateID, -Modules)
substrate_absorbed_modules(SubstrateID, Modules) :-
    substrate_spec(SubstrateID, substrate(Modules, _, _, _)).

%% substrate_absorbed_predicates(+SubstrateID, -Preds)
substrate_absorbed_predicates(SubstrateID, Preds) :-
    substrate_spec(SubstrateID, substrate(_, Preds, _, _)).

%% substrate_absorbs_predicate_t(+SubstrateID, +Goal, -Truth)
substrate_absorbs_predicate_t(SubstrateID, Goal, Truth) :-
    functor(Goal, F, A),
    substrate_absorbed_predicates(SubstrateID, Preds),
    memberd_t(b(F, A), Preds, Truth).

%% substrate_absorbs_module_t(+SubstrateID, +ModSpec, -Truth)
substrate_absorbs_module_t(SubstrateID, ModSpec, Truth) :-
    substrate_absorbed_modules(SubstrateID, Modules),
    if_(memberd_t(ModSpec, Modules),
        Truth = true,
        if_(ModSpec = library(Bare),
            memberd_t(Bare, Modules, Truth),
            Truth = false
        )
    ).

%% substrate_emit_abstract_form(+SubstrateID, +PrologTerm, -AbstractForm)
%  Emits the abstract representation (IR) appropriate for the given substrate.
substrate_emit_abstract_form(SubstrateID, PrologTerm, AbstractForm) :-
    substrate_spec(SubstrateID, substrate(_, _, Emitter, _)),
    emit_form(Emitter, PrologTerm, AbstractForm).

emit_form(abstract_ast, Term, ast(Term)).
