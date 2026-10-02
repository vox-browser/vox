module libjs

const string_html_test_names = ['anchor', 'big', 'blink', 'bold', 'fixed', 'fontcolor', 'fontsize',
	'italics', 'link', 'small', 'strike', 'sub', 'sup']
const string_html_test_tags = ['a', 'big', 'blink', 'b', 'tt', 'font', 'font', 'i', 'a', 'small',
	'strike', 'sub', 'sup']
const string_html_test_attributes = ['name', '', '', '', '', 'color', 'size', '', 'href', '', '',
	'', '']

fn string_html_call(mut vm VM, index int, receiver Value, arguments []Value) !Value {
	behaviours := [NativeFunctionPointer(string_prototype_anchor), string_prototype_big,
		string_prototype_blink, string_prototype_bold, string_prototype_fixed,
		string_prototype_fontcolor, string_prototype_fontsize, string_prototype_italics,
		string_prototype_link, string_prototype_small, string_prototype_strike, string_prototype_sub,
		string_prototype_sup]
	method := NativeFunction.create_raw(mut vm, vm.realm(), vm.realm().function_prototype,
		behaviours[index], if string_html_test_attributes[index].len == 0 { 0 } else { 1 },
		PropertyName.from_str(string_html_test_names[index]), none)
	return call(mut vm, Value.from_object(method.object), receiver, arguments)
}

fn test_string_html_all_thirteen_wrappers_preserve_tags_and_escape_only_attribute_quotes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	text := Value.from_string(vm.create_string_from_str('<>&"😀'))
	attribute := Value.from_string(vm.create_string_from_str('"&<\'😀"'))
	expected := ['<a name="&quot;&<\'😀&quot;"><>&"😀</a>', '<big><>&"😀</big>',
		'<blink><>&"😀</blink>', '<b><>&"😀</b>', '<tt><>&"😀</tt>',
		'<font color="&quot;&<\'😀&quot;"><>&"😀</font>',
		'<font size="&quot;&<\'😀&quot;"><>&"😀</font>', '<i><>&"😀</i>',
		'<a href="&quot;&<\'😀&quot;"><>&"😀</a>', '<small><>&"😀</small>',
		'<strike><>&"😀</strike>', '<sub><>&"😀</sub>', '<sup><>&"😀</sup>']
	for index, name in string_html_test_names {
		assert string_html_call(mut vm, index, text, [attribute])!.as_string().str() == expected[index]
		if string_html_test_attributes[index].len != 0 {
			result := string_html_call(mut vm, index, Value.from_i32(42), []Value{})!
			assert result.as_string().str() == '<${string_html_test_tags[index]} ${string_html_test_attributes[index]}="undefined">42</${string_html_test_tags[index]}>'
		} else {
			result := string_html_call(mut vm, index, Value.from_bool(false), [
				Value.from_symbol(Symbol.create(none, .unique)),
			])!
			assert result.as_string().str() == '<${string_html_test_tags[index]}>false</${string_html_test_tags[index]}>'
		}
	}
	units := [u16(0xd800), 0, 0xdc00]
	mut wanted := utf16('<a name="')
	wanted << [u16(0xdc00), 0]
	wanted << utf16('&quot;')
	wanted << [u16(0xd800)]
	wanted << utf16('">')
	wanted << units
	wanted << utf16('</a>')
	result := string_html_call(mut vm, 0,
		Value.from_string(vm.create_string(Utf16String.from_slice(units))), [
		Value.from_string(vm.create_string(Utf16String.from_slice([u16(0xdc00), 0, 0x0022, 0xd800]))),
	])!
	assert result.as_string().utf16.data == wanted
	for pair in [['', ''], ['plain', 'plain'], ['"', '&quot;'],
		['""', '&quot;&quot;'], ['"a"b"', '&quot;a&quot;b&quot;'],
		['&quot;', '&quot;']] {
		assert replace_string_html_quotes(utf16_string(pair[0])).str() == pair[1]
	}
}

@[heap]
struct StringHtmlLog {
mut:
	steps []int
}

fn test_string_html_converts_receiver_before_attribute_ignores_unused_values_and_restores_errors() {
	mut vm := VM.create()
	base := create_simple_execution_context(mut vm)
	mut log := &StringHtmlLog{}
	for mode in ['normal', 'receiver throws', 'attribute throws'] {
		mut values := []Value{}
		for index in 0 .. 3 {
			mut object := Object.create(vm.realm(), none)
			converter := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [index, mode, mut log] (mut vm VM) !Value {
				assert vm.argument(0).as_string().str() == 'string'
				log.steps << index
				if index == 2 || (index == 0 && mode == 'receiver throws')
					|| (index == 1 && mode == 'attribute throws') {
					return throw_completion(Value.from_i32(77))
				}
				return Value.from_string(vm.create_string_from_str(if index == 0 {
					'text'
				} else {
					'"'
				}))
			}, 1, PropertyName.from_str('convert'), none)
			object.define_direct_property(PropertyName.from_symbol(vm.well_known_symbol_to_primitive()),
				Value.from_object(converter.object), 7)
			values << Value.from_object(object)
		}
		for index, name in string_html_test_names {
			has_attribute := string_html_test_attributes[index].len != 0
			if result := string_html_call(mut vm, index, values[0], values[1..]) {
				assert mode == 'normal' || (mode == 'attribute throws' && !has_attribute)
				assert result.as_string().str().contains('>text</')
				if has_attribute { assert result.as_string().str().contains('="&quot;"')
				 }
			} else {
				assert mode == 'receiver throws' || (mode == 'attribute throws' && has_attribute)
				assert thrown_value(err).number == 77
			}
			assert log.steps == if has_attribute && mode != 'receiver throws' {
				[0, 1]
			} else {
				[0]
			}
			log.steps.clear()
			for receiver in [js_null(), js_undefined(),
				Value.from_symbol(Symbol.create(none, .unique))] {
				if _ := string_html_call(mut vm, index, receiver, values[1..]) {
					assert false
				} else {
					assert thrown_value(err).as_object().error_kind()? == .type_error
				}
			}
			assert log.steps.len == 0
			if has_attribute {
				if _ := string_html_call(mut vm, index, Value.from_i32(42), [
					Value.from_symbol(Symbol.create(none, .unique)),
				])
				{
					assert false
				} else {
					assert thrown_value(err).as_object().error_kind()? == .type_error
				}
			}
		}
	}
	assert vm.running_execution_context() == base && vm.interpreter_stack().depth() == 0
}
