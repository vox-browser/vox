// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn to_sorted_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-to-sorted.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_to_sorted_creates_dense_sorted_array_without_mutating_sparse_source() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert to_sorted_eval(mut vm, 'var a=[3,,undefined,1,2],compared=0;var out=a.toSorted((x,y)=>{if(x===undefined||y===undefined)throw 1;compared++;return x-y});out!==a&&out.length===5&&out[0]===1&&out[1]===2&&out[2]===3&&out[3]===undefined&&out[4]===undefined&&(3 in out)&&(4 in out)&&a[0]===3&&!(1 in a)&&compared>0')!.as_bool()
	assert to_sorted_eval(mut vm, 'var a=[{key:1,id:"a"},{key:0,id:"b"},{key:1,id:"c"}];a.toSorted((x,y)=>x.key-y.key).map(x=>x.id).join("")==="bac"&&a[0].id==="a"')!.as_bool()
}

fn test_to_sorted_uses_intrinsic_array_without_observing_constructor_or_species() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert to_sorted_eval(mut vm, 'class A extends Array{static get [Symbol.species](){throw 1}}var a=new A(2,1);Object.defineProperty(a,"constructor",{get(){throw 2}});var out=a.toSorted();Object.getPrototypeOf(out)===Array.prototype&&out[0]===1&&out[1]===2')!.as_bool()
}

fn test_to_sorted_snapshots_length_reads_all_values_before_comparing_and_includes_inheritance() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert to_sorted_eval(mut vm, 'var log="",source=Object.create({1:20});Object.defineProperty(source,"length",{get(){log+="length;";return 3}});Object.defineProperty(source,"0",{get(){log+="zero;";return 22}});Object.defineProperty(source,"2",{get(){log+="two;";return 0}});var out=Array.prototype.toSorted.call(source,(a,b)=>{if(log!=="length;zero;two;")throw 1;return a-b});out.join(":")==="0:20:22"&&log==="length;zero;two;"')!.as_bool()
}

fn test_to_sorted_validates_comparator_and_array_length_before_reading_indices() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert to_sorted_eval(mut vm, 'var reads=0,source={get length(){reads++;throw 1}},caught=false;try{Array.prototype.toSorted.call(source,null)}catch(e){caught=e instanceof TypeError}caught&&reads===0')!.as_bool()
	assert to_sorted_eval(mut vm, 'var reads=0,caught=false;try{Array.prototype.toSorted.call({length:4294967296,get 0(){reads++;return 1}})}catch(e){caught=e instanceof RangeError}caught&&reads===0')!.as_bool()
	assert to_sorted_eval(mut vm, 'var marker={},source=[2,1],same=false;try{source.toSorted(()=>{throw marker})}catch(e){same=e===marker}same&&source[0]===2&&source[1]===1')!.as_bool()
}
