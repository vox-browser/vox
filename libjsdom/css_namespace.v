// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import css
import libjs

// CSS.idl / CSS.cpp. Expose the native serializer and both supports overloads;
// support results come from the same CSS parser used by the document engine.
fn (mut host Host) install_css_namespace() {
	mut vm := host.vm
	mut namespace := libjs.Object.create(host.realm, host.realm.object_prototype)
	namespace.define_direct_property(libjs.PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), libjs.Value.from_string(vm.create_string_from_str('CSS')), libjs.attribute_configurable)
	attributes := libjs.attribute_writable | libjs.attribute_enumerable | libjs.attribute_configurable
	host.method_attributes(mut namespace, 'escape', 1, fn (mut vm libjs.VM) !libjs.Value {
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'CSS.escape requires an argument') }
		input := vm.argument(0).to_primitive_string(mut vm)!
		return libjs.Value.from_string(vm.create_string(libjs.utf16_string_from_code_units(css.serialize_an_identifier_utf16(input.utf16_string().code_units()))))
	}, attributes)
	host.method_attributes(mut namespace, 'supports', 1, fn (mut vm libjs.VM) !libjs.Value {
		if vm.argument_count() < 1 { return vm.throw_error(.type_error, 'CSS.supports requires an argument') }
		first := vm.argument(0).to_primitive_string(mut vm)!.str()
		if vm.argument_count() >= 2 {
			value := vm.argument(1).to_primitive_string(mut vm)!.str()
			return libjs.Value.from_bool(css.supports_property(first, value))
		}
		return libjs.Value.from_bool(css.supports_condition(first))
	}, attributes)
	mut global := host.realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('CSS'), libjs.Value.from_object(namespace), libjs.attribute_writable | libjs.attribute_configurable)
}
