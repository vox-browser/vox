module libjs

// Runtime/Value.cpp::OrdinaryHasInstance. The parameter order follows that
// source helper: instance value first, callable constructor second.
pub fn ordinary_has_instance(mut vm VM, value Value, constructor Value) !Value {
	if !constructor.is_function() { return Value.from_bool(false) }
	object := constructor.as_object()
	if bound := object.bound_function {
		return instance_of(mut vm, value, Value.from_object(bound.bound_target_function))
	}
	if !value.is_object() { return Value.from_bool(false) }
	prototype := object.get(mut vm, PropertyName.from_str('prototype'))!
	if !prototype.is_object() {
		return vm.throw_error_type(.type_error, .instance_of_operator_bad_prototype,
			constructor.str())
	}
	mut current := value.as_object().internal_get_prototype_of()
	for {
		parent := current or { return Value.from_bool(false) }
		if same_value(prototype, Value.from_object(parent)) { return Value.from_bool(true) }
		current = parent.internal_get_prototype_of()
	}
	return Value.from_bool(false)
}

// Runtime/Value.cpp::InstanceofOperator. Inline builtin metadata is pending,
// so the default @@hasInstance uses the ordinary native-call path.
pub fn instance_of(mut vm VM, value Value, target Value) !Value {
	if !target.is_object() { return vm.throw_error_type(.type_error, .not_an_object, target.str()) }
	handler := target.as_object().get_method(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_has_instance()))!
	if !handler.is_undefined() {
		return Value.from_bool(call(mut vm, handler, target, [value])!.to_boolean())
	}
	if !target.is_function() {
		return vm.throw_error_type(.type_error, .not_a_function, target.str())
	}
	// The pinned upstream's no-handler branch passes (target, value), despite
	// the helper's argument order above. Preserve that body exactly; normal
	// functions inherit Function.prototype's default handler and avoid it.
	return ordinary_has_instance(mut vm, target, value)
}
