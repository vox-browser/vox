module html

import dom

fn navigation_test_document() &dom.Document {
	mut document := &dom.Document{}
	document.set_url(dom.URL{ value: 'https://example.test/start' })
	document.set_origin(dom.URL{ value: 'https://example.test/' }.origin())
	document.set_is_initial_about_blank(false)
	return document
}

fn navigation_noop_handler() ! {}

fn intercept_navigation_event(base_event &dom.Event, target ?&dom.EventTarget) dom.JSValue {
	_ = target
	if base_event.interface_ == .navigate_event {
		mut event := unsafe { &NavigateEvent(base_event) }
		event.intercept(NavigationInterceptOptions{
			handler: NavigationInterceptHandler(navigation_noop_handler)
		}) or {}
	}
	return dom.js_undefined()
}

fn cancel_navigation_event(base_event &dom.Event, target ?&dom.EventTarget) dom.JSValue {
	_ = target
	mut event := unsafe { &dom.Event(base_event) }
	event.prevent_default()
	return dom.js_undefined()
}

fn initialized_navigation(document &dom.Document) &Navigation {
	mut navigation := Navigation.create(document)
	navigation.set_entries_and_events_disabled_override(false)
	initial := &SessionHistoryEntry{
		url:                dom.URL{
			value: 'https://example.test/start'
		}
		document_state:     &DocumentState{
			document: document
		}
		navigation_api_key: 'start'
	}
	navigation.initialize_the_navigation_api_entries_for_a_new_document([initial], initial)
	return navigation
}

fn test_navigation_entries_update_and_capabilities() {
	document := navigation_test_document()
	mut navigation := initialized_navigation(document)
	assert navigation.entries().len == 1
	assert navigation.current_entry()?.key() == 'start'
	assert !navigation.can_go_back()
	assert !navigation.can_go_forward()

	navigation.update_current_entry(NavigationUpdateCurrentEntryOptions{
		state: dom.js_string('updated')
	})!
	assert navigation.current_entry()?.get_state()!.to_string_value() == 'updated'
}

fn test_navigation_navigate_intercept_and_traverse() {
	document := navigation_test_document()
	mut navigation := initialized_navigation(document)
	handler := &dom.CallbackType{
		handle_event: intercept_navigation_event
	}
	navigation.set_onnavigate(handler)

	result := navigation.navigate('/next', NavigationNavigateOptions{
		state:   dom.js_number(42)
		history: .push
	})
	assert result.committed.state() == .fulfilled
	assert result.finished.state() == .fulfilled
	assert navigation.entries().len == 2
	assert navigation.current_entry()?.url()? == 'https://example.test/next'
	assert navigation.current_entry()?.get_state()!.number_data == 42
	assert navigation.can_go_back()
	assert !navigation.can_go_forward()
	assert navigation.transition() == none

	back_result := navigation.back(NavigationOptions{})
	assert back_result.finished.state() == .fulfilled
	assert navigation.current_entry()?.key() == 'start'
	assert navigation.can_go_forward()

	forward_result := navigation.forward(NavigationOptions{})
	assert forward_result.finished.state() == .fulfilled
	assert navigation.current_entry()?.url()? == 'https://example.test/next'
}

fn test_navigation_cancellation_rejects_result() {
	document := navigation_test_document()
	mut navigation := initialized_navigation(document)
	handler := &dom.CallbackType{
		handle_event: cancel_navigation_event
	}
	navigation.set_onnavigate(handler)
	result := navigation.navigate('/blocked', NavigationNavigateOptions{ history: .push })
	assert result.committed.state() == .rejected
	assert result.finished.state() == .rejected
	assert navigation.entries().len == 1
}

fn test_navigation_disabled_surface_and_early_errors() {
	document := navigation_test_document()
	mut navigation := initialized_navigation(document)
	navigation.set_entries_and_events_disabled_override(true)
	assert navigation.entries().len == 0
	assert navigation.current_entry() == none
	assert !navigation.can_go_back()
	result := navigation.navigate('/nope', NavigationNavigateOptions{})
	assert result.committed.state() == .rejected
	assert result.finished.state() == .rejected
}

fn test_document_open_keeps_initial_about_blank_navigation_disabled() {
	mut document := &dom.Document{}
	document.set_document_type(.html)
	document.set_url(dom.url_about_blank())
	document.set_origin(dom.URL{ value: 'https://example.test/' }.origin())
	document.set_is_initial_about_blank(true)
	install_document_fragment_parsing_hook(document)
	window := WindowModel.create_top_level(document, none, '')!
	mut navigation := unsafe { &Navigation(window.navigation()) }
	assert document.is_fully_active()
	assert navigation.has_entries_and_events_disabled()

	document.open()!
	assert !document.get_is_initial_about_blank()
	assert navigation.was_initial_about_blank_opened()
	assert navigation.has_entries_and_events_disabled()
	assert navigation.current_entry() == none

	entry := &SessionHistoryEntry{
		url: dom.URL{ value: 'https://example.test/next' }
		document_state: &DocumentState{
			document: document
		}
	}
	navigation.initialize_the_navigation_api_entries_for_a_new_document([entry], entry)
	assert !navigation.was_initial_about_blank_opened()
}

fn test_document_open_cancels_pending_and_ongoing_navigation_without_spinning() {
	mut document := &dom.Document{}
	document.set_document_type(.html)
	document.set_url(dom.url_about_blank())
	document.set_origin(dom.URL{ value: 'https://example.test/' }.origin())
	document.set_is_initial_about_blank(true)
	install_document_fragment_parsing_hook(document)
	window := WindowModel.create_top_level(document, none, '')!
	mut model := unsafe { &NavigableModel(window.navigable_model()) }
	model.has_session_history_entry_and_ready_ = false
	model.navigate(NavigableNavigateParams{
		url: dom.URL{ value: 'https://example.test/pending' }
		source_document: document
	})!
	assert model.has_pending_navigations()
	model.set_ongoing_navigation(NavigableOngoingNavigation{
		kind: .navigation
		id: 'ongoing'
	})

	document.open()!
	assert !model.has_pending_navigations()
	assert model.ongoing_navigation().kind == .empty
}

fn test_document_reopens_after_its_scripting_parser_completes() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	install_document_fragment_parsing_hook(document)
	document.open()!
	document.write_strings(['<p id="first">first</p>'])!
	document.close()!
	assert document.get_element_by_id('first') != none
	// The parser's end steps detach a parser that ran to completion; that is
	// not an aborted parser, so the next open() starts another stream.
	document.detach_parser()
	document.open()!
	document.write_strings(['<p id="second">second</p>'])!
	document.close()!
	assert document.get_element_by_id('first') == none
	assert document.get_element_by_id('second') != none
}
