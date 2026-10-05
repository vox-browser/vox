module browserjs

import dom

fn test_native_transform_gets_actual_new_target_prototype_once_before_dictionaries() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://transform-prototype.example.test/'}
	mut host := TransformStreamHost.create(&dom.Document{url: url, origin_: url.origin()})!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{
 const order=[],prototype=Object.create(TransformStream.prototype);let gets=0;const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;order.push("prototype");return prototype}return Reflect.get(target,key,receiver)}});const transform=Reflect.construct(TransformStream,[{get start(){order.push("start")}},{get highWaterMark(){order.push("writable");return 1}},{get highWaterMark(){order.push("readable");return 0}}],target);gets===1&&Object.getPrototypeOf(transform)===prototype&&order.join(",")==="prototype,writable,readable,start"&&TransformStream.prototype.constructor===TransformStream&&TransformStream.length===0
}')! == 'true'
	assert runtime.evaluate_host(r'{
 const reason=Symbol("prototype before strategy getter");let gets=0,strategyGets=0,caught=false;const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;throw reason}return Reflect.get(target,key,receiver)}});try{Reflect.construct(TransformStream,[{}, {get highWaterMark(){strategyGets++;return 1}}],target)}catch(value){caught=value===reason}caught&&gets===1&&strategyGets===0
}')! == 'true'
}
