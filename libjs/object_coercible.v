module libjs

// AbstractOperations.cpp::RequireObjectCoercible. This returns the original
// primitive or object; it does not perform ToObject or call conversion hooks.
pub fn require_object_coercible(mut vm VM, value Value) !Value {
	if value.is_nullish() {
		return vm.throw_error_type(.type_error, .not_object_coercible, value.str())
	}
	return value
}
