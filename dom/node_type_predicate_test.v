module dom

fn test_single_name_type_predicates_check_namespace_case_and_node_kind() {
	document := Document.create(url_about_blank())
	input := document.create_element_ns(namespace_html_uri, 'input')!
	svg_input := document.create_element_ns(namespace_svg_uri, 'input')!
	other_input := document.create_element_ns('urn:example', 'input')!
	upper_input := document.create_element_ns(namespace_html_uri, 'INPUT')!
	assert input.as_node().is_html_input_element()
	assert !svg_input.as_node().is_html_input_element()
	assert !other_input.as_node().is_html_input_element()
	assert !upper_input.as_node().is_html_input_element()
	assert !document.create_text_node('input').as_node().is_html_input_element()
	assert !unsafe { &Node(document) }.is_html_input_element()
}

fn test_single_name_svg_predicates_preserve_case_sensitive_foreign_object_identity() {
	document := Document.create(url_about_blank())
	foreign_object := document.create_element_ns(namespace_svg_uri, 'foreignObject')!
	lower := document.create_element_ns(namespace_svg_uri, 'foreignobject')!
	html := document.create_element_ns(namespace_html_uri, 'foreignObject')!
	assert foreign_object.as_node().is_svg_foreign_object_element()
	assert !lower.as_node().is_svg_foreign_object_element()
	assert !html.as_node().is_svg_foreign_object_element()
	assert !foreign_object.as_node().is_svg_svg_element()
}
