module libjs

pub type ArrayLikeValueCheck = fn (mut vm VM, value Value) !

// Runtime/AbstractOperations.cpp::LengthOfArrayLike, ordinary object path.
pub fn length_of_array_like(mut vm VM, object &Object) !u64 {
	return object.get(mut vm, PropertyName.from_str('length'))!.to_length(mut vm)
}

// Runtime/AbstractOperations.cpp::CreateListFromArrayLike.
pub fn create_list_from_array_like(mut vm VM, value Value, check_value ArrayLikeValueCheck) ![]Value {
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	object := value.as_object()
	length := length_of_array_like(mut vm, object)!
	return list_from_array_like(mut vm, object, length, check_value)
}

// Unlike general list conversion, a call can reject an impossible length
// before reading any element. Read length only once, after receiver validation.
pub fn create_argument_list_from_array_like(mut vm VM, value Value) ![]Value {
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	object := value.as_object()
	length := length_of_array_like(mut vm, object)!
	if length > maximum_argument_count {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	return list_from_array_like(mut vm, object, length, unsafe { nil })
}

fn list_from_array_like(mut vm VM, object &Object, length u64, check_value ArrayLikeValueCheck) ![]Value {
	// Ladybird 82ba30cd14b4: grow after reading values instead of reserving
	// an unbounded array up front; early getter/check exceptions must survive.
	capacity := if length < maximum_argument_count { length } else { maximum_argument_count }
	mut list := []Value{cap: int(capacity)}
	for index := u64(0); index < length; index++ {
		key := if index <= 0xffffffff {
			PropertyName.from_number(u32(index))
		} else {
			PropertyName.from_str(index.str())
		}
		next := object.get(mut vm, key)!
		if check_value != unsafe { nil } { check_value(mut vm, next)! }
		list << next
	}
	return list
}
