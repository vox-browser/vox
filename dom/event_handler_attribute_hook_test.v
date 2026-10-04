module dom

fn test_source_raw_attribute_hook_maps_full_names_and_vendor_event_case() {
	mut document := Document.create(url_about_blank())
	mut element := document.create_element_ns(namespace_html_uri, 'button')!
	target := unsafe { &EventTarget(element) }
	target.element_event_handler_attribute_changed('click', 'unrecognized stripped name')
	target.element_event_handler_attribute_changed('onunknown', 'unrecognized attribute')
	assert target.event_listener_list().len == 0
	element.set_attribute_value('onwebkitanimationend', 'original body')
	assert target.has_event_listener('webkitAnimationEnd')
	assert !target.has_event_listener('webkitanimationend')
	handler := target.data.event_handler_map['webkitAnimationEnd'] or { panic('vendor handler') }
	listener := handler.listener or { panic('vendor listener') }
	element.set_attribute_value('onwebkitanimationend', 'replacement body')
	assert handler.value.string_data == 'replacement body'
	assert voidptr(target.data.event_handler_map['webkitAnimationEnd'] or { panic('handler') }) == voidptr(handler)
	assert voidptr(handler.listener or { panic('listener') }) == voidptr(listener)
	element.remove_attribute('onwebkitanimationend')
	assert !target.has_event_listener('webkitAnimationEnd')
}

fn test_source_html_attribute_dispatch_distinguishes_global_and_body_frameset_sets() {
	mut document := Document.create(url_about_blank())
	document.browsing_context = &BrowsingContext{ active_document_: document }
	mut window := &Window{}
	document.set_window(window)
	window_target := unsafe { &EventTarget(window) }
	mut ordinary := document.create_element_ns(namespace_html_uri, 'div')!
	ordinary.set_attribute_value('onload', 'ordinary load')
	ordinary.set_attribute_value('onmessage', 'not an ordinary handler')
	ordinary_target := unsafe { &EventTarget(ordinary) }
	assert ordinary_target.has_event_listener('load')
	assert !ordinary_target.has_event_listener('message')
	for name in ['body', 'frameset'] {
		mut element := document.create_element_ns(namespace_html_uri, name)!
		target := unsafe { &EventTarget(element) }
		element.set_attribute_value('onload', 'reflected load')
		element.set_attribute_value('onmessage', 'reflected message')
		element.set_attribute_value('onclick', 'local click')
		assert (window_target.data.event_handler_map['load'] or { panic('reflected load') }).value.string_data == 'reflected load'
		assert (window_target.data.event_handler_map['message'] or { panic('reflected message') }).value.string_data == 'reflected message'
		assert !target.has_event_listener('load') && !target.has_event_listener('message')
		assert target.has_event_listener('click')
		// The pinned EventTarget.cpp predicate omits these four header members.
		for event_name in ['gamepadconnected', 'gamepaddisconnected', 'pagereveal', 'pageswap'] {
			element.set_attribute_value('on' + event_name, 'local source member')
			assert target.has_event_listener(event_name)
			assert !window_target.has_event_listener(event_name)
		}
		element.remove_attribute('onload')
		assert !window_target.has_event_listener('load')
	}
}

fn test_source_native_handler_attribute_hook_checks_csp_once_before_replacement() {
	mut document := Document.create(url_about_blank())
	mut element := document.create_element_ns(namespace_html_uri, 'button')!
	target := unsafe { &EventTarget(element) }
	element.set_attribute_value('onclick', 'original body')
	mut counts := &InlineAttributeCSPCounts{}
	document.set_csp_hook(DocumentCSPHook{
		inline_check: fn [counts] (_ voidptr, element &Element, type_ string, source string) bool {
			assert element.local_name() == 'button' && type_ == 'script-attribute'
			mut state := unsafe { &InlineAttributeCSPCounts(counts) }
			state.calls++
			return source == 'blocked body'
		}
	})
	element.set_attribute_value('onclick', 'blocked body')
	assert counts.calls == 1
	assert (target.data.event_handler_map['click'] or { panic('click') }).value.string_data == 'original body'
	element.set_attribute_value('onclick', 'allowed body')
	assert counts.calls == 2
	assert (target.data.event_handler_map['click'] or { panic('click') }).value.string_data == 'allowed body'
	element.remove_attribute('onclick')
	assert counts.calls == 2 && !target.has_event_listener('click')
}

@[heap]
struct InlineAttributeCSPCounts {
mut:
	calls int
}

fn test_source_html_handler_hook_retains_namespace_fixme_without_matching_svg_elements() {
	mut document := Document.create(url_about_blank())
	mut element := document.create_element_ns(namespace_html_uri, 'button')!
	element.set_attribute_value_ns('onclick', 'source namespace TODO', 'custom', 'urn:handler')
	assert unsafe { &EventTarget(element) }.has_event_listener('click')
	mut svg := document.create_element_ns(namespace_svg_uri, 'svg')!
	svg.set_attribute_value('onclick', 'not HTMLElement')
	assert !unsafe { &EventTarget(svg) }.has_event_listener('click')
}
