module platform

import math
import os
import time

// Keep the former serialization as an independent oracle, including face
// selection, length prefixes, float bits, and unresolved-path behavior.
fn original_shaping_font_key(font &Font) string {
	resolved_path := font.font_path() or { '' }
	return '${font.family.len}:${font.family}|${font.source_path.len}:${font.source_path}|${resolved_path.len}:${resolved_path}|${font.weight}|${font.face_index()}|${math.f32_bits(font.point_size)}|${font.is_invisible}|${font.font_rendering_policy}|${font.synthesize_ascii_caps}'
}

fn test_shaping_font_keys_preserve_every_serialized_identity_field() {
	for bits in [u32(0), 0x80000000, 0x41800000, 0x41800001, 0x7fc00001, 0x7fc00002] {
		for family in ['Lucida Grande', 'lucida grande', 'A|B:𐐀'] {
			for weight in [400, 700] {
				for source in ['', 'explicit|source:face'] {
					for path in ['resolved|one', 'resolved:two'] {
						for invisible in [false, true] {
							font := &Font{
								family:         family
								point_size:     math.f32_from_bits(bits)
								weight:         weight
								source_path:    source
								is_invisible:   invisible
								resolved_path_: path
							}
							key := original_shaping_font_key(font)
							for _ in 0 .. 3 {
								assert shaping_cache_font_key(font) == key
							}
							// A newly allocated equivalent handle has the same key.
							equivalent := &Font{ ...font }
							assert shaping_cache_font_key(equivalent) == key
						}
					}
				}
			}
		}
	}
}

fn test_shaping_font_key_retries_an_explicit_source_that_appears_later() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(), 'vox-late-shape-key-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := &Font{ family: 'UnavailableShapeKeyTestFace', point_size: 16, source_path: path }
	before := original_shaping_font_key(font)
	for _ in 0 .. 3 {
		assert shaping_cache_font_key(font) == before
		assert font.resolved_path_ == ''
	}
	os.cp(source, path)!
	after := shaping_cache_font_key(font)
	assert after == original_shaping_font_key(font)
	assert after != before
	assert font.resolved_path_ == path
	os.rm(path)!
	gc_collect()
	assert shaping_cache_font_key(font) == after
	assert original_shaping_font_key(font) == after
}

fn test_shaping_font_key_reuse_preserves_public_shapes_and_baselines() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	for size in [f32(13), 16, 19.5] {
		for invisible in [false, true] {
			font := &Font{ family: 'ShapeKeyFace', point_size: size, source_path: source, is_invisible: invisible }
			for text in ['A', 'cache me  ', 'héllo 𐐀', 'אבג العربية'] {
				for text_type in [GlyphRunTextType.common, .ltr, .rtl] {
					for spacing in [f32(0), 1.25] {
						expected := shape_text_uncached(17, spacing, spacing / 2, text, font, text_type)
						for _ in 0 .. 3 {
							actual := shape_text_with_spacing(17, spacing, spacing / 2, text, font, text_type)
							assert actual.glyph_run.glyphs() == expected.glyph_run.glyphs()
							assert actual.trailing_whitespace == expected.trailing_whitespace
							assert shaping_cache_font_key(font) == original_shaping_font_key(font)
						}
					}
				}
			}
		}
	}
	gc_collect()
}

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn reset_shaping_font_key_memo_for_test() {
	last_shaping_font_key = unsafe { nil }
	for index in 0 .. max_shaping_font_keys {
		recent_shaping_font_keys[index] = unsafe { nil }
	}
	recent_shaping_font_key_count = 0
	next_shaping_font_key = 0
}

fn shaping_memo_test_font(index int) &Font {
	return &Font{
		family:         'Lucida Grande'
		point_size:     12.0 + f32(index) / 4.0
		weight:         if index % 2 == 0 { 400 } else { 700 }
		resolved_path_: 'memo-resolved-face'
	}
}

fn test_shaping_font_key_memo_reuses_interleaved_equivalent_handles_without_allocating() {
	reset_shaping_font_key_memo_for_test()
	mut fonts := []&Font{}
	mut equivalents := []&Font{}
	mut keys := []string{}
	for index in 0 .. max_shaping_font_keys {
		font := shaping_memo_test_font(index)
		fonts << font
		equivalents << &Font{
			...font
		}
		key := shaping_cache_font_key(font)
		assert key == original_shaping_font_key(font)
		keys << shaping_cache_font_key(font)
	}
	assert recent_shaping_font_key_count == max_shaping_font_keys
	gc_collect()
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for pass in 0 .. 20 {
		for index in 0 .. fonts.len {
			font := if pass % 2 == 0 { fonts[index] } else { equivalents[index] }
			key := shaping_cache_font_key(font)
			assert key == keys[index]
			// Retain the original key bytes instead of serializing a fresh key.
			assert key.str == keys[index].str
		}
	}
	$if gcboehm ? {
		assert C.GC_get_total_bytes() == before
	}
	assert recent_shaping_font_key_count == max_shaping_font_keys
	assert next_shaping_font_key == 0
}

fn test_shaping_font_key_memo_has_bounded_fifo_replacement_and_last_key_fast_path() {
	reset_shaping_font_key_memo_for_test()
	mut fonts := []&Font{}
	mut keys := []string{}
	for index in 0 .. max_shaping_font_keys {
		font := shaping_memo_test_font(index)
		fonts << font
		keys << shaping_cache_font_key(font)
	}
	// Hits refresh the last-key shortcut without inserting duplicate entries.
	assert shaping_cache_font_key(fonts[0]).str == keys[0].str
	assert next_shaping_font_key == 0
	assert shaping_cache_font_key(fonts[0]).str == keys[0].str
	assert recent_shaping_font_key_count == max_shaping_font_keys
	overflow := shaping_memo_test_font(max_shaping_font_keys)
	overflow_key := shaping_cache_font_key(overflow)
	assert overflow_key == original_shaping_font_key(overflow)
	assert next_shaping_font_key == 1
	assert recent_shaping_font_key_count == max_shaping_font_keys
	assert shaping_cache_font_key(fonts[1]).str == keys[1].str
	regenerated := shaping_cache_font_key(fonts[0])
	assert regenerated == keys[0]
	assert regenerated.str != keys[0].str
	assert next_shaping_font_key == 2
	assert shaping_cache_font_key(fonts[0]).str == regenerated.str
	assert recent_shaping_font_key_count == max_shaping_font_keys
	for index in max_shaping_font_keys + 1 .. 4 * max_shaping_font_keys {
		font := shaping_memo_test_font(index)
		assert shaping_cache_font_key(font) == original_shaping_font_key(font)
		assert recent_shaping_font_key_count == max_shaping_font_keys
		assert next_shaping_font_key >= 0 && next_shaping_font_key < max_shaping_font_keys
	}
}

fn test_shaping_font_key_memo_guard_preserves_all_value_identity_fields() {
	reset_shaping_font_key_memo_for_test()
	base := &Font{
		family:         'Lucida Grande'
		point_size:     16
		resolved_path_: 'face|one:1'
	}
	fonts := [base, &Font{
		...base
		family: 'lucida grande'
	}, &Font{
		...base
		family: 'other|family:𐐀'
	},
		&Font{
			...base
			weight: 700
		}, &Font{
			...base
			source_path: 'face:source|1'
		},
		&Font{
			...base
			resolved_path_: 'face|two:1'
		}, &Font{
			...base
			is_invisible: true
		},
		&Font{
			...base
			point_size: math.f32_from_bits(u32(0x41800001))
		}, &Font{
			...base
			point_size: math.f32_from_bits(u32(0x00000000))
		},
		&Font{
			...base
			point_size: math.f32_from_bits(u32(0x80000000))
		}, &Font{
			...base
			point_size: math.f32_from_bits(u32(0x7fc00001))
		},
		&Font{
			...base
			point_size: math.f32_from_bits(u32(0x7fc00002))
		}]
	mut keys := []string{}
	for font in fonts {
		key := shaping_cache_font_key(font)
		assert key == original_shaping_font_key(font)
		assert key !in keys
		keys << shaping_cache_font_key(font)
	}
	gc_collect()
	for _ in 0 .. 4 {
		for index in 0 .. fonts.len {
			// Each request returns to a non-last entry, including signed-zero and
			// NaN payload identities which cannot use floating-point equality.
			key := shaping_cache_font_key(&Font{ ...fonts[index] })
			assert key == original_shaping_font_key(fonts[index])
			assert key.str == keys[index].str
		}
	}
	assert recent_shaping_font_key_count == fonts.len
}

fn test_shaping_font_key_memo_keeps_retrying_missing_sources_without_caching_fallbacks() {
	reset_shaping_font_key_memo_for_test()
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(),
		'vox-late-memo-key-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := &Font{
		family:      'MissingMemoTestFace'
		point_size:  16
		source_path: path
	}
	fallback_key := original_shaping_font_key(font)
	for _ in 0 .. max_shaping_font_keys + 2 {
		assert shaping_cache_font_key(font) == fallback_key
		assert font.resolved_path_ == ''
		assert recent_shaping_font_key_count == 0
		assert isnil(last_shaping_font_key)
	}
	for index in 0 .. max_shaping_font_keys {
		_ = shaping_cache_font_key(shaping_memo_test_font(index))
	}
	for _ in 0 .. 3 {
		assert shaping_cache_font_key(font) == fallback_key
		assert font.resolved_path_ == ''
		assert recent_shaping_font_key_count == max_shaping_font_keys
		assert next_shaping_font_key == 0
	}
	os.cp(source, path)!
	resolved_key := shaping_cache_font_key(font)
	assert resolved_key == original_shaping_font_key(font)
	assert resolved_key != fallback_key
	assert font.resolved_path_ == path
	assert next_shaping_font_key == 1
	os.rm(path)!
	for index in 1 .. max_shaping_font_keys {
		_ = shaping_cache_font_key(shaping_memo_test_font(index))
		assert shaping_cache_font_key(&Font{ ...font }).str == resolved_key.str
	}
}
