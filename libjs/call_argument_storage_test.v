module libjs

fn test_borrowed_arguments_preserve_nested_calls_closures_and_arguments_objects() {
	for enabled in [false, true] {
		set_borrowed_call_arguments_for_testing(enabled)
		defer { set_borrowed_call_arguments_for_testing(true) }
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut script := Script.parse('function keep(x){return arguments} function f(x){return x+1} function g(a,b){return a*10+b} var saved=keep(42);g(f(2),f(3))+saved[0]', vm.realm(), 'borrow.js', unsafe { nil })!
		diagnose_borrowed_call_arguments_for_testing(true)
		assert vm.run(mut script)!.number == 76
		count := diagnose_borrowed_call_arguments_for_testing(false)
		assert (count > 0) == enabled
		mut again := Script.parse('f(100);saved[0]', vm.realm(), 'again.js', unsafe { nil })!
		assert vm.run(mut again)!.number == 42
	}
}

fn test_borrowed_arguments_large_calls_construction_and_exceptions() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse('function big(a,b,c,d,e,f,g,h,i){return i}function C(x){this.x=x}function fail(x){throw x}var n=0;try{fail(17)}catch(e){n=e}big(1,2,3,4,5,6,7,8,9)+(new C(16)).x+n', vm.realm(), 'fallback.js', unsafe { nil })!
	assert vm.run(mut script)!.number == 42
}

@[heap]
struct ArgumentSliceKeeper {
mut:
	retained []Value
}
fn (keeper &ArgumentSliceKeeper) name_for_call_stack() Utf16String { return utf16_string('keeper') }
fn (keeper &ArgumentSliceKeeper) realm() ?&Realm { return none }
fn (mut keeper ArgumentSliceKeeper) internal_call(mut vm VM, receiver Value, arguments []Value) !Value {
	keeper.retained = arguments
	return js_undefined()
}

fn test_custom_callables_keep_owning_slices_and_native_views_keep_frames() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut keeper := &ArgumentSliceKeeper{}
	mut object := Object.create(vm.realm(), vm.realm().function_prototype)
	object.callable = FunctionObject(keeper)
	mut views := &BorrowArgumentViews{}
	native := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut views] (mut vm VM) !Value {
		views.views << vm.running_execution_context().arguments()
		return vm.argument(0)
	}, 1, PropertyName.from_str('capture'), none)
	mut global := vm.get_global_object()
	global.define_direct_property(PropertyName.from_str('keeper'), Value.from_object(object), 7)
	global.define_direct_property(PropertyName.from_str('capture'), Value.from_object(native.object), 7)
	mut script := Script.parse('keeper(42);capture(17);capture(99);function f(a){return a}f(100)', vm.realm(), 'retained.js', unsafe { nil })!
	vm.run(mut script)!
	assert keeper.retained.len == 1 && keeper.retained[0].number == 42
	assert views.views.len == 2 && views.views[0][0].number == 17 && views.views[1][0].number == 99
}

@[heap]
struct BorrowArgumentViews {
mut:
	views [][]Value
}

fn test_borrowed_argument_view_uses_callers_storage_without_a_copy() {
	mut storage := [8]Value{}
	storage[0] = Value.from_i32(42)
	view := unsafe { borrow_argument_values(&storage[0], 1) }
	assert view.len == 1 && view.cap == 1
	assert view.data == unsafe { voidptr(&storage[0]) }
	storage[0] = Value.from_i32(99)
	assert view[0].number == 99
}
