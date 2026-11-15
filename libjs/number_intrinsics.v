// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Install the translated Number constructor, predicates and exact radix/fixed
// methods into the actual realm. Decimal-exponential and Intl adapters remain
// separate dependencies; do not replace them with synthetic host callbacks.
fn initialize_number_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := NumberObject.create(&realm, 0, realm.object_prototype_record()).object
	realm.number_prototype = prototype
	for name, callback in {
		'toString': NativeFunctionPointer(number_prototype_to_string)
		'valueOf': number_prototype_value_of
		'toFixed': number_prototype_to_fixed
	} {
		install_intrinsic_method(mut vm, &realm, mut prototype, name, if name == 'valueOf' { 0 } else { 1 }, callback)
	}
	realm.parse_int_function = NativeFunction.create_raw(mut vm, &realm, realm.function_prototype, global_parse_int, 2, PropertyName.from_str('parseInt'), none).object
	realm.parse_float_function = NativeFunction.create_raw(mut vm, &realm, realm.function_prototype, global_parse_float, 1, PropertyName.from_str('parseFloat'), none).object
	constructor := NumberConstructor.create(mut vm, &realm, NumberConstructorDependencies{
		prototype: prototype
		prototype_getter: fn (realm &Realm) &Object { return realm.number_prototype or { panic('Missing Number prototype') } }
		parse_int: realm.parse_int_function or { panic('Missing parseInt intrinsic') }
		parse_float: realm.parse_float_function or { panic('Missing parseFloat intrinsic') }
	}).object
	realm.number_constructor = constructor
}
