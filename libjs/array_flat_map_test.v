// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn flat_map_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'flat-map.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_flat_map_flattens_one_array_level_and_skips_source_and_result_holes() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert flat_map_eval(mut vm, 'var calls=0,out=[1,,2].flatMap(v=>{calls++;return [v,,[v+10]]});calls===2&&out.length===4&&out[0]===1&&out[1][0]===11&&out[2]===2&&out[3][0]===12')!.as_bool()
	assert flat_map_eval(mut vm, 'var object={0:42,length:1};object[Symbol.isConcatSpreadable]=true;var a=[1];a[Symbol.isConcatSpreadable]=false;var r=[0,1].flatMap(v=>v?a:object);r.length===2&&r[0]===object&&r[1]===1')!.as_bool()
}

fn test_flat_map_reads_live_inherited_indices_and_snapshots_source_length() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert flat_map_eval(mut vm, 'var source=Object.create({1:2});source[0]=1;source[2]=3;source.length=3;var receiver={},seen="";var out=Array.prototype.flatMap.call(source,function(v,i,o){if(this!==receiver||o!==source)throw 1;seen+=i;if(i===0){delete source[2];source[3]=99;source.length=4}return [v,v]},receiver);seen==="01"&&out.join(":")==="1:1:2:2"')!.as_bool()
}

fn test_flat_map_species_starts_at_zero_and_creates_data_properties_without_setters() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert flat_map_eval(mut vm, 'var n=-1,setters=0;function Result(length){n=length}Object.defineProperty(Result.prototype,"0",{set(v){setters++},configurable:true});class A extends Array{static get [Symbol.species](){return Result}}var a=new A(20,22),out=a.flatMap(v=>[v]);out instanceof Result&&n===0&&setters===0&&out[0]+out[1]===42&&!Object.hasOwn(out,"length")')!.as_bool()
	assert flat_map_eval(mut vm, 'var source=[1,2],seen="";function Result(){return source}source.constructor={};source.constructor[Symbol.species]=Result;var out=source.flatMap((v,i)=>{seen+=v;return [v,9]});out===source&&seen==="19"&&source.join(":")==="1:9:9:9"')!.as_bool()
}

fn test_flat_map_orders_receiver_length_callback_validation_and_species_access() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert flat_map_eval(mut vm, 'var log="",source={get length(){log+="length;";return 1}},caught=false;try{Array.prototype.flatMap.call(source,null)}catch(e){caught=e instanceof TypeError}caught&&log==="length;"')!.as_bool()
	assert flat_map_eval(mut vm, 'var marker={},same=false;try{[1].flatMap(()=>{throw marker})}catch(e){same=e===marker}same')!.as_bool()
}

fn test_flatten_into_array_rejects_out_of_range_target_index_before_defining_properties() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	mut target := Object.create(vm.realm(), none)
	source := ArrayObject.create_from(mut vm, vm.realm(), [Value.from_i32(42)], vm.realm().array_prototype_record())!.object
	flatten_into_array(mut vm, mut target, source, 1, 9007199254740991, 0, js_undefined(), js_undefined()) or {
		assert thrown_value(err).as_object().error_kind()? == .type_error
		assert target.own_property_keys().len == 0
		return
	}
	assert false, 'FlattenIntoArray must reject target indices above its bound'
}
