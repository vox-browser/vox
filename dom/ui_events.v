module dom

import math

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
	font_face_set_load_event
	media_query_list_event
	ui_event
	mouse_event
	keyboard_event
	pointer_event
	composition_event
	focus_event
	input_event
	text_event
	wheel_event
	progress_event
	// HTML events that also extend DOM::Event and are identified by the DOM's event dispatch (see
	// dom/html_events.v).
	before_unload_event
	error_event
	close_event
	submit_event
	toggle_event
	command_event
	pop_state_event
	hash_change_event
	page_transition_event
	storage_event
	promise_rejection_event
	navigation_current_entry_change_event
	navigate_event
	message_event
	drag_event
	form_data_event
	// TrackEvent lives in the html module (it references html-module track types) but still needs a
	// distinct interface id here so a base &Event can be identified as a TrackEvent.
	track_event
	// Animations/AnimationPlaybackEvent extends DOM::Event. The enum entry
	// keeps its concrete interface observable without introducing a
	// dom<->animations import cycle.
	animation_playback_event
	// Clipboard/ClipboardEvent extends DOM::Event. Keeping the concrete
	// interface here avoids a dom<->clipboard import cycle.
	clipboard_event
	// CookieStore/CookieChangeEvent extends DOM::Event. Keeping the concrete
	// interface here avoids a dom<->cookiestore import cycle.
	cookie_change_event
	// MediaSourceExtensions/BufferedChangeEvent extends DOM::Event. Keeping the
	// concrete interface here avoids a dom<->mediasourceextensions import cycle.
	buffered_change_event
	// Speech/SpeechRecognitionEvent extends DOM::Event.
	speech_recognition_event
}

// UIEvents/KeyCode.h: Key_Escape = 0x1B.
pub const key_code_escape = u32(0x1B)

// UIEvents/KeyCode.h platform modifier mask. Platform adapters pass this mask
// into the create_from_platform_event helpers below.
pub const modifier_alt = u32(1 << 0)
pub const modifier_ctrl = u32(1 << 1)
pub const modifier_shift = u32(1 << 2)
pub const modifier_super = u32(1 << 3)
pub const modifier_keypad = u32(1 << 4)

// --- UIEvent (UIEvents/UIEvent.h) ---

pub struct UIEventInit {
	EventInit
pub mut:
	detail int
	// HTML::WindowProxy is outside the DOM package.
	view voidptr = unsafe { nil }
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

pub fn UIEvent.create(event_name string, init UIEventInit) &UIEvent {
	return &UIEvent{
		Event:   Event{
			interface_:   .ui_event
			type_:        event_name
			bubbles_:     init.bubbles
			cancelable_:  init.cancelable
			composed_:    init.composed
			initialized_: true
			is_trusted_:  true
			time_stamp_:  current_event_timestamp()
		}
		detail_: init.detail
		view_:   init.view
	}
}

pub fn UIEvent.construct_impl(event_name string, init UIEventInit) !&UIEvent {
	mut event := UIEvent.create(event_name, init)
	event.is_trusted_ = false
	return event
}

pub fn (e &UIEvent) view() voidptr {
	return e.view_
}

pub fn (e &UIEvent) which() u32 {
	return 0
}

pub fn (mut e UIEvent) init_ui_event(type_ string, bubbles bool, cancelable bool, view voidptr, detail int) {
	if e.dispatched_ {
		return
	}
	e.initialize_event(type_, bubbles, cancelable)
	e.view_ = view
	e.detail_ = detail
}

pub struct EventModifierInit {
	UIEventInit
pub mut:
	ctrl_key             bool
	shift_key            bool
	alt_key              bool
	meta_key             bool
	modifier_alt_graph   bool
	modifier_caps_lock   bool
	modifier_fn          bool
	modifier_fn_lock     bool
	modifier_hyper       bool
	modifier_num_lock    bool
	modifier_scroll_lock bool
	modifier_super       bool
	modifier_symbol      bool
	modifier_symbol_lock bool
}

// --- MouseEvent (UIEvents/MouseEvent.h) ---

pub struct MouseEventInit {
	EventModifierInit
pub mut:
	screen_x       f64
	screen_y       f64
	client_x       f64
	client_y       f64
	page_x         f64
	page_y         f64
	offset_x       f64
	offset_y       f64
	movement_x     f64
	movement_y     f64
	button         i16
	buttons        u16
	related_target ?&EventTarget
}

// Ladybird keeps the internal MouseEventOptions separate from the WebIDL
// MouseEventInit dictionary. The V binding dictionary already has the exact
// value representation needed by the event implementation, so the translated
// options type can share it while retaining the conversion boundary.
pub type MouseEventOptions = MouseEventInit

pub fn mouse_event_options_from_bindings(event_init MouseEventInit) MouseEventInit {
	return event_init
}

@[heap]
pub struct MouseEvent {
	UIEvent
pub mut:
	screen_x_             f64
	screen_y_             f64
	client_x_             f64
	client_y_             f64
	page_x_               f64
	page_y_               f64
	offset_x_             f64
	offset_y_             f64
	movement_x_           f64
	movement_y_           f64
	ctrl_key_             bool
	shift_key_            bool
	alt_key_              bool
	meta_key_             bool
	button_               i16
	buttons_              u16
	modifier_alt_graph_   bool
	modifier_caps_lock_   bool
	modifier_fn_          bool
	modifier_fn_lock_     bool
	modifier_hyper_       bool
	modifier_num_lock_    bool
	modifier_scroll_lock_ bool
	modifier_super_       bool
	modifier_symbol_      bool
	modifier_symbol_lock_ bool
}

pub fn MouseEvent.create(event_name string, init MouseEventInit) &MouseEvent {
	return &MouseEvent{
		UIEvent:               UIEvent{
			Event:   Event{
				interface_:   .mouse_event
				type_:        event_name
				bubbles_:     init.bubbles
				cancelable_:  init.cancelable
				composed_:    init.composed
				initialized_: true
				is_trusted_:  true
				time_stamp_:  current_event_timestamp()
				related_target_: init.related_target
			}
			detail_: init.detail
			view_:   init.view
		}
		screen_x_:             init.screen_x
		screen_y_:             init.screen_y
		client_x_:             init.client_x
		client_y_:             init.client_y
		page_x_:               init.page_x
		page_y_:               init.page_y
		offset_x_:             init.offset_x
		offset_y_:             init.offset_y
		movement_x_:           init.movement_x
		movement_y_:           init.movement_y
		ctrl_key_:             init.ctrl_key
		shift_key_:            init.shift_key
		alt_key_:              init.alt_key
		meta_key_:             init.meta_key
		button_:               init.button
		buttons_:              init.buttons
		modifier_alt_graph_:   init.modifier_alt_graph
		modifier_caps_lock_:   init.modifier_caps_lock
		modifier_fn_:          init.modifier_fn
		modifier_fn_lock_:     init.modifier_fn_lock
		modifier_hyper_:       init.modifier_hyper
		modifier_num_lock_:    init.modifier_num_lock
		modifier_scroll_lock_: init.modifier_scroll_lock
		modifier_super_:       init.modifier_super
		modifier_symbol_:      init.modifier_symbol
		modifier_symbol_lock_: init.modifier_symbol_lock
	}
}

pub fn MouseEvent.construct_impl(event_name string, init MouseEventInit) !&MouseEvent {
	return MouseEvent.create_for_constructor(event_name, init, current_event_timestamp())
}

pub fn MouseEvent.create_for_constructor(event_name string, event_init MouseEventInit, time_stamp DOMHighResTimeStamp) !&MouseEvent {
	options := mouse_event_options_from_bindings(event_init)
	mut event := MouseEvent.create(event_name, options)
	event.is_trusted_ = false
	event.set_time_stamp(time_stamp)
	// CSSOM View constructor defaults page/offset coordinates to client coordinates.
	event.page_x_ = event_init.client_x
	event.page_y_ = event_init.client_y
	event.offset_x_ = event_init.client_x
	event.offset_y_ = event_init.client_y
	return event
}

pub fn MouseEvent.create_from_mouse_event(mouse_event &MouseEvent, time_stamp DOMHighResTimeStamp) &MouseEvent {
	mut event := MouseEvent.create(mouse_event.type_name(), MouseEventInit{
		EventModifierInit: EventModifierInit{
			UIEventInit: UIEventInit{
				detail: mouse_event.detail_
				view:   mouse_event.view_
			}
			ctrl_key:             mouse_event.ctrl_key_
			shift_key:            mouse_event.shift_key_
			alt_key:              mouse_event.alt_key_
			meta_key:             mouse_event.meta_key_
			modifier_alt_graph:   mouse_event.modifier_alt_graph_
			modifier_caps_lock:   mouse_event.modifier_caps_lock_
			modifier_fn:          mouse_event.modifier_fn_
			modifier_fn_lock:     mouse_event.modifier_fn_lock_
			modifier_hyper:       mouse_event.modifier_hyper_
			modifier_num_lock:    mouse_event.modifier_num_lock_
			modifier_scroll_lock: mouse_event.modifier_scroll_lock_
			modifier_super:       mouse_event.modifier_super_
			modifier_symbol:      mouse_event.modifier_symbol_
			modifier_symbol_lock: mouse_event.modifier_symbol_lock_
		}
		screen_x:          mouse_event.screen_x_
		screen_y:          mouse_event.screen_y_
		client_x:          mouse_event.client_x_
		client_y:          mouse_event.client_y_
		page_x:            mouse_event.page_x_
		page_y:            mouse_event.page_y_
		offset_x:          mouse_event.offset_x_
		offset_y:          mouse_event.offset_y_
		movement_x:        mouse_event.movement_x_
		movement_y:        mouse_event.movement_y_
		button:            mouse_event.button_
		buttons:           mouse_event.buttons_
		related_target:    mouse_event.related_target()
	})
	event.is_trusted_ = false
	event.set_time_stamp(time_stamp)
	return event
}

// MouseEvent::create_from_platform_event. Geometry remains typed as CSS pixel
// points while native key/mouse input supplies only the modifier bit mask.
pub fn MouseEvent.create_from_platform_event(view voidptr, event_name string, screen CSSPixelPoint_, page CSSPixelPoint_, client CSSPixelPoint_, offset CSSPixelPoint_, movement ?CSSPixelPoint_, button MouseButton, buttons u16, modifiers u32, detail int) &MouseEvent {
	movement_value := movement or { CSSPixelPoint_{} }
	return MouseEvent.create(event_name, MouseEventInit{
		EventModifierInit: EventModifierInit{
			UIEventInit: UIEventInit{
				EventInit: EventInit{
					bubbles:    true
					cancelable: true
					composed:   true
				}
				detail:    detail
				view:      view
			}
			ctrl_key:    modifiers & modifier_ctrl != 0
			shift_key:   modifiers & modifier_shift != 0
			alt_key:     modifiers & modifier_alt != 0
			meta_key:    modifiers & modifier_super != 0
		}
		screen_x:          screen.x()
		screen_y:          screen.y()
		client_x:          client.x()
		client_y:          client.y()
		page_x:            page.x()
		page_y:            page.y()
		offset_x:          offset.x()
		offset_y:          offset.y()
		movement_x:        movement_value.x()
		movement_y:        movement_value.y()
		button:            mouse_button_to_button_code(button)
		buttons:           buttons
	})
}

pub fn (e &MouseEvent) clone() &MouseEvent {
	mut clone := MouseEvent.create(e.type_, MouseEventInit{
		EventModifierInit: EventModifierInit{
			UIEventInit:          UIEventInit{
				detail: e.detail_
				view:   e.view_
			}
			ctrl_key:             e.ctrl_key_
			shift_key:            e.shift_key_
			alt_key:              e.alt_key_
			meta_key:             e.meta_key_
			modifier_alt_graph:   e.modifier_alt_graph_
			modifier_caps_lock:   e.modifier_caps_lock_
			modifier_fn:          e.modifier_fn_
			modifier_fn_lock:     e.modifier_fn_lock_
			modifier_hyper:       e.modifier_hyper_
			modifier_num_lock:    e.modifier_num_lock_
			modifier_scroll_lock: e.modifier_scroll_lock_
			modifier_super:       e.modifier_super_
			modifier_symbol:      e.modifier_symbol_
			modifier_symbol_lock: e.modifier_symbol_lock_
		}
		screen_x:          e.screen_x_
		screen_y:          e.screen_y_
		client_x:          e.client_x_
		client_y:          e.client_y_
		page_x:            e.page_x_
		page_y:            e.page_y_
		offset_x:          e.offset_x_
		offset_y:          e.offset_y_
		movement_x:        e.movement_x_
		movement_y:        e.movement_y_
		button:            e.button_
		buttons:           e.buttons_
		related_target:    e.related_target()
	})
	// Cloning does not create a user-agent-dispatched event.
	clone.is_trusted_ = false
	return clone
}

// MouseEvent coordinate/modifier/button accessors (untrusted events floor the coordinates, per spec).
pub fn (e &MouseEvent) screen_x() f64 {
	return if e.is_trusted_ { e.screen_x_ } else { math.floor(e.screen_x_) }
}

pub fn (e &MouseEvent) screen_y() f64 {
	return if e.is_trusted_ { e.screen_y_ } else { math.floor(e.screen_y_) }
}

pub fn (e &MouseEvent) client_x() f64 {
	return if e.is_trusted_ { e.client_x_ } else { math.floor(e.client_x_) }
}

pub fn (e &MouseEvent) client_y() f64 {
	return if e.is_trusted_ { e.client_y_ } else { math.floor(e.client_y_) }
}

pub fn (e &MouseEvent) page_x() f64 {
	return if e.is_trusted_ { e.page_x_ } else { math.floor(e.page_x_) }
}

pub fn (e &MouseEvent) page_y() f64 {
	return if e.is_trusted_ { e.page_y_ } else { math.floor(e.page_y_) }
}

pub fn (e &MouseEvent) x() f64 {
	return e.client_x()
}

pub fn (e &MouseEvent) y() f64 {
	return e.client_y()
}

pub fn (e &MouseEvent) offset_x() f64 {
	return if e.is_trusted_ { e.offset_x_ } else { math.floor(e.offset_x_) }
}

pub fn (e &MouseEvent) offset_y() f64 {
	return if e.is_trusted_ { e.offset_y_ } else { math.floor(e.offset_y_) }
}

pub fn (e &MouseEvent) movement_x() f64 {
	return e.movement_x_
}

pub fn (e &MouseEvent) movement_y() f64 {
	return e.movement_y_
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

pub fn (e &MouseEvent) platform_ctrl_key() bool {
	$if macos {
		return e.meta_key()
	} $else {
		return e.ctrl_key()
	}
}

pub fn (e &MouseEvent) related_target() ?&EventTarget {
	return e.related_target_
}

pub fn (e &MouseEvent) related_target_mouse() ?&EventTarget {
	return e.related_target()
}

pub fn (mut e MouseEvent) set_offset_x(offset_x f64) {
	e.offset_x_ = offset_x
}

pub fn (mut e MouseEvent) set_offset_y(offset_y f64) {
	e.offset_y_ = offset_y
}

pub fn (e &MouseEvent) is_mouse_event() bool {
	return true
}

pub fn (e &MouseEvent) which() u32 {
	return u32(e.button_ + 1)
}

pub fn (e &MouseEvent) get_modifier_state(key string) bool {
	return match key {
		'Control' { e.ctrl_key_ }
		'Shift' { e.shift_key_ }
		'Alt' { e.alt_key_ }
		'Meta' { e.meta_key_ }
		'AltGraph' { e.modifier_alt_graph_ }
		'CapsLock' { e.modifier_caps_lock_ }
		'Fn' { e.modifier_fn_ }
		'FnLock' { e.modifier_fn_lock_ }
		'Hyper' { e.modifier_hyper_ }
		'NumLock' { e.modifier_num_lock_ }
		'ScrollLock' { e.modifier_scroll_lock_ }
		'Super' { e.modifier_super_ }
		'Symbol' { e.modifier_symbol_ }
		'SymbolLock' { e.modifier_symbol_lock_ }
		else { false }
	}
}

pub fn (mut e MouseEvent) init_mouse_event(type_ string, bubbles bool, cancelable bool, view voidptr, detail int, screen_x int, screen_y int, client_x int, client_y int, ctrl_key bool, alt_key bool, shift_key bool, meta_key bool, button i16, related_target ?&EventTarget) {
	if e.dispatched_ {
		return
	}
	e.initialize_event(type_, bubbles, cancelable)
	e.view_ = view
	e.detail_ = detail
	e.screen_x_ = screen_x
	e.screen_y_ = screen_y
	e.client_x_ = client_x
	e.client_y_ = client_y
	e.ctrl_key_ = ctrl_key
	e.alt_key_ = alt_key
	e.shift_key_ = shift_key
	e.meta_key_ = meta_key
	e.button_ = button
	e.set_related_target(related_target)
}

// --- KeyboardEvent (UIEvents/KeyboardEvent.h) ---

pub struct KeyboardEventInit {
	EventModifierInit
pub mut:
	key          string
	code         string
	location     u32
	repeat       bool
	is_composing bool
	char_code    u32
	key_code     u32
}

@[heap]
pub struct KeyboardEvent {
	UIEvent
pub mut:
	key_code_             u32
	char_code_            u32
	key_                  string
	code_                 string
	location_             u32
	ctrl_key_             bool
	shift_key_            bool
	alt_key_              bool
	meta_key_             bool
	modifier_alt_graph_   bool
	modifier_caps_lock_   bool
	modifier_fn_          bool
	modifier_fn_lock_     bool
	modifier_hyper_       bool
	modifier_num_lock_    bool
	modifier_scroll_lock_ bool
	modifier_super_       bool
	modifier_symbol_      bool
	modifier_symbol_lock_ bool
	repeat_               bool
	is_composing_         bool
}

pub fn KeyboardEvent.create(event_name string, init KeyboardEventInit) &KeyboardEvent {
	return &KeyboardEvent{
		UIEvent:               UIEvent{
			Event:   Event{
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
			view_:   init.view
		}
		key_code_:             init.key_code
		char_code_:            init.char_code
		key_:                  init.key
		code_:                 init.code
		location_:             init.location
		ctrl_key_:             init.ctrl_key
		shift_key_:            init.shift_key
		alt_key_:              init.alt_key
		meta_key_:             init.meta_key
		modifier_alt_graph_:   init.modifier_alt_graph
		modifier_caps_lock_:   init.modifier_caps_lock
		modifier_fn_:          init.modifier_fn
		modifier_fn_lock_:     init.modifier_fn_lock
		modifier_hyper_:       init.modifier_hyper
		modifier_num_lock_:    init.modifier_num_lock
		modifier_scroll_lock_: init.modifier_scroll_lock
		modifier_super_:       init.modifier_super
		modifier_symbol_:      init.modifier_symbol
		modifier_symbol_lock_: init.modifier_symbol_lock
		repeat_:               init.repeat
		is_composing_:         init.is_composing
	}
}

pub fn KeyboardEvent.construct_impl(event_name string, init KeyboardEventInit) !&KeyboardEvent {
	mut event := KeyboardEvent.create(event_name, init)
	event.is_trusted_ = false
	return event
}

pub fn KeyboardEvent.create_from_platform_event(event_name string, platform_key KeyCode, modifiers u32, code_point u32, repeat bool) &KeyboardEvent {
	return KeyboardEvent.create(event_name, KeyboardEventInit{
		EventModifierInit: EventModifierInit{
			UIEventInit: UIEventInit{
				EventInit: EventInit{
					bubbles:    true
					cancelable: true
					composed:   true
				}
			}
			ctrl_key:  modifiers & modifier_ctrl != 0
			shift_key: modifiers & modifier_shift != 0
			alt_key:   modifiers & modifier_alt != 0
			meta_key:  modifiers & modifier_super != 0
		}
		key:          get_event_key(platform_key, code_point, modifiers)
		code:         get_event_code(platform_key, modifiers)
		location:     get_event_location(platform_key, modifiers)
		repeat:       repeat
		is_composing: false
		key_code:     determine_key_code(platform_key, code_point)
		char_code:    determine_char_code(event_name, code_point)
	})
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

pub fn (e &KeyboardEvent) location() u32 {
	return e.location_
}

pub fn (e &KeyboardEvent) ctrl_key() bool {
	return e.ctrl_key_
}

pub fn (e &KeyboardEvent) shift_key() bool {
	return e.shift_key_
}

pub fn (e &KeyboardEvent) alt_key() bool {
	return e.alt_key_
}

pub fn (e &KeyboardEvent) meta_key() bool {
	return e.meta_key_
}

pub fn (e &KeyboardEvent) repeat() bool {
	return e.repeat_
}

pub fn (e &KeyboardEvent) is_composing() bool {
	return e.is_composing_
}

pub fn (e &KeyboardEvent) get_modifier_state(key string) bool {
	return match key {
		'Control' { e.ctrl_key_ }
		'Shift' { e.shift_key_ }
		'Alt' { e.alt_key_ }
		'Meta' { e.meta_key_ }
		'AltGraph' { e.modifier_alt_graph_ }
		'CapsLock' { e.modifier_caps_lock_ }
		'Fn' { e.modifier_fn_ }
		'FnLock' { e.modifier_fn_lock_ }
		'Hyper' { e.modifier_hyper_ }
		'NumLock' { e.modifier_num_lock_ }
		'ScrollLock' { e.modifier_scroll_lock_ }
		'Super' { e.modifier_super_ }
		'Symbol' { e.modifier_symbol_ }
		'SymbolLock' { e.modifier_symbol_lock_ }
		else { false }
	}
}

pub fn (mut e KeyboardEvent) init_keyboard_event(type_ string, bubbles bool, cancelable bool, view voidptr, key string, location u32, ctrl_key bool, alt_key bool, shift_key bool, meta_key bool) {
	if e.dispatched_ {
		return
	}
	e.initialize_event(type_, bubbles, cancelable)
	e.view_ = view
	e.key_ = key
	e.location_ = location
	e.ctrl_key_ = ctrl_key
	e.alt_key_ = alt_key
	e.shift_key_ = shift_key
	e.meta_key_ = meta_key
}

// which() returns the key code (UIEvents/KeyboardEvent.h override).
pub fn (e &KeyboardEvent) which() u32 {
	return e.key_code_
}

// --- PointerEvent (UIEvents/PointerEvent.h) : MouseEvent ---

pub struct PointerEventInit {
	MouseEventInit
pub mut:
	pointer_id           int
	width                f64 = 1.0
	height               f64 = 1.0
	pressure             f32
	tangential_pressure  f32
	tilt_x               ?int
	tilt_y               ?int
	twist                int
	altitude_angle       ?f64
	azimuth_angle        ?f64
	pointer_type         string
	is_primary           bool
	persistent_device_id int
	coalesced_events     []&PointerEvent
	predicted_events     []&PointerEvent
}

@[heap]
pub struct PointerEvent {
	MouseEvent
pub mut:
	pointer_id_           int
	width_                f64 = 1.0
	height_               f64 = 1.0
	pressure_             f32
	tangential_pressure_  f32
	tilt_x_               int
	tilt_y_               int
	twist_                int
	altitude_angle_       f64
	azimuth_angle_        f64
	pointer_type_         string
	is_primary_           bool
	persistent_device_id_ int
	coalesced_events_     []&PointerEvent
	predicted_events_     []&PointerEvent
}

pub fn PointerEvent.create(event_name string, init PointerEventInit) &PointerEvent {
	return &PointerEvent{
		MouseEvent:            MouseEvent{
			UIEvent:               UIEvent{
				Event:   Event{
					interface_:   .pointer_event
					type_:        event_name
					bubbles_:     init.bubbles
					cancelable_:  init.cancelable
					composed_:    init.composed
					initialized_: true
					is_trusted_:  true
					time_stamp_:  current_event_timestamp()
					related_target_: init.related_target
				}
				detail_: init.detail
				view_:   init.view
			}
			screen_x_:             init.screen_x
			screen_y_:             init.screen_y
			client_x_:             init.client_x
			client_y_:             init.client_y
			page_x_:               init.page_x
			page_y_:               init.page_y
			offset_x_:             init.offset_x
			offset_y_:             init.offset_y
			movement_x_:           init.movement_x
			movement_y_:           init.movement_y
			ctrl_key_:             init.ctrl_key
			shift_key_:            init.shift_key
			alt_key_:              init.alt_key
			meta_key_:             init.meta_key
			button_:               init.button
			buttons_:              init.buttons
			modifier_alt_graph_:   init.modifier_alt_graph
			modifier_caps_lock_:   init.modifier_caps_lock
			modifier_fn_:          init.modifier_fn
			modifier_fn_lock_:     init.modifier_fn_lock
			modifier_hyper_:       init.modifier_hyper
			modifier_num_lock_:    init.modifier_num_lock
			modifier_scroll_lock_: init.modifier_scroll_lock
			modifier_super_:       init.modifier_super
			modifier_symbol_:      init.modifier_symbol
			modifier_symbol_lock_: init.modifier_symbol_lock
		}
		pointer_id_:           init.pointer_id
		width_:                init.width
		height_:               init.height
		pressure_:             init.pressure
		tangential_pressure_:  init.tangential_pressure
		tilt_x_:               init.tilt_x or { 0 }
		tilt_y_:               init.tilt_y or { 0 }
		twist_:                init.twist
		altitude_angle_:       init.altitude_angle or { math.pi / 2.0 }
		azimuth_angle_:        init.azimuth_angle or { 0 }
		pointer_type_:         init.pointer_type
		is_primary_:           init.is_primary
		persistent_device_id_: init.persistent_device_id
		coalesced_events_:     init.coalesced_events.clone()
		predicted_events_:     init.predicted_events.clone()
	}
}

pub fn PointerEvent.construct_impl(event_name string, init PointerEventInit) !&PointerEvent {
	return PointerEvent.create_for_constructor(event_name, init, current_event_timestamp())
}

pub fn PointerEvent.create_for_constructor(event_name string, event_init PointerEventInit, time_stamp DOMHighResTimeStamp) !&PointerEvent {
	mut event := PointerEvent.create(event_name, event_init)
	event.is_trusted_ = false
	event.set_time_stamp(time_stamp)
	event.page_x_ = event_init.client_x
	event.page_y_ = event_init.client_y
	event.offset_x_ = event_init.client_x
	event.offset_y_ = event_init.client_y
	return event
}

pub fn PointerEvent.create_from_platform_event(view voidptr, event_name string, screen CSSPixelPoint_, page CSSPixelPoint_, client CSSPixelPoint_, offset CSSPixelPoint_, movement ?CSSPixelPoint_, button MouseButton, buttons u16, modifiers u32) &PointerEvent {
	movement_value := movement or { CSSPixelPoint_{} }
	return PointerEvent.create(event_name, PointerEventInit{
		MouseEventInit: MouseEventInit{
			EventModifierInit: EventModifierInit{
				UIEventInit: UIEventInit{
					EventInit: EventInit{
						bubbles:    true
						cancelable: true
						composed:   true
					}
					view:      view
				}
				ctrl_key:    modifiers & modifier_ctrl != 0
				shift_key:   modifiers & modifier_shift != 0
				alt_key:     modifiers & modifier_alt != 0
				meta_key:    modifiers & modifier_super != 0
			}
			screen_x:          screen.x()
			screen_y:          screen.y()
			client_x:          client.x()
			client_y:          client.y()
			page_x:            page.x()
			page_y:            page.y()
			offset_x:          offset.x()
			offset_y:          offset.y()
			movement_x:        movement_value.x()
			movement_y:        movement_value.y()
			button:            mouse_button_to_button_code(button)
			buttons:           buttons
		}
		pointer_type: pointer_type_mouse
		is_primary:   true
	})
}

pub fn (e &PointerEvent) clone() &PointerEvent {
	mut clone := PointerEvent.create(e.type_, PointerEventInit{
		MouseEventInit:       MouseEventInit{
			EventModifierInit: EventModifierInit{
				UIEventInit: UIEventInit{
					detail: e.detail_
					view:   e.view_
				}
				ctrl_key:    e.ctrl_key_
				shift_key:   e.shift_key_
				alt_key:     e.alt_key_
				meta_key:    e.meta_key_
			}
			screen_x:          e.screen_x()
			screen_y:          e.screen_y()
			client_x:          e.client_x()
			client_y:          e.client_y()
			page_x:            e.page_x()
			page_y:            e.page_y()
			offset_x:          e.offset_x()
			offset_y:          e.offset_y()
			movement_x:        e.movement_x_
			movement_y:        e.movement_y_
			button:            e.button_
			buttons:           e.buttons_
			related_target:    e.related_target()
		}
		pointer_id:           e.pointer_id_
		width:                e.width_
		height:               e.height_
		pressure:             e.pressure_
		tangential_pressure:  e.tangential_pressure_
		tilt_x:               e.tilt_x_
		tilt_y:               e.tilt_y_
		twist:                e.twist_
		altitude_angle:       e.altitude_angle_
		azimuth_angle:        e.azimuth_angle_
		pointer_type:         e.pointer_type_
		is_primary:           e.is_primary_
		persistent_device_id: e.persistent_device_id_
	})
	clone.is_trusted_ = false
	return clone
}

pub fn (e &PointerEvent) pointer_id() int {
	return e.pointer_id_
}

pub fn (e &PointerEvent) width() f64 {
	return e.width_
}

pub fn (e &PointerEvent) height() f64 {
	return e.height_
}

pub fn (e &PointerEvent) pressure() f32 {
	return e.pressure_
}

pub fn (e &PointerEvent) tangential_pressure() f32 {
	return e.tangential_pressure_
}

pub fn (e &PointerEvent) tilt_x() int {
	return e.tilt_x_
}

pub fn (e &PointerEvent) tilt_y() int {
	return e.tilt_y_
}

pub fn (e &PointerEvent) twist() int {
	return e.twist_
}

pub fn (e &PointerEvent) altitude_angle() f64 {
	return e.altitude_angle_
}

pub fn (e &PointerEvent) azimuth_angle() f64 {
	return e.azimuth_angle_
}

pub fn (e &PointerEvent) pointer_type() string {
	return e.pointer_type_
}

pub fn (e &PointerEvent) is_primary() bool {
	return e.is_primary_
}

pub fn (e &PointerEvent) persistent_device_id() int {
	return e.persistent_device_id_
}

pub fn (e &PointerEvent) get_coalesced_events() []&PointerEvent {
	return e.coalesced_events_.clone()
}

pub fn (e &PointerEvent) get_predicted_events() []&PointerEvent {
	return e.predicted_events_.clone()
}

pub fn (e &PointerEvent) is_pointer_event() bool {
	return true
}

fn (e &PointerEvent) should_have_fractional_coordinates() bool {
	return e.is_trusted_ || e.type_ !in ['click', 'auxclick', 'contextmenu']
}

pub fn (e &PointerEvent) screen_x() f64 {
	return if e.should_have_fractional_coordinates() { e.screen_x_ } else { math.floor(e.screen_x_) }
}

pub fn (e &PointerEvent) screen_y() f64 {
	return if e.should_have_fractional_coordinates() { e.screen_y_ } else { math.floor(e.screen_y_) }
}

pub fn (e &PointerEvent) page_x() f64 {
	return if e.should_have_fractional_coordinates() { e.page_x_ } else { math.floor(e.page_x_) }
}

pub fn (e &PointerEvent) page_y() f64 {
	return if e.should_have_fractional_coordinates() { e.page_y_ } else { math.floor(e.page_y_) }
}

pub fn (e &PointerEvent) client_x() f64 {
	return if e.should_have_fractional_coordinates() { e.client_x_ } else { math.floor(e.client_x_) }
}

pub fn (e &PointerEvent) client_y() f64 {
	return if e.should_have_fractional_coordinates() { e.client_y_ } else { math.floor(e.client_y_) }
}

pub fn (e &PointerEvent) offset_x() f64 {
	return if e.should_have_fractional_coordinates() { e.offset_x_ } else { math.floor(e.offset_x_) }
}

pub fn (e &PointerEvent) offset_y() f64 {
	return if e.should_have_fractional_coordinates() { e.offset_y_ } else { math.floor(e.offset_y_) }
}

pub enum MouseButton {
	none
	primary
	secondary
	middle
	backward
	forward
}

pub fn mouse_button_to_button_code(button MouseButton) i16 {
	return match button {
		.none { -1 }
		.primary { 0 }
		.middle { 1 }
		.secondary { 2 }
		.backward { 3 }
		.forward { 4 }
	}
}

pub fn button_code_to_mouse_button(button i16) MouseButton {
	return match button {
		0 { .primary }
		1 { .middle }
		2 { .secondary }
		3 { .backward }
		4 { .forward }
		else { .none }
	}
}

// --- CompositionEvent, FocusEvent, InputEvent and TextEvent ---

pub struct CompositionEventInit {
	UIEventInit
pub mut:
	data string
}

@[heap]
pub struct CompositionEvent {
	UIEvent
pub mut:
	data_ string
}

pub fn CompositionEvent.create(event_name string, init CompositionEventInit) &CompositionEvent {
	return &CompositionEvent{
		UIEvent: UIEvent{
			Event:   Event{
				interface_:   .composition_event
				type_:        event_name
				bubbles_:     init.bubbles
				cancelable_:  init.cancelable
				composed_:    init.composed
				initialized_: true
				is_trusted_:  true
				time_stamp_:  current_event_timestamp()
			}
			detail_: init.detail
			view_:   init.view
		}
		data_:   init.data
	}
}

pub fn CompositionEvent.construct_impl(event_name string, init CompositionEventInit) !&CompositionEvent {
	mut event := CompositionEvent.create(event_name, init)
	event.is_trusted_ = false
	return event
}

pub fn (e &CompositionEvent) data() string {
	return e.data_
}

pub fn (mut e CompositionEvent) init_composition_event(type_ string, bubbles bool, cancelable bool, view voidptr, data string) {
	if e.dispatched_ {
		return
	}
	e.initialize_event(type_, bubbles, cancelable)
	e.view_ = view
	e.data_ = data
}

pub struct FocusEventInit {
	UIEventInit
pub mut:
	related_target ?&EventTarget
}

@[heap]
pub struct FocusEvent {
	UIEvent
}

pub fn FocusEvent.create(event_name string, init FocusEventInit) &FocusEvent {
	return &FocusEvent{
		UIEvent: UIEvent{
			Event:   Event{
				interface_:      .focus_event
				type_:           event_name
				bubbles_:        init.bubbles
				cancelable_:     init.cancelable
				composed_:       init.composed
				initialized_:    true
				is_trusted_:     true
				related_target_: init.related_target
				time_stamp_:     current_event_timestamp()
			}
			detail_: init.detail
			view_:   init.view
		}
	}
}

pub fn FocusEvent.construct_impl(event_name string, init FocusEventInit) !&FocusEvent {
	mut event := FocusEvent.create(event_name, init)
	event.is_trusted_ = false
	return event
}

pub struct InputEventInit {
	UIEventInit
pub mut:
	data          ?string
	is_composing  bool
	input_type    string
	// HTML::DataTransfer cannot be imported into dom without forming a module
	// cycle, so retain the nullable GC edge as an opaque pointer.
	data_transfer voidptr = unsafe { nil }
	target_ranges []&StaticRange
}

@[heap]
pub struct InputEvent {
	UIEvent
pub mut:
	data_          ?string
	is_composing_  bool
	input_type_    string
	data_transfer_ voidptr = unsafe { nil }
	target_ranges_ []&StaticRange
}

fn new_input_event(event_name string, init InputEventInit, target_ranges []&StaticRange, trusted bool, time_stamp DOMHighResTimeStamp) &InputEvent {
	return &InputEvent{
		UIEvent:        UIEvent{
			Event:   Event{
				interface_:   .input_event
				type_:        event_name
				bubbles_:     init.bubbles
				cancelable_:  init.cancelable
				composed_:    init.composed
				initialized_: true
				is_trusted_:  trusted
				time_stamp_:  time_stamp
			}
			detail_: init.detail
			view_:   init.view
		}
		data_:          init.data
		is_composing_:  init.is_composing
		input_type_:    init.input_type
		data_transfer_: init.data_transfer
		target_ranges_: target_ranges.clone()
	}
}

pub fn InputEvent.create(event_name string, event_init InputEventInit, target_ranges []&StaticRange, time_stamp DOMHighResTimeStamp) &InputEvent {
	return new_input_event(event_name, event_init, target_ranges, false, time_stamp)
}

pub fn InputEvent.create_from_platform_event(event_name string, init InputEventInit, target_ranges []&StaticRange, time_stamp DOMHighResTimeStamp) &InputEvent {
	mut platform_init := init
	platform_init.bubbles = true
	platform_init.composed = true
	if event_name == 'beforeinput' {
		platform_init.cancelable = true
	}
	return new_input_event(event_name, platform_init, target_ranges, true, time_stamp)
}

pub fn InputEvent.construct_impl(event_name string, init InputEventInit) !&InputEvent {
	return new_input_event(event_name, init, init.target_ranges, false, 0)
}

pub fn (e &InputEvent) data() ?string {
	return e.data_
}

pub fn (e &InputEvent) is_composing() bool {
	return e.is_composing_
}

pub fn (e &InputEvent) input_type() string {
	return e.input_type_
}

pub fn (e &InputEvent) data_transfer() voidptr {
	return e.data_transfer_
}

pub fn InputEvent.data_transfer_offset() usize {
	return usize(__offsetof(InputEvent, data_transfer_))
}

pub fn (e &InputEvent) get_target_ranges() []&StaticRange {
	return e.target_ranges_.clone()
}

@[heap]
pub struct TextEvent {
	UIEvent
pub mut:
	data_ string
}

pub fn TextEvent.create(event_name string) &TextEvent {
	return &TextEvent{
		UIEvent: UIEvent{
			Event: Event{
				interface_:   .text_event
				type_:        event_name
				initialized_: true
				is_trusted_:  true
				time_stamp_:  current_event_timestamp()
			}
		}
	}
}

pub fn (e &TextEvent) data() string {
	return e.data_
}

pub fn (mut e TextEvent) init_text_event(type_ string, bubbles bool, cancelable bool, view voidptr, data string) {
	if e.dispatched_ {
		return
	}
	e.initialize_event(type_, bubbles, cancelable)
	e.view_ = view
	e.data_ = data
}

// --- WheelEvent ---

pub const dom_delta_pixel = u32(0)
pub const dom_delta_line = u32(1)
pub const dom_delta_page = u32(2)

pub struct WheelEventInit {
	MouseEventInit
pub mut:
	delta_x       f64
	delta_y       f64
	delta_z       f64
	delta_mode    u32
	wheel_delta_x i32
	wheel_delta_y i32
}

@[heap]
pub struct WheelEvent {
	MouseEvent
pub mut:
	delta_x_       f64
	delta_y_       f64
	delta_z_       f64
	delta_mode_    u32
	wheel_delta_x_ i32
	wheel_delta_y_ i32
}

fn legacy_wheel_delta_from_delta(delta f64) i32 {
	legacy_delta := -delta
	if legacy_delta >= 2147483647.0 {
		return i32(2147483647)
	}
	if legacy_delta <= -2147483648.0 {
		return i32(-2147483647 - 1)
	}
	if math.is_nan(legacy_delta) {
		return 0
	}
	return i32(math.round_to_even(legacy_delta))
}

fn new_wheel_event(event_name string, init WheelEventInit, trusted bool) &WheelEvent {
	return &WheelEvent{
		MouseEvent:  MouseEvent{
			UIEvent:               UIEvent{
				Event:   Event{
					interface_:   .wheel_event
					type_:        event_name
					bubbles_:     init.bubbles
					cancelable_:  init.cancelable
					composed_:    init.composed
					initialized_: true
					is_trusted_:  trusted
					time_stamp_:  current_event_timestamp()
					related_target_: init.related_target
				}
				detail_: init.detail
				view_:   init.view
			}
			screen_x_:             init.screen_x
			screen_y_:             init.screen_y
			client_x_:             init.client_x
			client_y_:             init.client_y
			page_x_:               init.page_x
			page_y_:               init.page_y
			offset_x_:             init.offset_x
			offset_y_:             init.offset_y
			movement_x_:           init.movement_x
			movement_y_:           init.movement_y
			ctrl_key_:             init.ctrl_key
			shift_key_:            init.shift_key
			alt_key_:              init.alt_key
			meta_key_:             init.meta_key
			button_:               init.button
			buttons_:              init.buttons
			modifier_alt_graph_:   init.modifier_alt_graph
			modifier_caps_lock_:   init.modifier_caps_lock
			modifier_fn_:          init.modifier_fn
			modifier_fn_lock_:     init.modifier_fn_lock
			modifier_hyper_:       init.modifier_hyper
			modifier_num_lock_:    init.modifier_num_lock
			modifier_scroll_lock_: init.modifier_scroll_lock
			modifier_super_:       init.modifier_super
			modifier_symbol_:      init.modifier_symbol
			modifier_symbol_lock_: init.modifier_symbol_lock
		}
		delta_x_:    init.delta_x
		delta_y_:    init.delta_y
		delta_z_:    init.delta_z
		delta_mode_: init.delta_mode
		wheel_delta_x_: if init.wheel_delta_x != 0 {
			init.wheel_delta_x
		} else {
			legacy_wheel_delta_from_delta(init.delta_x)
		}
		wheel_delta_y_: if init.wheel_delta_y != 0 {
			init.wheel_delta_y
		} else {
			legacy_wheel_delta_from_delta(init.delta_y)
		}
	}
}

pub fn WheelEvent.create(event_name string, init WheelEventInit) &WheelEvent {
	return new_wheel_event(event_name, init, true)
}

pub fn WheelEvent.construct_impl(event_name string, init WheelEventInit) !&WheelEvent {
	return WheelEvent.create_for_constructor(event_name, init, current_event_timestamp())
}

pub fn WheelEvent.create_for_constructor(event_name string, event_init WheelEventInit, time_stamp DOMHighResTimeStamp) &WheelEvent {
	mut event := new_wheel_event(event_name, event_init, false)
	event.set_time_stamp(time_stamp)
	event.page_x_ = event_init.client_x
	event.page_y_ = event_init.client_y
	event.offset_x_ = event_init.client_x
	event.offset_y_ = event_init.client_y
	return event
}

pub fn WheelEvent.create_from_platform_event(view voidptr, event_name string, screen CSSPixelPoint_, page CSSPixelPoint_, client CSSPixelPoint_, offset CSSPixelPoint_, delta_x f64, delta_y f64, button i16, buttons u16, modifiers u32) &WheelEvent {
	mut event := new_wheel_event(event_name, WheelEventInit{
		MouseEventInit: MouseEventInit{
			EventModifierInit: EventModifierInit{
				UIEventInit: UIEventInit{
					EventInit: EventInit{
						bubbles:    true
						cancelable: true
						composed:   true
					}
					view:      view
				}
				ctrl_key:  modifiers & modifier_ctrl != 0
				shift_key: modifiers & modifier_shift != 0
				alt_key:   modifiers & modifier_alt != 0
				meta_key:  modifiers & modifier_super != 0
			}
			screen_x: screen.x()
			screen_y: screen.y()
			client_x: client.x()
			client_y: client.y()
			button:   button
			buttons:  buttons
		}
		delta_x:    delta_x
		delta_y:    delta_y
		delta_mode: dom_delta_pixel
	}, true)
	event.page_x_ = page.x()
	event.page_y_ = page.y()
	event.offset_x_ = offset.x()
	event.offset_y_ = offset.y()
	return event
}

pub fn (e &WheelEvent) delta_x() f64 {
	return e.delta_x_
}

pub fn (e &WheelEvent) delta_y() f64 {
	return e.delta_y_
}

pub fn (e &WheelEvent) delta_z() f64 {
	return e.delta_z_
}

pub fn (e &WheelEvent) delta_mode() u32 {
	return e.delta_mode_
}

pub fn (e &WheelEvent) wheel_delta_x() i32 {
	return e.wheel_delta_x_
}

pub fn (e &WheelEvent) wheel_delta_y() i32 {
	return e.wheel_delta_y_
}

pub fn (e &WheelEvent) wheel_delta() i32 {
	return if e.wheel_delta_y_ != 0 { e.wheel_delta_y_ } else { e.wheel_delta_x_ }
}

pub const input_type_delete_by_cut = 'deleteByCut'
pub const input_type_delete_content_backward = 'deleteContentBackward'
pub const input_type_delete_content_forward = 'deleteContentForward'
pub const input_type_insert_from_paste = 'insertFromPaste'
pub const input_type_insert_composition_text = 'insertCompositionText'
pub const input_type_insert_line_break = 'insertLineBreak'
pub const input_type_insert_paragraph = 'insertParagraph'
pub const input_type_insert_text = 'insertText'

pub const pointer_type_mouse = 'mouse'
pub const pointer_type_pen = 'pen'
pub const pointer_type_touch = 'touch'

pub const dom_key_location_standard = u32(0)
pub const dom_key_location_left = u32(1)
pub const dom_key_location_right = u32(2)
pub const dom_key_location_numpad = u32(3)
