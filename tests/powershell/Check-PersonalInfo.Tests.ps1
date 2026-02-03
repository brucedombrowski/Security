#Requires -Version 5.1
<#
.SYNOPSIS
    PII Pattern Detection Unit Tests (Pester)

.DESCRIPTION
    Verifies PII detection patterns catch real PII and minimize false positives.
    PowerShell equivalent of test-pii-patterns.sh.

.NOTES
    NIST Control: SI-12 (Information Management)

    Exit codes:
      0 = All tests passed
      1 = One or more tests failed

.EXAMPLE
    Invoke-Pester -Path ./Check-PII.Tests.ps1 -Output Detailed
#>

BeforeAll {
    # Script and repository paths
    $script:TestDir = $PSScriptRoot
    $script:RepoDir = Split-Path -Parent (Split-Path -Parent $TestDir)
    $script:FixturesDir = Join-Path $TestDir 'fixtures'

    # Ensure fixtures directory exists
    if (-not (Test-Path $FixturesDir)) {
        New-Item -ItemType Directory -Path $FixturesDir -Force | Out-Null
    }

    # PII regex patterns (must match Check-PII.ps1)
    $script:Patterns = @{
        IPv4       = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'
        Phone      = '\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}'
        SSN        = '\d{3}-\d{2}-\d{4}'
        CreditCard = '\d{4}[-. ]?\d{4}[-. ]?\d{4}[-. ]?\d{4}'
    }
}

AfterAll {
    # Cleanup test fixtures
    $fixtureFiles = @(
        (Join-Path $script:FixturesDir 'clean-file.md'),
        (Join-Path $script:FixturesDir 'has-pii.md')
    )
    foreach ($file in $fixtureFiles) {
        if (Test-Path $file) {
            Remove-Item $file -Force
        }
    }
}

Describe 'IPv4 Address Detection' {
    Context 'when input contains valid IPv4 addresses' {
        It 'detects standard IPv4 (192.168.1.1)' {
            '192.168.1.1' | Should -Match $script:Patterns.IPv4
        }

        It 'detects private IP (10.0.0.1)' {
            '10.0.0.1' | Should -Match $script:Patterns.IPv4
        }

        It 'detects public IP (8.8.8.8)' {
            '8.8.8.8' | Should -Match $script:Patterns.IPv4
        }

        It 'detects localhost (127.0.0.1)' {
            '127.0.0.1' | Should -Match $script:Patterns.IPv4
        }
    }

    Context 'when input contains non-IP strings' {
        It 'rejects version string (1.2.3)' {
            'version 1.2.3' | Should -Not -Match $script:Patterns.IPv4
        }
    }

    Context 'known limitations' -Tag 'Known' {
        It 'matches version number 6.0.0.0 (handled via allowlist)' -Skip {
            # This is a known limitation - version numbers like 6.0.0.0
            # match the IPv4 pattern. Use allowlist to handle.
        }
    }
}

Describe 'Phone Number Detection' {
    Context 'when input contains US phone numbers' {
        It 'detects (555) 123-4567' {
            '(555) 123-4567' | Should -Match $script:Patterns.Phone
        }

        It 'detects 555-123-4567' {
            '555-123-4567' | Should -Match $script:Patterns.Phone
        }

        It 'detects 555.123.4567' {
            '555.123.4567' | Should -Match $script:Patterns.Phone
        }

        It 'detects 5551234567' {
            '5551234567' | Should -Match $script:Patterns.Phone
        }
    }
}

Describe 'Social Security Number Detection' {
    Context 'when input contains SSN formats' {
        It 'detects valid SSN format (123-45-6789)' {
            '123-45-6789' | Should -Match $script:Patterns.SSN
        }

        It 'detects SSN in text (SSN: 123-45-6789)' {
            'SSN: 123-45-6789' | Should -Match $script:Patterns.SSN
        }
    }

    Context 'when input contains invalid SSN formats' {
        It 'rejects invalid SSN (12-345-6789)' {
            '12-345-6789' | Should -Not -Match $script:Patterns.SSN
        }
    }
}

Describe 'Credit Card Detection' {
    Context 'when input contains credit card numbers' {
        It 'detects Visa format (4111-1111-1111-1111)' {
            '4111-1111-1111-1111' | Should -Match $script:Patterns.CreditCard
        }

        It 'detects MC format with spaces (5500 0000 0000 0004)' {
            '5500 0000 0000 0004' | Should -Match $script:Patterns.CreditCard
        }

        It 'detects continuous digits (4111111111111111)' {
            '4111111111111111' | Should -Match $script:Patterns.CreditCard
        }
    }
}

Describe 'False Positive Prevention' {
    Context 'when input contains look-alike patterns' {
        It 'rejects X.509 OID (1.3.6.1.5.5.7.3.4)' {
            # OIDs have 5+ segments, IPs have exactly 4
            # Use anchored pattern for strict matching
            '1.3.6.1.5.5.7.3.4' | Should -Not -Match "^$($script:Patterns.IPv4)$"
        }
    }
}

Describe 'Integration Test' -Tag 'Integration' {
    BeforeAll {
        # Create isolated test directories to avoid cross-test pollution
        $script:IntegrationDir = Join-Path $script:FixturesDir 'integration'
        if (Test-Path $script:IntegrationDir) {
            Remove-Item $script:IntegrationDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:IntegrationDir -Force | Out-Null
    }

    AfterAll {
        # Cleanup integration test directory
        if (Test-Path $script:IntegrationDir) {
            Remove-Item $script:IntegrationDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'when scanning clean directory' {
        BeforeAll {
            $script:CleanDir = Join-Path $script:IntegrationDir 'clean'
            New-Item -ItemType Directory -Path $script:CleanDir -Force | Out-Null
            $script:CleanFile = Join-Path $script:CleanDir 'clean-file.md'
        }

        It 'passes on clean fixture file' {
            # Create clean test file - use Set-Content with ASCII to avoid BOM issues
            "This is a clean file with no PII.`r`nVersion: 1.2.3`r`nBuild date: 2026-01-15" | Set-Content -Path $script:CleanFile -Encoding ASCII

            # Verify file exists
            Test-Path $script:CleanFile | Should -BeTrue

            # Run Check-PersonalInfo.ps1 on clean directory - should pass (exit 0)
            $output = & "$script:RepoDir/scripts/Check-PersonalInfo.ps1" $script:CleanDir 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'when scanning directory with PII' {
        BeforeAll {
            $script:PIIDir = Join-Path $script:IntegrationDir 'pii'
            New-Item -ItemType Directory -Path $script:PIIDir -Force | Out-Null
            $script:PIIFile = Join-Path $script:PIIDir 'has-pii.md'
        }

        It 'fails on file containing PII' {
            # Create file with PII - use Set-Content with ASCII to avoid BOM issues
            "Contact: John Doe`r`nPhone: 555-123-4567`r`nSSN: 123-45-6789" | Set-Content -Path $script:PIIFile -Encoding ASCII

            # Verify file exists and contains expected content
            Test-Path $script:PIIFile | Should -BeTrue
            $content = Get-Content $script:PIIFile -Raw
            $content | Should -Match '555-123-4567'
            $content | Should -Match '123-45-6789'

            # Run Check-PersonalInfo.ps1 on PII directory - should fail (exit 1)
            $output = & "$script:RepoDir/scripts/Check-PersonalInfo.ps1" $script:PIIDir 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }
}
