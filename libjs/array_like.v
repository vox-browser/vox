module libjs

pub type ArrayLikeValueCheck = fn (mut vm VM, value Value) !

// Runtime/AbstractOperations.cpp::LengthOfArrayLike, ordinary object path.
pub fn length_of_array_like(mut vm VM, object &Object) !u64 {
	return object.get(mut vm, PropertyName.from_str('length'))!.to_length(mut vm)
}

// Runtime/AbstractOperations.cpp::CreateListFromArrayLike. A V array replaces
// GC::RootVector. Its signed-int capacity is narrower than upstream size_t;
// reject unrepresentable allocations before reading indexed properties.
pub fn create_list_from_array_like(mut vm VM, value Value, check_value ArrayLikeValueCheck) ![]Value {
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	object := value.as_object()
	length := length_of_array_like(mut vm, object)!
	if length > 0x7fffffff {
		return vm.throw_error_type(.range_error, .not_enough_memory_to_allocate,
			(length * u64(sizeof(Value))).str())
	}
	mut list := []Value{cap: int(length)}
	for index in 0 .. int(length) {
		next := object.get(mut vm, PropertyName.from_number(u32(index)))!
		if check_value != unsafe { nil } { check_value(mut vm, next)! }
		list << next
	}
	return list
}
