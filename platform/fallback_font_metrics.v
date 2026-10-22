module platform

import x.ttf

// CSS needs the generic face's scalar metrics while computing font properties,
// before it selects the element's actual font. Do not retain an outline face
// solely for this query. Font handles used for shaping keep their usual caches.
pub fn fallback_font_pixel_metrics(point_size f32) FontPixelMetrics {
	if metrics := temporary_file_font_pixel_metrics('sans-serif', point_size, '') {
		return metrics
	}
	// Preserve the ordinary unavailable-face fallback, including its shaping
	// behavior, outside temporary storage. A callback or cache may retain it.
	font := Font{ family: 'sans-serif', point_size: point_size }
	return font.pixel_metrics()
}

fn temporary_file_font_pixel_metrics(family string, point_size f32, source_path string) ?FontPixelMetrics {
	scratch := begin_thread_scratch('fallback font metrics')
	defer { scratch.finish() }
	// The handle and a newly decoded face are private to this synchronous query.
	// This is the file-backed LibWeb policy; no system-font or shaping callback
	// receives the temporary handle, and no face/glyph cache receives its bytes.
	font := Font{ family: family, point_size: point_size, source_path: source_path }
	path := font.font_path()?
	face_index := font.face_index()
	cache_key := '${path}|${face_index}'
	if face := platform_font_faces[cache_key] {
		mut mutable_face := unsafe { &ttf.TTF_File(face) }
		glyph := font_cmap_glyph(face.buf, u32(`0`))
		advance, _ := mutable_face.get_horizontal_metrics(glyph)
		return font.decoded_face_pixel_metrics(face, f32(advance) * point_size / f32(face.units_per_em))
	}
	if platform_font_face_attempted[cache_key] {
		return none
	}
	mut bytes := read_outline_face_bytes(path, face_index)?
	mut face := decode_outline_face(mut bytes)
	glyph := font_cmap_glyph(face.buf, u32(`0`))
	advance, _ := face.get_horizontal_metrics(glyph)
	return font.decoded_face_pixel_metrics(face, f32(advance) * point_size / f32(face.units_per_em))
}
