module html

import dom
import math
import requestidlecallback

const window_test_html_namespace = 'http://www.w3.org/1999/xhtml'

fn create_active_window(url string) !(&dom.Document, &WindowModel) {
	mut document := dom.Document.create(dom.URL{url})
	document.set_origin(document.url.origin())
	window := WindowModel.create_top_level(document, none, 'top')!
	return document, window
}

fn test_window_global_set_and_noopener_feature_helper() {
	document, window := create_active_window('https://example.test/')!
	assert window in all_windows()
	assert get_noopener_for_window_open(document, {
		'noopener': 'yes'
	}, dom.URL{ value: 'https://example.test/new' }) == .yes
	assert get_noopener_for_window_open(document, map[string]string{}, none) == .no
}

fn test_window_cssom_view_media_and_cached_objects() {
	document_pointer, window_pointer := create_active_window('https://example.test/')!
	mut document := document_pointer
	mut window := window_pointer
	document.set_viewport_rect(dom.Rect{4, 8, 640, 480})
	window.set_host_configuration(WindowHostConfiguration{
		screen_width: 1920
		screen_height: 1080
		available_screen_width: 1900
		available_screen_height: 1040
		window_x: 22
		window_y: 31
		outer_width: 900
		outer_height: 700
		device_pixel_ratio: 2
	})
	assert window.inner_width() == 640
	assert window.inner_height() == 480
	assert window.scroll_x() == 4
	assert window.scroll_y() == 8
	assert window.screen_x() == 22
	assert window.screen_y() == 31
	assert window.outer_width() == 900
	assert window.outer_height() == 700
	assert window.device_pixel_ratio() == 2

	screen := window.screen()
	assert screen == window.screen()
	assert screen.width() == 1920
	assert screen.height() == 1080
	assert screen.avail_width() == 1900
	assert screen.avail_height() == 1040
	viewport := window.visual_viewport() or { panic('missing visual viewport') }
	assert viewport == window.visual_viewport() or { panic('missing cached visual viewport') }

	mut element := document.create_element_ns(window_test_html_namespace, 'div')!
	style := window.get_computed_style(element, '::before')
	assert style.is_computed()
	assert style.is_readonly()
	owner := style.owner_node() or { panic('missing computed-style owner') }
	assert owner.pseudo_element() or { panic('missing pseudo-element') } == .before
	assert window.get_computed_style(element, '::part(label)').owner_node() == none

	media := window.match_media('(min-width: 600px)')
	assert media.matches()
	assert media.media().contains('min-width')
}

fn test_window_scroll_idle_animation_selection_and_external() {
	document_pointer, window_pointer := create_active_window('https://example.test/')!
	mut document := document_pointer
	mut window := window_pointer
	document.set_viewport_rect(dom.Rect{0, 0, 320, 200})
	first_promise := window.scroll_xy(12, 18)
	assert first_promise.state() == .fulfilled
	assert window.scroll_x() == 0
	assert window.scroll_y() == 0
	window.scroll_by_xy(3, 4)
	assert window.scroll_x() == 0
	assert window.scroll_y() == 0
	window.scroll(ScrollToOptions{ left: math.nan(), top: math.inf(1) })
	assert window.scroll_x() == 0
	assert window.scroll_y() == 0

	callback := fn (_ requestidlecallback.IdleDeadline) ! {}
	first := window.request_idle_callback(callback, requestidlecallback.IdleRequestOptions{})
	second := window.request_idle_callback(callback, requestidlecallback.IdleRequestOptions{ timeout: 10 })
	assert first == 1
	assert second == 2
	assert window.idle_request_callbacks_.len == 2
	window.cancel_idle_callback(first)
	assert window.idle_request_callbacks_.len == 1
	remaining := window.idle_request_callbacks_[second] or { panic('missing second idle callback') }
	assert remaining.handle == second
	assert window.idle_request_callback_order_ == [second]
	window.cancel_idle_callback(second)

	assert window.animation_frame_callback_driver() == window.animation_driver_
	assert window.get_selection() != none
	assert window.external() == window.external()
	window.capture_events()
	window.release_events()
	window.move_to(1, 2)
	window.move_by(3, 4)
	window.resize_to(500, 400)
	window.resize_by(20, 10)
}

fn test_window_named_objects_follow_upstream_ordering() {
	document_pointer, window_pointer := create_active_window('https://example.test/')!
	mut document := document_pointer
	mut window := window_pointer
	mut document_node := unsafe { &dom.Node(document) }
	mut root := document.create_element_ns(window_test_html_namespace, 'html')!
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	mut image := document.create_element_ns(window_test_html_namespace, 'img')!
	image.set_attribute_value('name', 'picture')
	root_node.append_child(image.as_node())!
	mut first_div := document.create_element_ns(window_test_html_namespace, 'div')!
	first_div.set_attribute_value('id', 'duplicate')
	mut first_div_node := first_div.as_node()
	first_div_node.append_child(document.create_text_node('Needle and another needle').as_node())!
	root_node.append_child(first_div.as_node())!
	mut second_div := document.create_element_ns(window_test_html_namespace, 'div')!
	second_div.set_attribute_value('id', 'duplicate')
	root_node.append_child(second_div.as_node())!

	child_document := dom.Document.create(dom.URL{'https://example.test/frame'})
	mut mutable_child_document := unsafe { &dom.Document(child_document) }
	mutable_child_document.set_origin(child_document.url.origin())
	child_context := BrowsingContextModel.create(child_document, window.browsing_context(), 'frame')
	_ = WindowModel.create(child_document, child_context)!
	cross_origin_document := dom.Document.create(dom.URL{'https://elsewhere.test/frame'})
	mut mutable_cross_origin_document := unsafe { &dom.Document(cross_origin_document) }
	mutable_cross_origin_document.set_origin(cross_origin_document.url.origin())
	cross_origin_context := BrowsingContextModel.create(cross_origin_document, window.browsing_context(), 'foreign')
	_ = WindowModel.create(cross_origin_document, cross_origin_context)!

	child_names := window.document_tree_child_navigable_target_name_property_set()
	assert 'frame' in child_names
	assert 'foreign' !in child_names
	assert 'picture' in window.supported_property_names()
	assert 'duplicate' in window.supported_property_names()
	assert window.is_supported_property_name('picture')
	assert window.is_supported_property_name('duplicate')
	assert window.is_supported_property_name('frame')
	assert !window.is_supported_property_name('foreign')
	assert window.named_objects('picture').elements == [image]
	assert window.named_item_value('picture').kind == .object
	assert window.named_objects('duplicate').elements.len == 2
	assert window.named_item_value('duplicate').kind == .object
	collection := window.named_collections_.last()
	assert collection.length() == 2
	assert collection.item(0) or { panic('missing first collection item') } == first_div
	// Live find/selection requires a Page and layout; see layout/window_find_test.v.
	assert !window.find('')

	root_node.remove_child(first_div.as_node())!
	assert window.is_supported_property_name('duplicate')
	second_div.set_attribute_value('id', 'renamed-id')
	assert !window.is_supported_property_name('duplicate')
	assert window.is_supported_property_name('renamed-id')
	image.set_attribute_value('name', 'renamed-image')
	assert !window.is_supported_property_name('picture')
	assert window.is_supported_property_name('renamed-image')
	root_node.remove_child(second_div.as_node())!
	root_node.remove_child(image.as_node())!
	assert !window.is_supported_property_name('renamed-id')
	assert !window.is_supported_property_name('renamed-image')

}

fn test_document_open_window_routes_to_window_open_steps_and_preserves_proxy_identity() {
	mut document, window := create_active_window('https://example.test/')!
	assert document.is_fully_active()
	model_proxy := window.browsing_context().window_proxy() or { panic('missing WindowProxyModel') }
	dom_window := model_proxy.dom_proxy().window() or { panic('missing DOM WindowProxy target') }
	assert voidptr(dom_window) == voidptr(window)
	first := document.open_window('', '_self', '') or { panic('window open returned null') }
	second := document.open_window('', '_self', '') or { panic('window open returned null') }
	assert voidptr(first) == voidptr(model_proxy.dom_proxy())
	assert voidptr(second) == voidptr(first)
}

fn test_window_proxy_retargets_both_html_and_dom_slots() {
	first_document, first_window := create_active_window('https://example.test/first')!
	proxy := WindowProxyModel.create(first_window)
	assert proxy.window() == first_window
	assert proxy.dom_proxy().window() or { panic('missing first DOM target') } == unsafe {
		&dom.Window(first_window)
	}

	second_context := BrowsingContextModel.create(first_document, none, 'second')
	second_window := WindowModel.create(first_document, second_context)!
	mut mutable_proxy := proxy
	mutable_proxy.set_window(second_window)
	assert proxy.window() == second_window
	assert proxy.dom_proxy().window() or { panic('missing second DOM target') } == unsafe {
		&dom.Window(second_window)
	}
}
