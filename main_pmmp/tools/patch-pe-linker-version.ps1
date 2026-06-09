param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [byte]$Major = 14,
    [byte]$Minor = 29
)

$ErrorActionPreference = "Stop"

$resolved = Resolve-Path $Path
$bytes = [System.IO.File]::ReadAllBytes($resolved.Path)
if($bytes.Length -lt 0x100){
    throw "File is too small to be a PE image: $($resolved.Path)"
}

$peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
if($peOffset -lt 0 -or $peOffset + 0x1a -ge $bytes.Length){
    throw "Invalid PE header offset: $peOffset"
}

if($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or $bytes[$peOffset + 2] -ne 0 -or $bytes[$peOffset + 3] -ne 0){
    throw "Missing PE signature: $($resolved.Path)"
}

$optionalHeaderOffset = $peOffset + 4 + 20
$oldMajor = $bytes[$optionalHeaderOffset + 2]
$oldMinor = $bytes[$optionalHeaderOffset + 3]
$bytes[$optionalHeaderOffset + 2] = $Major
$bytes[$optionalHeaderOffset + 3] = $Minor
[System.IO.File]::WriteAllBytes($resolved.Path, $bytes)

[pscustomobject]@{
    path = $resolved.Path
    old_linker_version = "$oldMajor.$oldMinor"
    new_linker_version = "$Major.$Minor"
} | ConvertTo-Json -Depth 3
