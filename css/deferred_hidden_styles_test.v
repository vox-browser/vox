module css

import dom
import platform

fn hidden_style_element(document &dom.Document, parent &dom.Node, tag string, id string) &dom.Element {
	mut element := document.create_element_ns(dom.namespace_html_uri, tag) or { panic(err) }
	if id != '' { element.set_attribute_value('id', id) }
	mut owner := unsafe { &dom.Node(parent) }
	owner.append_child(element.as_node()) or { panic(err) }
	return element
}

fn hidden_style_fixture() (&dom.Document, &dom.Element, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{})
	root := hidden_style_element(document, document.as_node(), 'html', '')
	body := hidden_style_element(document, root.as_node(), 'body', '')
	hidden := hidden_style_element(document, body.as_node(), 'section', 'hidden')
	branch := hidden_style_element(document, hidden.as_node(), 'div', 'branch')
	target := hidden_style_element(document, branch.as_node(), 'span', 'target')
	add_document_author_style_sheet(document, '#hidden{display:none;color:red;--size:17px}#target{width:var(--size)}#target.changed{color:green}#target::before{content:"before";color:inherit}')
	css_style_computer_for(document)
	document.update_style()
	return document, hidden, branch, target
}

fn test_hidden_descendants_are_computed_on_query_without_an_active_style_loop() {
	mut document, hidden, _, target := hidden_style_fixture()
	defer { document.finalize() }
	assert hidden.el_computed_properties() != none
	assert target.el_computed_properties() == none
	assert !document.needs_style_update_after_layout()
	assert computed_value_for(target, .color)? == 'rgb(255, 0, 0)'
	assert computed_value_for(target, .width)? == '17px'
	assert target.el_computed_properties() != none
	assert css_style_computer_for(document).deferred_hidden_styles_.len == 0
}

fn test_hidden_query_styles_outlive_the_callers_retiring_arena() {
	mut document, _, _, target := hidden_style_fixture()
	document.enable_native_storage()
	defer {
		document.finalize()
		document.release_native_storage()
	}
	mut scratch := platform.new_arena('hidden CSSOM query caller')
	entry := scratch.enter()
	style := up_to_date_computed_properties_for_element(target)
	$if prealloc {
		assert !scratch.contains(style)
		assert document.native_storage().arena.contains(style)
	}
	scratch.leave(entry)
	scratch.release()
	assert style.property(.color, .no)?.css_text == 'rgb(255, 0, 0)'
	assert computed_value_for(target, .width)? == '17px'
}

fn test_hidden_style_queries_see_attribute_inheritance_and_stylesheet_changes() {
	mut document, mut hidden, _, mut target := hidden_style_fixture()
	defer { document.finalize() }
	assert computed_value_for(target, .color)? == 'rgb(255, 0, 0)'
	hidden.set_attribute_value('style', 'color:blue;--size:29px')
	target.set_attribute_value('class', 'changed')
	document.update_style()
	assert !document.needs_style_update_after_layout()
	assert computed_value_for(target, .color)? == 'rgb(0, 128, 0)'
	assert computed_value_for(target, .width)? == '29px'
	add_document_author_style_sheet(document, '#target.changed{color:purple}')
	document.set_needs_full_style_update(true)
	document.update_style()
	actual := computed_value_for(target, .color)?
	assert actual == 'rgb(128, 0, 128)'
}

fn test_hidden_cssom_queries_refresh_pseudos_custom_values_and_inline_comparisons() {
	mut document, _, _, mut target := hidden_style_fixture()
	defer { document.finalize() }
	resolved := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target, none))
	assert resolved.get_property_value('--size') == '17px'
	assert resolved.get_property_value('width') == '17px'
	pseudo := CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target, dom.PseudoElement.before))
	assert pseudo.get_property_value('color') == 'rgb(255, 0, 0)'
	target.set_attribute_value('style', 'color:blue')
	document.update_style()
	pair := computed_styles_with_and_without_inline(target) or { panic('missing inline comparison') }
	assert pair.with_inline.property(.color,.no)?.css_text == 'rgb(0, 0, 255)'
	assert pair.without_inline.property(.color,.no)?.css_text == 'rgb(255, 0, 0)'
}

fn test_revealing_a_hidden_subtree_refreshes_every_deferred_descendant() {
	mut document, mut hidden, branch, target := hidden_style_fixture()
	defer { document.finalize() }
	hidden.set_attribute_value('style', 'display:block;color:blue')
	document.update_style()
	assert branch.el_computed_properties() != none && target.el_computed_properties() != none
	assert computed_value_for(target, .color)? == 'rgb(0, 0, 255)'
	assert css_style_computer_for(document).deferred_hidden_styles_.len == 0
}

fn test_hidden_queries_materialize_only_the_requested_branch() {
	mut document, hidden, _, target := hidden_style_fixture()
	defer { document.finalize() }
	parent := hidden.as_node().parent()?
	other := hidden_style_element(document, parent, 'section', 'other')
	other_branch := hidden_style_element(document, other.as_node(), 'div', '')
	other_target := hidden_style_element(document, other_branch.as_node(), 'span', '')
	add_document_author_style_sheet(document, '#other{display:none;color:blue}')
	document.update_style()
	assert computed_value_for(target, .color)? == 'rgb(255, 0, 0)'
	assert other_target.el_computed_properties() == none
	assert computed_value_for(other_target, .color)? == 'rgb(0, 0, 255)'
}

fn test_svg_controls_and_popover_content_keep_eager_style_computation() {
	for tag in ['svg','input','button','div'] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_document_type(.html)
		document.set_browsing_context(&dom.BrowsingContext{})
		root := hidden_style_element(document, document.as_node(), 'html', '')
		mut hidden := hidden_style_element(document, root.as_node(), 'section', 'hidden')
		hidden.set_attribute_value('style','display:none')
		child := if tag == 'svg' {
			mut svg := document.create_element_ns('http://www.w3.org/2000/svg','svg') or { panic(err) }
			mut owner := hidden.as_node()
			owner.append_child(svg.as_node()) or { panic(err) }
			svg
		} else { hidden_style_element(document, hidden.as_node(), tag, '') }
		if tag == 'div' {
			mut popover := unsafe { &dom.Element(child) }
			popover.set_attribute_value('popover','')
		}
		css_style_computer_for(document)
		document.update_style()
		assert child.el_computed_properties() != none
		assert css_style_computer_for(document).deferred_hidden_styles_.len == 0
	}
}
