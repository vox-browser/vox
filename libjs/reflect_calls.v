module libjs

// Runtime/ReflectObject.cpp::apply. Callable validation precedes every observable
// length/index read in CreateListFromArrayLike; thisArgument is forwarded intact.
pub fn reflect_apply(mut vm VM) !Value {
	target := vm.argument(0)
	this_argument := vm.argument(1)
	arguments_list := vm.argument(2)
	if !target.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, target.str())
	}
	call_arguments := create_argument_list_from_array_like(mut vm, arguments_list)!
	return call(mut vm, target, this_argument, call_arguments)
}

// Runtime/ReflectObject.cpp::construct. An absent newTarget defaults to target;
// an explicitly supplied undefined is validated and rejected before list reads.
pub fn reflect_construct(mut vm VM) !Value {
	target := vm.argument(0)
	arguments_list := vm.argument(1)
	mut new_target := vm.argument(2)
	if !target.is_constructor() {
		return vm.throw_error_type(.type_error, .not_a_constructor, target.str())
	}
	if vm.argument_count() < 3 {
		new_target = target
	} else if !new_target.is_constructor() {
		return vm.throw_error_type(.type_error, .not_a_constructor, new_target.str())
	}
	call_arguments := create_argument_list_from_array_like(mut vm, arguments_list)!
	return Value.from_object(construct(mut vm, target, call_arguments, new_target.as_object())!)
}
