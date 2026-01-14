# Security

IT security analysis and compliance documentation tools for software projects.

## Overview

This toolkit provides automated security verification scripts aligned with federal security standards:

| Standard | Title |
|----------|-------|
| NIST SP 800-53 Rev 5 | Security and Privacy Controls |
| NIST SP 800-171 | Protecting CUI in Nonfederal Systems |
| FIPS 199 | Standards for Security Categorization |
| FIPS 200 | Minimum Security Requirements |

## Scripts

| Script | NIST Control | Description |
|--------|--------------|-------------|
| `check-pii.sh` | SI-12 | Scan for PII patterns (SSN, phone, IP, credit card) |
| `check-malware.sh` | SI-3 | ClamAV malware scanning |
| `check-secrets.sh` | SA-11 | Detect hardcoded credentials and API keys |
| `check-mac-addresses.sh` | SC-8 | IEEE 802.3 MAC address detection |
| `check-host-security.sh` | CM-6 | Host OS security posture verification |
| `run-all-scans.sh` | - | Run all scans with consolidated report |
| `generate-compliance.sh` | - | Generate security compliance statement PDF |

## Usage

### Scan a specific project

```bash
# Run all scans on a target directory
./scripts/run-all-scans.sh /path/to/project

# Run individual scans
./scripts/check-pii.sh /path/to/project
./scripts/check-secrets.sh /path/to/project
./scripts/check-malware.sh /path/to/project
```

### Integrate into CI/CD

```yaml
# GitHub Actions example
- name: Security Scan
  run: |
    git clone https://github.com/brucedombrowski/Security.git /tmp/security
    /tmp/security/scripts/run-all-scans.sh ${{ github.workspace }}
```

### Integrate into build script

```bash
# In your project's build.sh
SECURITY_REPO="/path/to/Security"
if [ -x "$SECURITY_REPO/scripts/run-all-scans.sh" ]; then
    "$SECURITY_REPO/scripts/run-all-scans.sh" "$(pwd)"
fi
```

### Generate Compliance Documentation

Generate a formal security compliance statement PDF for a project:

```bash
# Generate PDF and place in project directory
./scripts/generate-compliance.sh /path/to/project

# Specify custom output location
./scripts/generate-compliance.sh /path/to/project /path/to/output
```

See [COMPLIANCE.md](COMPLIANCE.md) for detailed documentation on the compliance workflow.

## Prerequisites

- **ClamAV** - Required for malware scanning
  ```bash
  # macOS
  brew install clamav

  # Ubuntu/Debian
  sudo apt install clamav
  ```

- **pdflatex** - Required for compliance PDF generation (TeX Live or MiKTeX)
  ```bash
  # macOS
  brew install --cask mactex-no-gui

  # Ubuntu/Debian
  sudo apt install texlive-latex-base texlive-latex-recommended
  ```

- **grep** - Standard grep with extended regex support (included in macOS/Linux)

## Exit Codes

All scripts follow standard exit code conventions:
- `0` = Pass (no issues found)
- `1` = Fail (issues detected or scan error)

## Security Policy

- Scripts output results to stdout only
- No files are written to the target repository
- Detailed vulnerability information is displayed for remediation
- Integrate with `.scans/` directory pattern for local result caching (git-ignored)

## NIST Control Mapping

| Control | Family | Description | Script |
|---------|--------|-------------|--------|
| SI-3 | System and Information Integrity | Malicious Code Protection | `check-malware.sh` |
| SI-12 | System and Information Integrity | Information Management and Retention | `check-pii.sh` |
| SA-11 | System and Services Acquisition | Developer Testing and Evaluation | `check-secrets.sh` |
| SC-8 | System and Communications Protection | Transmission Confidentiality and Integrity | `check-mac-addresses.sh` |
| CM-6 | Configuration Management | Configuration Settings | `check-host-security.sh` |

## License

MIT License - see [LICENSE](LICENSE) file.
