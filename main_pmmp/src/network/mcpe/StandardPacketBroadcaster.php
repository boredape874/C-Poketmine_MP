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
	public function __construct(
		private Server $server
	){}

	public function broadcastPackets(array $recipients, array $packets) : void{
		if(count($recipients) === 0){
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
				foreach($compressorTargets as $target){
					$target->queueCompressed($batch);
				}
			}else{
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
