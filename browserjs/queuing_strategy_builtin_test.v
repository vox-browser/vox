module browserjs

import dom

fn test_queuing_strategy_size_is_actual_source_native_builtin_with_original_get_v_receivers() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	url := dom.URL{'https://native-strategy-builtins.example.test/'}
	document := &dom.Document{url: url, origin_: url.origin()}
	mut host := QueuingStrategyHost.create(document)!
	host.install(mut runtime)!
	assert runtime.evaluate_host(r'{const count=new CountQueuingStrategy({highWaterMark:1}),bytes=new ByteLengthQueuingStrategy({highWaterMark:1});globalThis.nativeCountSize=count.size;globalThis.nativeByteSize=bytes.size;[count.size,bytes.size].every((callback,index)=>{const name=Object.getOwnPropertyDescriptor(callback,"name"),length=Object.getOwnPropertyDescriptor(callback,"length");let illegal=false;try{new callback()}catch(error){illegal=error instanceof TypeError}return callback.name==="size"&&callback.length===index&&name.writable===false&&name.enumerable===false&&name.configurable===true&&length.writable===false&&length.enumerable===false&&length.configurable===true&&!Object.prototype.hasOwnProperty.call(callback,"prototype")&&Object.getPrototypeOf(callback)===Function.prototype&&Function.prototype.toString.call(callback).includes("[native code]")&&illegal})&&count.size===new CountQueuingStrategy({highWaterMark:2}).size&&bytes.size===new ByteLengthQueuingStrategy({highWaterMark:2}).size&&count.size({get byteLength(){throw "count must ignore argument"}})===1}')! == 'true'
	assert runtime.evaluate_host(r'{const value={},reason=Symbol("original GetV throw");let calls=0,original=false;const chunk={get byteLength(){calls++;return value}};try{nativeByteSize({get byteLength(){throw reason}})}catch(error){original=error===reason}const result=nativeByteSize(chunk);Object.defineProperty(Number.prototype,"byteLength",{configurable:true,get(){"use strict";return this}});Object.defineProperty(String.prototype,"byteLength",{configurable:true,get(){"use strict";return this}});const primitiveReceivers=nativeByteSize(3)===3&&nativeByteSize("text")==="text";delete Number.prototype.byteLength;delete String.prototype.byteLength;result===value&&calls===1&&original&&primitiveReceivers}')! == 'true'
	count := runtime.evaluate_host_value('nativeCountSize')!
	bytes := runtime.evaluate_host_value('nativeByteSize')!
	assert native_value_host_function_record(count) != none
	assert native_value_host_function_record(bytes) != none
	assert host.functions.len == 2
	assert runtime.evaluate_host(r'{const native=Function.prototype.toString;Object.defineProperty=()=>{throw "author define"};Reflect.apply=()=>{throw "author apply"};nativeCountSize()===1&&nativeByteSize(new Uint8Array(3))===3&&native.call(nativeCountSize).includes("[native code]")}')! == 'true'
	runtime.close()
	assert native_value_host_function_record(count) == none
	assert native_value_host_function_record(bytes) == none
	assert host.functions.len == 0
}
