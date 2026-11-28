// SPDX-License-Identifier: BSD-2-Clause
module libjs

// PromiseConstructor.cpp::with_resolvers. The generic capability supplies all
// three values; do not manufacture a builtin promise for custom constructors.
fn promise_constructor_with_resolvers(mut vm VM) !Value {
	capability := new_promise_capability(mut vm, vm.this_value())!
	mut object := Object.create(vm.realm(), vm.realm().object_prototype)
	object.create_data_property_or_throw(mut vm, PropertyName.from_str('promise'), capability.promise)!
	object.create_data_property_or_throw(mut vm, PropertyName.from_str('resolve'), capability.resolve)!
	object.create_data_property_or_throw(mut vm, PropertyName.from_str('reject'), capability.reject)!
	return Value.from_object(object)
}
