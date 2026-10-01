module libjs

// AbstractOperations.cpp::max_js_string_length and checked length arithmetic.
pub fn max_js_string_length() usize {
	return usize(0xffffffff)
}

pub fn checked_js_string_length_sum(mut vm VM, a usize, b usize, error_type ErrorType) !usize {
	if b > (~usize(0)) - a { return vm.throw_error_type(.range_error, error_type) }
	sum := a + b
	if sum > max_js_string_length() { return vm.throw_error_type(.range_error, error_type) }
	return sum
}

pub fn checked_js_string_length_product(mut vm VM, a usize, b usize, error_type ErrorType) !usize {
	if a != 0 && b > (~usize(0)) / a { return vm.throw_error_type(.range_error, error_type) }
	product := a * b
	if product > max_js_string_length() { return vm.throw_error_type(.range_error, error_type) }
	return product
}
