// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import libjs
import webidl

fn (mut host Host) wrap_dom_exception(native &webidl.DOMException, prototype &libjs.Object) libjs.Value {
	object := libjs.Object.create(host.realm, prototype)
	host.dom_exceptions[voidptr(object)] = native
	return libjs.Value.from_object(object)
}

// Preserve author-thrown values. Native DOM algorithm errors use their WebIDL
// exception name; ECMAScript conversion errors remain ordinary TypeErrors.
fn (mut host Host) dom_error(mut vm libjs.VM, err IError) IError {
	if libjs.is_throw_completion(err) { return err }
	message := err.msg()
	if message.starts_with('TypeError:') { return vm.throw_error(.type_error, message.all_after('TypeError:').trim_space()) }
	if message.contains(':') {
		return libjs.throw_completion(host.wrap_dom_exception(webidl.DOMException.create_record(message.all_before(':'), message.all_after(':').trim_space()), host.dom_exception_prototype))
	}
	return err
}

fn (mut host Host) install_dom_exceptions() ! {
	mut vm := host.vm
	error_prototype := host.realm.error_prototypes[.error] or { return error('Missing intrinsic Error prototype') }
	mut prototype := libjs.Object.create(host.realm, error_prototype)
	host.dom_exception_prototype = prototype
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('DOMException')), libjs.attribute_configurable)
	for name in ['name', 'message', 'code'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			host.require_open(mut vm)!
			if vm.this_value().is_object() {
				if native := host.dom_exceptions[voidptr(vm.this_value().as_object())] {
					return match name {
						'name' { libjs.Value.from_string(vm.create_string(native.name_utf16())) }
						'message' { libjs.Value.from_string(vm.create_string(native.message_utf16())) }
						else { libjs.Value.from_i32(i32(native.code())) }
					}
				}
			}
			return vm.throw_error(.type_error, 'DOMException property called on incompatible receiver')
		}, unsafe { nil })
	}
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		message := if vm.argument(0).is_undefined() { libjs.utf16_string('') } else { vm.argument(0).to_primitive_string(mut vm)!.utf16 }
		name := if vm.argument(1).is_undefined() { libjs.utf16_string('Error') } else { vm.argument(1).to_primitive_string(mut vm)!.utf16 }
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_dom_exception(webidl.DOMException.create_utf16_record(name, message), if parent.is_object() { parent.as_object() } else { host.dom_exception_prototype }).as_object()
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'DOMException constructor requires new') },
		construct, 0, libjs.PropertyName.from_str('DOMException')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for index, name in ['INDEX_SIZE_ERR', 'DOMSTRING_SIZE_ERR', 'HIERARCHY_REQUEST_ERR', 'WRONG_DOCUMENT_ERR', 'INVALID_CHARACTER_ERR', 'NO_DATA_ALLOWED_ERR', 'NO_MODIFICATION_ALLOWED_ERR', 'NOT_FOUND_ERR', 'NOT_SUPPORTED_ERR', 'INUSE_ATTRIBUTE_ERR', 'INVALID_STATE_ERR', 'SYNTAX_ERR', 'INVALID_MODIFICATION_ERR', 'NAMESPACE_ERR', 'INVALID_ACCESS_ERR', 'VALIDATION_ERR', 'TYPE_MISMATCH_ERR', 'SECURITY_ERR', 'NETWORK_ERR', 'ABORT_ERR', 'URL_MISMATCH_ERR', 'QUOTA_EXCEEDED_ERR', 'TIMEOUT_ERR', 'INVALID_NODE_TYPE_ERR', 'DATA_CLONE_ERR'] {
		value := libjs.Value.from_i32(i32(index + 1))
		constructor.define_direct_property(libjs.PropertyName.from_str(name), value, libjs.attribute_enumerable)
		prototype.define_direct_property(libjs.PropertyName.from_str(name), value, libjs.attribute_enumerable)
	}
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('DOMException'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
}
