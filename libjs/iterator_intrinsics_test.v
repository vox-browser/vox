// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn iterator_intrinsics_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'iterator-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_iterator_intrinsic_graph_aliases_metadata_and_result_prototypes() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert iterator_intrinsics_eval(mut vm, 'var iterator=[1][Symbol.iterator]();var result=iterator.next();Array.prototype.values===Array.prototype[Symbol.iterator]&&Array.prototype.values.name==="values"&&Array.prototype.values.length===0&&iterator[Symbol.iterator]()===iterator&&Object.getPrototypeOf(result)===Object.prototype&&result.value===1&&result.done===false&&iterator.next().done&&Object.prototype.toString.call(iterator)==="[object Array Iterator]"')!.as_bool()
	assert iterator_intrinsics_eval(mut vm, 'var arrayParent=Object.getPrototypeOf([][Symbol.iterator]());var stringParent=Object.getPrototypeOf(""[Symbol.iterator]());Object.getPrototypeOf(arrayParent)===Object.getPrototypeOf(stringParent)&&Object.getPrototypeOf(Object.getPrototypeOf(arrayParent))===Object.prototype&&Object.getOwnPropertyDescriptor(Array.prototype,Symbol.iterator).enumerable===false')!.as_bool()
}

fn test_array_iterators_retain_live_length_holes_pairs_and_terminal_state() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert iterator_intrinsics_eval(mut vm, 'var array=[10,,30];var values=array.values();var first=values.next().value;array.push(40);first===10&&values.next().value===undefined&&values.next().value===30&&values.next().value===40&&values.next().done&&(array.push(50),values.next().done)')!.as_bool()
	assert iterator_intrinsics_eval(mut vm, 'var keys=[10,20].keys();var entries=[30].entries();var entry=entries.next().value;keys.next().value===0&&keys.next().value===1&&keys.next().done&&entry[0]===0&&entry[1]===30&&Object.getPrototypeOf(entry)===Array.prototype')!.as_bool()
	assert iterator_intrinsics_eval(mut vm, 'var reads=0;var object={0:42};Object.defineProperty(object,"length",{get:function(){reads++;return 1}});var borrowed=Array.prototype.values.call(object);reads===0&&borrowed.next().value===42&&reads===1&&borrowed.next().done&&reads===2')!.as_bool()
}

fn test_string_iterators_preserve_code_points_lone_surrogates_and_brand_errors() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert iterator_intrinsics_eval(mut vm, 'var iterator="A😀\\ud800"[Symbol.iterator]();iterator.next().value==="A"&&iterator.next().value==="😀"&&iterator.next().value==="\\ud800"&&iterator.next().done&&iterator.next().done&&Object.prototype.toString.call(iterator)==="[object String Iterator]"')!.as_bool()
	assert iterator_intrinsics_eval(mut vm, 'var next=Object.getPrototypeOf(""[Symbol.iterator]()).next;var caught=0;try{next.call({})}catch(e){if(e instanceof TypeError)caught++};try{String.prototype[Symbol.iterator].call(null)}catch(e){if(e instanceof TypeError)caught++};caught')!.number == 2
}

fn test_sync_iterator_value_lookup_and_call_keep_the_original_primitive_receiver() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut record := get_iterator_sync_value(mut vm, Value.from_string(vm.create_string_from_str('ab')))!
	assert iterator_step_value(mut vm, mut record)!.value.as_string().str() == 'a'
	assert iterator_step_value(mut vm, mut record)!.value.as_string().str() == 'b'
	assert iterator_step_value(mut vm, mut record)!.done
	iterator_intrinsics_eval(mut vm, 'var readThis,callThis;Object.defineProperty(String.prototype,Symbol.iterator,{configurable:true,get:function(){"use strict";readThis=this;return function(){"use strict";callThis=this;return {next:function(){return {done:true}}}}}})')!
	mut observed := get_iterator_sync_value(mut vm, Value.from_string(vm.create_string_from_str('primitive')))!
	assert iterator_step_value(mut vm, mut observed)!.done
	assert iterator_intrinsics_eval(mut vm, 'readThis==="primitive"&&callThis==="primitive"')!.as_bool()
}
