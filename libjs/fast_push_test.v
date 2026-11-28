module libjs

fn test_push_within_capacity_grows_and_pop_last_returns_in_reverse() {
	mut values := []int{cap: 2}
	for index in 0 .. 9 { push_within_capacity(mut values, index * 3) }
	assert values == [0, 3, 6, 9, 12, 15, 18, 21, 24]
	mut popped := []int{}
	for values.len > 0 { popped << pop_last(mut values, 'empty') }
	assert popped == [24, 21, 18, 15, 12, 9, 6, 3, 0] && values.len == 0
	mut options := []?&Object{}
	push_within_capacity(mut options, ?&Object(none))
	object := Object.create(unsafe { nil }, none)
	push_within_capacity(mut options, ?&Object(object))
	last := pop_last(mut options, 'empty') or { panic('missing object') }
	assert voidptr(last) == voidptr(object)
	assert pop_last(mut options, 'empty') == none
}

// Nested calls push and pop both context stacks and every reserved register.
fn test_direct_register_access_preserves_nested_call_state() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	depth := vm.execution_context_stack().len
	mut script := Script.parse('"use strict";function f(n){if(n==0)return this===undefined?1:0;try{return f(n-1)+1}finally{n++}}f(30)',
		vm.realm(), 'registers.js', unsafe { nil })!
	assert vm.run(mut script)!.number == 31
	assert vm.execution_context_stack().len == depth
}
