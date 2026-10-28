module libjs

// AST types for JavaScript.
//
// Translated from ast.rs. Every node carries a SourceRange for error
// messages and source maps. ExpressionKind and StatementKind use a
// tagged-struct approach (tag enum + flat data fields).

// =============================================================================
// Source location
// =============================================================================

struct Position {
mut:
	line   u32
	column u32
	offset u32
}

struct SourceRange {
mut:
	start Position
	end_  Position
}

// =============================================================================
// UTF-16 string (defined in utf16_utils.v)
// =============================================================================
// Utf16String is defined in utf16_utils.v

// =============================================================================
// Node wrapper
// =============================================================================

@[heap]
struct Expression {
mut:
	range SourceRange
	kind  ExpressionKind
}

fn Expression.new(range SourceRange, kind ExpressionKind) Expression {
	return Expression{
		range: range
		kind:  kind
	}
}

@[heap]
struct Statement {
mut:
	range SourceRange
	kind  StatementKind
}

fn Statement.new(range SourceRange, kind StatementKind) Statement {
	return Statement{
		range: range
		kind:  kind
	}
}

// =============================================================================
// Operator enums — values are ABI-compatible for FFI
// =============================================================================

enum BinaryOp {
	addition             = 0
	subtraction          = 1
	multiplication       = 2
	division             = 3
	modulo               = 4
	exponentiation       = 5
	strictly_equals      = 6
	strictly_inequals    = 7
	loosely_equals       = 8
	loosely_inequals     = 9
	greater_than         = 10
	greater_than_equals  = 11
	less_than            = 12
	less_than_equals     = 13
	bitwise_and          = 14
	bitwise_or           = 15
	bitwise_xor          = 16
	left_shift           = 17
	right_shift          = 18
	unsigned_right_shift = 19
	in_op                = 20
	instance_of          = 21
}

enum LogicalOp {
	and_op             = 0
	or_op              = 1
	nullish_coalescing = 2
}

enum UnaryOp {
	bitwise_not = 0
	not_op      = 1
	plus        = 2
	minus       = 3
	typeof_op   = 4
	void_op     = 5
	delete_op   = 6
}

enum UpdateOp {
	increment = 0
	decrement = 1
}

enum AssignmentOp {
	assignment                      = 0
	addition_assignment             = 1
	subtraction_assignment          = 2
	multiplication_assignment       = 3
	division_assignment             = 4
	modulo_assignment               = 5
	exponentiation_assignment       = 6
	bitwise_and_assignment          = 7
	bitwise_or_assignment           = 8
	bitwise_xor_assignment          = 9
	left_shift_assignment           = 10
	right_shift_assignment          = 11
	unsigned_right_shift_assignment = 12
	and_assignment                  = 13
	or_assignment                   = 14
	nullish_assignment              = 15
}

// =============================================================================
// Kind enums
// =============================================================================

enum DeclarationKind {
	var_kind   = 1
	let_kind   = 2
	const_kind = 3
}

enum FunctionKind {
	normal          = 0
	generator       = 1
	async_kind      = 2
	async_generator = 3
}

fn FunctionKind.from_async_generator(is_async bool, is_generator bool) FunctionKind {
	if is_async && is_generator {
		return .async_generator
	}
	if is_async {
		return .async_kind
	}
	if is_generator {
		return .generator
	}
	return .normal
}

enum ProgramType {
	script = 0
	module = 1
}

enum MetaPropertyType {
	new_target
	import_meta
}

// =============================================================================
// Identifier
// =============================================================================

enum LocalType {
	argument
	variable
}

@[heap]
struct Identifier {
mut:
	range SourceRange
	name  Utf16String
	// Scope analysis results — set by scope collector after parsing.
	local_type                int // 0=none, 1=argument, 2=variable
	local_index               u32
	is_global                 bool
	is_inside_scope_with_eval bool
	declaration_kind          int // 0=none, 1=var, 2=let, 3=const
}

fn Identifier.new(range SourceRange, name Utf16String) &Identifier {
	return &Identifier{
		range: range
		name:  name
	}
}

fn (id &Identifier) is_local() bool {
	return id.local_type != 0
}

struct PrivateIdentifier {
mut:
	range SourceRange
	name  Utf16String
}

// =============================================================================
// Function support types
// =============================================================================

struct FunctionParsingInsights {
mut:
	uses_this                    bool
	uses_this_from_environment   bool
	contains_direct_call_to_eval bool
	might_need_arguments_object  bool
}

struct FunctionParameter {
mut:
	binding       FunctionParameterBinding
	default_value ?Expression
	is_rest       bool
}

type FunctionParameterBinding = IdentifierBinding | BindingPatternBinding

struct IdentifierBinding {
	identifier &Identifier = unsafe { nil }
}

struct BindingPatternBinding {
	pattern BindingPattern
}

struct FunctionId {
	id u32
}

@[heap]
struct JsFunctionData {
mut:
	name              ?&Identifier
	source_text_start u32
	source_text_end   u32
	body              Statement
	parameters        []FunctionParameter
	function_length   int
	kind              FunctionKind
	is_strict_mode    bool
	is_arrow_function bool
	parsing_insights  FunctionParsingInsights
}

// =============================================================================
// Function table (side table for JsFunctionData)
// =============================================================================

struct FunctionTable {
mut:
	entries []?&JsFunctionData
}

fn FunctionTable.new() FunctionTable {
	return FunctionTable{}
}

fn (mut ft FunctionTable) insert(data JsFunctionData) FunctionId {
	ft.entries << ?&JsFunctionData(&JsFunctionData{
		...data
	})
	return FunctionId{
		id: u32(ft.entries.len - 1)
	}
}

fn (ft &FunctionTable) get(id FunctionId) &JsFunctionData {
	if d := ft.entries[int(id.id)] {
		return d
	}
	panic('FunctionTable.get: slot already taken')
}

fn (mut ft FunctionTable) take(id FunctionId) JsFunctionData {
	idx := int(id.id)
	if idx >= ft.entries.len {
		panic('FunctionTable.take: index ${idx} out of bounds (table len ${ft.entries.len})')
	}
	if d := ft.entries[idx] {
		ft.entries[idx] = none
		return *d
	}
	panic('FunctionTable.take: slot already taken')
}

fn (mut ft FunctionTable) try_take(id FunctionId) ?JsFunctionData {
	idx := int(id.id)
	if idx >= ft.entries.len {
		return none
	}
	if d := ft.entries[idx] {
		ft.entries[idx] = none
		return *d
	}
	return none
}

fn (mut ft FunctionTable) insert_at(id FunctionId, data JsFunctionData) {
	idx := int(id.id)
	for ft.entries.len <= idx {
		ft.entries << ?&JsFunctionData(none)
	}
	ft.entries[idx] = &JsFunctionData{
		...data
	}
}

// extract_reachable extracts a subtable containing all FunctionIds reachable
// from the given function body and parameters.
fn (mut ft FunctionTable) extract_reachable(data &JsFunctionData) FunctionTable {
	mut subtable := FunctionTable.new()
	// Walk parameters first (default values can contain functions).
	for param in data.parameters {
		if default_val := param.default_value {
			ft.collect_from_expression(&default_val, mut subtable)
		}
		match param.binding {
			BindingPatternBinding {
				ft.collect_from_pattern(&param.binding.pattern, mut subtable)
			}
			else {}
		}
	}
	ft.collect_from_statement(&data.body, mut subtable)
	return subtable
}

fn (mut ft FunctionTable) transfer(id FunctionId, mut result FunctionTable) {
	if data := ft.try_take(id) {
		for param in data.parameters {
			if default_val := param.default_value {
				ft.collect_from_expression(&default_val, mut result)
			}
			match param.binding {
				BindingPatternBinding {
					ft.collect_from_pattern(&param.binding.pattern, mut result)
				}
				else {}
			}
		}
		ft.collect_from_statement(&data.body, mut result)
		result.insert_at(id, data)
	}
}

fn (mut ft FunctionTable) collect_from_statement(stmt &Statement, mut result FunctionTable) {
	match stmt.kind.tag {
		.function_declaration {
			ft.transfer(stmt.kind.function_id, mut result)
		}
		.expression_stmt {
			if expr := stmt.kind.expression {
				ft.collect_from_expression(expr, mut result)
			}
		}
		.block, .function_body {
			if scope := stmt.kind.scope {
				for child in scope.children {
					ft.collect_from_statement(&child, mut result)
				}
			}
		}
		.program {
			if pd := stmt.kind.program_data {
				for child in pd.scope.children {
					ft.collect_from_statement(&child, mut result)
				}
			}
		}
		.if_stmt {
			if test := stmt.kind.test {
				ft.collect_from_expression(test, mut result)
			}
			if consequent := stmt.kind.consequent {
				ft.collect_from_statement(consequent, mut result)
			}
			if alternate := stmt.kind.alternate {
				ft.collect_from_statement(alternate, mut result)
			}
		}
		.while_stmt {
			if test := stmt.kind.test {
				ft.collect_from_expression(test, mut result)
			}
			if body := stmt.kind.body {
				ft.collect_from_statement(body, mut result)
			}
		}
		.do_while {
			if body := stmt.kind.body {
				ft.collect_from_statement(body, mut result)
			}
			if test := stmt.kind.test {
				ft.collect_from_expression(test, mut result)
			}
		}
		.for_stmt {
			if init := stmt.kind.for_init {
				match init {
					ForInitExpression {
						ft.collect_from_expression(init.expression, mut result)
					}
					ForInitDeclaration {
						ft.collect_from_statement(init.statement, mut result)
					}
				}
			}
			if test := stmt.kind.test {
				ft.collect_from_expression(test, mut result)
			}
			if update := stmt.kind.update {
				ft.collect_from_expression(update, mut result)
			}
			if body := stmt.kind.body {
				ft.collect_from_statement(body, mut result)
			}
		}
		.for_in_of {
			if lhs := stmt.kind.for_in_of_lhs {
				match lhs {
					ForInOfLhsDeclaration {
						ft.collect_from_statement(lhs.statement, mut result)
					}
					ForInOfLhsExpression {
						ft.collect_from_expression(lhs.expression, mut result)
					}
					ForInOfLhsPattern {
						ft.collect_from_pattern(&lhs.pattern, mut result)
					}
				}
			}
			if rhs := stmt.kind.rhs {
				ft.collect_from_expression(rhs, mut result)
			}
			if body := stmt.kind.body {
				ft.collect_from_statement(body, mut result)
			}
		}
		.switch_stmt {
			if sd := stmt.kind.switch_data {
				ft.collect_from_expression(&sd.discriminant, mut result)
				for case_ in sd.cases {
					if test := case_.test {
						ft.collect_from_expression(&test, mut result)
					}
					for child in case_.scope.children {
						ft.collect_from_statement(&child, mut result)
					}
				}
			}
		}
		.with_stmt {
			if obj := stmt.kind.object {
				ft.collect_from_expression(obj, mut result)
			}
			if body := stmt.kind.body {
				ft.collect_from_statement(body, mut result)
			}
		}
		.labelled {
			if item := stmt.kind.labelled_item {
				ft.collect_from_statement(item, mut result)
			}
		}
		.return_stmt {
			if arg := stmt.kind.return_arg {
				ft.collect_from_expression(arg, mut result)
			}
		}
		.throw_stmt {
			if expr := stmt.kind.throw_expr {
				ft.collect_from_expression(expr, mut result)
			}
		}
		.try_stmt {
			if td := stmt.kind.try_data {
				ft.collect_from_statement(&td.block, mut result)
				if handler := td.handler {
					if param := handler.parameter {
						match param {
							CatchBindingPattern {
								ft.collect_from_pattern(&param.pattern, mut result)
							}
							else {}
						}
					}
					ft.collect_from_statement(&handler.body, mut result)
				}
				if finalizer := td.finalizer {
					ft.collect_from_statement(&finalizer, mut result)
				}
			}
		}
		.variable_declaration, .using_declaration {
			for decl in stmt.kind.declarations {
				ft.collect_from_target(&decl.target, mut result)
				if init := decl.init {
					ft.collect_from_expression(&init, mut result)
				}
			}
		}
		.class_declaration {
			if cd := stmt.kind.class_data {
				ft.collect_from_class(cd, mut result)
			}
		}
		.export_stmt {
			if ed := stmt.kind.export_data {
				if export_stmt := ed.statement {
					ft.collect_from_statement(export_stmt, mut result)
				}
			}
		}
		.class_field_initializer {
			if expr := stmt.kind.expression {
				ft.collect_from_expression(expr, mut result)
			}
		}
		.empty, .debugger_stmt, .break_stmt, .continue_stmt, .import_stmt, .error_stmt,
		.error_declaration {}
	}
}

fn (mut ft FunctionTable) collect_from_expression(expr &Expression, mut result FunctionTable) {
	match expr.kind.tag {
		.function_expr {
			ft.transfer(expr.kind.function_id, mut result)
		}
		.class_expr {
			if cd := expr.kind.class_data {
				ft.collect_from_class(cd, mut result)
			}
		}
		.binary, .logical {
			if lhs := expr.kind.lhs {
				ft.collect_from_expression(lhs, mut result)
			}
			if rhs := expr.kind.rhs {
				ft.collect_from_expression(rhs, mut result)
			}
		}
		.unary {
			if operand := expr.kind.operand {
				ft.collect_from_expression(operand, mut result)
			}
		}
		.update {
			if argument := expr.kind.argument {
				ft.collect_from_expression(argument, mut result)
			}
		}
		.assignment {
			if assign_lhs := expr.kind.assignment_lhs {
				match assign_lhs {
					AssignmentLhsExpression {
						ft.collect_from_expression(assign_lhs.expression, mut result)
					}
					AssignmentLhsPattern {
						ft.collect_from_pattern(&assign_lhs.pattern, mut result)
					}
				}
			}
			if rhs := expr.kind.rhs {
				ft.collect_from_expression(rhs, mut result)
			}
		}
		.conditional {
			if test := expr.kind.test {
				ft.collect_from_expression(test, mut result)
			}
			if consequent := expr.kind.consequent {
				ft.collect_from_expression(consequent, mut result)
			}
			if alternate := expr.kind.alternate_expr {
				ft.collect_from_expression(alternate, mut result)
			}
		}
		.sequence {
			for e in expr.kind.expressions {
				ft.collect_from_expression(&e, mut result)
			}
		}
		.member {
			if obj := expr.kind.object {
				ft.collect_from_expression(obj, mut result)
			}
			if prop := expr.kind.property {
				ft.collect_from_expression(prop, mut result)
			}
		}
		.optional_chain {
			if base := expr.kind.base {
				ft.collect_from_expression(base, mut result)
			}
			for ref_ in expr.kind.references {
				match ref_ {
					OptionalChainCall {
						for arg in ref_.arguments {
							ft.collect_from_expression(&arg.value, mut result)
						}
					}
					OptionalChainComputedRef {
						ft.collect_from_expression(&ref_.expression, mut result)
					}
					OptionalChainMemberRef, OptionalChainPrivateMemberRef {}
				}
			}
		}
		.call, .new_expr {
			if cd := expr.kind.call_data {
				ft.collect_from_expression(&cd.callee, mut result)
				for arg in cd.arguments {
					ft.collect_from_expression(&arg.value, mut result)
				}
			}
		}
		.super_call {
			if sd := expr.kind.super_call_data {
				for arg in sd.arguments {
					ft.collect_from_expression(&arg.value, mut result)
				}
			}
		}
		.spread, .await_expr {
			if operand := expr.kind.operand {
				ft.collect_from_expression(operand, mut result)
			}
		}
		.array_expr {
			for elem in expr.kind.array_elements {
				if e := elem {
					ft.collect_from_expression(&e, mut result)
				}
			}
		}
		.object_expr {
			for prop in expr.kind.object_properties {
				ft.collect_from_expression(&prop.key, mut result)
				if val := prop.value {
					ft.collect_from_expression(&val, mut result)
				}
			}
		}
		.template_literal {
			if td := expr.kind.template_data {
				for e in td.expressions {
					ft.collect_from_expression(&e, mut result)
				}
			}
		}
		.tagged_template_literal {
			if tag := expr.kind.tag_expr {
				ft.collect_from_expression(tag, mut result)
			}
			if tl := expr.kind.template_literal_expr {
				ft.collect_from_expression(tl, mut result)
			}
		}
		.yield_expr {
			if arg := expr.kind.argument {
				ft.collect_from_expression(arg, mut result)
			}
		}
		.import_call {
			if spec := expr.kind.specifier {
				ft.collect_from_expression(spec, mut result)
			}
			if opts := expr.kind.options {
				ft.collect_from_expression(opts, mut result)
			}
		}
		.numeric_literal, .string_literal, .boolean_literal, .null_literal, .big_int_literal,
		.regexp_literal, .identifier_expr, .private_identifier_expr, .this_expr, .super_expr,
		.meta_property, .error {}
	}
}

fn (mut ft FunctionTable) collect_from_class(class_data &ClassData, mut result FunctionTable) {
	if super_class := class_data.super_class {
		ft.collect_from_expression(&super_class, mut result)
	}
	if constructor := class_data.constructor {
		ft.collect_from_expression(&constructor, mut result)
	}
	for element in class_data.elements {
		match element.kind {
			ClassElementMethod {
				ft.collect_from_expression(&element.kind.key, mut result)
				ft.collect_from_expression(&element.kind.function, mut result)
			}
			ClassElementField {
				ft.collect_from_expression(&element.kind.key, mut result)
				if init := element.kind.initializer {
					ft.collect_from_expression(&init, mut result)
				}
			}
			ClassElementStaticInit {
				ft.collect_from_statement(&element.kind.body, mut result)
			}
		}
	}
}

fn (mut ft FunctionTable) collect_from_pattern(pattern &BindingPattern, mut result FunctionTable) {
	for entry in pattern.entries {
		if entry.has_name_expression {
			if name_expr := entry.name.expression {
				ft.collect_from_expression(&name_expr, mut result)
			}
		}
		if entry.alias.kind == .identifier_kind {
			// nothing to collect
		} else if entry.alias.kind == .binding_pattern_kind {
			if bp := entry.alias.binding_pattern {
				ft.collect_from_pattern(&bp, mut result)
			}
		} else if entry.alias.kind == .member_expression_kind {
			if expr := entry.alias.expression {
				ft.collect_from_expression(&expr, mut result)
			}
		}
		if init := entry.initializer {
			ft.collect_from_expression(&init, mut result)
		}
	}
}

fn (mut ft FunctionTable) collect_from_target(target &VariableDeclaratorTarget, mut result FunctionTable) {
	match target {
		BindingPatternVarTarget {
			ft.collect_from_pattern(&target.pattern, mut result)
		}
		else {}
	}
}

// FunctionPayload bundles a JsFunctionData with a subtable of all nested
// functions reachable from its body.
struct FunctionPayload {
mut:
	data           JsFunctionData
	function_table FunctionTable
}

// =============================================================================
// Class support types
// =============================================================================

struct ClassData {
mut:
	name              ?&Identifier
	source_text_start u32
	source_text_end   u32
	constructor       ?Expression
	super_class       ?Expression
	elements          []ClassElementNode
}

struct ClassElementNode {
mut:
	range SourceRange
	kind  ClassElementKind
}

type ClassElementKind = ClassElementMethod | ClassElementField | ClassElementStaticInit

struct ClassElementMethod {
mut:
	key         Expression
	function    Expression
	method_kind ClassMethodKind
	is_static   bool
}

struct ClassElementField {
mut:
	key         Expression
	initializer ?Expression
	is_static   bool
}

struct ClassElementStaticInit {
mut:
	body Statement
}

enum ClassMethodKind {
	method = 0
	getter = 1
	setter = 2
}

// =============================================================================
// Binding pattern types
// =============================================================================

struct BindingPattern {
mut:
	kind    BindingPatternKind
	entries []BindingEntry
}

fn (bp &BindingPattern) contains_expression() bool {
	for entry in bp.entries {
		if entry.has_name_expression {
			return true
		}
		if entry.has_initializer {
			return true
		}
		if entry.alias.kind == .binding_pattern_kind {
			if nested := entry.alias.binding_pattern {
				if nested.contains_expression() {
					return true
				}
			}
		}
	}
	return false
}

enum BindingPatternKind {
	array
	object
}

struct BindingEntry {
mut:
	name                BindingEntryName
	alias               BindingEntryAlias
	initializer         ?Expression
	has_initializer     bool
	has_name_expression bool
	is_rest             bool
}

enum BindingEntryNameKind {
	none_kind
	identifier_kind
	expression_kind
}

struct BindingEntryName {
mut:
	kind       BindingEntryNameKind
	identifier ?&Identifier
	expression ?Expression
}

enum BindingEntryAliasKind {
	none_kind
	identifier_kind
	binding_pattern_kind
	member_expression_kind
}

struct BindingEntryAlias {
mut:
	kind            BindingEntryAliasKind
	identifier      ?&Identifier
	binding_pattern ?BindingPattern
	expression      ?Expression
}

// =============================================================================
// Variable declaration types
// =============================================================================

struct VariableDeclarator {
mut:
	range  SourceRange
	target VariableDeclaratorTarget
	init   ?Expression
}

type VariableDeclaratorTarget = IdentifierVarTarget | BindingPatternVarTarget

struct IdentifierVarTarget {
	identifier &Identifier = unsafe { nil }
}

struct BindingPatternVarTarget {
	pattern BindingPattern
}

// =============================================================================
// Object literal types
// =============================================================================

struct ObjectProperty {
mut:
	range         SourceRange
	property_type ObjectPropertyType
	key           Expression
	value         ?Expression
	is_method     bool
	is_computed   bool
}

enum ObjectPropertyType {
	key_value    = 0
	getter       = 1
	setter       = 2
	spread       = 3
	proto_setter = 4
}

// =============================================================================
// Call expression types
// =============================================================================

struct CallArgument {
mut:
	value     Expression
	is_spread bool
}

struct CallExpressionData {
mut:
	callee           Expression
	arguments        []CallArgument
	is_parenthesized bool
	is_inside_parens bool
}

struct SuperCallData {
mut:
	arguments    []CallArgument
	is_synthetic bool
}

// =============================================================================
// Optional chain types
// =============================================================================

enum OptionalChainMode {
	optional
	not_optional
}

type OptionalChainReference = OptionalChainCall
	| OptionalChainComputedRef
	| OptionalChainMemberRef
	| OptionalChainPrivateMemberRef

struct OptionalChainCall {
mut:
	arguments []CallArgument
	mode      OptionalChainMode
}

struct OptionalChainComputedRef {
mut:
	expression Expression
	mode       OptionalChainMode
}

struct OptionalChainMemberRef {
mut:
	identifier &Identifier = unsafe { nil }
	mode       OptionalChainMode
}

struct OptionalChainPrivateMemberRef {
mut:
	private_identifier PrivateIdentifier
	mode               OptionalChainMode
}

// =============================================================================
// Template literal types
// =============================================================================

struct TemplateLiteralData {
mut:
	expressions []Expression
	raw_strings []Utf16String
}

// =============================================================================
// RegExp literal
// =============================================================================

struct RegExpLiteralData {
mut:
	pattern Utf16String
	flags   Utf16String
	// compiled_regex omitted: FFI handle not needed in V translation
}

// =============================================================================
// Try/Catch types
// =============================================================================

struct TryStatementData {
mut:
	block     Statement
	handler   ?CatchClause
	finalizer ?Statement
}

struct CatchClause {
mut:
	range     SourceRange
	parameter ?CatchBinding
	body      Statement
}

type CatchBinding = CatchBindingIdentifier | CatchBindingPattern

struct CatchBindingIdentifier {
	identifier &Identifier = unsafe { nil }
}

struct CatchBindingPattern {
	pattern BindingPattern
}

// =============================================================================
// Switch types
// =============================================================================

struct SwitchStatementData {
mut:
	scope        &ScopeData = unsafe { nil }
	discriminant Expression
	cases        []SwitchCase
}

struct SwitchCase {
mut:
	range SourceRange
	scope &ScopeData = unsafe { nil }
	test  ?Expression
}

// =============================================================================
// Module types (import/export)
// =============================================================================

struct ModuleRequest {
mut:
	module_specifier Utf16String
	attributes       []ImportAttribute
}

struct ImportAttribute {
mut:
	key   Utf16String
	value Utf16String
}

struct ImportEntry {
mut:
	import_name ?Utf16String
	local_name  Utf16String
}

struct ImportStatementData {
mut:
	module_request ModuleRequest
	entries        []ImportEntry
}

enum ExportEntryKind {
	named_export                   = 0
	module_request_all             = 1
	module_request_all_but_default = 2
	empty_named_export             = 3
}

struct ExportEntry {
mut:
	kind                 ExportEntryKind
	export_name          ?Utf16String
	local_or_import_name ?Utf16String
}

struct ExportStatementData {
mut:
	statement         ?&Statement
	entries           []ExportEntry
	is_default_export bool
	module_request    ?ModuleRequest
}

// =============================================================================
// For-in/of types
// =============================================================================

enum ForInOfKind {
	for_in
	for_of
	for_await_of
}

type ForInit = ForInitDeclaration | ForInitExpression

struct ForInitDeclaration {
	statement &Statement = unsafe { nil }
}

struct ForInitExpression {
	expression &Expression = unsafe { nil }
}

type ForInOfLhs = ForInOfLhsDeclaration | ForInOfLhsExpression | ForInOfLhsPattern

struct ForInOfLhsDeclaration {
	statement &Statement = unsafe { nil }
}

struct ForInOfLhsExpression {
	expression &Expression = unsafe { nil }
}

struct ForInOfLhsPattern {
mut:
	pattern BindingPattern
}

// =============================================================================
// Assignment LHS
// =============================================================================

type AssignmentLhs = AssignmentLhsExpression | AssignmentLhsPattern

struct AssignmentLhsExpression {
	expression &Expression = unsafe { nil }
}

struct AssignmentLhsPattern {
mut:
	pattern BindingPattern
}

// =============================================================================
// Scope data
// =============================================================================

enum LocalVarKind {
	var_kind               = 0
	let_or_const           = 1
	function_kind          = 2
	arguments_object       = 3
	catch_clause_parameter = 4
}

struct LocalVariable {
mut:
	name Utf16String
	kind LocalVarKind
}

@[heap]
struct ScopeData {
mut:
	children                            []Statement
	local_variables                     []LocalVariable
	function_scope_data                 ?FunctionScopeData
	hoisted_functions                   []int
	annexb_function_names               []Utf16String
	uses_this                           bool
	uses_this_from_environment          bool
	contains_direct_call_to_eval        bool
	contains_access_to_arguments_object bool
}

fn ScopeData.new_shared() &ScopeData {
	return &ScopeData{}
}

fn ScopeData.shared_with_children(children []Statement) &ScopeData {
	return &ScopeData{
		children: children
	}
}

struct FunctionScopeData {
mut:
	functions_to_initialize                       []FunctionToInit
	vars_to_initialize                            []VarToInit
	var_names                                     []Utf16String
	has_function_named_arguments                  bool
	has_argument_parameter                        bool
	has_lexically_declared_arguments              bool
	non_local_var_count                           int
	non_local_var_count_for_parameter_expressions int
}

struct FunctionToInit {
	child_index int
}

struct LocalBinding {
mut:
	local_type LocalType
	index      u32
}

struct VarToInit {
mut:
	name             Utf16String
	is_parameter     bool
	is_function_name bool
	local            ?LocalBinding
}

// =============================================================================
// ExpressionKind — tagged struct approach
// =============================================================================

enum ExprKindTag {
	error
	numeric_literal
	string_literal
	boolean_literal
	null_literal
	big_int_literal
	regexp_literal
	identifier_expr
	private_identifier_expr
	binary
	logical
	unary
	update
	assignment
	conditional
	sequence
	member
	optional_chain
	call
	new_expr
	super_call
	spread
	this_expr
	super_expr
	function_expr
	class_expr
	array_expr
	object_expr
	template_literal
	tagged_template_literal
	meta_property
	import_call
	yield_expr
	await_expr
}

struct ExpressionKind {
mut:
	tag ExprKindTag
	// Literal data
	numeric_value f64
	string_value  Utf16String
	bool_value    bool
	big_int_value string
	regexp_data   ?RegExpLiteralData
	// Identifier data
	identifier         ?&Identifier
	private_identifier ?PrivateIdentifier
	// Operator data
	binary_op     BinaryOp
	logical_op    LogicalOp
	unary_op      UnaryOp
	update_op     UpdateOp
	assignment_op AssignmentOp
	// Sub-expression pointers
	lhs                   ?&Expression
	rhs                   ?&Expression
	operand               ?&Expression
	argument              ?&Expression
	test                  ?&Expression
	consequent            ?&Expression
	alternate_expr        ?&Expression
	object                ?&Expression
	property              ?&Expression
	base                  ?&Expression
	specifier             ?&Expression
	options               ?&Expression
	tag_expr              ?&Expression
	template_literal_expr ?&Expression
	// Flags
	prefixed      bool
	computed      bool
	is_yield_from bool
	// Assignment lhs
	assignment_lhs       ?AssignmentLhs
	lhs_is_parenthesized bool
	// Call data (heap-allocated to break struct cycles)
	call_data       ?&CallExpressionData
	super_call_data ?&SuperCallData
	// Function
	function_id FunctionId
	// Class (heap-allocated to break struct cycles)
	class_data ?&ClassData
	// Collections
	expressions       []Expression
	array_elements    []?Expression
	object_properties []ObjectProperty
	// Optional chain
	references []OptionalChainReference
	// Template
	template_data ?TemplateLiteralData
	// Meta property
	meta_property_type MetaPropertyType
}

fn ExpressionKind.error() ExpressionKind {
	return ExpressionKind{
		tag: .error
	}
}

fn ExpressionKind.identifier_kind(id &Identifier) ExpressionKind {
	return ExpressionKind{
		tag:        .identifier_expr
		identifier: id
	}
}

fn (ek &ExpressionKind) is_identifier() bool {
	return ek.tag == .identifier_expr
}

fn (ek &ExpressionKind) is_member() bool {
	return ek.tag == .member
}

fn (ek &ExpressionKind) is_call() bool {
	return ek.tag == .call
}

fn (ek &ExpressionKind) is_object() bool {
	return ek.tag == .object_expr
}

fn (ek &ExpressionKind) is_array() bool {
	return ek.tag == .array_expr
}

fn (ek &ExpressionKind) is_update() bool {
	return ek.tag == .update
}

// =============================================================================
// StatementKind — tagged struct approach
// =============================================================================

enum StmtKindTag {
	empty
	error_stmt
	error_declaration
	expression_stmt
	debugger_stmt
	block
	function_body
	program
	if_stmt
	while_stmt
	do_while
	for_stmt
	for_in_of
	switch_stmt
	with_stmt
	labelled
	break_stmt
	continue_stmt
	return_stmt
	throw_stmt
	try_stmt
	variable_declaration
	using_declaration
	function_declaration
	class_declaration
	import_stmt
	export_stmt
	class_field_initializer
}

struct StatementKind {
mut:
	tag StmtKindTag
	// Program data
	program_data ?ProgramData
	// Scope data for blocks/function body
	scope          ?&ScopeData
	in_strict_mode bool
	// Expression statement / class field initializer
	expression ?&Expression
	// Control flow: if/while/do-while/for
	test       ?&Expression
	consequent ?&Statement
	alternate  ?&Statement
	body       ?&Statement
	// For loop
	for_init ?ForInit
	update   ?&Expression
	// For-in/of
	for_in_of_kind ForInOfKind
	for_in_of_lhs  ?ForInOfLhs
	rhs            ?&Expression
	// Switch (heap-allocated to break struct cycles)
	switch_data ?&SwitchStatementData
	// With
	object ?&Expression
	// Labelled
	label         Utf16String
	labelled_item ?&Statement
	// Break/Continue
	target_label ?Utf16String
	// Return
	return_arg ?&Expression
	// Throw
	throw_expr ?&Expression
	// Try (heap-allocated to break struct cycles)
	try_data ?&TryStatementData
	// Variable declaration
	decl_kind    DeclarationKind
	declarations []VariableDeclarator
	// Function declaration
	function_id FunctionId
	func_name   ?&Identifier
	func_kind   FunctionKind
	is_hoisted  bool
	// Class declaration (heap-allocated to break struct cycles)
	class_data ?&ClassData
	// Import/Export
	import_data ?ImportStatementData
	export_data ?ExportStatementData
	// Class field initializer
	field_name Utf16String
}

fn StatementKind.empty() StatementKind {
	return StatementKind{
		tag: .empty
	}
}

// Labelled items contribute their function declaration to the surrounding
// declaration lists without removing the label from the executable tree.
fn (statement &Statement) function_declaration_for_labelled_item() ?&Statement {
	mut item := unsafe { statement }
	for item.kind.tag == .labelled {
		item = item.kind.labelled_item or { return none }
	}
	if item.kind.tag == .function_declaration {
		return item
	}
	return none
}

fn StatementKind.program(data ProgramData) StatementKind {
	return StatementKind{
		tag:          .program
		program_data: data
	}
}

// =============================================================================
// Program data
// =============================================================================

struct ProgramData {
mut:
	scope               &ScopeData = unsafe { nil }
	program_type        ProgramType
	is_strict_mode      bool
	has_top_level_await bool
}
