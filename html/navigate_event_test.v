module html

import dom

fn successful_navigation_handler() ! {}

fn test_navigate_event_exposes_initialized_attributes() {
	destination := NavigationDestination.create()
	signal := dom.AbortSignal.new()
	form_data := FormData.create([])
	event := NavigateEvent.construct_impl('navigate', NavigateEventInit{
		navigation_type:          .replace
		destination:              destination
		can_intercept:            true
		user_initiated:           true
		hash_change:              true
		signal:                   signal
		form_data:                form_data
		download_request:         'report.pdf'
		info:                     dom.js_string('state')
		has_ua_visual_transition: true
		fully_active_override:    true
	})!
	assert event.interface_ == .navigate_event
	assert event.navigation_type() == .replace
	assert event.destination() == destination
	assert event.can_intercept()
	assert event.user_initiated()
	assert event.hash_change()
	assert event.signal() == signal
	assert event.form_data()? == form_data
	assert event.download_request()? == 'report.pdf'
	assert event.info().to_string_value() == 'state'
	assert event.has_ua_visual_transition()
	assert !event.is_trusted()
}

fn test_navigate_event_interception_lifecycle() {
	mut event := NavigateEvent.create('navigate', NavigateEventInit{
		destination:           NavigationDestination.create()
		can_intercept:         true
		signal:                dom.AbortSignal.new()
		fully_active_override: true
	})!
	event.set_dispatched(true)
	event.intercept(NavigationInterceptOptions{
		handler:     NavigationInterceptHandler(successful_navigation_handler)
		focus_reset: .manual
		scroll:      .manual
	})!
	assert event.interception_state() == .intercepted
	assert event.navigation_handler_count() == 1
	assert event.focus_reset_behavior()? == .manual
	assert event.scroll_behavior()? == .manual
	event.run_navigation_handlers()!
	event.mark_committed()!
	event.scroll()!
	assert event.interception_state() == .scrolled
	event.finish(true)!
	assert event.interception_state() == .finished
}

fn test_navigate_event_enforces_shared_checks_and_state() {
	mut untrusted := NavigateEvent.construct_impl('navigate', NavigateEventInit{
		destination:           NavigationDestination.create()
		can_intercept:         true
		signal:                dom.AbortSignal.new()
		fully_active_override: true
	})!
	untrusted.set_dispatched(true)
	untrusted.intercept(NavigationInterceptOptions{}) or {
		assert err.msg().starts_with('SecurityError:')
	}

	mut undispatched := NavigateEvent.create('navigate', NavigateEventInit{
		destination:           NavigationDestination.create()
		can_intercept:         true
		signal:                dom.AbortSignal.new()
		fully_active_override: true
	})!
	undispatched.intercept(NavigationInterceptOptions{}) or {
		assert err.msg().starts_with('InvalidStateError:')
	}

	mut inactive := NavigateEvent.create('navigate', NavigateEventInit{
		destination:           NavigationDestination.create()
		can_intercept:         true
		signal:                dom.AbortSignal.new()
		fully_active_override: false
	})!
	inactive.set_dispatched(true)
	inactive.intercept(NavigationInterceptOptions{}) or {
		assert err.msg().contains('fully active')
	}
}

fn test_navigate_event_potentially_reset_the_focus_observes_navigation_state() {
	document := parse_document('<html><body><input></body></html>')
	mut navigation := Navigation.create(document)
	mut event := NavigateEvent.create('navigate', NavigateEventInit{
		destination:           NavigationDestination.create()
		signal:                dom.AbortSignal.new()
		associated_document:   document
		fully_active_override: true
		navigation:            navigation
	})!
	event.set_interception_state(.committed)
	navigation.set_focus_changed_during_ongoing_navigation(true)
	event.potentially_reset_the_focus()
	assert !navigation.focus_changed_during_ongoing_navigation()
	assert document.focused_area() == none

	event.potentially_reset_the_focus()
	body := document.body() or { panic('missing body') }
	assert document.focused_area()? == unsafe { &dom.Element(body) }.as_node()
}
