// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import platform

@[heap]
struct FormElementProperties {
	host &Host
	element &dom.Element
}

fn (properties &FormElementProperties) native() &html.HTMLFormElementModel {
	mut native := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(properties.element) })
	// Model creation and owner association are lazy. Discover untouched controls
	// before observing the form's supported names or indexed view.
	native.elements().length()
	return native
}

fn (properties &FormElementProperties) is_supported_property_index(index u32) bool {
	if properties.host.closed { return false }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	return u64(index) < u64(properties.native().length())
}

fn (properties &FormElementProperties) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if properties.host.closed || !key.is_number() { return none }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	mut native := properties.native()
	element := native.elements().item(int(key.number)) or { return none }
	mut owner := unsafe { &Host(properties.host) }
	return libjs.PropertyDescriptor{value: owner.wrap_node(element.as_node()), writable: false, enumerable: true, configurable: true}
}

fn (properties &FormElementProperties) own_property_keys() []libjs.PropertyName {
	if properties.host.closed { return [] }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	return []libjs.PropertyName{len: int(properties.native().length()), init: libjs.PropertyName.from_number(u32(index))}
}

fn (properties &FormElementProperties) is_supported_property_name(name libjs.Utf16String) bool {
	if properties.host.closed || name.str() == '' { return false }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	return properties.native().is_supported_property_name(name.str())
}

fn (properties &FormElementProperties) named_property_value(name libjs.Utf16String) libjs.Value {
	if properties.host.closed { return libjs.js_undefined() }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	mut native := properties.native()
	mut owner := unsafe { &Host(properties.host) }
	return owner.wrap_form_named_item(native.named_item_value(name.str()))
}

fn (properties &FormElementProperties) supported_property_names() []libjs.Utf16String {
	if properties.host.closed { return [] }
	persistent := platform.enter_persistent(); defer { platform.leave_persistent(persistent) }
	return properties.native().supported_property_names().map(libjs.utf16_string(it))
}

fn (host &Host) attach_form_properties(mut object libjs.Object, element &dom.Element) {
	provider := &FormElementProperties{host: host, element: element}
	object.host_properties = libjs.HostProperties(provider)
	object.legacy_platform_object = libjs.LegacyPlatformObject{indexed_properties: libjs.LegacyIndexedProperties(provider), named_properties: libjs.LegacyNamedProperties(provider), legacy_override_builtins: true, legacy_unenumerable_named_properties: true}
}
