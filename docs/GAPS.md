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

3. **No streaming / line-by-line file reading**:
   - Reading files requires loading the entire file into memory with `read string from file <path>`, followed by splitting strings.
   - Consequence: Fine for personal collection scale; for very large datasets this requires reading the whole text into a single String in memory.

---

## Discovered Language Gaps During Implementation

4. **No standalone expression statements or void function call statements**:
   - Memelang IR does not contain an expression-statement node (e.g. bare `foo()` on its own line). Function calls can only appear as expressions (such as `define rc as foo()`, `return foo()`, or within conditions).
   - Consequence: Command handler functions return an `Int` status code and are invoked via assignment expressions (`define rc as cmd_...()`).

5. **No list item removal / deletion / pop builtins**:
   - List operations in Memelang IR support `append`, `insert`, and indexed update (`set list[i] to val`), but do not include `remove`, `delete`, or `pop`.
   - Consequence: Removing an item (as in `cards remove <id>`) requires constructing a new `empty List<Card>` and copying non-matching items into it.

6. **No character-class or regex validation builtins**:
   - The language provides no `is_digit()`, `is_numeric()`, or regular expression matching builtins.
   - Consequence: String validation for year (4 digits) and quantity (non-negative integer) requires checking each character individually via `char at i of s` against digit literals `"0"` through `"9"`.

7. **No error handling / try-catch for conversion builtins** — **RESOLVED (2026-11)**:
   - The compiler now provides the safe-parse form `integer value of <s> or else <default>` (lazy fallback; see WRITING_GUIDE §11b.2).
   - Resolution: pre-validated parses in `cmd_add` / `cmd_set` (quantity canonicalization) now use the `or else` form; SPEC-mandated error messages are emitted before parsing, so error-message contracts are unchanged. Un-pre-validated parses (CSV-derived ids/quantities in `next_card_id` and `stats`) intentionally keep the strict form so corrupt data still fails loudly.

