// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

@[heap]
struct RegistryBinding {
	native &html.CustomElementRegistry
mut:
	constructors map[u64]libjs.Value
	metadata map[u64]&CustomElementMetadata
	pending map[string]&libjs.JSPromiseCapability
}

@[heap]
struct CustomElementMetadata {
mut:
	native html.CustomElementConstructor
	callbacks map[string]libjs.Value
}

fn custom_element_strings(mut vm libjs.VM, value libjs.Value) ![]string {
	if !value.is_object() { return vm.throw_error(.type_error, 'Expected a sequence object') }
	mut iterator := libjs.get_iterator_sync_value(mut vm, value)!
	mut result := []string{}
	for {
		vm.consume_execution_budget()!
		step := libjs.iterator_step_value(mut vm, mut iterator)!
		if step.done { return result }
		text := step.value.to_primitive_string(mut vm) or {
			return libjs.iterator_close(mut vm, iterator, libjs.completion_from_error(err)).release_error()
		}
		result << text.str()
	}
	return result
}

fn read_custom_element_metadata(mut vm libjs.VM, constructor libjs.Value, mut captured CustomElementMetadata) ! {
	prototype := constructor.as_object().get(mut vm, libjs.PropertyName.from_str('prototype'))!
	if !prototype.is_object() { return vm.throw_error(.type_error, 'Custom element prototype is not an object') }
	mut names := []string{}
	for name in ['connectedCallback', 'disconnectedCallback', 'connectedMoveCallback', 'adoptedCallback', 'attributeChangedCallback'] {
		callback := prototype.as_object().get(mut vm, libjs.PropertyName.from_str(name))!
		if callback.is_undefined() { continue }
		if !callback.is_function() { return vm.throw_error(.type_error, 'Custom element callback must be callable') }
		names << name
		captured.callbacks[name] = callback
	}
	mut observed := []string{}
	if 'attributeChangedCallback' in captured.callbacks {
		value := constructor.as_object().get(mut vm, libjs.PropertyName.from_str('observedAttributes'))!
		if !value.is_undefined() { observed = custom_element_strings(mut vm, value)! }
	}
	features := constructor.as_object().get(mut vm, libjs.PropertyName.from_str('disabledFeatures'))!
	disabled := if features.is_undefined() { []string{} } else { custom_element_strings(mut vm, features)! }
	form := constructor.as_object().get(mut vm, libjs.PropertyName.from_str('formAssociated'))!.to_boolean()
	if form {
		for name in ['formAssociatedCallback', 'formResetCallback', 'formDisabledCallback', 'formStateRestoreCallback'] {
			callback := prototype.as_object().get(mut vm, libjs.PropertyName.from_str(name))!
			if callback.is_undefined() { continue }
			if !callback.is_function() { return vm.throw_error(.type_error, 'Custom element callback must be callable') }
			names << name
			captured.callbacks[name] = callback
		}
	}
	captured.native = html.CustomElementConstructor{id: u64(voidptr(constructor.as_object())), observed_attributes: observed, lifecycle_callbacks: names, disabled_features: disabled, form_associated: form}
}

fn (host &Host) registry_receiver(mut vm libjs.VM) !&RegistryBinding {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if registry := host.registries[voidptr(vm.this_value().as_object())] { return registry }
	}
	return vm.throw_error(.type_error, 'CustomElementRegistry method called on incompatible receiver')
}

fn (mut host Host) install_custom_elements() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.registry_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('CustomElementRegistry')), libjs.attribute_configurable)
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.registry_prototype })
		mut owner := unsafe { &Host(host) }
		owner.registries[voidptr(object)] = &RegistryBinding{native: html.CustomElementRegistry.construct(host.document)}
		return object
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'CustomElementRegistry constructor requires new') }, construct, 0, libjs.PropertyName.from_str('CustomElementRegistry')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name, length in {'define': 2, 'get': 1, 'getName': 1, 'whenDefined': 1, 'upgrade': 1, 'initialize': 1} {
		host.method_attributes(mut prototype, name, length, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if name == 'whenDefined' {
				capability := libjs.new_promise_capability(mut vm, libjs.Value.from_object(host.realm.promise_constructor_record()))!
				result := owner.registry_operation(mut vm, name, capability) or {
					exception := owner.dom_error(mut vm, err)
					if !libjs.is_throw_completion(exception) { return exception }
					libjs.call(mut vm, capability.reject, libjs.js_undefined(), [libjs.thrown_value(exception)])!
					return capability.promise
				}
				return result
			}
			return owner.registry_operation(mut vm, name, none) or { return owner.dom_error(mut vm, err) }
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('CustomElementRegistry'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	native := if host.document.custom_element_registry() != unsafe { nil } { unsafe { &html.CustomElementRegistry(host.document.custom_element_registry()) } } else { html.CustomElementRegistry.create(host.document) }
	object := libjs.Object.create(host.realm, prototype)
	host.registries[voidptr(object)] = &RegistryBinding{native: native}
	host.accessor(mut global, 'customElements', fn [host, object] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		receiver := vm.this_value()
		if !receiver.is_nullish() && (!receiver.is_object() || voidptr(receiver.as_object()) != voidptr(host.realm.global_object_record())) { return vm.throw_error(.type_error, 'Illegal Window receiver') }
		return libjs.Value.from_object(object)
	}, unsafe { nil })
	mut document := unsafe { &dom.Document(host.document) }
	document.set_custom_element_construction_hook(dom.CustomElementConstructionHook{target: voidptr(&host), construct: construct_libjs_custom_element, report: report_libjs_custom_element_error, upgrade: upgrade_libjs_custom_element, invoke: invoke_libjs_custom_element_callback})
}

fn (mut host Host) registry_operation(mut vm libjs.VM, name string, capability ?&libjs.JSPromiseCapability) !libjs.Value {
	mut binding := host.registry_receiver(mut vm)!
	if vm.argument_count() < if name == 'define' { 2 } else { 1 } { return vm.throw_error(.type_error, name + ' requires arguments') }
	if name in ['upgrade', 'initialize'] {
		value := vm.argument(0)
		if !value.is_object() { return vm.throw_error(.type_error, 'Node required') }
		node := host.nodes[voidptr(value.as_object())] or { return vm.throw_error(.type_error, 'Node required') }
		if name == 'upgrade' { binding.native.upgrade(node) } else { binding.native.initialize(node)! }
		host.drain_custom_elements()
		return libjs.js_undefined()
	}
	if name == 'getName' {
		value := vm.argument(0)
		if !value.is_function() { return vm.throw_error(.type_error, 'Callback required') }
		return if text := binding.native.get_name(u64(voidptr(value.as_object()))) { libjs.Value.from_string(vm.create_string_from_str(text)) } else { libjs.js_null() }
	}
	key := vm.argument(0).to_primitive_string(mut vm)!.str()
	if name == 'get' {
		id := binding.native.get(key) or { return libjs.js_undefined() }
		return binding.constructors[id] or { return vm.throw_error(.type_error, 'Constructor belongs to another realm') }
	}
	if name == 'whenDefined' {
		pending := capability or { return error('Missing Promise capability') }
		if !html.is_valid_custom_element_name(key) { return error('SyntaxError: Invalid custom element name') }
		if id := binding.native.get(key) {
			constructor := binding.constructors[id] or { return vm.throw_error(.type_error, 'Constructor belongs to another realm') }
			libjs.call(mut vm, pending.resolve, libjs.js_undefined(), [constructor])!
			return pending.promise
		}
		if existing := binding.pending[key] { return existing.promise }
		binding.pending[key] = pending
		return pending.promise
	}
	constructor := vm.argument(1)
	if !constructor.is_function() { return vm.throw_error(.type_error, 'Custom element callback must be callable') }
	options := vm.argument(2)
	if !options.is_nullish() && !options.is_object() { return vm.throw_error(.type_error, 'ElementDefinitionOptions must be a dictionary') }
	value := if options.is_nullish() { libjs.js_undefined() } else { options.as_object().get(mut vm, libjs.PropertyName.from_str('extends'))! }
	extends := if value.is_undefined() { ?string(none) } else { ?string(value.to_primitive_string(mut vm)!.str()) }
	id := u64(voidptr(constructor.as_object()))
	mut captured := &CustomElementMetadata{}
	read := fn [host, constructor, mut captured] (_ html.CustomElementConstructor) !html.CustomElementConstructor {
		mut vm := host.vm
		read_custom_element_metadata(mut vm, constructor, mut captured)!
		return captured.native
	}
	defer { platform.release_closure(voidptr(read)) }
	binding.native.define_with_metadata(key, html.CustomElementConstructor{id: id, is_constructor: constructor.is_constructor()}, html.ElementDefinitionOptions{extends: extends}, read)!
	binding.constructors[id] = constructor
	binding.metadata[id] = captured
	if pending := binding.pending[key] {
		binding.pending.delete(key)
		libjs.call(mut vm, pending.resolve, libjs.js_undefined(), [constructor])!
	}
	host.drain_custom_elements()
	return libjs.js_undefined()
}

fn (mut host Host) drain_custom_elements() {
	mut document := unsafe { &dom.Document(host.document) }
	document.invoke_custom_element_reactions()
}
