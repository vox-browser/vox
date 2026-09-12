module css

import dom

fn shadow_part_test_element(document &dom.Document, tag string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or {
		panic(err)
	}
}

fn shadow_part_test_append_to_root(root &dom.ShadowRoot, child &dom.Element) {
	mut root_node := unsafe { &dom.Node(root) }
	root_node.append_child(child.as_node()) or { panic(err) }
}

fn shadow_part_test_selector(text string) Selector {
	list := parse_selector_with_parser(text, map[string]bool{}) or {
		panic('selector did not parse: ${text}')
	}
	return list.selectors[0]
}

fn test_part_selector_only_matches_direct_child_shadow_trees() {
	document := dom.Document.create(dom.url_about_blank())
	mut outer_host := shadow_part_test_element(document, 'outer-host')
	outer_root := outer_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut inner_host := shadow_part_test_element(document, 'inner-host')
	shadow_part_test_append_to_root(outer_root, inner_host)
	inner_root := inner_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut part := shadow_part_test_element(document, 'span')
	part.set_attribute_value('part', 'label')
	shadow_part_test_append_to_root(inner_root, part)

	selector := shadow_part_test_selector('::part(label)')
	mut document_context := MatchContext{}
	assert !matches(selector, part, none, mut document_context, none, none, .normal, none)

	mut outer_context := MatchContext{
		rule_shadow_root: unsafe { &dom.ShadowRoot(outer_root) }
	}
	assert matches(selector, part, none, mut outer_context, none, none, .normal, none)
}

fn test_part_selector_matches_exported_names_from_the_outer_scope() {
	document := dom.Document.create(dom.url_about_blank())
	mut outer_host := shadow_part_test_element(document, 'outer-host')
	outer_root := outer_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut inner_host := shadow_part_test_element(document, 'inner-host')
	inner_host.set_attribute_value('exportparts', 'private: public')
	shadow_part_test_append_to_root(outer_root, inner_host)
	inner_root := inner_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut part := shadow_part_test_element(document, 'span')
	part.set_attribute_value('part', 'private')
	shadow_part_test_append_to_root(inner_root, part)

	mut document_context := MatchContext{}
	assert matches(shadow_part_test_selector('::part(public)'), part, none, mut document_context, none, none, .normal, none)
	mut original_name_context := MatchContext{}
	assert !matches(shadow_part_test_selector('::part(private)'), part, none, mut original_name_context, none, none, .normal, none)
}

fn test_host_part_selector_can_match_within_its_own_shadow_root() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := shadow_part_test_element(document, 'part-host')
	root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut part := shadow_part_test_element(document, 'span')
	part.set_attribute_value('part', 'label')
	shadow_part_test_append_to_root(root, part)

	mut context := MatchContext{
		rule_shadow_root: unsafe { &dom.ShadowRoot(root) }
	}
	selector := shadow_part_test_selector(':host::part(label)')
	assert matches(selector, part, host, mut context, none, none, .normal, none)
	assert !context.for_host_part_matching

	mut nested_context := MatchContext{
		rule_shadow_root: unsafe { &dom.ShadowRoot(root) }
	}
	nested_selector := shadow_part_test_selector(':is(:host)::part(label)')
	assert matches(nested_selector, part, host, mut nested_context, none, none, .normal, none)
}
