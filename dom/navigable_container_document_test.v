module dom

fn test_container_navigable_lookup_preserves_identity_and_navigation_gaps() {
	mut parent := Document.create(url_about_blank())
	mut first := Document.create(url_about_blank())
	mut second := Document.create(url_about_blank())
	a := parent.create_element_ns(namespace_html_uri, 'iframe')!
	b := parent.create_element_ns(namespace_html_uri, 'iframe')!
	mut one := &Navigable{ container_: a.as_node(), active_document_: first }
	mut two := &Navigable{ container_: b.as_node(), active_document_: second }
	first.set_navigable(one)
	second.set_navigable(two)
	defer {
		one.remove_from_all_navigables()
		two.remove_from_all_navigables()
		parent.finalize()
		first.finalize()
		second.finalize()
	}
	assert voidptr(a.as_node().content_navigable()?) == voidptr(one)
	assert voidptr(b.as_node().content_navigable()?) == voidptr(two)
	one.set_active_document(none)
	assert voidptr(a.as_node().content_navigable()?) == voidptr(one)
	assert a.as_node().content_navigable()?.active_document() == none
	one.has_been_destroyed_ = true
	assert a.as_node().content_navigable() == none
	assert voidptr(b.as_node().content_navigable()?) == voidptr(two)
}
