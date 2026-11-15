// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) custom_element_binding(handle voidptr) !&RegistryBinding {
	for _, binding in host.registries {
		if voidptr(binding.native) == handle { return binding }
	}
	return error('TypeError: Custom element registry belongs to another realm')
}

fn (mut host Host) construct_html_element(mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	id := u64(voidptr(new_target))
	mut handle := host.document.custom_element_registry()
	if active := host.active_registries[id] { handle = active; host.active_registries.delete(id) }
	binding := host.custom_element_binding(handle) or { return host.dom_error(mut vm, err) }
	definition := binding.native.get_definition_from_new_target(id) or { return vm.throw_error(.type_error, 'No custom element definition is assigned to this constructor') }
	parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
	element := if dom.html_constructor_is_upgrading(definition) {
		dom.take_html_constructor_upgrade_element(definition, 'HTMLElement') or { return host.dom_error(mut vm, err) }
	} else {
		dom.create_element_for_html_constructor(host.document, definition, handle, 'HTMLElement') or { return host.dom_error(mut vm, err) }
	}
	mut object := host.wrap_node(element.as_node()).as_object()
	if !object.internal_set_prototype_of(if parent.is_object() { parent.as_object() } else { host.html_element_prototype }) { return vm.throw_error(.type_error, 'Unable to set custom element prototype') }
	return object
}

// A native reaction can enter from the browser or nest inside an existing JS
// operation. call_with_limits keeps nested construction in the current budget
// and checkpoints jobs only when the outer host entry has completed.
fn (mut host Host) custom_element_entry(callback libjs.NativeFunctionPointer) !libjs.Value {
	defer { platform.release_closure(voidptr(callback)) }
	host.require_open(mut host.vm)!
	if can_run := host.hooks.can_run_callback {
		if !can_run() { return libjs.js_undefined() }
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if before := host.hooks.before_callback { before() }
	defer { if after := host.hooks.after_callback { after() } }
	mut vm := host.vm
	function := libjs.NativeFunction.create(mut vm, host.realm, host.realm.function_prototype, callback, 0, libjs.PropertyName.from_str('customElementReaction'), none).object
	defer { host.changed() }
	return vm.call_with_limits(libjs.Value.from_object(function), libjs.js_undefined(), [], libjs.ExecutionLimits{max_instructions: 1000000})
}

fn (mut host Host) construct_custom_element(definition &dom.CustomElementDefinition, handle voidptr) !libjs.Value {
	binding := host.custom_element_binding(handle)!
	id := definition.constructor()
	constructor := binding.constructors[id] or { return error('TypeError: Custom element constructor belongs to another realm') }
	previous := host.active_registries[id] or { unsafe { nil } }
	host.active_registries[id] = handle
	defer { if previous != unsafe { nil } { host.active_registries[id] = previous } else { host.active_registries.delete(id) } }
	return host.custom_element_entry(fn [constructor] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_object(libjs.construct(mut vm, constructor, [], none)!)
	})
}

fn construct_libjs_custom_element(owner voidptr, definition &dom.CustomElementDefinition, registry voidptr) !&dom.Element {
	mut host := unsafe { &Host(owner) }
	value := host.construct_custom_element(definition, registry)!
	if value.is_object() {
		if node := host.nodes[voidptr(value.as_object())] {
			if element := node.as_element() { return element }
		}
	}
	return error('TypeError: Custom element constructor must return an HTMLElement')
}

fn upgrade_libjs_custom_element(owner voidptr, element &dom.Element, definition &dom.CustomElementDefinition) ! {
	mut host := unsafe { &Host(owner) }
	existing := host.wrap_node(element.as_node())
	value := host.construct_custom_element(definition, element.custom_element_registry())!
	if !value.is_object() || voidptr(value.as_object()) != voidptr(existing.as_object()) { return error('TypeError: Custom element constructor returned a different element than the one being upgraded') }
}

fn report_libjs_custom_element_error(owner voidptr, err IError) {
	host := unsafe { &Host(owner) }
	if callback := host.hooks.exception { callback(exception_message(err)) }
}

fn invoke_libjs_custom_element_callback(owner voidptr, element &dom.Element, reaction dom.CustomElementCallbackReaction) ! {
	mut host := unsafe { &Host(owner) }
	definition := element.custom_element_definition() or { return }
	binding := host.custom_element_binding(element.custom_element_registry())!
	metadata := binding.metadata[definition.constructor()] or { return }
	callback := metadata.callbacks[reaction.callback_name] or { return }
	receiver := host.wrap_node(element.as_node())
	mut arguments := []libjs.Value{}
	mut vm := host.vm
	if change := reaction.attribute {
		arguments << libjs.Value.from_string(vm.create_string_from_str(change.name))
		for option in [change.old_value, change.new_value, change.namespace_] {
			arguments << if text := option { libjs.Value.from_string(vm.create_string_from_str(text)) } else { libjs.js_null() }
		}
	} else if reaction.old_document != unsafe { nil } && reaction.new_document != unsafe { nil } {
		arguments << host.wrap_node(unsafe { &dom.Node(reaction.old_document) })
		arguments << host.wrap_node(unsafe { &dom.Node(reaction.new_document) })
	} else {
		for text in reaction.arguments { arguments << libjs.Value.from_string(vm.create_string_from_str(text)) }
	}
	host.custom_element_entry(fn [callback, receiver, arguments] (mut vm libjs.VM) !libjs.Value {
		return libjs.call(mut vm, callback, receiver, arguments)
	})!
}
