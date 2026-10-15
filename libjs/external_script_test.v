module libjs

fn test_external_script_retains_real_source_ownership_without_fabricating_an_ast() {
	mut vm := VM.create()
	context := create_simple_execution_context(mut vm)
	realm := context.realm?
	source := '"use strict"; globalThis.answer = 42;'
	mut script := Script.create_external(source, realm, 'https://example.test/external.js', 12,
		voidptr(vm))!
	assert script.external_source_text? == source
	assert script.parsed == unsafe { nil }
	assert script.is_strict_mode
	assert voidptr(script.realm) == voidptr(realm)
	assert script.filename == 'https://example.test/external.js'
	assert script.starting_line == 12
	assert script.host_defined == voidptr(vm)
	if _ := script.compile(mut vm) {
		assert false
	} else {
		assert err.msg().contains('external JavaScript backend')
	}
	empty := Script.create_external('', realm, '', 1, unsafe { nil })!
	assert empty.external_source_text? == ''
	assert !empty.is_strict_mode
	if _ := Script.create_external(source, realm, '', 0, unsafe { nil }) {
		assert false
	} else {
		assert err.msg().contains('positive')
	}
}
