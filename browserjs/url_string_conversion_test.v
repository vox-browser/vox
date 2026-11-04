module browserjs

fn test_url_primitive_string_projection_preserves_utf16_without_a_conversion_call() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	converter := runtime.evaluate_host_value(r'(globalThis.urlConversionCalls=0,function(value){++urlConversionCalls;return `${value}`})')!
	value := runtime.evaluate_host_value(r'String.fromCharCode(65,0xd800,0,0xdc00,0xd83d,0xde00)')!
	assert runtime.url_binding_dom_string(converter, value)!.code_units() == [u16(65), 0xd800, 0, 0xdc00, 0xd83d, 0xde00]
	expected_calls := if disable_primitive_url_string_conversion { '1' } else { '0' }
	assert runtime.evaluate_host('urlConversionCalls')! == expected_calls
	assert runtime.url_binding_dom_string(converter, value)!.to_well_formed().str() == 'A\uFFFD\x00\uFFFD😀'
	for expression in ['""', '"ascii"', '"Привет"', '"😀"'] {
		actual := runtime.evaluate_host_value(expression)!
		assert runtime.url_binding_dom_string(converter, actual)!.code_units() == runtime.native_utf16_string(actual)!.code_units()
	}
}

fn test_url_string_projection_keeps_object_coercion_and_actual_exceptions() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	converter := runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	object := runtime.evaluate_host_value(r'(globalThis.urlConversionHints=[],{[Symbol.toPrimitive](hint){urlConversionHints.push(hint);return "relative"}})')!
	assert runtime.url_binding_dom_string(converter, object)!.str() == 'relative'
	assert runtime.evaluate_host('urlConversionHints.join()')! == 'string'
	throwing := runtime.evaluate_host_value(r'(globalThis.urlConversionMarker={},{toString(){throw urlConversionMarker}})')!
	if _ := runtime.url_binding_dom_string(converter, throwing) {
		assert false, 'Object conversion must preserve its original exception'
	} else {
		assert err is JavaScriptValueException
		if err is JavaScriptValueException {
			assert err.value == runtime.evaluate_host_value('urlConversionMarker')!
		}
	}
	symbol := runtime.evaluate_host_value('Symbol("url")')!
	if _ := runtime.url_binding_dom_string(converter, symbol) {
		assert false, 'DOMString conversion must reject symbols'
	} else {
		assert err is JavaScriptValueException
	}
}

fn test_url_string_projection_rejects_a_closed_runtime_before_reading_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	converter := runtime.evaluate_host_value(r'(function(value){return `${value}`})')!
	value := runtime.evaluate_host_value('"retained"')!
	runtime.close()
	if _ := runtime.url_binding_dom_string(converter, value) {
		assert false, 'Projection cannot use a closed engine context'
	} else {
		assert err.msg().contains('closed')
	}
}
