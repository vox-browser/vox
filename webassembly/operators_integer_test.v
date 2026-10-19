module webassembly

import os
import strconv

// Generated results invoke byte-exact pinned C++ operator records, including
// AK::Checked's real signed division checks. No Wasm interpreter is substituted.
fn integer_operator_case(name string, lhs u64, rhs u64) !u64 {
	match name {
		'div_i32' {
			value := binary_divide_i32(i32(lhs), i32(rhs))!
			return u64(i64(value))
		}
		'div_u32' {
			value := binary_divide_u32(u32(lhs), u32(rhs))!
			return u64(value)
		}
		'div_i64' {
			value := binary_divide_i64(i64(lhs), i64(rhs))!
			return u64(value)
		}
		'div_u64' { return binary_divide_u64(lhs, rhs) }
		'mod_i32' {
			value := binary_modulo_i32(i32(lhs), i32(rhs))!
			return u64(i64(value))
		}
		'mod_u32' {
			value := binary_modulo_u32(u32(lhs), u32(rhs))!
			return u64(value)
		}
		'mod_i64' {
			value := binary_modulo_i64(i64(lhs), i64(rhs))!
			return u64(value)
		}
		'mod_u64' { return binary_modulo_u64(lhs, rhs) }
		'rotl_u32' { return u64(binary_rotate_left_u32(u32(lhs), u32(rhs))) }
		'rotr_u32' { return u64(binary_rotate_right_u32(u32(lhs), u32(rhs))) }
		'rotl_u64' { return binary_rotate_left_u64(lhs, rhs) }
		'rotr_u64' { return binary_rotate_right_u64(lhs, rhs) }
		else { panic('Unknown Source integer operator fixture: ${name}') }
	}
}

fn test_integer_operators_match_pinned_native_source_boundary_corpus() {
	rows := os.read_lines(os.dir(@DIR) + '/webassembly/fixtures/integer_operators.tsv')!
	mut count := 0
	for row in rows {
		if row.starts_with('#') || row.len == 0 { continue }
		parts := row.split('\t')
		assert parts.len == 4
		lhs := strconv.parse_uint(parts[1], 16, 64)!
		rhs := strconv.parse_uint(parts[2], 16, 64)!
		actual := integer_operator_case(parts[0], lhs, rhs) or {
			assert parts[3] == 'error:' + err.msg(), row
			count++
			continue
		}
		assert parts[3] == '${actual:016x}', row
		count++
	}
	assert count == 3264
}

fn test_source_integer_overflow_error_is_distinct_from_signed_remainder_minus_one() {
	assert binary_modulo_i32(i32(-2147483648), -1)! == 0
	assert binary_modulo_i64(i64(-9223372036854775807) - 1, -1)! == 0
	assert binary_divide_i32(-7, 3)! == -2
	assert binary_modulo_i32(-7, 3)! == -1
	assert binary_divide_i64(-7, -3)! == 2
	assert binary_modulo_i64(7, -3)! == 1
}
