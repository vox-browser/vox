// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand
import platform

fn typed_intrinsic_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'typed-array-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 300000})
}

fn test_typed_array_production_graph_all_element_types_and_abstract_metadata() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var rows=[[BigInt64Array,8],[BigUint64Array,8],[Float16Array,2],[Float32Array,4],[Float64Array,8],[Int8Array,1],[Int16Array,2],[Int32Array,4],[Uint8Array,1],[Uint16Array,2],[Uint32Array,4],[Uint8ClampedArray,1]],T=Object.getPrototypeOf(Uint8Array),P=Object.getPrototypeOf(Uint8Array.prototype);rows.every(([C,size])=>{var a=new C(2);return C.length===3&&C.BYTES_PER_ELEMENT===size&&C.prototype.BYTES_PER_ELEMENT===size&&Object.getPrototypeOf(C)===T&&Object.getPrototypeOf(C.prototype)===P&&a instanceof C&&a.length===2&&a.byteLength===2*size&&a.buffer instanceof ArrayBuffer&&Object.prototype.toString.call(a)==="[object "+C.name+"]"&&C[Symbol.species]===C})&&T.name==="TypedArray"&&T.length===0&&T.prototype===P&&Object.getPrototypeOf(P)===Object.prototype&&P[Symbol.iterator]===P.values&&P.toString===Array.prototype.toString&&!Object.getOwnPropertyDescriptor(Uint8Array,"prototype").writable&&!Object.getOwnPropertyDescriptor(Uint8Array,"BYTES_PER_ELEMENT").configurable')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var count=0,T=Object.getPrototypeOf(Uint8Array);for(var f of [()=>Uint8Array(1),()=>Float64Array(1),()=>BigInt64Array(1),()=>T(),()=>new T()])try{f()}catch(e){if(e instanceof TypeError)count++}count===5&&typeof TypedArray==="undefined"')!.as_bool()
}

fn test_typed_array_construction_lengths_iterables_arraylikes_and_live_conversion_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'new Uint8Array().length===0&&new Uint8Array(3).join()==="0,0,0"&&new Uint8Array([1,257,-1]).join()==="1,1,255"&&new Uint8Array("3").length===3&&Uint8Array.from("123").join()==="1,2,3"&&new Uint8Array(new Set([3,2,1])).join()==="3,2,1"&&new Float64Array({length:2,0:1.5,1:2.25}).join()==="1.5,2.25"')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var log="",source={get [Symbol.iterator](){log+="i";return undefined},get length(){log+="l";return 2},get 0(){log+="0";return {valueOf(){log+="v";return 4}}},get 1(){log+="1";return 5}},a=new Uint8Array(source);a.join()==="4,5"&&log==="il0v1"')!.as_bool()
}

fn test_typed_array_buffers_views_dataview_aliasing_and_numeric_storage() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var b=new ArrayBuffer(16),a=new Uint8Array(b,2,4),d=new DataView(b);a.set([1,2,3,4]);a.buffer===b&&a.byteOffset===2&&a.byteLength===4&&d.getUint8(2)===1&&(d.setUint8(3,9),a[1]===9)&&new Uint16Array(b,2,2)[0]===2305&&ArrayBuffer.isView(a)&&ArrayBuffer.isView(d)&&!ArrayBuffer.isView(new Proxy(a,{}))')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var f=new Float64Array([Math.PI,-0,Infinity,NaN]),copy=new Float64Array(f),bytes=new Uint8Array(f.buffer);copy.buffer!==f.buffer&&copy[0]===Math.PI&&Object.is(copy[1],-0)&&copy[2]===Infinity&&Number.isNaN(copy[3])&&bytes.byteLength===32&&new Int8Array([255,-129]).join()==="-1,127"&&new Uint8ClampedArray([-1,0.5,1.5,2.5,256]).join()==="0,0,2,2,255"')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var f=new Float16Array([1.5,-2]),d=new DataView(f.buffer);f[0]===1.5&&f[1]===-2&&d.getUint16(0,true)===15872&&d.getUint16(2,true)===49152')!.as_bool()
}

fn test_typed_array_bigint_storage_signedness_and_content_type_checks() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var a=new BigInt64Array([-1n,9223372036854775808n]),u=new BigUint64Array(a.buffer);a[0]===-1n&&a[1]===-9223372036854775808n&&u[0]===18446744073709551615n&&u[1]===9223372036854775808n&&BigInt64Array.from(["1","2"]).join()==="1,2"&&new BigInt64Array([1234567n]).toLocaleString("en-US")==="1,234,567"')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var errors=0;for(var f of [()=>new BigInt64Array([1]),()=>new Uint8Array([1n]),()=>new Uint8Array(new BigInt64Array(1)),()=>new BigInt64Array(new Uint8Array(1))])try{f()}catch(e){if(e instanceof TypeError)errors++}errors===4')!.as_bool()
}

fn test_typed_array_from_of_mapping_this_argument_and_inherited_static_methods() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'class U extends Uint8Array{}var a=U.from([1,2],function(v,i){return v+this.add+i},{add:3}),b=U.of(5,6);a instanceof U&&b instanceof U&&a.join()==="4,6"&&b.join()==="5,6"&&Uint8Array.from===Float64Array.from&&Uint8Array.from.length===1&&Uint8Array.of.length===0')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var reads=0,bad=false,source={get [Symbol.iterator](){reads++;return undefined}};try{Uint8Array.from.call({},source)}catch(e){bad=e instanceof TypeError}bad&&reads===0&&(function(){try{Uint8Array.from(null);return false}catch(e){return e instanceof TypeError}})()')!.as_bool()
}

fn test_typed_array_shared_methods_copies_views_iterators_and_numeric_sorting() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var a=new Uint8Array([10,2,1]),view=a.subarray(1),copy=a.slice(1),sorted=a.toSorted(),reversed=a.toReversed(),changed=a.with(0,7);view.buffer===a.buffer&&copy.buffer!==a.buffer&&copy.join()==="2,1"&&sorted.join()==="1,2,10"&&reversed.join()==="1,2,10"&&changed.join()==="7,2,1"&&a.join()==="10,2,1"&&a.map(x=>x+1).filter(x=>x>2).join()==="11,3"&&a.reduce((x,y)=>x+y,0)===13&&a.at(-1)===1&&[...a.keys()].join()==="0,1,2"&&[...a.entries()].map(x=>x.join(":")).join()==="0:10,1:2,2:1"')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var a=new Uint8Array([1,2,3,4]);a.set(a.subarray(0,3),1);a.join()==="1,1,2,3"&&(a.copyWithin(0,2),a.join()==="2,3,2,3")&&(a.fill(9,1,3),a.join()==="2,9,9,3")&&(a.reverse(),a.join()==="3,9,9,2")')!.as_bool()
}

fn test_typed_array_species_and_copying_methods_retain_intrinsic_constructors() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'class S extends Uint8Array{static get [Symbol.species](){return Float32Array}}var a=new S([1,2,3]),m=a.map(x=>x/2),c=a.toReversed(),U=Uint8Array;globalThis.Uint8Array=function(){throw 1};var good=m instanceof Float32Array&&m.join()==="0.5,1,1.5"&&c instanceof U&&c.join()==="3,2,1"&&a.toSorted() instanceof U;globalThis.Uint8Array=U;good')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var a=new Uint8Array([1]),marker={},called=0,same=false;Object.defineProperty(a,"constructor",{get(){throw marker}});try{a.map(()=>{called++;return 0})}catch(e){same=e===marker}same&&called===0&&a.toReversed()[0]===1')!.as_bool()
}

fn test_typed_array_raw_dispatch_ignores_author_visible_method_names_and_checks_brands() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var P=Object.getPrototypeOf(Uint8Array.prototype),map=P.map,old=Object.getOwnPropertyDescriptor(map,"name");Object.defineProperty(map,"name",{value:"fill",configurable:true});var a=new Uint8Array([1,2]),good=map.call(a,x=>x+1).join()==="2,3"&&a.join()==="1,2";Object.defineProperty(map,"name",old);good&&(function(){var n=0;for(var f of [()=>P.map.call({},()=>1),()=>Object.getOwnPropertyDescriptor(P,"length").get.call({}),()=>P.values.call({}),()=>P.map.call(new Proxy(a,{}),()=>1)])try{f()}catch(e){if(e instanceof TypeError)n++}return n===4})()')!.as_bool()
}

fn test_typed_array_uint8_encoding_helpers_use_real_intrinsics_and_live_storage() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var a=Uint8Array.fromHex("00ff10"),b=Uint8Array.fromBase64("AP8Q"),u=new Uint8Array(3),r=u.setFromHex("010203"),v=new Uint8Array(3),s=v.setFromBase64("AQID");a.toHex()==="00ff10"&&b.toHex()==="00ff10"&&a.toBase64()==="AP8Q"&&u.toHex()==="010203"&&r.read===6&&r.written===3&&v.toHex()==="010203"&&s.read===4&&s.written===3&&Uint8Array.fromHex.call({}, "ff") instanceof Uint8Array')!.as_bool()
}

fn test_typed_array_large_indices_are_checked_before_narrowing_and_keep_conversion_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var errors=0,b=new ArrayBuffer(8);for(var f of [()=>new Uint8Array(4294967296),()=>new Uint8Array({length:4294967296}),()=>Uint8Array.from({length:4294967296}),()=>new Uint8Array(b,4294967296),()=>new Uint8Array(b,0,4294967296)])try{f()}catch(e){if(e instanceof RangeError)errors++}errors===5')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var b=new ArrayBuffer(8),reads=0,a=false,c=false;try{new Uint8Array(b,4294967296,{valueOf(){reads++;return 0}})}catch(e){a=e instanceof RangeError}try{new Uint16Array(b,4294967297,{valueOf(){reads++;return 0}})}catch(e){c=e instanceof RangeError}a&&c&&reads===1')!.as_bool()
}

fn test_typed_array_resizable_and_detached_buffer_witnesses_stay_live() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert typed_intrinsic_eval(mut vm, 'var b=new ArrayBuffer(8,{maxByteLength:16}),a=new Uint16Array(b),fixed=new Uint16Array(b,2,2),tail=a.subarray(1);b.resize(12);var first=a.length===6&&fixed.length===2&&tail.length===5;b.resize(2);var second=a.length===1&&fixed.length===0&&fixed.byteLength===0&&fixed.byteOffset===0;b.resize(8);first&&second&&fixed.length===2&&a.length===4&&tail.length===3')!.as_bool()
	assert typed_intrinsic_eval(mut vm, 'var b=new ArrayBuffer(4),a=new Uint8Array(b),old=b.transfer(),bad=false;try{a.at(0)}catch(e){bad=e instanceof TypeError}b.detached&&a.length===0&&a.byteLength===0&&ArrayBuffer.isView(a)&&old.byteLength===4&&bad')!.as_bool()
}

fn test_typed_array_constructor_fallback_uses_new_target_realm_and_restores_caller() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	first := vm.realm()
	constructor := realm_typed_array_constructor(first, .uint8)
	foreign_context := initialize_host_defined_realm(mut vm, RealmGlobalHooks{})!
	defer { vm.pop_execution_context() }
	foreign := vm.realm()
	mut target := NativeFunction.create_constructor(mut vm, foreign, foreign.function_prototype, fn (mut vm VM) !Value { return js_undefined() }, fn (mut vm VM, new_target &Object) !&Object { return Object.create(vm.realm(), none) }, 0, PropertyName.from_str('ForeignTarget')).object
	target.define_direct_property(PropertyName.from_str('prototype'), Value.from_i32(0), attribute_writable | attribute_configurable)
	array := construct(mut vm, Value.from_object(constructor), [Value.from_i32(2)], target)!
	assert voidptr(array.prototype?) == voidptr(realm_typed_array_prototype(foreign, .uint8))
	assert voidptr(array.typed_array?.viewed_buffer.object.prototype?) == voidptr(first.array_buffer_prototype?)
	assert voidptr(vm.running_execution_context()) == voidptr(foreign_context)
}

fn test_typed_array_native_cells_backing_owner_and_iterator_survive_arena_reset() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	realm := vm.realm()
	constructor := realm_typed_array_constructor(realm, .uint8)
	mut arena := platform.new_arena('native typed-array records')
	entry := arena.enter()
	object := construct(mut vm, Value.from_object(constructor), [Value.from_i32(4)], none)!
	array := object.typed_array?
	iterator := ArrayIterator.create(realm, Value.from_object(object), .value, realm.array_iterator_prototype?)
	arena.leave(entry)
	assert !arena.contains(object) && !arena.contains(array) && !arena.contains(array.viewed_buffer)
	assert !arena.contains(array.viewed_buffer.block.owned?) && !arena.contains(iterator) && !arena.contains(iterator.object)
	arena.reset(); arena.release()
	mut actual := unsafe { &TypedArray(array) }
	typed_array_set_element(mut vm, mut actual, CanonicalIndex.create(.index, 0), Value.from_i32(7))!
	mut actual_iterator := unsafe { &ArrayIterator(iterator) }
	assert actual_iterator.next(mut vm, realm.array_prototype_record())!.value.number == 7
}

fn test_typed_array_native_loops_and_dense_own_keys_obey_instruction_limits() {
	for source in ['new Uint8Array(1000000).fill(1)', 'new Uint8Array(1000).indexOf(1)', 'Object.keys(new Uint8Array(1000))', 'Uint8Array.from({length:1000})'] {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		mut script := Script.parse(source, vm.realm(), 'typed-array-budget.js', unsafe { nil })!
		if _ := vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200}) { assert false }
		else { assert thrown_value(err).as_object().error_message()?.contains('instruction budget') }
	}
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut script := Script.parse('new Uint8Array(1000).indexOf(0)', vm.realm(), 'typed-array-budget-early-return.js', unsafe { nil })!
	assert vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 200})!.number == 0
}

fn test_cached_typed_array_constructors_views_and_callbacks_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-typed-intrinsic-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create(); create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert typed_intrinsic_eval(mut vm, 'function bytes(values){var a=Uint8Array.from(values);return a.subarray(1).map(x=>x+1).join(",")}bytes([1,2,3])==="3,4"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
