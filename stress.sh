#!/usr/bin/env bash
# Hard-asserting stress test: each case asserts BOTH exit code and expected substring.
set -u
cd "$(dirname "$0")"
CLI="./run.sh"
pass=0; fail=0
expect() { # desc, expected_exit, expected_substring, cmd...
  local desc="$1" eexit="$2" esub="$3"; shift 3
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" = "$eexit" ] && echo "$out" | grep -qF "$esub"; then
    pass=$((pass+1))
  else
    fail=$((fail+1)); echo "FAIL: $desc (exit=$rc want=$eexit; output: $out)"
  fi
}

rm -f cards.csv cards.csv.bak
expect "no-cards.csv on list" 1 "no cards.csv" $CLI list
$CLI init >/dev/null 2>&1
expect "unknown command" 1 "unknown command" $CLI boguscmd
expect "add missing args" 1 "" $CLI add 2020 Topps
expect "add bad quantity" 1 "" $CLI add 2020 Topps "P. Judge" NM abc
expect "add neg quantity" 1 "" $CLI add 2020 Topps "P. Judge" NM -3
expect "add float quantity" 1 "" $CLI add 2020 Topps "P. Judge" NM 3.5
expect "add leading-zero quantity" 1 "quantity must be a non-negative integer" $CLI add 2020 Topps "P. Judge" NM 007
expect "add leading-double-zero quantity" 1 "quantity must be a non-negative integer" $CLI add 2020 Topps "P. Judge" NM 00
expect "add 3-digit year" 1 "year must be 4 digits" $CLI add 205 Topps "P. Judge" NM 1
expect "add 5-digit year" 1 "year must be 4 digits" $CLI add 20205 Topps "P. Judge" NM 1
expect "add bad year" 1 "" $CLI add 20x5 Topps "P. Judge" NM 1
expect "add comma value" 1 "" $CLI add "2020," Topps "P. Judge" NM 1
expect "add ok" 0 "added 000001" $CLI add 1989 Topps "K. Griffey" NM 2
expect "add zero quantity ok" 0 "added 000002" $CLI add 2020 Topps "Zero Qty" NM 0
expect "show unknown id" 1 "not found" $CLI show 999999
expect "show malformed id" 1 "" $CLI show abc
expect "set unknown id" 1 "" $CLI set 999999 quantity 5
expect "photo missing file" 1 "no such file" $CLI photo 000001 photos/nope.jpg
expect "photo missing file outside photos" 1 "no such file" $CLI photo 000001 stress_src_nope.jpg
printf 'x' > stress_src.jpg
expect "photo organize into photos" 0 "organized photos/stress_src.jpg to 000001" $CLI photo 000001 stress_src.jpg
if [ ! -f photos/stress_src.jpg ]; then
  fail=$((fail+1)); echo "FAIL: photo organize did not copy source into photos/"
fi
expect "photo organize collision _1" 0 "organized photos/stress_src_1.jpg to 000001" $CLI photo 000001 stress_src.jpg
if [ ! -f photos/stress_src_1.jpg ]; then
  fail=$((fail+1)); echo "FAIL: photo organize collision did not create _1 name"
fi
rm -f stress_src.jpg
printf 'id,year,brand,player,condition,quantity,photo,notes\n000001,1989,Topps,Griffey,NM,2,\nBADROW\n' > cards.csv
expect "corrupt row exit 2" 2 "" $CLI list
printf 'id,year,brand,player,condition,quantity,photo,notes\n' > cards.csv
expect "header-only list" 0 "0 cards" $CLI list
expect "header-only stats" 0 "entries: 0" $CLI stats
printf 'id,year,brand,player,condition,quantity,photo,notes\n000001,1989,Topps,Griffey,NM,2,,rookie\n' > cards.csv
mkdir -p photos/dirphoto
expect "photo is directory" 1 "" $CLI photo 000001 photos/dirphoto
expect "remove ok" 0 "removed 000001" $CLI remove 000001
expect "remove again" 1 "not found" $CLI remove 000001
rm -f cards.csv cards.csv.bak; $CLI init >/dev/null 2>&1
rm -f photos/stress_src.jpg photos/stress_src_1.jpg
echo "----------------------------------------"
echo "stress_assert: $pass passed, $fail failed"
[ "$fail" = 0 ]
