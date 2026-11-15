// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/{Generator,AsyncGenerator}FunctionPrototype.cpp and the prototype
// ancestry in Intrinsics.cpp. Dynamic constructors and resume operations are
// separate translations; creating a function never executes its body.
fn initialize_generator_creation_intrinsics(mut vm VM, mut realm Realm) {
	mut async_iterator := Object.create(realm, realm.object_prototype)
	realm.async_iterator_prototype = async_iterator
	key := PropertyName.from_symbol(vm.well_known_symbol_async_iterator())
	identity := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.this_value() }, 0, key, none)
	async_iterator.define_direct_property(key, Value.from_object(identity.object), attribute_writable | attribute_configurable)
	for asynchronous in [false, true] {
		mut function := Object.create(realm, realm.function_prototype)
		mut generator := Object.create(realm, if asynchronous { realm.async_iterator_prototype } else { realm.iterator_prototype })
		function.define_direct_property(PropertyName.from_str('prototype'), Value.from_object(generator), attribute_configurable)
		function.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
			Value.from_string(vm.create_string_from_str(if asynchronous { 'AsyncGeneratorFunction' } else { 'GeneratorFunction' })), attribute_configurable)
		generator.define_direct_property(PropertyName.from_str('constructor'), Value.from_object(function), attribute_configurable)
		generator.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
			Value.from_string(vm.create_string_from_str(if asynchronous { 'AsyncGenerator' } else { 'Generator' })), attribute_configurable)
		if asynchronous {
			realm.async_generator_function_prototype = function
			realm.async_generator_prototype = generator
		} else {
			realm.generator_function_prototype = function
			realm.generator_prototype = generator
		}
	}
}
