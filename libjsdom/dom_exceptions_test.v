// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs

fn exception_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'dom-exceptions.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 10000})!
}

fn test_dom_exception_native_identity_subclassing_and_code_units() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert exception_eval(mut vm, 'class E extends DOMException{value=42}var e=new E("bad","SyntaxError");e instanceof E&&e instanceof DOMException&&e instanceof Error&&e.name==="SyntaxError"&&e.message==="bad"&&e.code===DOMException.SYNTAX_ERR&&e.value===42&&e.toString()==="SyntaxError: bad"&&Object.prototype.toString.call(e)==="[object DOMException]"&&DOMException.NOT_SUPPORTED_ERR===9')!.as_bool()
	assert exception_eval(mut vm, 'var e=new DOMException("\\ud800","\\udfff");e.message.charCodeAt(0)===55296&&e.name.charCodeAt(0)===57343&&e.code===0&&new DOMException().name==="Error"&&new DOMException().message===""&&DOMException.length===0')!.as_bool()
}

fn test_dom_exception_conversion_brand_checks_and_native_algorithm_errors() {
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), html.parse_document('<body></body>'), Hooks{})!
	defer { host.close() }
	assert exception_eval(mut vm, 'var marker={},seen="",caught=false;try{new DOMException({toString(){seen+="m";return "message"}},{toString(){seen+="n";throw marker}})}catch(e){caught=e===marker}var brands=0;for(var name of ["name","message","code"])try{Object.getOwnPropertyDescriptor(DOMException.prototype,name).get.call({})}catch(e){if(e instanceof TypeError)brands++}caught&&seen==="mn"&&brands===3')!.as_bool()
	exception := host.dom_error(mut vm, error('NotSupportedError: duplicate definition'))
	mut global := vm.global_object()
	global.define_direct_property(libjs.PropertyName.from_str('nativeError'), libjs.thrown_value(exception), libjs.attribute_configurable)
	assert exception_eval(mut vm, 'nativeError instanceof DOMException&&nativeError.name==="NotSupportedError"&&nativeError.code===9&&nativeError.message==="duplicate definition"')!.as_bool()
	marker := libjs.Value.from_object(libjs.Object.create(vm.realm(), none))
	assert libjs.thrown_value(host.dom_error(mut vm, libjs.throw_completion(marker))).cell == marker.cell
}
