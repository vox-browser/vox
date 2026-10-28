module libjs

import math
import strconv

// ============================================================================
// AST dump — tree-drawing output matching C++ ASTDump.cpp format
// ============================================================================

// ANSI color codes matching C++ ASTDump.cpp.
const ansi_reset = '\x1b[0m'
const ansi_dim = '\x1b[2m'
const ansi_green = '\x1b[32m'
const ansi_yellow = '\x1b[33m'
const ansi_cyan = '\x1b[36m'
const ansi_magenta = '\x1b[35m'
const ansi_white_bold = '\x1b[1;37m'

@[heap]
struct OutputCollector {
mut:
	data string
}

struct DumpState {
	prefix         string
	is_last        bool
	is_root        bool
	use_color      bool
	output         ?&OutputCollector
	function_table &FunctionTable = unsafe { nil }
}

// ============================================================================
// Core tree-drawing functions
// ============================================================================

fn print_node(state DumpState, text string) {
	mut line := text
	if !state.is_root {
		connector := if state.is_last { '└─ ' } else { '├─ ' }
		if state.use_color {
			line = '${state.prefix}${ansi_dim}${connector}${ansi_reset}${text}'
		} else {
			line = '${state.prefix}${connector}${text}'
		}
	}
	if oc := state.output {
		unsafe {
			oc.data += line + '\n'
		}
	} else {
		println(line)
	}
}

fn child_prefix(state DumpState) string {
	if state.is_root {
		return ''
	}
	branch := if state.is_last { '   ' } else { '│  ' }
	if state.use_color {
		return '${state.prefix}${ansi_dim}${branch}${ansi_reset}'
	}
	return '${state.prefix}${branch}'
}

fn child_state(state DumpState, is_last bool) DumpState {
	return DumpState{
		prefix:         child_prefix(state)
		is_last:        is_last
		is_root:        false
		use_color:      state.use_color
		output:         state.output
		function_table: state.function_table
	}
}

// ============================================================================
// Formatting helpers
// ============================================================================

fn format_position(state DumpState, range SourceRange) string {
	if range.start.line == 0 {
		return ''
	}
	if state.use_color {
		return ' ${ansi_dim}@${range.start.line}:${range.start.column}${ansi_reset}'
	}
	return ' @${range.start.line}:${range.start.column}'
}

fn color_node_name(state DumpState, name string) string {
	if !state.use_color {
		return name
	}
	return '${ansi_white_bold}${name}${ansi_reset}'
}

fn color_string(state DumpState, value string) string {
	if !state.use_color {
		return '"${value}"'
	}
	return '${ansi_green}"${value}"${ansi_reset}'
}

fn color_string_utf16(state DumpState, value Utf16String) string {
	return color_string(state, value.str())
}

fn color_number_f64(state DumpState, value f64) string {
	s := format_f64_value(value)
	if !state.use_color {
		return s
	}
	return '${ansi_magenta}${s}${ansi_reset}'
}

fn color_number_bool(state DumpState, value bool) string {
	s := if value { 'true' } else { 'false' }
	if !state.use_color {
		return s
	}
	return '${ansi_magenta}${s}${ansi_reset}'
}

fn color_number_str(state DumpState, value string) string {
	if !state.use_color {
		return value
	}
	return '${ansi_magenta}${value}${ansi_reset}'
}

fn color_op(state DumpState, op string) string {
	if !state.use_color {
		return '(${op})'
	}
	return '(${ansi_yellow}${op}${ansi_reset})'
}

fn color_label(state DumpState, label string) string {
	if !state.use_color {
		return label
	}
	return '${ansi_dim}${label}${ansi_reset}'
}

fn color_local(state DumpState, kind string, index u32) string {
	if !state.use_color {
		return '[${kind}:${index}]'
	}
	return '${ansi_cyan}[${kind}:${index}]${ansi_reset}'
}

fn color_global(state DumpState) string {
	if !state.use_color {
		return '[global]'
	}
	return '${ansi_yellow}[global]${ansi_reset}'
}

fn color_flag(state DumpState, flag string) string {
	if !state.use_color {
		return '[${flag}]'
	}
	return '${ansi_dim}[${flag}]${ansi_reset}'
}

// ============================================================================
// Float formatting
// ============================================================================

fn format_f64_value(value f64) string {
	if math.is_nan(value) {
		return 'NaN'
	}
	if math.is_inf(value, 1) {
		return 'Infinity'
	}
	if math.is_inf(value, -1) {
		return '-Infinity'
	}
	if value == 0 {
		return '0'
	}
	// Use V's shortest round-tripping digits, then apply the ECMAScript
	// Number::toString decimal/exponent thresholds rather than V's thresholds.
	sign := if value < 0 { '-' } else { '' }
	scientific := strconv.ftoa_64(math.abs(value))
	digits := scientific.all_before('e').replace('.', '').trim_right('0')
	exponent := scientific.all_after('e').int()
	point := exponent + 1
	if point > 0 && point <= 21 {
		if point >= digits.len {
			return sign + digits + '0'.repeat(point - digits.len)
		}
		return sign + digits[..point] + '.' + digits[point..]
	}
	if point > -6 && point <= 0 {
		return sign + '0.' + '0'.repeat(-point) + digits
	}
	mantissa := if digits.len == 1 { digits } else { digits[..1] + '.' + digits[1..] }
	exponent_sign := if exponent >= 0 { '+' } else { '' }
	return '${sign}${mantissa}e${exponent_sign}${exponent}'
}

// ============================================================================
// Op-to-string functions
// ============================================================================

fn binary_op_to_string(op BinaryOp) string {
	return match op {
		.addition { '+' }
		.subtraction { '-' }
		.multiplication { '*' }
		.division { '/' }
		.modulo { '%' }
		.exponentiation { '**' }
		.strictly_equals { '===' }
		.strictly_inequals { '!==' }
		.loosely_equals { '==' }
		.loosely_inequals { '!=' }
		.greater_than { '>' }
		.greater_than_equals { '>=' }
		.less_than { '<' }
		.less_than_equals { '<=' }
		.bitwise_and { '&' }
		.bitwise_or { '|' }
		.bitwise_xor { '^' }
		.left_shift { '<<' }
		.right_shift { '>>' }
		.unsigned_right_shift { '>>>' }
		.in_op { 'in' }
		.instance_of { 'instanceof' }
	}
}

fn logical_op_to_string(op LogicalOp) string {
	return match op {
		.and_op { '&&' }
		.or_op { '||' }
		.nullish_coalescing { '??' }
	}
}

fn unary_op_to_string(op UnaryOp) string {
	return match op {
		.bitwise_not { '~' }
		.not_op { '!' }
		.plus { '+' }
		.minus { '-' }
		.typeof_op { 'typeof' }
		.void_op { 'void' }
		.delete_op { 'delete' }
	}
}

fn update_op_to_string(op UpdateOp) string {
	return match op {
		.increment { '++' }
		.decrement { '--' }
	}
}

fn assignment_op_to_string(op AssignmentOp) string {
	return match op {
		.assignment { '=' }
		.addition_assignment { '+=' }
		.subtraction_assignment { '-=' }
		.multiplication_assignment { '*=' }
		.division_assignment { '/=' }
		.modulo_assignment { '%=' }
		.exponentiation_assignment { '**=' }
		.bitwise_and_assignment { '&=' }
		.bitwise_or_assignment { '|=' }
		.bitwise_xor_assignment { '^=' }
		.left_shift_assignment { '<<=' }
		.right_shift_assignment { '>>=' }
		.unsigned_right_shift_assignment { '>>>=' }
		.and_assignment { '&&=' }
		.or_assignment { '||=' }
		.nullish_assignment { '?'.repeat(2) + '=' }
	}
}

fn declaration_kind_to_string(kind DeclarationKind) string {
	return match kind {
		.let_kind { 'let' }
		.var_kind { 'var' }
		.const_kind { 'const' }
	}
}

fn optional_mode_str(mode OptionalChainMode) string {
	return match mode {
		.optional { 'optional' }
		.not_optional { 'not optional' }
	}
}

fn class_method_kind_to_string(kind ClassMethodKind) string {
	return match kind {
		.method { 'method' }
		.getter { 'getter' }
		.setter { 'setter' }
	}
}

// ============================================================================
// Dump node helpers (replacing Rust dump_node! macro)
// ============================================================================

fn dump_node(state DumpState, name string, range SourceRange) {
	print_node(state, color_node_name(state, name) + format_position(state, range))
}

fn dump_node_with(state DumpState, name string, range SourceRange, extra string) {
	print_node(state, color_node_name(state, name) + ' ' + extra + format_position(state, range))
}

// ============================================================================
// Labeled dump helpers
// ============================================================================

fn dump_labeled_expression(label string, expression &Expression, is_last bool, state DumpState) {
	label_state := child_state(state, is_last)
	print_node(label_state, color_label(state, label))
	dump_expression(expression, child_state(label_state, true))
}

fn dump_labeled_statement(label string, statement &Statement, is_last bool, state DumpState) {
	label_state := child_state(state, is_last)
	print_node(label_state, color_label(state, label))
	dump_statement(statement, child_state(label_state, true))
}

// ============================================================================
// Entry points
// ============================================================================

fn dump_program_to_string(program &Statement, function_table &FunctionTable) string {
	mut oc := &OutputCollector{}
	state := DumpState{
		is_root:        true
		use_color:      false
		output:         oc
		function_table: unsafe { function_table }
	}
	dump_statement(program, state)
	return oc.data
}

// ============================================================================
// Statement dumper
// ============================================================================

fn dump_statement(statement &Statement, state DumpState) {
	match statement.kind.tag {
		.empty {
			dump_node(state, 'EmptyStatement', statement.range)
		}
		.debugger_stmt {
			dump_node(state, 'DebuggerStatement', statement.range)
		}
		.expression_stmt {
			dump_node(state, 'ExpressionStatement', statement.range)
			if expr := statement.kind.expression {
				dump_expression(expr, child_state(state, true))
			}
		}
		.block {
			if s := statement.kind.scope {
				// The parser wraps for-loops in a Block for scope. The C++
				// parser does not, so skip the wrapper and dump the child directly.
				if s.children.len == 1 {
					tag := s.children[0].kind.tag
					if tag == .for_stmt || tag == .for_in_of {
						dump_statement(&s.children[0], state)
						return
					}
				}
				dump_scope_node('BlockStatement', s, statement.range, state)
			}
		}
		.function_body {
			if s := statement.kind.scope {
				dump_scope_node('FunctionBody', s, statement.range, state)
			}
		}
		.program {
			if pd := statement.kind.program_data {
				mut desc := color_node_name(state, 'Program')
				type_str := if pd.program_type == .module { 'module' } else { 'script' }
				desc += ' ' + color_op(state, type_str)
				if pd.is_strict_mode {
					desc += ' ' + color_flag(state, 'strict')
				}
				if pd.has_top_level_await {
					desc += ' ' + color_flag(state, 'top-level-await')
				}
				desc += format_position(state, statement.range)
				print_node(state, desc)
				for i, child in pd.scope.children {
					dump_statement(&child, child_state(state, i == pd.scope.children.len - 1))
				}
			}
		}
		.if_stmt {
			dump_node(state, 'IfStatement', statement.range)
			has_alternate := statement.kind.alternate != none
			if test := statement.kind.test {
				dump_labeled_expression('test', test, false, state)
			}
			if consequent := statement.kind.consequent {
				dump_labeled_statement('consequent', consequent, !has_alternate, state)
			}
			if alt := statement.kind.alternate {
				dump_labeled_statement('alternate', alt, true, state)
			}
		}
		.while_stmt {
			dump_node(state, 'WhileStatement', statement.range)
			if test := statement.kind.test {
				dump_labeled_expression('test', test, false, state)
			}
			if body := statement.kind.body {
				dump_labeled_statement('body', body, true, state)
			}
		}
		.do_while {
			dump_node(state, 'DoWhileStatement', statement.range)
			if body := statement.kind.body {
				dump_labeled_statement('body', body, false, state)
			}
			if test := statement.kind.test {
				dump_labeled_expression('test', test, true, state)
			}
		}
		.for_stmt {
			dump_node(state, 'ForStatement', statement.range)
			if init := statement.kind.for_init {
				init_state := child_state(state, false)
				print_node(init_state, color_label(state, 'init'))
				match init {
					ForInitExpression {
						dump_expression(init.expression, child_state(init_state, true))
					}
					ForInitDeclaration {
						dump_statement(init.statement, child_state(init_state, true))
					}
				}
			}
			if test := statement.kind.test {
				dump_labeled_expression('test', test, false, state)
			}
			if update := statement.kind.update {
				dump_labeled_expression('update', update, false, state)
			}
			if body := statement.kind.body {
				dump_labeled_statement('body', body, true, state)
			}
		}
		.for_in_of {
			name := match statement.kind.for_in_of_kind {
				.for_in { 'ForInStatement' }
				.for_of { 'ForOfStatement' }
				.for_await_of { 'ForAwaitOfStatement' }
			}

			dump_node(state, name, statement.range)
			if lhs := statement.kind.for_in_of_lhs {
				lhs_state := child_state(state, false)
				print_node(lhs_state, color_label(state, 'lhs'))
				dump_for_in_of_lhs(lhs, child_state(lhs_state, true))
			}
			if rhs_expr := statement.kind.rhs {
				dump_labeled_expression('rhs', rhs_expr, false, state)
			}
			if body := statement.kind.body {
				dump_labeled_statement('body', body, true, state)
			}
		}
		.switch_stmt {
			dump_node(state, 'SwitchStatement', statement.range)
			if sd := statement.kind.switch_data {
				dump_labeled_expression('discriminant', &sd.discriminant, sd.cases.len == 0, state)
				for i, case_ in sd.cases {
					dump_switch_case(&case_, child_state(state, i == sd.cases.len - 1), state)
				}
			}
		}
		.with_stmt {
			dump_node(state, 'WithStatement', statement.range)
			if obj := statement.kind.object {
				dump_labeled_expression('object', obj, false, state)
			}
			if body := statement.kind.body {
				dump_labeled_statement('body', body, true, state)
			}
		}
		.labelled {
			dump_node_with(state, 'LabelledStatement', statement.range, color_string_utf16(state,
				statement.kind.label))
			if item := statement.kind.labelled_item {
				dump_statement(item, child_state(state, true))
			}
		}
		.break_stmt {
			dump_node(state, 'BreakStatement', statement.range)
		}
		.continue_stmt {
			dump_node(state, 'ContinueStatement', statement.range)
		}
		.return_stmt {
			dump_node(state, 'ReturnStatement', statement.range)
			if arg := statement.kind.return_arg {
				dump_expression(arg, child_state(state, true))
			}
		}
		.throw_stmt {
			dump_node(state, 'ThrowStatement', statement.range)
			if expr := statement.kind.throw_expr {
				dump_expression(expr, child_state(state, true))
			}
		}
		.try_stmt {
			dump_node(state, 'TryStatement', statement.range)
			if td := statement.kind.try_data {
				has_handler := td.handler != none
				has_finalizer := td.finalizer != none
				dump_labeled_statement('block', &td.block, !has_handler && !has_finalizer, state)
				if handler := td.handler {
					handler_state := child_state(state, !has_finalizer)
					print_node(handler_state, color_label(state, 'handler'))
					dump_catch_clause(&handler, child_state(handler_state, true), state)
				}
				if finalizer := td.finalizer {
					dump_labeled_statement('finalizer', &finalizer, true, state)
				}
			}
		}
		.variable_declaration {
			dump_node_with(state, 'VariableDeclaration', statement.range, color_op(state,
				declaration_kind_to_string(statement.kind.decl_kind)))
			for i, decl in statement.kind.declarations {
				dump_variable_declarator(&decl, child_state(state,
					i == statement.kind.declarations.len - 1), state)
			}
		}
		.using_declaration {
			dump_node(state, 'UsingDeclaration', statement.range)
			for i, decl in statement.kind.declarations {
				dump_variable_declarator(&decl, child_state(state,
					i == statement.kind.declarations.len - 1), state)
			}
		}
		.function_declaration {
			function_data := state.function_table.get(statement.kind.function_id)
			dump_function(function_data, 'FunctionDeclaration', statement.range, state)
		}
		.class_declaration {
			dump_node(state, 'ClassDeclaration', statement.range)
			if cd := statement.kind.class_data {
				dump_class(cd, statement.range, child_state(state, true), state)
			}
		}
		.import_stmt {
			if id := statement.kind.import_data {
				module_spec := id.module_request.module_specifier.str()
				assert_clauses := format_assert_clauses(&id.module_request)
				dump_node_with(state, 'ImportStatement', statement.range, 'from ' +
					color_string(state, module_spec) + assert_clauses)
				if id.entries.len > 0 {
					for i, entry in id.entries {
						import_name := if ie := entry.import_name {
							ie.str()
						} else {
							'None'
						}
						local_name := entry.local_name.str()
						print_node(child_state(state, i == id.entries.len - 1),
							'ImportName: ${import_name}, LocalName: ${local_name}')
					}
				}
			}
		}
		.export_stmt {
			dump_node(state, 'ExportStatement', statement.range)
			if ed := statement.kind.export_data {
				has_statement := ed.statement != none
				has_entries := ed.entries.len > 0
				if has_entries {
					print_node(child_state(state, !has_statement), color_label(state, 'entries'))
					entries_state := child_state(state, !has_statement)
					for i, entry in ed.entries {
						export_name := if en := entry.export_name {
							'"${en.str()}"'
						} else {
							'null'
						}
						// When the entry is a module re-export, C++ prints
						// "null" for LocalName regardless of the stored value.
						local_name := if ed.module_request != none {
							'null'
						} else {
							if ln := entry.local_or_import_name {
								'"${ln.str()}"'
							} else {
								'null'
							}
						}
						mut entry_desc := 'ExportName: ${export_name}, LocalName: ${local_name}'
						if mr := ed.module_request {
							entry_desc += ', ModuleRequest: ${mr.module_specifier.str()}${format_assert_clauses(&mr)}'
						}
						print_node(child_state(entries_state, i == ed.entries.len - 1), entry_desc)
					}
				}
				if export_stmt := ed.statement {
					print_node(child_state(state, true), color_label(state, 'statement'))
					inner_state := child_state(child_state(state, true), true)
					// For `export default <expression>`, the C++ AST stores the
					// expression directly without an ExpressionStatement wrapper.
					if export_stmt.kind.tag == .expression_stmt {
						if expr := export_stmt.kind.expression {
							dump_expression(expr, inner_state)
						}
					} else {
						dump_statement(export_stmt, inner_state)
					}
				}
			}
		}
		.class_field_initializer {
			// This should not be dumped as it is never part of an actual AST.
		}
		.error_stmt, .error_declaration {
			dump_node(state, 'ErrorStatement', statement.range)
		}
	}
}

// ============================================================================
// Expression dumper
// ============================================================================

fn dump_expression(expression &Expression, state DumpState) {
	match expression.kind.tag {
		.numeric_literal {
			dump_node_with(state, 'NumericLiteral', expression.range, color_number_f64(state,
				expression.kind.numeric_value))
		}
		.string_literal {
			dump_node_with(state, 'StringLiteral', expression.range, color_string_utf16(state,
				expression.kind.string_value))
		}
		.boolean_literal {
			dump_node_with(state, 'BooleanLiteral', expression.range, color_number_bool(state,
				expression.kind.bool_value))
		}
		.null_literal {
			dump_node(state, 'NullLiteral', expression.range)
		}
		.big_int_literal {
			dump_node_with(state, 'BigIntLiteral', expression.range, color_number_str(state,
				expression.kind.big_int_value))
		}
		.regexp_literal {
			if rd := expression.kind.regexp_data {
				pattern := rd.pattern.str()
				flags := rd.flags.str()
				dump_node_with(state, 'RegExpLiteral', expression.range, '/${pattern}/${flags}')
			}
		}
		.identifier_expr {
			if ident := expression.kind.identifier {
				dump_identifier(ident, expression.range, state)
			}
		}
		.private_identifier_expr {
			if pi := expression.kind.private_identifier {
				dump_node_with(state, 'PrivateIdentifier', expression.range, color_string_utf16(state,
					pi.name))
			}
		}
		.binary {
			dump_node_with(state, 'BinaryExpression', expression.range, color_op(state,
				binary_op_to_string(expression.kind.binary_op)))
			if lhs := expression.kind.lhs {
				dump_expression(lhs, child_state(state, false))
			}
			if rhs := expression.kind.rhs {
				dump_expression(rhs, child_state(state, true))
			}
		}
		.logical {
			dump_node_with(state, 'LogicalExpression', expression.range, color_op(state,
				logical_op_to_string(expression.kind.logical_op)))
			if lhs := expression.kind.lhs {
				dump_expression(lhs, child_state(state, false))
			}
			if rhs := expression.kind.rhs {
				dump_expression(rhs, child_state(state, true))
			}
		}
		.unary {
			dump_node_with(state, 'UnaryExpression', expression.range, color_op(state,
				unary_op_to_string(expression.kind.unary_op)))
			if operand := expression.kind.operand {
				dump_expression(operand, child_state(state, true))
			}
		}
		.update {
			prefix_str := if expression.kind.prefixed { 'prefix' } else { 'postfix' }
			dump_node_with(state, 'UpdateExpression', expression.range,
				'(${update_op_to_string(expression.kind.update_op)}, ${prefix_str})')
			if arg := expression.kind.argument {
				dump_expression(arg, child_state(state, true))
			}
		}
		.assignment {
			dump_node_with(state, 'AssignmentExpression', expression.range, color_op(state,
				assignment_op_to_string(expression.kind.assignment_op)))
			if assign_lhs := expression.kind.assignment_lhs {
				match assign_lhs {
					AssignmentLhsExpression {
						dump_expression(assign_lhs.expression, child_state(state, false))
					}
					AssignmentLhsPattern {
						dump_binding_pattern(&assign_lhs.pattern, child_state(state, false), state)
					}
				}
			}
			if rhs := expression.kind.rhs {
				dump_expression(rhs, child_state(state, true))
			}
		}
		.conditional {
			dump_node(state, 'ConditionalExpression', expression.range)
			if test := expression.kind.test {
				dump_labeled_expression('test', test, false, state)
			}
			if consequent := expression.kind.consequent {
				dump_labeled_expression('consequent', consequent, false, state)
			}
			if alt := expression.kind.alternate_expr {
				dump_labeled_expression('alternate', alt, true, state)
			}
		}
		.sequence {
			dump_node(state, 'SequenceExpression', expression.range)
			for i, child in expression.kind.expressions {
				dump_expression(&child,
					child_state(state, i == expression.kind.expressions.len - 1))
			}
		}
		.member {
			name := if expression.kind.computed {
				'MemberExpression [computed]'
			} else {
				'MemberExpression'
			}
			dump_node(state, name, expression.range)
			if obj := expression.kind.object {
				dump_expression(obj, child_state(state, false))
			}
			if prop := expression.kind.property {
				dump_expression(prop, child_state(state, true))
			}
		}
		.optional_chain {
			dump_node(state, 'OptionalChain', expression.range)
			if base := expression.kind.base {
				dump_expression(base, child_state(state, expression.kind.references.len == 0))
			}
			for i, ref_ in expression.kind.references {
				ref_state := child_state(state, i == expression.kind.references.len - 1)
				match ref_ {
					OptionalChainCall {
						print_node(ref_state, 'Call(${optional_mode_str(ref_.mode)})')
						for j, arg in ref_.arguments {
							dump_expression(&arg.value, child_state(ref_state,
								j == ref_.arguments.len - 1))
						}
					}
					OptionalChainComputedRef {
						print_node(ref_state, 'ComputedReference(${optional_mode_str(ref_.mode)})')
						dump_expression(&ref_.expression, child_state(ref_state, true))
					}
					OptionalChainMemberRef {
						print_node(ref_state, 'MemberReference(${optional_mode_str(ref_.mode)})')
						dump_identifier(ref_.identifier, ref_.identifier.range, child_state(ref_state,
							true))
					}
					OptionalChainPrivateMemberRef {
						print_node(ref_state,
							'PrivateMemberReference(${optional_mode_str(ref_.mode)})')
						print_node(child_state(ref_state, true), '${color_node_name(state,
							'PrivateIdentifier')} ${color_string_utf16(state,
							ref_.private_identifier.name)}${format_position(state,
							ref_.private_identifier.range)}')
					}
				}
			}
		}
		.call {
			dump_node(state, 'CallExpression', expression.range)
			if cd := expression.kind.call_data {
				dump_expression(&cd.callee, child_state(state, cd.arguments.len == 0))
				for i, arg in cd.arguments {
					dump_expression(&arg.value, child_state(state, i == cd.arguments.len - 1))
				}
			}
		}
		.new_expr {
			dump_node(state, 'NewExpression', expression.range)
			if cd := expression.kind.call_data {
				dump_expression(&cd.callee, child_state(state, cd.arguments.len == 0))
				for i, arg in cd.arguments {
					dump_expression(&arg.value, child_state(state, i == cd.arguments.len - 1))
				}
			}
		}
		.super_call {
			dump_node(state, 'SuperCall', expression.range)
			if sd := expression.kind.super_call_data {
				for i, arg in sd.arguments {
					dump_expression(&arg.value, child_state(state, i == sd.arguments.len - 1))
				}
			}
		}
		.spread {
			dump_node(state, 'SpreadExpression', expression.range)
			if operand := expression.kind.operand {
				dump_expression(operand, child_state(state, true))
			}
		}
		.this_expr {
			dump_node(state, 'ThisExpression', expression.range)
		}
		.super_expr {
			dump_node(state, 'SuperExpression', expression.range)
		}
		.function_expr {
			function_data := state.function_table.get(expression.kind.function_id)
			dump_function(function_data, 'FunctionExpression', expression.range, state)
		}
		.class_expr {
			if cd := expression.kind.class_data {
				dump_class(cd, expression.range, state, state)
			}
		}
		.array_expr {
			dump_node(state, 'ArrayExpression', expression.range)
			for i, elem in expression.kind.array_elements {
				cs := child_state(state, i == expression.kind.array_elements.len - 1)
				if e := elem {
					dump_expression(&e, cs)
				} else {
					print_node(cs, '<elision>')
				}
			}
		}
		.object_expr {
			dump_node(state, 'ObjectExpression', expression.range)
			for i, prop in expression.kind.object_properties {
				dump_object_property(&prop, child_state(state,
					i == expression.kind.object_properties.len - 1), state)
			}
		}
		.template_literal {
			dump_node(state, 'TemplateLiteral', expression.range)
			if td := expression.kind.template_data {
				for i, child in td.expressions {
					dump_expression(&child, child_state(state, i == td.expressions.len - 1))
				}
			}
		}
		.tagged_template_literal {
			dump_node(state, 'TaggedTemplateLiteral', expression.range)
			if tag_expr := expression.kind.tag_expr {
				dump_labeled_expression('tag', tag_expr, false, state)
			}
			if tl_expr := expression.kind.template_literal_expr {
				dump_labeled_expression('template', tl_expr, true, state)
			}
		}
		.meta_property {
			mp_name := match expression.kind.meta_property_type {
				.new_target { 'new.target' }
				.import_meta { 'import.meta' }
			}

			dump_node_with(state, 'MetaProperty', expression.range, mp_name)
		}
		.import_call {
			dump_node(state, 'ImportCall', expression.range)
			if spec := expression.kind.specifier {
				dump_expression(spec, child_state(state, expression.kind.options == none))
			}
			if opts := expression.kind.options {
				dump_labeled_expression('options', opts, true, state)
			}
		}
		.yield_expr {
			mut desc := color_node_name(state, 'YieldExpression')
			if expression.kind.is_yield_from {
				desc += ' ' + color_flag(state, 'yield*')
			}
			desc += format_position(state, expression.range)
			print_node(state, desc)
			if arg := expression.kind.argument {
				dump_expression(arg, child_state(state, true))
			}
		}
		.await_expr {
			dump_node(state, 'AwaitExpression', expression.range)
			if operand := expression.kind.operand {
				dump_expression(operand, child_state(state, true))
			}
		}
		.error {
			dump_node(state, 'ErrorExpression', expression.range)
		}
	}
}

// ============================================================================
// Identifier dumper
// ============================================================================

fn dump_identifier(ident &Identifier, range SourceRange, state DumpState) {
	mut desc := color_node_name(state, 'Identifier')
	desc += ' ' + color_string_utf16(state, ident.name)
	if ident.is_local() {
		kind_str := if ident.local_type == 1 { 'argument' } else { 'variable' }
		desc += ' ' + color_local(state, kind_str, ident.local_index)
	} else if ident.is_global {
		desc += ' ' + color_global(state)
	}
	if ident.declaration_kind != 0 {
		dk_str := match ident.declaration_kind {
			1 { 'var' }
			2 { 'let' }
			3 { 'const' }
			else { 'unknown' }
		}

		desc += ' ' + color_op(state, dk_str)
	}
	if ident.is_inside_scope_with_eval {
		desc += ' ' + color_flag(state, 'in-eval-scope')
	}
	desc += format_position(state, range)
	print_node(state, desc)
}

// ============================================================================
// Helper dumpers
// ============================================================================

fn dump_scope_node(class_name string, scope &ScopeData, range SourceRange, state DumpState) {
	dump_node(state, class_name, range)
	for i, child in scope.children {
		dump_statement(&child, child_state(state, i == scope.children.len - 1))
	}
}

fn dump_function(function_data &JsFunctionData, class_name string, range SourceRange, state DumpState) {
	mut desc := color_node_name(state, class_name)
	is_async := function_data.kind == .async_kind || function_data.kind == .async_generator
	is_generator := function_data.kind == .generator || function_data.kind == .async_generator
	if is_async {
		desc += ' async'
	}
	if is_generator {
		desc += '*'
	}
	name_str := if id := function_data.name {
		id.name.str()
	} else {
		''
	}
	desc += ' ' + color_string(state, name_str)
	if function_data.is_strict_mode {
		desc += ' ' + color_flag(state, 'strict')
	}
	if function_data.is_arrow_function {
		desc += ' ' + color_flag(state, 'arrow')
	}
	if function_data.parsing_insights.contains_direct_call_to_eval {
		desc += ' ' + color_flag(state, 'direct-eval')
	}
	if function_data.parsing_insights.uses_this {
		desc += ' ' + color_flag(state, 'uses-this')
	}
	if function_data.parsing_insights.uses_this_from_environment {
		desc += ' ' + color_flag(state, 'uses-this-from-environment')
	}
	if function_data.parsing_insights.might_need_arguments_object {
		desc += ' ' + color_flag(state, 'might-need-arguments')
	}
	desc += format_position(state, range)
	print_node(state, desc)
	if function_data.parameters.len > 0 {
		print_node(child_state(state, false), color_label(state, 'parameters'))
		parameters_state := child_state(state, false)
		for i, param in function_data.parameters {
			parameter_state := child_state(parameters_state, i == function_data.parameters.len - 1)
			has_default := param.default_value != none
			if param.is_rest {
				print_node(parameter_state, color_label(state, 'rest'))
				match param.binding {
					IdentifierBinding {
						dump_identifier(param.binding.identifier, param.binding.identifier.range, child_state(parameter_state,
							!has_default))
					}
					BindingPatternBinding {
						dump_binding_pattern(&param.binding.pattern, child_state(parameter_state,
							!has_default), state)
					}
				}
			} else {
				match param.binding {
					IdentifierBinding {
						dump_identifier(param.binding.identifier, param.binding.identifier.range, child_state(parameters_state,
							i == function_data.parameters.len - 1))
					}
					BindingPatternBinding {
						dump_binding_pattern(&param.binding.pattern, child_state(parameters_state,
							i == function_data.parameters.len - 1), state)
					}
				}
			}
			if dv := param.default_value {
				print_node(child_state(parameter_state, true), color_label(state, 'default'))
				dump_expression(&dv, child_state(child_state(parameter_state, true), true))
			}
		}
	}
	print_node(child_state(state, true), color_label(state, 'body'))
	dump_statement(&function_data.body, child_state(child_state(state, true), true))
}

fn dump_class(class_data &ClassData, range SourceRange, state DumpState, root_state DumpState) {
	name_str := if id := class_data.name {
		id.name.str()
	} else {
		''
	}
	print_node(state, '${color_node_name(root_state, 'ClassExpression')} ${color_string(root_state,
		name_str)}${format_position(root_state, range)}')
	has_elements := class_data.elements.len > 0
	if sc := class_data.super_class {
		print_node(child_state(state, false), color_label(root_state, 'super class'))
		dump_expression(&sc, child_state(child_state(state, false), true))
	}
	if constructor := class_data.constructor {
		print_node(child_state(state, !has_elements), color_label(root_state, 'constructor'))
		dump_expression(&constructor, child_state(child_state(state, !has_elements), true))
	}
	if has_elements {
		print_node(child_state(state, true), color_label(root_state, 'elements'))
		for i, element in class_data.elements {
			dump_class_element(&element, child_state(child_state(state, true),
				i == class_data.elements.len - 1), root_state)
		}
	}
}

fn dump_class_element(element &ClassElementNode, state DumpState, root_state DumpState) {
	match element.kind {
		ClassElementMethod {
			mut desc := color_node_name(root_state, 'ClassMethod')
			if element.kind.is_static {
				desc += ' static'
			}
			if element.kind.method_kind != .method {
				desc += ' ' +
					color_op(root_state, class_method_kind_to_string(element.kind.method_kind))
			}
			desc += format_position(root_state, element.range)
			print_node(state, desc)
			dump_expression(&element.kind.key, child_state(state, false))
			dump_expression(&element.kind.function, child_state(state, true))
		}
		ClassElementField {
			mut desc := color_node_name(root_state, 'ClassField')
			if element.kind.is_static {
				desc += ' static'
			}
			desc += format_position(root_state, element.range)
			print_node(state, desc)
			has_init := element.kind.initializer != none
			dump_expression(&element.kind.key, child_state(state, !has_init))
			if init_val := element.kind.initializer {
				print_node(child_state(state, true), color_label(root_state, 'initializer'))
				dump_expression(&init_val, child_state(child_state(state, true), true))
			}
		}
		ClassElementStaticInit {
			print_node(state, '${color_node_name(root_state, 'StaticInitializer')}${format_position(root_state,
				element.range)}')
			dump_statement(&element.kind.body, child_state(state, true))
		}
	}
}

fn dump_binding_pattern(pattern &BindingPattern, state DumpState, root_state DumpState) {
	kind_str := match pattern.kind {
		.array { 'array' }
		.object { 'object' }
	}

	print_node(state, '${color_node_name(root_state, 'BindingPattern')} ${color_op(root_state,
		kind_str)}')
	for i, entry in pattern.entries {
		entry_state := child_state(state, i == pattern.entries.len - 1)
		if pattern.kind == .array && is_elision(&entry) {
			print_node(entry_state, color_node_name(root_state, 'Elision'))
			continue
		}
		mut label := 'entry'
		if entry.is_rest {
			label += ' (rest)'
		}
		print_node(entry_state, color_label(root_state, label))
		has_alias := entry.alias.kind != .none_kind
		has_initializer := entry.has_initializer
		if pattern.kind == .object {
			if entry.name.kind == .identifier_kind {
				if id := entry.name.identifier {
					print_node(child_state(entry_state, !has_alias && !has_initializer), color_label(root_state,
						'name'))
					dump_identifier(id, id.range, child_state(child_state(entry_state, !has_alias
						&& !has_initializer), true))
				}
			} else if entry.name.kind == .expression_kind {
				if expr := entry.name.expression {
					print_node(child_state(entry_state, !has_alias && !has_initializer), color_label(root_state,
						'name (computed)'))
					dump_expression(&expr, child_state(child_state(entry_state, !has_alias
						&& !has_initializer), true))
				}
			}
		}
		if has_alias {
			if entry.alias.kind == .identifier_kind {
				if id := entry.alias.identifier {
					print_node(child_state(entry_state, !has_initializer), color_label(root_state,
						'alias'))
					dump_identifier(id, id.range, child_state(child_state(entry_state,
						!has_initializer), true))
				}
			} else if entry.alias.kind == .binding_pattern_kind {
				if bp := entry.alias.binding_pattern {
					print_node(child_state(entry_state, !has_initializer), color_label(root_state,
						'alias'))
					dump_binding_pattern(&bp, child_state(child_state(entry_state, !has_initializer),
						true), root_state)
				}
			} else if entry.alias.kind == .member_expression_kind {
				if expr := entry.alias.expression {
					print_node(child_state(entry_state, !has_initializer), color_label(root_state,
						'alias'))
					dump_expression(&expr, child_state(child_state(entry_state, !has_initializer),
						true))
				}
			}
		}
		if has_initializer {
			if init_val := entry.initializer {
				print_node(child_state(entry_state, true), color_label(root_state, 'initializer'))
				dump_expression(&init_val, child_state(child_state(entry_state, true), true))
			}
		}
	}
}

fn is_elision(entry &BindingEntry) bool {
	return entry.name.kind == .none_kind && entry.alias.kind == .none_kind && !entry.has_initializer
		&& !entry.is_rest
}

fn dump_variable_declarator(declaration &VariableDeclarator, state DumpState, root_state DumpState) {
	print_node(state, '${color_node_name(root_state, 'VariableDeclarator')}${format_position(root_state,
		declaration.range)}')
	has_init := declaration.init != none
	match declaration.target {
		IdentifierVarTarget {
			dump_identifier(declaration.target.identifier, declaration.target.identifier.range, child_state(state,
				!has_init))
		}
		BindingPatternVarTarget {
			dump_binding_pattern(&declaration.target.pattern, child_state(state, !has_init),
				root_state)
		}
	}

	if init_val := declaration.init {
		dump_expression(&init_val, child_state(state, true))
	}
}

fn dump_object_property(property &ObjectProperty, state DumpState, root_state DumpState) {
	if property.property_type == .spread {
		print_node(state, '${color_node_name(root_state, 'ObjectProperty')} ${color_op(root_state,
			'spread')}${format_position(root_state, property.range)}')
		dump_expression(&property.key, child_state(state, true))
	} else {
		mut desc := color_node_name(root_state, 'ObjectProperty')
		if property.is_method {
			desc += ' ' + color_op(root_state, 'method')
		} else if property.property_type == .getter {
			desc += ' ' + color_op(root_state, 'getter')
		} else if property.property_type == .setter {
			desc += ' ' + color_op(root_state, 'setter')
		}
		desc += format_position(root_state, property.range)
		print_node(state, desc)
		dump_expression(&property.key, child_state(state, false))
		if val := property.value {
			dump_expression(&val, child_state(state, true))
		}
	}
}

fn dump_catch_clause(clause &CatchClause, state DumpState, root_state DumpState) {
	print_node(state, '${color_node_name(root_state, 'CatchClause')}${format_position(root_state,
		clause.range)}')
	if param := clause.parameter {
		match param {
			CatchBindingIdentifier {
				print_node(child_state(state, false), color_label(root_state, 'parameter'))
				dump_identifier(param.identifier, param.identifier.range, child_state(child_state(state,
					false), true))
			}
			CatchBindingPattern {
				print_node(child_state(state, false), color_label(root_state, 'parameter'))
				dump_binding_pattern(&param.pattern, child_state(child_state(state, false), true),
					root_state)
			}
		}
	}
	dump_statement(&clause.body, child_state(state, true))
}

fn dump_switch_case(case_ &SwitchCase, state DumpState, root_state DumpState) {
	if test_expr := case_.test {
		print_node(state, '${color_node_name(root_state, 'SwitchCase')}${format_position(root_state,
			case_.range)}')
		print_node(child_state(state, false), color_label(root_state, 'test'))
		dump_expression(&test_expr, child_state(child_state(state, false), true))
	} else {
		print_node(state, '${color_node_name(root_state, 'SwitchCase')} ${color_op(root_state,
			'default')}${format_position(root_state, case_.range)}')
	}
	print_node(child_state(state, true), color_label(root_state, 'consequent'))
	consequent_state := child_state(child_state(state, true), true)
	children := case_.scope.children
	for i, child in children {
		dump_statement(&child, child_state(consequent_state, i == children.len - 1))
	}
}

fn dump_for_in_of_lhs(lhs ForInOfLhs, state DumpState) {
	match lhs {
		ForInOfLhsDeclaration {
			dump_statement(lhs.statement, state)
		}
		ForInOfLhsExpression {
			dump_expression(lhs.expression, state)
		}
		ForInOfLhsPattern {
			dump_binding_pattern(&lhs.pattern, state, state)
		}
	}
}

fn format_assert_clauses(request &ModuleRequest) string {
	if request.attributes.len == 0 {
		return ''
	}
	mut result := ' ['
	for i, attr in request.attributes {
		if i > 0 {
			result += ', '
		}
		result += '${attr.key.str()}: ${attr.value.str()}'
	}
	result += ']'
	return result
}
