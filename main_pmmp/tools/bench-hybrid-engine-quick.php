<?php declare(strict_types=1);

if(!extension_loaded('pmmp_perf_ext')){
	fwrite(STDERR, "pmmp_perf_ext is not loaded\n");
	exit(2);
}

$iterations = (int) ($argv[1] ?? 100000);
$bitsetA = str_repeat("\xaa", 4096);
$bitsetB = str_repeat("\x0f", 4096);
$packets = [
	str_repeat("\x01a", 24),
	str_repeat("\x02b", 64),
	str_repeat("\x03c", 128),
	str_repeat("\x04d", 512),
];
$batch = pmmp_perf_encode_packet_batch($packets);

if(pmmp_perf_bitset_count("\xff\x00\x0f") !== 12){
	throw new RuntimeException('bitset count mismatch');
}
if(pmmp_perf_bitset_or($bitsetA, $bitsetB) !== ($bitsetA | $bitsetB)){
	throw new RuntimeException('bitset or mismatch');
}
if(pmmp_perf_bitset_andnot($bitsetA, $bitsetB) !== ($bitsetA & ~$bitsetB)){
	throw new RuntimeException('bitset andnot mismatch');
}
$headers = pmmp_perf_decode_packet_headers($batch);
if(count($headers) !== count($packets) || $headers[0]['length'] !== strlen($packets[0])){
	throw new RuntimeException('packet header index mismatch');
}

$start = hrtime(true);
$bytes = 0;
for($i = 0; $i < $iterations; ++$i){
	$bytes += strlen(pmmp_perf_bitset_or($bitsetA, $bitsetB));
}
$bitsetOrSeconds = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$counts = 0;
for($i = 0; $i < $iterations; ++$i){
	$counts += pmmp_perf_bitset_count($bitsetA);
}
$bitsetCountSeconds = (hrtime(true) - $start) / 1_000_000_000;

$start = hrtime(true);
$decodedHeaders = 0;
for($i = 0; $i < $iterations; ++$i){
	$decodedHeaders += count(pmmp_perf_decode_packet_headers($batch));
}
$headersSeconds = (hrtime(true) - $start) / 1_000_000_000;

echo json_encode([
	'iterations' => $iterations,
	'bitset_or_batches_per_second' => $iterations / $bitsetOrSeconds,
	'bitset_or_bytes_per_second' => $bytes / $bitsetOrSeconds,
	'bitset_count_batches_per_second' => $iterations / $bitsetCountSeconds,
	'packet_header_index_batches_per_second' => $iterations / $headersSeconds,
	'packet_header_index_packets_per_second' => $decodedHeaders / $headersSeconds,
	'bitset_or_seconds' => $bitsetOrSeconds,
	'bitset_count_seconds' => $bitsetCountSeconds,
	'packet_header_index_seconds' => $headersSeconds,
	'bitset_count_sum' => $counts,
	'decoded_headers' => $decodedHeaders,
], JSON_PRETTY_PRINT) . "\n";
