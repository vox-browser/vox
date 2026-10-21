module platform

fn test_coretext_queries_retain_face_payload_without_boxing_native_output_records() {
	$if macos {
		mut storage := new_arena('CoreText query payloads')
		entry := storage.enter()
		first := coretext_match_family('Helvetica', 400, false, 16) or { panic('missing Helvetica') }
		text := [u16(0x0b95)]
		before := storage.usage().used
		for _ in 0 .. 128 {
			face := coretext_match_family('Helvetica', 400, false, 16) or { panic('missing face') }
			assert face == first
			fallback := coretext_fallback(text, 'ta', 'Helvetica', 400, false, 16) or { panic('missing fallback') }
			assert fallback.path.len > 0 && fallback.postscript_name.len > 0
			assert fallback.metrics.ascent > 0 && fallback.metrics.descent >= 0
		}
		growth := storage.usage().used - before
		storage.leave(entry)
		$if prealloc {
			// Strings, variation arrays and result wrappers fit comfortably below
			// even one native output record per query pair. Two boxed records do not.
			assert growth < 128 * i64(sizeof(C.vox_ct_face)), '${growth} bytes for 256 queries'
		}
		assert first.path == '/System/Library/Fonts/Helvetica.ttc'
		assert first.postscript_name == 'Helvetica'
		assert first.metrics.ascent > 0
		storage.release()
	}
}

fn test_coretext_face_results_keep_independent_strings_and_variation_coordinates() {
	$if macos {
		regular := coretext_match_family('system-ui', 400, false, 16) or { panic('missing UI face') }
		bold := coretext_match_family('system-ui', 700, false, 32) or { panic('missing bold UI face') }
		for _ in 0 .. 32 {
			_ = coretext_match_family('Times', 400, true, 10) or { panic('missing Times') }
		}
		assert regular.path == '/System/Library/Fonts/SFNS.ttf'
		assert regular.variations == [FontVariationAxis{tag: 0x6f70737a, value: 17}]
		assert FontVariationAxis{tag: 0x77676874, value: 700} in bold.variations
		assert regular.metrics.ascent < bold.metrics.ascent
	}
}
