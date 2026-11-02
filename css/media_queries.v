module css

import dom
import strings

// Translated media/support CSSOM logic formerly hosted as stubs in cssom_rules.v.

@[heap]
pub struct Supports {
pub mut:
	condition &BooleanExpression = unsafe { nil }
	matches   bool
}

pub fn Supports.create(condition &BooleanExpression) &Supports {
	return &Supports{
		condition: condition
		matches: condition.evaluate_to_boolean(BooleanExpressionEvaluationContext{})
	}
}

pub fn (supports &Supports) to_string() string {
	return supports.condition.to_string()
}

pub fn (supports &Supports) matches_condition() bool {
	return supports.matches
}

pub fn (supports &Supports) dump(indent_levels int) string {
	return '${cssom_indent(indent_levels)}Supports condition: (matches = ${supports.matches})\n${supports.condition.dump(indent_levels + 1)}'
}

pub fn parse_css_supports(context ParsingParams, condition_text string) ?&Supports {
	mut parser := Parser.with_context(context, condition_text)
	return parser.parse_as_supports()
}

struct SupportsTokenStream {
mut:
	values              []ComponentValue
	index               int
	declared_namespaces map[string]bool
}

fn SupportsTokenStream.from_values(values []ComponentValue) SupportsTokenStream {
	return SupportsTokenStream{
		values: values.clone()
		declared_namespaces: map[string]bool{}
	}
}

fn SupportsTokenStream.from_values_with_namespaces(values []ComponentValue, declared_namespaces map[string]bool) SupportsTokenStream {
	return SupportsTokenStream{
		values: values.clone()
		declared_namespaces: declared_namespaces.clone()
	}
}

// fork returns an independent copy for a transaction. Current V moves some
// transaction locals to the heap; for `mut transaction := tokens` with a mut
// parameter it then copies the bytes of the parameter's pointer instead of the
// stream, so take the copy through a call.
fn (tokens SupportsTokenStream) fork() SupportsTokenStream {
	return tokens
}

fn (tokens SupportsTokenStream) has_next_token() bool {
	return tokens.index < tokens.values.len
}

fn (tokens SupportsTokenStream) next_token() ?ComponentValue {
	if !tokens.has_next_token() {
		return none
	}
	return tokens.values[tokens.index]
}

fn (mut tokens SupportsTokenStream) consume_a_token() ?ComponentValue {
	token := tokens.next_token() or { return none }
	tokens.index++
	return token
}

fn (mut tokens SupportsTokenStream) discard_a_token() {
	if tokens.has_next_token() {
		tokens.index++
	}
}

fn (mut tokens SupportsTokenStream) discard_whitespace() {
	for {
		token := tokens.next_token() or { return }
		if !token.is(.whitespace) {
			return
		}
		tokens.index++
	}
}

// https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition
fn parse_supports_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut parser := Parser{
		context: ParsingParams{
			declared_namespaces: tokens.declared_namespaces
		}
	}
	return parser.parse_supports_condition(mut tokens)
}

enum BooleanExpressionParseTest {
	supports_feature
	media_in_parens
	if_test
	container_query_feature
	style_feature
}

// https://drafts.csswg.org/css-values-5/#typedef-boolean-expr
fn (mut parser Parser) parse_boolean_expression(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult, parse_test BooleanExpressionParseTest) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	// `not <boolean-expr-group>`
	if peeked_token := transaction.next_token() {
		if peeked_token.is_ident('not') {
			transaction.discard_a_token()
			transaction.discard_whitespace()
			child := parser.parse_boolean_expression_group(mut transaction, result_for_general_enclosed, parse_test) or { return none }
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
		child := parser.parse_boolean_expression_group(mut transaction, result_for_general_enclosed, parse_test) or { return none }
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

fn (mut parser Parser) parse_boolean_expression_group(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult, parse_test BooleanExpressionParseTest) ?&BooleanExpression {
	// <boolean-expr-group> = <test> | ( <boolean-expr[ <test> ]> ) | <general-enclosed>
	if first_token := tokens.next_token() {
		if first_token.is_block() && first_token.block().is_paren() {
			mut transaction := tokens
			transaction.discard_a_token()
			mut child_tokens := SupportsTokenStream.from_values_with_namespaces(first_token.block().value, tokens.declared_namespaces)
			if expression := parser.parse_boolean_expression(mut child_tokens, result_for_general_enclosed, parse_test) {
				child_tokens.discard_whitespace()
				if !child_tokens.has_next_token() {
					tokens = transaction
					return BooleanExpression.create_in_parens(expression)
				}
			}
		}
	}

	match parse_test {
		.supports_feature {
			if test := parser.parse_supports_feature(mut tokens) {
				return test
			}
		}
		.media_in_parens {
			if test := parser.parse_media_in_parens(mut tokens) {
				return test
			}
		}
		.if_test {
			if test := parser.parse_if_test(mut tokens) {
				return test
			}
		}
		.container_query_feature {
			if test := parser.parse_container_query_feature(mut tokens) {
				return test
			}
		}
		.style_feature {
			if test := parser.parse_style_feature(mut tokens) {
				return test
			}
		}
	}

	if general_enclosed := parser.parse_general_enclosed(mut tokens, result_for_general_enclosed) {
		return general_enclosed
	}

	return none
}

// https://drafts.csswg.org/css-conditional-3/#typedef-supports-condition
fn (mut parser Parser) parse_supports_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	return parser.parse_boolean_expression(mut tokens, .false_, .supports_feature)
}

fn at_rule_is_supported(name string) bool {
	// https://drafts.csswg.org/css-conditional-5/#support-definition-at-rules
	// @charset is intentionally excluded because it is not a valid at-rule.
	if equals_ignoring_ascii_case(name, 'charset') {
		return false
	}
	if ascii_case_insensitive_name_is_one_of(name, [
		'container',
		'counter-style',
		'font-face',
		'font-feature-values',
		'function',
		'import',
		'keyframes',
		'-webkit-keyframes',
		'layer',
		'media',
		'namespace',
		'page',
		'property',
		'scope',
		'supports',
	]) {
		return true
	}
	return is_font_feature_value_type_at_keyword_local(name) || is_margin_rule_name(name)
}

// https://drafts.csswg.org/css-conditional-5/#typedef-supports-feature
fn (mut parser Parser) parse_supports_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first_token := transaction.consume_a_token() or { return none }

	// `<supports-decl> = ( <declaration> )`
	if first_token.is_block() && first_token.block().is_paren() {
		mut block_tokens := ParserTokenStream.from_values(first_token.block().value)
		if declaration := parser.parse_supports_declaration(mut block_tokens) {
			transaction.discard_whitespace()
			tokens = transaction
			return BooleanExpression.create_in_parens(declaration)
		}
	}

	// `<supports-selector-fn> = selector( <complex-selector> )`
	if first_token.is_function_named('selector') {
		selector := supports_component_values_to_string(first_token.function().value)
		mut selector_parser := RuleSelectorParser.create(parser.context, selector, 'utf-8')
		is_match := selector_parser.parse_as_selector(.standard) != none
			&& !supports_selector_contains_unknown_webkit_pseudo_element(selector)
		tokens = transaction
		return BooleanExpression.create_supports_selector(selector, is_match)
	}

	// `<supports-font-tech-fn> = font-tech( <font-tech> )`
	if first_token.is_function_named('font-tech') {
		mut tech_tokens := SupportsTokenStream.from_values(first_token.function().value)
		tech_tokens.discard_whitespace()
		tech_token := tech_tokens.consume_a_token() or { return none }
		tech_tokens.discard_whitespace()
		if tech_tokens.has_next_token() || !tech_token.is(.ident) {
			return none
		}
		tech_name := tech_token.token().ident()
		tokens = transaction
		return BooleanExpression.create_supports_font_tech(tech_name, font_tech_is_supported_name(tech_name))
	}

	// `<supports-font-format-fn> = font-format( <font-format> )`
	if first_token.is_function_named('font-format') {
		mut format_tokens := SupportsTokenStream.from_values(first_token.function().value)
		format_tokens.discard_whitespace()
		format_token := format_tokens.consume_a_token() or { return none }
		format_tokens.discard_whitespace()
		if format_tokens.has_next_token() || !format_token.is(.ident) {
			return none
		}
		format_name := format_token.token().ident()
		tokens = transaction
		return BooleanExpression.create_supports_font_format(format_name, font_format_is_supported(format_name))
	}

	// `<supports-env-fn> = env( <ident> )`
	if first_token.is_function_named('env') {
		mut variable_tokens := SupportsTokenStream.from_values(first_token.function().value)
		variable_tokens.discard_whitespace()
		variable_token := variable_tokens.consume_a_token() or { return none }
		variable_tokens.discard_whitespace()
		if variable_tokens.has_next_token() || !variable_token.is(.ident) {
			return none
		}
		variable_name := variable_token.token().ident()
		tokens = transaction
		return BooleanExpression.create_supports_env(variable_name,
			environment_variable_from_string_local(variable_name) != none)
	}

	// `<supports-at-rule-fn> = at-rule( <at-keyword-token> )`
	if first_token.is_function_named('at-rule') {
		mut at_rule_tokens := SupportsTokenStream.from_values(first_token.function().value)
		at_rule_tokens.discard_whitespace()
		at_rule_token := at_rule_tokens.consume_a_token() or { return none }
		at_rule_tokens.discard_whitespace()
		if at_rule_tokens.has_next_token() || !at_rule_token.is(.at_keyword) {
			return none
		}
		at_rule_name := at_rule_token.token().at_keyword()
		tokens = transaction
		return BooleanExpression.create_supports_at_rule(at_rule_name, at_rule_is_supported(at_rule_name))
	}

	return none
}

// https://drafts.csswg.org/css-conditional-5/#typedef-supports-decl
fn (mut parser Parser) parse_supports_declaration(mut tokens ParserTokenStream) ?&BooleanExpression {
	mut rule_context := parser.context.rule_context.clone()
	rule_context << .supports_condition
	mut declaration_parser := RuleSelectorParser.create(ParsingParams{
		document: parser.context.document
		mode: parser.context.mode
		value_context: parser.value_context.clone()
		rule_context: rule_context
		declared_namespaces: parser.context.declared_namespaces
		is_ua_style_sheet: parser.context.is_ua_style_sheet
	}, '', 'utf-8')
	declaration := declaration_parser.consume_a_declaration(mut tokens, .no, .yes) or {
		return none
	}
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}

	value_text := supports_component_values_to_string(declaration.value).trim_space()
	original := declaration.original_full_text or { '${declaration.name}: ${value_text}' }
	property := PropertyNameAndID.from_name(declaration.name) or {
		return BooleanExpression.create_supports_declaration(original, false)
	}
	if property.is_custom_property() {
		return BooleanExpression.create_supports_declaration(original, true)
	}
	property_id := property.id() or {
		return BooleanExpression.create_supports_declaration(original, false)
	}
	mut value_tokens := ComponentValueStream.new(declaration.value)
	is_match := parser.parse_css_value_tokens(property_id, mut value_tokens) != none
	return BooleanExpression.create_supports_declaration(original, is_match)
}

fn parse_supports_declaration_from_parser_tokens(mut tokens ParserTokenStream) ?&BooleanExpression {
	mut parser := Parser{}
	return parser.parse_supports_declaration(mut tokens)
}

fn component_values_contain_only_any_value(values []ComponentValue) bool {
	for value in values {
		if value.is_function() {
			if !component_values_contain_only_any_value(value.function().value) {
				return false
			}
			continue
		}
		if value.is_block() {
			if !component_values_contain_only_any_value(value.block().value) {
				return false
			}
			continue
		}
		if !value.is_token() {
			continue
		}
		if value.token().type_ in [.invalid, .end_of_file, .bad_string, .bad_url, .function,
			.open_curly, .open_paren, .open_square, .close_curly, .close_paren, .close_square] {
			return false
		}
	}
	return true
}

// https://drafts.csswg.org/mediaqueries-5/#typedef-general-enclosed
fn (mut parser Parser) parse_general_enclosed(mut tokens SupportsTokenStream, result MatchResult) ?&BooleanExpression {
	_ = parser
	mut transaction := tokens.fork()
	transaction.discard_whitespace()
	first_token := transaction.consume_a_token() or { return none }
	if first_token.is_function() {
		if !component_values_contain_only_any_value(first_token.function().value) {
			return none
		}
		tokens = transaction
		return BooleanExpression.create_general_enclosed(first_token.to_string(), result)
	}
	if first_token.is_block() && first_token.block().is_paren() {
		if !component_values_contain_only_any_value(first_token.block().value) {
			return none
		}
		tokens = transaction
		return BooleanExpression.create_general_enclosed(first_token.to_string(), result)
	}
	return none
}

fn supports_component_values_to_string(values []ComponentValue) string {
	mut builder := strings.new_builder(32)
	for value in values {
		builder.write_string(value.to_string())
	}
	return builder.str()
}

fn supports_selector_contains_unknown_webkit_pseudo_element(selector string) bool {
	selector_list := parse_selector_with_parser(selector, map[string]bool{}) or { return false }
	for item in selector_list.selectors {
		if item.contains_unknown_webkit_pseudo_element() {
			return true
		}
	}
	return false
}

pub enum MediaQueryKnownMediaType {
	all
	print
	screen
}

pub fn media_type_from_string(name string) ?MediaQueryKnownMediaType {
	return match name.to_lower() {
		'all' { MediaQueryKnownMediaType.all }
		'print' { MediaQueryKnownMediaType.print }
		'screen' { MediaQueryKnownMediaType.screen }
		else { none }
	}
}

pub fn media_query_known_media_type_to_string(media_type MediaQueryKnownMediaType) string {
	return match media_type {
		.all { 'all' }
		.print { 'print' }
		.screen { 'screen' }
	}
}

@[heap]
pub struct MediaQuery {
pub mut:
	text            string = 'all'
	matches         bool = true
	negated         bool
	media_type      MediaQueryType = MediaQueryType.all()
	media_condition ?&BooleanExpression
}

pub struct MediaQueryType {
pub mut:
	name       string
	known_type ?MediaQueryKnownMediaType
}

pub fn MediaQueryType.all() MediaQueryType {
	return MediaQueryType{
		name: 'all'
		known_type: MediaQueryKnownMediaType.all
	}
}

pub fn MediaQuery.create_not_all() &MediaQuery {
	return &MediaQuery{
		text: 'not all'
		matches: false
		negated: true
		media_type: MediaQueryType.all()
	}
}

pub fn MediaQuery.create() &MediaQuery {
	return &MediaQuery{
		text: 'all'
		matches: true
		media_type: MediaQueryType.all()
	}
}

pub fn parse_media_query(context ParsingParams, text string) ?&MediaQuery {
	mut parser := Parser.with_context(context, text)
	return parser.parse_as_media_query()
}

pub fn (media_query &MediaQuery) evaluate(doc ?&dom.Document) bool {
	mut result := media_query_matches_media_type(media_query.media_type)
	if result != .false_ {
		if condition := media_query.media_condition {
			result = match_result_and(result, condition.evaluate(BooleanExpressionEvaluationContext{
				document: doc
			}))
		}
	}
	if media_query.negated {
		result = negate_match_result(result)
	}
	return result == .true_
}

pub fn (media_query &MediaQuery) to_string() string {
	mut builder := strings.new_builder(64)

	if media_query.negated {
		builder.write_string('not ')
	}

	known_type_is_all := if known_type := media_query.media_type.known_type {
		known_type == .all
	} else {
		false
	}
	if media_query.negated || !known_type_is_all || media_query.media_condition == none {
		if known_type := media_query.media_type.known_type {
			builder.write_string(media_query_known_media_type_to_string(known_type))
		} else {
			builder.write_string(serialize_an_identifier(media_query.media_type.name.to_lower()))
		}
		if media_query.media_condition != none {
			builder.write_string(' and ')
		}
	}

	if condition := media_query.media_condition {
		builder.write_string(condition.to_string())
	}

	serialized := builder.str()
	if serialized.len == 0 {
		return media_query.text
	}
	return serialized
}

pub fn (media_query &MediaQuery) matches() bool {
	return media_query.matches
}

pub fn (media_query &MediaQuery) dump(indent_levels int) string {
	mut builder := strings.new_builder(96)
	builder.write_string('${cssom_indent(indent_levels)}Media condition: (matches = ${media_query.matches})\n')
	builder.write_string('${cssom_indent(indent_levels + 1)}Negated: ${media_query.negated}\n')
	builder.write_string('${cssom_indent(indent_levels + 1)}Type: ${media_query.media_type.name}\n')
	if condition := media_query.media_condition {
		builder.write_string('${cssom_indent(indent_levels + 1)}Condition:\n')
		builder.write_string(condition.dump(indent_levels + 2))
	}
	return builder.str()
}

// 4.2. The MediaQueryList Interface, https://drafts.csswg.org/cssom-view/#the-mediaquerylist-interface
@[heap]
pub struct MediaQueryList {
	dom.EventTarget
pub mut:
	document_          &dom.Document = unsafe { nil }
	media_queries      []&MediaQuery
	has_changed_state_ ?bool = false
	dom_registration_  &dom.MediaQueryList = unsafe { nil }
	registered_        bool
}

pub fn MediaQueryList.create(document &dom.Document, media []&MediaQuery) &MediaQueryList {
	return MediaQueryList.new(document, media)
}

pub fn MediaQueryList.new(document &dom.Document, media []&MediaQuery) &MediaQueryList {
	mut media_query_list := &MediaQueryList{
		document_: document
		media_queries: media.clone()
	}
	media_query_list.dom_registration_ = &dom.MediaQueryList{
		target: voidptr(media_query_list)
		matches_callback: media_query_list_registration_matches
		evaluate_callback: media_query_list_registration_evaluate
		has_changed_state_callback: media_query_list_registration_has_changed_state
		set_has_changed_state_callback: media_query_list_registration_set_has_changed_state
		dispatch_change_event_callback: media_query_list_registration_dispatch_change_event
	}
	media_query_list.has_changed_state_ = false
	media_query_list.evaluate()
	return media_query_list
}

pub fn (mut media_query_list MediaQueryList) initialize() {
	// WEB_SET_PROTOTYPE_FOR_INTERFACE(MediaQueryList);
	media_query_list.EventTarget.initialize()
}

pub fn (mut media_query_list MediaQueryList) visit_edges(mut visitor dom.CellVisitor) {
	media_query_list.EventTarget.visit_edges(mut visitor)
	visitor.visit(media_query_list.document_)
}

fn (media_query_list &MediaQueryList) event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(media_query_list) }
}

// https://drafts.csswg.org/cssom-view/#dom-mediaquerylist-media
pub fn (media_query_list &MediaQueryList) media() string {
	return serialize_a_media_query_list(media_query_list.media_queries)
}

// https://drafts.csswg.org/cssom-view/#dom-mediaquerylist-matches
pub fn (media_query_list &MediaQueryList) matches() bool {
	if media_query_list.media_queries.len == 0 {
		return true
	}

	mut did_match := false
	for media in media_query_list.media_queries {
		if media.matches() {
			did_match = true
			break
		}
	}

	// NOTE: If our document is inside a frame, we need to update layout
	//       since that may cause our frame (and thus viewport) to resize.
	if container_document := media_query_list.document_.container_document() {
		mut mutable_container_document := unsafe { &dom.Document(container_document) }
		mutable_container_document.update_layout(.media_query_list_matches)
		mut mutable_media_query_list := unsafe { &MediaQueryList(media_query_list) }
		mutable_media_query_list.evaluate()
	}

	mut now_matches := false
	for media in media_query_list.media_queries {
		if media.matches() {
			now_matches = true
			break
		}
	}

	if did_match != now_matches {
		mut mutable_media_query_list := unsafe { &MediaQueryList(media_query_list) }
		mutable_media_query_list.has_changed_state_ = true
	}

	return now_matches
}

pub fn (media_query_list &MediaQueryList) evaluate() bool {
	if media_query_list.media_queries.len == 0 {
		return true
	}

	mut now_matches := false
	mut mutable_media_query_list := unsafe { &MediaQueryList(media_query_list) }
	for i in 0 .. mutable_media_query_list.media_queries.len {
		mut media_query := unsafe { &MediaQuery(mutable_media_query_list.media_queries[i]) }
		is_match := media_query.evaluate(media_query_list.document_)
		media_query.matches = is_match
		now_matches = now_matches || is_match
	}

	return now_matches
}

// https://www.w3.org/TR/cssom-view/#dom-mediaquerylist-addlistener
pub fn (media_query_list &MediaQueryList) add_listener(listener ?&dom.IDLEventListener) {
	// 1. If listener is null, terminate these steps.
	callback := listener or { return }

	// 2. Append an event listener to the associated list of event listeners with type set to change,
	//    callback set to listener, and capture set to false, unless there already is an event listener
	//    in that list with the same type, callback, and capture.
	//    (NOTE: capture is set to false by default)
	media_query_list.event_target().add_event_listener_without_options('change', callback)
}

// https://www.w3.org/TR/cssom-view/#dom-mediaquerylist-removelistener
pub fn (media_query_list &MediaQueryList) remove_listener(listener ?&dom.IDLEventListener) {
	// 1. Remove an event listener from the associated list of event listeners, whose type is change, callback is listener, and capture is false.
	// NOTE: While the spec doesn't technically use remove_event_listener and instead manipulates the list directly, every major engine uses remove_event_listener.
	//       This means if an event listener removes another event listener that comes after it, the removed event listener will not be invoked.
	if callback := listener {
		media_query_list.event_target().remove_event_listener_without_options('change', callback)
	}
}

pub fn (media_query_list &MediaQueryList) set_onchange(event_handler ?&dom.CallbackType) {
	media_query_list.event_target().set_event_handler_attribute('change', event_handler)
}

pub fn (media_query_list &MediaQueryList) onchange() ?&dom.CallbackType {
	return media_query_list.event_target().event_handler_attribute('change')
}

pub fn (media_query_list &MediaQueryList) has_changed_state() ?bool {
	return media_query_list.has_changed_state_
}

pub fn (mut media_query_list MediaQueryList) set_has_changed_state(has_changed_state bool) {
	media_query_list.has_changed_state_ = has_changed_state
}

pub fn (media_query_list &MediaQueryList) dispatch_change_event(matches bool) {
	mut event_init := MediaQueryListEventInit{
		media: media_query_list.media()
		matches: matches
	}
	event_init.EventInit = dom.EventInit{}
	event := MediaQueryListEvent.create('change', event_init)
	dom.event_target_dispatch_event(media_query_list.event_target(), event.base_event())
}

fn media_query_list_registration_matches(target voidptr) bool {
	media_query_list := unsafe { &MediaQueryList(target) }
	return media_query_list.matches()
}

fn media_query_list_registration_evaluate(target voidptr) bool {
	media_query_list := unsafe { &MediaQueryList(target) }
	return media_query_list.evaluate()
}

fn media_query_list_registration_has_changed_state(target voidptr) bool {
	media_query_list := unsafe { &MediaQueryList(target) }
	return media_query_list.has_changed_state() or { false }
}

fn media_query_list_registration_set_has_changed_state(target voidptr, has_changed_state bool) {
	mut media_query_list := unsafe { &MediaQueryList(target) }
	media_query_list.set_has_changed_state(has_changed_state)
}

fn media_query_list_registration_dispatch_change_event(target voidptr, matches bool) {
	media_query_list := unsafe { &MediaQueryList(target) }
	media_query_list.dispatch_change_event(matches)
}

pub fn (mut media_query_list MediaQueryList) register_with_document() {
	// Window::match_media() registers the C++ CSS::MediaQueryList with DOM::Document.
	if media_query_list.registered_ {
		return
	}
	mut document := unsafe { &dom.Document(media_query_list.document_) }
	document.add_media_query_list(media_query_list.dom_registration_)
	media_query_list.registered_ = true
}

pub struct MediaQueryListEntry {
pub mut:
	text    string
	matches bool
mut:
	parsed_query_ ?&MediaQuery
	parsed_text_ string
	has_parsed_query_ bool
}

@[heap]
pub struct MediaList {
pub mut:
	media                  []MediaQueryListEntry
	associated_style_sheet ?&CSSStyleSheet
	associated_rule        ?&CSSRule
}

pub fn MediaList.create(media []MediaQueryListEntry) &MediaList {
	return &MediaList{
		media: media
	}
}

pub fn MediaList.create_empty() &MediaList {
	return MediaList.create([]MediaQueryListEntry{})
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-mediatext
pub fn (media_list &MediaList) media_text() string {
	return serialize_a_media_query_list_entries(media_list.media)
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-mediatext
pub fn (mut media_list MediaList) set_media_text(text string) {
	previous_sheet_effects := media_list.associated_style_sheet_effects()
	media_list.media.clear()
	if text.trim_space().len != 0 {
		media_list.media =
			media_query_entries_from_queries(parse_css_media_query_list_value_logic(text))
	}
	media_list.invalidate_associated_style_sheet(.media_list_set_media_text, previous_sheet_effects)
}

pub fn (media_list &MediaList) length() int {
	return media_list.media.len
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-item
pub fn (media_list &MediaList) item(index u32) ?string {
	if int(index) >= media_list.media.len {
		return none
	}
	return media_list.media[index].text
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-appendmedium
pub fn (mut media_list MediaList) append_medium(medium string) {
	// 1. Let m be the result of parsing the given value.
	parsed := parse_media_query_entry(medium) or { return }

	// 2. If m is null, then return.
	serialized := parsed.text

	// 3. If comparing m with any of the media queries in the collection of media queries returns true, then return.
	for existing_medium in media_list.media {
		if existing_medium.text == serialized {
			return
		}
	}

	previous_sheet_effects := media_list.associated_style_sheet_effects()

	// 4. Append m to the collection of media queries.
	media_list.media << parsed
	media_list.invalidate_associated_style_sheet(.media_list_append_medium, previous_sheet_effects)
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-deletemedium
pub fn (mut media_list MediaList) delete_medium(medium string) ! {
	// 1. Let m be the result of parsing the given value.
	parsed := parse_media_query_entry(medium) or { return }

	// 2. If m is null, then return.
	serialized := parsed.text
	previous_sheet_effects := media_list.associated_style_sheet_effects()

	// 3. Remove any media query from the collection of media queries for which comparing the media query with m
	//    returns true. If nothing was removed, then throw a NotFoundError exception.
	mut was_removed := false
	mut kept := []MediaQueryListEntry{}
	for existing in media_list.media {
		if existing.text == serialized {
			was_removed = true
			continue
		}
		kept << existing
	}
	if !was_removed {
		return error('NotFoundError: Media query not found in list')
	}

	media_list.media = kept
	media_list.invalidate_associated_style_sheet(.media_list_delete_medium, previous_sheet_effects)
}

pub fn (mut media_list MediaList) evaluate(document &dom.Document) bool {
	for i in 0 .. media_list.media.len {
		media_list.media[i].matches = evaluate_media_query_entry(mut media_list.media[i], document)
	}
	return media_list.matches()
}

pub fn (media_list &MediaList) matches() bool {
	if media_list.media.len == 0 {
		return true
	}

	for media in media_list.media {
		if media.matches {
			return true
		}
	}
	return false
}

pub fn (mut media_list MediaList) set_associated_style_sheet(style_sheet &CSSStyleSheet) {
	unsafe {
		media_list.associated_style_sheet = style_sheet
	}
}

pub fn (mut media_list MediaList) set_associated_rule(rule &CSSRule) {
	media_list.associated_rule = rule
}

fn (media_list &MediaList) owning_style_sheet() ?&CSSStyleSheet {
	if sheet := media_list.associated_style_sheet {
		return sheet
	}
	if rule := media_list.associated_rule {
		return rule.parent_style_sheet
	}
	return none
}

fn (media_list &MediaList) associated_style_sheet_effects() ?ShadowRootStylesheetEffects {
	if sheet := media_list.owning_style_sheet() {
		return determine_shadow_root_style_sheet_effects_for_style_sheet(sheet)
	}
	return none
}

fn (media_list &MediaList) invalidate_associated_style_sheet(reason dom.StyleInvalidationReason,
	previous_sheet_effects ?ShadowRootStylesheetEffects) {
	if sheet := media_list.owning_style_sheet() {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		mutable_sheet.invalidate_owners_with_previous_effects(reason, previous_sheet_effects)
		mutable_sheet.synchronize_fonts_after_rule_change()
	}
}

pub fn (media_list &MediaList) dump(indent_levels int) string {
	mut builder := strings.new_builder(64)
	builder.write_string('${cssom_indent(indent_levels)}Media list (${media_list.media.len}):\n')
	for media in media_list.media {
		builder.write_string('${cssom_indent(indent_levels + 1)}${media.text} (matches = ${media.matches})\n')
	}
	return builder.str()
}

pub fn serialize_a_media_query_list(media_queries []&MediaQuery) string {
	// 1. If the media query list is empty, then return the empty string.
	if media_queries.len == 0 {
		return ''
	}

	// 2. Serialize each media query in the list of media queries, in the same order as they
	// appear in the media query list, and then serialize the list.
	mut serialized := []string{}
	for media_query in media_queries {
		serialized << media_query.to_string()
	}
	return serialized.join(', ')
}

pub fn serialize_a_media_query_list_entries(media_queries []MediaQueryListEntry) string {
	if media_queries.len == 0 {
		return ''
	}
	mut serialized := []string{}
	for media_query in media_queries {
		serialized << media_query.text
	}
	return serialized.join(', ')
}

fn parse_media_query_entry(medium string) ?MediaQueryListEntry {
	query := parse_media_query_from_text(medium) or { return none }
	return MediaQueryListEntry{
		text: query.to_string()
		matches: query.matches()
		parsed_query_: query
		parsed_text_: query.to_string()
		has_parsed_query_: true
	}
}

fn evaluate_media_query_entry(mut entry MediaQueryListEntry, document &dom.Document) bool {
	// CSSOM changes replace the text; viewport and preference changes only
	// reevaluate the retained syntax tree. Direct V entry edits use the same key.
	if !entry.has_parsed_query_ || entry.parsed_text_ != entry.text {
		entry.parsed_query_ = parse_media_query_from_text(entry.text)
		entry.parsed_text_ = entry.text
		entry.has_parsed_query_ = true
	}
	query := entry.parsed_query_ or { return false }
	return query.evaluate(document)
}

fn media_query_entries_from_queries(queries []&MediaQuery) []MediaQueryListEntry {
	mut entries := []MediaQueryListEntry{cap: queries.len}
	for query in queries {
		entries << MediaQueryListEntry{
			text: query.to_string()
			matches: query.matches()
			parsed_query_: query
			parsed_text_: query.to_string()
			has_parsed_query_: true
		}
	}
	return entries
}

pub fn parse_media_query_from_text(text string) ?&MediaQuery {
	mut parser := Parser.from_css_text(text)
	return parser.parse_as_media_query()
}

fn media_query_matches_media_type(media_type MediaQueryType) MatchResult {
	known_type := media_type.known_type or { return .false_ }
	return match known_type {
		.all {
			.true_
		}
		.print {
			// FIXME: Enable for printing, when we have printing!
			.false_
		}
		.screen {
			// FIXME: Disable for printing, when we have printing!
			.true_
		}
	}
}

// `<media-condition>`, https://www.w3.org/TR/mediaqueries-4/#typedef-media-condition
fn parse_media_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut parser := Parser.from_component_values(tokens.values[tokens.index..])
	return parse_media_condition_with_parser(mut parser, mut tokens)
}

fn parse_media_condition_with_parser(mut parser Parser, mut tokens SupportsTokenStream) ?&BooleanExpression {
	return parser.parse_boolean_expression(mut tokens, .unknown, .media_in_parens)
}

// The `<media-in-parens>` test callback parses the parenthesized `<media-feature>` branch.
fn (mut parser Parser) parse_media_in_parens(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	first_token := transaction.next_token() or { return none }
	if !(first_token.is_block() && first_token.block().is_paren()) {
		return none
	}
	transaction.discard_a_token()

	mut inner_tokens := SupportsTokenStream.from_values(first_token.block().value)
	feature := parser.parse_media_feature(mut inner_tokens) or { return none }
	inner_tokens.discard_whitespace()
	if inner_tokens.has_next_token() {
		return none
	}

	tokens = transaction
	return feature
}

enum MediaFeatureNamePrefix {
	normal
	min
	max
}

struct MediaFeatureName {
	name   string
	prefix MediaFeatureNamePrefix
}

enum MediaFeatureValueTypeLocal {
	boolean
	integer
	length
	ratio
	resolution
}

enum MediaFeatureValueKindLocal {
	ident
	integer
	length
	ratio
	resolution
	unknown
}

struct MediaFeatureValueLocal {
	kind        MediaFeatureValueKindLocal
	text        string
	name        string
	value       f64
	typed_value ?StyleValue
}

enum MediaFeatureComparison {
	equal
	less_than
	less_than_or_equal
	greater_than
	greater_than_or_equal
}

fn parse_media_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut parser := Parser.from_component_values(tokens.values[tokens.index..])
	return parser.parse_media_feature(mut tokens)
}

fn (mut parser Parser) parse_media_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	if feature := parse_media_feature_boolean(mut parser, mut tokens) {
		return feature
	}
	if feature := parse_media_feature_plain(mut parser, mut tokens) {
		return feature
	}
	if feature := parse_media_feature_range(mut parser, mut tokens) {
		return feature
	}
	return none
}

fn parse_media_feature_boolean(mut parser Parser, mut tokens SupportsTokenStream) ?&BooleanExpression {
	_ = parser
	mut transaction := tokens
	transaction.discard_whitespace()
	name := parse_media_feature_name(mut transaction, false) or { return none }
	transaction.discard_whitespace()
	if transaction.has_next_token() {
		return none
	}
	tokens = transaction
	text := '(${name.name})'
	return BooleanExpression.create_media_feature(text, name.name, .is_true, none, none, none, none)
}

fn parse_media_feature_plain(mut parser Parser, mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	name := parse_media_feature_name(mut transaction, true) or { return none }
	transaction.discard_whitespace()
	if !(transaction.consume_a_token() or { return none }).is(.colon) {
		return none
	}
	transaction.discard_whitespace()
	value := parse_media_feature_value_with_parser(mut parser, name.name, mut transaction) or {
		return none
	}
	transaction.discard_whitespace()
	if transaction.has_next_token() {
		return none
	}
	tokens = transaction
	match name.prefix {
		.normal {
			text := '(${name.name}: ${value.text})'
			return BooleanExpression.create_media_feature(text, name.name, .exact_value, value, none, none, none)
		}
		.min {
			text := '(min-${name.name}: ${value.text})'
			return BooleanExpression.create_media_feature(text, name.name, .min_value, value, none, none, none)
		}
		.max {
			text := '(max-${name.name}: ${value.text})'
			return BooleanExpression.create_media_feature(text, name.name, .max_value, value, none, none, none)
		}
	}
}

fn parse_media_feature_range(mut parser Parser, mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	if name := parse_media_feature_name(mut transaction, false) {
		transaction.discard_whitespace()
		if comparison := parse_media_feature_comparison(mut transaction) {
			transaction.discard_whitespace()
			if value := parse_media_feature_value_with_parser(mut parser, name.name, mut transaction) {
				transaction.discard_whitespace()
				if !transaction.has_next_token() && value.kind != .ident {
					tokens = transaction
					text := '(${name.name} ${media_feature_comparison_to_string(comparison)} ${value.text})'
					return BooleanExpression.create_media_feature(text, name.name, .half_range_query_left, value, comparison, none, none)
				}
			}
		}
	}

	transaction = SupportsTokenStream{
		values: tokens.values.clone()
		index: tokens.index
	}
	transaction.discard_whitespace()
	maybe_name := find_media_feature_name_after_comparison(transaction) or { return none }
	left_value := parse_media_feature_value_with_parser(mut parser, maybe_name.name, mut transaction) or {
		return none
	}
	transaction.discard_whitespace()
	left_comparison := parse_media_feature_comparison(mut transaction) or { return none }
	transaction.discard_whitespace()
	name_token := transaction.consume_a_token() or { return none }
	if !name_token.is(.ident)
		|| !equals_ignoring_ascii_case(name_token.token().ident(), maybe_name.name) {
		return none
	}
	transaction.discard_whitespace()

	if !transaction.has_next_token() {
		tokens = transaction
		text := '(${left_value.text} ${media_feature_comparison_to_string(left_comparison)} ${maybe_name.name})'
		return BooleanExpression.create_media_feature(text, maybe_name.name, .half_range_query_right, left_value, left_comparison, none, none)
	}

	right_comparison := parse_media_feature_comparison(mut transaction) or { return none }
	transaction.discard_whitespace()
	right_value := parse_media_feature_value_with_parser(mut parser, maybe_name.name, mut transaction) or {
		return none
	}
	transaction.discard_whitespace()
	if transaction.has_next_token()
		|| !media_feature_comparisons_match(left_comparison, right_comparison)
		|| left_comparison == .equal || left_value.kind == .ident || right_value.kind == .ident {
		return none
	}

	tokens = transaction
	text := '(${left_value.text} ${media_feature_comparison_to_string(left_comparison)} ${maybe_name.name} ${media_feature_comparison_to_string(right_comparison)} ${right_value.text})'
	return BooleanExpression.create_media_feature(text, maybe_name.name, .range, left_value, left_comparison, right_comparison, right_value)
}

fn find_media_feature_name_after_comparison(tokens SupportsTokenStream) ?MediaFeatureName {
	mut temp := tokens
	for temp.has_next_token() {
		if _ := parse_media_feature_comparison(mut temp) {
			temp.discard_whitespace()
			return parse_media_feature_name(mut temp, false)
		}
		temp.discard_a_token()
		temp.discard_whitespace()
	}
	return none
}

fn parse_media_feature_name(mut tokens SupportsTokenStream, allow_min_max_prefix bool) ?MediaFeatureName {
	mut transaction := tokens
	token := transaction.consume_a_token() or { return none }
	if !token.is(.ident) {
		return none
	}

	name := token.token().ident()
	if media_feature_is_known(name) {
		tokens = transaction
		return MediaFeatureName{
			name: name.to_lower()
			prefix: .normal
		}
	}

	if allow_min_max_prefix {
		lower := name.to_lower()
		if lower.starts_with('min-') || lower.starts_with('max-') {
			adjusted_name := lower[4..]
			if media_feature_is_known(adjusted_name)
				&& media_feature_type_is_range_name(adjusted_name) {
				tokens = transaction
				return MediaFeatureName{
					name: adjusted_name
					prefix: if lower.starts_with('min-') {
						MediaFeatureNamePrefix.min
					} else {
						MediaFeatureNamePrefix.max
					}
				}
			}
		}
	}

	return none
}

fn parse_media_feature_comparison(mut tokens SupportsTokenStream) ?MediaFeatureComparison {
	mut transaction := tokens
	transaction.discard_whitespace()
	first := transaction.consume_a_token() or { return none }
	if !first.is(.delim) {
		return none
	}
	first_delim := first.token().delim()
	if first_delim == `=` {
		tokens = transaction
		return .equal
	}
	if first_delim == `<` {
		if second := transaction.next_token() {
			if second.is_delim(u32(`=`)) {
				transaction.discard_a_token()
				tokens = transaction
				return .less_than_or_equal
			}
		}
		tokens = transaction
		return .less_than
	}
	if first_delim == `>` {
		if second := transaction.next_token() {
			if second.is_delim(u32(`=`)) {
				transaction.discard_a_token()
				tokens = transaction
				return .greater_than_or_equal
			}
		}
		tokens = transaction
		return .greater_than
	}
	return none
}

fn parse_media_feature_value_with_parser(mut parser Parser, feature_name string, mut tokens SupportsTokenStream) ?MediaFeatureValueLocal {
	mut transaction := tokens.fork()
	transaction.discard_whitespace()
	mut values := []ComponentValue{}
	for transaction.has_next_token() {
		next := transaction.next_token() or { break }
		if !is_media_feature_value_token(next) {
			break
		}
		values << transaction.consume_a_token() or { break }
	}
	if values.len == 0 {
		return none
	}

	// Parse through Parser::parse_media_feature_value(), just like the upstream
	// media parser. Keeping a second value parser here used to discard units.
	mut value_tokens := ComponentValueStream.new(values)
	if style_value := parser.parse_media_feature_value(feature_name, mut value_tokens) {
		value_tokens.consume_whitespace()
		if !value_tokens.has_more_tokens() {
			tokens = transaction
			return media_feature_value_from_style_value(feature_name, style_value)
		}
	}

	// Match the C++ fallback by preserving unrecognized, syntactically
	// value-like component values.
	tokens = transaction
	return MediaFeatureValueLocal{
		kind: .unknown
		text: supports_component_values_to_string(values).trim_space()
	}
}

fn media_feature_value_from_style_value(feature_name string, style_value StyleValue) MediaFeatureValueLocal {
	text := style_value.serialize(.normal)
	return match style_value {
		KeywordStyleValue {
			MediaFeatureValueLocal{
				kind: .ident
				text: text
				name: string_from_keyword(style_value.keyword())
				typed_value: style_value
			}
		}
		IntegerStyleValue {
			MediaFeatureValueLocal{
				kind: .integer
				text: text
				value: f64(style_value.integer())
				typed_value: style_value
			}
		}
		LengthStyleValue {
			MediaFeatureValueLocal{
				kind: .length
				text: text
				typed_value: style_value
			}
		}
		RatioStyleValue {
			MediaFeatureValueLocal{
				kind: .ratio
				text: text
				typed_value: style_value
			}
		}
		ResolutionStyleValue {
			MediaFeatureValueLocal{
				kind: .resolution
				text: text
				typed_value: style_value
			}
		}
		CalculatedStyleValue {
			MediaFeatureValueLocal{
				kind: media_feature_calculated_value_kind(feature_name)
				text: text
				typed_value: style_value
			}
		}
		else {
			MediaFeatureValueLocal{
				kind: .unknown
				text: text
				typed_value: style_value
			}
		}
	}
}

fn media_feature_calculated_value_kind(feature_name string) MediaFeatureValueKindLocal {
	if media_feature_accepts_type_name(feature_name, .boolean)
		|| media_feature_accepts_type_name(feature_name, .integer) {
		return .integer
	}
	if media_feature_accepts_type_name(feature_name, .length) {
		return .length
	}
	if media_feature_accepts_type_name(feature_name, .ratio) {
		return .ratio
	}
	if media_feature_accepts_type_name(feature_name, .resolution) {
		return .resolution
	}
	return .unknown
}

fn is_media_feature_value_token(component_value ComponentValue) bool {
	if !component_value.is_token() {
		return true
	}
	if component_value.is(.ident) || component_value.is(.function)
		|| component_value.is(.at_keyword) || component_value.is(.hash)
		|| component_value.is(.string) || component_value.is(.bad_string)
		|| component_value.is(.url) || component_value.is(.bad_url) || component_value.is(.number)
		|| component_value.is(.percentage) || component_value.is(.dimension)
		|| component_value.is(.whitespace) || component_value.is(.comma) {
		return true
	}
	if component_value.is(.delim) {
		delim := component_value.token().delim()
		return delim != `<` && delim != `>` && delim != `=`
	}
	return false
}

enum MediaFeatureEvalKind {
	is_true
	exact_value
	min_value
	max_value
	half_range_query_left
	half_range_query_right
	range
}

fn evaluate_media_feature(feature_name string, kind MediaFeatureEvalKind, value ?MediaFeatureValueLocal, comparison ?MediaFeatureComparison, right_comparison ?MediaFeatureComparison, right_value ?MediaFeatureValueLocal, document ?&dom.Document) MatchResult {
	queried_value := query_media_feature(feature_name, document) or { return .unknown }
	match kind {
		.is_true {
			return evaluate_media_feature_value_as_boolean(feature_name, queried_value, document)
		}
		.exact_value {
			expected := value or { return .unknown }
			return compare_media_feature_values(queried_value, .equal, expected, document)
		}
		.min_value {
			expected := value or { return .unknown }
			return compare_media_feature_values(queried_value, .greater_than_or_equal, expected, document)
		}
		.max_value {
			expected := value or { return .unknown }
			return compare_media_feature_values(queried_value, .less_than_or_equal, expected, document)
		}
		.half_range_query_left {
			expected := value or { return .unknown }
			expected_comparison := comparison or { return .unknown }
			return compare_media_feature_values(queried_value, expected_comparison, expected, document)
		}
		.half_range_query_right {
			expected := value or { return .unknown }
			expected_comparison := comparison or { return .unknown }
			return compare_media_feature_values(expected, expected_comparison, queried_value, document)
		}
		.range {
			left := value or { return .unknown }
			left_comparison := comparison or { return .unknown }
			right := right_value or { return .unknown }
			comparison_to_right := right_comparison or { return .unknown }
			left_result := compare_media_feature_values(left, left_comparison, queried_value, document)
			if left_result != .true_ {
				return left_result
			}
			return compare_media_feature_values(queried_value, comparison_to_right, right, document)
		}
	}
}

fn query_media_feature(feature_name string, document ?&dom.Document) ?MediaFeatureValueLocal {
	viewport_width := if doc := document { doc.viewport_rect().width } else { 800.0 }
	viewport_height := if doc := document { doc.viewport_rect().height } else { 600.0 }
	return match feature_name {
		'any-hover', 'hover' {
			media_feature_ident_value('hover')
		}
		'any-pointer', 'pointer' {
			media_feature_ident_value('fine')
		}
		'color' {
			media_feature_integer_value(8)
		}
		'color-gamut', 'video-color-gamut' {
			media_feature_ident_value('srgb')
		}
		'color-index', 'grid', 'monochrome' {
			media_feature_integer_value(0)
		}
		'display-mode' {
			media_feature_ident_value('browser')
		}
		'dynamic-range', 'video-dynamic-range' {
			media_feature_ident_value('standard')
		}
		'environment-blending' {
			media_feature_ident_value('opaque')
		}
		'forced-colors', 'inverted-colors', 'scan' {
			media_feature_ident_value('none')
		}
		'height', 'device-height' {
			media_feature_length_value(viewport_height)
		}
		'horizontal-viewport-segments', 'vertical-viewport-segments' {
			media_feature_integer_value(1)
		}
		'nav-controls' {
			media_feature_ident_value('back')
		}
		'orientation' {
			media_feature_ident_value(if viewport_width >= viewport_height {
				'landscape'
			} else {
				'portrait'
			})
		}
		'overflow-block', 'overflow-inline' {
			media_feature_ident_value('scroll')
		}
		'prefers-color-scheme' {
			preferred := if doc := document {
				doc.preferred_color_scheme().to_lower()
			} else {
				'auto'
			}
			media_feature_ident_value(if preferred == 'dark' { 'dark' } else { 'light' })
		}
		'prefers-reduced-transparency' {
			reduce := if doc := document { doc.prefers_reduced_transparency() } else { false }
			media_feature_ident_value(if reduce { 'reduce' } else { 'no-preference' })
		}
		'prefers-contrast', 'prefers-reduced-data', 'prefers-reduced-motion' {
			media_feature_ident_value('no-preference')
		}
		'resolution' {
			media_feature_resolution_value(if doc := document { doc.display_device_pixel_ratio() } else { 1.0 })
		}
		'scripting' {
			media_feature_ident_value('enabled')
		}
		'update' {
			media_feature_ident_value('fast')
		}
		'width', 'device-width' {
			media_feature_length_value(viewport_width)
		}
		'aspect-ratio', 'device-aspect-ratio' {
			media_feature_ratio_value(if viewport_height != 0 {
				viewport_width / viewport_height
			} else {
				0.0
			})
		}
		else {
			none
		}
	}
}

fn media_feature_ident_value(name string) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind: .ident
		text: name
		name: name
	}
}

fn media_feature_integer_value(value f64) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind: .integer
		value: value
	}
}

fn media_feature_length_value(value f64) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind: .length
		value: value
	}
}

fn media_feature_ratio_value(value f64) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind: .ratio
		value: value
	}
}

fn media_feature_resolution_value(value f64) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind: .resolution
		value: value
	}
}

fn evaluate_media_feature_value_as_boolean(feature_name string, value MediaFeatureValueLocal, document ?&dom.Document) MatchResult {
	match value.kind {
		.ident {
			if media_feature_keyword_is_falsey_name(feature_name, value.name) {
				return .false_
			}
			return .true_
		}
		.integer, .length, .ratio, .resolution {
			resolved := media_feature_numeric_value(value, document) or { return .false_ }
			return as_match_result(resolved != 0)
		}
		.unknown {
			return .false_
		}
	}
}

fn compare_media_feature_values(left MediaFeatureValueLocal, comparison MediaFeatureComparison, right MediaFeatureValueLocal, document ?&dom.Document) MatchResult {
	if left.kind == .unknown || right.kind == .unknown {
		return .unknown
	}
	if left.kind != right.kind {
		return .false_
	}
	if left.kind == .ident {
		if comparison == .equal {
			return as_match_result(left.name == right.name)
		}
		return .false_
	}
	left_value := media_feature_numeric_value(left, document) or { return .false_ }
	right_value := media_feature_numeric_value(right, document) or { return .false_ }
	return match comparison {
		.equal { as_match_result(left_value == right_value) }
		.less_than { as_match_result(left_value < right_value) }
		.less_than_or_equal { as_match_result(left_value <= right_value) }
		.greater_than { as_match_result(left_value > right_value) }
		.greater_than_or_equal { as_match_result(left_value >= right_value) }
	}
}

fn media_feature_numeric_value(value MediaFeatureValueLocal, document ?&dom.Document) ?f64 {
	// Queried environment/container values already use canonical units. Their
	// text is never serialized; avoid formatting and constructing a resolution
	// context just to return the number we already have.
	if value.typed_value == none {
		return value.value
	}
	return query_feature_numeric_value(value, media_feature_length_resolution_context(document))
}

fn query_feature_numeric_value(value MediaFeatureValueLocal, length_context LengthResolutionContext) ?f64 {
	if typed_value := value.typed_value {
		calculation_context := CalculationResolutionContext{
			length_resolution_context: length_context
		}
		return match typed_value {
			IntegerStyleValue { f64(typed_value.integer()) }
			LengthStyleValue {
				media_feature_length_to_px(typed_value.length(), length_context)
			}
			RatioStyleValue {
				typed_value.resolved_with_context(calculation_context)?.value()
			}
			ResolutionStyleValue { typed_value.resolution().to_dots_per_pixel() }
			CalculatedStyleValue {
				media_feature_calculated_numeric_value(typed_value, value.kind, calculation_context, length_context)
			}
			else { none }
		}
	}
	return value.value
}

fn media_feature_calculated_numeric_value(value CalculatedStyleValue, kind MediaFeatureValueKindLocal, calculation_context CalculationResolutionContext, length_context LengthResolutionContext) ?f64 {
	if kind == .length {
		length := value.resolve_length(calculation_context) or { return none }
		return media_feature_length_to_px(length, length_context)
	}
	if kind == .integer || kind == .resolution {
		resolved := value.resolve_value(calculation_context) or { return none }
		return resolved.value
	}
	return none
}

fn media_feature_length_resolution_context(document ?&dom.Document) LengthResolutionContext {
	if doc := document {
		return LengthResolutionContext.for_document(doc)
	}
	mut context := LengthResolutionContext.default()
	context.viewport_rect = CSSPixelRect.new(0, 0, 800, 600)
	return context
}

fn media_feature_length_to_px(length Length, context LengthResolutionContext) ?f64 {
	if !length.is_absolute() && !length.is_font_relative() && !length.is_container_relative()
		&& !length.is_viewport_relative() {
		return none
	}
	return length.to_px_without_rounding(context)
}

fn media_feature_comparisons_match(a MediaFeatureComparison, b MediaFeatureComparison) bool {
	return match a {
		.equal { b == .equal }
		.less_than, .less_than_or_equal { b in [.less_than, .less_than_or_equal] }
		.greater_than, .greater_than_or_equal { b in [.greater_than, .greater_than_or_equal] }
	}
}

fn media_feature_comparison_to_string(comparison MediaFeatureComparison) string {
	return match comparison {
		.equal { '=' }
		.less_than { '<' }
		.less_than_or_equal { '<=' }
		.greater_than { '>' }
		.greater_than_or_equal { '>=' }
	}
}

fn media_feature_is_known(name string) bool {
	return name.to_lower() in [
		'any-hover',
		'any-pointer',
		'aspect-ratio',
		'color',
		'color-gamut',
		'color-index',
		'device-aspect-ratio',
		'device-height',
		'device-width',
		'display-mode',
		'dynamic-range',
		'environment-blending',
		'forced-colors',
		'grid',
		'height',
		'horizontal-viewport-segments',
		'hover',
		'inverted-colors',
		'monochrome',
		'nav-controls',
		'orientation',
		'overflow-block',
		'overflow-inline',
		'pointer',
		'prefers-color-scheme',
		'prefers-contrast',
		'prefers-reduced-data',
		'prefers-reduced-motion',
		'prefers-reduced-transparency',
		'resolution',
		'scan',
		'scripting',
		'update',
		'vertical-viewport-segments',
		'video-color-gamut',
		'video-dynamic-range',
		'width',
	]
}

fn media_feature_type_is_range_name(name string) bool {
	return name.to_lower() in [
		'aspect-ratio',
		'color',
		'color-index',
		'device-aspect-ratio',
		'device-height',
		'device-width',
		'height',
		'horizontal-viewport-segments',
		'monochrome',
		'resolution',
		'vertical-viewport-segments',
		'width',
	]
}

fn media_feature_accepts_type_name(name string, value_type MediaFeatureValueTypeLocal) bool {
	lower := name.to_lower()
	return match value_type {
		.boolean {
			lower == 'grid'
		}
		.integer {
			lower in [
				'color',
				'color-index',
				'horizontal-viewport-segments',
				'monochrome',
				'vertical-viewport-segments',
			]
		}
		.length {
			lower in ['device-height', 'device-width', 'height', 'width']
		}
		.ratio {
			lower in ['aspect-ratio', 'device-aspect-ratio']
		}
		.resolution {
			lower == 'resolution'
		}
	}
}

fn media_feature_accepts_keyword_name(name string, keyword string) bool {
	lower_name := name.to_lower()
	lower_keyword := keyword.to_lower()
	return match lower_name {
		'any-hover', 'hover' {
			lower_keyword in ['none', 'hover']
		}
		'any-pointer', 'pointer' {
			lower_keyword in ['none', 'coarse', 'fine']
		}
		'color-gamut', 'video-color-gamut' {
			lower_keyword in ['srgb', 'p3', 'rec2020']
		}
		'display-mode' {
			lower_keyword in ['fullscreen', 'standalone', 'minimal-ui', 'browser',
				'picture-in-picture']
		}
		'dynamic-range', 'video-dynamic-range' {
			lower_keyword in ['standard', 'high']
		}
		'environment-blending' {
			lower_keyword in ['opaque', 'additive', 'subtractive']
		}
		'forced-colors' {
			lower_keyword in ['none', 'active']
		}
		'inverted-colors' {
			lower_keyword in ['none', 'inverted']
		}
		'nav-controls' {
			lower_keyword in ['none', 'back']
		}
		'orientation' {
			lower_keyword in ['portrait', 'landscape']
		}
		'overflow-block' {
			lower_keyword in ['none', 'scroll', 'paged']
		}
		'overflow-inline' {
			lower_keyword in ['none', 'scroll']
		}
		'prefers-color-scheme' {
			lower_keyword in ['light', 'dark']
		}
		'prefers-contrast' {
			lower_keyword in ['no-preference', 'less', 'more', 'custom']
		}
		'prefers-reduced-data', 'prefers-reduced-motion', 'prefers-reduced-transparency' {
			lower_keyword in ['no-preference', 'reduce']
		}
		'resolution' {
			lower_keyword == 'infinite'
		}
		'scan' {
			lower_keyword in ['interlace', 'progressive']
		}
		'scripting' {
			lower_keyword in ['none', 'initial-only', 'enabled']
		}
		'update' {
			lower_keyword in ['none', 'slow', 'fast']
		}
		else {
			false
		}
	}
}

fn media_feature_keyword_is_falsey_name(name string, keyword string) bool {
	lower_name := name.to_lower()
	lower_keyword := keyword.to_lower()
	return match lower_name {
		'any-hover', 'any-pointer', 'forced-colors', 'hover', 'inverted-colors', 'nav-controls', 'overflow-block', 'overflow-inline', 'pointer', 'scan', 'scripting', 'update' {
			lower_keyword == 'none'
		}
		'dynamic-range', 'video-dynamic-range' {
			lower_keyword in ['standard', 'high']
		}
		'prefers-contrast', 'prefers-reduced-data', 'prefers-reduced-motion', 'prefers-reduced-transparency' {
			lower_keyword == 'no-preference'
		}
		else {
			false
		}
	}
}
