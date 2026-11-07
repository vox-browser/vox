module platform

// CoreText family selection and collection lookups are cached per face, while
// each point size still creates its own font for size-dependent results.
fn test_cached_coretext_matches_keep_collection_faces_and_scale_metrics_per_size() {
	$if macos {
		path := '/System/Library/Fonts/HelveticaNeue.ttc'
		mut seen := map[string]int{}
		for style in [[400, 0], [700, 0], [400, 1], [700, 1]] {
			weight, italic := style[0], style[1] == 1
			small := coretext_match_family('Helvetica Neue', weight, italic, 10) or { panic('missing Helvetica Neue') }
			for size in [f32(30), 10, 13.5] {
				face := coretext_match_family('Helvetica Neue', weight, italic, size) or { panic('missing size ${size}') }
				assert face.path == path
				assert face.postscript_name == small.postscript_name
				assert face.face_index == small.face_index
				assert face.weight == small.weight && face.italic == small.italic
				ratio := f64(size) / 10.0
				assert f64(face.metrics.ascent) - f64(small.metrics.ascent) * ratio < 0.01
				assert f64(small.metrics.ascent) * ratio - f64(face.metrics.ascent) < 0.01
			}
			assert small.postscript_name !in seen
			assert small.face_index !in seen.values()
			seen[small.postscript_name] = small.face_index
		}
		assert seen.len == 4
	}
}

fn test_cached_coretext_misses_remain_misses_at_every_size() {
	$if macos {
		for size in [f32(10), 16, 31.5] {
			assert coretext_match_family('Vox Missing Family 7c1d', 400, false, size) == none
			assert coretext_match_family('Vox Missing Family 7c1d', 700, true, size) == none
		}
	}
}

fn coretext_weight_coordinate(face SystemFontFace) ?f32 {
	for axis in face.variations {
		if axis.tag == 0x77676874 { return axis.value }
	}
	return none
}

// The system font's `wght` range and family name are read once per face file
// and PostScript name, then reused for every later point size of that face.
// CoreText names some optical-size instances `.SF NS` rather than
// `.AppleSystemUIFont`; a repeated query must return exactly the same face.
fn test_cached_system_ui_weight_ranges_and_family_names_keep_every_size_exact() {
	$if macos {
		for italic in [false, true] {
			for weight in [300, 500, 600, 900] {
				for size in [f32(11), 14, 23.5, 48] {
					first := coretext_match_family('system-ui', weight, italic, size) or {
						panic('missing system-ui ${size}')
					}
					again := coretext_match_family('system-ui', weight, italic, size) or {
						panic('missing system-ui ${size}')
					}
					assert first.family_name != ''
					assert again.family_name == first.family_name
					assert again.postscript_name == first.postscript_name
					assert again.path == first.path && again.face_index == first.face_index
					assert again.variations == first.variations
					assert again.metrics.ascent == first.metrics.ascent
					assert again.metrics.x_height == first.metrics.x_height
					assert again.italic == italic && again.weight == first.weight
					assert coretext_weight_coordinate(again) or { panic('no wght') } == f32(weight)
				}
			}
		}
		// The regular weight takes the default instance without a variation.
		regular := coretext_match_family('system-ui', 400, false, 12) or { panic('missing system-ui') }
		assert regular.family_name != ''
		assert coretext_weight_coordinate(regular) or { f32(400) } == 400
	}
}
