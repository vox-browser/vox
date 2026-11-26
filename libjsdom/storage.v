// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform

@[heap]
struct StorageBinding {
	host   &Host
	native &html.Storage
	object &libjs.Object
}

fn (binding &StorageBinding) is_supported_property_name(name libjs.Utf16String) bool {
	if binding.host.closed { return false }
	_ = binding.native.get_item(name.str()) or { return false }
	return true
}

fn (binding &StorageBinding) named_property_value(name libjs.Utf16String) libjs.Value {
	if binding.host.closed { return libjs.js_undefined() }
	value := binding.native.get_item(name.str()) or { return libjs.js_undefined() }
	return libjs.Value.from_string(binding.host.vm.create_string(libjs.utf16_string_from_utf8_without_validation(value)))
}

fn (binding &StorageBinding) supported_property_names() []libjs.Utf16String {
	if binding.host.closed { return [] }
	return binding.native.supported_property_names().map(libjs.utf16_string_from_utf8_without_validation(it))
}

fn (binding &StorageBinding) set_named_property(mut vm libjs.VM, name libjs.Utf16String, value libjs.Value) ! {
	binding.host.require_open(mut vm)!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	text := value.to_primitive_string(mut vm)!.str()
	mut native := binding.native
	mut host := unsafe { &Host(binding.host) }
	native.set_item(name.str(), text) or { return host.dom_error(mut vm, err) }
}

fn (binding &StorageBinding) delete_named_property(mut vm libjs.VM, name libjs.Utf16String) !bool {
	binding.host.require_open(mut vm)!
	mut native := binding.native
	native.remove_item(name.str())
	return true
}

fn (host &Host) storage_receiver(mut vm libjs.VM) !&StorageBinding {
	host.require_open(mut vm)!
	receiver := vm.this_value()
	if receiver.is_object() {
		object := receiver.as_object()
		if binding := host.session_storage_binding {
			if voidptr(object) == voidptr(binding.object) { return binding }
		}
		if binding := host.local_storage_binding {
			if voidptr(object) == voidptr(binding.object) { return binding }
		}
	}
	return vm.throw_error(.type_error, 'Storage member called on incompatible receiver')
}

fn (mut host Host) install_storage() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		libjs.Value.from_string(vm.create_string_from_str('Storage')), libjs.attribute_configurable)
	construct := fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
		return vm.throw_error(.type_error, 'Illegal Storage constructor')
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'Illegal Storage constructor') },
		construct, 0, libjs.PropertyName.from_str('Storage')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor),
		libjs.attribute_writable | libjs.attribute_configurable)

	host.accessor(mut prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value {
		binding := host.storage_receiver(mut vm)!
		return libjs.Value.from_f64(f64(binding.native.length()))
	}, unsafe { nil })
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	methods := {'key': 1, 'getItem': 1, 'setItem': 2, 'removeItem': 1, 'clear': 0}
	for name, arity in methods {
		host.method_attributes(mut prototype, name, arity, fn [host, name, arity] (mut vm libjs.VM) !libjs.Value {
			binding := host.storage_receiver(mut vm)!
			if vm.argument_count() < u32(arity) {
				return vm.throw_error(.type_error, 'Storage.' + name + ' requires arguments')
			}
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut native := binding.native
			match name {
				'key', 'getItem' {
					value := if name == 'key' {
						native.key(uint(vm.argument(0).to_u32(mut vm)!))
					} else {
						native.get_item(vm.argument(0).to_primitive_string(mut vm)!.str())
					}
					return if text := value {
						libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_utf8_without_validation(text)))
					} else {
						libjs.js_null()
					}
				}
				'setItem' {
					key := vm.argument(0).to_primitive_string(mut vm)!.str()
					value := vm.argument(1).to_primitive_string(mut vm)!.str()
					mut owner := unsafe { &Host(host) }
					native.set_item(key, value) or { return owner.dom_error(mut vm, err) }
				}
				'removeItem' { native.remove_item(vm.argument(0).to_primitive_string(mut vm)!.str()) }
				else { native.clear() }
			}
			return libjs.js_undefined()
		}, attributes)
	}
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('Storage'), libjs.Value.from_object(constructor),
		libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut global, 'localStorage', fn [host, prototype] (mut vm libjs.VM) !libjs.Value {
		mut owner := unsafe { &Host(host) }
		return owner.window_storage(mut vm, prototype, .local)
	}, unsafe { nil })
	host.accessor(mut global, 'sessionStorage', fn [host, prototype] (mut vm libjs.VM) !libjs.Value {
		mut owner := unsafe { &Host(host) }
		return owner.window_storage(mut vm, prototype, .session)
	}, unsafe { nil })
}

fn (mut host Host) window_storage(mut vm libjs.VM, prototype &libjs.Object, type_ html.StorageType) !libjs.Value {
	host.window_receiver(mut vm)!
	if type_ == .local {
		if binding := host.local_storage_binding { return libjs.Value.from_object(binding.object) }
	} else if binding := host.session_storage_binding {
		return libjs.Value.from_object(binding.object)
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut window := host.frame_window(mut vm)!
	native := if type_ == .local {
		window.local_storage() or { return host.dom_error(mut vm, err) }
	} else {
		window.session_storage() or { return host.dom_error(mut vm, err) }
	}
	mut object := libjs.Object.create(host.realm, prototype)
	object.class_name = 'Storage'
	binding := &StorageBinding{host: host, native: native, object: object}
	object.legacy_platform_object = &libjs.LegacyPlatformObject{
		named_properties: libjs.LegacyNamedProperties(binding)
		named_setter: libjs.LegacyNamedPropertySetter(binding)
		named_deleter: libjs.LegacyNamedPropertyDeleter(binding)
	}
	if type_ == .local {
		host.local_storage_binding = binding
	} else {
		host.session_storage_binding = binding
	}
	return libjs.Value.from_object(object)
}
