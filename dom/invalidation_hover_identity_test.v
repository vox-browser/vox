module dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_hover_invalidation_matches_identity_ancestors_and_shadow_hosts_without_node_copies() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	other := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	shadow := host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := shadow.as_node()
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	shadow_node.append_child(child.as_node()) or { panic(err) }
	set := StyleInvalidationSet{properties: [InvalidationProperty{
		type_: .pseudo_class
		pseudo_class_name: 'hover'
	}]}
	assert !host.includes_properties_from_invalidation_set(set)
	document.set_hovered_node(child.as_node())
	assert child.includes_properties_from_invalidation_set(set)
	assert host.includes_properties_from_invalidation_set(set)
	assert !other.includes_properties_from_invalidation_set(set)
	$if gcboehm ? {
		before := C.GC_get_total_bytes()
		for _ in 0 .. 10_000 {
			assert child.includes_properties_from_invalidation_set(set)
			assert host.includes_properties_from_invalidation_set(set)
			assert !other.includes_properties_from_invalidation_set(set)
		}
		assert C.GC_get_total_bytes() - before < 4096
	}
	document.set_hovered_node(other.as_node())
	assert !child.includes_properties_from_invalidation_set(set)
	assert !host.includes_properties_from_invalidation_set(set)
	assert other.includes_properties_from_invalidation_set(set)
	document.set_hovered_node(none)
	assert !other.includes_properties_from_invalidation_set(set)
}
