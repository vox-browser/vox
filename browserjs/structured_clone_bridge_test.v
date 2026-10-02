module browserjs

import webidl

fn test_actual_engine_source_clone_primitives_boxed_records_arrays_aliases_and_cycles() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__cloneSource={};__cloneSource.self=__cloneSource;const shared={value:18446744073709551616n};__cloneSource.array=new Array(4);__cloneSource.array[2]=shared;__cloneSource.again=shared;__cloneSource.boxes=[new Boolean(false),new Number(-0),new String(String.fromCharCode(0xd800)),Object(-18446744073709551616n)];__cloneSource')!
	for for_storage in [false, true] {
		record := bridge.serialize(value, for_storage)!
		cloned := bridge.deserialize(record)!
		runtime.define_value_host_function('__nativeSourceClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
		assert runtime.evaluate_host(r'{const result=__nativeSourceClone(),descriptor=Object.getOwnPropertyDescriptor(result,"self");result!==__cloneSource&&result.self===result&&result.array.length===4&&!(0 in result.array)&&!(1 in result.array)&&result.array[2]===result.again&&result.again!==__cloneSource.again&&result.again.value===18446744073709551616n&&result.boxes[0].valueOf()===false&&Object.is(result.boxes[1].valueOf(),-0)&&result.boxes[2].valueOf()===String.fromCharCode(0xd800)&&result.boxes[3].valueOf()===-18446744073709551616n&&descriptor.writable&&descriptor.enumerable&&descriptor.configurable}')! == 'true'
	}
}

fn test_actual_engine_source_clone_uses_key_descriptor_snapshot_then_hasown_get_order() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__cloneTrace=[];const target={};Object.defineProperty(target,"first",{enumerable:true,configurable:true,get(){__cloneTrace.push("getter");delete target.second;target.added=99;return 1}});Object.defineProperty(target,"second",{enumerable:true,configurable:true,value:2});Object.defineProperty(target,"hidden",{get(){throw new Error("hidden getter")}});target[Symbol("skip")]=()=>0;new Proxy(target,{ownKeys(object){__cloneTrace.push("keys");return Reflect.ownKeys(object)},getOwnPropertyDescriptor(object,key){__cloneTrace.push("desc:"+String(key));return Reflect.getOwnPropertyDescriptor(object,key)},get(object,key,receiver){__cloneTrace.push("get:"+String(key));return Reflect.get(object,key,receiver)}})')!
	record := bridge.serialize(value, false)!
	assert runtime.evaluate_host(r'__cloneTrace.join("|")')! == 'keys|desc:first|desc:second|desc:hidden|desc:first|get:first|getter|desc:second'
	cloned := bridge.deserialize(record)!
	runtime.define_value_host_function('__nativeKeyClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host(r'{const value=__nativeKeyClone();Reflect.ownKeys(value).join(",")==="first"&&value.first===1&&Object.getOwnPropertyDescriptor(value,"first").get===undefined}')! == 'true'
}

fn test_actual_engine_source_clone_map_set_copy_lists_before_nested_getters_and_capture_intrinsics() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__cloneMap=new Map();globalThis.__cloneSet=new Set();const originalMapSet=Map.prototype.set,originalSetAdd=Set.prototype.add;const key={get mutate(){__cloneMap.clear();originalMapSet.call(__cloneMap,"later",99);__cloneSet.clear();originalSetAdd.call(__cloneSet,"later");return 1}};globalThis.__makeSourceSet=()=>{const set=new Set();const item={get mutate(){set.clear();return 4}};originalSetAdd.call(set,item);originalSetAdd.call(set,"tail");return set};__cloneMap.set(key,__cloneMap);__cloneMap.set("tail",2);__cloneSet.add(key);__cloneSet.add("tail");Map.prototype.forEach=()=>{throw new Error("overridden")};Map.prototype.set=()=>{throw new Error("overridden")};Set.prototype.forEach=()=>{throw new Error("overridden")};Set.prototype.add=()=>{throw new Error("overridden")};Reflect.ownKeys=()=>{throw new Error("overridden")};Object.defineProperty=()=>{throw new Error("overridden")};__cloneMap')!
	cloned := bridge.clone(value)!
	runtime.define_value_host_function('__nativeMapClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host(r'{const value=__nativeMapClone(),entries=[...value.entries()];value instanceof Map&&entries.length===2&&entries[0][0].mutate===1&&entries[0][1]===value&&entries[1][0]==="tail"&&entries[1][1]===2}')! == 'true'
	// A separate source Set copiedList must precede its nested getter too.
	set_value := runtime.evaluate_host_value('__makeSourceSet()')!
	set_clone := bridge.clone(set_value)!
	runtime.define_value_host_function('__nativeSetClone', fn [set_clone] (_ voidptr, _ []voidptr) !voidptr { return set_clone })!
	assert runtime.evaluate_host(r'{const value=__nativeSetClone(),items=[...value.values()];value instanceof Set&&items.length===2&&items[0].mutate===4&&items[1]==="tail"}')! == 'true'
}

fn test_actual_engine_source_clone_preserves_thrown_completion_and_releases_temporary_roots() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__cloneMarker={};({get fail(){throw __cloneMarker}})')!
	marker := runtime.evaluate_host_value('__cloneMarker')!
	if _ := bridge.serialize(value, false) {
		assert false
	} else {
		assert err is JavaScriptValueException
		if err is JavaScriptValueException { assert err.value == marker }
	}
	safe := runtime.evaluate_host_value(r'({text:String.fromCharCode(0xd800),integer:18446744073709551616n,nested:{value:1}})')!
	start := runtime.protected_values_.len
	for _ in 0 .. 8 { bridge.serialize(safe, false)! }
	assert runtime.protected_values_.len == start
	for _ in 0 .. 8 {
		cloned := bridge.clone(safe)!
		runtime.release_javascript_value(cloned)
	}
	assert runtime.protected_values_.len == start
	symbol := runtime.evaluate_host_value('Symbol("source")')!
	if _ := bridge.serialize(symbol, false) { assert false } else {
		assert webidl.exception_value(err).dom_exception_?.name() == 'DataCloneError'
	}
	runtime.close()
	if _ := bridge.clone(safe) { assert false } else { assert err.msg().contains('closed') }
}

fn test_actual_engine_source_clone_brands_ignore_forged_prototypes_and_tostringtag() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	bridge := StructuredCloneBridge.create(runtime)!
	value := runtime.evaluate_host_value(r'globalThis.__cloneTagCalls=0;const fake=Object.create(Map.prototype);fake.x=1;Object.defineProperty(fake,Symbol.toStringTag,{get(){++__cloneTagCalls;throw new Error("forged brand")}});({fake,proxy:new Proxy([1],{})})')!
	cloned := bridge.clone(value)!
	runtime.define_value_host_function('__nativeBrandClone', fn [cloned] (_ voidptr, _ []voidptr) !voidptr { return cloned })!
	assert runtime.evaluate_host(r'{const result=__nativeBrandClone();__cloneTagCalls===0&&Object.getPrototypeOf(result.fake)===Object.prototype&&result.fake.x===1&&!Array.isArray(result.proxy)&&Object.getPrototypeOf(result.proxy)===Object.prototype&&result.proxy[0]===1}')! == 'true'
}
