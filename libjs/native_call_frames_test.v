module libjs

@[heap]
struct NativeFramesCapture {
mut:
	frames []&ExecutionContext
}

fn native_frames_eval(mut vm VM, source string) !string {
	mut script := Script.parse(source, vm.realm(), 'native-frames.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 50000000 })!
	assert value.is_string(), source
	return value.as_string().str()
}

const native_frames_sources = [
	// Repeated calls at one depth, more and fewer arguments than the initial capacity.
	'var s=0;for(var i=0;i<50;i++)s+=Math.max(i,3)+"abc".charCodeAt(i%3);[s,Math.max(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20),Math.max(),Math.min(4),String.fromCharCode(72,105,33,72,105,33,72,105,33,72,105,33)].join()',
	// Nested natives: callbacks call natives at deeper native depths.
	'[1,2,3].map(function(x){return [4,5].map(function(y){return Math.max(x,y)+[x].concat([y]).length}).join("/")}).join()',
	// Exceptions thrown through native frames, then further native calls.
	'var r=[];for(var i=0;i<3;i++){try{[1].forEach(function(){JSON.parse("{")})}catch(e){r.push(e.name)}r.push(Math.abs(-i))}r.join()',
	// Native recursion until the stack overflows, then recovery.
	'var depth=0;function f(){depth++;return [0].map(f)}var name;try{f()}catch(e){name=e.name}[name,depth>10,Math.max(1,2),[1,2].map(Math.abs).join("")].join()',
	// Arguments of an outer native stay intact across nested native calls.
	'var seen=[];[7,8].forEach(function(v,i,a){seen.push(Math.max(v,0));[1,2,3,4,5,6,7,8,9,10].forEach(function(){});seen.push(v,i,a.length)});seen.join()',
]

// Each native nesting depth reuses one argument-only frame; results are the
// same with the general pool.
fn test_native_frames_match_pooled_frames_and_restore_depth() {
	defer { set_native_frame_slots_for_testing(true) }
	mut results := [][]string{}
	for enabled in [false, true] {
		set_native_frame_slots_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		native_frame_slot_reuses_for_testing()
		mut outputs := []string{}
		for source in native_frames_sources {
			outputs << native_frames_eval(mut vm, source)!
			stack := vm.interpreter_stack()
			assert stack.native_frame_depth == 0, source
			assert stack.top() == 0 && stack.depth() == 0, source
		}
		reuses := native_frame_slot_reuses_for_testing()
		if enabled {
			assert reuses > 100
		} else {
			assert reuses == 0 && vm.interpreter_stack().native_frames.len == 0
		}
		results << outputs
	}
	assert results[0] == results[1]
	assert results[1][0] == '6130,20,-Infinity,4,Hi!Hi!Hi!Hi!'
	assert results[1][1] == '6/7,6/7,6/7'
	assert results[1][2] == 'SyntaxError,0,SyntaxError,1,SyntaxError,2'
	assert results[1][3].ends_with(',true,2,12')
	assert results[1][4] == '7,7,0,2,8,8,1,2'
}

// A frame something retains is abandoned to its holder; the next call at the
// same depth gets a new frame, and the retained one keeps its arguments.
fn test_native_frames_abandon_exposed_records() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut capture := &NativeFramesCapture{}
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut capture] (mut vm VM) !Value {
		if vm.argument(1).is_undefined() {
			capture.frames << vm.running_execution_context()
		}
		return vm.argument(0)
	}, 1, PropertyName.from_str('capture'), none)
	callee := Value.from_object(function.object)
	assert call(mut vm, callee, js_undefined(), [Value.from_i32(42)])!.number == 42
	assert call(mut vm, callee, js_undefined(), [Value.from_i32(7), Value.from_i32(1)])!.number == 7
	assert call(mut vm, callee, js_undefined(), [Value.from_i32(8), Value.from_i32(1)])!.number == 8
	assert call(mut vm, callee, js_undefined(), [Value.from_i32(99)])!.number == 99
	assert call(mut vm, callee, js_undefined(), [Value.from_i32(5), Value.from_i32(1)])!.number == 5
	assert capture.frames.len == 2 && voidptr(capture.frames[0]) != voidptr(capture.frames[1])
	assert capture.frames[0].argument(0).number == 42 && capture.frames[1].argument(0).number == 99
	assert !capture.frames[0].stack_allocated && !capture.frames[1].stack_allocated
	stack := vm.interpreter_stack()
	assert stack.native_frame_depth == 0 && stack.top() == 0
	// Unexposed calls share the depth's record; after the second capture the
	// last call got a fresh one, cleared on return.
	reused := stack.native_frames[0]
	assert voidptr(reused) != voidptr(capture.frames[1])
	assert reused.values.len == 0 && reused.argument_count == 0
	assert reused.values.cap >= native_frame_minimum_capacity
	unsafe { assert (&Value(reused.values.data))[0].is_undefined() && (&Value(reused.values.data))[1].is_undefined() }
	assert reused.this_value == none
	assert reused.function == none
	assert reused.realm == none && reused.lexical_environment == none
}
