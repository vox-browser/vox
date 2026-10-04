module html

import dom
import highresolutiontime
import math
import page

@[heap]
struct ActivationNotificationObservation {
mut:
	calls int
}

fn activation_notification_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn test_trusted_element_activation_uses_relative_source_clock_before_listener_and_cancellation() {
	mut document, window := activation_notification_document('https://activation-notification.example/element')!
	defer { document.finalize() }
	mut root := unsafe { &dom.Node(document) }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'button')!
	root.append_child(element.as_node())!
	native := document.get_window()?
	activation := UserActivation.construct_impl(native)!
	manager := window.close_watcher_manager()
	watcher := CloseWatcher.construct_impl(window, CloseWatcherOptions{})!
	assert watcher.is_active && !manager.can_prevent_close()
	state := &ActivationNotificationObservation{}
	target := unsafe { &dom.EventTarget(element) }
	target.add_event_listener_without_options('mousedown', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn [window, native, activation, manager, state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert native.has_sticky_activation() && native.has_transient_activation()
			assert window.has_sticky_activation() && window.has_transient_activation()
			assert activation.has_been_active() && activation.is_active()
			assert window.last_activation_timestamp() == native.last_activation_timestamp
			assert manager.can_prevent_close()
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			mut observation := unsafe { &ActivationNotificationObservation(state) }
			observation.calls++
			return dom.js_undefined()
		}
	}))
	context := highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	}
	before := highresolutiontime.current_high_resolution_time(context)
	mut event := dom.Event.create('mousedown', dom.EventInit{ cancelable: true })
	event.time_stamp_ = math.inf(1)
	assert !target.dispatch_event(event)
	after := highresolutiontime.current_high_resolution_time(context)
	assert state.calls == 1
	assert window.last_activation_timestamp() >= before
	assert window.last_activation_timestamp() <= after
	assert window.last_activation_timestamp() != event.time_stamp()
	assert window.environment_settings_.settings.has_transient_activation()
	assert snapshot_source_snapshot_params(document).has_transient_activation
}

fn test_native_activation_filters_and_window_override_preserve_source_timestamp() {
	mut document, window := activation_notification_document('https://activation-notification.example/filters')!
	defer { document.finalize() }
	native := document.get_window()?
	target := unsafe { &dom.EventTarget(document) }
	assert target.dispatch_event_binding(dom.Event.create('mousedown', dom.EventInit{}))!
	assert math.is_inf(window.last_activation_timestamp(), 1)
	assert unsafe { &dom.EventTarget(native) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert math.is_inf(window.last_activation_timestamp(), 1)
	escape := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{ key_code: 27, key: 'Escape' })
	assert target.dispatch_event(unsafe { &dom.Event(escape) })
	assert math.is_inf(window.last_activation_timestamp(), 1)
	mouse_up := dom.PointerEvent.create('pointerup', dom.PointerEventInit{ pointer_type: 'mouse' })
	touch_down := dom.PointerEvent.create('pointerdown', dom.PointerEventInit{ pointer_type: 'touch' })
	assert target.dispatch_event(unsafe { &dom.Event(mouse_up) })
	assert target.dispatch_event(unsafe { &dom.Event(touch_down) })
	assert math.is_inf(window.last_activation_timestamp(), 1)
	key := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{ key_code: 65, key: 'a' })
	assert target.dispatch_event(unsafe { &dom.Event(key) })
	assert native.has_transient_activation() && window.has_transient_activation()
	assert window.last_activation_timestamp() == native.last_activation_timestamp
}

fn test_trusted_pointer_activation_uses_actual_reassociated_window_document_clock() {
	mut original, mut window := activation_notification_document('https://activation-notification.example/original')!
	mut replacement, _ := activation_notification_document('https://activation-notification.example/replacement')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	replacement.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 60000
	window.set_associated_document(replacement)
	target := unsafe { &dom.EventTarget(original) }
	context := highresolutiontime.TimeOriginContext{
		time_origin: replacement.load_timing_info.navigation_start_time
	}
	before := highresolutiontime.current_high_resolution_time(context)
	touch_up := dom.PointerEvent.create('pointerup', dom.PointerEventInit{ pointer_type: 'touch' })
	assert target.dispatch_event(unsafe { &dom.Event(touch_up) })
	after := highresolutiontime.current_high_resolution_time(context)
	assert window.last_activation_timestamp() >= before
	assert window.last_activation_timestamp() <= after
	assert window.last_activation_timestamp() >= 60000
	assert window.has_transient_activation()
	mut native := original.get_window()?
	native.set_last_activation_timestamp(math.inf(1))
	mouse_down := dom.PointerEvent.create('pointerdown', dom.PointerEventInit{ pointer_type: 'mouse' })
	assert target.dispatch_event(unsafe { &dom.Event(mouse_down) })
	assert window.has_transient_activation() && native.has_transient_activation()
	window.set_associated_document(original)
}

fn test_adopted_element_trusted_activation_uses_current_document_window_and_clock() {
	mut original, original_window := activation_notification_document('https://activation-adoption.example/original')!
	mut replacement, replacement_window := activation_notification_document('https://activation-adoption.example/replacement')!
	defer {
		original.finalize()
		replacement.finalize()
	}
	element := original.create_element('button')!
	_ = replacement.adopt_node_binding(element.as_node())!
	assert element.document() == replacement
	replacement.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	context := highresolutiontime.TimeOriginContext{
		time_origin: replacement.load_timing_info.navigation_start_time
	}
	native_original := original.get_window()?
	target := unsafe { &dom.EventTarget(element) }
	state := &ActivationNotificationObservation{}
	target.add_event_listener_without_options('mousedown', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native_original
		handle_event:      fn [original_window, replacement_window, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert math.is_inf(original_window.last_activation_timestamp(), 1)
			assert !original_window.has_transient_activation()
			assert replacement_window.has_transient_activation()
			assert replacement_window.last_activation_timestamp() >= 30000
			mut observation := unsafe { &ActivationNotificationObservation(state) }
			observation.calls++
			return dom.js_undefined()
		}
	}))
	before := highresolutiontime.current_high_resolution_time(context)
	assert target.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	after := highresolutiontime.current_high_resolution_time(context)
	assert state.calls == 1
	assert replacement_window.last_activation_timestamp() >= before
	assert replacement_window.last_activation_timestamp() <= after
	assert math.is_inf(original_window.last_activation_timestamp(), 1)
}
