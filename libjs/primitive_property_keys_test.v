module libjs

fn test_primitive_property_keys_preserve_indices_symbols_and_string_storage() {
	defer { set_primitive_property_keys_for_testing(true) }
	for enabled in [false, true] {
		set_primitive_property_keys_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		diagnose_primitive_property_keys_for_testing(true)
		for name in ['length', 'className', '0', '4294967294', '4294967295', '-0', '01', '', 'x\x00y', '😀'] {
			text := vm.create_string_from_str(name)
			assert Value.from_string(text).to_property_key(mut vm)!.equals(PropertyName.from_utf16(text.utf16))
		}
		symbol := Symbol.create(utf16_string('key'), .unique)
		assert voidptr(Value.from_symbol(symbol).to_property_key(mut vm)!.as_symbol()) == voidptr(symbol)
		activity := diagnose_primitive_property_keys_for_testing(false)
		assert (activity.strings > 0 && activity.symbols > 0) == enabled
		for source in [
			'var n=0;var k={toString(){n++;return "x"}};var o={x:42};o[k]===42&&n===1',
			'var log="";var k={[Symbol.toPrimitive](hint){log+=hint;return "x"}};var o={get x(){log+="g";return 42}};o[k]===42&&log==="stringg"',
			'var n=0;var k={toString(){n++;throw 42}};var threw=false;try{({})[k]}catch(e){threw=e===42}threw&&n===1',
			'var n=0;var k={toString(){n++;return "x"}};try{null[k]}catch(e){}n===0',
			'var o={undefined:1,null:2,true:3,42:4};o[undefined]+o[null]+o[true]+o[42]===10',
		] {
			mut script := Script.parse(source, vm.realm(), 'primitive-keys.js', unsafe { nil })!
			assert vm.run(mut script)!.to_boolean(), source
		}
	}
}
