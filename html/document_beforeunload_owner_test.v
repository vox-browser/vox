module html

import dom
import highresolutiontime
import math
import page
import webdriver

@[heap]
struct BeforeUnloadOwnerObservation {
mut:
	calls      int
	time_stamp f64
}

fn before_unload_owner_document(address string) !(&dom.Document, &WindowModel) {
	owner := page.Page.create(1)!
	url := dom.URL{address}
	document := create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	native := document.get_window() or { return error('missing actual Window') }
	return document, unsafe { &WindowModel(native) }
}

fn before_unload_restore_prompt_handler(snapshot ?map[webdriver.PromptType]webdriver.PromptHandlerConfiguration) {
	webdriver.set_user_prompt_handler(snapshot or { map[webdriver.PromptType]webdriver.PromptHandlerConfiguration{} })
}

fn before_unload_dismiss_prompt() {
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{
			handler: .dismiss
		}
	})
}

fn before_unload_activate(document &dom.Document) {
	assert unsafe { &dom.EventTarget(document) }.dispatch_event(dom.Event.create('mousedown', dom.EventInit{}))
	assert (document.get_window() or { panic('missing actual Window') }).has_sticky_activation()
}

fn test_beforeunload_uses_actual_window_dispatch_clock_and_lifecycle_before_prompt_lookup() {
	mut document, window := before_unload_owner_document('https://beforeunload-owner.example/dispatch')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		before_unload_restore_prompt_handler(snapshot)
		document.finalize()
	}
	before_unload_dismiss_prompt()
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	before_unload_activate(document)
	native := document.get_window()?
	target := unsafe { &dom.EventTarget(native) }
	document_target := unsafe { &dom.EventTarget(document) }
	state := &BeforeUnloadOwnerObservation{}
	event_loop := main_thread_event_loop()
	initial_nesting := event_loop.termination_nesting_level
	target.set_event_handler_attribute('beforeunload', &dom.CallbackType{
		associated_window: native
		handle_event:      fn [document, document_target, target, native, state, event_loop, initial_nesting] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert event.is_trusted() && event.cancelable()
			assert event.interface_ == .before_unload_event
			assert voidptr(event.target() or { panic('missing event target') }) == voidptr(document_target)
			assert voidptr(event.current_target() or { panic('missing current target') }) == voidptr(target)
			assert voidptr(current or { panic('missing callback target') }) == voidptr(target)
			assert voidptr(native.current_event() or { panic('missing current event') }) == voidptr(event)
			assert document.get_unload_counter() == 1
			assert event_loop.termination_nesting_level == initial_nesting + 1
			mut observation := unsafe { &BeforeUnloadOwnerObservation(state) }
			observation.calls++
			observation.time_stamp = event.time_stamp()
			return dom.js_string('leave this page')
		}
	})
	context := highresolutiontime.TimeOriginContext{
		time_origin: document.load_timing_info.navigation_start_time
	}
	before := highresolutiontime.current_high_resolution_time(context)
	result := document.steps_to_fire_beforeunload(false)
	after := highresolutiontime.current_high_resolution_time(context)
	assert result.unload_prompt_shown && result.unload_prompt_canceled
	assert state.calls == 1
	assert state.time_stamp >= before && state.time_stamp <= after
	assert state.time_stamp >= 30000
	assert document.get_unload_counter() == 0
	assert event_loop.termination_nesting_level == initial_nesting
	assert native.current_event() == none && window.current_event() == none
}

fn test_beforeunload_prompt_gates_use_sticky_activation_and_current_document_sandbox() {
	mut document, _ := before_unload_owner_document('https://beforeunload-owner.example/gates')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		before_unload_restore_prompt_handler(snapshot)
		document.finalize()
	}
	before_unload_dismiss_prompt()
	mut native := document.get_window()?
	target := unsafe { &dom.EventTarget(native) }
	state := &BeforeUnloadOwnerObservation{}
	target.set_event_handler_attribute('beforeunload', &dom.CallbackType{
		associated_window: native
		handle_event:      fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &BeforeUnloadOwnerObservation(state) }
			observation.calls++
			return dom.js_string('leave this page')
		}
	})
	assert math.is_inf(native.last_activation_timestamp, 1)
	unactivated := document.steps_to_fire_beforeunload(false)
	assert !unactivated.unload_prompt_shown && !unactivated.unload_prompt_canceled
	before_unload_activate(document)
	// Consuming transient activation retains Source sticky activation.
	native.consume_user_activation()
	assert native.has_sticky_activation() && !native.has_transient_activation()
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_modals))
	sandboxed := document.steps_to_fire_beforeunload(false)
	assert !sandboxed.unload_prompt_shown && !sandboxed.unload_prompt_canceled
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_forms))
	already_shown := document.steps_to_fire_beforeunload(true)
	assert already_shown.unload_prompt_shown && !already_shown.unload_prompt_canceled
	allowed := document.steps_to_fire_beforeunload(false)
	assert allowed.unload_prompt_shown && allowed.unload_prompt_canceled
	assert state.calls == 4
	assert document.get_unload_counter() == 0
}

fn test_beforeunload_real_event_cancellation_and_return_value_use_source_prompt_handler_resolution() {
	mut document, _ := before_unload_owner_document('https://beforeunload-owner.example/resolution')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		before_unload_restore_prompt_handler(snapshot)
		document.finalize()
	}
	before_unload_activate(document)
	native := document.get_window()?
	target := unsafe { &dom.EventTarget(native) }
	// A sticky Window alone does not satisfy the event result/returnValue gate.
	before_unload_dismiss_prompt()
	plain := document.steps_to_fire_beforeunload(false)
	assert !plain.unload_prompt_shown && !plain.unload_prompt_canceled
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_event := unsafe { &dom.Event(event) }
			mutable_event.prevent_default()
			return dom.js_undefined()
		}
	})
	target.add_event_listener_without_options('beforeunload', listener)
	canceled := document.steps_to_fire_beforeunload(false)
	assert canceled.unload_prompt_shown && canceled.unload_prompt_canceled
	target.remove_event_listener('beforeunload', listener, false)
	target.add_event_listener_without_options('beforeunload', dom.IDLEventListener.create(&dom.CallbackType{
		associated_window: native
		handle_event:      fn (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut before_unload := unsafe { &dom.BeforeUnloadEvent(event) }
			before_unload.set_return_value('returnValue without canceling the event')
			assert !event.default_prevented()
			return dom.js_undefined()
		}
	}))
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.fallback_default: webdriver.PromptHandlerConfiguration{
			handler: .dismiss
		}
	})
	// The exact translated WebDriver lookup defaults beforeUnload to accept
	// before consulting fallbackDefault.
	default_accept := document.steps_to_fire_beforeunload(false)
	assert default_accept.unload_prompt_shown && !default_accept.unload_prompt_canceled
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.default_: webdriver.PromptHandlerConfiguration{
			handler: .dismiss
			notify:  true
		}
	})
	default_dismiss := document.steps_to_fire_beforeunload(false)
	assert default_dismiss.unload_prompt_shown && default_dismiss.unload_prompt_canceled
	webdriver.set_user_prompt_handler({
		webdriver.PromptType.before_unload: webdriver.PromptHandlerConfiguration{
			handler: .ignore
		}
		webdriver.PromptType.default_:      webdriver.PromptHandlerConfiguration{
			handler: .dismiss
		}
	})
	explicit_ignore := document.steps_to_fire_beforeunload(false)
	assert explicit_ignore.unload_prompt_shown && !explicit_ignore.unload_prompt_canceled
}

fn test_beforeunload_retains_relevant_window_while_using_its_current_associated_document_for_dispatch_and_clock() {
	mut original, mut window := before_unload_owner_document('https://beforeunload-owner.example/original')!
	mut replacement, _ := before_unload_owner_document('https://beforeunload-owner.example/replacement')!
	snapshot := webdriver.user_prompt_handler()
	defer {
		before_unload_restore_prompt_handler(snapshot)
		window.set_associated_document(original)
		original.finalize()
		replacement.finalize()
	}
	before_unload_dismiss_prompt()
	before_unload_activate(original)
	replacement.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 60000
	replacement.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_modals))
	window.set_associated_document(replacement)
	native := original.get_window()?
	target := unsafe { &dom.EventTarget(native) }
	state := &BeforeUnloadOwnerObservation{}
	target.set_event_handler_attribute('beforeunload', &dom.CallbackType{
		associated_window: native
		handle_event:      fn [original, replacement, target, state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('missing event target') }) == voidptr(replacement)
			assert voidptr(event.current_target() or { panic('missing current target') }) == voidptr(target)
			assert original.get_unload_counter() == 1
			assert replacement.get_unload_counter() == 0
			mut observation := unsafe { &BeforeUnloadOwnerObservation(state) }
			observation.calls++
			observation.time_stamp = event.time_stamp()
			return dom.js_string('leave this page')
		}
	})
	result := original.steps_to_fire_beforeunload(false)
	assert result.unload_prompt_shown && result.unload_prompt_canceled
	assert state.calls == 1 && state.time_stamp >= 60000
	// Step 6 reads the document being unloaded, while Window's dispatch and
	// relevant settings clock read its current associated document.
	original.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_modals))
	replacement.set_active_sandboxing_flag_bits(0)
	blocked := original.steps_to_fire_beforeunload(false)
	assert !blocked.unload_prompt_shown && !blocked.unload_prompt_canceled
	assert state.calls == 2
}
