# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) and AI agents working with code in this repository.

## Project Overview

Security verification toolkit for scanning software projects against federal security standards (NIST 800-53, NIST 800-171, FIPS 199/200). Pure Bash implementation with no build system.

## Core Values (TIA Principles)

All changes must maintain:
- **Transparency** - Document all findings, exceptions, and decisions clearly
- **Inspectability** - Output includes file:line references for verification
- **Accountability** - Allowlist entries require SHA256 integrity hash + justification
- **Traceability** - Checksums, toolkit version, and commit hashes link attestations to sources

## Commands

```bash
# Run all tests
./tests/run-all-tests.sh

# Run specific test suite
./tests/test-pii-patterns.sh
./tests/test-secrets-patterns.sh
./tests/test-mac-patterns.sh
./tests/test-audit-logging.sh

# Run all scans on a target project
./scripts/run-all-scans.sh /path/to/project

# Non-interactive mode (CI/CD)
./scripts/run-all-scans.sh -n /path/to/project

# Release workflow
./scripts/release.sh              # Test release
./scripts/release.sh 1.16.0       # Specific version
```

## Repository Structure

```
Security/
├── README.md                    # Usage documentation
├── CLAUDE.md                    # This file (AI agent instructions)
├── CHANGELOG.md                 # Version history
├── INSTALLATION.md              # Platform-specific setup
├── SECURITY.md                  # Vulnerability reporting
├── LICENSE                      # MIT License
├── scripts/
│   ├── run-all-scans.sh         # Master orchestrator
│   ├── release.sh               # Release workflow
│   ├── collect-host-inventory.sh # System inventory (CUI)
│   ├── Collect-HostInventory.ps1 # Windows PowerShell inventory
│   ├── check-pii.sh             # PII pattern detection
│   ├── check-malware.sh         # ClamAV malware scanning
│   ├── check-secrets.sh         # Secrets/credentials detection
│   ├── check-mac-addresses.sh   # MAC address scan
│   ├── check-host-security.sh   # Host OS security
│   ├── check-kev.sh             # CISA KEV cross-reference
│   ├── scan-vulnerabilities.sh  # Nmap/OpenVAS/Lynis
│   ├── harden-system.sh         # System hardening
│   ├── secure-delete.sh         # NIST SP 800-88 deletion
│   ├── purge-git-history.sh     # Remove sensitive files from git
│   ├── generate-compliance.sh   # Compliance statement PDF
│   ├── generate-scan-attestation.sh # PDF attestation
│   └── lib/
│       ├── audit-log.sh         # JSON Lines audit logging
│       ├── progress.sh          # Spinners, progress bars
│       └── timestamps.sh        # ISO 8601 UTC timestamps
├── templates/                   # LaTeX templates for PDFs
├── tests/                       # Unit tests
├── docs/
│   ├── COMPLIANCE.md            # NIST control mapping
│   ├── MAINTENANCE.md           # Maintenance schedules
│   ├── THREAT-INTELLIGENCE.md   # CISA KEV, DHS MARs
│   └── false-positives-macos.md # macOS-specific guidance
├── examples/                    # Redacted example outputs
├── .scans/                      # Raw scan output (gitignored)
├── .assessments/                # Security assessments (PRIVATE)
├── .allowlists/                 # Reviewed exceptions
└── .cache/                      # Threat intelligence cache
```

## Script Design Patterns

All scripts follow these conventions:

**Arguments:** First argument (optional) is target directory; defaults to parent of script

**Exit Codes:** `0` = Pass, `1` = Fail

**Output:**
- Console output for real-time feedback
- Results saved to `<target>/.scans/` with timestamps
- All outputs include toolkit version and commit hash

**Shared Libraries:** Source with `source "$SCRIPT_DIR/lib/audit-log.sh"`

| Library | Purpose |
|---------|---------|
| `audit-log.sh` | JSON Lines audit logging (NIST AU-2/AU-3) |
| `progress.sh` | Spinners, progress bars, ETA, TTY detection |
| `timestamps.sh` | ISO 8601 UTC timestamp utilities |

### NIST Control Mapping

| Script | NIST Control |
|--------|--------------|
| `collect-host-inventory.sh` | CM-8 (System Component Inventory) |
| `check-pii.sh` | SI-12 (Information Management) |
| `check-malware.sh` | SI-3 (Malicious Code Protection) |
| `check-secrets.sh` | SA-11 (Developer Testing) |
| `check-mac-addresses.sh` | SC-8 (Transmission Confidentiality) |
| `check-host-security.sh` | CM-6 (Configuration Settings) |
| `scan-vulnerabilities.sh` | RA-5, SI-2, SI-4, CA-2 |
| `secure-delete.sh` | MP-6 (Media Sanitization) |
| `purge-git-history.sh` | MP-6, SI-12 |

## Adding New Scans

1. Create `scripts/check-<category>.sh`
2. Map to appropriate NIST 800-53 control
3. Add to `run-all-scans.sh` orchestrator
4. Create test file `tests/test-<category>-patterns.sh`
5. Update README.md

### Template

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

### With build scripts

```bash
SECURITY_TOOLKIT="$HOME/Security"
"$SECURITY_TOOLKIT/scripts/run-all-scans.sh" "$(pwd)" || exit 1
```

## Output Directories

| Directory | Contents | Sensitivity |
|-----------|----------|-------------|
| `.scans/` | Raw scan results, checksums, PDFs | Shareable (transient) |
| `.assessments/` | Analysis reports, recommendations | Private (never commit) |
| `.allowlists/` | Reviewed exceptions with SHA256 hashes | Project-specific |
| `.cache/` | Threat intelligence (KEV catalog) | Auto-managed |

## Security Model

### Trust Boundaries

| Boundary | Trust Level | Rationale |
|----------|-------------|-----------|
| Local filesystem | Trusted | Scripts operate on user-accessible files |
| Target directory | Semi-trusted | May contain malicious files (why we scan) |
| Network (localhost) | Trusted | Vulnerability scans target local machine |
| Network (remote) | Untrusted | Remote scans require explicit authorization |

### Data Handling

| Category | Examples | Handling |
|----------|----------|----------|
| CUI | Host inventory, MAC addresses, serial numbers | Mode 600, CUI banner, secure delete |
| PII | SSNs, phone numbers found in scans | Displayed for remediation only |
| Secrets | API keys, passwords found in scans | Never logged in plaintext |

### Security Guarantees

1. **No Data Exfiltration**: Scripts do not transmit data externally
2. **No Code Execution from Targets**: Scans read files, never execute them
3. **Audit Trail**: All scan results are timestamped and checksummed
4. **Fail-Safe Defaults**: Destructive operations require explicit confirmation

## Key Considerations

### Pattern Changes
Regex pattern modifications affect detection accuracy across all scanned projects. Test thoroughly with `./tests/run-all-tests.sh`.

### Allowlist System
Allowlist entries use SHA256 hash of `file:line:content` for integrity verification. Never modify allowlist format without updating verification logic.

### CUI Sensitivity
Host inventory contains Controlled Unclassified Information (MAC addresses, serial numbers, software versions). Never expose in logs, tests, or examples.

### Known Limitations

1. **False Positives**: Use `.allowlists/` to suppress known-good matches
2. **False Negatives**: Cannot detect obfuscated malware, encrypted secrets, novel patterns
3. **Platform-Specific**: Some checks are macOS or Linux specific
4. **Point-in-Time**: Code changes invalidate prior attestations

## Dependencies

- **Required**: Bash 4.0+, grep, git
- **Required for malware scan**: ClamAV (`clamscan`, `freshclam`)
- **Optional**: pdflatex, Nmap, Lynis

## Key Documentation

- [INSTALLATION.md](INSTALLATION.md) - Platform-specific setup
- [docs/COMPLIANCE.md](docs/COMPLIANCE.md) - NIST control mapping details
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md) - Maintenance schedules
- [docs/THREAT-INTELLIGENCE.md](docs/THREAT-INTELLIGENCE.md) - CISA KEV integration
