<?php declare(strict_types=1);

if(!extension_loaded('pmmp_perf_ext')){
	fwrite(STDERR, "pmmp_perf_ext is not loaded\n");
	exit(2);
}

if(!function_exists('pmmp_perf_varint_prefix_length')){
	function pmmp_perf_varint_prefix_length(int $length) : int{ return 0; }
}
if(!function_exists('pmmp_perf_encode_packet_batch')){
	/**
	 * @param list<string> $packets
	 * @param list<int>|null $lengths
	 */
	function pmmp_perf_encode_packet_batch(array $packets, ?array $lengths = null) : string{ return ''; }
}
if(!function_exists('pmmp_perf_encode_packet_single')){
	function pmmp_perf_encode_packet_single(string $packet, int $length) : string{ return ''; }
}
if(!function_exists('pmmp_perf_encode_signed_varints')){
	/**
	 * @param list<int> $values
	 */
	function pmmp_perf_encode_signed_varints(array $values) : string{ return ''; }
}
if(!function_exists('pmmp_perf_encode_biome_palette')){
	/**
	 * @param list<int> $values
	 * @param array<int, string> $knownBiomeIds
	 */
	function pmmp_perf_encode_biome_palette(array $values, array $knownBiomeIds, int $fallbackBiomeId) : string{ return ''; }
}
if(!function_exists('pmmp_perf_encode_mapped_signed_varints')){
	/**
	 * @param list<int> $values
	 * @param array<int, int> $map
	 */
	function pmmp_perf_encode_mapped_signed_varints(array $values, array $map) : ?string{ return $values === [] || $map !== [] ? '' : null; }
}
if(!function_exists('pmmp_perf_pack_u32le')){
	/**
	 * @param list<int> $values
	 */
	function pmmp_perf_pack_u32le(array $values) : string{ return ''; }
}
if(!function_exists('pmmp_perf_unpack_u32le')){
	/**
	 * @return list<int>
	 */
	function pmmp_perf_unpack_u32le(string $data) : array{ return []; }
}
if(!function_exists('pmmp_perf_decode_packet_batch')){
	/**
	 * @return list<string>
	 */
	function pmmp_perf_decode_packet_batch(string $batch) : array{ return []; }
}
if(!function_exists('pmmp_perf_serialize_fast_paletted_array')){
	/**
	 * @param list<int> $palette
	 */
	function pmmp_perf_serialize_fast_paletted_array(int $bitsPerBlock, string $wordArray, array $palette) : string{ return ''; }
}
if(!function_exists('pmmp_perf_decode_packet_batch_callback')){
	/**
	 * @param \Closure(string, int): bool $callback
	 */
	function pmmp_perf_decode_packet_batch_callback(string $batch, \Closure $callback) : int{ return 0; }
}
if(!function_exists('pmmp_perf_bitset_or')){
	function pmmp_perf_bitset_or(string $a, string $b) : string{ return $a | $b; }
}
if(!function_exists('pmmp_perf_bitset_andnot')){
	function pmmp_perf_bitset_andnot(string $a, string $b) : string{ return $a & ~$b; }
}
if(!function_exists('pmmp_perf_bitset_count')){
	function pmmp_perf_bitset_count(string $bitset) : int{
		$count = 0;
		for($i = 0, $length = strlen($bitset); $i < $length; ++$i){
			$count += substr_count(decbin(ord($bitset[$i])), '1');
		}
		return $count;
	}
}
if(!function_exists('pmmp_perf_decode_packet_headers')){
	/**
	 * @return list<array{offset: int, length: int, packetId: int, idLength: int, frameLength: int}>
	 */
	function pmmp_perf_decode_packet_headers(string $batch) : array{ return []; }
}

$iterations = 5_000_000;
$lengths = [0, 1, 127, 128, 255, 300, 16_384, 2_097_151, 268_435_455];
$signedValues = [0, 1, 127, 128, 300, 4096, 8192, 16384, -1, -2];
$mappedSignedValues = [0, 1, 127, 128, 300, 4096, 8192, 16384];
$mappedSignedMap = [0 => 0, 1 => 1, 127 => 127, 128 => 128, 300 => 300, 4096 => 4096, 8192 => 8192, 16384 => 16384];
$biomeValues = [0, 1, 2, 3, 4, 5, 999, 42];
$knownBiomeIds = [0 => 'ocean', 1 => 'plains', 2 => 'desert', 3 => 'mountains', 4 => 'forest', 5 => 'taiga'];
$u32Values = [0, 1, 2, 127, 128, 255, 4096, 65535, 1048576, 268435455, 4294967295];
$u32Packed = pmmp_perf_pack_u32le($u32Values);
$fastPaletteValues = [0, 1, 2, 127, 128, 255, 4096, 65535, 1048576, 268435455, 4294967295, 7, 8, 9, 10, 11, 12, 13];
$fastPaletteWords = str_repeat("\x5a", 512);
$batchPackets = [
	str_repeat('a', 24),
	str_repeat('b', 64),
	str_repeat('c', 128),
	str_repeat('d', 512),
];
$batchPacketLengths = [24, 64, 128, 512];
$batch = pmmp_perf_encode_packet_batch($batchPackets);
$singlePacket = str_repeat('s', 160);
$singlePacketLength = strlen($singlePacket);
$bitsetA = str_repeat("\xaa", 4096);
$bitsetB = str_repeat("\x0f", 4096);
$expectedBitsetOr = $bitsetA | $bitsetB;
$expectedBitsetAndNot = $bitsetA & ~$bitsetB;
if(pmmp_perf_bitset_or($bitsetA, $bitsetB) !== $expectedBitsetOr){
	throw new \RuntimeException('pmmp_perf_bitset_or mismatch');
}
if(pmmp_perf_bitset_andnot($bitsetA, $bitsetB) !== $expectedBitsetAndNot){
	throw new \RuntimeException('pmmp_perf_bitset_andnot mismatch');
}
if(pmmp_perf_bitset_count("\xff\x00\x0f") !== 12){
	throw new \RuntimeException('pmmp_perf_bitset_count mismatch');
}
$headers = pmmp_perf_decode_packet_headers($batch);
if(count($headers) !== count($batchPackets) || $headers[0]['length'] !== strlen($batchPackets[0])){
	throw new \RuntimeException('pmmp_perf_decode_packet_headers mismatch');
}

$start = hrtime(true);
$nativeSum = 0;
for($i = 0; $i < $iterations; ++$i){
	$nativeSum += pmmp_perf_varint_prefix_length($lengths[$i % 9]);
}
$nativeElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$phpSum = 0;
for($i = 0; $i < $iterations; ++$i){
	$length = $lengths[$i % 9];
	$prefixLength = 1;
	while($length >= 128){
		$length >>= 7;
		++$prefixLength;
	}
	$phpSum += $prefixLength;
}
$phpElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$signedBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$signedBytes += strlen(pmmp_perf_encode_signed_varints($signedValues));
}
$signedElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$encodedBatchBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$encodedBatchBytes += strlen(pmmp_perf_encode_packet_batch($batchPackets));
}
$encodeBatchElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$encodedBatchWithLengthsBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$encodedBatchWithLengthsBytes += strlen(pmmp_perf_encode_packet_batch($batchPackets, $batchPacketLengths));
}
$encodeBatchWithLengthsElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$encodedSingleBatchBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$encodedSingleBatchBytes += strlen(pmmp_perf_encode_packet_single($singlePacket, $singlePacketLength));
}
$encodeSingleBatchElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$mappedSignedBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$mappedSignedBytes += strlen(pmmp_perf_encode_mapped_signed_varints($mappedSignedValues, $mappedSignedMap) ?? '');
}
$mappedSignedElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$mappedSignedPhpBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$mapped = [];
	foreach($mappedSignedValues as $value){
		$mapped[] = $mappedSignedMap[$value];
	}
	$mappedSignedPhpBytes += strlen(pmmp_perf_encode_signed_varints($mapped));
}
$mappedSignedPhpElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$biomePaletteBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$biomePaletteBytes += strlen(pmmp_perf_encode_biome_palette($biomeValues, $knownBiomeIds, 0));
}
$biomePaletteElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$u32PackBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$u32PackBytes += strlen(pmmp_perf_pack_u32le($u32Values));
}
$u32PackElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$u32PhpPackBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$u32PhpPackBytes += strlen(pack('L*', ...$u32Values));
}
$u32PhpPackElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$u32UnpackValues = 0;
for($i = 0; $i < $iterations; ++$i){
	$u32UnpackValues += count(pmmp_perf_unpack_u32le($u32Packed));
}
$u32UnpackElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$u32PhpUnpackValues = 0;
for($i = 0; $i < $iterations; ++$i){
	$u32PhpUnpacked = unpack('L*', $u32Packed);
	if($u32PhpUnpacked === false){
		throw new \RuntimeException('Failed to unpack u32 reference data');
	}
	$u32PhpUnpackValues += count($u32PhpUnpacked);
}
$u32PhpUnpackElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$fastPalettedArrayBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$fastPalettedArrayBytes += strlen(pmmp_perf_serialize_fast_paletted_array(4, $fastPaletteWords, $fastPaletteValues));
}
$fastPalettedArrayElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$fastPalettedArrayPhpBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$packedPalette = pack('L*', ...$fastPaletteValues);
	$fastPalettedArrayPhpBytes += strlen(chr(4) . $fastPaletteWords . pack('N', strlen($packedPalette)) . $packedPalette);
}
$fastPalettedArrayPhpElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$decodedPackets = 0;
for($i = 0; $i < $iterations; ++$i){
	$decodedPackets += count(pmmp_perf_decode_packet_batch($batch));
}
$decodeElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$callbackDecodedPackets = 0;
for($i = 0; $i < $iterations; ++$i){
	$callbackDecodedPackets += pmmp_perf_decode_packet_batch_callback($batch, static function(string $buffer, int $index) : bool{
		return true;
	});
}
$callbackDecodeElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$bitsetOrBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$bitsetOrBytes += strlen(pmmp_perf_bitset_or($bitsetA, $bitsetB));
}
$bitsetOrElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$bitsetAndNotBytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$bitsetAndNotBytes += strlen(pmmp_perf_bitset_andnot($bitsetA, $bitsetB));
}
$bitsetAndNotElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$bitsetCounts = 0;
for($i = 0; $i < $iterations; ++$i){
	$bitsetCounts += pmmp_perf_bitset_count($bitsetA);
}
$bitsetCountElapsed = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$decodedHeaderCount = 0;
for($i = 0; $i < $iterations; ++$i){
	$decodedHeaderCount += count(pmmp_perf_decode_packet_headers($batch));
}
$decodeHeadersElapsed = (hrtime(true) - $start) / 1_000_000_000;

echo json_encode([
	'iterations' => $iterations,
	'native_sum' => $nativeSum,
	'php_sum' => $phpSum,
	'native_calls_per_second' => $iterations / $nativeElapsed,
	'php_calls_per_second' => $iterations / $phpElapsed,
	'signed_varint_batches_per_second' => $iterations / $signedElapsed,
	'encode_packet_batches_per_second' => $iterations / $encodeBatchElapsed,
	'encode_packet_batches_with_lengths_per_second' => $iterations / $encodeBatchWithLengthsElapsed,
	'encode_packet_single_batches_per_second' => $iterations / $encodeSingleBatchElapsed,
	'mapped_signed_varint_batches_per_second' => $iterations / $mappedSignedElapsed,
	'mapped_signed_varint_php_map_batches_per_second' => $iterations / $mappedSignedPhpElapsed,
	'encode_biome_palettes_per_second' => $iterations / $biomePaletteElapsed,
	'u32le_pack_batches_per_second' => $iterations / $u32PackElapsed,
	'u32le_php_pack_batches_per_second' => $iterations / $u32PhpPackElapsed,
	'u32le_unpack_batches_per_second' => $iterations / $u32UnpackElapsed,
	'u32le_php_unpack_batches_per_second' => $iterations / $u32PhpUnpackElapsed,
	'fast_paletted_array_batches_per_second' => $iterations / $fastPalettedArrayElapsed,
	'fast_paletted_array_php_batches_per_second' => $iterations / $fastPalettedArrayPhpElapsed,
	'decode_packet_batches_per_second' => $iterations / $decodeElapsed,
	'decode_packets_per_second' => $decodedPackets / $decodeElapsed,
	'callback_decode_packet_batches_per_second' => $iterations / $callbackDecodeElapsed,
	'callback_decode_packets_per_second' => $callbackDecodedPackets / $callbackDecodeElapsed,
	'bitset_or_batches_per_second' => $iterations / $bitsetOrElapsed,
	'bitset_andnot_batches_per_second' => $iterations / $bitsetAndNotElapsed,
	'bitset_count_batches_per_second' => $iterations / $bitsetCountElapsed,
	'decode_packet_headers_batches_per_second' => $iterations / $decodeHeadersElapsed,
	'decode_packet_headers_per_second' => $decodedHeaderCount / $decodeHeadersElapsed,
	'signed_varint_bytes' => $signedBytes,
	'encoded_batch_bytes' => $encodedBatchBytes,
	'encoded_batch_with_lengths_bytes' => $encodedBatchWithLengthsBytes,
	'encoded_single_batch_bytes' => $encodedSingleBatchBytes,
	'mapped_signed_varint_bytes' => $mappedSignedBytes,
	'mapped_signed_varint_php_map_bytes' => $mappedSignedPhpBytes,
	'encoded_biome_palette_bytes' => $biomePaletteBytes,
	'u32le_pack_bytes' => $u32PackBytes,
	'u32le_php_pack_bytes' => $u32PhpPackBytes,
	'u32le_unpack_values' => $u32UnpackValues,
	'u32le_php_unpack_values' => $u32PhpUnpackValues,
	'fast_paletted_array_bytes' => $fastPalettedArrayBytes,
	'fast_paletted_array_php_bytes' => $fastPalettedArrayPhpBytes,
	'decoded_packets' => $decodedPackets,
	'callback_decoded_packets' => $callbackDecodedPackets,
	'bitset_or_bytes' => $bitsetOrBytes,
	'bitset_andnot_bytes' => $bitsetAndNotBytes,
	'bitset_counts' => $bitsetCounts,
	'decoded_packet_headers' => $decodedHeaderCount,
	'native_seconds' => $nativeElapsed,
	'php_seconds' => $phpElapsed,
	'signed_varint_seconds' => $signedElapsed,
	'encode_batch_seconds' => $encodeBatchElapsed,
	'encode_batch_with_lengths_seconds' => $encodeBatchWithLengthsElapsed,
	'encode_single_batch_seconds' => $encodeSingleBatchElapsed,
	'mapped_signed_varint_seconds' => $mappedSignedElapsed,
	'mapped_signed_varint_php_map_seconds' => $mappedSignedPhpElapsed,
	'encode_biome_palette_seconds' => $biomePaletteElapsed,
	'u32le_pack_seconds' => $u32PackElapsed,
	'u32le_php_pack_seconds' => $u32PhpPackElapsed,
	'u32le_unpack_seconds' => $u32UnpackElapsed,
	'u32le_php_unpack_seconds' => $u32PhpUnpackElapsed,
	'fast_paletted_array_seconds' => $fastPalettedArrayElapsed,
	'fast_paletted_array_php_seconds' => $fastPalettedArrayPhpElapsed,
	'decode_seconds' => $decodeElapsed,
	'callback_decode_seconds' => $callbackDecodeElapsed,
	'bitset_or_seconds' => $bitsetOrElapsed,
	'bitset_andnot_seconds' => $bitsetAndNotElapsed,
	'bitset_count_seconds' => $bitsetCountElapsed,
	'decode_headers_seconds' => $decodeHeadersElapsed,
], JSON_PRETTY_PRINT) . "\n";
