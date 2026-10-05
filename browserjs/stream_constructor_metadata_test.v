module browserjs

import dom

// Bindings/InterfaceObject.cpp initializes each constructor's prototype with
// attribute flags 0 and rejects construction without metadata before touching
// newTarget.prototype. The source controller IDLs have no constructors.
fn test_stream_interface_constructor_source_metadata_and_illegal_construct_order() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{value: 'https://native-stream-constructor-metadata.example.test/'}
	document := &dom.Document{url: url, origin_: url.origin()}
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut writable := WritableStreamHost.create(document)!
	writable.install(mut runtime)!
	mut transform := TransformStreamHost.create(document)!
	transform.install(mut runtime)!
	mut strategies := QueuingStrategyHost.create(document)!
	strategies.install(mut runtime)!
	assert runtime.evaluate_host(r'{const constructors=[ReadableStream,ReadableStreamDefaultReader,ReadableStreamDefaultController,ReadableByteStreamController,WritableStream,WritableStreamDefaultWriter,WritableStreamDefaultController,TransformStream,TransformStreamDefaultController,CountQueuingStrategy,ByteLengthQueuingStrategy];constructors.every(Constructor=>{const descriptor=Object.getOwnPropertyDescriptor(Constructor,"prototype");const prototype=Constructor.prototype;let strict=false;try{(function(){"use strict";Constructor.prototype={}})()}catch(error){strict=error instanceof TypeError}return descriptor.writable===false&&descriptor.enumerable===false&&descriptor.configurable===false&&Constructor.prototype===prototype&&prototype.constructor===Constructor&&strict&&!Reflect.set(Constructor,"prototype",{})})}')! == 'true'
	assert runtime.evaluate_host(r'{const controllers=[ReadableStreamDefaultController,ReadableByteStreamController,WritableStreamDefaultController,TransformStreamDefaultController];controllers.every(Constructor=>{let got=false,construct=false,call=false;const Target=new Proxy(function(){},{get(target,name,receiver){if(name==="prototype"){got=true;throw Symbol("must not get illegal controller prototype")}return Reflect.get(target,name,receiver)}});try{Reflect.construct(Constructor,[],Target)}catch(error){construct=error instanceof TypeError}try{Constructor()}catch(error){call=error instanceof TypeError}return !got&&construct&&call&&Constructor.length===0&&Constructor.prototype.constructor===Constructor})}')! == 'true'
	assert runtime.evaluate_host(r'{class Readable extends ReadableStream{};class Writable extends WritableStream{};class Transform extends TransformStream{};class Count extends CountQueuingStrategy{};const readable=new Readable();const writable=new Writable();const transform=new Transform();const count=new Count({highWaterMark:3});readable instanceof Readable&&readable instanceof ReadableStream&&writable instanceof Writable&&writable instanceof WritableStream&&transform instanceof Transform&&transform instanceof TransformStream&&count instanceof Count&&count.highWaterMark===3&&count.size()===1}')! == 'true'
}
