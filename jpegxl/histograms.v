// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

type EntropyCodes = AnsCodes | HuffmanCodes

struct Lz77Params {
	enabled    bool
	min_symbol u32
	min_length u32
}

pub struct Histograms {
	lz77              Lz77Params
	length_uint       HybridUint
	distance_cluster  int
	log_alphabet_size int
	uint_configs      []HybridUint
	codes             EntropyCodes
mut:
	context_map []u8
}

fn (codes EntropyCodes) single_symbol(context int) ?u32 {
	return match codes {
		AnsCodes { codes.single_symbol(context) }
		HuffmanCodes { codes.single_symbol(context) }
	}
}

fn (codes EntropyCodes) max_symbol_for_cluster(context int) !u32 {
	return match codes {
		AnsCodes { codes.max_symbol_for_cluster(context)! }
		HuffmanCodes { codes.max_symbol_for_cluster(context)! }
	}
}

pub fn (mut reader BitReader) read_histograms(contexts int, allow_lz77 bool) !Histograms {
	return reader.read_histograms_depth(contexts, allow_lz77, 0)
}

fn (mut reader BitReader) read_histograms_depth(contexts int, allow_lz77 bool, depth int) !Histograms {
	if contexts < 1 || contexts > 65536 || depth > 16 {
		return error('Invalid JPEG XL histogram dimensions')
	}
	enabled := reader.read(1)! != 0
	mut minimum_symbol := u32(0)
	mut minimum_length := u32(0)
	if enabled {
		minimum_symbol = reader.read_u32([U32Code{ offset: 224 }, U32Code{ offset: 512 },
			U32Code{ offset: 4096 }, U32Code{ bits: 15, offset: 8 }]!)!
		minimum_length = reader.read_u32([U32Code{ offset: 3 }, U32Code{ offset: 4 },
			U32Code{ bits: 2, offset: 5 }, U32Code{ bits: 8, offset: 9 }]!)!
	}
	if enabled && !allow_lz77 { return error('LZ77 is disallowed in this JPEG XL context') }
	mut length_uint := HybridUint{}
	if enabled { length_uint = reader.read_hybrid_uint(8)! }
	count := contexts + if enabled { 1 } else { 0 }
	context_map := if count > 1 {
		reader.read_context_map_depth(count, depth + 1)!
	} else {
		[u8(0)]
	}
	distance_cluster := if enabled { int(context_map.last()) } else { 0 }
	prefix := reader.read(1)! != 0
	log_alphabet_size := if prefix { 15 } else { int(reader.read(2)!) + 5 }
	mut clusters := 0
	for cluster in context_map { clusters = math.max(clusters, int(cluster) + 1) }
	mut configs := []HybridUint{cap: clusters}
	for _ in 0 .. clusters { configs << reader.read_hybrid_uint(log_alphabet_size)! }
	codes := if prefix {
		EntropyCodes(reader.read_huffman_codes(clusters)!)
	} else {
		EntropyCodes(reader.read_ans_codes(clusters, log_alphabet_size)!)
	}
	return Histograms{
		lz77:              Lz77Params{ enabled: enabled, min_symbol: minimum_symbol, min_length: minimum_length }
		length_uint:       length_uint
		context_map:       context_map
		distance_cluster:  distance_cluster
		log_alphabet_size: log_alphabet_size
		uint_configs:      configs
		codes:             codes
	}
}

pub fn (hist Histograms) map_context_to_cluster(context int) !int {
	if context < 0 || context >= hist.context_map.len {
		return error('Invalid JPEG XL entropy context')
	}
	return int(hist.context_map[context])
}

pub fn (hist Histograms) num_histograms() int {
	mut count := 0
	for cluster in hist.context_map { count = math.max(count, int(cluster) + 1) }
	return count
}

pub fn (mut hist Histograms) resize(contexts int) ! {
	if contexts < 1 || contexts > 65536 { return error('Invalid JPEG XL entropy context count') }
	if contexts < hist.context_map.len {
		hist.context_map.trim(contexts)
	} else {
		hist.context_map << []u8{len: contexts - hist.context_map.len}
	}
}

pub fn (hist Histograms) can_use_config_420_fast_path() bool {
	return !hist.lz77.enabled && hist.uint_configs.all(it.split_exponent == 4 && it.msb_in_token == 2 && it.lsb_in_token == 0)
}

pub fn (hist Histograms) max_num_bits() !int {
	mut maximum := 0
	for cluster, config in hist.uint_configs {
		if hist.lz77.enabled && cluster == hist.distance_cluster { continue }
		mut symbol := hist.codes.max_symbol_for_cluster(cluster)!
		if hist.lz77.enabled { symbol = math.min(symbol, hist.lz77.min_symbol - 1) }
		maximum = math.max(maximum, config.max_bits_for_symbol(symbol))
	}
	return maximum
}

pub fn (hist Histograms) single_symbol(cluster int) ?u32 {
	return hist.codes.single_symbol(cluster)
}

pub fn (hist Histograms) is_rle() bool {
	if !hist.lz77.enabled { return false }
	symbol := hist.codes.single_symbol(hist.distance_cluster) or { return false }
	return symbol == 1 && hist.uint_configs[hist.distance_cluster].split_exponent == 0
}
