// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import libjs
import platform

@[heap]
struct ComputedStyleIndices {
	host   &Host
	native &css.CSSStyleProperties
}

fn (indices &ComputedStyleIndices) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if indices.host.closed || !key.is_number() {
		return none
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if key.number >= u32(indices.native.length()) { return none }
	mut vm := indices.host.vm
	return libjs.PropertyDescriptor{ value: libjs.Value.from_string(vm.create_string_from_str(indices.native.item(uint(key.number)))), writable: false, enumerable: true, configurable: true }
}

fn (indices &ComputedStyleIndices) own_property_keys() []libjs.PropertyName {
	if indices.host.closed { return [] }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return []libjs.PropertyName{len: indices.native.length(), init: libjs.PropertyName.from_number(u32(index))}
}

fn (mut host Host) install_computed_styles() {
	mut global := host.realm.global_object_record()
	host.method_attributes(mut global, 'getComputedStyle', 1, fn [host] (mut vm libjs.VM) !libjs.Value {
		host.window_receiver(mut vm)!
		if vm.argument_count() == 0 {
			return vm.throw_error(.type_error, 'getComputedStyle requires an Element')
		}
		node := host.tree_node_argument(mut vm, vm.argument(0))!
		element := node.as_element() or { return vm.throw_error(.type_error, 'getComputedStyle requires an Element') }
		pseudo := if vm.argument(1).is_nullish() {
			?string(none)
		} else {
			?string(vm.argument(1).to_primitive_string(mut vm)!.str())
		}
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		mut owner := unsafe { &Host(host) }
		window := owner.frame_window(mut vm)!
		mut object := libjs.Object.create(host.realm, host.style_prototype)
		object.class_name = 'CSSStyleProperties'
		native := window.get_computed_style(element, pseudo)
		owner.computed_styles[voidptr(object)] = native
		object.host_properties = libjs.HostProperties(&ComputedStyleIndices{ host: owner, native: native })
		return libjs.Value.from_object(object)
	}, libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable)
}
