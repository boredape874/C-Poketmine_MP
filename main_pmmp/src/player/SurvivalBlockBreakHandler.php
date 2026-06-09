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

namespace pocketmine\player;

use pocketmine\block\Block;
use pocketmine\entity\animation\ArmSwingAnimation;
use pocketmine\entity\effect\VanillaEffects;
use pocketmine\item\enchantment\VanillaEnchantments;
use pocketmine\math\Facing;
use pocketmine\math\Vector3;
use pocketmine\network\mcpe\protocol\LevelEventPacket;
use pocketmine\network\mcpe\protocol\types\LevelEvent;
use pocketmine\world\particle\BlockPunchParticle;
use pocketmine\world\sound\BlockPunchSound;
use function abs;

final class SurvivalBlockBreakHandler{

	public const DEFAULT_FX_INTERVAL_TICKS = 5;

	private int $fxTicker = 0;
	private float $breakSpeed;
	private float $breakProgress = 0;
	private float $blockCenterX;
	private float $blockCenterY;
	private float $blockCenterZ;
	private float $maxPlayerDistanceSquared;

	public function __construct(
		private Player $player,
		private Vector3 $blockPos,
		private Block $block,
		private int $targetedFace,
		int $maxPlayerDistance,
		private int $fxTickInterval = self::DEFAULT_FX_INTERVAL_TICKS
	){
		$this->blockCenterX = $blockPos->x + 0.5;
		$this->blockCenterY = $blockPos->y + 0.5;
		$this->blockCenterZ = $blockPos->z + 0.5;
		$this->maxPlayerDistanceSquared = $maxPlayerDistance * $maxPlayerDistance;
		$this->breakSpeed = $this->calculateBreakProgressPerTick();
		if($this->breakSpeed > 0){
			$player = $this->player;
			$world = $player->getWorld();
			$world->broadcastPacketToViewers(
				$this->blockPos,
				LevelEventPacket::create(LevelEvent::BLOCK_START_BREAK, (int) (65535 * $this->breakSpeed), $this->blockPos)
			);
		}
	}

	/**
	 * Returns the calculated break speed as percentage progress per game tick.
	 */
	private function calculateBreakProgressPerTick() : float{
		if(!$this->block->getBreakInfo()->isBreakable()){
			return 0.0;
		}
		$player = $this->player;
		$breakTimePerTick = $this->block->getBreakInfo()->getBreakTime($player->getInventory()->getItemInHand()) * 20;
		if(!$player->isOnGround() && !$player->isFlying()){
			$breakTimePerTick *= 5;
		}
		if($player->isUnderwater() && !$player->getArmorInventory()->getHelmet()->hasEnchantment(VanillaEnchantments::AQUA_AFFINITY())){
			$breakTimePerTick *= 5;
		}
		if($breakTimePerTick > 0){
			$progressPerTick = 1 / $breakTimePerTick;

			$haste = $player->getEffects()->get(VanillaEffects::HASTE());
			if($haste !== null){
				$hasteLevel = $haste->getEffectLevel();
				$progressPerTick *= (1 + 0.2 * $hasteLevel) * (1.2 ** $hasteLevel);
			}

			$miningFatigue = $player->getEffects()->get(VanillaEffects::MINING_FATIGUE());
			if($miningFatigue !== null){
				$miningFatigueLevel = $miningFatigue->getEffectLevel();
				$progressPerTick *= 0.21 ** $miningFatigueLevel;
			}

			return $progressPerTick;
		}
		return 1;
	}

	public function update() : bool{
		$player = $this->player;
		$position = $player->getPosition();
		$dx = $position->x - $this->blockCenterX;
		$dy = $position->y - $this->blockCenterY;
		$dz = $position->z - $this->blockCenterZ;
		if(($dx * $dx + $dy * $dy + $dz * $dz) > $this->maxPlayerDistanceSquared){
			return false;
		}

		$newBreakSpeed = $this->calculateBreakProgressPerTick();
		if(abs($newBreakSpeed - $this->breakSpeed) > 0.0001){
			$this->breakSpeed = $newBreakSpeed;
			$world = $player->getWorld();
			$world->broadcastPacketToViewers(
				$this->blockPos,
				LevelEventPacket::create(LevelEvent::BLOCK_BREAK_SPEED, (int) (65535 * $this->breakSpeed), $this->blockPos)
			);
		}

		$this->breakProgress += $this->breakSpeed;

		if(($this->fxTicker++ % $this->fxTickInterval) === 0 && $this->breakProgress < 1){
			$world = $player->getWorld();
			$world->addParticle($this->blockPos, new BlockPunchParticle($this->block, $this->targetedFace));
			$world->addSound($this->blockPos, new BlockPunchSound($this->block));
			$player->broadcastAnimation(new ArmSwingAnimation($player), $player->getViewers());
		}

		return $this->breakProgress < 1;
	}

	public function getBlockPos() : Vector3{
		return $this->blockPos;
	}

	public function getTargetedFace() : int{
		return $this->targetedFace;
	}

	public function setTargetedFace(int $face) : void{
		Facing::validate($face);
		$this->targetedFace = $face;
	}

	public function getBreakSpeed() : float{
		return $this->breakSpeed;
	}

	public function getBreakProgress() : float{
		return $this->breakProgress;
	}

	public function __destruct(){
		$player = $this->player;
		$world = $player->getWorld();
		if($world->isInLoadedTerrain($this->blockPos)){
			$world->broadcastPacketToViewers(
				$this->blockPos,
				LevelEventPacket::create(LevelEvent::BLOCK_STOP_BREAK, 0, $this->blockPos)
			);
		}
	}
}
