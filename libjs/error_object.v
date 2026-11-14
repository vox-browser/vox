module libjs

// Translated from LibJS/Runtime/Error.{h,cpp} and ErrorData.{h,cpp}: Error
// instances, their [[ErrorData]] traceback, and the V8-style stack string.
// Error prototypes come from the owning realm's initialized intrinsic graph.

pub enum ErrorKind {
	error
	eval_error
	internal_error
	range_error
	reference_error
	syntax_error
	type_error
	uri_error
}

pub fn (kind ErrorKind) name() string {
	return match kind {
		.error { 'Error' }
		.eval_error { 'EvalError' }
		.internal_error { 'InternalError' }
		.range_error { 'RangeError' }
		.reference_error { 'ReferenceError' }
		.syntax_error { 'SyntaxError' }
		.type_error { 'TypeError' }
		.uri_error { 'URIError' }
	}
}

pub struct TracebackFrame {
pub:
	function_name       Utf16String
	cached_source_range ?SourceCodeRange
}

pub fn (frame TracebackFrame) source_range() SourceCodeRange {
	if range := frame.cached_source_range {
		return range
	}
	return SourceCodeRange{}
}

@[heap]
pub struct ErrorData {
pub mut:
	kind ErrorKind
	// Keep the owner explicit, including incomplete host-defined bootstrap realms.
	realm         ?&Realm
	traceback     []TracebackFrame
	cached_string ?&PrimitiveString
}

// ErrorData::populate_stack
fn populate_stack(vm &VM) []TracebackFrame {
	stack_trace := vm.stack_trace()
	mut traceback := []TracebackFrame{cap: stack_trace.len}
	for element in stack_trace {
		function_name := if function := element.execution_context.function {
			function.name_for_call_stack()
		} else {
			Utf16String.new()
		}
		traceback << TracebackFrame{
			function_name:       function_name
			cached_source_range: element.source_range
		}
	}
	return traceback
}

// Error::create(Realm&, Utf16String message) and the native error variants.
pub fn create_error(mut vm VM, realm &Realm, kind ErrorKind, message ?Utf16String) &Object {
	prototype := if intrinsic := realm.error_prototypes[kind] { ?&Object(intrinsic) } else { none }
	mut object := Object.create(realm, prototype)
	object.class_name = kind.name()
	object.error_data = &ErrorData{
		kind:      kind
		realm:     realm
		traceback: populate_stack(vm)
	}
	if text := message {
		object.set_error_message(mut vm, text)
	}
	return object
}

// Error::set_message
pub fn (mut object Object) set_error_message(mut vm VM, message Utf16String) {
	object.define_direct_property(PropertyName.from_str('message'), Value.from_string(vm.create_string(message)),
		attribute_writable | attribute_configurable)
}

pub fn (object &Object) error_kind() ?ErrorKind {
	data := object.error_data or { return none }
	return data.kind
}

pub fn (object &Object) error_realm() ?&Realm {
	data := object.error_data or { return none }
	return data.realm
}

pub fn (object &Object) error_message() ?string {
	if object.error_data == none {
		return none
	}
	// Embedding diagnostics inspect the error's stored message without
	// executing JavaScript. Ordinary Get is VM-aware and may call a getter.
	message := object.get_without_side_effects(PropertyName.from_str('message'))
	if !message.is_string() {
		return none
	}
	return message.as_string().str()
}

fn append_traceback_frame(mut builder []string, frame TracebackFrame) {
	function_name := frame.function_name.str()
	source_range := frame.source_range()
	filename := source_range.filename().str()
	// Note: Since we don't know whether we have a valid SourceRange here we just check for some default values.
	if filename != '' || source_range.start.line != 0 || source_range.start.column != 0 {
		if function_name == '' {
			builder << '    at ${filename}:${source_range.start.line}:${source_range.start.column}\n'
		} else {
			builder << '    at ${function_name} (${filename}:${source_range.start.line}:${source_range.start.column})\n'
		}
	} else {
		builder << '    at ${if function_name == '' { '<unknown>' } else { function_name }}\n'
	}
}

fn is_same_traceback_frame(a TracebackFrame, b TracebackFrame) bool {
	if a.function_name.is_empty() && b.function_name.is_empty() {
		source_range_a := a.source_range()
		source_range_b := b.source_range()
		return source_range_a.filename() == source_range_b.filename()
			&& source_range_a.start.line == source_range_b.start.line
	}
	return a.function_name == b.function_name
}

// ErrorData::stack_string: roughly follows V8's formatting.
pub fn (data &ErrorData) stack_string(compact bool) string {
	if data.traceback.len == 0 {
		return ''
	}
	mut builder := []string{}
	// Note: We don't want to capture the global execution context, so we omit the last frame.
	// Note: The error's name and message get prepended by Error.prototype.stack.
	mut repetitions := 0
	used_frames := data.traceback.len - 1
	for i in 0 .. used_frames {
		frame := data.traceback[i]
		if compact && i + 1 < used_frames {
			next_traceback_frame := data.traceback[i + 1]
			if is_same_traceback_frame(frame, next_traceback_frame) {
				repetitions++
				continue
			}
		}
		if repetitions > 4 {
			// More than 5 consecutive calls with the same name print the name once
			// and the number of repetitions, so recursive stacks stay readable.
			append_traceback_frame(mut builder, frame)
			builder << '    ${repetitions} more calls\n'
		} else {
			for _ in 0 .. repetitions + 1 {
				append_traceback_frame(mut builder, frame)
			}
		}
		repetitions = 0
	}
	for _ in 0 .. repetitions {
		append_traceback_frame(mut builder, data.traceback[used_frames - 1])
	}
	return builder.join('')
}
