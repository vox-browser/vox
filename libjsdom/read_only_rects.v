// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import geometry
import libjs
import platform

fn (mut host Host) wrap_read_only_rect(native &geometry.DOMRectReadOnly, prototype &libjs.Object) libjs.Value {
	if object := host.read_only_rect_wrappers[voidptr(native)] { return libjs.Value.from_object(object) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, prototype)
	object.class_name = 'DOMRectReadOnly'
	host.read_only_rects[voidptr(object)] = native
	host.read_only_rect_wrappers[voidptr(native)] = object
	return libjs.Value.from_object(object)
}

fn (host &Host) read_only_rect_receiver(mut vm libjs.VM) !&geometry.DOMRectReadOnly {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.read_only_rects[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'DOMRectReadOnly member called on incompatible receiver')
}

fn rect_coordinate(native &geometry.DOMRectReadOnly, name string) f64 {
	return match name {
		'x' { native.x() }
		'y' { native.y() }
		'width' { native.width() }
		'height' { native.height() }
		'top' { native.top() }
		'right' { native.right() }
		'bottom' { native.bottom() }
		else { native.left() }
	}
}

fn rect_number(mut vm libjs.VM, value libjs.Value) !f64 {
	return if value.is_undefined() { 0.0 } else { value.to_number(mut vm)!.number }
}

// Geometry/DOMRectReadOnly.idl. The wrapper owns the translated geometry record;
// dictionary coercion follows WebIDL's lexicographic member order.
fn (mut host Host) install_read_only_rects() {
	mut vm := host.vm
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.read_only_rect_prototype = prototype
	for name in ['x', 'y', 'width', 'height', 'top', 'right', 'bottom', 'left'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			return libjs.Value.from_f64(rect_coordinate(host.read_only_rect_receiver(mut vm)!, name))
		}, unsafe { nil })
	}
	host.method_attributes(mut prototype, 'toJSON', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		native := host.read_only_rect_receiver(mut vm)!
		mut object := libjs.Object.create(host.realm, host.realm.object_prototype)
		for name in ['x', 'y', 'width', 'height', 'top', 'right', 'bottom', 'left'] {
			object.create_data_property_or_throw(mut vm, libjs.PropertyName.from_str(name), libjs.Value.from_f64(rect_coordinate(native, name)))!
		}
		return libjs.Value.from_object(object)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		x := rect_number(mut vm, vm.argument(0))!
		y := rect_number(mut vm, vm.argument(1))!
		width := rect_number(mut vm, vm.argument(2))!
		height := rect_number(mut vm, vm.argument(3))!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_read_only_rect(geometry.DOMRectReadOnly.construct_impl(x, y, width, height), if parent.is_object() { parent.as_object() } else { host.read_only_rect_prototype }).as_object()
	}
	host.closures << voidptr(construct)
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value { return vm.throw_error(.type_error, 'DOMRectReadOnly constructor requires new') }, construct, 0, libjs.PropertyName.from_str('DOMRectReadOnly')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('DOMRectReadOnly')), libjs.attribute_configurable)
	host.method_attributes(mut constructor, 'fromRect', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		value := vm.argument(0)
		if !value.is_nullish() && !value.is_object() { return vm.throw_error(.type_error, 'DOMRectInit must be a dictionary') }
		mut options := geometry.DOMRectInit{}
		if value.is_object() {
			object := value.as_object()
			options.height = rect_number(mut vm, object.get(mut vm, libjs.PropertyName.from_str('height'))!)!
			options.width = rect_number(mut vm, object.get(mut vm, libjs.PropertyName.from_str('width'))!)!
			options.x = rect_number(mut vm, object.get(mut vm, libjs.PropertyName.from_str('x'))!)!
			options.y = rect_number(mut vm, object.get(mut vm, libjs.PropertyName.from_str('y'))!)!
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_read_only_rect(geometry.DOMRectReadOnly.dom_rect_read_only_from_rect(options), host.read_only_rect_prototype)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('DOMRectReadOnly'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
}
