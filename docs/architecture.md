# `prolog_toolkit` Architecture & Design

This document details the architectural layout, modules, and design philosophy of `prolog_toolkit`—a pure, ISO-compliant lexical and syntactic analysis toolkit for Prolog in Scryer Prolog.

---

## 1. System Overview

`prolog_toolkit` provides a complete pipeline from raw character streams to rich, semantically annotated Abstract Syntax Trees (ASTs):

```
Character Stream (chars)
       │
       ▼
 [prolog_lexer] / [prolog_lifted_lexer]
       │  - Pure DCG character scanning
       │  - Position tracking (line, column, byte offset, source)
       │  - Attributed tokens (token class, operator metadata)
       ▼
 [prolog_parser] / [prolog_reactive_ast]
       │  - Declarative grammar rules (DCG)
       │  - Lazy AST nodes via attributed variables (library(atts))
       │  - Reactive dependency resolution via verify_attributes/3
       ▼
 [prolog_expander]
       │  - Macro & goal expansion (term_expansion/2, goal_expansion/2)
       │  - Expansion lineage tracking (original source + macro rules used)
       ▼
 [prolog_provenance] & [term_io]
          - read_term/2,3 & read_term_ex/2,3,4
          - First-class variable provenance via attributed variables
          - Span merging on variable unification
```

---

## 2. Core Modules

| Module | Location | Purpose |
| :--- | :--- | :--- |
| `prolog_toolkit` | [`src/prolog_toolkit.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_toolkit.pl) | Top-level re-export facade for consumer applications. |
| `prolog_lexer` | [`src/prolog_lexer.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_lexer.pl) | High-performance DCG lexer operating on character lists. |
| `prolog_reactive_parser` | [`src/prolog_reactive_parser.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_reactive_parser.pl) | **Unified Parser**: Pure operator-precedence climbing and reactive clause parser supporting both standard raw ISO terms and lazy attributed ASTs. |
| `prolog_reactive_ast` | [`src/prolog_reactive_ast.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_reactive_ast.pl) | **Reactive Attributed AST Engine**: Lazy AST nodes with dependency tracking and cascade resolution via `library(atts)`. |
| `prolog_attributed_tokens` | [`src/prolog_attributed_tokens.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_attributed_tokens.pl) | **Attributed Token Stream**: Variables carrying token class, values, positions, and operator metadata. |
| `prolog_provenance` | [`src/prolog_provenance.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_provenance.pl) | First-class variable provenance tracking (names, occurrences, spans) on attributed variables. |
| `prolog_expander` | [`src/prolog_expander.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_expander.pl) | Pure macro expander with lineage tracking. |
| `term_io` | [`src/term_io.pl`](file:///home/doug/code/prolog_toolkit/src/term_io.pl) | High-level `read_term_ex` and `iso_read_term` APIs. |
| `prolog_operators` | [`src/prolog_operators.pl`](file:///home/doug/code/prolog_toolkit/src/prolog_operators.pl) | ISO and Scryer built-in operator table and precedence management. |

---

## 3. Reactive Attributed AST Architecture (`prolog_reactive_ast`)

### 3.1 The Key Idea

In standard parsers, AST nodes are constructed strictly bottom-up (or top-down through return values). If an operand, type, or operator precedence is not yet determined, parsing must either backtrack, construct intermediate dummy nodes, or run multi-pass tree rewrites.

In the **Reactive Attributed AST** model, **every AST node is a Prolog logical variable** carrying an attribute:
```prolog
ast_node(State, Deps, Constructor, Metadata)
```
Where:
- **`State`**: `lazy` (pending resolution) or `resolved`.
- **`Deps`**: List of child nodes or tokens required to finalize this node.
- **`Constructor`**: A declarative specification describing how to construct the final node (e.g. `binary_op(+)`, `call(Functor)`, `clause(Head, Body)`, `literal(Val)`).
- **`Metadata`**: Spans, annotations, type constraints, and reactive semantic actions.

Dependencies that are variables also carry:
```prolog
ast_subscribers(ListOfParentVars)
```

### 3.2 Dataflow Propagation via `verify_attributes/3`

Prolog's unification engine and `library(atts)` serve as an in-engine Functional Reactive Programming (FRP) / dependency network:

1. **Lazy Node Creation**:
   When a grammar rule recognizes a syntactic construct, it immediately produces an unbound variable `Node` with its `ast_node` attribute and registers itself as a subscriber to each child in `Deps`.
2. **Unification Trigger**:
   When a child node resolves or is bound to a concrete value, Scryer Prolog's `verify_attributes(ChildVar, Other, Goals)` hook fires automatically.
3. **Cascading Resolution**:
   The hook notifies all subscribed parents. Each parent checks whether all of its dependencies in `Deps` are ready (non-variable or resolved).
4. **Final Term Binding**:
   When all children are ready, the parent's `Constructor` executes, position spans are merged (`merge_spans(Left, Right)`), semantic actions fire, and `Node` unifies with the finalized AST term.
5. **Top-Level Convergence**:
   Binding `Node` immediately triggers `verify_attributes` on *its* subscribers, cascading upward to the root AST.

```
       [Grammar Rule]
             │
             ▼
      lazy_ast_node/4 ───(registers)───► ast_subscribers on Children
             │
   (Child 1 Unifies)
             │
             ▼
   verify_attributes/3
             │
             ▼
    notify_subscribers/1
             │
             ▼
     all_deps_ready?
      ├── No  ──► remain lazy
      └── Yes ──► execute Constructor, merge spans, bind Node!
                    │
                    ▼
          (Cascades to Grandparents...)
```

### 3.3 Key Architectural Advantages

1. **Out-of-Order & Incremental Parsing**:
   Child nodes can resolve in any order (left-to-right, right-to-left, or asynchronously from an editor/LSP buffer). The AST finalizes deterministically as information becomes available.
2. **First-Class Logical Variables in ASTs**:
   Prolog variables in source code (e.g. `X` in `foo(X, X)`) are preserved as regular logical variables. The dependency checker distinguishes between an *unresolved lazy node* (`is_lazy_ast_node(V)`) and a *program variable* (`var(V)` without lazy node state).
3. **Operator Precedence as Tree Constraints**:
   Ambiguous infix chains can be modeled as lazy binary nodes. When operator priorities are unified, tree balancing/rotations execute reactively before the node finalizes.
4. **Rational Tree (Cyclic AST) Safety**:
   Scryer Prolog supports rational trees natively (`X = f(X)`). Cyclic references in ASTs (e.g., self-referential terms, circular grammar productions) do not trigger infinite loops or stack overflows.
5. **Position & Provenance Propagation**:
   Token positions, byte offsets, and source file metadata propagate and merge automatically upon node resolution.

### 3.4 Incremental Parsing & AST Holes

A critical capability of the Reactive Attributed AST engine is **fine-grained incremental parsing**:
- Unparsed, dirty, or actively edited source sections are instantiated as **AST Holes** via `create_ast_hole(HoleNode, HoleID, Metadata)`.
- The surrounding program/clause AST is parsed and built normally around the hole, remaining in a `lazy` state without blocking or failing on syntax errors inside the dirty region.
- When the developer finishes editing the sub-expression (or a language server receives a keystroke), **only the modified sub-region is tokenized and parsed** (`reactive_parse_subterm/5`) within the existing clause variable context.
- Unifying `HoleNode = PatchedGoalNode` automatically triggers `verify_attributes/3`, cascading upward to resolve the parent body and clause AST deterministically.
- All variable occurrences in the patched sub-term share identical logical variables with the rest of the clause, and registered semantic actions (e.g. goal counting, linting, type checks) fire reactively with zero re-parsing of the surrounding code.

---

## 4. Variable Provenance & Attributed Variables (`prolog_provenance`)

Variables parsed in Prolog terms are given `provenance/1` attributes:
```prolog
provenance(var_meta{
    name: "Foo",
    occurrences: [
        pos_span{start: pos(1, 5, 4, Source), end: pos(1, 8, 7, Source)},
        pos_span{start: pos(3, 10, 42, Source), end: pos(3, 13, 45, Source)}
    ],
    inferred_types: [...]
})
```

When two variables sharing the same name inside a clause unify (or when terms are instantiated), Scryer's `verify_attributes/3` hook in `prolog_provenance.pl`:
- Merges the occurrence lists of both variables.
- Verifies and unifies type/value constraints.
- Retains full source trace for error reporting and IDE tooling.

---

## 5. Testing & Verification

The test suite is structured under `tests/`:
- `test_prolog_reactive_ast.pl`: Reactive AST node creation, out-of-order child resolution, subscriber cascades, rational tree safety, and reactive semantic actions.
- `test_prolog_reactive_parser.pl`: End-to-end scanning of attributed tokens, operator precedence climbing into reactive ASTs, variable sharing, list expressions, and DCG rules.
- `test_incremental_ast_patching.pl`: Incremental parsing spike: AST hole creation, targeted sub-expression parsing, and reactive root AST resolution with variable sharing.
- `test_term_io.pl`: ISO `read_term/2,3`, `read_term_ex/2,3,4`, attributed variable provenance, and macro lineage.
- `test_prolog_expander.pl`: Term and goal expansion with lineage.
- `test_parse_all_scryer_lib.pl`: Regression suite parsing Scryer Prolog's standard library.

---

## 6. Source-Provenance Meta-Interpreter & Debugger (Roadmap)

### 6.1 Goal & Vision
Build a pure, step-level meta-interpreter capable of executing user code and interpreted Scryer standard library modules (patched where needed). Leveraging the toolkit's reactive AST and provenance infrastructure, every goal invocation, unification, choicepoint, and reduction step retains its exact source location (`span(StartPos, EndPos)`), enabling:
- **Execution Tracing & Step Debugging**: Inspect the proof tree interactively with full line/column context.
- **Visual Derivation Trees**: Construct an explicit DAG or tree representation of the proof search for explanation and debugging.

### 6.2 Host Engine Primitive Absorption
To maintain high performance and avoid rewriting low-level abstract machine internals in Prolog:
- **Core ISO Primitives**: Unification (`=`), control structures (`,`, `;`, `->`, `*->`, `!`), arithmetic (`is`, `<`, `>`, etc.), and metalogical tests (`var/1`, `functor/3`, `arg/3`, `=..`) are absorbed directly by the host engine.
- **Delimited Control (`reset/3` and `shift/1`)**: Absorbed by the host engine. Because `shift` and `reset` in Scryer Prolog manipulate Rust WAM call-frame environments and continuation registers directly (`$reset_cont_marker`, `$unwind_environments`), delegating to the host allows the host to capture the continuation of the running meta-interpreter while preserving source provenance on all standard goal steps.

