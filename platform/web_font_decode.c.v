// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module platform

import crypto.sha256
import gfxfont
import os

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

// Retain the source decoder's prepared bytes for V's file-backed metrics and
// shaping boundary. Decoding belongs to LibGfx's WOFF/WOFF2 loader above it.
pub fn cache_prepared_font_data(data []u8) ?string {
	output_path := prepared_font_cache_path(data, 'ttf')
	if output_path == '' { return none }
	if !os.is_file(output_path) {
		os.write_file_array(output_path, data) or { return none }
	}
	return output_path
}

pub fn prepare_font_data(data []u8) ?string {
	if !is_sfnt_font_data(data) && !is_web_font_data(data) {
		return none
	}
	if is_sfnt_font_data(data) {
		return cache_prepared_font_data(data)
	}
	prepared := if data[..4].bytestr() == 'wOF2' {
		gfxfont.convert_woff2_to_sfnt(data) or { return none }
	} else {
		gfxfont.convert_woff_to_sfnt(data) or { return none }
	}
	return cache_prepared_font_data(prepared)
}

pub fn prepare_font_file(path string) ?string {
	data := os.read_bytes(path) or { return none }
	if is_sfnt_font_data(data) {
		return path
	}
	return prepare_font_data(data)
}
