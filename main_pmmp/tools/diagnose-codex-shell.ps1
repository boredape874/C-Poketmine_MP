param(
    [switch]$NoExitCode
)

$ErrorActionPreference = "Stop"

$checks = New-Object System.Collections.Generic.List[object]
$ok = $true

function Add-Check([string]$Name, [scriptblock]$Script){
    $started = Get-Date
    try{
        $global:LASTEXITCODE = $null
        $output = & $Script 2>&1
        $exitCode = $LASTEXITCODE
        $checkOk = $exitCode -eq 0 -or $exitCode -eq $null
        if(-not $checkOk){
            $script:ok = $false
        }
        $checks.Add([pscustomobject]@{
            name = $Name
            ok = $checkOk
            exit_code = $exitCode
            elapsed_ms = [int]((Get-Date) - $started).TotalMilliseconds
            output = ($output | Out-String).Trim()
        }) | Out-Null
    }catch{
        $script:ok = $false
        $checks.Add([pscustomobject]@{
            name = $Name
            ok = $false
            exit_code = $LASTEXITCODE
            elapsed_ms = [int]((Get-Date) - $started).TotalMilliseconds
            output = $_.Exception.Message
        }) | Out-Null
    }
}

$phpPath = Join-Path $PSScriptRoot "..\bin\php\php.exe"

Add-Check "powershell-location" { powershell -NoProfile -Command "Get-Location" }
Add-Check "cmd-cd" { cmd /c cd }
Add-Check "php-runtime-exists" { Test-Path -LiteralPath $phpPath }
Add-Check "php-version" { & $phpPath -v }
Add-Check "git-version" { git --version }
Add-Check "rg-version" { rg --version }
Add-Check "repo-write-test" {
    $path = Join-Path (Get-Location).Path ".codex-shell-write-test.tmp"
    Set-Content -LiteralPath $path -Value "ok" -NoNewline
    Remove-Item -LiteralPath $path -Force
    "ok"
}

[pscustomobject]@{
    generated_at = (Get-Date).ToString("o")
    cwd = (Get-Location).Path
    user = [Environment]::UserName
    machine = [Environment]::MachineName
    ok = $ok
    checks = $checks
} | ConvertTo-Json -Depth 6

if(-not $ok -and -not $NoExitCode){
    exit 7
}
