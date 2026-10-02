module browserjs

import dom

fn test_abort_controller_source_construct_trap_reads_actual_prototype_once_before_native_creation() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{'https://native-abort-prototype.example.test/'}
	document := &dom.Document{url: url, origin_: url.origin()}
	mut host := AbortSignalHost.create(document)!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{let gets=0;const prototype={};const Target=new Proxy(function(){},{get(target,name,receiver){if(name==="prototype"){gets++;return prototype}return Reflect.get(target,name,receiver)}});const controller=Reflect.construct(AbortController,[],Target);const signal=Object.getOwnPropertyDescriptor(AbortController.prototype,"signal").get.call(controller);gets===1&&Object.getPrototypeOf(controller)===prototype&&signal instanceof AbortSignal&&signal===Object.getOwnPropertyDescriptor(AbortController.prototype,"signal").get.call(controller)&&AbortController.prototype.constructor===AbortController}')! == 'true'
	before := host.records.len
	assert runtime.evaluate_host(r'{const reason=Symbol("actual prototype throw");const Target=new Proxy(function(){},{get(target,name,receiver){if(name==="prototype")throw reason;return Reflect.get(target,name,receiver)}});let original=false;try{Reflect.construct(AbortController,[],Target)}catch(error){original=error===reason}original}')! == 'true'
	assert host.records.len == before
	assert runtime.evaluate_host(r'{let got=false;const Target=new Proxy(function(){},{get(target,name,receiver){if(name==="prototype"){got=true;throw "must not lookup illegal constructor prototype"}return Reflect.get(target,name,receiver)}});let illegal=false;try{Reflect.construct(AbortSignal,[],Target)}catch(error){illegal=error instanceof TypeError}illegal&&!got}')! == 'true'
	assert runtime.evaluate_host(r'{class Derived extends AbortController{};const controller=new Derived();const base=Reflect.construct(AbortController,[],new Proxy(function(){},{get(target,name,receiver){if(name==="prototype")return 3;return Reflect.get(target,name,receiver)}}));controller instanceof Derived&&controller instanceof AbortController&&Object.getPrototypeOf(base)===AbortController.prototype&&AbortController.length===0&&AbortSignal.length===0&&Object.getOwnPropertyDescriptor(AbortController,"prototype").writable===false&&Object.getOwnPropertyDescriptor(AbortSignal,"prototype").writable===false}')! == 'true'
}

fn test_native_abort_tags_use_source_prototypes_original_getters_and_unforgeable_records() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{'https://native-abort-tags.example.test/'}
	document := &dom.Document{url: url, origin_: url.origin()}
	mut host := AbortSignalHost.create(document)!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{const controller=new AbortController();const signal=controller.signal;const reason={};signal.onabort=function(event){globalThis.tagAbortTrusted=event.isTrusted&&event.target===signal&&this===signal};controller.abort(reason);const tags=Object.prototype.toString.call(controller)==="[object AbortController]"&&Object.prototype.toString.call(signal)==="[object AbortSignal]"&&Object.getOwnPropertyDescriptor(signal,Symbol.toStringTag)===undefined&&Object.getOwnPropertyDescriptor(controller,Symbol.toStringTag)===undefined;let forged=false;try{Object.getOwnPropertyDescriptor(AbortSignal.prototype,"reason").get.call(Object.create(AbortSignal.prototype))}catch(error){forged=error instanceof TypeError}Object.defineProperty(signal,Symbol.toStringTag,{get(){throw reason}});let original=false;try{Object.prototype.toString.call(signal)}catch(error){original=error===reason}tags&&forged&&original&&tagAbortTrusted&&signal.reason===reason}')! == 'true'
	actual := runtime.evaluate_host_value('AbortSignal.abort("actual native reason")')!
	native := runtime.native_abort_signal(actual)!
	assert voidptr(runtime.native_event_target(actual)!) == voidptr(unsafe { &dom.EventTarget(native) })
	assert voidptr(runtime.javascript_abort_signal(native)!) == voidptr(actual)
	runtime.close()
	assert runtime.native_stream_wrapper_records_.len == 0
}
