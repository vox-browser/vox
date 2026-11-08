// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

pub struct SymbolReader {
	lz77_enabled bool
mut:
	lz77           Lz77State
	ans            AnsReader
	repeat_error   bool
	overflow_error bool
}

pub fn SymbolReader.new(hist Histograms, mut reader BitReader, image_width ?u32) !SymbolReader {
	ans := if hist.codes is AnsCodes { reader.read_ans_state()! } else { AnsReader{} }
	return SymbolReader{
		ans:          ans
		lz77_enabled: hist.lz77.enabled
		lz77:         Lz77State{ min_symbol: hist.lz77.min_symbol, min_length: hist.lz77.min_length, distance_multiplier: image_width or { u32(0) } }
	}
}

fn (mut symbols SymbolReader) token(hist Histograms, cluster int, mut reader BitReader) !u32 {
	codes := hist.codes
	return match codes {
		AnsCodes { symbols.ans.read(codes, cluster, mut reader)! }
		HuffmanCodes { codes.read(cluster, mut reader)! }
	}
}

pub fn (mut symbols SymbolReader) read_unsigned(hist Histograms, context int, mut reader BitReader) !u32 {
	cluster := hist.map_context_to_cluster(context)!
	return symbols.read_unsigned_clustered(hist, cluster, mut reader)
}

pub fn (mut symbols SymbolReader) read_signed(hist Histograms, context int, mut reader BitReader) !i32 {
	return unpack_signed(symbols.read_unsigned(hist, context, mut reader)!)
}

pub fn (mut symbols SymbolReader) read_signed_clustered(hist Histograms, cluster int, mut reader BitReader) !i32 {
	return unpack_signed(symbols.read_unsigned_clustered(hist, cluster, mut reader)!)
}

pub fn (mut symbols SymbolReader) read_unsigned_clustered(hist Histograms, cluster int, mut reader BitReader) !u32 {
	if cluster < 0 || cluster >= hist.uint_configs.len {
		return error('Invalid JPEG XL entropy cluster')
	}
	if symbols.lz77_enabled {
		if value := symbols.lz77.pull() {
			symbols.lz77.push(value)
			return value
		}
	}
	token := symbols.token(hist, cluster, mut reader)!
	if !symbols.lz77_enabled { return hist.uint_configs[cluster].read(token, mut reader) }
	if token < symbols.lz77.min_symbol {
		value := hist.uint_configs[cluster].read(token, mut reader)!
		symbols.lz77.push(value)
		return value
	}
	if symbols.lz77.decoded == 0 {
		symbols.repeat_error = true
		return 0
	}
	length := hist.length_uint.read(token - symbols.lz77.min_symbol, mut reader)!
	if length > u32(0xffffffff) - symbols.lz77.min_length {
		symbols.overflow_error = true
		return 0
	}
	distance_token := symbols.token(hist, hist.distance_cluster, mut reader)!
	distance := hist.uint_configs[hist.distance_cluster].read(distance_token, mut reader)!
	symbols.lz77.apply_copy(distance, length + symbols.lz77.min_length)
	value := symbols.lz77.pull() or { return error('Empty JPEG XL LZ77 copy') }
	symbols.lz77.push(value)
	return value
}

pub fn (symbols SymbolReader) check_final_state(hist Histograms, reader &BitReader) ! {
	if symbols.repeat_error { return error('Unexpected JPEG XL LZ77 repeat') }
	if symbols.overflow_error { return error('JPEG XL LZ77 arithmetic overflow') }
	reader.check_end()!
	if hist.codes is AnsCodes { symbols.ans.check_final_state()! }
}
