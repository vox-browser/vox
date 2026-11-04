module css

import platform

fn test_numeric_type_iteration_preserves_all_optional_exponent_combinations() {
	// Absent differs from explicit zero in copying/serialization, while both
	// have the same dimensional effect. Exercise all 5^7 combinations, including
	// negative powers and multiple competing nonzero dimensions.
	units := [NumericBaseType.length, .angle, .time, .frequency, .resolution, .flex, .percent]!
	powers := [0, -2, 0, 1, 2]!
	for combination in 0 .. 78125 {
		mut digits := combination
		mut source := NumericType.new()
		mut first := ?NumericBaseType(none)
		mut sole_one := ?NumericBaseType(none)
		mut nonzero := 0
		mut ones := 0
		mut nonpercent := false
		mut invalid_dimension := false
		for unit in units {
			digit := digits % 5
			digits /= 5
			if digit == 0 { continue }
			power := powers[digit]
			source.set_exponent(unit, power)
			if first == none { first = unit }
			if power == 0 { continue }
			nonzero++
			nonpercent = nonpercent || unit != .percent
			if power == 1 {
				ones++
				sole_one = unit
			} else {
				invalid_dimension = true
			}
		}
		if nonzero != 1 || ones != 1 { sole_one = none }
		assert source.first_present_base_type() == first
		assert source.entry_with_value_1_while_all_others_are_0() == sole_one
		assert source.contains_a_key_other_than_percent_with_a_non_zero_value() == nonpercent
		assert source.matches_number(none) == (nonzero == 0)
		assert source.matches_dimension() == (!invalid_dimension && ones <= 1
			&& (source.percent_ or { 0 }) == 0)
		mut copy := NumericType.new()
		copy.copy_all_entries_from(source, false)
		assert copy == source
		inverted := source.inverted()
		assert inverted.inverted() == source
	}
}

fn test_numeric_type_iteration_retains_percent_hints_and_order() {
	mut length := NumericType.with_type(.length, 1)
	percentage := NumericType.with_type(.percent, 1)
	length.apply_percent_hint(.length)
	combined := length.added_to(percentage) or { panic('length-percentage must combine') }
	assert (combined.percent_hint or { panic('missing hint') }) == NumericBaseType.length
	assert (combined.length_ or { panic('missing length') }) == 1
	assert (combined.percent_ or { panic('missing percentage') }) == 0
	assert combined.matches_length_percentage(.length)
	inverse := combined.inverted()
	assert (inverse.percent_hint or { panic('missing inverted hint') }) == NumericBaseType.length
	mut time := NumericType.with_type(.time, 1)
	time.apply_percent_hint(.time)
	assert combined.added_to(time) == none
	assert combined.multiplied_by(time) == none
	product := NumericType.with_type(.length, 2).multiplied_by(NumericType.with_type(.time, -1)) or {
		panic('unhinted dimensions must multiply')
	}
	assert product.dump() == '{ hint: none, "length" -> 2, "time" -> -1 }'
	cancelled := product.multiplied_by(product.inverted()) or { panic('dimensions must cancel') }
	assert cancelled.matches_number(none)
}

fn test_numeric_base_type_iteration_does_not_allocate_in_sample_arena() {
	$if prealloc {
		mut arena := platform.new_arena('numeric dimension iteration')
		entry := arena.enter()
		before := arena.usage().used
		mut checksum := 0
		for _ in 0 .. 4096 {
			for unit in numeric_base_types() { checksum += int(unit) + 1 }
		}
		after := arena.usage().used
		arena.leave(entry)
		arena.release()
		assert checksum == 4096 * 28
		assert after == before
	}
}
