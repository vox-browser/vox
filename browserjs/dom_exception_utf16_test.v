module browserjs

import libjs
import webidl

fn test_native_dom_exception_constructor_and_getters_preserve_actual_utf16_units() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_exception_binding()!
	actual := runtime.evaluate_host_value(r'new DOMException(String.fromCharCode(0xd800,0,0xd83d,0xde00,0xdc00),String.fromCharCode(0xdc00,78,0xd800))')!
	native := runtime.native_dom_exception(actual)!.dom_exception_?
	assert native.message_utf16().code_units() == [u16(0xd800), 0, 0xd83d, 0xde00, 0xdc00]
	assert native.name_utf16().code_units() == [u16(0xdc00), 78, 0xd800]
	assert native.code() == 0
	runtime.define_value_host_function('__actualUtf16Exception', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert runtime.evaluate_host(r'{const value=__actualUtf16Exception();value.message===String.fromCharCode(0xd800,0,0xd83d,0xde00,0xdc00)&&value.name===String.fromCharCode(0xdc00,78,0xd800)&&value instanceof DOMException}')! == 'true'
	message := libjs.utf16_string_from_code_units([u16(0xd800), 0, 65])
	record := webidl.DOMException.create_utf16_record(libjs.utf16_string('AbortError'), message)
	value := runtime.javascript_dom_exception(webidl.dom_exception_value_for_record(record))!
	runtime.define_value_host_function('__nativeUtf16Exception', fn [value] (_ voidptr, _ []voidptr) !voidptr { return value })!
	assert runtime.evaluate_host('__nativeUtf16Exception().message===String.fromCharCode(0xd800,0,65)&&__nativeUtf16Exception().code===20')! == 'true'
	root_count := runtime.protected_values_.len
	runtime.evaluate_host(r'for(let index=0;index<64;index++){__actualUtf16Exception().name;__actualUtf16Exception().message}')!
	assert runtime.protected_values_.len == root_count
}

fn test_native_dom_exception_utf16_tostring_order_string_hint_and_original_throws() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_exception_binding()!
	assert runtime.evaluate_host(r'globalThis.__exceptionUtf16Trace=[];const value=new DOMException({[Symbol.toPrimitive](hint){__exceptionUtf16Trace.push("message:"+hint);return String.fromCharCode(0xd800)}},{[Symbol.toPrimitive](hint){__exceptionUtf16Trace.push("name:"+hint);return "DataCloneError"}});__exceptionUtf16Trace.join("|")==="message:string|name:string"&&value.message===String.fromCharCode(0xd800)&&value.code===25')! == 'true'
	assert runtime.evaluate_host(r'{const marker={};let same=false;try{new DOMException({toString(){throw marker}})}catch(error){same=error===marker}let symbols=0;for(const invoke of [()=>new DOMException(Symbol()),()=>new DOMException("",Symbol())]){try{invoke()}catch(error){if(error instanceof TypeError)++symbols}}same&&symbols===2}')! == 'true'
}
