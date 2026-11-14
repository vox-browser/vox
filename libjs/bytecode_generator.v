module libjs

// Selected paths from Rust/src/bytecode/{generator,codegen}.rs.
// The V stream uses instruction indices and monotonically allocated registers;
// upstream's register reuse, caches and packed instruction ABI remain pending.
// Ordinary functions retain their defining source and compile on first call.
// Unsupported top-level syntax fails before the program executes.
struct BytecodeLoop {
mut:
	breaks      []u32
	continues   []u32
	scope_depth int
}

struct BytecodeGenerator {
mut:
	executable    &Executable
	strict        bool
	starting_line u32 = 1
	range         SourceRange
	scope_depth   int
	loops         []BytecodeLoop
	function_body bool
	initialized_functions []u32
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
	base := generator.expression(mut vm, kind.object or { return error('Missing member base') })!
	property := kind.property or { return error('Missing member property') }
	key := if kind.computed {
		generator.expression(mut vm, property)!
	} else {
		name := identifier_name(property) or {
			return generator.unsupported('private property access')
		}
		generator.constant(Value.from_string(vm.create_string(name)))
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
			op:     .get_property
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
		op:     .put_property
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
	previous_range := generator.range
	generator.range = expression.range
	defer { generator.range = previous_range }
	kind := expression.kind
	match kind.tag {
		.regexp_literal {
			data := kind.regexp_data or { return error('Missing regular expression') }
			compile_regexp_engine(data.pattern, data.flags) or { return error('SyntaxError: ' + err.msg()) }
			dst := generator.temporary()
			generator.emit(Instruction{op: .new_regexp, dst: dst, lhs: generator.constant(Value.from_string(vm.create_string(data.pattern))), rhs: generator.constant(Value.from_string(vm.create_string(data.flags)))})
			return dst
		}
		.array_expr {
			dst := generator.temporary()
			generator.emit(Instruction{op: .new_array, dst: dst, lhs: generator.constant(Value.from_f64(f64(kind.array_elements.len)))})
			for index, element in kind.array_elements {
				if value := element {
					item := generator.expression(mut vm, &value)!
					generator.emit(Instruction{op: .define_property, lhs: dst, rhs: generator.constant(Value.from_f64(f64(index))), src: item})
				}
			}
			return dst
		}
		.object_expr {
			dst := generator.temporary()
			generator.emit(Instruction{op: .new_object, dst: dst})
			for property in kind.object_properties {
				if property.property_type != .key_value { return generator.unsupported('object accessor, spread or prototype setter') }
				key := if !property.is_computed && property.key.kind.tag == .identifier_expr {
					generator.constant(Value.from_string(vm.create_string(identifier_name(&property.key)!)))
				} else { generator.expression(mut vm, &property.key)! }
				value := generator.expression(mut vm, &(property.value or { return error('Missing property value') }))!
				generator.emit(Instruction{op: .define_property, lhs: dst, rhs: key, src: value})
			}
			return dst
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
			generator.emit(Instruction{
				op:         .get_binding
				dst:        dst
				identifier: generator.identifier(identifier_name(expression)!)
				strict:     generator.strict
			})
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
			} else if data.callee.kind.tag == .member {
				base, key := generator.member_reference(mut vm, &data.callee)!
				callee = generator.temporary()
				this_value = base
				generator.emit(Instruction{
					op:     .get_property
					dst:    callee
					lhs:    base
					rhs:    key
					strict: generator.strict
				})
			} else if data.callee.kind.tag == .identifier_expr {
				callee = generator.temporary()
				this_value = generator.temporary()
				generator.emit(Instruction{
					op:         .get_callee_and_this
					dst:        callee
					rhs:        this_value
					identifier: generator.identifier(identifier_name(&data.callee)!)
					strict:     generator.strict
				})
			} else {
				callee = generator.expression(mut vm, &data.callee)!
			}
			// codegen.rs::generate_call_expression: evaluate arguments left to
			// right after retaining the callee and receiver. This generator's
			// temporaries are never reused, so later arguments cannot overwrite them.
			mut call_arguments := []Operand{cap: data.arguments.len}
			for argument in data.arguments {
				if argument.is_spread { return generator.unsupported('spread call arguments') }
				call_arguments << generator.expression(mut vm, &argument.value)!
			}
			dst := generator.temporary()
			generator.emit(Instruction{
				op:        if is_new { OpCode.construct } else { OpCode.call }
				dst:       dst
				lhs:       callee
				rhs:       this_value
				arguments: call_arguments
			})
			return dst
		}
		.member {
			base, key := generator.member_reference(mut vm, expression)!
			dst := generator.temporary()
			generator.emit(Instruction{
				op:     .get_property
				dst:    dst
				lhs:    base
				rhs:    key
				strict: generator.strict
			})
			return dst
		}
		.binary {
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
			for part in kind.expressions {
				last = generator.expression(mut vm, &part)!
			}
			return last
		}
		.unary {
			operand := kind.operand or { return error('Missing unary operand') }
			dst := generator.temporary()
			if kind.unary_op == .typeof_op && operand.kind.tag == .identifier_expr {
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
					generator.emit(Instruction{
						op:         .delete_binding
						dst:        dst
						identifier: generator.identifier(identifier_name(operand)!)
						strict:     generator.strict
					})
				} else if operand.kind.tag == .member {
					base, key := generator.member_reference(mut vm, operand)!
					generator.emit(Instruction{
						op:     .delete_property
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
			target := kind.assignment_lhs or { return error('Missing assignment target') }
			if target !is AssignmentLhsExpression {
				return generator.unsupported('destructuring assignment')
			}
			if target.expression.kind.tag == .member {
				return generator.member_assignment(mut vm, target.expression, kind.assignment_op, kind.rhs or {
					return error('Missing assignment rhs')
				})
			}
			name := identifier_name(target.expression) or {
				return generator.unsupported('property assignment')
			}
			identifier := generator.identifier(name)
			dst := generator.temporary()
			if kind.assignment_op == .assignment {
				right := generator.expression(mut vm, kind.rhs or {
					return error('Missing assignment rhs')
				})!
				generator.emit(Instruction{ op: .mov, dst: dst, lhs: right })
			} else {
				generator.emit(Instruction{
					op:         .get_binding
					dst:        dst
					identifier: identifier
					strict:     generator.strict
				})
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
				generator.emit(Instruction{
					op:         .set_binding
					lhs:        dst
					identifier: identifier
					strict:     generator.strict
				})
				for jump in jumps {
					generator.patch(jump)
				}
				return dst
			}
			generator.emit(Instruction{
				op:         .set_binding
				lhs:        dst
				identifier: identifier
				strict:     generator.strict
			})
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
					op:     .get_property
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
					op:     .put_property
					lhs:    base
					rhs:    key
					src:    dst
					strict: generator.strict
				})
				return if kind.prefixed { dst } else { old }
			}
			name := identifier_name(operand) or { return generator.unsupported('property update') }
			identifier := generator.identifier(name)
			old := generator.temporary()
			generator.emit(Instruction{
				op:         .get_binding
				dst:        old
				identifier: identifier
				strict:     generator.strict
			})
			generator.emit(Instruction{ op: .to_numeric, dst: old, lhs: old })
			dst := generator.temporary()
			generator.emit(Instruction{
				op:  if kind.update_op == .increment { OpCode.increment } else { OpCode.decrement }
				dst: dst
				lhs: old
			})
			generator.emit(Instruction{
				op:         .set_binding
				lhs:        dst
				identifier: identifier
				strict:     generator.strict
			})
			return if kind.prefixed { dst } else { old }
		}
		else {
			return generator.unsupported(kind.tag.str())
		}
	}
}

fn declaration_name(declaration VariableDeclarator) !Utf16String {
	if declaration.target is IdentifierVarTarget { return declaration.target.identifier.name }
	return error('Destructuring declarations are not translated yet')
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
			name := declaration_name(declaration)!
			mut exists := false
			for binding in generator.executable.global_bindings {
				if !binding.is_lexical && binding.name == name {
					exists = true
					break
				}
			}
			if !exists { generator.executable.global_bindings << GlobalBinding{
					name: name.clone()
				} }
		}
	}
	if kind.tag in [.program, .block, .function_body] {
		scope := if kind.tag == .program { (kind.program_data or { return error('Missing program') }).scope } else { kind.scope or {
				return error('Missing block')} }
		for child in scope.children {
			generator.collect_vars(&child)!
		}
	} else if kind.tag in [.if_stmt, .while_stmt, .do_while, .for_stmt] {
		if body := kind.body { generator.collect_vars(body)! }
		if consequent := kind.consequent { generator.collect_vars(consequent)! }
		if alternate := kind.alternate { generator.collect_vars(alternate)! }
		if init := kind.for_init {
			if init is ForInitDeclaration { generator.collect_vars(init.statement)! }
		}
	}
}

fn (mut generator BytecodeGenerator) lexical_declarations(children []Statement, global bool) ! {
	for child in children {
		if child.kind.tag != .variable_declaration || child.kind.decl_kind == .var_kind { continue
		 }
		for declaration in child.kind.declarations {
			name := declaration_name(declaration)!
			constant := child.kind.decl_kind == .const_kind
			if global {
				generator.executable.global_bindings << GlobalBinding{
					name:        name.clone()
					is_lexical:  true
					is_constant: constant
				}
			} else {
				generator.emit(Instruction{
					op:         if constant {
						OpCode.create_immutable_binding
					} else {
						OpCode.create_mutable_binding
					}
					identifier: generator.identifier(name)
				})
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
		if child.kind.tag != .function_declaration { continue }
		generator.initialized_functions << child.kind.function_id.id
		name := child.kind.func_name or { continue }
		dst := generator.temporary()
		generator.emit(Instruction{op: .new_function, dst: dst, identifier: child.kind.function_id.id})
		generator.emit(Instruction{op: .set_variable, lhs: dst, identifier: generator.identifier(name.name), strict: generator.strict})
	}
}

fn (mut generator BytecodeGenerator) statement(mut vm VM, statement &Statement) ! {
	previous_range := generator.range
	generator.range = statement.range
	defer { generator.range = previous_range }
	kind := statement.kind
	match kind.tag {
		.function_declaration {
			if kind.function_id.id !in generator.initialized_functions {
				return generator.unsupported('conditional function declarations')
			}
		}
		.return_stmt {
			if !generator.function_body { return generator.unsupported('return outside function') }
			value := if argument := kind.return_arg { generator.expression(mut vm, argument)! } else { generator.constant(js_undefined()) }
			generator.emit(Instruction{op: .end, lhs: value})
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
			if scope.children.any(it.kind.tag == .function_declaration) {
				return generator.unsupported('block-scoped function declarations')
			}
			generator.emit(Instruction{ op: .enter_scope })
			generator.scope_depth++
			generator.lexical_declarations(scope.children, false)!
			generator.initialize_functions(scope.children)
			for child in scope.children {
				generator.statement(mut vm, &child)!
			}
			generator.scope_depth--
			generator.emit(Instruction{ op: .leave_scope })
		}
		.variable_declaration {
			for declaration in kind.declarations {
				name := declaration_name(declaration) or {
					return generator.unsupported('destructuring declaration')
				}
				if declaration.init == none && kind.decl_kind == .var_kind { continue
				 }
				value := if init := declaration.init {
					generator.expression(mut vm, &init)!
				} else {
					generator.constant(js_undefined())
				}
				generator.emit(Instruction{
					op:         if kind.decl_kind == .var_kind {
						OpCode.set_variable
					} else {
						OpCode.initialize_binding
					}
					lhs:        value
					identifier: generator.identifier(name)
					strict:     generator.strict
				})
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
			if init := kind.for_init {
				if init is ForInitDeclaration {
					if init.statement.kind.decl_kind != .var_kind {
						for_scope = true
						generator.emit(Instruction{ op: .enter_scope })
						generator.scope_depth++
						generator.lexical_declarations([*init.statement], false)!
					}
					generator.statement(mut vm, init.statement)!
				} else if init is ForInitExpression {
					generator.expression(mut vm, init.expression)!
				}
			}
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
			if kind.target_label != none { return generator.unsupported('labelled loop control') }
			if generator.loops.len == 0 { return error('Loop control outside loop') }
			loop_index := generator.loops.len - 1
			for _ in generator.loops[loop_index].scope_depth .. generator.scope_depth {
				generator.emit(Instruction{ op: .leave_scope })
			}
			jump := generator.emit(Instruction{ op: .jump })
			if kind.tag == .break_stmt {
				generator.loops[loop_index].breaks << jump
			} else {
				generator.loops[loop_index].continues << jump
			}
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
