// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Install the existing native BigInt algorithms in the actual realm. Its
// prototype is ordinary and has no BigIntData slot. Raw callbacks keep the
// formatter and realm out of the permanent V closure-trampoline registry.
fn initialize_bigint_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.bigint_prototype = prototype
	for name, callback in {
		'toString': NativeFunctionPointer(bigint_prototype_to_string)
		'toLocaleString': bigint_prototype_to_intl_locale_string
		'valueOf': bigint_prototype_value_of
	} { install_intrinsic_method(mut vm, realm, mut prototype, name, 0, callback) }
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()), Value.from_string(vm.create_string_from_str('BigInt')), attribute_configurable)
	realm.bigint_constructor = BigIntConstructor.create(mut vm, realm, prototype).object
}

fn bigint_prototype_to_intl_locale_string(mut vm VM) !Value {
	bigint := this_bigint_value(mut vm, vm.this_value())!
	constructor := vm.realm().intl_number_format_constructor or { return vm.throw_error(.internal_error, 'Missing Intl.NumberFormat') }
	object := construct(mut vm, Value.from_object(constructor), [vm.argument(0), vm.argument(1)], none)!
	formatter := object.slots.intl_number_format or { return vm.throw_error(.internal_error, 'Missing Intl.NumberFormat slots') }
	return intl_number_parts_string(mut vm, intl_format_number_parts(mut vm, formatter, intl_mathematical_value(mut vm, Value.from_bigint(bigint))!)!)
}
