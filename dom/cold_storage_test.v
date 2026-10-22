module dom

import platform

fn test_ordinary_dom_cold_state_reads_and_empty_resets_do_not_allocate() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(namespace_html_uri, 'div')!
	mut node := element.as_node()
	mut target := unsafe { &EventTarget(node) }
	assert element.custom_data_ == unsafe { nil }
	assert element.binding_data_ == unsafe { nil }
	assert element.dependency_data_ == unsafe { nil }
	assert node.cold_data_ == unsafe { nil }
	assert target.data.cold_data_ == unsafe { nil }
	before := platform.thread_arena_usage().used
	for _ in 0 .. 256 {
		assert element.part_names().len == 0 && !element.has_part_names()
		assert element.custom_element_is_value() == none
		assert element.custom_element_definition() == none
		assert element.custom_state_set() == none
		assert element.ensure_custom_element_reaction_queue().len == 0
		assert element.take_custom_element_reactions().len == 0
		assert !element.has_registered_intersection_observer(voidptr(node))
		element.unregister_intersection_observer(voidptr(node))
		element.clear_removed_attributes_for_style_invalidation()
		element.set_is_value(none)
		element.set_custom_element_definition(none)
		assert node.registered_observer_list().len == 0
		assert node.slottable_name() == ''
		node.set_slottable_name('')
		node.set_assigned_slot(none)
		node.set_manual_slot_assignment(none)
		node.clear_registered_observers()
		assert !target.has_event_listeners()
		assert target.data.event_handler_count() == 0
		target.event_listener_list_changed()
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	assert element.custom_data_ == unsafe { nil }
	assert element.binding_data_ == unsafe { nil }
	assert element.dependency_data_ == unsafe { nil }
	assert node.cold_data_ == unsafe { nil }
	assert target.data.cold_data_ == unsafe { nil }
}

fn test_node_cold_storage_copies_membership_and_keeps_live_observer_identity() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(namespace_html_uri, 'span')!
	mut node := element.as_node()
	slot_element := document.create_element_ns(namespace_html_uri, 'slot')!
	slot := unsafe { &HTMLSlotElement(slot_element) }
	mut observer := MutationObserver.construct_impl(none)!
	registered := RegisteredObserver.create(observer, MutationObserverOptions{ attributes: true })
	node.add_registered_observer(registered)
	node.set_slottable_name('first')
	node.set_assigned_slot(slot)
	node.set_manual_slot_assignment(slot)
	snapshot := *node
	mut public_list := node.registered_observer_list()
	public_list.clear()
	assert node.registered_observer_list().len == 1
	mut options := MutationObserverOptions{ attributes: true, attribute_old_value: true }
	observer.observe(node, mut options)!
	assert snapshot.registered_observer_list()[0].options().attribute_old_value or { false }
	node.add_registered_observer(RegisteredObserver.create(observer, MutationObserverOptions{}))
	node.set_slottable_name('second')
	node.set_assigned_slot(none)
	node.set_manual_slot_assignment(none)
	assert snapshot.slottable_name() == 'first'
	assert snapshot.registered_observer_list().len == 1
	assert voidptr(snapshot.assigned_slot_internal() or { panic('lost slot') }) == voidptr(slot)
	assert voidptr(snapshot.manual_slot_assignment() or { panic('lost manual slot') }) == voidptr(slot)
	assert node.registered_observer_list().len == 2
	node.remove_registered_observer_at(0)
	assert node.registered_observer_list().len == 1
	node.clear_registered_observers()
	assert node.registered_observer_list().len == 0
	assert snapshot.registered_observer_list().len == 1
}

fn test_element_custom_storage_copies_values_and_queue_membership() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(namespace_html_uri, 'div')!
	definition := CustomElementDefinition.create('x-first', 'div', [], false, false, false)
	element.set_is_value('x-first')
	element.set_custom_element_definition(definition)
	element.enqueue_a_custom_element_callback_reaction('connectedCallback', ['first'])
	mut states := element.ensure_custom_state_set()
	snapshot := *element
	element.set_is_value('x-next')
	element.set_custom_element_definition(none)
	element.enqueue_a_custom_element_callback_reaction('connectedCallback', ['second'])
	mut reactions := element.ensure_custom_element_reaction_queue()
	reactions.clear()
	assert element.ensure_custom_element_reaction_queue().len == 2
	assert element.take_custom_element_reactions().len == 2
	assert element.ensure_custom_element_reaction_queue().len == 0
	assert snapshot.ensure_custom_element_reaction_queue().len == 1
	assert snapshot.custom_element_is_value() or { '' } == 'x-first'
	assert element.custom_element_is_value() or { '' } == 'x-next'
	assert voidptr(snapshot.custom_element_definition() or { panic('lost definition') }) == voidptr(definition)
	assert element.custom_element_definition() == none
	states.add('active')!
	assert (snapshot.custom_state_set() or { panic('lost live state set') }).has_state('active')
	assert voidptr(element.ensure_custom_state_set()) == voidptr(states)
}

fn test_element_binding_storage_preserves_part_token_list_live_identity() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element_ns(namespace_html_uri, 'div')!
	element.set_attribute_value('part', 'first second')
	parts := element.part_list()
	style_map := element.attribute_style_map()
	snapshot := *element
	element.set_attribute_value('part', 'next')
	mut names := element.part_names()
	names.clear()
	assert element.part_names() == ['next']
	assert snapshot.part_names() == ['first', 'second']
	assert voidptr(element.part_list()) == voidptr(parts)
	assert voidptr(snapshot.cached_part_list() or { panic('lost token list') }) == voidptr(parts)
	assert parts.contains('next')
	element.set_inline_style(none)
	assert element.cached_attribute_style_map() == none
	assert voidptr(snapshot.cached_attribute_style_map() or { panic('lost style map') }) == voidptr(style_map)
}

fn test_element_dependency_storage_copies_membership_when_resources_change() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut resource := document.create_element_ns(namespace_html_uri, 'div')!
	first := document.create_element_ns(namespace_html_uri, 'span')!
	second := document.create_element_ns(namespace_html_uri, 'span')!
	resource.register_intersection_observer(voidptr(first))
	resource.register_svg_resource_box_referencing_element(first)
	resource.register_svg_paint_resource_referencing_element(first)
	style_map := resource.computed_style_map()
	snapshot := *resource
	resource.unregister_intersection_observer(voidptr(first))
	resource.register_intersection_observer(voidptr(second))
	resource.register_svg_resource_box_referencing_element(second)
	resource.register_svg_paint_resource_referencing_element(second)
	assert snapshot.has_registered_intersection_observer(voidptr(first))
	assert !resource.has_registered_intersection_observer(voidptr(first))
	assert resource.has_registered_intersection_observer(voidptr(second))
	assert snapshot.svg_box_references().len == 1 && resource.svg_box_references().len == 2
	assert snapshot.svg_paint_references().len == 1 && resource.svg_paint_references().len == 2
	assert voidptr(resource.computed_style_map()) == voidptr(style_map)
	resource.mark_svg_resource_box_referencing_elements_for_layout_tree_update()
	assert resource.svg_box_references().len == 0
	assert snapshot.svg_box_references().len == 1
	assert first.as_node().needs_layout_tree_update
}

@[heap]
struct ColdEventHookProbe {
mut:
	calls int
}

fn cold_event_hook(context voidptr) {
	mut probe := unsafe { &ColdEventHookProbe(context) }
	probe.calls++
}

fn test_event_target_cold_hooks_copy_values_and_preserve_live_handler_maps() {
	mut target := EventTarget.new()
	first := &ColdEventHookProbe{}
	second := &ColdEventHookProbe{}
	target.data.set_listener_list_changed_hook(voidptr(first), cold_event_hook)
	before_handler := target.data
	target.set_event_handler_attribute('load', &CallbackType{})
	assert before_handler.event_handler_count() == 0
	snapshot := *target
	target.data.set_listener_list_changed_hook(voidptr(second), cold_event_hook)
	first_count := first.calls
	snapshot.event_listener_list_changed()
	assert first.calls == first_count + 1
	target.event_listener_list_changed()
	assert second.calls == 1
	handler := target.data.event_handler('load') or { panic('missing handler') }
	assert voidptr(snapshot.data.event_handler('load') or { panic('lost live handler') }) == voidptr(handler)
	target.set_event_handler_attribute('load', none)
	assert snapshot.data.event_handler('load') == none
}
