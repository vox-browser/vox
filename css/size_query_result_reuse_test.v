module css

import dom
import platform

fn query_reuse_element(document &dom.Document, parent &dom.Node, tag string) &dom.Element {
	mut element := document.create_element_ns(dom.namespace_html_uri, tag) or { panic(err) }
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn query_reuse_refresh(computer &StyleComputer, target &dom.Element) {
	mut abstract := dom.AbstractElement.new(target, none)
	computer.recompute_style(mut abstract)
	mut node := unsafe { &dom.Node(target.as_node()) }
	node.set_needs_style_update(false)
	node.set_child_needs_style_update(false)
}

fn query_reuse_fixture(source string) (&dom.Document, &dom.Element, &dom.Element, &StyleComputer) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_viewport_rect(dom.Rect{0,0,800,600})
	mut container := query_reuse_element(document, document.as_node(), 'div')
	container.set_attribute_value('style', 'container-type:size;container-name:card')
	mut target := query_reuse_element(document, container.as_node(), 'span')
	target.set_attribute_value('class','target')
	add_document_author_style_sheet(document, source)
	computer := css_style_computer_for(document)
	container.set_computed_properties(none, computed_properties_to_dom(computer.compute_style(dom.AbstractElement.new(container,none))))
	mut node := container.as_node()
	node.set_layout_node(&dom.LayoutNode{dom_node_:node,has_geometry_:true,content_width_:300,content_height_:200})
	query_reuse_refresh(computer,target)
	return document, container, target, computer
}

fn query_reuse_resize(container &dom.Element, width f64) {
	mut node := container.as_node().unsafe_layout_node() or { panic('missing container geometry') }
	node.content_width_ = width
	invalidate_descendant_styles_depending_on_size_container_query(container)
}

fn test_unchanged_size_query_answers_avoid_recascade_but_threshold_crossings_restyle() {
	mut document, container, target, computer := query_reuse_fixture('.target{color:blue}@container card (width>=200px){.target{color:red}}')
	defer { document.finalize() }
	assert computed_properties_for_element(target)?.property(.color,.no)?.css_text == 'rgb(255, 0, 0)'
	query_reuse_resize(container,350)
	assert !target.needs_style_update()
	query_reuse_resize(container,150)
	assert target.needs_style_update()
	query_reuse_refresh(computer,target)
	assert computed_properties_for_element(target)?.property(.color,.no)?.css_text == 'rgb(0, 0, 255)'
	query_reuse_resize(container,100)
	assert !target.needs_style_update()
	query_reuse_resize(container,250)
	assert target.needs_style_update()
}

fn test_size_query_cache_keeps_false_rules_and_every_distinct_condition() {
	mut document, container, target, computer := query_reuse_fixture('.target{color:blue;width:10px}@container (width>=200px){.target{color:red}}@container (width>=400px){.target{width:90px}}')
	defer { document.finalize() }
	query_reuse_resize(container,350)
	assert !target.needs_style_update()
	query_reuse_resize(container,450)
	assert target.needs_style_update()
	query_reuse_refresh(computer,target)
	assert computed_properties_for_element(target)?.property(.width,.no)?.css_text == '90px'
}

fn test_generated_pseudo_queries_invalidate_the_originating_element() {
	mut document, container, target, computer := query_reuse_fixture('.target::before{content:"x";color:blue}@container (width>=250px){.target::before{color:red}}')
	defer { document.finalize() }
	query_reuse_resize(container,280)
	assert !target.needs_style_update()
	query_reuse_resize(container,200)
	assert target.needs_style_update()
	query_reuse_refresh(computer,target)
	pseudo := dom.AbstractElement.new(target, dom.PseudoElement.before)
	bridge := pseudo.computed_properties() or { panic('missing generated pseudo style') }
	style := computed_properties_from_dom(bridge) or { panic('missing generated pseudo CSS handle') }
	assert style.property(.color,.no)?.css_text == 'rgb(0, 0, 255)'
}

fn test_container_relative_lengths_always_restyle_even_when_query_answers_stay_equal() {
	mut document, container, target, computer := query_reuse_fixture('.target{width:10cqw}@container (width>=200px){.target{color:red}}')
	defer { document.finalize() }
	assert target.style_depends_on_container_relative_units()
	query_reuse_resize(container,400)
	assert target.needs_style_update()
	query_reuse_refresh(computer,target)
	assert computed_properties_for_element(target)?.length_percentage_to_px(.width,0)? == 40
}

fn test_missing_and_overflowed_query_records_keep_conservative_invalidation() {
	mut document, container, target, mut computer := query_reuse_fixture('@container (width>=200px){.target{color:red}}')
	defer { document.finalize() }
	key := u64(target.as_node().unique_id().value())
	computer.size_query_matches_.delete(key)
	query_reuse_resize(container,350)
	assert target.needs_style_update()
	query_reuse_refresh(computer,target)
	for index in 0 .. 65 {
		rule := parse_css_rule_with_params(ParsingParams{}, '@container (width>=${index}px){}') or { panic('invalid query') }
		computer.record_size_query_match(rule,dom.AbstractElement.new(target,none),true)
	}
	assert !computer.size_query_matches_[key].complete
	query_reuse_resize(container,360)
	assert target.needs_style_update()
}

fn test_skipping_an_unchanged_parent_does_not_skip_its_dependent_descendants() {
	mut document, container, target, computer := query_reuse_fixture('@container (width>=200px){.target{color:red}}@container (width>=400px){.inner{color:blue}}')
	defer { document.finalize() }
	mut inner := query_reuse_element(document,target.as_node(),'b')
	inner.set_attribute_value('class','inner')
	query_reuse_refresh(computer,inner)
	mut parent_node := unsafe { &dom.Node(target.as_node()) }
	parent_node.set_needs_style_update(false)
	parent_node.set_child_needs_style_update(false)
	query_reuse_resize(container,450)
	assert !target.needs_style_update()
	assert inner.needs_style_update()
}

fn test_query_records_are_replaced_after_selector_and_stylesheet_changes() {
	mut document, container, mut target, computer := query_reuse_fixture('@container (width>=200px){.target{color:red}}@container (width>=400px){.other{color:blue}}')
	defer { document.finalize() }
	target.set_attribute_value('class','other')
	query_reuse_refresh(computer,target)
	query_reuse_resize(container,150)
	assert !target.needs_style_update()
	query_reuse_resize(container,450)
	assert target.needs_style_update()
}

fn test_query_records_survive_a_retiring_cssom_caller_arena() {
	mut document, container, target, mut computer := query_reuse_fixture('@container (width>=200px){.target{color:red}}')
	document.enable_native_storage()
	defer { document.finalize(); document.release_native_storage() }
	key := u64(target.as_node().unique_id().value())
	previous := computer.size_query_matches_[key] or { panic('missing initial query record') }
	rule := previous.values[0].rule
	computer.size_query_matches_.delete(key)
	mut scratch := platform.new_arena('size query CSSOM caller')
	entry := scratch.enter()
	assert rule.container_rule_matches(dom.AbstractElement.new(target,none))
	$if prealloc {
		record := computer.size_query_matches_[key] or { panic('missing query record') }
		assert !scratch.contains(record.values.data)
	}
	scratch.leave(entry)
	scratch.release()
	query_reuse_resize(container,350)
	assert !target.needs_style_update()
	query_reuse_resize(container,150)
	assert target.needs_style_update()
}
