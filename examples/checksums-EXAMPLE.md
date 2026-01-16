# Scan Output Checksums

Generated: 2026-01-15T14:30:00Z
Toolkit: Security Verification Toolkit v1.14.0 (abc1234)
Source: https://github.com/brucedombrowski/Security
Target: /path/to/scanned/project

## Host Inventory Reference

All scan outputs reference this host inventory snapshot:

```
SHA256: a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456
File:   host-inventory-2026-01-15-T143000Z.txt
```

**Note:** The host inventory contains sensitive information (MAC addresses,
serial numbers, installed software). Scan results can be shared without
exposing this data - they only reference the inventory checksum.

## SHA256 Checksums

```
b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567a  clamav-log-2026-01-15.txt
a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456  host-inventory-2026-01-15-T143000Z.txt
c3d4e5f6789012345678901234567890abcdef1234567890abcdef12345678ab  host-security-scan-2026-01-15-T143000Z.txt
d4e5f6789012345678901234567890abcdef1234567890abcdef123456789abc  mac-address-scan-2026-01-15-T143000Z.txt
e5f6789012345678901234567890abcdef1234567890abcdef123456789abcde  malware-scan-2026-01-15-T143000Z.txt
f6789012345678901234567890abcdef1234567890abcdef123456789abcdef0  pii-scan-2026-01-15-T143000Z.txt
789012345678901234567890abcdef1234567890abcdef123456789abcdef012  secrets-scan-2026-01-15-T143000Z.txt
89012345678901234567890abcdef1234567890abcdef123456789abcdef0123  security-scan-report-2026-01-15-T143000Z.txt
```

## Verification

To verify integrity of scan results:

```bash
cd .scans && shasum -a 256 -c checksums.md
```
