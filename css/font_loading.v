// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// CSS/FontLoading.cpp: format dispatch and vector-font preparation.
module css

import encoding.binary
import gfxfont
import platform
import skia

pub fn requires_off_thread_vector_font_preparation(data []u8, mime_type_essence ?string) bool {
	if mime := mime_type_essence {
		if mime in ['font/woff2', 'application/font-woff2'] { return true }
	}
	if data.len < 4 { return false }
	return binary.big_endian_u32(data) == 0x774f4632
}

fn font_typeface_from_prepared_bytes(data []u8, family_name string) !&PlatformTypeface {
	if !skia.font_typeface_is_valid(data, 0) { return error('Failed to load font') }
	path := platform.cache_prepared_font_data(data) or {
		return error('Failed to retain prepared font')
	}
	return &PlatformTypeface{
		family_name: family_name.clone()
		source_path: path.clone()
	}
}

pub fn try_load_vector_font(data []u8, mime_type_essence ?string, family_name string) !&PlatformTypeface {
	if mime := mime_type_essence {
		match mime {
			'font/ttf', 'application/x-font-ttf', 'font/otf' {
				return font_typeface_from_prepared_bytes(data, family_name)
			}
			'font/woff', 'application/font-woff', 'font/x-woff' {
				return font_typeface_from_prepared_bytes(gfxfont.convert_woff_to_sfnt(data)!,
					family_name)
			}
			'font/woff2', 'application/font-woff2' {
				return font_typeface_from_prepared_bytes(gfxfont.convert_woff2_to_sfnt(data)!,
					family_name)
			}
			else {}
		}
	} else {
		if result := font_typeface_from_prepared_bytes(data, family_name) { return result }
		if converted := gfxfont.convert_woff_to_sfnt(data) {
			if result := font_typeface_from_prepared_bytes(converted, family_name) { return result }
		}
		if converted := gfxfont.convert_woff2_to_sfnt(data) {
			if result := font_typeface_from_prepared_bytes(converted, family_name) { return result }
		}
	}
	return error('Automatic format detection failed')
}
