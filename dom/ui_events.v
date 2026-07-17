module dom

// Translation of Ladybird's LibWeb/UIEvents/ event subclasses (UIEvent, MouseEvent, KeyboardEvent,
// PointerEvent). They live in the dom module (not a separate module) because they extend DOM::Event and
// the DOM's event dispatch must identify them; a separate module would create a dom<->uievents cycle.
//
// Class hierarchy (via struct embedding, Event first so a &Subclass upcasts/downcasts to &Event at offset 0):
//   Event -> UIEvent -> MouseEvent -> PointerEvent
//   Event -> UIEvent -> KeyboardEvent

// Which concrete event interface an Event is. Stored on Event.interface_ so predicates can identify a
// base &Event's real type without RTTI.
pub enum EventInterface {
	event
	ui_event
	mouse_event
	keyboard_event
	pointer_event
}

// UIEvents/KeyCode.h: Key_Escape = 0x1B.
pub const key_code_escape = u32(0x1B)

// --- UIEvent (UIEvents/UIEvent.h) ---

pub struct UIEventInit {
	EventInit
pub mut:
	detail int
}

@[heap]
pub struct UIEvent {
	Event
pub mut:
	detail_ int
	// view_ is HTML::WindowProxy in C++, which isn't ported into dom; kept as an opaque pointer.
	view_ voidptr = unsafe { nil }
}

pub fn (e &UIEvent) detail() int {
	return e.detail_
}

// --- MouseEvent (UIEvents/MouseEvent.h) ---

pub struct MouseEventInit {
	UIEventInit
pub mut:
	screen_x   f64
	screen_y   f64
	client_x   f64
	client_y   f64
	page_x     f64
	page_y     f64
	offset_x   f64
	offset_y   f64
	movement_x f64
	movement_y f64
	ctrl_key   bool
	shift_key  bool
	alt_key    bool
	meta_key   bool
	button     i16
	buttons    u16
}

@[heap]
pub struct MouseEvent {
	UIEvent
pub mut:
	screen_x_   f64
	screen_y_   f64
	client_x_   f64
	client_y_   f64
	page_x_     f64
	page_y_     f64
	offset_x_   f64
	offset_y_   f64
	movement_x_ f64
	movement_y_ f64
	ctrl_key_   bool
	shift_key_  bool
	alt_key_    bool
	meta_key_   bool
	button_     i16
	buttons_    u16
}

pub fn MouseEvent.create(event_name string, init MouseEventInit) &MouseEvent {
	return &MouseEvent{
		UIEvent: UIEvent{
			Event: Event{
				interface_:   .mouse_event
				type_:        event_name
				bubbles_:     init.bubbles
				cancelable_:  init.cancelable
				composed_:    init.composed
				initialized_: true
				is_trusted_:  true
				time_stamp_:  current_event_timestamp()
			}
			detail_: init.detail
		}
		screen_x_:   init.screen_x
		screen_y_:   init.screen_y
		client_x_:   init.client_x
		client_y_:   init.client_y
		page_x_:     init.page_x
		page_y_:     init.page_y
		offset_x_:   init.offset_x
		offset_y_:   init.offset_y
		movement_x_: init.movement_x
		movement_y_: init.movement_y
		ctrl_key_:   init.ctrl_key
		shift_key_:  init.shift_key
		alt_key_:    init.alt_key
		meta_key_:   init.meta_key
		button_:     init.button
		buttons_:    init.buttons
	}
}

// MouseEvent coordinate/modifier/button accessors (untrusted events floor the coordinates, per spec).
pub fn (e &MouseEvent) screen_x() f64 {
	return if e.is_trusted_ { e.screen_x_ } else { f64(int(e.screen_x_)) }
}

pub fn (e &MouseEvent) screen_y() f64 {
	return if e.is_trusted_ { e.screen_y_ } else { f64(int(e.screen_y_)) }
}

pub fn (e &MouseEvent) client_x() f64 {
	return if e.is_trusted_ { e.client_x_ } else { f64(int(e.client_x_)) }
}

pub fn (e &MouseEvent) client_y() f64 {
	return if e.is_trusted_ { e.client_y_ } else { f64(int(e.client_y_)) }
}

pub fn (e &MouseEvent) button() i16 {
	return e.button_
}

pub fn (e &MouseEvent) buttons() u16 {
	return e.buttons_
}

pub fn (e &MouseEvent) ctrl_key() bool {
	return e.ctrl_key_
}

pub fn (e &MouseEvent) shift_key() bool {
	return e.shift_key_
}

pub fn (e &MouseEvent) alt_key() bool {
	return e.alt_key_
}

pub fn (e &MouseEvent) meta_key() bool {
	return e.meta_key_
}

// --- KeyboardEvent (UIEvents/KeyboardEvent.h) ---

pub struct KeyboardEventInit {
	UIEventInit
pub mut:
	key          string
	code         string
	location     u32
	ctrl_key     bool
	shift_key    bool
	alt_key      bool
	meta_key     bool
	repeat       bool
	is_composing bool
	char_code    u32
	key_code     u32
}

@[heap]
pub struct KeyboardEvent {
	UIEvent
pub mut:
	key_code_     u32
	char_code_    u32
	key_          string
	code_         string
	location_     u32
	ctrl_key_     bool
	shift_key_    bool
	alt_key_      bool
	meta_key_     bool
	repeat_       bool
	is_composing_ bool
}

pub fn KeyboardEvent.create(event_name string, init KeyboardEventInit) &KeyboardEvent {
	return &KeyboardEvent{
		UIEvent: UIEvent{
			Event: Event{
				interface_:   .keyboard_event
				type_:        event_name
				bubbles_:     init.bubbles
				cancelable_:  init.cancelable
				composed_:    init.composed
				initialized_: true
				is_trusted_:  true
				time_stamp_:  current_event_timestamp()
			}
			detail_: init.detail
		}
		key_code_:     init.key_code
		char_code_:    init.char_code
		key_:          init.key
		code_:         init.code
		location_:     init.location
		ctrl_key_:     init.ctrl_key
		shift_key_:    init.shift_key
		alt_key_:      init.alt_key
		meta_key_:     init.meta_key
		repeat_:       init.repeat
		is_composing_: init.is_composing
	}
}

pub fn (e &KeyboardEvent) key_code() u32 {
	return e.key_code_
}

pub fn (e &KeyboardEvent) char_code() u32 {
	return e.char_code_
}

pub fn (e &KeyboardEvent) key() string {
	return e.key_
}

pub fn (e &KeyboardEvent) code() string {
	return e.code_
}

// which() returns the key code (UIEvents/KeyboardEvent.h override).
pub fn (e &KeyboardEvent) which() u32 {
	return e.key_code_
}

// --- PointerEvent (UIEvents/PointerEvent.h) : MouseEvent ---

pub struct PointerEventInit {
	MouseEventInit
pub mut:
	pointer_id          int
	width               f64 = 1.0
	height              f64 = 1.0
	pressure            f32
	tangential_pressure f32
	tilt_x              int
	tilt_y              int
	twist               int
	altitude_angle      f64
	azimuth_angle       f64
	pointer_type        string
	is_primary          bool
}

@[heap]
pub struct PointerEvent {
	MouseEvent
pub mut:
	pointer_id_          int
	width_               f64 = 1.0
	height_              f64 = 1.0
	pressure_            f32
	tangential_pressure_ f32
	tilt_x_              int
	tilt_y_              int
	twist_               int
	altitude_angle_      f64
	azimuth_angle_       f64
	pointer_type_        string
	is_primary_          bool
}

pub fn PointerEvent.create(event_name string, init PointerEventInit) &PointerEvent {
	return &PointerEvent{
		MouseEvent: MouseEvent{
			UIEvent: UIEvent{
				Event: Event{
					interface_:   .pointer_event
					type_:        event_name
					bubbles_:     init.bubbles
					cancelable_:  init.cancelable
					composed_:    init.composed
					initialized_: true
					is_trusted_:  true
					time_stamp_:  current_event_timestamp()
				}
				detail_: init.detail
			}
			screen_x_:   init.screen_x
			screen_y_:   init.screen_y
			client_x_:   init.client_x
			client_y_:   init.client_y
			page_x_:     init.page_x
			page_y_:     init.page_y
			offset_x_:   init.offset_x
			offset_y_:   init.offset_y
			movement_x_: init.movement_x
			movement_y_: init.movement_y
			ctrl_key_:   init.ctrl_key
			shift_key_:  init.shift_key
			alt_key_:    init.alt_key
			meta_key_:   init.meta_key
			button_:     init.button
			buttons_:    init.buttons
		}
		pointer_id_:          init.pointer_id
		width_:               init.width
		height_:              init.height
		pressure_:            init.pressure
		tangential_pressure_: init.tangential_pressure
		tilt_x_:              init.tilt_x
		tilt_y_:              init.tilt_y
		twist_:               init.twist
		altitude_angle_:      init.altitude_angle
		azimuth_angle_:       init.azimuth_angle
		pointer_type_:        init.pointer_type
		is_primary_:          init.is_primary
	}
}

pub fn (e &PointerEvent) pointer_id() int {
	return e.pointer_id_
}

pub fn (e &PointerEvent) pointer_type() string {
	return e.pointer_type_
}

pub fn (e &PointerEvent) is_primary() bool {
	return e.is_primary_
}
