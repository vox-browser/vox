module main

import math
import os
import platform

const disable_glyph_content_keys = os.getenv('VOX_DISABLE_GLYPH_CONTENT_KEYS') != ''

// Layout forks retained glyph runs when rebuilding lines. Their allocation
// addresses change even when the face and every painted glyph stay equal.
// Compare the actual retained replay input, retaining conservative font-owner
// identity and exact position bits. Unpublished/dirty runs keep pointer keys.
fn srk_glyph_run(seed u64, run &platform.GlyphRun) u64 {
	indices := run.glyph_indices()
	positions := run.glyph_positions()
	if disable_glyph_content_keys || run.replay_data_dirty_ || run.font() == unsafe { nil }
		|| indices.len == 0 || positions.len != indices.len * 2 {
		return srk_ptr(seed, voidptr(run))
	}
	font := run.font()
	mut h := srk_ptr(srk_str(seed, 'retained-glyph-content'), voidptr(font))
	h = srk_str(h, font.font_path() or { '' })
	h = srk_int(h, font.face_index())
	h = srk_int(h, int(run.face()))
	h = srk_int(h, int(run.text_type()))
	axes := font.variations()
	h = srk_int(h, axes.len)
	for axis in axes {
		h = srk_mix(srk_mix(h, u64(axis.tag)), u64(math.f32_bits(axis.value)))
	}
	h = srk_int(h, indices.len)
	for index in indices { h = srk_mix(h, u64(index)) }
	h = srk_int(h, positions.len)
	for position in positions { h = srk_mix(h, math.f64_bits(position)) }
	return h
}
