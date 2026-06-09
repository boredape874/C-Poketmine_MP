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

use pocketmine\network\mcpe\protocol\ClientboundPacket;
use pocketmine\player\Player;
use pocketmine\timings\Timings;
use function count;
use function spl_object_id;

final class NetworkBroadcastUtils{

	private function __construct(){
		//NOOP
	}

	/**
	 * @param Player[]            $recipients
	 * @param ClientboundPacket[] $packets
	 */
	public static function broadcastPackets(array $recipients, array $packets) : bool{
		if(count($packets) === 0){
			throw new \InvalidArgumentException("Cannot broadcast empty list of packets");
		}
		if(count($recipients) === 0){
			return false;
		}

		Timings::$broadcastPackets->startTiming();
		try{
			/** @var array<int, PacketBroadcaster> $uniqueBroadcasters */
			$uniqueBroadcasters = [];
			/** @var array<int, array<int, NetworkSession>> $broadcasterTargets */
			$broadcasterTargets = [];
			foreach($recipients as $player){
				if($player->isConnected()){
					$session = $player->getNetworkSession();
					$broadcaster = $session->getBroadcaster();
					$broadcasterId = spl_object_id($broadcaster);
					$uniqueBroadcasters[$broadcasterId] = $broadcaster;
					$broadcasterTargets[$broadcasterId][spl_object_id($session)] = $session;
				}
			}
			if(count($uniqueBroadcasters) === 0){
				return false;
			}

			foreach($uniqueBroadcasters as $broadcasterId => $broadcaster){
				$broadcaster->broadcastPackets($broadcasterTargets[$broadcasterId], $packets);
			}

			return true;
		}finally{
			Timings::$broadcastPackets->stopTiming();
		}
	}

	/**
	 * @param Player[] $recipients
	 * @phpstan-param \Closure(EntityEventBroadcaster, array<int, NetworkSession>) : void $callback
	 */
	public static function broadcastEntityEvent(array $recipients, \Closure $callback) : void{
		if(count($recipients) === 0){
			return;
		}

		$uniqueBroadcasters = [];
		$broadcasterTargets = [];

		foreach($recipients as $recipient){
			if($recipient->isConnected()){
				$session = $recipient->getNetworkSession();
				$broadcaster = $session->getEntityEventBroadcaster();
				$broadcasterId = spl_object_id($broadcaster);
				$uniqueBroadcasters[$broadcasterId] = $broadcaster;
				$broadcasterTargets[$broadcasterId][spl_object_id($session)] = $session;
			}
		}
		if(count($uniqueBroadcasters) === 0){
			return;
		}

		foreach($uniqueBroadcasters as $k => $broadcaster){
			$callback($broadcaster, $broadcasterTargets[$k]);
		}
	}
}
