module libjs

fn evaluate_with_test(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'with-execution.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_with_executes_a_dynamic_template_and_looks_up_live_properties() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert evaluate_with_test(mut vm, r'
		var title = "outside";
		var render = Function("data", "var text = \"\"; with (data || {}) { text += title; } return text;");
		var data = {title: "first"};
		var first = render(data);
		data.title = "second";
		var second = render(data);
		data[Symbol.unscopables] = {title: true};
		first === "first" && second === "second" && render(data) === "outside" && render(null) === "outside";
	')!.as_bool()
}

fn test_with_uses_its_object_as_receiver_and_lets_closures_capture_it() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert evaluate_with_test(mut vm, r'
		var object = {x: 2, read() { return this.x; }};
		var captured, direct, boxed;
		with (object) { direct = read(); captured = function () { return x; }; x++; }
		with ("abc") { boxed = charAt(1); }
		direct === 2 && captured() === 3 && object.x === 3 && boxed === "b" && typeof x === "undefined";
	')!.as_bool()
}

fn test_with_restores_the_previous_environment_on_abrupt_exits() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert evaluate_with_test(mut vm, r'
		var x = 1, object = {x: 2}, caught, after, finallyValue, denied = false;
		try { with (object) { throw x; } } catch (error) { caught = [error, x]; }
		for (let i = 0; i < 2; i++) { with (object) { if (i === 0) continue; break; } }
		after = x;
		var inner = function (x) { try { with (object) return x; } finally { finallyValue = x; } };
		try { with (null) {} } catch (error) { denied = error instanceof TypeError; }
		caught[0] === 2 && caught[1] === 1 && after === 1 && inner(3) === 2 && finallyValue === 3 && denied;
	')!.as_bool()
	assert evaluate_with_test(mut vm, '1; with ({}) {}')!.is_undefined()
}

fn test_with_var_initializers_use_the_dynamic_scope_without_leaking_bindings() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert evaluate_with_test(mut vm, r'
		function run() {
			var object = {x: 1};
			with (object) { var x = (delete object.x, 8), fallback = 9; }
			return typeof x === "undefined" && object.x === 8 && fallback === 9;
		}
		run();
	')!.as_bool()
}

fn test_with_writes_retain_the_reference_across_side_effects() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert evaluate_with_test(mut vm, r'
		var x = 100, object = {x: 1}, add;
		with (object) { x = (delete object.x, 2); add = function () { return x += (delete object.x, 3); }; }
		var afterAdd = add();
		object.x = {valueOf() { delete object.x; return 6; }};
		var postfix;
		with (object) { postfix = x++; }
		afterAdd === 5 && postfix === 6 && object.x === 7 && x === 100;
	')!.as_bool()
}
