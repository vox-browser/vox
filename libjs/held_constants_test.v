module libjs

// A pooled frame keeps the constants of the body it last ran; registers and
// arguments are cleared. The same constants are then neither cleared nor
// copied again, and other constants (or replaced storage) are copied in.
fn test_pooled_frames_hold_constants_and_clear_everything_else() {
	mut stack := InterpreterStack.new()
	first := [Value.from_i32(7), Value.from_i32(8)]
	mut frame := stack.allocate_reusable(3, first, 1) or { panic('frame') }
	frame.values[2] = Value.from_i32(99)
	frame.values[5] = Value.from_i32(42)
	stack.deallocate(0)
	assert stack.recycled.len == 1
	pooled := stack.recycled[0]
	assert pooled.values[3].number == 7 && pooled.values[4].number == 8
	assert pooled.values[2].is_undefined() && pooled.values[5].is_undefined()
	again := stack.allocate_reusable(3, first, 1) or { panic('again') }
	assert voidptr(again) == voidptr(frame)
	assert again.values[3].number == 7 && again.values[4].number == 8
	assert again.values[0].is_special_empty_value()
	stack.deallocate(0)
	other := [Value.from_i32(1), Value.from_i32(2)]
	third := stack.allocate_reusable(3, other, 1) or { panic('third') }
	assert voidptr(third) == voidptr(frame)
	assert third.values[3].number == 1 && third.values[4].number == 2
	stack.deallocate(0)
	// Different storage under the same frame no longer holds them.
	mut reused := stack.allocate_reusable(3, other, 1) or { panic('reused') }
	reused.values = reused.values.clone()
	stack.deallocate(0)
	if stack.recycled.len == 1 {
		assert stack.recycled[0].values[3].is_undefined()
	}
}

fn held_constants_eval(source string) !string {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'held-constants.js', unsafe { nil })!
	value := vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 300000 })!
	return value.as_string().str()
}

// Bodies with equal frame shapes alternate through the pool with their own
// constants.
fn test_alternating_bodies_keep_their_constants() {
	source := 'function a(x){return "a"+x+"!"}function b(x){return "b"+x+"?"}' +
		'var r=[];for(var i=0;i<4;i++){r.push(a(i));r.push(b(i))}r.join()'
	assert held_constants_eval(source)! == 'a0!,b0?,a1!,b1?,a2!,b2?,a3!,b3?'
}

// A frame reused by a body with other constants, a different layout or no
// constants shows none of the previous body's constants.
fn test_reused_frames_drop_another_bodys_constants() {
	mut stack := InterpreterStack.new()
	frame := voidptr(stack.allocate_reusable(6, [Value.from_i32(1)], 3) or { panic('wide') })
	stack.deallocate(0)
	short := stack.allocate_reusable(5, [Value.from_i32(2)], 2) or { panic('short') }
	assert voidptr(short) == frame && short.values[5].number == 2 && short.argument(0).is_undefined()
	stack.deallocate(0)
	bare := stack.allocate_reusable(6, [], 3) or { panic('bare') }
	assert voidptr(bare) == frame
	for index in int(reserved_register_count) .. bare.values.len { assert bare.values[index].is_undefined(), '${index}' }
	stack.deallocate(0)
}
