# SPEC — `cards`: Baseball Card Inventory CLI in Memelang

A real-world test vehicle for the Memelang language. Built as Memelang
source modules, compiled with the Memelang compiler (python target is the
runnable artifact; all six targets must produce identical output for
scripted sessions). This document is the contract — implement it exactly;
where Memelang cannot express something, note it in docs/GAPS.md rather
than working around it in host code (there IS no host code — everything
runs as generated Memelang output).

## Project layout

/mnt/ssd/projects/card-inventory/
  main.meme        entry point: argv routing to commands
  storage.meme     CSV load/save/parse helpers, id generation
  commands.meme    one function per command
  docs/GAPS.md     language gaps hit during development (append-only)
  run.sh           compile (heuristic provider, lockfile) + exec python target
  cards.csv        the data file (created by `cards init`)
  photos/          (user's picture files live here or anywhere — referenced by path)

## Data format (locked)

- CSV at cards.csv, first line is the header:
  `id,year,brand,player,condition,quantity,photo,notes`
- 8 columns exactly; rows must have exactly 8 fields — a malformed row is
  corruption: print the line number + message, exit 2.
- NO quoting support: values must not contain commas or newlines. `add`
  and `set` validate arguments and exit 1 with a clear message if a comma
  or newline is present. (Document in help text.)
- `id` is a zero-padded 6-digit string ("000001"), lexically sortable.
  Next id = highest existing id + 1 (integer value of, add 1, text of,
  then pad with "0" via a while loop until string length 6). Empty file
  (header only) -> first id 000001.
- `quantity` must be a non-negative integer (validate on add/set; store as
  the canonical text form, e.g. no leading zeros — "007" is invalid input,
  "0" is valid).
- `photo` is a filesystem path (usually into photos/); empty string when
  absent.

## Commands (argv contract — `argument 1` is the command name)

All commands work on cards.csv in the CURRENT WORKING DIRECTORY (not the
executable's directory). If cards.csv does not exist for any command
except `init` and `help`: print "no cards.csv — run: cards init" and exit 1.

- `cards help` — print the command summary. Exit 0.
- `cards init` — create cards.csv with the header if absent; if present,
  print "already exists" and exit 0 (idempotent).
- `cards add <year> <brand> <player> <condition> <quantity> [notes]` —
  validate (year 4 digits, quantity non-negative integer, no commas/newlines),
  append row with next id, print "added <id>", exit 0. Bad input: message +
  exit 1.
- `cards list [player]` — print header line, then one line per row:
  `<id>  <year>  <player>  <brand>  <condition>  qty <quantity>  [photo]`
  where `[photo]` shows `*` when the photo column is non-empty. With a
  filter argument, only rows whose player contains it (case-sensitive
  contains is fine). Print "0 cards" when nothing matches.
- `cards show <id>` — print all 8 fields, one per line, labeled. Unknown
  id: "not found: <id>", exit 1.
- `cards set <id> <field> <value>` — field is one of year, brand, player,
  condition, quantity, photo, notes (unknown field: exit 1). quantity
  validated. photo value may be empty string argument "". Rewrite the whole
  file. Print "updated <id> <field>". Unknown id: exit 1.
- `cards remove <id>` — rewrite the file without the row. Print "removed
  <id>". Unknown id: exit 1.
- `cards photo <id> <path>` — the photo path must exist on disk (use the
  file-exists check): if not, "no such file: <path>", exit 1. If the path is
  already inside photos/ (it starts with "photos/"), set the photo column
  (same rewrite as set) and print "linked <path> to <id>". Otherwise the
  file is ORGANIZED into photos/: ensure the photos/ directory exists
  (create it if missing), then copy the file to photos/<filename> — never
  overwriting an existing file: if photos/<filename> already exists, use
  <base>_1<ext>, <base>_2<ext>, ... (counter appended before the extension).
  Store the new photos/ path in the photo column and print
  "organized <newpath> to <id>". Unknown id: "not found: <id>", exit 1
  (checked before any copy is made).
- `cards photos` — for every row with a non-empty photo column, print
  `<id>  OK` or `<id>  MISSING  <path>` (existence checked live).
- `cards check` — run the photos report for ALL rows, then print a summary:
  `<n> entries, <p> with photos, <m> missing files`. Exit 1 if any missing,
  else 0.
- `cards stats` — print `entries: <n>`, `total cards: <sum of quantities>`,
  `with photos: <p>`, `without photos: <n minus p>`.

Numeric fields are parsed with the string->int builtin and formatted with
the int->string builtin. Where input was pre-validated as all digits, use
the safe-parse form `integer value of <s> or else 0` (the fallback is dead
code by construction and SPEC-mandated error messages are emitted before
parsing). Read the whole CSV with read string from file, split by newline,
split each line by comma; write with write file (rebuild the full text and
write once — do not append for updates).

## Compile & run contract

run.sh (bash, trivial):
  cd to script dir; uv run --project /mnt/ssd/projects/meme meme compile
  main.meme --provider heuristic --target python --lockfile main.meme.lock
  -o build/cards.py, then `python3 build/cards.py "$@"`.
The lockfile means zero-LLM rebuilds after first compile. All six targets
(python/rust/cpp/go/c/ts) must compile the app and produce identical output
for the scripted acceptance session below — compile each target in CI-style
parity tests via a small test script (parity.sh) the build agent creates.

## Acceptance session (must pass end-to-end, exact output asserted in a
test script `acceptance.sh`):

  cards init
  cards add 1989 Topps "Ken Griffey Jr." NM 2 rookie year
  cards add 1993 Donruss "Barry Bonds" EX 1
  cards add 1980 Topps "Rickey Henderson" VG 1
  cards list
  cards list Griffey
  cards show 000002
  cards set 000003 quantity 4
  cards photo 000001 photos/griffey.jpg   (place a real file there first)
  cards photo 000002 photos/missing.jpg   (expect exit 1 — file absent)
  cards photos
  cards check
  cards stats
  cards remove 000003
  cards list
  cards add 1989 Fleer "Barry Bonds" NM 0   (quantity "0" is valid)
  cards add 189 Topps "Bad Year" NM 1       (expect exit 1 — year not 4 digits)
  cards add 1989 Topps "Zero Lead" NM 007   (expect exit 1 — leading zero qty)
  cards photo 000003 out/Bonds.jpg          (place a real file outside photos/;
                                             expect "organized photos/Bonds.jpg to 000003")
  cards photo 000002 out/Bonds.jpg          (expect "organized photos/Bonds_1.jpg to 000002"
                                             — collision gets _1 before the extension)
  cards photos                              (all three linked photos report OK)
  cards check                               (3 entries, 3 with photos, 0 missing files)

## Known language gaps to record in docs/GAPS.md (do not hack around)

- RESOLVED (2026-11): file copy/move builtins now exist (`copy file <src>
  to <dst>`, `create directory <path>`); `cards photo` organizes external
  files into photos/ with collision-safe naming. See the photo command
  contract above.
- No directory listing builtin: `photos` validates known paths only.
- No read line-by-line: whole-file read + split is the pattern (fine at
  collection scale).

## Build rules

- Memelang source only — no host-language helper code anywhere; run.sh only
  invokes the memelang compiler.
- Modules: main/storage/commands with `use`, per the language's import rules.
- Every function returns/exits per the contract; use Optional and fail
  semantics where natural.
- After building: run acceptance.sh against the python target until green,
  then compile+run the same session against the other five targets and
  assert identical output (parity.sh).
