// Copyright (c) 2020-2022, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2021, Luke Wilde <lukew@serenityos.org>
// Copyright (c) 2022, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2024, Glenn Skrzypczak <glenn.skrzypczak@gmail.com>
// Copyright (c) 2024, Tim Ledbetter <tim.ledbetter@ladybird.org>
// Copyright (c) 2025, Felipe Munoz Mazur <felipe.munoz.mazur@protonmail.com>
// Copyright (c) 2025, Simon Farre <simon.farre.cx@gmail.com>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from:
// - Libraries/LibWeb/DOM/Event.cpp/.h
// - Libraries/LibWeb/DOM/EventTarget.cpp/.h
// - Libraries/LibWeb/DOM/CustomEvent.cpp/.h
// - Libraries/LibWeb/DOM/DOMEventListener.cpp/.h
// - Libraries/LibWeb/DOM/IDLEventListener.cpp/.h
// - Libraries/LibWeb/DOM/EventDispatcher.cpp/.h
// - Libraries/LibWeb/DOM/AbortController.cpp/.h
// - Libraries/LibWeb/DOM/AbortSignal.cpp/.h

module dom

import time
import webidl
import libjs

// DOM event algorithms use the translated callback and JS-value boundary types
// below. Execution realms and arbitrary JavaScript objects remain runtime
// boundaries; event state and callback return-value semantics stay typed here.

pub type DOMHighResTimeStamp = f64

pub enum JSValueKind {
	undefined
	null_
	boolean
	number
	string
	object
	runtime_value
}

@[heap]
pub struct JSValue {
pub mut:
	kind         JSValueKind = .undefined
	boolean_data bool
	number_data  f64
	string_data  string
	// Source PrimitiveString units at the structured-clone engine boundary.
	// string_data remains the standalone string/diagnostic compatibility view.
	string_utf16_ ?libjs.Utf16String
	object_data  voidptr
	// HTML's structured-clone implementation uses object_data for its
	// lightweight object model. Other object_data values (event callbacks,
	// host objects, and so on) remain deliberately non-serializable.
	is_structured_object_ bool
	// Actual host/WebIDL values retain their original reason and owning root;
	// they are not reconstructed as the standalone structured-object model.
	native_value_ ?webidl.Value
}

pub fn js_undefined() JSValue {
	return JSValue{}
}

pub fn js_null() JSValue {
	return JSValue{
		kind: .null_
	}
}

pub fn js_bool(value bool) JSValue {
	return JSValue{
		kind:         .boolean
		boolean_data: value
	}
}

pub fn js_number(value f64) JSValue {
	return JSValue{
		kind:        .number
		number_data: value
	}
}

pub fn js_string(value string) JSValue {
	return JSValue{
		kind:        .string
		string_data: value
	}
}

pub fn js_utf16_string(value libjs.Utf16String) JSValue {
	return JSValue{kind: .string, string_data: value.str(), string_utf16_: value}
}

pub fn js_object(value voidptr) JSValue {
	return JSValue{
		kind:        .object
		object_data: value
	}
}

pub fn js_structured_object(value voidptr) JSValue {
	return JSValue{
		kind:                  .object
		object_data:           value
		is_structured_object_: true
	}
}

pub fn (value JSValue) is_undefined() bool {
	return value.kind == .undefined
}

pub fn (value JSValue) is_nullish() bool {
	return value.kind == .undefined || value.kind == .null_
}

pub fn (value JSValue) is_boolean() bool {
	return value.kind == .boolean
}

pub fn (value JSValue) is_number() bool {
	return value.kind == .number
}

pub fn (value JSValue) is_string() bool {
	return value.kind == .string
}

pub fn (value JSValue) is_object() bool {
	return value.kind == .object
}

pub fn (value JSValue) is_structured_object() bool {
	return value.kind == .object && value.is_structured_object_
}

pub fn (value JSValue) as_bool() bool {
	return value.boolean_data
}

pub fn (value JSValue) to_string_value() string {
	return match value.kind {
		.undefined {
			'undefined'
		}
		.null_ {
			'null'
		}
		.boolean {
			if value.boolean_data {
				'true'
			} else {
				'false'
			}
		}
		.number {
			value.number_data.str()
		}
		.string {
			value.string_data
		}
		.object {
			'[object Object]'
		}
		.runtime_value {
			native := value.native_value_ or { panic('Missing actual DOM JavaScript value') }
			if exception := webidl.dom_exception_from_object(native) {
				return '${exception.name()}: ${exception.message()}'
			}
			webidl.to_string(native) or { err.msg() }
		}
	}
}

fn abort_error_value(message string) JSValue {
	return js_webidl_value(webidl.dom_exception_value(webidl.DOMException.create('AbortError', message)))
}

fn timeout_error_value(message string) JSValue {
	return js_webidl_value(webidl.dom_exception_value(webidl.DOMException.create('TimeoutError', message)))
}

// https://dom.spec.whatwg.org/#dictdef-eventinit
pub struct EventInit {
pub mut:
	bubbles    bool
	cancelable bool
	composed   bool
}

pub enum EventPhase {
	none
	capturing_phase
	at_target
	bubbling_phase
}

pub type TouchTargetList = []&EventTarget

pub struct EventPathEntry {
pub mut:
	invocation_target                &EventTarget = unsafe { nil }
	invocation_target_in_shadow_tree bool
	shadow_adjusted_target           ?&EventTarget
	related_target                   ?&EventTarget
	touch_target_list                TouchTargetList
	root_of_closed_tree              bool
	slot_in_closed_tree              bool
	index                            int
}

// https://dom.spec.whatwg.org/#concept-event-create
pub fn Event.create(event_name string, event_init EventInit) &Event {
	mut event := Event.new_with_init(event_name, event_init)
	// 4. Initialize event's isTrusted attribute to true.
	event.set_is_trusted(true)
	return event
}

pub fn Event.construct_impl(event_name string, event_init EventInit) !&Event {
	return Event.new_with_init(event_name, event_init)
}

// https://dom.spec.whatwg.org/#inner-event-creation-steps
pub fn Event.new(event_name string) &Event {
	return &Event{
		type_:        event_name
		initialized_: true
		time_stamp_:  current_event_timestamp()
	}
}

// https://dom.spec.whatwg.org/#inner-event-creation-steps
pub fn Event.new_with_init(event_name string, event_init EventInit) &Event {
	return &Event{
		type_:        event_name
		bubbles_:     event_init.bubbles
		cancelable_:  event_init.cancelable
		composed_:    event_init.composed
		initialized_: true
		time_stamp_:  current_event_timestamp()
	}
}

pub fn current_event_timestamp() DOMHighResTimeStamp {
	// C++ uses current_high_resolution_time(relevant global object). This DOM-only port does not
	// yet thread the relevant global through Event construction, so use V's monotonic clock rather
	// than epoch time.
	return DOMHighResTimeStamp(f64(time.sys_mono_now()) / 1_000_000.0)
}

pub fn (mut e Event) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(Event);
	// Base::initialize(realm);
	// Bindings::EventPrototype::define_unforgeable_attributes(realm, *this);
}

pub fn (mut e Event) visit_edges(mut visitor CellVisitor) {
	// Base::visit_edges(visitor);
	if target := e.target_ {
		visitor.visit(target)
	}
	if related_target := e.related_target_ {
		visitor.visit(related_target)
	}
	if current_target := e.current_target_ {
		visitor.visit(current_target)
	}
	for entry in e.path_ {
		visitor.visit(entry.invocation_target)
		if shadow_adjusted_target := entry.shadow_adjusted_target {
			visitor.visit(shadow_adjusted_target)
		}
		if related_target := entry.related_target {
			visitor.visit(related_target)
		}
		for touch_target in entry.touch_target_list {
			visitor.visit(touch_target)
		}
	}
	for touch_target in e.touch_target_list_ {
		visitor.visit(touch_target)
	}
	for owner in e.processed_click_handler_targets_ {
		visitor.visit(owner)
	}
}

// The compact engine replays uncompiled raw handlers after native Page input.
// Remember actual processed click owners even if a callback replaces its slot.
pub fn (event &Event) did_process_click_handler(target &EventTarget) bool {
	for owner in event.processed_click_handler_targets_ {
		if voidptr(owner) == voidptr(target) {
			return true
		}
	}
	return false
}

fn (mut event Event) note_processed_click_handler(target &EventTarget) {
	if !event.did_process_click_handler(target) {
		event.processed_click_handler_targets_ << target
	}
}

fn (mut event Event) reset_click_handler_replay_receipt() {
	event.processed_click_handler_targets_ = []&EventTarget{}
}

// C++: FlyString const& Event::type() const
pub fn (e &Event) type_name() string {
	return e.type_
}

pub fn (mut e Event) set_type(type_ string) {
	e.type_ = type_
}

// https://dom.spec.whatwg.org/#dom-event-timestamp
pub fn (e &Event) time_stamp() DOMHighResTimeStamp {
	return e.time_stamp_
}

pub fn (e &Event) target() ?&EventTarget {
	return e.target_
}

pub fn (mut e Event) set_target(target ?&EventTarget) {
	e.target_ = target
}

// NOTE: This is intended for the JS bindings.
pub fn (e &Event) src_element() ?&EventTarget {
	return e.target()
}

pub fn (e &Event) related_target() ?&EventTarget {
	return e.related_target_
}

pub fn (mut e Event) set_related_target(related_target ?&EventTarget) {
	e.related_target_ = related_target
}

pub fn (e &Event) should_stop_propagation() bool {
	return e.stop_propagation_
}

pub fn (mut e Event) set_stop_propagation(stop_propagation bool) {
	e.stop_propagation_ = stop_propagation
}

pub fn (e &Event) should_stop_immediate_propagation() bool {
	return e.stop_immediate_propagation_
}

pub fn (mut e Event) set_stop_immediate_propagation(stop_immediate_propagation bool) {
	e.stop_immediate_propagation_ = stop_immediate_propagation
}

pub fn (e &Event) cancelled() bool {
	return e.cancelled_
}

pub fn (mut e Event) set_cancelled(cancelled bool) {
	e.cancelled_ = cancelled
}

pub fn (e &Event) in_passive_listener() bool {
	return e.in_passive_listener_
}

pub fn (mut e Event) set_in_passive_listener(in_passive_listener bool) {
	e.in_passive_listener_ = in_passive_listener
}

pub fn (e &Event) composed() bool {
	return e.composed_
}

pub fn (mut e Event) set_composed(composed bool) {
	e.composed_ = composed
}

pub fn (e &Event) initialized() bool {
	return e.initialized_
}

pub fn (mut e Event) set_initialized(initialized bool) {
	e.initialized_ = initialized
}

pub fn (e &Event) dispatched() bool {
	return e.dispatched_
}

pub fn (mut e Event) set_dispatched(dispatched bool) {
	e.dispatched_ = dispatched
}

pub fn (mut e Event) prevent_default() {
	e.set_cancelled_flag()
}

pub fn (e &Event) default_prevented() bool {
	return e.cancelled()
}

pub fn (e &Event) event_phase() u16 {
	return u16(int(e.phase_))
}

pub fn (mut e Event) set_phase(phase EventPhase) {
	e.phase_ = phase
}

pub fn (e &Event) current_target() ?&EventTarget {
	return e.current_target_
}

pub fn (mut e Event) set_current_target(current_target ?&EventTarget) {
	e.current_target_ = current_target
}

// AD-HOC: Needed to return a WindowProxy when the current target is a Window,
// ensuring that JavaScript sees the correct global object instead of the internal Window.
pub fn (e &Event) current_target_for_bindings() ?&EventTarget {
	return e.current_target()
}

pub fn (e &Event) return_value() bool {
	return !e.cancelled()
}

pub fn (mut e Event) set_return_value(return_value bool) {
	if !return_value {
		e.set_cancelled_flag()
	}
}

// https://dom.spec.whatwg.org/#concept-event-path-append
pub fn (mut e Event) append_to_path(invocation_target &EventTarget, shadow_adjusted_target ?&EventTarget, related_target ?&EventTarget, touch_targets TouchTargetList, slot_in_closed_tree bool) {
	// 1. Let invocationTargetInShadowTree be false.
	mut invocation_target_in_shadow_tree := false
	// 2. If invocationTarget is a node and its root is a shadow root, then set invocationTargetInShadowTree to true.
	if invocation_target_node := event_target_as_node(invocation_target) {
		invocation_target_in_shadow_tree = invocation_target_node.root().as_shadow_root() != none
	}
	// 3. Let root-of-closed-tree be false.
	mut root_of_closed_tree := false
	// 4. If invocationTarget is a shadow root whose mode is "closed", then set root-of-closed-tree to true.
	if invocation_target_node := event_target_as_node(invocation_target) {
		if shadow_root := invocation_target_node.as_shadow_root() {
			root_of_closed_tree = shadow_root.mode == .closed
		}
	}
	// 5. Append a new struct to event's path whose invocation target is invocationTarget, invocation-target-in-shadow-tree is
	// invocationTargetInShadowTree, shadow-adjusted target is shadowAdjustedTarget, relatedTarget is relatedTarget,
	// touch target list is touchTargets, root-of-closed-tree is root-of-closed-tree, and slot-in-closed-tree is slot-in-closed-tree.
	e.path_ << EventPathEntry{
		invocation_target:                invocation_target
		invocation_target_in_shadow_tree: invocation_target_in_shadow_tree
		shadow_adjusted_target:           shadow_adjusted_target
		related_target:                   related_target
		touch_target_list:                touch_targets.clone()
		root_of_closed_tree:              root_of_closed_tree
		slot_in_closed_tree:              slot_in_closed_tree
		index:                            e.path_.len
	}
}

pub fn (e &Event) path() []EventPathEntry {
	return e.path_.clone()
}

pub fn (mut e Event) clear_path() {
	e.path_.clear()
}

pub fn (mut e Event) set_touch_target_list(touch_target_list TouchTargetList) {
	e.touch_target_list_ = touch_target_list.clone()
}

pub fn (e &Event) touch_target_list() TouchTargetList {
	return e.touch_target_list_.clone()
}

pub fn (mut e Event) clear_touch_target_list() {
	e.touch_target_list_.clear()
}

pub fn (e &Event) bubbles() bool {
	return e.bubbles_
}

pub fn (mut e Event) set_bubbles(bubbles bool) {
	e.bubbles_ = bubbles
}

pub fn (e &Event) cancelable() bool {
	return e.cancelable_
}

pub fn (mut e Event) set_cancelable(cancelable bool) {
	e.cancelable_ = cancelable
}

pub fn (e &Event) is_trusted() bool {
	return e.is_trusted_
}

pub fn (mut e Event) set_is_trusted(is_trusted bool) {
	e.is_trusted_ = is_trusted
}

pub fn (mut e Event) stop_propagation() {
	e.set_stop_propagation(true)
}

pub fn (e &Event) cancel_bubble() bool {
	return e.should_stop_propagation()
}

pub fn (mut e Event) set_cancel_bubble(cancel_bubble bool) {
	if cancel_bubble {
		e.set_stop_propagation(true)
	}
}

pub fn (mut e Event) stop_immediate_propagation() {
	e.set_stop_propagation(true)
	e.set_stop_immediate_propagation(true)
}

pub fn (mut e Event) set_time_stamp(time_stamp f64) {
	e.time_stamp_ = time_stamp
}

fn (mut e Event) set_cancelled_flag() {
	if e.cancelable() && !e.in_passive_listener() {
		e.set_cancelled(true)
	}
}

// https://dom.spec.whatwg.org/#concept-event-initialize
pub fn (mut e Event) initialize_event(type_ string, bubbles bool, cancelable bool) {
	// 1. Set event's initialized flag.
	e.set_initialized(true)

	// 2. Unset event's stop propagation flag, stop immediate propagation flag, and canceled flag.
	e.set_stop_propagation(false)
	e.set_stop_immediate_propagation(false)
	e.set_cancelled(false)

	// 3. Set event's isTrusted attribute to false.
	e.set_is_trusted(false)

	// 4. Set event's target to null.
	e.set_target(none)

	// 5. Set event's type attribute to type.
	e.set_type(type_)

	// 6. Set event's bubbles attribute to bubbles.
	e.set_bubbles(bubbles)

	// 8. Set event's cancelable attribute to cancelable.
	e.set_cancelable(cancelable)
}

// https://dom.spec.whatwg.org/#dom-event-initevent
pub fn (mut e Event) init_event(type_ string, bubbles bool, cancelable bool) {
	// 1. If this's dispatch flag is set, then return.
	if e.dispatched() {
		return
	}

	// 2. Initialize this with type, bubbles, and cancelable.
	e.initialize_event(type_, bubbles, cancelable)
}

// https://dom.spec.whatwg.org/#dom-event-composedpath
pub fn (e &Event) composed_path() []&EventTarget {
	// 1. Let composedPath be an empty list.
	mut composed_path := []&EventTarget{}

	// 2. Let path be this's path. (NOTE: Not necessary)
	path := e.path()

	// 3. If path is empty, then return composedPath.
	if path.len == 0 {
		return composed_path
	}

	// 4. Let currentTarget be this's currentTarget attribute value. (NOTE: Not necessary)
	current_target := e.current_target() or { return composed_path }

	// 5. Assert: currentTarget is an EventTarget object.
	// 6. Append currentTarget to composedPath.
	composed_path << current_target

	// 7. Let currentTargetIndex be 0.
	mut current_target_index := 0

	// 8. Let currentTargetHiddenSubtreeLevel be 0.
	mut current_target_hidden_subtree_level := 0

	// 9. Let index be path's size - 1.
	// 10. While index is greater than or equal to 0:
	for index := path.len - 1; index >= 0; index-- {
		path_entry := path[index]
		// 1. If path[index]'s root-of-closed-tree is true, then increase currentTargetHiddenSubtreeLevel by 1.
		if path_entry.root_of_closed_tree {
			current_target_hidden_subtree_level++
		}
		// 2. If path[index]'s invocation target is currentTarget, then set currentTargetIndex to index and break.
		if voidptr(path_entry.invocation_target) == voidptr(current_target) {
			current_target_index = index
			break
		}
		// 3. If path[index]'s slot-in-closed-tree is true, then decrease currentTargetHiddenSubtreeLevel by 1.
		if path_entry.slot_in_closed_tree && current_target_hidden_subtree_level > 0 {
			current_target_hidden_subtree_level--
		}
	}

	// 11. Let currentHiddenLevel and maxHiddenLevel be currentTargetHiddenSubtreeLevel.
	mut current_hidden_level := current_target_hidden_subtree_level
	mut max_hidden_level := current_target_hidden_subtree_level

	// 12. Set index to currentTargetIndex - 1.
	// 13. While index is greater than or equal to 0:
	if current_target_index > 0 {
		for index := current_target_index - 1; index >= 0; index-- {
			path_entry := path[index]
			// 1. If path[index]'s root-of-closed-tree is true, then increase currentHiddenLevel by 1.
			if path_entry.root_of_closed_tree {
				current_hidden_level++
			}
			// 2. If currentHiddenLevel is less than or equal to maxHiddenLevel, then prepend path[index]'s invocation target to composedPath.
			if current_hidden_level <= max_hidden_level {
				composed_path.prepend(path_entry.invocation_target)
			}
			// 3. If path[index]'s slot-in-closed-tree is true, then:
			if path_entry.slot_in_closed_tree {
				if current_hidden_level > 0 {
					current_hidden_level--
				}
				if current_hidden_level < max_hidden_level {
					max_hidden_level = current_hidden_level
				}
			}
		}
	}

	// 14. Set currentHiddenLevel and maxHiddenLevel to currentTargetHiddenSubtreeLevel.
	current_hidden_level = current_target_hidden_subtree_level
	max_hidden_level = current_target_hidden_subtree_level

	// 15. Set index to currentTargetIndex + 1.
	// 16. While index is less than path's size:
	for index := current_target_index + 1; index < path.len; index++ {
		path_entry := path[index]
		// 1. If path[index]'s slot-in-closed-tree is true, then increase currentHiddenLevel by 1.
		if path_entry.slot_in_closed_tree {
			current_hidden_level++
		}
		// 2. If currentHiddenLevel is less than or equal to maxHiddenLevel, then append path[index]'s invocation target to composedPath.
		if current_hidden_level <= max_hidden_level {
			composed_path << path_entry.invocation_target
		}
		// 3. If path[index]'s root-of-closed-tree is true, then:
		if path_entry.root_of_closed_tree {
			if current_hidden_level > 0 {
				current_hidden_level--
			}
			if current_hidden_level < max_hidden_level {
				max_hidden_level = current_hidden_level
			}
		}
	}
	return composed_path
}

// https://dom.spec.whatwg.org/#dictdef-customeventinit
pub struct CustomEventInit {
	EventInit
pub mut:
	detail JSValue = JSValue{
		kind: .null_
	}
}

// https://dom.spec.whatwg.org/#customevent
@[heap]
pub struct CustomEvent {
	Event
pub mut:
	detail_ JSValue = JSValue{
		kind: .null_
	}
}

pub fn CustomEvent.create(event_name string, event_init CustomEventInit) &CustomEvent {
	return CustomEvent.new(event_name, event_init)
}

pub fn CustomEvent.construct_impl(event_name string, event_init CustomEventInit) !&CustomEvent {
	return CustomEvent.create(event_name, event_init)
}

fn CustomEvent.new(event_name string, event_init CustomEventInit) &CustomEvent {
	return &CustomEvent{
		Event:   Event{
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  current_event_timestamp()
		}
		detail_: event_init.detail
	}
}

pub fn (mut ce CustomEvent) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(CustomEvent);
	ce.Event.initialize()
}

pub fn (mut ce CustomEvent) visit_edges(mut visitor CellVisitor) {
	ce.Event.visit_edges(mut visitor)
	visitor.visit(ce.detail_.object_data)
}

// https://dom.spec.whatwg.org/#dom-customevent-detail
pub fn (ce &CustomEvent) detail() JSValue {
	return ce.detail_
}

// https://dom.spec.whatwg.org/#dom-customevent-initcustomevent
pub fn (mut ce CustomEvent) init_custom_event(type_ string, bubbles bool, cancelable bool, detail JSValue) {
	// 1. If this's dispatch flag is set, then return.
	if ce.Event.dispatched() {
		return
	}

	// 2. Initialize this with type, bubbles, and cancelable.
	ce.Event.initialize_event(type_, bubbles, cancelable)

	// 3. Set this's detail attribute to detail.
	ce.detail_ = detail
}

// NOTE: Even though these dictionaries are defined in EventTarget.idl, they are here to prevent a circular include between EventTarget.h and AbortSignal.h.
pub struct EventListenerOptions {
pub mut:
	capture bool
}

pub struct AddEventListenerOptions {
pub mut:
	capture bool
	passive ?bool
	once    bool
	signal  ?&AbortSignal
}

pub type EventListenerOptionsOrBool = EventListenerOptions | bool
pub type AddEventListenerOptionsOrBool = AddEventListenerOptions | bool

// https://dom.spec.whatwg.org/#concept-event-listener
// NOTE: The spec calls this "event listener", and it's importantly not the same as "EventListener".
@[heap]
pub struct DOMEventListener {
pub mut:
	// type (a string)
	type_ string

	// callback (null or an EventListener object)
	callback ?&IDLEventListener

	// signal (null or an AbortSignal object)
	signal ?&AbortSignal

	// capture (a boolean, initially false)
	capture bool

	// passive (null or a boolean, initially null)
	passive ?bool

	// once (a boolean, initially false)
	once bool

	// removed (a boolean for bookkeeping purposes, initially false)
	removed bool
}

pub fn DOMEventListener.new() &DOMEventListener {
	return &DOMEventListener{}
}

pub fn (mut listener DOMEventListener) visit_edges(mut visitor CellVisitor) {
	if callback := listener.callback {
		visitor.visit(callback)
	}
	if signal := listener.signal {
		visitor.visit(signal)
	}
}

@[heap]
pub struct IDLEventListener {
pub mut:
	callback_ &CallbackType = unsafe { nil }
}

pub fn IDLEventListener.create(callback &CallbackType) &IDLEventListener {
	return IDLEventListener.new(callback)
}

pub fn IDLEventListener.new(callback &CallbackType) &IDLEventListener {
	return &IDLEventListener{
		callback_: callback
	}
}

pub fn (listener &IDLEventListener) callback() &CallbackType {
	return listener.callback_
}

fn event_listener_callbacks_match(a ?&IDLEventListener, b ?&IDLEventListener) bool {
	left := a or { return b == none }
	right := b or { return false }
	left_callback := left.callback()
	right_callback := right.callback()
	if left_callback.callback_identity_ != unsafe { nil }
		|| right_callback.callback_identity_ != unsafe { nil } {
		return left_callback.callback_identity_ != unsafe { nil }
			&& left_callback.callback_identity_ == right_callback.callback_identity_
	}
	return voidptr(left_callback) == voidptr(right_callback)
}

pub fn (mut listener IDLEventListener) visit_edges(mut visitor CellVisitor) {
	visitor.visit(listener.callback_)
}

pub struct FlattenedAddEventListenerOptions {
pub mut:
	capture bool
	passive ?bool
	once    bool
	signal  ?&AbortSignal
}

pub enum EventTargetKind {
	generic
	node
	window
	abort_signal
}

pub struct EventTargetData {
pub mut:
	kind EventTargetKind
	listener_list_changed_target voidptr
	listener_list_changed_hook fn (voidptr) = unsafe { nil }

	event_listener_list []&DOMEventListener

mut:
	// https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-map
	// Most EventTargets never publish a handler. Keep the ordinary V map
	// managed separately and create it only after the first handler activates.
	handler_storage_ &EventHandlerStorage = unsafe { nil }
}

@[heap]
pub struct EventHandler_ {
pub mut:
	value    JSValue
	listener ?&DOMEventListener
}

pub fn EventTarget.construct_impl() !&EventTarget {
	// The new EventTarget() constructor steps are to do nothing.
	return &EventTarget{}
}

pub fn EventTarget.new() &EventTarget {
	return &EventTarget{}
}

pub fn (et &EventTarget) is_focusable() bool {
	node := event_target_as_node(et) or { return false }
	element := node.as_element() or { return false }
	return element.is_focusable()
}

pub fn (mut et EventTarget) initialize() {
	// FIXME: We can't do this for UniversalGlobalScopeMixin classes, as this will run when creating the initial global object.
	//        During this time, the ESO is not setup, so it will cause a nullptr dereference in host_defined_intrinsics.
	if !et.is_universal_global_scope_mixin() {
		// WEB_SET_PROTOTYPE_FOR_INTERFACE(EventTarget);
	}
}

pub fn (mut et EventTarget) visit_edges(mut visitor CellVisitor) {
	// Base::visit_edges(visitor);
	for listener in et.data.event_listener_list {
		visitor.visit(listener)
	}
	if et.data.handler_storage_ != unsafe { nil } {
		for _, handler in et.data.handler_storage_.handlers {
			visitor.visit(handler)
			if listener := handler.listener {
				visitor.visit(listener)
			}
		}
	}
}

pub fn (et &EventTarget) event_listener_list() []&DOMEventListener {
	return et.data.event_listener_list.clone()
}

// https://dom.spec.whatwg.org/#concept-flatten-options
pub fn flatten_event_listener_options(options EventListenerOptionsOrBool) bool {
	// 1. If options is a boolean, then return options.
	// 2. Return options["capture"].
	return match options {
		bool { options }
		EventListenerOptions { options.capture }
	}
}

// https://dom.spec.whatwg.org/#concept-flatten-options
pub fn flatten_add_event_listener_options_capture(options AddEventListenerOptionsOrBool) bool {
	// 1. If options is a boolean, then return options.
	// 2. Return options["capture"].
	return match options {
		bool { options }
		AddEventListenerOptions { options.capture }
	}
}

// https://dom.spec.whatwg.org/#event-flatten-more
pub fn flatten_add_event_listener_options(options AddEventListenerOptionsOrBool) FlattenedAddEventListenerOptions {
	// 1. Let capture be the result of flattening options.
	capture := flatten_add_event_listener_options_capture(options)

	// 2. Let once be false.
	mut once := false

	// 3. Let passive and signal be null.
	mut passive := ?bool(none)
	mut signal := ?&AbortSignal(none)

	// 4. If options is a dictionary, then:
	if options is AddEventListenerOptions {
		// 1. Set once to options["once"].
		once = options.once

		// 2. If options["passive"] exists, then set passive to options["passive"].
		passive = options.passive

		// 3. If options["signal"] exists, then set signal to options["signal"].
		signal = options.signal
	}

	// 5. Return capture, passive, once, and signal.
	return FlattenedAddEventListenerOptions{
		capture: capture
		passive: passive
		once:    once
		signal:  signal
	}
}

// https://dom.spec.whatwg.org/#default-passive-value
pub fn default_passive_value(type_ string, event_target &EventTarget) bool {
	// 1. Return true if all of the following are true:
	//    - type is one of "touchstart", "touchmove", "wheel", or "mousewheel".
	//    - eventTarget is a Window object, or is a node whose node document is eventTarget, or is a node whose node document's document element is eventTarget,
	//      or is a node whose node document's body element is eventTarget.
	if type_ in ['touchstart', 'touchmove', 'wheel', 'mousewheel'] {
		if event_target_as_window(event_target) != none {
			return true
		}
		node := event_target_as_node(event_target) or { return false }
		document := node.document()
		if document == unsafe { nil } {
			return false
		}
		if node == unsafe { &Node(document) } {
			return true
		}
		if document_element := document.document_element() {
			if node == document_element.as_node() {
				return true
			}
		}
		if body_element := document.body() {
			if node == html_element_as_element(body_element).as_node() {
				return true
			}
		}
	}

	// 2. Return false.
	return false
}

// https://dom.spec.whatwg.org/#dom-eventtarget-addeventlistener
pub fn (et &EventTarget) add_event_listener(type_ string, callback ?&IDLEventListener, options AddEventListenerOptionsOrBool) {
	// 1. Let capture, passive, once, and signal be the result of flattening more options.
	flattened_options := flatten_add_event_listener_options(options)

	// 2. Add an event listener with this and an event listener whose type is type, callback is callback, capture is capture, passive is passive,
	//    once is once, and signal is signal.
	event_listener := &DOMEventListener{
		type_:    type_
		callback: callback
		signal:   flattened_options.signal
		capture:  flattened_options.capture
		passive:  flattened_options.passive
		once:     flattened_options.once
	}
	et.add_an_event_listener(event_listener)
}

pub fn (et &EventTarget) add_event_listener_without_options(type_ string, callback &IDLEventListener) {
	et.add_event_listener(type_, callback, AddEventListenerOptions{})
}

// https://dom.spec.whatwg.org/#add-an-event-listener
pub fn (et &EventTarget) add_an_event_listener(listener &DOMEventListener) {
	// FIXME: 1. If eventTarget is a ServiceWorkerGlobalScope object, its service worker's script resource's has ever been evaluated flag is set,
	//           and listener's type matches the type attribute value of any of the service worker events, then report a warning to the console
	//           that this might not give the expected results. [SERVICE-WORKERS]

	// 2. If listener's signal is not null and is aborted, then return.
	if signal := listener.signal {
		if signal.aborted() {
			return
		}
	}

	// 3. If listener's callback is null, then return.
	if listener.callback == none {
		return
	}

	// 4. If listener's passive is null, then set it to the default passive value given listener's type and eventTarget.
	if listener.passive == none {
		mut mutable_listener := unsafe { &DOMEventListener(listener) }
		mutable_listener.passive = default_passive_value(listener.type_, et)
	}

	// 5. If eventTarget's event listener list does not contain an event listener whose type is listener's type, callback is listener's callback,
	//    and capture is listener's capture, then append listener to eventTarget's event listener list.
	mut target := unsafe { &EventTarget(et) }
	mut listener_already_registered := false
	for entry in target.data.event_listener_list {
		if entry.type_ == listener.type_
			&& event_listener_callbacks_match(entry.callback, listener.callback)
			&& entry.capture == listener.capture {
			listener_already_registered = true
			break
		}
	}
	if !listener_already_registered {
		target.data.event_listener_list << listener
		if node := event_target_as_node(et) {
			mut mutable_node := unsafe { &Node(node) }
			if listener.type_ !in mutable_node.event_listener_types {
				mutable_node.event_listener_types << listener.type_
			}
		}
		target.event_listener_list_changed()
	}

	// 6. If listener's signal is not null, then add the following abort steps to it:
	if signal := listener.signal {
		mut mutable_signal := unsafe { &AbortSignal(signal) }
		_ = mutable_signal.add_abort_algorithm(fn [et, listener] () {
			// 1. Remove an event listener with eventTarget and listener.
			et.remove_an_event_listener(listener)
		})
	}
}

// https://dom.spec.whatwg.org/#dom-eventtarget-removeeventlistener
pub fn (et &EventTarget) remove_event_listener(type_ string, callback ?&IDLEventListener, options EventListenerOptionsOrBool) {
	// 1. Let capture be the result of flattening options.
	capture := flatten_event_listener_options(options)

	// 2. If this's event listener list contains an event listener whose type is type, callback is callback, and capture is capture,
	//    then remove an event listener with this and that event listener.
	for listener in et.event_listener_list() {
		if listener.type_ == type_ && event_listener_callbacks_match(listener.callback, callback)
			&& listener.capture == capture {
			et.remove_an_event_listener(listener)
			return
		}
	}
}

pub fn (et &EventTarget) remove_event_listener_without_options(type_ string, callback &IDLEventListener) {
	et.remove_event_listener(type_, callback, EventListenerOptions{})
}

// https://dom.spec.whatwg.org/#remove-an-event-listener
pub fn (et &EventTarget) remove_an_event_listener(listener &DOMEventListener) {
	// FIXME: 1. If eventTarget is a ServiceWorkerGlobalScope object and its service worker's set of event types to handle contains type,
	//           then report a warning to the console that this might not give the expected results. [SERVICE-WORKERS]

	// 2. Set listener's removed to true and remove listener from eventTarget's event listener list.
	mut mutable_listener := unsafe { &DOMEventListener(listener) }
	mutable_listener.removed = true
	mut target := unsafe { &EventTarget(et) }
	for index, entry in target.data.event_listener_list {
		if entry == listener {
			target.data.event_listener_list.delete(index)
			if node := event_target_as_node(et) {
				mut has_same_type := false
				for remaining in target.data.event_listener_list {
					if remaining.type_ == listener.type_ {
						has_same_type = true
						break
					}
				}
				if !has_same_type {
					mut mutable_node := unsafe { &Node(node) }
					mutable_node.event_listener_types =
						mutable_node.event_listener_types.filter(it != listener.type_)
				}
			}
			target.event_listener_list_changed()
			return
		}
	}
}

// EventTarget.cpp invokes this virtual hook after actual listener-list changes.
// A typed callback preserves that dispatch for EventTarget subclasses outside DOM.
pub fn (et &EventTarget) event_listener_list_changed() {
	if et.data.listener_list_changed_hook != unsafe { nil } {
		et.data.listener_list_changed_hook(et.data.listener_list_changed_target)
	}
}

// https://dom.spec.whatwg.org/#dom-eventtarget-dispatchevent
pub fn (et &EventTarget) dispatch_event_binding(event &Event) !bool {
	// 1. If event's dispatch flag is set, or if its initialized flag is not set, then throw an "InvalidStateError" DOMException.
	if event.dispatched() {
		return error('InvalidStateError: The event is already being dispatched.')
	}
	if !event.initialized() {
		return error('InvalidStateError: Cannot dispatch an uninitialized event.')
	}

	// 2. Initialize event's isTrusted attribute to false.
	mut mutable_event := unsafe { &Event(event) }
	mutable_event.set_is_trusted(false)

	// 3. Return the result of dispatching event to this.
	return et.dispatch_event(event)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#window-reflecting-body-element-event-handler-set
pub fn is_window_reflecting_body_element_event_handler(name string) bool {
	return name in ['blur', 'error', 'focus', 'load', 'resize', 'scroll']
}

// https://html.spec.whatwg.org/multipage/webappapis.html#windoweventhandlers
fn is_window_event_handler(name string) bool {
	return name in ['afterprint', 'beforeprint', 'beforeunload', 'hashchange', 'languagechange',
		'message', 'messageerror', 'offline', 'online', 'pagehide', 'pageshow', 'popstate',
		'rejectionhandled', 'storage', 'unhandledrejection', 'unload']
}

// https://html.spec.whatwg.org/multipage/webappapis.html#determining-the-target-of-an-event-handler
fn determine_target_of_event_handler(event_target &EventTarget, name string) ?&EventTarget {
	// To determine the target of an event handler, given an EventTarget object eventTarget on which the event handler is exposed,
	// and an event handler name name, the following steps are taken:

	// 1. If eventTarget is not a body element or a frameset element, then return eventTarget.
	node := event_target_as_node(event_target) or { return event_target }
	element := node.as_element() or { return event_target }
	if !is_html_element_with_local_name(element, 'body')
		&& !is_html_element_with_local_name(element, 'frameset') {
		return event_target
	}
	// 2. If name is not the name of an attribute member of the WindowEventHandlers interface mixin and the Window-reflecting
	//    body element event handler set does not contain name, then return eventTarget.
	if !is_window_event_handler(name) && !is_window_reflecting_body_element_event_handler(name) {
		return event_target
	}
	// 3. If eventTarget's node document is not an active document, then return null.
	document := node.document()
	if document == unsafe { nil } || !document.is_active() {
		return none
	}
	// 4. Return eventTarget's node document's relevant global object.
	window := document.get_window() or { return none }
	return unsafe { &EventTarget(window) }
}

// https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-attributes:event-handler-idl-attributes-2
pub fn (et &EventTarget) event_handler_attribute(name string) ?&CallbackType {
	// 1. Let eventTarget be the result of determining the target of an event handler given this object and name.
	target := determine_target_of_event_handler(et, name) or { return none }

	// 2. If eventTarget is null, then return null.
	// 3. Return the result of getting the current value of the event handler given eventTarget and name.
	return target.get_current_value_of_event_handler(name)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#getting-the-current-value-of-the-event-handler
pub fn (et &EventTarget) get_current_value_of_event_handler(name string) ?&CallbackType {
	// 1. Let handlerMap be eventTarget's event handler map. (NOTE: Not necessary)
	// 2. Let eventHandler be handlerMap[name].
	// Optimization: The spec creates all the event handlers exposed on an object up front and has the initial value of the handler set to null.
	//               If the event handler hasn't been set, null would be returned in step 4.
	//               However, this would be very allocation heavy. For example, each DOM::Element includes GlobalEventHandlers, which defines 60+ event handler attributes.
	//               Plus, the vast majority of these allocations would be likely wasted, as web content will only use a handful of these attributes on certain elements.
	//               Thus, treat the event handler not being in the event handler map as equivalent to an event handler with an initial null value.
	handler := et.data.event_handler(name) or { return none }
	// 3. If eventHandler's value is an internal raw uncompiled handler, then compile it.
	if handler.value.kind == .string {
		document := inline_event_handler_document(et) or { return none }
		// Source returns before changing the raw value when scripting is disabled.
		if unsafe { &Node(document) }.is_scripting_disabled() { return none }
		compiler := document.inline_event_handler_compiler_ or { return none }
		if supports := compiler.supports_handler {
			if !supports(et, name) { return none }
		}
		// An unavailable owner/environment is an explicit port boundary. Preserve
		// the raw value for an actual compiler; never fabricate a callable.
		if !compiler.can_compile(et) { return none }
		if available := compiler.can_compile_handler {
			if !available(et, name) { return none }
		}
		callback := compiler.compile(et, name, handler.value.string_data,
			inline_event_handler_function_source(et, name, handler.value.string_data)) or {
			// Source parse/early-error failure nulls the value while retaining this
			// handler and its activated listener. Syntax reporting is a source FIXME.
			mut mutable_handler := unsafe { &EventHandler_(handler) }
			mutable_handler.value = js_null()
			return none
		}
		mut mutable_handler := unsafe { &EventHandler_(handler) }
		mutable_handler.value = js_object(callback)
		return callback
	}

	// 4. Return eventHandler's value.
	if handler.value.kind == .object && handler.value.object_data != unsafe { nil } {
		return unsafe { &CallbackType(handler.value.object_data) }
	}
	return none
}

fn inline_event_handler_document(event_target &EventTarget) ?&Document {
	// 1. If eventTarget is an element, then let element be eventTarget, and document be element's node document.
	//    Otherwise, eventTarget is a Window object, let element be null, and document be eventTarget's associated Document.
	mut document := ?&Document(none)
	if node := event_target_as_node(event_target) {
		if element := node.as_element() {
			_ = element
			document = node.document()
		}
	} else if window := event_target_as_window(event_target) {
		document = window.associated_document()
	}
	return document
}

fn inline_event_handler_function_source(event_target &EventTarget, name string, body string) string {
	if name == 'error' && event_target_as_window(event_target) != none {
		return 'function on${name}(event, source, lineno, colno, error) {\n${body}\n}'
	}
	return 'function on${name}(event) {\n${body}\n}'
}

// https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-attributes:event-handler-idl-attributes-3
pub fn (et &EventTarget) set_event_handler_attribute(name string, value ?&CallbackType) {
	// 1. Let eventTarget be the result of determining the target of an event handler given this object and name.
	event_target := determine_target_of_event_handler(et, name) or { return }

	// 2. If eventTarget is null, then return.
	// 3. If the given value is null, then deactivate an event handler given eventTarget and name.
	// Unwrap explicitly: current V passes the address of a none-checked option's
	// payload, not the payload, to a voidptr parameter.
	callback := value or {
		event_target.deactivate_event_handler(name)
		return
	}

	// 4. Otherwise:
	mut target := unsafe { &EventTarget(event_target) }
	if mut handler := target.data.event_handler(name) {
		handler.value = js_object(callback)
		event_target.activate_event_handler(name, handler)
		return
	}

	handler := &EventHandler_{
		value: js_object(callback)
	}
	event_target.activate_event_handler(name, handler)
	target.data.store_event_handler(name, handler)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#activate-an-event-handler
pub fn (et &EventTarget) activate_event_handler(name string, event_handler &EventHandler_) {
	// 1. Let handlerMap be eventTarget's event handler map.
	// 2. Let eventHandler be handlerMap[name].
	// Upstream's optimization uses the actual passed-in EventHandler identity.
	// 3. If eventHandler's listener is not null, then return.
	mut handler := unsafe { &EventHandler_(event_handler) }
	if handler.listener != none {
		return
	}

	// 4. Let callback be the result of creating a Web IDL EventListener instance representing a reference to a function of one argument
	// that executes the steps of the event handler processing algorithm, given eventTarget, name, and its argument.
	// 5. Let listener be a new event listener whose type is the event handler event type corresponding to eventHandler and callback is callback.
	// 6. Add an event listener with eventTarget and listener.
	// 7. Set eventHandler's listener to listener.
	event_target := unsafe { &EventTarget(et) }
	mut listener_window := event_target_relevant_window(event_target)
	mut report_exception := ?EventCallbackExceptionReporter(none)
	// event_handler_listener_realm first uses the handler callback's Realm.
	// Keep that Realm on the existing listener when its handler is replaced.
	if handler.value.kind == .object && handler.value.object_data != unsafe { nil } {
		handler_callback := unsafe { &CallbackType(handler.value.object_data) }
		listener_window = handler_callback.associated_window
		report_exception = handler_callback.report_exception
	} else if document := inline_event_handler_document(event_target) {
		// The activation callback belongs to this original relevant Realm even
		// when the engine binding arrives after parser-created raw attributes.
		report_exception = fn [document] (exception IError) {
			document.report_event_callback_exception(exception)
		}
	}
	mut callback := &CallbackType{
		associated_window: listener_window
		handle_event_with_exception: fn [event_target, name] (event &Event, current_target ?&EventTarget) !JSValue {
			_ = current_target
			event_target.process_event_handler_for_event(name, event)!
			return js_undefined()
		}
	}
	callback.report_exception = report_exception
	listener := &DOMEventListener{
		type_:    name
		callback: IDLEventListener.new(callback)
	}
	et.add_an_event_listener(listener)
	handler.listener = listener
}

pub fn (et &EventTarget) deactivate_event_handler(name string) {
	// 1. Let handlerMap be eventTarget's event handler map.
	// 2. Let eventHandler be handlerMap[name].
	// 3. Set eventHandler's value to null.
	// 4. Let listener be eventHandler's listener.
	// 5. If listener is not null, then remove an event listener with eventTarget and listener.
	// 6. Set eventHandler's listener to null.
	mut target := unsafe { &EventTarget(et) }
	mut handler := target.data.event_handler(name) or { return }
	handler.value = js_null()
	if listener := handler.listener {
		et.remove_an_event_listener(listener)
	}
	handler.listener = none
	target.data.remove_event_handler(name)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#the-event-handler-processing-algorithm
pub fn (et &EventTarget) process_event_handler_for_event(name string, event &Event) ! {
	// 1. Let callback be the result of getting the current value of the event handler given eventTarget and name.
	callback := et.get_current_value_of_event_handler(name) or { return }
	// Adapter bookkeeping precedes invocation, including abrupt completions and
	// self-mutation. Raw handlers without a supported compiler are not processed.
	if name == 'click' && event.type_ == 'click' {
		mut mutable_event := unsafe { &Event(event) }
		mutable_event.note_processed_click_handler(et)
	}

	// 2. If callback is null, then return.

	// 3. Let special error event handling be true if event is an ErrorEvent object, event's type is error, and event's currentTarget implements the WindowOrWorkerGlobalScope mixin.
	special_error_event_handling := event_uses_special_error_event_handling(event)

	// 4. Process the Event object event by invoking the callback.
	mut return_value := js_undefined()
	if handle_event := callback.handle_event_with_exception {
		return_value = handle_event(event, event.current_target())!
	} else if handle_event := callback.handle_event {
		return_value = handle_event(event, event.current_target())
	}

	is_beforeunload := event.type_ == 'beforeunload'

	// 5. Process return value as follows.
	if event_is_before_unload_event(event) && is_beforeunload {
		// If event is a BeforeUnloadEvent object and event's type is "beforeunload", if return value is not null, then:
		if !return_value.is_nullish() {
			mut mutable_event := unsafe { &Event(event) }
			mutable_event.set_cancelled(true)
			// If returnValue is still empty, convert and retain the callback's return value.
			mut before_unload_event := unsafe { &BeforeUnloadEvent(event) }
			if before_unload_event.return_value().len == 0 {
				before_unload_event.set_return_value(webidl.to_string(return_value.as_webidl_value()!)!)
			}
		}
	}

	if special_error_event_handling {
		// If special error event handling is true, if return value is true, then set event's canceled flag.
		if return_value.is_boolean() && return_value.as_bool() {
			mut mutable_event := unsafe { &Event(event) }
			mutable_event.set_cancelled(true)
		}
	} else {
		// Otherwise, if return value is false, then set event's canceled flag.
		if return_value.is_boolean() && !return_value.as_bool() && !is_beforeunload {
			mut mutable_event := unsafe { &Event(event) }
			mutable_event.set_cancelled(true)
		}
	}
}

// EventTarget::process_event_handler_for_event and Bindings::invoke_event_handler
// share this source predicate. Ordinary listeners always receive one Event.
pub fn event_uses_special_error_event_handling(event &Event) bool {
	return event_is_error_event(event) && event.type_ == 'error' && if current_target := event.current_target() {
		event_target_as_window(current_target) != none
	} else {
		false
	}
}

fn event_is_error_event(event &Event) bool {
	return event.interface_ == .error_event
}

fn event_is_before_unload_event(event &Event) bool {
	return event.interface_ == .before_unload_event
}

fn event_is_mouse_event(event &Event) bool {
	// is<UIEvents::MouseEvent> is true for MouseEvent and its subclass PointerEvent.
	return event.interface_ == .mouse_event || event.interface_ == .pointer_event
}

fn event_is_keyboard_event(event &Event) bool {
	return event.interface_ == .keyboard_event
}

fn keyboard_event_key_code_is_escape(event &Event) bool {
	if event.interface_ != .keyboard_event {
		return false
	}
	keyboard_event := unsafe { &KeyboardEvent(event) }
	return keyboard_event.key_code_ == key_code_escape
}

fn event_is_pointer_event(event &Event) bool {
	return event.interface_ == .pointer_event
}

fn pointer_event_pointer_type(event &Event) string {
	if event.interface_ != .pointer_event {
		return ''
	}
	pointer_event := unsafe { &PointerEvent(event) }
	return pointer_event.pointer_type_
}

fn should_inline_script_attribute_be_blocked_by_content_security_policy(element &Element, value string) bool {
	return element.document().should_block_inline_content(element, 'script-attribute', value)
}

// https://html.spec.whatwg.org/multipage/webappapis.html#event-handler-attributes:concept-element-attributes-change-ext
pub fn (et &EventTarget) element_event_handler_attribute_changed(local_name string, value ?string) {
	// NOTE: Step 1 of this algorithm was handled in HTMLElement::attribute_changed.
	if node := event_target_as_node(et) {
		if !node.document().is_scripting_enabled_by_embedder() { return }
	}

	event_name := event_name_from_event_handler_attribute_local_name(local_name) or { return }

	// 2. Let eventTarget be the result of determining the target of an event handler given element and localName.
	event_target := determine_target_of_event_handler(et, event_name) or { return }

	// 3. If eventTarget is null, then return.
	// 4. If value is null, then deactivate an event handler given eventTarget and localName.
	if value == none {
		event_target.deactivate_event_handler(event_name)
		return
	}

	// 5. Otherwise:
	//  1. If the Should element's inline behavior be blocked by Content Security Policy? algorithm returns "Blocked" when executed upon element,
	//     "script attribute", and value, then return. [CSP]
	script_attribute := value
	if node := event_target_as_node(et) {
		if element := node.as_element() {
			if should_inline_script_attribute_be_blocked_by_content_security_policy(element,
				script_attribute)
			{
				return
			}
		}
	}
	//  2. Let handlerMap be eventTarget's event handler map.
	//  3. Let eventHandler be handlerMap[localName].
	//  4. Let location be the script location that triggered the execution of these steps.
	//  5. Set eventHandler's value to the internal raw uncompiled handler value/location.
	//  6. Activate an event handler given eventTarget and name.
	mut target := unsafe { &EventTarget(event_target) }
	if mut handler := target.data.event_handler(event_name) {
		handler.value = js_string(script_attribute)
		event_target.activate_event_handler(event_name, handler)
		return
	}
	handler := &EventHandler_{
		value: js_string(script_attribute)
	}
	event_target.activate_event_handler(event_name, handler)
	target.data.store_event_handler(event_name, handler)
}

// document.v already defines EventTarget.dispatch_event(event &Event) bool. This helper carries the translated EventTarget.cpp dispatch body
// without redefining that existing method from outside the assigned write set.
pub fn event_target_dispatch_event(target &EventTarget, event &Event) bool {
	// Window.cpp overrides this virtual method: its associated Document is the
	// legacy target override, and EventTarget's activation path is bypassed.
	if event_target_as_window(target) != none {
		return EventDispatcher.dispatch(target, event, true)
	}
	// https://html.spec.whatwg.org/multipage/interaction.html#activation-triggering-input-event
	// https://html.spec.whatwg.org/multipage/interaction.html#user-activation-processing-model
	if is_activation_triggering_input_event(event) {
		if mut window := event_target_relevant_window(target) {
			current_time := current_high_resolution_time(window)
			window.set_last_activation_timestamp(current_time)
			window.close_watcher_manager().notify_about_user_activation()
		}
	}
	return EventDispatcher.dispatch(target, event, false)
}

fn is_activation_triggering_input_event(event &Event) bool {
	// An activation triggering input event is any event whose isTrusted attribute is true and whose type is one of:
	if !event.is_trusted() {
		return false
	}

	// keydown, provided the key is neither the Esc key nor a shortcut key reserved by the user agent.
	if event.type_ == 'keydown' {
		if event_is_keyboard_event(event) {
			return !keyboard_event_key_code_is_escape(event)
		}
		return false
	}

	// mousedown.
	if event.type_ == 'mousedown' {
		return true
	}

	// pointerdown, provided the event's pointerType is "mouse".
	if event.type_ == 'pointerdown' {
		if event_is_pointer_event(event) {
			return pointer_event_pointer_type(event) == 'mouse'
		}
		return false
	}

	// pointerup, provided the event's pointerType is not "mouse".
	if event.type_ == 'pointerup' {
		if event_is_pointer_event(event) {
			return pointer_event_pointer_type(event) != 'mouse'
		}
		return false
	}

	// FIXME: touchend
	return false
}

fn event_target_relevant_window(target &EventTarget) ?&Window {
	if window := event_target_as_window(target) {
		return window
	}
	if node := event_target_as_node(target) {
		document := node.document()
		if document != unsafe { nil } {
			return document.get_window()
		}
	}
	return none
}

fn event_listener_callback_global_window(listener &DOMEventListener) ?&Window {
	// C++ obtains this from listener.callback.callback's associated Realm. The
	// WebIDL bridge stores that Realm's Window directly on CallbackType; it must
	// not be inferred from currentTarget because callbacks can cross realms.
	callback := listener.callback or { return none }
	return callback.callback().associated_window
}

pub fn (et &EventTarget) has_event_listener(type_ string) bool {
	for listener in et.data.event_listener_list {
		if listener.type_ == type_ {
			return true
		}
	}
	return false
}

pub fn (et &EventTarget) has_event_listeners() bool {
	return et.data.event_listener_list.len > 0
}

// HTMLAnchorElement, HTMLAreaElement, and SVGAElement override activation behavior with activating the hyperlink,
// which upstream implements on DOM::Element.
fn event_target_hyperlink_element(et &EventTarget) ?&Element {
	node := event_target_as_node(et) or { return none }
	element := node.as_element() or { return none }
	if is_html_element_with_local_name(element, 'a') || is_html_element_with_local_name(element, 'area')
		|| (element.is_svg_element() && element.local_name() == 'a') {
		return element
	}
	return none
}

// HTML's form and interactive elements (button, input, label, select, summary) override activation behavior. DOM
// cannot import HTML, so HTML installs those element overrides here.
pub struct ElementActivationBehaviorHooks {
pub:
	has_activation_behavior                             fn (&Element) bool = unsafe { nil }
	activation_behavior                                 fn (&Element, &Event) = unsafe { nil }
	legacy_pre_activation_behavior                      fn (&Element) = unsafe { nil }
	legacy_cancelled_activation_behavior                fn (&Element) = unsafe { nil }
	legacy_cancelled_activation_behavior_was_not_called fn (&Element) = unsafe { nil }
}

pub fn install_element_activation_behavior_hooks(hooks ElementActivationBehaviorHooks) {
	dom_element_activation_behavior_hooks = hooks
}

fn event_target_element(et &EventTarget) ?&Element {
	node := event_target_as_node(et) or { return none }
	return node.as_element()
}

pub fn (et &EventTarget) has_activation_behavior() bool {
	if element := event_target_hyperlink_element(et) {
		// SVGAElement always has activation behavior; HTMLAnchorElement and HTMLAreaElement have it when they create a
		// hyperlink.
		return element.is_svg_element() || element.creates_a_hyperlink()
	}
	element := event_target_element(et) or { return false }
	hook := dom_element_activation_behavior_hooks.has_activation_behavior
	if hook == unsafe { nil } {
		return false
	}
	return hook(element)
}

pub fn (et &EventTarget) activation_behavior(event &Event) {
	if element := event_target_hyperlink_element(et) {
		mut mutable_element := unsafe { &Element(element) }
		mutable_element.activate_the_hyperlink(event)
		return
	}
	element := event_target_element(et) or { return }
	hook := dom_element_activation_behavior_hooks.activation_behavior
	if hook != unsafe { nil } {
		hook(element, event)
	}
}

// NOTE: These only exist for checkbox and radio input elements.
pub fn (et &EventTarget) legacy_pre_activation_behavior() {
	element := event_target_element(et) or { return }
	hook := dom_element_activation_behavior_hooks.legacy_pre_activation_behavior
	if hook != unsafe { nil } {
		hook(element)
	}
}

pub fn (et &EventTarget) legacy_cancelled_activation_behavior() {
	element := event_target_element(et) or { return }
	hook := dom_element_activation_behavior_hooks.legacy_cancelled_activation_behavior
	if hook != unsafe { nil } {
		hook(element)
	}
}

pub fn (et &EventTarget) legacy_cancelled_activation_behavior_was_not_called() {
	element := event_target_element(et) or { return }
	hook := dom_element_activation_behavior_hooks.legacy_cancelled_activation_behavior_was_not_called
	if hook != unsafe { nil } {
		hook(element)
	}
}

pub fn (et &EventTarget) is_universal_global_scope_mixin() bool {
	_ = et
	return false
}

fn (et &EventTarget) ensure_data() &EventTargetData {
	mut target := unsafe { &EventTarget(et) }
	return &target.data
}

pub struct EventDispatcher {}

pub struct LegacyListenerExceptionFlag {
pub mut:
	did_listeners_throw bool
}

// https://dom.spec.whatwg.org/#concept-event-listener-inner-invoke
pub fn EventDispatcher.inner_invoke(event &Event, listeners []&DOMEventListener, phase EventPhase, invocation_target_in_shadow_tree bool, mut legacy_output LegacyListenerExceptionFlag) bool {
	// 1. Let found be false.
	mut found := false

	// 2. For each listener of listeners, whose removed is false:
	for listener in listeners {
		if listener.removed {
			continue
		}

		// 1. If event's type attribute value is not listener's type, then continue.
		if event.type_ != listener.type_ {
			continue
		}

		// 2. Set found to true.
		found = true

		// 3. If phase is "capturing" and listener's capture is false, then continue.
		if phase == .capturing_phase && !listener.capture {
			continue
		}

		// 4. If phase is "bubbling" and listener's capture is true, then continue.
		if phase == .bubbling_phase && listener.capture {
			continue
		}

		// 5. If listener's once is true, then remove an event listener given event's currentTarget attribute value and listener.
		if listener.once {
			if current_target := event.current_target() {
				current_target.remove_an_event_listener(listener)
			}
		}

		// 6. Let global be listener callback's associated Realm's global object.
		listener_global_window := event_listener_callback_global_window(listener)

		// 7. Let currentEvent be undefined.
		mut current_event := ?&Event(none)

		// 8. If global is a Window object, then:
		if global_window := listener_global_window {
			mut mutable_global_window := unsafe { &Window(global_window) }

			// 1. Set currentEvent to global's current event.
			current_event = mutable_global_window.current_event()

			// 2. If invocationTargetInShadowTree is false, then set global's current event to event.
			if !invocation_target_in_shadow_tree {
				mutable_global_window.set_current_event(event)
			}
		}

		// 9. If listener's passive is true, then set event's in passive listener flag.
		mut mutable_event := unsafe { &Event(event) }
		if listener.passive or { false } {
			mutable_event.set_in_passive_listener(true)
		}
		// 10. If global is a Window object, then record timing info for event listener given event and listener.
		// 11. Call a user object's operation with listener's callback, "handleEvent", event, and event's currentTarget attribute value.
		if idle_listener := listener.callback {
			callback := idle_listener.callback()
			if handle_event := callback.handle_event_with_exception {
				handle_event(event, event.current_target_for_bindings()) or {
					if report_exception := callback.report_exception { report_exception(err) }
					legacy_output.did_listeners_throw = true
				}
			} else if handle_event := callback.handle_event {
				_ = handle_event(event, event.current_target_for_bindings())
			}
		} else {
			legacy_output.did_listeners_throw = false
		}

		// 12. Unset event's in passive listener flag.
		mutable_event.set_in_passive_listener(false)
		// 13. If global is a Window object, then restore global's current event.
		if global_window := listener_global_window {
			mut mutable_global_window := unsafe { &Window(global_window) }
			mutable_global_window.set_current_event(current_event)
		}

		// 14. If event's stop immediate propagation flag is set, then break.
		if event.should_stop_immediate_propagation() {
			break
		}
	}

	// 3. Return found.
	return found
}

// https://dom.spec.whatwg.org/#concept-event-listener-invoke
pub fn EventDispatcher.invoke(struct_ EventPathEntry, event &Event, phase EventPhase, mut legacy_output LegacyListenerExceptionFlag) {
	// 1. Set event's target to the shadow-adjusted target of the last struct in event's path,
	// that is either struct or preceding struct, whose shadow-adjusted target is non-null.
	// 2. Set event's relatedTarget to struct's relatedTarget.
	// 3. Set event's touch target list to struct's touch target list.
	mut mutable_event := unsafe { &Event(event) }
	mut last_valid_shadow_adjusted_target := ?&EventTarget(none)
	for entry in event.path() {
		if entry.index <= struct_.index {
			if shadow_adjusted_target := entry.shadow_adjusted_target {
				last_valid_shadow_adjusted_target = unsafe { &EventTarget(shadow_adjusted_target) }
			}
		}
	}
	if shadow_adjusted_target := last_valid_shadow_adjusted_target {
		mutable_event.set_target(shadow_adjusted_target)
	}
	mutable_event.set_related_target(struct_.related_target)
	mutable_event.set_touch_target_list(struct_.touch_target_list)
	// 4. If event's stop propagation flag is set, then return.
	if event.should_stop_propagation() {
		return
	}

	// 5. Initialize event's currentTarget attribute to struct's invocation target.
	mutable_event.set_current_target(struct_.invocation_target)
	// 6. Let listeners be a clone of event's currentTarget attribute value's event listener list.
	listeners := struct_.invocation_target.event_listener_list()

	// 7. Let invocationTargetInShadowTree be struct's invocation-target-in-shadow-tree.
	invocation_target_in_shadow_tree := struct_.invocation_target_in_shadow_tree

	// 8. Let found be the result of running inner invoke with event, listeners, phase, invocationTargetInShadowTree,
	// and legacyOutputDidListenersThrowFlag if given.
	found := EventDispatcher.inner_invoke(event, listeners, phase,
		invocation_target_in_shadow_tree, mut legacy_output)

	// 9. If found is false and event's isTrusted attribute is true, then run the legacy prefixed animation/transition fallback.
	if !found && event.is_trusted() {
		// 1. Let originalEventType be event's type attribute value.
		original_event_type := event.type_name()

		// 2. If event's type attribute value is a match for any of the strings in the first column in the following table,
		//    set event's type attribute value to the string in the second column on the same row as the matching string, and return otherwise.
		prefixed_event_type := legacy_prefixed_animation_or_transition_event_type(original_event_type) or {
			return
		}
		mutable_event.set_type(prefixed_event_type)

		// 3. Inner invoke with event, listeners, phase, invocationTargetInShadowTree, and legacyOutputDidListenersThrowFlag if given.
		EventDispatcher.inner_invoke(event, listeners, phase, invocation_target_in_shadow_tree, mut
			legacy_output)

		// 4. Set event's type attribute value to originalEventType.
		mutable_event.set_type(original_event_type)
	}
}

fn legacy_prefixed_animation_or_transition_event_type(type_ string) ?string {
	return match type_ {
		'animationend' { 'webkitAnimationEnd' }
		'animationiteration' { 'webkitAnimationIteration' }
		'animationstart' { 'webkitAnimationStart' }
		'transitionend' { 'webkitTransitionEnd' }
		else { none }
	}
}

// https://dom.spec.whatwg.org/#concept-event-dispatch
pub fn EventDispatcher.dispatch(target &EventTarget, event &Event, legacy_target_override bool) bool {
	mut legacy_output := LegacyListenerExceptionFlag{}
	return EventDispatcher.dispatch_with_legacy_output(target, event, legacy_target_override, mut
		legacy_output)
}

// https://dom.spec.whatwg.org/#concept-event-dispatch
pub fn EventDispatcher.dispatch_with_legacy_output(target &EventTarget, event &Event, legacy_target_override bool, mut legacy_output LegacyListenerExceptionFlag) bool {
	// 1. Set event's dispatch flag.
	mut mutable_event := unsafe { &Event(event) }
	mutable_event.reset_click_handler_replay_receipt()
	mutable_event.set_dispatched(true)
	// 2. Let targetOverride be target, if legacy target override flag is not given, and target's associated Document otherwise. [HTML]
	mut target_override := ?&EventTarget(none)
	if !legacy_target_override {
		target_override = unsafe { &EventTarget(target) }
	} else {
		window := unsafe { &Window(target) }
		if document := window.associated_document() {
			target_override = unsafe { &EventTarget(document) }
		}
	}

	// 3. Let activationTarget be null.
	mut activation_target := ?&EventTarget(none)
	// 4. Let relatedTarget be the result of retargeting event's relatedTarget against target.
	mut related_target := retarget(event.related_target(), target)

	// 5. Let clearTargets be false.
	mut clear_targets := false

	// OPTIMIZATION: Only dispatch events if there is at least one listener on the node or its ancestors. Activation
	//               events are always dispatched. This saves us from going through the path building and dispatch
	//               phases for events that will be dropped on the floor anyway.
	is_activation_event := event_is_mouse_event(event) && event.type_ == 'click'
	mut should_dispatch := is_activation_event
	if !should_dispatch {
		should_dispatch = should_dispatch_non_activation_event(target, event.type_)
		if !should_dispatch && event.is_trusted() {
			if legacy_event_type := legacy_prefixed_animation_or_transition_event_type(event.type_) {
				should_dispatch = should_dispatch_non_activation_event(target, legacy_event_type)
			}
		}
	}

	// 6. If target is not relatedTarget or target is event's relatedTarget, then:
	related_target_is_target := if rt := related_target { rt == target } else { false }
	event_related_target_is_target := if event_related_target := event.related_target() {
		event_related_target == target
	} else {
		false
	}
	if should_dispatch && (!related_target_is_target || event_related_target_is_target) {
		// 1. Let touchTargets be a new list.
		mut touch_targets := TouchTargetList{}

		// 2. For each touchTarget of event's touch target list, append the result of retargeting touchTarget against target to touchTargets.
		for touch_target in event.touch_target_list() {
			if retargeted := retarget(touch_target, target) {
				touch_targets << retargeted
			}
		}

		// 3. Append to an event path with event, target, targetOverride, relatedTarget, touchTargets, and false.
		mutable_event.append_to_path(target, target_override, related_target, touch_targets, false)

		// 4. Let isActivationEvent be true, if event is a MouseEvent object and event's type attribute is "click"; otherwise false.
		// 5. If isActivationEvent is true and target has activation behavior, then set activationTarget to target.
		if is_activation_event && target.has_activation_behavior() {
			activation_target = unsafe { &EventTarget(target) }
		}
		// 6. Let slottable be target, if target is a slottable and is assigned, and null otherwise.
		mut slottable := ?&EventTarget(none)
		if target_node := event_target_as_node(target) {
			if is_an_assigned_slottable(target_node) {
				slottable = unsafe { &EventTarget(target) }
			}
		}
		// 7. Let slot-in-closed-tree be false.
		mut slot_in_closed_tree := false
		// 8. Let parent be the result of invoking target's get the parent with event.
		mut current_target := unsafe { &EventTarget(target) }
		mut parent := event_target_get_parent(current_target, event)
		// 9. While parent is non-null, append parent entries to the event path.
		for parent != none {
			parent_target := parent or { break }
			if slottable != none {
				slottable = none
				if parent_node := event_target_as_node(parent_target) {
					if parent_shadow_root := parent_node.root().as_shadow_root() {
						if parent_shadow_root.mode == .closed {
							slot_in_closed_tree = true
						}
					}
				}
			}
			if parent_node := event_target_as_node(parent_target) {
				if is_an_assigned_slottable(parent_node) {
					slottable = unsafe { &EventTarget(parent_target) }
				}
			}
			related_target = retarget(event.related_target(), parent_target)
			touch_targets.clear()
			for touch_target in event.touch_target_list() {
				if retargeted := retarget(touch_target, parent_target) {
					touch_targets << retargeted
				}
			}

			mut parent_is_in_current_target_root := event_target_as_window(parent_target) != none
			if current_target_node := event_target_as_node(current_target) {
				if parent_node := event_target_as_node(parent_target) {
					parent_is_in_current_target_root =
						current_target_node.root().is_shadow_including_inclusive_ancestor_of(parent_node)
				}
			}
			mut related_target_is_parent := false
			if retargeted_related_target := related_target {
				related_target_is_parent = retargeted_related_target == parent_target
			}
			if parent_is_in_current_target_root {
				if is_activation_event && event.bubbles() && activation_target == none
					&& parent_target.has_activation_behavior() {
					activation_target = unsafe { &EventTarget(parent_target) }
				}
				mutable_event.append_to_path(parent_target, none, related_target, touch_targets,
					slot_in_closed_tree)
			} else if related_target_is_parent {
				parent = none
			} else {
				current_target = unsafe { &EventTarget(parent_target) }
				if is_activation_event && activation_target == none
					&& current_target.has_activation_behavior() {
					activation_target = current_target
				}
				mutable_event.append_to_path(parent_target, current_target, related_target,
					touch_targets, slot_in_closed_tree)
			}

			if parent != none {
				parent = event_target_get_parent(parent_target, event)
			}
			slot_in_closed_tree = false
		}
		// 10. Let clearTargetsStruct be the last struct in event's path whose shadow-adjusted target is non-null.
		// 11. If clearTargetsStruct's shadow-adjusted target, relatedTarget, or touch target list is in a shadow root, set clearTargets to true.
		mut clear_targets_struct := EventPathEntry{}
		mut has_clear_targets_struct := false
		for entry in event.path() {
			if entry.shadow_adjusted_target != none {
				clear_targets_struct = entry
				has_clear_targets_struct = true
			}
		}
		if has_clear_targets_struct {
			if target_to_check := clear_targets_struct.shadow_adjusted_target {
				clear_targets = event_target_is_node_whose_root_is_shadow_root(target_to_check)
			}
			if !clear_targets {
				if related_target_to_check := clear_targets_struct.related_target {
					clear_targets =
						event_target_is_node_whose_root_is_shadow_root(related_target_to_check)
				}
			}
			if !clear_targets {
				for touch_target in clear_targets_struct.touch_target_list {
					if event_target_is_node_whose_root_is_shadow_root(touch_target) {
						clear_targets = true
						break
					}
				}
			}
		}

		// 12. If activationTarget is non-null and activationTarget has legacy-pre-activation behavior, then run it.
		if activation := activation_target {
			activation.legacy_pre_activation_behavior()
		}
		// 13. For each struct of event's path, in reverse order:
		path := event.path()
		for index := path.len - 1; index >= 0; index-- {
			// 1. If struct's shadow-adjusted target is non-null, then set event's eventPhase attribute to AT_TARGET.
			if path[index].shadow_adjusted_target != none {
				mutable_event.set_phase(.at_target)
			} else {
				// 2. Otherwise, set event's eventPhase attribute to CAPTURING_PHASE.
				mutable_event.set_phase(.capturing_phase)
			}

			// 3. Invoke with struct, event, "capturing", and legacyOutputDidListenersThrowFlag if given.
			EventDispatcher.invoke(path[index], event, .capturing_phase, mut legacy_output)
		}

		// 14. For each struct of event's path:
		for path_entry in path {
			// 1. If struct's shadow-adjusted target is non-null, then set event's eventPhase attribute to AT_TARGET.
			if path_entry.shadow_adjusted_target != none {
				mutable_event.set_phase(.at_target)
			} else {
				// 2. Otherwise:
				// 1. If event's bubbles attribute is false, then continue.
				if !event.bubbles() {
					continue
				}

				// 2. Set event's eventPhase attribute to BUBBLING_PHASE.
				mutable_event.set_phase(.bubbling_phase)
			}

			// 3. Invoke with struct, event, "bubbling", and legacyOutputDidListenersThrowFlag if given.
			EventDispatcher.invoke(path_entry, event, .bubbling_phase, mut legacy_output)
		}
	}

	// 7. Set event's eventPhase attribute to NONE.
	// 8. Set event's currentTarget attribute to null.
	// 9. Set event's path to the empty list.
	// 10. Unset event's dispatch flag, stop propagation flag, and stop immediate propagation flag.
	mutable_event.set_phase(.none)
	mutable_event.set_current_target(none)
	mutable_event.clear_path()
	mutable_event.set_dispatched(false)
	mutable_event.set_stop_propagation(false)
	mutable_event.set_stop_immediate_propagation(false)

	// 11. If clearTargets, then:
	if clear_targets {
		// 1. Set event's target to null.
		// 2. Set event's relatedTarget to null.
		// 3. Set event's touch target list to the empty list.
		mutable_event.set_target(none)
		mutable_event.set_related_target(none)
		mutable_event.clear_touch_target_list()
	}

	// 12. If activationTarget is non-null, then run activation or legacy canceled activation behavior.
	if activation := activation_target {
		if !event.cancelled() {
			activation.activation_behavior(event)
			activation.legacy_cancelled_activation_behavior_was_not_called()
		} else {
			activation.legacy_cancelled_activation_behavior()
		}
	}
	// 13. Return false if event's canceled flag is set; otherwise true.
	return !event.cancelled()
}

fn should_dispatch_non_activation_event(target &EventTarget, type_ string) bool {
	// C++: should_dispatch = !node || node->has_inclusive_ancestor_with_event_listener(event.type()).
	if event_target_as_node(target) == none {
		return true
	}
	return event_target_or_ancestor_has_event_listener(target, type_)
}

fn event_target_or_ancestor_has_event_listener(target &EventTarget, type_ string) bool {
	if target.has_event_listener(type_) {
		return true
	}
	node := event_target_as_node(target) or { return false }
	for ancestor := node.parent_or_shadow_host(); ancestor != none; {
		current := ancestor or { break }
		if unsafe { &EventTarget(current) }.has_event_listener(type_) {
			return true
		}
		ancestor = current.parent_or_shadow_host()
	}
	document := node.document()
	if document != unsafe { nil } && document.window != unsafe { nil } {
		if unsafe { &EventTarget(document.window) }.has_event_listener(type_) {
			return true
		}
	}
	return false
}

fn event_target_get_parent(target &EventTarget, event &Event) ?&EventTarget {
	if event_target_as_window(target) != none {
		return none
	}
	node := event_target_as_node(target) or { return none }
	if shadow_root := node.as_shadow_root() {
		return shadow_root.get_parent(event)
	}
	if node.is_document() {
		document := unsafe { &Document(node) }
		if window := document.get_parent(event) {
			return unsafe { &EventTarget(window) }
		}
		return none
	}
	return node.get_parent(event)
}

fn event_target_is_node_whose_root_is_shadow_root(target &EventTarget) bool {
	node := event_target_as_node(target) or { return false }
	return node.root().as_shadow_root() != none
}

pub fn retarget(target ?&EventTarget, against &EventTarget) ?&EventTarget {
	// To retarget an object A against an object B, repeat these steps until they return an object:
	target_event := target or { return none }
	mut a := unsafe { &EventTarget(target_event) }
	for {
		// 1. If A is not a node, then return A.
		a_node := event_target_as_node(a) or { return a }

		// If A's root is not a shadow root, then return A.
		a_root := a_node.root()
		a_shadow_root := a_root.as_shadow_root() or { return a }

		// If B is a node and A's root is a shadow-including inclusive ancestor of B, then return A.
		if b_node := event_target_as_node(against) {
			if a_root.is_shadow_including_inclusive_ancestor_of(b_node) {
				return a
			}
		}

		// 2. Set A to A's root's host.
		host := a_shadow_root.host() or { return a }
		a = unsafe { &EventTarget(host.as_node()) }
	}
	return a
}

fn event_target_as_node(target &EventTarget) ?&Node {
	if target.data.kind != .node {
		return none
	}
	return unsafe { &Node(target) }
}

fn event_target_as_window(target &EventTarget) ?&Window {
	if target.data.kind != .window {
		return none
	}
	return unsafe { &Window(target) }
}

pub fn is_an_assigned_slottable(node &Node) bool {
	return assigned_slot_for_node(node) != none
}

pub type AbortAlgorithm = fn ()

// https://dom.spec.whatwg.org/#abortsignal
@[heap]
pub struct AbortSignal {
	EventTarget
pub mut:
	// https://dom.spec.whatwg.org/#abortsignal-abort-reason
	// An AbortSignal object has an associated abort reason, which is a JavaScript value. It is undefined unless specified otherwise.
	abort_reason JSValue

	// https://dom.spec.whatwg.org/#abortsignal-abort-algorithms
	abort_algorithms        map[u64]AbortAlgorithm
	abort_algorithm_order   []u64
	next_abort_algorithm_id u64

	// https://dom.spec.whatwg.org/#abortsignal-source-signals
	// An AbortSignal object has associated source signals, which is initially empty.
	source_signals_ []&AbortSignal

	// https://dom.spec.whatwg.org/#abortsignal-dependent-signals
	// An AbortSignal object has associated dependent signals, which is initially empty.
	dependent_signals []&AbortSignal

	// https://dom.spec.whatwg.org/#abortsignal-dependent
	// An AbortSignal object has a dependent (a boolean), which is initially false.
	dependent_ bool
}

pub fn AbortSignal.construct_impl() !&AbortSignal {
	return AbortSignal.new()
}

pub fn AbortSignal.new() &AbortSignal {
	return &AbortSignal{EventTarget: EventTarget{data: EventTargetData{kind: .abort_signal}}}
}

pub fn (mut signal AbortSignal) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(AbortSignal);
	signal.EventTarget.initialize()
}

// https://dom.spec.whatwg.org/#abortsignal-add
pub fn (mut signal AbortSignal) add_abort_algorithm(abort_algorithm AbortAlgorithm) ?u64 {
	// 1. If signal is aborted, then return.
	if signal.aborted() {
		return none
	}

	// 2. Append algorithm to signal's abort algorithms.
	signal.next_abort_algorithm_id++
	signal.abort_algorithms[signal.next_abort_algorithm_id] = abort_algorithm
	signal.abort_algorithm_order << signal.next_abort_algorithm_id
	return signal.next_abort_algorithm_id
}

// https://dom.spec.whatwg.org/#abortsignal-remove
pub fn (mut signal AbortSignal) remove_abort_algorithm(id u64) {
	// To remove an algorithm algorithm from an AbortSignal signal, remove algorithm from signal's abort algorithms.
	signal.abort_algorithms.delete(id)
	signal.abort_algorithm_order = signal.abort_algorithm_order.filter(it != id)
}

// https://dom.spec.whatwg.org/#dom-abortsignal-aborted
// An AbortSignal object is aborted when its abort reason is not undefined.
pub fn (signal &AbortSignal) aborted() bool {
	return !signal.abort_reason.is_undefined()
}

// https://dom.spec.whatwg.org/#abortsignal-signal-abort
pub fn (mut signal AbortSignal) signal_abort(reason JSValue) {
	signal.signal_abort_with_clock(reason, current_event_timestamp)
}

// AbortSignal.cpp receives the relevant global object. Its clock callback
// retains the source global-relative event timestamp without a DOM→HTML import.
pub fn (mut signal AbortSignal) signal_abort_with_clock(reason JSValue, clock fn () f64) {
	// 1. If signal is aborted, then return.
	if signal.aborted() {
		return
	}

	// 2. Set signal's abort reason to reason if it is given; otherwise to a new "AbortError" DOMException.
	if !reason.is_undefined() {
		signal.abort_reason = reason
	} else {
		signal.abort_reason = abort_error_value('Aborted without reason')
	}

	// 3. Let dependentSignalsToAbort be a new list.
	mut dependent_signals_to_abort := []&AbortSignal{}

	// 4. For each dependentSignal of signal's dependent signals:
	for dependent_signal in signal.dependent_signals {
		// 1. If dependentSignal is not aborted, then:
		if !dependent_signal.aborted() {
			// 1. Set dependentSignal's abort reason to signal's abort reason.
			mut mutable_dependent_signal := unsafe { &AbortSignal(dependent_signal) }
			mutable_dependent_signal.set_reason(signal.abort_reason)

			// 2. Append dependentSignal to dependentSignalsToAbort.
			dependent_signals_to_abort << dependent_signal
		}
	}

	// 5. Run the abort steps for signal.
	signal.run_abort_steps(clock)

	// 6. For each dependentSignal of dependentSignalsToAbort, run the abort steps for dependentSignal.
	for dependent_signal in dependent_signals_to_abort {
		mut mutable_dependent_signal := unsafe { &AbortSignal(dependent_signal) }
		mutable_dependent_signal.run_abort_steps(clock)
	}
}

fn (mut signal AbortSignal) run_abort_steps(clock fn () f64) {
	// https://dom.spec.whatwg.org/#run-the-abort-steps
	// 1. For each algorithm in signal's abort algorithms: run algorithm.
	for algorithm_id in signal.abort_algorithm_order.clone() {
		if algorithm := signal.abort_algorithms[algorithm_id] {
			algorithm()
		}
	}

	// 2. Empty signal's abort algorithms.
	signal.abort_algorithms.clear()
	signal.abort_algorithm_order.clear()

	// 3. Fire an event named abort at signal.
	mut abort_event := Event.create('abort', EventInit{})
	abort_event.set_time_stamp(clock())
	abort_event.set_is_trusted(true)
	event_target_dispatch_event(unsafe { &EventTarget(signal) }, abort_event)
}

pub fn (signal &AbortSignal) reason() JSValue {
	return signal.abort_reason
}

pub fn (mut signal AbortSignal) set_reason(reason JSValue) {
	signal.abort_reason = reason
}

pub fn (signal &AbortSignal) dependent() bool {
	return signal.dependent_
}

pub fn (mut signal AbortSignal) set_dependent(dependent bool) {
	signal.dependent_ = dependent
}

pub fn (signal &AbortSignal) source_signals() []&AbortSignal {
	return signal.source_signals_
}

pub fn (mut signal AbortSignal) append_source_signal(source_signal &AbortSignal) {
	signal.source_signals_ << source_signal
}

pub fn (mut signal AbortSignal) append_dependent_signal(dependent_signal &AbortSignal) {
	signal.dependent_signals << dependent_signal
}

pub fn (signal &AbortSignal) set_onabort(event_handler ?&CallbackType) {
	unsafe { &EventTarget(signal) }.set_event_handler_attribute('abort', event_handler)
}

pub fn (signal &AbortSignal) onabort() ?&CallbackType {
	return unsafe { &EventTarget(signal) }.event_handler_attribute('abort')
}

// https://dom.spec.whatwg.org/#dom-abortsignal-throwifaborted
pub fn (signal &AbortSignal) throw_if_aborted() ! {
	// The throwIfAborted() method steps are to throw this's abort reason, if this is aborted.
	if !signal.aborted() {
		return
	}
	return webidl.throw_value(signal.abort_reason.as_webidl_value()!)
}

pub fn (mut signal AbortSignal) visit_edges(mut visitor CellVisitor) {
	signal.EventTarget.visit_edges(mut visitor)
	visitor.visit(signal.abort_reason.object_data)
	for source_signal in signal.source_signals_ {
		visitor.visit(source_signal)
	}
	for dependent_signal in signal.dependent_signals {
		visitor.visit(dependent_signal)
	}
}

// https://dom.spec.whatwg.org/#dom-abortsignal-abort
pub fn AbortSignal.abort(reason JSValue) !&AbortSignal {
	// 1. Let signal be a new AbortSignal object.
	mut signal := AbortSignal.construct_impl()!

	// 2. Set signal's abort reason to reason if it is given; otherwise to a new "AbortError" DOMException.
	if reason.is_undefined() {
		signal.set_reason(abort_error_value('Aborted without reason'))
	} else {
		signal.set_reason(reason)
	}

	// 3. Return signal.
	return signal
}

// https://dom.spec.whatwg.org/#dom-abortsignal-any
pub fn AbortSignal.any(signals []&AbortSignal) !&AbortSignal {
	// The static any(signals) method steps are to return the result of creating a dependent abort signal from signals using AbortSignal and the current realm.
	return AbortSignal.create_dependent_abort_signal(signals)
}

// https://dom.spec.whatwg.org/#create-a-dependent-abort-signal
pub fn AbortSignal.create_dependent_abort_signal(signals []&AbortSignal) !&AbortSignal {
	// 1. Let resultSignal be a new object implementing signalInterface using realm.
	mut result_signal := AbortSignal.construct_impl()!

	// 2. For each signal of signals: if signal is aborted, then set resultSignal's abort reason to signal's abort reason and return resultSignal.
	for signal in signals {
		if signal.aborted() {
			result_signal.set_reason(signal.reason())
			return result_signal
		}
	}

	// 3. Set resultSignal's dependent to true.
	result_signal.set_dependent(true)

	// 4. For each signal of signals:
	for signal in signals {
		// 1. If signal's dependent is false, then:
		if !signal.dependent() {
			// 1. Append signal to resultSignal's source signals.
			result_signal.append_source_signal(signal)

			// 2. Append resultSignal to signal's dependent signals.
			mut mutable_signal := unsafe { &AbortSignal(signal) }
			mutable_signal.append_dependent_signal(result_signal)
		} else {
			// 2. Otherwise, for each sourceSignal of signal's source signals:
			for source_signal in signal.source_signals() {
				// 1. Assert: sourceSignal is not aborted and not dependent.
				// 2. Append sourceSignal to resultSignal's source signals.
				result_signal.append_source_signal(source_signal)

				// 3. Append resultSignal to sourceSignal's dependent signals.
				mut mutable_source_signal := unsafe { &AbortSignal(source_signal) }
				mutable_source_signal.append_dependent_signal(result_signal)
			}
		}
	}

	// 5. Return resultSignal.
	return result_signal
}

// https://dom.spec.whatwg.org/#abortcontroller
@[heap]
pub struct AbortController {
pub mut:
	// https://dom.spec.whatwg.org/#abortcontroller-signal
	signal_ &AbortSignal = unsafe { nil }
}

pub fn AbortController.construct_impl() !&AbortController {
	signal := AbortSignal.construct_impl()!
	return AbortController.new(signal)
}

// https://dom.spec.whatwg.org/#dom-abortcontroller-abortcontroller
pub fn AbortController.new(signal &AbortSignal) &AbortController {
	return &AbortController{
		signal_: signal
	}
}

pub fn (mut controller AbortController) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(AbortController);
}

pub fn (mut controller AbortController) visit_edges(mut visitor CellVisitor) {
	visitor.visit(controller.signal_)
}

// https://dom.spec.whatwg.org/#dom-abortcontroller-signal
pub fn (controller &AbortController) signal() &AbortSignal {
	return controller.signal_
}

// https://dom.spec.whatwg.org/#dom-abortcontroller-abort
pub fn (mut controller AbortController) abort(reason JSValue) {
	controller.abort_with_clock(reason, current_event_timestamp)
}

pub fn (mut controller AbortController) abort_with_clock(reason JSValue, clock fn () f64) {
	// The abort(reason) method steps are to signal abort on this's signal with reason if it is given.
	if controller.signal_ != unsafe { nil } {
		mut signal := unsafe { &AbortSignal(controller.signal_) }
		signal.signal_abort_with_clock(reason, clock)
	}
}
