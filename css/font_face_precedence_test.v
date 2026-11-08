module css

import dom

fn precedence_font_face(mut set FontFaceSet, name string, subset string) &FontFaceObject {
	mut face := FontFaceObject.construct_impl('Precedence', FontFaceSource.from_string('url(${name}.ttf)'),
		FontFaceDescriptors{ weight: '400', unicode_range: subset })
	face.status_ = .loaded
	face.parsed_font = &PlatformTypeface{ family_name: 'Precedence', source_path: '${name}.ttf' }
	set.add(face) or { panic(err) }
	return face
}

fn precedence_font_cascade(mut computer FontComputer, weight int) &FontCascadeList {
	return computer.compute_font_for_style_values(['Precedence'], CSSPixels.new(16), 0,
		weight, Percentage{ value_: 100 }, .none_, map[string]f64{}, FontFeatureData{})
}

fn test_chromium_later_font_face_precedes_an_earlier_matching_face() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	defer { document.finalize() }
	mut computer := FontComputer.create_for_document(document)
	mut set := FontFaceSet.create_for_font_computer(computer)
	precedence_font_face(mut set, 'earlier', 'U+0-10FFFF')
	precedence_font_face(mut set, 'later', 'U+0-10FFFF')
	for weight in [400, 450] {
		cascade := precedence_font_cascade(mut computer, weight)
		assert cascade.fonts.len == 2
		assert cascade.fonts[0].font.typeface.source_path == 'later.ttf'
		assert cascade.fonts[1].font.typeface.source_path == 'earlier.ttf'
	}
	assert set.set_entries()[0].urls[0].value == 'earlier.ttf'
	assert set.set_entries()[1].urls[0].value == 'later.ttf'
}

fn test_later_overlapping_subset_only_overrides_the_characters_it_covers() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	defer { document.finalize() }
	mut computer := FontComputer.create_for_document(document)
	mut set := FontFaceSet.create_for_font_computer(computer)
	precedence_font_face(mut set, 'whole-family', 'U+0-10FFFF')
	precedence_font_face(mut set, 'latin-a', 'U+41')
	cascade := precedence_font_cascade(mut computer, 400)
	assert cascade.font_for_code_point(u32(`A`)).typeface.source_path == 'latin-a.ttf'
	assert cascade.font_for_code_point(u32(`B`)).typeface.source_path == 'whole-family.ttf'
}

fn test_pending_later_font_keeps_priority_over_a_loaded_earlier_face() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	defer { document.finalize() }
	mut computer := FontComputer.create_for_document(document)
	mut set := FontFaceSet.create_for_font_computer(computer)
	precedence_font_face(mut set, 'loaded', 'U+0-10FFFF')
	pending := FontFaceObject.construct_impl('Precedence', FontFaceSource.from_string('url(pending.ttf)'),
		FontFaceDescriptors{ weight: '400' })
	set.add(pending)!
	cascade := precedence_font_cascade(mut computer, 400)
	assert cascade.fonts.len == 1
	assert cascade.pending_faces.len == 1
	assert voidptr(cascade.pending_faces[0].font_face) == voidptr(pending)
	assert cascade.pending_faces[0].font_index == 0
	assert pending.status() == .unloaded
}

fn test_font_definition_reordering_invalidates_a_cached_rendering_cascade() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_font_rendering_policy(.chromium)
	defer { document.finalize() }
	mut computer := FontComputer.create_for_document(document)
	mut set := FontFaceSet.create_for_font_computer(computer)
	first := precedence_font_face(mut set, 'first', 'U+0-10FFFF')
	second := precedence_font_face(mut set, 'second', 'U+0-10FFFF')
	before := precedence_font_cascade(mut computer, 400)
	assert before.fonts[0].font.typeface.source_path == 'second.ttf'
	computer.synchronize_font_face_order([second, first])
	after := precedence_font_cascade(mut computer, 400)
	assert voidptr(after) != voidptr(before)
	assert after.fonts[0].font.typeface.source_path == 'first.ttf'
	computer.synchronize_font_face_order([second, first])
	assert voidptr(precedence_font_cascade(mut computer, 400)) == voidptr(after)
}

fn test_libweb_font_policy_preserves_its_upstream_order() {
	mut computer := FontComputer.create()
	mut set := FontFaceSet.create_for_font_computer(computer)
	precedence_font_face(mut set, 'first', 'U+0-10FFFF')
	precedence_font_face(mut set, 'second', 'U+0-10FFFF')
	assert precedence_font_cascade(mut computer, 400).fonts[0].font.typeface.source_path == 'first.ttf'
}
