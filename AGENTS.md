# Security - AI Agent Instructions

## Project Purpose

This repository contains security analysis and compliance documentation tools for scanning software projects against federal security standards (NIST 800-53, FIPS).

## Repository Structure

```
Security/
├── README.md           # Usage documentation
├── AGENTS.md           # This file (AI agent instructions)
├── CHANGELOG.md        # Version history
├── LICENSE             # MIT License
├── .gitignore          # Excludes .scans/ and result files
├── scripts/
│   ├── run-all-scans.sh         # Master orchestrator (inventory + scans + PDF)
│   ├── collect-host-inventory.sh # System inventory (SENSITIVE: MAC addresses, etc.)
│   ├── check-pii.sh             # PII pattern detection
│   ├── check-malware.sh         # ClamAV malware scanning (with DB auto-update)
│   ├── check-secrets.sh         # Secrets/credentials detection
│   ├── check-mac-addresses.sh   # IEEE 802.3 MAC address scan
│   └── check-host-security.sh   # Host OS security verification
└── templates/
    ├── scan_attestation.tex         # Generic attestation LaTeX template
    ├── security_compliance_statement.tex  # Project-specific compliance template
    └── logo.png                     # Logo for PDF headers
```

## Script Design Patterns

All scripts follow these conventions:

### Arguments
- First argument (optional): Target directory to scan
- If not provided, defaults to parent directory of script

### Exit Codes
- `0` = Pass (no issues found)
- `1` = Fail (issues detected)

### Output
- Console output for real-time feedback
- Results saved to `<target>/.scans/` directory:
  - **Host inventory**: `host-inventory-YYYY-MM-DD.txt` (SENSITIVE - contains MAC addresses)
  - Individual scan logs: `*-scan-YYYY-MM-DD.txt` (reference inventory checksum)
  - Consolidated report: `security-scan-report-YYYY-MM-DD.txt`
  - Checksums file: `checksums.md` (SHA256 of all outputs + inventory reference)
  - PDF attestation: `scan-attestation-YYYY-MM-DD.pdf` (if pdflatex available)
  - ClamAV metadata: `malware-metadata-YYYY-MM-DD/` (JSON with file hashes)
  - ClamAV log: `clamav-log-YYYY-MM-DD.txt`
- All outputs include toolkit version and commit hash for traceability
- Scan results can be shared without exposing sensitive machine data (they only reference inventory checksum)
- Suitable for CI/CD pipeline integration

### NIST Control Mapping
Each script maps to specific NIST 800-53 controls:
- `collect-host-inventory.sh` → CM-8 (System Component Inventory)
- `check-pii.sh` → SI-12 (Information Management)
- `check-malware.sh` → SI-3 (Malicious Code Protection)
- `check-secrets.sh` → SA-11 (Developer Testing)
- `check-mac-addresses.sh` → SC-8 (Transmission Confidentiality)
- `check-host-security.sh` → CM-6 (Configuration Settings)

## Adding New Scans

When adding new security checks:

1. Create script in `scripts/` directory
2. Follow naming convention: `check-<category>.sh`
3. Accept target directory as first argument
4. Use exit code 0 for pass, 1 for fail
5. Map to appropriate NIST 800-53 control
6. Update `run-all-scans.sh` to include new scan
7. Update README.md with new script documentation

### Template for new scans

```bash
#!/bin/bash
#
# <Description> Verification Script
#
# Purpose: <What this script checks>
# NIST Control: <Control ID and name>
#
# Exit codes:
#   0 = Pass
#   1 = Fail

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -n "$1" ]; then
    TARGET_DIR="$1"
else
    TARGET_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
REPO_NAME=$(basename "$TARGET_DIR")

echo "<Scan Name>"
echo "==========="
echo "Timestamp: $TIMESTAMP"
echo "Target: $TARGET_DIR"
echo ""

# ... scan logic ...

exit $EXIT_CODE
```

## Integration Patterns

### With SpeakUp-style attestation

If a project wants to produce attestation files (public proof of passing scans):

1. Run scans with this toolkit
2. On success, generate attestation markdown
3. On failure, remove any existing attestation

### With build scripts

Projects can call these scripts from their build process:

```bash
SECURITY_TOOLKIT="$HOME/Security"
"$SECURITY_TOOLKIT/scripts/run-all-scans.sh" "$(pwd)" || exit 1
```

## Templates

### scan_attestation.tex
Generic attestation document generated automatically by `run-all-scans.sh`:
- Substitution variables: `\UniqueID`, `\DocumentDate`, `\TargetName`, `\PIIScanResult`, etc.
- NIST control mapping table
- Scan results table with PASS/FAIL color coding
- Verification instructions for checksums

### security_compliance_statement.tex
Project-specific compliance document requiring manual curation:
- Cryptographic implementation details
- Certificate handling documentation
- Security controls description
- Formal certification statement

## Future Enhancements

Potential additions to the toolkit:

1. **Dependency vulnerability scanning**
   - `npm audit` for Node.js
   - `pip-audit` for Python
   - `dotnet list package --vulnerable` for .NET

2. **FIPS cryptographic compliance**
   - Check for FIPS-approved algorithms
   - Detect weak crypto usage

3. **Static code analysis**
   - Language-specific security linters
   - OWASP pattern detection

## Dependencies

- **Required**: grep (with -E extended regex), git (for version identification)
- **Required for malware scan**: ClamAV (`clamscan`, `freshclam`, `sigtool`)
- **Optional for PDF generation**: pdflatex (from TeX Live or BasicTeX)
- **macOS specific**: Various system commands for host security checks
- **Linux specific**: ufw/iptables, SELinux/AppArmor for host security checks

### Installing Dependencies

**macOS:**
```bash
brew install clamav
brew install basictex  # For PDF generation (optional)
```

**Linux (Debian/Ubuntu):**
```bash
sudo apt install clamav clamav-daemon
sudo apt install texlive-latex-base  # For PDF generation (optional)
```
