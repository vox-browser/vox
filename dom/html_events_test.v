module dom

fn test_close_event_carries_fields() {
	e := CloseEvent.create('close', CloseEventInit{
		was_clean: true
		code:      1000
		reason:    'bye'
	})
	assert e.type_ == 'close'
	assert e.interface_ == .close_event
	assert e.was_clean() == true
	assert e.code() == u16(1000)
	assert e.reason() == 'bye'
	// CloseEvent::create does not set is_trusted (unlike SubmitEvent/StorageEvent).
	assert e.is_trusted_ == false
}

fn test_submit_event_is_trusted_and_holds_submitter() {
	e := SubmitEvent.create('submit', SubmitEventInit{})
	assert e.interface_ == .submit_event
	assert e.is_trusted_ == true
	assert e.submitter() == none
}

fn test_toggle_event_states() {
	e := ToggleEvent.create('toggle', ToggleEventInit{
		old_state: 'closed'
		new_state: 'open'
	})
	assert e.interface_ == .toggle_event
	assert e.old_state() == 'closed'
	assert e.new_state() == 'open'
	// With no source and no current target, the retargeting getter returns none.
	assert e.source() == none
}

fn test_command_event_command() {
	e := CommandEvent.create('command', CommandEventInit{
		command: 'show-modal'
	})
	assert e.command() == 'show-modal'
	assert e.is_trusted_ == true
}

fn test_hash_change_event_urls() {
	e := HashChangeEvent.create('hashchange', HashChangeEventInit{
		old_url: 'https://a/#x'
		new_url: 'https://a/#y'
	})
	assert e.old_url() == 'https://a/#x'
	assert e.new_url() == 'https://a/#y'
	assert e.is_trusted_ == false
}

fn test_page_transition_event_persisted() {
	e := PageTransitionEvent.create('pageshow', PageTransitionEventInit{
		persisted: true
	})
	assert e.persisted() == true
}

fn test_storage_event_optional_fields_and_init() {
	mut e := StorageEvent.create('storage', StorageEventInit{
		key:       'k'
		new_value: 'v'
		url:       'https://a/'
	})
	assert e.is_trusted_ == true
	assert e.key()? == 'k'
	assert e.old_value() == none
	assert e.new_value()? == 'v'
	assert e.url() == 'https://a/'

	// initStorageEvent re-initializes an as-yet-undispatched event.
	e.init_storage_event('storage', true, false, 'k2', 'old', 'new', 'https://b/', none)
	assert e.type_ == 'storage'
	assert e.bubbles_ == true
	assert e.key()? == 'k2'
	assert e.old_value()? == 'old'
	assert e.new_value()? == 'new'
	assert e.url() == 'https://b/'
}

fn test_promise_rejection_event() {
	e := PromiseRejectionEvent.create('unhandledrejection', PromiseRejectionEventInit{
		promise: js_null()
		reason:  js_null()
	})
	assert e.interface_ == .promise_rejection_event
	assert e.is_trusted_ == true
	assert e.reason().kind == .null_
	// The reason defaults to undefined when omitted.
	e2 := PromiseRejectionEvent.create('rejectionhandled', PromiseRejectionEventInit{
		promise: js_null()
	})
	assert e2.reason().kind == .undefined
}
