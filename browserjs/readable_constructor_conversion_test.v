module browserjs

import dom

fn native_readable_conversion_document() &dom.Document {
	url := dom.URL{value: 'https://readable-conversion.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_native_readable_generated_constructor_converts_strategy_before_source_dictionary() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_readable_conversion_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{
 const order=[];const source={get autoAllocateChunkSize(){order.push("auto");return {valueOf(){order.push("auto-number");return 8}}},get cancel(){order.push("cancel")},get pull(){order.push("pull")},get start(){order.push("start")},get type(){order.push("type")}};const strategy={get highWaterMark(){order.push("hwm");return {[Symbol.toPrimitive](hint){order.push(hint);return 1}}},get size(){order.push("size")}};new ReadableStream(source,strategy);order.join(",")==="hwm,number,size,auto,auto-number,cancel,pull,start,type"
}')! == 'true'
	assert runtime.evaluate_host(r'{
 const reason=Symbol("strategy getter first");let sourceGets=0,caught=false;try{new ReadableStream({get autoAllocateChunkSize(){sourceGets++;throw "source dictionary must not run"}},{get highWaterMark(){throw reason}})}catch(value){caught=value===reason}caught&&sourceGets===0
}')! == 'true'
	assert runtime.evaluate_host(r'{
 let strategyGets=0,caught=false;try{new ReadableStream(null,{get highWaterMark(){strategyGets++;return 1}})}catch(error){caught=error instanceof TypeError}caught&&strategyGets===0
}')! == 'true'
}

fn test_native_readable_numbers_use_actual_ecmascript_conversion_and_original_throw() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_readable_conversion_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{
 const operations=[()=>new ReadableStream({}, {highWaterMark:1n}),()=>new ReadableStream({}, {highWaterMark:Symbol()}),()=>new ReadableStream({autoAllocateChunkSize:1n}),()=>new ReadableStream({autoAllocateChunkSize:Symbol()})];operations.every(operation=>{try{operation();return false}catch(error){return error instanceof TypeError}})
}')! == 'true'
	assert runtime.evaluate_host(r'{
 const reason=Symbol("original numeric throw");const operations=[()=>new ReadableStream({}, {highWaterMark:{valueOf(){throw reason}}}),()=>new ReadableStream({autoAllocateChunkSize:{valueOf(){throw reason}}})];operations.every(operation=>{try{operation();return false}catch(value){return value===reason}})
}')! == 'true'
	assert runtime.evaluate_host(r'{
 let sizeGets=0,start=false,caught=false;try{new ReadableStream({type:"bytes",start(){start=true}},{get size(){sizeGets++;return ()=>1},highWaterMark:NaN})}catch(error){caught=error instanceof RangeError}caught&&sizeGets===1&&!start
}')! == 'true'
}

fn test_native_readable_and_reader_subclasses_get_prototype_once_before_argument_conversion() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := ReadableStreamHost.create(native_readable_conversion_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{
 class DerivedStream extends ReadableStream{};class DerivedReader extends ReadableStreamDefaultReader{};const source=new DerivedStream({start(controller){controller.close()}});const reader=new DerivedReader(source);source instanceof DerivedStream&&source instanceof ReadableStream&&reader instanceof DerivedReader&&reader instanceof ReadableStreamDefaultReader&&ReadableStream.prototype.constructor===ReadableStream&&ReadableStreamDefaultReader.prototype.constructor===ReadableStreamDefaultReader&&ReadableStream.length===0&&ReadableStreamDefaultReader.length===1
}')! == 'true'
	assert runtime.evaluate_host(r'{
 let order=[],gets=0;const prototype=Object.create(ReadableStream.prototype);const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;order.push("prototype");return prototype}return Reflect.get(target,key,receiver)}});const source=Reflect.construct(ReadableStream,[{}, {get highWaterMark(){order.push("hwm");return 0},get size(){order.push("size")}}],target);Object.getPrototypeOf(source)===prototype&&gets===1&&order.join(",")==="prototype,hwm,size"
}')! == 'true'
	assert runtime.evaluate_host(r'{
 const reason=Symbol("prototype before required arguments");let gets=0,caught=false;const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;throw reason}return Reflect.get(target,key,receiver)}});try{Reflect.construct(ReadableStreamDefaultReader,[],target)}catch(value){caught=value===reason}caught&&gets===1
}')! == 'true'
	assert runtime.evaluate_host(r'{
 let gets=0;const source=new ReadableStream();const prototype=Object.create(ReadableStreamDefaultReader.prototype);const target=new Proxy(function(){},{get(target,key,receiver){if(key==="prototype"){gets++;return prototype}return Reflect.get(target,key,receiver)}});const reader=Reflect.construct(ReadableStreamDefaultReader,[source],target);Object.getPrototypeOf(reader)===prototype&&gets===1
}')! == 'true'
}
