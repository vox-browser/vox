module browserjs

import dom
import streams
import webidl

fn strategy_host_document() &dom.Document {
	url := dom.URL{'https://native-strategy.example.test/'}
	return &dom.Document{url: url, origin_: url.origin()}
}

fn test_native_strategy_records_store_unrestricted_double_and_share_real_global_size_functions() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := QueuingStrategyHost.create(strategy_host_document())!
	host.install(mut runtime)!
	host.install(mut runtime)!
	assert host.functions.len == 0
	runtime.evaluate_host(r'globalThis.one=new CountQueuingStrategy({highWaterMark:-3});globalThis.two=new CountQueuingStrategy({highWaterMark:NaN});globalThis.bytes=new ByteLengthQueuingStrategy({highWaterMark:Infinity})')!
	assert host.functions.len == 0
	actual := runtime.evaluate_host_value('one')!
	native := unsafe { &streams.CountQueuingStrategy(host.record(actual, .count)!.native) }
	assert native.high_water_mark() == -3
	assert runtime.evaluate_host(r'[one.highWaterMark===-3,Number.isNaN(two.highWaterMark),bytes.highWaterMark===Infinity,one.size===two.size,one.size!==bytes.size,one.size.name==="size",one.size.length===0,bytes.size.name==="size",bytes.size.length===1,one.size()===1,one.size(Symbol())===1,!("prototype" in one.size),!("prototype" in bytes.size),one instanceof CountQueuingStrategy,bytes instanceof ByteLengthQueuingStrategy,Object.prototype.toString.call(bytes)==="[object ByteLengthQueuingStrategy]"].join(",")')! == 'true,true,true,true,true,true,true,true,true,true,true,true,true,true,true,true'
	assert host.functions.len == 2
	assert runtime.evaluate_host(r'{let failed=0;for(const size of [one.size,bytes.size]){try{new size()}catch(error){if(error instanceof TypeError)failed++}}failed===2}')! == 'true'
	callback := host.scope.byte_length_queuing_strategy_size_callback()!
	chunk := runtime.evaluate_host_value('({byteLength:73})')!
	actual_length := webidl.invoke_callback(*callback, none, [runtime.webidl_value(chunk)!])!
	assert (actual_length.number_primitive() or { panic('missing actual number') }) == 73
}

fn test_byte_size_uses_actual_get_v_without_coercion_and_preserves_abrupt_values() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := QueuingStrategyHost.create(strategy_host_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{const bytes=new ByteLengthQueuingStrategy({highWaterMark:0});const original={valueOf(){throw new Error("must not coerce")}};const reason=Symbol("actual GetV failure");let calls=0;const chunk={get byteLength(){calls++;return original}};let abrupt=false;try{bytes.size({get byteLength(){throw reason}})}catch(error){abrupt=error===reason}let nullError=false;try{bytes.size(null)}catch(error){nullError=error instanceof TypeError}bytes.size(chunk)===original&&calls===1&&abrupt&&nullError&&bytes.size(new Uint16Array(3))===6&&bytes.size(3)===undefined&&bytes.size(3n)===undefined&&bytes.size(Symbol())===undefined}')! == 'true'
	assert runtime.evaluate_host(r'{let failed=0;for(const Constructor of [CountQueuingStrategy,ByteLengthQueuingStrategy]){for(const name of ["highWaterMark","size"]){const get=Object.getOwnPropertyDescriptor(Constructor.prototype,name).get;for(const receiver of [{},new (Constructor===CountQueuingStrategy?ByteLengthQueuingStrategy:CountQueuingStrategy)({highWaterMark:0})]){try{get.call(receiver)}catch(error){if(error instanceof TypeError)failed++}}}}failed===8}')! == 'true'
}

fn test_native_strategy_generated_constructor_prototype_dictionary_and_number_order() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut host := QueuingStrategyHost.create(strategy_host_document())!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{const order=[];const prototype={};const Target=new Proxy(function(){},{get(target,name,receiver){if(name==="prototype"){order.push("prototype");return prototype}return Reflect.get(target,name,receiver)}});const init={get highWaterMark(){order.push("hwm");return {valueOf(){order.push("number");return -9}}}};const value=Reflect.construct(CountQueuingStrategy,[init],Target);const hwm=Object.getOwnPropertyDescriptor(CountQueuingStrategy.prototype,"highWaterMark").get.call(value);hwm===-9&&Object.getPrototypeOf(value)===prototype&&order.join(",")==="prototype,hwm,number"}')! == 'true'
	assert runtime.evaluate_host(r'{const original=Symbol("prototype abrupt");let got=false;const Target=new Proxy(function(){},{get(target,name,receiver){if(name==="prototype")throw original;return Reflect.get(target,name,receiver)}});const init={get highWaterMark(){got=true;return 1}};let same=false;try{Reflect.construct(ByteLengthQueuingStrategy,[init],Target)}catch(error){same=error===original}same&&!got}')! == 'true'
	assert runtime.evaluate_host(r'{let errors=0;for(const Constructor of [CountQueuingStrategy,ByteLengthQueuingStrategy]){for(const init of [undefined,null,{},3,{highWaterMark:undefined},{highWaterMark:3n},{highWaterMark:Symbol()}]){try{new Constructor(init)}catch(error){if(error instanceof TypeError)errors++}}try{new Constructor()}catch(error){if(error instanceof TypeError)errors++}try{Constructor({highWaterMark:1})}catch(error){if(error instanceof TypeError)errors++}}class Count extends CountQueuingStrategy{}class Bytes extends ByteLengthQueuingStrategy{}const count=new Count({highWaterMark:true});const bytes=new Bytes({highWaterMark:"4"});errors===18&&count.highWaterMark===1&&bytes.highWaterMark===4&&count instanceof Count&&bytes instanceof Bytes&&CountQueuingStrategy.length===1&&ByteLengthQueuingStrategy.length===1&&CountQueuingStrategy.prototype.constructor===CountQueuingStrategy&&ByteLengthQueuingStrategy.prototype.constructor===ByteLengthQueuingStrategy}')! == 'true'
}

fn test_native_strategy_objects_feed_the_actual_default_stream_queues() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	document := strategy_host_document()
	mut host := QueuingStrategyHost.create(document)!
	host.install(mut runtime)!
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut writable := WritableStreamHost.create(document)!
	writable.install(mut runtime)!
	assert runtime.evaluate_host(r'{const strategy=new CountQueuingStrategy({highWaterMark:3});let controller;const stream=new ReadableStream({start(value){controller=value}},strategy);const before=controller.desiredSize;controller.enqueue({});before===3&&controller.desiredSize===2}')! == 'true'
	assert runtime.evaluate_host(r'{const strategy=new ByteLengthQueuingStrategy({highWaterMark:10});let controller;const stream=new ReadableStream({start(value){controller=value}},strategy);controller.enqueue(new Uint8Array(4));let getCalls=0;const original={valueOf(){throw new Error("wrong numeric coercion")}};let range=false;try{controller.enqueue({get byteLength(){getCalls++;return original}})}catch(error){range=error instanceof RangeError}range&&getCalls===1&&controller.desiredSize===null}')! == 'true'
	runtime.evaluate_host(r'globalThis.strategyDone=false;globalThis.strategyWriteBytes=0;globalThis.strategyWritable=new WritableStream({write(chunk){strategyWriteBytes=chunk.byteLength}},new ByteLengthQueuingStrategy({highWaterMark:12}));globalThis.strategyWriter=strategyWritable.getWriter();strategyWriter.write(new Uint8Array(5)).then(()=>strategyDone=true)')!
	assert runtime.evaluate_host('strategyDone&&strategyWriteBytes===5&&strategyWriter.desiredSize===12')! == 'true'
}
