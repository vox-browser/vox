module resizeobserver

import dom
import page

__global resize_callback_invocations int

fn no_op_resize_callback(_ []&ResizeObserverEntry, _ &ResizeObserver) {}

fn counting_resize_callback(entries []&ResizeObserverEntry, _ &ResizeObserver) {
	resize_callback_invocations += entries.len
}

fn resize_test_element(tag string) &dom.Element {
	document := dom.Document.create(dom.url_about_blank())
	return document.create_element(tag) or { panic(err) }
}

fn test_box_size_entry_geometry_and_svg_origin() {
	mut element := resize_test_element('div')
	mut target := ResizeTarget.new(element, ResizeTargetMetrics{
		has_layout_box: true
		border_width: 120
		border_height: 80
		content_width: 100
		content_height: 60
		device_pixel_ratio: 2
		absolute_padding_x: 4
		absolute_padding_y: 5
	})
	entry := ResizeObserverEntry.create_and_populate(target)
	assert entry.border_box_size()[0].inline_size() == 120
	assert entry.border_box_size()[0].block_size() == 80
	assert entry.content_box_size()[0].inline_size() == 100
	assert entry.content_box_size()[0].block_size() == 60
	assert entry.device_pixel_content_box_size()[0].inline_size() == 240
	assert entry.device_pixel_content_box_size()[0].block_size() == 160
	assert entry.content_rect().x() == 4
	assert entry.content_rect().y() == 5
	target.metrics.is_svg_element = true
	assert ResizeObserverEntry.create_and_populate(target).content_rect().x() == 0
}

fn test_observe_uses_pointer_identity_replaces_and_unregisters() {
	mut observer := ResizeObserver.new(no_op_resize_callback)
	first := ResizeTarget.new(resize_test_element('div'), ResizeTargetMetrics{})
	second := ResizeTarget.new(resize_test_element('div'), ResizeTargetMetrics{})
	observer.observe(first, ResizeObserverOptions{})
	observer.observe(second, ResizeObserverOptions{ box: .border_box })
	assert observer.observation_targets().len == 2
	observer.observe(first, ResizeObserverOptions{ box: .device_pixel_content_box })
	assert observer.observation_targets().len == 2
	assert observer.observation_targets().last().observed_box() == .device_pixel_content_box
	observer.unobserve(first)
	assert observer.is_registered()
	observer.unobserve(second)
	assert !observer.is_registered()
}

fn test_active_observation_broadcast_updates_last_reported_size() {
	mut observer := ResizeObserver.new(no_op_resize_callback)
	mut target := ResizeTarget.new(resize_test_element('div'), ResizeTargetMetrics{
		has_layout_box: true
		content_width: 10
		content_height: 20
	})
	observer.observe(target, ResizeObserverOptions{})
	observer.gather_active_observations()
	assert observer.active_targets().len == 1
	observer.broadcast_active_observations()
	assert observer.last_entries().len == 1
	observer.gather_active_observations()
	assert observer.active_targets().len == 0
	target.metrics.content_width = 11
	observer.gather_active_observations()
	assert observer.active_targets().len == 1
	observer.disconnect()
	assert !observer.is_registered()
}

fn test_document_resize_loop_uses_concrete_observer_registration() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut root := document.create_element('div') or { panic(err) }
	mut target_element := document.create_element('div') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target_element.as_node()) or { panic(err) }
	mut target := ResizeTarget.new(target_element, ResizeTargetMetrics{
		has_layout_box: true
		content_width: 25
		content_height: 10
	})
	mut observer := ResizeObserver.new(no_op_resize_callback)
	observer.observe(target, ResizeObserverOptions{})

	document.gather_active_observations_at_depth(0)
	assert document.has_active_resize_observations()
	assert !document.has_skipped_resize_observations()
	assert document.broadcast_active_resize_observations() == 3
	assert !document.has_active_resize_observations()
	assert observer.last_entries().len == 1

	target.metrics.content_width = 30
	document.gather_active_observations_at_depth(3)
	assert !document.has_active_resize_observations()
	assert document.has_skipped_resize_observations()
	observer.disconnect()
}

fn test_observe_identity_is_the_underlying_dom_element() {
	mut observer := ResizeObserver.new(no_op_resize_callback)
	element := resize_test_element('div')
	first_wrapper := ResizeTarget.new(element, ResizeTargetMetrics{})
	second_wrapper := ResizeTarget.new(element, ResizeTargetMetrics{ has_layout_box: true })
	observer.observe(first_wrapper, ResizeObserverOptions{})
	observer.observe(second_wrapper, ResizeObserverOptions{ box: .border_box })
	assert observer.observation_targets().len == 1
	assert voidptr(observer.observation_targets()[0].target()) == voidptr(second_wrapper)
}

fn test_exact_resize_observer_entry_points() {
	target := ResizeTarget.new(resize_test_element('div'), ResizeTargetMetrics{
		has_layout_box: true
		border_width: 20
		border_height: 30
		content_width: 10
		content_height: 15
		device_pixel_ratio: 2
	})
	mut size := ResizeObserverSize.calculate_box_size(target, .content_box)
	assert size.inline_size() == 10
	assert size.block_size() == 15
	size.set_inline_size(11)
	size.set_block_size(16)
	assert size.inline_size() == 11 && size.block_size() == 16

	observation := ResizeObservation.create(target, .border_box)
	assert voidptr(observation.target()) == voidptr(target)
	assert observation.observed_box() == .border_box
	assert observation.last_reported_sizes().len == 1
	mut mutable_observation := observation
	mutable_observation.set_last_reported_sizes([
		ResizeObserverSize.calculate_box_size(target, .border_box),
	])
	assert !mutable_observation.is_active()

	entry := ResizeObserverEntry.create_and_populate(target)
	assert voidptr(entry.target()) == voidptr(target)
	assert ResizeObserverEntry.target_offset() == 0
	assert ResizeObserverEntry.content_rect_offset() > ResizeObserverEntry.target_offset()
	assert entry.content_rect().width() == 10
	assert entry.border_box_size_js_array()[0].inline_size() == 20
	assert entry.content_box_size_js_array()[0].inline_size() == 10
	assert entry.device_pixel_content_box_size_js_array()[0].inline_size() == 40
	mut copied := to_js_array(entry.content_box_size())
	copied.clear()
	assert entry.content_box_size().len == 1

	mut observer := ResizeObserver.construct_impl(no_op_resize_callback)
	observer.observe(target, ResizeObserverOptions{})
	assert observer.is_registered()
	observer.unobserve(target)
	assert !observer.is_registered()
	observer.unregister_observer_if_needed()
}

fn test_dead_targets_are_removed_and_release_activity_root() {
	mut document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('div') or { panic(err) }
	mut target := ResizeTarget.new(element, ResizeTargetMetrics{ has_layout_box: true })
	mut observer := ResizeObserver.create(no_op_resize_callback, document)
	assert !observer.has_activity_root()
	observer.observe(target, ResizeObserverOptions{})
	assert observer.has_activity_root()
	assert document.registered_resize_observer_count() == 1
	target.mark_dead()
	observer.remove_dead_observations()
	assert observer.observation_targets().len == 0
	assert !observer.is_registered()
	assert !observer.has_activity_root()
	assert document.registered_resize_observer_count() == 0
	observer.finalize()
}

fn test_document_destruction_releases_resize_observer_roots() {
	mut document := dom.Document.create(dom.url_about_blank())
	target := ResizeTarget.new(document.create_element('div') or { panic(err) }, ResizeTargetMetrics{})
	mut observer := ResizeObserver.create_for_constructor(document, no_op_resize_callback)
	observer.observe(target, ResizeObserverOptions{})
	assert observer.has_activity_root()
	document.destroy()
	assert !observer.has_activity_root()
	assert !observer.is_registered()
	assert document.registered_resize_observer_count() == 0
	ResizeObserver.release_activity_roots_with_dead_documents()
	observer.finalize()
}

fn test_live_registry_and_callback_boundary() {
	resize_callback_invocations = 0
	document := dom.Document.create(dom.url_about_blank())
	target := ResizeTarget.new(document.create_element('div') or { panic(err) }, ResizeTargetMetrics{})
	mut observer := ResizeObserver.create(counting_resize_callback, document)
	assert live_resize_observers().any(voidptr(it) == voidptr(observer))
	assert observer.callback() != unsafe { nil }
	entry := ResizeObserverEntry.create_and_populate(target)
	invoke_resize_observer_callback(observer, [entry])
	assert resize_callback_invocations == 1
	observer.finalize()
	prune_live_resize_observers()
	assert !live_resize_observers().any(voidptr(it) == voidptr(observer))
}

fn test_observe_requests_a_frame_for_the_initial_resize_update() {
	mut page_model := page.Page.create(1.0)!
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_page(unsafe { &dom.Page(page_model) })
	mut client := page_model.client()
	client.events.clear()

	target := ResizeTarget.new(document.create_element('div') or { panic(err) }, ResizeTargetMetrics{})
	mut observer := ResizeObserver.create_for_constructor(document, no_op_resize_callback)
	observer.observe(target, ResizeObserverOptions{})
	assert client.events.map(it.name) == ['request-frame']

	// Re-observing replaces the observation and schedules its new initial delivery.
	observer.observe(target, ResizeObserverOptions{ box: .border_box })
	assert client.events.map(it.name) == ['request-frame', 'request-frame']
	observer.finalize()
}
