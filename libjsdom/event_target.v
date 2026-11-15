// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

// DOM/EventTarget.idl. Standalone targets use the same native dispatcher and
// listener adapters as Node and Window; subclass instances retain newTarget.
fn (mut host Host) install_event_target_interface() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.event_target_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.event_target_prototype })
		object.class_name = 'EventTarget'
		native := dom.EventTarget.construct_impl()!
		mut owner := unsafe { &Host(host) }
		owner.event_targets[voidptr(object)] = native
		owner.event_target_wrappers[voidptr(native)] = object
		return object
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'EventTarget constructor requires new') },
		construct, 0, libjs.PropertyName.from_str('EventTarget')).object
	host.event_target_constructor = constructor
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('EventTarget')), libjs.attribute_configurable)
	host.install_event_target_methods(mut prototype)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('EventTarget'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
}
