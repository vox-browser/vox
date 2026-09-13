module css

import dom

fn invalidation_test_selector(text string) Selector {
	list := parse_selector_with_parser(text, map[string]bool{}) or {
		panic('selector did not parse: ${text}')
	}
	return list.selectors[0]
}

fn test_pseudo_class_invalidation_matches_only_the_selector_target() {
	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}

	assert selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div'), element)
	assert selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div::before'), element)
	assert selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div::after'), element)
	assert !selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('div::first-line'), element)
	assert !selector_matches_pseudo_class_invalidation_candidate(invalidation_test_selector('span::before'), element)
}

fn pseudo_class_invalidation_set(pseudo_class CSSPseudoClass) dom.StyleInvalidationSet {
	mut set := InvalidationSet{}
	set.set_needs_invalidate_pseudo_class(pseudo_class)
	return invalidation_set_to_dom(set)
}

fn test_targetable_pseudo_class_invalidation_matches_current_document_state() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	mut hover_parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut hovered := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut focus_parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut focused := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input') or { panic(err) }
	mut active := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button') or { panic(err) }
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	mut bystander := document.create_element_ns('http://www.w3.org/1999/xhtml', 'aside') or { panic(err) }
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'x-host') or { panic(err) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(hover_parent.as_node()) or { panic(err) }
	mut hover_parent_node := hover_parent.as_node()
	hover_parent_node.append_child(hovered.as_node()) or { panic(err) }
	root_node.append_child(focus_parent.as_node()) or { panic(err) }
	mut focus_parent_node := focus_parent.as_node()
	focus_parent_node.append_child(focused.as_node()) or { panic(err) }
	root_node.append_child(active.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	root_node.append_child(host.as_node()) or { panic(err) }
	host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	document.set_hovered_node(hovered.as_node())
	document.set_focused_area(focused.as_node())
	active.set_being_activated(true)
	document.set_target_element(target)

	root_set := pseudo_class_invalidation_set(.root)
	assert root.includes_properties_from_invalidation_set(root_set)
	assert !bystander.includes_properties_from_invalidation_set(root_set)
	host_set := pseudo_class_invalidation_set(.host)
	assert host.includes_properties_from_invalidation_set(host_set)
	assert !bystander.includes_properties_from_invalidation_set(host_set)
	hover_set := pseudo_class_invalidation_set(.hover)
	assert hovered.includes_properties_from_invalidation_set(hover_set)
	assert hover_parent.includes_properties_from_invalidation_set(hover_set)
	assert root.includes_properties_from_invalidation_set(hover_set)
	assert !bystander.includes_properties_from_invalidation_set(hover_set)
	focus_set := pseudo_class_invalidation_set(.focus)
	assert focused.includes_properties_from_invalidation_set(focus_set)
	assert !focus_parent.includes_properties_from_invalidation_set(focus_set)
	assert focused.includes_properties_from_invalidation_set(pseudo_class_invalidation_set(.focus_visible))
	focus_within_set := pseudo_class_invalidation_set(.focus_within)
	assert focused.includes_properties_from_invalidation_set(focus_within_set)
	assert focus_parent.includes_properties_from_invalidation_set(focus_within_set)
	assert !bystander.includes_properties_from_invalidation_set(focus_within_set)
	assert active.includes_properties_from_invalidation_set(pseudo_class_invalidation_set(.active))
	assert target.includes_properties_from_invalidation_set(pseudo_class_invalidation_set(.target))
}

fn test_structural_position_invalidation_matches_element_sibling_boundaries() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut first := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut middle := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut last := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut only_parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut only := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(first.as_node()) or { panic(err) }
	parent_node.append_child(middle.as_node()) or { panic(err) }
	parent_node.append_child(last.as_node()) or { panic(err) }
	mut only_parent_node := only_parent.as_node()
	only_parent_node.append_child(only.as_node()) or { panic(err) }

	first_set := pseudo_class_invalidation_set(.first_child)
	assert first.includes_properties_from_invalidation_set(first_set)
	assert !middle.includes_properties_from_invalidation_set(first_set)
	assert !last.includes_properties_from_invalidation_set(first_set)
	last_set := pseudo_class_invalidation_set(.last_child)
	assert !first.includes_properties_from_invalidation_set(last_set)
	assert !middle.includes_properties_from_invalidation_set(last_set)
	assert last.includes_properties_from_invalidation_set(last_set)
	only_set := pseudo_class_invalidation_set(.only_child)
	assert only.includes_properties_from_invalidation_set(only_set)
	assert !first.includes_properties_from_invalidation_set(only_set)
	assert !last.includes_properties_from_invalidation_set(only_set)
}
