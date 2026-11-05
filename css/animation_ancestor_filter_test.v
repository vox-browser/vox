module css

import dom

fn animation_ancestor_value(element &dom.Element, property PropertyID) string {
	style := computed_properties_for_element(element) or { panic('missing computed style') }
	return (style.property(property, .no) or { panic('missing computed property') }).css_text
}

fn animation_ancestor_fixture(custom bool) !(&dom.Document, &StyleComputer, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	mut outer := document.create_element('section')!
	outer.set_attribute_value('class', 'outer')
	mut document_node := document.as_node()
	document_node.append_child(outer.as_node())!
	mut target := document.create_element('div')!
	target.set_attribute_value('class', 'target')
	mut outer_node := outer.as_node()
	outer_node.append_child(target.as_node())!
	mut link := document.create_element('a')!
	link.set_attribute_value('class', 'hero-github')
	mut target_node := target.as_node()
	target_node.append_child(link.as_node())!
	icon := document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	mut link_node := link.as_node()
	link_node.append_child(icon.as_node())!
	keyframes := if custom {
		'from { --icon-size: 20px } to { --icon-size: 30px }'
	} else {
		'from { color: red } to { color: blue }'
	}
	add_document_author_style_sheet(document, '
		.outer .target { --icon-size: 20px; width: var(--icon-size); animation: change 1s linear both }
		.outer .target .hero-github svg { width: 20px; height: 20px }
		@keyframes change { ${keyframes} }
	')
	mut computer := css_style_computer_for(document)
	document.update_style()
	assert animation_ancestor_value(icon, .width) == '20px'
	assert computer.ancestor_filter_.buckets.all(it == 0)
	return document, computer, target, icon
}

fn test_animated_custom_property_recascade_preserves_descendant_selectors() {
	mut document, mut computer, target, icon := animation_ancestor_fixture(true)!
	defer { document.finalize() }
	for time_ms in [250.0, 750.0, 1000.0] {
		computer.set_animation_time_ms(time_ms)
		document.update_style()
		assert animation_ancestor_value(icon, .width) == '20px'
		assert animation_ancestor_value(icon, .height) == '20px'
		assert animation_ancestor_value(target, .width) in ['20px', '30px']
		assert computer.ancestor_filter_.buckets.all(it == 0)
	}
}

fn test_animation_sample_rotation_preserves_descendant_selector_context() {
	$if prealloc {
		mut document, mut computer, _, icon := animation_ancestor_fixture(false)!
		defer { document.finalize() }
		mut samples := computer.animation_sample_storage()
		computer.set_animation_time_ms(100)
		document.update_style()
		before := samples.current_serial
		samples.enter()
		padding := []u8{len: 1024 * 1024, init: 17}
		assert padding[padding.len - 1] == 17
		samples.leave()
		// Force a full refresh without claiming this allocation was one frame's
		// normal sampling demand, which would enlarge its adaptive budget.
		samples.update_start_used = samples.current.usage().used
		samples.update_bytes = 0
		computer.set_animation_time_ms(200)
		document.update_style()
		assert samples.current_serial > before
		assert animation_ancestor_value(icon, .width) == '20px'
		assert animation_ancestor_value(icon, .height) == '20px'
		assert computer.ancestor_filter_.buckets.all(it == 0)
	}
}

fn test_animation_ancestor_seeding_crosses_shadow_hosts_and_preserves_existing_filter() {
	mut document, mut computer, target, _ := animation_ancestor_fixture(false)!
	defer { document.finalize() }
	mut host := unsafe { &dom.Element(target) }
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	inner := document.create_element('div')!
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_node.append_child(inner.as_node())!
	computer.push_ancestor(host)
	before := computer.ancestor_filter_.buckets.clone()
	ancestors := computer.push_animation_recompute_ancestors(dom.AbstractElement.new(inner, none))
	selector := selector_from_text('.outer .target div')
	assert !computer.should_reject_with_ancestor_filter(selector)
	for ancestor in ancestors { computer.pop_ancestor(ancestor) }
	assert computer.ancestor_filter_.buckets == before
	computer.pop_ancestor(host)
	assert computer.ancestor_filter_.buckets.all(it == 0)
}
