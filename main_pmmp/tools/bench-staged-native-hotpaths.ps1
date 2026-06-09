param(
    [int]$Iterations = 300,
    [string]$DllPath = "var/native-build/php_pmmp_perf_ext.dll",
    [switch]$Raw
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$rootPath = $root.Path
$php = Join-Path $rootPath "bin/php/php.exe"
$extDir = Join-Path $rootPath "bin/php/ext"
$dll = if([System.IO.Path]::IsPathRooted($DllPath)){
    (Resolve-Path $DllPath).Path
}else{
    (Resolve-Path (Join-Path $rootPath $DllPath)).Path
}
$bench = Join-Path $rootPath "tools/bench-hotpaths.php"

$phpArgs = @(
    "-n",
    "-d", "extension_dir=$extDir",
    "-d", "extension=php_pmmpthread.dll",
    "-d", "extension=php_openssl.dll",
    "-d", "extension=php_chunkutils2.dll",
    "-d", "extension=php_igbinary.dll",
    "-d", "extension=php_leveldb.dll",
    "-d", "extension=php_crypto.dll",
    "-d", "extension=php_libdeflate.dll",
    "-d", "extension=php_encoding.dll",
    "-d", "extension=$dll",
    $bench,
    "--iterations=$Iterations"
)

$output = & $php @phpArgs
if($LASTEXITCODE -ne 0){
    exit $LASTEXITCODE
}

if($Raw){
    $output
    exit 0
}

$result = $output | ConvertFrom-Json
[pscustomobject]@{
    root = $rootPath
    staged_dll = $dll
    staged_sha256 = (Get-FileHash -LiteralPath $dll -Algorithm SHA256).Hash
    iterations = $Iterations
    native_loaded = [bool]$result.packet_batch_raw.native_extension_loaded
    packet_batch_raw = $result.packet_batch_raw
    packet_encoding = $result.packet_encoding
    packet_decoding = $result.packet_decoding
    subchunk_serialization = $result.subchunk_serialization
    full_chunk_serialization = $result.full_chunk_serialization
    fast_chunk_serializer = $result.fast_chunk_serializer
} | ConvertTo-Json -Depth 8
