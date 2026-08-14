module dom

// Translation of Ladybird's HTML/BeforeUnloadEvent and HTML/ErrorEvent. Like the UIEvents subclasses,
// these extend DOM::Event and the DOM's event dispatch must identify them (event_is_before_unload_event,
// event_is_error_event), so they live in dom and set Event.interface_. (They're HTML-spec events, but the
// html module can still construct them since it imports dom.)

// --- BeforeUnloadEvent (HTML/BeforeUnloadEvent.h) ---

@[heap]
pub struct BeforeUnloadEvent {
	Event
pub mut:
	return_value_ string
}

pub fn BeforeUnloadEvent.create(event_name string, event_init EventInit) &BeforeUnloadEvent {
	return &BeforeUnloadEvent{
		Event: Event{
			interface_:   .before_unload_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
	}
}

pub fn (e &BeforeUnloadEvent) return_value() string {
	return e.return_value_
}

pub fn (mut e BeforeUnloadEvent) set_return_value(return_value string) {
	e.return_value_ = return_value
}

// --- ErrorEvent (HTML/ErrorEvent.h) ---

pub struct ErrorEventInit {
	EventInit
pub mut:
	message  string
	filename string
	lineno   u32
	colno    u32
	error    JSValue = js_undefined()
}

@[heap]
pub struct ErrorEvent {
	Event
pub mut:
	message_  string
	filename_ string
	lineno_   u32
	colno_    u32
	error_    JSValue = js_undefined()
}

pub fn ErrorEvent.create(event_name string, event_init ErrorEventInit) &ErrorEvent {
	return &ErrorEvent{
		Event:     Event{
			interface_:   .error_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
		message_:  event_init.message
		filename_: event_init.filename
		lineno_:   event_init.lineno
		colno_:    event_init.colno
		error_:    event_init.error
	}
}

pub fn (e &ErrorEvent) message() string {
	return e.message_
}

pub fn (e &ErrorEvent) filename() string {
	return e.filename_
}

pub fn (e &ErrorEvent) lineno() u32 {
	return e.lineno_
}

pub fn (e &ErrorEvent) colno() u32 {
	return e.colno_
}

pub fn (e &ErrorEvent) error() JSValue {
	return e.error_
}

// --- CloseEvent (HTML/CloseEvent.h) ---

pub struct CloseEventInit {
	EventInit
pub mut:
	was_clean bool
	code      u16
	reason    string
}

@[heap]
pub struct CloseEvent {
	Event
pub mut:
	was_clean_ bool
	code_      u16
	reason_    string
}

pub fn CloseEvent.create(event_name string, event_init CloseEventInit) &CloseEvent {
	return &CloseEvent{
		Event:      Event{
			interface_:   .close_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  current_event_timestamp()
		}
		was_clean_: event_init.was_clean
		code_:      event_init.code
		reason_:    event_init.reason
	}
}

pub fn CloseEvent.construct_impl(event_name string, event_init CloseEventInit) !&CloseEvent {
	return CloseEvent.create(event_name, event_init)
}

pub fn (e &CloseEvent) was_clean() bool {
	return e.was_clean_
}

pub fn (e &CloseEvent) code() u16 {
	return e.code_
}

pub fn (e &CloseEvent) reason() string {
	return e.reason_
}

// --- SubmitEvent (HTML/SubmitEvent.h) ---

pub struct SubmitEventInit {
	EventInit
pub mut:
	submitter ?&HTMLElement
}

@[heap]
pub struct SubmitEvent {
	Event
pub mut:
	submitter_ ?&HTMLElement
}

pub fn SubmitEvent.create(event_name string, event_init SubmitEventInit) &SubmitEvent {
	return &SubmitEvent{
		Event:      Event{
			interface_:   .submit_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
		submitter_: event_init.submitter
	}
}

pub fn SubmitEvent.construct_impl(event_name string, event_init SubmitEventInit) !&SubmitEvent {
	return SubmitEvent.create(event_name, event_init)
}

pub fn (e &SubmitEvent) submitter() ?&HTMLElement {
	return e.submitter_
}

// --- ToggleEvent (HTML/ToggleEvent.h) ---

pub struct ToggleEventInit {
	EventInit
pub mut:
	old_state string
	new_state string
	source    ?&Element
}

@[heap]
pub struct ToggleEvent {
	Event
pub mut:
	old_state_ string
	new_state_ string
	source_    ?&Element
}

pub fn ToggleEvent.create(event_name string, event_init ToggleEventInit) &ToggleEvent {
	return &ToggleEvent{
		Event:      Event{
			interface_:   .toggle_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
		old_state_: event_init.old_state
		new_state_: event_init.new_state
		source_:    event_init.source
	}
}

pub fn ToggleEvent.construct_impl(event_name string, event_init ToggleEventInit) !&ToggleEvent {
	return ToggleEvent.create(event_name, event_init)
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-toggleevent-oldstate
pub fn (e &ToggleEvent) old_state() string {
	return e.old_state_
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-toggleevent-newstate
pub fn (e &ToggleEvent) new_state() string {
	return e.new_state_
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-toggleevent-source
pub fn (e &ToggleEvent) source() ?&Element {
	// The source getter steps are to return the result of retargeting source against this's currentTarget.
	return retarget_event_source(e.source_, e.current_target())
}

// --- CommandEvent (HTML/CommandEvent.h) ---

pub struct CommandEventInit {
	EventInit
pub mut:
	source  ?&Element
	command string
}

@[heap]
pub struct CommandEvent {
	Event
pub mut:
	source_  ?&Element
	command_ string
}

pub fn CommandEvent.create(event_name string, event_init CommandEventInit) &CommandEvent {
	return &CommandEvent{
		Event:    Event{
			interface_:   .command_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
		source_:  event_init.source
		command_: event_init.command
	}
}

pub fn CommandEvent.construct_impl(event_name string, event_init CommandEventInit) !&CommandEvent {
	return CommandEvent.create(event_name, event_init)
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-commandevent-command
pub fn (e &CommandEvent) command() string {
	return e.command_
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-commandevent-source
pub fn (e &CommandEvent) source() ?&Element {
	return retarget_event_source(e.source_, e.current_target())
}

// Shared helper for the ToggleEvent/CommandEvent source getters:
// as<DOM::Element>(retarget(source, current_target())).
fn retarget_event_source(source ?&Element, against ?&EventTarget) ?&Element {
	src := source or { return none }
	target := against or { return src }
	retargeted := retarget(unsafe { &EventTarget(src) }, target) or { return none }
	node := event_target_as_node(retargeted) or { return none }
	return node.as_element()
}

// --- PopStateEvent (HTML/PopStateEvent.h) ---

pub struct PopStateEventInit {
	EventInit
pub mut:
	state JSValue = js_null()
}

@[heap]
pub struct PopStateEvent {
	Event
pub mut:
	state_ JSValue = js_null()
}

pub fn PopStateEvent.create(event_name string, event_init PopStateEventInit) &PopStateEvent {
	return &PopStateEvent{
		Event:  Event{
			interface_:   .pop_state_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  current_event_timestamp()
		}
		state_: event_init.state
	}
}

pub fn PopStateEvent.construct_impl(event_name string, event_init PopStateEventInit) &PopStateEvent {
	return PopStateEvent.create(event_name, event_init)
}

pub fn (e &PopStateEvent) state() JSValue {
	return e.state_
}

// --- HashChangeEvent (HTML/HashChangeEvent.h) ---

pub struct HashChangeEventInit {
	EventInit
pub mut:
	old_url string
	new_url string
}

@[heap]
pub struct HashChangeEvent {
	Event
pub mut:
	old_url_ string
	new_url_ string
}

pub fn HashChangeEvent.create(event_name string, event_init HashChangeEventInit) &HashChangeEvent {
	return &HashChangeEvent{
		Event:    Event{
			interface_:   .hash_change_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  current_event_timestamp()
		}
		old_url_: event_init.old_url
		new_url_: event_init.new_url
	}
}

pub fn HashChangeEvent.construct_impl(event_name string, event_init HashChangeEventInit) &HashChangeEvent {
	return HashChangeEvent.create(event_name, event_init)
}

pub fn (e &HashChangeEvent) old_url() string {
	return e.old_url_
}

pub fn (e &HashChangeEvent) new_url() string {
	return e.new_url_
}

// --- PageTransitionEvent (HTML/PageTransitionEvent.h) ---

pub struct PageTransitionEventInit {
	EventInit
pub mut:
	persisted bool
}

@[heap]
pub struct PageTransitionEvent {
	Event
pub mut:
	persisted_ bool
}

pub fn PageTransitionEvent.create(event_name string, event_init PageTransitionEventInit) &PageTransitionEvent {
	return &PageTransitionEvent{
		Event:      Event{
			interface_:   .page_transition_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  current_event_timestamp()
		}
		persisted_: event_init.persisted
	}
}

pub fn PageTransitionEvent.construct_impl(event_name string, event_init PageTransitionEventInit) !&PageTransitionEvent {
	return PageTransitionEvent.create(event_name, event_init)
}

pub fn (e &PageTransitionEvent) persisted() bool {
	return e.persisted_
}

// --- StorageEvent (HTML/StorageEvent.h) ---

// https://html.spec.whatwg.org/multipage/webstorage.html#storageeventinit
pub struct StorageEventInit {
	EventInit
pub mut:
	key          ?string
	old_value    ?string
	new_value    ?string
	url          string
	storage_area ?&Storage
}

// https://html.spec.whatwg.org/multipage/webstorage.html#storageevent
@[heap]
pub struct StorageEvent {
	Event
pub mut:
	key_          ?string
	old_value_    ?string
	new_value_    ?string
	url_          string
	storage_area_ ?&Storage
}

pub fn StorageEvent.create(event_name string, event_init StorageEventInit) &StorageEvent {
	return &StorageEvent{
		Event:         Event{
			interface_:   .storage_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
		key_:          event_init.key
		old_value_:    event_init.old_value
		new_value_:    event_init.new_value
		url_:          event_init.url
		storage_area_: event_init.storage_area
	}
}

pub fn StorageEvent.construct_impl(event_name string, event_init StorageEventInit) &StorageEvent {
	return &StorageEvent{
		Event:         Event{
			interface_:   .storage_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  current_event_timestamp()
		}
		key_:          event_init.key
		old_value_:    event_init.old_value
		new_value_:    event_init.new_value
		url_:          event_init.url
		storage_area_: event_init.storage_area
	}
}

pub fn (e &StorageEvent) key() ?string {
	return e.key_
}

pub fn (e &StorageEvent) old_value() ?string {
	return e.old_value_
}

pub fn (e &StorageEvent) new_value() ?string {
	return e.new_value_
}

pub fn (e &StorageEvent) url() string {
	return e.url_
}

pub fn (e &StorageEvent) storage_area() ?&Storage {
	return e.storage_area_
}

// https://html.spec.whatwg.org/multipage/webstorage.html#dom-storageevent-initstorageevent
pub fn (mut e StorageEvent) init_storage_event(type_ string, bubbles bool, cancelable bool, key ?string, old_value ?string, new_value ?string, url string, storage_area ?&Storage) {
	// The initStorageEvent(...) method must initialize the event in a manner analogous to the
	// similarly-named initEvent() method. [DOM]
	if e.dispatched() {
		return
	}

	e.initialize_event(type_, bubbles, cancelable)
	e.key_ = key
	e.old_value_ = old_value
	e.new_value_ = new_value
	e.url_ = url
	e.storage_area_ = storage_area
}

// --- PromiseRejectionEvent (HTML/PromiseRejectionEvent.h) ---

pub struct PromiseRejectionEventInit {
	EventInit
pub mut:
	// C++: GC::Root<JS::Object> promise. Represented as a JS object value in this port.
	promise JSValue
	reason  JSValue = js_undefined()
}

@[heap]
pub struct PromiseRejectionEvent {
	Event
pub mut:
	promise_ JSValue
	reason_  JSValue = js_undefined()
}

pub fn PromiseRejectionEvent.create(event_name string, event_init PromiseRejectionEventInit) &PromiseRejectionEvent {
	return &PromiseRejectionEvent{
		Event:    Event{
			interface_:   .promise_rejection_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
		promise_: event_init.promise
		reason_:  event_init.reason
	}
}

pub fn PromiseRejectionEvent.construct_impl(event_name string, event_init PromiseRejectionEventInit) !&PromiseRejectionEvent {
	return PromiseRejectionEvent.create(event_name, event_init)
}

pub fn (e &PromiseRejectionEvent) promise() JSValue {
	return e.promise_
}

pub fn (e &PromiseRejectionEvent) reason() JSValue {
	return e.reason_
}
