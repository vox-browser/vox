module resizeobserver

import dom

fn no_op_resize_callback(_ []&ResizeObserverEntry, _ &ResizeObserver) {}

fn resize_test_element(tag string) &dom.Element {
	document := dom.Document.create(dom.url_about_blank())
	return document.create_element(tag) or { panic(err) }
}

fn test_box_size_entry_geometry_and_svg_origin() {
	mut element := resize_test_element('div')
	mut target := ResizeTarget.new(element, ResizeTargetMetrics{
		has_layout_box:     true
		border_width:       120
		border_height:      80
		content_width:      100
		content_height:     60
		device_pixel_ratio: 2
		absolute_padding_x: 4
		absolute_padding_y: 5
	})
	entry := ResizeObserverEntry.create_and_populate(target)
	assert entry.border_box_size[0] == ResizeObserverSize{
		inline_size: 120
		block_size:  80
	}
	assert entry.content_box_size[0] == ResizeObserverSize{
		inline_size: 100
		block_size:  60
	}
	assert entry.device_pixel_content_box_size[0] == ResizeObserverSize{
		inline_size: 240
		block_size:  160
	}
	assert entry.content_rect.x() == 4
	assert entry.content_rect.y() == 5
	target.metrics.is_svg_element = true
	assert ResizeObserverEntry.create_and_populate(target).content_rect.x() == 0
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
	assert observer.observation_targets().last().observed_box == .device_pixel_content_box
	observer.unobserve(first)
	assert observer.is_registered()
	observer.unobserve(second)
	assert !observer.is_registered()
}

fn test_active_observation_broadcast_updates_last_reported_size() {
	mut observer := ResizeObserver.new(no_op_resize_callback)
	mut target := ResizeTarget.new(resize_test_element('div'), ResizeTargetMetrics{
		has_layout_box: true
		content_width:  10
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

fn test_observe_identity_is_the_underlying_dom_element() {
	mut observer := ResizeObserver.new(no_op_resize_callback)
	element := resize_test_element('div')
	first_wrapper := ResizeTarget.new(element, ResizeTargetMetrics{})
	second_wrapper := ResizeTarget.new(element, ResizeTargetMetrics{ has_layout_box: true })
	observer.observe(first_wrapper, ResizeObserverOptions{})
	observer.observe(second_wrapper, ResizeObserverOptions{ box: .border_box })
	assert observer.observation_targets().len == 1
	assert voidptr(observer.observation_targets()[0].target) == voidptr(second_wrapper)
}
