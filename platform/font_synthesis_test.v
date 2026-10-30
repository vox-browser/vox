module platform

fn test_font_synthesis_modes_do_not_alias_shape_or_font_identity() {
	base := &Font{ family: 'Arial', point_size: 16, italic: true, font_rendering_policy: .chromium }
	for flags in [u8(1), 2, 4, 8, 15] {
		variant := &Font{ ...base, font_synthesis_disabled: flags }
		assert !base.has_same_identity(variant)
		assert shaping_cache_font_key(base) != shaping_cache_font_key(variant)
		assert base.italic && variant.italic
		$if macos {
			first := base.system_face() or { panic('Arial unavailable') }
			second := variant.system_face() or { panic('Arial unavailable') }
			assert first.path == second.path && first.face_index == second.face_index
		}
	}
}
