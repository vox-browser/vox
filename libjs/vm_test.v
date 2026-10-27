module libjs

fn test_vm_creation_preallocates_strings_symbols_and_default_hooks() {
	mut vm := VM.create()
	assert vm.empty_string().is_empty()
	assert vm.single_ascii_character_string(`a`).str() == 'a'
	assert vm.cached_strings.object_object.str() == '[object Object]'
	assert vm.well_known_symbol_iterator().descriptive_string().str() == 'Symbol(Symbol.iterator)'
	assert vm.well_known_symbol(.to_string_tag).description?.str() == 'Symbol.toStringTag'
	assert vm.error_message(.out_of_memory).str() == 'Out of memory'
	assert vm.host_get_supported_import_attributes().len == 1
	assert vm.host_promise_job_queue_is_empty()
	assert !vm.has_running_execution_context()
	assert vm.get_active_script_or_module().is_empty()
	assert agent_can_suspend(vm)
}

fn test_execution_context_stack_tracks_running_and_previous_contexts() {
	mut vm := VM.create()
	mut first := ExecutionContext.create(0, [], 0)
	mut second := ExecutionContext.create(0, [], 0)
	vm.push_execution_context(mut first)
	assert vm.has_running_execution_context()
	assert voidptr(vm.running_execution_context()) == voidptr(first)
	vm.push_execution_context(mut second)
	assert voidptr(vm.running_execution_context()) == voidptr(second)
	assert vm.execution_context_stack().len == 2
	top_to_bottom := vm.execution_contexts_top_to_bottom()
	assert top_to_bottom.len == 2
	assert voidptr(top_to_bottom[0]) == voidptr(second)
	assert voidptr(top_to_bottom[1]) == voidptr(first)
	previous := vm.previous_execution_context() or { panic('expected a previous context') }
	assert voidptr(previous) == voidptr(first)
	popped := vm.pop_execution_context()
	assert voidptr(popped) == voidptr(second)
	assert voidptr(vm.running_execution_context()) == voidptr(first)
	vm.pop_execution_context()
	assert !vm.has_running_execution_context()
	assert vm.previous_execution_context() == none
}

@[heap]
struct VmTestFunction {
	name string
mut:
	calls int
}

fn (function &VmTestFunction) name_for_call_stack() Utf16String {
	return utf16_string(function.name)
}

fn (function &VmTestFunction) realm() ?&Realm {
	return none
}

fn (mut function VmTestFunction) internal_call(mut vm VM, this_value Value, arguments []Value) !Value {
	function.calls++
	return Value.from_i32(i32(arguments.len))
}

@[heap]
struct VmTestLog {
mut:
	numbers []int
	values  []Value
}

fn vm_test_enter_global_code(mut vm VM) {
	// ScriptEvaluation installs the global environment before running code.
	global_environment := vm.realm().global_environment_record()
	mut running := vm.running_execution_context()
	running.lexical_environment = Environment(global_environment)
	running.variable_environment = Environment(global_environment)
}

fn vm_test_executable(filename string, line u32, column u32) &Executable {
	code := SourceCode.create(utf16_string(filename), Utf16String.new())
	return &Executable{
		registers_and_locals_count: 5
		source_map:                 [
			SourceMapEntry{
				bytecode_offset: 0
				source_range:    SourceCodeRange{
					code:  code
					start: Position{
						line:   line
						column: column
					}
				}
			},
		]
		bytecode_length:            8
	}
}

fn test_inline_frames_are_walked_between_base_pushes() {
	mut vm := VM.create()
	mut base := ExecutionContext.create(0, [], 0)
	vm.push_execution_context(mut base)
	mut inline_frame := ExecutionContext.create(0, [], 0)
	inline_frame.caller_frame = base
	vm.set_running_execution_context(inline_frame)
	mut nested_base := ExecutionContext.create(0, [], 0)
	vm.push_execution_context(mut nested_base)
	contexts := vm.execution_contexts_top_to_bottom()
	assert contexts.len == 3
	assert voidptr(contexts[0]) == voidptr(nested_base)
	assert voidptr(contexts[1]) == voidptr(inline_frame)
	assert voidptr(contexts[2]) == voidptr(base)
	assert voidptr(vm.previous_execution_context()?) == voidptr(inline_frame)
	matching := vm.last_execution_context_matching(fn (context &ExecutionContext) bool {
		return context.caller_frame != none
	})?
	assert voidptr(matching) == voidptr(inline_frame)
	assert vm.last_execution_context_matching(fn (context &ExecutionContext) bool {
		return false
	}) == none
	popped := vm.pop_execution_context()
	assert voidptr(popped) == voidptr(nested_base)
	assert voidptr(vm.running_execution_context()) == voidptr(inline_frame)
	assert vm.execution_contexts_top_to_bottom().len == 2
	vm.set_running_execution_context(base)
	vm.pop_execution_context()
	assert !vm.has_running_execution_context()
}

fn test_saved_execution_context_stacks_restore_running_state_and_overrides() {
	mut vm := VM.create()
	mut base := ExecutionContext.create(0, [], 0)
	vm.push_execution_context(mut base)
	override_realm := Realm.create()
	mut scope := TypeErrorRealmScope.new(mut vm, override_realm)
	vm.save_execution_context_stack()
	assert vm.saved_execution_context_stack_count() == 1
	assert !vm.has_running_execution_context()
	assert vm.execution_context_stack().len == 0
	assert vm.get_active_script_or_module().is_empty()
	mut other := ExecutionContext.create(0, [], 0)
	vm.push_execution_context(mut other)
	vm.clear_execution_context_stack()
	assert !vm.has_running_execution_context()
	roots := vm.heap_roots()
	assert roots.contains(voidptr(override_realm))
	vm.restore_execution_context_stack()
	assert vm.saved_execution_context_stack_count() == 0
	assert voidptr(vm.running_execution_context()) == voidptr(base)
	assert vm.execution_context_stack().len == 1
	scope.restore()
	scope.restore()
	assert !vm.heap_roots().contains(voidptr(override_realm))
}

fn test_type_error_realm_scope_applies_only_at_its_stack_depth() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	current := vm.realm()
	override_realm := Realm.create()
	mut scope := TypeErrorRealmScope.new(mut vm, override_realm)
	type_error :=
		thrown_value(vm.throw_error_type(.type_error, .not_an_object, 'value')).as_object()
	assert type_error.error_kind()? == .type_error
	assert type_error.error_message()? == 'value is not an object'
	assert voidptr(type_error.error_realm()?) == voidptr(override_realm)
	range_error := thrown_value(vm.throw_error(.range_error, 'out of range')).as_object()
	assert voidptr(range_error.error_realm()?) == voidptr(current)
	assert range_error.class_name == 'RangeError'
	mut nested := ExecutionContext.create(0, [], 0)
	nested.realm = current
	vm.push_execution_context(mut nested)
	nested_error :=
		thrown_value(vm.throw_error_type(.type_error, .not_an_object, 'nested')).as_object()
	assert voidptr(nested_error.error_realm()?) == voidptr(current)
	vm.pop_execution_context()
	scope.restore()
	restored :=
		thrown_value(vm.throw_error_type(.type_error, .not_an_object, 'restored')).as_object()
	assert voidptr(restored.error_realm()?) == voidptr(current)
	utf16_error :=
		thrown_value(vm.throw_error_utf16(.syntax_error, utf16_string('ünexpected'))).as_object()
	assert utf16_error.error_message()? == 'ünexpected'
	assert utf16_error.class_name == 'SyntaxError'
	assert utf16_error.is_error_object()
}

fn test_errors_capture_the_execution_context_stack_as_a_traceback() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut function := &VmTestFunction{
		name: 'outer'
	}
	mut frame := ExecutionContext.create(5, [], 0)
	frame.function = FunctionObject(function)
	frame.executable = vm_test_executable('trace.js', 3, 4)
	frame.realm = vm.realm()
	vm.push_execution_context(mut frame)
	error_object := thrown_value(vm.throw_error(.error, 'boom')).as_object()
	data := error_object.error_data?
	assert data.traceback.len == 2
	assert data.traceback[0].function_name.str() == 'outer'
	assert data.traceback[0].source_range().start.line == 3
	assert data.traceback[1].function_name.is_empty()
	assert data.stack_string(false) == '    at outer (trace.js:3:4)\n'
	trace := vm.stack_trace()
	assert trace.len == 2
	assert trace[0].source_range?.filename().str() == 'trace.js'
	assert trace[1].source_range == none
	assert vm.backtrace_lines() == ['-> outer @ trace.js:3,4', '-> ']
	mut anonymous := ExecutionContext.create(5, [], 0)
	anonymous.executable = vm_test_executable('anon.js', 9, 1)
	anonymous.realm = frame.realm
	vm.push_execution_context(mut anonymous)
	anonymous_error := thrown_value(vm.throw_error(.error, 'anonymous')).as_object()
	assert anonymous_error.error_data?.stack_string(false) == '    at anon.js:9:1\n    at outer (trace.js:3:4)\n'
	vm.pop_execution_context()
	for _ in 0 .. 5 {
		mut repeated := ExecutionContext.create(5, [], 0)
		repeated.function = FunctionObject(function)
		repeated.executable = frame.executable
		repeated.realm = frame.realm
		vm.push_execution_context(mut repeated)
	}
	compact_error := thrown_value(vm.throw_error(.error, 'deep')).as_object()
	assert compact_error.error_data?.traceback.len == 7
	assert compact_error.error_data?.stack_string(true) == '    at outer (trace.js:3:4)\n    5 more calls\n'
	assert compact_error.error_data?.stack_string(false).count('at outer') == 6
	assert vm.heap_roots().contains(voidptr(frame.executable?))
}

fn test_binding_resolution_walks_environments_and_reports_coordinates() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm_test_enter_global_code(mut vm)
	mut outer := DeclarativeEnvironment.create(vm.lexical_environment())
	mut inner := DeclarativeEnvironment.create(Environment(outer))
	x := utf16_string('x')
	y := utf16_string('y')
	outer.create_mutable_binding(mut vm, y, false)!
	outer.initialize_binding(mut vm, y, Value.from_i32(2), .normal)!
	inner.create_mutable_binding(mut vm, x, false)!
	inner.initialize_binding(mut vm, x, Value.from_i32(1), .normal)!
	mut running := vm.running_execution_context()
	running.lexical_environment = Environment(inner)
	x_reference := vm.resolve_binding(x, true, none)!
	assert x_reference.is_environment_reference()
	assert same_environment(x_reference.base_environment_record(), Environment(inner))
	assert x_reference.environment_coordinate?.hops == 0
	assert x_reference.environment_coordinate?.index == 0
	assert x_reference.get_value(mut vm)!.as_i32() == 1
	y_reference := vm.resolve_binding(y, true, none)!
	assert y_reference.environment_coordinate?.hops == 1
	assert same_environment(y_reference.base_environment_record(), Environment(outer))
	assert y_reference.get_value(mut vm)!.as_i32() == 2
	assert y_reference.is_strict()
	global_reference := vm.resolve_binding(utf16_string('undeclared'), false, none)!
	assert global_reference.is_unresolvable()
	assert global_reference.environment_coordinate == none
	explicit := vm.resolve_binding(y, false, Environment(outer))!
	assert explicit.environment_coordinate?.hops == 0
	mut global_object := vm.get_global_object()
	assert global_object.create_data_property(mut vm, PropertyName.from_str('g'), Value.from_i32(3)) or {
		panic(err)
	}
	g_reference := vm.resolve_binding(utf16_string('g'), true, none)!
	assert g_reference.is_environment_reference()
	assert g_reference.environment_coordinate == none
	assert g_reference.base_environment_record().is_global_environment()
	assert g_reference.get_value(mut vm)!.as_i32() == 3
	assert vm.get_identifier_reference(none, x, true, 0)!.is_unresolvable()
}

fn test_this_and_new_target_resolve_through_the_this_environment() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	vm_test_enter_global_code(mut vm)
	global_this := vm.resolve_this_binding()!
	assert voidptr(global_this.as_object()) == voidptr(vm.global_object())
	mut function_environment := FunctionEnvironment.create(vm.lexical_environment())
	target := Object.create(vm.realm(), none)
	function_environment.set_new_target(Value.from_object(target))
	mut block := DeclarativeEnvironment.create(Environment(function_environment))
	mut running := vm.running_execution_context()
	running.lexical_environment = Environment(block)
	assert voidptr(vm.get_new_target().as_object()) == voidptr(target)
	vm.resolve_this_binding() or {
		assert thrown_value(err).as_object().error_kind()? == .reference_error
	}
	function_environment.bind_this_value(mut vm, Value.from_i32(8))!
	assert vm.resolve_this_binding()!.as_i32() == 8
	function_environment.set_this_binding_status(.lexical)
	assert voidptr(vm.resolve_this_binding()!.as_object()) == voidptr(vm.global_object())
	assert vm.variable_environment()?.is_global_environment()
	assert vm.current_realm() != none
	assert vm.active_function_object() == none
	assert vm.argument_count() == 0
	assert vm.argument(3).is_undefined()
}

fn test_registers_return_values_and_exception_handling() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	handler_executable := &Executable{
		registers_and_locals_count: 5
		exception_handlers:         [
			ExceptionHandlers{
				start_offset:      0
				end_offset:        10
				handler_offset:    40
				catches_exception: true
			},
		]
		bytecode_length:            50
	}
	mut frame := ExecutionContext.create(5, [], 0)
	frame.executable = handler_executable
	vm.push_execution_context(mut frame)
	vm.set_accumulator(Value.from_i32(1))
	assert vm.accumulator().as_i32() == 1
	vm.do_return(js_special_empty_value())
	assert vm.reg(register_return_value).is_undefined()
	assert vm.reg(register_exception).is_special_empty_value()
	exception := Value.from_i32(99)
	assert vm.handle_exception(5, exception) == .continue_in_this_executable
	assert frame.program_counter == 40
	assert vm.reg(register_exception).as_i32() == 99
	assert vm.handle_exception(45, Value.from_i32(7)) == .exit_from_executable
	assert vm.reg(register_exception).as_i32() == 7
	assert voidptr(vm.current_executable()) == voidptr(handler_executable)

	mut stack := vm.interpreter_stack()
	mut callee := stack.allocate(5, [], 0) or { panic('callee frame') }
	callee.executable = &Executable{
		registers_and_locals_count: 5
		bytecode_length:            8
	}
	callee.caller_frame = frame
	callee.caller_return_pc = 8
	vm.set_running_execution_context(callee)
	assert vm.interpreter_stack().depth() == 1
	assert vm.handle_exception(3, Value.from_i32(5)) == .continue_in_this_executable
	assert voidptr(vm.running_execution_context()) == voidptr(frame)
	assert frame.program_counter == 40
	assert vm.reg(register_exception).as_i32() == 5
	assert vm.interpreter_stack().depth() == 0
	mut second_callee := stack.allocate(5, [], 0) or { panic('second callee frame') }
	second_callee.caller_frame = frame
	vm.set_running_execution_context(second_callee)
	vm.unwind_inline_frame_for_exception()
	assert voidptr(vm.running_execution_context()) == voidptr(frame)
	assert vm.interpreter_stack().depth() == 0
	assert vm.execution_generation() == 0
	vm.finish_execution_generation()
	assert vm.execution_generation() == 1
}

fn test_native_function_table_deduplicates_registrations() {
	mut vm := VM.create()
	first := fn (mut vm VM) !Value {
		return Value.from_i32(1)
	}
	second := fn (mut vm VM) !Value {
		return Value.from_i32(2)
	}
	first_index := vm.register_native_function(first, .raw_native_function)
	second_index := vm.register_native_function(second, .raw_native_function)
	assert first_index == 0
	assert second_index == 1
	assert vm.register_native_function(first, .raw_native_function) == first_index
	assert vm.native_function_count() == 2
	registered := vm.native_function(second_index, .raw_native_function)
	assert registered(mut vm)!.as_i32() == 2
}

fn test_promise_jobs_run_in_order_and_finalization_cleanup_requeues_failures() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut log := &VmTestLog{}
	for index in 1 .. 4 {
		vm.host_enqueue_promise_job(fn [mut log, index] () !Value {
			log.numbers << index
			if index == 2 {
				return error('ignored')
			}
			return js_undefined()
		}, none)
	}
	assert !vm.host_promise_job_queue_is_empty()
	assert vm.promise_job_count() == 3
	vm.run_queued_promise_jobs()
	assert log.numbers == [1, 2, 3]
	assert vm.host_promise_job_queue_is_empty()

	mut registry := &VmTestRegistry{
		fail_first: true
		empty:      true
	}
	vm.host_enqueue_finalization_registry_cleanup_job(mut registry)
	assert vm.finalization_registry_cleanup_job_count() == 1
	vm.run_queued_finalization_registry_cleanup_jobs()
	assert registry.attempts == 2
	assert vm.finalization_registry_cleanup_job_count() == 0
	mut dropped := &VmTestRegistry{
		fail_first: true
		empty:      false
	}
	vm.enqueue_finalization_registry_cleanup_job(mut dropped)
	vm.run_queued_finalization_registry_cleanup_jobs()
	assert dropped.attempts == 1
	assert vm.heap_roots().contains(finalization_registry_identity(registry)) == false
}

@[heap]
struct VmTestRegistry {
	fail_first bool
	empty      bool
mut:
	attempts int
}

fn (registry &VmTestRegistry) has_empty_cells() bool {
	return registry.empty
}

fn (mut registry VmTestRegistry) cleanup(mut vm VM) ! {
	registry.attempts++
	if registry.fail_first && registry.attempts == 1 {
		return vm.throw_error(.type_error, 'cleanup failed')
	}
}

fn test_promise_rejection_tracking_reaches_host_callbacks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut log := &VmTestLog{}
	vm.on_promise_unhandled_rejection = fn [mut log] (mut promise Promise) {
		log.values << promise.result
	}
	mut promise := Promise.create(vm.realm())
	promise.reject(mut vm, Value.from_i32(4))
	assert promise.state == .rejected
	assert promise.is_settled()
	assert log.values.len == 1
	assert log.values[0].as_i32() == 4
	mut handled := Promise.create(vm.realm())
	handled.set_is_handled()
	handled.reject(mut vm, Value.from_i32(5))
	assert log.values.len == 1
	vm.on_promise_rejection_handled = fn [mut log] (mut promise Promise) {
		log.numbers << 1
	}
	vm.host_promise_rejection_tracker(mut promise, RejectionOperation.handle)
	assert log.numbers.len == 1
	mut fulfilled := Promise.create(vm.realm())
	fulfilled.fulfill(Value.from_bool(true))
	assert fulfilled.state == .fulfilled
	assert fulfilled.result.as_bool()
	mut callback := &VmTestFunction{
		name: 'job'
	}
	mut job_callback := vm.host_make_job_callback(FunctionObject(callback))
	result := vm.host_call_job_callback(mut job_callback, js_undefined(), [
		Value.from_i32(1),
		Value.from_i32(2),
	])!
	assert result.as_i32() == 2
	assert callback.calls == 1
	capability := PromiseCapability.create(fulfilled, FunctionObject(callback), none)
	assert capability.resolve != none
	assert capability.reject == none
}

fn test_module_execution_counters_and_default_host_hooks() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert !vm.is_executing_module()
	vm.enter_module_execution()
	vm.enter_module_execution()
	assert vm.is_executing_module()
	vm.leave_module_execution()
	assert vm.is_executing_module()
	vm.leave_module_execution()
	assert !vm.is_executing_module()
	assert vm.increment_module_async_evaluation_count() == 0
	assert vm.increment_module_async_evaluation_count() == 1
	assert !vm.dynamic_imports_allowed()
	vm.set_dynamic_imports_allowed(true)
	assert vm.dynamic_imports_allowed()
	realm := vm.realm()
	global := vm.global_object()
	assert vm.host_get_code_for_eval(global) == none
	vm.host_ensure_can_compile_strings(realm, []Utf16String{}, Utf16String.new(),
		Utf16String.new(), CompilationType.function, []Value{}, js_undefined())!
	mut object := Object.create(realm, none)
	vm.host_ensure_can_add_private_element(mut object)!
	mut buffer := &VmTestArrayBuffer{
		capacity: 16
	}
	assert vm.host_resize_array_buffer(mut buffer, 8)! == .handled
	assert buffer.byte_length == 8
	vm.host_resize_array_buffer(mut buffer, 32) or {
		assert thrown_value(err).as_object().error_message()? == 'Not enough memory to allocate 32 bytes'
	}
	assert vm.host_grow_shared_array_buffer(mut buffer, 8)! == .unhandled
	nanoseconds := vm.host_system_utc_epoch_nanoseconds(global)
	assert nanoseconds.str().len > 18
	vm.host_unrecognized_date_string(utf16_string('not a date'))
	assert vm.host_get_supported_import_attributes()[0].str() == 'type'
	assert !vm.debugging_enabled()
	vm.enable_debugging()
	assert vm.debugging_enabled()
	assert vm.debugger()? != unsafe { nil }
	vm.disable_debugging()
	assert !vm.debugging_enabled()
	mut agent := &VmTestAgent{
		blocking: false
	}
	vm.set_agent(Agent(agent))
	assert !agent_can_suspend(vm)
	mut installed_agent := vm.agent()?
	installed_agent.spin_event_loop_until(fn () bool {
		return true
	})
	assert agent.spins == 1
}

@[heap]
struct VmTestArrayBuffer {
	capacity uint
mut:
	byte_length uint
}

fn (mut buffer VmTestArrayBuffer) try_resize(new_byte_length uint, zero_fill_new_bytes bool) bool {
	if new_byte_length > buffer.capacity {
		return false
	}
	buffer.byte_length = new_byte_length
	return true
}

@[heap]
struct VmTestAgent {
	blocking bool
mut:
	spins int
}

fn (agent &VmTestAgent) can_block() bool {
	return agent.blocking
}

fn (mut agent VmTestAgent) spin_event_loop_until(goal_condition fn () bool) {
	agent.spins++
	for !goal_condition() {}
}
