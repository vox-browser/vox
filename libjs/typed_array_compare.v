module libjs

import math

// TypedArray.cpp::CompareTypedArrayElements. Default order is numeric (including
// BigInt), with NaNs last and negative zero before positive zero. A supplied
// callback is called before those rules and its result undergoes ToNumber.
pub fn compare_typed_array_elements(mut vm VM, x Value, y Value, compare_function ?&Object) !f64 {
	assert (x.is_number() && y.is_number()) || (x.is_bigint() && y.is_bigint())
	if function := compare_function {
		value := call(mut vm, Value.from_object(function), js_undefined(), [x, y])!
		number := value.to_number(mut vm)!.number
		return if math.is_nan(number) { 0 } else { number }
	}
	x_nan := x.is_number() && math.is_nan(x.number)
	y_nan := y.is_number() && math.is_nan(y.number)
	if x_nan && y_nan { return 0 }
	if x_nan { return 1 }
	if y_nan { return -1 }
	if x.is_bigint() {
		if x.as_bigint().big_integer < y.as_bigint().big_integer { return -1 }
		if x.as_bigint().big_integer > y.as_bigint().big_integer { return 1 }
	} else {
		if x.number < y.number { return -1 }
		if x.number > y.number { return 1 }
		if x.number == 0 && y.number == 0 {
			if math.signbit(x.number) && !math.signbit(y.number) { return -1 }
			if !math.signbit(x.number) && math.signbit(y.number) { return 1 }
		}
	}
	return 0
}
