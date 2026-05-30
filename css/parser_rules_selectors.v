module css

// This file ports Ladybird's LibWeb/CSS/Parser rule, selector, parser orchestration,
// rule-context, error-reporter, and arbitrary-substitution-function glue into the
// smaller V CSS model. Where the generated parser tables, full selector AST, DOM
// integration, or CSSRule subclasses do not exist in this port yet, explicit local
// stubs keep the translated control flow visible.

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
	_ = params
	tokens := Tokenizer.tokenize(input, encoding)
	return RuleSelectorParser{
		tokens:              tokens
		token_stream:        ParserTokenStream.from_tokens(tokens)
		declared_namespaces: map[string]bool{}
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
		if token.is(.open_curly) {
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
	type_of_qualified_rule := RuleContext.style

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
		if token.is(.open_curly) {
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
	// To consume a block, from a token stream input:
	// Assert: The next token is a <{-token>.
	assert input.next_token().is(.open_curly)

	// Discard a token from input.
	input.discard_a_token()
	// Consume a block's contents from input and let rules be the result.
	rules := parser.consume_a_blocks_contents(mut input)
	// Discard a token from input.
	input.discard_a_token()

	// Return rules.
	return rules
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

fn (mut parser RuleSelectorParser) consume_qualified_rule_in_block(mut input ParserTokenStream, mut rules []RuleOrListOfDeclarations, mut declarations []Declaration) {
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
	if parser.is_valid_declaration_in_the_current_context(declaration) {
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
			if equals_ignoring_ascii_case(rule.name, 'import') {
				return parser.convert_to_import_rule(rule)
			}
			if equals_ignoring_ascii_case(rule.name, 'layer') {
				return parser.convert_to_layer_rule(rule, nested)
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
			if equals_ignoring_ascii_case(rule.name, 'font-face') {
				return CSSRule.create_grouping(.font_face, CSSRuleList.create_empty())
			}
			if equals_ignoring_ascii_case(rule.name, 'page') {
				return CSSRule.create_grouping(.page, CSSRuleList.create_empty())
			}
			if equals_ignoring_ascii_case(rule.name, 'property') {
				return CSSRule.create(.property)
			}
			if equals_ignoring_ascii_case(rule.name, 'counter-style') {
				return CSSRule.create(.counter_style)
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
		supports = parse_css_supports(ParsingParams{}, condition)
		tokens.discard_whitespace()
	}

	media_text :=
		parser_component_values_to_string(tokens.values[tokens.index..tokens.values.len - 1]).trim_space()
	mut media := MediaList.create_empty()
	if media_text.len > 0 {
		mut mutable_media := unsafe { &MediaList(media) }
		mutable_media.set_media_text(media_text)
	}
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
		mut layer_rule := CSSRule.create_grouping(.layer_block, CSSRuleList.create(child_rules))
		layer_rule.layer = layer_name
		layer_rule.layer_internal = if layer_name.len == 0 {
			next_unique_anonymous_layer_name_stub()
		} else {
			layer_name
		}
		return layer_rule
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
	mut layer_rule := CSSRule.create(.layer_statement)
	layer_rule.layer = layer_names.join(', ')
	return layer_rule
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
	supports := parse_css_supports(ParsingParams{}, condition) or { return none }
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
	mut keyframes_rule := CSSRule.create_grouping(.keyframes, CSSRuleList.create_empty())
	keyframes_rule.url = name_token.to_string()
	return keyframes_rule
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

fn (mut parser RuleSelectorParser) convert_to_style_declaration(declarations []Declaration) &CSSStyleProperties {
	_ = parser
	mut style := CSSStyleProperties.create()
	for declaration in declarations {
		value := parser_component_values_to_string(declaration.value).trim_space()
		if is_a_custom_property_name_string(declaration.name) {
			style.custom_properties[declaration.name] = if original := declaration.original_value_text {
				original
			} else {
				value
			}
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
	return !parser_selector_uses_undeclared_namespace(trimmed, declared_namespaces)
}

fn parser_balanced_selector_text(text string) bool {
	mut parens := 0
	mut squares := 0
	for ch in text {
		match ch {
			`(` { parens++ }
			`)` { parens-- }
			`[` { squares++ }
			`]` { squares-- }
			else {}
		}

		if parens < 0 || squares < 0 {
			return false
		}
	}
	return parens == 0 && squares == 0
}

fn parser_selector_uses_undeclared_namespace(text string, declared_namespaces map[string]bool) bool {
	// Stub for parse_selector_qualified_name(): recognizes the common `prefix|name` spelling and applies the
	// Selectors invalid-namespace rule. Full namespace tokenization belongs in the future selector AST port.
	for part in text.fields() {
		if part.contains('|') && !part.starts_with('|') && !part.starts_with('*|') {
			prefix := part.all_before('|').trim_left('>+~,.#[:')
			if prefix.len > 0 && prefix !in declared_namespaces {
				return true
			}
		}
	}
	return false
}

fn (parser RuleSelectorParser) is_valid_declaration_in_the_current_context(declaration Declaration) bool {
	_ = parser
	if declaration.name.len == 0 {
		return false
	}
	return true
}

fn (parser RuleSelectorParser) is_valid_at_rule_in_the_current_context(rule AtRule) bool {
	_ = parser
	_ = rule
	return true
}

fn (parser RuleSelectorParser) is_valid_qualified_rule_in_the_current_context(rule QualifiedRule) bool {
	_ = parser
	return rule.prelude.len > 0
}

fn rule_context_type_for_at_rule_local(name string) RuleContext {
	if equals_ignoring_ascii_case(name, 'media') {
		return .media
	}
	if equals_ignoring_ascii_case(name, 'supports') {
		return .supports
	}
	if equals_ignoring_ascii_case(name, 'layer') {
		return .layer
	}
	if equals_ignoring_ascii_case(name, 'page') {
		return .page
	}
	return .top_level
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
			&& existing_context.first == context.first && existing_context.second == context.second {
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
			&& existing_context.first == context.first && existing_context.second == context.second {
			contexts.contexts.delete(index)
			return
		}
	}
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

pub fn substitute_arbitrary_substitution_functions(values []ComponentValue, context ?SubstitutionContext) []ComponentValue {
	// Explicit stub: CSS Values 5 arbitrary substitution needs DOM::AbstractElement, registered custom properties,
	// environment variables, and parse-with-syntax support. Preserve guaranteed-invalid propagation for callers.
	_ = context
	if contains_guaranteed_invalid_value(values) {
		return [ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
	}
	return values.clone()
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

pub fn parse_css_stylesheet_contents_with_parser(css_text string, declared_namespaces map[string]bool) []&CSSRule {
	mut parser := RuleSelectorParser.create_with_namespaces(css_text, declared_namespaces)
	return parser.parse_as_stylesheet_contents()
}

pub fn parse_css_rule_with_parser(rule_text string, declared_namespaces map[string]bool) ?&CSSRule {
	mut parser := RuleSelectorParser.create_with_namespaces(rule_text, declared_namespaces)
	return parser.parse_as_css_rule()
}

pub fn parse_css_property_declaration_block_with_parser(block string) &CSSStyleProperties {
	mut body := block.trim_space()
	if body.starts_with('{') && body.ends_with('}') {
		body = body[1..body.len - 1]
	}

	mut parser := RuleSelectorParser.create(ParsingParams{}, body, 'utf-8')
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
