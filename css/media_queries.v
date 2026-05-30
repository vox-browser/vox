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
	_ = context
	mut tokens :=
		SupportsTokenStream.from_values(parse_component_values_for_value_logic(condition_text))
	condition := parse_supports_condition(mut tokens) or { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() {
		return none
	}
	return Supports.create(condition)
}

fn parse_css_supports_stub(condition_text string) ?&Supports {
	trimmed := condition_text.trim_space()
	if trimmed.len == 0 {
		return none
	}
	return Supports.create(BooleanExpression.create_general_enclosed(trimmed, .true_))
}

struct SupportsTokenStream {
mut:
	values []ComponentValue
	index  int
}

fn SupportsTokenStream.from_values(values []ComponentValue) SupportsTokenStream {
	return SupportsTokenStream{
		values: values.clone()
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
			mut child_tokens := SupportsTokenStream.from_values(first_token.block().value)
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
		matches := parse_selector_with_parser(selector, map[string]bool{}) != none
			&& !supports_selector_contains_unknown_webkit_pseudo_element_stub(selector)
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

fn supports_selector_contains_unknown_webkit_pseudo_element_stub(selector string) bool {
	_ = selector
	// Stub for Selector::contains_unknown_webkit_pseudo_element().
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

pub fn (media_query_list &MediaQueryList) register_with_document_stub() {
	_ = media_query_list
	// Stub: Window::match_media() registers the C++ CSS::MediaQueryList with DOM::Document.
	// The V DOM module currently owns a small placeholder MediaQueryList to avoid a circular dom <-> css import,
	// so registration has to stay at this boundary until the shared interface is split out.
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
	parsed := parse_media_query_entry_stub(medium) or { return }

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
	parsed := parse_media_query_entry_stub(medium) or { return }

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
		media_list.media[i].matches = evaluate_media_query_entry_stub(media_list.media[i], document)
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

fn media_query_text_matches_stub(text string) bool {
	query := parse_media_query_from_text(text) or { return false }
	return query.matches()
}

fn parse_media_query_entry_stub(medium string) ?MediaQueryListEntry {
	query := parse_media_query_from_text(medium) or { return none }
	return MediaQueryListEntry{
		text:    query.to_string()
		matches: query.matches()
	}
}

fn parse_media_query_list_stub(text string) []MediaQueryListEntry {
	return media_query_entries_from_queries(parse_css_media_query_list_value_logic(text))
}

fn evaluate_media_query_entry_stub(entry MediaQueryListEntry, document &dom.Document) bool {
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
		condition = parse_media_condition_stub(condition_text)
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

fn parse_media_condition_stub(condition_text string) ?&BooleanExpression {
	trimmed := condition_text.trim_space()
	if trimmed.len == 0 {
		return none
	}
	// Stub for Parser::parse_media_condition(): media-feature evaluation needs
	// Window::query_media_feature(). Preserve the parsed condition text and keep
	// ordinary screen media active until the feature evaluator is ported.
	return BooleanExpression.create_general_enclosed(trimmed, .true_)
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
