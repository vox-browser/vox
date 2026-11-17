module libjsdom

import dom
import html
import libjs
import platform

struct InlineHandler {
	target &dom.EventTarget
	name string
	function libjs.Value
	callback &dom.CallbackType
}

fn (host &Host) owns_inline_target(target &dom.EventTarget) bool {
	if host.closed || host.document.has_been_destroyed() { return false }
	if target.data.kind == .window {
		if window := host.document.get_window() { return voidptr(window) == voidptr(target) }
		return false
	}
	if target.data.kind != .node { return false }
	node := unsafe { &dom.Node(target) }
	return node.is_element() && voidptr(node.document()) == voidptr(host.document)
}

fn (mut host Host) install_inline_event_handlers() {
	available := fn [host] (target &dom.EventTarget) bool { return host.owns_inline_target(target) }
	compile := fn [host] (target &dom.EventTarget, name string, _ string, source string) ?&dom.CallbackType {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.compile_inline_handler(target, name, source) or { return none }
	}
	host.closures << voidptr(available)
	host.closures << voidptr(compile)
	report := fn [host] (err IError) {
		if callback := host.hooks.exception { callback(exception_message_with_stack(err)) }
	}
	host.closures << voidptr(report)
	mut document := unsafe { &dom.Document(host.document) }
	document.set_event_callback_exception_reporter(report)
	document.set_inline_event_handler_compiler(dom.InlineEventHandlerCompiler{
		owner_identity: voidptr(&host)
		can_compile: available
		compile: compile
	})
}

// DOM/EventTarget.cpp::get_current_value_of_event_handler: lookup order is
// element, form owner, Document, then the relevant realm's global environment.
fn (mut host Host) compile_inline_handler(target &dom.EventTarget, name string, source string) !&dom.CallbackType {
	mut vm := host.vm
	mut environment := libjs.Environment(host.realm.global_environment_record())
	if target.data.kind == .node {
		element := unsafe { &dom.Node(target) }.as_element() or { return error('Handler target is not an element') }
		environment = libjs.Environment(libjs.ObjectEnvironment.create(host.wrap_node(host.document.as_node()).as_object(), true, environment))
		if element.is_html_element() && (element.local_name() in ['button', 'fieldset', 'input', 'object', 'output', 'select', 'textarea'] || element.is_form_associated_custom_element()) {
			if form := html.computed_listed_element_form_owner(element) {
				environment = libjs.Environment(libjs.ObjectEnvironment.create(host.wrap_node(form.as_node()).as_object(), true, environment))
			}
		}
		environment = libjs.Environment(libjs.ObjectEnvironment.create(host.wrap_node(element.as_node()).as_object(), true, environment))
	}
	function := libjs.create_host_function(mut vm, source, host.document.url.serialize() + '#on' + name, environment)!
	mut callback := host.event_callback(target, name, function, dom.AddEventListenerOptions{}, true)
	callback.compiled_source_text_ = source
	host.inline_handlers << InlineHandler{target: target, name: name.clone(), function: function, callback: callback}
	return callback
}
