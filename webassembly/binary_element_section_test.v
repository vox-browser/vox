module webassembly

import webidl

fn element_section_binary(payload []u8) []u8 {
	mut bytes := [u8(0), 0x61, 0x73, 0x6d, 1, 0, 0, 0, 9, u8(payload.len)]
	bytes << payload
	return bytes
}

fn test_element_section_retains_all_eight_modes_types_and_expressions() {
	mut payload := [u8(8)]
	for tag in 0 .. 8 {
		payload << u8(tag)
		if tag & 1 == 0 {
			if tag & 2 != 0 { payload << [u8(0x80), 1] }
			payload << [u8(0x41), 2, 0x0b]
		}
		if tag & 1 != 0 || tag & 2 != 0 {
			payload << if tag & 4 != 0 { u8(0x6f) } else { u8(0) }
		}
		payload << u8(1)
		if tag & 4 == 0 {
			payload << u8(3)
		} else {
			payload << [u8(0xd0), if tag == 4 { u8(0x70) } else { u8(0x6f) }, 0x0b]
		}
	}
	compiled := compile_module(element_section_binary(payload))!
	assert compiled.element_segments.len == 8
	for tag, segment in compiled.element_segments {
		if tag & 1 == 0 {
			assert segment.mode == .active
			index := segment.table_index?
			assert index == if tag & 2 == 0 { u32(0) } else { u32(128) }
			offset := segment.offset?
			assert (offset.instructions[0].arguments as BinaryI32Constant).value == 2
		} else {
			assert segment.mode == if tag & 2 == 0 {
				BinaryElementMode.passive
			} else {
				BinaryElementMode.declarative
			}
			assert segment.table_index == none && segment.offset == none
		}
		assert segment.items.len == 1
		assert segment.items[0].instructions.len == 2
		assert segment.items[0].instructions[1].opcode == binary_op_synthetic_end_expression
		if tag & 4 == 0 {
			assert segment.element_type == BinaryValueType{ kind: .function_reference, nullable: false }
			assert segment.items[0].instructions[0].opcode == binary_op_ref_func
			assert (segment.items[0].instructions[0].arguments as BinaryIndexArgument) == BinaryIndexArgument{ kind: .function_, index: 3 }
		} else {
			kind := if tag == 4 {
				BinaryValueKind.function_reference
			} else {
				BinaryValueKind.extern_reference
			}
			assert segment.element_type == BinaryValueType{ kind: kind }
			assert segment.items[0].instructions[0].opcode == binary_op_ref_null
			assert (segment.items[0].instructions[0].arguments as BinaryValueType) == segment.element_type
		}
	}
	mut restored := Module.create_for_serialization()
	restored.deserialization_steps(compiled.serialization_steps(false)!)!
	assert restored.element_segments == compiled.element_segments
}

fn test_element_section_parser_defers_reference_type_validation_to_validator() {
	mut decoder := Decoder{ bytes: [u8(1), 5, 0x7f, 1, 0x41, 0, 0x0b] }
	segments := parse_element_section(mut decoder)!
	assert segments[0].element_type.kind == .i32
	assert segments[0].items[0].instructions[0].opcode == binary_op_i32_const
	assert decoder.offset == decoder.bytes.len
}

fn test_element_section_rejects_invalid_tags_kinds_and_truncated_operands() {
	for payload in [[]u8{}, [u8(1), 8], [u8(1), 1, 1], [u8(1), 2, 0x80], [u8(1), 0, 0x41, 1],
		[u8(1), 0, 0x41, 0, 0x0b, 1, 0x80], [u8(1), 5, 0x6f, 1, 0xd0, 0x6f], [u8(1), 5, 0x40, 0],
		[u8(0), 0]] {
		assert !validate(webidl.BufferSource.array_buffer(element_section_binary(payload)))
	}
}
