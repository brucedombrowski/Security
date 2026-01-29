#!/bin/bash
#
# Integration Tests - End-to-End Scan Verification
#
# Purpose: Verify the complete scan workflow with known test patterns
# NIST Control: CA-2, CA-7 (Security Assessment & Monitoring)
#
# Usage: ./tests/test-integration.sh
#
# Exit codes:
#   0 = All tests passed
#   1 = One or more tests failed

set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test helper functions
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  Test $TESTS_RUN: $1... "
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}"
    echo "    Expected: $1"
    echo "    Got: $2"
}

test_skip() {
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    TESTS_RUN=$((TESTS_RUN - 1))
    echo -e "${YELLOW}SKIP${NC} ($1)"
}

# Cleanup function
cleanup() {
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

# Create test environment with known patterns
setup_test_environment() {
    TEST_DIR=$(mktemp -d)

    # Create directory structure
    mkdir -p "$TEST_DIR/src"
    mkdir -p "$TEST_DIR/config"
    mkdir -p "$TEST_DIR/docs"

    # File with known PII patterns (for PII scanner to detect)
    cat > "$TEST_DIR/src/user-data.txt" << 'EOF'
User Database Export
====================
John Doe: 123-45-6789
Phone: 555-123-4567
Card: 4111111111111111
IP: 192.168.1.100
EOF

    # File with known secrets (for secrets scanner to detect)
    cat > "$TEST_DIR/config/settings.env" << 'EOF'
# Configuration
DATABASE_URL=postgres://user:password123@localhost/db
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
api_key = "sk1234567890abcdef1234567890abcdef"
password = "secretpass123"
EOF

    # Clean file (should not trigger any scanner)
    cat > "$TEST_DIR/docs/readme.txt" << 'EOF'
This is a clean documentation file.
No sensitive data here.
Just regular text content.
EOF

    # File with MAC address (for MAC scanner to detect)
    cat > "$TEST_DIR/config/network.conf" << 'EOF'
# Network Configuration
interface eth0
  mac_address = AA:BB:CC:DD:EE:FF
  dhcp = true
EOF

    echo "$TEST_DIR"
}

echo "=========================================="
echo "Integration Tests - End-to-End Verification"
echo "=========================================="
echo ""

# -----------------------------------------------------------------------------
# Setup
# -----------------------------------------------------------------------------
echo "--- Setting up test environment ---"
TEST_DIR=$(setup_test_environment)
echo "  Test directory: $TEST_DIR"
echo ""

# -----------------------------------------------------------------------------
# Individual Scanner Tests
# -----------------------------------------------------------------------------
echo "--- PII Scanner Integration ---"

test_start "PII scanner detects SSN pattern"
pii_output=$("$REPO_DIR/scripts/check-pii.sh" "$TEST_DIR" 2>&1 || true)
if echo "$pii_output" | grep -q "123-45-6789\|SSN\|Social Security"; then
    test_pass
else
    test_fail "SSN detection" "not detected"
fi

test_start "PII scanner detects phone number"
if echo "$pii_output" | grep -q "555-123-4567\|Phone"; then
    test_pass
else
    test_fail "phone detection" "not detected"
fi

test_start "PII scanner detects credit card"
if echo "$pii_output" | grep -q "4111111111111111\|Credit Card"; then
    test_pass
else
    test_fail "credit card detection" "not detected"
fi

test_start "PII scanner detects IP address"
if echo "$pii_output" | grep -q "192.168.1.100\|IPv4"; then
    test_pass
else
    test_fail "IP detection" "not detected"
fi

echo ""
echo "--- Secrets Scanner Integration ---"

test_start "Secrets scanner detects AWS key"
secrets_output=$("$REPO_DIR/scripts/check-secrets.sh" "$TEST_DIR" 2>&1 || true)
if echo "$secrets_output" | grep -q "AKIAIOSFODNN7EXAMPLE\|AWS"; then
    test_pass
else
    test_fail "AWS key detection" "not detected"
fi

test_start "Secrets scanner detects API key or password"
if echo "$secrets_output" | grep -qi "api.key\|Generic API\|password\|Hardcoded"; then
    test_pass
else
    test_fail "API key or password detection" "not detected"
fi

test_start "Secrets scanner detects database password"
if echo "$secrets_output" | grep -q "password123\|DATABASE_URL\|Password"; then
    test_pass
else
    test_fail "database password detection" "not detected"
fi

echo ""
echo "--- MAC Address Scanner Integration ---"

test_start "MAC scanner detects MAC address"
mac_output=$("$REPO_DIR/scripts/check-mac-addresses.sh" "$TEST_DIR" 2>&1 || true)
if echo "$mac_output" | grep -qi "AA:BB:CC:DD:EE:FF\|MAC"; then
    test_pass
else
    test_fail "MAC address detection" "not detected"
fi

echo ""
echo "--- Malware Scanner Integration ---"

test_start "Malware scanner runs without error"
if command -v clamscan &> /dev/null; then
    malware_output=$("$REPO_DIR/scripts/check-malware.sh" "$TEST_DIR" 2>&1 || true)
    if echo "$malware_output" | grep -qi "scan\|clamav\|clean\|infected"; then
        test_pass
    else
        test_fail "malware scan output" "no recognizable output"
    fi
else
    test_skip "ClamAV not installed"
fi

echo ""

# -----------------------------------------------------------------------------
# Full Scan Suite Test
# -----------------------------------------------------------------------------
echo "--- Full Scan Suite Integration ---"

test_start "run-all-scans.sh completes successfully"
# Run with non-interactive mode, skip malware (slow) if ClamAV missing
skip_flags=""
if ! command -v clamscan &> /dev/null; then
    skip_flags="--skip-malware"
fi
full_scan_output=$("$REPO_DIR/scripts/run-all-scans.sh" -n $skip_flags "$TEST_DIR" 2>&1 || true)
if echo "$full_scan_output" | grep -qi "scan\|complete\|report"; then
    test_pass
else
    test_fail "scan completion" "scan did not complete"
fi

test_start "Scan creates .scans directory"
if [ -d "$TEST_DIR/.scans" ]; then
    test_pass
else
    test_fail ".scans directory" "not created"
fi

test_start "Scan creates report file"
if ls "$TEST_DIR/.scans/"*report*.txt 2>/dev/null | head -1 | grep -q "report"; then
    test_pass
else
    test_fail "report file" "not created"
fi

test_start "Report contains NIST references"
report_file=$(ls "$TEST_DIR/.scans/"*report*.txt 2>/dev/null | head -1 || echo "")
if [ -n "$report_file" ] && grep -qi "NIST\|800-53\|800-171" "$report_file"; then
    test_pass
else
    test_fail "NIST references in report" "not found"
fi

test_start "Report summarizes findings"
if [ -n "$report_file" ] && grep -qi "PASS\|FAIL\|Finding\|Result" "$report_file"; then
    test_pass
else
    test_fail "findings summary" "not found"
fi

echo ""

# -----------------------------------------------------------------------------
# Clean File Test (No False Positives)
# -----------------------------------------------------------------------------
echo "--- False Positive Verification ---"

# Create a truly clean directory
CLEAN_DIR=$(mktemp -d)
echo "This is completely clean text with no patterns." > "$CLEAN_DIR/clean.txt"
echo "Another clean file for testing." > "$CLEAN_DIR/another.txt"

test_start "PII scanner passes on clean files"
clean_pii=$("$REPO_DIR/scripts/check-pii.sh" "$CLEAN_DIR" 2>&1 || true)
if echo "$clean_pii" | grep -q "PASS\|No PII"; then
    test_pass
else
    test_fail "PASS on clean files" "unexpected findings"
fi

test_start "Secrets scanner passes on clean files"
clean_secrets=$("$REPO_DIR/scripts/check-secrets.sh" "$CLEAN_DIR" 2>&1 || true)
if echo "$clean_secrets" | grep -q "PASS\|No secrets"; then
    test_pass
else
    test_fail "PASS on clean files" "unexpected findings"
fi

rm -rf "$CLEAN_DIR"

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "=========================================="
echo "Integration Test Summary"
echo "=========================================="
echo "  Total:   $TESTS_RUN"
echo "  Passed:  $TESTS_PASSED"
echo "  Failed:  $TESTS_FAILED"
echo "  Skipped: $TESTS_SKIPPED"
echo ""

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$TESTS_FAILED integration test(s) failed${NC}"
    exit 1
fi
