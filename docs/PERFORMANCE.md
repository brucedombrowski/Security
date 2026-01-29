# Performance Guide

Security Verification Toolkit - Performance Baselines and Optimization

## Overview

This document provides performance baselines, resource requirements, and optimization strategies for the Security Verification Toolkit.

## Scan Time Baselines

### Individual Scanners

Measured on Apple M1 Pro with SSD storage:

| Scanner | Small Repo | Medium Repo | Large Repo | Notes |
|---------|------------|-------------|------------|-------|
| | (<1,000 files) | (1,000-10,000 files) | (>10,000 files) | |
| **check-pii.sh** | 5-10 sec | 30-60 sec | 2-5 min | Pattern matching |
| **check-secrets.sh** | 5-10 sec | 30-60 sec | 2-5 min | Pattern matching |
| **check-mac-addresses.sh** | 3-5 sec | 15-30 sec | 1-2 min | Simple patterns |
| **check-malware.sh** | 1-2 min | 5-10 min | 15-30 min | ClamAV intensive |
| **check-host-security.sh** | 10-15 sec | 10-15 sec | 10-15 sec | System checks only |
| **collect-host-inventory.sh** | 30-60 sec | 30-60 sec | 30-60 sec | System enumeration |
| **scan-vulnerabilities.sh** | 2-5 min | 2-5 min | 2-5 min | Network dependent |

### Full Suite (run-all-scans.sh)

| Repository Size | Typical Duration | With Malware Scan | Skip Malware |
|-----------------|------------------|-------------------|--------------|
| Small (<1,000 files) | 2-3 min | 3-4 min | 1-2 min |
| Medium (1,000-10,000) | 10-15 min | 15-20 min | 5-8 min |
| Large (>10,000 files) | 30-60 min | 45-90 min | 15-25 min |

## Resource Requirements

### Memory Usage

| Component | Baseline | Peak | Notes |
|-----------|----------|------|-------|
| PII Scanner | 20 MB | 100 MB | Scales with file size |
| Secrets Scanner | 20 MB | 100 MB | Scales with file size |
| Malware Scanner | 500 MB | 1.2 GB | ClamAV database in memory |
| Host Inventory | 10 MB | 50 MB | System enumeration |
| PDF Generation | 100 MB | 300 MB | LaTeX compilation |

### Disk Space

| Component | Size | Location |
|-----------|------|----------|
| Toolkit scripts | ~500 KB | scripts/ |
| ClamAV database | 300-500 MB | /var/lib/clamav or Homebrew path |
| Scan output (typical) | 50-200 KB | .scans/ |
| PDF attestation | 100-300 KB | .scans/ |
| Audit logs | 10-50 KB/day | .scans/audit/ |

### CPU Usage

- **Pattern scanners**: Single-threaded, 50-80% single core
- **ClamAV**: Multi-threaded, can use 100% of available cores
- **PDF generation**: Single-threaded, brief spikes to 100%

## Optimization Strategies

### 1. Configure Exclusions

Create `.pii-exclude` to skip unnecessary directories:

```
# High-impact exclusions
node_modules/
.git/
vendor/
__pycache__/
.venv/

# Build artifacts
build/
dist/
out/
target/

# Large binary directories
assets/
images/
fonts/
```

**Impact**: Can reduce scan time by 50-80% for projects with many dependencies.

### 2. Skip Malware Scan for Quick Checks

```bash
# Development workflow - skip slow malware scan
./scripts/run-all-scans.sh --skip-malware .

# Full scan for release verification
./scripts/run-all-scans.sh .
```

**Impact**: Reduces scan time by 60-70%.

### 3. Run Targeted Scans

Instead of full suite, run only needed scanners:

```bash
# Quick PII check before commit
./scripts/check-pii.sh .

# Secrets check after adding config files
./scripts/check-secrets.sh src/config/

# Pre-release malware scan
./scripts/check-malware.sh .
```

### 4. Parallelize in CI/CD

Run independent scans in parallel:

```yaml
jobs:
  pii-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/check-pii.sh .

  secrets-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/check-secrets.sh .

  malware-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          sudo apt-get install -y clamav
          sudo freshclam
          ./scripts/check-malware.sh .
```

**Impact**: Total CI time equals longest single scan, not sum of all scans.

### 5. Optimize ClamAV

```bash
# Update database during off-hours
0 3 * * * /usr/bin/freshclam

# Use SSD storage for ClamAV database
# Move database to fast storage if on HDD
```

### 6. Use Incremental Scanning (Git-based)

For CI, scan only changed files:

```bash
# Get changed files
CHANGED=$(git diff --name-only HEAD~1)

# Create temp directory with only changed files
mkdir -p /tmp/scan-target
for f in $CHANGED; do
  cp --parents "$f" /tmp/scan-target/ 2>/dev/null || true
done

# Scan only changed files
./scripts/check-pii.sh /tmp/scan-target
./scripts/check-secrets.sh /tmp/scan-target
```

## Detection Quality Metrics

### False Positive Rates

Baseline rates on typical codebases:

| Scanner | False Positive Rate | Notes |
|---------|---------------------|-------|
| PII (IPv4) | 5-15% | Version numbers, OIDs |
| PII (Phone) | 1-5% | Formatted numbers |
| PII (SSN) | <1% | Very specific pattern |
| PII (Credit Card) | <1% | Luhn validation reduces FPs |
| Secrets (API Keys) | 5-10% | Base64 strings, hashes |
| Secrets (Passwords) | 10-20% | Common words in comments |

### Reducing False Positives

1. **Use allowlists** for known good matches:
   ```bash
   ./scripts/check-pii.sh -i .  # Interactive mode
   ```

2. **Configure exclusions** for documentation:
   ```
   # .pii-exclude
   docs/
   examples/
   *.md
   ```

3. **Review regularly** - allowlist entries may become stale

## Benchmarking Your Environment

Run this to establish your baseline:

```bash
#!/bin/bash
# benchmark.sh - Measure scan times

echo "Repository: $(basename $(pwd))"
echo "Files: $(find . -type f | wc -l)"
echo "Size: $(du -sh . | cut -f1)"
echo ""

time_scan() {
    local name="$1"
    local cmd="$2"
    echo -n "$name: "
    start=$(date +%s)
    eval "$cmd" > /dev/null 2>&1
    end=$(date +%s)
    echo "$((end - start)) seconds"
}

time_scan "PII Scan" "./scripts/check-pii.sh ."
time_scan "Secrets Scan" "./scripts/check-secrets.sh ."
time_scan "MAC Scan" "./scripts/check-mac-addresses.sh ."
time_scan "Malware Scan" "./scripts/check-malware.sh ."
time_scan "Full Suite" "./scripts/run-all-scans.sh -n ."
```

## Monitoring Scan Performance

### Track Over Time

Add to your CI pipeline:

```yaml
- name: Record scan metrics
  run: |
    echo "scan_duration_seconds $(cat .scans/*report*.txt | grep 'Elapsed:' | grep -oE '[0-9]+')" >> metrics.txt
    echo "files_scanned $(find . -type f | wc -l)" >> metrics.txt
    echo "findings_count $(grep -c 'REVIEW' .scans/*report*.txt || echo 0)" >> metrics.txt
```

### Alert on Regression

If scan time increases significantly (>50%), investigate:
- New large directories added
- Exclusions accidentally removed
- ClamAV database corruption
- Disk performance issues

## Hardware Recommendations

### Minimum Requirements

- **CPU**: 2 cores
- **RAM**: 4 GB (8 GB with malware scanning)
- **Disk**: SSD strongly recommended
- **OS**: macOS 10.15+, Ubuntu 20.04+, Windows 10+

### Recommended for Large Repositories

- **CPU**: 4+ cores
- **RAM**: 16 GB
- **Disk**: NVMe SSD
- **Network**: Fast connection for ClamAV updates

### CI/CD Runner Sizing

| Workload | GitHub Actions Runner | AWS EC2 |
|----------|----------------------|---------|
| Small repos | ubuntu-latest | t3.medium |
| Medium repos | ubuntu-latest | t3.large |
| Large repos | ubuntu-latest-4core | c5.xlarge |
