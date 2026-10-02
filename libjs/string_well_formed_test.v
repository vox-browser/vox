module libjs

fn string_well_formed_fixture_units(text string) ![]u16 {
	mut units := []u16{}
	if text != '-' {
		for offset := 0; offset < text.len; offset += 4 {
			units << u16(text[offset..offset + 4].parse_uint(16, 16)!)
		}
	}
	return units
}

fn test_string_well_formed_scalar_backend_matches_pinned_simdutf_corpus_exactly() {
	corpus := $embed_file('testdata/string-well-formed.tsv').to_string()
	mut count := 0
	for row in corpus.split_into_lines() {
		if row.len == 0 || row.starts_with('#') { continue
		 }
		fields := row.split('\t')
		assert fields.len == 3
		input := string_well_formed_fixture_units(fields[0])!
		output := string_well_formed_fixture_units(fields[2])!
		text := Utf16String.from_slice(input)
		assert text.is_well_formed() == (fields[1] == '1'), row
		assert text.to_well_formed().data == output, row
		assert text.data == input
		count++
	}
	assert count == 2388
}

@[heap]
struct StringWellFormedLog {
mut:
	conversions int
}

fn test_string_well_formed_native_bodies_coerce_once_preserve_pairs_and_propagate_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	text := Utf16String.from_slice([u16(0xd800), 0xd800, 0xdc00, 0xdc00, 0, 0xd800])
	mut log := &StringWellFormedLog{}
	mut receiver := Object.create(vm.realm(), none)
	converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [text, mut log] (mut vm VM) !Value {
		assert vm.argument(0).as_string().str() == 'string'
		log.conversions++
		return Value.from_string(vm.create_string(text))
	}, 1, PropertyName.from_str('convert'), none)
	receiver.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
		Value.from_object(converter.object), 7)
	for well_formed in [false, true] {
		behaviour := if well_formed {
			NativeFunctionPointer(string_prototype_to_well_formed)
		} else {
			NativeFunctionPointer(string_prototype_is_well_formed)
		}
		function := Value.from_object(NativeFunction.create_raw(mut vm, vm.realm(),
			vm.realm().function_prototype, behaviour, 0, PropertyName.from_str('wellFormed'), none).object)
		result := call(mut vm, function, Value.from_object(receiver), []Value{})!
		assert log.conversions == 1
		log.conversions = 0
		if well_formed {
			assert result.as_string().utf16.data == [u16(0xfffd), 0xd800, 0xdc00, 0xfffd, 0, 0xfffd]
		} else {
			assert !result.as_bool()
		}
		for bad in [js_null(), js_undefined(), Value.from_symbol(Symbol.create(none, .unique))] {
			if _ := call(mut vm, function, bad, []Value{}) {
				assert false
			} else {
				assert thrown_value(err).as_object().error_kind()? == .type_error
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
