module libjs

// JavaScript parser: recursive descent with precedence climbing.
//
// This is the core parser module. It contains the Parser struct (parser
// state + helpers) and delegates actual parsing to submodules.

// Named precedence levels for parse_expression().
const precedence_comma = 0
const precedence_assignment = 2
const precedence_unary = 17
const precedence_member = 19
// V's by-value AST temporaries use more native stack than the Rust arena.
// The upstream guard needs a lower limit here to fire before stack exhaustion.
const max_parser_recursion_depth = u32(32)
const max_parser_recursion_stack_bytes = uint(4 * 1024 * 1024)

// Result of parsing a function's formal parameter list.
struct ParsedParameters {
mut:
	parameters      []FunctionParameter
	function_length int
	parameter_info  []ParamInfo
	is_simple       bool
}

// Information about a single parameter name binding.
struct ParamInfo {
mut:
	name            Utf16String
	is_rest         bool
	is_from_pattern bool
	identifier      ?&Identifier
}

// Result of parsing a property key (object literal or class element).
struct PropertyKey {
mut:
	expression    Expression
	name          ?Utf16String
	is_proto      bool
	is_computed   bool
	is_identifier bool
}

// Method kind for parse_method_definition.
enum MethodKind {
	normal
	getter
	setter
	constructor
}

// Associativity for operator precedence.
enum Associativity {
	left
	right
}

// Tracks which tokens are forbidden in the current expression context.
struct ForbiddenTokens {
mut:
	forbid_in                   bool
	forbid_logical              bool
	forbid_coalesce             bool
	forbid_paren_open           bool
	forbid_question_mark_period bool
	forbid_equals               bool
}

fn ForbiddenTokens.none() ForbiddenTokens {
	return ForbiddenTokens{}
}

fn ForbiddenTokens.with_in() ForbiddenTokens {
	return ForbiddenTokens{
		forbid_in: true
	}
}

fn (f &ForbiddenTokens) allows(token TokenType) bool {
	return match token {
		.in_kw { !f.forbid_in }
		.double_ampersand, .double_pipe { !f.forbid_logical }
		.double_question_mark { !f.forbid_coalesce }
		.paren_open { !f.forbid_paren_open }
		.question_mark_period { !f.forbid_question_mark_period }
		.equals { !f.forbid_equals }
		else { true }
	}
}

fn (f &ForbiddenTokens) merge(other ForbiddenTokens) ForbiddenTokens {
	return ForbiddenTokens{
		forbid_in:                   f.forbid_in || other.forbid_in
		forbid_logical:              f.forbid_logical || other.forbid_logical
		forbid_coalesce:             f.forbid_coalesce || other.forbid_coalesce
		forbid_paren_open:           f.forbid_paren_open || other.forbid_paren_open
		forbid_question_mark_period: f.forbid_question_mark_period
			|| other.forbid_question_mark_period
		forbid_equals:               f.forbid_equals || other.forbid_equals
	}
}

fn (f &ForbiddenTokens) forbid(tokens []TokenType) ForbiddenTokens {
	mut result := ForbiddenTokens{
		forbid_in:                   f.forbid_in
		forbid_logical:              f.forbid_logical
		forbid_coalesce:             f.forbid_coalesce
		forbid_paren_open:           f.forbid_paren_open
		forbid_question_mark_period: f.forbid_question_mark_period
		forbid_equals:               f.forbid_equals
	}
	for t in tokens {
		match t {
			.in_kw { result.forbid_in = true }
			.double_ampersand, .double_pipe { result.forbid_logical = true }
			.double_question_mark { result.forbid_coalesce = true }
			.paren_open { result.forbid_paren_open = true }
			.question_mark_period { result.forbid_question_mark_period = true }
			.equals { result.forbid_equals = true }
			else {}
		}
	}
	return result
}

struct ParserError {
mut:
	message string
	line    u32
	column  u32
}

// Boolean flags that are saved/restored during speculative parsing.
struct ParserFlags {
mut:
	strict_mode                                  bool
	allow_super_property_lookup                  bool
	allow_super_constructor_call                 bool
	in_function_context                          bool
	in_formal_parameter_context                  bool
	in_generator_function_context                bool
	await_expression_is_valid                    bool
	in_break_context                             bool
	in_continue_context                          bool
	string_legacy_octal_escape_sequence_in_scope bool
	in_class_field_initializer                   bool
	in_class_static_init_block                   bool
	new_target_is_valid                          bool
	function_might_need_arguments_object         bool
	previous_token_was_period                    bool
}

// Snapshot of parser state for speculative parsing (backtracking).
struct SavedState {
mut:
	token                 Token
	errors_len            int
	flags                 ParserFlags
	scope_collector_state ScopeCollectorState
}

// Bound name entry from binding pattern parsing.
struct BoundName {
mut:
	name       Utf16String
	identifier &Identifier
}

// Label value for labels_in_scope map.
struct LabelValue {
mut:
	has_continue bool
	line         u32
	col          u32
}

// The main JavaScript parser.
struct Parser {
mut:
	lexer         Lexer
	current_token Token
	errors        []ParserError
	saved_states  []SavedState
	program_type  ProgramType
	source        []u16
	// Parser state flags (saved/restored during speculative parsing)
	flags ParserFlags
	// Flags NOT saved/restored during speculative parsing
	initiated_by_eval              bool
	in_eval_function_context       bool
	labels_in_scope                map[string]LabelValue
	last_inner_label_is_iteration  bool
	last_primary_was_parenthesized bool
	last_function_name             Utf16String
	last_function_kind             FunctionKind
	last_class_name                Utf16String
	pattern_bound_names            []BoundName
	allow_member_expressions       bool
	binding_pattern_start          ?Position
	class_has_super_class          bool
	class_scope_depth              u32
	recursion_depth                u32
	recursion_stack_base           uint
	recursion_limit                u32 = max_parser_recursion_depth
	stack_info                     StackInfo
	recursion_limit_reached        bool
	has_default_export_name        bool
	referenced_private_names_stack []map[string]bool
	for_loop_declaration_count     int
	for_loop_declaration_has_init  bool
	for_loop_declaration_is_var    bool
	scope_collector                ScopeCollector
	exported_names                 map[string]bool
	function_table                 FunctionTable
}

fn Parser.new(source []u16, program_type ProgramType) Parser {
	return Parser.new_with_line_offset(source, program_type, 1)
}

fn Parser.new_with_line_offset(source []u16, program_type ProgramType, initial_line_number u32) Parser {
	mut lexer := Lexer.new(source, initial_line_number, 0)
	if program_type == .module {
		lexer.disallow_html_comments()
	}
	first_token := lexer.next()
	return Parser{
		lexer:           lexer
		current_token:   first_token
		program_type:    program_type
		source:          source
		scope_collector: ScopeCollector.new()
		function_table:  FunctionTable.new()
		stack_info:      StackInfo.new()
	}
}

// === AST construction helpers ===

fn (p &Parser) range_from(start Position) SourceRange {
	return SourceRange{
		start: start
		end_:  p.position()
	}
}

fn (p &Parser) expression(start Position, expr ExpressionKind) Expression {
	return Expression.new(p.range_from(start), expr)
}

fn (p &Parser) statement(start Position, stmt StatementKind) Statement {
	return Statement.new(p.range_from(start), stmt)
}

fn (p &Parser) make_identifier(start Position, name Utf16String) &Identifier {
	return Identifier.new(p.range_from(start), name)
}

fn (mut p Parser) register_function_parameters_with_scope(parameters []FunctionParameter, parameter_info []ParamInfo) {
	mut entries := []ParameterEntry{}
	mut has_parameter_expressions := false
	mut info_index := 0
	for parameter in parameters {
		if parameter.default_value != none {
			has_parameter_expressions = true
		}
		match parameter.binding {
			IdentifierBinding {
				mut name := Utf16String.new()
				mut is_rest := false
				mut is_from_pattern := false
				if info_index < parameter_info.len {
					pi := parameter_info[info_index]
					info_index++
					name = pi.name.clone()
					is_rest = pi.is_rest
					is_from_pattern = pi.is_from_pattern
				} else {
					name = parameter.binding.identifier.name.clone()
					is_rest = parameter.is_rest
				}
				entries << ParameterEntry{
					name:                  name
					identifier:            parameter.binding.identifier
					is_rest:               is_rest
					is_from_pattern:       is_from_pattern
					is_first_from_pattern: false
				}
			}
			BindingPatternBinding {
				if parameter.binding.pattern.contains_expression() {
					has_parameter_expressions = true
				}
				entries << ParameterEntry{
					name:                  Utf16String.new()
					is_from_pattern:       true
					is_first_from_pattern: true
				}
				for info_index < parameter_info.len && parameter_info[info_index].is_from_pattern {
					pi := parameter_info[info_index]
					entries << ParameterEntry{
						name:                  pi.name.clone()
						identifier:            pi.identifier
						is_rest:               pi.is_rest
						is_from_pattern:       true
						is_first_from_pattern: false
					}
					info_index++
				}
			}
		}
	}
	p.scope_collector.set_function_parameters(entries, has_parameter_expressions)
}

// === Token access ===

fn (p &Parser) current_token_ref() &Token {
	return &p.current_token
}

fn (p &Parser) current_token_type() TokenType {
	return p.current_token.token_type
}

fn (p &Parser) match_token(tt TokenType) bool {
	return p.current_token.token_type == tt
}

fn (p &Parser) done() bool {
	return p.recursion_limit_reached || p.match_token(.eof)
}

// === Token consumption ===

fn (mut p Parser) consume() Token {
	old := p.current_token
	p.current_token = p.lexer.next()
	p.check_arguments_or_eval(old)
	p.flags.previous_token_was_period = old.token_type == .period
	return old
}

// A literal property name is not an identifier reference. Suppress only
// that token's check; computed-key expressions use ordinary consumption.
fn (mut p Parser) consume_property_key_token() Token {
	old := p.current_token
	p.current_token = p.lexer.next()
	p.flags.previous_token_was_period = old.token_type == .period
	return old
}

fn (mut p Parser) consume_and_check_identifier() Token {
	token := p.consume()
	if p.flags.strict_mode && token.token_type == .identifier {
		value := p.token_value(token)
		if is_strict_reserved_word(value) {
			name := string_from_utf16_lossy(value)
			p.syntax_error("Identifier must not be a reserved word in strict mode ('${name}')")
		}
	}
	return token
}

fn (mut p Parser) consume_token(expected TokenType) Token {
	if p.current_token.token_type != expected {
		p.expected(expected.name())
	}
	return p.consume()
}

fn (mut p Parser) eat(tt TokenType) bool {
	if p.match_token(tt) {
		p.consume()
		return true
	}
	return false
}

fn (mut p Parser) check_arguments_or_eval(token Token) {
	if token.token_type == .identifier && !p.flags.previous_token_was_period {
		value := if id_val := token.identifier_value {
			id_val.data
		} else {
			start := int(token.value_start)
			end := start + int(token.value_len)
			if end <= p.source.len {
				p.source[start..end]
			} else {
				[]u16{}
			}
		}
		if utf16_equals(value, utf16('arguments')) {
			if p.flags.in_class_field_initializer {
				p.syntax_error("'arguments' is not allowed in class field initializer")
			}
			p.flags.function_might_need_arguments_object = true
		} else if utf16_equals(value, utf16('eval')) {
			p.flags.function_might_need_arguments_object = true
		}
	}
}

fn (mut p Parser) consume_identifier() Token {
	if p.match_identifier() {
		return p.consume_and_check_identifier()
	}
	p.expected('identifier')
	return p.consume()
}

fn (mut p Parser) consume_and_validate_numeric_literal() Token {
	token := p.consume()
	if p.flags.strict_mode {
		value := p.token_value(token)
		if value.len > 1 && value[0] == ch(`0`) && value[1] >= ch(`0`) && value[1] <= ch(`9`) {
			p.syntax_error('Unprefixed octal number not allowed in strict mode')
		}
	}
	if p.match_identifier_name() && p.current_token.trivia_len == 0 {
		p.syntax_error('Numeric literal must not be immediately followed by identifier')
	}
	return token
}

fn (mut p Parser) consume_or_insert_semicolon() {
	if p.match_token(.semicolon) {
		p.consume()
		return
	}
	if p.current_token.trivia_has_line_terminator || p.match_token(.curly_close) || p.done() {
		return
	}
	p.expected('Semicolon')
}

// === Lookahead ===

fn (mut p Parser) next_token() Token {
	p.lexer.save_state()
	token := p.lexer.next()
	p.lexer.load_state()
	return token
}

// === Position ===

fn (p &Parser) position() Position {
	return Position{
		line:   p.current_token.line_number
		column: p.current_token.line_column
		offset: p.current_token.offset
	}
}

fn (p &Parser) source_text_end_offset() u32 {
	return p.current_token.offset - p.current_token.trivia_len
}

// === Error reporting ===

fn (mut p Parser) enter_recursion() bool {
	stack_address := C.vox_ak_current_frame_address()
	if p.recursion_depth == 0 { p.recursion_stack_base = stack_address }
	stack_used := if p.recursion_stack_base >= stack_address {
		p.recursion_stack_base - stack_address
	} else {
		stack_address - p.recursion_stack_base
	}
	p.recursion_depth++
	if p.recursion_depth > p.recursion_limit || p.stack_info.size_free() < 512 * 1024
		|| stack_used > max_parser_recursion_stack_bytes {
		p.recursion_depth--
		p.recursion_limit_reached = true
		p.syntax_error('Maximum parser recursion depth exceeded')
		return false
	}
	return true
}

fn (mut p Parser) leave_recursion() {
	p.recursion_depth--
}

fn (mut p Parser) syntax_error(message string) {
	p.errors << ParserError{
		message: message
		line:    p.current_token.line_number
		column:  p.current_token.line_column
	}
}

fn (mut p Parser) syntax_error_at(message string, line u32, column u32) {
	p.errors << ParserError{
		message: message
		line:    line
		column:  column
	}
}

fn (mut p Parser) syntax_error_at_position(message string, pos Position) {
	p.syntax_error_at(message, pos.line, pos.column)
}

fn (mut p Parser) register_referenced_private_name(name []u16) bool {
	if p.referenced_private_names_stack.len > 0 {
		key := string_from_utf16_lossy(name)
		p.referenced_private_names_stack[p.referenced_private_names_stack.len - 1][key] = true
		return true
	}
	return false
}

fn (mut p Parser) parse_private_identifier(range_start Position) PrivateIdentifier {
	value := p.token_value(p.current_token)
	if !p.register_referenced_private_name(value) {
		name := string_from_utf16_lossy(value)
		p.syntax_error("Reference to undeclared private field or method '${name}'")
	}
	token := p.consume()
	value2 := p.token_value(token)
	return PrivateIdentifier{
		range: p.range_from(range_start)
		name:  Utf16String.from_slice(value2)
	}
}

fn (mut p Parser) expected(what string) {
	msg := if m := p.current_token.message {
		m
	} else {
		'Unexpected token ${p.current_token.token_type.name()}. Expected ${what}'
	}
	p.syntax_error(msg)
}

fn (mut p Parser) compile_regex_pattern(pattern []u16, flags []u16) voidptr {
	// Stub: regex compilation would call into C++ FFI
	_ = pattern
	_ = flags
	return unsafe { nil }
}

fn (mut p Parser) validate_regex_flags(flags []u16) {
	valid_flags := [ch(`d`), ch(`g`), ch(`i`), ch(`m`), ch(`s`),
		ch(`u`), ch(`v`), ch(`y`)]
	mut seen := [128]bool{}
	for flag in flags {
		if flag >= 128 || flag !in valid_flags {
			c := if flag < 128 { u8(flag).ascii_str() } else { '?' }
			p.syntax_error("Invalid RegExp flag '${c}'")
			return
		}
		if seen[int(flag)] {
			c := if flag < 128 { u8(flag).ascii_str() } else { '?' }
			p.syntax_error("Repeated RegExp flag '${c}'")
			return
		}
		seen[int(flag)] = true
	}
}

fn (p &Parser) has_errors() bool {
	return p.errors.len > 0
}

fn (p &Parser) errors_ref() []ParserError {
	return p.errors
}

fn (p &Parser) error_messages() []string {
	mut messages := []string{cap: p.errors.len}
	for e in p.errors {
		messages << '${e.line}:${e.column}: ${e.message}'
	}
	return messages
}

// === State save/restore for backtracking ===

fn (mut p Parser) save_state() {
	p.lexer.save_state()
	p.saved_states << SavedState{
		token:                 p.current_token
		errors_len:            p.errors.len
		flags:                 p.flags
		scope_collector_state: p.scope_collector.save_state()
	}
}

fn (mut p Parser) load_state() {
	if p.saved_states.len == 0 {
		panic('No saved state to restore')
	}
	state := p.saved_states.pop()
	p.current_token = state.token
	p.errors = p.errors[..state.errors_len]
	p.flags = state.flags
	p.scope_collector.load_state(state.scope_collector_state)
	p.lexer.load_state()
}

fn (mut p Parser) discard_saved_state() {
	p.saved_states.pop()
	p.lexer.discard_saved_state()
}

// === Token matching helpers ===

fn (p &Parser) match_identifier() bool {
	return p.token_is_identifier(p.current_token)
}

fn (p &Parser) token_is_identifier(token Token) bool {
	tt := token.token_type
	return tt == .identifier
		|| (tt == .escaped_keyword && !p.match_invalid_escaped_keyword())
		|| (tt == .let_kw && !p.flags.strict_mode)
		|| (tt == .yield_kw && !p.flags.strict_mode && !p.flags.in_generator_function_context)
		|| (tt == .await_kw && !p.flags.await_expression_is_valid && p.program_type != .module
		&& !p.flags.in_class_static_init_block) || tt == .async
}

fn (p &Parser) match_identifier_name() bool {
	return p.current_token.token_type.is_identifier_name() || p.match_identifier()
}

fn (p &Parser) match_invalid_escaped_keyword() bool {
	if p.current_token.token_type != .escaped_keyword {
		return false
	}
	value := p.token_value(p.current_token)
	if utf16_equals(value, utf16('await')) {
		return p.program_type == .module || p.flags.await_expression_is_valid
			|| p.flags.in_class_static_init_block
	}
	if utf16_equals(value, utf16('async')) {
		return false
	}
	if utf16_equals(value, utf16('yield')) {
		return p.flags.in_generator_function_context
	}
	if p.flags.strict_mode {
		return true
	}
	return !utf16_equals(value, utf16('let')) && !utf16_equals(value, utf16('static'))
}

fn (mut p Parser) check_identifier_name_for_assignment_validity(name []u16, force_strict bool) {
	if p.flags.strict_mode || force_strict {
		if utf16_equals(name, utf16('arguments')) || utf16_equals(name, utf16('eval')) {
			p.syntax_error("Binding pattern target may not be called 'arguments' or 'eval' in strict mode")
		} else if is_strict_reserved_word(name) {
			name_str := string_from_utf16_lossy(name)
			p.syntax_error("Identifier must not be a reserved word in strict mode ('${name_str}')")
		}
	}
}

fn (mut p Parser) check_arrow_duplicate_parameters(parameter_info []ParamInfo) {
	mut seen_names := map[string]bool{}
	for pi in parameter_info {
		name := pi.name
		if name.is_empty() {
			continue
		}
		key := name.str()
		if key in seen_names {
			name_str := string_from_utf16_lossy(name.data)
			p.syntax_error("Duplicate parameter '${name_str}' not allowed in arrow function")
		}
		seen_names[key] = true
	}
}

fn (mut p Parser) check_unique_formal_parameters(parameter_info []ParamInfo) {
	mut seen_names := map[string]bool{}
	for pi in parameter_info {
		if pi.name.is_empty() {
			continue
		}
		key := pi.name.str()
		if key in seen_names {
			p.syntax_error("Duplicate parameter '${key}' not allowed")
		}
		seen_names[key] = true
	}
}

fn (mut p Parser) check_parameters_post_body(parameter_info []ParamInfo, force_strict bool, kind FunctionKind) {
	_ = kind
	mut seen_names := map[string]bool{}
	for pi in parameter_info {
		name := pi.name
		if name.is_empty() {
			continue
		}
		p.check_identifier_name_for_assignment_validity(name.data, force_strict)
		key := name.str()
		if key in seen_names {
			name_str := string_from_utf16_lossy(name.data)
			p.syntax_error("Duplicate parameter '${name_str}' not allowed in strict mode")
		}
		seen_names[key] = true
	}
}

fn (p &Parser) token_value(token Token) []u16 {
	if id_val := token.identifier_value {
		return id_val.data
	}
	start := int(token.value_start)
	end := start + int(token.value_len)
	assert end <= p.source.len, 'token_value: bounds [${start}..${end}) exceed source length ${p.source.len}'
	return p.source[start..end]
}

fn (p &Parser) token_original_value(token Token) []u16 {
	start := int(token.value_start)
	end := int(token.value_start + token.value_len)
	assert end <= p.source.len, 'token_original_value: bounds [${start}..${end}) exceed source length ${p.source.len}'
	return p.source[start..end]
}

fn (mut p Parser) synthesize_binding_pattern(start Position) ?BindingPattern {
	// Clear any syntax errors that occurred in the range of the expression
	end_line := p.current_token.line_number
	end_column := p.current_token.line_column
	p.errors = p.errors.filter(fn [start, end_line, end_column] (e ParserError) bool {
		in_range := (e.line > start.line || (e.line == start.line && e.column >= start.column))
			&& !(e.line > end_line || (e.line == end_line && e.column >= end_column))
		return !in_range
	})

	saved_lexer := p.lexer
	saved_token := p.current_token
	saved_allow := p.allow_member_expressions

	p.lexer = Lexer.new_at_offset(p.source, int(start.offset), start.line, start.column)
	p.current_token = p.lexer.next()
	p.allow_member_expressions = true

	pattern := p.parse_binding_pattern()

	p.lexer = saved_lexer
	p.current_token = saved_token
	p.allow_member_expressions = saved_allow

	return pattern
}

fn is_simple_assignment_target(expression Expression, allow_call_expression bool) bool {
	return expression.kind.is_identifier() || expression.kind.is_member()
		|| (allow_call_expression && expression.kind.is_call())
}

fn is_object_expression(expression Expression) bool {
	return expression.kind.is_object()
}

fn is_array_expression(expression Expression) bool {
	return expression.kind.is_array()
}

fn is_parenthesized_object_or_array_expression(expression Expression, start Position) bool {
	return (is_object_expression(expression) || is_array_expression(expression))
		&& expression.range.start.offset != start.offset
}

fn is_identifier_expression(expression Expression) bool {
	return expression.kind.is_identifier()
}

fn is_member_expression(expression Expression) bool {
	return expression.kind.is_member()
}

fn is_call_expression(expression Expression) bool {
	return expression.kind.is_call()
}

fn is_update_expression(expression Expression) bool {
	return expression.kind.is_update()
}

// === Main entry point ===

fn (mut p Parser) parse_program(starts_in_strict_mode bool) Statement {
	start := p.position()

	if p.program_type == .script {
		children, is_strict := p.parse_script(starts_in_strict_mode)
		scope := ScopeData.shared_with_children(children)
		p.scope_collector.set_scope_node(scope)
		p.scope_collector.close_scope()
		return p.statement(start, StatementKind.program(ProgramData{
			scope:               scope
			program_type:        .script
			is_strict_mode:      is_strict
			has_top_level_await: false
		}))
	} else {
		children, has_top_level_await := p.parse_module()
		scope := ScopeData.shared_with_children(children)
		p.scope_collector.set_scope_node(scope)
		p.scope_collector.close_scope()
		return p.statement(start, StatementKind.program(ProgramData{
			scope:               scope
			program_type:        .module
			is_strict_mode:      true
			has_top_level_await: has_top_level_await
		}))
	}
}

fn (mut p Parser) parse_script(starts_in_strict_mode bool) ([]Statement, bool) {
	p.scope_collector.open_program_scope(.script)

	strict_before := p.flags.strict_mode
	if starts_in_strict_mode {
		p.flags.strict_mode = true
	}

	has_use_strict, mut children := p.parse_directive()

	if p.flags.strict_mode || has_use_strict {
		p.flags.strict_mode = true
	}

	children << p.parse_statement_list(true)
	if !p.done() {
		if p.flags.in_function_context {
			p.expected('CurlyClose')
		} else {
			p.expected('statement or declaration')
		}
		p.consume()
	}

	is_strict := p.flags.strict_mode
	p.flags.strict_mode = strict_before
	return children, is_strict
}

fn (mut p Parser) parse_module() ([]Statement, bool) {
	p.scope_collector.open_program_scope(.module)

	strict_before := p.flags.strict_mode
	await_before := p.flags.await_expression_is_valid
	p.flags.strict_mode = true
	p.flags.await_expression_is_valid = true

	mut children := []Statement{}

	for !p.done() {
		children << p.parse_statement_list(true)

		if p.done() {
			break
		}

		if p.match_export_or_import() {
			if p.match_token(.export_kw) {
				children << p.parse_export_statement()
			} else {
				children << p.parse_import_statement()
			}
		} else {
			p.expected('statement or declaration')
			p.consume()
		}
	}

	p.check_undeclared_exports(children)

	p.flags.strict_mode = strict_before
	p.flags.await_expression_is_valid = await_before
	has_top_level_await := p.scope_collector.contains_await_expression()
	return children, has_top_level_await
}

fn (mut p Parser) check_undeclared_exports(children []Statement) {
	mut declared_names := map[string]bool{}
	for child in children {
		match child.kind.tag {
			.variable_declaration {
				for decl in child.kind.declarations {
					collect_binding_names_from_target(decl.target, mut declared_names)
				}
			}
			.function_declaration {
				if name_id := child.kind.func_name {
					declared_names[name_id.name.str()] = true
				}
			}
			.class_declaration {
				if cd := child.kind.class_data {
					if name_id := cd.name {
						declared_names[name_id.name.str()] = true
					}
				}
			}
			.import_stmt {
				if id := child.kind.import_data {
					for entry in id.entries {
						declared_names[entry.local_name.str()] = true
					}
				}
			}
			.export_stmt {
				if ed := child.kind.export_data {
					if stmt := ed.statement {
						match stmt.kind.tag {
							.variable_declaration {
								for decl in stmt.kind.declarations {
									collect_binding_names_from_target(decl.target, mut
										declared_names)
								}
							}
							.function_declaration {
								if name_id := stmt.kind.func_name {
									declared_names[name_id.name.str()] = true
								}
							}
							.class_declaration {
								if cd := stmt.kind.class_data {
									if name_id := cd.name {
										declared_names[name_id.name.str()] = true
									}
								}
							}
							else {}
						}
					}
				}
			}
			else {}
		}
	}

	// Check each export's local bindings
	for child in children {
		if child.kind.tag == .export_stmt {
			if ed := child.kind.export_data {
				if ed.statement != none {
					continue
				}
				for entry in ed.entries {
					if ed.module_request != none {
						continue
					}
					if entry.kind == .empty_named_export {
						continue
					}
					if local_name := entry.local_or_import_name {
						key := local_name.str()
						if key !in declared_names {
							p.syntax_error_at_position("'${key}' in export is not declared",
								child.range.start)
						}
					}
				}
			}
		}
	}
}

fn (mut p Parser) parse_directive() (bool, []Statement) {
	p.flags.string_legacy_octal_escape_sequence_in_scope = false
	mut found_use_strict := false
	mut statements := []Statement{}
	for !p.done() && p.match_token(.string_literal) {
		raw_value := p.token_original_value(p.current_token)
		statement := p.parse_statement(false)
		statements << statement

		if is_use_strict(raw_value) {
			found_use_strict = true
			if p.flags.string_legacy_octal_escape_sequence_in_scope {
				p.syntax_error('Octal escape sequence in string literal not allowed in strict mode')
			}
			break
		}
	}
	p.flags.string_legacy_octal_escape_sequence_in_scope = false
	return found_use_strict, statements
}

fn (mut p Parser) parse_statement_list(allow_labelled_functions bool) []Statement {
	mut statements := []Statement{}
	for !p.done() {
		if p.match_export_or_import() {
			break
		}
		if p.match_declaration() {
			statements << p.parse_declaration()
		} else if p.match_statement() {
			statements << p.parse_statement(allow_labelled_functions)
		} else {
			break
		}
	}
	return statements
}

fn (mut p Parser) match_statement() bool {
	tt := p.current_token_type()
	return tt == .curly_open || tt == .return_kw || tt == .var_kw || tt == .for_kw || tt == .if_kw
		|| tt == .throw_kw || tt == .try_kw || tt == .break_kw || tt == .continue_kw
		|| tt == .switch_kw || tt == .do_kw || tt == .while_kw || tt == .with_kw || tt == .debugger
		|| tt == .semicolon || tt == .slash || tt == .slash_equals || p.match_expression()
}

fn (mut p Parser) match_declaration() bool {
	return match p.current_token_type() {
		.function_kw, .class_kw, .const_kw {
			true
		}
		.let_kw {
			if !p.flags.strict_mode {
				p.try_match_let_declaration()
			} else {
				true
			}
		}
		.async {
			next := p.next_token()
			next.token_type == .function_kw && !next.trivia_has_line_terminator
		}
		.identifier {
			value := p.token_value(p.current_token)
			if !utf16_equals(value, utf16('using')) {
				false
			} else {
				next := p.next_token()
				next.trivia_has_line_terminator == false && next.token_type.is_identifier_name()
			}
		}
		else {
			false
		}
	}
}

fn (mut p Parser) try_match_let_declaration() bool {
	next := p.next_token()
	if next.token_type.is_identifier_name() && !utf16_equals(p.token_value(next), utf16('in')) {
		return true
	}
	if next.token_type == .curly_open || next.token_type == .bracket_open {
		return true
	}
	return false
}

fn (p &Parser) match_iteration_start() bool {
	tt := p.current_token_type()
	return tt == .for_kw || tt == .while_kw || tt == .do_kw
}

fn (mut p Parser) match_export_or_import() bool {
	if p.match_token(.export_kw) {
		return true
	}
	if p.match_token(.import_kw) {
		next := p.next_token()
		return next.token_type != .paren_open && next.token_type != .period
	}
	return false
}

// === Operator precedence ===

fn operator_precedence(tt TokenType) int {
	return match tt {
		.period, .bracket_open, .paren_open, .question_mark_period {
			20
		}
		.new_kw {
			19
		}
		.plus_plus, .minus_minus {
			18
		}
		.exclamation_mark, .tilde, .typeof_kw, .void_kw, .delete_kw, .await_kw {
			17
		}
		.double_asterisk {
			16
		}
		.asterisk, .slash, .percent {
			15
		}
		.plus, .minus {
			14
		}
		.shift_left, .shift_right, .unsigned_shift_right {
			13
		}
		.less_than, .less_than_equals, .greater_than, .greater_than_equals, .in_kw, .instanceof_kw {
			12
		}
		.equals_equals, .exclamation_mark_equals, .equals_equals_equals,
		.exclamation_mark_equals_equals {
			11
		}
		.ampersand {
			10
		}
		.caret {
			9
		}
		.pipe {
			8
		}
		.double_question_mark {
			7
		}
		.double_ampersand {
			6
		}
		.double_pipe {
			5
		}
		.question_mark {
			4
		}
		.equals, .plus_equals, .minus_equals, .double_asterisk_equals, .asterisk_equals,
		.slash_equals, .percent_equals, .shift_left_equals, .shift_right_equals,
		.unsigned_shift_right_equals, .ampersand_equals, .caret_equals, .pipe_equals,
		.double_ampersand_equals, .double_pipe_equals, .double_question_mark_equals {
			3
		}
		.yield_kw {
			2
		}
		.comma {
			1
		}
		else {
			0
		}
	}
}

fn operator_associativity(tt TokenType) Associativity {
	return match tt {
		.period, .bracket_open, .paren_open, .question_mark_period, .asterisk, .slash, .percent,
		.plus, .minus, .shift_left, .shift_right, .unsigned_shift_right, .less_than,
		.less_than_equals, .greater_than, .greater_than_equals, .in_kw, .instanceof_kw,
		.equals_equals, .exclamation_mark_equals, .equals_equals_equals,
		.exclamation_mark_equals_equals, .typeof_kw, .void_kw, .delete_kw, .await_kw, .ampersand,
		.caret, .pipe, .double_question_mark, .double_ampersand, .double_pipe, .comma {
			.left
		}
		else {
			.right
		}
	}
}

// === Helper functions ===

fn is_use_strict(raw []u16) bool {
	return utf16_equals(raw, utf16("'use strict'")) || utf16_equals(raw, utf16('"use strict"'))
}

fn collect_binding_names_from_target(target VariableDeclaratorTarget, mut names map[string]bool) {
	match target {
		IdentifierVarTarget {
			names[target.identifier.name.str()] = true
		}
		BindingPatternVarTarget {
			collect_binding_pattern_names(target.pattern, mut names)
		}
	}
}

fn collect_binding_pattern_names(pattern BindingPattern, mut names map[string]bool) {
	for entry in pattern.entries {
		if entry.alias.kind == .identifier_kind {
			if id := entry.alias.identifier {
				names[id.name.str()] = true
			}
		} else if entry.alias.kind == .binding_pattern_kind {
			if bp := entry.alias.binding_pattern {
				collect_binding_pattern_names(bp, mut names)
			}
		}
		if entry.alias.kind == .none_kind && entry.name.kind == .identifier_kind {
			if id := entry.name.identifier {
				names[id.name.str()] = true
			}
		}
	}
}

const strict_reserved_words = ['implements', 'interface', 'let', 'package', 'private',
	'protected', 'public', 'static', 'yield']

fn is_strict_reserved_word(name []u16) bool {
	// These grammar terminals are ASCII. Compare their units directly instead
	// of allocating nine UTF-16 strings for every ordinary strict identifier.
	for word in strict_reserved_words {
		if name.len != word.len { continue }
		mut matches := true
		for index, character in word {
			if name[index] != u16(character) { matches = false; break }
		}
		if matches { return true }
	}
	return false
}

// Await and yield use contextual LabelIdentifier rules; the other
// ReservedWords are never valid labels, including escaped spellings.
fn is_unconditional_reserved_word(name []u16) bool {
	return string_from_utf16_lossy(name) in ['break', 'case', 'catch', 'class', 'const', 'continue',
		'debugger', 'default', 'delete', 'do', 'else', 'enum', 'export', 'extends', 'false',
		'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof', 'new', 'null', 'return',
		'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof', 'var', 'void', 'while', 'with']
}
