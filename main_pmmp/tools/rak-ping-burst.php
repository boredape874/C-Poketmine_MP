<?php declare(strict_types=1);

namespace pocketmine\tools\rak_ping_burst;

use function array_sum;
use function count;
use function file_put_contents;
use function getopt;
use function intdiv;
use function is_array;
use function is_string;
use function json_encode;
use function max;
use function microtime;
use function min;
use function pack;
use function socket_clear_error;
use function socket_close;
use function socket_create;
use function socket_get_option;
use function socket_last_error;
use function socket_recvfrom;
use function socket_sendto;
use function socket_set_option;
use function socket_set_nonblock;
use function socket_strerror;
use function substr;
use function unpack;
use function usleep;
use const AF_INET;
use const JSON_PRETTY_PRINT;
use const JSON_THROW_ON_ERROR;
use const SOCK_DGRAM;
use const SOL_SOCKET;
use const SO_RCVBUF;
use const SO_SNDBUF;
use const SOL_UDP;

const RAKNET_MAGIC = "\x00\xff\xff\x00\xfe\xfe\xfe\xfe\xfd\xfd\xfd\xfd\x12\x34\x56\x78";

/**
 * @phpstan-param array<string, mixed> $data
 */
function writeJson(array $data) : void{
	file_put_contents('php://stdout', json_encode($data, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR) . "\n");
}

function encodeLong(int $value) : string{
	return pack('N2', intdiv($value, 0x100000000), $value & 0xffffffff);
}

function decodeLong(string $value) : int{
	$parts = unpack('Nhigh/Nlow', $value);
	if($parts === false){
		return 0;
	}
	return ((int) $parts['high'] * 0x100000000) + (int) $parts['low'];
}

/**
 * @param array<int|string, float> $sendTimes
 * @param float[]             $latencies
 */
function drainResponses(\Socket $socket, array &$sendTimes, array &$latencies, float $deadline, int $targetResponses) : void{
	while(microtime(true) < $deadline && count($latencies) < $targetResponses){
		$buffer = '';
		$from = '';
		$fromPort = 0;
		$bytes = @socket_recvfrom($socket, $buffer, 2048, 0, $from, $fromPort);
		if($bytes === false){
			socket_clear_error($socket);
			break;
		}
		if($bytes >= 25 && $buffer[0] === "\x1c" && substr($buffer, 17, 16) === RAKNET_MAGIC){
			$pingTime = decodeLong(substr($buffer, 1, 8));
			$key = (string) $pingTime;
			if(isset($sendTimes[$key])){
				$latencies[] = (microtime(true) - $sendTimes[$key]) * 1000;
				unset($sendTimes[$key]);
			}
		}
	}
}

$optsRaw = getopt('', ['host::', 'port::', 'count::', 'timeout-ms::', 'batch-size::', 'batch-delay-us::']);
$opts = is_array($optsRaw) ? $optsRaw : [];
$hostOpt = $opts['host'] ?? null;
$portOpt = $opts['port'] ?? null;
$countOpt = $opts['count'] ?? null;
$timeoutOpt = $opts['timeout-ms'] ?? null;
$batchSizeOpt = $opts['batch-size'] ?? null;
$batchDelayOpt = $opts['batch-delay-us'] ?? null;
$host = is_string($hostOpt) ? $hostOpt : '127.0.0.1';
$port = is_string($portOpt) ? (int) $portOpt : 19132;
$count = max(1, is_string($countOpt) ? (int) $countOpt : 64);
$timeoutMs = max(100, is_string($timeoutOpt) ? (int) $timeoutOpt : 1500);
$batchSize = max(1, is_string($batchSizeOpt) ? (int) $batchSizeOpt : $count);
$batchDelayUs = max(0, is_string($batchDelayOpt) ? (int) $batchDelayOpt : 0);

$socket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
if($socket === false){
	file_put_contents('php://stderr', socket_strerror(socket_last_error()) . "\n");
	exit(1);
}
socket_set_nonblock($socket);
socket_set_option($socket, SOL_SOCKET, SO_SNDBUF, 4 * 1024 * 1024);
socket_set_option($socket, SOL_SOCKET, SO_RCVBUF, 4 * 1024 * 1024);

/** @var array<int|string, float> $sendTimes */
$sendTimes = [];
$latencies = [];
$sent = 0;
$start = microtime(true);
for($i = 0; $i < $count; ++$i){
	$pingTime = ((int) ($start * 1_000_000)) + $i;
	$packet = "\x01" . encodeLong($pingTime) . RAKNET_MAGIC . encodeLong($pingTime ^ 0x5f3759df);
	$result = socket_sendto($socket, $packet, 33, 0, $host, $port);
	if($result !== false){
		$sendTimes[(string) $pingTime] = microtime(true);
		++$sent;
	}
	if((($i + 1) % $batchSize) === 0){
		drainResponses($socket, $sendTimes, $latencies, microtime(true) + 0.02, $sent);
		if($batchDelayUs > 0){
			usleep($batchDelayUs);
		}
	}
}

$deadline = microtime(true) + ($timeoutMs / 1000);
while(microtime(true) < $deadline && count($latencies) < $sent){
	$before = count($latencies);
	drainResponses($socket, $sendTimes, $latencies, $deadline, $sent);
	if(count($latencies) === $before){
		usleep(1000);
	}
}

$received = count($latencies);
$lost = $sent - $received;
$min = null;
$max = null;
foreach($latencies as $latency){
	$min = $min === null || $latency < $min ? $latency : $min;
	$max = $max === null || $latency > $max ? $latency : $max;
}
$avg = $received > 0 ? array_sum($latencies) / $received : null;
$sendBuffer = socket_get_option($socket, SOL_SOCKET, SO_SNDBUF);
$receiveBuffer = socket_get_option($socket, SOL_SOCKET, SO_RCVBUF);

socket_close($socket);

writeJson([
	'host' => $host,
	'port' => $port,
	'sent' => $sent,
	'received' => $received,
	'lost' => $lost,
	'loss_percent' => $sent > 0 ? ($lost / $sent) * 100 : 100,
	'latency_ms_min' => $min,
	'latency_ms_avg' => $avg,
	'latency_ms_max' => $max,
	'send_buffer' => $sendBuffer,
	'receive_buffer' => $receiveBuffer,
]);
