# Memelang Language Gaps and Limitations

This document records language limitations and gaps encountered while implementing the `cards` CLI in Memelang, per `SPEC.md`. As required, we record every limitation hit instead of hacking around it or modifying the compiler.

## Initial Known Gaps (from SPEC.md)

1. **No file copy / move / rename builtins** — **RESOLVED (2026-11)**:
   - The compiler now provides `copy file <src> to <dst>`, `move file <src>
     to <dst>`, `delete file <path>`, `create directory <path>`, and
     `list files in <path>` (see the Memelang WRITING_GUIDE §11b.1).
   - Resolution: `cards photo <id> <path>` now copies files from outside
     photos/ into photos/ (`create directory` + `copy file`) with
     collision-safe `_1`, `_2` naming, per SPEC.md.

2. **No directory listing builtins**:
   - The language previously had no `list files in <dir>` or globbing capability.
   - Consequence: The `photos` and `check` commands can only validate known paths stored in `cards.csv`, rather than discovering unreferenced files on disk.

3. **No streaming / line-by-line file reading** — **RESOLVED (2026-11)**:
   - The compiler now provides `read lines from file <path>` -> `List<String>` (see Memelang WRITING_GUIDE §11b.4).
   - Resolution: Reading files line-by-line no longer requires manual whole-file reading and splitting in user code; newlines (`\n`) are stripped deterministically and empty files yield `[]`. Missing files fail with `Error reading file: <path>` across all six targets.

---

## Discovered Language Gaps During Implementation

4. **No standalone expression statements or void function call statements** — **RESOLVED (2026-11)**:
   - The compiler now provides the `call <function-name>(<args>)` statement (see Memelang WRITING_GUIDE §8 and §11b.5).
   - Resolution: Functions (both `Void` and non-`Void`) can now be invoked directly as statements without needing the `define rc as func(...)` workaround. Return values from non-`Void` functions invoked via `call` are safely discarded.

5. **No list item removal / deletion / pop builtins**:
   - List operations in Memelang IR support `append`, `insert`, and indexed update (`set list[i] to val`), but do not include `remove`, `delete`, or `pop`.
   - Consequence: Removing an item (as in `cards remove <id>`) requires constructing a new `empty List<Card>` and copying non-matching items into it.

6. **No character-class or regex validation builtins** — **RESOLVED (2026-11)**:
   - The compiler now provides `is letter <c>`, `is upper <c>`, and `is lower <c>` alongside `is digit <c>` (see Memelang WRITING_GUIDE §11b.2 and §11b.6).
   - Resolution: Character-class validation can now test whether a character is an ASCII letter, uppercase letter, lowercase letter, or digit directly without manually testing against character literals or bounds. Empty and multi-character inputs return `false`.

7. **No error handling / try-catch for conversion builtins** — **RESOLVED (2026-11)**:
   - The compiler now provides the safe-parse form `integer value of <s> or else <default>` (lazy fallback; see WRITING_GUIDE §11b.2).
   - Resolution: pre-validated parses in `cmd_add` / `cmd_set` (quantity canonicalization) now use the `or else` form; SPEC-mandated error messages are emitted before parsing, so error-message contracts are unchanged. Un-pre-validated parses (CSV-derived ids/quantities in `next_card_id` and `stats`) intentionally keep the strict form so corrupt data still fails loudly.

