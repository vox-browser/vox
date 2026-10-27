module dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_node_identity_distinguishes_equal_contents_and_preserves_record_copies() {
	document := Document.create(url_about_blank())
	first := document.create_text_node('same text').as_node()
	second := document.create_text_node('same text').as_node()
	assert first == first
	assert first != second
	assert first.is_same_node(first)
	assert !first.is_same_node(second)
	assert first.is_equal_node(second)
	copy := *first
	assert copy == *first
	assert first == copy
}

fn test_node_ancestry_uses_identity_in_connected_and_shadow_trees() {
	document := Document.create(url_about_blank())
	mut parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or { panic(err) }
	unrelated := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	assert child.as_node().is_descendant_of(parent_node)
	assert parent_node.is_inclusive_ancestor_of(parent_node)
	assert parent_node.is_inclusive_ancestor_of(child.as_node())
	assert !unrelated.as_node().is_descendant_of(parent_node)
	shadow := parent.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := shadow.as_node()
	shadow_child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	shadow_node.append_child(shadow_child.as_node()) or { panic(err) }
	assert !shadow_child.as_node().is_descendant_of(parent_node)
	assert parent_node.is_shadow_including_ancestor_of(shadow_child.as_node())
}

fn test_repeated_node_identity_checks_do_not_allocate_temporary_records() {
	document := Document.create(url_about_blank())
	parent := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	first := document.create_text_node('first').as_node()
	second := document.create_text_node('second').as_node()
	mut parent_node := parent.as_node()
	parent_node.append_child(first) or { panic(err) }
	assert first != second
	$if gcboehm ? {
		before := C.GC_get_total_bytes()
		for _ in 0 .. 10_000 {
			assert first.is_same_node(first)
			assert !first.is_same_node(second)
			assert first.is_descendant_of(parent_node)
			assert !second.is_descendant_of(parent_node)
		}
		assert C.GC_get_total_bytes() - before < 4096
	} $else {
		for _ in 0 .. 10_000 {
			assert first.is_same_node(first)
			assert !first.is_same_node(second)
			assert first.is_descendant_of(parent_node)
			assert !second.is_descendant_of(parent_node)
		}
	}
}
