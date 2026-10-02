module browserjs

import dom

fn test_native_writable_factories_get_actual_new_target_prototype_once_before_conversions() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{'https://writable-prototype.example.test/'}
	mut host := WritableStreamHost.create(&dom.Document{url: url, origin_: url.origin()})!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{
 const order=[],prototype=Object.create(WritableStream.prototype);let gets=0;const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;order.push("prototype");return prototype}return Reflect.get(target,key,receiver)}});const writable=Reflect.construct(WritableStream,[{get start(){order.push("start")}},{get highWaterMark(){order.push("hwm");return 1},get size(){order.push("size")}}],target);gets===1&&Object.getPrototypeOf(writable)===prototype&&order.join(",")==="prototype,hwm,size,start"
}')! == 'true'
	assert runtime.evaluate_host(r'{
 const reason=Symbol("prototype before writer argument validation");let gets=0,caught=false;const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;throw reason}return Reflect.get(target,key,receiver)}});try{Reflect.construct(WritableStreamDefaultWriter,[],target)}catch(value){caught=value===reason}caught&&gets===1
}')! == 'true'
	assert runtime.evaluate_host(r'{
 const prototype=Object.create(WritableStreamDefaultWriter.prototype),writable=new WritableStream();let gets=0;const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;return prototype}return Reflect.get(target,key,receiver)}});const writer=Reflect.construct(WritableStreamDefaultWriter,[writable],target);Object.getPrototypeOf(writer)===prototype&&gets===1&&WritableStream.prototype.constructor===WritableStream&&WritableStreamDefaultWriter.prototype.constructor===WritableStreamDefaultWriter
}')! == 'true'
}
