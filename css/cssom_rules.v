module css

import dom
import strings

// This file ports the CSSOM rule/list/style-sheet layer from Ladybird's LibWeb/CSS.
// It includes folded translations of CSSConditionRule.cpp and CSSGroupingRule.cpp.
// Fetch, JS realm/promise, style-value resource loading, and some DOM/style-scope
// integration points are represented by explicit local boundaries until the
// surrounding V modules grow those subsystems.

pub enum CSSRuleType {
	style
	import_rule
	media
	font_face
	page
	keyframes
	keyframe
	margin
	namespace_rule
	counter_style
	supports
	container_rule
	font_feature_values
	layer_block
	layer_statement
	nested_declarations
	property
	scope
	function_rule
	function_declarations
}

// The rule types whose C++ class derives from CSSGroupingRule, i.e. the rules
// that may contain style rules: CSSStyleRule, CSSPageRule, CSSLayerBlockRule,
// and the CSSConditionRule subclasses CSSMediaRule and CSSSupportsRule.
pub const css_grouping_rule_types = [CSSRuleType.style, .page, .layer_block, .media, .supports,
	.container_rule, .scope, .function_rule]

pub fn (t CSSRuleType) type_for_bindings() u16 {
	// NOTE: Types that aren't defined in the spec must return 0.
	// To do this, Ladybird arbitrarily makes non-spec ones start at 100.
	return match t {
		.style { 1 }
		.import_rule { 3 }
		.media { 4 }
		.font_face { 5 }
		.page { 6 }
		.keyframes { 7 }
		.keyframe { 8 }
		.margin { 9 }
		.namespace_rule { 10 }
		.counter_style { 11 }
		.supports { 12 }
		.font_feature_values { 14 }
		.layer_block, .layer_statement, .nested_declarations, .property, .scope, .container_rule, .function_rule, .function_declarations {
			0
		}
	}
}

pub fn (t CSSRuleType) class_name() string {
	return match t {
		.style { 'CSSStyleRule' }
		.import_rule { 'CSSImportRule' }
		.media { 'CSSMediaRule' }
		.font_face { 'CSSFontFaceRule' }
		.page { 'CSSPageRule' }
		.keyframes { 'CSSKeyframesRule' }
		.keyframe { 'CSSKeyframeRule' }
		.margin { 'CSSMarginRule' }
		.namespace_rule { 'CSSNamespaceRule' }
		.counter_style { 'CSSCounterStyleRule' }
		.supports { 'CSSSupportsRule' }
		.container_rule { 'CSSContainerRule' }
		.font_feature_values { 'CSSFontFeatureValuesRule' }
		.layer_block { 'CSSLayerBlockRule' }
		.layer_statement { 'CSSLayerStatementRule' }
		.nested_declarations { 'CSSNestedDeclarations' }
		.property { 'CSSPropertyRule' }
		.scope { 'CSSScopeRule' }
		.function_rule { 'CSSFunctionRule' }
		.function_declarations { 'CSSFunctionDeclarations' }
	}
}

pub enum TraversalOrder {
	preorder
	postorder
}

pub enum CSSRuleListNested {
	no
	yes
}

pub enum CSSStyleSheetLoadingState {
	unloaded
	loading
	loaded
	error
}

pub fn css_style_sheet_loading_state_name(loading_state CSSStyleSheetLoadingState) string {
	return match loading_state {
		.unloaded { 'Unloaded' }
		.loading { 'Loading' }
		.loaded { 'Loaded' }
		.error { 'Error' }
	}
}

pub struct Selector {
pub mut:
	data_ &SelectorData = unsafe { nil }
}

pub struct SelectorList {
pub mut:
	selectors []Selector
}

pub fn (list SelectorList) len() int {
	return list.selectors.len
}

pub fn (list SelectorList) is_empty() bool {
	return list.selectors.len == 0
}

pub fn serialize_a_group_of_selectors(selectors SelectorList) string {
	mut serialized := []string{}
	for selector in selectors.selectors {
		selector_text := selector.serialize().trim_space()
		if selector_text.len == 0 {
			continue
		}
		serialized << selector_text
	}
	return serialized.join(', ')
}

pub struct CSSStyleProperty {
pub mut:
	name        string
	value       string
	important   bool
	style_value ?&dom.StyleValue
}

@[heap]
pub struct CSSStyleProperties {
pub mut:
	properties []CSSStyleProperty
	// CSSStyleProperties stores custom declarations as StyleProperty objects in
	// upstream, preserving the parsed UnresolvedStyleValue token graph and its
	// pointer identity through the cascade.
	custom_properties       map[string]StyleProperty
	parent_rule             ?&CSSRule
	computed                bool
	readonly                bool
	updating                bool
	owner_node              ?dom.AbstractElement
	typed_properties_cache_ ?[]StyleProperty
	// Bit 0 is present for normal declarations and bit 1 for !important ones.
	// It is populated together with typed_properties_cache_.
	typed_importance_mask_ u8
mut:
	deferred_declarations_ ?&DeferredStyleDeclaration
}

pub fn CSSStyleProperties.create() &CSSStyleProperties {
	return &CSSStyleProperties{
		custom_properties: map[string]StyleProperty{}
	}
}

pub fn (properties &CSSStyleProperties) length() int {
	properties.ensure_declarations_parsed()
	return properties.properties.len + properties.custom_properties.len
}

pub fn (properties &CSSStyleProperties) serialized() string {
	properties.ensure_declarations_parsed()
	return css_style_properties_serialized(properties)
}

pub fn (mut properties CSSStyleProperties) set_parent_rule(rule &CSSRule) {
	properties.parent_rule = rule
}

@[heap]
pub struct CSSOMStylePropertyMap {
pub mut:
	declaration &CSSStyleProperties = unsafe { nil }
}

pub fn CSSOMStylePropertyMap.create(declaration &CSSStyleProperties) &CSSOMStylePropertyMap {
	return &CSSOMStylePropertyMap{
		declaration: declaration
	}
}

@[heap]
pub struct CSSRuleList {
pub mut:
	rules             []&CSSRule
	owner_rule        ?&CSSRule
	owner_style_sheet ?&CSSStyleSheet
	on_change         ?fn ()
}

pub fn CSSRuleList.create(rules []&CSSRule) &CSSRuleList {
	mut rule_list := &CSSRuleList{}
	for rule in rules {
		rule_list.rules << rule
	}
	return rule_list
}

pub fn CSSRuleList.create_empty() &CSSRuleList {
	return CSSRuleList.create([]&CSSRule{})
}

pub fn (rule_list &CSSRuleList) item(index usize) ?&CSSRule {
	if index >= usize(rule_list.rules.len) {
		return none
	}
	return rule_list.rules[index]
}

pub fn (rule_list &CSSRuleList) length() int {
	return rule_list.rules.len
}

pub fn (mut rule_list CSSRuleList) set_owner_rule(owner_rule &CSSRule) {
	rule_list.owner_rule = owner_rule
	for mut rule in rule_list.rules {
		rule.set_parent_rule(owner_rule)
	}
}

pub fn (mut rule_list CSSRuleList) set_parent_style_sheet(parent_style_sheet ?&CSSStyleSheet) {
	rule_list.owner_style_sheet = parent_style_sheet
	for mut rule in rule_list.rules {
		rule.set_parent_style_sheet(parent_style_sheet)
	}
}

fn (rule_list &CSSRuleList) unload_font_rules(rules []&CSSRule) {
	if sheet := rule_list.owner_style_sheet {
		if document := sheet.owning_document() {
			style_computer := css_style_computer_for(document)
			mut font_computer := unsafe { &FontComputer(style_computer.font_computer_) }
			font_computer.unload_fonts_from_css_rules(rules)
			return
		}
	}
	disconnect_font_faces_in_css_rules(rules)
}

pub fn (mut rule_list CSSRuleList) set_rules(rules []&CSSRule) {
	rule_list.unload_font_rules(rule_list.rules)
	for mut old_rule in rule_list.rules {
		old_rule.set_parent_rule(none)
	}

	rule_list.rules = rules

	for mut rule in rule_list.rules {
		if owner_rule := rule_list.owner_rule {
			rule.set_parent_rule(owner_rule)
		} else if parent_style_sheet := rule_list.owner_style_sheet {
			rule.set_parent_style_sheet(parent_style_sheet)
		}
	}

	rule_list.did_change()
}

// AD-HOC: The spec doesn't include a declared_namespaces parameter, but Ladybird needs it to handle parsing of namespaced selectors.
// https://drafts.csswg.org/cssom/#insert-a-css-rule
pub fn (mut rule_list CSSRuleList) insert_a_css_rule_from_text(rule string, index u32, nested CSSRuleListNested, declared_namespaces map[string]bool) !u32 {
	// 3. Set new rule to the results of performing parse a CSS rule on argument rule.
	parsing_params := ParsingParams{
		rule_context: rule_list.rule_context()
		declared_namespaces: declared_namespaces.clone()
	}
	mut new_rule := parse_css_rule_with_params_and_nesting(parsing_params, rule, if nested == .yes {
		ParserNested.yes
	} else {
		ParserNested.no
	}) or {
		trimmed_rule := rule.trim_left(' \t\n\r\f')
		lower_rule := trimmed_rule.to_lower()
		if nested == .yes && (lower_rule.starts_with('@import')
			|| lower_rule.starts_with('@namespace')) {
			if top_level_rule := parse_css_rule_with_params(ParsingParams{
				declared_namespaces: declared_namespaces.clone()
			}, rule) {
				return rule_list.insert_a_css_rule(top_level_rule, index, nested, declared_namespaces)
			}
		}
		// 4. If new rule is a syntax error, and nested is set, perform the following substeps:
		if nested == .yes {
			// - Set declarations to the results of performing parse a CSS declaration block, on argument rule.
			declarations := parse_css_property_declaration_block_with_params(ParsingParams{
				rule_context: rule_list.rule_context()
				declared_namespaces: declared_namespaces.clone()
			}, rule)

			// - If declarations is empty, throw a SyntaxError exception.
			if declarations.length() == 0 {
				return error('SyntaxError: Unable to parse CSS declarations block')
			}

			// - Otherwise, set new rule to a new nested declarations rule with declarations as it contents.
			CSSRule.create_nested_declarations(declarations)
		} else {
			return error('SyntaxError: Unable to parse CSS rule')
		}
	}

	return rule_list.insert_a_css_rule(new_rule, index, nested, declared_namespaces)
}

// https://drafts.csswg.org/cssom/#insert-a-css-rule
pub fn (mut rule_list CSSRuleList) insert_a_css_rule(new_rule &CSSRule, index u32, nested CSSRuleListNested, declared_namespaces map[string]bool) !u32 {
	_ = declared_namespaces

	// 1. Set length to the number of items in list.
	length := rule_list.rules.len

	// 2. If index is greater than length, then throw an IndexSizeError exception.
	if int(index) > length {
		return error('IndexSizeError: CSS rule index out of bounds')
	}

	// 5. If new rule is a syntax error, throw a SyntaxError exception.
	// NB: A null rule cannot be passed to this V overload.

	// 6. If new rule cannot be inserted into list at the zero-indexed position index due to constraints specified by CSS, then throw a HierarchyRequestError exception. [CSS21]
	// "Any @import rules must precede all other valid at-rules and style rules in a style sheet
	// (ignoring @charset and @layer statement rules) and must not have any other valid at-rules
	// or style rules between it and previous @import rules, or else the @import rule is invalid."
	// https://drafts.csswg.org/css-cascade-5/#at-import
	//
	// "Any @namespace rules must follow all @charset and @import rules and precede all other
	// non-ignored at-rules and style rules in a style sheet.
	mut rule_is_disallowed := false
	match new_rule.type_ {
		.layer_statement {}
		.import_rule {
			rule_is_disallowed = rule_list.has_rule_of_type_other_than_specified_before_index([
				CSSRuleType.import_rule,
				.layer_statement,
			], index)
		}
		.namespace_rule {
			rule_is_disallowed = rule_list.has_rule_of_type_at_or_after_index(.import_rule, index)
				|| rule_list.has_rule_of_type_other_than_specified_before_index([
					CSSRuleType.import_rule,
					.namespace_rule,
					.layer_statement,
				], index)
		}
		else {
			rule_is_disallowed = rule_list.has_rule_of_type_at_or_after_index(.import_rule, index)
				|| rule_list.has_rule_of_type_at_or_after_index(.namespace_rule, index)
		}
	}

	// FIXME: There are more constraints that we should check here - Parser::is_valid_in_the_current_context is probably a good reference for that.
	if rule_is_disallowed || (nested == .yes && new_rule.type_ in [.import_rule, .namespace_rule]) {
		return error('HierarchyRequestError: Cannot insert rule at specified index')
	}

	// 7. If new rule is an @namespace at-rule, and list contains anything other than @import at-rules, and @namespace at-rules, throw an InvalidStateError exception.
	if new_rule.type_ == .namespace_rule {
		for existing_rule in rule_list.rules {
			if existing_rule.type_ !in [.import_rule, .namespace_rule] {
				return error('InvalidStateError: Cannot insert @namespace rule into a stylesheet with non-namespace/import rules')
			}
		}
	}

	// 8. Insert new rule into list at the zero-indexed position index.
	rule_list.rules.insert(int(index), new_rule)
	if owner_rule := rule_list.owner_rule {
		mut mutable_new_rule := unsafe { &CSSRule(new_rule) }
		mutable_new_rule.set_parent_rule(owner_rule)
	} else if parent_style_sheet := rule_list.owner_style_sheet {
		mut mutable_new_rule := unsafe { &CSSRule(new_rule) }
		mutable_new_rule.set_parent_style_sheet(parent_style_sheet)
	}

	// 9. Return index.
	rule_list.did_change()
	return index
}

// https://www.w3.org/TR/cssom/#remove-a-css-rule
pub fn (mut rule_list CSSRuleList) remove_a_css_rule(index u32) ! {
	// 1. Set length to the number of items in list.
	length := rule_list.rules.len

	// 2. If index is greater than or equal to length, then throw an IndexSizeError exception.
	if int(index) >= length {
		return error('IndexSizeError: CSS rule index out of bounds')
	}

	// 3. Set old rule to the indexth item in list.
	mut old_rule := rule_list.rules[index]

	// 4. If old rule is an @namespace at-rule, and list contains anything other than @import at-rules, and @namespace at-rules, throw an InvalidStateError exception.
	if old_rule.type_ == .namespace_rule {
		for rule in rule_list.rules {
			if rule.type_ != .import_rule && rule.type_ != .namespace_rule {
				return error('InvalidStateError: Cannot remove @namespace rule from a stylesheet with non-namespace/import rules')
			}
		}
	}

	// Disconnect every nested font rule before the removed subtree becomes unreachable.
	rule_list.unload_font_rules([old_rule])

	// 5. Remove rule old rule from list at the zero-indexed position index.
	rule_list.rules.delete(int(index))

	// 6. Set old rule's parent CSS rule and parent CSS style sheet to null.
	// NOTE: We set the parent stylesheet to null within set_parent_rule.
	old_rule.set_parent_rule(none)

	rule_list.did_change()
}

pub fn (rule_list &CSSRuleList) for_each_effective_rule(order TraversalOrder, callback fn (&CSSRule)) {
	for rule in rule_list.rules {
		if order == .preorder {
			callback(rule)
		}

		match rule.type_ {
			.import_rule {
				if loaded_style_sheet := rule.loaded_style_sheet {
					loaded_style_sheet.for_each_effective_rule(order, callback)
				}
			}
			.container_rule, .function_rule, .layer_block, .media, .page, .scope, .style, .supports {
				rule.for_each_effective_rule(order, callback)
			}
			.counter_style, .font_face, .font_feature_values, .function_declarations, .keyframe, .keyframes, .layer_statement, .margin, .namespace_rule, .nested_declarations, .property {
			}
		}

		if order == .postorder {
			callback(rule)
		}
	}
}

pub fn (rule_list &CSSRuleList) for_each_effective_rule_with_context(order TraversalOrder, context voidptr, callback fn (voidptr, &CSSRule)) {
	for rule in rule_list.rules {
		if order == .preorder {
			callback(context, rule)
		}

		match rule.type_ {
			.import_rule {
				if loaded_style_sheet := rule.loaded_style_sheet {
					loaded_style_sheet.for_each_effective_rule_with_context(order, context, callback)
				}
			}
			.container_rule, .function_rule, .layer_block, .media, .page, .scope, .style, .supports {
				rule.for_each_effective_rule_with_context(order, context, callback)
			}
			.counter_style, .font_face, .font_feature_values, .function_declarations, .keyframe, .keyframes, .layer_statement, .margin, .namespace_rule, .nested_declarations, .property {
			}
		}

		if order == .postorder {
			callback(context, rule)
		}
	}
}

// Returns whether the match state of any media queries changed after evaluation.
pub fn (mut rule_list CSSRuleList) evaluate_media_queries(document &dom.Document) bool {
	mut any_media_queries_changed_match_state := false

	for mut rule in rule_list.rules {
		match rule.type_ {
			.container_rule {
				if mut child_rules := rule.rules {
					if child_rules.evaluate_media_queries(document) {
						any_media_queries_changed_match_state = true
					}
				}
			}
			.import_rule {
				if mut loaded_style_sheet := rule.loaded_style_sheet {
					if loaded_style_sheet.evaluate_media_queries(document) {
						any_media_queries_changed_match_state = true
					}
				}
			}
			.layer_block {
				if mut child_rules := rule.rules {
					if child_rules.evaluate_media_queries(document) {
						any_media_queries_changed_match_state = true
					}
				}
			}
			.function_rule {
				if mut child_rules := rule.rules {
					if child_rules.evaluate_media_queries(document) {
						any_media_queries_changed_match_state = true
					}
				}
			}
			.media {
				was_first_evaluation := !rule.did_evaluate
				did_match := rule.condition_matches()
				now_matches := rule.evaluate_media(document)
				if !was_first_evaluation && did_match != now_matches {
					any_media_queries_changed_match_state = true
				}
				if now_matches {
					if mut child_rules := rule.rules {
						if child_rules.evaluate_media_queries(document) {
							any_media_queries_changed_match_state = true
						}
					}
				}
			}
			.supports {
				if rule.condition_matches() {
					if mut child_rules := rule.rules {
						if child_rules.evaluate_media_queries(document) {
							any_media_queries_changed_match_state = true
						}
					}
				}
			}
			.scope {
				if mut child_rules := rule.rules {
					if child_rules.evaluate_media_queries(document) {
						any_media_queries_changed_match_state = true
					}
				}
			}
			.style {
				if mut child_rules := rule.rules {
					if child_rules.evaluate_media_queries(document) {
						any_media_queries_changed_match_state = true
					}
				}
			}
			.counter_style, .font_face, .font_feature_values, .function_declarations, .keyframe, .keyframes, .layer_statement, .margin, .namespace_rule, .nested_declarations, .property, .page {
			}
		}
	}

	return any_media_queries_changed_match_state
}

fn (rule_list &CSSRuleList) rule_context() []RuleContext {
	mut context := []RuleContext{}
	mut current := rule_list.owner_rule
	for {
		rule := current or { break }
		context << rule_context_type_for_rule(rule.type_)
		current = rule.parent_rule
	}
	context.reverse_in_place()
	return context
}

fn (rule_list &CSSRuleList) has_rule_of_type_other_than_specified_before_index(types []CSSRuleType, index u32) bool {
	for i in 0 .. int(index) {
		if rule_list.rules[i].type_ !in types {
			return true
		}
	}
	return false
}

fn (rule_list &CSSRuleList) has_rule_of_type_at_or_after_index(type_ CSSRuleType, index u32) bool {
	for i in int(index) .. rule_list.rules.len {
		if rule_list.rules[i].type_ == type_ {
			return true
		}
	}
	return false
}

fn (mut rule_list CSSRuleList) did_change() {
	if on_change := rule_list.on_change {
		on_change()
	}
	if mut owner_rule := rule_list.owner_rule {
		owner_rule.clear_caches()
	}
	if mut sheet := rule_list.owner_style_sheet {
		sheet.recalculate_rule_caches()
	}
}

@[heap]
pub struct CSSRule {
pub mut:
	type_ CSSRuleType

	parent_rule                       ?&CSSRule
	parent_style_sheet                ?&CSSStyleSheet
	cached_layer_name                 ?string
	cached_parent_container_rule      ?&CSSRule
	parent_container_rule_cache_valid bool

	rules ?&CSSRuleList

	media                ?&MediaList
	did_evaluate         bool
	supports             ?&Supports
	container_conditions []ContainerRuleCondition

	url                string
	document           ?&dom.Document
	layer              ?string
	layer_internal     ?string
	loaded_style_sheet ?&CSSStyleSheet
	loading_state      CSSStyleSheetLoadingState = .unloaded

	namespace_uri string
	prefix        string

	selectors                    SelectorList
	cached_absolutized_selectors ?SelectorList
	scope_start_selectors        ?SelectorList
	scope_end_selectors          ?SelectorList
	cached_scope_start_selectors ?SelectorList
	cached_scope_end_selectors   ?SelectorList
	import_has_scope             bool
	declaration                  ?&CSSStyleProperties
	style_map_cache              ?&CSSOMStylePropertyMap

	keyframe_key                      ?Percentage
	layer_name_list                   []string
	page_selectors                    PageSelectorList
	page_descriptors                  ?&CSSPageDescriptors
	margin_name                       string
	property_rule_name                string
	property_rule_syntax              string
	property_rule_inherits            bool
	property_rule_initial_value       ?string
	property_rule_initial_style_value ?StyleValue
	function_name                     string
	function_parameters               []FunctionParameterInternal
	function_return_type              SyntaxNode
	function_descriptors              ?&CSSFunctionDescriptors

	font_face_rule           ?&CSSFontFaceRule
	font_feature_values_rule ?&CSSFontFeatureValuesRule
	counter_style_rule       ?&CSSCounterStyleRule
}

pub fn CSSRule.create(type_ CSSRuleType) &CSSRule {
	return &CSSRule{
		type_: type_
	}
}

pub fn CSSRule.create_grouping(type_ CSSRuleType, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create(type_)
	rule.rules = rules
	mut mutable_rules := unsafe { &CSSRuleList(rules) }
	mutable_rules.set_owner_rule(rule)
	return rule
}

pub fn CSSRule.create_media(media &MediaList, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.media, rules)
	rule.media = media
	mut mutable_media := unsafe { &MediaList(media) }
	mutable_media.set_associated_rule(rule)
	return rule
}

pub fn CSSRule.create_supports(supports &Supports, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.supports, rules)
	rule.supports = supports
	return rule
}

pub fn CSSRule.create_container(conditions []ContainerRuleCondition, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.container_rule, rules)
	rule.container_conditions = conditions.clone()
	return rule
}

pub fn CSSRule.create_scope(start_selectors ?SelectorList, end_selectors ?SelectorList, rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.scope, rules)
	rule.scope_start_selectors = start_selectors
	rule.scope_end_selectors = end_selectors
	return rule
}

pub fn CSSRule.create_function(rules &CSSRuleList, name string, parameters []FunctionParameterInternal, return_type SyntaxNode) &CSSRule {
	mut rule := CSSRule.create_grouping(.function_rule, rules)
	rule.function_name = name
	rule.function_parameters = parameters.clone()
	rule.function_return_type = return_type
	return rule
}

pub fn CSSRule.create_function_declarations(descriptors &CSSFunctionDescriptors) &CSSRule {
	mut rule := CSSRule.create(.function_declarations)
	rule.function_descriptors = descriptors
	mut mutable_descriptors := unsafe { &CSSFunctionDescriptors(descriptors) }
	mutable_descriptors.base.set_parent_rule(rule)
	return rule
}

pub fn CSSRule.create_import(url string, document ?&dom.Document, layer ?string, scope ?ImportScope, supports ?&Supports, media &MediaList) &CSSRule {
	mut rule := CSSRule.create(.import_rule)
	rule.url = url
	rule.document = document
	rule.layer = layer
	if import_scope := scope {
		rule.import_has_scope = true
		rule.scope_start_selectors = import_scope.start_selectors
		rule.scope_end_selectors = import_scope.end_selectors
	}
	rule.supports = supports
	rule.media = media
	mut mutable_media := unsafe { &MediaList(media) }
	mutable_media.set_associated_rule(rule)
	if layer_name := layer {
		if layer_name.len == 0 {
			rule.layer_internal = next_unique_anonymous_layer_name()
		} else {
			rule.layer_internal = layer_name
		}
	}
	return rule
}

pub fn CSSRule.create_namespace(prefix ?string, namespace_uri string) &CSSRule {
	return &CSSRule{
		type_: .namespace_rule
		namespace_uri: namespace_uri
		prefix: prefix or { '' }
	}
}

pub fn CSSRule.create_style(selectors SelectorList, declaration &CSSStyleProperties, nested_rules &CSSRuleList) &CSSRule {
	mut rule := CSSRule.create_grouping(.style, nested_rules)
	rule.selectors = selectors
	rule.declaration = declaration
	mut mutable_declaration := unsafe { &CSSStyleProperties(declaration) }
	mutable_declaration.set_parent_rule(rule)
	return rule
}

pub fn CSSRule.create_nested_declarations(declaration &CSSStyleProperties) &CSSRule {
	mut rule := CSSRule.create(.nested_declarations)
	rule.declaration = declaration
	mut mutable_declaration := unsafe { &CSSStyleProperties(declaration) }
	mutable_declaration.set_parent_rule(rule)
	return rule
}

pub fn (rule &CSSRule) type_for_bindings() u16 {
	return rule.type_.type_for_bindings()
}

// https://www.w3.org/TR/cssom/#dom-cssrule-csstext
pub fn (rule &CSSRule) css_text() string {
	// The cssText attribute must return a serialization of the CSS rule.
	return rule.serialized()
}

// https://www.w3.org/TR/cssom/#dom-cssrule-csstext
pub fn (mut rule CSSRule) set_css_text(text string) {
	_ = text
	// On setting the cssText attribute must do nothing.
}

pub fn (mut rule CSSRule) set_parent_rule(parent_rule ?&CSSRule) {
	rule.clear_caches()
	rule.parent_rule = parent_rule

	if parent := parent_rule {
		rule.set_parent_style_sheet(parent.parent_style_sheet)
	} else {
		rule.set_parent_style_sheet(none)
	}
	rule.clear_caches()
}

pub fn (mut rule CSSRule) set_parent_style_sheet(parent_style_sheet ?&CSSStyleSheet) {
	if rule.type_ == .import_rule {
		if mut old_parent_style_sheet := rule.parent_style_sheet {
			old_parent_style_sheet.remove_critical_subresource(rule)
		}
	}

	rule.clear_caches()
	rule.parent_style_sheet = parent_style_sheet
	if mut font_face_rule := rule.font_face_rule {
		font_face_rule.set_parent_style_sheet(parent_style_sheet)
	}
	if mut counter_style_rule := rule.counter_style_rule {
		counter_style_rule.set_parent_style_sheet(parent_style_sheet)
	}
	if declaration := rule.declaration {
		mut declaration_with_base := unsafe { &CSSStyleProperties(declaration) }
		mut base_url := ''
		if sheet := parent_style_sheet {
			if explicit_base_url := sheet.base_url {
				base_url = explicit_base_url
			} else if location := sheet.base.location {
				base_url = location
			}
		}
		declaration_with_base.set_rule_base_url(base_url)
	}
	rule.clear_caches()

	if rule.type_ == .import_rule {
		if mut parent := rule.parent_style_sheet {
			parent.add_critical_subresource(rule)
		}
		if mut loaded := rule.loaded_style_sheet {
			if parent := parent_style_sheet {
				for owner in parent.owning_documents_or_shadow_roots {
					loaded.add_owning_document_or_shadow_root(owner)
				}
			}
		}
		if rule.loading_state == .unloaded {
			if _ := parent_style_sheet {
				rule.fetch()
			}
		}
	}

	if child_rules := rule.rules {
		mut mutable_child_rules := unsafe { &CSSRuleList(child_rules) }
		mutable_child_rules.set_parent_style_sheet(parent_style_sheet)
	}

	if rule.type_ == .style {
		// This is annoying: Style values that request resources need to know their CSSStyleSheet in order to fetch them.
		if declaration := rule.declaration {
			mut mutable_declaration := unsafe { &CSSStyleProperties(declaration) }
			mutable_declaration.set_rule_resource_owner(parent_style_sheet)
		}
	}
}

pub fn (rule &CSSRule) dump(indent_levels int) string {
	mut builder := strings.new_builder(128)
	builder.write_string('${cssom_indent(indent_levels)}${rule.type_.class_name()}:\n')
	match rule.type_ {
		.media {
			if media := rule.media {
				builder.write_string(media.dump(indent_levels + 1))
			}
		}
		.supports {
			if supports := rule.supports {
				builder.write_string(supports.dump(indent_levels + 1))
			}
		}
		.container_rule {
			builder.write_string('${cssom_indent(indent_levels + 1)}Condition: ${rule.condition_text()}\n')
		}
		.import_rule {
			builder.write_string('${cssom_indent(indent_levels + 1)}Document URL: ${rule.url}\n')
			builder.write_string('${cssom_indent(indent_levels + 1)}Loading state: ${css_style_sheet_loading_state_name(rule.loading_state)}\n')
		}
		.namespace_rule {
			builder.write_string('${cssom_indent(indent_levels + 1)}Namespace: ${rule.namespace_uri}\n')
			if rule.prefix.len != 0 {
				builder.write_string('${cssom_indent(indent_levels + 1)}Prefix: ${rule.prefix}\n')
			}
		}
		.style {
			for selector in rule.selectors.selectors {
				builder.write_string('${cssom_indent(indent_levels + 1)}Selector: ${selector.serialize()}\n')
			}
		}
		else {}
	}

	if child_rules := rule.rules {
		builder.write_string('${cssom_indent(indent_levels + 1)}Rules (${child_rules.length()}):\n')
		for child_rule in child_rules.rules {
			builder.write_string(child_rule.dump(indent_levels + 2))
		}
	}
	return builder.str()
}

pub fn (mut rule CSSRule) clear_caches() {
	rule.cached_layer_name = none
	rule.cached_parent_container_rule = none
	rule.parent_container_rule_cache_valid = false
	if rule.type_ == .style {
		rule.cached_absolutized_selectors = none
	}
	if rule.type_ == .scope {
		rule.cached_scope_start_selectors = none
		rule.cached_scope_end_selectors = none
	}
	if child_rules := rule.rules {
		mut mutable_child_rules := unsafe { &CSSRuleList(child_rules) }
		for mut child_rule in mutable_child_rules.rules {
			child_rule.clear_caches()
		}
	}
}

pub fn (mut rule CSSRule) parent_layer_internal_qualified_name() string {
	if cached := rule.cached_layer_name {
		return cached
	}
	value := rule.parent_layer_internal_qualified_name_slow_case()
	rule.cached_layer_name = value
	return value
}

pub fn (rule &CSSRule) parent_layer_internal_qualified_name_slow_case() string {
	mut layer_names := []string{}
	mut current_rule := rule.parent_rule
	for {
		parent := current_rule or { break }
		match parent.type_ {
			.import_rule {
				// @import is only a parent to style sheets, not to rules directly. It's handled below this loop.
				break
			}
			.layer_block {
				if internal_name := parent.layer_internal {
					layer_names << internal_name
				}
			}
			else {
				// Ignore everything else
				// Note that LayerStatement cannot have child rules so we still ignore it here.
			}
		}

		current_rule = parent.parent_rule
	}

	// If this style sheet is owned by a rule, include its qualified layer name.
	if style_sheet := rule.parent_style_sheet {
		if owner_rule := style_sheet.owner_rule {
			if owner_rule.type_ == .import_rule {
				if layer_name := owner_rule.layer_internal {
					if owner_rule.matches() {
						layer_names << layer_name
						mut mutable_owner := unsafe { &CSSRule(owner_rule) }
						parent_qualified_layer_name :=
							mutable_owner.parent_layer_internal_qualified_name()
						if parent_qualified_layer_name.len != 0 {
							layer_names << parent_qualified_layer_name
						}
					}
				}
			}
		}
	}

	layer_names.reverse_in_place()
	return layer_names.join('.')
}

pub fn (rule &CSSRule) serialized() string {
	return match rule.type_ {
		.media {
			rule.serialized_media_rule()
		}
		.supports {
			rule.serialized_supports_rule()
		}
		.container_rule {
			rule.serialized_container_rule()
		}
		.import_rule {
			rule.serialized_import_rule()
		}
		.namespace_rule {
			rule.serialized_namespace_rule()
		}
		.style {
			rule.serialized_style_rule()
		}
		.layer_block {
			rule.serialized_layer_block_rule()
		}
		.layer_statement {
			rule.serialized_layer_statement_rule()
		}
		.keyframes {
			rule.serialized_keyframes_rule()
		}
		.keyframe {
			rule.serialized_keyframe_rule()
		}
		.font_face {
			rule.serialized_font_face_rule()
		}
		.font_feature_values {
			rule.serialized_font_feature_values_rule()
		}
		.counter_style {
			rule.serialized_counter_style_rule()
		}
		.page {
			rule.serialized_page_rule()
		}
		.margin {
			rule.serialized_margin_rule()
		}
		.property {
			rule.serialized_property_rule()
		}
		.scope {
			rule.serialized_scope_rule()
		}
		.function_rule {
			rule.serialized_function_rule()
		}
		.function_declarations {
			if descriptors := rule.function_descriptors {
				descriptors.base.serialized()
			} else {
				''
			}
		}
		.nested_declarations {
			if declaration := rule.declaration {
				declaration.serialized()
			} else {
				''
			}
		}
	}
}

pub fn (rule &CSSRule) css_rules() ?&CSSRuleList {
	return rule.rules
}

pub fn (rule &CSSRule) scope_start() ?string {
	selectors := rule.scope_start_selectors or { return none }
	return serialize_a_group_of_selectors(selectors)
}

pub fn (rule &CSSRule) scope_end() ?string {
	selectors := rule.scope_end_selectors or { return none }
	return serialize_a_group_of_selectors(selectors)
}

pub fn (rule &CSSRule) parent_scope_rule() ?&CSSRule {
	mut current_parent := rule.parent_rule
	for {
		parent := current_parent or { break }
		if parent.type_ == .scope {
			return parent
		}
		current_parent = parent.parent_rule
	}
	mut current_style_sheet := rule.parent_style_sheet
	for {
		style_sheet := current_style_sheet or { break }
		owner_rule := style_sheet.owner_rule or { break }
		if owner_rule.has_scope() {
			return owner_rule
		}
		current_parent = owner_rule.parent_rule
		for {
			parent := current_parent or { break }
			if parent.type_ == .scope {
				return parent
			}
			current_parent = parent.parent_rule
		}
		current_style_sheet = owner_rule.parent_style_sheet
	}
	return none
}

pub fn (mut rule CSSRule) scope_start_selectors_for_matching() ?SelectorList {
	selectors := rule.scope_start_selectors or { return none }
	if cached := rule.cached_scope_start_selectors {
		return cached
	}
	matching_selectors := absolutize_selectors_relative_to(selectors, rule.parent_rule)
	rule.cached_scope_start_selectors = matching_selectors
	return matching_selectors
}

pub fn (mut rule CSSRule) scope_end_selectors_for_matching() ?SelectorList {
	selectors := rule.scope_end_selectors or { return none }
	if cached := rule.cached_scope_end_selectors {
		return cached
	}
	mut matching_selectors := SelectorList{}
	for selector in selectors.selectors {
		compound_selectors := selector.compound_selectors()
		if compound_selectors.len == 0 {
			continue
		}
		first_combinator := compound_selectors[0].combinator
		if first_combinator !in [.no_combinator, .descendant] || (!selector.contains_the_nesting_selector()
			&& !selector.contains_pseudo_class(.scope)) {
			matching_selectors.selectors << selector.relative_to(SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{
					type_: .scope
				}))
		} else if first_combinator == .descendant {
			mut copied := compound_selectors.clone()
			copied[0].combinator = .no_combinator
			matching_selectors.selectors << selector_from_compound_selectors(copied)
		} else {
			matching_selectors.selectors << selector
		}
	}
	rule.cached_scope_end_selectors = matching_selectors
	return matching_selectors
}

fn (rule &CSSRule) serialized_scope_rule() string {
	mut builder := strings.new_builder(128)
	builder.write_string('@scope')
	if start := rule.scope_start() {
		builder.write_string(' (${start})')
	}
	if end := rule.scope_end() {
		builder.write_string(' to (${end})')
	}
	builder.write_string(' {\n')
	if rules := rule.rules {
		for child_rule in rules.rules {
			result := child_rule.css_text()
			if result.len == 0 {
				continue
			}
			builder.write_string('  ${result}\n')
		}
	}
	builder.write_u8(`}`)
	return builder.str()
}

// https://drafts.csswg.org/cssom/#dom-cssgroupingrule-insertrule
pub fn (mut rule CSSRule) insert_rule(rule_text string, index u32) !u32 {
	if mut rules := rule.rules {
		parent_sheet := rule.parent_style_sheet or {
			return error('InvalidStateError: Grouping rule has no parent stylesheet')
		}

		// The insertRule(rule, index) method must return the result of invoking insert a CSS rule rule into the child CSS
		// rules at index, with the nested flag set.
		result := rules.insert_a_css_rule_from_text(rule_text, index, .yes, parent_sheet.declared_namespaces())!

		mut mutable_parent_sheet := unsafe { &CSSStyleSheet(parent_sheet) }
		mutable_parent_sheet.invalidate_owners(.style_sheet_insert_rule)
		mutable_parent_sheet.synchronize_fonts_after_rule_change()
		return result
	}
	return error('InvalidStateError: Rule has no child rule list')
}

pub fn (mut rule CSSRule) delete_rule(index u32) ! {
	if mut rules := rule.rules {
		rules.remove_a_css_rule(index)!
		if mut parent_sheet := rule.parent_style_sheet {
			parent_sheet.invalidate_owners(.style_sheet_delete_rule)
			parent_sheet.synchronize_fonts_after_rule_change()
		}
		return
	}
	return error('InvalidStateError: Rule has no child rule list')
}

pub fn (rule &CSSRule) for_each_effective_rule(order TraversalOrder, callback fn (&CSSRule)) {
	if rule.type_ in [.media, .supports] && !rule.condition_matches() {
		return
	}
	if rules := rule.rules {
		rules.for_each_effective_rule(order, callback)
	}
}

pub fn (rule &CSSRule) for_each_effective_rule_with_context(order TraversalOrder, context voidptr, callback fn (voidptr, &CSSRule)) {
	if rule.type_ in [.media, .supports] && !rule.condition_matches() {
		return
	}
	if rules := rule.rules {
		rules.for_each_effective_rule_with_context(order, context, callback)
	}
}

pub fn (rule &CSSRule) condition_text() string {
	return match rule.type_ {
		.media {
			if media := rule.media {
				media.media_text()
			} else {
				''
			}
		}
		.supports {
			if supports := rule.supports {
				supports.to_string()
			} else {
				''
			}
		}
		.container_rule { rule.container_condition_text() }
		else {
			''
		}
	}
}

pub fn (rule &CSSRule) condition_matches() bool {
	return match rule.type_ {
		.media {
			if media := rule.media {
				media.matches()
			} else {
				true
			}
		}
		.supports {
			if supports := rule.supports {
				supports.matches_condition()
			} else {
				false
			}
		}
		.container_rule { false }
		else {
			true
		}
	}
}

pub fn (mut rule CSSRule) evaluate_media(document &dom.Document) bool {
	rule.did_evaluate = true
	if mut media := rule.media {
		return media.evaluate(document)
	}
	return true
}

// https://www.w3.org/TR/cssom-1/#serialize-a-css-rule
fn (rule &CSSRule) serialized_media_rule() string {
	// The result of concatenating the following:
	mut builder := strings.new_builder(128)

	// 1. The string "@media", followed by a single SPACE (U+0020).
	builder.write_string('@media ')
	// 2. The result of performing serialize a media query list on rule's media query list.
	builder.write_string(rule.condition_text())
	// 3. A single SPACE (U+0020), followed by the string "{", i.e., LEFT CURLY BRACKET (U+007B), followed by a newline.
	builder.write_string(' {\n')
	// 4. The result of performing serialize a CSS rule on each rule in the rule's cssRules list,
	//    filtering out empty strings, indenting each item with two spaces, all joined with newline.
	if rules := rule.rules {
		for i in 0 .. rules.length() {
			child_rule := rules.item(usize(i)) or { continue }
			result := child_rule.css_text()

			if result.len == 0 {
				continue
			}

			builder.write_string('  ')
			builder.write_string(result)
			builder.write_u8(`\n`)
		}
	}
	// 5. A newline, followed by the string "}", i.e., RIGHT CURLY BRACKET (U+007D)
	// AD-HOC: All modern browsers omit the ending newline if there are no CSS rules, so let's do the same.
	//         If there are rules, the required newline will be appended in the for-loop above.
	builder.write_u8(`}`)

	return builder.str()
}

// https://www.w3.org/TR/cssom-1/#serialize-a-css-rule
fn (rule &CSSRule) serialized_supports_rule() string {
	// Note: The spec doesn't cover this yet, so I'm roughly following the spec for the @media rule.
	// It should be pretty close!
	mut builder := strings.new_builder(128)

	builder.write_string('@supports ')
	builder.write_string(rule.condition_text())
	builder.write_string(' {\n')
	if rules := rule.rules {
		for i in 0 .. rules.length() {
			child_rule := rules.item(usize(i)) or { continue }
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

// https://www.w3.org/TR/cssom/#serialize-a-css-rule
fn (rule &CSSRule) serialized_import_rule() string {
	mut builder := strings.new_builder(128)

	// The result of concatenating the following:

	// 1. The string "@import" followed by a single SPACE (U+0020).
	builder.write_string('@import ')

	// 2. The result of performing serialize a URL on the rule's location.
	//    "To serialize a URL means to create a string represented by "url(",
	//    followed by the serialization of the URL as a string, followed by ")"."
	builder.write_string(serialize_a_url(rule.url))

	// AD-HOC: Serialize the rule's layer if it exists.
	if layer := rule.layer {
		if layer.len == 0 {
			builder.write_string(' layer')
		} else {
			builder.write_string(' layer(${layer})')
		}
	}

	// AD-HOC: Serialize the rule's import scope if it exists.
	if rule.import_has_scope {
		builder.write_string(' scope')
		if rule.scope_start_selectors != none || rule.scope_end_selectors != none {
			builder.write_u8(`(`)
			if start := rule.scope_start() {
				if rule.scope_end_selectors != none {
					builder.write_string('(${start})')
				} else {
					builder.write_string(start)
				}
			}
			if end := rule.scope_end() {
				if rule.scope_start_selectors != none {
					builder.write_u8(` `)
				}
				builder.write_string('to (${end})')
			}
			builder.write_u8(`)`)
		}
	}

	// AD-HOC: Serialize the rule's supports condition if it exists.
	//         This isn't currently specified, but major browsers include this in their serialization of import rules.
	if supports := rule.supports {
		builder.write_string(' supports(${supports.to_string()})')
	}

	// 3. If the rule's associated media list is not empty, a single SPACE (U+0020) followed by the result of performing serialize a media query list on the media list.
	if media := rule.media {
		if media.length() != 0 {
			builder.write_string(' ${media.media_text()}')
		}
	}

	// 4. The string ";", i.e., SEMICOLON (U+003B).
	builder.write_u8(`;`)

	return builder.str()
}

// https://drafts.csswg.org/css-cascade-4/#fetch-an-import
pub fn (mut rule CSSRule) fetch() {
	// To fetch an @import, given an @import rule rule:

	// 1. Let parentStylesheet be rule's parent CSS style sheet. [CSSOM]
	if rule.parent_style_sheet == none {
		return
	}

	// 2. If rule has a <supports-condition>, and that condition is not true, return.
	if supports := rule.supports {
		if !supports.matches_condition() {
			return
		}
	}

	rule.set_loading_state(.loading)

	// Boundary: Fetch/style-resource integration is outside this V port. Keep the observable loading transition explicit.
	if loaded_style_sheet := rule.loaded_style_sheet {
		rule.set_loading_state(loaded_style_sheet.loading_state())
		return
	}
	rule.set_loading_state(.loaded)
}

pub fn (mut rule CSSRule) set_style_sheet(style_sheet &CSSStyleSheet) {
	rule.loaded_style_sheet = style_sheet
	mut mutable_style_sheet := unsafe { &CSSStyleSheet(style_sheet) }
	mutable_style_sheet.set_owner_css_rule(rule)

	if parent_style_sheet := rule.parent_style_sheet {
		for owner in parent_style_sheet.owning_documents_or_shadow_roots {
			mutable_style_sheet.add_owning_document_or_shadow_root(owner)
		}
	}

	if document := mutable_style_sheet.owning_document() {
		mutable_style_sheet.load_pending_image_resources(document)
	}

	mutable_style_sheet.invalidate_owners(dom.StyleInvalidationReason.style_change)
	rule.set_loading_state(mutable_style_sheet.loading_state())
}

// https://drafts.csswg.org/cssom/#dom-cssimportrule-media
pub fn (rule &CSSRule) import_media() ?&MediaList {
	// The media attribute must return the value of the media attribute of the associated CSS style sheet.
	// AD-HOC: Return our own MediaList.
	//         https://github.com/w3c/csswg-drafts/issues/12063
	return rule.media
}

// https://drafts.csswg.org/cssom/#dom-cssimportrule-layername
pub fn (rule &CSSRule) layer_name() ?string {
	// The layerName attribute must return the layer name declared in the at-rule itself, or an empty string if the
	// layer is anonymous, or null if the at-rule does not declare a layer.
	return rule.layer
}

// https://drafts.csswg.org/cssom/#dom-cssimportrule-supportstext
pub fn (rule &CSSRule) supports_text() ?string {
	// The supportsText attribute must return the <supports-condition> declared in the at-rule itself, or null if the
	// at-rule does not declare a supports condition.
	if supports := rule.supports {
		return supports.to_string()
	}
	return none
}

pub struct ImportScope {
pub mut:
	start_selectors ?SelectorList
	end_selectors   ?SelectorList
}

pub fn (rule &CSSRule) has_scope() bool {
	return rule.type_ == .import_rule && rule.import_has_scope
}

pub fn (rule &CSSRule) import_scope_start_selectors() ?SelectorList {
	if !rule.has_scope() {
		return none
	}
	return rule.scope_start_selectors
}

pub fn (rule &CSSRule) import_scope_end_selectors() ?SelectorList {
	if !rule.has_scope() {
		return none
	}
	return rule.scope_end_selectors
}

pub fn (mut rule CSSRule) internal_qualified_layer_name() ?string {
	if rule.layer == none {
		return none
	}

	parent_name := rule.parent_layer_internal_qualified_name()
	internal := rule.layer_internal or { return none }
	if parent_name.len == 0 {
		return internal
	}
	return '${parent_name}.${internal}'
}

pub fn (rule &CSSRule) matches() bool {
	if supports := rule.supports {
		if !supports.matches_condition() {
			return false
		}
	}
	if media := rule.media {
		return media.matches()
	}
	return true
}

// https://www.w3.org/TR/cssom/#serialize-a-css-rule
fn (rule &CSSRule) serialized_namespace_rule() string {
	mut builder := strings.new_builder(64)
	// The literal string "@namespace", followed by a single SPACE (U+0020),
	builder.write_string('@namespace ')

	// followed by the serialization as an identifier of the prefix attribute (if any),
	if rule.prefix.len != 0 {
		builder.write_string(serialize_an_identifier(rule.prefix))
		// followed by a single SPACE (U+0020) if there is a prefix,
		builder.write_u8(` `)
	}

	//  followed by the serialization as URL of the namespaceURI attribute,
	builder.write_string(serialize_a_url(rule.namespace_uri))

	// followed the character ";" (U+003B).
	builder.write_u8(`;`)

	return builder.str()
}

// https://drafts.csswg.org/cssom-1/#dom-cssstylerule-style
pub fn (rule &CSSRule) style() ?&CSSStyleProperties {
	declaration := rule.declaration or { return none }
	declaration.ensure_declarations_parsed()
	return declaration
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssstylerule-stylemap
pub fn (mut rule CSSRule) style_map() ?&CSSOMStylePropertyMap {
	if rule.style_map_cache == none {
		if declaration := rule.style() {
			rule.style_map_cache = CSSOMStylePropertyMap.create(declaration)
		}
	}
	return rule.style_map_cache
}

// https://drafts.csswg.org/cssom-1/#serialize-a-css-rule
fn (rule &CSSRule) serialized_style_rule() string {
	mut builder := strings.new_builder(128)

	// 1. Let s initially be the result of performing serialize a group of selectors on the rule's associated selectors,
	//    followed by the string " {", i.e., a single SPACE (U+0020), followed by LEFT CURLY BRACKET (U+007B).
	builder.write_string(serialize_a_group_of_selectors(rule.selectors))
	builder.write_string(' {')

	// 2. Let decls be the result of performing serialize a CSS declaration block on the rule's associated declarations,
	//    or null if there are no such declarations.
	mut decls := ?string(none)
	if declaration := rule.declaration {
		if declaration.length() > 0 {
			decls = declaration.serialized()
		}
	}

	// 3. Let rules be the result of performing serialize a CSS rule on each rule in the rule's cssRules list,
	//    or null if there are no such rules.
	mut rules := []string{}
	if child_rules := rule.rules {
		for child_rule in child_rules.rules {
			rules << child_rule.serialized()
		}
	}

	// 4. If decls and rules are both null, append " }" to s (i.e. a single SPACE (U+0020) followed by RIGHT CURLY BRACKET (U+007D)) and return s.
	if decls == none && rules.len == 0 {
		builder.write_string(' }')
		return builder.str()
	}

	// 5. If rules is null:
	if rules.len == 0 {
		// 1. Append a single SPACE (U+0020) to s
		builder.write_u8(` `)
		// 2. Append decls to s
		if declarations := decls {
			builder.write_string(declarations)
		}
		// 3. Append " }" to s (i.e. a single SPACE (U+0020) followed by RIGHT CURLY BRACKET (U+007D)).
		builder.write_string(' }')
		// 4. Return s.
		return builder.str()
	}

	// 6. Otherwise:
	// 1. If decls is not null, prepend it to rules.
	if declarations := decls {
		rules.prepend(declarations)
	}

	// 2. For each rule in rules:
	for child_rule in rules {
		// * If rule is the empty string, do nothing.
		if child_rule.len == 0 {
			continue
		}

		// * Otherwise:
		// 1. Append a newline followed by two spaces to s.
		// 2. Append rule to s.
		builder.write_string('\n  ${child_rule}')
	}

	// 3. Append a newline followed by RIGHT CURLY BRACKET (U+007D) to s.
	builder.write_string('\n}')

	// 4. Return s.
	return builder.str()
}

// https://drafts.csswg.org/cssom-1/#dom-cssstylerule-selectortext
pub fn (rule &CSSRule) selector_text() string {
	// The selectorText attribute, on getting, must return the result of serializing the associated group of selectors.
	return serialize_a_group_of_selectors(rule.selectors)
}

// https://drafts.csswg.org/cssom-1/#dom-cssstylerule-selectortext
pub fn (mut rule CSSRule) set_selector_text(selector_text string) {
	rule.clear_caches()

	// 1. Run the parse a group of selectors algorithm on the given value.
	mut declared_namespaces := map[string]bool{}
	if parent_style_sheet := rule.parent_style_sheet {
		declared_namespaces = parent_style_sheet.declared_namespaces()
	}

	mut parsed_selectors := ?SelectorList(none)
	if nesting_parent := rule.nesting_parent_rule() {
		// AD-HOC: If we're a nested style rule, then we need to parse the selector as relative and then adapt it with implicit &s.
		parsed_selectors = parse_selector_for_nested_style_rule_with_parser(selector_text, declared_namespaces, if nesting_parent.type_ == .scope {
			StyleNestingParent.scope
		} else {
			StyleNestingParent.style
		})
	} else {
		parsed_selectors = parse_selector_with_parser(selector_text, declared_namespaces)
	}

	// 2. If the algorithm returns a non-null value replace the associated group of selectors with the returned value.
	if selectors := parsed_selectors {
		// NOTE: If we have a parent style rule, we need to update the selectors to add any implicit `&`s
		rule.selectors = selectors
		if mut sheet := rule.parent_style_sheet {
			sheet.invalidate_owners(dom.StyleInvalidationReason.style_change)
		}
	}

	// 3. Otherwise, if the algorithm returns a null value, do nothing.
}

fn absolutize_selectors_relative_to(selectors SelectorList, parent ?&CSSRule) SelectorList {
	parent_is_scope_rule := if parent_rule := parent {
		parent_rule.type_ == .scope
	} else {
		false
	}
	mut requires_absolutization := false
	for selector in selectors.selectors {
		compound_selectors := selector.compound_selectors()
		selector_is_scope_relative := parent_is_scope_rule && compound_selectors.len != 0
			&& compound_selectors[0].combinator !in [.no_combinator, .descendant]
		if selector.contains_the_nesting_selector() || selector_is_scope_relative {
			requires_absolutization = true
			break
		}
	}
	if !requires_absolutization {
		return selectors
	}

	parent_rule := parent or {
		// A top-level nesting selector is matched like :scope, without changing its specificity.
		return selectors
	}
	mut selector_for_nesting := SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{
			type_: .where
			argument_selector_list: SelectorList{
				selectors: [selector_from_text(':scope')]
			}
		})
	if parent_rule.type_ == .style {
		mut mutable_parent := unsafe { &CSSRule(parent_rule) }
		selector_for_nesting = SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{
				type_: .is_
				argument_selector_list: mutable_parent.absolutized_selectors()
			})
	}

	mut absolutized_selectors := SelectorList{}
	for selector in selectors.selectors {
		compound_selectors := selector.compound_selectors()
		if !selector.contains_the_nesting_selector() && parent_rule.type_ == .scope
			&& compound_selectors.len != 0
			&& compound_selectors[0].combinator !in [.no_combinator, .descendant] {
			absolutized_selectors.selectors << selector.relative_to(selector_for_nesting)
			continue
		}
		if absolutized := selector.absolutized(selector_for_nesting) {
			absolutized_selectors.selectors << absolutized
		}
	}
	return absolutized_selectors
}

pub fn (mut rule CSSRule) absolutized_selectors() SelectorList {
	if cached := rule.cached_absolutized_selectors {
		return cached
	}
	absolutized_selectors := absolutize_selectors_relative_to(rule.selectors, rule.nesting_parent_rule())
	rule.cached_absolutized_selectors = absolutized_selectors
	return absolutized_selectors
}

pub fn (rule &CSSRule) parent_style_rule() ?&CSSRule {
	mut current_parent := rule.parent_rule
	for {
		parent := current_parent or { break }
		if parent.type_ == .style {
			return parent
		}
		current_parent = parent.parent_rule
	}
	return none
}

pub fn (rule &CSSRule) nesting_parent_rule() ?&CSSRule {
	mut current_parent := rule.parent_rule
	for {
		parent := current_parent or { break }
		if parent.type_ == .style || parent.type_ == .scope {
			return parent
		}
		current_parent = parent.parent_rule
	}
	return none
}

pub fn (mut rule CSSRule) qualified_layer_name() string {
	return rule.parent_layer_internal_qualified_name()
}

pub struct StyleSheet {
pub mut:
	media              &MediaList = unsafe { nil }
	owner_node         ?&dom.Element
	parent_style_sheet ?&CSSStyleSheet
	location           ?string
	title              string
	type_string        string
	disabled           bool
	alternate          bool
	origin_clean       bool = true
}

pub fn StyleSheet.create(media &MediaList) StyleSheet {
	return StyleSheet{
		media: media
		origin_clean: true
	}
}

pub fn (sheet &StyleSheet) href() ?string {
	if location := sheet.location {
		return location
	}
	return none
}

pub fn (mut sheet StyleSheet) set_owner_node(element ?&dom.Element) {
	sheet.owner_node = element
}

pub fn (mut sheet StyleSheet) set_parent_css_style_sheet(parent ?&CSSStyleSheet) {
	sheet.parent_style_sheet = parent
}

// https://drafts.csswg.org/cssom/#dom-stylesheet-title
pub fn (sheet &StyleSheet) title_for_bindings() ?string {
	// The title attribute must return the title or null if title is the empty string.
	if sheet.title.len == 0 {
		return none
	}

	return sheet.title
}

@[heap]
pub struct CSSStyleSheet {
pub mut:
	base StyleSheet

	rules &CSSRuleList = unsafe { nil }

	default_namespace_rule ?&CSSRule
	namespace_rules        map[string]&CSSRule
	import_rules           []&CSSRule

	owner_rule ?&CSSRule

	base_url                                    ?string
	constructor_document                        ?&dom.Document
	owning_documents_or_shadow_roots            []&dom.Node
	constructed                                 bool
	disallow_modification                       bool
	did_match                                   ?bool
	shared_single_constructed_sheet_style_cache ?&StyleCache

	critical_subresources   []&CSSRule
	pending_image_values    []&dom.StyleValue
	associated_font_loaders []&FontLoader
	source_text_            ?string
mut:
	shared_style_cache_revision_ u64
}

pub struct CSSStyleSheetInit {
pub mut:
	base_url   ?string
	media      string
	media_list ?&MediaList
	disabled   bool
}

pub fn CSSStyleSheet.create(rules &CSSRuleList, media &MediaList, location ?string) &CSSStyleSheet {
	mut sheet := &CSSStyleSheet{
		base: StyleSheet.create(media)
		rules: rules
		namespace_rules: map[string]&CSSRule{}
	}
	sheet.base.location = location
	mut mutable_media := unsafe { &MediaList(media) }
	mutable_media.set_associated_style_sheet(sheet)

	mut mutable_rules := unsafe { &CSSRuleList(rules) }
	mutable_rules.set_parent_style_sheet(sheet)

	sheet.recalculate_rule_caches()
	return sheet
}

// https://drafts.csswg.org/cssom/#dom-cssstylesheet-cssstylesheet
pub fn css_style_sheet_construct(options ?CSSStyleSheetInit, associated_document ?&dom.Document) !&CSSStyleSheet {
	// 1. Construct a new CSSStyleSheet object sheet.
	mut sheet := CSSStyleSheet.create(CSSRuleList.create_empty(), MediaList.create_empty(), none)

	// 2. Set sheet's location to the base URL of the associated Document for the current principal global object.
	if document := associated_document {
		sheet.base.location = document.base_url().to_string()
	}

	// 3. Set sheet's stylesheet base URL to the baseURL attribute value from options.
	if init := options {
		if base_url := init.base_url {
			if base_url.len == 0 {
				return error('NotAllowedError: Constructed style sheets must have a valid base URL')
			}
			parsed_base_url := if location := sheet.base.location {
				dom.dom_url_parse(base_url, dom.URL{
					value: location
				}, 'utf-8')
			} else {
				dom.dom_url_parse(base_url, dom.URL{
					value: ''
				}, 'utf-8')
			}
			resolved_base_url := parsed_base_url or {
				return error('NotAllowedError: Constructed style sheets must have a valid base URL')
			}

			sheet.base_url = resolved_base_url.to_string()
		}
	}

	// 4. Set sheet's parent CSS style sheet to null.
	sheet.set_parent_css_style_sheet(none)

	// 5. Set sheet's owner node to null.
	sheet.set_owner_node(none)

	// 6. Set sheet's owner CSS rule to null.
	sheet.set_owner_css_rule(none)

	// 7. Set sheet's title to the empty string.
	sheet.base.title = ''

	// 8. Unset sheet's alternate flag.
	sheet.base.alternate = false

	// 9. Set sheet's origin-clean flag.
	sheet.base.origin_clean = true

	// 10. Set sheet's constructed flag.
	sheet.constructed = true

	// 11. Set sheet's Constructor document to the associated Document for the current global object.
	sheet.constructor_document = associated_document

	// 12. If the media attribute of options is a string, create a MediaList object from the string and assign it as sheet's media.
	//     Otherwise, serialize a media query list from the attribute and then create a MediaList object from the resulting string and set it as sheet's media.
	if init := options {
		if media_list := init.media_list {
			sheet.base.media = media_list
			mut mutable_media_list := unsafe { &MediaList(media_list) }
			mutable_media_list.set_associated_style_sheet(sheet)
		} else {
			sheet.set_media(init.media)
		}
		// 13. If the disabled attribute of options is true, set sheet's disabled flag.
		if init.disabled {
			sheet.base.disabled = true
		}
	}

	// 14. Return sheet
	return sheet
}

pub fn (sheet &CSSStyleSheet) type_() string {
	return 'text/css'
}

pub fn (sheet &CSSStyleSheet) css_rules() &CSSRuleList {
	return sheet.rules
}

pub fn (sheet &CSSStyleSheet) href() ?string {
	return sheet.base.href()
}

pub fn (mut sheet CSSStyleSheet) set_owner_node(element ?&dom.Element) {
	sheet.base.set_owner_node(element)
}

pub fn (mut sheet CSSStyleSheet) set_parent_css_style_sheet(parent ?&CSSStyleSheet) {
	sheet.base.set_parent_css_style_sheet(parent)
}

pub fn (mut sheet CSSStyleSheet) set_owner_css_rule(rule ?&CSSRule) {
	sheet.owner_rule = rule
}

pub fn (mut sheet CSSStyleSheet) set_media(media string) {
	mut media_list := unsafe { &MediaList(sheet.base.media) }
	media_list.set_media_text(media)
}

pub fn (sheet &CSSStyleSheet) make_parsing_params() ParsingParams {
	if document := sheet.owning_document() {
		return ParsingParams{
			document: document
			declared_namespaces: sheet.declared_namespaces()
		}
	}
	return ParsingParams{
		declared_namespaces: sheet.declared_namespaces()
	}
}

// https://www.w3.org/TR/cssom/#dom-cssstylesheet-insertrule
pub fn (mut sheet CSSStyleSheet) insert_rule(rule string, index u32) !u32 {
	// FIXME: 1. If the origin-clean flag is unset, throw a SecurityError exception.

	// If the disallow modification flag is set, throw a NotAllowedError DOMException.
	if sheet.disallow_modification {
		return error("NotAllowedError: Can't call insert_rule() on non-modifiable stylesheets")
	}

	// 3. Let parsed rule be the return value of invoking parse a rule with rule.
	mut parsed_rule := parse_css_rule_with_params(sheet.make_parsing_params(), rule) or {
		// 4. If parsed rule is a syntax error, return parsed rule.
		return error('SyntaxError: Unable to parse CSS rule')
	}

	// 5. If parsed rule is an @import rule, and the constructed flag is set, throw a SyntaxError DOMException.
	if sheet.constructed && parsed_rule.type_ == .import_rule {
		return error("SyntaxError: Can't insert @import rules into a constructed stylesheet")
	}

	// 6. Return the result of invoking insert a CSS rule rule in the CSS rules at index.
	result := sheet.rules.insert_a_css_rule(parsed_rule, index, .no, sheet.declared_namespaces())!

	// NOTE: The spec doesn't say where to set the parent style sheet, so Ladybird does it here.
	parsed_rule.set_parent_style_sheet(sheet)

	owner_is_inline_style := if owner := sheet.base.owner_node {
		owner.as_node().is_html_style_element()
	} else {
		false
	}
	if !sheet.constructed && owner_is_inline_style && parsed_rule.type_ == .keyframes {
		invalidate_owners_for_inserted_keyframes_rule(mut sheet, parsed_rule)
	} else if !sheet.constructed && owner_is_inline_style && parsed_rule.type_ == .style {
		invalidate_owners_for_inserted_style_rule(mut sheet, parsed_rule, .style_sheet_insert_rule)
	} else {
		sheet.invalidate_owners(.style_sheet_insert_rule)
	}
	sheet.synchronize_fonts_after_rule_change()
	return result
}

// https://www.w3.org/TR/cssom/#dom-cssstylesheet-deleterule
pub fn (mut sheet CSSStyleSheet) delete_rule(index u32) ! {
	// FIXME: 1. If the origin-clean flag is unset, throw a SecurityError exception.

	// 2. If the disallow modification flag is set, throw a NotAllowedError DOMException.
	if sheet.disallow_modification {
		return error("NotAllowedError: Can't call delete_rule() on non-modifiable stylesheets")
	}

	// 3. Remove a CSS rule in the CSS rules at index.
	previous_sheet_effects := determine_shadow_root_style_sheet_effects_for_style_sheet(sheet)
	sheet.rules.remove_a_css_rule(index)!
	sheet.invalidate_owners_with_previous_effects(.style_sheet_delete_rule, previous_sheet_effects)
	sheet.synchronize_fonts_after_rule_change()
}

// https://drafts.csswg.org/cssom/#dom-cssstylesheet-replace
pub fn (mut sheet CSSStyleSheet) replace(text string) !&CSSStyleSheet {
	// Boundary: Promise/parallel execution is a JS integration point. This V port performs the same rule replacement synchronously.
	if !sheet.constructed {
		return error("NotAllowedError: Can't call replace() on non-constructed stylesheets")
	}

	if sheet.disallow_modification {
		return error("NotAllowedError: Can't call replace() on non-modifiable stylesheets")
	}

	sheet.disallow_modification = true
	previous_sheet_effects := determine_shadow_root_style_sheet_effects_for_style_sheet(sheet)
	rules := parse_css_stylesheet_contents_with_params(sheet.make_parsing_params(), text)
	mut rules_without_import := []&CSSRule{}
	for parsed_rule in rules {
		if parsed_rule.type_ != .import_rule {
			rules_without_import << parsed_rule
		}
	}
	for mut parsed_rule in rules_without_import {
		parsed_rule.set_parent_style_sheet(sheet)
	}
	sheet.rules.set_rules(rules_without_import)
	sheet.invalidate_owners_with_previous_effects(.style_sheet_replace, previous_sheet_effects)
	sheet.synchronize_fonts_after_rule_change()
	sheet.disallow_modification = false
	return sheet
}

// https://drafts.csswg.org/cssom/#dom-cssstylesheet-replacesync
pub fn (mut sheet CSSStyleSheet) replace_sync(text string) ! {
	// 1. If the constructed flag is not set, or the disallow modification flag is set, throw a NotAllowedError exception.
	if !sheet.constructed {
		return error("NotAllowedError: Can't call replaceSync() on non-constructed stylesheets")
	}
	if sheet.disallow_modification {
		return error("NotAllowedError: Can't call replaceSync() on non-modifiable stylesheets")
	}

	// 2. Let rules be the result of running parse a stylesheet's contents from text.
	previous_sheet_effects := determine_shadow_root_style_sheet_effects_for_style_sheet(sheet)
	rules := parse_css_stylesheet_contents_with_params(sheet.make_parsing_params(), text)

	// 3. If rules contains one or more @import rules, remove those rules from rules.
	mut rules_without_import := []&CSSRule{}
	for parsed_rule in rules {
		if parsed_rule.type_ != .import_rule {
			rules_without_import << parsed_rule
		}
	}

	// NOTE: The spec doesn't say where to set the parent style sheet, so Ladybird does it here.
	for mut parsed_rule in rules_without_import {
		parsed_rule.set_parent_style_sheet(sheet)
	}

	// 4. Set sheet's CSS rules to rules.
	sheet.rules.set_rules(rules_without_import)
	sheet.invalidate_owners_with_previous_effects(.style_sheet_replace, previous_sheet_effects)
	sheet.synchronize_fonts_after_rule_change()
}

// https://drafts.csswg.org/cssom/#dom-cssstylesheet-addrule
pub fn (mut sheet CSSStyleSheet) add_rule(selector ?string, style ?string, index ?u32) !int {
	// 1. Let rule be an empty string.
	mut rule := strings.new_builder(64)

	// 2. Append selector to rule.
	if selector_value := selector {
		rule.write_string(selector_value)
	}

	// 3. Append " { " to rule.
	rule.write_u8(`{`)

	// 4. If block is not empty, append block, followed by a space, to rule.
	if style_value := style {
		if style_value.len != 0 {
			rule.write_string('${style_value} ')
		}
	}

	// 5. Append "}" to rule.
	rule.write_u8(`}`)

	// 6. Let index be optionalIndex if provided, or the number of CSS rules in the stylesheet otherwise.
	// 7. Call insertRule(), with rule and index as arguments.
	sheet.insert_rule(rule.str(), index or { u32(sheet.rules.length()) })!

	// 8. Return -1.
	return -1
}

// https://www.w3.org/TR/cssom/#dom-cssstylesheet-removerule
pub fn (mut sheet CSSStyleSheet) remove_rule(index ?u32) ! {
	// The removeRule(index) method must run the same steps as deleteRule().
	return sheet.delete_rule(index or { u32(0) })
}

pub fn (sheet &CSSStyleSheet) for_each_effective_rule(order TraversalOrder, callback fn (&CSSRule)) {
	if sheet.base.media.matches() {
		sheet.rules.for_each_effective_rule(order, callback)
	}
}

pub fn (sheet &CSSStyleSheet) for_each_effective_rule_with_context(order TraversalOrder, context voidptr, callback fn (voidptr, &CSSRule)) {
	if sheet.base.media.matches() {
		sheet.rules.for_each_effective_rule_with_context(order, context, callback)
	}
}

struct EffectiveRuleCallbackContext {
	callback fn (&CSSRule)
	type_ CSSRuleType
	include_nested_declarations bool
}

fn invoke_filtered_effective_rule(context voidptr, rule &CSSRule) {
	state := unsafe { &EffectiveRuleCallbackContext(context) }
	if rule.type_ == state.type_
		|| (state.include_nested_declarations && rule.type_ == .nested_declarations) {
		state.callback(rule)
	}
}

pub fn (sheet &CSSStyleSheet) for_each_effective_style_producing_rule(callback fn (&CSSRule)) {
	context := EffectiveRuleCallbackContext{
		callback: callback
		type_: .style
		include_nested_declarations: true
	}
	sheet.for_each_effective_rule_with_context(.preorder, voidptr(&context), invoke_filtered_effective_rule)
}

pub fn (sheet &CSSStyleSheet) for_each_effective_keyframes_at_rule(callback fn (&CSSRule)) {
	context := EffectiveRuleCallbackContext{
		callback: callback
		type_: .keyframes
		include_nested_declarations: false
	}
	sheet.for_each_effective_rule_with_context(.preorder, voidptr(&context), invoke_filtered_effective_rule)
}

pub fn (sheet &CSSStyleSheet) for_each_effective_counter_style_at_rule(callback fn (&CSSRule)) {
	context := EffectiveRuleCallbackContext{
		callback: callback
		type_: .counter_style
		include_nested_declarations: false
	}
	sheet.for_each_effective_rule_with_context(.preorder, voidptr(&context), invoke_filtered_effective_rule)
}

pub fn (sheet &CSSStyleSheet) for_each_effective_property_at_rule(callback fn (&CSSRule)) {
	context := EffectiveRuleCallbackContext{
		callback: callback
		type_: .property
		include_nested_declarations: false
	}
	sheet.for_each_effective_rule_with_context(.preorder, voidptr(&context), invoke_filtered_effective_rule)
}

pub fn (sheet &CSSStyleSheet) registered_properties_from_css_property_rules() map[string]CustomPropertyRegistration {
	mut registered_properties := map[string]CustomPropertyRegistration{}
	registered_properties_ptr := &registered_properties
	sheet.for_each_effective_property_at_rule(fn [registered_properties_ptr] (rule &CSSRule) {
		unsafe {
			mut registrations := *registered_properties_ptr
			registrations[rule.property_rule_name()] = rule.property_rule_to_registration()
			*registered_properties_ptr = registrations
		}
	})
	return registered_properties
}

pub fn (mut sheet CSSStyleSheet) add_owning_document_or_shadow_root(document_or_shadow_root &dom.Node) {
	for existing in sheet.owning_documents_or_shadow_roots {
		if existing == document_or_shadow_root {
			return
		}
	}
	sheet.owning_documents_or_shadow_roots << document_or_shadow_root

	// All owning documents or shadow roots must be part of the same document, so activate fonts only when the first
	// owner is added. Disabled sheets delay activation until they are enabled.
	if !sheet.base.disabled && sheet.owning_documents_or_shadow_roots.len == 1 {
		sheet.load_fonts_for_document(document_or_shadow_root.document())
	}

	for import_rule in sheet.import_rules {
		if mut loaded_style_sheet := import_rule.loaded_style_sheet {
			loaded_style_sheet.add_owning_document_or_shadow_root(document_or_shadow_root)
		}
	}
}

pub fn (mut sheet CSSStyleSheet) remove_owning_document_or_shadow_root(document_or_shadow_root &dom.Node) {
	document := document_or_shadow_root.document()
	mut kept := []&dom.Node{}
	for existing in sheet.owning_documents_or_shadow_roots {
		if existing != document_or_shadow_root {
			kept << existing
		}
	}
	sheet.owning_documents_or_shadow_roots = kept

	// All owning documents or shadow roots must be part of the same document so Ladybird only unloads this style
	// sheet's fonts once none remain.
	if sheet.owning_documents_or_shadow_roots.len == 0 {
		sheet.unload_fonts_for_document(document)
	}

	for import_rule in sheet.import_rules {
		if mut loaded_style_sheet := import_rule.loaded_style_sheet {
			loaded_style_sheet.remove_owning_document_or_shadow_root(document_or_shadow_root)
		}
	}
}

pub fn (mut sheet CSSStyleSheet) invalidate_owners(reason dom.StyleInvalidationReason) {
	sheet.invalidate_owners_with_previous_effects(reason, none)
}

pub enum ShouldInvalidateRuleCache {
	no
	yes
}

fn apply_style_sheet_shadow_root_effects(host &dom.Element, shadow_root &dom.ShadowRoot, effects ShadowRootStylesheetEffects, reason dom.StyleInvalidationReason) bool {
	if effects.may_match_light_dom_outside_shadow_host {
		mut host_root := unsafe { &dom.Node(host.as_node().root()) }
		host_root.invalidate_style(reason)
	} else if effects.may_match_light_dom_under_shadow_host {
		mut host_node := host.as_node()
		host_node.invalidate_style(reason)
	} else if effects.may_affect_assigned_nodes_via_slots {
		mut host_node := host.as_node()
		host_node.invalidate_style(reason)
	} else if effects.may_match_shadow_host {
		mut host_node := host.as_node()
		host_node.invalidate_style(reason)
		mut shadow_node := unsafe { &dom.Node(shadow_root) }
		shadow_node.set_needs_style_update(true)
	} else {
		return false
	}
	return true
}

fn (mut sheet CSSStyleSheet) invalidate_owners_with_previous_effects(reason dom.StyleInvalidationReason, previous_sheet_effects ?ShadowRootStylesheetEffects) {
	sheet.did_match = none
	sheet.invalidate_shared_style_cache()
	// MediaList mutation changes which rules are effective. Refresh that state before
	// owner invalidation inspects the new shadow-root effects or rebuilds a rule cache.
	if document := sheet.owning_document() {
		sheet.evaluate_media_queries(document)
	}
	invalidate_style_for_style_sheet_owners(sheet, reason, .yes, previous_sheet_effects)
}

pub fn (mut sheet CSSStyleSheet) shared_single_constructed_sheet_style_cache(mut style_scope StyleScope) &StyleCache {
	assert sheet.constructed
	if cache := sheet.shared_single_constructed_sheet_style_cache {
		return cache
	}
	cache := style_scope.populate_new_rule_cache()
	sheet.shared_single_constructed_sheet_style_cache = cache
	return cache
}

pub fn (mut sheet CSSStyleSheet) invalidate_shared_style_cache() {
	sheet.shared_style_cache_revision_++
	sheet.shared_single_constructed_sheet_style_cache = none
}

fn invalidate_style_for_style_sheet_owners(sheet &CSSStyleSheet, reason dom.StyleInvalidationReason, should_invalidate_rule_cache ShouldInvalidateRuleCache, previous_sheet_effects ?ShadowRootStylesheetEffects) {
	for owner in sheet.owning_documents_or_shadow_roots {
		mut scope := css_style_scope_for_node(owner)
		if should_invalidate_rule_cache == .yes {
			scope.invalidate_rule_cache()
		}
		scope_owner := scope.node_ref() or { continue }
		mut mutable_owner := unsafe { &dom.Node(scope_owner) }
		mutable_owner.invalidate_style(reason)

		shadow_root := scope_owner.as_shadow_root() or { continue }
		invalidate_assigned_elements_for_dirty_style_sheet_slots(shadow_root)
		host := shadow_root.host() or { continue }
		effects := determine_shadow_root_style_sheet_effects(shadow_root)
		if !apply_style_sheet_shadow_root_effects(host, shadow_root, effects, reason) {
			if previous := previous_sheet_effects {
				apply_style_sheet_shadow_root_effects(host, shadow_root, previous, reason)
			}
		}
	}
}

pub fn (sheet &CSSStyleSheet) for_each_owning_style_scope(callback fn (&StyleScope)) {
	for owner in sheet.owning_documents_or_shadow_roots {
		callback(css_style_scope_for_node(owner))
	}
}

pub fn (mut sheet CSSStyleSheet) set_disabled(disabled bool) {
	if sheet.base.disabled == disabled {
		return
	}
	previous_sheet_effects := determine_shadow_root_style_sheet_effects_for_style_sheet(sheet)
	document := sheet.owning_document()
	sheet.did_match = none
	sheet.base.set_disabled(disabled)
	if !disabled {
		if owner_document := document {
			sheet.evaluate_media_queries(owner_document)
			sheet.load_fonts_for_document(owner_document)
			sheet.load_pending_image_resources(owner_document)
		}
	} else if owner_document := document {
		sheet.unload_fonts_for_document(owner_document)
	}
	sheet.invalidate_owners_with_previous_effects(.style_sheet_disabled_state_change, previous_sheet_effects)
}

fn (mut sheet CSSStyleSheet) load_fonts_for_document(document &dom.Document) {
	style_computer := css_style_computer_for(document)
	mut font_computer := unsafe { &FontComputer(style_computer.font_computer_) }
	font_computer.synchronize_fonts_from_css_rules(sheet.rules.rules, style_computer.font_face_set_,
		!sheet.base.disabled && sheet.base.media.matches())
	synchronize_font_face_order_for_document(document, style_computer)
}

fn (mut sheet CSSStyleSheet) unload_fonts_for_document(document &dom.Document) {
	style_computer := css_style_computer_for(document)
	mut font_computer := unsafe { &FontComputer(style_computer.font_computer_) }
	font_computer.unload_fonts_from_css_rules(sheet.rules.rules)
}

fn (mut sheet CSSStyleSheet) synchronize_fonts_after_rule_change() {
	document := sheet.owning_document() or { return }
	sheet.load_fonts_for_document(document)
}

fn synchronize_font_face_order_for_document(document &dom.Document, style_computer &StyleComputer) {
	mut ordered_faces := []&FontFaceObject{}
	ordered_faces_ptr := &ordered_faces
	scope := css_style_scope_for_node(unsafe { &dom.Node(document) })
	scope.for_each_active_css_style_sheet(fn [ordered_faces_ptr] (active_sheet &CSSStyleSheet) {
		active_sheet.for_each_effective_rule(.preorder, fn [ordered_faces_ptr] (rule &CSSRule) {
			font_rule := rule.font_face_rule_ref() or { return }
			face := font_rule.css_connected_font_face_ref() or { return }
			unsafe {
				mut collected := *ordered_faces_ptr
				if !font_face_object_array_contains(collected, face) {
					collected << face
				}
				*ordered_faces_ptr = collected
			}
		})
	})
	mut font_face_set := unsafe { &FontFaceSet(style_computer.font_face_set_) }
	font_face_set.synchronize_css_connected_font_order(ordered_faces)
}

pub fn (sheet &CSSStyleSheet) owning_document() ?&dom.Document {
	if sheet.owning_documents_or_shadow_roots.len != 0 {
		return sheet.owning_documents_or_shadow_roots[0].document()
	}

	if owner_node := sheet.base.owner_node {
		return owner_node.document()
	}

	return none
}

pub fn (mut sheet CSSStyleSheet) register_pending_image_value(value &dom.StyleValue) {
	sheet.pending_image_values << value
}

pub fn (mut sheet CSSStyleSheet) add_associated_font_loader(font_loader &FontLoader) {
	sheet.associated_font_loaders << font_loader
}

pub fn (sheet &CSSStyleSheet) has_associated_font_loader(font_loader &FontLoader) bool {
	for loader in sheet.associated_font_loaders {
		if loader == font_loader {
			return true
		}
	}
	return false
}

pub fn (mut sheet CSSStyleSheet) load_pending_image_resources(document &dom.Document) {
	_ = document
	if sheet.base.disabled {
		return
	}
	// Boundary: ImageStyleValue::load_any_resources requires DOM/Fetch resource loading.
	sheet.pending_image_values.clear()
}

// Returns whether the match state of any media queries changed after evaluation.
pub fn (mut sheet CSSStyleSheet) evaluate_media_queries(document &dom.Document) bool {
	mut any_media_queries_changed_match_state := false

	mut media := unsafe { &MediaList(sheet.base.media) }
	now_matches := media.evaluate(document)
	if previous_match := sheet.did_match {
		if previous_match != now_matches {
			any_media_queries_changed_match_state = true
		}
	}
	if now_matches && sheet.rules.evaluate_media_queries(document) {
		any_media_queries_changed_match_state = true
	}

	sheet.did_match = now_matches
	if any_media_queries_changed_match_state {
		sheet.invalidate_shared_style_cache()
		sheet.synchronize_fonts_after_rule_change()
	}

	return any_media_queries_changed_match_state
}

pub fn (sheet &CSSStyleSheet) default_namespace() ?string {
	if namespace_rule := sheet.default_namespace_rule {
		return namespace_rule.namespace_uri
	}

	return none
}

pub fn (sheet &CSSStyleSheet) declared_namespaces() map[string]bool {
	mut declared_namespaces := map[string]bool{}

	for namespace_, _ in sheet.namespace_rules {
		declared_namespaces[namespace_] = true
	}

	return declared_namespaces
}

pub fn (sheet &CSSStyleSheet) namespace_uri(namespace_prefix string) ?string {
	if namespace_rule := sheet.namespace_rules[namespace_prefix] {
		return namespace_rule.namespace_uri
	}
	return none
}

pub fn (mut sheet CSSStyleSheet) recalculate_rule_caches() {
	sheet.invalidate_shared_style_cache()
	sheet.default_namespace_rule = none
	sheet.namespace_rules.clear()
	sheet.import_rules.clear()

	for rule in sheet.rules.rules {
		// "Any @import rules must precede all other valid at-rules and style rules in a style sheet
		// (ignoring @charset and @layer statement rules) and must not have any other valid at-rules
		// or style rules between it and previous @import rules, or else the @import rule is invalid."
		// https://drafts.csswg.org/css-cascade-5/#at-import
		//
		// "Any @namespace rules must follow all @charset and @import rules and precede all other
		// non-ignored at-rules and style rules in a style sheet.
		// ...
		// A syntactically invalid @namespace rule (whether malformed or misplaced) must be ignored."
		// https://drafts.csswg.org/css-namespaces/#syntax
		match rule.type_ {
			.import_rule {
				// @import rules must appear before @namespace rules, so skip this if we've seen @namespace.
				if sheet.namespace_rules.len != 0 {
					continue
				}
				sheet.import_rules << rule
			}
			.namespace_rule {
				if rule.namespace_uri.len != 0 && rule.prefix.len == 0 {
					sheet.default_namespace_rule = rule
				}

				sheet.namespace_rules[rule.prefix] = rule
			}
			else {
				// Any other types mean that further @namespace rules are invalid, so we can stop here.
				return
			}
		}
	}
}

pub fn (mut sheet CSSStyleSheet) set_source_text(source string) {
	sheet.source_text_ = source
}

pub fn (sheet &CSSStyleSheet) source_text() ?string {
	return sheet.source_text_
}

pub fn (mut sheet CSSStyleSheet) add_critical_subresource(subresource &CSSRule) {
	for existing in sheet.critical_subresources {
		if existing == subresource {
			return
		}
	}
	sheet.critical_subresources << subresource
}

pub fn (mut sheet CSSStyleSheet) remove_critical_subresource(subresource &CSSRule) {
	for index, existing in sheet.critical_subresources {
		if existing == subresource {
			sheet.critical_subresources.delete(index)
			break
		}
	}
	sheet.check_if_loading_completed()
}

pub fn (sheet &CSSStyleSheet) loading_state() CSSStyleSheetLoadingState {
	mut any_loading := false
	mut any_errors := false

	for subresource in sheet.critical_subresources {
		match subresource.loading_state {
			.unloaded, .loading {
				any_loading = true
			}
			.loaded {}
			.error {
				any_errors = true
			}
		}
	}

	if any_loading {
		return .loading
	}

	if any_errors {
		return .error
	}

	return .loaded
}

pub fn (mut sheet CSSStyleSheet) check_if_loading_completed() {
	state := sheet.loading_state()
	if state == .loaded || state == .error {
		// We're finished loading, so propagate that to our owner.
		if mut import_rule := sheet.owner_rule {
			if import_rule.type_ == .import_rule {
				import_rule.set_loading_state(state)
			}
		}
		// Boundary: StyleElementBase/HTMLLinkElement load completion callbacks require HTML owner nodes.
	}
}

pub fn (mut rule CSSRule) set_loading_state(loading_state CSSStyleSheetLoadingState) {
	rule.loading_state = loading_state
	if loading_state == .loaded || loading_state == .error {
		if mut parent := rule.parent_style_sheet {
			parent.check_if_loading_completed()
		}
	}
}

pub enum StyleSheetListAlternate {
	no
	yes
}

pub enum StyleSheetListOriginClean {
	no
	yes
}

@[heap]
pub struct StyleSheetList {
pub mut:
	document_or_shadow_root &dom.Node = unsafe { nil }
	sheets                  []&CSSStyleSheet

	// https://www.w3.org/TR/cssom/#preferred-css-style-sheet-set-name
	preferred_css_style_sheet_set_name string
	// https://www.w3.org/TR/cssom/#last-css-style-sheet-set-name
	last_css_style_sheet_set_name ?string
}

pub fn StyleSheetList.create(document_or_shadow_root &dom.Node) &StyleSheetList {
	return &StyleSheetList{
		document_or_shadow_root: document_or_shadow_root
	}
}

// https://www.w3.org/TR/cssom/#remove-a-css-style-sheet
pub fn (mut list StyleSheetList) remove_a_css_style_sheet(mut sheet CSSStyleSheet) {
	// 1. Remove the CSS style sheet from the list of document or shadow root CSS style sheets.
	list.remove_sheet(sheet)

	// 2. Set the CSS style sheet's parent CSS style sheet, owner node and owner CSS rule to null.
	sheet.set_parent_css_style_sheet(none)
	sheet.set_owner_node(none)
	sheet.set_owner_css_rule(none)
}

// https://www.w3.org/TR/cssom/#add-a-css-style-sheet
pub fn (mut list StyleSheetList) add_a_css_style_sheet(mut sheet CSSStyleSheet) {
	// 1. Add the CSS style sheet to the list of document or shadow root CSS style sheets at the appropriate location. The remainder of these steps deal with the disabled flag.
	list.add_sheet(sheet)

	// 2. If the disabled flag is set, then return.
	if sheet.base.disabled {
		return
	}

	// 3. If the title is not the empty string, the alternate flag is unset, and preferred CSS style sheet set name is the empty string change the preferred CSS style sheet set name to the title.
	if sheet.base.title.len != 0 && !sheet.base.alternate
		&& list.preferred_css_style_sheet_set_name.len == 0 {
		list.preferred_css_style_sheet_set_name = sheet.base.title
	}

	// 4. If any of the following is true, then unset the disabled flag and return:
	//    - The title is the empty string.
	//    - The last CSS style sheet set name is null and the title is a case-sensitive match for the preferred CSS style sheet set name.
	//    - The title is a case-sensitive match for the last CSS style sheet set name.
	// NOTE: We don't enable alternate sheets with an empty title.  This isn't directly mentioned in the algorithm steps, but the
	// HTML specification says that the title element must be specified with a non-empty value for alternative style sheets.
	// See: https://html.spec.whatwg.org/multipage/links.html#the-link-is-an-alternative-stylesheet
	if (sheet.base.title.len == 0 && !sheet.base.alternate)
		|| (sheet.base.title.len != 0
		&& ((list.last_css_style_sheet_set_name == none
		&& sheet.base.title.to_lower() == list.preferred_css_style_sheet_set_name.to_lower())
		|| (list.last_css_style_sheet_set_name != none
		&& sheet.base.title.to_lower() == (list.last_css_style_sheet_set_name or {
			''
		}).to_lower()))) {
		sheet.base.disabled = false
		return
	}

	// 5. Set the disabled flag.
	sheet.base.disabled = true
}

// https://www.w3.org/TR/cssom/#create-a-css-style-sheet
pub fn (mut list StyleSheetList) create_a_css_style_sheet(css_text string, type_ string, owner_node ?&dom.Element, media string, title string, alternate StyleSheetListAlternate, origin_clean StyleSheetListOriginClean, location ?string, parent_style_sheet ?&CSSStyleSheet, owner_rule ?&CSSRule) &CSSStyleSheet {
	// 1. Create a new CSS style sheet object and set its properties as specified.
	// AD-HOC: The spec never tells us when to parse this style sheet, but the most logical place is here.
	mut sheet := parse_css_stylesheet_with_parser(css_text, location)
	sheet.base.type_string = type_
	list.initialize_a_css_style_sheet(mut sheet, owner_node, media, title, alternate, origin_clean,
		parent_style_sheet, owner_rule)
	return sheet
}

pub fn (mut list StyleSheetList) initialize_a_css_style_sheet(mut sheet CSSStyleSheet, owner_node ?&dom.Element, media string, title string, alternate StyleSheetListAlternate, origin_clean StyleSheetListOriginClean, parent_style_sheet ?&CSSStyleSheet, owner_rule ?&CSSRule) {
	sheet.set_parent_css_style_sheet(parent_style_sheet)
	sheet.set_owner_css_rule(owner_rule)
	sheet.set_owner_node(owner_node)
	sheet.set_media(media)
	sheet.base.title = title
	sheet.base.alternate = alternate == .yes
	sheet.base.origin_clean = origin_clean == .yes

	// 2. Then run the add a CSS style sheet steps for the newly created CSS style sheet.
	list.add_a_css_style_sheet(mut sheet)
}

pub fn (list &StyleSheetList) item(index usize) ?&CSSStyleSheet {
	if index >= usize(list.sheets.len) {
		return none
	}
	return list.sheets[index]
}

pub fn (list &StyleSheetList) length() int {
	return list.sheets.len
}

pub fn (list &StyleSheetList) document() &dom.Document {
	return list.document_or_shadow_root.document()
}

struct StyleSheetInvalidationRuleCollection {
mut:
	rules []&CSSRule
}

fn collect_style_sheet_invalidation_rules(context voidptr, rule &CSSRule) {
	if rule.type_ !in [.style, .nested_declarations] { return }
	mut collection := unsafe { &StyleSheetInvalidationRuleCollection(context) }
	collection.rules << rule
}

fn build_invalidation_set_for_stylesheet(sheet &CSSStyleSheet) StyleSheetInvalidationSet {
	mut result := StyleSheetInvalidationSet{}
	mut collection := StyleSheetInvalidationRuleCollection{}
	sheet.for_each_effective_rule_with_context(.preorder, voidptr(&collection), collect_style_sheet_invalidation_rules)

	for rule in collection.rules {
		if result.invalidation_set.needs_invalidate_whole_subtree() {
			break
		}
		if rule.type_ == .style {
			extend_style_sheet_invalidation_set_with_style_rule(mut result, rule)
		}
	}
	return result
}

fn rule_requires_broad_add_or_remove_invalidation(rule &CSSRule) bool {
	// @font-face declares a resource whose effect on computed style is deferred until the font
	// actually loads. CSSFontLoaded handles that invalidation, so adding or removing the rule itself
	// does not require a whole-subtree style update.
	// @keyframes only affects elements that reference its animation name; the sheet add/remove paths
	// apply targeted invalidation for those elements after processing ordinary style rules.
	return rule.type_ in [.property, .font_feature_values, .counter_style, .layer_block,
		.layer_statement]
}

fn stylesheet_requires_broad_add_or_remove_invalidation(sheet &CSSStyleSheet) bool {
	mut requires_broad_invalidation := false
	requires_broad_invalidation_ptr := &requires_broad_invalidation
	sheet.for_each_effective_rule(.preorder, fn [requires_broad_invalidation_ptr] (rule &CSSRule) {
		unsafe {
			if *requires_broad_invalidation_ptr {
				return
			}
			*requires_broad_invalidation_ptr = rule_requires_broad_add_or_remove_invalidation(rule)
		}
	})
	return requires_broad_invalidation
}

fn (mut list StyleSheetList) add_sheet(sheet &CSSStyleSheet) {
	mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
	mutable_sheet.add_owning_document_or_shadow_root(list.document_or_shadow_root)

	mutable_sheet.load_pending_image_resources(list.document())

	list.insert_sheet_in_tree_order(sheet)

	// NOTE: We evaluate media queries immediately when adding a new sheet.
	//       This coalesces the full document style invalidations.
	//       If we don't do this, we invalidate now, and then again when Document updates media rules.
	mutable_sheet.evaluate_media_queries(list.document())

	if mutable_sheet.rules.length() == 0 {
		// NOTE: If the added sheet has no rules, we don't have to invalidate anything.
		return
	}

	invalidate_css_style_scope_for_node(list.document_or_shadow_root)
	if !list.document_or_shadow_root.is_shadow_root()
		&& list.document_or_shadow_root.entire_subtree_needs_style_update() {
		return
	}

	mut invalidation_result := build_invalidation_set_for_stylesheet(sheet)
	requires_broad_invalidation := invalidation_result.invalidation_set.needs_invalidate_whole_subtree()
		|| stylesheet_requires_broad_add_or_remove_invalidation(sheet)
	if requires_broad_invalidation {
		if shadow_root := list.document_or_shadow_root.as_shadow_root() {
			effects := determine_shadow_root_style_sheet_effects(shadow_root)
			invalidation_result.may_match_shadow_host = invalidation_result.may_match_shadow_host
				|| effects.may_match_shadow_host
			invalidation_result.may_match_light_dom_under_shadow_host = invalidation_result.may_match_light_dom_under_shadow_host
				|| effects.may_match_light_dom_under_shadow_host
			invalidation_result.may_match_light_dom_outside_shadow_host = invalidation_result.may_match_light_dom_outside_shadow_host
				|| effects.may_match_light_dom_outside_shadow_host
		}
	}
	invalidate_root_for_style_sheet_change(list.document_or_shadow_root, invalidation_result, .style_sheet_list_add_sheet, requires_broad_invalidation)
	invalidate_root_for_keyframes_rules_in_sheet(list.document_or_shadow_root, sheet)
}

fn (mut list StyleSheetList) insert_sheet_in_tree_order(sheet &CSSStyleSheet) {
	if list.sheets.len == 0 {
		// This is the first sheet, append it to the list.
		list.sheets << sheet
	} else {
		// We have sheets from before. Insert the new sheet in the correct position (DOM tree order).
		mut did_insert := false
		if owner_node := sheet.base.owner_node {
			for i := list.sheets.len - 1; i >= 0; i-- {
				existing_sheet := list.sheets[i]
				existing_owner_node := existing_sheet.base.owner_node or { continue }
				position :=
					existing_owner_node.as_node().compare_document_position(owner_node.as_node())
				if position & dom.document_position_following != 0 {
					list.sheets.insert(i + 1, sheet)
					did_insert = true
					break
				}
			}
		}
		if !did_insert {
			list.sheets.insert(0, sheet)
		}
	}
}

// StyleScope::move_sheet(). Upstream reorders a sheet that stays in the same scope without detaching it from the
// StyleEngine; V has no StyleEngine, so both cases take the remove/add path whose invalidation restyles the
// elements the sheet's rules can reach at their old and new cascade positions.
pub fn (mut list StyleSheetList) move_sheet(sheet &CSSStyleSheet, mut destination StyleSheetList) {
	list.remove_sheet(sheet)
	destination.add_sheet(sheet)
}

fn (mut list StyleSheetList) remove_sheet(sheet &CSSStyleSheet) {
	mut invalidation_result := build_invalidation_set_for_stylesheet(sheet)
	requires_broad_invalidation := invalidation_result.invalidation_set.needs_invalidate_whole_subtree()
		|| stylesheet_requires_broad_add_or_remove_invalidation(sheet)

	mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
	mutable_sheet.remove_owning_document_or_shadow_root(list.document_or_shadow_root)
	mut did_remove := false
	mut kept := []&CSSStyleSheet{}
	for existing in list.sheets {
		if existing == sheet {
			did_remove = true
			continue
		}
		kept << existing
	}
	list.sheets = kept
	if !did_remove {
		return
	}

	if mutable_sheet.rules.length() == 0 {
		// NOTE: If the removed sheet had no rules, we don't have to invalidate anything.
		return
	}

	invalidate_css_style_scope_for_node(list.document_or_shadow_root)
	if !list.document_or_shadow_root.is_shadow_root()
		&& list.document_or_shadow_root.entire_subtree_needs_style_update() {
		return
	}

	if requires_broad_invalidation {
		if shadow_root := list.document_or_shadow_root.as_shadow_root() {
			effects := determine_shadow_root_style_sheet_effects(shadow_root)
			invalidation_result.may_match_shadow_host = invalidation_result.may_match_shadow_host
				|| effects.may_match_shadow_host
			invalidation_result.may_match_light_dom_under_shadow_host = invalidation_result.may_match_light_dom_under_shadow_host
				|| effects.may_match_light_dom_under_shadow_host
			invalidation_result.may_match_light_dom_outside_shadow_host = invalidation_result.may_match_light_dom_outside_shadow_host
				|| effects.may_match_light_dom_outside_shadow_host
		}
	}
	invalidate_root_for_style_sheet_change(list.document_or_shadow_root, invalidation_result, .style_sheet_list_remove_sheet, requires_broad_invalidation)
	invalidate_root_for_keyframes_rules_in_sheet(list.document_or_shadow_root, sheet)
}

pub enum RuleContext {
	unknown
	style
	counter_style
	media
	font_face
	font_feature_values
	font_feature_value
	keyframes
	keyframe
	supports
	container_rule
	scope
	supports_condition
	layer
	property
	page
	margin
	function_rule
}

fn rule_context_type_for_rule(rule_type CSSRuleType) RuleContext {
	return match rule_type {
		.style, .nested_declarations { .style }
		.counter_style { .counter_style }
		.media { .media }
		.font_face { .font_face }
		.font_feature_values { .font_feature_values }
		.keyframes { .keyframes }
		.keyframe { .keyframe }
		.supports { .supports }
		.container_rule { .container_rule }
		.scope { .scope }
		.layer_block { .layer }
		.property { .property }
		.page { .page }
		.margin { .margin }
		.function_rule { .function_rule }
		.function_declarations { .function_rule }
		else { .unknown }
	}
}

pub struct PropertyDefinition {
pub mut:
	name          string
	syntax        string
	inherits      bool
	initial_value ?string
}

pub struct CustomPropertyRegistration {
pub mut:
	property_name string
	syntax        string
	inherit       bool
	initial_value ?string
}

pub fn (registration CustomPropertyRegistration) equals(other CustomPropertyRegistration) bool {
	return registration.property_name == other.property_name && registration.syntax == other.syntax
		&& registration.inherit == other.inherit
		&& option_string_equal(registration.initial_value, other.initial_value)
}

// https://www.w3.org/TR/cssom-1/#dom-css-escape
pub fn escape(identifier string) string {
	// The escape(ident) operation must return the result of invoking serialize an identifier of ident.
	return serialize_an_identifier(identifier)
}

// https://www.w3.org/TR/css-conditional-3/#dom-css-supports
pub fn supports_property(property_name string, value string) bool {
	// 1. If property is an ASCII case-insensitive match for any defined CSS property that the UA supports, or is a
	//    custom property name string, and value successfully parses according to that property's grammar, return true.
	if property := property_id_from_string(property_name) {
		if parse_css_value(ParsingParams{}, value, property) != none {
			return true
		}
	}
	if is_a_custom_property_name_string(property_name) && value.trim_space().len != 0 {
		return true
	}

	// 2. Otherwise, return false.
	return false
}

// https://www.w3.org/TR/css-conditional-3/#dom-css-supports
pub fn supports_condition(condition_text string) bool {
	// 1. If conditionText, parsed and evaluated as a <supports-condition>, would return true, return true.
	if supports := parse_css_supports(ParsingParams{}, condition_text) {
		if supports.matches_condition() {
			return true
		}
	}

	// 2. Otherwise, If conditionText, wrapped in parentheses and then parsed and evaluated as a <supports-condition>,
	//    would return true, return true.
	wrapped_condition_text := '(${condition_text})'
	if supports := parse_css_supports(ParsingParams{}, wrapped_condition_text) {
		if supports.matches_condition() {
			return true
		}
	}

	// 3. Otherwise, return false.
	return false
}

// https://www.w3.org/TR/css-properties-values-api-1/#the-registerproperty-function
pub fn register_property(definition PropertyDefinition) !CustomPropertyRegistration {
	// 1. Let property set be the value of the current global object's associated Document's [[registeredPropertySet]] slot.
	// Boundary: This V binding has no current-global/Document parameter, so the document-owned property set is handled
	// by register_property_for_document() below.

	// 2. If name is not a custom property name string, throw a SyntaxError and exit this algorithm.
	if !is_a_custom_property_name_string(definition.name) {
		return error('SyntaxError: Invalid property name')
	}

	// If property set already contains an entry with name as its property name (compared codepoint-wise),
	// throw an InvalidModificationError and exit this algorithm.
	// Boundary: duplicate checks require the document-owned property set; use register_property_for_document().

	// 3. Attempt to consume a syntax definition from syntax. If it returns failure, throw a SyntaxError.
	//    Otherwise, let syntax definition be the returned syntax definition.
	syntax_component_values := parse_component_values_for_value_logic(definition.syntax)
	maybe_syntax := parse_as_syntax_with_ident_limit(syntax_component_values, .yes) or {
		return error('SyntaxError: Invalid syntax definition')
	}

	// 4. If syntax definition is the universal syntax definition, and initialValue is not present,
	if maybe_syntax.type() == .universal {
		if initial_value := definition.initial_value {
			// Otherwise, if syntax definition is the universal syntax definition,
			// parse initialValue as the @property initial-value descriptor. Unlike
			// property values, descriptor values do not admit arbitrary
			// substitution functions.
			initial_value_components := parse_component_values_for_value_logic(initial_value)
			mut substitution_presence := SubstitutionFunctionsPresence{}
			collect_arbitrary_substitution_function_presence(initial_value_components, mut substitution_presence) or {
				return error('SyntaxError: Invalid initial value')
			}
			if substitution_presence.has_any() {
				return error('SyntaxError: Invalid initial value')
			}
			parsed_initial_value := parse_with_a_syntax(initial_value_components, maybe_syntax)
			if parsed_initial_value.type_() == .guaranteed_invalid {
				return error('SyntaxError: Invalid initial value')
			}
		}
		// Otherwise, if initialValue is not present, throw a SyntaxError and exit this algorithm.
	} else if definition.initial_value == none {
		// Otherwise, if initialValue is not present, throw a SyntaxError and exit this algorithm.
		return error('SyntaxError: Initial value must be provided for non-universal syntax')
		// Otherwise, parse initialValue according to syntax definition.
	} else if initial_value := definition.initial_value {
		initial_value_component_values := parse_component_values_for_value_logic(initial_value)
		parsed_initial_value := parse_with_a_syntax(initial_value_component_values, maybe_syntax)
		if parsed_initial_value.type_() == .guaranteed_invalid {
			return error('SyntaxError: Invalid initial value')
		}
		// Otherwise, let parsed initial value be the parsed result.
		// NB: Already done.
		// If parsed initial value is not computationally independent, throw a SyntaxError and exit this algorithm.
		if !parsed_initial_value.is_computationally_independent() {
			return error('SyntaxError: Initial value must be computationally independent')
		}
	}

	// 5. Set inherit flag to the value of inherits.
	// NB: Combined with 6.

	// 6. Let registered property be a struct with a property name of name, a syntax of syntax definition,
	//    an initial value of parsed initial value, and an inherit flag of inherit flag.
	return CustomPropertyRegistration{
		property_name: definition.name
		syntax: definition.syntax
		inherit: definition.inherits
		initial_value: definition.initial_value
	}
}

pub fn register_property_for_document(mut document dom.Document, definition PropertyDefinition) !CustomPropertyRegistration {
	// 2. If name is not a custom property name string, throw a SyntaxError and exit this algorithm.
	if !is_a_custom_property_name_string(definition.name) {
		return error('SyntaxError: Invalid property name')
	}

	// If property set already contains an entry with name as its property name (compared codepoint-wise),
	// throw an InvalidModificationError and exit this algorithm.
	if definition.name in document.registered_property_set {
		return error('InvalidModificationError: Property is already registered')
	}

	registration := register_property(definition)!

	document.registered_property_set[registration.property_name] = dom.CustomPropertyRegistration{
		initial_value: registration.initial_value
		syntax: registration.syntax
		inherits: registration.inherit
	}
	document.did_change_custom_property_registrations()

	return registration
}

fn cssom_indent(indent_levels int) string {
	if indent_levels <= 0 {
		return ''
	}
	return '  '.repeat(indent_levels)
}

fn next_unique_anonymous_layer_name() string {
	unsafe {
		static anonymous_layer_id := u64(0)
		anonymous_layer_id++
		return '#${anonymous_layer_id}'
	}
}

fn is_a_custom_property_name_string(name string) bool {
	// https://drafts.csswg.org/css-variables-2/#typedef-custom-property-name
	// The <custom-property-name> production corresponds to this: it's defined as any <dashed-ident>
	// (a valid identifier that starts with two dashes), except -- itself, which is reserved for future use by CSS.
	if name == '--' {
		return false
	}

	return name.starts_with('--') && name.len > 2
}
