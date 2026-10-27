module libjs

// Runtime/AbstractOperations.cpp::GetSubstitution. Flat UTF-16 slices replace
// AK's views and builder; capture reads/conversions remain live and ordered.
pub fn get_substitution(mut vm VM, matched Utf16String, text Utf16String, position uint, captures []Value, named_captures Value, replacement_template Utf16String) !Utf16String {
	string_length := uint(text.len())
	assert position <= string_length
	mut result := []u16{}
	mut remainder := unsafe { replacement_template.data }
	for remainder.len > 0 {
		mut ref_length := 1
		mut replacement := unsafe { remainder[..1] }
		if remainder.len >= 2 && remainder[0] == u16(`$`) {
			match rune(remainder[1]) {
				`$` {
					ref_length = 2
					replacement = unsafe { remainder[..1] }
				}
				`\`` {
					ref_length = 2
					replacement = unsafe { text.data[..int(position)] }
				}
				`&` {
					ref_length = 2
					replacement = unsafe { matched.data }
				}
				`'` {
					ref_length = 2
					tail_position := position + uint(matched.len())
					tail_start := if tail_position < string_length {
						tail_position
					} else {
						string_length
					}
					replacement = unsafe { text.data[int(tail_start)..] }
				}
				`0`...`9` {
					mut digit_count := 1
					if remainder.len > 2 && remainder[2] >= u16(`0`) && remainder[2] <= u16(`9`) {
						digit_count = 2
					}
					mut index := uint(string_to_number(Utf16String.from_slice(remainder[1..1 +
						digit_count])))
					assert index <= 99
					if index > uint(captures.len) && digit_count == 2 {
						digit_count = 1
						index = uint(string_to_number(Utf16String.from_slice(remainder[1..2])))
					}
					ref_length = 1 + digit_count
					replacement = unsafe { remainder[..ref_length] }
					if index >= 1 && index <= uint(captures.len) {
						capture := captures[int(index) - 1]
						replacement = if capture.is_undefined() {
							[]u16{}
						} else {
							capture.to_primitive_string(mut vm)!.utf16.data
						}
					}
				}
				`<` {
					ref_length = 2
					replacement = unsafe { remainder[..2] }
					if greater_than := string_index_of(Utf16String{ data: remainder },
						utf16_string('>'), 2)
					{
						if !named_captures.is_undefined() {
							ref_length = int(greater_than) + 1
							group_name := Utf16String.from_slice(remainder[2..int(greater_than)])
							assert named_captures.is_object()
							capture := named_captures.as_object().get(mut vm,
								PropertyName.from_utf16(group_name))!
							replacement = if capture.is_undefined() {
								[]u16{}
							} else {
								capture.to_primitive_string(mut vm)!.utf16.data
							}
						}
					}
				}
				else {}
			}
		}
		// Append before advancing: replacement may point into remainder.
		result << replacement
		remainder = unsafe { remainder[ref_length..] }
	}
	return Utf16String{
		data: result
	}
}
