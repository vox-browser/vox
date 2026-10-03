module browserjs

import webidl

fn test_native_quota_exceeded_error_source_fields_conversion_order_and_identity() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_quota_exceeded_error_binding()!
	assert runtime.evaluate_host(r'
 const error=new QuotaExceededError("native quota",{quota:2,requested:3});
 const empty=new QuotaExceededError();class DerivedQuota extends QuotaExceededError{};const derived=new DerivedQuota("derived",null);
 [error instanceof QuotaExceededError,error instanceof DOMException,error.name==="QuotaExceededError",error.message==="native quota",error.code===22,error.quota===2,error.requested===3,empty.quota===null,empty.requested===null,derived instanceof DerivedQuota,derived instanceof QuotaExceededError,derived.quota===null,QuotaExceededError.length===0,Object.prototype.toString.call(error)==="[object QuotaExceededError]"].every(Boolean)
')! == 'true'
	assert runtime.evaluate_host(r'
 const invalids=[{quota:-1},{requested:-1},{quota:4,requested:3}];
 const primitive=invalids.every(options=>{try{new QuotaExceededError("",options);return false}catch(error){return error instanceof RangeError}});
 const nonfinite=[{quota:NaN},{requested:Infinity},{quota:1n},{quota:Object(1n)}].every(options=>{try{new QuotaExceededError("",options);return false}catch(error){return error instanceof TypeError}});
 globalThis.quotaReadOrder=[];const converted=new QuotaExceededError({toString(){quotaReadOrder.push("message");return "coerced"}},{get quota(){quotaReadOrder.push("quota");return {valueOf(){quotaReadOrder.push("quota-number");return "0x2"}}},get requested(){quotaReadOrder.push("requested");return 3.5}});
 globalThis.quotaOriginalReason={original:true};let original;try{new QuotaExceededError("",{get quota(){throw quotaOriginalReason}})}catch(reason){original=reason}
 JSON.stringify([primitive,nonfinite,quotaReadOrder.join(","),converted.quota,converted.requested,original===quotaOriginalReason])
')! == '[true,true,"message,quota,quota-number,requested",2,3.5,true]'
	assert runtime.evaluate_host(r'
 const invalid=[()=>QuotaExceededError(),()=>Object.getOwnPropertyDescriptor(QuotaExceededError.prototype,"quota").get.call({})];invalid.every(test=>{try{test();return false}catch(error){return error instanceof TypeError}})
')! == 'true'
	native := webidl.QuotaExceededError.create('actual source record')
	first := runtime.javascript_quota_exceeded_error(&native)!
	assert first == runtime.javascript_quota_exceeded_error(&native)!
	actual := runtime.native_dom_exception(first)!.dom_exception_ or { panic('missing DOMException source record') }
	assert voidptr(actual) == voidptr(&native.base)
}

fn test_native_quota_constructor_keeps_utf16_tostring_order_and_original_throws() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.install_quota_exceeded_error_binding()!
	actual := runtime.evaluate_host_value(r'new QuotaExceededError(String.fromCharCode(0xd800,0,0xdc00),{quota:0,requested:0.5})')!
	native := runtime.native_dom_exception(actual)!.dom_exception_?
	assert native.message_utf16().code_units() == [u16(0xd800), 0, 0xdc00]
	runtime.define_value_host_function('__quotaUTF16Record', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert runtime.evaluate_host(r'__quotaUTF16Record().message===String.fromCharCode(0xd800,0,0xdc00)&&__quotaUTF16Record().quota===0&&__quotaUTF16Record().requested===0.5')! == 'true'
	assert runtime.evaluate_host(r'{const trace=[];const value=new QuotaExceededError({[Symbol.toPrimitive](hint){trace.push("message:"+hint);return String.fromCharCode(0xd800)}},{get quota(){trace.push("quota");return {[Symbol.toPrimitive](hint){trace.push("quota:"+hint);return 1}}},get requested(){trace.push("requested");return 2}});value.message===String.fromCharCode(0xd800)&&trace.join("|")==="message:string|quota|quota:number|requested"}')! == 'true'
	assert runtime.evaluate_host(r'{const marker={};let same=false;try{new QuotaExceededError({toString(){throw marker}},{get quota(){throw "wrong order"}})}catch(error){same=error===marker}let symbol=false;try{new QuotaExceededError(Symbol())}catch(error){symbol=error instanceof TypeError}same&&symbol}')! == 'true'
}
