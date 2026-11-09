module dom

fn test_svg_and_mathml_event_attributes_keep_native_handler_slots() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	for namespace in [namespace_svg_uri, 'http://www.w3.org/1998/Math/MathML'] {
		mut element := document.create_element_ns(namespace, 'math')!
		target := unsafe { &EventTarget(element) }
		element.set_attribute_value('onclick', 'callback()')
		assert target.data.has_event_handler('click')
		element.remove_attribute('onclick')
		assert !target.data.has_event_handler('click')
		element.set_attribute_ns_for_bindings('urn:other', 'x:onclick', 'callback()')!
		assert !target.data.has_event_handler('click')
	}
}

fn test_native_tab_index_defaults_are_independent_of_focusability_and_namespace() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	for namespace in [namespace_html_uri, namespace_svg_uri, 'http://www.w3.org/1998/Math/MathML'] {
		mut anchor := document.create_element_ns(namespace, 'a')!
		assert anchor.tab_index() == 0
		for value in ['', 'invalid', '2147483648', '-2147483649', '18446744073709551616'] {
			anchor.set_attribute_value('tabindex', value)
			assert anchor.tab_index() == 0, value
		}
		for value, expected in {'1.5':1, '4abc':4, '-2147483648':-2147483648, '2147483647':2147483647} {
			anchor.set_attribute_value('tabindex', value)
			assert anchor.tab_index() == expected, value
		}
	}
	foreign := document.create_element_ns('urn:other', 'a')!
	assert foreign.tab_index() == -1
	for name in ['area','button','frame','iframe','input','object','select','textarea'] {
		assert document.create_element_ns(namespace_html_uri, name)!.tab_index() == 0, name
		assert document.create_element_ns('http://www.w3.org/1998/Math/MathML', name)!.tab_index() == -1, name
	}
}

fn test_native_tab_index_only_gives_the_first_details_summary_a_default_zero() {
 mut document := Document.create(url_about_blank())
 defer { document.finalize() }
 details := document.create_element_ns(namespace_html_uri, 'details')!
 first := document.create_element_ns(namespace_html_uri, 'summary')!
 second := document.create_element_ns(namespace_html_uri, 'summary')!
 assert first.tab_index() == -1
 details.as_node().append_child(first.as_node())!
 details.as_node().append_child(second.as_node())!
 assert first.tab_index() == 0
 assert second.tab_index() == -1
 first.as_node().remove(false)
 assert second.tab_index() == 0
}
