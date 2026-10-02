module browserjs

import webidl

fn test_actual_dom_exception_binding_preserves_one_native_record_and_wrapper() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_exception_binding()!
	value := webidl.dom_exception_value(webidl.DOMException.create('SyntaxError',
		'Invalid font data'))
	first := runtime.javascript_dom_exception(value)!
	assert runtime.javascript_dom_exception(value)! == first
	assert runtime.native_dom_exception(first)!.dom_exception_? == value.dom_exception_?
	runtime.define_value_host_function('__nativeFontError', fn [first] (_ voidptr, _ []voidptr) !voidptr {
		return first
	})!
	assert runtime.evaluate_host('const fontError=__nativeFontError(); fontError instanceof DOMException && fontError.name==="SyntaxError" && fontError.message==="Invalid font data" && fontError.code===12')! == 'true'
	actual := runtime.evaluate_host_value('new DOMException("Unavailable", "NetworkError")')!
	native := runtime.native_dom_exception(actual)!
	assert native.dom_exception_?.name() == 'NetworkError'
	assert runtime.javascript_dom_exception(native)! == actual
	assert runtime.evaluate_host('const marker={};let same=false;try{new DOMException({toString(){throw marker}})}catch(e){same=e===marker}same')! == 'true'
}
