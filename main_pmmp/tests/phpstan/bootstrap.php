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

if(!defined('LEVELDB_ZLIB_RAW_COMPRESSION')){
	//leveldb might not be loaded
	define('LEVELDB_ZLIB_RAW_COMPRESSION', 4);
}
if(!extension_loaded('libdeflate')){
	function libdeflate_deflate_compress(string $data, int $level = 6) : string{}
}
if(!extension_loaded('pmmp_perf_ext')){
	/**
	 * @param list<string>   $packets
	 * @param list<int>|null $lengths
	 */
	function pmmp_perf_encode_packet_batch(array $packets, ?array $lengths = null) : string{}

	function pmmp_perf_varint_prefix_length(int $length) : int{}

	/**
	 * @param list<int> $values
	 */
	function pmmp_perf_encode_signed_varints(array $values) : string{}

	/**
	 * @return array{name: string, version: string, purpose: string}
	 */
	function pmmp_perf_build_info() : array{}

}
if(!function_exists('pmmp_perf_read_fast_paletted_array')){
	/**
	 * @return array{int, string, list<int>, int}
	 */
	function pmmp_perf_read_fast_paletted_array(string $data, int $offset) : array{}
}

//opcache breaks PHPStan when dynamic reflection is used - see https://github.com/phpstan/phpstan-src/pull/801#issuecomment-978431013
ini_set('opcache.enable', 'off');
