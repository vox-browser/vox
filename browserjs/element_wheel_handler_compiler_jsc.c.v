// DOM/EventTarget.cpp: lazily compile wheel, media and track handlers in owner scopes.
module browserjs

import dom
import html


// GlobalEventHandlers event names; the WindowEventHandlers that follow them in
// the source table belong to Window (and forward from body and frameset).
const element_inline_handler_events = element_global_event_handler_events()

fn element_global_event_handler_events() map[string]bool {
	mut events := map[string]bool{}
	for name in window_event_handler_names() {
		if name.attribute == 'onafterprint' { break }
		events[name.event] = true
	}
	return events
}

// Ordinary HTML elements own every inline handler natively, so script-dispatched
// and natively fired events run content attributes and on* properties alike.
// Media and track elements keep their dedicated owners; image, object,
// fieldset, output and form-associated custom elements keep compact replay.
fn element_owns_native_inline_handlers(element &dom.Element) bool {
	return element.is_html_element()
		&& element.local_name() !in ['img', 'object', 'fieldset', 'output', 'audio', 'video', 'track']
		&& !element.is_form_associated_custom_element()
}

fn event_target_owns_native_inline_handler(target &dom.EventTarget, name string) bool {
	if name !in element_inline_handler_events || !event_target_is_element(target) { return false }
	element := unsafe { &dom.Node(target) }.as_element() or { return false }
	return element_owns_native_inline_handlers(element)
}

fn (mut host ElementWheelHost) install_raw_wheel_handler_compiler() ! {
	settings := host.settings
	owner := voidptr(&host)
	mut document := unsafe { &dom.Document(host.document) }
	document.set_inline_event_handler_compiler(dom.InlineEventHandlerCompiler{
		supports_handler: fn [owner, settings] (target &dom.EventTarget, name string) bool {
			if name in ['wheel', 'scrollend'] || (target.data.kind == .window
				&& voidptr(target) == voidptr(settings.global_object())) { return true }
			// Decided without resolving the element through the provider registry.
			if event_target_owns_native_inline_handler(target, name) { return true }
			// Most native pointer/focus dispatches query ordinary raw handlers.
			// Reject unsupported names before resolving an element: resolution
			// refreshes the complete provider registry for media/track ownership.
			if name !in ['load', 'play', 'pause', 'playing', 'waiting', 'canplay', 'canplaythrough', 'loadedmetadata', 'loadeddata', 'ratechange', 'volumechange', 'timeupdate', 'durationchange', 'seeking', 'seeked', 'progress', 'suspend', 'abort', 'emptied', 'loadstart', 'ended', 'resize', 'error'] { return false }
			mut host := unsafe { &ElementWheelHost(owner) }
			if host.closed || host.runtime.closed { return false }
			element := host.raw_wheel_handler_element(target) or { return false }
			if element.local_name() == 'track' { return name in ['load', 'error'] }
			return element.local_name() in ['audio', 'video']
				&& name in ['play', 'pause', 'playing', 'waiting', 'canplay', 'canplaythrough', 'loadedmetadata', 'loadeddata', 'ratechange', 'volumechange', 'timeupdate', 'durationchange', 'seeking', 'seeked', 'progress', 'suspend', 'abort', 'emptied', 'loadstart', 'ended', 'resize', 'error']
		}
		can_compile: fn [owner, settings] (target &dom.EventTarget) bool {
			mut host := unsafe { &ElementWheelHost(owner) }
			if host.closed || host.runtime.closed || host.runtime.context == unsafe { nil }
				|| !html.is_scripting_enabled(settings.realm()) { return false }
			if target.data.kind == .window {
				return voidptr(target) == voidptr(settings.global_object())
			}
			element := host.raw_wheel_handler_element(target) or { return false }
			binding := host.runtime.event_binding() or { return false }
			if voidptr(host.document) !in binding.target_wrappers { return false }
			if element.local_name() in ['audio', 'video'] {
				return host.live_raw_media_wheel_hosts().len != 0
			}
			// The form owner is part of a control's handler scope. Create the control
			// model, which resets its form owner, rather than leaving the handler raw.
			raw_handler_ensure_control(element)
			if !raw_wheel_handler_form_owner_available(element) { return false }
			if control := raw_wheel_handler_control(element) {
				if form := control.form() {
					if host.raw_wheel_handler_element(unsafe { &dom.EventTarget(form) }) == none {
						return false
					}
				}
			}
			return true
		}
		can_compile_handler: fn [owner] (target &dom.EventTarget, name string) bool {
			if target.data.kind == .window { return true }
			mut host := unsafe { &ElementWheelHost(owner) }
			element := host.raw_wheel_handler_element(target) or { return false }
			if element.local_name() in ['audio', 'video']
				|| (element.local_name() == 'track' && name in ['load', 'error']) {
				return host.raw_media_or_track_handler_available(target, element, name)
			}
			return name in ['wheel', 'scrollend'] || event_target_owns_native_inline_handler(target, name)
		}
		compile: fn [owner, settings] (target &dom.EventTarget, name string, body string, source string) ?&dom.CallbackType {
			mut host := unsafe { &ElementWheelHost(owner) }
			if target.data.kind == .window {
				return host.runtime.compile_window_event_handler(target, name, body, source, settings)
			}
			return host.compile_raw_wheel_handler(target, name, body, source)
		}
	})
}

fn (mut host ElementWheelHost) raw_wheel_handler_element(target &dom.EventTarget) ?&dom.Element {
	if !event_target_is_element(target) { return none }
	host.refresh_elements()
	for _, element in host.elements {
		if voidptr(element) != voidptr(target) { continue }
		if voidptr(element.document()) != voidptr(host.document) || !element.is_html_element()
			|| element.local_name() in ['img', 'object', 'fieldset', 'output']
			|| element.is_form_associated_custom_element() { return none }
		return element
	}
	return none
}

// Read the real cached control; compiling an attribute must not manufacture a
// form model or infer ownership from its nearest ancestor.
fn raw_wheel_handler_control(element &dom.Element) ?&html.FormAssociatedElement {
	match element.local_name() {
		'input' {
			input := unsafe { &dom.HTMLInputElement(element) }
			if input.input_element_model_ == unsafe { nil } { return none }
			return unsafe { &html.HTMLInputElementModel(input.input_element_model_) }.control
		}
		'button' {
			button := unsafe { &dom.HTMLButtonElement(element) }
			if button.button_element_model_ == unsafe { nil } { return none }
			return unsafe { &html.HTMLButtonElementModel(button.button_element_model_) }.control
		}
		'select' {
			select_ := unsafe { &dom.HTMLSelectElement(element) }
			if select_.select_element_model_ == unsafe { nil } { return none }
			return unsafe { &html.HTMLSelectElementModel(select_.select_element_model_) }.control
		}
		'textarea' {
			textarea := unsafe { &dom.HTMLTextAreaElement(element) }
			if textarea.text_area_element_model_ == unsafe { nil } { return none }
			return unsafe { &html.HTMLTextAreaElementModel(textarea.text_area_element_model_) }.control
		}
		else { return none }
	}
}

fn raw_handler_ensure_control(element &dom.Element) {
	match element.local_name() {
		'input' { _ = html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }) }
		'button' { _ = html.HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) }) }
		'select' { _ = html.HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) }) }
		'textarea' { _ = html.HTMLTextAreaElementModel.create(unsafe { &dom.HTMLTextAreaElement(element) }) }
		else { return }
	}
	if mut control := raw_wheel_handler_control(element) {
		if control.form() == none { control.reset_form_owner() }
	}
}

fn raw_wheel_handler_form_owner_available(element &dom.Element) bool {
	return element.local_name() !in ['input', 'button', 'select', 'textarea']
		|| raw_wheel_handler_control(element) != none
}

fn (runtime &Runtime) raw_wheel_handler_body_is_valid(handler_name string, body string) bool {
	name := js_source_string('on' + handler_name)
	parameter := js_source_string('event')
	body_value := js_source_string(body)
	defer { C.JSStringRelease(name) }
	defer { C.JSStringRelease(parameter) }
	defer { C.JSStringRelease(body_value) }
	// Parse the actual FunctionBody in isolation. Checking a generated Script
	// alone would allow closing braces to escape into the scope factory.
	mut exception := voidptr(0)
	validated := C.vox_jsc_JSObjectMakeFunction(runtime.context, name, 1, &parameter,
		body_value, unsafe { nil }, 1, &exception)
	return exception == unsafe { nil } && validated != unsafe { nil }
}

fn (mut host ElementWheelHost) compile_raw_wheel_handler(target &dom.EventTarget, name string, body string, source string) ?&dom.CallbackType {
	mut runtime := host.runtime
	if (name !in ['wheel', 'scrollend', 'load', 'play', 'pause', 'playing', 'waiting', 'canplay', 'canplaythrough', 'loadedmetadata', 'loadeddata', 'ratechange', 'volumechange', 'timeupdate', 'durationchange', 'seeking', 'seeked', 'progress', 'suspend', 'abort', 'emptied', 'loadstart', 'ended', 'resize', 'error']
		&& !event_target_owns_native_inline_handler(target, name)) || !runtime.raw_wheel_handler_body_is_valid(name, body) { return none }
	element := host.raw_wheel_handler_element(target) or { return none }
	mut vm := runtime.agent_vm
	mut context := runtime.realm_context
	vm.push_execution_context(mut context)
	defer {
		popped := vm.pop_execution_context()
		assert voidptr(popped) == voidptr(runtime.realm_context)
	}
	binding := runtime.event_binding() or { return none }
	document_wrapper := binding.target_wrappers[voidptr(host.document)] or { return none }
	mut scopes := [document_wrapper]
	if control := raw_wheel_handler_control(element) {
		if form := control.form() {
			form_wrapper := runtime.javascript_event_target(unsafe { &dom.EventTarget(form) }, none) or { return none }
			scopes << form_wrapper
		}
	}
	element_wrapper := runtime.javascript_event_target(target, none) or { return none }
	scopes << element_wrapper
	mut openings := ''
	mut endings := ''
	for index in 0 .. scopes.len {
		openings += 'with(this[${index}]){'
		endings += '}'
	}
	// The zero-parameter outer function contributes no helper variable or named
	// function binding. Ordinary inner arguments/this/new.target shadow its
	// implicit bindings. Name inference avoids introducing a handler self binding.
	handler_name := 'on' + name
	factory_body := js_source_string(openings + 'return ({' + handler_name + ':function(event){\n' + body + '\n}}).' + handler_name + ';' + endings)
	defer { C.JSStringRelease(factory_body) }
	mut exception := voidptr(0)
	factory := C.vox_jsc_JSObjectMakeFunction(runtime.context, unsafe { nil }, 0, unsafe { nil },
		factory_body, unsafe { nil }, 1, &exception)
	if exception != unsafe { nil } || factory == unsafe { nil } { return none }
	C.JSValueProtect(runtime.context, factory)
	defer { C.JSValueUnprotect(runtime.context, factory) }
	exception = unsafe { nil }
	carrier := C.vox_jsc_JSObjectMakeArray(runtime.context, uint(scopes.len), scopes.data, &exception)
	if exception != unsafe { nil } || carrier == unsafe { nil } { return none }
	exception = unsafe { nil }
	function := C.vox_jsc_JSObjectCallAsFunction(runtime.context, factory, carrier, 0, unsafe { nil }, &exception)
	if exception != unsafe { nil } || function == unsafe { nil } { return none }
	mut callback := runtime.event_callback_with_settings(function, true, host.settings) or { return none }
	callback.compiled_source_text_ = source
	return callback
}
