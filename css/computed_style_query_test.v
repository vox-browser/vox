module css

import dom

fn computed_query_fixture() (&dom.Document, &dom.Element, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut branch := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	mut target := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	mut unrelated := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	branch.set_attribute_value('style', 'color:red;--query-width:17px')
	target.set_attribute_value('style', 'width:var(--query-width)')
	unrelated.set_attribute_value('style', 'color:green;width:31px')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(branch.as_node()) or { panic(err) }
	root_node.append_child(unrelated.as_node()) or { panic(err) }
	mut branch_node := branch.as_node()
	branch_node.append_child(target.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	return document, branch, target, unrelated
}

fn computed_query_stored(element &dom.Element) &ComputedProperties {
	bridge := dom.AbstractElement.new(element, none).computed_properties() or { panic('missing style') }
	return computed_properties_from_dom(bridge) or { panic('missing style owner') }
}

fn computed_query_property(style &ComputedProperties, id PropertyID) string {
	return (style.property(id, .no) or { panic('missing property') }).css_text
}

fn computed_query_assert_oracle(element &dom.Element) {
	actual := computed_query_stored(element)
	expected := css_style_computer_for(element.document()).compute_style_with_seeded_ancestors(dom.AbstractElement.new(element, none))
	for id in computed_interpolation_longhand_property_ids() {
		assert computed_query_property(actual, id) == computed_query_property(expected, id), '${id}'
	}
}

fn test_computed_query_bootstraps_styles_and_reuses_a_clean_result() {
	mut document, branch, target, unrelated := computed_query_fixture()
	assert dom.AbstractElement.new(target, none).computed_properties() == none
	style := up_to_date_computed_properties_for_element(target)
	assert computed_query_property(style, .width) == '17px'
	assert computed_query_property(style, .color) == computed_query_property(computed_query_stored(branch), .color)
	assert !document.needs_full_style_update()
	assert dom.AbstractElement.new(unrelated, none).computed_properties() != none
	document.reset_style_invalidation_counters()
	assert voidptr(up_to_date_computed_properties_for_element(target)) == voidptr(style)
	assert document.style_invalidation_counters().element_style_recomputations == 0
	computed_query_assert_oracle(target)
}

fn test_computed_query_flushes_selective_inline_invalidation() {
	mut document, _, mut target, unrelated := computed_query_fixture()
	_ = up_to_date_computed_properties_for_element(target)
	unrelated_before := computed_query_stored(unrelated)
	target.set_attribute_value('style', 'width:43px;color:blue')
	assert document.element_needs_style_update(target)
	assert !document.needs_full_style_update()
	document.reset_style_invalidation_counters()
	style := up_to_date_computed_properties_for_element(target)
	assert computed_query_property(style, .width) == '43px'
	assert document.style_invalidation_counters().element_style_recomputations == 1
	assert voidptr(computed_query_stored(unrelated)) == voidptr(unrelated_before)
	assert !document.element_needs_style_update(target)
	computed_query_assert_oracle(target)
}

fn test_computed_query_flushes_a_stale_inheritance_ancestor() {
	mut document, mut branch, target, unrelated := computed_query_fixture()
	_ = up_to_date_computed_properties_for_element(target)
	unrelated_before := computed_query_stored(unrelated)
	branch.set_attribute_value('style', 'color:blue;--query-width:29px')
	assert document.element_needs_style_update(target)
	assert !target.needs_style_update()
	assert !document.needs_full_style_update()
	document.reset_style_invalidation_counters()
	style := up_to_date_computed_properties_for_element(target)
	assert computed_query_property(style, .width) == '29px'
	assert computed_query_property(style, .color) == computed_query_property(computed_query_stored(branch), .color)
	assert voidptr(computed_query_stored(unrelated)) == voidptr(unrelated_before)
	assert document.style_invalidation_counters().element_style_recomputations <= 2
	computed_query_assert_oracle(target)
}

fn test_computed_query_inline_comparison_flushes_pending_style_and_restores_inline_data() {
	mut document, _, mut target, unrelated := computed_query_fixture()
	_ = up_to_date_computed_properties_for_element(target)
	unrelated_before := computed_query_stored(unrelated)
	target.set_attribute_value('style', 'width:47px;--private-query-value:11px')
	document.reset_style_invalidation_counters()
	pair := computed_styles_with_and_without_inline(target) or { panic('missing pair') }
	assert computed_query_property(pair.with_inline, .width) == '47px'
	assert computed_query_property(pair.without_inline, .width) == 'auto'
	assert voidptr(computed_query_stored(unrelated)) == voidptr(unrelated_before)
	assert document.style_invalidation_counters().element_style_recomputations == 1
	assert target.get_attribute('style') or { '' } == 'width:47px;--private-query-value:11px'
	assert voidptr(up_to_date_computed_properties_for_element(target)) == voidptr(pair.with_inline)
	computed_query_assert_oracle(target)
}

fn test_computed_query_new_child_keeps_unrelated_computed_styles() {
	mut document, mut branch, target, unrelated := computed_query_fixture()
	_ = up_to_date_computed_properties_for_element(target)
	unrelated_before := computed_query_stored(unrelated)
	mut inserted := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	inserted.set_attribute_value('style', 'width:var(--query-width)')
	mut parent := branch.as_node()
	parent.append_child(inserted.as_node()) or { panic(err) }
	assert inserted.el_computed_properties() == none
	document.reset_style_invalidation_counters()
	style := up_to_date_computed_properties_for_element(inserted)
	assert computed_query_property(style, .width) == '17px'
	assert computed_query_property(style, .color) == computed_query_property(computed_query_stored(branch), .color)
	assert (voidptr(computed_query_stored(unrelated)) == voidptr(unrelated_before)) == !disable_selective_missing_style_query
	if !disable_selective_missing_style_query {
		assert document.style_invalidation_counters().element_style_recomputations <= 2
	}
	computed_query_assert_oracle(inserted)
}

fn test_computed_query_inline_comparison_on_new_child_keeps_unrelated_styles() {
	mut document, mut branch, target, unrelated := computed_query_fixture()
	_ = up_to_date_computed_properties_for_element(target)
	unrelated_before := computed_query_stored(unrelated)
	mut inserted := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	inserted.set_attribute_value('style', 'width:39px')
	mut parent := branch.as_node()
	parent.append_child(inserted.as_node()) or { panic(err) }
	document.reset_style_invalidation_counters()
	pair := computed_styles_with_and_without_inline(inserted) or { panic('missing pair') }
	assert computed_query_property(pair.with_inline, .width) == '39px'
	assert computed_query_property(pair.without_inline, .width) == 'auto'
	assert (voidptr(computed_query_stored(unrelated)) == voidptr(unrelated_before)) == !disable_selective_missing_style_query
	if !disable_selective_missing_style_query {
		assert document.style_invalidation_counters().element_style_recomputations <= 2
	}
	assert inserted.get_attribute('style') or { '' } == 'width:39px'
}
