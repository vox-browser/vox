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
		Event: Event{
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
