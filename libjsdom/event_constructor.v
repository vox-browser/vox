// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs

// DOM/Event.idl and Event::construct_impl. Retain actual native Event records
// in the same identity map used by browser-dispatched callbacks. The host's
// current Event prototype supplies the non-object newTarget.prototype fallback;
// cross-realm WebIDL prototype selection remains separate binding work.
fn (mut host Host) install_event_constructor(mut prototype libjs.Object) {
	mut vm := host.vm
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'Event constructor requires a type') }
		type_ := vm.argument(0).to_primitive_string(mut vm)!.str()
		options := vm.argument(1)
		mut init := dom.EventInit{}
		if !options.is_nullish() {
			if !options.is_object() { return vm.throw_error(.type_error, 'EventInit must be an object') }
			dictionary := options.as_object()
			init = dom.EventInit{
				bubbles: dictionary.get(mut vm, libjs.PropertyName.from_str('bubbles'))!.to_boolean()
				cancelable: dictionary.get(mut vm, libjs.PropertyName.from_str('cancelable'))!.to_boolean()
				composed: dictionary.get(mut vm, libjs.PropertyName.from_str('composed'))!.to_boolean()
			}
		}
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut object := libjs.Object.create(host.realm, if parent.is_object() { parent.as_object() } else { host.event_prototype })
		native := dom.Event.construct_impl(type_, init) or { return vm.throw_error(.internal_error, err.msg()) }
		mut owner := unsafe { &Host(host) }
		return owner.register_event_wrapper(mut object, native).as_object()
	}
	host.closures << voidptr(construct)
	function := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Event constructor requires new') },
		construct, 1, libjs.PropertyName.from_str('Event'))
	mut constructor := function.object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor),
		libjs.attribute_writable | libjs.attribute_configurable)
	for index, name in ['NONE', 'CAPTURING_PHASE', 'AT_TARGET', 'BUBBLING_PHASE'] {
		constructor.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_i32(index), libjs.attribute_enumerable)
		prototype.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_i32(index), libjs.attribute_enumerable)
	}
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('Event'), libjs.Value.from_object(constructor),
		libjs.attribute_writable | libjs.attribute_configurable)
}
