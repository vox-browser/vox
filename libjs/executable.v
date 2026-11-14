module libjs

// The executable and source-code records the VM and execution contexts read:
// register/local/constant layout, exception handler ranges, and the bytecode
// offset to source position map from LibJS/Bytecode/Executable.h, plus
// SourceCode/SourceRange from LibJS/SourceCode.h and SourceRange.h. Bytecode
// instructions below use V records and instruction-index offsets; they do not
// share the generated upstream interpreter's packed bytecode ABI.

@[heap]
pub struct SourceCode {
pub:
	filename Utf16String
	code     Utf16String
}

pub fn SourceCode.create(filename Utf16String, code Utf16String) &SourceCode {
	return &SourceCode{
		filename: filename
		code:     code
	}
}

// The parser owns the name SourceRange, so the runtime range is SourceCodeRange.
pub struct SourceCodeRange {
pub:
	code  ?&SourceCode
	start Position
}

pub fn (range SourceCodeRange) filename() Utf16String {
	if code := range.code {
		return code.filename
	}
	return Utf16String.new()
}

pub struct ExceptionHandlers {
pub:
	start_offset      u32
	end_offset        u32
	handler_offset    u32
	catches_exception bool
}

pub struct SourceMapEntry {
pub:
	bytecode_offset u32
	source_range    SourceCodeRange
}

@[heap]
pub struct Executable {
pub mut:
	name                       Utf16String
	registers_and_locals_count u32
	constants                  []Value
	identifier_table           []Utf16String
	local_variable_names       []Utf16String
	local_index_base           u32
	// Sorted by start_offset with exclusive end offsets.
	exception_handlers []ExceptionHandlers
	// Sorted by bytecode_offset.
	source_map      []SourceMapEntry
	bytecode_length u32
	source_code     ?&SourceCode
	instructions    []Instruction
	global_bindings []GlobalBinding
	parsed_source &ParsedSource = unsafe { nil }
	starting_line u32 = 1
}

pub fn (executable &Executable) get_identifier(index u32) Utf16String {
	return executable.identifier_table[index]
}

pub fn (executable &Executable) exception_handlers_for_offset(offset u32) ?ExceptionHandlers {
	// NB: exception_handlers is sorted by start_offset.
	mut low := 0
	mut high := executable.exception_handlers.len
	for low < high {
		middle := low + (high - low) / 2
		entry := executable.exception_handlers[middle]
		if offset < entry.start_offset {
			high = middle
		} else if offset >= entry.end_offset {
			low = middle + 1
		} else {
			return entry
		}
	}
	return none
}

pub fn (executable &Executable) source_range_at(offset u32) ?SourceCodeRange {
	if offset >= executable.bytecode_length {
		return none
	}
	if executable.source_map.len == 0 {
		return none
	}
	mut low := 0
	mut high := executable.source_map.len
	for low < high {
		middle := low + (high - low) / 2
		if executable.source_map[middle].bytecode_offset <= offset {
			low = middle + 1
		} else {
			high = middle
		}
	}
	if low == 0 {
		return none
	}
	return executable.source_map[low - 1].source_range
}

pub fn (executable &Executable) get_source_range(program_counter u32) SourceCodeRange {
	if range := executable.source_range_at(program_counter) {
		return range
	}
	return SourceCodeRange{}
}
