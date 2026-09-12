module css

fn test_font_face_set_check_requires_matching_faces_to_be_loaded() {
	mut set := FontFaceSet.create()
	mut face := FontFaceObject.construct_impl('CheckFace', FontFaceSource.from_string('url("font.woff2")'), FontFaceDescriptors{})
	set.add(face)!

	assert !set.check('16px CheckFace', 'A')!
	face.status_ = .loaded
	assert set.check('italic 16px CheckFace', 'A')!
}

fn test_font_face_set_check_accepts_system_or_unmatched_fonts() {
	set := FontFaceSet.create()

	assert set.check('16px sans-serif', 'A')!
	assert set.check('16px MissingFace', 'A')!
}

fn test_font_face_set_check_reports_font_syntax_errors() {
	set := FontFaceSet.create()
	if _ := set.check('definitely not a font shorthand', 'A') {
		assert false, 'invalid font shorthand should throw a SyntaxError'
	} else {
		assert err.msg().contains('SyntaxError')
	}
}
