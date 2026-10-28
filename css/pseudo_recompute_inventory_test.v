module css

import dom

fn pseudo_recompute_has_style(element &dom.Element, pseudo dom.PseudoElement) bool {
	target := dom.AbstractElement.new(element, pseudo)
	return target.computed_properties() != none
}

fn pseudo_recompute_color(element &dom.Element, pseudo dom.PseudoElement) string {
	target := dom.AbstractElement.new(element, pseudo)
	bridge := target.computed_properties() or { panic('missing pseudo style') }
	style := computed_properties_from_dom(bridge) or { panic('missing typed pseudo style') }
	value := style.property(.color, .no) or { panic('missing pseudo color') }
	return value.css_text
}

fn test_pseudo_recomputation_refreshes_previous_markers_and_enters_top_layer_backdrops() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('id', 'target')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(element.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, '#target {display:list-item} #target::before{content:"before"} #target::after{content:"after"} #target::marker{color:red} #target[changed]::marker{color:blue} #target::backdrop{background:blue}')
	computer := css_style_computer_for(document)
	mut target := dom.AbstractElement.new(element, none)
	mut changed := false
	_, first := computer.recompute_style_with_invalidation(mut target, &changed)
	assert first.display().is_list_item()
	assert pseudo_recompute_has_style(element, .before)
	assert pseudo_recompute_has_style(element, .after)
	assert pseudo_recompute_has_style(element, .marker)
	assert pseudo_recompute_color(element, .marker) == 'rgb(255, 0, 0)'
	assert !pseudo_recompute_has_style(element, .backdrop)
	element.set_attribute_value('style', 'display:block')
	element.set_attribute_value('changed', '')
	element.in_top_layer = true
	element.rendered_in_top_layer = true
	_, second := computer.recompute_style_with_invalidation(mut target, &changed)
	assert !second.display().is_list_item()
	// Marker style has an implicit initial value even without a marker box.
	// Its previous list-item role must still schedule this recomputation.
	assert pseudo_recompute_color(element, .marker) == 'rgb(0, 0, 255)'
	assert pseudo_recompute_has_style(element, .backdrop)
	assert pseudo_recompute_has_style(element, .before)
	assert pseudo_recompute_has_style(element, .after)
}

fn test_pseudo_admission_keeps_origin_ancestry_and_clears_removed_styles() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(element.as_node()) or { panic(err) }
	add_document_author_style_sheet(document, 'html .red::before{content:"before";color:red} html .blue::before{content:"before";color:blue} html .blue::after{content:"after";color:blue}')
	mut computer := css_style_computer_for(document)
	computer.push_ancestor(root)
	defer { computer.pop_ancestor(root) }
	ancestors := computer.ancestor_filter_.buckets.clone()
	mut target := dom.AbstractElement.new(element, none)
	mut changed := false
	for class_name in ['red', 'missing', 'blue', 'missing'] {
		element.set_attribute_value('class', class_name)
		_, _ = computer.recompute_style_with_invalidation(mut target, &changed)
		assert computer.ancestor_filter_.buckets == ancestors
		assert pseudo_recompute_has_style(element, .before) == (class_name != 'missing')
		assert pseudo_recompute_has_style(element, .after) == (class_name == 'blue')
		if class_name == 'red' {
			assert pseudo_recompute_color(element, .before) == 'rgb(255, 0, 0)'
		} else if class_name == 'blue' {
			assert pseudo_recompute_color(element, .before) == 'rgb(0, 0, 255)'
			assert pseudo_recompute_color(element, .after) == 'rgb(0, 0, 255)'
		}
	}
}
