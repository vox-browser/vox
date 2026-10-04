module dom

fn source_base_lifecycle_document(address string) !&Document {
	mut document := Document.create(URL{ value: address })
	document.set_document_type(.html)
	html := document.create_element('html')!
	head := document.create_element('head')!
	mut document_node := document.as_node()
	document_node.append_child(html.as_node())!
	mut html_node := html.as_node()
	html_node.append_child(head.as_node())!
	return document
}

fn test_source_base_insertion_freezes_actual_first_element_and_retains_fallback_snapshot() {
	mut document := source_base_lifecycle_document('https://base.test/root/page.html')!
	defer { document.finalize() }
	head := document.head()?
	mut head_node := head.as_node()
	mut later := document.create_element('base')!
	later.set_attribute_value('href', 'later/')
	head_node.append_child(later.as_node())!
	later_base := unsafe { &HTMLBaseElement(later) }
	assert voidptr(document.first_base_element_with_href_in_tree_order()?) == voidptr(later)
	assert later_base.frozen_base_url_initialized_
	assert document.base_url().serialize() == 'https://base.test/root/later/'
	mut first := document.create_element('base')!
	first.set_attribute_value('href', 'first/')
	first.set_attribute_value('id', 'actual-base')
	head_node.insert_before(first.as_node(), later.as_node(), false)
	assert voidptr(document.first_base_element_with_href_in_tree_order()?) == voidptr(first)
	assert voidptr(document.get_element_by_id('actual-base')?) == voidptr(first)
	assert document.base_url().serialize() == 'https://base.test/root/first/'
	document.set_url(URL{ value: 'https://base.test/new/document.html' })
	assert document.base_url().serialize() == 'https://base.test/root/first/'
	first.set_attribute_value('href', 'changed/')
	assert document.base_url().serialize() == 'https://base.test/new/changed/'
	assert document.encoding_parse_url('image.png')?.serialize() == 'https://base.test/new/changed/image.png'
}

fn test_source_base_attribute_dispatch_preserves_parent_steps_and_source_namespace_behavior() {
	mut document := source_base_lifecycle_document('https://base.test/root/page.html')!
	defer { document.finalize() }
	head := document.head()?
	mut head_node := head.as_node()
	mut base := document.create_element('base')!
	head_node.append_child(base.as_node())!
	assert document.first_base_element_with_href_in_tree_order() == none
	base.set_attribute_value('href', 'first/')
	assert document.base_url().serialize() == 'https://base.test/root/first/'
	base.set_attribute_value('id', 'parent-attribute')
	base.set_attribute_value('onclick', 'parent event handler')
	assert voidptr(document.get_element_by_id('parent-attribute')?) == voidptr(base)
	assert unsafe { &EventTarget(base) }.has_event_listener('click')
	document.set_url(URL{ value: 'https://base.test/new/page.html' })
	base.set_attribute_value('title', 'does not refreeze')
	assert document.base_url().serialize() == 'https://base.test/root/first/'
	// Source checks the local name after the parent hook even for a namespace.
	base.set_attribute_value_ns('href', 'namespaced value', 'custom', 'urn:base')
	assert document.base_url().serialize() == 'https://base.test/new/first/'
	base.remove_attribute('href')
	assert document.first_base_element_with_href_in_tree_order() == none
	assert document.base_url() == document.fallback_base_url()
}

@[heap]
struct SourceBaseRemovalObservation {
mut:
	calls           int
	is_subtree_root NodeIsSubtreeRoot
	old_ancestor    ?&Node
	old_root        ?&Node
}

fn source_base_record_removal(target voidptr, is_subtree_root NodeIsSubtreeRoot, old_ancestor ?&Node, old_root &Node) {
	mut observation := unsafe { &SourceBaseRemovalObservation(target) }
	observation.calls++
	observation.is_subtree_root = is_subtree_root
	observation.old_ancestor = old_ancestor
	observation.old_root = old_root
}

fn test_source_base_removal_dispatches_descendants_with_actual_context_and_freezes_new_first() {
	mut document := source_base_lifecycle_document('https://base.test/root/page.html')!
	defer { document.finalize() }
	head := document.head()?
	mut head_node := head.as_node()
	wrapper := document.create_element('div')!
	mut wrapper_node := wrapper.as_node()
	mut first := document.create_element('base')!
	first.set_attribute_value('href', 'first/')
	first.set_attribute_value('id', 'removed-base')
	wrapper_node.append_child(first.as_node())!
	head_node.append_child(wrapper_node)!
	mut second := document.create_element('base')!
	second.set_attribute_value('href', 'second/')
	second.set_attribute_value('target', 'actual-target')
	head_node.append_child(second.as_node())!
	assert document.base_url().serialize() == 'https://base.test/root/first/'
	assert !unsafe { &HTMLBaseElement(second) }.frozen_base_url_initialized_
	mut observation := &SourceBaseRemovalObservation{}
	mut first_node := first.as_node()
	first_node.set_lifecycle_hook(NodeLifecycleHook{ target: observation, removed_from: source_base_record_removal })
	document.set_url(URL{ value: 'https://base.test/new/page.html' })
	wrapper_node.remove(false)
	assert observation.calls == 1 && observation.is_subtree_root == .no
	assert voidptr(observation.old_ancestor?) == voidptr(head_node)
	assert voidptr(observation.old_root?) == voidptr(document.as_node())
	assert document.get_element_by_id('removed-base') == none
	assert voidptr(document.first_base_element_with_href_in_tree_order()?) == voidptr(second)
	assert voidptr(document.first_base_element_with_target_in_tree_order()?) == voidptr(second)
	assert document.base_url().serialize() == 'https://base.test/new/second/'
	mut second_node := second.as_node()
	second_node.set_lifecycle_hook(NodeLifecycleHook{
		target:       observation
		removed_from: source_base_record_removal
	})
	second_node.remove(false)
	assert observation.calls == 2 && observation.is_subtree_root == .yes
	assert voidptr(observation.old_ancestor?) == voidptr(head_node)
	assert voidptr(observation.old_root?) == voidptr(document.as_node())
	assert document.first_base_element_with_href_in_tree_order() == none
	assert document.first_base_element_with_target_in_tree_order() == none
	assert document.base_url() == document.fallback_base_url()
}

fn test_source_base_adoption_uses_actual_current_document_and_removes_old_cached_identity() {
	mut source := source_base_lifecycle_document('https://old-base.test/root/page.html')!
	mut destination := source_base_lifecycle_document('https://new-base.test/other/page.html')!
	defer {
		source.finalize()
		destination.finalize()
	}
	mut base := source.create_element('base')!
	base.set_attribute_value('href', 'assets/')
	source_head := source.head()?
	mut source_head_node := source_head.as_node()
	source_head_node.append_child(base.as_node())!
	assert source.base_url().serialize() == 'https://old-base.test/root/assets/'
	destination_head := destination.head()?
	mut destination_head_node := destination_head.as_node()
	destination_head_node.append_child(base.as_node())!
	assert voidptr(base.document()) == voidptr(destination)
	assert source.first_base_element_with_href_in_tree_order() == none
	assert source.base_url() == source.fallback_base_url()
	assert voidptr(destination.first_base_element_with_href_in_tree_order()?) == voidptr(base)
	assert destination.base_url().serialize() == 'https://new-base.test/other/assets/'
}

fn test_source_base_dispatch_excludes_other_namespaces_and_keeps_disallowed_url_fallback() {
	mut document := source_base_lifecycle_document('https://base.test/root/page.html')!
	defer { document.finalize() }
	head := document.head()?
	mut head_node := head.as_node()
	mut foreign := document.create_element_ns('urn:foreign', 'base')!
	foreign.set_attribute_value('href', 'https://wrong.test/')
	head_node.append_child(foreign.as_node())!
	assert document.first_base_element_with_href_in_tree_order() == none
	mut base := document.create_element('base')!
	base.set_attribute_value('href', 'data:text/html,wrong')
	head_node.append_child(base.as_node())!
	assert unsafe { &HTMLBaseElement(base) }.frozen_base_url_initialized_
	assert document.base_url() == document.fallback_base_url()
	base.set_attribute_value('href', 'javascript:wrong()')
	assert document.base_url() == document.fallback_base_url()
	base.set_attribute_value('href', 'http://[invalid')
	assert document.base_url() == document.fallback_base_url()
	base.set_attribute_value('href', 'allowed/')
	assert document.base_url().serialize() == 'https://base.test/root/allowed/'
}
