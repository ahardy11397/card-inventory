#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Starting Memelang Multi-Target Parity Sweep ==="

BUILD_DIR="$SCRIPT_DIR/build"
mkdir -p "$BUILD_DIR"

MEME_PROJECT="/mnt/ssd/projects/meme"
LOCKFILE="$SCRIPT_DIR/main.meme.lock"

# Target 1: Python
echo "--> [1/6] Compiling Python target..."
uv run --project "$MEME_PROJECT" meme compile main.meme --provider heuristic --target python --lockfile "$LOCKFILE" -o "$BUILD_DIR/cards.py"
cat <<'EOF' > "$BUILD_DIR/cards_python"
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/cards.py" "$@"
EOF
chmod +x "$BUILD_DIR/cards_python"

# Target 2: Rust
echo "--> [2/6] Compiling Rust target..."
uv run --project "$MEME_PROJECT" meme compile main.meme --provider heuristic --target rust --lockfile "$LOCKFILE" -o "$BUILD_DIR/cards.rs"
rustc --edition=2021 "$BUILD_DIR/cards.rs" -o "$BUILD_DIR/cards_rust"

# Target 3: C++
echo "--> [3/6] Compiling C++ target..."
uv run --project "$MEME_PROJECT" meme compile main.meme --provider heuristic --target cpp --lockfile "$LOCKFILE" -o "$BUILD_DIR/cards.cpp"
g++ -std=c++20 "$BUILD_DIR/cards.cpp" -o "$BUILD_DIR/cards_cpp"

# Target 4: Go
echo "--> [4/6] Compiling Go target..."
uv run --project "$MEME_PROJECT" meme compile main.meme --provider heuristic --target go --lockfile "$LOCKFILE" -o "$BUILD_DIR/cards.go"
go build -o "$BUILD_DIR/cards_go" "$BUILD_DIR/cards.go"

# Target 5: C
echo "--> [5/6] Compiling C target..."
uv run --project "$MEME_PROJECT" meme compile main.meme --provider heuristic --target c --lockfile "$LOCKFILE" -o "$BUILD_DIR/cards.c"
gcc -std=c11 -O2 "$BUILD_DIR/cards.c" -o "$BUILD_DIR/cards_c" -lm

# Target 6: TypeScript
echo "--> [6/6] Compiling TypeScript target..."
uv run --project "$MEME_PROJECT" meme compile main.meme --provider heuristic --target ts --lockfile "$LOCKFILE" -o "$BUILD_DIR/cards.ts"
tsc "$BUILD_DIR/cards.ts" --outDir "$BUILD_DIR" --target es2022 --module node16
cat <<'EOF' > "$BUILD_DIR/cards_ts"
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "$SCRIPT_DIR/cards.js" "$@"
EOF
chmod +x "$BUILD_DIR/cards_ts"

echo ""
echo "=== Running Acceptance Suite Against All 6 Targets ==="

TARGETS=("python" "rust" "cpp" "go" "c" "ts")
declare -A RUNNERS=(
    ["python"]="$BUILD_DIR/cards_python"
    ["rust"]="$BUILD_DIR/cards_rust"
    ["cpp"]="$BUILD_DIR/cards_cpp"
    ["go"]="$BUILD_DIR/cards_go"
    ["c"]="$BUILD_DIR/cards_c"
    ["ts"]="$BUILD_DIR/cards_ts"
)

# Helper function to run the full scripted acceptance session and capture raw outputs
run_session() {
    local runner="$1"
    local logfile="$2"
    local session_dir
    session_dir="$(mktemp -d /tmp/parity_session_XXXXXX)"
    mkdir -p "$session_dir/photos"
    touch "$session_dir/photos/griffey.jpg"
    rm -f "$session_dir/photos/missing.jpg"
    mkdir -p "$session_dir/out"
    touch "$session_dir/out/Bonds.jpg"

    (
        cd "$session_dir"
        {
            "$runner" init || echo "EXIT:$?"
            "$runner" add 1989 Topps "Ken Griffey Jr." NM 2 rookie year || echo "EXIT:$?"
            "$runner" add 1993 Donruss "Barry Bonds" EX 1 || echo "EXIT:$?"
            "$runner" add 1980 Topps "Rickey Henderson" VG 1 || echo "EXIT:$?"
            "$runner" list || echo "EXIT:$?"
            "$runner" list Griffey || echo "EXIT:$?"
            "$runner" show 000002 || echo "EXIT:$?"
            "$runner" set 000003 quantity 4 || echo "EXIT:$?"
            "$runner" photo 000001 photos/griffey.jpg || echo "EXIT:$?"
            "$runner" photo 000002 photos/missing.jpg || echo "EXIT:$?"
            "$runner" photos || echo "EXIT:$?"
            "$runner" check || echo "EXIT:$?"
            "$runner" stats || echo "EXIT:$?"
            "$runner" remove 000003 || echo "EXIT:$?"
            "$runner" list || echo "EXIT:$?"
            "$runner" add 1989 Fleer "Barry Bonds" NM 0 || echo "EXIT:$?"
            "$runner" add 189 Topps "Bad Year" NM 1 || echo "EXIT:$?"
            "$runner" add 1989 Topps "Zero Lead" NM 007 || echo "EXIT:$?"
            "$runner" photo 000003 out/Bonds.jpg || echo "EXIT:$?"
            "$runner" photo 000002 out/Bonds.jpg || echo "EXIT:$?"
            "$runner" photos || echo "EXIT:$?"
            "$runner" check || echo "EXIT:$?"
        } > "$logfile" 2>&1
    )
    rm -rf "$session_dir"
}

for target in "${TARGETS[@]}"; do
    runner="${RUNNERS[$target]}"
    echo "Running acceptance suite for target: $target..."
    "$SCRIPT_DIR/acceptance.sh" "$runner" > /dev/null

    log_path="$BUILD_DIR/session_${target}.txt"
    run_session "$runner" "$log_path"
    echo "  -> Target $target passed acceptance suite. Session captured to $log_path."
done

echo ""
echo "=== Verifying Byte-For-Byte Parity Across All 6 Targets ==="
ref_log="$BUILD_DIR/session_python.txt"
for target in "rust" "cpp" "go" "c" "ts"; do
    target_log="$BUILD_DIR/session_${target}.txt"
    if ! cmp -s "$ref_log" "$target_log"; then
        echo "PARITY ERROR between python and $target!"
        diff -u "$ref_log" "$target_log" || true
        exit 1
    fi
    echo "  -> python == $target : PASS (byte-for-byte identical)"
done

echo ""
echo "================================================================================"
echo "PARITY VERIFIED: All 6 targets produced 100% byte-identical output across the acceptance session!"
echo "================================================================================"
