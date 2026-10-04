module dom

fn test_source_document_activity_requires_an_actual_navigable() {
	mut document := Document.create(url_about_blank())
	document.set_browsing_context(&BrowsingContext{ active_document_: document })
	assert !document.is_active()
}

fn test_source_document_activity_uses_navigable_identity_without_browsing_context_presence() {
	mut document := Document.create(url_about_blank())
	other := Document.create(URL{'https://other.example/'})
	mut navigable := &Navigable{ active_document_: document }
	document.set_navigable(navigable)
	assert document.is_active()
	navigable.active_document_ = other
	assert !document.is_active()
	navigable.active_document_ = none
	assert !document.is_active()
}

fn test_source_inactive_body_cannot_read_replace_or_remove_retained_window_handlers() {
	mut old_document := Document.create(url_about_blank())
	mut new_document := Document.create(URL{'https://replacement.example/'})
	context := &BrowsingContext{ active_document_: old_document }
	old_document.set_browsing_context(context)
	new_document.set_browsing_context(context)
	mut navigable := &Navigable{}
	navigable.set_active_document(old_document)
	mut old_window := &Window{}
	mut new_window := &Window{}
	old_document.set_window(old_window)
	new_document.set_window(new_window)
	old_window_target := unsafe { &EventTarget(old_window) }
	new_window_target := unsafe { &EventTarget(new_window) }
	mut old_body := old_document.create_element_ns(namespace_html_uri, 'body')!
	old_body.set_attribute_value('onload', 'original owner body')
	old_handler := old_window_target.data.event_handler_map['load'] or { panic('old Window handler') }
	old_listener := old_handler.listener or { panic('old Window listener') }
	navigable.set_active_document(new_document)
	assert !old_document.is_active() && new_document.is_active()
	old_body.set_attribute_value('onload', 'inactive replacement')
	old_body.remove_attribute('onload')
	assert unsafe { &EventTarget(old_body) }.event_handler_attribute('load') == none
	assert old_handler.value.string_data == 'original owner body'
	assert voidptr(old_handler.listener or { panic('old listener') }) == voidptr(old_listener)
	assert old_window_target.has_event_listener('load')
	mut new_body := new_document.create_element_ns(namespace_html_uri, 'body')!
	new_body.set_attribute_value('onload', 'replacement owner body')
	assert (new_window_target.data.event_handler_map['load'] or { panic('new Window handler') }).value.string_data == 'replacement owner body'
}

fn test_source_inactive_document_scroll_apis_do_not_read_or_modify_its_previous_window() {
	mut document := Document.create(url_about_blank())
	document.set_document_type(.html)
	document.populate_with_html_head_and_body()!
	document.set_browsing_context(&BrowsingContext{ active_document_: document })
	mut navigable := &Navigable{}
	navigable.set_active_document(document)
	mut window := &Window{}
	document.set_window(window)
	document.set_viewport_rect(Rect{12, 34, 800, 600})
	mut root := document.document_element() or { panic('root') }
	assert root.scroll_left() == 12 && root.scroll_top() == 34
	// Retain a stale back-pointer to test the active-document identity boundary.
	navigable.active_document_ = Document.create(URL{'https://next.example/'})
	assert root.scroll_left() == 0 && root.scroll_top() == 0
	assert root.el_scroll(56, 78).state() == .fulfilled
	assert window.scroll_x() == 12 && window.scroll_y() == 34
}
