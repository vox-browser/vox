module css

import dom

fn justify_items_text(element &dom.Element) string {
	abstract := dom.AbstractElement.new(element, none)
	style := computed_properties_from_dom(abstract.computed_properties() or { panic('missing style') }) or { panic('missing handle') }
	value := style.property(.justify_items, .yes) or { return '(none)' }
	typed := typed_style_value_logic_from_dom(value) or { return '(untyped)' }
	return serialize_dom_style_value(typed)
}

// A bare justify-items legacy computes to normal, or to the parent's legacy
// tuple. The inherited-value refresh must reach the same value as the
// complete computation, or every refresh flips it and requests a relayout.
fn test_inherited_refresh_resolves_bare_justify_items_legacy_like_a_full_computation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := document.create_element('div')!
	parent.set_attribute_value('style', 'color:red')
	child := document.create_element('span')!
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node())!
	computer := StyleComputer.new(document)
	mut parent_abstract := dom.AbstractElement.new(parent, none)
	mut child_abstract := dom.AbstractElement.new(child, none)
	computer.recompute_style(mut parent_abstract)
	computer.recompute_style(mut child_abstract)
	assert justify_items_text(child) == 'normal'

	// An unchanged parent: nothing to invalidate, and the value stays.
	quiet := computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert quiet.is_none()
	assert justify_items_text(child) == 'normal'

	// An inherited color change repaints without a relayout.
	parent.set_attribute_value('style', 'color:blue')
	computer.recompute_style(mut parent_abstract)
	recolored := computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert !recolored.needs_relayout() && !recolored.needs_layout_tree_rebuild()
	assert justify_items_text(child) == 'normal'

	// A legacy tuple on the parent reaches the child through the refresh, and
	// leaving it restores normal; both are layout changes.
	parent.set_attribute_value('style', 'color:blue;justify-items:legacy center')
	computer.recompute_style(mut parent_abstract)
	took := computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert justify_items_text(child) == 'legacy center'
	assert took.needs_relayout()
	parent.set_attribute_value('style', 'color:blue')
	computer.recompute_style(mut parent_abstract)
	left := computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert justify_items_text(child) == 'normal'
	assert left.needs_relayout()

	// An em length on the child still recomputes against the parent's font.
	parent.set_attribute_value('style', 'font-size:10px')
	mut child_element := unsafe { &dom.Element(child) }
	child_element.set_attribute_value('style', 'width:2em')
	computer.recompute_style(mut parent_abstract)
	computer.recompute_style(mut child_abstract)
	parent.set_attribute_value('style', 'font-size:20px')
	computer.recompute_style(mut parent_abstract)
	resized := computer.recompute_inherited_style_with_invalidation(mut child_abstract)
	assert resized.needs_relayout()
	assert justify_items_text(child) == 'normal'
}
