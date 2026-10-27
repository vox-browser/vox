module libjs

// AbstractOperations.cpp::max_js_string_length and checked length arithmetic.
pub fn max_js_string_length() uint {
	return uint(0xffffffff)
}

pub fn checked_js_string_length_sum(mut vm VM, a uint, b uint, error_type ErrorType) !uint {
	if b > (~uint(0)) - a { return vm.throw_error_type(.range_error, error_type) }
	sum := a + b
	if sum > max_js_string_length() { return vm.throw_error_type(.range_error, error_type) }
	return sum
}

pub fn checked_js_string_length_product(mut vm VM, a uint, b uint, error_type ErrorType) !uint {
	if a != 0 && b > (~uint(0)) / a { return vm.throw_error_type(.range_error, error_type) }
	product := a * b
	if product > max_js_string_length() { return vm.throw_error_type(.range_error, error_type) }
	return product
}
