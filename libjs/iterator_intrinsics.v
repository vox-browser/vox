// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Intrinsics.cpp, IteratorPrototype.cpp, ArrayPrototype.cpp and
// StringPrototype.cpp. Install the translated Array/String iterator records
// in their owning realm; iterator helpers and the Iterator constructor remain
// separate work.
fn initialize_iterator_intrinsics(mut vm VM, mut realm Realm) {
	mut prototype := Object.create(realm, realm.object_prototype)
	realm.iterator_prototype = prototype
	identity := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value { return vm.this_value() }, 0,
		PropertyName.from_symbol(vm.well_known_symbol_iterator()), none)
	prototype.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		Value.from_object(identity.object), attribute_writable | attribute_configurable)
	realm.array_iterator_prototype = ArrayIteratorPrototype.create(mut vm, realm, prototype,
		realm.array_prototype_record(), realm.object_prototype).object
	realm.string_iterator_prototype = StringIteratorPrototype.create(mut vm, realm, prototype,
		realm.object_prototype).object
	mut array := realm.array_prototype_record()
	for name, kind in {
		'keys':    PropertyKind.key
		'values':  .value
		'entries': .key_and_value
	} {
		function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
			fn [kind] (mut vm VM) !Value {
				target := vm.this_value().to_object_with_prototypes(mut vm, realm_primitive_prototypes())!
				return Value.from_object(ArrayIterator.create(vm.realm(), Value.from_object(target), kind,
					vm.realm().array_iterator_prototype or { panic('Missing Array iterator prototype') }).object)
			}, 0, PropertyName.from_str(name), none)
		array.define_direct_property(PropertyName.from_str(name), Value.from_object(function.object),
			attribute_writable | attribute_configurable)
		if kind == .value {
			realm.array_prototype_values = Value.from_object(function.object)
			array.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
				Value.from_object(function.object), attribute_writable | attribute_configurable)
		}
	}
	mut text := realm.string_prototype or { panic('Missing String prototype') }
	function := NativeFunction.create_raw(mut vm, realm, realm.function_prototype,
		fn (mut vm VM) !Value {
			value := vm.this_value()
			if value.is_nullish() {
				return vm.throw_error_type(.type_error, .to_object_null_or_undefined)
			}
			text := value.to_primitive_string(mut vm)!
			return Value.from_object(StringIterator.create(vm.realm(), text.utf16,
				vm.realm().string_iterator_prototype or { panic('Missing String iterator prototype') }).object)
		}, 0, PropertyName.from_symbol(vm.well_known_symbol_iterator()), none)
	text.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_iterator()),
		Value.from_object(function.object), attribute_writable | attribute_configurable)
}

// GetIterator(value, sync), retaining the primitive receiver both while
// reading @@iterator and when calling it.
pub fn get_iterator_sync_value(mut vm VM, value Value) !&IteratorRecord {
	method := value.get_method_with_prototypes(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_iterator()), realm_primitive_prototypes())!
	if method.is_undefined() { return vm.throw_error_type(.type_error, .not_iterable, value.str()) }
	return get_iterator_from_method(mut vm, value, method)
}
