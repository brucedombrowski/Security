#!/bin/bash
#
# Audit Logging Test Suite
#
# Purpose: Verify audit logging library functionality
# NIST Controls: AU-2, AU-3
#
# Tests:
#   1. Log file creation
#   2. JSON format validity
#   3. Event types logging
#   4. Helper functions
#   5. Log rotation (daily files)
#   6. Error handling

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECURITY_REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_DIR="$SECURITY_REPO_DIR/scripts/lib"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Create temporary test directory
TEST_DIR=$(mktemp -d)
trap "rm -rf $TEST_DIR" EXIT

# Test helper functions
pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}: $1"
    if [ -n "$2" ]; then
        echo "       Details: $2"
    fi
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Test $TESTS_RUN: "
}

# Source the audit log library
source "$LIB_DIR/audit-log.sh"

echo "========================================"
echo "Audit Logging Test Suite"
echo "========================================"
echo "Library: $LIB_DIR/audit-log.sh"
echo "Test Dir: $TEST_DIR"
echo ""

# ============================================================================
# Test 1: Log file creation
# ============================================================================
run_test
TEST_NAME="Log file creation"
init_audit_log "$TEST_DIR" "test-scan"
if [ -f "$AUDIT_LOG_FILE" ]; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Audit log file not created"
fi

# ============================================================================
# Test 2: SCAN_START event logged
# ============================================================================
run_test
TEST_NAME="SCAN_START event logged"
if grep -q '"event":"SCAN_START"' "$AUDIT_LOG_FILE" 2>/dev/null; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "SCAN_START event not found in log"
fi

# ============================================================================
# Test 3: JSON format validity
# ============================================================================
run_test
TEST_NAME="JSON format validity"
# Check each line is valid JSON (using Python if available, else basic check)
if command -v python3 &>/dev/null; then
    INVALID_LINES=0
    while IFS= read -r line; do
        if ! echo "$line" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
            INVALID_LINES=$((INVALID_LINES + 1))
        fi
    done < "$AUDIT_LOG_FILE"

    if [ "$INVALID_LINES" -eq 0 ]; then
        pass "$TEST_NAME"
    else
        fail "$TEST_NAME" "$INVALID_LINES invalid JSON lines"
    fi
elif command -v jq &>/dev/null; then
    if jq -e . "$AUDIT_LOG_FILE" >/dev/null 2>&1; then
        pass "$TEST_NAME"
    else
        fail "$TEST_NAME" "jq validation failed"
    fi
else
    # Basic check: lines start with { and end with }
    if grep -v '^{.*}$' "$AUDIT_LOG_FILE" | grep -q .; then
        fail "$TEST_NAME" "Lines don't match JSON object pattern"
    else
        pass "$TEST_NAME (basic check - jq/python not available)"
    fi
fi

# ============================================================================
# Test 4: Required fields present (AU-3 compliance)
# ============================================================================
run_test
TEST_NAME="Required fields present (AU-3)"
REQUIRED_FIELDS=("timestamp" "host" "user" "pid" "scan_type" "event" "details")
MISSING_FIELDS=""

for field in "${REQUIRED_FIELDS[@]}"; do
    if ! grep -q "\"$field\":" "$AUDIT_LOG_FILE"; then
        MISSING_FIELDS="$MISSING_FIELDS $field"
    fi
done

if [ -z "$MISSING_FIELDS" ]; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Missing fields:$MISSING_FIELDS"
fi

# ============================================================================
# Test 5: audit_log function
# ============================================================================
run_test
TEST_NAME="audit_log function"
audit_log "TEST_EVENT" "test details with spaces"
if grep -q '"event":"TEST_EVENT"' "$AUDIT_LOG_FILE"; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Custom event not logged"
fi

# ============================================================================
# Test 6: audit_log_finding helper
# ============================================================================
run_test
TEST_NAME="audit_log_finding helper"
audit_log_finding "SSN" "src/data.txt:42" "pattern=xxx-xx-xxxx"
if grep -q '"event":"FINDING_DETECTED"' "$AUDIT_LOG_FILE" && \
   grep -q 'type=SSN' "$AUDIT_LOG_FILE"; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Finding not logged correctly"
fi

# ============================================================================
# Test 7: audit_log_allowlist_match helper
# ============================================================================
run_test
TEST_NAME="audit_log_allowlist_match helper"
audit_log_allowlist_match "API_KEY" "config.js:10" "abc123hash"
if grep -q '"event":"ALLOWLIST_MATCH"' "$AUDIT_LOG_FILE"; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Allowlist match not logged"
fi

# ============================================================================
# Test 8: audit_log_file_skipped helper
# ============================================================================
run_test
TEST_NAME="audit_log_file_skipped helper"
audit_log_file_skipped "/path/to/symlink" "symlink"
if grep -q '"event":"FILE_SKIPPED"' "$AUDIT_LOG_FILE"; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "File skipped not logged"
fi

# ============================================================================
# Test 9: audit_log_error helper
# ============================================================================
run_test
TEST_NAME="audit_log_error helper"
audit_log_error "Test error message" "test context"
if grep -q '"event":"ERROR"' "$AUDIT_LOG_FILE"; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Error not logged"
fi

# ============================================================================
# Test 10: audit_log_config_change helper
# ============================================================================
run_test
TEST_NAME="audit_log_config_change helper"
audit_log_config_change "allowlist" "add" "entry=test-entry"
if grep -q '"event":"CONFIG_CHANGE"' "$AUDIT_LOG_FILE"; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Config change not logged"
fi

# ============================================================================
# Test 11: finalize_audit_log function
# ============================================================================
run_test
TEST_NAME="finalize_audit_log function"
# Save the log file path before finalize clears it
SAVED_LOG_FILE="$AUDIT_LOG_FILE"
finalize_audit_log "PASS" "findings=0"
# Re-init to continue tests
init_audit_log "$TEST_DIR" "test-scan-2"
if grep -q '"event":"SCAN_COMPLETE"' "$SAVED_LOG_FILE" 2>/dev/null; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "SCAN_COMPLETE event not logged"
fi

# ============================================================================
# Test 12: is_audit_log_enabled function
# ============================================================================
run_test
TEST_NAME="is_audit_log_enabled function"
if is_audit_log_enabled; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Audit logging should be enabled"
fi

# ============================================================================
# Test 13: get_audit_log_path function
# ============================================================================
run_test
TEST_NAME="get_audit_log_path function"
LOG_PATH=$(get_audit_log_path)
if [ -n "$LOG_PATH" ] && [ -f "$LOG_PATH" ]; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "get_audit_log_path returned invalid path"
fi

# ============================================================================
# Test 14: Special characters in details are escaped
# ============================================================================
run_test
TEST_NAME="Special character escaping"
audit_log "SPECIAL_CHARS" "path=/tmp/test with spaces/file.txt quote=\"value\""
# Check the log file still has valid JSON after special chars
if command -v python3 &>/dev/null; then
    LAST_LINE=$(tail -1 "$AUDIT_LOG_FILE")
    if echo "$LAST_LINE" | python3 -c "import json,sys; json.load(sys.stdin)" 2>/dev/null; then
        pass "$TEST_NAME"
    else
        fail "$TEST_NAME" "Special characters broke JSON format"
    fi
else
    # Basic check
    pass "$TEST_NAME (python not available for validation)"
fi

# ============================================================================
# Test 15: Timestamp format (ISO 8601)
# ============================================================================
run_test
TEST_NAME="Timestamp format (ISO 8601)"
# Check timestamp matches YYYY-MM-DDTHH:MM:SSZ pattern
if grep -E '"timestamp":"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$AUDIT_LOG_FILE" >/dev/null; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Timestamp not in ISO 8601 format"
fi

# ============================================================================
# Test 16: Log file naming (daily rotation)
# ============================================================================
run_test
TEST_NAME="Log file naming (daily rotation)"
DATE_STAMP=$(date -u +%Y-%m-%d)
if echo "$AUDIT_LOG_FILE" | grep -q "audit-log-$DATE_STAMP.jsonl"; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Log file name doesn't follow daily rotation pattern"
fi

# ============================================================================
# Test 17: scan_type field consistency
# ============================================================================
run_test
TEST_NAME="scan_type field consistency"
if grep '"scan_type":"test-scan-2"' "$AUDIT_LOG_FILE" >/dev/null; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "scan_type not consistent across entries"
fi

# ============================================================================
# Test 18: PID field is numeric
# ============================================================================
run_test
TEST_NAME="PID field is numeric"
if grep -E '"pid":[0-9]+,' "$AUDIT_LOG_FILE" >/dev/null; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "PID field is not numeric"
fi

# ============================================================================
# Test 19: Disabled logging handling
# ============================================================================
run_test
TEST_NAME="Disabled logging handling"
# Disable logging and try to write
CURRENT_LOG="$AUDIT_LOG_FILE"
AUDIT_LOG_ENABLED=0
BEFORE_COUNT=$(wc -l < "$CURRENT_LOG" | tr -d ' ')
audit_log "SHOULD_NOT_APPEAR" "test" || true  # Expect return 1 when disabled
AFTER_COUNT=$(wc -l < "$CURRENT_LOG" | tr -d ' ')
if [ "$BEFORE_COUNT" -eq "$AFTER_COUNT" ]; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Logging occurred while disabled (before=$BEFORE_COUNT after=$AFTER_COUNT)"
fi
# Re-enable for remaining tests
AUDIT_LOG_ENABLED=1

# ============================================================================
# Test 20: Empty event type rejected
# ============================================================================
run_test
TEST_NAME="Empty event type rejected"
BEFORE_COUNT=$(wc -l < "$CURRENT_LOG" | tr -d ' ')
audit_log "" "should not log" || true  # Expect return 1 for empty event
AFTER_COUNT=$(wc -l < "$CURRENT_LOG" | tr -d ' ')
if [ "$BEFORE_COUNT" -eq "$AFTER_COUNT" ]; then
    pass "$TEST_NAME"
else
    fail "$TEST_NAME" "Empty event type was logged (before=$BEFORE_COUNT after=$AFTER_COUNT)"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$TESTS_FAILED test(s) failed${NC}"
    exit 1
fi
