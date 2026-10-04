module browserjs

import dom
import fileapi

fn native_blob_constructor_runtime() &Runtime {
	mut runtime := Runtime.create()
	url := dom.URL{'https://native-blob-constructor.example.test/'}
	document := &dom.Document{ url: url, origin_: url.origin() }
	mut readable := ReadableStreamHost.create(document) or { panic(err) }
	readable.install(mut runtime) or { panic(err) }
	mut host := BlobHost.create(document) or { panic(err) }
	host.install(mut runtime) or { panic(err) }
	host.install_constructor() or { panic(err) }
	return runtime
}

fn test_native_blob_constructor_converts_actual_source_parts_before_copying_after_options() {
	$if !darwin {
		return
	}
	mut runtime := native_blob_constructor_runtime()
	defer { runtime.close() }
	original := fileapi.Blob.create('Q'.bytes(), '')
	actual := runtime.javascript_blob(original)!
	runtime.define_value_host_function('__originalBlobPart', fn [actual] (_ voidptr, _ []voidptr) !voidptr {
		return actual
	})!
	value := runtime.evaluate_host_value('globalThis.blobConstructorOrder=[];globalThis.blobConstructorBuffer=new Uint8Array([1,2,3]);const iterable={*[Symbol.iterator](){blobConstructorOrder.push("iterator");yield {toString(){blobConstructorOrder.push("string");return String.fromCharCode(0xd800)+"\\r\\n"}};yield blobConstructorBuffer.subarray(1);yield __originalBlobPart()}};const options={get endings(){blobConstructorOrder.push("endings");return "native"},get type(){blobConstructorOrder.push("type");blobConstructorBuffer[1]=9;return "TeXT/PLAIN"}};globalThis.constructedBlob=new Blob(iterable,options);constructedBlob')!
	blob := runtime.native_blob(value)!
	assert blob.raw_bytes() == [u8(0xEF), 0xBF, 0xBD, `\n`, 9, 3, `Q`]
	assert blob.type_() == 'text/plain'
	assert runtime.evaluate_host('blobConstructorOrder.join(",")==="iterator,string,endings,type"&&constructedBlob instanceof Blob&&Blob.length===0&&Blob.prototype.constructor===Blob&&Object.getOwnPropertyDescriptor(Blob,"prototype").writable===false')! == 'true'
	value2 := runtime.evaluate_host_value('const buffer=new ArrayBuffer(2);new Uint8Array(buffer).set([7,8]);new Blob([buffer],{get type(){buffer.transfer();return ""}})')!
	assert runtime.native_blob(value2)!.raw_bytes().len == 0
	assert runtime.evaluate_host('new Blob().size===0&&new Blob(undefined,null).size===0&&new Blob([null,undefined,1n,true]).size===18&&new Blob([],{type:"text/plain;v=é"}).type===""')! == 'true'
}

fn test_native_blob_constructor_retains_source_failures_iterator_behavior_and_prototypes() {
	$if !darwin {
		return
	}
	mut runtime := native_blob_constructor_runtime()
	defer { runtime.close() }
	assert runtime.evaluate_host('globalThis.blobConstructorMarker={};globalThis.blobIteratorClosed=false;const iterator={ [Symbol.iterator](){return this},next(){return {done:false,value:Symbol()}},return(){blobIteratorClosed=true;return {done:true}}};let unionFailure=false;try{new Blob(iterator)}catch(reason){unionFailure=reason instanceof TypeError}let marker=false;try{new Blob([{toString(){throw blobConstructorMarker}}])}catch(reason){marker=reason===blobConstructorMarker}unionFailure&&marker&&!blobIteratorClosed')! == 'true'
	assert runtime.evaluate_host('const failures=[()=>Blob(),()=>new Blob(null),()=>new Blob("abc"),()=>new Blob([],{endings:"invalid"}),()=>new Blob([],1),()=>new Blob([new Uint8Array(new ArrayBuffer(2,{maxByteLength:4}))])];failures.every(call=>{try{call();return false}catch(reason){return reason instanceof TypeError}})')! == 'true'
	assert runtime.evaluate_host('class Child extends Blob{};const child=new Child(["a"]);function Target(){}Target.prototype=null;const fallback=Reflect.construct(Blob,[],Target);child instanceof Child&&child instanceof Blob&&Object.getPrototypeOf(fallback)===Blob.prototype')! == 'true'
	assert runtime.evaluate_host('globalThis.blobPrototypeOrder=[];const target=new Proxy(function(){},{get(object,name){blobPrototypeOrder.push(name);if(name==="prototype")return Blob.prototype;return Reflect.get(object,name)}});const bits={get [Symbol.iterator](){blobPrototypeOrder.push("iterator");return function*(){yield "a"}}};Reflect.construct(Blob,[bits],target);blobPrototypeOrder.join(",")==="prototype,iterator"')! == 'true'
	assert runtime.evaluate_host('const get=Object.getOwnPropertyDescriptor,global=get(globalThis,"Blob"),prototype=get(Blob,"prototype"),name=get(Blob,"name"),length=get(Blob,"length"),constructor=get(Blob.prototype,"constructor");global.value===Blob&&global.writable&&!global.enumerable&&global.configurable&&prototype.value===Blob.prototype&&!prototype.writable&&!prototype.enumerable&&!prototype.configurable&&name.value==="Blob"&&!name.writable&&!name.enumerable&&name.configurable&&length.value===0&&!length.writable&&!length.enumerable&&length.configurable&&constructor.value===Blob&&constructor.writable&&!constructor.enumerable&&constructor.configurable&&Reflect.ownKeys(Blob).length===3')! == 'true'
	assert runtime.evaluate_host('let failure;try{Blob()}catch(reason){failure=reason}failure instanceof TypeError&&failure.message==="Blob constructor must be called with \'new\'"')! == 'true'
	assert runtime.evaluate_host('{const unit=String.fromCharCode(0xd800);let failure;try{new Blob([],{endings:unit})}catch(reason){failure=reason}failure instanceof TypeError&&failure.message==="Invalid value \'"+unit+"\' for enumeration type \'EndingType\'"}')! == 'true'
	assert runtime.evaluate_host('{const marker=blobConstructorMarker;const failures=[()=>new Blob(new Proxy([],{get(object,name){if(name===Symbol.iterator)throw marker;return Reflect.get(object,name)}})),()=>new Blob({[Symbol.iterator](){return {next(){throw marker}}}}),()=>new Blob({[Symbol.iterator](){return {next(){return {get done(){throw marker}}}}}}),()=>new Blob({[Symbol.iterator](){return {next(){return {done:false,get value(){throw marker}}}}}}),()=>Reflect.construct(Blob,[],new Proxy(function(){},{get(){throw marker}})),()=>new Blob([],{get type(){throw marker}})];failures.every(call=>{try{call();return false}catch(reason){return reason===marker}})}')! == 'true'
}
