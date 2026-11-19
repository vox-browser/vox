module libjs

// Selected paths from Rust/src/bytecode/{generator,codegen}.rs.
// The V stream uses instruction indices and monotonically allocated registers;
// upstream's register reuse, caches and packed instruction ABI remain pending.
// Ordinary functions retain their defining source and compile on first call.
// Unsupported top-level syntax fails before the program executes.
struct BytecodeLoop {
mut:
	is_iteration bool = true
	breaks      []u32
	continues   []u32
	scope_depth int
	iterator    ?Operand
	returns     []LoopReturnExit
	abrupts     []LoopAbruptExit
}

struct BytecodeGenerator {
mut:
	register_bindings []FunctionRegisterBinding
	executable    &Executable
	strict        bool
	starting_line u32 = 1
	range         SourceRange
	scope_depth   int
	loops         []BytecodeLoop
	labels        []BytecodeLabel
	finalizers    []BytecodeFinally
	function_body bool
	generator_function bool
	initialized_functions []u32
	annex_b_function_names []Utf16String
	compile_stack_ ?StackInfo
}

fn (mut generator BytecodeGenerator) check_compile_stack() ! {
	if generator.compile_stack_ == none { generator.compile_stack_ = StackInfo.new() }
	if (generator.compile_stack_ or { return error('Missing compiler stack bounds') }).size_free() < 512 * 1024 {
		return error('LibJS bytecode compilation stack budget exceeded')
	}
}

fn (mut generator BytecodeGenerator) emit(instruction Instruction) u32 {
	index := u32(generator.executable.instructions.len)
	mut start := generator.range.start
	if start.line > 0 { start.line += generator.starting_line - 1 }
	generator.executable.instructions << instruction
	generator.executable.source_map << SourceMapEntry{
		bytecode_offset: index
		source_range:    SourceCodeRange{
			code:  generator.executable.source_code
			start: start
		}
	}
	return index
}

fn (mut generator BytecodeGenerator) patch(index u32) {
	generator.executable.instructions[index].target = u32(generator.executable.instructions.len)
}

fn (mut generator BytecodeGenerator) temporary() Operand {
	index := generator.executable.registers_and_locals_count
	generator.executable.registers_and_locals_count++
	return Operand.register(index)
}

fn (mut generator BytecodeGenerator) constant(value Value) Operand {
	index := u32(generator.executable.constants.len)
	generator.executable.constants << value
	return Operand.constant(index)
}

fn (mut generator BytecodeGenerator) identifier(name Utf16String) u32 {
	for index, existing in generator.executable.identifier_table {
		if existing == name { return u32(index) }
	}
	index := u32(generator.executable.identifier_table.len)
	generator.executable.identifier_table << name.clone()
	return index
}

fn (generator &BytecodeGenerator) unsupported(description string) IError {
	filename := (generator.executable.source_code or { panic('missing source') }).filename.str()
	return error('LibJS bytecode: ${filename}:${generator.range.start.line +
		generator.starting_line - 1}:${generator.range.start.column + 1}: ${description} is not translated yet')
}

fn binary_opcode(op BinaryOp) OpCode {
	return match op {
		.addition { .add }
		.subtraction { .sub }
		.multiplication { .mul }
		.division { .div }
		.modulo { .mod_ }
		.exponentiation { .exp }
		.strictly_equals { .strict_equals }
		.strictly_inequals { .strict_inequals }
		.loosely_equals { .loose_equals }
		.loosely_inequals { .loose_inequals }
		.less_than { .less_than }
		.less_than_equals { .less_than_equals }
		.greater_than { .greater_than }
		.greater_than_equals { .greater_than_equals }
		.bitwise_and { .bitwise_and }
		.bitwise_or { .bitwise_or }
		.bitwise_xor { .bitwise_xor }
		.left_shift { .left_shift }
		.right_shift { .right_shift }
		.unsigned_right_shift { .unsigned_right_shift }
		.in_op { .in_op }
		.instance_of { .instance_of }
	}
}

fn identifier_name(expression &Expression) !Utf16String {
	if expression.kind.tag != .identifier_expr {
		return error('Only identifier assignment targets are translated')
	}
	return (expression.kind.identifier or { return error('Identifier is missing') }).name
}

// codegen.rs::emit_compound_assignment.
fn compound_assignment_opcode(op AssignmentOp) !OpCode {
	return match op {
		.bitwise_and_assignment { .bitwise_and }
		.bitwise_or_assignment { .bitwise_or }
		.bitwise_xor_assignment { .bitwise_xor }
		.left_shift_assignment { .left_shift }
		.right_shift_assignment { .right_shift }
		.unsigned_right_shift_assignment { .unsigned_right_shift }
		.addition_assignment { .add }
		.subtraction_assignment { .sub }
		.multiplication_assignment { .mul }
		.division_assignment { .div }
		.modulo_assignment { .mod_ }
		.exponentiation_assignment { .exp }
		else { return error('Invalid compound assignment operator') }
	}
}

// codegen.rs::{generate_member_expression,generate_call_expression}: retain the
// base before evaluating a computed key and reuse it as a method's receiver.
fn (mut generator BytecodeGenerator) member_reference(mut vm VM, expression &Expression) !(Operand, Operand) {
	kind := expression.kind
	object := kind.object or { return error('Missing member base') }
	mut base := Operand{}
	if object.kind.tag == .super_expr {
		base = generator.temporary()
		generator.emit(Instruction{op: .resolve_this_binding, dst: base})
	} else { base = generator.expression(mut vm, object)! }
	property := kind.property or { return error('Missing member property') }
	key := if kind.computed {
		generator.expression(mut vm, property)!
	} else if identifier := property.kind.private_identifier {
		generator.constant(Value.from_string(vm.create_string(identifier.name)))
	} else {
		name := identifier_name(property) or {
			return generator.unsupported('private property access')
		}
		generator.constant(Value.from_string(vm.create_string(name)))
	}
	if object.kind.tag == .super_expr {
		receiver := base
		base = generator.temporary()
		generator.emit(Instruction{op: .resolve_super_reference, dst: base, lhs: receiver})
	}
	return base, key
}

fn (mut generator BytecodeGenerator) short_circuit(op LogicalOp, operand Operand) []u32 {
	if op == .nullish_coalescing {
		take_rhs := generator.emit(Instruction{ op: .jump_if_nullish, lhs: operand })
		skip_rhs := generator.emit(Instruction{ op: .jump })
		generator.patch(take_rhs)
		return [skip_rhs]
	}
	return [
		generator.emit(Instruction{
			op:  if op == .and_op { OpCode.jump_if_false } else { OpCode.jump_if_true }
			lhs: operand
		}),
	]
}

// generate_assignment_expression's non-super member branches. The retained
// base and property are Values, as upstream: GetByValue and PutByValue each
// perform ToPropertyKey, without re-evaluating either AST expression.
fn (mut generator BytecodeGenerator) member_assignment(mut vm VM, target &Expression, op AssignmentOp, rhs &Expression) !Operand {
	base, key := generator.member_reference(mut vm, target)!
	dst := generator.temporary()
	mut jumps := []u32{}
	if op != .assignment {
		generator.emit(Instruction{
			op:     member_property_opcode(target, .get_property)
			dst:    dst
			lhs:    base
			rhs:    key
			strict: generator.strict
		})
		if op in [.and_assignment, .or_assignment, .nullish_assignment] {
			logical := match op {
				.and_assignment { LogicalOp.and_op }
				.or_assignment { LogicalOp.or_op }
				else { LogicalOp.nullish_coalescing }
			}

			jumps = generator.short_circuit(logical, dst)
		}
	}
	right := generator.expression(mut vm, rhs)!
	if op == .assignment || jumps.len > 0 {
		generator.emit(Instruction{ op: .mov, dst: dst, lhs: right })
	} else {
		generator.emit(Instruction{
			op:  compound_assignment_opcode(op)!
			dst: dst
			lhs: dst
			rhs: right
		})
	}
	generator.emit(Instruction{
		op:     member_property_opcode(target, .put_property)
		lhs:    base
		rhs:    key
		src:    dst
		strict: generator.strict
	})
	for jump in jumps {
		generator.patch(jump)
	}
	return dst
}

fn (mut generator BytecodeGenerator) expression(mut vm VM, expression &Expression) !Operand {
	generator.check_compile_stack()!
	previous_range := generator.range
	generator.range = expression.range
	defer { generator.range = previous_range }
	kind := expression.kind
	match kind.tag {
		.yield_expr { return generator.yield_expression(mut vm, expression) }
		.import_call {
			specifier := generator.expression(mut vm, kind.specifier or { return error('Missing import specifier') })!
			options := if options_expression := kind.options { generator.expression(mut vm, options_expression)! } else { generator.constant(js_undefined()) }
			result := generator.temporary()
			generator.emit(Instruction{op: .import_call, dst: result, lhs: specifier, rhs: options})
			return result
		}
		.tagged_template_literal { return generator.tagged_template(mut vm, expression) }
		.template_literal {
			data := kind.template_data or { return error('Missing template literal') }
			mut text := generator.constant(Value.from_string(vm.create_string(Utf16String.new())))
			// codegen.rs::generate_template_literal: evaluate each substitution
			// and ToString it before evaluating the next one. Addition itself
			// uses the default primitive hint and cannot perform this conversion.
			for part in data.expressions {
				value := generator.expression(mut vm, &part)!
				mut segment := value
				if part.kind.tag != .string_literal {
					segment = generator.temporary()
					generator.emit(Instruction{op: .to_string, dst: segment, lhs: value})
				}
				joined := generator.temporary()
				generator.emit(Instruction{op: .add, dst: joined, lhs: text, rhs: segment})
				text = joined
			}
			return text
		}
		.class_expr { return generator.class_expression(mut vm, kind.class_data or { return error('Missing class expression') }) }
		.meta_property {
			dst := generator.temporary()
			generator.emit(Instruction{op: if kind.meta_property_type == .import_meta { OpCode.get_import_meta } else { OpCode.get_new_target },dst:dst})
			return dst
		}
		.super_call {
			data := kind.super_call_data or { return error('Missing super call data') }
			callee := generator.temporary()
			generator.emit(Instruction{op: .get_super_constructor, dst: callee})
			if !data.is_synthetic && data.arguments.any(it.is_spread) {
				arguments := generator.arguments_array(mut vm, data.arguments)!
				result := generator.temporary()
				generator.emit(Instruction{op: .super_construct_with_array, dst: result, lhs: callee, rhs: arguments})
				return result
			}
			mut arguments := []Operand{}
			if !data.is_synthetic {
				for argument in data.arguments {
					arguments << generator.expression(mut vm, &argument.value)!
				}
			}
			result := generator.temporary()
			// A default derived constructor forwards the actual argument list;
			// its synthetic spread must not consult Array's iterator.
			generator.emit(Instruction{op: .super_construct, dst: result, lhs: callee, arguments: arguments, strict: data.is_synthetic})
			return result
		}
		.await_expr {
			value := generator.expression(mut vm, kind.operand or { return error('Missing await operand') })!
			generator.emit(Instruction{op: .await_value, lhs: value})
			result := generator.temporary()
			generator.emit(Instruction{op: .resume_async, dst: result})
			return result
		}
		.regexp_literal {
			data := kind.regexp_data or { return error('Missing regular expression') }
			engine := compile_regexp_engine(data.pattern, data.flags) or {
				return error('SyntaxError: ' + err.msg())
			}
			dst := generator.temporary()
			pattern := generator.constant(Value.from_string(vm.create_string(data.pattern)))
			flags := generator.constant(Value.from_string(vm.create_string(data.flags)))
			generator.executable.regexp_literal_programs << RegExpLiteralProgram{
				constant_index: pattern.index()
				engine: engine
			}
			generator.emit(Instruction{op: .new_regexp, dst: dst, lhs: pattern, rhs: flags})
			return dst
		}
		.array_expr {
			for element in kind.array_elements() {
				if value := element {
					if value.kind.tag == .spread { return generator.array_literal_with_spread(mut vm, kind.array_elements()) }
				}
			}
			dst := generator.temporary()
			generator.emit(Instruction{op: .new_array, dst: dst, lhs: generator.constant(Value.from_f64(f64(kind.array_elements().len)))})
			for index, element in kind.array_elements() {
				if value := element {
					item := generator.expression(mut vm, &value)!
					generator.emit(Instruction{op: .define_property, lhs: dst, rhs: generator.constant(Value.from_f64(f64(index))), src: item})
				}
			}
			return dst
		}
		.object_expr {
			return generator.object_literal(mut vm, kind.object_properties())
		}
		.function_expr {
			dst := generator.temporary()
			generator.emit(Instruction{op: .new_function, dst: dst, identifier: kind.function_id.id, strict: generator.executable.parsed_source.function_table.get(kind.function_id).name != none})
			return dst
		}
		.numeric_literal {
			return generator.constant(Value.from_f64(kind.numeric_value))
		}
		.big_int_literal {
			// codegen.rs::bigint_literal_digits and RustIntegration.cpp's BigInt
			// constant reader; SignedBigInteger::from_base removes separators.
			digits := kind.big_int_value.trim_string_right('n').replace('_', '')
			integer := string_to_bigint(utf16_string(digits)) or {
				return error('Invalid parsed BigInt literal')
			}
			return generator.constant(Value.from_bigint(integer))
		}
		.string_literal {
			return generator.constant(Value.from_string(vm.create_string(kind.string_value)))
		}
		.boolean_literal {
			return generator.constant(Value.from_bool(kind.bool_value))
		}
		.null_literal {
			return generator.constant(js_null())
		}
		.identifier_expr {
			dst := generator.temporary()
			generator.load_identifier(expression, dst)!
			return dst
		}
		.this_expr {
			dst := generator.temporary()
			generator.emit(Instruction{ op: .resolve_this_binding, dst: dst })
			return dst
		}
		.call, .new_expr {
			data := kind.call_data or { return error('Missing call data') }
			is_new := kind.tag == .new_expr
			mut callee := Operand{}
			mut this_value := generator.constant(js_undefined())
			if is_new {
				// A new-expression evaluates its callee as a value; no method
				// receiver or environment this-binding is supplied to [[Construct]].
				callee = generator.expression(mut vm, &data.callee)!
			} else {
				callee, this_value = generator.call_reference(mut vm, &data.callee)!
			}
			// codegen.rs::generate_call_expression: evaluate arguments left to
			// right after retaining the callee and receiver. This generator's
			// temporaries are never reused, so later arguments cannot overwrite them.
			dst := generator.temporary()
			generator.emit_call_arguments(mut vm, dst, callee, this_value, data.arguments, is_new)!
			return dst
		}
		.optional_chain {
			value, _ := generator.optional_chain_reference(mut vm, expression, false)!
			return value
		}
		.member {
			base, key := generator.member_reference(mut vm, expression)!
			dst := generator.temporary()
			generator.emit(Instruction{
				op:     member_property_opcode(expression, .get_property)
				dst:    dst
				lhs:    base
				rhs:    key
				strict: generator.strict
			})
			return dst
		}
		.binary {
			if kind.binary_op == .in_op {
				if lhs := kind.lhs {
					if identifier := lhs.kind.private_identifier {
						base := generator.expression(mut vm, kind.rhs or { return error('Missing private in object') })!
						dst := generator.temporary()
						generator.emit(Instruction{op: .has_private, dst: dst, lhs: base, rhs: generator.constant(Value.from_string(vm.create_string(identifier.name)))})
						return dst
					}
				}
			}
			op := binary_opcode(kind.binary_op)
			left :=
				generator.expression(mut vm, kind.lhs or { return error('Missing binary lhs') })!
			right := generator.expression(mut vm,
				kind.rhs or { return error('Missing binary rhs') })!
			dst := generator.temporary()
			generator.emit(Instruction{ op: op, dst: dst, lhs: left, rhs: right })
			return dst
		}
		.logical {
			dst := generator.temporary()
			left := generator.expression(mut vm,
				kind.lhs or { return error('Missing logical lhs') })!
			generator.emit(Instruction{ op: .mov, dst: dst, lhs: left })
			jumps := generator.short_circuit(kind.logical_op, dst)
			right := generator.expression(mut vm, kind.rhs or {
				return error('Missing logical rhs')
			})!
			generator.emit(Instruction{ op: .mov, dst: dst, lhs: right })
			for jump in jumps {
				generator.patch(jump)
			}
			return dst
		}
		.conditional {
			return generator.conditional_tail(mut vm, expression)
		}
		.sequence {
			mut last := generator.constant(js_undefined())
			for part in kind.expressions() {
				last = generator.expression(mut vm, &part)!
			}
			return last
		}
		.unary {
			operand := kind.operand or { return error('Missing unary operand') }
			dst := generator.temporary()
			if kind.unary_op == .typeof_op && operand.kind.tag == .identifier_expr {
				if local := generator.expression_register(operand) {
					generator.emit(Instruction{op: .typeof_op, dst: dst, lhs: local})
					return dst
				}
				generator.emit(Instruction{
					op:         .typeof_binding
					dst:        dst
					identifier: generator.identifier(identifier_name(operand)!)
					strict:     generator.strict
				})
				return dst
			}
			if kind.unary_op == .delete_op {
				// codegen.rs::emit_delete_reference: identifiers are resolved
				// without GetValue; non-references run only for their side effects.
				if operand.kind.tag == .identifier_expr {
					if _ := generator.expression_register(operand) {
						generator.emit(Instruction{op: .mov, dst: dst, lhs: generator.constant(Value.from_bool(false))})
						return dst
					}
					generator.emit(Instruction{
						op:         .delete_binding
						dst:        dst
						identifier: generator.identifier(identifier_name(operand)!)
						strict:     generator.strict
					})
				} else if operand.kind.tag == .optional_chain {
					value, _ := generator.optional_chain_reference(mut vm, operand, true)!
					return value
				} else if operand.kind.tag == .member {
					base, key := generator.member_reference(mut vm, operand)!
					generator.emit(Instruction{
						op:     member_property_opcode(operand, .delete_property)
						dst:    dst
						lhs:    base
						rhs:    key
						strict: generator.strict
					})
				} else {
					generator.expression(mut vm, operand)!
					return generator.constant(Value.from_bool(true))
				}
				return dst
			}
			value := generator.expression(mut vm, operand)!
			if kind.unary_op == .void_op { return generator.constant(js_undefined()) }
			op := match kind.unary_op {
				.plus { OpCode.unary_plus }
				.minus { OpCode.unary_minus }
				.not_op { OpCode.not_op }
				.bitwise_not { OpCode.bitwise_not }
				else { OpCode.typeof_op }
			}

			generator.emit(Instruction{ op: op, dst: dst, lhs: value })
			return dst
		}
		.assignment {
			target := kind.assignment_lhs() or { return error('Missing assignment target') }
			if target is AssignmentLhsPattern {
				if kind.assignment_op != .assignment { return error('Invalid destructuring assignment operator') }
				value := generator.expression(mut vm, kind.rhs or { return error('Missing assignment rhs') })!
				generator.assignment_pattern(mut vm, target.pattern, value)!
				return value
			}
			if target !is AssignmentLhsExpression {
				return error('Invalid assignment target')
			}
			if target.expression.kind.tag == .member {
				return generator.member_assignment(mut vm, target.expression, kind.assignment_op, kind.rhs or {
					return error('Missing assignment rhs')
				})
			}
			_ := identifier_name(target.expression) or {
				return generator.unsupported('property assignment')
			}
			dst := generator.temporary()
			if kind.assignment_op == .assignment {
				right := generator.expression(mut vm, kind.rhs or {
					return error('Missing assignment rhs')
				})!
				generator.emit(Instruction{ op: .mov, dst: dst, lhs: right })
			} else {
				generator.load_identifier(target.expression, dst)!
				mut jumps := []u32{}
				if kind.assignment_op in [.and_assignment, .or_assignment, .nullish_assignment] {
					logical := match kind.assignment_op {
						.and_assignment { LogicalOp.and_op }
						.or_assignment { LogicalOp.or_op }
						else { LogicalOp.nullish_coalescing }
					}

					jumps = generator.short_circuit(logical, dst)
				}
				right := generator.expression(mut vm, kind.rhs or {
					return error('Missing assignment rhs')
				})!
				if jumps.len > 0 {
					generator.emit(Instruction{ op: .mov, dst: dst, lhs: right })
				} else {
					actual := compound_assignment_opcode(kind.assignment_op)!

					generator.emit(Instruction{ op: actual, dst: dst, lhs: dst, rhs: right })
				}
				generator.store_identifier(target.expression, dst)!
				for jump in jumps {
					generator.patch(jump)
				}
				return dst
			}
			generator.store_identifier(target.expression, dst)!
			return dst
		}
		.update {
			operand := kind.argument or { return error('Missing update operand') }
			if operand.kind.tag == .member {
				// generate_update_expression: retain base/key for store-back, and
				// preserve the numeric old value for postfix results.
				base, key := generator.member_reference(mut vm, operand)!
				old := generator.temporary()
				generator.emit(Instruction{
					op:     member_property_opcode(operand, .get_property)
					dst:    old
					lhs:    base
					rhs:    key
					strict: generator.strict
				})
				generator.emit(Instruction{ op: .to_numeric, dst: old, lhs: old })
				dst := generator.temporary()
				generator.emit(Instruction{
					op:  if kind.update_op == .increment {
						OpCode.increment
					} else {
						OpCode.decrement
					}
					dst: dst
					lhs: old
				})
				generator.emit(Instruction{
					op:     member_property_opcode(operand, .put_property)
					lhs:    base
					rhs:    key
					src:    dst
					strict: generator.strict
				})
				return if kind.prefixed { dst } else { old }
			}
			_ := identifier_name(operand) or { return generator.unsupported('property update') }
			old := generator.temporary()
			generator.load_identifier(operand, old)!
			generator.emit(Instruction{ op: .to_numeric, dst: old, lhs: old })
			dst := generator.temporary()
			generator.emit(Instruction{
				op:  if kind.update_op == .increment { OpCode.increment } else { OpCode.decrement }
				dst: dst
				lhs: old
			})
			generator.store_identifier(operand, dst)!
			return if kind.prefixed { dst } else { old }
		}
		else {
			return generator.unsupported(kind.tag.str())
		}
	}
}

fn declaration_bound_names(declaration VariableDeclarator) []Utf16String {
    mut names := []Utf16String{}
    collect_declarator_names(declaration.target,mut names)
    return names
}

fn (mut generator BytecodeGenerator) collect_vars(statement &Statement) ! {
	kind := statement.kind
	if kind.tag == .function_declaration {
		name := kind.func_name or { return error('Missing function declaration name') }
		if !generator.executable.global_bindings.any(it.name == name.name && !it.is_lexical) {
			generator.executable.global_bindings << GlobalBinding{name: name.name.clone()}
		}
		return
	}
	if kind.tag == .variable_declaration && kind.decl_kind == .var_kind {
        for declaration in kind.declarations {
            for name in declaration_bound_names(declaration) {
                if !generator.executable.global_bindings.any(it.name==name && !it.is_lexical) {
                    generator.executable.global_bindings << GlobalBinding{name:name.clone()}
                }
            }
        }
    }
	if kind.tag in [.program, .block, .function_body] {
		scope := if kind.tag == .program { (kind.program_data or { return error('Missing program') }).scope } else { kind.scope or {
				return error('Missing block')} }
		for child in scope.children {
			if kind.tag == .block && child.function_declaration_for_labelled_item() != none {
				continue
			}
			generator.collect_vars(&child)!
		}
		if kind.tag in [.program, .function_body] && !generator.strict {
			generator.annex_b_function_names = scope.annexb_function_names.clone()
			for name in scope.annexb_function_names {
				if !generator.executable.global_bindings.any(it.name == name && !it.is_lexical) {
					generator.executable.global_bindings << GlobalBinding{name: name.clone(), is_annex_b: true}
				}
			}
		}
	} else if kind.tag in [.if_stmt, .while_stmt, .do_while, .for_stmt, .for_in_of] {
		if body := kind.body { generator.collect_vars(body)! }
		if consequent := kind.consequent { generator.collect_vars(consequent)! }
		if alternate := kind.alternate { generator.collect_vars(alternate)! }
		if init := kind.for_init {
			if init is ForInitDeclaration { generator.collect_vars(init.statement)! }
		}
		if lhs := kind.for_in_of_lhs {
			if lhs is ForInOfLhsDeclaration { generator.collect_vars(lhs.statement)! }
		}
	} else if kind.tag == .switch_stmt {
		data := kind.switch_data or { return error('Missing switch statement') }
		for clause in data.cases {
			for child in clause.scope.children {
				if child.function_declaration_for_labelled_item() == none { generator.collect_vars(&child)! }
			}
		}
	} else if kind.tag==.try_stmt {
		data := kind.try_data or { return error('Missing try statement') }
		generator.collect_vars(&data.block)!
		if handler := data.handler { generator.collect_vars(&handler.body)! }
		if finalizer := data.finalizer { generator.collect_vars(&finalizer)! }
	} else if kind.tag == .labelled {
		generator.collect_vars(kind.labelled_item or { return error('Missing labelled statement') })!
	}
}

fn (mut generator BytecodeGenerator) lexical_declarations(children []Statement, global bool) ! {
	for child in children {
		if child.kind.tag == .class_declaration {
			data := child.kind.class_data or { return error('Missing class declaration') }
			name := data.name or { return error('Missing class name') }
			if global { generator.executable.global_bindings << GlobalBinding{ name: name.name.clone(), is_lexical: true } }
			else { generator.emit(Instruction{ op: .create_mutable_binding, identifier: generator.identifier(name.name) }) }
			continue
		}
		if child.kind.tag != .variable_declaration || child.kind.decl_kind == .var_kind { continue
		 }
        for declaration in child.kind.declarations {
            for name in declaration_bound_names(declaration) {
                constant := child.kind.decl_kind==.const_kind
                if global {
                    generator.executable.global_bindings << GlobalBinding{name:name.clone(),is_lexical:true,is_constant:constant}
                } else {
                    generator.emit(Instruction{op:if constant { OpCode.create_immutable_binding } else { OpCode.create_mutable_binding },identifier:generator.identifier(name)})
                }
            }
        }
	}
}

fn (mut generator BytecodeGenerator) clear_completion() {
	undefined := generator.constant(js_undefined())
	generator.emit(Instruction{
		op:  .mov
		dst: Operand.register(register_accumulator)
		lhs: undefined
	})
}

fn (mut generator BytecodeGenerator) initialize_functions(children []Statement) {
	for child in children {
		declaration := child.function_declaration_for_labelled_item() or { continue }
		generator.initialized_functions << declaration.kind.function_id.id
		name := declaration.kind.func_name or { continue }
		dst := generator.temporary()
		generator.emit(Instruction{op: .new_function, dst: dst, identifier: declaration.kind.function_id.id})
		generator.emit(Instruction{op: .set_variable, lhs: dst, identifier: generator.identifier(name.name), strict: generator.strict})
	}
}

fn (mut generator BytecodeGenerator) statement(mut vm VM, statement &Statement) ! {
	generator.check_compile_stack()!
	previous_range := generator.range
	generator.range = statement.range
	defer { generator.range = previous_range }
	kind := statement.kind
	match kind.tag {
		.class_declaration {
			data := kind.class_data or { return error('Missing class declaration') }
			name := data.name or { return error('Missing class name') }
			value := generator.class_expression(mut vm, data)!
			generator.emit(Instruction{ op: .initialize_binding, lhs: value, identifier: generator.identifier(name.name), strict: true })
		}
		.for_in_of { generator.for_in_statement(mut vm, statement)! }
		.switch_stmt { generator.switch_statement(mut vm, statement)! }
		.try_stmt { generator.try_catch_statement(mut vm,statement)! }
		.labelled { generator.labelled_statement(mut vm, statement)! }
		.function_declaration {
			if kind.function_id.id !in generator.initialized_functions {
				return generator.unsupported('conditional function declarations')
			}
			if kind.is_hoisted && !generator.strict {
				generator.copy_annex_b_function(statement)!
			}
		}
		.return_stmt {
			if !generator.function_body { return generator.unsupported('return outside function') }
			value := if argument := kind.return_arg { generator.expression(mut vm, argument)! } else { generator.constant(js_undefined()) }
			generator.emit_return(value)
		}
		.empty, .debugger_stmt {}
		.expression_stmt {
			value := generator.expression(mut vm, kind.expression or {
				return error('Missing expression')
			})!
			generator.emit(Instruction{
				op:  .mov
				dst: Operand.register(register_accumulator)
				lhs: value
			})
		}
		.block {
			scope := kind.scope or { return error('Missing block scope') }
			if elide_empty_block(scope) {
				// Keep budgeted boundary operations, without allocating an empty
				// environment or changing the actual lexical-depth metadata.
				generator.emit(Instruction{op: .nop})
				for child in scope.children { generator.statement(mut vm, &child)! }
				generator.emit(Instruction{op: .nop})
				return
			}
			generator.emit(Instruction{ op: .enter_scope })
			generator.scope_depth++
			generator.lexical_declarations(scope.children, false)!
			generator.initialize_lexical_functions(scope.children)!
			for child in scope.children {
				generator.statement(mut vm, &child)!
			}
			generator.scope_depth--
			generator.emit(Instruction{ op: .leave_scope })
		}
        .variable_declaration {
            for declaration in kind.declarations {
                if declaration.init==none && kind.decl_kind==.var_kind { continue }
                value := if init := declaration.init { generator.expression(mut vm,&init)! } else { generator.constant(js_undefined()) }
                generator.initialize_declaration_target(mut vm,declaration.target,value,kind.decl_kind!=.var_kind)!
            }
        }
		.if_stmt {
			generator.clear_completion()
			test := generator.expression(mut vm, kind.test or { return error('Missing if test') })!
			alternate := generator.emit(Instruction{ op: .jump_if_false, lhs: test })
			generator.statement(mut vm,
				kind.consequent or { return error('Missing if consequent') })!
			end := generator.emit(Instruction{ op: .jump })
			generator.patch(alternate)
			if other := kind.alternate { generator.statement(mut vm, other)! }
			generator.patch(end)
		}
		.while_stmt, .do_while, .for_stmt {
			generator.clear_completion()
			mut for_scope := false
			mut per_iteration := []Utf16String{}
			if init := kind.for_init {
				if init is ForInitDeclaration {
					if init.statement.kind.decl_kind != .var_kind {
						for_scope = true
						generator.emit(Instruction{ op: .enter_scope })
						generator.scope_depth++
						generator.lexical_declarations([*init.statement], false)!
						if init.statement.kind.decl_kind == .let_kind {
							for declaration in init.statement.kind.declarations {
								per_iteration << declaration_bound_names(declaration)
							}
						}
					}
					generator.statement(mut vm, init.statement)!
				} else if init is ForInitExpression {
					generator.expression(mut vm, init.expression)!
				}
			}
			generator.copy_for_iteration_bindings(per_iteration)
			start := u32(generator.executable.instructions.len)
			mut exit_jump := ?u32(none)
			if kind.tag != .do_while {
				if test := kind.test {
					value := generator.expression(mut vm, test)!
					exit_jump = generator.emit(Instruction{ op: .jump_if_false, lhs: value })
				}
			}
			generator.loops << BytecodeLoop{
				scope_depth: generator.scope_depth
			}
			generator.statement(mut vm, kind.body or { return error('Missing loop body') })!
			continue_target := u32(generator.executable.instructions.len)
			generator.copy_for_iteration_bindings(per_iteration)
			if update := kind.update { generator.expression(mut vm, update)! }
			if kind.tag == .do_while {
				value := generator.expression(mut vm, kind.test or {
					return error('Missing do-while test')
				})!
				generator.emit(Instruction{ op: .jump_if_true, lhs: value, target: start })
			} else {
				generator.emit(Instruction{ op: .jump, target: start })
			}
			loop := generator.loops.pop()
			if jump := exit_jump { generator.patch(jump) }
			for jump in loop.breaks {
				generator.patch(jump)
			}
			for jump in loop.continues {
				generator.executable.instructions[jump].target = continue_target
			}
			if for_scope {
				generator.scope_depth--
				generator.emit(Instruction{ op: .leave_scope })
			}
		}
		.break_stmt, .continue_stmt {
			generator.loop_control_statement(statement)!
		}
		.throw_stmt {
			value := generator.expression(mut vm, kind.throw_expr or {
				return error('Missing throw value')
			})!
			generator.emit(Instruction{ op: .throw_op, lhs: value })
		}
		else {
			return generator.unsupported(kind.tag.str())
		}
	}
}

pub fn (mut script Script) compile(mut vm VM) !&Executable {
	if script.starting_line == 0 { return error('Script starting line must be positive') }
	if script.parsed == unsafe { nil } {
		return error('Script source is owned by an external JavaScript backend; no translated AST is available')
	}
	if cached := script.cached_executable { return cached }
	if script.parsed.has_errors() { return ScriptParseError{
			diagnostics: script.parsed.diagnostics
		} }
	program := script.parsed.program.kind.program_data or { return error('Missing program') }
	if program.program_type == .module {
		return error('LibJS module execution is not translated yet')
	}
	mut generator := BytecodeGenerator{
		executable:    &Executable{
			name:                       utf16_string(script.filename)
			registers_and_locals_count: reserved_register_count
			source_code:                SourceCode.create(utf16_string(script.filename),
				utf16_string(script.parsed.source_text))
			parsed_source: script.parsed
			starting_line: script.starting_line
			native_cache_scope: 'script'
		}
		strict:        script.is_strict_mode
		starting_line: script.starting_line
		range:         script.parsed.program.range
	}
	generator.collect_vars(&script.parsed.program)!
	generator.lexical_declarations(program.scope.children, true)!
	generator.clear_completion()
	generator.initialize_functions(program.scope.children)
	for statement in program.scope.children {
		generator.statement(mut vm, &statement)!
	}
	generator.emit(Instruction{ op: .end, lhs: Operand.register(register_accumulator) })
	generator.executable.bytecode_length = u32(generator.executable.instructions.len)
	generator.executable.validate(0)!
	script.cached_executable = generator.executable
	return generator.executable
}
