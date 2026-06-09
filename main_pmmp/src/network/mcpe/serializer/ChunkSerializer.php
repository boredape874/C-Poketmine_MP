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

namespace pocketmine\network\mcpe\serializer;

use pmmp\encoding\Byte;
use pmmp\encoding\ByteBufferWriter;
use pmmp\encoding\VarInt;
use pocketmine\block\tile\Spawnable;
use pocketmine\data\bedrock\BiomeIds;
use pocketmine\data\bedrock\LegacyBiomeIdToStringIdMap;
use pocketmine\nbt\TreeRoot;
use pocketmine\network\mcpe\convert\BlockTranslator;
use pocketmine\network\mcpe\protocol\serializer\NetworkNbtSerializer;
use pocketmine\network\mcpe\protocol\types\DimensionIds;
use pocketmine\world\format\Chunk;
use pocketmine\world\format\PalettedBlockArray;
use pocketmine\world\format\SubChunk;
use function count;
use function function_exists;

final class ChunkSerializer{
	private static ?bool $nativeSignedVarintEncoderAvailable = null;
	private static ?bool $nativeBiomePaletteEncoderAvailable = null;
	private static ?bool $nativeMappedSignedVarintEncoderAvailable = null;

	private function __construct(){
		//NOOP
	}

	private static function isNativeSignedVarintEncoderAvailable() : bool{
		return self::$nativeSignedVarintEncoderAvailable ??= function_exists('pmmp_perf_encode_signed_varints');
	}

	private static function isNativeBiomePaletteEncoderAvailable() : bool{
		return self::$nativeBiomePaletteEncoderAvailable ??= function_exists('pmmp_perf_encode_biome_palette');
	}

	private static function isNativeMappedSignedVarintEncoderAvailable() : bool{
		return self::$nativeMappedSignedVarintEncoderAvailable ??= function_exists('pmmp_perf_encode_mapped_signed_varints');
	}

	/**
	 * Returns the min/max subchunk index expected in the protocol.
	 * This has no relation to the world height supported by PM.
	 *
	 * @phpstan-param DimensionIds::* $dimensionId
	 * @return int[]
	 * @phpstan-return array{int, int}
	 */
	public static function getDimensionChunkBounds(int $dimensionId) : array{
		return match($dimensionId){
			DimensionIds::OVERWORLD => [-4, 19],
			DimensionIds::NETHER => [0, 7],
			DimensionIds::THE_END => [0, 15],
			default => throw new \InvalidArgumentException("Unknown dimension ID $dimensionId"),
		};
	}

	/**
	 * Returns the number of subchunks that will be sent from the given chunk.
	 * Chunks are sent in a stack, so every chunk below the top non-empty one must be sent.
	 *
	 * @phpstan-param DimensionIds::* $dimensionId
	 */
	public static function getSubChunkCount(Chunk $chunk, int $dimensionId) : int{
		//if the protocol world bounds ever exceed the PM supported bounds again in the future, we might need to
		//polyfill some stuff here
		[$minSubChunkIndex, $maxSubChunkIndex] = self::getDimensionChunkBounds($dimensionId);
		for($y = $maxSubChunkIndex, $count = $maxSubChunkIndex - $minSubChunkIndex + 1; $y >= $minSubChunkIndex; --$y, --$count){
			if($chunk->getSubChunk($y)->isEmptyFast()){
				continue;
			}
			return $count;
		}

		return 0;
	}

	/**
	 * @phpstan-param DimensionIds::* $dimensionId
	 */
	public static function serializeFullChunk(Chunk $chunk, int $dimensionId, BlockTranslator $blockTranslator, ?string $tiles = null, ?int $subChunkCount = null) : string{
		$stream = new ByteBufferWriter();

		$subChunkCount ??= self::getSubChunkCount($chunk, $dimensionId);
		$writtenCount = 0;

		[$minSubChunkIndex, $maxSubChunkIndex] = self::getDimensionChunkBounds($dimensionId);
		for($y = $minSubChunkIndex; $writtenCount < $subChunkCount; ++$y, ++$writtenCount){
			self::serializeSubChunk($chunk->getSubChunk($y), $blockTranslator, $stream, false);
		}

		$biomeIdMap = LegacyBiomeIdToStringIdMap::getInstance()->getLegacyToStringMap();
		//all biomes must always be written :(
		for($y = $minSubChunkIndex; $y <= $maxSubChunkIndex; ++$y){
			self::serializeBiomePalette($chunk->getSubChunk($y)->getBiomeArray(), $biomeIdMap, $stream);
		}

		Byte::writeUnsigned($stream, 0); //border block array count
		//Border block entry format: 1 byte (4 bits X, 4 bits Z). These are however useless since they crash the regular client.

		if($tiles !== null){
			$stream->writeByteArray($tiles);
		}else{
			$chunkTiles = $chunk->getTiles();
			if(count($chunkTiles) > 0){
				$stream->writeByteArray(self::serializeTilesFromArray($chunkTiles));
			}
		}
		return $stream->getData();
	}

	public static function serializeSubChunk(SubChunk $subChunk, BlockTranslator $blockTranslator, ByteBufferWriter $stream, bool $persistentBlockStates) : void{
		$layers = $subChunk->getBlockLayers();
		Byte::writeUnsigned($stream, 8); //version

		Byte::writeUnsigned($stream, count($layers));

		$blockStateDictionary = null;
		foreach($layers as $blocks){
			$bitsPerBlock = $blocks->getBitsPerBlock();
			$words = $blocks->getWordArray();
			Byte::writeUnsigned($stream, ($bitsPerBlock << 1) | ($persistentBlockStates ? 0 : 1));
			$stream->writeByteArray($words);

			if($persistentBlockStates){
				$blockStateDictionary ??= $blockTranslator->getBlockStateDictionary();
				$nbtSerializer = new NetworkNbtSerializer();
				if($bitsPerBlock === 0){
					$state = $blockStateDictionary->generateDataFromStateId($blockTranslator->internalIdToNetworkId($blocks->get(0, 0, 0)));
					if($state === null){
						$state = $blockTranslator->getFallbackStateData();
					}

					$stream->writeByteArray($nbtSerializer->write(new TreeRoot($state->toNbt())));
					continue;
				}

				$palette = $blocks->getPalette();
				VarInt::writeSignedInt($stream, count($palette)); //yes, this is intentionally zigzag
				foreach($palette as $p){
					//TODO: introduce a binary cache for this
					$state = $blockStateDictionary->generateDataFromStateId($blockTranslator->internalIdToNetworkId($p));
					if($state === null){
						$state = $blockTranslator->getFallbackStateData();
					}

					$stream->writeByteArray($nbtSerializer->write(new TreeRoot($state->toNbt())));
				}
			}else{
				if($bitsPerBlock === 0){
					VarInt::writeSignedInt($stream, $blockTranslator->internalIdToNetworkId($blocks->get(0, 0, 0)));
					continue;
				}

				$palette = $blocks->getPalette();
				$paletteCount = count($palette);
				VarInt::writeSignedInt($stream, $paletteCount); //yes, this is intentionally zigzag
				if(self::$nativeMappedSignedVarintEncoderAvailable !== false && $paletteCount > 2 && self::isNativeMappedSignedVarintEncoderAvailable()){
					$cache = &$blockTranslator->getNetworkIdCache();
					$encodedPalette = \pmmp_perf_encode_mapped_signed_varints($palette, $cache);
					if($encodedPalette !== null){
						$stream->writeByteArray($encodedPalette);
						continue;
					}
				}
				if(self::$nativeSignedVarintEncoderAvailable !== false && $paletteCount > 2 && self::isNativeSignedVarintEncoderAvailable()){
					$networkIds = $blockTranslator->internalIdsToNetworkIds($palette);
					$stream->writeByteArray(\pmmp_perf_encode_signed_varints($networkIds));
				}else{
					foreach($palette as $p){
						VarInt::writeSignedInt($stream, $blockTranslator->internalIdToNetworkId($p));
					}
				}
			}
		}
	}

	/**
	 * @param string[] $biomeIdMap
	 * @phpstan-param array<int, string> $biomeIdMap
	 */
	private static function serializeBiomePalette(PalettedBlockArray $biomePalette, array $biomeIdMap, ByteBufferWriter $stream) : void{
		$biomePaletteBitsPerBlock = $biomePalette->getBitsPerBlock();
		Byte::writeUnsigned($stream, ($biomePaletteBitsPerBlock << 1) | 1); //the last bit is non-persistence (like for blocks), though it has no effect on biomes since they always use integer IDs
		$stream->writeByteArray($biomePalette->getWordArray());

		if($biomePaletteBitsPerBlock === 0){
			$p = $biomePalette->get(0, 0, 0);
			VarInt::writeSignedInt($stream, isset($biomeIdMap[$p]) ? $p : BiomeIds::OCEAN);
			return;
		}

		$biomePaletteArray = $biomePalette->getPalette();
		$biomePaletteCount = count($biomePaletteArray);
		VarInt::writeSignedInt($stream, $biomePaletteCount);

		$oceanBiomeId = BiomeIds::OCEAN;
		if(self::$nativeBiomePaletteEncoderAvailable !== false && $biomePaletteCount > 2 && self::isNativeBiomePaletteEncoderAvailable()){
			$stream->writeByteArray(\pmmp_perf_encode_biome_palette($biomePaletteArray, $biomeIdMap, $oceanBiomeId));
		}else{
			foreach($biomePaletteArray as $p){
				VarInt::writeSignedInt($stream, isset($biomeIdMap[$p]) ? $p : $oceanBiomeId);
			}
		}
	}

	public static function serializeTiles(Chunk $chunk) : string{
		return self::serializeTilesFromArray($chunk->getTiles());
	}

	/**
	 * @param \pocketmine\block\tile\Tile[] $tiles
	 */
	private static function serializeTilesFromArray(array $tiles) : string{
		$stream = new ByteBufferWriter();
		foreach($tiles as $tile){
			if($tile instanceof Spawnable){
				$stream->writeByteArray($tile->getSerializedSpawnCompound()->getEncodedNbt());
			}
		}

		return $stream->getData();
	}
}
