module webassembly

import libjs

fn source_unwind_tags(mut store BinaryMachineStore) (u64, u64) {
	canonical := canonicalize_binary_type(BinaryDefinedType{ kind: .function_, rec_group: BinaryRecGroupSpan{ count: 1 } }, BinaryTypeContext{})
	first := store.allocate_tag(BinaryMachineFunctionType{}, canonical, 0) or { panic('actual tag allocation') }
	second := store.allocate_tag(BinaryMachineFunctionType{}, canonical, 0) or { panic('actual tag allocation') }
	return first, second
}

fn test_source_throw_unwind_preserves_tag_mapping_catch_order_parameter_bits_and_branch_arity() {
	for tagged in [true, false] {
		for capture in [false, true] {
			stack_info := libjs.StackInfo.new()
			mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
			mut store := BinaryMachineStore.create()
			first, second := source_unwind_tags(mut store)
			fields := [BinaryMachineValue.from_i64(-17),
				BinaryMachineValue.from_reference(BinaryExternReference{ address: 29 }),
				BinaryMachineValue{ low: 0x7ff8000000001234 }]
			store.allocate_exception(first, [])?
			exception := store.allocate_exception(second, fields)?
			owner := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{
				tags: [
					second,
					first,
				]
			})
			mut configuration := BinaryMachineConfiguration.create(mut store)
			defer { configuration.destroy() }
			configuration.value_stack_.append(BinaryMachineValue.from_i32(303))
			arity := uint(if tagged { fields.len } else { 0 }) + uint(if capture { 1 } else { 0 })
			expression := &BinaryExpression{
				instructions: [
					BinaryInstruction{ opcode: binary_op_nop },
					BinaryInstruction{ opcode: binary_op_synthetic_end_expression },
				]
			}
			mut locals := BinaryMachineArguments{}
			configuration.set_frame(.no, owner, mut locals, expression, arity)
			configuration.value_stack_.append(BinaryMachineValue.from_i32(17))
			configuration.value_stack_.append(BinaryMachineValue.from_i32(29))
			configuration.label_stack_ << BinaryMachineLabel.create(0, 91, 2, unsafe { nil })
			mut catches := [BinaryCatch{ tag_index: u32(1), label_index: 0 }]
			if tagged {
				catches << BinaryCatch{ tag_index: u32(0), label_index: 1, capture_reference: capture }
			} else {
				catches << BinaryCatch{ label_index: 1, capture_reference: capture }
			}
			catches << BinaryCatch{ label_index: 0 }
			instruction := &BinaryInstruction{ opcode: binary_op_try_table, arguments: BinaryTryTableArguments{ catches: catches } }
			configuration.label_stack_ << BinaryMachineLabel.create(0, 92, 3, instruction)
			configuration.label_stack_ << BinaryMachineLabel.create(0, 93, 3, unsafe { nil })
			configuration.value_stack_.append(BinaryMachineValue.from_i32(777))
			configuration.ip_ = 73
			interpreter.set_trap_message('Earlier trap')
			assert interpreter.unwind_to_throw_handler(mut configuration, exception)? == 1
			assert configuration.label_stack_.len == 1
			assert configuration.value_stack_.size() == 1 + arity
			assert unsafe { configuration.value_stack_.data()[0].to_i32() } == 303
			if tagged {
				for i, field in fields {
					assert unsafe { configuration.value_stack_.data()[i + 1] } == field
				}
			}
			if capture {
				ref := configuration.value_stack_.last().to_reference()
				assert ref is BinaryExceptionReference
				if ref is BinaryExceptionReference {
					assert ref.address == exception
				}
			}
			assert store.get_exception(exception)?.params() == fields
			assert configuration.frame_stack_.len == 1 && configuration.ip_ == 73
			assert interpreter.trap().format() == 'Earlier trap'
		}
	}
}

fn test_source_throw_search_selects_innermost_matching_try_table_before_outer_handler() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	first, second := source_unwind_tags(mut store)
	store.allocate_exception(first, [])?
	exception := store.allocate_exception(second, [BinaryMachineValue.from_i32(41)])?
	owner := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{ tags: [
		second,
		first,
	] })
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
	mut locals := BinaryMachineArguments{}
	configuration.set_frame(.no, owner, mut locals, expression, 1)
	outer := &BinaryInstruction{ opcode: binary_op_try_table, arguments: BinaryTryTableArguments{ catches: [BinaryCatch{ tag_index: u32(0) }] } }
	configuration.label_stack_ << BinaryMachineLabel.create(1, 91, 0, outer)
	configuration.value_stack_.append(BinaryMachineValue.from_i32(404))
	configuration.label_stack_ << BinaryMachineLabel.create(1, 92, 1, unsafe { nil })
	inner := &BinaryInstruction{ opcode: binary_op_try_table, arguments: BinaryTryTableArguments{ catches: [BinaryCatch{ capture_reference: true }] } }
	configuration.label_stack_ << BinaryMachineLabel.create(0, 93, 1, inner)
	configuration.label_stack_ << BinaryMachineLabel.create(0, 94, 1, unsafe { nil })
	configuration.value_stack_.append(BinaryMachineValue.from_i32(777))
	assert interpreter.unwind_to_throw_handler(mut configuration, exception)? == 92
	assert configuration.label_stack_.len == 3
	assert voidptr(configuration.label_stack_[1].try_table_instruction()) == voidptr(outer)
	assert configuration.value_stack_.size() == 2
	assert unsafe { configuration.value_stack_.data()[0].to_i32() } == 404
	assert *configuration.value_stack_.last() == BinaryMachineValue.from_reference(BinaryExceptionReference{ address: exception })
}

fn test_source_unmatched_throw_drops_only_current_frame_labels_without_searching_caller() {
	stack_info := libjs.StackInfo.new()
	mut interpreter := BinaryMachineBytecodeInterpreter.create(&stack_info)
	mut store := BinaryMachineStore.create()
	first, second := source_unwind_tags(mut store)
	exception := store.allocate_exception(second, [BinaryMachineValue.from_i32(41)])?
	owner := BinaryMachineModuleInstance.create_with_contents(BinaryMachineModuleConstruction{
		tags: [
			second,
			first,
		]
	})
	mut configuration := BinaryMachineConfiguration.create(mut store)
	defer { configuration.destroy() }
	expression := &BinaryExpression{ instructions: [BinaryInstruction{ opcode: binary_op_synthetic_end_expression }] }
	mut caller_locals := BinaryMachineArguments{}
	configuration.set_frame(.no, owner, mut caller_locals, expression, 0)
	caller_catch := &BinaryInstruction{ opcode: binary_op_try_table, arguments: BinaryTryTableArguments{ catches: [BinaryCatch{ tag_index: u32(0) }] } }
	configuration.label_stack_ << BinaryMachineLabel.create(0, 91, 0, caller_catch)
	configuration.value_stack_.append(BinaryMachineValue.from_i32(303))
	mut callee_locals := BinaryMachineArguments{}
	configuration.set_frame(.no, owner, mut callee_locals, expression, 0)
	callee_catch := &BinaryInstruction{ opcode: binary_op_try_table, arguments: BinaryTryTableArguments{ catches: [BinaryCatch{ tag_index: u32(1) }] } }
	configuration.label_stack_ << BinaryMachineLabel.create(0, 92, 1, callee_catch)
	configuration.label_stack_ << BinaryMachineLabel.create(0, 93, 1, unsafe { nil })
	configuration.value_stack_.append(BinaryMachineValue.from_i32(777))
	configuration.ip_ = 73
	interpreter.set_trap_message('Earlier trap')
	assert interpreter.unwind_to_throw_handler(mut configuration, exception) == none
	assert configuration.label_stack_.len == 2
	assert voidptr(configuration.label_stack_[1].try_table_instruction()) == voidptr(caller_catch)
	assert configuration.value_stack_.size() == 2
	assert unsafe { configuration.value_stack_.data()[0].to_i32() } == 303
	assert configuration.value_stack_.last().to_i32() == 777
	assert configuration.frame_stack_.len == 2 && configuration.frame().label_index() == 2
	assert configuration.ip_ == 73 && interpreter.trap().format() == 'Earlier trap'
}
