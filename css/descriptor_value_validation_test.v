module css

fn test_descriptor_parser_rejects_top_level_semicolons() {
	assert parse_css_descriptor_value_logic(.function_rule, .result, 'one') != none
	assert parse_css_descriptor_value_logic(.function_rule, .result, 'one; two') == none
	assert parse_css_descriptor_value_logic(.function_rule, .result, 'if(style(--x): one; else: two)') != none
}

fn test_font_face_object_setter_rejects_trailing_semicolon() {
	mut face := FontFaceObject.construct_impl('Foo', FontFaceSource.from_string('url(foo.woff2)'), FontFaceDescriptors{})
	face.set_weight('400;') or {
		assert err.msg().contains('SyntaxError')
		return
	}
	assert false, 'FontFace.weight must reject a trailing semicolon'
}
