#!/usr/bin/env bash

source test/init

plan tests 10

script=$PWD/openqa-label-known-issues-multi

# Run the script with a stubbed sibling "openqa-label-known-issues" so the
# script's "$(dirname "$0")"/openqa-label-known-issues resolves to our mock.
run_multi() {
    local stub_body=$1 input=$2
    local bindir
    bindir=$(mktemp -d)
    cp "$script" "$bindir/openqa-label-known-issues-multi"
    cat > "$bindir/openqa-label-known-issues" << EOF
#!/bin/bash
$stub_body
EOF
    chmod +x "$bindir"/openqa-label-known-issues*
    printf '%s' "$input" | "$bindir/openqa-label-known-issues-multi"
    local rc=$?
    rm -rf "$bindir"
    return $rc
}

unknown='echo "[$1]($1): Unknown test issue, to be reviewed"'

# 1. Unknown issue: header to stderr, summary to stdout, exit 0
try 'stdout=$(run_multi "$unknown" "http://o3/tests/1" 2>/tmp/err_$$); cat /tmp/err_$$; echo "---"; echo "$stdout"; rm -f /tmp/err_$$'
is "$rc" 0 "exit 0 on unknown issue"
has "$got" "[http://o3/tests/1](http://o3/tests/1): Unknown test issue, to be reviewed" "header forwarded to stderr"
has "$got" "1 unknown issues to be reviewed" "summary printed to stdout"

# 2. Header does not leak to stdout (only summary on stdout)
try 'run_multi "$unknown" "http://o3/tests/1" 2>/dev/null'
is "$rc" 0 "exit 0 (stdout-only capture)"
hasnt "$got" "autoinst-log.txt" "excerpt/header not on stdout"
has "$got" "unknown issues to be reviewed" "summary on stdout"

# 3. Known issue (no unknown header): no review summary
try 'run_multi "echo done" "http://o3/tests/2" 2>/dev/null'
is "$rc" 0 "exit 0 on known issue"
is "$got" "" "no summary when nothing to review"

# 4. Child failure propagates exit code and forwards output to stderr
try 'run_multi "echo boom >&1; exit 3" "http://o3/tests/3" 2>&1'
is "$rc" 3 "child non-zero exit code propagated"
has "$got" "boom" "failure output forwarded"
