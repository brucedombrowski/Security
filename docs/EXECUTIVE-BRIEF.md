# Security Verification Toolkit — Executive Brief

**Version:** 2.1.2
**Date:** February 2026
**Classification:** Unclassified

---

## Purpose

The Security Verification Toolkit automates security compliance verification for software projects against federal standards, enabling organizations to meet NIST 800-53, NIST 800-171, and FIPS 199/200 requirements with auditable, repeatable scans.

## Business Value

| Benefit | Impact |
|---------|--------|
| **Reduced Compliance Cost** | Automated scans replace manual security reviews |
| **Faster Certification** | Pre-built NIST control mappings accelerate ATO process |
| **Audit-Ready Output** | PDF attestations with checksums for submittal packages |
| **Risk Reduction** | Continuous scanning catches PII, secrets, and vulnerabilities early |

## Capability Summary

### What It Scans

- **PII Detection** — SSN, phone numbers, email, credit cards, IP addresses
- **Secrets Detection** — API keys, passwords, tokens, private keys (35+ patterns)
- **Malware Scanning** — ClamAV integration for malicious code (SI-3)
- **Vulnerability Assessment** — CVE cross-reference via NVD and CISA KEV
- **Host Security** — OS configuration, encryption, firewall status

### NIST Control Coverage

| Control Family | Controls Addressed |
|----------------|-------------------|
| Access Control (AC) | AC-3, AC-6 |
| Audit (AU) | AU-2, AU-3 |
| Configuration Management (CM) | CM-6, CM-8 |
| Risk Assessment (RA) | RA-5 |
| System & Info Integrity (SI) | SI-2, SI-3, SI-4, SI-5, SI-12 |
| System & Comms Protection (SC) | SC-8 |

## Platform Support

| Platform | Status |
|----------|--------|
| macOS (Intel/ARM) | Fully Supported |
| Linux (Ubuntu, CentOS, Debian) | Fully Supported |
| Windows 10/11, Server 2016+ | Supported (PowerShell + Git Bash) |
| CI/CD (GitHub Actions) | Integrated |

## Current Release Highlights (v2.1.x)

- Windows PowerShell support for cross-platform deployment
- Automated CI/CD integration with GitHub Actions
- CISA Known Exploited Vulnerabilities (KEV) catalog integration
- NVD CVE lookup with local caching for air-gapped environments
- PDF attestation generation for compliance packages

## Deployment Model

- **Pure Bash** — No build system, dependencies, or compilation required
- **Offline Capable** — Bundled threat intelligence for air-gapped networks
- **Non-Invasive** — Read-only scans; no modifications to target systems
- **Auditable** — All outputs include SHA256 checksums and version tracking

## Integration Options

```bash
# Single command execution
./scripts/run-all-scans.sh /path/to/project

# CI/CD pipeline integration
./scripts/run-all-scans.sh -n /path/to/project  # Non-interactive mode

# Interactive menu
./scripts/tui.sh
```

## Governance

| Aspect | Approach |
|--------|----------|
| **Transparency** | All findings documented with file:line references |
| **Inspectability** | Open source, auditable scan logic |
| **Accountability** | Allowlist entries require SHA256 hash + justification |
| **Traceability** | Checksums link attestations to source code state |

## Support & Maintenance

- **Repository:** github.com/brucedombrowski/security-toolkit
- **License:** MIT
- **Updates:** Threat intelligence (KEV catalog) updated with each release
- **Documentation:** Comprehensive guides for installation, usage, and compliance mapping

---

**Contact:** See repository SECURITY.md for vulnerability reporting procedures.
