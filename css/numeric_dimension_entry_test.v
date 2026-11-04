module css

import platform

fn numeric_dimension_reference(value NumericType) ?NumericBaseType {
	mut result := ?NumericBaseType(none)
	for base in [NumericBaseType.length, .angle, .time, .frequency, .resolution, .flex, .percent]! {
		power := value.exponent(base) or { continue }
		if power == 0 { continue }
		if power != 1 || result != none { return none }
		result = base
	}
	return result
}

fn test_direct_numeric_dimension_preserves_all_optional_powers_and_hints() {
	units := [NumericBaseType.length, .angle, .time, .frequency, .resolution, .flex, .percent]!
	powers := [0, -2, 0, 1, 2]!
	for combination in 0 .. 78125 {
		mut digits := combination
		mut value := NumericType.new()
		for unit in units {
			digit := digits % 5
			digits /= 5
			if digit != 0 { value.set_exponent(unit, powers[digit]) }
		}
		if combination % 8 != 0 { value.percent_hint = units[combination % 7] }
		before := value
		assert value.entry_with_value_1_while_all_others_are_0() == numeric_dimension_reference(value)
		assert value == before
	}
}

fn test_direct_numeric_dimension_rejects_extreme_signed_powers_without_overflow() {
	units := [NumericBaseType.length, .angle, .time, .frequency, .resolution, .flex, .percent]!
	for unit in units {
		for power in [min_int, max_int, -1, -2, 0, 1, 2] {
			mut value := NumericType.with_type(unit, power)
			assert value.entry_with_value_1_while_all_others_are_0() == numeric_dimension_reference(value)
			for other in units {
				if other == unit { continue }
				for partner in [min_int, max_int, -1, 0, 1, 2] {
					value.set_exponent(other, partner)
					assert value.entry_with_value_1_while_all_others_are_0() == numeric_dimension_reference(value)
				}
				value.set_exponent(other, 0)
			}
		}
	}
}

fn test_direct_numeric_dimension_matches_wide_deterministic_inputs() {
	units := [NumericBaseType.length, .angle, .time, .frequency, .resolution, .flex, .percent]!
	mut bits := u64(0x4d595df4d0f33173)
	for index in 0 .. 16384 {
		mut value := NumericType.new()
		for unit in units {
			bits ^= bits << 13
			bits ^= bits >> 7
			bits ^= bits << 17
			power := match bits & 7 {
				0 { continue }
				1 { min_int }
				2 { max_int }
				3 { 0 }
				4 { 1 }
				5 { -1 }
				else { int(bits) }
			}
			value.set_exponent(unit, power)
		}
		if index % 8 != 0 { value.percent_hint = units[index % 7] }
		assert value.entry_with_value_1_while_all_others_are_0() == numeric_dimension_reference(value)
	}
}

fn test_direct_numeric_dimension_does_not_allocate_or_mutate_in_sample_storage() {
	$if prealloc {
		mut value := NumericType.with_type(.length, 1)
		value.set_exponent(.percent, 0)
		value.percent_hint = .length
		assert (value.entry_with_value_1_while_all_others_are_0() or { panic('missing length') }) == NumericBaseType.length
		mut arena := platform.new_arena('numeric dimension entry')
		defer { arena.release() }
		entry := arena.enter()
		before := arena.usage().used
		for _ in 0 .. 4096 {
			assert (value.entry_with_value_1_while_all_others_are_0() or { panic('missing length') }) == NumericBaseType.length
		}
		assert arena.usage().used == before
		arena.leave(entry)
	}
}
