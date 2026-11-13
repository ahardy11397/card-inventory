#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CARDS_BIN="${1:-$SCRIPT_DIR/run.sh}"

echo "Running acceptance suite using runner: $CARDS_BIN"

TMP_DIR="$(mktemp -d /tmp/cards_acc_XXXXXX)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# Setup test working directory
TEST_DIR="$TMP_DIR/work"
mkdir -p "$TEST_DIR/photos"
touch "$TEST_DIR/photos/griffey.jpg"
rm -f "$TEST_DIR/photos/missing.jpg"
mkdir -p "$TEST_DIR/out"
touch "$TEST_DIR/out/Bonds.jpg"

cd "$TEST_DIR"

step_num=0
assert_step() {
    local cmd_desc="$1"
    local expected_code="$2"
    local expected_output="$3"
    shift 3
    local actual_code=0
    step_num=$((step_num + 1))

    local actual_output
    actual_output="$("$CARDS_BIN" "$@" 2>&1)" || actual_code=$?

    if [ "$actual_code" -ne "$expected_code" ]; then
        echo "FAIL Step $step_num: $cmd_desc"
        echo "Expected exit code: $expected_code, got: $actual_code"
        echo "Output was:"
        echo "$actual_output"
        exit 1
    fi

    if [ "$actual_output" != "$expected_output" ]; then
        echo "FAIL Step $step_num: $cmd_desc"
        echo "--- Expected output ---"
        echo "$expected_output"
        echo "--- Actual output ---"
        echo "$actual_output"
        echo "--- Diff ---"
        diff -u <(echo "$expected_output") <(echo "$actual_output") || true
        exit 1
    fi

    echo "PASS Step $step_num: $cmd_desc"
}

# Step 1: cards init
assert_step "cards init" 0 "" init

# Step 2: cards add 1989 Topps "Ken Griffey Jr." NM 2 rookie year
assert_step "cards add Griffey" 0 "added 000001" add 1989 Topps "Ken Griffey Jr." NM 2 rookie year

# Step 3: cards add 1993 Donruss "Barry Bonds" EX 1
assert_step "cards add Bonds" 0 "added 000002" add 1993 Donruss "Barry Bonds" EX 1

# Step 4: cards add 1980 Topps "Rickey Henderson" VG 1
assert_step "cards add Henderson" 0 "added 000003" add 1980 Topps "Rickey Henderson" VG 1

# Step 5: cards list
expected_list5=$(cat <<'EOF'
id  year  player  brand  condition  qty  photo
000001  1989  Ken Griffey Jr.  Topps  NM  qty 2
000002  1993  Barry Bonds  Donruss  EX  qty 1
000003  1980  Rickey Henderson  Topps  VG  qty 1
EOF
)
assert_step "cards list" 0 "$expected_list5" list

# Step 6: cards list Griffey
expected_list6=$(cat <<'EOF'
id  year  player  brand  condition  qty  photo
000001  1989  Ken Griffey Jr.  Topps  NM  qty 2
EOF
)
assert_step "cards list Griffey" 0 "$expected_list6" list Griffey

# Step 7: cards show 000002
expected_show7=$(cat <<'EOF'
id: 000002
year: 1993
brand: Donruss
player: Barry Bonds
condition: EX
quantity: 1
photo: 
notes: 
EOF
)
assert_step "cards show 000002" 0 "$expected_show7" show 000002

# Step 8: cards set 000003 quantity 4
assert_step "cards set 000003 quantity 4" 0 "updated 000003 quantity" set 000003 quantity 4

# Step 9: cards photo 000001 photos/griffey.jpg
assert_step "cards photo 000001 photos/griffey.jpg" 0 "linked photos/griffey.jpg to 000001" photo 000001 photos/griffey.jpg

# Step 10: cards photo 000002 photos/missing.jpg (expect exit 1 — file absent)
assert_step "cards photo 000002 photos/missing.jpg (expect exit 1)" 1 "no such file: photos/missing.jpg" photo 000002 photos/missing.jpg

# Step 11: cards photos
expected_photos11=$(cat <<'EOF'
000001  OK
EOF
)
assert_step "cards photos" 0 "$expected_photos11" photos

# Step 12: cards check
expected_check12=$(cat <<'EOF'
000001  OK
3 entries, 1 with photos, 0 missing files
EOF
)
assert_step "cards check" 0 "$expected_check12" check

# Step 13: cards stats
expected_stats13=$(cat <<'EOF'
entries: 3
total cards: 7
with photos: 1
without photos: 2
EOF
)
assert_step "cards stats" 0 "$expected_stats13" stats

# Step 14: cards remove 000003
assert_step "cards remove 000003" 0 "removed 000003" remove 000003

# Step 15: cards list
expected_list15=$(cat <<'EOF'
id  year  player  brand  condition  qty  photo
000001  1989  Ken Griffey Jr.  Topps  NM  qty 2  *
000002  1993  Barry Bonds  Donruss  EX  qty 1
EOF
)
assert_step "cards list after remove" 0 "$expected_list15" list

# Step 16: cards add 1989 Fleer "Barry Bonds" NM 0 (quantity "0" is valid)
assert_step "cards add quantity 0 (valid)" 0 "added 000003" add 1989 Fleer "Barry Bonds" NM 0

# Step 17: cards add 189 Topps "Bad Year" NM 1 (expect exit 1 — year not 4 digits)
assert_step "cards add 3-digit year (expect exit 1)" 1 "error: year must be 4 digits" add 189 Topps "Bad Year" NM 1

# Step 18: cards add 1989 Topps "Zero Lead" NM 007 (expect exit 1 — leading zero qty)
assert_step "cards add leading-zero quantity (expect exit 1)" 1 "error: quantity must be a non-negative integer" add 1989 Topps "Zero Lead" NM 007

# Step 19: cards photo 000003 out/Bonds.jpg (file outside photos/ gets organized)
assert_step "cards photo 000003 out/Bonds.jpg (organize)" 0 "organized photos/Bonds.jpg to 000003" photo 000003 out/Bonds.jpg
if [ ! -f "$TEST_DIR/photos/Bonds.jpg" ]; then
    echo "FAIL Step 19: photos/Bonds.jpg was not copied into photos/"
    exit 1
fi

# Step 20: same source again — collision gets _1 before the extension
assert_step "cards photo 000002 out/Bonds.jpg (collision _1)" 0 "organized photos/Bonds_1.jpg to 000002" photo 000002 out/Bonds.jpg
if [ ! -f "$TEST_DIR/photos/Bonds_1.jpg" ]; then
    echo "FAIL Step 20: photos/Bonds_1.jpg was not created for the collision"
    exit 1
fi

# Step 21: cards photos
expected_photos21=$(cat <<'EOF'
000001  OK
000002  OK
000003  OK
EOF
)
assert_step "cards photos" 0 "$expected_photos21" photos

# Step 22: cards check
expected_check22=$(cat <<'EOF'
000001  OK
000002  OK
000003  OK
3 entries, 3 with photos, 0 missing files
EOF
)
assert_step "cards check" 0 "$expected_check22" check

echo ""
echo "ALL 22 ACCEPTANCE STEPS PASSED SUCCESSFULLY!"
