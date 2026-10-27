module dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

// Keep the previous root-based collection as an independent ordering oracle.
fn segment_scope_reference_scope(node &Node) &StyleScope {
	root := node.root()
	if shadow := root.as_shadow_root() {
		if shadow.uses_document_style_sheets() {
			return node.document().style_scope()
		}
		return shadow.style_scope()
	}
	return node.document().style_scope()
}

fn segment_scope_reference_add(mut scopes []&StyleScope, scope &StyleScope) {
	if scope !in scopes {
		scopes << scope
	}
}

fn segment_scope_reference(node &Node) []&StyleScope {
	mut scopes := []&StyleScope{cap: 4}
	segment_scope_reference_add(mut scopes, segment_scope_reference_scope(node))
	if element := node.as_element() {
		if root := element.shadow_root() {
			segment_scope_reference_add(mut scopes, root.style_scope())
		}
	}
	for ancestor := node.parent_or_shadow_host(); ancestor != none; {
		current := ancestor or { break }
		segment_scope_reference_add(mut scopes, segment_scope_reference_scope(current))
		if element := current.as_element() {
			if root := element.shadow_root() {
				segment_scope_reference_add(mut scopes, root.style_scope())
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return scopes
}

fn segment_scope_assert_reference(node &Node) {
	expected := segment_scope_reference(node)
	actual := node.observing_style_scopes()
	assert voidptr(actual.first) == voidptr(expected[0])
	assert actual.additional.len == expected.len - 1
	for index, scope in actual.additional {
		assert voidptr(scope) == voidptr(expected[index + 1])
	}
}

fn segment_scope_element(document &Document, name string) &Element {
	return document.create_element_ns(namespace_html_uri, name) or { panic(err) }
}

fn segment_scope_append(parent &Node, child &Node) {
	mut mutable_parent := unsafe { &Node(parent) }
	mutable_parent.append_child(child) or { panic(err) }
}

fn segment_scope_deep_branch(document &Document, parent &Node, depth int) &Node {
	mut leaf := parent
	for _ in 0 .. depth {
		child := segment_scope_element(document, 'span')
		segment_scope_append(leaf, child.as_node())
		leaf = child.as_node()
	}
	return leaf
}

fn test_segment_scopes_match_reference_on_deep_ordinary_branches_with_unrelated_root() {
	document := Document.create(url_about_blank())
	mut unrelated := segment_scope_element(document, 'div')
	unrelated.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	ordinary := segment_scope_element(document, 'section')
	segment_scope_append(document.as_node(), ordinary.as_node())
	leaf := segment_scope_deep_branch(document, ordinary.as_node(), 64)
	assert document.shadow_roots.len == 1
	segment_scope_assert_reference(document.as_node())
	segment_scope_assert_reference(ordinary.as_node())
	segment_scope_assert_reference(leaf)
	gc_collect()
	segment_scope_assert_reference(leaf)
}

fn test_segment_scope_ordinary_fallback_reads_allocate_nothing_with_unrelated_root() {
	document := Document.create(url_about_blank())
	mut unrelated := segment_scope_element(document, 'div')
	unrelated.attach_shadow(ShadowRootInit{mode: .closed}) or { panic(err) }
	ordinary := segment_scope_element(document, 'section')
	segment_scope_append(document.as_node(), ordinary.as_node())
	leaf := segment_scope_deep_branch(document, ordinary.as_node(), 64)
	expected := document.style_scope()
	// Warm every lazy scope before the allocation window; no assertions inside it.
	segment_scope_assert_reference(leaf)
	gc_collect()
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut matched := 0
	for _ in 0 .. 1024 {
		actual := leaf.observing_style_scopes()
		if voidptr(actual.first) == voidptr(expected) && actual.additional.len == 0
			&& actual.additional.cap == 0 {
			matched++
		}
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert matched == 1024
	assert allocated == 0
	assert document.shadow_roots.len == 1
	segment_scope_assert_reference(leaf)
}

fn test_segment_scopes_match_nested_author_and_document_sheet_user_agent_roots() {
	document := Document.create(url_about_blank())
	mut outer_host := segment_scope_element(document, 'div')
	segment_scope_append(document.as_node(), outer_host.as_node())
	outer := outer_host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut ua_host := segment_scope_element(document, 'span')
	segment_scope_append(shadow_root_as_node(outer), ua_host.as_node())
	mut ua := ua_host.attach_a_user_agent_shadow_root(.named)
	ua.set_uses_document_style_sheets(true)
	mut inner_host := segment_scope_element(document, 'div')
	segment_scope_append(shadow_root_as_node(ua), inner_host.as_node())
	inner := inner_host.attach_shadow(ShadowRootInit{mode: .closed}) or { panic(err) }
	leaf := segment_scope_deep_branch(document, shadow_root_as_node(inner), 16)
	for node in [leaf, inner_host.as_node(), shadow_root_as_node(inner), ua_host.as_node(),
		shadow_root_as_node(ua), outer_host.as_node(), shadow_root_as_node(outer)] {
		segment_scope_assert_reference(node)
	}
	actual := leaf.observing_style_scopes()
	assert voidptr(actual.first) == voidptr(inner.style_scope())
	assert actual.additional.len == 3
	assert voidptr(actual.additional[0]) == voidptr(document.style_scope())
	assert voidptr(actual.additional[1]) == voidptr(outer.style_scope())
	assert voidptr(actual.additional[2]) == voidptr(ua.style_scope())
	ua.set_uses_document_style_sheets(false)
	gc_collect()
	segment_scope_assert_reference(leaf)
	changed := leaf.observing_style_scopes()
	assert voidptr(changed.additional[0]) == voidptr(ua.style_scope())
	assert voidptr(changed.additional[1]) == voidptr(outer.style_scope())
	assert voidptr(changed.additional[2]) == voidptr(document.style_scope())
}

fn test_segment_scopes_preserve_light_child_order_under_multiple_shadow_hosts() {
	document := Document.create(url_about_blank())
	mut outer_host := segment_scope_element(document, 'div')
	segment_scope_append(document.as_node(), outer_host.as_node())
	outer := outer_host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut inner_host := segment_scope_element(document, 'span')
	segment_scope_append(outer_host.as_node(), inner_host.as_node())
	mut inner := inner_host.attach_a_user_agent_shadow_root(.named)
	inner.set_uses_document_style_sheets(true)
	leaf := segment_scope_deep_branch(document, inner_host.as_node(), 8)
	segment_scope_assert_reference(leaf)
	segment_scope_assert_reference(inner_host.as_node())
	segment_scope_assert_reference(outer_host.as_node())
	actual := leaf.observing_style_scopes()
	assert voidptr(actual.first) == voidptr(document.style_scope())
	assert actual.additional.len == 2
	assert voidptr(actual.additional[0]) == voidptr(inner.style_scope())
	assert voidptr(actual.additional[1]) == voidptr(outer.style_scope())
}

fn test_segment_scopes_match_reference_for_detached_document_fragment_roots() {
	document := Document.create(url_about_blank())
	mut unrelated := segment_scope_element(document, 'div')
	unrelated.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	fragment := document.create_document_fragment()
	branch := segment_scope_element(document, 'section')
	segment_scope_append(fragment.as_node(), branch.as_node())
	leaf := segment_scope_deep_branch(document, branch.as_node(), 32)
	assert fragment.as_node().parent() == none
	segment_scope_assert_reference(fragment.as_node())
	segment_scope_assert_reference(branch.as_node())
	segment_scope_assert_reference(leaf)
	actual := leaf.observing_style_scopes()
	assert voidptr(actual.first) == voidptr(document.style_scope())
	assert actual.additional.len == 0
	gc_collect()
	segment_scope_assert_reference(leaf)
}

struct SegmentScopeReparentCollector {
	target &Node
	parent &Node
mut:
	scopes []&StyleScope
	did_move bool
}

fn test_segment_scope_callbacks_keep_fallback_snapshot_after_reparenting() {
	document := Document.create(url_about_blank())
	mut host := segment_scope_element(document, 'div')
	segment_scope_append(document.as_node(), host.as_node())
	root := host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	leaf := segment_scope_element(document, 'span')
	segment_scope_append(host.as_node(), leaf.as_node())
	collector := &SegmentScopeReparentCollector{
		target: leaf.as_node()
		parent: shadow_root_as_node(root)
	}
	leaf.as_node().for_each_style_scope_which_may_observe_the_node(fn [collector] (scope &StyleScope) {
		unsafe {
			mut state := &SegmentScopeReparentCollector(collector)
			state.scopes << scope
			if !state.did_move {
				state.did_move = true
				segment_scope_append(state.parent, state.target)
			}
		}
	})
	assert collector.scopes.len == 2
	assert voidptr(collector.scopes[0]) == voidptr(document.style_scope())
	assert voidptr(collector.scopes[1]) == voidptr(root.style_scope())
	later := leaf.as_node().observing_style_scopes()
	assert voidptr(later.first) == voidptr(root.style_scope())
	assert later.additional.len == 1
	assert voidptr(later.additional[0]) == voidptr(document.style_scope())
	gc_collect()
	segment_scope_assert_reference(leaf.as_node())
}
