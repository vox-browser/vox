module dom

fn test_active_state_keeps_legacy_invalidation_and_ignores_equal_writes() {
	mut document := Document.create(url_about_blank())
	mut element := document.create_element('div')!
	mut node := element.as_node()
	node.set_entire_subtree_needs_style_update(false)
	element.set_being_activated(true)
	assert element.is_being_activated()
	assert node.entire_subtree_needs_style_update()
	node.set_entire_subtree_needs_style_update(false)
	element.set_being_activated(true)
	assert !node.entire_subtree_needs_style_update()
	element.set_being_activated(false)
	assert !element.is_being_activated()
	assert node.entire_subtree_needs_style_update()
}
