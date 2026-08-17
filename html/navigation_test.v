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
