// SPDX-License-Identifier: BSD-2-Clause
module libjs

// Runtime/JSONObject.cpp::parse/parse_json/InternalizeJSONProperty. The native
// simdjson dependency is replaced by a strict UTF-16 JSON grammar; JavaScript
// conversion, ordinary property creation and reviver semantics stay in the VM.
// stringify/rawJSON are separate runtime slices, not host JSON substitutes.
fn create_json_object(mut vm VM, realm &Realm) &Object {
	mut object := Object.create(realm, realm.object_prototype)
	install_intrinsic_method(mut vm, realm, mut object, 'parse', 2, json_parse)
	object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_string_tag()),
		Value.from_string(vm.create_string_from_str('JSON')), attribute_configurable)
	return object
}

@[heap]
struct JSONParseRecord {
	value    Value
	start    int
	end_     int
	children map[string]&JSONParseRecord
}

struct JSONPropertyKeyCacheEntry {
	start int
	end_  int
	key   ?PropertyName
}

struct JSONTextParser {
	text          []u16
	record_source bool
	stack         StackInfo
mut:
	position      int
	property_keys [128]JSONPropertyKeyCacheEntry
}

struct JSONStringToken {
	start       int
	end_        int
	has_escapes bool
}

fn (mut parser JSONTextParser) take(mut vm VM) !u16 {
	vm.consume_execution_budget()!
	if parser.position >= parser.text.len {
		return vm.throw_error_type(.syntax_error, .json_malformed)
	}
	character := parser.text[parser.position]
	parser.position++
	return character
}

fn (mut parser JSONTextParser) whitespace(mut vm VM) ! {
	for parser.position < parser.text.len && parser.text[parser.position] in [u16(9), 10, 13, 32] {
		parser.take(mut vm)!
	}
}

fn (parser &JSONTextParser) at(character u16) bool {
	return parser.position < parser.text.len && parser.text[parser.position] == character
}

fn json_hex_digit(character u16) int {
	if character >= `0` && character <= `9` { return int(character - `0`) }
	if character >= `a` && character <= `f` { return int(character - `a`) + 10 }
	if character >= `A` && character <= `F` { return int(character - `A`) + 10 }
	return -1
}

// Validate each source code unit once, retaining its range rather than growing
// a temporary UTF-16 array for the common unescaped string case.
fn (mut parser JSONTextParser) string_token(mut vm VM) !JSONStringToken {
	if parser.take(mut vm)! != `"` { return vm.throw_error_type(.syntax_error, .json_malformed) }
	start := parser.position
	mut has_escapes := false
	for {
		character := parser.take(mut vm)!
		if character == `"` {
			return JSONStringToken{ start: start, end_: parser.position - 1, has_escapes: has_escapes }
		}
		if character < 0x20 { return vm.throw_error_type(.syntax_error, .json_malformed) }
		if character != `\\` { continue }
		has_escapes = true
		escaped := parser.take(mut vm)!
		match escaped {
			`"`, `\\`, `/`, `b`, `f`, `n`, `r`, `t` {}
			`u` {
				for _ in 0 .. 4 {
					digit := json_hex_digit(parser.take(mut vm)!)
					if digit < 0 { return vm.throw_error_type(.syntax_error, .json_malformed) }
				}
			}
			else { return vm.throw_error_type(.syntax_error, .json_malformed) }
		}
	}
	return error('Unreachable JSON string parser')
}

fn (parser &JSONTextParser) decode_string(token JSONStringToken) Utf16String {
	if !token.has_escapes {
		// Ladybird ed7562519e69: construct unescaped strings directly from
		// their source storage. Vox already parses UTF-16, preserving lone
		// surrogates without a UTF-8 conversion or an intermediate builder.
		return utf16_string_from_code_units(parser.text[token.start..token.end_])
	}
	mut units := []u16{cap: token.end_ - token.start}
	mut position := token.start
	for position < token.end_ {
		character := parser.text[position]
		position++
		if character != `\\` {
			units << character
			continue
		}
		escaped := parser.text[position]
		position++
		match escaped {
			`"`, `\\`, `/` { units << escaped }
			`b` { units << u16(8) }
			`f` { units << u16(12) }
			`n` { units << u16(10) }
			`r` { units << u16(13) }
			`t` { units << u16(9) }
			`u` {
				mut unit := u16(0)
				for _ in 0 .. 4 {
					unit = (unit << 4) | u16(json_hex_digit(parser.text[position]))
					position++
				}
				units << unit
			}
			else { panic('Invalid validated JSON escape') }
		}
	}
	return utf16_string_from_code_units(units)
}

fn (mut parser JSONTextParser) string_value(mut vm VM) !Utf16String {
	token := parser.string_token(mut vm)!
	return parser.decode_string(token)
}

fn (mut parser JSONTextParser) property_name(mut vm VM) !PropertyName {
	token := parser.string_token(mut vm)!
	raw := unsafe { parser.text[token.start..token.end_] }
	// Ladybird 9ac3fde4d8ba: reuse decoded keys within one parse. The
	// bounded direct-mapped cache retains source ranges, so even escaped
	// keys avoid another decode on a hit without allocating lookup strings.
	mut hash := u64(raw.len) * 31
	if raw.len > 0 { hash += u64(raw[0]) * 17 + u64(raw.last()) }
	slot := int(hash % u64(parser.property_keys.len))
	entry := parser.property_keys[slot]
	if key := entry.key {
		// Hash collisions must compare the complete raw UTF-16 spelling.
		if raw == parser.text[entry.start..entry.end_] { return key }
	}
	key := PropertyName.from_utf16(parser.decode_string(token))
	parser.property_keys[slot] = JSONPropertyKeyCacheEntry{
		start: token.start
		end_: token.end_
		key: key
	}
	return key
}

fn (mut parser JSONTextParser) digits(mut vm VM) ! {
	start := parser.position
	for parser.position < parser.text.len && parser.text[parser.position] >= `0` && parser.text[parser.position] <= `9` {
		parser.take(mut vm)!
	}
	if parser.position == start { return vm.throw_error_type(.syntax_error, .json_malformed) }
}

fn (mut parser JSONTextParser) number_value(mut vm VM) !Value {
	start := parser.position
	if parser.at(`-`) { parser.take(mut vm)! }
	if parser.at(`0`) { parser.take(mut vm)! } else { parser.digits(mut vm)! }
	if parser.at(`.`) {
		parser.take(mut vm)!
		parser.digits(mut vm)!
	}
	if parser.at(`e`) || parser.at(`E`) {
		parser.take(mut vm)!
		if parser.at(`+`) || parser.at(`-`) { parser.take(mut vm)! }
		parser.digits(mut vm)!
	}
	return Value.from_f64(string_to_number(utf16_string_from_code_units(parser.text[start..parser.position])))
}

fn (mut parser JSONTextParser) value(mut vm VM, depth int) !&JSONParseRecord {
	vm.consume_execution_budget()!
	if depth > 512 || parser.stack.size_free() < 512 * 1024 {
		return vm.throw_error(.range_error, 'JSON nesting limit exceeded')
	}
	parser.whitespace(mut vm)!
	start := parser.position
	mut result := js_undefined()
	mut children := map[string]&JSONParseRecord{}
	if parser.at(`"`) {
		result = Value.from_string(vm.create_string(parser.string_value(mut vm)!))
	} else if parser.at(`{`) || parser.at(`[`) {
		array := parser.at(`[`)
		parser.take(mut vm)!
		mut object := if array {
			ArrayObject.create(mut vm, vm.realm(), 0, vm.realm().array_prototype_record())!.object
		} else {
			Object.create(vm.realm(), vm.realm().object_prototype)
		}
		close := if array { u16(`]`) } else { u16(`}`) }
		parser.whitespace(mut vm)!
		mut index := u32(0)
		if !parser.at(close) {
			for {
				key := if array {
					PropertyName.from_number(index)
				} else {
					name := parser.property_name(mut vm)!
					parser.whitespace(mut vm)!
					if parser.take(mut vm)! != `:` {
						return vm.throw_error_type(.syntax_error, .json_malformed)
					}
					name
				}
				child := parser.value(mut vm, depth + 1)!
				object.create_data_property_or_throw(mut vm, key, child.value)!
				if parser.record_source { children[key.str()] = child }
				index++
				parser.whitespace(mut vm)!
				if parser.at(close) { break }
				if parser.take(mut vm)! != `,` {
					return vm.throw_error_type(.syntax_error, .json_malformed)
				}
				parser.whitespace(mut vm)!
			}
		}
		parser.take(mut vm)!
		result = Value.from_object(object)
	} else if parser.at(`t`) || parser.at(`f`) || parser.at(`n`) {
		word := if parser.at(`t`) {
			'true'
		} else if parser.at(`f`) {
			'false'
		} else {
			'null'
		}
		for character in word {
			if parser.take(mut vm)! != u16(character) {
				return vm.throw_error_type(.syntax_error, .json_malformed)
			}
		}
		result = if word == 'null' { js_null() } else { Value.from_bool(word == 'true') }
	} else {
		result = parser.number_value(mut vm)!
	}
	return &JSONParseRecord{ value: result, start: start, end_: parser.position, children: children }
}

fn json_parse(mut vm VM) !Value {
	text := vm.argument(0).to_primitive_string(mut vm)!.utf16
	reviver := vm.argument(1)
	stack := StackInfo.new()
	mut parser := JSONTextParser{ text: text.as_slice(), record_source: reviver.is_function(), stack: stack }
	record := parser.value(mut vm, 0)!
	parser.whitespace(mut vm)!
	if parser.position != parser.text.len {
		return vm.throw_error_type(.syntax_error, .json_malformed)
	}
	if !reviver.is_function() { return record.value }
	mut root := Object.create(vm.realm(), vm.realm().object_prototype)
	key := PropertyName.from_str('')
	root.create_data_property_or_throw(mut vm, key, record.value)!
	return internalize_json_property(mut vm, root, key, reviver, record, text, stack, 0)
}

fn internalize_json_property(mut vm VM, holder &Object, key PropertyName, reviver Value, record ?&JSONParseRecord, text Utf16String, stack StackInfo, depth int) !Value {
	vm.consume_execution_budget()!
	if depth > 512 || stack.size_free() < 512 * 1024 {
		return vm.throw_error(.range_error, 'JSON reviver nesting limit exceeded')
	}
	value := holder.get(mut vm, key)!
	mut context := Object.create(vm.realm(), vm.realm().object_prototype)
	mut children := map[string]&JSONParseRecord{}
	if original := record {
		if same_value(original.value, value) {
			children = original.children
			if !value.is_object() {
				context.create_data_property_or_throw(mut vm, PropertyName.from_str('source'),
					Value.from_string(vm.create_string(utf16_string_from_code_units(text.as_slice()[original.start..original.end_]))))!
			}
		}
	}
	if value.is_object() {
		mut object := value.as_object()
		mut keys := []PropertyName{}
		if value.is_array(mut vm)! {
			length := length_of_array_like(mut vm, object)!
			for index in u64(0) .. length {
				vm.consume_execution_budget()!
				keys << PropertyName.from_str(index.str())
			}
		} else {
			for name in object.own_property_keys() {
				vm.consume_execution_budget()!
				if name.is_symbol() { continue }
				descriptor := object.internal_get_own_property(name) or { continue }
				if descriptor.enumerable or { false } { keys << name }
			}
		}
		for name in keys {
			child := if original := children[name.str()] {
				?&JSONParseRecord(original)
			} else {
				none
			}
			replacement := internalize_json_property(mut vm, object, name, reviver, child, text, stack, depth + 1)!
			if replacement.is_undefined() {
				object.internal_delete(name)
			} else {
				object.create_data_property(mut vm, name, replacement)!
			}
		}
	}
	return call(mut vm, reviver, Value.from_object(holder), [key.to_value(mut vm), value,
		Value.from_object(context)])
}
