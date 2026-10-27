module css

import dom
import strings

// Extra CSSOM/event/sheet wrapper logic translated from the small Ladybird
// wrapper classes that do not have their own V subclass files.

// --- Event wrapper helpers ---

pub fn (event &AnimationEvent) base_event() &dom.Event {
	return event.event
}

pub fn (event &TransitionEvent) base_event() &dom.Event {
	return event.event
}

pub fn (event &MediaQueryListEvent) base_event() &dom.Event {
	return unsafe { &dom.Event(event) }
}

pub fn (event &FontFaceSetLoadEvent) base_event() &dom.Event {
	return event.event
}

// --- StyleSheetIdentifier wire conversion ---

pub struct StyleSheetIdentifierWire {
pub mut:
	type_                 StyleSheetIdentifierType
	dom_element_unique_id ?u64
	url                   ?string
	rule_count            uint
}

pub fn (identifier StyleSheetIdentifier) encode_for_ipc() StyleSheetIdentifierWire {
	return StyleSheetIdentifierWire{
		type_:                 identifier.type_
		dom_element_unique_id: identifier.dom_element_unique_id
		url:                   identifier.url
		rule_count:            identifier.rule_count
	}
}

pub fn style_sheet_identifier_decode_from_ipc(wire StyleSheetIdentifierWire) StyleSheetIdentifier {
	return StyleSheetIdentifier{
		type_:                 wire.type_
		dom_element_unique_id: wire.dom_element_unique_id
		url:                   wire.url
		rule_count:            wire.rule_count
	}
}

// --- StyleSheet / CSSStyleSheet wrapper accessors ---

pub fn (sheet &StyleSheet) media_for_bindings() &MediaList {
	return sheet.media
}

pub fn (sheet &StyleSheet) owner_node() ?&dom.Element {
	return sheet.owner_node
}

pub fn (sheet &StyleSheet) parent_css_style_sheet() ?&CSSStyleSheet {
	return sheet.parent_style_sheet
}

pub fn (sheet &StyleSheet) location() ?string {
	return sheet.location
}

pub fn (mut sheet StyleSheet) set_location(location ?string) {
	sheet.location = location
}

pub fn (sheet &StyleSheet) title() string {
	return sheet.title
}

pub fn (mut sheet StyleSheet) set_title(title string) {
	sheet.title = title
}

pub fn (sheet &StyleSheet) type_string_for_bindings() string {
	return sheet.type_string
}

pub fn (mut sheet StyleSheet) set_type(type_ string) {
	sheet.type_string = type_
}

pub fn (sheet &StyleSheet) disabled() bool {
	return sheet.disabled
}

pub fn (mut sheet StyleSheet) set_disabled(disabled bool) {
	sheet.disabled = disabled
}

pub fn (sheet &StyleSheet) is_alternate() bool {
	return sheet.alternate
}

pub fn (mut sheet StyleSheet) set_alternate(alternate bool) {
	sheet.alternate = alternate
}

pub fn (sheet &StyleSheet) is_origin_clean() bool {
	return sheet.origin_clean
}

pub fn (mut sheet StyleSheet) set_origin_clean(origin_clean bool) {
	sheet.origin_clean = origin_clean
}

pub fn (mut sheet StyleSheet) visit_edges(mut visitor dom.CellVisitor) {
	if owner_node := sheet.owner_node {
		visitor.visit(owner_node)
	}
	if parent_style_sheet := sheet.parent_style_sheet {
		visitor.visit(parent_style_sheet)
	}
	visitor.visit(sheet.media)
}

pub fn (sheet &CSSStyleSheet) rules_for_bindings() &CSSRuleList {
	return sheet.rules
}

pub fn (sheet &CSSStyleSheet) owner_css_rule() ?&CSSRule {
	return sheet.owner_rule
}

pub fn (sheet &CSSStyleSheet) style_sheet_for_bindings() &CSSStyleSheet {
	return sheet
}

pub fn (sheet &CSSStyleSheet) constructor_document() ?&dom.Document {
	return sheet.constructor_document
}

pub fn (mut sheet CSSStyleSheet) set_constructor_document(document ?&dom.Document) {
	sheet.constructor_document = document
}

pub fn (sheet &CSSStyleSheet) base_url_for_bindings() ?string {
	return sheet.base_url
}

pub fn (mut sheet CSSStyleSheet) set_base_url(url ?string) {
	sheet.base_url = url
}

pub fn (sheet &CSSStyleSheet) constructed_for_bindings() bool {
	return sheet.constructed
}

pub fn (mut sheet CSSStyleSheet) set_constructed(constructed bool) {
	sheet.constructed = constructed
}

pub fn (sheet &CSSStyleSheet) disallow_modification_for_bindings() bool {
	return sheet.disallow_modification
}

pub fn (mut sheet CSSStyleSheet) set_disallow_modification(disallow_modification bool) {
	sheet.disallow_modification = disallow_modification
}

pub fn (mut sheet CSSStyleSheet) visit_edges(mut visitor dom.CellVisitor) {
	sheet.base.visit_edges(mut visitor)
	visitor.visit(sheet.rules)
	if owner_rule := sheet.owner_rule {
		visitor.visit(owner_rule)
	}
	if default_namespace_rule := sheet.default_namespace_rule {
		visitor.visit(default_namespace_rule)
	}
	if constructor_document := sheet.constructor_document {
		visitor.visit(constructor_document)
	}
	for _, namespace_rule in sheet.namespace_rules {
		visitor.visit(namespace_rule)
	}
	for import_rule in sheet.import_rules {
		visitor.visit(import_rule)
	}
	for owner in sheet.owning_documents_or_shadow_roots {
		visitor.visit(owner)
	}
	for subresource in sheet.critical_subresources {
		visitor.visit(subresource)
	}
}

pub fn (list &CSSRuleList) item_value(index uint) ?&CSSRule {
	return list.item(index)
}

pub fn (mut list CSSRuleList) visit_edges(mut visitor dom.CellVisitor) {
	for rule in list.rules {
		visitor.visit(rule)
	}
	if owner_rule := list.owner_rule {
		visitor.visit(owner_rule)
	}
	if owner_style_sheet := list.owner_style_sheet {
		visitor.visit(owner_style_sheet)
	}
}

pub fn (list &StyleSheetList) item_value(index uint) ?&CSSStyleSheet {
	return list.item(index)
}

pub fn (mut list StyleSheetList) visit_edges(mut visitor dom.CellVisitor) {
	visitor.visit(list.document_or_shadow_root)
	for sheet in list.sheets {
		visitor.visit(sheet)
	}
}

// --- CSSRule base and CSSImportRule helpers ---

pub fn (rule &CSSRule) class_name() string {
	return rule.type_.class_name()
}

pub fn (rule &CSSRule) parent_css_rule() ?&CSSRule {
	return rule.parent_rule
}

pub fn (rule &CSSRule) parent_css_style_sheet() ?&CSSStyleSheet {
	return rule.parent_style_sheet
}

pub fn (rule &CSSRule) href() string {
	if rule.type_ != .import_rule {
		return ''
	}
	return rule.kind_data().url
}

pub fn (rule &CSSRule) style_sheet_for_bindings() ?&CSSStyleSheet {
	if rule.type_ != .import_rule {
		return none
	}
	return rule.kind_data().loaded_style_sheet
}

pub fn (rule &CSSRule) loaded_style_sheet_for_bindings() ?&CSSStyleSheet {
	return rule.style_sheet_for_bindings()
}

pub fn (rule &CSSRule) media_list_for_bindings() ?&MediaList {
	if rule.type_ !in [.import_rule, .media] {
		return none
	}
	return rule.media
}

pub fn (rule &CSSRule) namespace_rule_prefix() string {
	if rule.type_ != .namespace_rule {
		return ''
	}
	return rule.kind_data().prefix
}

pub fn (rule &CSSRule) namespace_rule_namespace_uri() string {
	if rule.type_ != .namespace_rule {
		return ''
	}
	return rule.kind_data().namespace_uri
}

// --- CSSLayerBlockRule ---

pub fn CSSRule.create_layer_block(name string, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.layer_block, rules)
	rule.kind_data_ = &CSSRuleKindData{
		layer: name
		layer_internal: if name.len == 0 { next_unique_anonymous_layer_name() } else { name }
	}
	return rule
}

pub fn (rule &CSSRule) layer_block_name() string {
	if rule.type_ != .layer_block {
		return ''
	}
	return rule.kind_data().layer or { '' }
}

pub fn (rule &CSSRule) layer_block_internal_name() string {
	if rule.type_ != .layer_block {
		return ''
	}
	return rule.kind_data().layer_internal or { rule.layer_block_name() }
}

pub fn (mut rule CSSRule) layer_block_internal_qualified_name() string {
	parent_name := rule.parent_layer_internal_qualified_name()
	internal_name := rule.layer_block_internal_name()
	if parent_name.len == 0 {
		return internal_name
	}
	return '${parent_name}.${internal_name}'
}

fn (rule &CSSRule) serialized_layer_block_rule() string {
	// AD-HOC: No spec yet, so this is based on the @media serialization algorithm.
	mut builder := strings.new_builder(128)
	builder.write_string('@layer')
	if name := rule.kind_data().layer {
		if name.len != 0 {
			builder.write_string(' ${name}')
		}
	}
	builder.write_string(' {\n')
	if rules := rule.rules {
		if rules.length() == 0 {
			builder.write_u8(`}`)
			return builder.str()
		}
		for i in 0 .. rules.length() {
			child_rule := rules.item(uint(i)) or { continue }
			if i != 0 {
				builder.write_u8(`\n`)
			}
			builder.write_string('  ')
			builder.write_string(child_rule.css_text())
		}
	}
	builder.write_string('\n}')
	return builder.str()
}

// --- CSSLayerStatementRule ---

pub fn CSSRule.create_layer_statement(name_list []string) &CSSRule {
	mut rule := CSSRule.create(.layer_statement)
	rule.kind_data_ = &CSSRuleKindData{
		layer_name_list: name_list.clone()
		layer: name_list.join(', ')
	}
	return rule
}

pub fn (rule &CSSRule) layer_statement_name_list() []string {
	if rule.type_ != .layer_statement {
		return []string{}
	}
	if rule.kind_data().layer_name_list.len != 0 {
		return rule.kind_data().layer_name_list.clone()
	}
	if names := rule.kind_data().layer {
		mut list := []string{}
		for name in names.split(',') {
			trimmed := name.trim_space()
			if trimmed.len != 0 {
				list << trimmed
			}
		}
		return list
	}
	return []string{}
}

pub fn (mut rule CSSRule) layer_statement_internal_qualified_name_list() []string {
	names := rule.layer_statement_name_list()
	parent_name := rule.parent_layer_internal_qualified_name()
	if parent_name.len == 0 {
		return names
	}
	mut qualified_layer_names := []string{cap: names.len}
	for name in names {
		qualified_layer_names << '${parent_name}.${name}'
	}
	return qualified_layer_names
}

fn (rule &CSSRule) serialized_layer_statement_rule() string {
	// AD-HOC: No spec yet.
	return '@layer ${rule.layer_statement_name_list().join(', ')};'
}

// --- CSSKeyframeRule / CSSKeyframesRule ---

pub fn CSSRule.create_keyframe(key Percentage, declarations &CSSStyleProperties) &CSSRule {
	mut rule := CSSRule.create(.keyframe)
	rule.kind_data_ = &CSSRuleKindData{ keyframe_key: key }
	rule.declaration = declarations
	mut mutable_declarations := unsafe { &CSSStyleProperties(declarations) }
	mutable_declarations.set_parent_rule(rule)
	return rule
}

pub fn CSSRule.create_keyframes(name string, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.keyframes, rules)
	rule.kind_data_ = &CSSRuleKindData{ url: name }
	return rule
}

pub fn (rule &CSSRule) key_text() string {
	if rule.type_ != .keyframe {
		return ''
	}
	if key := rule.kind_data().keyframe_key {
		return key.to_string()
	}
	return rule.kind_data().url
}

pub fn (mut rule CSSRule) set_key_text(key_text string) {
	_ = key_text
	// FIXME: CSSKeyframeRule::set_key_text is not implemented upstream either.
}

pub fn (rule &CSSRule) keyframes_name() string {
	if rule.type_ != .keyframes {
		return ''
	}
	return cssom_unquote_css_string_if_wrapped(rule.kind_data().url)
}

pub fn (mut rule CSSRule) set_keyframes_name(name string) {
	if rule.type_ == .keyframes {
		if rule.kind_data().url != name {
			mut storage := rule.enter_kind_data_storage()
			defer { storage.finish() }
			rule.set_kind_data(CSSRuleKindData{ ...rule.kind_data(), url: name.clone() })
		}
	}
}

pub fn (rule &CSSRule) keyframes_length() u32 {
	if rule.type_ != .keyframes {
		return 0
	}
	if rules := rule.rules {
		return u32(rules.length())
	}
	return 0
}

fn (rule &CSSRule) serialized_keyframe_rule() string {
	style_text := if style := rule.declaration { style.serialized() } else { '' }
	return '${rule.key_text()} { ${style_text} }'
}

fn (rule &CSSRule) serialized_keyframes_rule() string {
	mut builder := strings.new_builder(128)
	// CSSKeyframesRule::serialized() writes `@keyframes "{}"` with the name
	// inserted verbatim - it is not run through "serialize a string", so a name
	// that already carries an escape keeps its single reverse solidus.
	builder.write_string('@keyframes "')
	builder.write_string(rule.keyframes_name())
	builder.write_string('" { ')
	if rules := rule.rules {
		for keyframe in rules.rules {
			builder.write_string(keyframe.css_text())
			builder.write_u8(` `)
		}
	}
	builder.write_u8(`}`)
	return builder.str()
}

fn cssom_unquote_css_string_if_wrapped(value string) string {
	// Parser conversion currently stores Token::to_string() for keyframe names, so string
	// names may already include CSS quotes. Full CSS string unescaping belongs in the parser.
	if value.len >= 2 && ((value[0] == `"` && value[value.len - 1] == `"`)
		|| (value[0] == `'` && value[value.len - 1] == `'`)) {
		return value[1..value.len - 1]
	}
	return value
}

// --- CSSFontFaceRule / CSSFontFeatureValuesRule / CSSCounterStyleRule storage ---

pub fn CSSRule.create_font_face_rule(font_face_rule &CSSFontFaceRule) &CSSRule {
	mut rule := CSSRule.create(.font_face)
	rule.kind_data_ = &CSSRuleKindData{ font_face_rule: font_face_rule }
	return rule
}

pub fn (rule &CSSRule) font_face_rule_ref() ?&CSSFontFaceRule {
	if rule.type_ != .font_face {
		return none
	}
	return rule.kind_data().font_face_rule
}

fn (rule &CSSRule) serialized_font_face_rule() string {
	if font_face_rule := rule.kind_data().font_face_rule {
		return font_face_rule.serialized()
	}
	return '@font-face { }'
}

pub fn CSSRule.create_font_feature_values_rule(font_feature_values_rule &CSSFontFeatureValuesRule) &CSSRule {
	mut rule := CSSRule.create(.font_feature_values)
	rule.kind_data_ = &CSSRuleKindData{ font_feature_values_rule: font_feature_values_rule }
	return rule
}

pub fn (rule &CSSRule) font_feature_values_rule_ref() ?&CSSFontFeatureValuesRule {
	if rule.type_ != .font_feature_values {
		return none
	}
	return rule.kind_data().font_feature_values_rule
}

fn (rule &CSSRule) serialized_font_feature_values_rule() string {
	if font_feature_values_rule := rule.kind_data().font_feature_values_rule {
		return font_feature_values_rule.serialized()
	}
	return '@font-feature-values { }'
}

pub fn CSSRule.create_counter_style_rule(counter_style_rule &CSSCounterStyleRule) &CSSRule {
	mut rule := CSSRule.create(.counter_style)
	rule.kind_data_ = &CSSRuleKindData{
		counter_style_rule: counter_style_rule
		url: counter_style_rule.name()
	}
	return rule
}

pub fn (rule &CSSRule) counter_style_rule_value() ?&CSSCounterStyleRule {
	if rule.type_ != .counter_style {
		return none
	}
	return rule.kind_data().counter_style_rule
}

fn (rule &CSSRule) serialized_counter_style_rule() string {
	if counter_style_rule := rule.kind_data().counter_style_rule {
		return counter_style_rule.serialized()
	}
	return '@counter-style ${serialize_an_identifier(rule.kind_data().url)} { }'
}

// --- CSSPageRule ---

pub fn CSSRule.create_page(selectors PageSelectorList, descriptors &CSSPageDescriptors, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.page, rules)
	rule.kind_data_ = &CSSRuleKindData{
		page_selectors: selectors.clone()
		page_descriptors: descriptors
	}
	mut mutable_descriptors := unsafe { &CSSPageDescriptors(descriptors) }
	mutable_descriptors.base.set_parent_rule(rule)
	return rule
}

pub fn (rule &CSSRule) page_style() ?&CSSPageDescriptors {
	if rule.type_ != .page {
		return none
	}
	return rule.kind_data().page_descriptors
}

pub fn (rule &CSSRule) page_selector_text() string {
	if rule.type_ != .page {
		return ''
	}
	// The selectorText attribute, on getting, must return the result of serializing the
	// associated selector list.
	// https://www.w3.org/TR/cssom/#serialize-a-group-of-selectors
	// To serialize a group of selectors serialize each selector in the group of selectors and
	// then serialize a comma-separated list of these serializations.
	mut selectors := []string{cap: rule.kind_data().page_selectors.len}
	for selector in rule.kind_data().page_selectors {
		serialized := selector.serialize()
		if serialized.len != 0 {
			selectors << serialized
		}
	}
	return selectors.join(', ')
}

pub fn (mut rule CSSRule) set_page_selector_text(text string) {
	if rule.type_ != .page {
		return
	}

	mut storage := rule.enter_kind_data_storage()
	defer { storage.finish() }

	// On setting the selectorText attribute these steps must be run:
	// 1. Run the parse a list of CSS page selectors algorithm on the given value.
	selectors := parse_page_selector_list(text) or { return }

	// 2. If the algorithm returns a non-null value replace the associated selector list with
	// the returned value.
	// 3. Otherwise, if the algorithm returns a null value, do nothing.
	rule.set_kind_data(CSSRuleKindData{ ...rule.kind_data(), page_selectors: selectors })
}

fn (rule &CSSRule) serialized_page_rule() string {
	mut builder := strings.new_builder(128)
	builder.write_string('@page ')
	selector := rule.page_selector_text()
	if selector.len != 0 {
		builder.write_string('${selector} ')
	}
	builder.write_string('{ ')
	if descriptors := rule.kind_data().page_descriptors {
		if descriptors.base.length() > 0 {
			builder.write_string(descriptors.base.serialized())
			builder.write_u8(` `)
		}
	}
	if rules := rule.rules {
		for i in 0 .. rules.length() {
			child_rule := rules.item(uint(i)) or { continue }
			result := child_rule.css_text()
			if result.len == 0 {
				continue
			}
			builder.write_string('${result} ')
		}
	}
	builder.write_u8(`}`)
	return builder.str()
}

fn parse_page_selector_list(text string) ?PageSelectorList {
	mut tokens := ParserTokenStream.from_tokens(Tokenizer.tokenize(text, 'utf-8'))
	return parse_a_page_selector_list_translated(mut tokens)
}

fn parse_a_page_selector_list_translated(mut tokens ParserTokenStream) ?PageSelectorList {
	// https://drafts.csswg.org/css-page-3/#syntax-page-selector
	// <page-selector-list> = <page-selector>#
	// <page-selector> = [ <ident-token>? <pseudo-page>* ]!
	// <pseudo-page> = : [ left | right | first | blank ]

	mut selector_list := PageSelectorList{}

	tokens.discard_whitespace()

	for tokens.has_next_token() {
		// First optional ident
		mut maybe_ident := ?string(none)
		if tokens.next_token().is(.ident) {
			maybe_ident = tokens.consume_a_token().token().ident()
		}

		// Then an optional series of pseudo-classes
		mut pseudo_classes := []PagePseudoClass{}
		for tokens.next_token().is(.colon) {
			tokens.discard_a_token() // :
			if !tokens.next_token().is(.ident) {
				return none
			}
			pseudo_class_name := tokens.consume_a_token().token().ident()
			if pseudo_class := page_pseudo_class_from_string(pseudo_class_name) {
				pseudo_classes << pseudo_class
			} else {
				return none
			}
		}

		if maybe_ident == none && pseudo_classes.len == 0 {
			// Nothing parsed
			return none
		}

		selector_list << PageSelector.new(maybe_ident, pseudo_classes)

		tokens.discard_whitespace()

		if tokens.next_token().is(.comma) {
			tokens.discard_a_token() // ,
			tokens.discard_whitespace()
			if !tokens.has_next_token() {
				return none
			}
		} else if tokens.has_next_token() {
			return none
		}
	}

	return selector_list
}

// --- CSSMarginRule ---

pub fn CSSRule.create_margin(name string, style &CSSStyleProperties) &CSSRule {
	mut rule := CSSRule.create(.margin)
	rule.kind_data_ = &CSSRuleKindData{ margin_name: name.to_lower() }
	rule.declaration = style
	mut mutable_style := unsafe { &CSSStyleProperties(style) }
	mutable_style.set_parent_rule(rule)
	return rule
}

pub fn (rule &CSSRule) margin_rule_name() string {
	if rule.type_ != .margin {
		return ''
	}
	if rule.kind_data().margin_name.len != 0 {
		return rule.kind_data().margin_name
	}
	return rule.kind_data().url
}

fn (rule &CSSRule) serialized_margin_rule() string {
	mut builder := strings.new_builder(64)
	builder.write_string('@${rule.margin_rule_name()} { ')
	if style := rule.declaration {
		if style.length() > 0 {
			builder.write_string(style.serialized())
			builder.write_u8(` `)
		}
	}
	builder.write_u8(`}`)
	return builder.str()
}

pub fn is_margin_rule_name(name string) bool {
	lower := name.to_lower()
	return lower in [
		'top-left-corner',
		'top-left',
		'top-center',
		'top-right',
		'top-right-corner',
		'bottom-left-corner',
		'bottom-left',
		'bottom-center',
		'bottom-right',
		'bottom-right-corner',
		'left-top',
		'left-middle',
		'left-bottom',
		'right-top',
		'right-middle',
		'right-bottom',
	]
}

// --- CSSPropertyRule ---

pub fn CSSRule.create_property_rule(name string, syntax string, inherits bool, initial_value ?string) &CSSRule {
	return CSSRule.create_property_rule_with_parsed_initial_value(name, syntax, inherits,
		initial_value, none)
}

pub fn CSSRule.create_property_rule_with_parsed_initial_value(name string, syntax string, inherits bool, initial_value ?string, initial_style_value ?StyleValue) &CSSRule {
	mut rule := CSSRule.create(.property)
	rule.kind_data_ = &CSSRuleKindData{
		property_rule_name: name
		property_rule_syntax: syntax
		property_rule_inherits: inherits
		property_rule_initial_value: initial_value
		property_rule_initial_style_value: initial_style_value
		url: name
		namespace_uri: syntax
		prefix: initial_value or { '' }
	}
	return rule
}

pub fn (rule &CSSRule) property_rule_name() string {
	if rule.type_ != .property {
		return ''
	}
	if rule.kind_data().property_rule_name.len != 0 {
		return rule.kind_data().property_rule_name
	}
	return rule.kind_data().url
}

pub fn (rule &CSSRule) property_rule_syntax() string {
	if rule.type_ != .property {
		return ''
	}
	if rule.kind_data().property_rule_syntax.len != 0 {
		return rule.kind_data().property_rule_syntax
	}
	return rule.kind_data().namespace_uri
}

pub fn (rule &CSSRule) property_rule_inherits() bool {
	return rule.type_ == .property && rule.kind_data().property_rule_inherits
}

pub fn (rule &CSSRule) property_rule_initial_value() ?string {
	if rule.type_ != .property {
		return none
	}
	if initial_value := rule.kind_data().property_rule_initial_value {
		return initial_value
	}
	if rule.kind_data().prefix.len != 0 {
		return rule.kind_data().prefix
	}
	return none
}

pub fn (rule &CSSRule) property_rule_initial_style_value() ?StyleValue {
	if rule.type_ != .property {
		return none
	}
	return rule.kind_data().property_rule_initial_style_value
}

pub fn (rule &CSSRule) property_rule_to_registration() CustomPropertyRegistration {
	return CustomPropertyRegistration{
		property_name: rule.property_rule_name()
		syntax:        rule.property_rule_syntax()
		inherit:       rule.property_rule_inherits()
		initial_value: rule.property_rule_initial_value()
	}
}

fn (rule &CSSRule) serialized_property_rule() string {
	mut builder := strings.new_builder(128)
	builder.write_string('@property ${serialize_an_identifier(rule.property_rule_name())} ')
	builder.write_string('{ ')
	builder.write_string('syntax: ${serialize_a_string(rule.property_rule_syntax())}; ')
	builder.write_string('inherits: ${rule.property_rule_inherits()}; ')
	if initial_value := rule.property_rule_initial_value() {
		builder.write_string('initial-value: ${initial_value}; ')
	}
	builder.write_u8(`}`)
	return builder.str()
}
