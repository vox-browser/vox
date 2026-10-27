module libjs

// TypedArray.cpp's concrete ClassName::create(realm, length, new_target).
// IntrinsicPrototypeGetter replaces the C++ pointer to the concrete prototype
// member. Callers provide that dependency until TypedArray intrinsics exist.
pub fn create_typed_array_from_constructor(mut vm VM, kind BufferElementType, length u32, new_target &Object, intrinsic_prototype IntrinsicPrototypeGetter) !&TypedArray {
	prototype := get_prototype_from_constructor(mut vm, new_target, intrinsic_prototype)!
	buffer := ArrayBufferObject.create(mut vm, vm.realm(), uint(length) * kind.size(),
		vm.realm().array_buffer_prototype_record())!
	return TypedArray.create(vm.realm(), kind, length, buffer, prototype)
}

// TypedArray.cpp's concrete ConstructorName::call and ::construct bodies.
// These translate constructor behavior without installing a partial intrinsic
// constructor/prototype graph or the pending Uint8Array encoding methods.
pub fn call_typed_array_constructor(mut vm VM, kind BufferElementType) !Value {
	return vm.throw_error_type(.type_error, .constructor_without_new, kind.typed_array_name())
}

pub fn construct_typed_array(mut vm VM, kind BufferElementType, new_target &Object, intrinsic_prototype IntrinsicPrototypeGetter) !&TypedArray {
	if vm.argument_count() == 0 {
		return create_typed_array_from_constructor(mut vm, kind, 0, new_target, intrinsic_prototype)
	}
	first := vm.argument(0)
	if first.is_object() {
		mut array := create_typed_array_from_constructor(mut vm, kind, 0, new_target,
			intrinsic_prototype)!
		object := first.as_object()
		if source := object.typed_array {
			initialize_typed_array_from_typed_array(mut vm, mut array, source)!
		} else if buffer := object.array_buffer {
			initialize_typed_array_from_array_buffer(mut vm, mut array, buffer, vm.argument(1),
				vm.argument(2))!
		} else {
			iterator := object.get_method(mut vm,
				PropertyName.from_symbol(vm.well_known_symbol_iterator()))!
			if !iterator.is_undefined() {
				mut record := get_iterator_from_method(mut vm, first, iterator)!
				values := iterator_to_list(mut vm, mut record)!
				initialize_typed_array_from_list(mut vm, mut array, values)!
			} else {
				initialize_typed_array_from_array_like(mut vm, mut array, object)!
			}
		}
		return array
	}
	length := first.to_index(mut vm) or {
		value := thrown_value(err)
		if value.is_object() {
			if error_kind := value.as_object().error_kind() {
				if error_kind == .range_error {
					return vm.throw_error_type(.range_error, .invalid_length, 'typed array')
				}
			}
		}
		return err
	}
	validate_typed_array_length(mut vm, uint(length), kind.size())!
	return create_typed_array_from_constructor(mut vm, kind, u32(length), new_target,
		intrinsic_prototype)
}
