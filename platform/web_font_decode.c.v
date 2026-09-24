// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module platform

import crypto.sha256
import os

#flag darwin -framework CoreFoundation
#flag darwin -framework CoreGraphics
#include "font_decode_bridge.h"

fn C.libweb_v_decode_web_font(input_path &char, output_path &char) int

fn is_sfnt_font_data(data []u8) bool {
	if data.len < 4 {
		return false
	}
	return (data[0] == 0 && data[1] == 1 && data[2] == 0 && data[3] == 0)
		|| data[..4].bytestr() in ['OTTO', 'ttcf']
}

fn is_web_font_data(data []u8) bool {
	return data.len >= 4 && data[..4].bytestr() in ['wOFF', 'wOF2']
}

fn prepared_font_cache_path(data []u8, suffix string) string {
	digest := sha256.sum(data).hex()
	directory := os.join_path(os.temp_dir(), 'ladybird-v-fonts-${os.getpid()}')
	os.mkdir_all(directory) or { return '' }
	return os.join_path(directory, '${digest}.${suffix}')
}

// Prepare a downloaded vector font for the file-backed metrics, shaping, and
// replay boundaries. sfnt data is retained verbatim. On macOS CoreGraphics
// performs the same WOFF/WOFF2 preparation step as upstream's decoder and the
// reconstructed sfnt is cached for the lifetime of this process.
pub fn prepare_font_data(data []u8) ?string {
	if !is_sfnt_font_data(data) && !is_web_font_data(data) {
		return none
	}
	output_path := prepared_font_cache_path(data, 'ttf')
	if output_path == '' {
		return none
	}
	if os.is_file(output_path) {
		return output_path
	}
	if is_sfnt_font_data(data) {
		os.write_file_array(output_path, data) or { return none }
		return output_path
	}
	input_path := prepared_font_cache_path(data, if data[..4].bytestr() == 'wOF2' { 'woff2' } else { 'woff' })
	if input_path == '' {
		return none
	}
	if !os.is_file(input_path) {
		os.write_file_array(input_path, data) or { return none }
	}
	if C.libweb_v_decode_web_font(input_path.str, output_path.str) == 0 || !os.is_file(output_path) {
		return none
	}
	return output_path
}

pub fn prepare_font_file(path string) ?string {
	data := os.read_bytes(path) or { return none }
	if is_sfnt_font_data(data) {
		return path
	}
	return prepare_font_data(data)
}
