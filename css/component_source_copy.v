module css

import os

const disable_exact_component_source_copy = os.getenv('VOX_DISABLE_EXACT_COMPONENT_SOURCE_COPY') != ''
const exact_component_source_copy_diagnostics = os.getenv('VOX_EXACT_COMPONENT_SOURCE_COPY_DIAGNOSTICS') != ''
__global exact_component_source_copy_reported bool

struct ComponentSourceByteCount {
mut:
	length int
}

struct ComponentSourceOutput {
mut:
	bytes []u8
	offset int
}

// Component spelling is immutable during serialization. Count the complete
// spelling first, then copy each original piece into one owned, terminated
// buffer. No temporary builder or scratch owner escapes this call.
fn exact_component_source_copy(values []ComponentValue) ?string {
	if disable_exact_component_source_copy || disable_flat_component_source { return none }
	if values.len == 0 { return '' }
	if values.len == 1 {
		component := unsafe { &values[0] }
		if component.value is &Token {
			report_exact_component_source_copy()
			return component.value.original_source_text_.clone()
		}
	}
	mut count := ComponentSourceByteCount{}
	for index in 0 .. values.len {
		if !count_component_source_bytes(unsafe { &values[index] }, mut count) { return none }
	}
	if count.length == 0 { return '' }
	mut output := ComponentSourceOutput{bytes: []u8{len: count.length + 1}}
	for index in 0 .. values.len {
		copy_component_source_bytes(unsafe { &values[index] }, mut output)
	}
	report_exact_component_source_copy()
	return unsafe { (&u8(output.bytes.data)).vstring_with_len(count.length) }
}

fn count_component_source_piece(text string, mut count ComponentSourceByteCount) bool {
	if text.len > max_i32 - count.length { return false }
	count.length += text.len
	return true
}

fn count_component_source_bytes(component &ComponentValue, mut count ComponentSourceByteCount) bool {
	if component.value is &Token {
		return count_component_source_piece(component.value.original_source_text_, mut count)
	} else if component.value is &Function {
		if !count_component_source_piece(component.value.name_token.original_source_text_, mut count) { return false }
		for index in 0 .. component.value.value.len {
			if !count_component_source_bytes(unsafe { &component.value.value[index] }, mut count) { return false }
		}
		return count_component_source_piece(component.value.end_token.original_source_text_, mut count)
	} else if component.value is &SimpleBlock {
		if !count_component_source_piece(component.value.token.original_source_text_, mut count) { return false }
		for index in 0 .. component.value.value.len {
			if !count_component_source_bytes(unsafe { &component.value.value[index] }, mut count) { return false }
		}
		return count_component_source_piece(component.value.end_token.original_source_text_, mut count)
	} else if component.value is RawComponentValue {
		return count_component_source_piece(component.value.text, mut count)
	}
	return true
}

fn copy_component_source_piece(text string, mut output ComponentSourceOutput) {
	if text.len == 0 { return }
	// The first walk counted these exact immutable pieces. Each copy remains
	// within its source string and the final buffer's logical length.
	unsafe { C.memcpy(&output.bytes[output.offset], text.str, uint(text.len)) }
	output.offset += text.len
}

fn copy_component_source_bytes(component &ComponentValue, mut output ComponentSourceOutput) {
	if component.value is &Token {
		copy_component_source_piece(component.value.original_source_text_, mut output)
	} else if component.value is &Function {
		copy_component_source_piece(component.value.name_token.original_source_text_, mut output)
		for index in 0 .. component.value.value.len {
			copy_component_source_bytes(unsafe { &component.value.value[index] }, mut output)
		}
		copy_component_source_piece(component.value.end_token.original_source_text_, mut output)
	} else if component.value is &SimpleBlock {
		copy_component_source_piece(component.value.token.original_source_text_, mut output)
		for index in 0 .. component.value.value.len {
			copy_component_source_bytes(unsafe { &component.value.value[index] }, mut output)
		}
		copy_component_source_piece(component.value.end_token.original_source_text_, mut output)
	} else if component.value is RawComponentValue {
		copy_component_source_piece(component.value.text, mut output)
	}
}

fn report_exact_component_source_copy() {
	if exact_component_source_copy_diagnostics && !exact_component_source_copy_reported {
		exact_component_source_copy_reported = true
		eprintln('Vox CSS source: copied component spelling into one exact owned buffer')
	}
}
