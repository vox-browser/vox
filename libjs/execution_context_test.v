module libjs

fn test_execution_contexts_lay_out_registers_locals_constants_and_arguments() {
	constants := [Value.from_i32(7), Value.from_bool(true)]
	mut context := ExecutionContext.create(6, constants, 2)
	assert context.registers_and_constants_and_locals_and_arguments_count() == 10
	for index in 0 .. int(reserved_register_count) {
		assert context.values[index].is_special_empty_value()
	}
	assert context.values[5].is_undefined()
	assert context.values[6].as_i32() == 7
	assert context.values[7].as_bool()
	assert context.argument(0).is_undefined()
	assert context.argument(2).is_undefined()
	context.set_argument(1, Value.from_i32(3))
	assert context.argument(1).as_i32() == 3
	assert context.arguments().len == 2
	assert context.yield_continuation == no_yield_continuation
	assert context.caller_frame == none
	assert context.values.cap == 16
	mut executable := &Executable{
		registers_and_locals_count: 6
		local_variable_names:       [utf16_string('a')]
		local_index_base:           5
	}
	context.executable = executable
	context.values[5] = Value.from_i32(11)
	locals := context.local_variables()
	assert locals.len == 1
	assert locals[0].as_i32() == 11
	context.frame_initialized = true
	context.program_counter = 4
	duplicate := context.copy()
	assert duplicate.values.len == context.values.len
	assert duplicate.values[5].as_i32() == 11
	assert duplicate.argument(1).as_i32() == 3
	assert duplicate.program_counter == 4
	assert voidptr(duplicate.executable?) == voidptr(executable)
	context.frame_initialized = false
	partial := context.copy()
	assert partial.values[5].is_undefined()
	assert partial.argument(1).as_i32() == 3
}

fn test_execution_context_roots_depend_on_frame_initialization() {
	mut vm := VM.create()
	realm := Realm.create()
	object := Object.create(realm, none)
	mut context := ExecutionContext.create(6, [], 1)
	context.realm = realm
	context.values[5] = Value.from_object(object)
	argument := Object.create(realm, none)
	context.set_argument(0, Value.from_object(argument))
	this_object := Object.create(realm, none)
	context.this_value = Value.from_object(this_object)
	mut environment := DeclarativeEnvironment.create(none)
	context.lexical_environment = Environment(environment)
	mut before_enter := HeapRoots{}
	context.visit_roots(mut before_enter)
	assert before_enter.contains(voidptr(realm))
	assert before_enter.contains(voidptr(argument))
	assert before_enter.contains(voidptr(this_object))
	assert before_enter.contains(voidptr(environment))
	assert !before_enter.contains(voidptr(object))
	context.frame_initialized = true
	mut after_enter := HeapRoots{}
	context.visit_roots(mut after_enter)
	assert after_enter.contains(voidptr(object))
	assert vm.heap_roots().cells.len > 0
}

fn test_executables_look_up_exception_handlers_and_source_ranges() {
	code := SourceCode.create(utf16_string('test.js'), utf16_string('a;\nb;\nc;'))
	executable := &Executable{
		identifier_table:   [utf16_string('id')]
		exception_handlers: [
			ExceptionHandlers{
				start_offset:      0
				end_offset:        10
				handler_offset:    50
				catches_exception: true
			},
			ExceptionHandlers{
				start_offset:   10
				end_offset:     20
				handler_offset: 60
			},
		]
		source_map:         [
			SourceMapEntry{
				bytecode_offset: 0
				source_range:    SourceCodeRange{
					code:  code
					start: Position{
						line:   1
						column: 1
					}
				}
			},
			SourceMapEntry{
				bytecode_offset: 8
				source_range:    SourceCodeRange{
					code:  code
					start: Position{
						line:   3
						column: 2
					}
				}
			},
		]
		bytecode_length:    16
	}
	assert executable.get_identifier(0).str() == 'id'
	assert executable.exception_handlers_for_offset(5)?.handler_offset == 50
	assert executable.exception_handlers_for_offset(5)?.catches_exception
	assert executable.exception_handlers_for_offset(10)?.handler_offset == 60
	assert executable.exception_handlers_for_offset(19)?.handler_offset == 60
	assert executable.exception_handlers_for_offset(20) == none
	assert executable.source_range_at(7)?.start.line == 1
	assert executable.source_range_at(8)?.start.line == 3
	assert executable.source_range_at(15)?.start.column == 2
	assert executable.source_range_at(16) == none
	assert executable.get_source_range(100).filename().is_empty()
	assert executable.get_source_range(9).filename().str() == 'test.js'
	empty := &Executable{
		bytecode_length: 4
	}
	assert empty.source_range_at(1) == none
	assert empty.exception_handlers_for_offset(1) == none
}

fn test_interpreter_stack_allocates_frames_until_its_budget_is_exhausted() {
	mut stack := InterpreterStack.new()
	assert stack.top() == 0
	assert stack.size_remaining() == interpreter_stack_size
	first := stack.allocate(5, [], 0) or { panic('first frame') }
	assert first.frame_id == 1
	assert first.stack_offset == 0
	assert first.stack_allocated
	mark := stack.top()
	assert mark > 0
	second := stack.allocate(8, [Value.from_i32(1)], 3) or { panic('second frame') }
	assert second.frame_id == 2
	assert second.stack_offset == mark
	assert second.values.len == 12
	assert stack.depth() == 2
	assert stack.allocate(1 << 20, [], 0) == none
	assert stack.depth() == 2
	stack.deallocate_context(second)
	assert stack.depth() == 1
	assert stack.top() == mark
	assert !second.stack_allocated
	third := stack.allocate(1, [], 1) or { panic('third frame') }
	assert third.frame_id == 3
	stack.deallocate(0)
	assert stack.depth() == 0
	assert stack.top() == 0
	assert !stack.is_exhausted()
}

@[noinline]
fn consume_stack_and_measure(info StackInfo, depth int) uint {
	buffer := [128]u64{}
	if depth == 0 {
		return info.size_free() + uint(buffer[0])
	}
	return consume_stack_and_measure(info, depth - 1) + uint(buffer[depth % 128])
}

fn test_stack_info_reports_shrinking_free_space_during_recursion() {
	info := StackInfo.new()
	assert info.size > 0
	assert info.top == info.base + info.size
	free_here := info.size_free()
	assert free_here > 0
	assert free_here < info.size
	deeper := consume_stack_and_measure(info, 50)
	assert deeper < free_here
	mut vm := VM.create()
	assert !vm.did_reach_stack_space_limit()
	assert vm.stack_info().size == info.size
}
