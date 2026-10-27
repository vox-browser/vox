module libjs

import math

// LibJS/Print.{h,cpp}: retained UTF-16 output replaces the optional AK builder
// or Stream. Specialized paths cover runtime records translated in this package;
// Date, RegExp, collection, Promise, generator, Intl and Temporal records remain
// dependencies of their corresponding specialized inspectors.
pub struct PrintOptions {
pub:
	strip_ansi  bool
	raw_strings bool
}

struct PrintContext {
mut:
	vm           &VM
	options      PrintOptions
	output       []u16
	seen_objects map[voidptr]&Object
}

fn (mut context PrintContext) out(text string) {
	context.output << utf16_string(text).data
}

fn (mut context PrintContext) out_utf16(text Utf16String) {
	context.output << text.data
}

fn (mut context PrintContext) ansi(code string) {
	if !context.options.strip_ansi { context.out('\x1b[${code}m') }
}

fn (mut context PrintContext) print_type(name Utf16String) {
	context.out('[')
	context.ansi('36;1')
	context.out_utf16(name)
	context.ansi('0')
	context.out(']')
}

// Print.cpp::escape_for_string_literal, preserving all UTF-16 code units that
// the upstream helper does not escape (including tabs, quotes and surrogates).
fn print_escape_string_literal(text Utf16String) Utf16String {
	mut output := []u16{}
	for unit in text.data {
		escaped := match unit {
			u16(`\r`) { '\\r' }
			u16(`\v`) { '\\v' }
			u16(`\f`) { '\\f' }
			u16(`\b`) { '\\b' }
			u16(`\n`) { '\\n' }
			u16(`\\`) { '\\\\' }
			else { '' }
		}
		if escaped.len > 0 { output << utf16_string(escaped).data } else { output << unit }
	}
	return Utf16String.from_slice(output)
}

// Value.cpp::to_utf16_string_without_side_effects, kept separate from ToString
// and recursive Print so diagnostic formatting never invokes coercion hooks.
pub fn (value Value) to_utf16_string_without_side_effects() Utf16String {
	if value.is_string() { return value.as_string().utf16 }
	if value.is_symbol() { return value.as_symbol().descriptive_string() }
	if value.is_bigint() { return value.as_bigint().to_utf16_string() }
	if value.is_number() { return utf16_string(format_f64_value(value.number)) }
	return utf16_string(match value.tag {
		.empty { '<empty>' }
		.undefined { 'undefined' }
		.null { 'null' }
		.boolean {
			if value.as_bool() { 'true' } else { 'false' }
		}
		.object { '[object ${value.as_object().class_name}]' }
		.accessor { '<accessor>' }
		else { panic('Unexpected Value tag') }
	})
}

fn (mut context PrintContext) print_array(array &ArrayObject) ! {
	context.out('[')
	mut first := true
	mut printed_count := 0
	for index := u32(0); index < array.length; index++ {
		key := PropertyName.from_number(index)
		if array.object.internal_get_own_property(key) == none { continue }
		context.out(if first { ' ' } else { ', ' })
		first = false
		value := array.object.get(mut context.vm, key) or { return }
		context.print_value(value)!
		printed_count++
		if printed_count > 100 && index + 1 < array.length {
			context.out(', ...')
			break
		}
	}
	if !first { context.out(' ') }
	context.out(']')
}

fn (mut context PrintContext) print_object(object &Object) ! {
	context.out('${object.class_name}{')
	mut first := true
	original_seen_count := context.seen_objects.len
	mut visited := []Utf16String{}
	mut target := ?&Object(object)
	// Object.cpp::EnumerateObjectProperties: snapshot each level's own keys,
	// discard removed keys and symbols, shadow inherited keys even when hidden.
	for {
		holder := target or { break }
		keys := holder.own_property_keys()
		for key in keys {
			if key.is_symbol() { continue }
			name := if key.is_number() { utf16_string(key.number.str()) } else { key.as_string() }
			if name in visited { continue }
			descriptor := holder.internal_get_own_property(key) or { continue }
			visited << name
			if !(descriptor.enumerable or { false }) { continue }
			context.out(if first { ' ' } else { ', ' })
			first = false
			context.ansi('33;1')
			context.print_value(Value.from_string(context.vm.create_string(name)))!
			context.ansi('0')
			context.out(': ')
			value := object.get(mut context.vm, key) or { return }
			context.print_value(value)!
			if context.seen_objects.len > original_seen_count + 20 { return }
		}
		target = holder.internal_get_prototype_of()
	}
	if !first { context.out(' ') }
	context.out('}')
}

fn (mut context PrintContext) print_array_buffer(buffer &ArrayBufferObject) ! {
	context.print_type(utf16_string('ArrayBuffer'))
	length := buffer.byte_length()
	context.out('\n  byteLength: ')
	context.print_value(Value.from_f64(f64(length)))!
	if buffer.is_detached() {
		context.out('\n  Detached')
		return
	}
	if length == 0 { return }
	bytes := buffer.read_bytes(0, length)
	context.out('\n')
	for index, byte in bytes {
		context.out('${byte:02x}')
		if index + 1 < bytes.len {
			context.out(if (index + 1) % 32 == 0 {
				'\n'
			} else if (index + 1) % 16 == 0 {
				'  '
			} else {
				' '
			})
		}
	}
}

fn (mut context PrintContext) print_data_view(view &DataView) ! {
	record := make_data_view_with_buffer_witness_record(view, .seq_cst)
	context.print_type(utf16_string('DataView'))
	context.out('\n  buffer: ')
	context.print_type(utf16_string('ArrayBuffer'))
	buffer := view.viewed_buffer or { panic('DataView has no buffer') }
	context.out(' @ ${voidptr(buffer)}')
	if is_view_out_of_bounds(record) {
		context.out('\n  <out of bounds>')
		return
	}
	context.out('\n  byteLength: ')
	context.print_value(Value.from_f64(f64(get_view_byte_length(record))))!
	context.out('\n  byteOffset: ')
	context.print_value(Value.from_f64(f64(view.byte_offset())))!
}

fn (mut context PrintContext) print_typed_array(array &TypedArray) ! {
	record := make_typed_array_with_buffer_witness_record(array, .seq_cst)
	context.print_type(utf16_string(array.object.class_name))
	context.out('\n  buffer: ')
	context.print_type(utf16_string('ArrayBuffer'))
	context.out(' @ ${voidptr(array.viewed_buffer)}')
	if is_typed_array_out_of_bounds(record) {
		context.out('\n  <out of bounds>')
		return
	}
	length := typed_array_length(record)
	context.out('\n  length: ')
	context.print_value(Value.from_f64(f64(length)))!
	context.out('\n  byteLength: ')
	context.print_value(Value.from_f64(f64(typed_array_byte_length(record))))!
	context.out('\n[ ')
	mut printed_count := 0
	for index in u32(0) .. length {
		if index > 0 { context.out(', ') }
		byte_index := array.byte_offset + index * array.element_size()
		context.print_value(array.get_value_from_buffer(mut context.vm, uint(byte_index), .unordered, true))!
		printed_count++
		if printed_count > 100 && index < length {
			context.out(', ...')
			break
		}
	}
	context.out(' ]')
}

fn (mut context PrintContext) print_value(value Value) ! {
	if value.is_special_empty_value() {
		context.ansi('34;1')
		context.out('<empty>')
		context.ansi('0')
		return
	}
	if value.is_object() {
		object := value.as_object()
		identity := voidptr(object)
		if identity in context.seen_objects {
			context.out('<already printed Object ${identity}>')
			return
		}
		context.seen_objects[identity] = object
		if array := object.array_object { return context.print_array(array) }
		if value.is_function() {
			context.print_type(utf16_string(object.class_name))
			if object.native_callable {
				context.out(' ')
				context.out_utf16(object.native_initial_name or { Utf16String.new() })
			}
			return
		}
		if object.is_error_object() {
			name := object.get_without_side_effects(PropertyName.from_str('name'))
			message := object.get_without_side_effects(PropertyName.from_str('message'))
			if name.is_accessor() || message.is_accessor() { return context.print_value(value) }
			context.print_type(name.to_utf16_string_without_side_effects())
			text := message.to_utf16_string_without_side_effects()
			if text.len() > 0 {
				context.out(' ')
				context.ansi('31;1')
				context.out_utf16(text)
				context.ansi('0')
			}
			return
		}
		if view := object.data_view { return context.print_data_view(view) }
		if buffer := object.array_buffer { return context.print_array_buffer(buffer) }
		if array := object.typed_array { return context.print_typed_array(array) }
		if wrapper := object.boolean_object {
			context.print_type(utf16_string('Boolean'))
			context.out(' ')
			return context.print_value(Value.from_bool(wrapper.value))
		}
		if wrapper := object.number_object {
			context.print_type(utf16_string('Number'))
			context.out(' ')
			return context.print_value(Value.from_f64(wrapper.value))
		}
		if wrapper := object.string_object {
			context.print_type(utf16_string('String'))
			context.out(' ')
			return context.print_value(Value.from_string(wrapper.value))
		}
		return context.print_object(object)
	}
	if value.is_string() {
		context.ansi('32;1')
	} else if value.is_number() || value.is_bigint() {
		context.ansi('35;1')
	} else if value.is_boolean() || value.is_null() {
		context.ansi('33;1')
	} else if value.is_undefined() {
		context.ansi('34;1')
	}
	if value.is_string() && !context.options.raw_strings {
		context.out('"')
	} else if value.is_number() && value.number == 0 && math.signbit(value.number) {
		context.out('-')
	}
	contents := value.to_utf16_string_without_side_effects()
	context.out_utf16(if value.is_string() && !context.options.raw_strings {
		print_escape_string_literal(contents)
	} else {
		contents
	})
	if value.is_string() && !context.options.raw_strings { context.out('"') }
	context.ansi('0')
}

pub fn inspect_value(mut vm VM, value Value, options PrintOptions) !Utf16String {
	mut context := PrintContext{ vm: &vm, options: options }
	context.print_value(value)!
	return Utf16String.from_slice(context.output)
}
