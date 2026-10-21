module platform

// Shaping is synchronous. Retained glyph runs contain glyph indices, positions
// and their V font identity, with no borrowed hb_font/hb_face storage. Static
// idle can retire these native lookup caches as well as the V glyph-run cache.
fn release_unused_harfbuzz_fonts() {
	mut released := false
	for index in 0 .. harfbuzz_scaled_fonts.len {
		mut entry := unsafe { &harfbuzz_scaled_fonts[index] }
		if entry.font == unsafe { nil } { continue }
		C.hb_font_destroy(entry.font)
		entry.font = unsafe { nil }
		entry.face = unsafe { nil }
		released = true
	}
	for key, face in harfbuzz_document_faces {
		if face == unsafe { nil } { continue }
		C.hb_face_destroy(face)
		// Preserve the key/hash reservation across future idle/refill cycles.
		mut slot := unsafe { &harfbuzz_document_faces[key] }
		unsafe { *slot = nil }
		mut attempted := unsafe { &harfbuzz_document_attempted[key] }
		unsafe { *attempted = false }
		released = true
	}
	for key, blob in harfbuzz_document_blobs {
		if blob == unsafe { nil } { continue }
		C.hb_blob_destroy(blob)
		mut slot := unsafe { &harfbuzz_document_blobs[key] }
		unsafe { *slot = nil }
		released = true
	}
	if harfbuzz_emoji_face != unsafe { nil } {
		C.hb_face_destroy(harfbuzz_emoji_face)
		harfbuzz_emoji_face = unsafe { nil }
		released = true
	}
	if harfbuzz_emoji_blob != unsafe { nil } {
		C.hb_blob_destroy(harfbuzz_emoji_blob)
		harfbuzz_emoji_blob = unsafe { nil }
		released = true
	}
	if !released { return }
	harfbuzz_emoji_attempted = false
	harfbuzz_cache_generation++
	skia_system_face_advances_lookup.bitmap_faces.clear()
}
