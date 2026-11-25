module libjs

pub type ArrayLikeValueCheck = fn (mut vm VM, value Value) !

// Runtime/AbstractOperations.cpp::LengthOfArrayLike, ordinary object path.
pub fn length_of_array_like(mut vm VM, object &Object) !u64 {
	return object.get(mut vm, vm.length_key())!.to_length(mut vm)
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
fn argument_array_like(mut vm VM, value Value) !(&Object, u64) {
	if !value.is_object() { return vm.throw_error_type(.type_error, .not_an_object, value.str()) }
	object := value.as_object()
	length := length_of_array_like(mut vm, object)!
	if length > maximum_argument_count {
		return vm.throw_error_type(.internal_error, .call_stack_size_exceeded)
	}
	return object, length
}

pub fn create_argument_list_from_array_like(mut vm VM, value Value) ![]Value {
	object, length := argument_array_like(mut vm, value)!
	return list_from_array_like(mut vm, object, length, unsafe { nil })
}

@[direct_array_access]
fn (mut vm VM) call_with_array_like_arguments(target Value, receiver Value, value Value) !Value {
	object, length := argument_array_like(mut vm, value)!
	if length == 0 { return call(mut vm, target, receiver, unsafe { borrow_argument_values(nil, 0) }) }
	mut stack := vm.interpreter_stack()
	// Keep values visible to the VM's root traversal while getters run.
	if length > call_argument_workspace_capacity || !use_call_argument_workspaces()
		|| stack.call_argument_depth >= call_argument_workspace_limit {
		arguments := list_from_array_like(mut vm, object, length, unsafe { nil })!
		return call(mut vm, target, receiver, arguments)
	}
	count := int(length)
	mut workspace := stack.acquire_call_argument_workspace()
	defer { stack.release_call_argument_workspace(mut workspace, count) }
	// Getters may call apply again. The workspace stays owned by this call
	// until both the getters and the target have finished.
	mut index := 0
	if object.array_object != none && object.proxy_object == none
		&& object.reads_key_directly(PropertyName.from_number(0)) {
		// Dense arrays store each element at its index. A missing, reordered,
		// or accessor property needs the full lookup and can change later entries.
		for index < count && index < object.properties.len {
			property := &object.properties[index]
			if property.key.kind != .number_key || property.key.number != u32(index)
				|| property.value.is_accessor() { break }
			workspace.values[index] = property.value
			record_direct_property_read()
			index++
		}
	}
	for ; index < count; index++ {
		workspace.values[index] = object.get(mut vm, PropertyName.from_number(u32(index)))!
	}
	arguments := unsafe { borrow_argument_values(&workspace.values[0], count) }
	if can_borrow_call_arguments(target) { return call(mut vm, target, receiver, arguments) }
	return call(mut vm, target, receiver, arguments.clone())
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
