module css

import dom

fn styled_child(mut document dom.Document, parent_style string, child_style string) !(&dom.Element, &dom.Element) {
	mut parent := document.create_element('div')!
	parent.set_attribute_value('style', parent_style)
	mut child := document.create_element('span')!
	child.set_attribute_value('style', child_style)
	mut node := parent.as_node()
	node.append_child(child.as_node())!
	return parent, child
}

fn test_substituted_value_reuse_shares_parses_but_not_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	declaration := 'width:var(--w, var(--fallback, 2em))'
	mut p1, mut c1 := styled_child(mut document, '--w:10px;font-size:10px', declaration)!
	mut p2, mut c2 := styled_child(mut document, '--w:30px;font-size:10px', declaration)!
	mut p3, mut c3 := styled_child(mut document, 'font-size:10px', declaration)!
	mut p4, mut c4 := styled_child(mut document, 'font-size:20px', declaration)!
	mut computer := css_style_computer_for(document)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut widths := []f64{}
	for pair in [[p1, c1], [p2, c2], [p3, c3], [p4, c4], [p1, c1]] {
		mut parent := pair[0]
		parent_style := computer.compute_style(dom.AbstractElement.new(parent, none))
		parent.set_computed_properties(none, computed_properties_to_dom(parent_style))
		child_style := computer.compute_style(dom.AbstractElement.new(pair[1], none))
		widths << child_style.length_percentage_to_px(.width, 0)?
	}
	// The same substitution shares one parse; em still resolves per element.
	assert widths == [10.0, 30.0, 20.0, 40.0, 10.0], '${widths}'
	$if prealloc {
		if !disable_substituted_value_reuse {
			assert computer.substituted_values_ != unsafe { nil }
			assert computer.substituted_values_.hits >= 2
		}
	}
}
