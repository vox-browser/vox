module platform

import math
import os
import time

// Keep the former serialization as an independent oracle, including face
// selection, length prefixes, float bits, and unresolved-path behavior.
fn original_shaping_font_key(font &Font) string {
	resolved_path := font.font_path() or { '' }
	return '${font.family.len}:${font.family}|${font.source_path.len}:${font.source_path}|${resolved_path.len}:${resolved_path}|${font.weight}|${font.face_index()}|${math.f32_bits(font.point_size)}|${font.is_invisible}'
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
