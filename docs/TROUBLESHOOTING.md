# Troubleshooting Guide

Advanced diagnostics for Security Verification Toolkit issues. For common questions, see [FAQ.md](FAQ.md).

## Quick Diagnostics

Run this command to check toolkit health:

```bash
./scripts/run-all-scans.sh --check-deps
```

## Exit Codes Reference

Scripts use these exit codes:

| Code | Meaning | Action |
|------|---------|--------|
| 0 | Success/Pass | No action needed |
| 1 | Findings require review | Check `.scans/` output for details |
| 2 | Missing dependency | Install required tool (e.g., ClamAV) |

**Note:** Exit code 1 means "review required" - the scan completed successfully but found items that need human review. This is not an error.

---

## ClamAV Issues

### Virus database outdated

**Symptom:** Warning about outdated virus definitions.

**Diagnostic:**
```bash
# Check database age
ls -la /opt/homebrew/var/lib/clamav/*.cvd  # macOS
ls -la /var/lib/clamav/*.cvd               # Linux

# Check freshclam log
cat /var/log/clamav/freshclam.log
```

**Fix:**
```bash
sudo freshclam
```

### ClamAV daemon not responding

**Symptom:** `clamd` connection refused errors.

**Diagnostic:**
```bash
# Check if daemon is running
pgrep -l clamd

# Test daemon connection
clamdscan --ping
```

**Fix:**
```bash
# macOS
brew services restart clamav

# Linux (systemd)
sudo systemctl restart clamav-daemon
```

### ClamAV path resolution failures

**Symptom:** "ClamAV not found" despite installation.

**Diagnostic:**
```bash
# Check installation paths
which clamscan
which freshclam

# Check Homebrew paths (macOS)
brew --prefix clamav
```

**Fix:** The toolkit searches these paths in order:
1. `$PATH` lookup
2. `/opt/homebrew/bin/` (macOS ARM)
3. `/usr/local/bin/` (macOS Intel)
4. `/usr/bin/` (Linux)

Add the correct path to your shell profile if needed.

---

## NVD API Issues

### Rate limiting (HTTP 429)

**Symptom:** `Too Many Requests` errors.

**Diagnostic:**
```bash
# Check cache status
ls -la ~/.cache/nvd-api/
```

**Fix:**
1. Wait 30 seconds between API calls (automatic)
2. Set `NVD_API_KEY` for higher rate limits:
   ```bash
   export NVD_API_KEY="your-api-key"
   ```
3. Get API key at: https://nvd.nist.gov/developers/request-an-api-key

### API connection failures

**Symptom:** Network timeouts or connection refused.

**Diagnostic:**
```bash
# Test API connectivity
curl -I "https://services.nvd.nist.gov/rest/json/cves/2.0"
```

**Fix:**
1. Check firewall rules for `services.nvd.nist.gov`
2. Check proxy settings: `$HTTP_PROXY`, `$HTTPS_PROXY`
3. Use offline mode with cached data

### Cache corruption

**Symptom:** JSON parse errors from cached responses.

**Fix:**
```bash
# Clear NVD cache
rm -rf ~/.cache/nvd-api/
```

---

## Allowlist Issues

### Hash mismatch on allowlisted entry

**Symptom:** Entry not suppressed despite being allowlisted.

**Cause:** The matched content changed since the allowlist entry was created.

**Diagnostic:**
```bash
# View allowlist entry
cat .allowlists/pii-allowlist

# Entry format: SHA256 # REASON # TRUNCATED_FINDING
# The SHA256 is computed from the matched CONTENT ONLY (not file path or line number)
# This allows entries to survive when code moves between lines
```

**Fix:**
1. Re-add the entry using interactive mode:
   ```bash
   ./scripts/check-pii.sh -i .
   ```
2. Or manually compute the hash from the matched content:
   ```bash
   # Hash is of the content portion only (after file:line:)
   echo -n "192.168.1.1" | shasum -a 256
   ```

### Allowlist file not detected

**Symptom:** Allowlisted entries still flagged.

**Diagnostic:**
```bash
# Check allowlist exists and has correct permissions
ls -la .allowlists/

# Verify format (one entry per line)
head .allowlists/pii-allowlist
```

**Fix:** Ensure allowlist files are in `.allowlists/` directory at the target root.

---

## PDF Generation Issues

### LaTeX compilation errors

**Symptom:** PDF generation fails with LaTeX errors.

**Diagnostic:**
```bash
# Check for .log file
cat .scans/*.log

# Common error patterns:
# - "Missing $ inserted" = unescaped special chars
# - "Undefined control sequence" = missing package
```

**Fix:**
1. Ensure all LaTeX packages are installed:
   ```bash
   sudo tlmgr install fancyhdr lastpage geometry xcolor hyperref
   ```
2. Check for special characters in input (& % $ # _ { } ~ ^)

### Logo not found

**Symptom:** Warning about missing logo.png.

**Diagnostic:**
```bash
ls -la templates/logo.png
```

**Fix:** Place a logo.png file in `templates/` or the script will continue without it.

---

## Audit Log Issues

### Log file not created

**Symptom:** No audit log in `.scans/` directory.

**Cause:** `init_audit_log` not called or directory permissions.

**Diagnostic:**
```bash
# Check .scans directory permissions
ls -la .scans/

# Verify audit log initialization
grep -r "init_audit_log" scripts/
```

**Fix:** Ensure target directory is writable and `.scans/` can be created.

### Invalid JSON in audit log

**Symptom:** JSON parse errors when reading audit log.

**Diagnostic:**
```bash
# Validate JSON Lines format (each line is valid JSON)
while read -r line; do
    echo "$line" | jq . > /dev/null || echo "Invalid: $line"
done < .scans/audit-*.jsonl
```

**Fix:** Audit logs use JSON Lines format (one JSON object per line). Ensure log wasn't truncated mid-write.

---

## Integration Test Failures

### Tests pass locally but fail in CI

**Diagnostic checklist:**
1. Shell version: `bash --version` (requires 4.0+)
2. Available tools: `which nmap lynis clamscan`
3. File permissions: `ls -la tests/`
4. Environment variables: `env | grep -E "^(PATH|HOME|USER)="`

### Test timeout

**Symptom:** Test hangs then fails.

**Diagnostic:**
```bash
# Run with verbose output
bash -x ./tests/test-integration.sh
```

**Fix:**
1. Reduce test data size in `tests/fixtures/`
2. Increase timeout in test script
3. Check for infinite loops in test logic

---

## macOS-Specific Issues

### System Integrity Protection (SIP) blocking scans

**Symptom:** Permission denied on system directories.

**Diagnostic:**
```bash
csrutil status
```

**Note:** This is expected. The toolkit cannot scan SIP-protected directories (`/System`, `/usr/bin`, etc.). These are excluded by design.

### Gatekeeper blocking script execution

**Symptom:** "cannot be opened because the developer cannot be verified"

**Fix:**
```bash
# Remove quarantine attribute
xattr -d com.apple.quarantine scripts/*.sh
```

### ARM vs Intel path differences

**Symptom:** Tools not found on Apple Silicon.

**Diagnostic:**
```bash
# Check architecture
uname -m  # arm64 or x86_64

# Check Homebrew prefix
brew --prefix  # /opt/homebrew (ARM) or /usr/local (Intel)
```

**Fix:** The toolkit auto-detects paths, but ensure `PATH` includes:
- ARM: `/opt/homebrew/bin`
- Intel: `/usr/local/bin`

---

## Linux-Specific Issues

### AppArmor/SELinux blocking scans

**Symptom:** Permission denied despite correct file permissions.

**Diagnostic:**
```bash
# Check SELinux (RHEL/CentOS)
getenforce
ausearch -m avc -ts recent

# Check AppArmor (Ubuntu)
aa-status
```

**Fix:** Create policy exceptions or run in permissive mode for testing.

### Missing GNU coreutils

**Symptom:** `timeout`, `realpath`, or other commands not found.

**Fix:**
```bash
# Debian/Ubuntu
sudo apt install coreutils

# Alpine
apk add coreutils
```

---

## Network Scanning Issues (Nmap/OpenVAS)

### Nmap requires root for SYN scan

**Symptom:** "TCP/IP fingerprinting requires root privileges"

**Fix:**
```bash
sudo ./scripts/scan-vulnerabilities.sh --nmap-only localhost
```

### OpenVAS not responding

**Diagnostic:**
```bash
# Check GVM services
systemctl status gvmd ospd-openvas

# Test OMP/GMP connection
gvm-cli --gmp-username admin socket --xml "<get_version/>"
```

---

## Getting Debug Output

Enable verbose output for any script:

```bash
# Method 1: Set DEBUG variable
DEBUG=1 ./scripts/check-pii.sh .

# Method 2: Use bash -x
bash -x ./scripts/check-pii.sh .

# Method 3: Check audit log
cat .scans/audit-*.jsonl | jq .
```

## Reporting Issues

When reporting issues, include:

1. **Command run:** Full command with arguments
2. **Exit code:** `echo $?` after command
3. **Error output:** Full error message
4. **Environment:**
   ```bash
   uname -a
   bash --version
   ./scripts/run-all-scans.sh --version
   ```
5. **Relevant logs:** `.scans/audit-*.jsonl`

Open issues at: https://github.com/brucedombrowski/security-toolkit/issues
