module css


import dom
import strings
import platform

type ParserRuleDeclarations = []Declaration

// This file ports Ladybird's LibWeb/CSS/Parser rule, selector, parser orchestration,
// rule-context, error-reporter, and arbitrary-substitution-function glue into the
// smaller V CSS model. Where the generated parser tables, full selector AST, DOM
// integration, or CSSRule subclasses do not exist in this port yet, explicit local
// stubs keep the translated control flow visible.
// It includes folded translations of Parser/RuleParsing.cpp and
// Parser/ArbitrarySubstitutionFunctions.cpp.

enum ParserNested {
	no
	yes
	scope
}

enum NestedDeclarationRuleKind {
	style
	function_rule
}

enum SaveOriginalText {
	no
	yes
}

pub enum SelectorParsingMode {
	standard
	forgiving
}

enum ParserSelectorType {
	standalone
	relative
}

enum ParseError {
	includes_ignored_vendor_prefix
	syntax_error
}

enum AllowBlankLayerName {
	no
	yes
}

struct InvalidQualifiedRuleError {}

type QualifiedRuleResult = InvalidQualifiedRuleError | QualifiedRule | bool

struct ParsedStyleSheet {
pub mut:
	location ?string
	rules    []Rule
}

pub struct RuleSelectorParser {
pub mut:
	defer_style_declarations bool
	tokens              []Token
	token_stream        ParserTokenStream
	document            &dom.Document = unsafe { nil }
	mode                ParsingMode
	value_context       []ValueParsingContext
	rule_context        []RuleContext
	declared_namespaces map[string]bool
	is_ua_style_sheet   IsUAStyleSheet
mut:
	raw_rules_transient bool
	component_input_transient bool
	parsed_rule_selectors map[string]Selector
	parsed_rule_selector_bytes int
}

pub fn RuleSelectorParser.create(params ParsingParams, input string, encoding string) RuleSelectorParser {
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(0, diagnostic_scope_start) }

	tokens := Tokenizer.tokenize(input, encoding)
	return RuleSelectorParser{
		tokens: tokens
		token_stream: ParserTokenStream.from_tokens(tokens)
		document: params.document
		mode: params.mode
		value_context: params.value_context.clone()
		rule_context: params.rule_context.clone()
		declared_namespaces: params.declared_namespaces.clone()
		is_ua_style_sheet: params.is_ua_style_sheet
	}
}

// Stylesheet callers consume component values, never the public raw-token
// array. Build that tree directly, keeping only one raw token at a time.
fn RuleSelectorParser.create_for_stylesheet(params ParsingParams, input string) RuleSelectorParser {
	return RuleSelectorParser{
		token_stream: stylesheet_parser_input(input)
		document: params.document
		mode: params.mode
		value_context: params.value_context.clone()
		rule_context: params.rule_context.clone()
		declared_namespaces: params.declared_namespaces.clone()
		is_ua_style_sheet: params.is_ua_style_sheet
	}
}

pub fn RuleSelectorParser.create_with_namespaces(input string, declared_namespaces map[string]bool) RuleSelectorParser {
	tokens := Tokenizer.tokenize(input, 'utf-8')
	return RuleSelectorParser{
		tokens: tokens
		token_stream: ParserTokenStream.from_tokens(tokens)
		declared_namespaces: declared_namespaces.clone()
	}
}

fn (parser RuleSelectorParser) parsing_params() ParsingParams {
	// Clone borrowed headers rather than taking addresses of parser fields.
	// Current V otherwise boxes the complete parser for every parameter snapshot.
	value_context := parser.value_context
	rule_context := parser.rule_context
	declared_namespaces := unsafe { parser.declared_namespaces }
	return ParsingParams{
		document: parser.document
		mode: parser.mode
		value_context: value_context.clone()
		rule_context: rule_context.clone()
		declared_namespaces: declared_namespaces.clone()
		is_ua_style_sheet: parser.is_ua_style_sheet
	}
}

struct ParserTokenStream {
pub mut:
	values []ComponentValue
	index  int
	marks  []int
}

fn ParserTokenStream.from_tokens(tokens []Token) ParserTokenStream {
	mut token_stream := RawTokenStream{
		tokens: tokens
	}
	mut values := []ComponentValue{}
	for !token_stream.next_token().is(.end_of_file) {
		values << parser_consume_a_component_value_from_tokens(mut token_stream)
	}
	return ParserTokenStream{
		values: values
	}
}

fn ParserTokenStream.from_source(input string, encoding string) ParserTokenStream {
	return ParserTokenStream.from_source_with_spelling(input, encoding, false)
}

fn ParserTokenStream.from_source_with_spelling(input string, encoding string,
	borrow_spelling bool) ParserTokenStream {
	mut source := &StylesheetTokenSource{
		tokenizer: Tokenizer.new(filter_code_points(input, encoding))
	}
	source.tokenizer.borrow_source_spelling = borrow_spelling
	defer { source.tokenizer.input_arena.release() }
	source.advance()
	mut stream := RawTokenStream{source: source}
	mut values := []ComponentValue{}
	for !stream.next_token().is(.end_of_file) {
		values << parser_consume_a_component_value_from_tokens(mut stream)
	}
	return ParserTokenStream{values: values}
}

fn ParserTokenStream.from_values(values []ComponentValue) ParserTokenStream {
	// Like upstream's token span, this stream borrows immutable component input
	// and supplies EOF beyond that span. No copy or appended sentinel is needed.
	stream_values := if values.len > 0 && values.last().is(.end_of_file) { values[..values.len - 1] } else { values }
	return ParserTokenStream{
		values: stream_values
	}
}

fn (stream ParserTokenStream) is_empty() bool {
	return !stream.has_next_token()
}

fn (stream ParserTokenStream) has_next_token() bool {
	return stream.index < stream.values.len && !stream.values[stream.index].is(.end_of_file)
}

// The stored span contains real tokens; EOF is supplied by next_token().
fn (stream ParserTokenStream) remaining_token_count() int {
	remaining := stream.values.len - stream.index
	return if remaining < 0 { 0 } else { remaining }
}

fn (stream ParserTokenStream) next_token() ComponentValue {
	if stream.index < stream.values.len {
		return stream.values[stream.index]
	}
	return parser_stream_eof()
}

fn (stream ParserTokenStream) peek_token(offset int) ComponentValue {
	index := stream.index + offset
	if index >= 0 && index < stream.values.len {
		return stream.values[index]
	}
	return parser_stream_eof()
}

fn (mut stream ParserTokenStream) consume_a_token() ComponentValue {
	token := stream.next_token()
	if stream.index < stream.values.len {
		stream.index++
	}
	return token
}

fn (mut stream ParserTokenStream) discard_a_token() {
	if stream.index < stream.values.len {
		stream.index++
	}
}

fn (mut stream ParserTokenStream) reconsume_current_input_token() {
	if stream.index > 0 {
		stream.index--
	}
}

fn (mut stream ParserTokenStream) discard_whitespace() {
	for stream.next_token().is(.whitespace) {
		stream.discard_a_token()
	}
}

fn (mut stream ParserTokenStream) mark() {
	stream.marks << stream.index
}

fn (mut stream ParserTokenStream) restore_a_mark() {
	if stream.marks.len == 0 {
		return
	}
	stream.index = stream.marks[stream.marks.len - 1]
	stream.marks.delete(stream.marks.len - 1)
}

fn (mut stream ParserTokenStream) discard_a_mark() {
	if stream.marks.len == 0 {
		return
	}
	stream.marks.delete(stream.marks.len - 1)
}

fn (stream ParserTokenStream) dump_string() string {
	return parser_component_values_to_string(stream.values)
}

fn (stream ParserTokenStream) tokens_since(start_index int) []ComponentValue {
	end := if stream.index <= stream.values.len { stream.index } else { stream.values.len }
	if start_index < 0 || start_index >= end {
		return []ComponentValue{}
	}
	return stream.values[start_index..end]
}

struct RawTokenStream {
pub mut:
	tokens []Token
	index  int
	source &StylesheetTokenSource = unsafe { nil }
}

struct StylesheetTokenSource {
mut:
	tokenizer Tokenizer
	current Token
	count int
}

fn (mut source StylesheetTokenSource) advance() {
	if source.current.is(.end_of_file) {
		// As with an exhausted raw array, only the first EOF has an input
		// position. Enclosing unterminated blocks receive synthetic EOF.
		source.current = Tokenizer.create_eof_token()
		return
	}
	if source.count % 256 == 0 { platform.cooperative_work_checkpoint() }
	start := source.tokenizer.position
	mut token := source.tokenizer.consume_a_token()
	token.set_position_range(start, source.tokenizer.position)
	source.current = token
	source.count++
}

fn (stream RawTokenStream) next_token() Token {
	if stream.source != unsafe { nil } { return stream.source.current }
	if stream.index < stream.tokens.len {
		return stream.tokens[stream.index]
	}
	return Tokenizer.create_eof_token()
}

fn (mut stream RawTokenStream) consume_a_token() Token {
	token := stream.next_token()
	if stream.source != unsafe { nil } {
		stream.source.advance()
		return token
	}
	if stream.index < stream.tokens.len {
		stream.index++
	}
	return token
}

fn (mut stream RawTokenStream) discard_a_token() {
	if stream.source != unsafe { nil } {
		stream.source.advance()
		return
	}
	if stream.index < stream.tokens.len {
		stream.index++
	}
}

// https://drafts.csswg.org/css-syntax/#parse-stylesheet
fn (mut parser RuleSelectorParser) parse_a_stylesheet(location ?string) ParsedStyleSheet {
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(1, diagnostic_scope_start) }

	// To parse a stylesheet from an input given an optional url location:
	// 1. If input is a byte stream for a stylesheet, decode bytes from input, and set input to the result.
	// 2. Normalize input, and set input to the result.
	// NOTE: These are done automatically when creating the Parser.

	// 3. Create a new stylesheet, with its location set to location (or null, if location was not passed).
	mut style_sheet := ParsedStyleSheet{
		location: location
	}

	// 4. Consume a stylesheet's contents from input, and set the stylesheet's rules to the result.
	style_sheet.rules = parser.consume_a_stylesheets_contents(mut parser.token_stream)

	// 5. Return the stylesheet.
	return style_sheet
}

// https://drafts.csswg.org/css-syntax/#parse-a-stylesheets-contents
fn (mut parser RuleSelectorParser) parse_a_stylesheets_contents(mut input ParserTokenStream) []Rule {
	// To parse a stylesheet's contents from input:
	// 1. Normalize input, and set input to the result.
	// NOTE: This is done automatically when creating the Parser.

	// 2. Consume a stylesheet's contents from input, and return the result.
	return parser.consume_a_stylesheets_contents(mut input)
}

pub fn (mut parser RuleSelectorParser) convert_rules(raw_rules []Rule) []&CSSRule {
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(2, diagnostic_scope_start) }

	mut import_rules_valid := true
	mut namespace_rules_valid := true

	// Interpret all of the resulting top-level qualified rules as style rules, defined below.
	mut rules := []&CSSRule{}
	for raw_rule in raw_rules {
		rule := parser.convert_to_rule(raw_rule, .no, .style) or {
			parser_log_parse_error()
			continue
		}

		// Any @import rules must precede all other valid at-rules and style rules (ignoring @charset and @layer
		// statement rules). Any @namespace rules must follow all @charset and @import rules and precede all other
		// non-ignored at-rules and style rules.
		match rule.type_ {
			.layer_statement {}
			.import_rule {
				if !import_rules_valid {
					continue
				}
			}
			.namespace_rule {
				import_rules_valid = false
				if !namespace_rules_valid {
					continue
				}
				parser.declared_namespaces[rule.kind_data().prefix] = true
			}
			else {
				import_rules_valid = false
				namespace_rules_valid = false
			}
		}

		rules << rule
	}
	return rules
}

// https://drafts.csswg.org/css-syntax/#parse-a-css-stylesheet
pub fn (mut parser RuleSelectorParser) parse_as_css_stylesheet(location ?string, media_list ?&MediaList) &CSSStyleSheet {
	// To parse a CSS stylesheet, first parse a stylesheet.
	rule_list := CSSRuleList.create(parser.parse_stylesheet_rules(location))
	media := media_list or { MediaList.create_empty() }
	return CSSStyleSheet.create(rule_list, media, location)
}

pub fn (mut parser RuleSelectorParser) parse_as_stylesheet_contents() []&CSSRule {
	mut input := parser.token_stream
	return parser.convert_rules(parser.parse_a_stylesheets_contents(mut input))
}

pub fn (mut parser RuleSelectorParser) parse_as_css_rule() ?&CSSRule {
	return parser.parse_as_css_rule_with_nesting(.no)
}

pub fn (mut parser RuleSelectorParser) parse_as_css_rule_with_nesting(nested ParserNested) ?&CSSRule {
	mut input := parser.token_stream
	rule := parser.parse_a_rule(mut input, nested) or { return none }
	return parser.convert_to_rule(rule, nested, .style)
}

pub fn (mut parser RuleSelectorParser) parse_as_selector(parsing_mode SelectorParsingMode) ?SelectorList {
	mut input := parser.token_stream
	selector_list := parser.parse_a_selector_list(mut input, .standalone, parsing_mode) or {
		return none
	}
	return selector_list
}

pub fn (mut parser RuleSelectorParser) parse_as_relative_selector(parsing_mode SelectorParsingMode) ?SelectorList {
	mut input := parser.token_stream
	selector_list := parser.parse_a_selector_list(mut input, .relative, parsing_mode) or {
		return none
	}
	return selector_list
}

pub fn (mut parser RuleSelectorParser) parse_as_list_of_component_values() []ComponentValue {
	mut input := parser.token_stream
	return parser.parse_a_list_of_component_values(mut input)
}

pub fn (mut parser RuleSelectorParser) parse_as_component_value() ?ComponentValue {
	mut input := parser.token_stream
	return parser.parse_a_component_value(mut input)
}

// https://drafts.csswg.org/css-syntax/#parse-rule
fn (mut parser RuleSelectorParser) parse_a_rule(mut input ParserTokenStream, nested ParserNested) ?Rule {
	// To parse a rule from input:
	// 1. Normalize input, and set input to the result.
	// NOTE: This is done automatically when creating the Parser.

	// 2. Discard whitespace from input.
	input.discard_whitespace()

	// 3. If the next token is an <EOF-token>, return failure.
	if input.next_token().is(.end_of_file) {
		return none
	}

	// 4. If the next token is an <at-keyword-token>, consume an at-rule from input, and let rule be the return value.
	mut rule := Rule(AtRule{})
	if input.next_token().is(.at_keyword) {
		at_rule := parser.consume_an_at_rule(mut input, nested) or { return none }
		rule = at_rule
	} else {
		// 5. Otherwise, consume a qualified rule from input and let rule be the return value. If nothing was returned,
		// return failure.
		result := parser.consume_a_qualified_rule(mut input, none, nested)
		match result {
			QualifiedRule {
				rule = result
			}
			else {
				return none
			}
		}
	}

	// 6. Discard whitespace from input.
	input.discard_whitespace()

	// 7. If the next token is an <EOF-token>, return rule. Otherwise, return failure.
	if input.next_token().is(.end_of_file) {
		return rule
	}
	return none
}

// https://drafts.csswg.org/css-syntax/#parse-declaration
fn (mut parser RuleSelectorParser) parse_a_declaration(mut input ParserTokenStream) ?Declaration {
	// To parse a declaration from input:
	// 1. Normalize input, and set input to the result.
	// NOTE: This is done automatically when creating the Parser.
	// 2. Discard whitespace from input.
	input.discard_whitespace()

	// 3. Consume a declaration from input. If anything is returned, let decl be the return value. If nothing was
	// returned, return failure.
	declaration := parser.consume_a_declaration(mut input, .no, .no) or { return none }

	// 4. Discard whitespace from input.
	input.discard_whitespace()

	// 5. If the next token is an <EOF-token>, return decl. Otherwise, return failure.
	if input.next_token().is(.end_of_file) {
		return declaration
	}
	return none
}

// https://drafts.csswg.org/css-syntax/#parse-component-value
fn (mut parser RuleSelectorParser) parse_a_component_value(mut input ParserTokenStream) ?ComponentValue {
	// To parse a component value from input:
	// 1. Normalize input, and set input to the result.
	// NOTE: This is done automatically when creating the Parser.

	// 2. Discard whitespace from input.
	input.discard_whitespace()

	// 3. If input is empty, return failure.
	if input.next_token().is(.end_of_file) {
		return none
	}

	// 4. Consume a component value from input and let value be the return value.
	value := parser.consume_a_component_value(mut input)

	// 5. Discard whitespace from input.
	input.discard_whitespace()

	// 6. If input is empty, return value. Otherwise, return failure.
	if input.next_token().is(.end_of_file) {
		return value
	}
	return none
}

// https://drafts.csswg.org/css-syntax/#parse-list-of-component-values
fn (mut parser RuleSelectorParser) parse_a_list_of_component_values(mut input ParserTokenStream) []ComponentValue {
	// To parse a list of component values from input:
	// 1. Normalize input, and set input to the result.
	// NOTE: This is done automatically when creating the Parser.

	// 2. Consume a list of component values from input, and return the result.
	return parser.consume_a_list_of_component_values(mut input, none, .no)
}

fn (mut parser RuleSelectorParser) parse_a_comma_separated_list_of_component_values(mut input ParserTokenStream) [][]ComponentValue {
	mut lists := [][]ComponentValue{}
	for {
		lists << parser.consume_a_list_of_component_values(mut input, TokenType.comma, .no)
		if input.is_empty() {
			break
		}
		input.discard_a_token()
	}
	return lists
}

// https://drafts.csswg.org/css-syntax/#consume-stylesheet-contents
fn (mut parser RuleSelectorParser) consume_a_stylesheets_contents(mut input ParserTokenStream) []Rule {
	// To consume a stylesheet's contents from a token stream input:
	// Let rules be an initially empty list of rules.
	mut rules := []Rule{}

	// Process input:
	for {
		platform.cooperative_work_checkpoint()
		token := input.next_token()

		// <whitespace-token>
		if token.is(.whitespace) {
			input.discard_a_token()
			continue
		}

		// <EOF-token>
		if token.is(.end_of_file) {
			return rules
		}

		// <CDO-token>
		// <CDC-token>
		if token.is(.cdo) || token.is(.cdc) {
			input.discard_a_token()
			continue
		}

		// <at-keyword-token>
		if token.is(.at_keyword) {
			// Consume an at-rule from input. If anything is returned, append it to rules.
			if maybe_at_rule := parser.consume_an_at_rule(mut input, .no) {
				rules << maybe_at_rule
			}
			continue
		}

		// anything else
		result := parser.consume_a_qualified_rule(mut input, none, .no)
		match result {
			QualifiedRule {
				rules << result
			}
			else {}
		}
	}
	return rules
}

// https://drafts.csswg.org/css-syntax/#consume-at-rule
fn (mut parser RuleSelectorParser) consume_an_at_rule(mut input ParserTokenStream, nested ParserNested) ?AtRule {
	// To consume an at-rule from a token stream input, given an optional bool nested (default false):
	// Assert: The next token is an <at-keyword-token>.
	assert input.next_token().is(.at_keyword)

	// Consume a token from input, and let rule be a new at-rule with its name set to the returned token's value,
	// its prelude initially set to an empty list, and no declarations or child rules.
	name := input.consume_a_token().token().at_keyword()
	mut rule := AtRule{
		name: name
		prelude: []ComponentValue{}
		child_rules_and_lists_of_declarations: []RuleOrListOfDeclarations{}
		is_block_rule: false
	}

	// Process input:
	for {
		token := input.next_token()

		// <semicolon-token>
		// <EOF-token>
		if token.is(.semicolon) || token.is(.end_of_file) {
			// Discard a token from input. If rule is valid in the current context, return it; otherwise return nothing.
			input.discard_a_token()
			if parser.is_valid_at_rule_in_the_current_context(rule) {
				return rule
			}
			return none
		}

		// <}-token>
		if token.is(.close_curly) {
			if nested == .yes {
				// If rule is valid in the current context, return it.
				if parser.is_valid_at_rule_in_the_current_context(rule) {
					return rule
				}
				return none
			}
			// Otherwise, consume a token and append the result to rule's prelude.
			rule.prelude << input.consume_a_token()
			continue
		}

		// <{-token>
		if token.is_curly_block() {
			// Consume a block from input, and assign the result to rule's child rules.
			parser.rule_context << rule_context_type_for_at_rule_local(rule.name)
			rule.child_rules_and_lists_of_declarations = parser.consume_a_block(mut input)
			rule.is_block_rule = true
			parser.rule_context.delete(parser.rule_context.len - 1)

			// If rule is valid in the current context, return it. Otherwise, return nothing.
			if parser.is_valid_at_rule_in_the_current_context(rule) {
				return rule
			}
			return none
		}

		// anything else
		// Consume a component value from input and append the returned value to rule's prelude.
		rule.prelude << parser.consume_a_component_value(mut input)
	}
	return none
}

// https://drafts.csswg.org/css-syntax/#consume-qualified-rule
fn (mut parser RuleSelectorParser) consume_a_qualified_rule(mut input ParserTokenStream, stop_token ?TokenType, nested ParserNested) QualifiedRuleResult {
	// To consume a qualified rule, from a token stream input, given an optional token stop token and an optional bool
	// nested (default false):
	// Let rule be a new qualified rule with its prelude, declarations, and child rules all initially set to empty lists.
	mut rule := QualifiedRule{
		prelude: []ComponentValue{}
		declarations: []Declaration{}
		child_rules: []RuleOrListOfDeclarations{}
	}
	prelude_start := input.index

	// NOTE: Qualified rules inside @keyframes are a keyframe rule. We'll assume all others are style rules.
	type_of_qualified_rule := if parser.rule_context.len > 0
		&& parser.rule_context[parser.rule_context.len - 1] == .keyframes {
		RuleContext.keyframe
	} else {
		RuleContext.style
	}

	// Process input:
	for {
		token := input.next_token()

		// <EOF-token>
		// stop token (if passed)
		if token.is(.end_of_file) {
			// This is a parse error. Return nothing.
			parser_log_parse_error()
			return false
		}
		if stop := stop_token {
			if token.is(stop) {
				// This is a parse error. Return nothing.
				parser_log_parse_error()
				return false
			}
		}

		// <}-token>
		if token.is(.close_curly) {
			// This is a parse error. If nested is true, return nothing. Otherwise, consume a token and append the result
			// to rule's prelude.
			parser_log_parse_error()
			if nested == .yes {
				return false
			}
			if disable_borrowed_rule_preludes {
				rule.prelude << input.consume_a_token()
			} else {
				input.discard_a_token()
			}
			continue
		}

		// <{-token>
		if token.is_curly_block() {
			if !disable_borrowed_rule_preludes {
				rule.prelude = input.values[prelude_start..input.index]
			}
			// If the first two non-<whitespace-token> values of rule's prelude are an <ident-token> whose value starts
			// with "--" followed by a <colon-token>, then:
			mut prelude_tokens := ParserTokenStream.from_values(rule.prelude)
			prelude_tokens.discard_whitespace()
			first_non_whitespace := prelude_tokens.consume_a_token()
			prelude_tokens.discard_whitespace()
			second_non_whitespace := prelude_tokens.consume_a_token()
			if first_non_whitespace.is(.ident)
				&& first_non_whitespace.token().ident().starts_with('--')
				&& second_non_whitespace.is(.colon) {
				if nested == .yes {
					parser.consume_the_remnants_of_a_bad_declaration(mut input, .yes)
					return false
				}
				_ = parser.consume_a_block(mut input)
				return false
			}

			// Otherwise, consume a block from input, and let child rules be the result.
			parser.rule_context << type_of_qualified_rule
			rule.child_rules = parser.consume_a_block(mut input)
			parser.rule_context.delete(parser.rule_context.len - 1)

			// If the first item of child rules is a list of declarations, remove it from child rules and assign it to
			// rule's declarations.
			if rule.child_rules.len > 0 && rule.child_rules[0] is DeclarationList {
				first := rule.child_rules[0] as DeclarationList
				rule.declarations = first.declarations
				rule.child_rules.delete(0)
			}

			// If rule is valid in the current context, return it; otherwise return an invalid rule error.
			if parser.is_valid_qualified_rule_in_the_current_context(rule) {
				return rule
			}
			return InvalidQualifiedRuleError{}
		}

		// anything else
		// Consume a component value from input and append the result to rule's prelude.
		if disable_borrowed_rule_preludes {
			rule.prelude << parser.consume_a_component_value(mut input)
		} else {
			input.discard_a_token()
		}
	}
	return false
}

// https://drafts.csswg.org/css-syntax/#consume-block
fn (mut parser RuleSelectorParser) consume_a_block(mut input ParserTokenStream) []RuleOrListOfDeclarations {
	// In this port's component-value stream the {}-block is a single SimpleBlock component value
	// (the normalizer pre-parses blocks), so consume that block and parse its inner contents,
	// rather than the spec's raw-token walk between <{-token> and <}-token>.
	block_value := input.consume_a_token()
	if !block_value.is_block() {
		return []RuleOrListOfDeclarations{}
	}
	block := block_value.block()
	mut block_stream := ParserTokenStream.from_values(block.value)
	return parser.consume_a_blocks_contents(mut block_stream)
}

// https://drafts.csswg.org/css-syntax/#consume-block-contents
fn (mut parser RuleSelectorParser) consume_a_blocks_contents(mut input ParserTokenStream) []RuleOrListOfDeclarations {
	// To consume a block's contents from a token stream input:
	// Let rules be an empty list, containing either rules or lists of declarations.
	mut rules := []RuleOrListOfDeclarations{}

	// Let decls be an empty list of declarations.
	mut declarations := []Declaration{}

	// Process input:
	for {
		token := input.next_token()

		// <whitespace-token>
		// <semicolon-token>
		if token.is(.whitespace) || token.is(.semicolon) {
			input.discard_a_token()
			continue
		}

		// <EOF-token>
		// <}-token>
		if token.is(.end_of_file) || token.is(.close_curly) {
			// AD-HOC: If decls is not empty, append it to rules.
			if declarations.len > 0 {
				rules << DeclarationList{
					declarations: declarations
				}
			}
			// Return rules.
			return rules
		}

		// <at-keyword-token>
		if token.is(.at_keyword) {
			// If decls is not empty, append it to rules, and set decls to a fresh empty list of declarations.
			if declarations.len > 0 {
				rules << DeclarationList{
					declarations: declarations
				}
				declarations = []Declaration{}
			}

			// Consume an at-rule from input, with nested set to true. If a rule was returned, append it to rules.
			if at_rule := parser.consume_an_at_rule(mut input, .yes) {
				rules << RuleNode{
					rule: Rule(at_rule)
				}
			}
			continue
		}

		// anything else
		// OPTIMIZATION: Look ahead to determine if this can be a declaration (ident whitespace* ':').
		mut could_be_declaration := false
		if token.is(.ident) {
			mut lookahead := 1
			for input.peek_token(lookahead).is(.whitespace) {
				lookahead++
			}
			could_be_declaration = input.peek_token(lookahead).is(.colon)
		}

		if could_be_declaration {
			// Mark input.
			input.mark()

			// Consume a declaration from input, with nested set to true. If a declaration was returned, append it to
			// decls, and discard a mark from input.
			if declaration := parser.consume_a_declaration(mut input, .yes, .no) {
				// V deep-clones an optional binding appended directly, including
				// the borrowed token span and name. Preserve those source owners.
				declarations << Declaration{
					name: declaration.name
					value: declaration.value
					important: declaration.important
					original_value_text: declaration.original_value_text
					original_full_text: declaration.original_full_text
				}
				input.discard_a_mark()
			} else {
				// Otherwise, restore a mark from input, then consume a qualified rule from input, with nested set to
				// true, and <semicolon-token> as the stop token.
				input.restore_a_mark()
				parser.consume_qualified_rule_in_block(mut input, mut rules, mut declarations)
			}
		} else {
			// Not a declaration, go straight to qualified rule parsing.
			parser.consume_qualified_rule_in_block(mut input, mut rules, mut declarations)
		}
	}
	return rules
}

fn (mut parser RuleSelectorParser) consume_qualified_rule_in_block(mut input ParserTokenStream, mut rules []RuleOrListOfDeclarations, mut declarations ParserRuleDeclarations) {
	result := parser.consume_a_qualified_rule(mut input, TokenType.semicolon, .yes)
	match result {
		QualifiedRule {
			if declarations.len > 0 {
				rules << DeclarationList{
					declarations: declarations.clone()
				}
				declarations.clear()
			}
			rules << RuleNode{
				rule: Rule(result)
			}
		}
		InvalidQualifiedRuleError {
			if declarations.len > 0 {
				rules << DeclarationList{
					declarations: declarations.clone()
				}
				declarations.clear()
			}
		}
		else {}
	}
}

fn (mut parser RuleSelectorParser) consume_a_component_value(mut input ParserTokenStream) ComponentValue {
	_ = parser
	return input.consume_a_token()
}

// Parser.cpp: Parser::consume_a_component_value_and_do_nothing<ComponentValue>.
// The component-value stream has already done all nesting work, so discarding
// directly avoids copying a value which the recovery path immediately drops.
fn (mut parser RuleSelectorParser) consume_a_component_value_and_do_nothing(mut input ParserTokenStream) {
	_ = parser
	input.discard_a_token()
}

// https://drafts.csswg.org/css-syntax/#consume-list-of-component-values
fn (mut parser RuleSelectorParser) consume_a_list_of_component_values(mut input ParserTokenStream, stop_token ?TokenType, nested ParserNested) []ComponentValue {
	// To consume a list of component values from a token stream input, given an optional token stop token and an optional
	// boolean nested (default false):
	// Let values be an empty list of component values.
	mut values := []ComponentValue{}

	// Process input:
	for {
		token := input.next_token()

		// <eof-token>
		// stop token (if passed)
		if token.is(.end_of_file) {
			return values
		}
		if stop := stop_token {
			if token.is(stop) {
				return values
			}
		}

		// <}-token>
		if token.is(.close_curly) {
			if nested == .yes {
				return values
			}
			parser_log_parse_error()
			values << input.consume_a_token()
			continue
		}

		// anything else
		values << parser.consume_a_component_value(mut input)
	}
	return values
}

// https://drafts.csswg.org/css-syntax/#consume-declaration
fn (mut parser RuleSelectorParser) consume_a_declaration(mut input ParserTokenStream, nested ParserNested, save_full_text SaveOriginalText) ?Declaration {
	// To consume a declaration from a token stream input, given an optional bool nested (default false):
	// Let decl be a new declaration, with an initially empty name and a value set to an empty list.
	mut declaration := Declaration{
		name: ''
		value: []ComponentValue{}
	}
	start_token_index := input.index

	// 1. If the next token is an <ident-token>, consume a token from input and set decl's name to the token's value.
	if input.next_token().is(.ident) {
		declaration.name = input.consume_a_token().token().ident()
	} else {
		// Otherwise, consume the remnants of a bad declaration from input, with nested, and return nothing.
		parser.consume_the_remnants_of_a_bad_declaration(mut input, nested)
		return none
	}

	// 2. Discard whitespace from input.
	input.discard_whitespace()

	// 3. If the next token is a <colon-token>, discard a token from input.
	if input.next_token().is(.colon) {
		input.discard_a_token()
	} else {
		// Otherwise, consume the remnants of a bad declaration from input, with nested, and return nothing.
		parser.consume_the_remnants_of_a_bad_declaration(mut input, nested)
		return none
	}

	// 4. Discard whitespace from input.
	input.discard_whitespace()

	// 5. Consume a list of component values from input, with nested, and with <semicolon-token> as the stop token, and
	// set decl's value to the result.
	// Declaration values borrow the immutable component stream. Growing a second
	// vector copied every token and retained each growth buffer under prealloc.
	start_value := input.index
	for !input.next_token().is(.end_of_file) && !input.next_token().is(.semicolon)
		&& !(nested == .yes && input.next_token().is(.close_curly)) {
		input.discard_a_token()
	}
	declaration.value = input.values[start_value..input.index]

	// 6. If the last two non-<whitespace-token>s in decl's value are a <delim-token> with the value "!" followed by an
	// <ident-token> with a value that is an ASCII case-insensitive match for "important", remove them from decl's value
	// and set decl's important flag.
	parser_strip_important(mut declaration)

	// 7. While the last item in decl's value is a <whitespace-token>, remove that token.
	for declaration.value.len > 0 && declaration.value[declaration.value.len - 1].is(.whitespace) {
		declaration.value = declaration.value[..declaration.value.len - 1]
	}

	// 8. If decl's name is a custom property name string, then set decl's original text to the segment of the original
	// source text string corresponding to the tokens of decl's value.
	if is_invalid_custom_property_name_string_local(declaration.name) {
		return none
	}
	if is_a_custom_property_name_string(declaration.name) {
		if !is_valid_optional_declaration_value(declaration.value) {
			return none
		}
		declaration.original_value_text = parser_component_values_original_text(declaration.value)
	} else if declaration_contains_a_curly_block_and_non_whitespace(declaration.value) {
		// Otherwise, if decl's value contains a top-level simple block with an associated token of <{-token>, and also
		// contains any other non-<whitespace-token> value, return nothing.
		return none
	} else if equals_ignoring_ascii_case(declaration.name, 'unicode-range') {
		// FIXME: Special unicode-range handling.
	}

	// 9. If decl is valid in the current context, return it; otherwise return nothing.
	// Boundary: supports-declaration parsing lives in media_queries.v and constructs a parser directly for an
	// already-isolated declaration. save_full_text is only used by that path, so validate it as SupportsCondition.
	validate_as_supports_condition := save_full_text == .yes && parser.rule_context.len == 0
	if validate_as_supports_condition {
		parser.rule_context << .supports_condition
	}
	is_valid_declaration := parser.is_valid_declaration_in_the_current_context(declaration)
	if validate_as_supports_condition {
		parser.rule_context.delete(parser.rule_context.len - 1)
	}
	if is_valid_declaration {
		if save_full_text == .yes {
			declaration.original_full_text =
				parser_component_values_to_string(input.tokens_since(start_token_index))
		}
		return declaration
	}
	return none
}

// https://drafts.csswg.org/css-syntax/#consume-the-remnants-of-a-bad-declaration
fn (mut parser RuleSelectorParser) consume_the_remnants_of_a_bad_declaration(mut input ParserTokenStream, nested ParserNested) {
	// To consume the remnants of a bad declaration from a token stream input, given a bool nested:
	// Process input:
	for {
		token := input.next_token()

		// <eof-token>
		// <semicolon-token>
		if token.is(.end_of_file) || token.is(.semicolon) {
			input.discard_a_token()
			return
		}

		// <}-token>
		if token.is(.close_curly) {
			if nested == .yes {
				return
			}
			input.discard_a_token()
			continue
		}

		// anything else
		parser.consume_a_component_value_and_do_nothing(mut input)
	}
}

fn parser_consume_a_component_value_from_tokens(mut input RawTokenStream) ComponentValue {
	for {
		type_ := input.component_token_type()
		if type_ in [.open_curly, .open_square, .open_paren] {
			return ComponentValue.from_block(parser_consume_a_simple_block(mut input))
		}
		if type_ == .function {
			return ComponentValue.from_function(parser_consume_a_function(mut input))
		}
		return ComponentValue.from_token(input.consume_a_token())
	}
	return ComponentValue.from_token(Tokenizer.create_eof_token())
}

// https://drafts.csswg.org/css-syntax/#consume-simple-block
fn parser_consume_a_simple_block(mut input RawTokenStream) SimpleBlock {
	// Assert: the next token of input is <{-token>, <[-token>, or <(-token>.
	type_ := input.component_token_type()
	assert type_ in [.open_curly, .open_square, .open_paren]

	// Let ending token be the mirror variant of the next token.
	ending_token := match type_ {
		.open_curly { TokenType.close_curly }
		.open_square { TokenType.close_square }
		else { TokenType.close_paren }
	}

	// Let block be a new simple block with its associated token set to the next token and with its value initially set
	// to an empty list.
	mut block := SimpleBlock{
		token: input.next_token()
		value: []ComponentValue{cap: component_input_initial_capacity()}
	}

	// Discard a token from input.
	input.discard_a_token()

	// Process input:
	for {
		next_type := input.component_token_type()
		if next_type == .end_of_file || next_type == ending_token {
			block.end_token = input.consume_a_token()
			return block
		}
		block.value << parser_consume_a_component_value_from_tokens(mut input)
	}
	return block
}

// https://drafts.csswg.org/css-syntax/#consume-function
fn parser_consume_a_function(mut input RawTokenStream) Function {
	// Assert: The next token is a <function-token>.
	assert input.component_token_type() == .function

	// Consume a token from input, and let function be a new function with its name equal the returned token's value, and
	// a value set to an empty list.
	name_token := input.consume_a_token()
	mut function := Function{
		name: name_token.function_name()
		value: []ComponentValue{cap: component_input_initial_capacity()}
		name_token: name_token
	}

	// Process input:
	for {
		next_type := input.component_token_type()
		if next_type == .end_of_file || next_type == .close_paren {
			function.end_token = input.consume_a_token()
			return function
		}
		function.value << parser_consume_a_component_value_from_tokens(mut input)
	}
	return function
}

fn (mut parser RuleSelectorParser) convert_to_rule(rule Rule, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) ?&CSSRule {
	if parser.component_input_transient {
		return parser.convert_to_rule_impl(own_transient_rule_prelude(rule), nested, declaration_rule_kind)
	}
	// Query/selector parsers may retain spans of their prelude input. Only the
	// raw rule vectors are temporary; their nested component payloads already
	// belong to the immutable tokenizer input.
	owned := if parser.raw_rules_transient {
		match rule {
			AtRule { Rule(AtRule{...rule, prelude: rule.prelude.clone()}) }
			QualifiedRule { Rule(rule) }
		}
	} else { rule }
	return parser.convert_to_rule_impl(owned, nested, declaration_rule_kind)
}

fn (mut parser RuleSelectorParser) convert_to_rule_impl(rule Rule, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) ?&CSSRule {
	platform.cooperative_work_checkpoint()
	match rule {
		AtRule {
			if equals_ignoring_ascii_case(rule.name, 'keyframes')
				|| equals_ignoring_ascii_case(rule.name, '-webkit-keyframes') {
				return parser.convert_to_keyframes_rule(rule)
			}
			if has_ignored_vendor_prefix_local(rule.name) {
				return none
			}
			if equals_ignoring_ascii_case(rule.name, 'container') {
				return parser.convert_to_container_rule(rule, nested, declaration_rule_kind)
			}
			if equals_ignoring_ascii_case(rule.name, 'counter-style') {
				return parser.convert_to_counter_style_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'font-face') {
				return parser.convert_to_font_face_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'font-feature-values') {
				return parser.convert_to_font_feature_values_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'function') {
				return parser.convert_to_function_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'import') {
				return parser.convert_to_import_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'layer') {
				return parser.convert_to_layer_rule(rule, nested, declaration_rule_kind)
			}
			if is_margin_rule_name(rule.name) {
				return parser.convert_to_margin_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'media') {
				return parser.convert_to_media_rule(rule, nested, declaration_rule_kind)
			}
			if equals_ignoring_ascii_case(rule.name, 'namespace') {
				return parser.convert_to_namespace_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'supports') {
				return parser.convert_to_supports_rule(rule, nested, declaration_rule_kind)
			}
			if equals_ignoring_ascii_case(rule.name, 'page') {
				return parser.convert_to_page_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'property') {
				return parser.convert_to_property_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'scope') {
				return parser.convert_to_scope_rule(rule, nested, declaration_rule_kind)
			}
			parser_report_error(ParsingError(UnknownRuleError{
				rule_name: '@${rule.name}'
			}))
			return none
		}
		QualifiedRule {
			return parser.convert_to_style_rule(rule, nested)
		}
	}
}

fn (parser RuleSelectorParser) parent_for_style_nesting(nested ParserNested) StyleNestingParent {
	if nested == .no {
		return .none_
	}
	for index := parser.rule_context.len - 1; index >= 0; index-- {
		match parser.rule_context[index] {
			.style {
				return .style
			}
			.scope {
				return .scope
			}
			else {}
		}
	}
	// During whole-stylesheet conversion the V parser carries the nearest nesting
	// parent in ParserNested. Single-rule CSSOM parsing instead supplies the full
	// owner rule context above.
	return if nested == .scope { .scope } else { .style }
}

fn (mut parser RuleSelectorParser) convert_to_style_rule(qualified_rule QualifiedRule, nested ParserNested) ?&CSSRule {
	mut prelude_stream := ParserTokenStream.from_values(qualified_rule.prelude)
	maybe_selectors := parser.parse_a_selector_list(mut prelude_stream, if nested != .no {
		ParserSelectorType.relative
	} else {
		ParserSelectorType.standalone
	}, .standard) or {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: 'style'
			prelude: prelude_stream.dump_string()
			description: 'Selectors invalid.'
		}))
		return none
	}

	if maybe_selectors.is_empty() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: 'style'
			prelude: prelude_stream.dump_string()
			description: 'Empty selector.'
		}))
		return none
	}

	mut selectors := maybe_selectors
	if nested != .no {
		selectors = adapt_nested_relative_selector_list(selectors, parser.parent_for_style_nesting(nested))
	}

	declaration := parser.declaration_for_style_rule(qualified_rule.declarations)
	mut child_rules := []&CSSRule{}
	for child in qualified_rule.child_rules {
		match child {
			RuleNode {
				if converted_rule := parser.convert_to_rule(child.rule, .yes, .style) {
					// "In addition to nested style rules, this specification allows
					// nested group rules inside of style rules: any at-rule whose body
					// contains style rules can be nested inside of a style rule as
					// well." A CSSStyleRule is itself a CSSGroupingRule, so a nested
					// style rule is accepted here too.
					if converted_rule.type_ in css_grouping_rule_types {
						child_rules << converted_rule
					} else {
						parser_report_error(ParsingError(InvalidRuleLocationError{
							outer_rule_name: 'style'
							inner_rule_name: converted_rule.type_.class_name()
						}))
					}
				}
			}
			DeclarationList {
				child_rules << CSSRule.create_nested_declarations(parser.declaration_for_style_rule(child.declarations))
			}
		}
	}

	return CSSRule.create_style(selectors, declaration, CSSRuleList.create(child_rules))
}

// https://drafts.csswg.org/css-conditional-5/#container-rule
fn (mut parser RuleSelectorParser) convert_to_container_rule(rule AtRule, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) ?&CSSRule {
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	prelude := prelude_stream.dump_string()
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@container'
			prelude: prelude
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	prelude_items := parser.parse_a_comma_separated_list_of_component_values(mut prelude_stream)
	mut conditions := []ContainerRuleCondition{cap: prelude_items.len}
	for item in prelude_items {
		mut item_tokens := SupportsTokenStream.from_values(item)
		container_name := parse_container_name(mut item_tokens)
		item_tokens.discard_whitespace()
		mut query_parser := Parser{
			context: parser.parsing_params()
			value_context: parser.value_context.clone()
		}
		container_query := query_parser.parse_container_query(mut item_tokens)
		if container_name == none && container_query == none {
			parser_report_error(ParsingError(InvalidRuleError{
				rule_name: '@container'
				prelude: prelude
				description: 'Missing container name or query.'
			}))
			return none
		}
		item_tokens.discard_whitespace()
		if item_tokens.has_next_token() {
			parser_report_error(ParsingError(InvalidRuleError{
				rule_name: '@container'
				prelude: prelude
				description: 'Trailing tokens after name and query.'
			}))
			return none
		}
		conditions << ContainerRuleCondition{
			container_name: container_name
			container_query: container_query
		}
	}

	children := parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations, nested, declaration_rule_kind)
	return CSSRule.create_container(conditions, CSSRuleList.create(children))
}

fn (mut parser RuleSelectorParser) parse_import_scope_selector_list(mut tokens ParserTokenStream, selector_type ParserSelectorType) ?SelectorList {
	selectors := parser.parse_a_selector_list(mut tokens, selector_type, .standard) or { return none }
	tokens.discard_whitespace()
	if selectors.is_empty() || tokens.has_next_token()
		|| selector_list_contains_pseudo_element(selectors) {
		return none
	}
	return selectors
}

fn (mut parser RuleSelectorParser) parse_import_scope_function(scope_function Function) ?ImportScope {
	mut tokens := ParserTokenStream.from_values(scope_function.value)
	mut scope := ImportScope{}
	tokens.discard_whitespace()
	if !tokens.has_next_token() {
		return scope
	}

	if tokens.next_token().is_block() && tokens.next_token().block().is_paren() {
		start_block := tokens.consume_a_token().block()
		mut start_tokens := ParserTokenStream.from_values(start_block.value)
		scope.start_selectors = parser.parse_import_scope_selector_list(mut start_tokens, .standalone) or { return none }
		tokens.discard_whitespace()
	}

	if tokens.next_token().is_ident('to') {
		tokens.discard_a_token()
		tokens.discard_whitespace()
		if !tokens.next_token().is_block() || !tokens.next_token().block().is_paren() {
			return none
		}
		end_block := tokens.consume_a_token().block()
		mut end_tokens := ParserTokenStream.from_values(end_block.value)
		scope.end_selectors = parser.parse_import_scope_selector_list(mut end_tokens, .relative) or {
			return none
		}
		tokens.discard_whitespace()
	}

	if scope.start_selectors == none && scope.end_selectors == none {
		scope.start_selectors = parser.parse_import_scope_selector_list(mut tokens, .standalone) or {
			return none
		}
		return scope
	}
	if tokens.has_next_token() {
		return none
	}
	return scope
}

fn (mut parser RuleSelectorParser) convert_to_import_rule(rule AtRule) ?&CSSRule {
	mut tokens := ParserTokenStream.from_values(rule.prelude)
	if rule.is_block_rule || rule.prelude.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@import'
			prelude: tokens.dump_string()
			description: if rule.is_block_rule {
				'Must be a statement, not a block.'
			} else {
				'Empty prelude.'
			}
		}))
		return none
	}

	tokens.discard_whitespace()
	url := parser_parse_url_or_string(mut tokens) or {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@import'
			prelude: tokens.dump_string()
			description: 'Unable to parse URL.'
		}))
		return none
	}

	tokens.discard_whitespace()
	mut layer := ?string(none)
	mut scope := ?ImportScope(none)
	mut supports := ?&Supports(none)
	for {
		tokens.discard_whitespace()
		if layer == none && tokens.next_token().is_ident('layer') {
			tokens.discard_a_token()
			layer = ''
			continue
		}
		if layer == none && tokens.next_token().is_function_named('layer') {
			layer_function := tokens.next_token().function()
			mut layer_tokens := ParserTokenStream.from_values(layer_function.value)
			name := parser.parse_layer_name(mut layer_tokens, .no) or { return none }
			layer_tokens.discard_whitespace()
			if layer_tokens.has_next_token() {
				return none
			}
			tokens.discard_a_token()
			layer = name
			continue
		}
		if scope == none && tokens.next_token().is_ident('scope') {
			tokens.discard_a_token()
			scope = ImportScope{}
			continue
		}
		if scope == none && tokens.next_token().is_function_named('scope') {
			scope_function := tokens.next_token().function()
			scope = parser.parse_import_scope_function(scope_function) or { return none }
			tokens.discard_a_token()
			continue
		}
		if supports == none && tokens.next_token().is_function_named('supports') {
			supports_function := tokens.next_token().function()
			condition := parser_component_values_to_string(supports_function.value)
			supports = parse_css_supports(parser.parsing_params(), condition)
			if supports == none {
				mut supports_tokens := ParserTokenStream.from_values(supports_function.value)
				if supports_declaration := parse_supports_declaration_from_parser_tokens(mut supports_tokens) {
					supports = Supports.create(supports_declaration)
				}
			}
			if supports == none {
				return none
			}
			tokens.discard_a_token()
			continue
		}
		break
	}

	media_text :=
		parser_component_values_to_string(tokens.values[tokens.index..]).trim_space()
	mut media_queries := []&MediaQuery{}
	if media_text.len != 0 {
		media_queries = parse_css_media_query_list_value_logic(media_text)
	}
	media := MediaList.create(media_query_entries_from_queries(media_queries))
	return CSSRule.create_import(url, none, layer, scope, supports, media)
}

fn (mut parser RuleSelectorParser) convert_to_layer_rule(rule AtRule, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) ?&CSSRule {
	if rule.is_block_rule {
		mut prelude_tokens := ParserTokenStream.from_values(rule.prelude)
		layer_name := parser.parse_layer_name(mut prelude_tokens, .yes) or { return none }
		prelude_tokens.discard_whitespace()
		if prelude_tokens.has_next_token() {
			return none
		}
		mut child_rules := parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations,
			nested, declaration_rule_kind)
		return CSSRule.create_layer_block(layer_name, CSSRuleList.create(child_rules))
	}

	mut prelude_tokens := ParserTokenStream.from_values(rule.prelude)
	prelude_tokens.discard_whitespace()
	mut layer_names := []string{}
	for prelude_tokens.has_next_token() {
		if layer_names.len > 0 {
			if !prelude_tokens.consume_a_token().is(.comma) {
				return none
			}
			prelude_tokens.discard_whitespace()
		}
		name := parser.parse_layer_name(mut prelude_tokens, .no) or { return none }
		layer_names << name
		prelude_tokens.discard_whitespace()
	}
	if layer_names.len == 0 {
		return none
	}
	return CSSRule.create_layer_statement(layer_names)
}

fn (mut parser RuleSelectorParser) convert_to_media_rule(rule AtRule, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) ?&CSSRule {
	mut prelude_tokens := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		return none
	}
	mut media := MediaList.create_empty()
	mut mutable_media := unsafe { &MediaList(media) }
	mutable_media.set_media_text(prelude_tokens.dump_string())
	return CSSRule.create_media(media, CSSRuleList.create(parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations,
		nested, declaration_rule_kind)))
}

fn (mut parser RuleSelectorParser) convert_to_namespace_rule(rule AtRule) ?&CSSRule {
	mut tokens := ParserTokenStream.from_values(rule.prelude)
	if rule.is_block_rule || rule.prelude.len == 0 {
		return none
	}
	tokens.discard_whitespace()
	mut prefix := ?string(none)
	if tokens.next_token().is(.ident) {
		prefix = tokens.consume_a_token().token().ident()
		tokens.discard_whitespace()
	}
	namespace_uri := parser_parse_url_or_string(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return CSSRule.create_namespace(prefix, namespace_uri)
}

fn (mut parser RuleSelectorParser) convert_to_supports_rule(rule AtRule, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) ?&CSSRule {
	mut supports_tokens := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule || rule.prelude.len == 0 {
		return none
	}
	condition := supports_tokens.dump_string()
	supports := parse_css_supports(parser.parsing_params(), condition) or { return none }
	return CSSRule.create_supports(supports, CSSRuleList.create(parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations,
		nested, declaration_rule_kind)))
}

fn selector_list_contains_pseudo_element(selectors SelectorList) bool {
	for selector in selectors.selectors {
		if selector.pseudo_element() != none {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/css-cascade-6/#scope-atrule
fn (mut parser RuleSelectorParser) convert_to_scope_rule(rule AtRule, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) ?&CSSRule {
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		return none
	}

	mut start_selectors := ?SelectorList(none)
	mut end_selectors := ?SelectorList(none)
	prelude_stream.discard_whitespace()
	if prelude_stream.next_token().is_block() && prelude_stream.next_token().block().is_paren() {
		start_block := prelude_stream.consume_a_token().block()
		mut start_tokens := ParserTokenStream.from_values(start_block.value)
		mut parsed_start := parser.parse_a_selector_list(mut start_tokens, if nested != .no {
			ParserSelectorType.relative
		} else {
			ParserSelectorType.standalone
		}, .standard) or { return none }
		start_tokens.discard_whitespace()
		if parsed_start.is_empty() || start_tokens.has_next_token()
			|| selector_list_contains_pseudo_element(parsed_start) {
			return none
		}
		if nested != .no {
			parsed_start = adapt_nested_relative_selector_list(parsed_start, parser.parent_for_style_nesting(nested))
		}
		start_selectors = parsed_start
		prelude_stream.discard_whitespace()
	}

	if prelude_stream.next_token().is_ident('to') {
		prelude_stream.discard_a_token()
		prelude_stream.discard_whitespace()
		if !prelude_stream.next_token().is_block()
			|| !prelude_stream.next_token().block().is_paren() {
			return none
		}
		end_block := prelude_stream.consume_a_token().block()
		mut end_tokens := ParserTokenStream.from_values(end_block.value)
		parsed_end := parser.parse_a_selector_list(mut end_tokens, .relative, .standard) or {
			return none
		}
		end_tokens.discard_whitespace()
		if parsed_end.is_empty() || end_tokens.has_next_token()
			|| selector_list_contains_pseudo_element(parsed_end) {
			return none
		}
		end_selectors = parsed_end
		prelude_stream.discard_whitespace()
	}

	if prelude_stream.has_next_token() {
		return none
	}
	children := parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations,
		.scope, declaration_rule_kind)
	return CSSRule.create_scope(start_selectors, end_selectors, CSSRuleList.create(children))
}

fn (mut parser RuleSelectorParser) convert_to_keyframes_rule(rule AtRule) ?&CSSRule {
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule || rule.prelude.len == 0 {
		return none
	}
	prelude_stream.discard_whitespace()
	name_token := prelude_stream.consume_a_token()
	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() || (!name_token.is(.string) && !name_token.is(.ident)) {
		return none
	}

	if name_token.is(.ident) {
		name := name_token.token().ident()
		if !is_valid_custom_ident(name, ['none']) {
			parser_report_error(ParsingError(InvalidRuleError{
				rule_name: '@keyframes'
				prelude: prelude_stream.dump_string()
				description: 'Invalid keyframes name.'
			}))
			return none
		}
	}

	mut keyframes := []&CSSRule{}
	for child in rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				match child.rule {
					AtRule {
						parser_report_error(ParsingError(InvalidRuleLocationError{
							outer_rule_name: '@keyframes'
							inner_rule_name: '@${child.rule.name}'
						}))
					}
					QualifiedRule {
						for keyframe_rule in parser.convert_to_keyframe_rules(child.rule) {
							keyframes << keyframe_rule
						}
					}
				}
			}
			DeclarationList {
				parser_report_error(ParsingError(InvalidRuleLocationError{
					outer_rule_name: '@keyframes'
					inner_rule_name: 'list-of-declarations'
				}))
			}
		}
	}

	name := if name_token.is(.string) {
		name_token.token().string_value()
	} else {
		name_token.token().ident()
	}
	return CSSRule.create_keyframes(name, CSSRuleList.create(keyframes))
}

fn (mut parser RuleSelectorParser) convert_to_keyframe_rules(qualified_rule QualifiedRule) []&CSSRule {
	for child_rule in qualified_rule.child_rules {
		match child_rule {
			RuleNode {
				match child_rule.rule {
					AtRule {
						parser_report_error(ParsingError(InvalidRuleLocationError{
							outer_rule_name: 'keyframe'
							inner_rule_name: '@${child_rule.rule.name}'
						}))
					}
					QualifiedRule {
						parser_report_error(ParsingError(InvalidRuleLocationError{
							outer_rule_name: 'keyframe'
							inner_rule_name: 'qualified-rule'
						}))
					}
				}
			}
			DeclarationList {
				parser_report_error(ParsingError(InvalidRuleLocationError{
					outer_rule_name: 'keyframe'
					inner_rule_name: 'list-of-declarations'
				}))
			}
		}
	}

	selectors := parser.parse_keyframe_selector_list(qualified_rule.prelude)
	style := parser.convert_to_style_declaration(qualified_rule.declarations)
	mut rules := []&CSSRule{}
	for selector in selectors {
		rules << CSSRule.create_keyframe(selector, style)
	}
	return rules
}

fn (mut parser RuleSelectorParser) parse_keyframe_selector_list(prelude []ComponentValue) []Percentage {
	mut selectors := []Percentage{}
	mut child_tokens := ParserTokenStream.from_values(prelude)
	for child_tokens.has_next_token() {
		child_tokens.discard_whitespace()
		if !child_tokens.has_next_token() {
			break
		}

		tok := child_tokens.consume_a_token()
		if !tok.is_token() {
			parser_report_error(ParsingError(InvalidRuleError{
				rule_name: 'keyframe'
				prelude: child_tokens.dump_string()
				description: 'Invalid selector.'
			}))
			child_tokens.reconsume_current_input_token()
			break
		}

		token := tok.token()
		mut read_a_selector := false
		if token.is(.ident) {
			if equals_ignoring_ascii_case(token.ident(), 'from') {
				selectors << Percentage.new(0)
				read_a_selector = true
			}
			if equals_ignoring_ascii_case(token.ident(), 'to') {
				selectors << Percentage.new(100)
				read_a_selector = true
			}
		} else if token.is(.percentage) {
			selectors << Percentage.new(token.percentage())
			read_a_selector = true
		}

		if read_a_selector {
			child_tokens.discard_whitespace()
			if child_tokens.consume_a_token().is(.comma) {
				continue
			}
		}

		child_tokens.reconsume_current_input_token()
		break
	}
	return selectors
}

fn (mut parser RuleSelectorParser) convert_to_property_rule(rule AtRule) ?&CSSRule {
	// https://drafts.css-houdini.org/css-properties-values-api-1/#at-ruledef-property
	// @property <custom-property-name> {
	// <declaration-list>
	// }
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@property'
			prelude: prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	if rule.prelude.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@property'
			prelude: prelude_stream.dump_string()
			description: 'Empty prelude.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	token := prelude_stream.consume_a_token()
	if !token.is(.ident) {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@property'
			prelude: prelude_stream.dump_string()
			description: 'Name must be an ident.'
		}))
		return none
	}

	name := token.token().ident()
	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@property'
			prelude: prelude_stream.dump_string()
			description: 'Trailing tokens after name in prelude.'
		}))
		return none
	}

	if !is_a_custom_property_name_string(name) {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@property'
			prelude: prelude_stream.dump_string()
			description: "Name must be an ident starting with '--'."
		}))
		return none
	}

	mut syntax_maybe := ?string(none)
	mut inherits_maybe := ?bool(none)
	mut initial_value_maybe := ?string(none)
	for declaration in declarations_from_at_rule(rule) {
		value := parser_component_values_to_string(declaration.value).trim_space()
		match declaration.name.to_lower() {
			'syntax' {
				if declaration.value.len == 1 && declaration.value[0].is(.string) {
					syntax_maybe = declaration.value[0].token().string_value()
				}
			}
			'inherits' {
				if value.to_lower() == 'true' {
					inherits_maybe = true
				} else if value.to_lower() == 'false' {
					inherits_maybe = false
				}
			}
			'initial-value' {
				initial_value_maybe = value
			}
			else {}
		}
	}

	// @property rules require a syntax and inherits descriptor; if either are missing, the entire rule is invalid and must be ignored.
	syntax := syntax_maybe or { return none }
	if syntax.len == 0 {
		return none
	}
	inherits := inherits_maybe or { return none }

	syntax_component_values := parse_component_values_for_value_logic(syntax)
	maybe_syntax := parse_as_syntax_with_ident_limit(syntax_component_values, .yes) or {
		return none
	}

	// The initial-value descriptor is optional only if the syntax is the universal syntax definition,
	// otherwise the descriptor is required; if it's missing, the entire rule is invalid and must be ignored.
	if initial_value_maybe == none && maybe_syntax.type() != .universal {
		return none
	}

	mut parsed_initial_value_maybe := ?StyleValue(none)
	if initial_value := initial_value_maybe {
		initial_value_component_values := parse_component_values_for_value_logic(initial_value)
		mut substitution_presence := SubstitutionFunctionsPresence{}
		collect_arbitrary_substitution_function_presence(initial_value_component_values, mut substitution_presence) or {
			return none
		}
		if substitution_presence.has_any() {
			return none
		}
		parsed_initial_value := parse_with_a_syntax(initial_value_component_values, maybe_syntax)
		if parsed_initial_value.type_() == .guaranteed_invalid {
			return none
		}
		// Otherwise, if the value of the syntax descriptor is not the universal syntax definition,
		// the following conditions must be met for the @property rule to be valid:
		if maybe_syntax.type() != .universal {
			//  - The initial-value descriptor must be present.
			//  - The initial-value descriptor's value must parse successfully according to the grammar specified by the syntax definition.
			//  - The initial-value must be computationally independent.
			if !parsed_initial_value.is_computationally_independent() {
				return none
			}
		}
		parsed_initial_value_maybe = parsed_initial_value
	}

	return CSSRule.create_property_rule_with_parsed_initial_value(name, syntax, inherits, initial_value_maybe, parsed_initial_value_maybe)
}

fn (mut parser RuleSelectorParser) convert_to_counter_style_rule(rule AtRule) ?&CSSRule {
	// https://drafts.csswg.org/css-counter-styles-3/#the-counter-style-rule
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@counter-style'
			prelude: prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	if rule.prelude.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@counter-style'
			prelude: prelude_stream.dump_string()
			description: 'Empty prelude.'
		}))
		return none
	}

	name := parser.parse_counter_style_name(mut prelude_stream) or {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@counter-style'
			prelude: prelude_stream.dump_string()
			description: 'Missing counter style name.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@counter-style'
			prelude: prelude_stream.dump_string()
			description: 'Trailing tokens after name in prelude.'
		}))
		return none
	}

	// https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style-name
	// When used here, to define a counter style, it also cannot be any of the non-overridable counter-style names
	if css_counter_style_rule_matches_non_overridable_counter_style_name(name)
		&& parser.is_ua_style_sheet != .yes {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@counter-style'
			prelude: prelude_stream.dump_string()
			description: 'Non-overridable counter style name.'
		}))
		return none
	}

	mut system := ?CounterStyleSystemStyleValue(none)
	mut negative := ?CounterStyleSymbolListStyleValue(none)
	mut prefix := ?StyleValue(none)
	mut suffix := ?StyleValue(none)
	mut range := ?CounterStyleRangeStyleValue(none)
	mut pad := ?CounterStylePadStyleValue(none)
	mut fallback := ?StyleValue(none)
	mut symbols := ?CounterStyleSymbolListStyleValue(none)
	mut additive_symbols := ?CounterStyleAdditiveSymbolsStyleValue(none)
	mut speak_as := ?StyleValue(none)

	for declaration in declarations_from_at_rule(rule) {
		value_text := parser_component_values_to_string(declaration.value).trim_space()
		match declaration.name.to_lower() {
			'system' {
				system = parse_counter_style_system_descriptor_value(value_text)
			}
			'negative' {
				negative = parse_counter_style_symbol_list_descriptor_value(value_text)
			}
			'prefix' {
				prefix = parse_counter_style_symbol_descriptor_value(value_text)
			}
			'suffix' {
				suffix = parse_counter_style_symbol_descriptor_value(value_text)
			}
			'range' {
				range = parse_counter_style_range_descriptor_value(value_text)
			}
			'pad' {
				pad = parse_counter_style_pad_descriptor_value(value_text)
			}
			'fallback' {
				fallback = parse_counter_style_name_descriptor_value(value_text)
			}
			'symbols' {
				symbols = parse_counter_style_symbol_list_descriptor_value(value_text)
			}
			'additive-symbols' {
				additive_symbols = parse_counter_style_additive_symbols_descriptor_value(value_text)
			}
			'speak-as' {
				speak_as = parse_counter_style_speak_as_descriptor_value(value_text)
			}
			else {}
		}
	}

	return CSSRule.create_counter_style_rule(CSSCounterStyleRule.create(name, system, negative, prefix, suffix, range, pad, fallback, symbols, additive_symbols, speak_as))
}

fn (mut parser RuleSelectorParser) convert_to_font_face_rule(rule AtRule) ?&CSSRule {
	// https://drafts.csswg.org/css-fonts/#font-face-rule
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@font-face'
			prelude: prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@font-face'
			prelude: prelude_stream.dump_string()
			description: 'Prelude is not allowed.'
		}))
		return none
	}

	mut descriptors := []FontFaceDescriptor{}
	for declaration in declarations_from_at_rule(rule) {
		id := font_face_descriptor_id_from_property(declaration.name) or { continue }
		descriptor := parse_font_face_descriptor_for_rule_parsing(id, declaration.value) or {
			continue
		}
		append_font_face_descriptor(mut descriptors, descriptor)
	}

	return CSSRule.create_font_face_rule(CSSFontFaceRule.create(CSSFontFaceDescriptors.create(descriptors)))
}

fn (mut parser RuleSelectorParser) parse_comma_separated_family_name_list(mut tokens ParserTokenStream) ?[]string {
	mut family_names := []string{}
	comma_separated_families := parser.parse_a_comma_separated_list_of_component_values(mut tokens)

	if comma_separated_families.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@font-feature-values'
			prelude: tokens.dump_string()
			description: 'Empty family name list.'
		}))
		return none
	}

	for family_component_values in comma_separated_families {
		family_name := parse_font_family_name_for_rule_parsing(family_component_values) or {
			parser_report_error(ParsingError(InvalidRuleError{
				rule_name: '@font-feature-values'
				prelude: parser_component_values_to_string(family_component_values)
				description: 'Invalid family name.'
			}))
			return none
		}

		family_names << family_name
	}

	return family_names
}

fn (mut parser RuleSelectorParser) convert_to_font_feature_values_rule(rule AtRule) ?&CSSRule {
	// https://drafts.csswg.org/css-fonts-4/#font-feature-values-syntax
	// @font-feature-values = @font-feature-values <family-name># { <declaration-rule-list> }
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@font-feature-values'
			prelude: prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	family_names := parser.parse_comma_separated_family_name_list(mut prelude_stream) or {
		return none
	}

	mut font_feature_values_rule := CSSFontFeatureValuesRule.create(family_names)

	rule.for_each_as_declaration_rule_list(fn [mut font_feature_values_rule] (at_rule AtRule) {
		// <font-feature-value-type> = <@stylistic> | <@historical-forms> | <@styleset> | <@character-variant> | <@swash> | <@ornaments> | <@annotation>
		// @stylistic = @stylistic { <declaration-list> }
		// @historical-forms = @historical-forms { <declaration-list> }
		// @styleset = @styleset { <declaration-list> }
		// @character-variant = @character-variant { <declaration-list> }
		// @swash = @swash { <declaration-list> }
		// @ornaments = @ornaments { <declaration-list> }
		// @annotation = @annotation { <declaration-list> }
		mut feature_values_map := ?&CSSFontFeatureValuesMap(none)
		mut max_value_count := uint(1)

		if equals_ignoring_ascii_case(at_rule.name, 'stylistic') {
			feature_values_map = font_feature_values_rule.stylistic()
		} else if equals_ignoring_ascii_case(at_rule.name, 'historical-forms') {
			feature_values_map = font_feature_values_rule.historical_forms()
		} else if equals_ignoring_ascii_case(at_rule.name, 'styleset') {
			feature_values_map = font_feature_values_rule.styleset()
			max_value_count = max_u32_as_usize()
		} else if equals_ignoring_ascii_case(at_rule.name, 'character-variant') {
			feature_values_map = font_feature_values_rule.character_variant()
			max_value_count = 2
		} else if equals_ignoring_ascii_case(at_rule.name, 'swash') {
			feature_values_map = font_feature_values_rule.swash()
		} else if equals_ignoring_ascii_case(at_rule.name, 'ornaments') {
			feature_values_map = font_feature_values_rule.ornaments()
		} else if equals_ignoring_ascii_case(at_rule.name, 'annotation') {
			feature_values_map = font_feature_values_rule.annotation()
		} else {
			return
		}

		target_map := feature_values_map or { return }
		at_rule.for_each_as_declaration_list(fn [target_map, max_value_count, at_rule] (declaration Declaration) {
			if declaration.important == .yes {
				parser_report_error(ParsingError(InvalidRuleError{
					rule_name: '@${at_rule.name}'
					prelude: parser_component_values_to_string(declaration.value)
					description: 'Declarations in @font-feature-values rules cannot be marked !important.'
				}))
				return
			}

			values := parse_font_feature_values_declaration_values(declaration.value) or {
				parser_report_error(ParsingError(InvalidRuleError{
					rule_name: '@${at_rule.name}'
					prelude: parser_component_values_to_string(declaration.value)
					description: 'Feature value entry must be a non-negative integer.'
				}))
				return
			}

			if values.len == 0 {
				parser_report_error(ParsingError(InvalidRuleError{
					rule_name: '@${at_rule.name}'
					prelude: parser_component_values_to_string(declaration.value)
					description: 'Empty feature value.'
				}))
				return
			}

			if uint(values.len) > max_value_count {
				parser_report_error(ParsingError(InvalidRuleError{
					rule_name: '@${at_rule.name}'
					prelude: parser_component_values_to_string(declaration.value)
					description: 'Too many feature values provided (maximum ${max_value_count}).'
				}))
				return
			}

			mut mutable_map := unsafe { &CSSFontFeatureValuesMap(target_map) }
			mutable_map.set(declaration.name, values) or {}
		})
	}, fn (_ Declaration) {
		// FIXME: Handle the `font-display` descriptor here, see
		//        https://drafts.csswg.org/css-fonts-4/#font-display-font-feature-values
	})

	return CSSRule.create_font_feature_values_rule(font_feature_values_rule)
}

struct ParsedFunctionPrelude {
	name        string
	parameters  []FunctionParameterInternal
	return_type SyntaxNode
}

fn parse_function_css_type(mut tokens ParserTokenStream) ?SyntaxNode {
	transaction_index := tokens.index
	tokens.discard_whitespace()

	mut component_tokens := ComponentValueTokenStream.new(tokens.values[tokens.index..])
	if syntax_component := parse_syntax_component(mut component_tokens, .no) {
		tokens.index += component_tokens.index
		return syntax_component
	}

	tokens.index = transaction_index
	tokens.discard_whitespace()
	if tokens.next_token().is_function_named('type') {
		type_function := tokens.consume_a_token().function()
		if syntax := parse_as_syntax(type_function.value) {
			return syntax
		}
	}

	tokens.index = transaction_index
	return none
}

fn (mut parser RuleSelectorParser) parse_function_prelude(mut tokens ParserTokenStream) ?ParsedFunctionPrelude {
	tokens.discard_whitespace()
	function_component := tokens.consume_a_token()
	if !function_component.is_function() {
		return none
	}

	function := function_component.function()
	if !is_a_custom_property_name_string(function.name) {
		return none
	}

	mut parameters := []FunctionParameterInternal{}
	mut parameters_tokens := ParserTokenStream.from_values(function.value)
	parameters_tokens.discard_whitespace()
	if parameters_tokens.has_next_token() {
		parameter_lists := parser.parse_a_comma_separated_list_of_component_values(mut parameters_tokens)
		for parameter_values in parameter_lists {
			mut parameter_tokens := ParserTokenStream.from_values(parameter_values)
			parameter_tokens.discard_whitespace()
			name_token := parameter_tokens.consume_a_token()
			if !name_token.is(.ident)
				|| !is_a_custom_property_name_string(name_token.token().ident()) {
				return none
			}
			parameter_name := name_token.token().ident()

			mut parameter_type := SyntaxNode.create_universal()
			if parsed_type := parse_function_css_type(mut parameter_tokens) {
				parameter_type = parsed_type
			}

			parameter_tokens.discard_whitespace()
			mut default_value := ?[]ComponentValue(none)
			if parameter_tokens.next_token().is(.colon) {
				parameter_tokens.discard_a_token()
				parameter_tokens.discard_whitespace()
				parsed_default := parse_declaration_value(mut parameter_tokens, none) or {
					return none
				}

				mut default_tokens := ComponentValueTokenStream.new(parsed_default)
				_ := parse_according_to_syntax_node(mut default_tokens, parameter_type) or {
					return none
				}
				default_tokens.discard_whitespace()
				if default_tokens.has_next_token() {
					return none
				}
				default_value = parsed_default.clone()
			}

			parameter_tokens.discard_whitespace()
			if parameter_tokens.has_next_token() {
				return none
			}
			parameters << FunctionParameterInternal{
				name: parameter_name
				type_: parameter_type
				default_value: default_value
			}
		}
	}

	tokens.discard_whitespace()
	mut return_type := SyntaxNode.create_universal()
	if tokens.next_token().is(.ident)
		&& equals_ignoring_ascii_case(tokens.next_token().token().ident(), 'returns') {
		tokens.discard_a_token()
		return_type = parse_function_css_type(mut tokens) or { return none }
	}

	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}

	return ParsedFunctionPrelude{
		name: function.name
		parameters: parameters
		return_type: return_type
	}
}

fn (mut parser RuleSelectorParser) convert_to_function_declarations(declarations []Declaration) &CSSRule {
	mut descriptors := []Descriptor{}
	for declaration in declarations {
		mut descriptor_parser := Parser.from_component_values(declaration.value)
		descriptor_parser.context = parser.parsing_params()
		if descriptor := descriptor_parser.convert_to_descriptor(.function_rule, declaration) {
			append_descriptor(mut descriptors, descriptor)
		}
	}
	return CSSRule.create_function_declarations(CSSFunctionDescriptors.create(descriptors))
}

fn (mut parser RuleSelectorParser) convert_to_function_rule(rule AtRule) ?&CSSRule {
	if !rule.is_block_rule {
		return none
	}

	mut prelude_tokens := ParserTokenStream.from_values(rule.prelude)
	prelude := parser.parse_function_prelude(mut prelude_tokens) or { return none }
	mut children := []&CSSRule{}
	for child in rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				if child_rule := parser.convert_to_rule(child.rule, .yes, .function_rule) {
					children << child_rule
				}
			}
			DeclarationList {
				children << parser.convert_to_function_declarations(child.declarations)
			}
		}
	}

	return CSSRule.create_function(CSSRuleList.create(children), prelude.name, prelude.parameters,
		prelude.return_type)
}

fn (mut parser RuleSelectorParser) convert_to_page_rule(page_rule AtRule) ?&CSSRule {
	// https://drafts.csswg.org/css-page-3/#syntax-page-selector
	// @page = @page <page-selector-list>? { <declaration-rule-list> }
	mut tokens := ParserTokenStream.from_values(page_rule.prelude)
	if !page_rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@page'
			prelude: tokens.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	page_selectors := parse_page_selector_list_for_rule_parsing(mut tokens) or { return none }
	mut child_rules := []&CSSRule{}
	mut descriptors := []Descriptor{}
	for child in page_rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {
				at_rule := match child.rule {
					AtRule { child.rule }
					QualifiedRule {
						report_invalid_rule_location(InvalidRuleLocationError{
							outer_rule_name: '@page'
							inner_rule_name: 'qualified-rule'
						})
						continue
					}
				}
				if converted_rule := parser.convert_to_rule(Rule(at_rule), .no, .style) {
					if converted_rule.type_ == .margin {
						child_rules << converted_rule
					} else {
						parser_report_error(ParsingError(InvalidRuleLocationError{
							outer_rule_name: '@page'
							inner_rule_name: converted_rule.type_.class_name()
						}))
					}
				}
			}
			DeclarationList {
				for declaration in child.declarations {
					if parsed := convert_to_page_descriptor_for_rule_parsing(declaration) {
						append_page_descriptor(mut descriptors, parsed)
					}
				}
			}
		}
	}

	return CSSRule.create_page(page_selectors, CSSPageDescriptors.create(descriptors), CSSRuleList.create(child_rules))
}

fn (mut parser RuleSelectorParser) convert_to_margin_rule(rule AtRule) ?&CSSRule {
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@${rule.name}'
			prelude: prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name: '@${rule.name}'
			prelude: prelude_stream.dump_string()
			description: 'Prelude is not allowed.'
		}))
		return none
	}

	// https://drafts.csswg.org/css-page-3/#syntax-page-selector
	// There are lots of these, but they're all in the format:
	// @foo = @foo { <declaration-list> };
	//
	// FIXME: The declaration list should be a CSSMarginDescriptors, but that has no spec definition:
	//        https://github.com/w3c/csswg-drafts/issues/10106
	//        So, we just parse a CSSStyleProperties instead for now.
	style := parser.convert_to_style_declaration(declarations_from_at_rule(rule))
	return CSSRule.create_margin(rule.name, style)
}

fn (mut parser RuleSelectorParser) convert_child_rule_list(children []RuleOrListOfDeclarations, nested ParserNested, declaration_rule_kind NestedDeclarationRuleKind) []&CSSRule {
	mut child_rules := []&CSSRule{}
	for child in children {
		match child {
			RuleNode {
				if child_rule := parser.convert_to_rule(child.rule, nested, declaration_rule_kind) {
					child_rules << child_rule
				}
			}
			DeclarationList {
				if declaration_rule_kind == .function_rule {
					child_rules << parser.convert_to_function_declarations(child.declarations)
				} else {
					child_rules << CSSRule.create_nested_declarations(parser.convert_to_style_declaration(child.declarations))
				}
			}
		}
	}
	return child_rules
}

fn (mut parser RuleSelectorParser) convert_to_style_declaration(declarations ParserRuleDeclarations) &CSSStyleProperties {
	return parser.convert_to_style_declaration_with_values(declarations, []&dom.StyleValue{})
}

fn (mut parser RuleSelectorParser) convert_to_style_declaration_with_values(declarations ParserRuleDeclarations, parsed_values []&dom.StyleValue) &CSSStyleProperties {
	mut result := CSSStyleProperties.create()
	mut builder := CSSOMDeclarationBuilder{}
	params := parser.parsing_params()
	for index, declaration in declarations {
		if is_a_custom_property_name_string(declaration.name) {
			value_text := if original := declaration.original_value_text {
				if parser.raw_rules_transient { original.clone() } else { original }
			} else {
				parser_component_values_to_string(declaration.value).trim_space()
			}
			result.custom_properties[if parser.component_input_transient { declaration.name.clone() } else { declaration.name }] = StyleProperty{
				important: declaration.important
				property_id: .color
				value: parse_custom_property_components(if parser.component_input_transient { own_stylesheet_components(declaration.value) } else { declaration.value }, value_text)
			}
		} else {
			property := PropertyNameAndID.from_name(declaration.name) or { continue }
			property_id := property.id() or { continue }
			if index < parsed_values.len && parsed_values[index] != unsafe { nil } {
				append_parsed_cssom_declaration(voidptr(&builder), StyleProperty{
					important: declaration.important
					property_id: property_id
					value: parsed_values[index]
				})
				continue
			}
			// Syntax parsing already produced this immutable component tree.
			// Serializing and tokenizing it again both allocates and can merge
			// tokens separated by comments, changing the declaration's grammar.
			// Transient input is exported into independent retained payloads.
			parsed := parse_property_components_with_export(params, property_id, declaration.value,
				parser.component_input_transient) or {
				continue
			}
			append_parsed_cssom_declaration(voidptr(&builder), StyleProperty{
				important: declaration.important
				property_id: property_id
				value: dom_style_value_from_value_logic(parsed)
			})
		}
	}
	publish_cssom_declarations(voidptr(&builder), voidptr(result))
	return result
}

// Parser::DescriptorList::append(). A shorthand descriptor is expanded into its
// longhands before the "only the last instance of each descriptor is included"
// rule applies, so `@page { margin: 1cm }` records four margin descriptors and a
// later `margin-top` replaces only that one.
fn append_page_descriptor(mut descriptors []Descriptor, parsed ParsedPageDescriptor) {
	if !is_descriptor_shorthand(.page, parsed.descriptor.descriptor_name_and_id.id()) {
		append_descriptor(mut descriptors, parsed.descriptor)
		return
	}
	for expanded in expand_page_margin_shorthand_descriptor_value(parsed.style_value) {
		longhand := parse_css_descriptor_value_for_cssom(.page, expanded.descriptor_id,
			expanded.serialized_value) or { continue }
		append_descriptor(mut descriptors, Descriptor{
			descriptor_name_and_id: DescriptorNameAndID.from_id(expanded.descriptor_id)
			value: longhand.value
			serialized_value: longhand.serialized
		})
	}
}

fn append_descriptor(mut descriptors []Descriptor, descriptor Descriptor) {
	for index, existing in descriptors {
		if existing.descriptor_name_and_id == descriptor.descriptor_name_and_id {
			descriptors.delete(index)
			break
		}
	}
	descriptors << descriptor
}

fn append_font_face_descriptor(mut descriptors []FontFaceDescriptor, descriptor FontFaceDescriptor) {
	for index, existing in descriptors {
		if existing.id == descriptor.id {
			descriptors.delete(index)
			break
		}
	}
	descriptors << descriptor
}

fn parse_font_face_descriptor_for_rule_parsing(id FontFaceDescriptorID, component_values []ComponentValue) ?FontFaceDescriptor {
	if id == .font_family {
		font_family := parse_font_family_descriptor_components(component_values) or { return none }
		return FontFaceDescriptor{
			id: id
			value: font_family.serialize(.normal)
			style_value: font_family
		}
	}
	if id == .font_style {
		font_style := parse_font_style_descriptor_components(component_values) or { return none }
		return FontFaceDescriptor{
			id: id
			value: font_style.serialize(.normal)
			style_value: font_style
		}
	}
	if id == .font_weight {
		font_weight := parse_font_weight_descriptor_components(component_values) or { return none }
		return FontFaceDescriptor{
			id: id
			value: font_weight.serialize(.normal)
			style_value: font_weight
		}
	}
	if id == .font_width {
		font_width := parse_font_width_descriptor_components(component_values) or { return none }
		return FontFaceDescriptor{
			id: id
			value: font_width.serialize(.normal)
			style_value: font_width
		}
	}
	if id in [.font_feature_settings, .font_variation_settings] {
		property_id := if id == .font_feature_settings {
			PropertyID.font_feature_settings
		} else {
			PropertyID.font_variation_settings
		}
		style_value := parse_font_property_descriptor_components(component_values, property_id) or {
			return none
		}
		return FontFaceDescriptor{
			id: id
			value: style_value.serialize(.normal)
			style_value: style_value
		}
	}
	if id in [.ascent_override, .descent_override, .line_gap_override] {
		style_value := parse_font_metric_override_descriptor_components(component_values) or {
			return none
		}
		return FontFaceDescriptor{
			id: id
			value: style_value.serialize(.normal)
			style_value: style_value
		}
	}
	if id == .font_display {
		style_value := parse_font_keyword_descriptor_components(component_values, [
			'auto',
			'block',
			'swap',
			'fallback',
			'optional',
		]) or { return none }
		return FontFaceDescriptor{
			id: id
			value: style_value.serialize(.normal)
			style_value: style_value
		}
	}
	if id in [.font_language_override, .font_named_instance] {
		keyword := if id == .font_language_override { 'normal' } else { 'auto' }
		style_value := parse_font_keyword_or_string_descriptor_components(component_values, keyword) or { return none }
		return FontFaceDescriptor{
			id: id
			value: style_value.serialize(.normal)
			style_value: style_value
		}
	}
	if id == .src {
		mut value_parser := Parser.from_component_values(component_values)
		mut tokens := ComponentValueStream.new(component_values)
		sources := value_parser.parse_font_source_values(mut tokens)
		if sources.len == 0 {
			return none
		}
		return FontFaceDescriptor{
			id: id
			value: sources.map(it.serialize(.normal)).join(', ')
			font_sources: sources
		}
	}
	if id == .unicode_range {
		mut value_parser := Parser.from_component_values(component_values)
		mut tokens := ComponentValueStream.new(component_values)
		ranges := value_parser.parse_unicode_ranges(mut tokens)
		if ranges.len == 0 {
			return none
		}
		return FontFaceDescriptor{
			id: id
			value: ranges.map(it.to_css_string()).join(', ')
			unicode_ranges: ranges
		}
	}
	value := parser_component_values_to_string(component_values).trim_space()
	parsed := parse_font_face_descriptor(id, value) or { return none }
	return FontFaceDescriptor{
		id: id
		value: parsed
	}
}

fn parse_font_family_name_for_rule_parsing(values []ComponentValue) ?string {
	mut tokens := ParserTokenStream.from_values(values)
	tokens.discard_whitespace()
	first := tokens.next_token()
	if first.is(.string) {
		tokens.discard_a_token()
		tokens.discard_whitespace()
		if tokens.has_next_token() {
			return none
		}
		return first.token().string_value()
	}

	mut parts := []string{}
	for tokens.has_next_token() {
		tokens.discard_whitespace()
		if !tokens.next_token().is(.ident) {
			break
		}
		parts << tokens.consume_a_token().token().ident()
	}
	tokens.discard_whitespace()
	if parts.len == 0 || tokens.has_next_token() {
		return none
	}
	if parts.len == 1 {
		if !is_valid_custom_ident(parts[0], []) {
			return none
		}
		if is_generic_font_family_name(parts[0]) {
			return none
		}
	}
	return parts.join(' ')
}

fn is_generic_font_family_name(name string) bool {
	return name.to_lower() in ['serif', 'sans-serif', 'monospace', 'cursive', 'fantasy', 'system-ui',
		'ui-serif', 'ui-sans-serif', 'ui-monospace', 'ui-rounded', 'math', 'emoji', 'fangsong']
}

fn parse_font_feature_values_declaration_values(values []ComponentValue) ?[]u32 {
	mut tokens := ParserTokenStream.from_values(values)
	tokens.discard_whitespace()
	mut result := []u32{}
	for tokens.has_next_token() {
		token := tokens.consume_a_token()
		if !token.is(.number) || !token.token().number().is_integer()
			|| token.token().number().integer_value() < 0 {
			return none
		}
		result << u32(token.token().number().integer_value())
		tokens.discard_whitespace()
	}
	return result
}

fn (mut parser RuleSelectorParser) parse_counter_style_name(mut tokens ParserTokenStream) ?string {
	return parse_counter_style_name_from_tokens(mut tokens)
}

fn parse_counter_style_name_from_tokens(mut tokens ParserTokenStream) ?string {
	// https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style-name
	// <counter-style-name> is a <custom-ident> that is not an ASCII case-insensitive match for none.
	transaction_index := tokens.index
	tokens.discard_whitespace()
	token := tokens.consume_a_token()
	if !token.is(.ident) || !is_valid_custom_ident(token.token().ident(), ['none']) {
		tokens.index = transaction_index
		return none
	}
	mut custom_ident := token.token().ident()

	// https://drafts.csswg.org/css-counter-styles-3/#the-counter-style-rule
	// Counter style names are case-sensitive. However, the names defined in this specification are ASCII lowercased
	// on parse wherever they are used as counter styles, e.g. in the list-style set of properties, in the
	// @counter-style rule, and in the counter() functions.
	if is_predefined_counter_style_name(custom_ident) {
		custom_ident = custom_ident.to_lower()
	}

	return custom_ident
}

fn is_predefined_counter_style_name(name string) bool {
	return name.to_lower() in ['decimal', 'disc', 'square', 'circle', 'disclosure-open',
		'disclosure-closed']
}

fn css_counter_style_rule_matches_non_overridable_counter_style_name(name string) bool {
	// The non-overridable counter-style names are the keywords decimal, disc, square, circle, disclosure-open, and disclosure-closed.
	return name.to_lower() in ['decimal', 'disc', 'square', 'circle', 'disclosure-open',
		'disclosure-closed']
}

fn parse_counter_style_system_descriptor_value(value string) ?CounterStyleSystemStyleValue {
	mut tokens := ParserTokenStream.from_values(parse_component_values_for_value_logic(value))
	tokens.discard_whitespace()
	if !tokens.has_next_token() {
		return none
	}
	first := tokens.consume_a_token()
	if !first.is(.ident) {
		return none
	}
	lower := first.token().ident().to_lower()
	if lower == 'fixed' {
		tokens.discard_whitespace()
		mut first_symbol := ?StyleValue(none)
		if tokens.has_next_token() {
			first_symbol = parse_counter_style_integer_value(mut tokens) or { return none }
			tokens.discard_whitespace()
			if tokens.has_next_token() {
				return none
			}
		}
		return CounterStyleSystemStyleValue.create_fixed(first_symbol)
	}
	if lower == 'extends' {
		tokens.discard_whitespace()
		name := parse_counter_style_name_from_tokens(mut tokens) or { return none }
		tokens.discard_whitespace()
		if tokens.has_next_token() {
			return none
		}
		return CounterStyleSystemStyleValue.create_extends(name)
	}
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return match lower {
		'cyclic' { CounterStyleSystemStyleValue.create(.cyclic) }
		'numeric' { CounterStyleSystemStyleValue.create(.numeric) }
		'alphabetic' { CounterStyleSystemStyleValue.create(.alphabetic) }
		'symbolic' { CounterStyleSystemStyleValue.create(.symbolic) }
		'additive' { CounterStyleSystemStyleValue.create(.additive) }
		else { none }
	}
}

// ValueParsing.cpp: Parser::parse_symbol_value.
fn parse_symbol_value(mut tokens ParserTokenStream) ?StyleValue {
	// https://drafts.csswg.org/css-counter-styles-3/#typedef-symbol
	// <symbol> = <string> | <image> | <custom-ident>
	// Note: The <image> syntax in <symbol> is currently at-risk. No implementations have plans to implement it
	//       currently, and it complicates some usages of counter() in ways that haven’t been fully handled.
	// NB: Given the above we don't currently support <image> here - we may need to revisit this if other browsers implement it.
	tokens.discard_whitespace()
	token := tokens.consume_a_token()
	if token.is(.string) {
		return StyleValue(StringStyleValue.create(token.token().string_value()))
	}
	if token.is(.ident) {
		ident := token.token().ident()
		if keyword := keyword_from_string(ident) {
			if keyword.is_css_wide_keyword() {
				return none
			}
		}
		return StyleValue(CustomIdentStyleValue.create(ident))
	}
	return none
}

fn parse_counter_style_symbol_descriptor_value(value string) ?StyleValue {
	mut tokens := ParserTokenStream.from_values(parse_component_values_for_value_logic(value))
	symbol := parse_symbol_value(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return symbol
}

fn parse_counter_style_name_descriptor_value(value string) ?StyleValue {
	mut tokens := ParserTokenStream.from_values(parse_component_values_for_value_logic(value))
	name := parse_counter_style_name_from_tokens(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return StyleValue(CustomIdentStyleValue.create(name))
}

fn parse_counter_style_speak_as_descriptor_value(value string) ?StyleValue {
	// speak-as accepts keywords plus <counter-style-name>. This V translation does not have a dedicated
	// CounterStyleSpeakAsStyleValue, so keep the parsed ident as a typed custom-ident boundary.
	return parse_counter_style_name_descriptor_value(value)
}

fn parse_counter_style_symbol_list_descriptor_value(value string) ?CounterStyleSymbolListStyleValue {
	mut tokens := ParserTokenStream.from_values(parse_component_values_for_value_logic(value))
	mut symbols := []StyleValue{}
	tokens.discard_whitespace()
	for tokens.has_next_token() {
		symbol := parse_symbol_value(mut tokens) or { return none }
		symbols << symbol
		tokens.discard_whitespace()
	}
	if symbols.len == 0 {
		return none
	}
	return CounterStyleSymbolListStyleValue.create(symbols)
}

fn parse_counter_style_integer_value(mut tokens ParserTokenStream) ?StyleValue {
	tokens.discard_whitespace()
	token := tokens.consume_a_token()
	if !token.is(.number) || !token.token().number().is_integer() {
		return none
	}
	return StyleValue(IntegerStyleValue.create(token.token().number().integer_value()))
}

fn parse_counter_style_nonnegative_integer_value(mut tokens ParserTokenStream) ?StyleValue {
	value := parse_counter_style_integer_value(mut tokens) or { return none }
	if value.as_integer().integer() < 0 {
		return none
	}
	return value
}

fn parse_counter_style_range_bound(mut tokens ParserTokenStream) ?CounterStyleRangeBound {
	tokens.discard_whitespace()
	token := tokens.next_token()
	if token.is(.ident) && equals_ignoring_ascii_case(token.token().ident(), 'infinite') {
		tokens.consume_a_token()
		return CounterStyleRangeBound(CounterStyleInfinite{})
	}
	return CounterStyleRangeBound(parse_counter_style_integer_value(mut tokens) or { return none })
}

fn counter_style_range_bound_to_i64(bound CounterStyleRangeBound, infinite_value i64) i64 {
	return match bound {
		CounterStyleInfinite { infinite_value }
		StyleValue { bound.as_integer().integer() }
	}
}

fn parse_counter_style_range_entry(mut tokens ParserTokenStream) ?CounterStyleRangeStyleValueEntry {
	first_value := parse_counter_style_range_bound(mut tokens) or { return none }
	second_value := parse_counter_style_range_bound(mut tokens) or { return none }

	// If the lower bound of any range is higher than the upper bound, the entire descriptor is
	// invalid and must be ignored.
	first_int := counter_style_range_bound_to_i64(first_value, counter_i64_min)
	second_int := counter_style_range_bound_to_i64(second_value, counter_i64_max)
	if first_int > second_int {
		return none
	}

	return CounterStyleRangeStyleValueEntry{
		start: first_value
		end: second_value
	}
}

fn parse_counter_style_range_descriptor_value(value string) ?CounterStyleRangeStyleValue {
	mut tokens := ParserTokenStream.from_values(parse_component_values_for_value_logic(value))
	tokens.discard_whitespace()
	if !tokens.has_next_token() {
		return none
	}
	if tokens.next_token().is(.ident)
		&& equals_ignoring_ascii_case(tokens.next_token().token().ident(), 'auto') {
		tokens.consume_a_token()
		tokens.discard_whitespace()
		if tokens.has_next_token() {
			return none
		}
		return CounterStyleRangeStyleValue.create_auto()
	}

	mut entries := []CounterStyleRangeStyleValueEntry{}
	for {
		entries << parse_counter_style_range_entry(mut tokens) or { return none }
		tokens.discard_whitespace()
		if !tokens.has_next_token() {
			break
		}
		if !tokens.consume_a_token().is(.comma) {
			return none
		}
		tokens.discard_whitespace()
	}
	return CounterStyleRangeStyleValue.create(entries)
}

// ValueParsing.cpp: Parser::parse_nonnegative_integer_symbol_pair_value.
fn parse_nonnegative_integer_symbol_pair_value(mut tokens ParserTokenStream) ?CounterStyleAdditiveSymbolTupleStyleValue {
	// [ <integer [0,∞]> && <symbol> ]
	mut integer := ?StyleValue(none)
	mut symbol := ?StyleValue(none)

	for tokens.has_next_token() {
		start_index := tokens.index
		if integer_value := parse_counter_style_nonnegative_integer_value(mut tokens) {
			if integer != none {
				return none
			}
			integer = integer_value
			tokens.discard_whitespace()
			continue
		}
		tokens.index = start_index

		if symbol_value := parse_symbol_value(mut tokens) {
			if symbol != none {
				return none
			}
			symbol = symbol_value
			tokens.discard_whitespace()
			continue
		}
		tokens.index = start_index
		break
	}

	integer_value := integer or { return none }
	symbol_value := symbol or { return none }
	return CounterStyleAdditiveSymbolTupleStyleValue{
		weight: integer_value
		symbol: symbol_value
	}
}

fn parse_counter_style_pad_descriptor_value(value string) ?CounterStylePadStyleValue {
	mut tokens := ParserTokenStream.from_values(parse_component_values_for_value_logic(value))
	pair := parse_nonnegative_integer_symbol_pair_value(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return CounterStylePadStyleValue.create(pair.weight, pair.symbol)
}

fn parse_counter_style_additive_symbols_descriptor_value(value string) ?CounterStyleAdditiveSymbolsStyleValue {
	mut tokens := ParserTokenStream.from_values(parse_component_values_for_value_logic(value))
	mut tuples := []CounterStyleAdditiveSymbolTupleStyleValue{}
	mut previous_weight := counter_i64_max
	for {
		tuple := parse_nonnegative_integer_symbol_pair_value(mut tokens) or {
			return none
		}
		weight := tuple.weight.as_integer().integer()
		// Each entry in the additive-symbols descriptor’s value defines an additive tuple, which consists
		// of a counter symbol and an integer weight. Each weight must be a non-negative integer, and the
		// additive tuples must be specified in order of strictly descending weight; otherwise, the
		// declaration is invalid and must be ignored.
		if weight >= previous_weight {
			return none
		}
		previous_weight = weight
		tuples << tuple
		tokens.discard_whitespace()
		if !tokens.has_next_token() {
			break
		}
		if !tokens.consume_a_token().is(.comma) {
			return none
		}
		tokens.discard_whitespace()
	}
	if tuples.len == 0 {
		return none
	}
	return CounterStyleAdditiveSymbolsStyleValue.create(tuples)
}

fn parse_page_selector_list_for_rule_parsing(mut tokens ParserTokenStream) ?PageSelectorList {
	text := tokens.dump_string().trim_space()
	tokens.index = tokens.values.len
	return parse_page_selector_list(text)
}

struct ParsedPageDescriptor {
	descriptor  Descriptor
	style_value StyleValue
}

fn convert_to_page_descriptor_for_rule_parsing(declaration Declaration) ?ParsedPageDescriptor {
	descriptor_id := descriptor_id_from_string(.page, declaration.name) or { return none }
	value_text := parser_component_values_to_string(declaration.value).trim_space()
	value := parse_css_descriptor_value_for_cssom(.page, descriptor_id, value_text) or {
		return none
	}
	return ParsedPageDescriptor{
		descriptor: Descriptor{
			descriptor_name_and_id: DescriptorNameAndID.from_id(descriptor_id)
			value: value.value
			serialized_value: value.serialized
		}
		style_value: value.style_value
	}
}

fn declarations_from_at_rule(rule AtRule) ParserRuleDeclarations {
	mut declarations := []Declaration{}
	// Keep the declaration vector in the caller's frame. Capturing a mutable dynamic array in a V
	// function value copies its header, so appending in the visitor mutated only the capture and made
	// descriptor at-rules (notably every @counter-style in Default.css) appear empty.
	for child in rule.child_rules_and_lists_of_declarations {
		match child {
			RuleNode {}
			DeclarationList {
				declarations << child.declarations
			}
		}
	}
	return declarations
}

fn (mut parser RuleSelectorParser) parse_layer_name(mut tokens ParserTokenStream, allow_blank_layer_name AllowBlankLayerName) ?string {
	// https://drafts.csswg.org/css-cascade-5/#typedef-layer-name
	// <layer-name> = <ident> [ '.' <ident> ]*
	tokens.discard_whitespace()
	if !tokens.has_next_token() && allow_blank_layer_name == .yes {
		return ''
	}
	first_name_token := tokens.consume_a_token()
	if !parser_is_valid_layer_name_part(first_name_token) {
		return none
	}
	mut builder := first_name_token.token().ident()
	for tokens.has_next_token() {
		if !tokens.next_token().is_delim(u32(`.`)) {
			break
		}
		tokens.discard_a_token()
		name_token := tokens.consume_a_token()
		if !parser_is_valid_layer_name_part(name_token) {
			return none
		}
		builder += '.${name_token.token().ident()}'
	}
	return builder
}

fn (mut parser RuleSelectorParser) parse_a_selector_list(mut tokens ParserTokenStream, mode ParserSelectorType, parsing_mode SelectorParsingMode) ?SelectorList {
	mut selectors := SelectorList{}
	for {
		selector_text := parser.consume_selector_source(mut tokens)
		if selector_text.len == 0 {
			if parsing_mode == .forgiving {
				selectors.selectors << selector_from_text('')
			} else {
				return none
			}
		} else if selector := parser.parse_memoized_rule_selector(selector_text, mode) {
			selectors.selectors << selector
		} else if parsing_mode == .forgiving {
			selectors.selectors << create_selector(selector_text, [CompoundSelector{
				simple_selectors: [invalid_simple_selector(selector_text)]
			}])
		} else {
			return none
		}

		if tokens.is_empty() {
			break
		}
		tokens.discard_a_token()
	}

	if selectors.is_empty() && parsing_mode != .forgiving {
		return none
	}
	return selectors
}

fn parser_parse_url_or_string(mut tokens ParserTokenStream) ?string {
	token := tokens.consume_a_token()
	if token.is(.url) {
		return token.token().url()
	}
	if token.is(.string) {
		return token.token().string_value()
	}
	if token.is_function_named('url') {
		function := token.function()
		return parser_component_values_to_string(function.value).trim_space().trim('"').trim("'")
	}
	return none
}

fn parser_strip_important(mut declaration Declaration) {
	if declaration.value.len < 2 {
		return
	}
	mut important_index := -1
	for i := declaration.value.len - 1; i > 0; i-- {
		value := declaration.value[i]
		if value.is_ident('important') {
			important_index = i
			break
		}
		if !value.is(.whitespace) {
			break
		}
	}
	if important_index < 0 {
		return
	}
	mut bang_index := -1
	for i := important_index - 1; i > 0; i-- {
		value := declaration.value[i]
		if value.is_delim(u32(`!`)) {
			bang_index = i
			break
		}
		if value.is(.whitespace) {
			continue
		}
		break
	}
	if bang_index >= 0 {
		// Both removed tokens and the intervening/trailing whitespace are a
		// suffix. Keep the shared syntax-cache input immutable.
		declaration.value = declaration.value[..bang_index]
		declaration.important = .yes
	}
}

fn declaration_contains_a_curly_block_and_non_whitespace(declaration_value []ComponentValue) bool {
	mut contains_curly_block := false
	mut contains_non_whitespace := false
	for value in declaration_value {
		if value.is_block() && value.block().is_curly() {
			if contains_non_whitespace {
				return true
			}
			contains_curly_block = true
			continue
		}
		if !value.is(.whitespace) {
			if contains_curly_block {
				return true
			}
			contains_non_whitespace = true
			continue
		}
	}
	return false
}

// Reconstruct a selector prelude as text.
//
// `Token::to_string()` alone is not enough: it serializes a <number> from its
// value, so the explicit `+` in `:nth-child(2n+1)` is lost and the selector
// arrives as the invalid `:nth-child(2n1)`. Upstream never notices, because
// `Parser::parse_a_selector_list()` consumes the component values directly
// instead of rebuilding text. The original source text alone is not enough
// either: it leaves escapes undecoded, so `[\61 =b]` would not match the `a`
// attribute. Numeric tokens cannot contain escapes and identifier-like tokens
// cannot carry a sign, so take each from the side that preserves it.
fn parser_selector_prelude_to_string(values []ComponentValue) string {
	mut builder := strings.new_builder(values.len * 8)
	for value in values {
		parser_append_selector_prelude_component(mut builder, value)
	}
	return builder.str()
}


fn parser_append_selector_prelude_component(mut builder strings.Builder, value ComponentValue) {
	if value.value is &Token {
		token := value.token()
		if token.type_ in [TokenType.number, .percentage, .dimension] {
			original := token.original_source_text()
			if original.len > 0 {
				builder.write_string(original)
				return
			}
		}
		builder.write_string(token.to_string())
	} else if value.value is &SimpleBlock {
		block := value.block()
		builder.write_string(block.token.bracket_string())
		for item in block.value {
			parser_append_selector_prelude_component(mut builder, item)
		}
		builder.write_string(block.token.bracket_mirror_string())
	} else if value.value is &Function {
		function := value.function()
		builder.write_string(serialize_an_identifier(function.name))
		builder.write_u8(`(`)
		for item in function.value {
			parser_append_selector_prelude_component(mut builder, item)
		}
		builder.write_u8(`)`)
	} else {
		builder.write_string(value.to_string())
	}
}

fn parser_component_values_to_string(values []ComponentValue) string {
	mut builder := strings.new_builder(values.len * 8)
	for value in values {
		if value.is(.end_of_file) {
			continue
		}
		builder.write_string(value.to_string())
	}
	return builder.str()
}

fn parser_component_values_original_text(values []ComponentValue) string {
	$if prealloc {
		// Nested blocks and functions assemble intermediate strings. Only the
		// final source spelling belongs to the declaration's owner.
		scratch := platform.begin_thread_scratch('CSS component source serialization')
		text := assemble_component_values_original_text(values)
		scratch.leave()
		owned := text.clone()
		scratch.finish()
		return owned
	}
	return assemble_component_values_original_text(values)
}

fn assemble_component_values_original_text(values []ComponentValue) string {
	mut builder := strings.new_builder(values.len * 8)
	if !disable_flat_component_source && flat_component_source_diagnostics && !flat_component_source_reported {
		flat_component_source_reported = true
		eprintln('Vox CSS source: serialized nested components into one builder')
	}
	for index in 0 .. values.len {
		value := unsafe { &values[index] }
		if disable_flat_component_source { builder.write_string(value.original_source_text()) }
		else { append_component_original_text(mut builder, value) }
	}
	return builder.str()
}

fn append_component_original_text(mut builder strings.Builder, component &ComponentValue) {
	if component.value is &Token {
		builder.write_string(component.value.original_source_text())
	} else if component.value is &Function {
		builder.write_string(component.value.name_token.original_source_text())
		for index in 0 .. component.value.value.len {
			append_component_original_text(mut builder, unsafe { &component.value.value[index] })
		}
		builder.write_string(component.value.end_token.original_source_text())
	} else if component.value is &SimpleBlock {
		builder.write_string(component.value.token.original_source_text())
		for index in 0 .. component.value.value.len {
			append_component_original_text(mut builder, unsafe { &component.value.value[index] })
		}
		builder.write_string(component.value.end_token.original_source_text())
	} else if component.value is RawComponentValue {
		builder.write_string(component.value.text)
	} else if component.value is GuaranteedInvalidValue {
	}
}

fn parser_is_valid_layer_name_part(token ComponentValue) bool {
	return token.is(.ident) && !is_css_wide_keyword_local(token.token().ident())
}

// A trailing combinator or comma leaves a selector incomplete, but an escaped
// one is part of the final identifier: `.mobileOnly\+` names class `mobileOnly+`.
// The character is escaped when an odd number of reverse solidi precede it.
fn selector_text_ends_with_unescaped_separator(text string) bool {
	if text.len == 0 || text[text.len - 1] !in [`>`, `+`, `~`, `,`] {
		return false
	}
	mut solidi := 0
	for index := text.len - 2; index >= 0 && text[index] == `\\`; index-- {
		solidi++
	}
	return solidi % 2 == 0
}

fn parser_parse_validated_selector(selector_text string, mode ParserSelectorType, declared_namespaces map[string]bool) ?Selector {
	trimmed := selector_text.trim_space()
	if trimmed.len == 0 {
		return none
	}
	if mode == .standalone && (trimmed.starts_with('>') || trimmed.starts_with('+')
		|| trimmed.starts_with('~')) {
		return none
	}
	if selector_text_ends_with_unescaped_separator(trimmed) {
		return none
	}
	if !parser_balanced_selector_text(trimmed) {
		return none
	}
	// Syntax validation, namespace validation and the returned selector must
	// share one graph instead of parsing the same complex selector three times.
	mut selector := selector_from_text(trimmed)
	compounds := selector.compound_selectors()
	if parsed_selector_has_invalid_simple_selectors(trimmed, compounds, mode == .relative)
		|| parser_selector_value_uses_undeclared_namespace(selector, declared_namespaces) {
		return none
	}
	if mode == .relative && compounds.len > 0 && compounds[0].combinator == .no_combinator {
		mut adapted := compounds.clone()
		adapted[0].combinator = .descendant
		selector = selector_from_compound_selectors(adapted)
	}
	return selector
}

fn parser_balanced_selector_text(text string) bool {
	mut parens := 0
	mut squares := 0
	mut quote := u8(0)
	mut i := 0
	for i < text.len {
		ch := text[i]
		if quote != 0 {
			if ch == `\\` && i + 1 < text.len {
				i += 2
				continue
			}
			if ch == quote {
				quote = 0
			}
			i++
			continue
		}
		if ch == `\\` && i + 1 < text.len {
			// Escaped brackets are identifier code points.
			i += 2
			continue
		}
		match ch {
			`"`, `'` {
				quote = ch
			}
			`(` { parens++ }
			`)` { parens-- }
			`[` { squares++ }
			`]` { squares-- }
			else {}
		}

		if parens < 0 || squares < 0 {
			return false
		}
		i++
	}
	return parens == 0 && squares == 0 && quote == 0
}

fn parser_simple_selector_uses_undeclared_namespace(simple_selector SimpleSelector, declared_namespaces map[string]bool) bool {
	match simple_selector.type_ {
		.tag_name, .universal {
			return parser_qualified_name_uses_undeclared_namespace(simple_selector.qualified_name(), declared_namespaces)
		}
		.attribute {
			return parser_qualified_name_uses_undeclared_namespace(simple_selector.attribute().qualified_name, declared_namespaces)
		}
		.pseudo_class {
			for selector in simple_selector.pseudo_class().argument_selector_list.selectors {
				if parser_selector_value_uses_undeclared_namespace(selector, declared_namespaces) {
					return true
				}
			}
		}
		.pseudo_element {
			if selector := simple_selector.pseudo_element().compound_selector {
				return parser_selector_value_uses_undeclared_namespace(selector, declared_namespaces)
			}
		}
		else {}
	}

	return false
}

fn parser_selector_value_uses_undeclared_namespace(selector Selector, declared_namespaces map[string]bool) bool {
	for compound_selector in selector.compound_selectors() {
		for simple_selector in compound_selector.simple_selectors {
			if parser_simple_selector_uses_undeclared_namespace(simple_selector, declared_namespaces) {
				return true
			}
		}
	}
	return false
}

fn parser_qualified_name_uses_undeclared_namespace(qualified_name SelectorQualifiedName, declared_namespaces map[string]bool) bool {
	return qualified_name.namespace_type == .named
		&& qualified_name.namespace_ !in declared_namespaces
}

fn (parser RuleSelectorParser) is_valid_declaration_in_the_current_context(declaration Declaration) bool {
	if declaration.name.len == 0 {
		return false
	}

	if parser.rule_context.len == 0 {
		return false
	}

	last_context := parser.rule_context[parser.rule_context.len - 1]
	return match last_context {
		.unknown { false }
		.style, .scope, .function_rule { true }
		.keyframe {
			property := PropertyNameAndID.from_name(declaration.name) or { return true }
			property_id := property.id() or { return true }
			property_id !in [.animation, .animation_delay, .animation_direction, .animation_duration,
				.animation_fill_mode, .animation_iteration_count, .animation_name,
				.animation_play_state, .animation_timeline]
		}
		.container_rule, .layer, .media, .supports {
			rule_context_contains(parser.rule_context, .style)
				|| rule_context_contains(parser.rule_context, .scope)
				|| rule_context_contains(parser.rule_context, .function_rule)
		}
		.font_feature_value { true }
		.counter_style, .font_face, .font_feature_values, .page, .property, .margin { true }
		.keyframes { false }
		.supports_condition { true }
	}
}

fn (parser RuleSelectorParser) is_valid_at_rule_in_the_current_context(rule AtRule) bool {
	if parser.rule_context.len == 0 {
		return !is_margin_rule_name(rule.name)
	}

	if rule_context_contains(parser.rule_context, .style) {
		return ascii_case_insensitive_name_is_one_of(rule.name, ['container', 'layer', 'media',
			'scope', 'supports'])
	}
	if rule_context_contains(parser.rule_context, .function_rule) {
		return ascii_case_insensitive_name_is_one_of(rule.name, ['container', 'media', 'supports'])
	}

	last_context := parser.rule_context[parser.rule_context.len - 1]
	return match last_context {
		.unknown {
			false
		}
		.style {
			false
		}
		.function_rule {
			ascii_case_insensitive_name_is_one_of(rule.name, ['media', 'supports'])
		}
		.container_rule, .layer, .media, .scope, .supports {
			!ascii_case_insensitive_name_is_one_of(rule.name, ['import', 'namespace'])
		}
		.supports_condition {
			false
		}
		.page {
			is_margin_rule_name(rule.name)
		}
		.counter_style, .font_face, .font_feature_value, .keyframes, .keyframe, .property, .margin {
			false
		}
		.font_feature_values {
			is_font_feature_value_type_at_keyword_local(rule.name)
		}
	}
}

fn (parser RuleSelectorParser) is_valid_qualified_rule_in_the_current_context(rule QualifiedRule) bool {
	_ = rule
	if parser.rule_context.len == 0 {
		return true
	}

	last_context := parser.rule_context[parser.rule_context.len - 1]
	return match last_context {
		.unknown {
			false
		}
		.style {
			true
		}
		.container_rule, .layer, .media, .scope, .supports {
			true
		}
		.keyframes {
			true
		}
		.supports_condition {
			false
		}
		.counter_style, .font_face, .font_feature_values, .font_feature_value, .function_rule, .page, .property, .keyframe, .margin {
			false
		}
	}
}

fn rule_context_type_for_at_rule_local(name string) RuleContext {
	if equals_ignoring_ascii_case(name, 'media') {
		return .media
	}
	if equals_ignoring_ascii_case(name, 'container') {
		return .container_rule
	}
	if equals_ignoring_ascii_case(name, 'counter-style') {
		return .counter_style
	}
	if equals_ignoring_ascii_case(name, 'font-face') {
		return .font_face
	}
	if equals_ignoring_ascii_case(name, 'keyframes')
		|| equals_ignoring_ascii_case(name, '-webkit-keyframes') {
		return .keyframes
	}
	if equals_ignoring_ascii_case(name, 'font-feature-values') {
		return .font_feature_values
	}
	if equals_ignoring_ascii_case(name, 'function') {
		return .function_rule
	}
	if is_font_feature_value_type_at_keyword_local(name) {
		return .font_feature_value
	}
	if equals_ignoring_ascii_case(name, 'supports') {
		return .supports
	}
	if equals_ignoring_ascii_case(name, 'scope') {
		return .scope
	}
	if equals_ignoring_ascii_case(name, 'layer') {
		return .layer
	}
	if equals_ignoring_ascii_case(name, 'property') {
		return .property
	}
	if equals_ignoring_ascii_case(name, 'page') {
		return .page
	}
	if is_margin_rule_name(name) {
		return .margin
	}
	return .unknown
}

fn ascii_case_insensitive_name_is_one_of(name string, names []string) bool {
	for candidate in names {
		if equals_ignoring_ascii_case(name, candidate) {
			return true
		}
	}
	return false
}

fn rule_context_contains(context []RuleContext, target RuleContext) bool {
	for item in context {
		if item == target {
			return true
		}
	}
	return false
}

fn is_font_feature_value_type_at_keyword_local(name string) bool {
	return ascii_case_insensitive_name_is_one_of(name, [
		'stylistic',
		'historical-forms',
		'styleset',
		'character-variant',
		'swash',
		'ornaments',
		'annotation',
	])
}

// The corresponding upstream call is guarded by CSS_PARSER_DEBUG. Keep the
// production build silent when that diagnostic flag is disabled.
fn parser_log_parse_error() {}

pub struct UnknownPropertyError {
pub:
	rule_name     string = 'style'
	property_name string
}

pub struct UnknownRuleError {
pub:
	rule_name string
}

pub struct UnknownMediaFeatureError {
pub:
	media_feature_name string
}

pub struct UnknownPseudoClassOrElementError {
pub:
	rule_name string = 'style'
	name      string
}

pub struct InvalidPropertyError {
pub:
	rule_name     string = 'style'
	property_name string
	value_string  string
	description   string
}

pub struct InvalidValueError {
pub:
	value_type   string
	value_string string
	description  string
}

pub struct InvalidRuleError {
pub:
	rule_name   string
	prelude     string
	description string
}

pub struct InvalidQueryError {
pub:
	query_type   string = '@media'
	value_string string
	description  string
}

pub struct InvalidSelectorError {
pub:
	rule_name    string = 'style'
	value_string string
	description  string
}

pub struct InvalidPseudoClassOrElementError {
pub:
	name         string
	value_string string
	description  string
}

pub type ParsingError = InvalidPropertyError
	| InvalidRuleLocationError
	| InvalidPseudoClassOrElementError
	| InvalidQueryError
	| InvalidRuleError
	| InvalidSelectorError
	| InvalidValueError
	| UnknownMediaFeatureError
	| UnknownPropertyError
	| UnknownPseudoClassOrElementError
	| UnknownRuleError

pub struct ParsingErrorMetadata {
pub:
	message     string
	occurrences u32 = 1
}

@[heap]
pub struct ErrorReporter {
mut:
	errors map[string]ParsingErrorMetadata
}

__global css_error_reporter = &ErrorReporter{
	errors: map[string]ParsingErrorMetadata{}
}

pub fn ErrorReporter.the() &ErrorReporter {
	return css_error_reporter
}

// ParsingError is a tagged union of records. Upstream uses the complete record
// as its HashMap key, including fields that are intentionally omitted from the
// human-readable message. Build the same collision-free identity here rather
// than using serialize_parsing_error() as the key.
fn parsing_error_key_field(value string) string {
	return '${value.len}:${value}'
}

fn parsing_error_key(error ParsingError) string {
	return match error {
		UnknownPropertyError {
			'unknown-property:${parsing_error_key_field(error.rule_name)}${parsing_error_key_field(error.property_name)}'
		}
		UnknownRuleError {
			'unknown-rule:${parsing_error_key_field(error.rule_name)}'
		}
		UnknownMediaFeatureError {
			'unknown-media-feature:${parsing_error_key_field(error.media_feature_name)}'
		}
		UnknownPseudoClassOrElementError {
			'unknown-pseudo:${parsing_error_key_field(error.rule_name)}${parsing_error_key_field(error.name)}'
		}
		InvalidPropertyError {
			'invalid-property:${parsing_error_key_field(error.rule_name)}${parsing_error_key_field(error.property_name)}${parsing_error_key_field(error.value_string)}${parsing_error_key_field(error.description)}'
		}
		InvalidValueError {
			'invalid-value:${parsing_error_key_field(error.value_type)}${parsing_error_key_field(error.value_string)}${parsing_error_key_field(error.description)}'
		}
		InvalidRuleError {
			'invalid-rule:${parsing_error_key_field(error.rule_name)}${parsing_error_key_field(error.prelude)}${parsing_error_key_field(error.description)}'
		}
		InvalidQueryError {
			'invalid-query:${parsing_error_key_field(error.query_type)}${parsing_error_key_field(error.value_string)}${parsing_error_key_field(error.description)}'
		}
		InvalidSelectorError {
			'invalid-selector:${parsing_error_key_field(error.rule_name)}${parsing_error_key_field(error.value_string)}${parsing_error_key_field(error.description)}'
		}
		InvalidPseudoClassOrElementError {
			'invalid-pseudo:${parsing_error_key_field(error.name)}${parsing_error_key_field(error.value_string)}${parsing_error_key_field(error.description)}'
		}
		InvalidRuleLocationError {
			'invalid-rule-location:${parsing_error_key_field(error.outer_rule_name)}${parsing_error_key_field(error.inner_rule_name)}'
		}
	}
}

pub fn serialize_parsing_error(error ParsingError) string {
	return match error {
		UnknownPropertyError {
			"Unknown property '${error.property_name}' in ${error.rule_name} rule."
		}
		UnknownRuleError {
			"Unknown rule '${error.rule_name}'."
		}
		UnknownMediaFeatureError {
			"Unknown media feature '${error.media_feature_name}'."
		}
		UnknownPseudoClassOrElementError {
			"Unknown pseudo class or element '${error.name}' in ${error.rule_name} selector."
		}
		InvalidPropertyError {
			"Property '${error.property_name}' in ${error.rule_name} rule has invalid value `${error.value_string}`."
		}
		InvalidValueError {
			'Unable to parse ${error.value_type} from `${error.value_string}`: ${error.description}'
		}
		InvalidRuleError {
			"'${error.rule_name}' rule with prelude `${error.prelude}` is invalid: ${error.description}"
		}
		InvalidQueryError {
			"'${error.query_type}' query `${error.value_string}` is invalid: ${error.description}"
		}
		InvalidSelectorError {
			'${error.rule_name} selector `${error.value_string}` is invalid: ${error.description}'
		}
		InvalidPseudoClassOrElementError {
			"Pseudo '${error.name}' value `${error.value_string}` is invalid: ${error.description}"
		}
		InvalidRuleLocationError {
			"'${error.inner_rule_name}' rule is invalid inside ${error.outer_rule_name}"
		}
	}
}

pub fn (mut reporter ErrorReporter) report(error ParsingError) {
	key := parsing_error_key(error)
	// Updating an existing key can rehash the map too. All backing storage
	// belongs to the reporter, independently of the current parser/document.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if existing := reporter.errors[key] {
		reporter.errors[key] = ParsingErrorMetadata{
			...existing
			occurrences: existing.occurrences + 1
		}
		return
	}
	reporter.errors[key.clone()] = ParsingErrorMetadata{
		message: serialize_parsing_error(error)
	}
}

pub fn (reporter &ErrorReporter) occurrences(error ParsingError) u32 {
	if metadata := reporter.errors[parsing_error_key(error)] {
		return metadata.occurrences
	}
	return 0
}

pub fn (reporter &ErrorReporter) number_of_errors() int {
	return reporter.errors.len
}

pub fn (reporter &ErrorReporter) dump() {
	eprintln('${reporter.errors.len} CSS errors reported:')
	for _, metadata in reporter.errors {
		eprintln('- ${metadata.message} (${metadata.occurrences} occurrences)')
	}
}

fn parser_report_error(error ParsingError) {
	mut reporter := css_error_reporter
	reporter.report(error)
}

pub enum SubstitutionDependencyType {
	property
	attribute
	function
}

pub struct SubstitutionContext {
pub mut:
	dependency_type   SubstitutionDependencyType
	first             string
	second            ?string
	function_identity u64
	is_cyclic         bool
}

pub fn (context SubstitutionContext) to_string() string {
	type_name := match context.dependency_type {
		.property { 'Property' }
		.attribute { 'Attribute' }
		.function { 'Function' }
	}

	return '${type_name} ${context.first} ${context.second or { '' }}'.trim_space()
}

pub struct GuardedSubstitutionContexts {
pub mut:
	contexts              []SubstitutionContext
	function_local_scopes []&FunctionLocalScope
	function_definition_scopes ?map[u64]&StyleScope
}

fn (contexts GuardedSubstitutionContexts) definition_scope(identity u64) ?&StyleScope {
	if scopes := contexts.function_definition_scopes {
		return scopes[identity] or { return none }
	}
	return none
}

fn (mut contexts GuardedSubstitutionContexts) remember_definition_scope(identity u64, scope &StyleScope) {
	// Ordinary var()/attr()/env() resolution never calls a custom function.
	// Keep its empty context free of a heap-allocated map until the first call.
	mut scopes := unsafe { contexts.function_definition_scopes or { map[u64]&StyleScope{} } }
	scopes[identity] = scope
	contexts.function_definition_scopes = unsafe { scopes }
}

pub fn (mut contexts GuardedSubstitutionContexts) guard(mut context SubstitutionContext) {
	for index, mut existing_context in contexts.contexts {
		if existing_context.dependency_type == context.dependency_type
			&& existing_context.first == context.first
			&& option_string_equal(existing_context.second, context.second)
			&& existing_context.function_identity == context.function_identity {
			for cyclic_index := index; cyclic_index < contexts.contexts.len; cyclic_index++ {
				contexts.contexts[cyclic_index].is_cyclic = true
			}
			context.is_cyclic = true
			return
		}
	}
	contexts.contexts << context
}

pub fn (mut contexts GuardedSubstitutionContexts) unguard(context SubstitutionContext) {
	for index, existing_context in contexts.contexts {
		if existing_context.dependency_type == context.dependency_type
			&& existing_context.first == context.first
			&& option_string_equal(existing_context.second, context.second)
			&& existing_context.function_identity == context.function_identity {
			contexts.contexts.delete(index)
			return
		}
	}
}

fn (mut contexts GuardedSubstitutionContexts) mark_existing_as_cyclic(context SubstitutionContext) bool {
	for index, existing_context in contexts.contexts {
		if existing_context.dependency_type == context.dependency_type
			&& existing_context.first == context.first
			&& option_string_equal(existing_context.second, context.second)
			&& existing_context.function_identity == context.function_identity {
			for cyclic_index := index; cyclic_index < contexts.contexts.len; cyclic_index++ {
				contexts.contexts[cyclic_index].is_cyclic = true
			}
			return true
		}
	}
	return false
}

fn (contexts GuardedSubstitutionContexts) is_marked_cyclic(context SubstitutionContext) bool {
	for existing_context in contexts.contexts {
		if existing_context.dependency_type == context.dependency_type
			&& existing_context.first == context.first
			&& option_string_equal(existing_context.second, context.second)
			&& existing_context.function_identity == context.function_identity {
			return existing_context.is_cyclic
		}
	}
	return false
}

pub enum ArbitrarySubstitutionFunction {
	attr
	env
	if_
	inherit
	var_
}

pub fn to_arbitrary_substitution_function(name string) ?ArbitrarySubstitutionFunction {
	if equals_ignoring_ascii_case(name, 'attr') {
		return .attr
	}
	if equals_ignoring_ascii_case(name, 'env') {
		return .env
	}
	if equals_ignoring_ascii_case(name, 'if') {
		return .if_
	}
	if equals_ignoring_ascii_case(name, 'inherit') {
		return .inherit
	}
	if equals_ignoring_ascii_case(name, 'var') {
		return .var_
	}
	return none
}

// Parser::collect_arbitrary_substitution_function_presence(). Keeping this on
// the parser boundary gives properties, descriptors, syntax parsing, and Typed
// OM one recursive implementation for inspecting component values.
pub fn collect_arbitrary_substitution_function_presence(values []ComponentValue, mut presence SubstitutionFunctionsPresence) ! {
	if !disable_leaf_substitution_skip && !substitution_values_have_nested_values(values) {
		report_leaf_substitution_skip()
		return
	}
	$if prealloc {
		scratch := platform.begin_thread_scratch('CSS substitution validation')
		collect_substitution_presence_in_workspace(values, mut presence) or {
			code := err.code()
			scratch.leave()
			message := err.msg().clone()
			scratch.finish()
			return error_with_code(message, code)
		}
		scratch.finish()
		return
	}
	collect_substitution_presence_in_workspace(values, mut presence)!
}

fn collect_substitution_presence_in_workspace(values []ComponentValue, mut presence SubstitutionFunctionsPresence) ! {
	for value in values {
		collect_substitution_presence_from_component_in_workspace(value, mut presence)!
	}
}

fn collect_arbitrary_substitution_function_presence_from_component(value ComponentValue, mut presence SubstitutionFunctionsPresence) ! {
	if !disable_leaf_substitution_skip && !value.is_function() && !value.is_block() {
		report_leaf_substitution_skip()
		return
	}
	$if prealloc {
		scratch := platform.begin_thread_scratch('CSS substitution validation')
		collect_substitution_presence_from_component_in_workspace(value, mut presence) or {
			code := err.code()
			scratch.leave()
			message := err.msg().clone()
			scratch.finish()
			return error_with_code(message, code)
		}
		scratch.finish()
		return
	}
	collect_substitution_presence_from_component_in_workspace(value, mut presence)!
}

// Argument validation borrows spans; only these scalar flags escape. Recursion
// stays inside the same workspace and never publishes tokens.
fn collect_substitution_presence_from_component_in_workspace(value ComponentValue, mut presence SubstitutionFunctionsPresence) ! {
	if value.is_function() {
		function := value.function()
		if is_a_custom_property_name_string(function.name) {
			presence.custom_function = true
		}
		if substitution_function := to_arbitrary_substitution_function(function.name) {
			if !arbitrary_substitution_arguments_are_valid(substitution_function, function.value) {
				return error('invalid arbitrary substitution function syntax')
			}
			match substitution_function {
				.attr {
					presence.attr = true
				}
				.env {
					presence.env = true
				}
				.if_ {
					presence.if_ = true
				}
				.inherit {
					presence.inherit = true
				}
				.var_ {
					presence.var = true
				}
			}
		}
		collect_substitution_presence_in_workspace(function.value, mut presence)!
	} else if value.is_block() {
		collect_substitution_presence_in_workspace(value.block().value, mut presence)!
	}
}

pub fn contains_guaranteed_invalid_value(values []ComponentValue) bool {
	for value in values {
		if value.contains_guaranteed_invalid_value() {
			return true
		}
	}
	return false
}

pub struct DeclarationValueList {
pub mut:
	values [][]ComponentValue
}

pub fn (list DeclarationValueList) first() []ComponentValue {
	if list.values.len == 0 {
		return []ComponentValue{}
	}
	return list.values[0]
}

pub fn (list DeclarationValueList) get(index int) ?[]ComponentValue {
	if index < 0 || index >= list.values.len {
		return none
	}
	return list.values[index]
}

pub struct IfArgsBranch {
pub mut:
	condition []ComponentValue
	value     ?[]ComponentValue
}

pub struct IfArgs {
pub mut:
	branches []IfArgsBranch
}

pub type ArbitrarySubstitutionFunctionArguments = DeclarationValueList | IfArgs

fn arbitrary_substitution_guaranteed_invalid_value() []ComponentValue {
	return [ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
}

fn contains_attr_tainted_value(values []ComponentValue) bool {
	return values.any(it.contains_attr_tainted_value())
}

fn mark_as_attr_tainted(values []ComponentValue) []ComponentValue {
	mut tainted := values.clone()
	for index := 0; index < tainted.len; index++ {
		tainted[index].set_attr_tainted()
	}
	return tainted
}

// Shared declaration-value validation. The returned span is borrowed and may
// only be consumed synchronously by private read-only callers.
fn parse_declaration_value_span(mut tokens ParserTokenStream, end_token_type ?TokenType) ?[]ComponentValue {
	start_index := tokens.index
	for tokens.has_next_token() {
		peek := tokens.next_token()
		if peek.is_block() {
			if !nested_declaration_value_contents_are_valid(peek.block().value) {
				break
			}
			tokens.discard_a_token()
			continue
		}
		if peek.is_function() {
			if !nested_declaration_value_contents_are_valid(peek.function().value) {
				break
			}
			tokens.discard_a_token()
			continue
		}
		if !peek.is_token() {
			tokens.discard_a_token()
			continue
		}

		mut valid := true
		if peek.is(.invalid) || peek.is(.end_of_file) || peek.is(.bad_string) || peek.is(.bad_url)
			|| peek.is(.semicolon) || peek.is(.function) || peek.is(.open_curly)
			|| peek.is(.open_paren) || peek.is(.open_square) || peek.is(.close_curly)
			|| peek.is(.close_paren) || peek.is(.close_square) {
			valid = false
		} else if peek.is(.delim) && peek.token().delim() == u32(`!`) {
			valid = false
		} else if end := end_token_type {
			if peek.is(end) {
				valid = false
			}
		}

		if !valid {
			break
		}
		tokens.discard_a_token()
	}

	if tokens.index == start_index {
		tokens.index = start_index
		return none
	}
	return tokens.tokens_since(start_index)
}

// ValueParsing.cpp: Parser::parse_declaration_value.
fn parse_declaration_value(mut tokens ParserTokenStream, end_token_type ?TokenType) ?[]ComponentValue {
	span := parse_declaration_value_span(mut tokens, end_token_type) or { return none }
	// Existing grammar callers retain an independently mutable result buffer.
	return span.clone()
}

fn nested_declaration_value_contents_are_valid(values []ComponentValue) bool {
	for value in values {
		if value.is_block() {
			if !nested_declaration_value_contents_are_valid(value.block().value) {
				return false
			}
			continue
		}
		if value.is_function() {
			if !nested_declaration_value_contents_are_valid(value.function().value) {
				return false
			}
			continue
		}
		if !value.is_token() {
			continue
		}
		if value.is(.invalid) || value.is(.end_of_file) || value.is(.bad_string)
			|| value.is(.bad_url) || value.is(.function) || value.is(.open_curly)
			|| value.is(.open_paren) || value.is(.open_square) || value.is(.close_curly)
			|| value.is(.close_paren) || value.is(.close_square) {
			return false
		}
	}
	return true
}

fn is_valid_optional_declaration_value(values []ComponentValue) bool {
	mut tokens := ParserTokenStream.from_values(values)
	tokens.discard_whitespace()
	if !tokens.has_next_token() {
		return true
	}
	_ := parse_declaration_value_span(mut tokens, none) or { return false }
	tokens.discard_whitespace()
	return !tokens.has_next_token()
}

fn parse_declaration_value_then_optional_declaration_value(mut tokens ParserTokenStream, separator TokenType) ?DeclarationValueList {
	arguments := parse_substitution_argument_spans(mut tokens, separator) or { return none }
	if second_argument := arguments.second_argument {
		return DeclarationValueList{
			values: [arguments.first_argument.clone(), second_argument.clone()]
		}
	}
	return DeclarationValueList{
		values: [arguments.first_argument.clone()]
	}
}

// Borrowed argument spans for immediate validation and var()/inherit() replacement.
// Public argument grammar continues to return independently owned arrays.
struct SubstitutionArgumentSpans {
	first_argument  []ComponentValue
	second_argument ?[]ComponentValue
}

fn parse_substitution_argument_spans(mut tokens ParserTokenStream, separator TokenType) ?SubstitutionArgumentSpans {
	first_argument := parse_declaration_value_span(mut tokens, separator) or { return none }
	if !tokens.has_next_token() {
		return SubstitutionArgumentSpans{first_argument: first_argument}
	}
	if !tokens.next_token().is(separator) {
		return none
	}
	tokens.discard_a_token()
	second_argument := parse_declaration_value_span(mut tokens, none) or { []ComponentValue{} }
	return SubstitutionArgumentSpans{
		first_argument: first_argument
		second_argument: second_argument
	}
}

fn parse_substitution_name_argument_spans(values []ComponentValue) ?SubstitutionArgumentSpans {
	mut tokens := ParserTokenStream.from_values(values)
	arguments := parse_substitution_argument_spans(mut tokens, .comma) or { return none }
	if tokens.has_next_token() {
		return none
	}
	return arguments
}

fn arbitrary_substitution_arguments_are_valid(function ArbitrarySubstitutionFunction, values []ComponentValue) bool {
	mut tokens := ParserTokenStream.from_values(values)
	match function {
		.attr, .env, .inherit, .var_ {
			_ := parse_substitution_argument_spans(mut tokens, .comma) or { return false }
			return !tokens.has_next_token()
		}
		.if_ {
			mut branch_count := 0
			for tokens.has_next_token() {
				_ := parse_substitution_argument_spans(mut tokens, .colon) or { break }
				branch_count++
				if !tokens.next_token().is(.semicolon) {
					break
				}
				tokens.discard_a_token()
			}
			return branch_count > 0 && !tokens.has_next_token()
		}
	}
}

pub fn parse_according_to_argument_grammar(function ArbitrarySubstitutionFunction, values []ComponentValue) ?ArbitrarySubstitutionFunctionArguments {
	mut tokens := ParserTokenStream.from_values(values)
	match function {
		.attr, .env, .inherit, .var_ {
			list := parse_declaration_value_then_optional_declaration_value(mut tokens, .comma) or {
				return none
			}
			if tokens.has_next_token() {
				return none
			}
			return ArbitrarySubstitutionFunctionArguments(list)
		}
		.if_ {
			mut args := IfArgs{}
			for tokens.has_next_token() {
				if_args_branch := parse_declaration_value_then_optional_declaration_value(mut tokens, .colon) or { break }

				args.branches << IfArgsBranch{
					condition: if_args_branch.first()
					value: if_args_branch.get(1)
				}

				if !tokens.next_token().is(.semicolon) {
					break
				}
				tokens.discard_a_token()
			}

			if args.branches.len == 0 || tokens.has_next_token() {
				return none
			}
			return ArbitrarySubstitutionFunctionArguments(args)
		}
	}
}

fn arbitrary_arguments_as_declaration_value_list(arguments ArbitrarySubstitutionFunctionArguments) ?DeclarationValueList {
	if arguments is DeclarationValueList {
		return arguments
	}
	return none
}

fn arbitrary_arguments_as_if_args(arguments ArbitrarySubstitutionFunctionArguments) ?IfArgs {
	if arguments is IfArgs {
		return arguments
	}
	return none
}

enum AttrSyntaxKind {
	omitted
	raw_string
	number
	unit
	syntax
}

struct AttrSyntax {
mut:
	kind   AttrSyntaxKind
	unit   string
	syntax ?SyntaxNode
}

fn attr_failure_result(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, second_argument ?[]ComponentValue, syntax AttrSyntax) []ComponentValue {
	// 1. If second arg is null, and syntax was omitted, return an empty CSS <string>.
	if second_argument == none && syntax.kind == .omitted {
		return mark_as_attr_tainted([
			ComponentValue.from_token(Token.create_string('', '')),
		])
	}

	// 2. If second arg is null, return the guaranteed-invalid value.
	if second_argument == none {
		return mark_as_attr_tainted(arbitrary_substitution_guaranteed_invalid_value())
	}

	// 3. Substitute arbitrary substitution functions in second arg, and return the result.
	return mark_as_attr_tainted(substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, second_argument, none))
}

fn parse_number_from_attr_value(attribute_value string) ?Number {
	values := parse_component_values_for_value_logic(attribute_value.trim_space())
	mut tokens := ParserTokenStream.from_values(values)
	tokens.discard_whitespace()
	token := tokens.consume_a_token()
	tokens.discard_whitespace()
	if tokens.has_next_token() || !token.is(.number) {
		return none
	}
	return token.token().number()
}

fn style_value_to_component_values_for_substitution(style_value StyleValue) []ComponentValue {
	if style_value.type_() == .guaranteed_invalid {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	return parse_component_values_for_value_logic(style_value.serialize(.normal))
}

fn replace_an_attr_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-values-5/#replace-an-attr-function
	declaration_value_list := arbitrary_arguments_as_declaration_value_list(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	first_argument := declaration_value_list.first()
	second_argument := declaration_value_list.get(1)
	mut attribute_name := ''
	mut syntax := AttrSyntax{}

	substituted := substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, first_argument, none)
	mut first_argument_tokens := ParserTokenStream.from_values(substituted)

	// <attr-name> = [ <ident-token>? '|' ]? <ident-token>
	// FIXME: Support optional attribute namespace.
	if !first_argument_tokens.next_token().is(.ident) {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}
	attribute_name = first_argument_tokens.consume_a_token().token().ident()
	first_argument_tokens.discard_whitespace()

	// <attr-type> = type( <syntax> ) | raw-string | number | <attr-unit>
	if first_argument_tokens.next_token().is(.ident) {
		syntax_ident := first_argument_tokens.next_token().token().ident()
		if equals_ignoring_ascii_case(syntax_ident, 'raw-string') {
			first_argument_tokens.discard_a_token()
			syntax.kind = .raw_string
		} else if equals_ignoring_ascii_case(syntax_ident, 'number') {
			first_argument_tokens.discard_a_token()
			syntax.kind = .number
		} else if dimension := dimension_for_unit(syntax_ident) {
			_ = dimension
			syntax.kind = .unit
			syntax.unit = first_argument_tokens.consume_a_token().token().ident()
		} else {
			return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
		}
	} else if first_argument_tokens.next_token().is_delim(u32(`%`)) {
		first_argument_tokens.discard_a_token()
		syntax.kind = .unit
		syntax.unit = '%'
	} else if first_argument_tokens.next_token().is_function_named('type') {
		type_function := first_argument_tokens.consume_a_token().function()
		if parsed_syntax := parse_as_syntax(type_function.value) {
			syntax.kind = .syntax
			syntax.syntax = parsed_syntax
		} else {
			return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
		}
	}

	first_argument_tokens.discard_whitespace()
	if first_argument_tokens.has_next_token() {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}

	el := element or {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}

	// FIXME: Attribute namespaces.
	attribute_value := el.element().get_attribute(attribute_name) or {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}

	if syntax.kind == .number || syntax.kind == .unit {
		parsed_number := parse_number_from_attr_value(attribute_value) or {
			return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
		}
		if syntax.kind == .number {
			return mark_as_attr_tainted([ComponentValue.from_token(Token.create_number(parsed_number, ''))])
		}
		if syntax.unit == '%' {
			return mark_as_attr_tainted([
				ComponentValue.from_token(Token.create_percentage(parsed_number, '')),
			])
		}
		return mark_as_attr_tainted([
			ComponentValue.from_token(Token.create_dimension(parsed_number, syntax.unit, '')),
		])
	}

	if syntax.kind == .omitted || syntax.kind == .raw_string {
		return mark_as_attr_tainted([ComponentValue.from_token(Token.create_string(attribute_value, ''))])
	}

	syntax_node := syntax.syntax or {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}

	unsubstituted_values := parse_component_values_for_value_logic(attribute_value)
	substituted_values := substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, unsubstituted_values, SubstitutionContext{
		dependency_type: .attribute
		first: attribute_name
	})
	parsed_value := parse_with_a_syntax(substituted_values, syntax_node)
	if parsed_value.type_() == .guaranteed_invalid {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}
	return mark_as_attr_tainted(style_value_to_component_values_for_substitution(parsed_value))
}

fn environment_variable_from_string_local(name string) ?dom.EnvironmentVariable {
	return match name.to_lower() {
		'preferred-text-scale' { dom.EnvironmentVariable.preferred_text_scale }
		'safe-area-inset-bottom' { dom.EnvironmentVariable.safe_area_inset_bottom }
		'safe-area-inset-left' { dom.EnvironmentVariable.safe_area_inset_left }
		'safe-area-inset-right' { dom.EnvironmentVariable.safe_area_inset_right }
		'safe-area-inset-top' { dom.EnvironmentVariable.safe_area_inset_top }
		'safe-area-max-inset-bottom' { dom.EnvironmentVariable.safe_area_max_inset_bottom }
		'safe-area-max-inset-left' { dom.EnvironmentVariable.safe_area_max_inset_left }
		'safe-area-max-inset-right' { dom.EnvironmentVariable.safe_area_max_inset_right }
		'safe-area-max-inset-top' { dom.EnvironmentVariable.safe_area_max_inset_top }
		'viewport-segment-bottom' { dom.EnvironmentVariable.viewport_segment_bottom }
		'viewport-segment-height' { dom.EnvironmentVariable.viewport_segment_height }
		'viewport-segment-left' { dom.EnvironmentVariable.viewport_segment_left }
		'viewport-segment-right' { dom.EnvironmentVariable.viewport_segment_right }
		'viewport-segment-top' { dom.EnvironmentVariable.viewport_segment_top }
		'viewport-segment-width' { dom.EnvironmentVariable.viewport_segment_width }
		else { none }
	}
}

fn environment_variable_dimension_count_local(variable dom.EnvironmentVariable) int {
	return match variable {
		.viewport_segment_bottom, .viewport_segment_height, .viewport_segment_left, .viewport_segment_right, .viewport_segment_top, .viewport_segment_width {
			2
		}
		else {
			0
		}
	}
}

fn environment_variable_is_viewport_segment_local(variable dom.EnvironmentVariable) bool {
	return variable in [
		dom.EnvironmentVariable.viewport_segment_bottom,
		.viewport_segment_height,
		.viewport_segment_left,
		.viewport_segment_right,
		.viewport_segment_top,
		.viewport_segment_width,
	]
}

fn replace_an_env_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-env/#substitute-an-env
	declaration_value_list := arbitrary_arguments_as_declaration_value_list(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	first_argument := declaration_value_list.first()
	second_argument := declaration_value_list.get(1)

	substituted_first_argument := substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, first_argument, none)
	mut first_argument_tokens := ParserTokenStream.from_values(substituted_first_argument)
	first_argument_tokens.discard_whitespace()
	name_token := first_argument_tokens.consume_a_token()
	if !name_token.is(.ident) {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	name := name_token.token().ident()
	first_argument_tokens.discard_whitespace()

	mut indices := []i64{}
	for first_argument_tokens.has_next_token() {
		maybe_integer := first_argument_tokens.consume_a_token()
		if !maybe_integer.is(.number) {
			return arbitrary_substitution_guaranteed_invalid_value()
		}
		number := maybe_integer.token().number()
		if number.is_integer() && number.integer_value() >= 0 {
			indices << number.integer_value()
		} else {
			return arbitrary_substitution_guaranteed_invalid_value()
		}
		first_argument_tokens.discard_whitespace()
	}

	if environment_variable := environment_variable_from_string_local(name) {
		if indices.len == environment_variable_dimension_count_local(environment_variable) {
			if environment_variable_is_viewport_segment_local(environment_variable) {
				return arbitrary_substitution_guaranteed_invalid_value()
			}
			if el := element {
				if result := el.document().environment_variable_value(environment_variable) {
					return parse_component_values_for_value_logic(result)
				}
			}
		}
	}

	if fallback := second_argument {
		return substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, fallback, none)
	}

	return arbitrary_substitution_guaranteed_invalid_value()
}

// https://drafts.csswg.org/css-values-5/#typedef-if-condition
fn (mut parser Parser) parse_if_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	original_tokens := tokens
	if expression := parser.parse_boolean_expression(mut tokens, .false_, .if_test) {
		tokens.discard_whitespace()
		if !tokens.has_next_token() {
			return expression
		}
	}

	// A failed transaction is rewound before attempting the `else` branch.
	tokens = original_tokens
	mut else_tokens := tokens
	else_tokens.discard_whitespace()
	if token := else_tokens.consume_a_token() {
		else_tokens.discard_whitespace()
		if !else_tokens.has_next_token() && token.is_ident('else') {
			tokens = else_tokens
			return BooleanExpression.create_constant(.true_)
		}
	}
	return none
}

fn (mut parser Parser) parse_if_test(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	maybe_function_token := transaction.consume_a_token() or { return none }
	if !maybe_function_token.is_function() {
		return none
	}

	function := maybe_function_token.function()
	function_name := function.name.to_lower()

	if function_name == 'supports' {
		mut declaration_tokens := ParserTokenStream.from_values(function.value)
		if supports_declaration := parser.parse_supports_declaration(mut declaration_tokens) {
			tokens = transaction
			return supports_declaration
		}

		mut condition_tokens := SupportsTokenStream.from_values_with_namespaces(function.value, parser.context.declared_namespaces)
		if supports_condition := parser.parse_supports_condition(mut condition_tokens) {
			condition_tokens.discard_whitespace()
			if !condition_tokens.has_next_token() {
				tokens = transaction
				return supports_condition
			}
		}
		return none
	}

	if function_name == 'media' {
		mut feature_tokens := SupportsTokenStream.from_values(function.value)
		if media_feature := parser.parse_media_feature(mut feature_tokens) {
			feature_tokens.discard_whitespace()
			if !feature_tokens.has_next_token() {
				tokens = transaction
				return media_feature
			}
		}

		mut condition_tokens := ComponentValueStream.new(function.value)
		if media_condition := parser.parse_media_condition(mut condition_tokens) {
			condition_tokens.consume_whitespace()
			if !condition_tokens.has_more_tokens() {
				tokens = transaction
				return media_condition
			}
		}
		return none
	}

	// style( <style-query> )
	if function_name == 'style' {
		mut style_tokens := SupportsTokenStream.from_values(function.value)
		if style_query := parser.parse_style_query(mut style_tokens, .false_) {
			style_tokens.discard_whitespace()
			if !style_tokens.has_next_token() {
				tokens = transaction
				return style_query
			}
		}
	}
	return none
}

fn replace_an_if_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-values-5/#replace-an-if-function
	if_args := arbitrary_arguments_as_if_args(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}

	// As in C++, construct one parser and reuse it for every branch condition.
	mut condition_parser := Parser{}
	mut evaluation_document := ?&dom.Document(none)
	if abstract_element := element {
		document := abstract_element.element().document()
		condition_parser.context = ParsingParams{
			document: document
		}
		evaluation_document = document
	}
	mut did_evaluate_attr_tainted_condition := false

	for branch in if_args.branches {
		substituted_condition := substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, branch.condition, none)
		condition_is_attr_tainted := contains_attr_tainted_value(substituted_condition)
		mut condition_tokens := SupportsTokenStream.from_values(substituted_condition)
		condition := condition_parser.parse_if_condition(mut condition_tokens) or {
			continue
		}
		mut did_evaluate_attr_tainted_style_query := false
		condition_result := condition.evaluate(BooleanExpressionEvaluationContext{
			document:                              evaluation_document
			style_query_element:                   element
			guarded_contexts:                      &guarded_contexts
			did_evaluate_attr_tainted_style_query: &did_evaluate_attr_tainted_style_query
		})
		did_evaluate_attr_tainted_condition = did_evaluate_attr_tainted_condition
			|| condition_is_attr_tainted || did_evaluate_attr_tainted_style_query
		if condition_result == .false_ {
			continue
		}
		value := branch.value or { return []ComponentValue{} }
		result := substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, value, none)
		if did_evaluate_attr_tainted_condition {
			return mark_as_attr_tainted(result)
		}
		return result
	}

	return []ComponentValue{}
}

fn custom_property_tokens_from_element_for_substitution(abstract_element dom.AbstractElement, custom_property_name string) ?[]ComponentValue {
	value := abstract_element.get_custom_property(custom_property_name) or { return none }
	if value.guaranteed_invalid {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	if retained_value := dom_style_value_from_custom_property_bridge(value) {
		if typed := typed_style_value_logic_from_dom(retained_value) {
			if typed is UnresolvedStyleValue {
				return typed.tokens.clone()
			}
		}
	}
	return parse_component_values_for_value_logic(value.css_text)
}

fn computed_custom_property_tokens_for_substitution(abstract_element dom.AbstractElement, custom_property_name string, mut guarded_contexts GuardedSubstitutionContexts) ?[]ComponentValue {
	if function_local_scope_index_for_property(guarded_contexts, custom_property_name) >= 0 {
		local_resolution := resolve_custom_property_for_function_scope(abstract_element,
			custom_property_name, mut guarded_contexts)
		if local_resolution.kind == .resolved {
			return local_resolution.tokens
		}
		if local_resolution.kind == .invalid {
			return arbitrary_substitution_guaranteed_invalid_value()
		}
	}
	computed := resolve_computed_custom_property_value(abstract_element, custom_property_name,
		mut guarded_contexts)
	if computed.kind == .substituted {
		return computed.tokens
	}
	if computed.kind == .guaranteed_invalid {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	typed := typed_style_value_logic_from_dom(computed.existing_value) or {
		return parse_component_values_for_value_logic(computed.existing_value.css_text)
	}
	if typed is GuaranteedInvalidStyleValue {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	return typed.tokenize()
}

fn replace_an_inherit_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-values-5/#replace-an-inherit-function
	declaration_value_list := arbitrary_arguments_as_declaration_value_list(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	return replace_an_inherit_function_from_spans(element, mut guarded_contexts,
		declaration_value_list.first(), declaration_value_list.get(1))
}

fn replace_an_inherit_function_from_spans(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, first_argument []ComponentValue, second_argument ?[]ComponentValue) []ComponentValue {
	// The name parser only advances its cursor. A leaf argument has no work for
	// substitution and can be borrowed without publishing a mutable result.
	substituted_first_argument := if substitution_values_have_nested_values(first_argument) {
		substitute_arbitrary_substitution_functions_with_optional_element(element,
			mut guarded_contexts, first_argument, none)
	} else {
		first_argument
	}
	mut first_argument_tokens := ParserTokenStream.from_values(substituted_first_argument)
	first_argument_tokens.discard_whitespace()
	name_token := first_argument_tokens.consume_a_token()
	first_argument_tokens.discard_whitespace()

	if name_token.is(.ident) && is_a_custom_property_name_string(name_token.token().ident())
		&& !first_argument_tokens.has_next_token() {
		if el := element {
			name := name_token.token().ident()
			if guarded_contexts.function_local_scopes.len > 0 {
				popped := guarded_contexts.function_local_scopes.pop()
				inherited := resolve_custom_property_for_function_scope(el, name, mut guarded_contexts)
				guarded_contexts.function_local_scopes << popped
				if inherited.kind == .resolved {
					return inherited.tokens
				}
			} else if element_to_inherit_style_from := el.element_to_inherit_style_from() {
				if inherited_value := custom_property_tokens_from_element_for_substitution(element_to_inherit_style_from, name) {
					if !contains_guaranteed_invalid_value(inherited_value) {
						return inherited_value
					}
				}
			}
		}
	}

	if fallback := second_argument {
		return substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, fallback, none)
	}

	return arbitrary_substitution_guaranteed_invalid_value()
}

fn replace_a_var_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-variables-1/#replace-a-var-function
	declaration_value_list := arbitrary_arguments_as_declaration_value_list(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	return replace_a_var_function_from_spans(element, mut guarded_contexts,
		declaration_value_list.first(), declaration_value_list.get(1))
}

fn replace_a_var_function_from_spans(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, first_argument []ComponentValue, second_argument ?[]ComponentValue) []ComponentValue {
	substituted_first_argument := if substitution_values_have_nested_values(first_argument) {
		substitute_arbitrary_substitution_functions_with_optional_element(element,
			mut guarded_contexts, first_argument, none)
	} else {
		first_argument
	}
	mut name_tokens := ParserTokenStream.from_values(substituted_first_argument)
	name_tokens.discard_whitespace()
	name_token := name_tokens.consume_a_token()
	name_tokens.discard_whitespace()

	mut result := []ComponentValue{}
	if name_tokens.has_next_token() || !name_token.is(.ident)
		|| !is_a_custom_property_name_string(name_token.token().ident()) {
		result = arbitrary_substitution_guaranteed_invalid_value()
	} else if el := element {
		custom_property_name := name_token.token().ident()
		result = computed_custom_property_tokens_for_substitution(el, custom_property_name, mut guarded_contexts) or {
			arbitrary_substitution_guaranteed_invalid_value()
		}
	} else {
		result = arbitrary_substitution_guaranteed_invalid_value()
	}

	// FIXME: Animation-tainted custom properties.
	if contains_guaranteed_invalid_value(result) {
		if fallback := second_argument {
			result = substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, fallback, none)
		}
	}
	return result
}

pub fn replace_an_arbitrary_substitution_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, function ArbitrarySubstitutionFunction, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	return match function {
		.attr { replace_an_attr_function(element, mut guarded_contexts, arguments) }
		.env { replace_an_env_function(element, mut guarded_contexts, arguments) }
		.if_ { replace_an_if_function(element, mut guarded_contexts, arguments) }
		.inherit { replace_an_inherit_function(element, mut guarded_contexts, arguments) }
		.var_ { replace_a_var_function(element, mut guarded_contexts, arguments) }
	}
}

fn substitution_values_have_nested_values(source []ComponentValue) bool {
	for value in source {
		if value.is_function() || value.is_block() {
			return true
		}
	}
	return false
}

// Flatten substitution results into the caller's fresh output buffer. Ordinary
// functions and blocks still receive their own independently mutable children.
// Failure propagates to the outer wrapper, which discards the partial output.
fn substitute_arbitrary_substitution_functions_step_2_into(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, source []ComponentValue, mut dest []ComponentValue) bool {
	if !substitution_values_have_nested_values(source) {
		dest << source
		return true
	}
	for index, value in source {
		if value.is_function() {
			source_function := value.function()
			if is_a_custom_property_name_string(source_function.name) {
				result := replace_a_dashed_function(element, mut guarded_contexts,
					source_function.name, source_function.value)
				if contains_guaranteed_invalid_value(result) {
					dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
				} else {
					result_start := dest.len
					if !substitute_arbitrary_substitution_functions_step_2_into(element,
						mut guarded_contexts, result, mut dest) {
						return false
					}
					result_length := dest.len - result_start
					if source.len - index - 1 + result_length > 16384 {
						return false
					}
				}
				continue
			}
			if maybe_function_id := to_arbitrary_substitution_function(source_function.name) {
				// FIXME: Substitute early-invoked functions in func's contents.
				early_result := source_function.value
				if contains_guaranteed_invalid_value(early_result) {
					dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
					continue
				}

				result := if maybe_function_id == .var_ || maybe_function_id == .inherit {
					// The arguments are only read during this immediate call. Keep
					// public grammar results owned, but avoid private span clones.
					arguments := parse_substitution_name_argument_spans(early_result) or {
						dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
						continue
					}
					if maybe_function_id == .var_ {
						replace_a_var_function_from_spans(element, mut guarded_contexts,
							arguments.first_argument, arguments.second_argument)
					} else {
						replace_an_inherit_function_from_spans(element, mut guarded_contexts,
							arguments.first_argument, arguments.second_argument)
					}
				} else {
					call_arguments := parse_according_to_argument_grammar(maybe_function_id, early_result) or {
						dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
						continue
					}
					replace_an_arbitrary_substitution_function(element, mut guarded_contexts, maybe_function_id, call_arguments)
				}

				if contains_guaranteed_invalid_value(result) {
					dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
				} else {
					result_start := dest.len
					if !substitute_arbitrary_substitution_functions_step_2_into(element,
						mut guarded_contexts, result, mut dest) {
						return false
					}
					result_length := dest.len - result_start

					// NB: Protect against the billion-laughs attack by limiting to an arbitrary large number of tokens.
					// https://drafts.csswg.org/css-values-5/#long-substitution
					// Match the original per-substitution check; an earlier output
					// prefix is not part of this substitution's expansion length.
					if source.len - index - 1 + result_length > 16384 {
						return false
					}
				}
				continue
			}

			function_values := substitute_arbitrary_substitution_functions_step_2(element, mut guarded_contexts, source_function.value) or { return false }
			mut function := source_function
			function.value = function_values
			dest << ComponentValue.from_function(function)
			continue
		}

		if value.is_block() {
			source_block := value.block()
			block_values := substitute_arbitrary_substitution_functions_step_2(element, mut guarded_contexts, source_block.value) or { return false }
			mut block := source_block
			block.value = block_values
			dest << ComponentValue.from_block(block)
			continue
		}

		dest << value
	}
	return true
}

fn substitute_arbitrary_substitution_functions_step_2(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, source []ComponentValue) ?[]ComponentValue {
	if !substitution_values_have_nested_values(source) {
		// Public output and ordinary nested children remain independent. Bound
		// the source view so cloning does not copy unused retained capacity.
		return source[..source.len].clone()
	}
	// A substitution can reject an oversized remainder before producing output.
	// Do not reserve an unbounded source-sized buffer before that limit check.
	capacity := if source.len > 16384 { 16384 } else { source.len }
	mut dest := []ComponentValue{cap: capacity}
	if !substitute_arbitrary_substitution_functions_step_2_into(element,
		mut guarded_contexts, source, mut dest) {
		return none
	}
	return dest
}

fn substitute_arbitrary_substitution_functions_with_optional_element(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, values []ComponentValue, context ?SubstitutionContext) []ComponentValue {
	// https://drafts.csswg.org/css-values-5/#substitute-arbitrary-substitution-function
	mut context_to_unguard := ?SubstitutionContext(none)
	if existing_context := context {
		mut context_copy := existing_context
		guarded_contexts.guard(mut context_copy)
		if context_copy.is_cyclic {
			return arbitrary_substitution_guaranteed_invalid_value()
		}
		context_to_unguard = context_copy
	}

	mut new_values := substitute_arbitrary_substitution_functions_step_2(element, mut guarded_contexts, values) or { arbitrary_substitution_guaranteed_invalid_value() }

	if guarded_context := context_to_unguard {
		if guarded_contexts.is_marked_cyclic(guarded_context) {
			new_values = arbitrary_substitution_guaranteed_invalid_value()
		}
		guarded_contexts.unguard(guarded_context)
	}

	return new_values
}

pub fn substitute_arbitrary_substitution_functions_for_element(element dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, values []ComponentValue, context ?SubstitutionContext) []ComponentValue {
	return substitute_arbitrary_substitution_functions_with_optional_element(element, mut guarded_contexts, values, context)
}

pub fn substitute_arbitrary_substitution_functions(values []ComponentValue, context ?SubstitutionContext) []ComponentValue {
	mut guarded_contexts := GuardedSubstitutionContexts{}
	return substitute_arbitrary_substitution_functions_with_optional_element(none, mut guarded_contexts, values, context)
}

fn has_ignored_vendor_prefix_local(name string) bool {
	lower := name.to_lower()
	return lower.starts_with('-moz-') || lower.starts_with('-ms-') || lower.starts_with('-o-')
}

fn is_css_wide_keyword_local(name string) bool {
	return name in ['initial', 'inherit', 'unset', 'revert', 'revert-layer']
}

fn is_invalid_custom_property_name_string_local(name string) bool {
	return name == '--'
}

pub fn parse_css_stylesheet_with_parser(css_text string, location ?string) &CSSStyleSheet {
	return parse_css_stylesheet_with_params(ParsingParams{}, css_text, location)
}

pub fn parse_css_stylesheet_with_params(params ParsingParams, css_text string, location ?string) &CSSStyleSheet {
	return parse_css_stylesheet_in_workspace(params, css_text, location, none, false)
}

pub fn parse_css_stylesheet_contents_with_params(params ParsingParams, css_text string) []&CSSRule {
	mut parser := RuleSelectorParser.create_for_stylesheet(params, css_text)
	return parser.parse_as_stylesheet_contents()
}

pub fn parse_css_stylesheet_contents_with_parser(css_text string, declared_namespaces map[string]bool) []&CSSRule {
	return parse_css_stylesheet_contents_with_params(ParsingParams{
		declared_namespaces: declared_namespaces
	}, css_text)
}

pub fn parse_css_rule_with_params(params ParsingParams, rule_text string) ?&CSSRule {
	return parse_css_rule_with_params_and_nesting(params, rule_text, .no)
}

pub fn parse_css_rule_with_params_and_nesting(params ParsingParams, rule_text string, nested ParserNested) ?&CSSRule {
	mut parser := RuleSelectorParser.create(params, rule_text, 'utf-8')
	return parser.parse_as_css_rule_with_nesting(nested)
}

pub fn parse_css_rule_with_parser(rule_text string, declared_namespaces map[string]bool) ?&CSSRule {
	return parse_css_rule_with_params(ParsingParams{
		declared_namespaces: declared_namespaces
	}, rule_text)
}

pub fn parse_css_property_declaration_block_with_parser(block string) &CSSStyleProperties {
	return parse_css_property_declaration_block_with_params(ParsingParams{
		rule_context: [RuleContext.style]
	}, block)
}

pub fn parse_css_property_declaration_block_with_params(params ParsingParams, block string) &CSSStyleProperties {
	mut body := block.trim_space()
	if body.starts_with('{') && body.ends_with('}') {
		body = body[1..body.len - 1]
	}

	mut parser := RuleSelectorParser.create(params, body, 'utf-8')
	mut input := parser.token_stream
	mut declarations := []Declaration{}
	for {
		input.discard_whitespace()
		if !input.has_next_token() {
			break
		}
		if input.next_token().is(.semicolon) {
			input.discard_a_token()
			continue
		}
		if declaration := parser.consume_a_declaration(mut input, .no, .no) {
			declarations << declaration
		} else {
			parser.consume_the_remnants_of_a_bad_declaration(mut input, .no)
		}
	}
	return parser.convert_to_style_declaration(declarations)
}

pub fn parse_selector_with_parser(selector_text string, declared_namespaces map[string]bool) ?SelectorList {
	mut parser := RuleSelectorParser.create_with_namespaces(selector_text, declared_namespaces)
	return parser.parse_as_selector(.standard)
}

pub fn parse_selector_for_nested_style_rule_with_parser(selector_text string, declared_namespaces map[string]bool, nesting_parent StyleNestingParent) ?SelectorList {
	mut parser := RuleSelectorParser.create_with_namespaces(selector_text, declared_namespaces)
	selectors := parser.parse_as_relative_selector(.standard) or { return none }
	return adapt_nested_relative_selector_list(selectors, nesting_parent)
}
