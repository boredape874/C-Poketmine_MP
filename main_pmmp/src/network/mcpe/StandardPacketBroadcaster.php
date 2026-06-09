<?php

/*
 *
 *  ____            _        _   __  __ _                  __  __ ____
 * |  _ \ ___   ___| | _____| |_|  \/  (_)_ __   ___      |  \/  |  _ \
 * | |_) / _ \ / __| |/ / _ \ __| |\/| | | '_ \ / _ \_____| |\/| | |_) |
 * |  __/ (_) | (__|   <  __/ |_| |  | | | | | |  __/_____| |  | |  __/
 * |_|   \___/ \___|_|\_\___|\__|_|  |_|_|_| |_|\___|     |_|  |_|_|
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * @author PocketMine Team
 * @link http://www.pocketmine.net/
 *
 *
 */

declare(strict_types=1);

namespace pocketmine\network\mcpe;

use pmmp\encoding\ByteBufferWriter;
use pocketmine\event\server\DataPacketSendEvent;
use pocketmine\network\mcpe\protocol\serializer\PacketBatch;
use pocketmine\Server;
use pocketmine\timings\Timings;
use function count;
use function spl_object_id;
use function strlen;

final class StandardPacketBroadcaster implements PacketBroadcaster{
	private static int $broadcastCalls = 0;
	private static int $broadcastRecipients = 0;
	private static int $broadcastPackets = 0;
	private static int $encodedPackets = 0;
	private static int $encodedPacketBytes = 0;
	private static int $duplicateSerializationWork = 0;
	private static int $sharedCompressedBatches = 0;
	private static int $sharedCompressedRecipients = 0;
	private static int $directBufferedPackets = 0;
	private static int $directBufferedRecipients = 0;

	public function __construct(
		private Server $server
	){}

	public static function recordBroadcast(int $recipients, int $packets) : void{
		++self::$broadcastCalls;
		self::$broadcastRecipients += $recipients;
		self::$broadcastPackets += $packets;
		self::$duplicateSerializationWork += $recipients > 1 ? $packets * ($recipients - 1) : 0;
	}

	public static function recordEncodedPacket(int $bytes) : void{
		++self::$encodedPackets;
		self::$encodedPacketBytes += $bytes;
	}

	public static function recordSharedCompressedBatch(int $recipients) : void{
		++self::$sharedCompressedBatches;
		self::$sharedCompressedRecipients += $recipients;
	}

	public static function recordDirectBufferedPackets(int $recipients, int $packets) : void{
		self::$directBufferedRecipients += $recipients;
		self::$directBufferedPackets += $packets;
	}

	public static function getPerformanceMetrics() : array{
		return [
			'broadcast_calls' => self::$broadcastCalls,
			'broadcast_recipients' => self::$broadcastRecipients,
			'broadcast_packets' => self::$broadcastPackets,
			'encoded_packets' => self::$encodedPackets,
			'encoded_packet_bytes' => self::$encodedPacketBytes,
			'duplicate_serialization_work' => self::$duplicateSerializationWork,
			'shared_compressed_batches' => self::$sharedCompressedBatches,
			'shared_compressed_recipients' => self::$sharedCompressedRecipients,
			'direct_buffered_packets' => self::$directBufferedPackets,
			'direct_buffered_recipients' => self::$directBufferedRecipients,
		];
	}

	public static function resetPerformanceMetrics() : void{
		self::$broadcastCalls = 0;
		self::$broadcastRecipients = 0;
		self::$broadcastPackets = 0;
		self::$encodedPackets = 0;
		self::$encodedPacketBytes = 0;
		self::$duplicateSerializationWork = 0;
		self::$sharedCompressedBatches = 0;
		self::$sharedCompressedRecipients = 0;
		self::$directBufferedPackets = 0;
		self::$directBufferedRecipients = 0;
	}

	public function broadcastPackets(array $recipients, array $packets) : void{
		$recipientCount = count($recipients);
		if($recipientCount === 0){
			return;
		}

		//TODO: this shouldn't really be called here, since the broadcaster might be replaced by an alternative
		//implementation that doesn't fire events
		if(DataPacketSendEvent::hasHandlers()){
			$ev = new DataPacketSendEvent($recipients, $packets);
			$ev->call();
			if($ev->isCancelled()){
				return;
			}
			$packets = $ev->getPackets();
			if(count($packets) === 0){
				return;
			}
		}

		$packetCount = count($packets);
		self::recordBroadcast($recipientCount, $packetCount);

		$compressors = [];

		$targetsByCompressor = [];
		foreach($recipients as $recipient){
			//TODO: different compressors might be compatible, it might not be necessary to split them up by object
			$compressor = $recipient->getCompressor();
			$compressorId = spl_object_id($compressor);
			$compressors[$compressorId] = $compressor;

			$targetsByCompressor[$compressorId][] = $recipient;
		}

		$totalLength = 0;
		$packetBuffers = [];
		$packetLengths = [];
		$writer = new ByteBufferWriter();
		foreach($packets as $packet){
			$writer->clear(); //memory reuse let's gooooo
			$buffer = NetworkSession::encodePacketTimed($writer, $packet);
			$length = strlen($buffer);
			$lengthPrefixLength = 1;
			for($remaining = $length; $remaining >= 128; $remaining >>= 7){
				++$lengthPrefixLength;
			}
			self::recordEncodedPacket($length);
			//varint length prefix + packet buffer
			$totalLength += $lengthPrefixLength + $length;
			$packetBuffers[] = $buffer;
			$packetLengths[] = $length;
		}

		foreach($targetsByCompressor as $compressorId => $compressorTargets){
			$compressor = $compressors[$compressorId];

			$threshold = $compressor->getCompressionThreshold();
			if(count($compressorTargets) > 1 && $threshold !== null && $totalLength >= $threshold){
				//do not prepare shared batch unless we're sure it will be compressed
				$stream = new ByteBufferWriter();
				PacketBatch::encodeRawWithLengths($stream, $packetBuffers, $packetLengths);
				$batchBuffer = $stream->getData();

				$batch = $this->server->prepareBatch($batchBuffer, $compressor, timings: Timings::$playerNetworkSendCompressBroadcast);
				self::recordSharedCompressedBatch(count($compressorTargets));
				foreach($compressorTargets as $target){
					$target->queueCompressed($batch);
				}
			}else{
				self::recordDirectBufferedPackets(count($compressorTargets), count($packetBuffers));
				if(count($packetBuffers) === 1){
					$packetBuffer = $packetBuffers[0];
					foreach($compressorTargets as $target){
						$target->addToSendBuffer($packetBuffer);
					}
				}else{
					foreach($compressorTargets as $target){
						foreach($packetBuffers as $packetBuffer){
							$target->addToSendBuffer($packetBuffer);
						}
					}
				}
			}
		}
	}
}
