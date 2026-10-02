module browserjs

fn test_dom_exception_constructor_uses_actual_native_fields_codes_and_prototype() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_exception_binding()!
	runtime.evaluate_host(dom_exception_bootstrap())!
	assert runtime.evaluate_host(r'
 const defaultException=new DOMException();
 const abort=new DOMException("stop","AbortError");
 defaultException.name==="Error"&&defaultException.message===""&&defaultException.code===0&&abort.name==="AbortError"&&abort.message==="stop"&&abort.code===20&&abort instanceof DOMException&&abort instanceof Error&&Object.prototype.toString.call(abort)==="[object DOMException]"&&String(abort)==="AbortError: stop"&&Object.getPrototypeOf(DOMException)===Function.prototype;
 ')! == 'true'
	assert runtime.evaluate_host('new DOMException("ignored","DOMStringSizeError").code===0&&new DOMException("ignored","ValidationError").code===0&&DOMException.DOMSTRING_SIZE_ERR===2&&DOMException.prototype.DATA_CLONE_ERR===25')! == 'true'
	assert runtime.evaluate_host('Object.getOwnPropertyDescriptor(DOMException,"prototype").writable===false&&Object.getOwnPropertyDescriptor(DOMException.prototype,"message").enumerable&&Object.getOwnPropertyDescriptor(DOMException.prototype,"code").set===undefined')! == 'true'
}

fn test_dom_exception_binding_preserves_idl_string_conversion_and_receiver_brand() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_dom_exception_binding()!
	runtime.evaluate_host(dom_exception_bootstrap())!
	assert runtime.evaluate_host(r'
 let rejected=0;for(const invoke of [function(){DOMException();},function(){new DOMException(Symbol());},function(){new DOMException("",Symbol());},function(){Object.getOwnPropertyDescriptor(DOMException.prototype,"name").get.call({});}]){try{invoke();}catch(error){if(error instanceof TypeError)rejected++;}}
 const converted=new DOMException(null,{toString:function(){return "InvalidStateError";}});
 rejected===4&&converted.message==="null"&&converted.name==="InvalidStateError"&&converted.code===11&&DOMException.length===0;
 ')! == 'true'
}
