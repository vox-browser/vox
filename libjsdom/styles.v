// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import dom
import libjs
import platform

// ElementCSSInlineStyle and CSSStyle{Declaration,Properties} IDL bindings.
// Every operation reaches the element's retained native declaration block;
// script wrappers never keep a parallel copy of the style attribute.
fn (mut host Host) install_styles() {
	mut prototype := libjs.Object.create(host.realm, host.realm.object_prototype)
	host.style_prototype = prototype
	mut vm := host.vm
	prototype.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('CSSStyleProperties')), libjs.attribute_configurable)
	host.accessor(mut prototype, 'cssText', fn [host] (mut vm libjs.VM) !libjs.Value {
		return libjs.Value.from_string(vm.create_string_from_str(host.style_receiver(mut vm)!.css_text()))
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut style := host.style_receiver(mut vm)!
		mut owner := unsafe { &Host(host) }
		style.set_css_text(vm.argument(0).to_primitive_string(mut vm)!.str()) or { return owner.dom_error(mut vm,err) }
		owner.changed()
		return libjs.js_undefined()
	})
	host.accessor(mut prototype, 'length', fn [host] (mut vm libjs.VM) !libjs.Value { return libjs.Value.from_i32(i32(host.style_receiver(mut vm)!.length())) }, unsafe { nil })
	host.accessor(mut prototype, 'parentRule', fn [host] (mut vm libjs.VM) !libjs.Value {
		host.style_receiver(mut vm)!
		return libjs.js_null()
	}, unsafe { nil })
	for name in ['item', 'getPropertyValue', 'getPropertyPriority', 'setProperty', 'removeProperty'] {
		host.method(mut prototype, name, if name == 'setProperty' { 2 } else { 1 }, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut style := host.style_receiver(mut vm)!
			if vm.argument_count() < if name == 'setProperty' { 2 } else { 1 } { return vm.throw_error(.type_error, 'CSSStyleDeclaration.${name} requires more arguments') }
			if name == 'item' { return libjs.Value.from_string(vm.create_string_from_str(style.item(uint(vm.argument(0).to_u32(mut vm)!)))) }
			property := vm.argument(0).to_primitive_string(mut vm)!.str()
			match name {
				'getPropertyValue' { return libjs.Value.from_string(vm.create_string_from_str(style.get_property_value(property))) }
				'getPropertyPriority' { return libjs.Value.from_string(vm.create_string_from_str(style.get_property_priority(property))) }
				'removeProperty' {
					mut owner := unsafe { &Host(host) }
					removed := style.remove_property(property) or { return owner.dom_error(mut vm,err) }
					owner.changed()
					return libjs.Value.from_string(vm.create_string_from_str(removed))
				}
				else {
					value := if vm.argument(1).is_null() { '' } else { vm.argument(1).to_primitive_string(mut vm)!.str() }
					priority := if vm.argument(2).is_nullish() { '' } else { vm.argument(2).to_primitive_string(mut vm)!.str() }
					mut owner := unsafe { &Host(host) }
					style.set_property(property, value, priority) or { return owner.dom_error(mut vm,err) }
					owner.changed()
					return libjs.js_undefined()
				}
			}
		})
	}
	mut names := []string{}
	$for member in css.PropertyID.values {
		names << css.string_from_property_id(css.PropertyID(member.value))
	}
	for css_name in names {
		mut aliases := [css_name]
		camel := css_property_camel_case(css_name)
		if camel != css_name { aliases << camel }
		if css_name.starts_with('-webkit-') { aliases << css_property_camel_case(css_name[1..]) }
		if css_name == 'float' { aliases << 'cssFloat' }
		for name in aliases {
			host.accessor_attributes(mut prototype, name, fn [host, css_name] (mut vm libjs.VM) !libjs.Value {
				return libjs.Value.from_string(vm.create_string_from_str(host.style_receiver(mut vm)!.get_property_value(css_name)))
			}, fn [host, css_name] (mut vm libjs.VM) !libjs.Value {
				mut style := host.style_receiver(mut vm)!
				value := if vm.argument(0).is_null() { '' } else { vm.argument(0).to_primitive_string(mut vm)!.str() }
				mut owner := unsafe { &Host(host) }
				style.set_property(css_name, value, '') or { return owner.dom_error(mut vm,err) }
				owner.changed()
				return libjs.js_undefined()
			}, if name == 'cssFloat' { libjs.attribute_enumerable | libjs.attribute_configurable } else { libjs.attribute_configurable })
		}
	}
	mut element := host.element_prototype
	host.accessor(mut element, 'style', fn [host] (mut vm libjs.VM) !libjs.Value {
		actual := host.element(mut vm)!
		mut owner := unsafe { &Host(host) }
		return owner.wrap_style(actual)
	}, fn [host] (mut vm libjs.VM) !libjs.Value {
		mut style := css.element_style(host.element(mut vm)!)
		style.set_css_text(vm.argument(0).to_primitive_string(mut vm)!.str())!
		mut owner := unsafe { &Host(host) }
		owner.changed()
		return libjs.js_undefined()
	})
}

fn css_property_camel_case(name string) string {
	mut result := []u8{cap: name.len}
	mut uppercase := false
	for ch in name.bytes() {
		if ch == `-` { uppercase = true; continue }
		result << if uppercase && ch >= `a` && ch <= `z` { ch - 32 } else { ch }
		uppercase = false
	}
	return result.bytestr()
}

fn (host &Host) style_receiver(mut vm libjs.VM) !&css.CSSStyleProperties {
	host.require_open(mut vm)!
	if vm.this_value().is_object() {
		if native:=host.computed_styles[voidptr(vm.this_value().as_object())] { return native }
		if element := host.style_elements[voidptr(vm.this_value().as_object())] { return css.element_style(element) }
	}
	return vm.throw_error(.type_error, 'CSSStyleDeclaration method called on incompatible receiver')
}

fn (mut host Host) wrap_style(element &dom.Element) libjs.Value {
	if wrapper := host.style_wrappers[element.unique_id()] { return libjs.Value.from_object(wrapper) }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut object := libjs.Object.create(host.realm, host.style_prototype)
	object.class_name = 'CSSStyleProperties'
	object.host_properties = libjs.HostProperties(&StyleIndices{ host: host, element: element })
	host.style_wrappers[element.unique_id()] = object
	host.style_elements[voidptr(object)] = element
	return libjs.Value.from_object(object)
}

@[heap]
struct StyleIndices {
	host &Host
	element &dom.Element
}

fn (indices &StyleIndices) get_own_property(key libjs.PropertyName) ?libjs.PropertyDescriptor {
	if indices.host.closed || indices.host.document.has_been_destroyed() || !key.is_number() { return none }
	style := css.element_style(indices.element)
	if key.number >= u32(style.length()) { return none }
	mut vm := indices.host.vm
	return libjs.PropertyDescriptor{ value: libjs.Value.from_string(vm.create_string_from_str(style.item(uint(key.number)))), writable: false, enumerable: true, configurable: true }
}

fn (indices &StyleIndices) own_property_keys() []libjs.PropertyName {
	if indices.host.closed || indices.host.document.has_been_destroyed() { return [] }
	return []libjs.PropertyName{ len: css.element_style(indices.element).length(), init: libjs.PropertyName.from_number(u32(index)) }
}
