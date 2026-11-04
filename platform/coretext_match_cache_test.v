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
