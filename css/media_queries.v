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
		matches:   condition.evaluate_to_boolean(none)
	}
}

pub fn (supports &Supports) to_string() string {
	return supports.condition.to_string()
}

pub fn (supports &Supports) matches_condition() bool {
	return supports.matches
}

pub fn (supports &Supports) dump(indent_levels int) string {
	return '${cssom_indent(indent_levels)}Supports condition: (matches = ${supports.matches})\n${supports.condition.dump(
		indent_levels + 1)}'
}

pub fn parse_css_supports(context ParsingParams, condition_text string) ?&Supports {
	mut tokens := SupportsTokenStream.from_values_with_namespaces(parse_component_values_for_value_logic(condition_text),
		context.declared_namespaces)
	condition := parse_supports_condition(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return Supports.create(condition)
}

struct SupportsTokenStream {
mut:
	values              []ComponentValue
	index               int
	declared_namespaces map[string]bool
}

fn SupportsTokenStream.from_values(values []ComponentValue) SupportsTokenStream {
	return SupportsTokenStream{
		values:              values.clone()
		declared_namespaces: map[string]bool{}
	}
}

fn SupportsTokenStream.from_values_with_namespaces(values []ComponentValue, declared_namespaces map[string]bool) SupportsTokenStream {
	return SupportsTokenStream{
		values:              values.clone()
		declared_namespaces: declared_namespaces.clone()
	}
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
	// RuleContext::SupportsCondition is represented by calling the declaration
	// parser with supports-condition validation below.
	return parse_supports_boolean_expression(mut tokens, .false_)
}

// https://drafts.csswg.org/css-values-5/#typedef-boolean-expr
fn parse_supports_boolean_expression(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	// `not <boolean-expr-group>`
	if peeked_token := transaction.next_token() {
		if peeked_token.is_ident('not') {
			transaction.discard_a_token()
			transaction.discard_whitespace()
			child := parse_supports_boolean_expression_group(mut transaction,
				result_for_general_enclosed) or { return none }
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
		child := parse_supports_boolean_expression_group(mut transaction,
			result_for_general_enclosed) or { return none }
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

fn parse_supports_boolean_expression_group(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	// <boolean-expr-group> = <test> | ( <boolean-expr[ <test> ]> ) | <general-enclosed>
	if first_token := tokens.next_token() {
		if first_token.is_block() && first_token.block().is_paren() {
			mut transaction := tokens
			transaction.discard_a_token()
			mut child_tokens := SupportsTokenStream.from_values_with_namespaces(first_token.block().value,
				tokens.declared_namespaces)
			if expression := parse_supports_boolean_expression(mut child_tokens,
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

	if test := parse_supports_feature(mut tokens) {
		return test
	}

	if general_enclosed := parse_supports_general_enclosed(mut tokens, result_for_general_enclosed) {
		return general_enclosed
	}

	return none
}

// https://drafts.csswg.org/css-conditional-5/#typedef-supports-feature
fn parse_supports_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first_token := transaction.consume_a_token() or { return none }

	// `<supports-decl> = ( <declaration> )`
	if first_token.is_block() && first_token.block().is_paren() {
		mut block_tokens := ParserTokenStream.from_values(first_token.block().value)
		if declaration := parse_supports_declaration_from_parser_tokens(mut block_tokens) {
			transaction.discard_whitespace()
			tokens = transaction
			return BooleanExpression.create_in_parens(declaration)
		}
	}

	// `<supports-selector-fn> = selector( <complex-selector> )`
	if first_token.is_function_named('selector') {
		selector := supports_component_values_to_string(first_token.function().value)
		matches := parse_selector_with_parser(selector, transaction.declared_namespaces) != none
			&& !supports_selector_contains_unknown_webkit_pseudo_element(selector)
		tokens = transaction
		return BooleanExpression.create_supports_selector(selector, matches)
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
		return BooleanExpression.create_supports_font_tech(tech_name,
			font_tech_is_supported_name(tech_name))
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
		return BooleanExpression.create_supports_font_format(format_name,
			font_format_is_supported(format_name))
	}

	return none
}

// https://drafts.csswg.org/css-conditional-5/#typedef-supports-decl
fn parse_supports_declaration_from_parser_tokens(mut tokens ParserTokenStream) ?&BooleanExpression {
	mut parser := RuleSelectorParser.create(ParsingParams{}, '', 'utf-8')
	declaration := parser.consume_a_declaration(mut tokens, .no, .yes) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}

	property := PropertyNameAndID.from_name(declaration.name) or { return none }
	if property.is_custom_property() {
		original := declaration.original_full_text or {
			supports_component_values_to_string(declaration.value)
		}

		return BooleanExpression.create_supports_declaration(original, true)
	}
	property_id := property.id() or { return none }
	value_text := supports_component_values_to_string(declaration.value).trim_space()
	matches := parse_css_value(ParsingParams{}, value_text, property_id) != none
	original := declaration.original_full_text or { '${declaration.name}: ${value_text}' }
	return BooleanExpression.create_supports_declaration(original, matches)
}

// https://www.w3.org/TR/mediaqueries-4/#typedef-general-enclosed
fn parse_supports_general_enclosed(mut tokens SupportsTokenStream, result MatchResult) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first_token := transaction.consume_a_token() or { return none }
	if first_token.is_function() {
		tokens = transaction
		return BooleanExpression.create_general_enclosed(first_token.to_string(), result)
	}
	if first_token.is_block() && first_token.block().is_paren() {
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
	matches         bool   = true
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
		name:       'all'
		known_type: MediaQueryKnownMediaType.all
	}
}

pub fn MediaQuery.create_not_all() &MediaQuery {
	return &MediaQuery{
		text:       'not all'
		matches:    false
		negated:    true
		media_type: MediaQueryType.all()
	}
}

pub fn MediaQuery.create() &MediaQuery {
	return &MediaQuery{
		text:       'all'
		matches:    true
		media_type: MediaQueryType.all()
	}
}

pub fn parse_media_query(context ParsingParams, text string) ?&MediaQuery {
	queries := parse_css_media_query_list_value_logic(text)
	if queries.len != 1 {
		return none
	}
	_ = context
	return queries[0]
}

pub fn (media_query &MediaQuery) evaluate(doc &dom.Document) bool {
	mut result := media_query_matches_media_type(media_query.media_type)
	if result != .false_ {
		if condition := media_query.media_condition {
			result = match_result_and(result, condition.evaluate(doc))
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
}

pub fn MediaQueryList.create(document &dom.Document, media []&MediaQuery) &MediaQueryList {
	return MediaQueryList.new(document, media)
}

pub fn MediaQueryList.new(document &dom.Document, media []&MediaQuery) &MediaQueryList {
	mut media_query_list := &MediaQueryList{
		document_:     document
		media_queries: media.clone()
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
		matches := media_query.evaluate(media_query_list.document_)
		media_query.matches = matches
		now_matches = now_matches || matches
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
	mut init := MediaQueryListEventInit{
		media:   media_query_list.media()
		matches: matches
	}
	init.EventInit = dom.EventInit{}
	event := MediaQueryListEvent.create('change', init)
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

pub fn (media_query_list &MediaQueryList) register_with_document() {
	// Window::match_media() registers the C++ CSS::MediaQueryList with DOM::Document.
	// Boundary: the V dom module cannot import css, so register the translated CSS
	// object through an opaque callback record owned by DOM.
	mut document := unsafe { &dom.Document(media_query_list.document_) }
	document.add_css_media_query_list(dom.CSSMediaQueryListRegistration{
		target:                voidptr(media_query_list)
		matches:               media_query_list_registration_matches
		evaluate:              media_query_list_registration_evaluate
		has_changed_state:     media_query_list_registration_has_changed_state
		set_has_changed_state: media_query_list_registration_set_has_changed_state
		dispatch_change_event: media_query_list_registration_dispatch_change_event
	})
}

pub struct MediaQueryListEntry {
pub mut:
	text    string
	matches bool
}

@[heap]
pub struct MediaList {
pub mut:
	media                  []MediaQueryListEntry
	associated_style_sheet ?&CSSStyleSheet
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
	media_list.media.clear()
	if text.trim_space().len != 0 {
		media_list.media =
			media_query_entries_from_queries(parse_css_media_query_list_value_logic(text))
	}
	media_list.invalidate_associated_style_sheet()
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

	// 4. Append m to the collection of media queries.
	media_list.media << parsed
	media_list.invalidate_associated_style_sheet()
}

// https://www.w3.org/TR/cssom-1/#dom-medialist-deletemedium
pub fn (mut media_list MediaList) delete_medium(medium string) ! {
	// 1. Let m be the result of parsing the given value.
	parsed := parse_media_query_entry(medium) or { return }

	// 2. If m is null, then return.
	serialized := parsed.text

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
	media_list.invalidate_associated_style_sheet()
}

pub fn (mut media_list MediaList) evaluate(document &dom.Document) bool {
	for i in 0 .. media_list.media.len {
		media_list.media[i].matches = evaluate_media_query_entry(media_list.media[i], document)
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

fn (media_list &MediaList) invalidate_associated_style_sheet() {
	if sheet := media_list.associated_style_sheet {
		mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
		mutable_sheet.invalidate_owners(dom.StyleInvalidationReason.style_change)
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
		text:    query.to_string()
		matches: query.matches()
	}
}

fn evaluate_media_query_entry(entry MediaQueryListEntry, document &dom.Document) bool {
	query := parse_media_query_from_text(entry.text) or { return false }
	return query.evaluate(document)
}

fn media_query_entries_from_queries(queries []&MediaQuery) []MediaQueryListEntry {
	mut entries := []MediaQueryListEntry{cap: queries.len}
	for query in queries {
		entries << MediaQueryListEntry{
			text:    query.to_string()
			matches: query.matches()
		}
	}
	return entries
}

pub fn parse_media_query_from_text(text string) ?&MediaQuery {
	trimmed := text.trim_space()
	if trimmed.len == 0 {
		return none
	}

	mut condition_tokens :=
		SupportsTokenStream.from_values(parse_component_values_for_value_logic(trimmed))
	if condition := parse_media_condition(mut condition_tokens) {
		condition_tokens.discard_whitespace()
		if !condition_tokens.has_next_token() {
			mut query := MediaQuery{
				text:            trimmed
				media_type:      MediaQueryType.all()
				media_condition: unsafe { &BooleanExpression(condition) }
			}
			query.matches = query.evaluate(unsafe { nil })
			return &query
		}
	}

	lower := trimmed.to_lower()
	if lower == 'not all' {
		return MediaQuery.create_not_all()
	}

	mut remaining := trimmed
	mut negated := false
	mut only_modifier := false
	if starts_with_ascii_word_case_insensitive(remaining, 'not') {
		negated = true
		remaining = remaining[3..].trim_space()
	} else if starts_with_ascii_word_case_insensitive(remaining, 'only') {
		only_modifier = true
		remaining = remaining[4..].trim_space()
	}
	_ = only_modifier

	media_type_name, rest := consume_first_ascii_word(remaining)
	if media_type_name.len == 0
		|| media_type_name.to_lower() in ['layer', 'not', 'and', 'only', 'or'] {
		return MediaQuery.create_not_all()
	}

	mut media_type := MediaQueryType{
		name:       media_type_name
		known_type: media_type_from_string(media_type_name)
	}
	mut condition := ?&BooleanExpression(none)
	mut condition_text := rest.trim_space()
	if condition_text.len != 0 {
		if !starts_with_ascii_word_case_insensitive(condition_text, 'and') {
			return MediaQuery.create_not_all()
		}
		condition_text = condition_text[3..].trim_space()
		if condition_text.len == 0 {
			return MediaQuery.create_not_all()
		}
		condition = parse_media_condition_from_text(condition_text) or {
			return MediaQuery.create_not_all()
		}
		if media_condition := condition {
			if media_condition.kind == .or {
				return MediaQuery.create_not_all()
			}
		}
	}

	mut query := MediaQuery{
		text:            trimmed
		negated:         negated
		media_type:      media_type
		media_condition: condition
	}
	query.matches = query.evaluate(unsafe { nil })
	return &query
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

fn parse_media_condition_from_text(condition_text string) ?&BooleanExpression {
	trimmed := condition_text.trim_space()
	if trimmed.len == 0 {
		return none
	}
	mut tokens := SupportsTokenStream.from_values(parse_component_values_for_value_logic(trimmed))
	condition := parse_media_condition(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return condition
}

// `<media-condition>`, https://www.w3.org/TR/mediaqueries-4/#typedef-media-condition
fn parse_media_condition(mut tokens SupportsTokenStream) ?&BooleanExpression {
	return parse_media_boolean_expression(mut tokens, .unknown)
}

// https://drafts.csswg.org/css-values-5/#typedef-boolean-expr
fn parse_media_boolean_expression(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	if peeked_token := transaction.next_token() {
		if peeked_token.is_ident('not') {
			transaction.discard_a_token()
			transaction.discard_whitespace()
			child := parse_media_boolean_expression_group(mut transaction,
				result_for_general_enclosed) or { return none }
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
		child := parse_media_boolean_expression_group(mut transaction, result_for_general_enclosed) or {
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

fn parse_media_boolean_expression_group(mut tokens SupportsTokenStream, result_for_general_enclosed MatchResult) ?&BooleanExpression {
	if first_token := tokens.next_token() {
		if first_token.is_block() && first_token.block().is_paren() {
			mut transaction := tokens
			transaction.discard_a_token()
			mut child_tokens := SupportsTokenStream.from_values(first_token.block().value)
			if expression := parse_media_boolean_expression(mut child_tokens,
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

	if test := parse_media_in_parens(mut tokens) {
		return test
	}

	if general_enclosed := parse_supports_general_enclosed(mut tokens, result_for_general_enclosed) {
		return general_enclosed
	}

	return none
}

// `<media-in-parens>` currently only has the concrete `<media-feature>` branch in the V port.
fn parse_media_in_parens(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	first_token := transaction.next_token() or { return none }
	if !(first_token.is_block() && first_token.block().is_paren()) {
		return none
	}
	transaction.discard_a_token()

	mut inner_tokens := SupportsTokenStream.from_values(first_token.block().value)
	feature := parse_media_feature(mut inner_tokens) or { return none }
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
	kind  MediaFeatureValueKindLocal
	text  string
	name  string
	value f64
}

enum MediaFeatureComparison {
	equal
	less_than
	less_than_or_equal
	greater_than
	greater_than_or_equal
}

fn parse_media_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	if feature := parse_media_feature_boolean(mut tokens) {
		return feature
	}
	if feature := parse_media_feature_plain(mut tokens) {
		return feature
	}
	if feature := parse_media_feature_range(mut tokens) {
		return feature
	}
	return none
}

fn parse_media_feature_boolean(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	name := parse_media_feature_name(mut transaction, false) or { return none }
	transaction.discard_whitespace()
	if transaction.has_next_token() {
		return none
	}
	tokens = transaction
	text := '(${name.name})'
	return BooleanExpression.create_general_enclosed(text, evaluate_media_feature_without_window(name.name,
		.is_true, none, none, none, none))
}

fn parse_media_feature_plain(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	name := parse_media_feature_name(mut transaction, true) or { return none }
	transaction.discard_whitespace()
	if !(transaction.consume_a_token() or { return none }).is(.colon) {
		return none
	}
	transaction.discard_whitespace()
	value := parse_media_feature_value(name.name, mut transaction) or { return none }
	transaction.discard_whitespace()
	if transaction.has_next_token() {
		return none
	}
	tokens = transaction
	match name.prefix {
		.normal {
			text := '(${name.name}: ${value.text})'
			return BooleanExpression.create_general_enclosed(text, evaluate_media_feature_without_window(name.name,
				.exact_value, value, none, none, none))
		}
		.min {
			text := '(min-${name.name}: ${value.text})'
			return BooleanExpression.create_general_enclosed(text, evaluate_media_feature_without_window(name.name,
				.min_value, value, none, none, none))
		}
		.max {
			text := '(max-${name.name}: ${value.text})'
			return BooleanExpression.create_general_enclosed(text, evaluate_media_feature_without_window(name.name,
				.max_value, value, none, none, none))
		}
	}
}

fn parse_media_feature_range(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()

	if name := parse_media_feature_name(mut transaction, false) {
		transaction.discard_whitespace()
		if comparison := parse_media_feature_comparison(mut transaction) {
			transaction.discard_whitespace()
			if value := parse_media_feature_value(name.name, mut transaction) {
				transaction.discard_whitespace()
				if !transaction.has_next_token() && value.kind != .ident {
					tokens = transaction
					text := '(${name.name} ${media_feature_comparison_to_string(comparison)} ${value.text})'
					return BooleanExpression.create_general_enclosed(text, evaluate_media_feature_without_window(name.name,
						.half_range_query_left, value, comparison, none, none))
				}
			}
		}
	}

	transaction = SupportsTokenStream{
		values: tokens.values.clone()
		index:  tokens.index
	}
	transaction.discard_whitespace()
	maybe_name := find_media_feature_name_after_comparison(transaction) or { return none }
	left_value := parse_media_feature_value(maybe_name.name, mut transaction) or { return none }
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
		return BooleanExpression.create_general_enclosed(text, evaluate_media_feature_without_window(maybe_name.name,
			.half_range_query_right, left_value, left_comparison, none, none))
	}

	right_comparison := parse_media_feature_comparison(mut transaction) or { return none }
	transaction.discard_whitespace()
	right_value := parse_media_feature_value(maybe_name.name, mut transaction) or { return none }
	transaction.discard_whitespace()
	if transaction.has_next_token()
		|| !media_feature_comparisons_match(left_comparison, right_comparison)
		|| left_comparison == .equal || left_value.kind == .ident || right_value.kind == .ident {
		return none
	}

	tokens = transaction
	text := '(${left_value.text} ${media_feature_comparison_to_string(left_comparison)} ${maybe_name.name} ${media_feature_comparison_to_string(right_comparison)} ${right_value.text})'
	return BooleanExpression.create_general_enclosed(text, evaluate_media_feature_without_window(maybe_name.name,
		.range, left_value, left_comparison, right_comparison, right_value))
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
			name:   name.to_lower()
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
					name:   adjusted_name
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

fn parse_media_feature_value(feature_name string, mut tokens SupportsTokenStream) ?MediaFeatureValueLocal {
	mut transaction := tokens
	transaction.discard_whitespace()
	start_index := transaction.index
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

	text := supports_component_values_to_string(values).trim_space()
	mut value_tokens := SupportsTokenStream.from_values(values)
	if value := parse_known_media_feature_value(feature_name, text, mut value_tokens) {
		value_tokens.discard_whitespace()
		if !is_media_feature_value_token(value_tokens.next_token() or {
			ComponentValue.from_token(Tokenizer.create_eof_token())
		}) {
			tokens = transaction
			return value
		}
	}

	// Match C++ parse_media_feature_value() fallback: preserve unknown value tokens when they are syntactically value-like.
	if transaction.index > start_index {
		tokens = transaction
		return MediaFeatureValueLocal{
			kind: .unknown
			text: text
		}
	}
	return none
}

fn parse_known_media_feature_value(feature_name string, text string, mut tokens SupportsTokenStream) ?MediaFeatureValueLocal {
	tokens.discard_whitespace()
	if token := tokens.next_token() {
		if token.is(.ident) {
			ident := token.token().ident().to_lower()
			if media_feature_accepts_keyword_name(feature_name, ident) {
				tokens.discard_a_token()
				return MediaFeatureValueLocal{
					kind: .ident
					text: text
					name: ident
				}
			}
		}
	}

	if media_feature_accepts_type_name(feature_name, .boolean) {
		if value := parse_media_feature_integer_value(mut tokens) {
			if value == 0 || value == 1 {
				return MediaFeatureValueLocal{
					kind:  .integer
					text:  text
					value: value
				}
			}
		}
	}

	if media_feature_accepts_type_name(feature_name, .integer) {
		if value := parse_media_feature_integer_value(mut tokens) {
			return MediaFeatureValueLocal{
				kind:  .integer
				text:  text
				value: value
			}
		}
	}

	if media_feature_accepts_type_name(feature_name, .length) {
		if value := parse_media_feature_length_value(mut tokens) {
			return MediaFeatureValueLocal{
				kind:  .length
				text:  text
				value: value
			}
		}
	}

	if media_feature_accepts_type_name(feature_name, .ratio) {
		if value := parse_media_feature_ratio_value(mut tokens) {
			return MediaFeatureValueLocal{
				kind:  .ratio
				text:  text
				value: value
			}
		}
	}

	if media_feature_accepts_type_name(feature_name, .resolution) {
		if value := parse_media_feature_resolution_value(mut tokens) {
			return MediaFeatureValueLocal{
				kind:  .resolution
				text:  text
				value: value
			}
		}
	}

	return none
}

fn parse_media_feature_integer_value(mut tokens SupportsTokenStream) ?f64 {
	mut transaction := tokens
	transaction.discard_whitespace()
	token := transaction.consume_a_token() or { return none }
	if !token.is(.number) || !token.token().number().is_integer() {
		return none
	}
	tokens = transaction
	return token.token().number().value()
}

fn parse_media_feature_length_value(mut tokens SupportsTokenStream) ?f64 {
	mut transaction := tokens
	transaction.discard_whitespace()
	token := transaction.consume_a_token() or { return none }
	if token.is(.number) && token.token().number_value() == 0 {
		tokens = transaction
		return 0.0
	}
	if token.is(.dimension) {
		unit := string_to_length_unit(token.token().dimension_unit()) or { return none }
		if unit == .px {
			tokens = transaction
			return token.token().dimension_value()
		}
		if parse_css_media_feature_value_logic('', token.to_string()) != none {
			tokens = transaction
			return token.token().dimension_value()
		}
	}
	if token.is_function() && parse_css_media_feature_value_logic('', token.to_string()) != none {
		tokens = transaction
		return 0.0
	}
	return none
}

fn parse_media_feature_ratio_value(mut tokens SupportsTokenStream) ?f64 {
	mut transaction := tokens
	transaction.discard_whitespace()
	left := transaction.consume_a_token() or { return none }
	if !left.is(.number) || left.token().number_value() < 0 {
		return none
	}
	transaction.discard_whitespace()
	solidus := transaction.consume_a_token() or { return none }
	if !solidus.is_delim(u32(`/`)) {
		return none
	}
	transaction.discard_whitespace()
	right := transaction.consume_a_token() or { return none }
	if !right.is(.number) || right.token().number_value() <= 0 {
		return none
	}
	tokens = transaction
	return left.token().number_value() / right.token().number_value()
}

fn parse_media_feature_resolution_value(mut tokens SupportsTokenStream) ?f64 {
	mut transaction := tokens
	transaction.discard_whitespace()
	token := transaction.consume_a_token() or { return none }
	if token.is(.dimension) {
		unit := string_to_resolution_unit(token.token().dimension_unit()) or { return none }
		tokens = transaction
		return token.token().dimension_value() * ratio_between_resolution_units(unit, .dppx)
	}
	return none
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

fn evaluate_media_feature_without_window(feature_name string, kind MediaFeatureEvalKind, value ?MediaFeatureValueLocal, comparison ?MediaFeatureComparison, right_comparison ?MediaFeatureComparison, right_value ?MediaFeatureValueLocal) MatchResult {
	queried_value := query_media_feature_without_window(feature_name) or { return .unknown }
	match kind {
		.is_true {
			return evaluate_media_feature_value_as_boolean(feature_name, queried_value)
		}
		.exact_value {
			expected := value or { return .unknown }
			return compare_media_feature_values(queried_value, .equal, expected)
		}
		.min_value {
			expected := value or { return .unknown }
			return compare_media_feature_values(queried_value, .greater_than_or_equal, expected)
		}
		.max_value {
			expected := value or { return .unknown }
			return compare_media_feature_values(queried_value, .less_than_or_equal, expected)
		}
		.half_range_query_left {
			expected := value or { return .unknown }
			expected_comparison := comparison or { return .unknown }
			return compare_media_feature_values(queried_value, expected_comparison, expected)
		}
		.half_range_query_right {
			expected := value or { return .unknown }
			expected_comparison := comparison or { return .unknown }
			return compare_media_feature_values(expected, expected_comparison, queried_value)
		}
		.range {
			left := value or { return .unknown }
			left_comparison := comparison or { return .unknown }
			right := right_value or { return .unknown }
			comparison_to_right := right_comparison or { return .unknown }
			left_result := compare_media_feature_values(left, left_comparison, queried_value)
			if left_result != .true_ {
				return left_result
			}
			return compare_media_feature_values(queried_value, comparison_to_right, right)
		}
	}
}

fn query_media_feature_without_window(feature_name string) ?MediaFeatureValueLocal {
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
			media_feature_length_value(600)
		}
		'horizontal-viewport-segments', 'vertical-viewport-segments' {
			media_feature_integer_value(1)
		}
		'nav-controls' {
			media_feature_ident_value('back')
		}
		'orientation' {
			media_feature_ident_value('landscape')
		}
		'overflow-block', 'overflow-inline' {
			media_feature_ident_value('scroll')
		}
		'prefers-color-scheme' {
			media_feature_ident_value('light')
		}
		'prefers-contrast', 'prefers-reduced-data', 'prefers-reduced-motion',
		'prefers-reduced-transparency' {
			media_feature_ident_value('no-preference')
		}
		'resolution' {
			media_feature_resolution_value(1)
		}
		'scripting' {
			media_feature_ident_value('enabled')
		}
		'update' {
			media_feature_ident_value('fast')
		}
		'width', 'device-width' {
			media_feature_length_value(800)
		}
		'aspect-ratio', 'device-aspect-ratio' {
			media_feature_ratio_value(800.0 / 600.0)
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
		kind:  .integer
		text:  serialize_a_number(value)
		value: value
	}
}

fn media_feature_length_value(value f64) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind:  .length
		text:  '${serialize_a_number(value)}px'
		value: value
	}
}

fn media_feature_ratio_value(value f64) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind:  .ratio
		text:  serialize_a_number(value)
		value: value
	}
}

fn media_feature_resolution_value(value f64) MediaFeatureValueLocal {
	return MediaFeatureValueLocal{
		kind:  .resolution
		text:  '${serialize_a_number(value)}dppx'
		value: value
	}
}

fn evaluate_media_feature_value_as_boolean(feature_name string, value MediaFeatureValueLocal) MatchResult {
	match value.kind {
		.ident {
			if media_feature_keyword_is_falsey_name(feature_name, value.name) {
				return .false_
			}
			return .true_
		}
		.integer, .length, .ratio, .resolution {
			return as_match_result(value.value != 0)
		}
		.unknown {
			return .unknown
		}
	}
}

fn compare_media_feature_values(left MediaFeatureValueLocal, comparison MediaFeatureComparison, right MediaFeatureValueLocal) MatchResult {
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
	return match comparison {
		.equal { as_match_result(left.value == right.value) }
		.less_than { as_match_result(left.value < right.value) }
		.less_than_or_equal { as_match_result(left.value <= right.value) }
		.greater_than { as_match_result(left.value > right.value) }
		.greater_than_or_equal { as_match_result(left.value >= right.value) }
	}
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
		'any-hover', 'any-pointer', 'forced-colors', 'hover', 'inverted-colors', 'nav-controls',
		'overflow-block', 'overflow-inline', 'pointer', 'scan', 'scripting', 'update' {
			lower_keyword == 'none'
		}
		'dynamic-range', 'video-dynamic-range' {
			lower_keyword in ['standard', 'high']
		}
		'prefers-contrast', 'prefers-reduced-data', 'prefers-reduced-motion',
		'prefers-reduced-transparency' {
			lower_keyword == 'no-preference'
		}
		else {
			false
		}
	}
}

fn starts_with_ascii_word_case_insensitive(text string, word string) bool {
	if text.len < word.len {
		return false
	}
	if text[..word.len].to_lower() != word {
		return false
	}
	if text.len == word.len {
		return true
	}
	return text[word.len].is_space()
}

fn consume_first_ascii_word(text string) (string, string) {
	mut index := 0
	for index < text.len && !text[index].is_space() {
		index++
	}
	return text[..index], text[index..]
}
