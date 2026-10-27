module dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

struct ObservingScopeMutationCollector {
	host &Element
mut:
	scopes []&StyleScope
	did_attach bool
}

fn test_ordinary_deep_tree_scope_reads_reuse_document_scope_without_allocating() {
	mut document := Document.create(url_about_blank())
	mut root := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut leaf := root.as_node()
	for _ in 0 .. 32 {
		child := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
		leaf.append_child(child.as_node()) or { panic(err) }
		leaf = child.as_node()
	}
	assert document.shadow_roots.len == 0
	expected := document.style_scope()
	mut matches := 0
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 1024 {
		scopes := leaf.observing_style_scopes()
		if voidptr(scopes.first) == voidptr(expected) && scopes.additional.len == 0
			&& voidptr(leaf.style_scope()) == voidptr(expected) {
			matches++
		}
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert matches == 1024
	assert allocated == 0
	gc_collect()
	assert voidptr(leaf.observing_style_scopes().first) == voidptr(expected)
}

fn test_observing_scope_fallback_keeps_nested_order_and_unique_document_scope() {
	mut document := Document.create(url_about_blank())
	mut outer_host := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(outer_host.as_node()) or { panic(err) }
	outer := outer_host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut outer_node := shadow_root_as_node(outer)
	mut inner_host := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	outer_node.append_child(inner_host.as_node()) or { panic(err) }
	inner := inner_host.attach_shadow(ShadowRootInit{mode: .closed}) or { panic(err) }
	mut inner_node := shadow_root_as_node(inner)
	target := document.create_element_ns(namespace_html_uri, 'b') or { panic(err) }
	inner_node.append_child(target.as_node()) or { panic(err) }
	for _ in 0 .. 3 { gc_collect() }
	scopes := target.as_node().observing_style_scopes()
	assert voidptr(scopes.first) == voidptr(inner.style_scope())
	assert scopes.additional.len == 2
	assert voidptr(scopes.additional[0]) == voidptr(outer.style_scope())
	assert voidptr(scopes.additional[1]) == voidptr(document.style_scope())
	// A host observes its own author shadow scope as well as its containing scope.
	host_scopes := inner_host.as_node().observing_style_scopes()
	assert voidptr(host_scopes.first) == voidptr(outer.style_scope())
	assert host_scopes.additional.len == 2
	assert voidptr(host_scopes.additional[0]) == voidptr(inner.style_scope())
	assert voidptr(host_scopes.additional[1]) == voidptr(document.style_scope())
}

fn test_disconnected_shadow_root_registry_and_adoption_choose_current_document_scope() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	mut host := source.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	root := host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut root_node := shadow_root_as_node(root)
	child := source.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	root_node.append_child(child.as_node()) or { panic(err) }
	assert source.shadow_roots.len == 1
	scopes := child.as_node().observing_style_scopes()
	assert voidptr(scopes.first) == voidptr(root.style_scope())
	assert scopes.additional.len == 1
	assert voidptr(scopes.additional[0]) == voidptr(source.style_scope())
	destination.adopt_node(host.as_node())
	assert source.shadow_roots.len == 0
	assert destination.shadow_roots.len == 1
	gc_collect()
	moved := child.as_node().observing_style_scopes()
	assert voidptr(moved.first) == voidptr(root.style_scope())
	assert moved.additional.len == 1
	assert voidptr(moved.additional[0]) == voidptr(destination.style_scope())
	ordinary := source.create_element_ns(namespace_html_uri, 'p') or { panic(err) }
	remaining := ordinary.as_node().observing_style_scopes()
	assert voidptr(remaining.first) == voidptr(source.style_scope())
	assert remaining.additional.len == 0
}

fn test_scope_callback_uses_precomputed_snapshot_when_it_attaches_a_shadow_root() {
	mut document := Document.create(url_about_blank())
	mut host := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut document_node := document.as_node()
	document_node.append_child(host.as_node()) or { panic(err) }
	collector := &ObservingScopeMutationCollector{host: host}
	host.as_node().for_each_style_scope_which_may_observe_the_node(fn [collector] (scope &StyleScope) {
		unsafe {
			mut state := &ObservingScopeMutationCollector(collector)
			state.scopes << scope
			if !state.did_attach {
				state.did_attach = true
				mut target := state.host
				target.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
			}
		}
	})
	assert document.shadow_roots.len == 1
	assert collector.scopes.len == 1
	assert voidptr(collector.scopes[0]) == voidptr(document.style_scope())
	// A later call sees the newly registered shadow root, but the first callback
	// traversal did not acquire a new entry during iteration.
	later := host.as_node().observing_style_scopes()
	assert voidptr(later.first) == voidptr(document.style_scope())
	assert later.additional.len == 1
	root := host.shadow_root() or { panic('callback did not create root') }
	assert voidptr(later.additional[0]) == voidptr(root.style_scope())
}

fn test_style_scope_without_shadow_roots_covers_document_and_detached_deep_nodes() {
	mut document := Document.create(url_about_blank())
	expected := document.style_scope()
	assert voidptr(document.as_node().style_scope()) == voidptr(expected)
	mut detached := document.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	mut parent := detached.as_node()
	for _ in 0 .. 32 {
		child := document.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
		parent.append_child(child.as_node()) or { panic(err) }
		parent = child.as_node()
	}
	assert detached.as_node().parent() == none
	assert document.shadow_roots.len == 0
	assert voidptr(parent.style_scope()) == voidptr(expected)
	gc_collect()
	assert voidptr(parent.style_scope()) == voidptr(expected)
}

fn test_public_style_scope_fallback_tracks_creation_adoption_and_document_sheet_mode() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	mut host := source.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	child := source.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(child.as_node()) or { panic(err) }
	assert voidptr(child.as_node().style_scope()) == voidptr(source.style_scope())
	mut root := host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut root_node := shadow_root_as_node(root)
	root_node.append_child(child.as_node()) or { panic(err) }
	assert voidptr(child.as_node().style_scope()) == voidptr(root.style_scope())
	root.set_uses_document_style_sheets(true)
	assert voidptr(child.as_node().style_scope()) == voidptr(source.style_scope())
	root.set_uses_document_style_sheets(false)
	assert voidptr(child.as_node().style_scope()) == voidptr(root.style_scope())
	destination.adopt_node(host.as_node())
	assert source.shadow_roots.len == 0
	assert destination.shadow_roots.len == 1
	assert voidptr(host_node.style_scope()) == voidptr(destination.style_scope())
	assert voidptr(child.as_node().style_scope()) == voidptr(root.style_scope())
	root.set_uses_document_style_sheets(true)
	gc_collect()
	assert voidptr(child.as_node().style_scope()) == voidptr(destination.style_scope())
	assert voidptr(source.as_node().style_scope()) == voidptr(source.style_scope())
}

struct StyleScopeAdoptionProbe {
	descendant &Node
	root &ShadowRoot
	destination &Document
	nested ?&Node
mut:
	outer_calls int
	nested_calls int
	scope_checks int
	outer_depth u32
	nested_depth u32
	after_nested_depth u32
}

fn style_scope_adoption_probe_matches(probe &StyleScopeAdoptionProbe) bool {
	if voidptr(probe.descendant.document()) != voidptr(probe.destination) {
		return false
	}
	if voidptr(probe.descendant.style_scope()) != voidptr(probe.root.style_scope()) {
		return false
	}
	scopes := probe.descendant.observing_style_scopes()
	return voidptr(scopes.first) == voidptr(probe.root.style_scope())
		&& scopes.additional.len == 1
		&& voidptr(scopes.additional[0]) == voidptr(probe.destination.style_scope())
}

fn style_scope_nested_adoption_hook(target voidptr, old_document &Document) {
	_ = old_document
	unsafe {
		mut probe := &StyleScopeAdoptionProbe(target)
		probe.nested_calls++
		probe.nested_depth = probe.destination.style_scope_adoption_depth_
		assert probe.destination.shadow_roots.len == 0
		if style_scope_adoption_probe_matches(probe) { probe.scope_checks++ }
	}
}

fn style_scope_outer_adoption_hook(target voidptr, old_document &Document) {
	_ = old_document
	unsafe {
		mut probe := &StyleScopeAdoptionProbe(target)
		probe.outer_calls++
		probe.outer_depth = probe.destination.style_scope_adoption_depth_
		// All descendant document pointers already changed, while the host's
		// nested shadow root has not reached its own adopting steps yet.
		assert probe.destination.shadow_roots.len == 0
		if style_scope_adoption_probe_matches(probe) { probe.scope_checks++ }
		if nested := probe.nested {
			mut destination := &Document(probe.destination)
			destination.adopt_node(nested)
			probe.after_nested_depth = destination.style_scope_adoption_depth_
			assert destination.shadow_roots.len == 0
			if style_scope_adoption_probe_matches(probe) { probe.scope_checks++ }
		}
	}
}

fn test_adopting_host_hook_preserves_shadow_scope_before_destination_registration() {
	mut source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	mut host := source.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	root := host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut root_node := shadow_root_as_node(root)
	child := source.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	root_node.append_child(child.as_node()) or { panic(err) }
	probe := &StyleScopeAdoptionProbe{descendant: child.as_node(), root: root, destination: destination}
	mut host_node := host.as_node()
	host_node.set_adopted_from_hook(NodeAdoptedFromHook{
		target: voidptr(probe)
		callback: style_scope_outer_adoption_hook
	})
	destination.adopt_node(host_node)
	assert probe.outer_calls == 1
	assert probe.outer_depth == 1
	assert probe.scope_checks == 1
	assert destination.style_scope_adoption_depth_ == 0
	assert source.style_scope_adoption_depth_ == 0
	assert source.shadow_roots.len == 0
	assert destination.shadow_roots.len == 1
	gc_collect()
	assert style_scope_adoption_probe_matches(probe)
}

fn test_reentrant_adoption_depth_stays_guarded_until_outer_hooks_finish() {
	mut source := Document.create(url_about_blank())
	mut nested_source := Document.create(url_about_blank())
	mut destination := Document.create(url_about_blank())
	mut host := source.create_element_ns(namespace_html_uri, 'div') or { panic(err) }
	root := host.attach_shadow(ShadowRootInit{mode: .open}) or { panic(err) }
	mut root_node := shadow_root_as_node(root)
	child := source.create_element_ns(namespace_html_uri, 'span') or { panic(err) }
	root_node.append_child(child.as_node()) or { panic(err) }
	nested := nested_source.create_element_ns(namespace_html_uri, 'p') or { panic(err) }
	probe := &StyleScopeAdoptionProbe{
		descendant: child.as_node()
		root: root
		destination: destination
		nested: nested.as_node()
	}
	mut host_node := host.as_node()
	host_node.set_adopted_from_hook(NodeAdoptedFromHook{target: voidptr(probe), callback: style_scope_outer_adoption_hook})
	mut nested_node := nested.as_node()
	nested_node.set_adopted_from_hook(NodeAdoptedFromHook{target: voidptr(probe), callback: style_scope_nested_adoption_hook})
	destination.adopt_node(host_node)
	assert probe.outer_calls == 1
	assert probe.nested_calls == 1
	assert probe.outer_depth == 1
	assert probe.nested_depth == 2
	assert probe.after_nested_depth == 1
	assert probe.scope_checks == 3
	assert destination.style_scope_adoption_depth_ == 0
	assert voidptr(nested_node.document()) == voidptr(destination)
	assert destination.shadow_roots.len == 1
	// Same-document adoption does not enter the guarded cross-document steps.
	destination.adopt_node(host_node)
	assert destination.style_scope_adoption_depth_ == 0
	assert probe.outer_calls == 1
	assert probe.nested_calls == 1
	gc_collect()
	assert style_scope_adoption_probe_matches(probe)
}
