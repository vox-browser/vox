module css

import dom

fn test_numeric_line_heights_quantize_the_font_before_multiplication() {
	for chromium in [false, true] {
		for line_height in ['15.73248px', '1.2em', '120%', '1.2'] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
			document.set_navigable(&dom.Navigable{ active_document_: document })
			if chromium { document.set_font_rendering_policy(.chromium) }
			mut root := document.create_element('html')!
			root.set_attribute_value('style', 'font-size:13.1104px;line-height:${line_height}')
			mut node := document.as_node()
			node.append_child(root.as_node())!
			_ = css_style_computer_for(document)
			document.update_style()
			style := up_to_date_computed_properties_for_element(root)
			expected := if chromium && line_height == '1.2' { 15.71875 } else { 15.734375 }
			assert style.line_height().to_double() == expected, line_height
			values := resolve_computed_values_for_document(style, document)
			assert values.line_height().to_double() == expected, line_height
			clone := style.clone_for_anonymous_block()
			anonymous := resolve_computed_values_for_document(clone, document)
			assert anonymous.line_height().to_double() == expected, line_height
			mut subjectless := unsafe { &ComputedProperties(style) }
			subjectless.subject_element_ = none
			assert subjectless.line_height().to_double() == expected, line_height
		}
	}
}

fn test_numeric_line_height_uses_the_rounded_font_size_on_both_sides_of_a_quantum() {
	for size, expected in {
		'13.1156930333': 15.71875
		'13.119':        15.75
	} {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
		document.set_navigable(&dom.Navigable{ active_document_: document })
		document.set_font_rendering_policy(.chromium)
		mut root := document.create_element('html')!
		root.set_attribute_value('style', 'font-size:${size}px;line-height:1.2')
		mut node := document.as_node()
		node.append_child(root.as_node())!
		_ = css_style_computer_for(document)
		document.update_style()
		style := up_to_date_computed_properties_for_element(root)
		assert style.line_height().to_double() == expected
	}
}
