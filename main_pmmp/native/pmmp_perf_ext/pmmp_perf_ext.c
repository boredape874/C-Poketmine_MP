#ifdef HAVE_CONFIG_H
# include "config.h"
#endif

#include "php.h"
#include "php_pmmp_perf_ext.h"
#include "Zend/zend_smart_str.h"
#include <stdint.h>
#include <string.h>

static size_t pmmp_perf_unsigned_varint_length(size_t value)
{
	size_t prefix_length = 1;
	while(value >= 128){
		value >>= 7;
		++prefix_length;
	}
	return prefix_length;
}

static char *pmmp_perf_write_unsigned_varint_to_ptr(char *out, size_t value)
{
	do{
		unsigned char byte = (unsigned char) (value & 0x7f);
		value >>= 7;
		if(value != 0){
			byte |= 0x80;
		}
		*out++ = (char) byte;
	}while(value != 0);

	return out;
}

static char *pmmp_perf_write_unsigned_varint32_to_ptr(char *out, uint32_t value)
{
	do{
		unsigned char byte = (unsigned char) (value & 0x7f);
		value >>= 7;
		if(value != 0){
			byte |= 0x80;
		}
		*out++ = (char) byte;
	}while(value != 0);

	return out;
}

static void pmmp_perf_write_unsigned_varint(smart_str *out, size_t value)
{
	do{
		unsigned char byte = (unsigned char) (value & 0x7f);
		value >>= 7;
		if(value != 0){
			byte |= 0x80;
		}
		smart_str_appendc(out, (char) byte);
	}while(value != 0);
}

static void pmmp_perf_write_unsigned_varint32(smart_str *out, uint32_t value)
{
	do{
		unsigned char byte = (unsigned char) (value & 0x7f);
		value >>= 7;
		if(value != 0){
			byte |= 0x80;
		}
		smart_str_appendc(out, (char) byte);
	}while(value != 0);
}

PHP_FUNCTION(pmmp_perf_varint_prefix_length)
{
	zend_long length;
	zend_long prefix_length = 1;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_LONG(length)
	ZEND_PARSE_PARAMETERS_END();

	if(length < 0){
		zend_argument_value_error(1, "must be greater than or equal to 0");
		RETURN_THROWS();
	}

	while(length >= 128){
		length >>= 7;
		++prefix_length;
	}

	RETURN_LONG(prefix_length);
}

PHP_FUNCTION(pmmp_perf_build_info)
{
	array_init(return_value);
	add_assoc_string(return_value, "name", "pmmp_perf_ext");
	add_assoc_string(return_value, "version", PHP_PMMP_PERF_EXT_VERSION);
	add_assoc_string(return_value, "purpose", "PMMP hot path native PoC");
}

PHP_FUNCTION(pmmp_perf_encode_packet_batch)
{
	zval *packets;
	zval *lengths = NULL;
	zval *packet;
	zend_ulong index;
	zend_string *key;
	size_t packet_count;
	bool validate_lengths;
	size_t output_capacity = 0;
	zend_string *out;
	char *out_ptr;

	ZEND_PARSE_PARAMETERS_START(1, 2)
		Z_PARAM_ARRAY(packets)
		Z_PARAM_OPTIONAL
		Z_PARAM_ARRAY_OR_NULL(lengths)
	ZEND_PARSE_PARAMETERS_END();

	packet_count = zend_hash_num_elements(Z_ARRVAL_P(packets));
	if(lengths != NULL && Z_TYPE_P(lengths) != IS_NULL && zend_hash_num_elements(Z_ARRVAL_P(lengths)) != packet_count){
		zend_argument_value_error(2, "must have the same number of elements as argument #1 ($packets)");
		RETURN_THROWS();
	}
	if(packet_count == 0){
		RETURN_EMPTY_STRING();
	}

	validate_lengths = lengths != NULL && Z_TYPE_P(lengths) != IS_NULL;
	ZEND_HASH_FOREACH_KEY_VAL(Z_ARRVAL_P(packets), index, key, packet){
		zval *length_zv = NULL;
		size_t packet_length;

		if(Z_TYPE_P(packet) != IS_STRING){
			zend_argument_type_error(1, "must contain only strings");
			RETURN_THROWS();
		}

		packet_length = Z_STRLEN_P(packet);
		if(validate_lengths){
			length_zv = key == NULL ? zend_hash_index_find(Z_ARRVAL_P(lengths), index) : zend_hash_find(Z_ARRVAL_P(lengths), key);
			if(length_zv == NULL || Z_TYPE_P(length_zv) != IS_LONG || Z_LVAL_P(length_zv) < 0 || (size_t) Z_LVAL_P(length_zv) != packet_length){
				zend_argument_value_error(2, "must contain non-negative lengths matching argument #1 ($packets)");
				RETURN_THROWS();
			}
		}

		if(packet_length > SIZE_MAX - output_capacity - 5){
			zend_argument_value_error(1, "is too large to encode");
			RETURN_THROWS();
		}
		output_capacity += packet_length + pmmp_perf_unsigned_varint_length(packet_length);
	}ZEND_HASH_FOREACH_END();

	out = zend_string_alloc(output_capacity, 0);
	out_ptr = ZSTR_VAL(out);

	ZEND_HASH_FOREACH_KEY_VAL(Z_ARRVAL_P(packets), index, key, packet){
		size_t packet_length;

		packet_length = Z_STRLEN_P(packet);
		out_ptr = pmmp_perf_write_unsigned_varint_to_ptr(out_ptr, packet_length);
		memcpy(out_ptr, Z_STRVAL_P(packet), packet_length);
		out_ptr += packet_length;
	}ZEND_HASH_FOREACH_END();

	ZSTR_VAL(out)[output_capacity] = '\0';
	RETURN_STR(out);
}

PHP_FUNCTION(pmmp_perf_encode_packet_single)
{
	zend_string *packet;
	zend_long length;
	size_t packet_length;
	size_t output_capacity;
	zend_string *out;
	char *out_ptr;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_STR(packet)
		Z_PARAM_LONG(length)
	ZEND_PARSE_PARAMETERS_END();

	if(length < 0){
		zend_argument_value_error(2, "must be greater than or equal to 0");
		RETURN_THROWS();
	}

	packet_length = ZSTR_LEN(packet);
	if((size_t) length != packet_length){
		zend_argument_value_error(2, "must match argument #1 ($packet) length");
		RETURN_THROWS();
	}

	if(packet_length > SIZE_MAX - 5){
		zend_argument_value_error(1, "is too large to encode");
		RETURN_THROWS();
	}
	output_capacity = packet_length + pmmp_perf_unsigned_varint_length(packet_length);

	out = zend_string_alloc(output_capacity, 0);
	out_ptr = pmmp_perf_write_unsigned_varint_to_ptr(ZSTR_VAL(out), packet_length);
	memcpy(out_ptr, ZSTR_VAL(packet), packet_length);
	ZSTR_VAL(out)[output_capacity] = '\0';
	RETURN_STR(out);
}

PHP_FUNCTION(pmmp_perf_encode_signed_varints)
{
	zval *values;
	zval *value;
	size_t value_count;
	zend_string *out;
	char *out_ptr;
	size_t output_length;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY(values)
	ZEND_PARSE_PARAMETERS_END();

	value_count = zend_hash_num_elements(Z_ARRVAL_P(values));
	if(value_count == 0){
		RETURN_EMPTY_STRING();
	}
	if(value_count > SIZE_MAX / 5){
		zend_argument_value_error(1, "is too large to encode");
		RETURN_THROWS();
	}
	out = zend_string_alloc(value_count * 5, 0);
	out_ptr = ZSTR_VAL(out);

	ZEND_HASH_FOREACH_VAL(Z_ARRVAL_P(values), value){
		zend_long signed_value;
		int32_t int_value;
		uint32_t encoded_value;

		if(Z_TYPE_P(value) != IS_LONG){
			zend_argument_type_error(1, "must contain only integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		signed_value = Z_LVAL_P(value);
		if(signed_value < INT32_MIN || signed_value > INT32_MAX){
			zend_argument_value_error(1, "must contain only 32-bit signed integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		int_value = (int32_t) signed_value;
		encoded_value = ((uint32_t) int_value << 1) ^ (uint32_t) (int_value >> 31);
		out_ptr = pmmp_perf_write_unsigned_varint32_to_ptr(out_ptr, encoded_value);
	}ZEND_HASH_FOREACH_END();

	output_length = (size_t) (out_ptr - ZSTR_VAL(out));
	out = zend_string_truncate(out, output_length, 0);
	ZSTR_VAL(out)[output_length] = '\0';
	RETURN_STR(out);
}

PHP_FUNCTION(pmmp_perf_encode_biome_palette)
{
	zval *values;
	zval *known_biome_ids;
	zval *value;
	zend_long fallback_biome_id;
	size_t value_count;
	zend_string *out;
	char *out_ptr;
	size_t output_length;

	ZEND_PARSE_PARAMETERS_START(3, 3)
		Z_PARAM_ARRAY(values)
		Z_PARAM_ARRAY(known_biome_ids)
		Z_PARAM_LONG(fallback_biome_id)
	ZEND_PARSE_PARAMETERS_END();

	if(fallback_biome_id < INT32_MIN || fallback_biome_id > INT32_MAX){
		zend_argument_value_error(3, "must be a 32-bit signed integer");
		RETURN_THROWS();
	}

	value_count = zend_hash_num_elements(Z_ARRVAL_P(values));
	if(value_count == 0){
		RETURN_EMPTY_STRING();
	}
	if(value_count > SIZE_MAX / 5){
		zend_argument_value_error(1, "is too large to encode");
		RETURN_THROWS();
	}
	out = zend_string_alloc(value_count * 5, 0);
	out_ptr = ZSTR_VAL(out);

	ZEND_HASH_FOREACH_VAL(Z_ARRVAL_P(values), value){
		zend_long signed_value;
		int32_t int_value;
		uint32_t encoded_value;

		if(Z_TYPE_P(value) != IS_LONG){
			zend_argument_type_error(1, "must contain only integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		signed_value = Z_LVAL_P(value);
		if(signed_value < INT32_MIN || signed_value > INT32_MAX){
			zend_argument_value_error(1, "must contain only 32-bit signed integers");
			zend_string_release(out);
			RETURN_THROWS();
		}
		if(!zend_hash_index_exists(Z_ARRVAL_P(known_biome_ids), (zend_ulong) signed_value)){
			signed_value = fallback_biome_id;
		}

		int_value = (int32_t) signed_value;
		encoded_value = ((uint32_t) int_value << 1) ^ (uint32_t) (int_value >> 31);
		out_ptr = pmmp_perf_write_unsigned_varint32_to_ptr(out_ptr, encoded_value);
	}ZEND_HASH_FOREACH_END();

	output_length = (size_t) (out_ptr - ZSTR_VAL(out));
	out = zend_string_truncate(out, output_length, 0);
	ZSTR_VAL(out)[output_length] = '\0';
	RETURN_STR(out);
}

PHP_FUNCTION(pmmp_perf_encode_mapped_signed_varints)
{
	zval *values;
	zval *map;
	zval *value;
	size_t value_count;
	zend_string *out;
	char *out_ptr;
	size_t output_length;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_ARRAY(values)
		Z_PARAM_ARRAY(map)
	ZEND_PARSE_PARAMETERS_END();

	value_count = zend_hash_num_elements(Z_ARRVAL_P(values));
	if(value_count == 0){
		RETURN_EMPTY_STRING();
	}
	if(value_count > SIZE_MAX / 5){
		zend_argument_value_error(1, "is too large to encode");
		RETURN_THROWS();
	}
	out = zend_string_alloc(value_count * 5, 0);
	out_ptr = ZSTR_VAL(out);

	ZEND_HASH_FOREACH_VAL(Z_ARRVAL_P(values), value){
		zend_long source_value;
		zval *mapped_zv;
		zend_long mapped_value;
		int32_t int_value;
		uint32_t encoded_value;

		if(Z_TYPE_P(value) != IS_LONG){
			zend_argument_type_error(1, "must contain only integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		source_value = Z_LVAL_P(value);
		if(source_value < 0){
			zend_string_release(out);
			RETURN_NULL();
		}

		mapped_zv = zend_hash_index_find(Z_ARRVAL_P(map), (zend_ulong) source_value);
		if(mapped_zv == NULL){
			zend_string_release(out);
			RETURN_NULL();
		}
		if(Z_TYPE_P(mapped_zv) != IS_LONG){
			zend_argument_type_error(2, "must contain only integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		mapped_value = Z_LVAL_P(mapped_zv);
		if(mapped_value < INT32_MIN || mapped_value > INT32_MAX){
			zend_argument_value_error(2, "must contain only 32-bit signed integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		int_value = (int32_t) mapped_value;
		encoded_value = ((uint32_t) int_value << 1) ^ (uint32_t) (int_value >> 31);
		out_ptr = pmmp_perf_write_unsigned_varint32_to_ptr(out_ptr, encoded_value);
	}ZEND_HASH_FOREACH_END();

	output_length = (size_t) (out_ptr - ZSTR_VAL(out));
	out = zend_string_truncate(out, output_length, 0);
	ZSTR_VAL(out)[output_length] = '\0';
	RETURN_STR(out);
}

PHP_FUNCTION(pmmp_perf_pack_u32le)
{
	zval *values;
	zval *value;
	size_t value_count;
	zend_string *out;
	char *out_ptr;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_ARRAY(values)
	ZEND_PARSE_PARAMETERS_END();

	value_count = zend_hash_num_elements(Z_ARRVAL_P(values));
	if(value_count == 0){
		RETURN_EMPTY_STRING();
	}
	if(value_count > SIZE_MAX / 4){
		zend_argument_value_error(1, "is too large to encode");
		RETURN_THROWS();
	}
	out = zend_string_alloc(value_count * 4, 0);
	out_ptr = ZSTR_VAL(out);

	ZEND_HASH_FOREACH_VAL(Z_ARRVAL_P(values), value){
		zend_long long_value;
		uint32_t int_value;

		if(Z_TYPE_P(value) != IS_LONG){
			zend_argument_type_error(1, "must contain only integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		long_value = Z_LVAL_P(value);
		if(long_value < 0 || long_value > UINT32_MAX){
			zend_argument_value_error(1, "must contain only 32-bit unsigned integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		int_value = (uint32_t) long_value;
		*out_ptr++ = (char) (int_value & 0xff);
		*out_ptr++ = (char) ((int_value >> 8) & 0xff);
		*out_ptr++ = (char) ((int_value >> 16) & 0xff);
		*out_ptr++ = (char) ((int_value >> 24) & 0xff);
	}ZEND_HASH_FOREACH_END();

	ZSTR_VAL(out)[value_count * 4] = '\0';
	RETURN_STR(out);
}

PHP_FUNCTION(pmmp_perf_unpack_u32le)
{
	zend_string *data;
	const unsigned char *bytes;
	size_t length;
	size_t count;
	size_t offset = 0;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_STR(data)
	ZEND_PARSE_PARAMETERS_END();

	length = ZSTR_LEN(data);
	if((length & 3) != 0){
		zend_argument_value_error(1, "length must be a multiple of 4");
		RETURN_THROWS();
	}
	if(length == 0){
		RETURN_EMPTY_ARRAY();
	}

	count = length / 4;
	if(count > UINT32_MAX){
		zend_argument_value_error(1, "contains too many integers to decode");
		RETURN_THROWS();
	}
	bytes = (const unsigned char *) ZSTR_VAL(data);
	array_init_size(return_value, (uint32_t) count);
	for(; offset < length; offset += 4){
		uint32_t value = ((uint32_t) bytes[offset]) |
			((uint32_t) bytes[offset + 1] << 8) |
			((uint32_t) bytes[offset + 2] << 16) |
			((uint32_t) bytes[offset + 3] << 24);
		add_next_index_long(return_value, (zend_long) value);
	}
}

PHP_FUNCTION(pmmp_perf_serialize_fast_paletted_array)
{
	zend_long bits_per_block;
	zend_string *word_array;
	zval *palette;
	zval *value;
	size_t word_length;
	size_t palette_count;
	size_t palette_bytes;
	size_t output_capacity;
	zend_string *out;
	char *out_ptr;

	ZEND_PARSE_PARAMETERS_START(3, 3)
		Z_PARAM_LONG(bits_per_block)
		Z_PARAM_STR(word_array)
		Z_PARAM_ARRAY(palette)
	ZEND_PARSE_PARAMETERS_END();

	if(bits_per_block < 0 || bits_per_block > UINT8_MAX){
		zend_argument_value_error(1, "must fit in one unsigned byte");
		RETURN_THROWS();
	}

	word_length = ZSTR_LEN(word_array);
	palette_count = zend_hash_num_elements(Z_ARRVAL_P(palette));
	if(palette_count > UINT32_MAX / 4){
		zend_argument_value_error(3, "is too large to encode");
		RETURN_THROWS();
	}
	palette_bytes = palette_count * 4;
	if(word_length > SIZE_MAX - 5 || palette_bytes > SIZE_MAX - 5 - word_length){
		zend_argument_value_error(2, "is too large to encode");
		RETURN_THROWS();
	}
	output_capacity = 1 + word_length + 4 + palette_bytes;
	out = zend_string_alloc(output_capacity, 0);
	out_ptr = ZSTR_VAL(out);

	*out_ptr++ = (char) bits_per_block;
	memcpy(out_ptr, ZSTR_VAL(word_array), word_length);
	out_ptr += word_length;
	*out_ptr++ = (char) ((palette_bytes >> 24) & 0xff);
	*out_ptr++ = (char) ((palette_bytes >> 16) & 0xff);
	*out_ptr++ = (char) ((palette_bytes >> 8) & 0xff);
	*out_ptr++ = (char) (palette_bytes & 0xff);

	ZEND_HASH_FOREACH_VAL(Z_ARRVAL_P(palette), value){
		zend_long long_value;
		uint32_t int_value;

		if(Z_TYPE_P(value) != IS_LONG){
			zend_argument_type_error(3, "must contain only integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		long_value = Z_LVAL_P(value);
		if(long_value < 0 || long_value > UINT32_MAX){
			zend_argument_value_error(3, "must contain only 32-bit unsigned integers");
			zend_string_release(out);
			RETURN_THROWS();
		}

		int_value = (uint32_t) long_value;
		*out_ptr++ = (char) (int_value & 0xff);
		*out_ptr++ = (char) ((int_value >> 8) & 0xff);
		*out_ptr++ = (char) ((int_value >> 16) & 0xff);
		*out_ptr++ = (char) ((int_value >> 24) & 0xff);
	}ZEND_HASH_FOREACH_END();

	ZSTR_VAL(out)[output_capacity] = '\0';
	RETURN_STR(out);
}

static bool pmmp_perf_fast_paletted_word_length(unsigned char bits_per_block, size_t *word_length)
{
	size_t values_per_word;
	size_t word_count;

	if(bits_per_block == 0){
		*word_length = 0;
		return true;
	}
	if(bits_per_block > 32){
		return false;
	}
	values_per_word = 32 / bits_per_block;
	if(values_per_word == 0){
		return false;
	}
	word_count = (4096 + values_per_word - 1) / values_per_word;
	if(word_count > SIZE_MAX / 4){
		return false;
	}
	*word_length = word_count * 4;
	return true;
}

PHP_FUNCTION(pmmp_perf_read_fast_paletted_array)
{
	zend_string *data;
	zend_long offset_arg;
	const unsigned char *bytes;
	size_t length;
	size_t offset;
	size_t word_length;
	size_t palette_bytes;
	size_t palette_count;
	size_t palette_offset;
	size_t i;
	unsigned char bits_per_block;
	zval palette;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_STR(data)
		Z_PARAM_LONG(offset_arg)
	ZEND_PARSE_PARAMETERS_END();

	if(offset_arg < 0){
		zend_argument_value_error(2, "must be greater than or equal to 0");
		RETURN_THROWS();
	}

	bytes = (const unsigned char *) ZSTR_VAL(data);
	length = ZSTR_LEN(data);
	offset = (size_t) offset_arg;
	if(offset >= length){
		zend_argument_value_error(2, "exceeds data length");
		RETURN_THROWS();
	}

	bits_per_block = bytes[offset++];
	if(!pmmp_perf_fast_paletted_word_length(bits_per_block, &word_length)){
		zend_value_error("Invalid bits-per-block value");
		RETURN_THROWS();
	}
	if(word_length > length - offset){
		zend_value_error("Fast paletted-array word data exceeds remaining bytes");
		RETURN_THROWS();
	}

	palette_offset = offset + word_length;
	if(4 > length - palette_offset){
		zend_value_error("Fast paletted-array palette length is truncated");
		RETURN_THROWS();
	}
	palette_bytes = ((size_t) bytes[palette_offset] << 24) |
		((size_t) bytes[palette_offset + 1] << 16) |
		((size_t) bytes[palette_offset + 2] << 8) |
		(size_t) bytes[palette_offset + 3];
	palette_offset += 4;
	if((palette_bytes & 3) != 0){
		zend_value_error("Fast paletted-array palette length must be a multiple of 4");
		RETURN_THROWS();
	}
	if(palette_bytes > length - palette_offset){
		zend_value_error("Fast paletted-array palette data exceeds remaining bytes");
		RETURN_THROWS();
	}

	palette_count = palette_bytes / 4;
	if(palette_count > UINT32_MAX){
		zend_value_error("Fast paletted-array palette contains too many integers");
		RETURN_THROWS();
	}

	array_init_size(&palette, (uint32_t) palette_count);
	for(i = 0; i < palette_bytes; i += 4){
		size_t at = palette_offset + i;
		uint32_t value = ((uint32_t) bytes[at]) |
			((uint32_t) bytes[at + 1] << 8) |
			((uint32_t) bytes[at + 2] << 16) |
			((uint32_t) bytes[at + 3] << 24);
		add_next_index_long(&palette, (zend_long) value);
	}

	array_init_size(return_value, 4);
	add_next_index_long(return_value, (zend_long) bits_per_block);
	add_next_index_stringl(return_value, (const char *) bytes + offset, word_length);
	add_next_index_zval(return_value, &palette);
	add_next_index_long(return_value, (zend_long) (palette_offset + palette_bytes));
}

PHP_FUNCTION(pmmp_perf_decode_packet_batch)
{
	zend_string *batch;
	const unsigned char *data;
	size_t length;
	size_t offset = 0;
	zend_long packet_index = 0;

	ZEND_PARSE_PARAMETERS_START(1, 1)
		Z_PARAM_STR(batch)
	ZEND_PARSE_PARAMETERS_END();

	data = (const unsigned char *) ZSTR_VAL(batch);
	length = ZSTR_LEN(batch);
	array_init_size(return_value, 8);

	while(offset < length){
		size_t packet_length = 0;
		uint32_t shift = 0;
		unsigned char byte;

		do{
			if(offset >= length){
				zend_value_error("Truncated VarInt length at packet " ZEND_LONG_FMT, packet_index);
				zval_ptr_dtor(return_value);
				RETURN_THROWS();
			}
			if(shift >= 35){
				zend_value_error("VarInt length too large at packet " ZEND_LONG_FMT, packet_index);
				zval_ptr_dtor(return_value);
				RETURN_THROWS();
			}
			byte = data[offset++];
			packet_length |= ((size_t) (byte & 0x7f)) << shift;
			shift += 7;
		}while((byte & 0x80) != 0);

		if(packet_length > length - offset){
			zend_value_error("Packet " ZEND_LONG_FMT " length exceeds remaining batch data", packet_index);
			zval_ptr_dtor(return_value);
			RETURN_THROWS();
		}

		add_next_index_stringl(return_value, (const char *) data + offset, packet_length);
		offset += packet_length;
		++packet_index;
	}
}

PHP_FUNCTION(pmmp_perf_decode_packet_batch_callback)
{
	zend_string *batch;
	zend_fcall_info fci;
	zend_fcall_info_cache fcc;
	const unsigned char *data;
	size_t length;
	size_t offset = 0;
	zend_long packet_index = 0;

	ZEND_PARSE_PARAMETERS_START(2, 2)
		Z_PARAM_STR(batch)
		Z_PARAM_FUNC(fci, fcc)
	ZEND_PARSE_PARAMETERS_END();

	data = (const unsigned char *) ZSTR_VAL(batch);
	length = ZSTR_LEN(batch);

	while(offset < length){
		size_t packet_length = 0;
		uint32_t shift = 0;
		unsigned char byte;
		zval params[2];
		zval retval;
		bool keep_going;

		do{
			if(offset >= length){
				zend_value_error("Truncated VarInt length at packet " ZEND_LONG_FMT, packet_index);
				RETURN_THROWS();
			}
			if(shift >= 35){
				zend_value_error("VarInt length too large at packet " ZEND_LONG_FMT, packet_index);
				RETURN_THROWS();
			}
			byte = data[offset++];
			packet_length |= ((size_t) (byte & 0x7f)) << shift;
			shift += 7;
		}while((byte & 0x80) != 0);

		if(packet_length > length - offset){
			zend_value_error("Packet " ZEND_LONG_FMT " length exceeds remaining batch data", packet_index);
			RETURN_THROWS();
		}

		ZVAL_STRINGL(&params[0], (const char *) data + offset, packet_length);
		ZVAL_LONG(&params[1], packet_index);
		ZVAL_UNDEF(&retval);

		fci.params = params;
		fci.param_count = 2;
		fci.retval = &retval;

		if(zend_call_function(&fci, &fcc) == FAILURE){
			zval_ptr_dtor(&params[0]);
			zend_throw_error(NULL, "Failed to call packet batch callback");
			RETURN_THROWS();
		}

		zval_ptr_dtor(&params[0]);
		if(EG(exception)){
			if(!Z_ISUNDEF(retval)){
				zval_ptr_dtor(&retval);
			}
			RETURN_THROWS();
		}

		keep_going = zend_is_true(&retval);
		zval_ptr_dtor(&retval);

		offset += packet_length;
		++packet_index;
		if(!keep_going){
			RETURN_LONG(packet_index);
		}
	}

	RETURN_LONG(packet_index);
}

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_varint_prefix_length, 0, 1, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, length, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_build_info, 0, 0, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_encode_packet_batch, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, packets, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, lengths, IS_ARRAY, 1, "null")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_encode_packet_single, 0, 2, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, packet, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, length, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_encode_signed_varints, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_encode_biome_palette, 0, 3, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, knownBiomeIds, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, fallbackBiomeId, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_encode_mapped_signed_varints, 0, 2, IS_STRING, 1)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, map, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_pack_u32le, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, values, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_unpack_u32le, 0, 1, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, data, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_serialize_fast_paletted_array, 0, 3, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, bitsPerBlock, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, wordArray, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, palette, IS_ARRAY, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_read_fast_paletted_array, 0, 2, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, data, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, offset, IS_LONG, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_decode_packet_batch, 0, 1, IS_ARRAY, 0)
	ZEND_ARG_TYPE_INFO(0, batch, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_pmmp_perf_decode_packet_batch_callback, 0, 2, IS_LONG, 0)
	ZEND_ARG_TYPE_INFO(0, batch, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, callback, IS_CALLABLE, 0)
ZEND_END_ARG_INFO()

static const zend_function_entry pmmp_perf_ext_functions[] = {
	PHP_FE(pmmp_perf_varint_prefix_length, arginfo_pmmp_perf_varint_prefix_length)
	PHP_FE(pmmp_perf_build_info, arginfo_pmmp_perf_build_info)
	PHP_FE(pmmp_perf_encode_packet_batch, arginfo_pmmp_perf_encode_packet_batch)
	PHP_FE(pmmp_perf_encode_packet_single, arginfo_pmmp_perf_encode_packet_single)
	PHP_FE(pmmp_perf_encode_signed_varints, arginfo_pmmp_perf_encode_signed_varints)
	PHP_FE(pmmp_perf_encode_biome_palette, arginfo_pmmp_perf_encode_biome_palette)
	PHP_FE(pmmp_perf_encode_mapped_signed_varints, arginfo_pmmp_perf_encode_mapped_signed_varints)
	PHP_FE(pmmp_perf_pack_u32le, arginfo_pmmp_perf_pack_u32le)
	PHP_FE(pmmp_perf_unpack_u32le, arginfo_pmmp_perf_unpack_u32le)
	PHP_FE(pmmp_perf_serialize_fast_paletted_array, arginfo_pmmp_perf_serialize_fast_paletted_array)
	PHP_FE(pmmp_perf_read_fast_paletted_array, arginfo_pmmp_perf_read_fast_paletted_array)
	PHP_FE(pmmp_perf_decode_packet_batch, arginfo_pmmp_perf_decode_packet_batch)
	PHP_FE(pmmp_perf_decode_packet_batch_callback, arginfo_pmmp_perf_decode_packet_batch_callback)
	PHP_FE_END
};

zend_module_entry pmmp_perf_ext_module_entry = {
	STANDARD_MODULE_HEADER,
	"pmmp_perf_ext",
	pmmp_perf_ext_functions,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	PHP_PMMP_PERF_EXT_VERSION,
	STANDARD_MODULE_PROPERTIES
};

#ifdef COMPILE_DL_PMMP_PERF_EXT
# ifdef ZTS
ZEND_TSRMLS_CACHE_DEFINE()
# endif
ZEND_GET_MODULE(pmmp_perf_ext)
#endif
