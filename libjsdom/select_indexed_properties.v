// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

@[heap]
struct OptionIndexedSetter {
	host &Host
	native &html.HTMLOptionsCollection
}

fn (setter &OptionIndexedSetter) set_indexed_property(mut vm libjs.VM, index u32, value libjs.Value) ! {
	setter.host.set_indexed_option(mut vm, setter.native, index, value)!
}

fn (host &Host) set_indexed_option(mut vm libjs.VM, native &html.HTMLOptionsCollection, index u32, value libjs.Value) ! {
	host.require_open(mut vm)!
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	mut option := ?&dom.HTMLOptionElement(none)
	if !value.is_nullish() {
		element := host.form_data_element(mut vm, value, false)!
		if element.local_name() != 'option' { return vm.throw_error(.type_error, 'Indexed option values must be HTMLOptionElement or null') }
		option = unsafe { &dom.HTMLOptionElement(element) }
	}
	mut owner := unsafe { &Host(host) }
	defer { owner.finish_form_mutation() }
	native.set_value_of_indexed_property(index, option) or { return owner.dom_error(mut vm, err) }
}

// Select's indexed getter/setter are native operations on its option owner.
// Keep the owner lazy, just as ordinary select IDL access does.
@[heap]
struct SelectElementIndices {
	host &Host
	element &dom.Element
}

fn (indices &SelectElementIndices) options() &html.HTMLOptionsCollection {
	mut model := prepare_libjs_select(indices.element)
	return model.options()
}

fn (indices &SelectElementIndices) is_supported_property_index(index u32) bool {
	if indices.host.closed { return false }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	return u64(index) < u64(indices.options().length())
}

fn (indices &SelectElementIndices) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if indices.host.closed || !key.is_number() { return none }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	option := indices.options().item(key.number) or { return none }
	mut owner := unsafe { &Host(indices.host) }
	return libjs.PropertyDescriptor{value: owner.wrap_node(unsafe { &dom.Element(option) }.as_node()), writable: true, enumerable: true, configurable: true}
}

fn (indices &SelectElementIndices) own_property_keys() []libjs.PropertyName {
	if indices.host.closed { return [] }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	return []libjs.PropertyName{len: int(indices.options().length()), init: libjs.PropertyName.from_number(u32(index))}
}

fn (indices &SelectElementIndices) set_indexed_property(mut vm libjs.VM, index u32, value libjs.Value) ! {
	indices.host.require_open(mut vm)!
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	indices.host.set_indexed_option(mut vm, indices.options(), index, value)!
}

fn (host &Host) attach_select_indices(mut object libjs.Object, element &dom.Element) {
	provider := &SelectElementIndices{host: host, element: element}
	object.host_properties = libjs.HostProperties(provider)
	object.legacy_platform_object = libjs.LegacyPlatformObject{indexed_properties: libjs.LegacyIndexedProperties(provider), indexed_setter: libjs.LegacyIndexedPropertySetter(provider)}
}
