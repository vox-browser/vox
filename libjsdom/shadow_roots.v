// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (host &Host) shadow_root_receiver(mut vm libjs.VM) !&dom.ShadowRoot {
	node := host.node(mut vm)!
	return node.as_shadow_root() or { return vm.throw_error(.type_error, 'ShadowRoot member requires ShadowRoot') }
}

fn (host &Host) shadow_root_options(mut vm libjs.VM, value libjs.Value) !dom.ShadowRootInit {
	if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'ShadowRootInit must be a dictionary') }
	// Convert dictionary members in WebIDL's lexical order, before attaching
	// anything. A getter can throw or mutate the target during conversion.
	mut init := dom.ShadowRootInit{}
	if value.is_nullish() { return vm.throw_error(.type_error, 'ShadowRootInit.mode is required') }
	object := value.as_object()
	init.clonable = object.get(mut vm, libjs.PropertyName.from_str('clonable'))!.to_boolean()
	registry := object.get(mut vm, libjs.PropertyName.from_str('customElementRegistry'))!
	if !registry.is_undefined() {
		if registry.is_null() { init.custom_element_registry = voidptr(unsafe { nil }) }
		else if registry.is_object() {
			binding := host.registries[voidptr(registry.as_object())] or { return vm.throw_error(.type_error, 'Expected CustomElementRegistry') }
			init.custom_element_registry = voidptr(binding.native)
		} else { return vm.throw_error(.type_error, 'Expected CustomElementRegistry') }
	}
	init.delegates_focus = object.get(mut vm, libjs.PropertyName.from_str('delegatesFocus'))!.to_boolean()
	mode := object.get(mut vm, libjs.PropertyName.from_str('mode'))!
	if mode.is_undefined() { return vm.throw_error(.type_error, 'ShadowRootInit.mode is required') }
	mode_name := mode.to_primitive_string(mut vm)!.str()
	if mode_name !in ['open', 'closed'] { return vm.throw_error(.type_error, 'Invalid ShadowRootMode') }
	init.mode = if mode_name == 'open' { .open } else { .closed }
	init.serializable = object.get(mut vm, libjs.PropertyName.from_str('serializable'))!.to_boolean()
	slot := object.get(mut vm, libjs.PropertyName.from_str('slotAssignment'))!
	if !slot.is_undefined() {
		name := slot.to_primitive_string(mut vm)!.str()
		if name !in ['named', 'manual'] { return vm.throw_error(.type_error, 'Invalid SlotAssignmentMode') }
		init.slot_assignment = if name == 'manual' { .manual } else { .named }
	}
	return init
}

fn (mut host Host) install_shadow_roots() ! {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.fragment_prototype)
	host.shadow_root_prototype = prototype
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal ShadowRoot constructor') },
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object { return vm.throw_error(.type_error, 'Illegal ShadowRoot constructor') }, 0, libjs.PropertyName.from_str('ShadowRoot')).object
	mut global := host.realm.global_object_record()
	fragment := global.get(mut vm, libjs.PropertyName.from_str('DocumentFragment'))!
	if !constructor.internal_set_prototype_of(fragment.as_object()) { return error('Unable to set ShadowRoot interface ancestry') }
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('ShadowRoot')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('ShadowRoot'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	mut element := host.element_prototype
	host.method_attributes(mut element, 'attachShadow', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut native := host.element(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'attachShadow requires options') }
		persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
		init := host.shadow_root_options(mut vm, vm.argument(0))!
		mut owner := unsafe { &Host(host) }
		root := native.attach_shadow(init) or { return owner.dom_error(mut vm, err) }
		owner.changed()
		return owner.wrap_node(unsafe { &dom.Node(root) })
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	host.accessor(mut element, 'shadowRoot', fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.element(mut vm)!
		mut owner := unsafe { &Host(host) }
		return if root := native.shadow_root_for_bindings() { owner.wrap_node(unsafe { &dom.Node(root) }) } else { libjs.js_null() }
	}, unsafe { nil })
	for name in ['mode', 'delegatesFocus', 'serializable', 'slotAssignment', 'clonable', 'host', 'innerHTML'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			root := host.shadow_root_receiver(mut vm)!
			mut owner := unsafe { &Host(host) }
			return match name {
				'delegatesFocus' { libjs.Value.from_bool(root.delegates_focus()) }
				'serializable' { libjs.Value.from_bool(root.serializable()) }
				'clonable' { libjs.Value.from_bool(root.clonable()) }
				'host' { if native := root.host() { owner.wrap_node(native.as_node()) } else { libjs.js_null() } }
				'mode' { libjs.Value.from_string(vm.create_string_from_str(root.mode().str())) }
				'slotAssignment' { libjs.Value.from_string(vm.create_string_from_str(root.slot_assignment().str())) }
				else { libjs.Value.from_string(vm.create_string_from_str(root.inner_html() or { return owner.dom_error(mut vm, err) })) }
			}
		}, if name == 'innerHTML' { fn [host] (mut vm libjs.VM) !libjs.Value {
			mut root := host.shadow_root_receiver(mut vm)!
			persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
			text := if vm.argument(0).is_null() { '' } else { vm.argument(0).to_primitive_string(mut vm)!.str() }
			mut owner := unsafe { &Host(host) }
			root.set_inner_html(text) or { return owner.dom_error(mut vm, err) }
			owner.changed()
			return libjs.js_undefined()
		} } else { unsafe { nil } })
	}
}
