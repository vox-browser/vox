// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import geometry
import libjs
import platform

fn (mut host Host) wrap_dom_rect(native &geometry.DOMRect, prototype &libjs.Object) libjs.Value {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	value := host.wrap_read_only_rect(native.as_read_only(), prototype)
	host.dom_rects[voidptr(value.as_object())] = native
	mut object := value.as_object()
	object.class_name = 'DOMRect'
	return value
}

fn (host &Host) dom_rect_receiver(mut vm libjs.VM) !&geometry.DOMRect {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native := host.dom_rects[voidptr(vm.this_value().as_object())] { return native }
	}
	return vm.throw_error(.type_error, 'Expected DOMRect')
}

fn dom_rect_dictionary(mut vm libjs.VM, value libjs.Value) !geometry.DOMRectInit {
	if !value.is_nullish() && !value.is_object() {
		return vm.throw_error(.type_error, 'DOMRectInit must be a dictionary')
	}
	height := rect_number(mut vm, text_encoding_member(mut vm, value, 'height')!)!
	width := rect_number(mut vm, text_encoding_member(mut vm, value, 'width')!)!
	x := rect_number(mut vm, text_encoding_member(mut vm, value, 'x')!)!
	y := rect_number(mut vm, text_encoding_member(mut vm, value, 'y')!)!
	return geometry.DOMRectInit{ x: x, y: y, width: width, height: height }
}

@[heap]
struct ClientRectList {
	host   &Host
	native &geometry.DOMRectList
}

fn (list &ClientRectList) is_supported_property_index(index u32) bool {
	return !list.host.closed && index < list.native.length()
}

fn (list &ClientRectList) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if list.host.closed || !key.is_number() { return none }
	if native := list.native.item(key.number) {
		mut owner := unsafe { &Host(list.host) }
		return libjs.PropertyDescriptor{ value: owner.wrap_dom_rect(native, owner.dom_rect_prototype), writable: false, enumerable: true, configurable: false }
	}
	return none
}

fn (list &ClientRectList) own_property_keys() []libjs.PropertyName {
	if list.host.closed { return [] }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return []libjs.PropertyName{len: int(list.native.length()), init: libjs.PropertyName.from_number(u32(index))}
}

fn (host &Host) client_rect_list_receiver(mut vm libjs.VM) !&geometry.DOMRectList {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if provider := vm.this_value().as_object().host_properties {
			if provider is ClientRectList {
				if voidptr(provider.host) == voidptr(host) { return provider.native }
			}
		}
	}
	return vm.throw_error(.type_error, 'Expected DOMRectList')
}

fn (mut host Host) wrap_client_rect_list(rects []&geometry.DOMRect) libjs.Value {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, host.client_rect_list_prototype)
	object.class_name = 'DOMRectList'
	provider := &ClientRectList{ host: &host, native: geometry.DOMRectList.create(rects) }
	object.host_properties = libjs.HostProperties(provider)
	object.legacy_platform_object = libjs.LegacyPlatformObject{ indexed_properties: libjs.LegacyIndexedProperties(provider) }
	return libjs.Value.from_object(object)
}

fn (mut host Host) install_client_rects() ! {
	mut vm := host.vm
	mut global := host.realm.global_object_record()
	mut prototype := libjs.Object.create(host.realm, host.read_only_rect_prototype)
	host.dom_rect_prototype = prototype
	construct := fn [host] (mut vm libjs.VM, new_target &libjs.Object) !&libjs.Object {
		host.require_open(mut vm)!
		parent := new_target.get(mut vm, libjs.PropertyName.from_str('prototype'))!
		x := rect_number(mut vm, vm.argument(0))!
		y := rect_number(mut vm, vm.argument(1))!
		width := rect_number(mut vm, vm.argument(2))!
		height := rect_number(mut vm, vm.argument(3))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_dom_rect(geometry.DOMRect.construct(x, y, width, height), if parent.is_object() {
			parent.as_object()
		} else {
			host.dom_rect_prototype
		}).as_object()
	}
	host.closures << voidptr(construct)
	parent := global.get(mut vm, libjs.PropertyName.from_str('DOMRectReadOnly'))!.as_object()
	mut constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, parent,
		fn (mut vm libjs.VM) !libjs.Value {
			return vm.throw_error(.type_error, 'DOMRect requires new')
		}, construct, 0, libjs.PropertyName.from_str('DOMRect')).object
	constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(prototype), 0)
	prototype.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('DOMRect')), libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('DOMRect'), libjs.Value.from_object(constructor), libjs.attribute_writable | libjs.attribute_configurable)
	for name in ['x', 'y', 'width', 'height'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			return libjs.Value.from_f64(rect_coordinate(host.dom_rect_receiver(mut vm)!.as_read_only(), name))
		}, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.dom_rect_receiver(mut vm)!
			value := vm.argument(0).to_number(mut vm)!.number
			match name {
				'x' { native.set_x(value) }
				'y' { native.set_y(value) }
				'width' { native.set_width(value) }
				else { native.set_height(value) }
			}
			return libjs.js_undefined()
		})
	}
	host.method_attributes(mut constructor, 'fromRect', 0, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.require_open(mut vm)!
		init := dom_rect_dictionary(mut vm, vm.argument(0))!
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		return owner.wrap_dom_rect(geometry.DOMRect.from_rect(init), host.dom_rect_prototype)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut list := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.client_rect_list_prototype = list
	mut list_constructor := libjs.NativeFunction.create_constructor(mut vm, host.realm, host.realm.function_prototype,
		fn (mut vm libjs.VM) !libjs.Value {
			return vm.throw_error(.type_error, 'Illegal DOMRectList constructor')
		},
		fn (mut vm libjs.VM, _ &libjs.Object) !&libjs.Object {
			return vm.throw_error(.type_error, 'Illegal DOMRectList constructor')
		}, 0, libjs.PropertyName.from_str('DOMRectList')).object
	list_constructor.define_direct_property(libjs.PropertyName.from_str('prototype'), libjs.Value.from_object(list), 0)
	list.define_direct_property(libjs.PropertyName.from_str('constructor'), libjs.Value.from_object(list_constructor), libjs.attribute_writable | libjs.attribute_configurable)
	list.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('DOMRectList')), libjs.attribute_configurable)
	list.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_iterator()), host.realm.array_prototype_values, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	global.define_direct_property(libjs.PropertyName.from_str('DOMRectList'), libjs.Value.from_object(list_constructor), libjs.attribute_writable | libjs.attribute_configurable)
	host.accessor(mut list, 'length', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_f64(f64(host.client_rect_list_receiver(mut vm)!.length()))
	}, unsafe { nil })
	host.method_attributes(mut list, 'item', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		list := host.client_rect_list_receiver(mut vm)!
		if vm.argument_count() == 0 { return vm.throw_error(.type_error, 'item requires an index') }
		index := vm.argument(0).to_u32(mut vm)!
		mut owner := unsafe { &Host(host) }
		return if native := list.item(index) {
			owner.wrap_dom_rect(native, host.dom_rect_prototype)
		} else {
			libjs.js_null()
		}
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	mut element := host.element_prototype
	for name in ['getBoundingClientRect', 'getClientRects'] {
		host.method_attributes(mut element, name, 0, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.element(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			mut owner := unsafe { &Host(host) }
			if name == 'getBoundingClientRect' {
				r := native.get_bounding_client_rect()
				return owner.wrap_dom_rect(geometry.DOMRect.construct(r.x, r.y, r.width, r.height), host.dom_rect_prototype)
			}
			mut rects := []&geometry.DOMRect{}
			for r in native.get_client_rects() {
				rects << geometry.DOMRect.construct(r.x_, r.y_, r.width(), r.height())
			}
			return owner.wrap_client_rect_list(rects)
		}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
	}
}
