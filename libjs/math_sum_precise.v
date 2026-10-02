module libjs

import math

struct MathTwoSumResult {
	hi f64
	lo f64
}

fn math_two_sum(x f64, y f64) MathTwoSumResult {
	hi := x + y
	return MathTwoSumResult{ hi: hi, lo: y - (hi - x) }
}

enum MathSumState { minus_zero plus_infinity minus_infinity not_a_number finite }

// MathObject.cpp::sumPrecise. Retain the expansion accumulator, explicit
// overflow carry, final half-ulp correction, and IteratorClose on bad items.
pub fn math_sum_precise(mut vm VM) !Value {
	items := require_object_coercible(mut vm, vm.argument(0))!
	method := items.get_method_with_prototypes(mut vm,
		PropertyName.from_symbol(vm.well_known_symbol_iterator()), PrimitiveObjectPrototypes{})!
	if method.is_undefined() { return vm.throw_error_type(.type_error, .not_iterable, items.str()) }
	mut record := get_iterator_from_method(mut vm, items, method)!
	mut state := MathSumState.minus_zero
	mut overflow := 0.0
	mut count := u64(0)
	mut partials := []f64{}
	power_2_1023 := 8.98846567431158e307
	max_ulp := math.max_f64 - math.nextafter(math.max_f64, 0)
	for {
		next := iterator_step_value(mut vm, mut record)!
		if next.done { break }
		value := next.value
		if count >= (u64(1) << 53) - 1 {
			closed := iterator_close(mut vm, record, completion_from_error(vm.throw_error_type(.range_error, .array_max_size)))
			return closed.release_error()
		}
		if !value.is_number() {
			closed := iterator_close(mut vm, record, completion_from_error(vm.throw_error_type(.type_error, .is_not_a, value.str(), 'number')))
			return closed.release_error()
		}
		n := value.number
		if state != .not_a_number {
			if math.is_nan(n) { state = .not_a_number }
			else if math.is_inf(n, 1) { state = if state == .minus_infinity { .not_a_number } else { .plus_infinity } }
			else if math.is_inf(n, -1) { state = if state == .plus_infinity { .not_a_number } else { .minus_infinity } }
			else if !(n == 0 && math.signbit(n)) && state in [.minus_zero, .finite] {
				state = .finite
				mut x := n
				mut used := 0
				for index in 0 .. partials.len {
					mut y := partials[index]
					if math.abs(x) < math.abs(y) { x, y = y, x }
					mut result := math_two_sum(x, y)
					if math.is_inf(result.hi, 0) {
						sign := if math.signbit(result.hi) { -1.0 } else { 1.0 }
						overflow += sign
						if math.abs(overflow) >= f64(u64(1) << 53) { return vm.throw_error_type(.range_error, .math_sum_precise_overflow) }
						x = (x - sign * power_2_1023) - sign * power_2_1023
						if math.abs(x) < math.abs(y) { x, y = y, x }
						result = math_two_sum(x, y)
					}
					if result.lo != 0 { partials[used] = result.lo; used++ }
					x = result.hi
				}
				partials.trim(used)
				if x != 0 { partials << x }
			}
		}
		count++
	}
	if state == .not_a_number { return Value.from_f64(math.nan()) }
	if state == .plus_infinity { return Value.from_f64(math.inf(1)) }
	if state == .minus_infinity { return Value.from_f64(math.inf(-1)) }
	if state == .minus_zero { return Value.from_f64(math.f64_from_bits(u64(1) << 63)) }
	mut index := partials.len - 1
	mut hi := 0.0
	mut lo := 0.0
	if overflow != 0 {
		next := if index >= 0 { partials[index] } else { 0.0 }
		index--
		if math.abs(overflow) > 1 || (overflow > 0 && next > 0) || (overflow < 0 && next < 0) {
			return Value.from_f64(math.inf(if overflow > 0 { 1 } else { -1 }))
		}
		result := math_two_sum(overflow * power_2_1023, next / 2)
		hi = result.hi
		lo = result.lo * 2
		if math.is_inf(hi * 2, 0) {
			if hi > 0 {
				if hi == power_2_1023 && lo == -(max_ulp / 2) && index >= 0 && partials[index] < 0 { return Value.from_f64(math.max_f64) }
				return Value.from_f64(math.inf(1))
			}
			if hi == -power_2_1023 && lo == max_ulp / 2 && index >= 0 && partials[index] > 0 { return Value.from_f64(-math.max_f64) }
			return Value.from_f64(math.inf(-1))
		}
		if lo != 0 {
			if index + 1 < partials.len { partials[index + 1] = lo } else { partials << lo }
			index++
			lo = 0
		}
		hi *= 2
	}
	for index >= 0 {
		result := math_two_sum(hi, partials[index])
		index--
		hi = result.hi
		lo = result.lo
		if lo != 0 { break }
	}
	if index >= 0 && ((lo < 0 && partials[index] < 0) || (lo > 0 && partials[index] > 0)) {
		y := lo * 2
		x := hi + y
		if y == x - hi { hi = x }
	}
	return Value.from_f64(hi)
}
