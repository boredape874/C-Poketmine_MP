<?php declare(strict_types=1);

namespace pocketmine\tools\bench_hotpaths;

use pmmp\encoding\ByteBufferWriter;
use pocketmine\inventory\SimpleInventory;
use pocketmine\math\Vector3;
use pocketmine\network\mcpe\compression\ZlibCompressor;
use pocketmine\network\mcpe\NetworkSession;
use pocketmine\network\mcpe\protocol\AnimatePacket;
use pocketmine\network\mcpe\protocol\InventoryContentPacket;
use pocketmine\network\mcpe\protocol\InventorySlotPacket;
use pocketmine\network\mcpe\protocol\MobEquipmentPacket;
use pocketmine\network\mcpe\protocol\MoveActorAbsolutePacket;
use pocketmine\network\mcpe\protocol\MovePlayerPacket;
use pocketmine\network\mcpe\protocol\PacketPool;
use pocketmine\network\mcpe\protocol\PlayerActionPacket;
use pocketmine\network\mcpe\protocol\serializer\PacketBatch;
use pocketmine\network\mcpe\protocol\SetActorDataPacket;
use pocketmine\network\mcpe\protocol\SetActorMotionPacket;
use pocketmine\network\mcpe\protocol\TextPacket;
use pocketmine\network\mcpe\protocol\types\BlockPosition;
use pocketmine\network\mcpe\protocol\types\entity\ByteMetadataProperty;
use pocketmine\network\mcpe\protocol\types\entity\FloatMetadataProperty;
use pocketmine\network\mcpe\protocol\types\entity\PropertySyncData;
use pocketmine\network\mcpe\protocol\types\entity\StringMetadataProperty;
use pocketmine\network\mcpe\protocol\types\inventory\ContainerIds;
use pocketmine\network\mcpe\protocol\types\inventory\FullContainerName;
use pocketmine\network\mcpe\protocol\types\inventory\ItemStackWrapper;
use pocketmine\network\mcpe\protocol\types\PlayerAction;
use pocketmine\network\mcpe\protocol\types\DimensionIds;
use pocketmine\network\mcpe\protocol\UpdateBlockPacket;
use pocketmine\network\mcpe\serializer\ChunkSerializer;
use pocketmine\player\ChunkSelector;
use pocketmine\item\VanillaItems;
use pocketmine\block\VanillaBlocks;
use pocketmine\data\bedrock\BiomeIds;
use pocketmine\network\mcpe\convert\TypeConverter;
use pocketmine\world\format\Chunk;
use pocketmine\world\format\io\FastChunkSerializer;
use pocketmine\world\format\PalettedBlockArray;
use pocketmine\world\format\SubChunk;
use pocketmine\world\World;
use pmmp\encoding\ByteBufferReader;
use function count;
use function dirname;
use function fwrite;
use function function_exists;
use function getopt;
use function hrtime;
use function json_encode;
use function max;
use function str_repeat;
use function strlen;
use function chr;
use function abs;
use const JSON_PRETTY_PRINT;
use const JSON_THROW_ON_ERROR;
use const STDOUT;

require dirname(__DIR__) . '/vendor/autoload.php';

function varintPrefixLength(int $length) : int{
	$prefixLength = 1;
	for($remaining = $length; $remaining >= 128; $remaining >>= 7){
		++$prefixLength;
	}
	return $prefixLength;
}

/**
 * @phpstan-return array{iterations: int, radius: int, chunks_seen: int, elapsed_ms: float, chunks_per_second: float}
 */
function benchChunkSelector(int $iterations, int $radius) : array{
	$selector = new ChunkSelector();
	$count = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		foreach($selector->selectChunks($radius, 625 + ($i & 15), 625 - ($i & 15)) as $chunkHash){
			$count += $chunkHash === 0 ? 0 : 1;
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'radius' => $radius,
		'chunks_seen' => $count,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'chunks_per_second' => $count / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, radius: int, budget: int, baseline_front_selected: int, biased_front_selected: int, biased_total_selected: int, elapsed_ms: float, selections_per_second: float}
 */
function benchChunkPrefetchPriority(int $iterations, int $radius) : array{
	$selector = new ChunkSelector();
	$budget = 8;
	$baselineFrontSelected = 0;
	$biasedFrontSelected = 0;
	$biasedTotalSelected = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$centerX = 625 + ($i & 15);
		$centerZ = 625 - ($i & 15);
		$queue = [];
		foreach($selector->selectChunks($radius, $centerX, $centerZ) as $hash){
			$queue[$hash] = true;
		}

		$selected = 0;
		foreach($queue as $hash => $_){
			World::getXZ($hash, $chunkX, $chunkZ);
			if($chunkX - $centerX >= 0){
				++$baselineFrontSelected;
			}
			if(++$selected >= $budget){
				break;
			}
		}

		$selected = 0;
		foreach($queue as $hash => $_){
			World::getXZ($hash, $chunkX, $chunkZ);
			if($chunkX - $centerX < 0){
				continue;
			}
			++$biasedFrontSelected;
			++$biasedTotalSelected;
			if(++$selected >= $budget){
				continue 2;
			}
		}
		foreach($queue as $hash => $_){
			World::getXZ($hash, $chunkX, $chunkZ);
			++$biasedTotalSelected;
			if($chunkX - $centerX >= 0){
				++$biasedFrontSelected;
			}
			if(++$selected >= $budget){
				break;
			}
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'radius' => $radius,
		'budget' => $budget,
		'baseline_front_selected' => $baselineFrontSelected,
		'biased_front_selected' => $biasedFrontSelected,
		'biased_total_selected' => $biasedTotalSelected,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'selections_per_second' => ($iterations * $budget) / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, cases: int, total_prefix_length: int, elapsed_ms: float, cases_per_second: float}
 */
function benchVarintLengths(int $iterations) : array{
	$lengths = [0, 1, 2, 32, 127, 128, 255, 256, 4095, 4096, 65535, 65536, 1_048_576, 16_777_216];
	$count = 0;
	$total = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		foreach($lengths as $length){
			$total += varintPrefixLength($length + ($i & 7));
			++$count;
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'cases' => count($lengths),
		'total_prefix_length' => $total,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'cases_per_second' => $count / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @param string[] $packets
 * @param int[]    $lengths
 * @phpstan-param list<string> $packets
 * @phpstan-param list<int> $lengths
 */
function encodeRawWithLengthsPhp(ByteBufferWriter $out, array $packets, array $lengths) : void{
	foreach($packets as $i => $packet){
		\pmmp\encoding\VarInt::writeUnsignedInt($out, $lengths[$i]);
		$out->writeByteArray($packet);
	}
}

/**
 * @phpstan-return array{iterations: int, packets_per_batch: int, native_extension_loaded: bool, packet_batch_elapsed_ms: float, php_reference_elapsed_ms: float, packet_batch_batches_per_second: float, php_reference_batches_per_second: float, output_bytes: int}
 */
function benchPacketBatchRaw(int $iterations) : array{
	$packets = [
		str_repeat('a', 12),
		str_repeat('b', 28),
		str_repeat('c', 64),
		str_repeat('d', 127),
		str_repeat('e', 128),
		str_repeat('f', 255),
		str_repeat('g', 512),
		str_repeat('h', 1024),
		str_repeat('i', 48),
		str_repeat('j', 96),
		str_repeat('k', 160),
		str_repeat('l', 320),
	];
	$lengths = [];
	foreach($packets as $packet){
		$lengths[] = strlen($packet);
	}
	$writer = new ByteBufferWriter();
	$outputBytes = 0;

	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$writer->clear();
		PacketBatch::encodeRawWithLengths($writer, $packets, $lengths);
		$outputBytes += strlen($writer->getData());
	}
	$packetBatchElapsedNs = max(1, hrtime(true) - $start);

	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$writer->clear();
		encodeRawWithLengthsPhp($writer, $packets, $lengths);
		$outputBytes += strlen($writer->getData());
	}
	$phpElapsedNs = max(1, hrtime(true) - $start);

	return [
		'iterations' => $iterations,
		'packets_per_batch' => count($packets),
		'native_extension_loaded' => function_exists('pmmp_perf_encode_packet_batch'),
		'packet_batch_elapsed_ms' => $packetBatchElapsedNs / 1_000_000,
		'php_reference_elapsed_ms' => $phpElapsedNs / 1_000_000,
		'packet_batch_batches_per_second' => $iterations / ($packetBatchElapsedNs / 1_000_000_000),
		'php_reference_batches_per_second' => $iterations / ($phpElapsedNs / 1_000_000_000),
		'output_bytes' => $outputBytes,
	];
}

/**
 * @phpstan-return array{iterations: int, items: int, conversions: int, elapsed_ms: float, conversions_per_second: float}
 */
function benchItemTranslator(int $iterations) : array{
	$translator = TypeConverter::getInstance()->getItemTranslator();
	$items = [
		VanillaItems::STONE_SWORD(),
		VanillaItems::DIAMOND(),
		VanillaItems::APPLE(),
		VanillaItems::ARROW(),
		VanillaItems::OAK_SIGN(),
		VanillaItems::WATER_BUCKET(),
	];
	$count = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		foreach($items as $item){
			$translator->toNetworkId($item);
			++$count;
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'items' => count($items),
		'conversions' => $count,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'conversions_per_second' => $count / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, inventories: int, item_adds: int, leftover_stacks: int, elapsed_ms: float, item_adds_per_second: float}
 */
function benchSimpleInventoryAdd(int $iterations) : array{
	$itemAdds = 0;
	$leftovers = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$inventory = new SimpleInventory(36);
		$inventory->setItem(0, VanillaItems::ARROW()->setCount(32));
		$inventory->setItem(1, VanillaItems::DIAMOND()->setCount(48));
		$inventory->setItem(2, VanillaItems::APPLE()->setCount(12));

		$items = [
			VanillaItems::ARROW()->setCount(40),
			VanillaItems::DIAMOND()->setCount(40),
			VanillaItems::APPLE()->setCount(24),
			VanillaItems::EMERALD()->setCount(3),
		];
		foreach($items as $item){
			$leftovers += count($inventory->addItem($item));
			++$itemAdds;
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'inventories' => $iterations,
		'item_adds' => $itemAdds,
		'leftover_stacks' => $leftovers,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'item_adds_per_second' => $itemAdds / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, packets_per_iteration: int, encoded_packets: int, batch_bytes: int, elapsed_ms: float, packets_per_second: float}
 */
function benchPacketEncoding(int $iterations) : array{
	$typeConverter = TypeConverter::getInstance();
	$sword = ItemStackWrapper::legacy($typeConverter->coreItemStackToNet(VanillaItems::STONE_SWORD()));
	$apple = ItemStackWrapper::legacy($typeConverter->coreItemStackToNet(VanillaItems::APPLE()->setCount(32)));
	$diamond = ItemStackWrapper::legacy($typeConverter->coreItemStackToNet(VanillaItems::DIAMOND()->setCount(16)));
	$empty = new ItemStackWrapper(0, \pocketmine\network\mcpe\protocol\types\inventory\ItemStack::null());
	$inventoryName = new FullContainerName(ContainerIds::INVENTORY, null);
	$packets = [
		TextPacket::raw(str_repeat('x', 64)),
		TextPacket::tip(str_repeat('t', 32)),
		MoveActorAbsolutePacket::create(12345, new Vector3(128.5, 64.0, -32.25), 22.5, 180.0, 180.0, MoveActorAbsolutePacket::FLAG_GROUND),
		MovePlayerPacket::simple(12346, new Vector3(129.25, 64.0, -31.5), 24.0, 181.0, 181.0, MovePlayerPacket::MODE_NORMAL, true, 0, 98765),
		SetActorMotionPacket::create(12345, new Vector3(0.08, -0.02, 0.13), 98765),
		SetActorDataPacket::create(12345, [
			0 => new ByteMetadataProperty(1),
			2 => new StringMetadataProperty('BenchPlayer'),
			3 => new FloatMetadataProperty(20.0),
		], new PropertySyncData([0 => 1, 1 => 20], [0 => 1.0, 1 => 0.25]), 98765),
		MobEquipmentPacket::create(12345, $sword, 0, 0, ContainerIds::INVENTORY),
		InventorySlotPacket::create(ContainerIds::INVENTORY, 5, $inventoryName, null, $diamond),
		InventoryContentPacket::create(ContainerIds::INVENTORY, [$sword, $apple, $diamond, $empty], $inventoryName, $empty),
	];
	$writer = new ByteBufferWriter();
	$batchWriter = new ByteBufferWriter();
	$count = 0;
	$batchBytes = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$buffers = [];
		$lengths = [];
		foreach($packets as $packet){
			$writer->clear();
			$buffer = NetworkSession::encodePacketTimed($writer, $packet);
			$buffers[] = $buffer;
			$length = strlen($buffer);
			$lengths[] = $length;
			$batchBytes += $length;
			++$count;
		}
		$batchWriter->clear();
		PacketBatch::encodeRawWithLengths($batchWriter, $buffers, $lengths);
		$batchBytes += strlen($batchWriter->getData());
		$batchWriter->clear();
		PacketBatch::encodeRawSingle($batchWriter, $buffers[0], $lengths[0]);
		$batchBytes += strlen($batchWriter->getData());
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'packets_per_iteration' => count($packets),
		'encoded_packets' => $count,
		'batch_bytes' => $batchBytes,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'packets_per_second' => $count / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, packets_per_iteration: int, generator_decoded_packets: int, callback_decoded_packets: int, native_string_decoded_packets: int, batch_bytes: int, generator_elapsed_ms: float, callback_elapsed_ms: float, native_string_elapsed_ms: float, generator_packets_per_second: float, callback_packets_per_second: float, native_string_packets_per_second: float, packets_per_second: float, native_extension_loaded: bool}
 */
function benchPacketDecoding(int $iterations) : array{
	$packets = [
		MovePlayerPacket::simple(12346, new Vector3(129.25, 64.0, -31.5), 24.0, 181.0, 181.0, MovePlayerPacket::MODE_NORMAL, true, 0, 98765),
		PlayerActionPacket::create(12346, PlayerAction::START_BREAK, new BlockPosition(128, 64, -32), new BlockPosition(128, 64, -32), 1),
		AnimatePacket::create(12346, AnimatePacket::ACTION_SWING_ARM),
		MovePlayerPacket::simple(12346, new Vector3(129.5, 64.0, -31.25), 24.5, 181.5, 181.5, MovePlayerPacket::MODE_NORMAL, true, 0, 98766),
	];
	$writer = new ByteBufferWriter();
	$batchWriter = new ByteBufferWriter();
	$buffers = [];
	$lengths = [];
	$batchBytes = 0;
	foreach($packets as $packet){
		$writer->clear();
		$buffer = NetworkSession::encodePacketTimed($writer, $packet);
		$buffers[] = $buffer;
		$length = strlen($buffer);
		$lengths[] = $length;
		$batchBytes += $length;
	}
	PacketBatch::encodeRawWithLengths($batchWriter, $buffers, $lengths);
	$batch = $batchWriter->getData();
	$batchBytes += strlen($batch);
	$packetPool = PacketPool::getInstance();
	$generatorCount = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$stream = new ByteBufferReader($batch);
		foreach(PacketBatch::decodeRaw($stream) as $buffer){
			$packet = $packetPool->getPacket($buffer);
			if($packet !== null){
				$packet->decode(new ByteBufferReader($buffer));
				++$generatorCount;
			}
		}
	}
	$generatorElapsedNs = max(1, hrtime(true) - $start);
	$callbackCount = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$stream = new ByteBufferReader($batch);
		PacketBatch::decodeRawCallback($stream, static function(string $buffer) use ($packetPool, &$callbackCount) : bool{
			$packet = $packetPool->getPacket($buffer);
			if($packet !== null){
				$packet->decode(new ByteBufferReader($buffer));
				++$callbackCount;
			}
			return true;
		});
	}
	$callbackElapsedNs = max(1, hrtime(true) - $start);
	$nativeStringCount = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		PacketBatch::decodeRawStringCallback($batch, static function(string $buffer) use ($packetPool, &$nativeStringCount) : bool{
			$packet = $packetPool->getPacket($buffer);
			if($packet !== null){
				$packet->decode(new ByteBufferReader($buffer));
				++$nativeStringCount;
			}
			return true;
		});
	}
	$nativeStringElapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'packets_per_iteration' => count($packets),
		'generator_decoded_packets' => $generatorCount,
		'callback_decoded_packets' => $callbackCount,
		'native_string_decoded_packets' => $nativeStringCount,
		'batch_bytes' => $batchBytes,
		'generator_elapsed_ms' => $generatorElapsedNs / 1_000_000,
		'callback_elapsed_ms' => $callbackElapsedNs / 1_000_000,
		'native_string_elapsed_ms' => $nativeStringElapsedNs / 1_000_000,
		'generator_packets_per_second' => $generatorCount / ($generatorElapsedNs / 1_000_000_000),
		'callback_packets_per_second' => $callbackCount / ($callbackElapsedNs / 1_000_000_000),
		'native_string_packets_per_second' => $nativeStringCount / ($nativeStringElapsedNs / 1_000_000_000),
		'packets_per_second' => $nativeStringCount / ($nativeStringElapsedNs / 1_000_000_000),
		'native_extension_loaded' => function_exists('pmmp_perf_decode_packet_batch'),
	];
}

/**
 * @phpstan-return array{iterations: int, lookups_per_iteration: int, packet_lookups: int, elapsed_ms: float, lookups_per_second: float}
 */
function benchPacketPoolLookup(int $iterations) : array{
	$packets = [
		MovePlayerPacket::simple(12346, new Vector3(129.25, 64.0, -31.5), 24.0, 181.0, 181.0, MovePlayerPacket::MODE_NORMAL, true, 0, 98765),
		PlayerActionPacket::create(12346, PlayerAction::START_BREAK, new BlockPosition(128, 64, -32), new BlockPosition(128, 64, -32), 1),
		AnimatePacket::create(12346, AnimatePacket::ACTION_SWING_ARM),
		TextPacket::raw(str_repeat('x', 32)),
	];
	$writer = new ByteBufferWriter();
	$buffers = [];
	foreach($packets as $packet){
		$writer->clear();
		$buffers[] = NetworkSession::encodePacketTimed($writer, $packet);
	}
	$packetPool = PacketPool::getInstance();
	$count = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		foreach($buffers as $buffer){
			if($packetPool->getPacket($buffer) !== null){
				++$count;
			}
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'lookups_per_iteration' => count($buffers),
		'packet_lookups' => $count,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'lookups_per_second' => $count / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, blocks_per_iteration: int, packets: int, encoded_bytes: int, state_data_lookups: int, elapsed_ms: float, packets_per_second: float, state_data_lookups_per_second: float}
 */
function benchBlockUpdatePackets(int $iterations) : array{
	$translator = TypeConverter::getInstance()->getBlockTranslator();
	$stateIds = [
		VanillaBlocks::STONE()->getStateId(),
		VanillaBlocks::DIRT()->getStateId(),
		VanillaBlocks::GRASS()->getStateId(),
		VanillaBlocks::OAK_PLANKS()->getStateId(),
		VanillaBlocks::WATER()->getStateId(),
		VanillaBlocks::SAND()->getStateId(),
		VanillaBlocks::COBBLESTONE()->getStateId(),
		VanillaBlocks::GLASS()->getStateId(),
	];
	$positions = [];
	for($i = 0; $i < 16; ++$i){
		$positions[] = new BlockPosition($i & 15, 64 + ($i & 7), ($i * 3) & 15);
	}
	$writer = new ByteBufferWriter();
	$count = 0;
	$bytes = 0;
	$stateDataLookups = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		foreach($stateIds as $j => $stateId){
			$translator->internalIdToNetworkStateData($stateId);
			++$stateDataLookups;
			$packet = UpdateBlockPacket::create(
				$positions[($i + $j) & 15],
				$translator->internalIdToNetworkId($stateId),
				UpdateBlockPacket::FLAG_NETWORK,
				UpdateBlockPacket::DATA_LAYER_NORMAL
			);
			$writer->clear();
			$packet->encode($writer);
			$bytes += strlen($writer->getData());
			++$count;
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'blocks_per_iteration' => count($stateIds),
		'packets' => $count,
		'encoded_bytes' => $bytes,
		'state_data_lookups' => $stateDataLookups,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'packets_per_second' => $count / ($elapsedNs / 1_000_000_000),
		'state_data_lookups_per_second' => $stateDataLookups / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, entities_per_iteration: int, array_matches: int, callback_matches: int, boolean_hits: int, array_elapsed_ms: float, callback_elapsed_ms: float, boolean_elapsed_ms: float, array_entities_per_second: float, callback_entities_per_second: float, boolean_queries_per_second: float}
 */
function benchNearbyEntityIteration(int $iterations) : array{
	$entities = [];
	for($chunkZ = -1; $chunkZ <= 1; ++$chunkZ){
		for($chunkX = -1; $chunkX <= 1; ++$chunkX){
			for($i = 0; $i < 12; ++$i){
				$entities[] = [
					(float) ($chunkX * 16 + (($i * 5) & 15)),
					(float) (62 + ($i & 7)),
					(float) ($chunkZ * 16 + (($i * 7) & 15)),
					0.6,
					1.8,
				];
			}
		}
	}

	$entityCount = count($entities);
	$arrayMatches = 0;
	$callbackMatches = 0;
	$booleanHits = 0;
	$checksum = 0.0;

	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$minX = -8.0 + ($i & 3);
		$maxX = $minX + 18.0;
		$minY = 60.0;
		$maxY = 72.0;
		$minZ = -8.0 + (($i >> 2) & 3);
		$maxZ = $minZ + 18.0;
		$matches = [];
		foreach($entities as $entity){
			if($entity[0] + $entity[3] >= $minX && $entity[0] - $entity[3] <= $maxX && $entity[1] + $entity[4] >= $minY && $entity[1] <= $maxY && $entity[2] + $entity[3] >= $minZ && $entity[2] - $entity[3] <= $maxZ){
				$matches[] = $entity;
			}
		}
		foreach($matches as $entity){
			$checksum += $entity[0];
			++$arrayMatches;
		}
	}
	$arrayElapsedNs = max(1, hrtime(true) - $start);

	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$minX = -8.0 + ($i & 3);
		$maxX = $minX + 18.0;
		$minY = 60.0;
		$maxY = 72.0;
		$minZ = -8.0 + (($i >> 2) & 3);
		$maxZ = $minZ + 18.0;
		foreach($entities as $entity){
			if($entity[0] + $entity[3] >= $minX && $entity[0] - $entity[3] <= $maxX && $entity[1] + $entity[4] >= $minY && $entity[1] <= $maxY && $entity[2] + $entity[3] >= $minZ && $entity[2] - $entity[3] <= $maxZ){
				$checksum += $entity[0];
				++$callbackMatches;
			}
		}
	}
	$callbackElapsedNs = max(1, hrtime(true) - $start);

	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$minX = 2048.0 + ($i & 3);
		$maxX = $minX + 18.0;
		$minY = 60.0;
		$maxY = 72.0;
		$minZ = 2048.0 + (($i >> 2) & 3);
		$maxZ = $minZ + 18.0;
		foreach($entities as $entity){
			if($entity[0] + $entity[3] >= $minX && $entity[0] - $entity[3] <= $maxX && $entity[1] + $entity[4] >= $minY && $entity[1] <= $maxY && $entity[2] + $entity[3] >= $minZ && $entity[2] - $entity[3] <= $maxZ){
				++$booleanHits;
				break;
			}
		}
	}
	$booleanElapsedNs = max(1, hrtime(true) - $start);
	$checksum += $booleanHits;

	return [
		'iterations' => $iterations,
		'entities_per_iteration' => $entityCount,
		'array_matches' => $arrayMatches,
		'callback_matches' => $callbackMatches,
		'boolean_hits' => $booleanHits + (int) ($checksum === -1.0),
		'array_elapsed_ms' => $arrayElapsedNs / 1_000_000,
		'callback_elapsed_ms' => $callbackElapsedNs / 1_000_000,
		'boolean_elapsed_ms' => $booleanElapsedNs / 1_000_000,
		'array_entities_per_second' => ($iterations * $entityCount) / ($arrayElapsedNs / 1_000_000_000),
		'callback_entities_per_second' => ($iterations * $entityCount) / ($callbackElapsedNs / 1_000_000_000),
		'boolean_queries_per_second' => $iterations / ($booleanElapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, serialized_subchunks: int, serialized_bytes: int, elapsed_ms: float, subchunks_per_second: float}
 */
function benchSerializeSubChunk(int $iterations) : array{
	$states = [
		VanillaBlocks::STONE()->getStateId(),
		VanillaBlocks::DIRT()->getStateId(),
		VanillaBlocks::GRASS()->getStateId(),
		VanillaBlocks::OAK_PLANKS()->getStateId(),
		VanillaBlocks::SAND()->getStateId(),
		VanillaBlocks::COBBLESTONE()->getStateId(),
	];
	$blocks = new PalettedBlockArray($states[0]);
	foreach($states as $i => $stateId){
		for($y = 0; $y < 16; $y += 4){
			$blocks->set(($i * 3) & 15, $y, ($i * 5) & 15, $stateId);
		}
	}
	$subChunk = new SubChunk($states[0], [$blocks], new PalettedBlockArray(BiomeIds::OCEAN));
	$translator = TypeConverter::getInstance()->getBlockTranslator();
	$writer = new ByteBufferWriter();
	$bytes = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$writer->clear();
		ChunkSerializer::serializeSubChunk($subChunk, $translator, $writer, false);
		$bytes += strlen($writer->getData());
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'serialized_subchunks' => $iterations,
		'serialized_bytes' => $bytes,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'subchunks_per_second' => $iterations / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, serialized_chunks: int, serialized_bytes: int, elapsed_ms: float, chunks_per_second: float, native_extension_loaded: bool}
 */
function benchSerializeFullChunk(int $iterations) : array{
	$states = [
		VanillaBlocks::STONE()->getStateId(),
		VanillaBlocks::DIRT()->getStateId(),
		VanillaBlocks::GRASS()->getStateId(),
		VanillaBlocks::OAK_PLANKS()->getStateId(),
		VanillaBlocks::SAND()->getStateId(),
		VanillaBlocks::COBBLESTONE()->getStateId(),
	];
	$subChunks = [];
	for($sy = Chunk::MIN_SUBCHUNK_INDEX; $sy <= Chunk::MAX_SUBCHUNK_INDEX; ++$sy){
		if($sy >= 0 && $sy < 4){
			$blocks = new PalettedBlockArray($states[0]);
			foreach($states as $i => $stateId){
				for($y = 0; $y < 16; $y += 4){
					$blocks->set(($i * 3 + $sy) & 15, $y, ($i * 5 + $sy) & 15, $stateId);
				}
			}
			$subChunks[$sy] = new SubChunk($states[0], [$blocks], new PalettedBlockArray(BiomeIds::OCEAN));
		}else{
			$subChunks[$sy] = new SubChunk($states[0], [], new PalettedBlockArray(BiomeIds::OCEAN));
		}
	}
	$chunk = new Chunk($subChunks, true);
	$translator = TypeConverter::getInstance()->getBlockTranslator();
	$bytes = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$bytes += strlen(ChunkSerializer::serializeFullChunk($chunk, DimensionIds::OVERWORLD, $translator));
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'serialized_chunks' => $iterations,
		'serialized_bytes' => $bytes,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'chunks_per_second' => $iterations / ($elapsedNs / 1_000_000_000),
		'native_extension_loaded' => function_exists('pmmp_perf_encode_signed_varints'),
	];
}

/**
 * @phpstan-return array{iterations: int, serialized_chunks: int, deserialized_chunks: int, serialized_bytes: int, serialize_elapsed_ms: float, deserialize_elapsed_ms: float, serialize_chunks_per_second: float, deserialize_chunks_per_second: float, native_pack_loaded: bool, native_unpack_loaded: bool}
 */
function benchFastChunkSerializer(int $iterations) : array{
	$states = [
		VanillaBlocks::STONE()->getStateId(),
		VanillaBlocks::DIRT()->getStateId(),
		VanillaBlocks::GRASS()->getStateId(),
		VanillaBlocks::OAK_PLANKS()->getStateId(),
		VanillaBlocks::SAND()->getStateId(),
		VanillaBlocks::COBBLESTONE()->getStateId(),
		VanillaBlocks::WATER()->getStateId(),
		VanillaBlocks::LAVA()->getStateId(),
	];
	$subChunks = [];
	for($sy = Chunk::MIN_SUBCHUNK_INDEX; $sy <= Chunk::MAX_SUBCHUNK_INDEX; ++$sy){
		if($sy >= 0 && $sy < 6){
			$blocks = new PalettedBlockArray($states[0]);
			$biomes = new PalettedBlockArray(BiomeIds::OCEAN);
			foreach($states as $i => $stateId){
				for($y = 0; $y < 16; $y += 4){
					$blocks->set(($i * 3 + $sy) & 15, $y, ($i * 5 + $sy) & 15, $stateId);
					$biomes->set(($i * 7 + $sy) & 15, $y, ($i * 11 + $sy) & 15, BiomeIds::OCEAN + ($i & 3));
				}
			}
			$subChunks[$sy] = new SubChunk($states[0], [$blocks], $biomes);
		}else{
			$subChunks[$sy] = new SubChunk($states[0], [], new PalettedBlockArray(BiomeIds::OCEAN));
		}
	}
	$chunk = new Chunk($subChunks, true);
	$bytes = 0;

	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$bytes += strlen(FastChunkSerializer::serializeTerrain($chunk));
	}
	$serializeElapsedNs = max(1, hrtime(true) - $start);

	$serialized = FastChunkSerializer::serializeTerrain($chunk);
	$deserialized = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		FastChunkSerializer::deserializeTerrain($serialized);
		++$deserialized;
	}
	$deserializeElapsedNs = max(1, hrtime(true) - $start);

	return [
		'iterations' => $iterations,
		'serialized_chunks' => $iterations,
		'deserialized_chunks' => $deserialized,
		'serialized_bytes' => $bytes,
		'serialize_elapsed_ms' => $serializeElapsedNs / 1_000_000,
		'deserialize_elapsed_ms' => $deserializeElapsedNs / 1_000_000,
		'serialize_chunks_per_second' => $iterations / ($serializeElapsedNs / 1_000_000_000),
		'deserialize_chunks_per_second' => $iterations / ($deserializeElapsedNs / 1_000_000_000),
		'native_pack_loaded' => function_exists('pmmp_perf_pack_u32le'),
		'native_unpack_loaded' => function_exists('pmmp_perf_unpack_u32le'),
	];
}

/**
 * @phpstan-return array{iterations: int, small_batches: int, large_batches: int, compressed_bytes: int, elapsed_ms: float, batches_per_second: float}
 */
function benchCompression(int $iterations) : array{
	$compressor = new ZlibCompressor(ZlibCompressor::DEFAULT_LEVEL, ZlibCompressor::DEFAULT_THRESHOLD, ZlibCompressor::DEFAULT_MAX_DECOMPRESSION_SIZE);
	$small = str_repeat('a', 128);
	$large = str_repeat('b', 4096);
	$bytes = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$bytes += strlen(chr($compressor->getNetworkId()) . $compressor->compress($small));
		$bytes += strlen(chr($compressor->getNetworkId()) . $compressor->compress($large));
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'small_batches' => $iterations,
		'large_batches' => $iterations,
		'compressed_bytes' => $bytes,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'batches_per_second' => ($iterations * 2) / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, accepted_updates: int, rejected_updates: int, speed_changes: int, fx_events: int, completed_breaks: int, elapsed_ms: float, updates_per_second: float}
 */
function benchMiningProgress(int $iterations) : array{
	$blockX = 128.0;
	$blockY = 64.0;
	$blockZ = -32.0;
	$centerX = $blockX + 0.5;
	$centerY = $blockY + 0.5;
	$centerZ = $blockZ + 0.5;
	$maxDistance = 6.0;
	$maxDistanceSquared = $maxDistance * $maxDistance;
	$speeds = [0.0125, 0.016, 0.02, 0.0075, 0.025, 0.01, 0.018, 0.014];
	$accepted = 0;
	$rejected = 0;
	$speedChanges = 0;
	$fxEvents = 0;
	$completedBreaks = 0;
	$progress = 0.0;
	$breakSpeed = $speeds[0];
	$fxTicker = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$playerX = $centerX + (($i & 7) - 3) * 0.45;
		$playerY = $centerY + (($i >> 3) & 3) * 0.35;
		$playerZ = $centerZ + (($i >> 5) & 7) * 0.32;
		if(($i & 63) === 63){
			$playerX += 8.0;
		}
		$dx = $playerX - $centerX;
		$dy = $playerY - $centerY;
		$dz = $playerZ - $centerZ;
		if($dx * $dx + $dy * $dy + $dz * $dz > $maxDistanceSquared){
			++$rejected;
			continue;
		}
		++$accepted;
		$newSpeed = $speeds[($i >> 4) & 7];
		if(abs($newSpeed - $breakSpeed) > 0.0001){
			$breakSpeed = $newSpeed;
			++$speedChanges;
		}
		$progress += $breakSpeed;
		if(($fxTicker++ % 5) === 0 && $progress < 1.0){
			++$fxEvents;
		}
		if($progress >= 1.0){
			++$completedBreaks;
			$progress = 0.0;
			$breakSpeed = $speeds[$i & 7];
			$fxTicker = 0;
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'accepted_updates' => $accepted,
		'rejected_updates' => $rejected,
		'speed_changes' => $speedChanges,
		'fx_events' => $fxEvents,
		'completed_breaks' => $completedBreaks,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'updates_per_second' => $iterations / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, movement_updates: int, look_only_updates: int, event_checks: int, chunk_order_reductions: int, exhausted_distance: float, elapsed_ms: float, updates_per_second: float}
 */
function benchMovementProcess(int $iterations) : array{
	$lastX = 128.0;
	$lastY = 64.0;
	$lastZ = -32.0;
	$lastYaw = 180.0;
	$lastPitch = 0.0;
	$moveRateLimit = 200.0;
	$nextChunkOrderRun = 80;
	$movementUpdates = 0;
	$lookOnlyUpdates = 0;
	$eventChecks = 0;
	$chunkOrderReductions = 0;
	$exhaustedDistance = 0.0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$moveRateLimit = min(200.0, max(0.0, $moveRateLimit) + 2.0);
		$x = $lastX;
		$y = $lastY;
		$z = $lastZ;
		if(($i & 3) !== 0){
			$x += (($i & 7) - 3) * 0.015625;
			$z += (((($i >> 3) & 7) - 3) * 0.015625);
		}
		$yaw = $lastYaw + (($i & 1) === 0 ? 1.25 : -1.25);
		$pitch = $lastPitch + (($i & 2) === 0 ? 0.25 : -0.25);
		$deltaX = $x - $lastX;
		$deltaY = $y - $lastY;
		$deltaZ = $z - $lastZ;
		$delta = $deltaX * $deltaX + $deltaY * $deltaY + $deltaZ * $deltaZ;
		$deltaAngle = abs($lastYaw - $yaw) + abs($lastPitch - $pitch);
		if($delta > 0.0001 || $deltaAngle > 1.0){
			++$eventChecks;
			$lastX = $x;
			$lastY = $y;
			$lastZ = $z;
			$lastYaw = $yaw;
			$lastPitch = $pitch;
			$horizontalDistanceSquared = $deltaX * $deltaX + $deltaZ * $deltaZ;
			if($horizontalDistanceSquared > 0.0){
				++$movementUpdates;
				$exhaustedDistance += $horizontalDistanceSquared;
				if($nextChunkOrderRun > 20){
					$nextChunkOrderRun = 20;
					++$chunkOrderReductions;
				}
			}else{
				++$lookOnlyUpdates;
			}
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'movement_updates' => $movementUpdates,
		'look_only_updates' => $lookOnlyUpdates,
		'event_checks' => $eventChecks,
		'chunk_order_reductions' => $chunkOrderReductions,
		'exhausted_distance' => $exhaustedDistance,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'updates_per_second' => $iterations / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, snapshots: int, pending_accumulator: int, elapsed_ms: float, snapshots_per_second: float}
 */
function benchChunkPressureSnapshot(int $iterations) : array{
	$loadQueueCount = 42;
	$activeGenerationCount = 6;
	$neededCount = 24;
	$requestedGenerationCount = 24;
	$requestedSendingCount = 12;
	$sentCount = 136;
	$pendingAccumulator = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$pendingAccumulator += $loadQueueCount + $activeGenerationCount + $requestedSendingCount + $neededCount + $requestedGenerationCount + $sentCount - $sentCount - $requestedGenerationCount - $neededCount;
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'snapshots' => $iterations,
		'pending_accumulator' => $pendingAccumulator,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'snapshots_per_second' => $iterations / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, scale_accumulator: int, pending_accumulator: int, elapsed_ms: float, decisions_per_second: float}
 */
function benchGlobalChunkBudgetCoordinator(int $iterations) : array{
	$online = 400;
	$asyncSize = 16;
	$scaleAccumulator = 0;
	$pendingAccumulator = 0;
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$pending = $online * (16 + ($i & 31));
		$requestedSending = $online * (($i >> 5) & 15);
		$asyncBacklog = ($i >> 8) & 63;
		$useAverage = (($i >> 14) & 127) / 127;
		$scale = 100;
		if($useAverage > 0.85 || $asyncBacklog > $asyncSize * 3 || $requestedSending > $online * 8){
			$scale = 50;
		}elseif($useAverage > 0.70 || $asyncBacklog > $asyncSize || $requestedSending > $online * 4){
			$scale = 75;
		}elseif($useAverage < 0.45 && $asyncBacklog === 0 && $pending > $online * 24){
			$scale = 125;
		}
		$scaleAccumulator += $scale;
		$pendingAccumulator += $pending;
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'scale_accumulator' => $scaleAccumulator,
		'pending_accumulator' => $pendingAccumulator,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'decisions_per_second' => $iterations / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, candidates: int, active_skips: int, stale_completions: int, elapsed_ms: float, candidates_per_second: float}
 */
function benchPopulationPrefetchSelection(int $iterations) : array{
	$centerX = 128;
	$centerZ = -64;
	$radius = 5;
	$candidates = 0;
	$activeSkips = 0;
	$staleCompletions = 0;
	$generation = 0;
	$active = [];
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$directionX = (($i & 2) === 0 ? 1.0 : -1.0) * (($i & 1) === 0 ? 0.125 : 0.75);
		$directionZ = (($i & 8) === 0 ? 1.0 : -1.0) * (($i & 4) === 0 ? 0.125 : 0.75);
		if(($i & 31) === 0){
			++$generation;
			foreach($active as $activeGeneration){
				if($activeGeneration !== $generation){
					++$staleCompletions;
				}
			}
			$active = [];
		}
		$stepX = $directionX > 0.0 ? 1 : -1;
		$stepZ = $directionZ > 0.0 ? 1 : -1;
		for($j = 0; $j < 2; ++$j){
			$chunkX = $centerX + $stepX * $radius + ($j - 1);
			$chunkZ = $centerZ + $stepZ * $radius + ($j - 1);
			$hash = ($chunkX << 32) ^ ($chunkZ & 0xffffffff);
			if(isset($active[$hash])){
				++$activeSkips;
				continue;
			}
			$active[$hash] = $generation;
			$candidates += (($chunkX ^ $chunkZ) & 1) === 0 ? 1 : 0;
			if(($i & 7) === 0){
				unset($active[$hash]);
			}
		}
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'candidates' => $candidates,
		'active_skips' => $activeSkips,
		'stale_completions' => $staleCompletions,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'candidates_per_second' => ($iterations * 2) / ($elapsedNs / 1_000_000_000),
	];
}

/**
 * @phpstan-return array{iterations: int, players: int, requests: int, unique_requests: int, shared_hits: int, elapsed_ms: float, requests_per_second: float}
 */
function benchChunkPopulationCoalescing(int $iterations) : array{
	$players = 400;
	$requests = 0;
	$uniqueRequests = 0;
	$sharedHits = 0;
	$active = [];
	$start = hrtime(true);
	for($i = 0; $i < $iterations; ++$i){
		$centerX = 1024 + ($i & 7);
		$centerZ = -1024 + (($i >> 3) & 7);
		for($player = 0; $player < $players; ++$player){
			$chunkX = $centerX + (($player >> 2) & 3) - 1;
			$chunkZ = $centerZ + ($player & 3) - 1;
			$hash = ($chunkX << 32) ^ ($chunkZ & 0xffffffff);
			++$requests;
			if(isset($active[$hash])){
				++$sharedHits;
			}else{
				$active[$hash] = true;
				++$uniqueRequests;
			}
		}
		$active = [];
	}
	$elapsedNs = max(1, hrtime(true) - $start);
	return [
		'iterations' => $iterations,
		'players' => $players,
		'requests' => $requests,
		'unique_requests' => $uniqueRequests,
		'shared_hits' => $sharedHits,
		'elapsed_ms' => $elapsedNs / 1_000_000,
		'requests_per_second' => $requests / ($elapsedNs / 1_000_000_000),
	];
}

$opts = getopt('', ['iterations::', 'radius::']);
$iterations = isset($opts['iterations']) ? (int) $opts['iterations'] : 2000;
$radius = isset($opts['radius']) ? (int) $opts['radius'] : 4;

$result = [
	'chunk_selector' => benchChunkSelector($iterations, $radius),
	'chunk_prefetch_priority' => benchChunkPrefetchPriority($iterations, $radius),
	'varint_lengths' => benchVarintLengths($iterations * 100),
	'packet_batch_raw' => benchPacketBatchRaw($iterations * 100),
	'item_translator' => benchItemTranslator($iterations * 100),
	'simple_inventory_add' => benchSimpleInventoryAdd($iterations),
	'packet_encoding' => benchPacketEncoding($iterations * 100),
	'packet_decoding' => benchPacketDecoding($iterations * 100),
	'packet_pool_lookup' => benchPacketPoolLookup($iterations * 500),
	'block_update_packets' => benchBlockUpdatePackets($iterations * 100),
	'nearby_entity_iteration' => benchNearbyEntityIteration($iterations * 100),
	'subchunk_serialization' => benchSerializeSubChunk($iterations * 100),
	'full_chunk_serialization' => benchSerializeFullChunk($iterations * 10),
	'fast_chunk_serializer' => benchFastChunkSerializer($iterations * 10),
	'compression' => benchCompression($iterations * 20),
	'mining_progress' => benchMiningProgress($iterations * 200),
	'movement_process' => benchMovementProcess($iterations * 200),
	'chunk_pressure_snapshot' => benchChunkPressureSnapshot($iterations * 200),
	'global_chunk_budget' => benchGlobalChunkBudgetCoordinator($iterations * 200),
	'population_prefetch_selection' => benchPopulationPrefetchSelection($iterations * 200),
	'chunk_population_coalescing' => benchChunkPopulationCoalescing($iterations * 20),
];

fwrite(STDOUT, json_encode($result, JSON_PRETTY_PRINT | JSON_THROW_ON_ERROR) . "\n");
