module platform

fn test_canonical_system_fallback_owns_face_inputs_without_candidate_caches() {
	mut published := unsafe { &Font(nil) }
	mut arena := new_arena('fallback candidate input')
	entry := arena.enter()
	candidate := &Font{
		family:                'workspace-fallback-family'.clone()
		point_size:            23.125
		weight:                500
		font_rendering_policy: .chromium
		system_face_override:  SystemFontFace{
			path:            '/workspace-only/fallback-face.ttf'.clone()
			postscript_name: 'WorkspaceFallbackFace'.clone()
			family_name:     'Workspace fallback'.clone()
			face_index:      3
			weight:          500
			metrics:         SystemFontMetrics{ ascent: 17, descent: 5 }
			variations:      [FontVariationAxis{ tag: 0x77676874, value: 500 }]
		}
		resolved_path_:        '/workspace-only/derived-path.ttf'.clone()
		system_face_resolved_: true
		has_pixel_metrics_:    true
	}
	published = canonical_system_fallback_font(candidate)
	assert voidptr(published) != voidptr(candidate)
	original := candidate.system_face_override or { panic('missing input face') }
	owned := published.system_face_override or { panic('missing owned face') }
	assert voidptr(owned.path.str) != voidptr(original.path.str)
	assert voidptr(owned.postscript_name.str) != voidptr(original.postscript_name.str)
	assert voidptr(owned.family_name.str) != voidptr(original.family_name.str)
	assert owned.variations.data != original.variations.data
	arena.leave(entry)
	arena.release()

	face := published.system_face() or { panic('missing published face') }
	assert published.family == 'workspace-fallback-family'
	assert face.path == '/workspace-only/fallback-face.ttf'
	assert face.postscript_name == 'WorkspaceFallbackFace'
	assert face.family_name == 'Workspace fallback'
	assert face.face_index == 3 && face.weight == 500
	assert face.metrics.ascent == 17 && face.metrics.descent == 5
	assert face.variations.len == 1
	assert face.variations[0].tag == 0x77676874 && face.variations[0].value == 500
	assert published.resolved_path_ == ''
	assert !published.system_face_resolved_ && !published.has_pixel_metrics_
	assert published.decoded_face_ == unsafe { nil }
	assert published.harfbuzz_face_ == unsafe { nil }
	assert voidptr(canonical_system_fallback_font(published)) == voidptr(published)
}

fn test_system_fallback_cached_faces_survive_the_calling_workspace() {
	$if macos {
		base := &Font{
			family:                'SystemUi'
			point_size:            13.125
			weight:                400
			font_rendering_policy: .chromium
		}
		mut japanese := unsafe { &Font(nil) }
		mut tamil := unsafe { &Font(nil) }
		mut arena := new_arena('system fallback caller')
		entry := arena.enter()
		japanese = system_fallback_font(0x65e5, 'ja'.clone(), base) or { panic('no Japanese fallback') }
		tamil = system_fallback_font(0x0b95, 'ta'.clone(), base) or { panic('no Tamil fallback') }
		assert chromium_system_font_family_available('Georgia'.clone())
		assert !chromium_system_font_family_available('vox-workspace-unavailable-family'.clone())
		resolved := resolve_system_font_face('Georgia'.clone(), 400, false, 19.125) or {
			panic('no Georgia face')
		}
		assert resolved.path.len > 0
		arena.leave(entry)
		arena.release()

		japanese_face := japanese.system_face() or { panic('lost Japanese face') }
		tamil_face := tamil.system_face() or { panic('lost Tamil face') }
		assert japanese_face.postscript_name == 'HiraKakuProN-W3'
		assert tamil_face.path.len > 0 && tamil_face.family_name.len > 0
		assert japanese.contains_glyph(0x65e5) && tamil.contains_glyph(0x0b95)
		assert shaped_text_width(0, 0, '日本', japanese, .ltr) > 0
		assert shaped_text_width(0, 0, 'கம', tamil, .ltr) > 0
		assert voidptr(system_fallback_font(0x672c, 'ja', base)?) == voidptr(japanese)
		assert voidptr(system_fallback_font(0x0bae, 'ta', base)?) == voidptr(tamil)
		cached := resolve_system_font_face('Georgia', 400, false, 19.125) or { panic('lost Georgia face') }
		assert cached.path.len > 0 && cached.postscript_name.len > 0
		assert chromium_system_font_family_available('Georgia')
		assert !chromium_system_font_family_available('vox-workspace-unavailable-family')
	}
}

fn test_warmed_system_font_queries_do_not_retain_temporary_keys() {
	$if macos {
		base := &Font{
			family:                'SystemUi'
			point_size:            15.375
			weight:                400
			font_rendering_policy: .chromium
		}
		fallback := system_fallback_font(0x65e5, 'ja', base) or { panic('no fallback') }
		assert system_fallback_font(u32(`A`), 'en', base) == none
		assert chromium_system_font_family_available('Georgia')
		assert !chromium_system_font_family_available('vox-warmed-unavailable-family')
		assert resolve_system_font_face('Georgia', 400, false, 15.375) != none
		assert resolve_system_font_face('-apple-system', 400, false, 15.375) == none
		before := thread_arena_usage().used
		for _ in 0 .. 1024 {
			assert voidptr(system_fallback_font(0x65e5, 'ja', base)?) == voidptr(fallback)
			assert system_fallback_font(u32(`A`), 'en', base) == none
			assert chromium_system_font_family_available('Georgia')
			assert !chromium_system_font_family_available('vox-warmed-unavailable-family')
			assert resolve_system_font_face('Georgia', 400, false, 15.375) != none
			assert resolve_system_font_face('-apple-system', 400, false, 15.375) == none
		}
		$if prealloc {
			assert thread_arena_usage().used - before < 2048
		}
	}
}

fn test_system_fallback_canonical_identity_keeps_size_and_weight() {
	face := SystemFontFace{
		path:            '/workspace-only/identity-face.ttf'
		postscript_name: 'WorkspaceIdentityFace'
		family_name:     'Workspace identity'
	}
	first := canonical_system_fallback_font(&Font{
		family:                'identity fallback'
		point_size:            21.25
		weight:                400
		font_rendering_policy: .chromium
		system_face_override:  face
	})
	same := canonical_system_fallback_font(&Font{
		family:                'another family for same face'
		point_size:            21.25
		weight:                400
		font_rendering_policy: .chromium
		system_face_override:  face
	})
	larger := canonical_system_fallback_font(&Font{
		family:                'identity fallback'
		point_size:            22.25
		weight:                400
		font_rendering_policy: .chromium
		system_face_override:  face
	})
	bolder := canonical_system_fallback_font(&Font{
		family:                'identity fallback'
		point_size:            21.25
		weight:                700
		font_rendering_policy: .chromium
		system_face_override:  face
	})
	assert voidptr(first) == voidptr(same)
	assert voidptr(first) != voidptr(larger)
	assert voidptr(first) != voidptr(bolder)
}
