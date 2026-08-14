module css

import dom

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
	tokens              []Token
	token_stream        ParserTokenStream
	rule_context        []RuleContext
	declared_namespaces map[string]bool
}

pub fn RuleSelectorParser.create(params ParsingParams, input string, encoding string) RuleSelectorParser {
	tokens := Tokenizer.tokenize(input, encoding)
	return RuleSelectorParser{
		tokens:              tokens
		token_stream:        ParserTokenStream.from_tokens(tokens)
		rule_context:        params.rule_context.clone()
		declared_namespaces: params.declared_namespaces.clone()
	}
}

pub fn RuleSelectorParser.create_with_namespaces(input string, declared_namespaces map[string]bool) RuleSelectorParser {
	tokens := Tokenizer.tokenize(input, 'utf-8')
	return RuleSelectorParser{
		tokens:              tokens
		token_stream:        ParserTokenStream.from_tokens(tokens)
		declared_namespaces: declared_namespaces.clone()
	}
}

fn (parser RuleSelectorParser) parsing_params() ParsingParams {
	return ParsingParams{
		rule_context:        parser.rule_context.clone()
		declared_namespaces: parser.declared_namespaces.clone()
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
	values << ComponentValue.from_token(Tokenizer.create_eof_token())
	return ParserTokenStream{
		values: values
	}
}

fn ParserTokenStream.from_values(values []ComponentValue) ParserTokenStream {
	mut stream_values := values.clone()
	if stream_values.len == 0 || !stream_values[stream_values.len - 1].is(.end_of_file) {
		stream_values << ComponentValue.from_token(Tokenizer.create_eof_token())
	}
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

// remaining_token_count returns the number of real (non-EOF) tokens left from the
// current position. `values` always ends with an EOF sentinel, so it is excluded.
fn (stream ParserTokenStream) remaining_token_count() int {
	remaining := stream.values.len - 1 - stream.index
	return if remaining < 0 { 0 } else { remaining }
}

fn (stream ParserTokenStream) next_token() ComponentValue {
	if stream.index < stream.values.len {
		return stream.values[stream.index]
	}
	return ComponentValue.from_token(Tokenizer.create_eof_token())
}

fn (stream ParserTokenStream) peek_token(offset int) ComponentValue {
	index := stream.index + offset
	if index >= 0 && index < stream.values.len {
		return stream.values[index]
	}
	return ComponentValue.from_token(Tokenizer.create_eof_token())
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
	return parser_component_values_to_string(stream.values[..stream.values.len - 1])
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
}

fn (stream RawTokenStream) next_token() Token {
	if stream.index < stream.tokens.len {
		return stream.tokens[stream.index]
	}
	return Tokenizer.create_eof_token()
}

fn (mut stream RawTokenStream) consume_a_token() Token {
	token := stream.next_token()
	if stream.index < stream.tokens.len {
		stream.index++
	}
	return token
}

fn (mut stream RawTokenStream) discard_a_token() {
	if stream.index < stream.tokens.len {
		stream.index++
	}
}

// https://drafts.csswg.org/css-syntax/#parse-stylesheet
fn (mut parser RuleSelectorParser) parse_a_stylesheet(location ?string) ParsedStyleSheet {
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
	mut import_rules_valid := true
	mut namespace_rules_valid := true

	// Interpret all of the resulting top-level qualified rules as style rules, defined below.
	mut rules := []&CSSRule{}
	for raw_rule in raw_rules {
		rule := parser.convert_to_rule(raw_rule, .no) or {
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
				parser.declared_namespaces[rule.prefix] = true
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
	style_sheet := parser.parse_a_stylesheet(location)
	rule_list := CSSRuleList.create(parser.convert_rules(style_sheet.rules))
	media := media_list or { MediaList.create_empty() }
	return CSSStyleSheet.create(rule_list, media, location)
}

pub fn (mut parser RuleSelectorParser) parse_as_stylesheet_contents() []&CSSRule {
	mut input := parser.token_stream
	return parser.convert_rules(parser.parse_a_stylesheets_contents(mut input))
}

pub fn (mut parser RuleSelectorParser) parse_as_css_rule() ?&CSSRule {
	mut input := parser.token_stream
	rule := parser.parse_a_rule(mut input) or { return none }
	return parser.convert_to_rule(rule, .no)
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
fn (mut parser RuleSelectorParser) parse_a_rule(mut input ParserTokenStream) ?Rule {
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
		at_rule := parser.consume_an_at_rule(mut input, .no) or { return none }
		rule = at_rule
	} else {
		// 5. Otherwise, consume a qualified rule from input and let rule be the return value. If nothing was returned,
		// return failure.
		result := parser.consume_a_qualified_rule(mut input, none, .no)
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
		name:                                  name
		prelude:                               []ComponentValue{}
		child_rules_and_lists_of_declarations: []RuleOrListOfDeclarations{}
		is_block_rule:                         false
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
		prelude:      []ComponentValue{}
		declarations: []Declaration{}
		child_rules:  []RuleOrListOfDeclarations{}
	}

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
			rule.prelude << input.consume_a_token()
			continue
		}

		// <{-token>
		if token.is_curly_block() {
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
		rule.prelude << parser.consume_a_component_value(mut input)
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
				declarations << declaration
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
		name:  ''
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
	declaration.value = parser.consume_a_list_of_component_values(mut input, TokenType.semicolon,
		nested)

	// 6. If the last two non-<whitespace-token>s in decl's value are a <delim-token> with the value "!" followed by an
	// <ident-token> with a value that is an ASCII case-insensitive match for "important", remove them from decl's value
	// and set decl's important flag.
	parser_strip_important(mut declaration)

	// 7. While the last item in decl's value is a <whitespace-token>, remove that token.
	for declaration.value.len > 0 && declaration.value[declaration.value.len - 1].is(.whitespace) {
		declaration.value.delete(declaration.value.len - 1)
	}

	// 8. If decl's name is a custom property name string, then set decl's original text to the segment of the original
	// source text string corresponding to the tokens of decl's value.
	if is_invalid_custom_property_name_string_local(declaration.name) {
		return none
	}
	if is_a_custom_property_name_string(declaration.name) {
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
		_ = parser.consume_a_component_value(mut input)
	}
}

fn parser_consume_a_component_value_from_tokens(mut input RawTokenStream) ComponentValue {
	for {
		token := input.next_token()
		if token.is(.open_curly) || token.is(.open_square) || token.is(.open_paren) {
			return ComponentValue.from_block(parser_consume_a_simple_block(mut input))
		}
		if token.is(.function) {
			return ComponentValue.from_function(parser_consume_a_function(mut input))
		}
		return ComponentValue.from_token(input.consume_a_token())
	}
	return ComponentValue.from_token(Tokenizer.create_eof_token())
}

// https://drafts.csswg.org/css-syntax/#consume-simple-block
fn parser_consume_a_simple_block(mut input RawTokenStream) SimpleBlock {
	// Assert: the next token of input is <{-token>, <[-token>, or <(-token>.
	next := input.next_token()
	assert next.is(.open_curly) || next.is(.open_square) || next.is(.open_paren)

	// Let ending token be the mirror variant of the next token.
	ending_token := input.next_token().mirror_variant()

	// Let block be a new simple block with its associated token set to the next token and with its value initially set
	// to an empty list.
	mut block := SimpleBlock{
		token: input.next_token()
		value: []ComponentValue{}
	}

	// Discard a token from input.
	input.discard_a_token()

	// Process input:
	for {
		token := input.next_token()
		if token.is(.end_of_file) || token.is(ending_token) {
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
	assert input.next_token().is(.function)

	// Consume a token from input, and let function be a new function with its name equal the returned token's value, and
	// a value set to an empty list.
	name_token := input.consume_a_token()
	mut function := Function{
		name:       name_token.function_name()
		value:      []ComponentValue{}
		name_token: name_token
	}

	// Process input:
	for {
		token := input.next_token()
		if token.is(.end_of_file) || token.is(.close_paren) {
			function.end_token = input.consume_a_token()
			return function
		}
		function.value << parser_consume_a_component_value_from_tokens(mut input)
	}
	return function
}

fn (mut parser RuleSelectorParser) convert_to_rule(rule Rule, nested ParserNested) ?&CSSRule {
	match rule {
		AtRule {
			if equals_ignoring_ascii_case(rule.name, 'keyframes')
				|| equals_ignoring_ascii_case(rule.name, '-webkit-keyframes') {
				return parser.convert_to_keyframes_rule(rule)
			}
			if has_ignored_vendor_prefix_local(rule.name) {
				return none
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
			if equals_ignoring_ascii_case(rule.name, 'import') {
				return parser.convert_to_import_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'layer') {
				return parser.convert_to_layer_rule(rule, nested)
			}
			if is_margin_rule_name(rule.name) {
				return parser.convert_to_margin_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'media') {
				return parser.convert_to_media_rule(rule, nested)
			}
			if equals_ignoring_ascii_case(rule.name, 'namespace') {
				return parser.convert_to_namespace_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'supports') {
				return parser.convert_to_supports_rule(rule, nested)
			}
			if equals_ignoring_ascii_case(rule.name, 'page') {
				return parser.convert_to_page_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'property') {
				return parser.convert_to_property_rule(rule)
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

fn (mut parser RuleSelectorParser) convert_to_style_rule(qualified_rule QualifiedRule, nested ParserNested) ?&CSSRule {
	mut prelude_stream := ParserTokenStream.from_values(qualified_rule.prelude)
	maybe_selectors := parser.parse_a_selector_list(mut prelude_stream, if nested == .yes {
		ParserSelectorType.relative
	} else {
		ParserSelectorType.standalone
	}, .standard) or {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   'style'
			prelude:     prelude_stream.dump_string()
			description: 'Selectors invalid.'
		}))
		return none
	}

	if maybe_selectors.is_empty() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   'style'
			prelude:     prelude_stream.dump_string()
			description: 'Empty selector.'
		}))
		return none
	}

	mut selectors := maybe_selectors
	if nested == .yes {
		selectors = adapt_nested_relative_selector_list(selectors)
	}

	declaration := parser.convert_to_style_declaration(qualified_rule.declarations)
	mut child_rules := []&CSSRule{}
	for child in qualified_rule.child_rules {
		match child {
			RuleNode {
				if converted_rule := parser.convert_to_rule(child.rule, .yes) {
					if converted_rule.type_ in [.media, .supports, .layer_block] {
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
				child_rules << CSSRule.create_nested_declarations(parser.convert_to_style_declaration(child.declarations))
			}
		}
	}

	return CSSRule.create_style(selectors, declaration, CSSRuleList.create(child_rules))
}

fn (mut parser RuleSelectorParser) convert_to_import_rule(rule AtRule) ?&CSSRule {
	mut tokens := ParserTokenStream.from_values(rule.prelude)
	if rule.is_block_rule || rule.prelude.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@import'
			prelude:     tokens.dump_string()
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
			rule_name:   '@import'
			prelude:     tokens.dump_string()
			description: 'Unable to parse URL.'
		}))
		return none
	}

	tokens.discard_whitespace()
	mut layer := ?string(none)
	if tokens.next_token().is_ident('layer') {
		tokens.discard_a_token()
		layer = ''
	} else if tokens.next_token().is_function_named('layer') {
		layer_function := tokens.consume_a_token().function()
		mut layer_tokens := ParserTokenStream.from_values(layer_function.value)
		name := parser.parse_layer_name(mut layer_tokens, .no) or { return none }
		layer_tokens.discard_whitespace()
		if layer_tokens.has_next_token() {
			return none
		}
		layer = name
	}

	tokens.discard_whitespace()
	mut supports := ?&Supports(none)
	if tokens.next_token().is_function_named('supports') {
		supports_function := tokens.consume_a_token().function()
		condition := parser_component_values_to_string(supports_function.value)
		supports = parse_css_supports(parser.parsing_params(), condition)
		if supports == none {
			mut supports_tokens := ParserTokenStream.from_values(supports_function.value)
			if supports_declaration := parse_supports_declaration_from_parser_tokens(mut supports_tokens) {
				supports = Supports.create(supports_declaration)
			}
		}
		tokens.discard_whitespace()
	}

	media_text :=
		parser_component_values_to_string(tokens.values[tokens.index..tokens.values.len - 1]).trim_space()
	mut media_queries := []&MediaQuery{}
	if media_text.len != 0 {
		media_queries = parse_css_media_query_list_value_logic(media_text)
	}
	media := MediaList.create(media_query_entries_from_queries(media_queries))
	return CSSRule.create_import(url, none, layer, supports, media)
}

fn (mut parser RuleSelectorParser) convert_to_layer_rule(rule AtRule, nested ParserNested) ?&CSSRule {
	if rule.is_block_rule {
		mut prelude_tokens := ParserTokenStream.from_values(rule.prelude)
		layer_name := parser.parse_layer_name(mut prelude_tokens, .yes) or { return none }
		prelude_tokens.discard_whitespace()
		if prelude_tokens.has_next_token() {
			return none
		}
		mut child_rules := parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations,
			nested)
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

fn (mut parser RuleSelectorParser) convert_to_media_rule(rule AtRule, nested ParserNested) ?&CSSRule {
	mut prelude_tokens := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule || rule.prelude.len == 0 {
		return none
	}
	mut media := MediaList.create_empty()
	mut mutable_media := unsafe { &MediaList(media) }
	mutable_media.set_media_text(prelude_tokens.dump_string())
	return CSSRule.create_media(media, CSSRuleList.create(parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations,
		nested)))
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

fn (mut parser RuleSelectorParser) convert_to_supports_rule(rule AtRule, nested ParserNested) ?&CSSRule {
	mut supports_tokens := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule || rule.prelude.len == 0 {
		return none
	}
	condition := supports_tokens.dump_string()
	supports := parse_css_supports(parser.parsing_params(), condition) or { return none }
	return CSSRule.create_supports(supports, CSSRuleList.create(parser.convert_child_rule_list(rule.child_rules_and_lists_of_declarations,
		nested)))
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
		if is_css_wide_keyword_local(name) || equals_ignoring_ascii_case(name, 'none')
			|| equals_ignoring_ascii_case(name, 'default') {
			parser_report_error(ParsingError(InvalidRuleError{
				rule_name:   '@keyframes'
				prelude:     prelude_stream.dump_string()
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

	return CSSRule.create_keyframes(name_token.to_string(), CSSRuleList.create(keyframes))
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
				rule_name:   'keyframe'
				prelude:     child_tokens.dump_string()
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
			rule_name:   '@property'
			prelude:     prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	if rule.prelude.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@property'
			prelude:     prelude_stream.dump_string()
			description: 'Empty prelude.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	token := prelude_stream.consume_a_token()
	if !token.is(.ident) {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@property'
			prelude:     prelude_stream.dump_string()
			description: 'Name must be an ident.'
		}))
		return none
	}

	name := token.token().ident()
	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@property'
			prelude:     prelude_stream.dump_string()
			description: 'Trailing tokens after name in prelude.'
		}))
		return none
	}

	if !is_a_custom_property_name_string(name) {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@property'
			prelude:     prelude_stream.dump_string()
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
	maybe_syntax := parse_as_syntax(syntax_component_values) or { return none }

	// The initial-value descriptor is optional only if the syntax is the universal syntax definition,
	// otherwise the descriptor is required; if it's missing, the entire rule is invalid and must be ignored.
	if initial_value_maybe == none && maybe_syntax.type() != .universal {
		return none
	}

	mut parsed_initial_value_maybe := ?StyleValue(none)
	if initial_value := initial_value_maybe {
		initial_value_component_values := parse_component_values_for_value_logic(initial_value)
		parsed_initial_value := parse_with_a_syntax(initial_value_component_values, maybe_syntax)
		// Otherwise, if the value of the syntax descriptor is not the universal syntax definition,
		// the following conditions must be met for the @property rule to be valid:
		//  - The initial-value descriptor must be present.
		//  - The initial-value descriptor's value must parse successfully according to the grammar specified by the syntax definition.
		//  - FIXME: The initial-value must be computationally independent.
		if parsed_initial_value.type_() == .guaranteed_invalid {
			return none
		}
		parsed_initial_value_maybe = parsed_initial_value
	}

	return CSSRule.create_property_rule_with_parsed_initial_value(name, syntax, inherits,
		initial_value_maybe, parsed_initial_value_maybe)
}

fn (mut parser RuleSelectorParser) convert_to_counter_style_rule(rule AtRule) ?&CSSRule {
	// https://drafts.csswg.org/css-counter-styles-3/#the-counter-style-rule
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@counter-style'
			prelude:     prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	if rule.prelude.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@counter-style'
			prelude:     prelude_stream.dump_string()
			description: 'Empty prelude.'
		}))
		return none
	}

	name := parser.parse_counter_style_name(mut prelude_stream) or {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@counter-style'
			prelude:     prelude_stream.dump_string()
			description: 'Missing counter style name.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@counter-style'
			prelude:     prelude_stream.dump_string()
			description: 'Trailing tokens after name in prelude.'
		}))
		return none
	}

	// https://drafts.csswg.org/css-counter-styles-3/#typedef-counter-style-name
	// When used here, to define a counter style, it also cannot be any of the non-overridable counter-style names
	// FIXME: We should allow these in the UA stylesheet in order to initially define them.
	if css_counter_style_rule_matches_non_overridable_counter_style_name(name) {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@counter-style'
			prelude:     prelude_stream.dump_string()
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

	return CSSRule.create_counter_style_rule(CSSCounterStyleRule.create(name, system, negative,
		prefix, suffix, range, pad, fallback, symbols, additive_symbols, speak_as))
}

fn (mut parser RuleSelectorParser) convert_to_font_face_rule(rule AtRule) ?&CSSRule {
	// https://drafts.csswg.org/css-fonts/#font-face-rule
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@font-face'
			prelude:     prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@font-face'
			prelude:     prelude_stream.dump_string()
			description: 'Prelude is not allowed.'
		}))
		return none
	}

	mut descriptors := []FontFaceDescriptor{}
	rule.for_each_as_declaration_list(fn [mut descriptors] (declaration Declaration) {
		id := font_face_descriptor_id_from_property(declaration.name) or { return }
		value := parser_component_values_to_string(declaration.value).trim_space()
		parsed := parse_font_face_descriptor_for_rule_parsing(id, value) or { return }
		append_font_face_descriptor(mut descriptors, FontFaceDescriptor{
			id:    id
			value: parsed
		})
	})

	return CSSRule.create_font_face_rule(CSSFontFaceRule.create(CSSFontFaceDescriptors.create(descriptors)))
}

fn (mut parser RuleSelectorParser) parse_comma_separated_family_name_list(mut tokens ParserTokenStream) ?[]string {
	mut family_names := []string{}
	comma_separated_families := parser.parse_a_comma_separated_list_of_component_values(mut tokens)

	if comma_separated_families.len == 0 {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@font-feature-values'
			prelude:     tokens.dump_string()
			description: 'Empty family name list.'
		}))
		return none
	}

	for family_component_values in comma_separated_families {
		family_name := parse_font_family_name_for_rule_parsing(family_component_values) or {
			parser_report_error(ParsingError(InvalidRuleError{
				rule_name:   '@font-feature-values'
				prelude:     parser_component_values_to_string(family_component_values)
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
			rule_name:   '@font-feature-values'
			prelude:     prelude_stream.dump_string()
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
		mut max_value_count := usize(1)

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
					rule_name:   '@${at_rule.name}'
					prelude:     parser_component_values_to_string(declaration.value)
					description: 'Declarations in @font-feature-values rules cannot be marked !important.'
				}))
				return
			}

			values := parse_font_feature_values_declaration_values(declaration.value) or {
				parser_report_error(ParsingError(InvalidRuleError{
					rule_name:   '@${at_rule.name}'
					prelude:     parser_component_values_to_string(declaration.value)
					description: 'Feature value entry must be a non-negative integer.'
				}))
				return
			}

			if values.len == 0 {
				parser_report_error(ParsingError(InvalidRuleError{
					rule_name:   '@${at_rule.name}'
					prelude:     parser_component_values_to_string(declaration.value)
					description: 'Empty feature value.'
				}))
				return
			}

			if usize(values.len) > max_value_count {
				parser_report_error(ParsingError(InvalidRuleError{
					rule_name:   '@${at_rule.name}'
					prelude:     parser_component_values_to_string(declaration.value)
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

fn (mut parser RuleSelectorParser) convert_to_page_rule(page_rule AtRule) ?&CSSRule {
	// https://drafts.csswg.org/css-page-3/#syntax-page-selector
	// @page = @page <page-selector-list>? { <declaration-rule-list> }
	mut tokens := ParserTokenStream.from_values(page_rule.prelude)
	if !page_rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@page'
			prelude:     tokens.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	page_selectors := parse_page_selector_list_for_rule_parsing(mut tokens) or { return none }
	mut child_rules := []&CSSRule{}
	mut descriptors := []Descriptor{}
	page_rule.for_each_as_declaration_rule_list(fn [mut child_rules, mut parser] (at_rule AtRule) {
		if converted_rule := parser.convert_to_rule(Rule(at_rule), .no) {
			if converted_rule.type_ == .margin {
				child_rules << converted_rule
			} else {
				parser_report_error(ParsingError(InvalidRuleLocationError{
					outer_rule_name: '@page'
					inner_rule_name: converted_rule.type_.class_name()
				}))
			}
		}
	}, fn [mut descriptors] (declaration Declaration) {
		if descriptor := convert_to_page_descriptor_for_rule_parsing(declaration) {
			append_descriptor(mut descriptors, descriptor)
		}
	})

	return CSSRule.create_page(page_selectors, CSSPageDescriptors.create(descriptors),
		CSSRuleList.create(child_rules))
}

fn (mut parser RuleSelectorParser) convert_to_margin_rule(rule AtRule) ?&CSSRule {
	mut prelude_stream := ParserTokenStream.from_values(rule.prelude)
	if !rule.is_block_rule {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@${rule.name}'
			prelude:     prelude_stream.dump_string()
			description: 'Must be a block, not a statement.'
		}))
		return none
	}

	prelude_stream.discard_whitespace()
	if prelude_stream.has_next_token() {
		parser_report_error(ParsingError(InvalidRuleError{
			rule_name:   '@${rule.name}'
			prelude:     prelude_stream.dump_string()
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

fn (mut parser RuleSelectorParser) convert_child_rule_list(children []RuleOrListOfDeclarations, nested ParserNested) []&CSSRule {
	mut child_rules := []&CSSRule{}
	for child in children {
		match child {
			RuleNode {
				if child_rule := parser.convert_to_rule(child.rule, nested) {
					child_rules << child_rule
				}
			}
			DeclarationList {
				child_rules << CSSRule.create_nested_declarations(parser.convert_to_style_declaration(child.declarations))
			}
		}
	}
	return child_rules
}

fn (mut parser RuleSelectorParser) convert_to_style_declaration(declarations ParserRuleDeclarations) &CSSStyleProperties {
	_ = parser
	mut style := CSSStyleProperties.create()
	for declaration in declarations {
		value := parser_component_values_to_string(declaration.value).trim_space()
		if is_a_custom_property_name_string(declaration.name) {
			value_text := if original := declaration.original_value_text {
				original
			} else {
				value
			}
			style.custom_properties[declaration.name] = custom_property_value_with_priority(value_text,
				declaration.important)
		} else {
			style.properties << CSSStyleProperty{
				name:      declaration.name
				value:     value
				important: declaration.important == .yes
			}
		}
	}
	return style
}

fn append_descriptor(mut descriptors []Descriptor, descriptor Descriptor) {
	for index, existing in descriptors {
		if existing.descriptor_id == descriptor.descriptor_id {
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

fn parse_font_face_descriptor_for_rule_parsing(id FontFaceDescriptorID, value string) ?string {
	return parse_font_face_descriptor(id, value)
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
		if is_css_wide_keyword_string(parts[0]) || equals_ignoring_ascii_case(parts[0], 'default') {
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
	if !token.is(.ident) || equals_ignoring_ascii_case(token.token().ident(), 'none') {
		tokens.index = transaction_index
		return none
	}
	mut custom_ident := token.token().ident()
	if keyword := keyword_from_string(custom_ident) {
		if keyword.is_css_wide_keyword() {
			tokens.index = transaction_index
			return none
		}
	}

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

fn parse_counter_style_symbol_value(mut tokens ParserTokenStream) ?StyleValue {
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
	symbol := parse_counter_style_symbol_value(mut tokens) or { return none }
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
		symbol := parse_counter_style_symbol_value(mut tokens) or { return none }
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
		end:   second_value
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

fn parse_counter_style_nonnegative_integer_symbol_pair_value(mut tokens ParserTokenStream) ?CounterStyleAdditiveSymbolTupleStyleValue {
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

		if symbol_value := parse_counter_style_symbol_value(mut tokens) {
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
	pair := parse_counter_style_nonnegative_integer_symbol_pair_value(mut tokens) or { return none }
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
		tuple := parse_counter_style_nonnegative_integer_symbol_pair_value(mut tokens) or {
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
	tokens.index = tokens.values.len - 1
	return parse_page_selector_list(text)
}

fn convert_to_page_descriptor_for_rule_parsing(declaration Declaration) ?Descriptor {
	descriptor_id := descriptor_id_from_string(.page, declaration.name) or { return none }
	value_text := parser_component_values_to_string(declaration.value).trim_space()
	value := parse_css_descriptor_value_for_cssom(.page, descriptor_id, value_text) or {
		return none
	}
	return Descriptor{
		descriptor_id:    descriptor_id
		value:            value.value
		serialized_value: value.serialized
	}
}

fn declarations_from_at_rule(rule AtRule) ParserRuleDeclarations {
	mut declarations := []Declaration{}
	rule.for_each_as_declaration_list(fn [mut declarations] (declaration Declaration) {
		declarations << declaration
	})
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
		selector_parts :=
			parser.consume_a_list_of_component_values(mut tokens, TokenType.comma, .no)
		selector_text := parser_component_values_to_string(selector_parts).trim_space()
		if selector_text.len == 0 {
			if parsing_mode == .forgiving {
				selectors.selectors << Selector{
					text: ''
				}
			} else {
				return none
			}
		} else if parser_selector_text_is_syntactically_valid(selector_text, mode,
			parser.declared_namespaces)
		{
			// The current V selector model stores raw selector text and builds a lightweight parsed tree on demand.
			mut parsed := selector_list_from_text(selector_text, mode == .relative)
			if parsed.selectors.len == 0 {
				parsed.selectors << Selector{
					text: selector_text
				}
			}
			for selector in parsed.selectors {
				selectors.selectors << selector
			}
		} else if parsing_mode == .forgiving {
			selectors.selectors << Selector{
				text: selector_text
			}
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
		declaration.value.delete(important_index)
		declaration.value.delete(bang_index)
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

fn parser_component_values_to_string(values []ComponentValue) string {
	mut builder := ''
	for value in values {
		if value.is(.end_of_file) {
			continue
		}
		builder += value.to_string()
	}
	return builder
}

fn parser_component_values_original_text(values []ComponentValue) string {
	mut builder := ''
	for value in values {
		builder += value.original_source_text()
	}
	return builder
}

fn parser_is_valid_layer_name_part(token ComponentValue) bool {
	return token.is(.ident) && !is_css_wide_keyword_local(token.token().ident())
}

fn parser_selector_text_is_syntactically_valid(selector_text string, mode ParserSelectorType, declared_namespaces map[string]bool) bool {
	trimmed := selector_text.trim_space()
	if trimmed.len == 0 {
		return false
	}
	if mode == .standalone && (trimmed.starts_with('>') || trimmed.starts_with('+')
		|| trimmed.starts_with('~')) {
		return false
	}
	if trimmed.ends_with('>') || trimmed.ends_with('+') || trimmed.ends_with('~')
		|| trimmed.ends_with(',') {
		return false
	}
	if !parser_balanced_selector_text(trimmed) {
		return false
	}
	if selector_text_has_invalid_simple_selectors(trimmed, mode == .relative) {
		return false
	}
	return !parser_selector_uses_undeclared_namespace(trimmed, declared_namespaces)
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
		match ch {
			`"`, `'` { quote = ch }
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

fn parser_selector_uses_undeclared_namespace(text string, declared_namespaces map[string]bool) bool {
	for selector_text in split_selector_list_text(text) {
		if parser_complex_selector_uses_undeclared_namespace(selector_text.trim_space(),
			declared_namespaces)
		{
			return true
		}
	}
	return false
}

fn parser_complex_selector_uses_undeclared_namespace(text string, declared_namespaces map[string]bool) bool {
	for compound_selector in parse_complex_selector(text) {
		for simple_selector in compound_selector.simple_selectors {
			if parser_simple_selector_uses_undeclared_namespace(simple_selector,
				declared_namespaces)
			{
				return true
			}
		}
	}
	return false
}

fn parser_simple_selector_uses_undeclared_namespace(simple_selector SimpleSelector, declared_namespaces map[string]bool) bool {
	match simple_selector.type_ {
		.tag_name, .universal {
			return parser_qualified_name_uses_undeclared_namespace(simple_selector.qualified_name,
				declared_namespaces)
		}
		.attribute {
			return parser_qualified_name_uses_undeclared_namespace(simple_selector.attribute.qualified_name,
				declared_namespaces)
		}
		.pseudo_class {
			for selector in simple_selector.pseudo_class.argument_selector_list.selectors {
				if parser_selector_uses_undeclared_namespace(selector.text, declared_namespaces) {
					return true
				}
			}
		}
		.pseudo_element {
			if selector := simple_selector.pseudo_element.compound_selector {
				return parser_selector_uses_undeclared_namespace(selector.text, declared_namespaces)
			}
		}
		else {}
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
		.style, .keyframe { true }
		.layer, .media, .supports { rule_context_contains(parser.rule_context, .style) }
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
		return ascii_case_insensitive_name_is_one_of(rule.name, ['layer', 'media', 'supports'])
	}

	last_context := parser.rule_context[parser.rule_context.len - 1]
	return match last_context {
		.unknown {
			false
		}
		.style {
			false
		}
		.layer, .media, .supports {
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
		.layer, .media, .supports {
			true
		}
		.keyframes {
			true
		}
		.supports_condition {
			false
		}
		.counter_style, .font_face, .font_feature_values, .font_feature_value, .page, .property,
		.keyframe, .margin {
			false
		}
	}
}

fn rule_context_type_for_at_rule_local(name string) RuleContext {
	if equals_ignoring_ascii_case(name, 'media') {
		return .media
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
	if is_font_feature_value_type_at_keyword_local(name) {
		return .font_feature_value
	}
	if equals_ignoring_ascii_case(name, 'supports') {
		return .supports
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

fn parser_report_error(error ParsingError) {
	_ = serialize_parsing_error(error)
}

pub enum SubstitutionDependencyType {
	property
	attribute
	function
}

pub struct SubstitutionContext {
pub mut:
	dependency_type SubstitutionDependencyType
	first           string
	second          ?string
	is_cyclic       bool
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
	contexts []SubstitutionContext
}

pub fn (mut contexts GuardedSubstitutionContexts) guard(mut context SubstitutionContext) {
	for mut existing_context in contexts.contexts {
		if existing_context.dependency_type == context.dependency_type
			&& existing_context.first == context.first
			&& option_string_equal(existing_context.second, context.second) {
			existing_context.is_cyclic = true
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
			&& option_string_equal(existing_context.second, context.second) {
			contexts.contexts.delete(index)
			return
		}
	}
}

fn (contexts GuardedSubstitutionContexts) is_marked_cyclic(context SubstitutionContext) bool {
	for existing_context in contexts.contexts {
		if existing_context.dependency_type == context.dependency_type
			&& existing_context.first == context.first
			&& option_string_equal(existing_context.second, context.second) {
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

fn parse_arbitrary_declaration_value(mut tokens ParserTokenStream, end_token_type ?TokenType) ?[]ComponentValue {
	start_index := tokens.index
	mut declaration_value := []ComponentValue{}
	for tokens.has_next_token() {
		peek := tokens.next_token()
		if !peek.is_token() {
			declaration_value << tokens.consume_a_token()
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
		declaration_value << tokens.consume_a_token()
	}

	if declaration_value.len == 0 {
		tokens.index = start_index
		return none
	}
	return declaration_value
}

fn parse_declaration_value_then_optional_declaration_value(mut tokens ParserTokenStream, separator TokenType) ?DeclarationValueList {
	first_argument := parse_arbitrary_declaration_value(mut tokens, separator) or { return none }

	if !tokens.has_next_token() {
		return DeclarationValueList{
			values: [first_argument]
		}
	}

	if !tokens.next_token().is(separator) {
		return none
	}

	tokens.discard_a_token()
	second_argument := parse_arbitrary_declaration_value(mut tokens, none) or { []ComponentValue{} }
	return DeclarationValueList{
		values: [first_argument, second_argument]
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
				if_args_branch := parse_declaration_value_then_optional_declaration_value(mut tokens,
					.colon) or { break }

				args.branches << IfArgsBranch{
					condition: if_args_branch.first()
					value:     if_args_branch.get(1)
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
		return [ComponentValue.from_token(Token.create_string('', ''))]
	}

	// 2. If second arg is null, return the guaranteed-invalid value.
	if second_argument == none {
		return arbitrary_substitution_guaranteed_invalid_value()
	}

	// 3. Substitute arbitrary substitution functions in second arg, and return the result.
	return substitute_arbitrary_substitution_functions_with_optional_element(element, mut
		guarded_contexts, second_argument, none)
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

	substituted := substitute_arbitrary_substitution_functions_with_optional_element(element, mut
		guarded_contexts, first_argument, none)
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
			return [ComponentValue.from_token(Token.create_number(parsed_number, ''))]
		}
		if syntax.unit == '%' {
			return [
				ComponentValue.from_token(Token.create_percentage(parsed_number, '')),
			]
		}
		return [
			ComponentValue.from_token(Token.create_dimension(parsed_number, syntax.unit, '')),
		]
	}

	if syntax.kind == .omitted || syntax.kind == .raw_string {
		return [ComponentValue.from_token(Token.create_string(attribute_value, ''))]
	}

	syntax_node := syntax.syntax or {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}

	unsubstituted_values := parse_component_values_for_value_logic(attribute_value)
	substituted_values := substitute_arbitrary_substitution_functions_with_optional_element(element, mut
		guarded_contexts, unsubstituted_values, SubstitutionContext{
		dependency_type: .attribute
		first:           attribute_name
	})
	parsed_value := parse_with_a_syntax(substituted_values, syntax_node)
	if parsed_value.type_() == .guaranteed_invalid {
		return attr_failure_result(element, mut guarded_contexts, second_argument, syntax)
	}
	return style_value_to_component_values_for_substitution(parsed_value)
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
		.viewport_segment_bottom, .viewport_segment_height, .viewport_segment_left,
		.viewport_segment_right, .viewport_segment_top, .viewport_segment_width {
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

	substituted_first_argument := substitute_arbitrary_substitution_functions_with_optional_element(element, mut
		guarded_contexts, first_argument, none)
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
		return substitute_arbitrary_substitution_functions_with_optional_element(element, mut
			guarded_contexts, fallback, none)
	}

	return arbitrary_substitution_guaranteed_invalid_value()
}

fn parse_if_condition_for_arbitrary_substitution(condition []ComponentValue) ?MatchResult {
	mut else_tokens := SupportsTokenStream.from_values(condition)
	else_tokens.discard_whitespace()
	if token := else_tokens.consume_a_token() {
		else_tokens.discard_whitespace()
		if !else_tokens.has_next_token() && token.is_ident('else') {
			// The else keyword represents a condition that is always true.
			return .true_
		}
	}

	mut tokens := SupportsTokenStream.from_values(condition)
	expression := parse_if_boolean_expression(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return expression.evaluate(none)
}

// https://drafts.csswg.org/css-values-5/#typedef-if-condition
fn parse_if_boolean_expression(mut tokens SupportsTokenStream) ?&BooleanExpression {
	return parse_if_boolean_expression_inner(mut tokens, .false_)
}

fn parse_if_boolean_expression_inner(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	if peeked_token := transaction.next_token() {
		if peeked_token.is_ident('not') {
			transaction.discard_a_token()
			transaction.discard_whitespace()
			child := parse_if_boolean_expression_group(mut transaction, result_for_general_enclosed) or {
				return none
			}
			transaction.discard_whitespace()
			tokens = transaction
			return BooleanExpression.create_not(child)
		}
	}

	mut children := []&BooleanExpression{}
	mut combinator := ?string(none)
	for transaction.has_next_token() {
		if children.len != 0 {
			token := transaction.consume_a_token() or { return none }
			if !token.is(.ident) {
				return none
			}
			maybe_combinator := token.token().ident().to_lower()
			if maybe_combinator != 'and' && maybe_combinator != 'or' {
				return none
			}
			if existing := combinator {
				if existing != maybe_combinator {
					return none
				}
			} else {
				combinator = maybe_combinator
			}
		}

		transaction.discard_whitespace()
		child := parse_if_boolean_expression_group(mut transaction, result_for_general_enclosed) or {
			return none
		}
		children << child
		transaction.discard_whitespace()
	}

	if children.len == 0 {
		return none
	}

	tokens = transaction
	if children.len == 1 {
		return children[0]
	}

	if combinator_value := combinator {
		if combinator_value == 'and' {
			return BooleanExpression.create_and(children)
		}
		if combinator_value == 'or' {
			return BooleanExpression.create_or(children)
		}
	}
	return none
}

fn parse_if_boolean_expression_group(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	if first_token := tokens.next_token() {
		if first_token.is_block() && first_token.block().is_paren() {
			mut transaction := tokens
			transaction.discard_a_token()
			mut child_tokens := SupportsTokenStream.from_values(first_token.block().value)
			if expression := parse_if_boolean_expression_inner(mut child_tokens,
				result_for_general_enclosed)
			{
				child_tokens.discard_whitespace()
				if !child_tokens.has_next_token() {
					tokens = transaction
					return BooleanExpression.create_in_parens(expression)
				}
			}
		}
	}

	if test := parse_if_test(mut tokens) {
		return test
	}

	return none
}

fn parse_if_test(mut tokens SupportsTokenStream) ?&BooleanExpression {
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
		if supports_declaration := parse_supports_declaration_from_parser_tokens(mut declaration_tokens) {
			tokens = transaction
			return supports_declaration
		}

		mut condition_tokens := SupportsTokenStream.from_values(function.value)
		if supports_condition := parse_supports_condition(mut condition_tokens) {
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
		if media_feature := parse_media_feature(mut feature_tokens) {
			feature_tokens.discard_whitespace()
			if !feature_tokens.has_next_token() {
				tokens = transaction
				return media_feature
			}
		}

		mut condition_tokens := SupportsTokenStream.from_values(function.value)
		if media_condition := parse_media_condition(mut condition_tokens) {
			condition_tokens.discard_whitespace()
			if !condition_tokens.has_next_token() {
				tokens = transaction
				return media_condition
			}
		}
		return none
	}

	// FIXME: Support style().
	return none
}

fn replace_an_if_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-values-5/#replace-an-if-function
	if_args := arbitrary_arguments_as_if_args(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}

	for branch in if_args.branches {
		substituted_condition := substitute_arbitrary_substitution_functions_with_optional_element(element, mut
			guarded_contexts, branch.condition, none)
		condition_result := parse_if_condition_for_arbitrary_substitution(substituted_condition) or {
			continue
		}
		if condition_result == .false_ {
			continue
		}
		value := branch.value or { return []ComponentValue{} }
		return substitute_arbitrary_substitution_functions_with_optional_element(element, mut
			guarded_contexts, value, none)
	}

	return []ComponentValue{}
}

fn custom_property_tokens_from_element_for_substitution(abstract_element dom.AbstractElement, custom_property_name string) ?[]ComponentValue {
	value := abstract_element.get_custom_property(custom_property_name) or { return none }
	if value.guaranteed_invalid {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	return parse_component_values_for_value_logic(value.css_text)
}

fn computed_custom_property_tokens_for_substitution(abstract_element dom.AbstractElement, custom_property_name string) ?[]ComponentValue {
	if tokens := custom_property_tokens_from_element_for_substitution(abstract_element,
		custom_property_name)
	{
		return tokens
	}
	if initial_value := abstract_element.document().custom_property_initial_value(custom_property_name) {
		// Mirrors StyleComputer::compute_value_of_custom_property() for the representable no-specified-value case:
		// registered custom properties fall back to their document initial value, while unregistered properties remain
		// the guaranteed-invalid initial value and are handled by the caller's fallback path.
		return parse_component_values_for_value_logic(initial_value)
	}
	return none
}

fn replace_an_inherit_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-values-5/#replace-an-inherit-function
	declaration_value_list := arbitrary_arguments_as_declaration_value_list(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	first_argument := declaration_value_list.first()
	second_argument := declaration_value_list.get(1)

	substituted_first_argument := substitute_arbitrary_substitution_functions_with_optional_element(element, mut
		guarded_contexts, first_argument, none)
	mut first_argument_tokens := ParserTokenStream.from_values(substituted_first_argument)
	first_argument_tokens.discard_whitespace()
	name_token := first_argument_tokens.consume_a_token()
	first_argument_tokens.discard_whitespace()

	if name_token.is(.ident) && is_a_custom_property_name_string(name_token.token().ident())
		&& !first_argument_tokens.has_next_token() {
		if el := element {
			if element_to_inherit_style_from := el.element_to_inherit_style_from() {
				if inherited_value := custom_property_tokens_from_element_for_substitution(element_to_inherit_style_from,
					name_token.token().ident())
				{
					if !contains_guaranteed_invalid_value(inherited_value) {
						return inherited_value
					}
				}
			}
		}
	}

	if fallback := second_argument {
		return substitute_arbitrary_substitution_functions_with_optional_element(element, mut
			guarded_contexts, fallback, none)
	}

	return arbitrary_substitution_guaranteed_invalid_value()
}

fn replace_a_var_function(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, arguments ArbitrarySubstitutionFunctionArguments) []ComponentValue {
	// https://drafts.csswg.org/css-variables-1/#replace-a-var-function
	declaration_value_list := arbitrary_arguments_as_declaration_value_list(arguments) or {
		return arbitrary_substitution_guaranteed_invalid_value()
	}
	first_argument := declaration_value_list.first()
	second_argument := declaration_value_list.get(1)

	substituted_first_argument := substitute_arbitrary_substitution_functions_with_optional_element(element, mut
		guarded_contexts, first_argument, none)
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
		result = computed_custom_property_tokens_for_substitution(el, custom_property_name) or {
			arbitrary_substitution_guaranteed_invalid_value()
		}
	} else {
		result = arbitrary_substitution_guaranteed_invalid_value()
	}

	// FIXME: Animation-tainted custom properties.
	if contains_guaranteed_invalid_value(result) {
		if fallback := second_argument {
			result = substitute_arbitrary_substitution_functions_with_optional_element(element, mut
				guarded_contexts, fallback, none)
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

fn substitute_arbitrary_substitution_functions_step_2(element ?dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, source []ComponentValue) ?[]ComponentValue {
	mut dest := []ComponentValue{}
	for index, value in source {
		if value.is_function() {
			source_function := value.function()
			if maybe_function_id := to_arbitrary_substitution_function(source_function.name) {
				// FIXME: Substitute early-invoked functions in func's contents.
				early_result := source_function.value
				if contains_guaranteed_invalid_value(early_result) {
					dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
					continue
				}

				arguments := parse_according_to_argument_grammar(maybe_function_id, early_result) or {
					dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
					continue
				}
				result := replace_an_arbitrary_substitution_function(element, mut guarded_contexts,
					maybe_function_id, arguments)

				if contains_guaranteed_invalid_value(result) {
					dest << ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})
				} else {
					result_after_processing := substitute_arbitrary_substitution_functions_step_2(element, mut
						guarded_contexts, result) or { return none }

					// NB: Protect against the billion-laughs attack by limiting to an arbitrary large number of tokens.
					// https://drafts.csswg.org/css-values-5/#long-substitution
					if source.len - index - 1 + result_after_processing.len > 16384 {
						return none
					}
					dest << result_after_processing
				}
				continue
			}

			function_values := substitute_arbitrary_substitution_functions_step_2(element, mut
				guarded_contexts, source_function.value) or { return none }
			mut function := source_function
			function.value = function_values
			dest << ComponentValue.from_function(function)
			continue
		}

		if value.is_block() {
			source_block := value.block()
			block_values := substitute_arbitrary_substitution_functions_step_2(element, mut
				guarded_contexts, source_block.value) or { return none }
			mut block := source_block
			block.value = block_values
			dest << ComponentValue.from_block(block)
			continue
		}

		dest << value
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

	mut new_values := substitute_arbitrary_substitution_functions_step_2(element, mut
		guarded_contexts, values) or { arbitrary_substitution_guaranteed_invalid_value() }

	if guarded_context := context_to_unguard {
		if guarded_contexts.is_marked_cyclic(guarded_context) {
			new_values = arbitrary_substitution_guaranteed_invalid_value()
		}
		guarded_contexts.unguard(guarded_context)
	}

	return new_values
}

pub fn substitute_arbitrary_substitution_functions_for_element(element dom.AbstractElement, mut guarded_contexts GuardedSubstitutionContexts, values []ComponentValue, context ?SubstitutionContext) []ComponentValue {
	return substitute_arbitrary_substitution_functions_with_optional_element(element, mut
		guarded_contexts, values, context)
}

pub fn substitute_arbitrary_substitution_functions(values []ComponentValue, context ?SubstitutionContext) []ComponentValue {
	mut guarded_contexts := GuardedSubstitutionContexts{}
	return substitute_arbitrary_substitution_functions_with_optional_element(none, mut
		guarded_contexts, values, context)
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
	mut parser := RuleSelectorParser.create(ParsingParams{}, css_text, 'utf-8')
	return parser.parse_as_css_stylesheet(location, none)
}

pub fn parse_css_stylesheet_contents_with_params(params ParsingParams, css_text string) []&CSSRule {
	mut parser := RuleSelectorParser.create(params, css_text, 'utf-8')
	return parser.parse_as_stylesheet_contents()
}

pub fn parse_css_stylesheet_contents_with_parser(css_text string, declared_namespaces map[string]bool) []&CSSRule {
	return parse_css_stylesheet_contents_with_params(ParsingParams{
		declared_namespaces: declared_namespaces
	}, css_text)
}

pub fn parse_css_rule_with_params(params ParsingParams, rule_text string) ?&CSSRule {
	mut parser := RuleSelectorParser.create(params, rule_text, 'utf-8')
	return parser.parse_as_css_rule()
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

pub fn parse_selector_for_nested_style_rule_with_parser(selector_text string, declared_namespaces map[string]bool) ?SelectorList {
	mut parser := RuleSelectorParser.create_with_namespaces(selector_text, declared_namespaces)
	return parser.parse_as_relative_selector(.standard)
}
