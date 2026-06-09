param(
    [string]$DllPath = "var/native-build/php_pmmp_perf_ext.dll",
    [switch]$NoPhpIni
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$php = Join-Path $root "bin/php/php.exe"
$dll = Resolve-Path (Join-Path $root $DllPath)
$tempScript = Join-Path $root "var/native-build/test-native-extension.php"

$code = @'
$ok = extension_loaded("pmmp_perf_ext");
$info = $ok ? pmmp_perf_build_info() : [];
$length = $ok ? pmmp_perf_varint_prefix_length(300) : -1;
$batch = $ok ? bin2hex(pmmp_perf_encode_packet_batch(["abc", "de"], [3, 2])) : "";
$singleBatch = $ok && function_exists("pmmp_perf_encode_packet_single") ? bin2hex(pmmp_perf_encode_packet_single("abc", 3)) : "";
$decodedBatch = $ok ? array_map("bin2hex", pmmp_perf_decode_packet_batch(pmmp_perf_encode_packet_batch(["abc", "de"], [3, 2]))) : [];
$callbackDecodedBatch = [];
if($ok && function_exists("pmmp_perf_decode_packet_batch_callback")){
    pmmp_perf_decode_packet_batch_callback(pmmp_perf_encode_packet_batch(["abc", "de"], [3, 2]), static function(string $buffer, int $index) use (&$callbackDecodedBatch) : bool{
        $callbackDecodedBatch[$index] = bin2hex($buffer);
        return true;
    });
}
$signedVarints = $ok ? bin2hex(pmmp_perf_encode_signed_varints([0, 1, 127, 128, 300, -1])) : "";
$mappedSignedVarints = $ok && function_exists("pmmp_perf_encode_mapped_signed_varints") ? bin2hex(pmmp_perf_encode_mapped_signed_varints([1, 3], [1 => 2, 3 => 4])) : "";
$mappedSignedVarintsMissing = $ok && function_exists("pmmp_perf_encode_mapped_signed_varints") ? pmmp_perf_encode_mapped_signed_varints([1, 9], [1 => 2, 3 => 4]) : false;
$biomePalette = $ok && function_exists("pmmp_perf_encode_biome_palette") ? bin2hex(pmmp_perf_encode_biome_palette([0, 1, 999], [0 => "ocean", 1 => "plains"], 0)) : "";
$u32le = $ok && function_exists("pmmp_perf_pack_u32le") ? bin2hex(pmmp_perf_pack_u32le([0, 1, 255, 65535, 4294967295])) : "";
$u32leUnpacked = $ok && function_exists("pmmp_perf_unpack_u32le") ? pmmp_perf_unpack_u32le(hex2bin($u32le)) : [];
$fastPalettedArray = $ok && function_exists("pmmp_perf_serialize_fast_paletted_array") ? bin2hex(pmmp_perf_serialize_fast_paletted_array(3, "\x01\x02", [0, 1, 255])) : "";
$fastPalettedArrayReadFixture = $ok && function_exists("pmmp_perf_serialize_fast_paletted_array") ? pmmp_perf_serialize_fast_paletted_array(0, "", [255]) : "";
$fastPalettedArrayRead = $ok && function_exists("pmmp_perf_read_fast_paletted_array") ? pmmp_perf_read_fast_paletted_array($fastPalettedArrayReadFixture, 0) : [];
echo json_encode([
    "loaded" => $ok,
    "info" => $info,
    "varint_prefix_length_300" => $length,
    "batch_hex" => $batch,
    "single_batch_hex" => $singleBatch,
    "decoded_batch_hex" => $decodedBatch,
    "callback_decoded_batch_hex" => $callbackDecodedBatch,
    "signed_varints_hex" => $signedVarints,
    "mapped_signed_varints_hex" => $mappedSignedVarints,
    "mapped_signed_varints_missing_is_null" => $mappedSignedVarintsMissing === null,
    "biome_palette_hex" => $biomePalette,
    "u32le_hex" => $u32le,
    "u32le_unpacked" => $u32leUnpacked,
    "fast_paletted_array_hex" => $fastPalettedArray,
    "fast_paletted_array_read_fixture_hex" => bin2hex($fastPalettedArrayReadFixture),
    "fast_paletted_array_read" => [
        "bits_per_block" => $fastPalettedArrayRead[0] ?? null,
        "word_array_hex" => isset($fastPalettedArrayRead[1]) ? bin2hex($fastPalettedArrayRead[1]) : null,
        "palette" => $fastPalettedArrayRead[2] ?? null,
        "offset" => $fastPalettedArrayRead[3] ?? null,
    ],
], JSON_PRETTY_PRINT);
'@

Set-Content -LiteralPath $tempScript -Value "<?php`n$code" -Encoding ASCII
$defaultLoaded = -not $NoPhpIni -and (& $php -r "echo extension_loaded('pmmp_perf_ext') ? '1' : '0';") -eq "1"
if($defaultLoaded){
    & $php $tempScript
}elseif($NoPhpIni){
    & $php -n -d "extension=$($dll.Path)" $tempScript
}else{
    & $php -d "extension=$($dll.Path)" $tempScript
}
if($LASTEXITCODE -ne 0){
    exit $LASTEXITCODE
}
