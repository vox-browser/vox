module css


import dom
import platform

// Translated scaffolding from:
// - LibWeb/CSS/StyleScope.h/cpp
// - the RuleCache and rule matching cache parts of LibWeb/CSS/StyleComputer.cpp
//
// DOM owns document/shadow-root style sheet lists in the C++ engine. The current
// V module split has DOM-side stylesheet placeholders, so the css.CSSStyleSheet
// lists are not reachable from dom.Document/dom.ShadowRoot yet. Those
// integration points are represented by explicit boundary helpers below; the
// cache-building and selector bucketing logic itself follows the C++ structure.
pub enum RuleCacheIterationDecision {
	continue_
	break_
}

pub struct RuleCaches {
pub mut:
	main     &RuleCache = unsafe { nil }
	by_layer map[string]&RuleCache
}

pub fn RuleCaches.new() &RuleCaches {
	return &RuleCaches{
		main: RuleCache.new()
		by_layer: map[string]&RuleCache{}
	}
}

pub fn (mut caches RuleCaches) visit_edges() {
	caches.main.visit_edges()
	for _, mut cache in caches.by_layer {
		cache.visit_edges()
	}
}

pub struct SelectorInsights {
pub mut:
	has_has_selectors                                                    bool
	has_has_selectors_with_relative_selector_that_has_sibling_combinator bool
	has_local_link_selectors                                             bool
}

pub fn StyleInvalidationData.new() &StyleInvalidationData {
	return &StyleInvalidationData{
		invalidation_plans: map[string]&InvalidationPlan{}
		invalidation_plan_properties: map[string]InvalidationProperty{}
		ids_used_in_has_selectors: map[string]bool{}
		class_names_used_in_has_selectors: map[string]bool{}
		attribute_names_used_in_has_selectors: map[string]bool{}
		tag_names_used_in_has_selectors: map[string]bool{}
		pseudo_classes_used_in_has_selectors: map[CSSPseudoClass]bool{}
	}
}

pub fn RuleCache.new() &RuleCache {
	return &RuleCache{
		rules_by_id: map[string][]&MatchingRule{}
		rules_by_class: map[string][]&MatchingRule{}
		rules_by_tag_name: map[string][]&MatchingRule{}
		rules_by_attribute_name: map[string][]&MatchingRule{}
		rules_by_pseudo_element: map[PseudoElement][]&MatchingRule{}
		rules_by_animation_keyframes: map[string]&KeyFrameSet{}
	}
}

fn style_scope_push_rule(mut bucket map[string][]&MatchingRule, key string, matching_rule &MatchingRule) {
	mut rules := bucket[key] or { []&MatchingRule{} }
	rules << matching_rule
	bucket[key] = rules
}

fn style_scope_push_pseudo_element_rule(mut bucket map[PseudoElement][]&MatchingRule, key PseudoElement, matching_rule &MatchingRule) {
	mut rules := bucket[key] or { []&MatchingRule{} }
	rules << matching_rule
	bucket[key] = rules
}

pub fn (rule &MatchingRule) visit_edges() {
	// C++ traces rule/sheet for LibGC. V references are handled by
	// the translated runtime, so this is intentionally a no-op.
	_ = rule
}

pub fn (cache &RuleCache) visit_edges() {
	// C++ walks all rule vectors and animation keyframe sets for LibGC. The V
	// port does not expose a CSS GC visitor here yet.
	_ = cache
}

pub fn (rule &MatchingRule) declaration() ?&CSSStyleProperties {
	css_rule := rule.rule or { return none }
	if css_rule.type_ == .style || css_rule.type_ == .nested_declarations {
		return css_rule.style()
	}
	return none
}

pub fn (rule &MatchingRule) absolutized_selectors() SelectorList {
	css_rule := rule.rule or {
		return SelectorList{
			selectors: [rule.selector]
		}
	}

	if css_rule.type_ == .style {
		mut mutable_rule := unsafe { &CSSRule(css_rule) }
		return mutable_rule.absolutized_selectors()
	}
	if css_rule.type_ == .nested_declarations {
		parent_style_rule := css_rule.parent_style_rule() or { return SelectorList{} }
		mut mutable_parent := unsafe { &CSSRule(parent_style_rule) }
		return mutable_parent.absolutized_selectors()
	}
	return SelectorList{}
}

pub fn (rule &MatchingRule) qualified_layer_name() string {
	css_rule := rule.rule or { return '' }
	if css_rule.type_ == .style {
		mut mutable_rule := unsafe { &CSSRule(css_rule) }
		return mutable_rule.qualified_layer_name()
	}
	if css_rule.type_ == .nested_declarations {
		parent_style_rule := css_rule.parent_style_rule() or { return '' }
		mut mutable_parent := unsafe { &CSSRule(parent_style_rule) }
		return mutable_parent.qualified_layer_name()
	}
	return ''
}

struct SimplifiedSelectorForBucketing {
	type_ SimpleSelectorType
	name  string
}

fn style_scope_is_roundabout_selector_bucketable_as_something_simpler(simple_selector SimpleSelector) ?SimplifiedSelectorForBucketing {
	if simple_selector.type_ != .pseudo_class {
		return none
	}

	pseudo_class := simple_selector.pseudo_class()
	if pseudo_class.type_ != .is_ && pseudo_class.type_ != .where {
		return none
	}

	if pseudo_class.argument_selector_list.selectors.len != 1 {
		return common_is_where_subject_bucket(pseudo_class.argument_selector_list.selectors)
	}

	argument_selector := pseudo_class.argument_selector_list.selectors[0]
	compound_selectors := argument_selector.compound_selectors()
	if compound_selectors.len == 0 {
		return none
	}
	compound_selector := compound_selectors[compound_selectors.len - 1]
	if compound_selector.simple_selectors.len != 1 {
		return none
	}

	inner_simple_selector := compound_selector.simple_selectors[0]
	if inner_simple_selector.type_ == .class || inner_simple_selector.type_ == .id {
		return SimplifiedSelectorForBucketing{
			type_: inner_simple_selector.type_
			name: inner_simple_selector.name().name
		}
	}
	if inner_simple_selector.type_ == .tag_name {
		return SimplifiedSelectorForBucketing{
			type_: inner_simple_selector.type_
			name: inner_simple_selector.qualified_name().name.lowercase_name
		}
	}
	return none
}

fn (cache &RuleCache) selector_name_bucket_key(name string) string {
	return if cache.fold_id_and_class_name_case { to_ascii_lowercase(name) } else { name }
}

pub fn (mut cache RuleCache) add_rule(matching_rule &MatchingRule, pseudo_element ?PseudoElement, contains_root_pseudo_class bool) {
	if matching_rule.slotted {
		cache.slotted_rules << matching_rule
		return
	}
	if matching_rule.contains_part_pseudo_element {
		cache.part_rules << matching_rule
		return
	}

	compound_selectors := matching_rule.selector.compound_selectors()
	if compound_selectors.len == 0 {
		cache.append_other_subject_rule(matching_rule)
		return
	}
	last_compound_selector := compound_selectors[compound_selectors.len - 1]
	if attribute_name := style_scope_attribute_before_tag_bucket(last_compound_selector) {
		style_scope_push_rule(mut cache.rules_by_attribute_name, attribute_name, matching_rule)
		record_attribute_before_tag_bucket(matching_rule.selector)
		return
	}

	// NOTE: We traverse the simple selectors in reverse order to make sure that
	// class/ID buckets are preferred over tag buckets in the common case of
	// div.foo or div#foo selectors.
	for i := last_compound_selector.simple_selectors.len - 1; i >= 0; i-- {
		simple_selector := last_compound_selector.simple_selectors[i]
		if simple_selector.type_ == .id {
			style_scope_push_rule(mut cache.rules_by_id, cache.selector_name_bucket_key(simple_selector.name().name), matching_rule)
			return
		}
		if simple_selector.type_ == .class {
			style_scope_push_rule(mut cache.rules_by_class, cache.selector_name_bucket_key(simple_selector.name().name), matching_rule)
			return
		}
		if simple_selector.type_ == .tag_name {
			style_scope_push_rule(mut cache.rules_by_tag_name, simple_selector.qualified_name().name.lowercase_name, matching_rule)
			return
		}
		// NOTE: Selectors like `:is/where(.foo)` and `:is/where(.foo .bar)` are
		// bucketed as class selectors for `foo` and `bar` respectively.
		if simplified := style_scope_is_roundabout_selector_bucketable_as_something_simpler(simple_selector) {
			if simplified.type_ == .tag_name {
				style_scope_push_rule(mut cache.rules_by_tag_name, simplified.name, matching_rule)
				return
			}
			if simplified.type_ == .class {
				style_scope_push_rule(mut cache.rules_by_class, cache.selector_name_bucket_key(simplified.name), matching_rule)
				return
			}
			if simplified.type_ == .id {
				style_scope_push_rule(mut cache.rules_by_id, cache.selector_name_bucket_key(simplified.name), matching_rule)
				return
			}
		}
	}

	if matching_rule.contains_pseudo_element {
		if pseudo := pseudo_element {
			if is_known_pseudo_element_type(pseudo) {
				style_scope_push_pseudo_element_rule(mut cache.rules_by_pseudo_element, pseudo, matching_rule)
			} else {
				// NOTE: We don't cache rules for unknown pseudo-elements. They can't
				// match anything anyway.
			}
		}
	} else if contains_root_pseudo_class {
		cache.root_rules << matching_rule
	} else {
		for simple_selector in last_compound_selector.simple_selectors {
			if simple_selector.type_ == .attribute {
				style_scope_push_rule(mut cache.rules_by_attribute_name, simple_selector.attribute().qualified_name.name.lowercase_name, matching_rule)
				return
			}
		}
		cache.append_other_subject_rule(matching_rule)
	}
}

pub fn (cache &RuleCache) matching_rule_buckets(abstract_element dom.AbstractElement) [][]&MatchingRule {
	element := abstract_element.element()
	attribute_count := if attrs := element.attributes_ { attrs.length() } else { 0 }
	mut buckets := [][]&MatchingRule{cap: element.classes.len + attribute_count + 5}
	mut iterator := rule_bucket_iterator(cache, abstract_element)
	for {
		bucket := iterator.next() or { break }
		buckets << unsafe { bucket }
	}
	return buckets
}

fn rule_cache_attribute_bucket_name(name string) string {
	// Preserve the selector-name cache's existing Unicode folding, while the
	// overwhelmingly common lowercase ASCII names need no new string.
	for byte in name {
		if (byte >= `A` && byte <= `Z`) || byte >= 0x80 {
			return name.to_lower()
		}
	}
	return name
}

pub fn (cache &RuleCache) for_each_matching_rules(abstract_element dom.AbstractElement, callback fn([]&MatchingRule) RuleCacheIterationDecision) {
	mut iterator := rule_bucket_iterator(cache, abstract_element)
	for {
		bucket := iterator.next() or { break }
		if callback(bucket) == .break_ {
			return
		}
	}
}

fn rule_cache_bucket_has_pseudo_element(bucket []&MatchingRule, pseudo_element PseudoElement) bool {
	for rule in bucket {
		if rule_pseudo_element := rule.pseudo_element {
			if rule_pseudo_element == pseudo_element {
				return true
			}
		}
	}
	return false
}

fn (cache &RuleCache) has_candidate_rule_for_pseudo_element(abstract_element dom.AbstractElement, pseudo_element PseudoElement) bool {
	// This public coarse query also supports manually updated bucket vectors
	// and mutable MatchingRule hints. Keep reading those live views directly.
	return cache.has_pseudo_subject_candidate(abstract_element, pseudo_element)
}

fn (cache &RuleCache) has_pseudo_subject_candidate(abstract_element dom.AbstractElement, pseudo_element PseudoElement) bool {
	element := abstract_element.element()
	report_empty_pseudo_candidate_indexes(cache, element)
	if retain_empty_pseudo_candidate_lookups || cache.rules_by_class.len > 0 {
		for original_class_name in element.classes {
			class_name := cache.selector_name_bucket_key(original_class_name)
			if bucket := cache.rules_by_class[class_name] {
				if rule_cache_bucket_has_pseudo_element(bucket, pseudo_element) {
					return true
				}
			}
		}
	}
	if retain_empty_pseudo_candidate_lookups || cache.rules_by_id.len > 0 {
		if original_id := element.id() {
			id := cache.selector_name_bucket_key(original_id)
			if bucket := cache.rules_by_id[id] {
				if rule_cache_bucket_has_pseudo_element(bucket, pseudo_element) {
					return true
				}
			}
		}
	}
	if retain_empty_pseudo_candidate_lookups || cache.rules_by_tag_name.len > 0 {
		tag_name := element.lowercased_local_name()
		if bucket := cache.rules_by_tag_name[tag_name] {
			if rule_cache_bucket_has_pseudo_element(bucket, pseudo_element) {
				return true
			}
		}
	}
	if retain_empty_pseudo_candidate_lookups || cache.rules_by_pseudo_element.len > 0 {
		if pseudo := style_scope_pseudo_element_from_abstract_element(abstract_element) {
			if is_known_pseudo_element_type(pseudo) {
				if bucket := cache.rules_by_pseudo_element[pseudo] {
					if rule_cache_bucket_has_pseudo_element(bucket, pseudo_element) {
						return true
					}
				}
			} else {
				// NOTE: We don't cache rules for unknown pseudo-elements. They can't
				// match anything anyway.
			}
		}
	}

	if (retain_empty_pseudo_candidate_lookups || cache.root_rules.len > 0)
		&& element.is_document_element() {
		if rule_cache_bucket_has_pseudo_element(cache.root_rules, pseudo_element) {
			return true
		}
	}

	if cache.rules_by_attribute_name.len != 0 {
		if attrs := element.attributes_ {
			for attribute in attrs.attrs {
				name := rule_cache_attribute_bucket_name(attribute.name())
				if bucket := cache.rules_by_attribute_name[name] {
					if rule_cache_bucket_has_pseudo_element(bucket, pseudo_element) {
						return true
					}
				}
			}
		}
	}

	if rule_cache_bucket_has_pseudo_element(cache.other_rules, pseudo_element) {

		return true

	}
	return false
}

fn (caches &RuleCaches) has_candidate_rule_for_pseudo_element(abstract_element dom.AbstractElement, pseudo_element PseudoElement) bool {
	if caches.main.has_candidate_rule_for_pseudo_element(abstract_element, pseudo_element) {
		return true
	}
	for _, cache in caches.by_layer {
		if cache.has_candidate_rule_for_pseudo_element(abstract_element, pseudo_element) {
			return true
		}
	}
	return false
}

// Avoid running a complete cascade for generated pseudo-elements when none of
// the element's rule-cache buckets can possibly supply a rule for that pseudo.
// This is the same coarse candidate filtering used before selector matching;
// it can produce false positives, but never skips a potentially matching rule.
pub fn (scope &StyleScope) has_candidate_rule_for_pseudo_element(abstract_element dom.AbstractElement, pseudo_element PseudoElement) bool {
	scope.build_rule_cache_if_needed()
	for caches in [scope.author_rule_cache, scope.user_rule_cache, scope.user_agent_rule_cache]! {
		if value := caches {
			if value.has_candidate_rule_for_pseudo_element(abstract_element, pseudo_element) {
				return true
			}
		}
	}
	return false
}

pub fn StyleScope.new(node &dom.Node) &StyleScope {
	return &StyleScope{
		node: node
		pending_has_invalidation_features: map[i64]&PendingHasInvalidationMutationFeatures{}
	}
}

pub fn (scope &StyleScope) node_ref() ?&dom.Node {
	return scope.node
}

pub fn (scope &StyleScope) document() ?&dom.Document {
	node := scope.node or { return none }
	document := node.document()
	if document == unsafe { nil } {
		return none
	}
	return document
}

pub fn (scope &StyleScope) author_rule_caches() ?&RuleCaches {
	return scope.author_rule_cache
}

pub fn (scope &StyleScope) user_rule_caches() ?&RuleCaches {
	return scope.user_rule_cache
}

pub fn (scope &StyleScope) user_agent_rule_caches() ?&RuleCaches {
	return scope.user_agent_rule_cache
}

pub fn (scope &StyleScope) has_valid_rule_cache() bool {
	if document := scope.document() {
		if scope.rule_cache_font_policy_ != document.font_rendering_policy() { return false }
	}
	return scope.rule_cache != none
}

fn (mut scope StyleScope) adopt_style_cache(cache &StyleCache) {
	if document := scope.document() { scope.rule_cache_font_policy_ = document.font_rendering_policy() }
	scope.rule_cache = cache
	scope.qualified_layer_names_in_order = cache.qualified_layer_names_in_order.clone()
	scope.selector_insights = cache.selector_insights
	scope.pseudo_class_rule_cache = cache.pseudo_class_rule_cache.clone()
	scope.style_invalidation_data = cache.style_invalidation_data
	scope.author_rule_cache = cache.author_rule_cache
	scope.user_rule_cache = cache.user_rule_cache
	scope.user_agent_rule_cache = cache.user_agent_rule_cache
	scope.has_size_container_queries = cache.has_size_container_queries
}

pub fn (mut scope StyleScope) populate_new_rule_cache() &StyleCache {
	if document := scope.document() { scope.rule_cache_font_policy_ = document.font_rendering_policy() }
	scope.has_size_container_queries = false
	scope.author_rule_cache = RuleCaches.new()
	scope.user_rule_cache = RuleCaches.new()
	scope.user_agent_rule_cache = RuleCaches.new()

	scope.selector_insights = &SelectorInsights{}
	scope.style_invalidation_data = StyleInvalidationData.new()

	scope.build_user_style_sheet_if_needed()

	scope.build_qualified_layer_names_cache()

	scope.pseudo_class_rule_cache = map[PseudoClass]&RuleCache{}
	for pseudo_class in style_scope_pseudo_classes_with_rule_cache() {
		scope.pseudo_class_rule_cache[pseudo_class] = RuleCache.new()
	}

	if insights := scope.selector_insights {
		scope.make_rule_cache_for_cascade_origin(.author, insights)
		scope.make_rule_cache_for_cascade_origin(.user, insights)
		scope.make_rule_cache_for_cascade_origin(.user_agent, insights)
	}

	cache := &StyleCache{
		qualified_layer_names_in_order: scope.qualified_layer_names_in_order.clone()
		selector_insights: scope.selector_insights or { &SelectorInsights{} }
		pseudo_class_rule_cache: scope.pseudo_class_rule_cache.clone()
		style_invalidation_data: scope.style_invalidation_data or { StyleInvalidationData.new() }
		author_rule_cache: scope.author_rule_cache or { RuleCaches.new() }
		user_rule_cache: scope.user_rule_cache or { RuleCaches.new() }
		user_agent_rule_cache: scope.user_agent_rule_cache or { RuleCaches.new() }
		has_size_container_queries: scope.has_size_container_queries
	}
	mut function_cache := unsafe { &StyleCache(cache) }
	for origin in [CascadeOrigin.author, .user, .user_agent] {
		scope.cache_function_definitions(mut function_cache, origin)
	}
	scope.rule_cache = cache
	return cache
}

pub fn (mut scope StyleScope) build_rule_cache() {
	if cache := scope.shared_user_agent_only_shadow_style_cache() {
		scope.adopt_style_cache(cache)
		return
	}
	if node := scope.node {
		if node.as_shadow_root() != none {
			active_author_sheets := scope.stylesheets_for_cascade_origin(.author)
			document_scope := css_style_scope_for_document(node.document())
			if active_author_sheets.len == 1 && active_author_sheets[0].constructed
				&& document_scope.user_style_source == none && !node.document().in_quirks_mode()
				&& node.document().font_rendering_policy() == .libweb {
				mut constructed_sheet := unsafe { &CSSStyleSheet(active_author_sheets[0]) }
				cache := constructed_sheet.shared_single_constructed_sheet_style_cache(mut scope)
				scope.adopt_style_cache(cache)
				return
			}
		}
	}
	scope.populate_new_rule_cache()
}

// The list of document or shadow root CSS style sheets.
pub fn (mut scope StyleScope) style_sheet_list() &StyleSheetList {
	if list := scope.style_sheets {
		return list
	}
	node := scope.node or { panic('StyleScope.style_sheet_list: scope without a node') }
	list := StyleSheetList.create(node)
	scope.style_sheets = list
	return list
}

pub fn (mut scope StyleScope) invalidate_rule_cache() {
	scope.adopted_user_agent_only_shadow_cache_ = unsafe { nil }
	scope.invalidate_counter_style_cache()
	scope.rule_cache = none
	scope.author_rule_cache = none

	// NOTE: We could be smarter about keeping the user rule cache, and style sheet.
	//       Currently we are re-parsing the user style sheet every time we build the caches,
	//       as it may have changed.
	scope.user_rule_cache = none
	scope.user_style_sheet = none

	// NOTE: It might not be necessary to throw away the UA rule cache.
	//       If we are sure that it's safe, we could keep it as an optimization.
	scope.user_agent_rule_cache = none

	scope.pseudo_class_rule_cache = map[PseudoClass]&RuleCache{}
	scope.style_invalidation_data = none
	scope.has_size_container_queries = false
}

pub fn (mut scope StyleScope) invalidate_user_style_sheet() {
	scope.user_style_sheet = none
	scope.invalidate_rule_cache()
}

pub fn (mut scope StyleScope) build_user_style_sheet_if_needed() {
	if scope.user_style_sheet != none {
		return
	}
	mut user_style_source := scope.user_style_source
	if user_style_source == none {
		if document := scope.document() {
			if document.has_page() {
				user_style_source = document.page().user_style()
			}
		}
	}
	if source := user_style_source {
		scope.user_style_sheet = parse_css_stylesheet_with_parser(source, none)
	}
}

pub fn (scope &StyleScope) build_rule_cache_if_needed() {
	if scope.adopted_user_agent_only_shadow_cache_ != unsafe { nil }
		&& !scope.adopted_user_agent_only_shadow_cache_.environment_matches(scope) {
		mut mutable_scope := unsafe { &StyleScope(scope) }
		mutable_scope.invalidate_rule_cache()
	}
	if scope.has_valid_rule_cache() {
		return
	}
	mut mutable_scope := unsafe { &StyleScope(scope) }
	mutable_scope.build_rule_cache()
}

fn style_scope_user_agent_stylesheet(name string) ?&CSSStyleSheet {
	// Reuse the shared, parsed-once user-agent stylesheet instead of re-parsing Default.css per document.
	if sheet := user_agent_default_style_sheet(name) {
		return sheet
	}
	source := user_agent_style_sheet_source(name) or { return none }
	return parse_css_stylesheet_with_params(ParsingParams{
		is_ua_style_sheet: .yes
	}, source, none)
}

struct ActiveStyleSheetCollection {
mut:
	sheets []&CSSStyleSheet
}

fn style_scope_append_active_sheet(context voidptr, sheet &CSSStyleSheet) {
	mut collection := unsafe { &ActiveStyleSheetCollection(context) }
	collection.sheets << sheet
}

pub fn (scope &StyleScope) stylesheets_for_cascade_origin(cascade_origin CascadeOrigin) []&CSSStyleSheet {
	mut sheets := []&CSSStyleSheet{}
	match cascade_origin {
		.user_agent {
			if sheet := style_scope_user_agent_stylesheet('CSS/Default.css') {
				sheets << sheet
			}
			if document := scope.document() {
				if document.in_quirks_mode() {
					if sheet := style_scope_user_agent_stylesheet('CSS/QuirksMode.css') {
						sheets << sheet
					}
				}
			}
			if sheet := style_scope_user_agent_stylesheet('MathML/Default.css') {
				sheets << sheet
			}
			if sheet := style_scope_user_agent_stylesheet('SVG/Default.css') {
				sheets << sheet
			}
			if document := scope.document() {
				if document.font_rendering_policy() == .chromium { sheets << chromium_control_font_style_sheet() }
			}
		}
		.user {
			mut mutable_scope := unsafe { &StyleScope(scope) }
			mutable_scope.build_user_style_sheet_if_needed()
			if sheet := mutable_scope.user_style_sheet {
				sheets << sheet
			}
		}
		.author {
			mut collection := ActiveStyleSheetCollection{}
			style_scope_for_each_active_css_style_sheet_boundary_with_context(scope, voidptr(&collection), style_scope_append_active_sheet)
			return collection.sheets
		}
		else {}
	}

	return sheets
}

pub fn (scope &StyleScope) for_each_stylesheet(cascade_origin CascadeOrigin, callback fn(&CSSStyleSheet)) {
	for sheet in scope.stylesheets_for_cascade_origin(cascade_origin) {
		callback(sheet)
	}
}

struct RuleCacheBuildContext {
	scope &StyleScope
	rule_caches &RuleCaches
	sheet &CSSStyleSheet
	cascade_origin CascadeOrigin
	insights &SelectorInsights
	style_sheet_index uint
	fold_id_and_class_name_case bool
mut:
	rule_index uint
}

fn style_scope_cache_style_rule(raw_context voidptr, rule &CSSRule) {
	if rule.type_ !in [.style, .nested_declarations] { return }
	mut context := unsafe { &RuleCacheBuildContext(raw_context) }
	mut scope := unsafe { &StyleScope(context.scope) }
	mut rule_caches := unsafe { &RuleCaches(context.rule_caches) }
	sheet := context.sheet
	cascade_origin := context.cascade_origin
	mut mutable_insights := unsafe { &SelectorInsights(context.insights) }
	style_sheet_index := context.style_sheet_index
	fold_id_and_class_name_case := context.fold_id_and_class_name_case
	if container_rule := rule.parent_container_rule() {
		if container_rule.container_rule_contains_size_feature() {
			scope.has_size_container_queries = true
		}
	}
	absolutized_selectors := style_scope_absolutized_selectors_for_rule(rule)
	if style_invalidation_data := scope.style_invalidation_data {
		mut mutable_invalidation_data := unsafe { &StyleInvalidationData(style_invalidation_data) }
		for selector in absolutized_selectors.selectors {
			mutable_invalidation_data.build_invalidation_sets_for_selector(selector)
		}
		if scope_rule := rule.parent_scope_rule() {
			style_scope_collect_boundary_selector_dependencies(scope_rule, mut mutable_invalidation_data, mut mutable_insights)
		}
	}

	for selector in absolutized_selectors.selectors {
		mut matching_rule := &MatchingRule{
			rule: style_scope_mut_css_rule(rule)
			sheet: style_scope_mut_css_style_sheet(sheet)
			default_namespace: sheet.default_namespace()
			selector: selector
			style_sheet_index: style_sheet_index
			rule_index: context.rule_index
			specificity: selector.specificity()
			cascade_origin: cascade_origin
			scope_rule: rule.parent_scope_rule()
			container_rule: rule.parent_container_rule()
		}

		qualified_layer_name := matching_rule.qualified_layer_name()
		mut rule_cache := if qualified_layer_name.len == 0 {
			rule_caches.main
		} else {
			if qualified_layer_name !in rule_caches.by_layer {
				rule_caches.by_layer[qualified_layer_name] = RuleCache.new()
			}
			rule_caches.by_layer[qualified_layer_name] or { rule_caches.main }
		}

		rule_cache.fold_id_and_class_name_case = fold_id_and_class_name_case
		rule_cache.disjunctive_subject_masks_trusted_ = true

		mut contains_root_pseudo_class := false
		mut pseudo_element := ?PseudoElement(none)

		StyleScope.collect_selector_insights(selector, mut mutable_insights)

		compound_selectors := selector.compound_selectors()
		if compound_selectors.len != 0 {
			last_compound_selector := compound_selectors[compound_selectors.len - 1]
			for simple_selector in last_compound_selector.simple_selectors {
				if !matching_rule.contains_pseudo_element {
					if simple_selector.type_ == .pseudo_element {
						matching_rule.contains_pseudo_element = true
						// FIXME: This wrongly assumes there is only one pseudo-element per selector.
						pseudo_element = simple_selector.pseudo_element().type_
						matching_rule.slotted = simple_selector.pseudo_element().type_ == .slotted
						matching_rule.contains_part_pseudo_element = simple_selector.pseudo_element().type_ == .part
					}
				}
				if !contains_root_pseudo_class {
					if simple_selector.type_ == .pseudo_class && simple_selector.pseudo_class().type_ == .root {
						contains_root_pseudo_class = true
					}
				}
			}
		}
		matching_rule.pseudo_element = pseudo_element

		for pseudo_class in style_scope_pseudo_classes_with_rule_cache() {
			mut pseudo_class_cache := scope.pseudo_class_rule_cache[pseudo_class] or {
				continue
			}
			if selector.contains_pseudo_class(pseudo_class) {
				// For pseudo class rule caches we intentionally pass no
				// pseudo-element, because we don't want to bucket pseudo
				// class rules by pseudo-element type.
				pseudo_class_cache.fold_id_and_class_name_case = fold_id_and_class_name_case
				pseudo_class_cache.add_rule(matching_rule, none, contains_root_pseudo_class)
			}
		}

		rule_cache.add_rule(matching_rule, pseudo_element, contains_root_pseudo_class)
		rule_cache.index_pseudo_subject_rule(matching_rule, pseudo_element, contains_root_pseudo_class)
	}
	context.rule_index++
}

fn style_scope_cache_keyframes_rule(context voidptr, rule &CSSRule) {
	if rule.type_ != .keyframes { return }
	mut cache := unsafe { &RuleCache(context) }
	style_scope_add_keyframes_rule_to_cache(mut cache, rule)
}

pub fn (mut scope StyleScope) make_rule_cache_for_cascade_origin(cascade_origin CascadeOrigin, insights &SelectorInsights) {
	fold_id_and_class_name_case := if document := scope.document() { document.in_quirks_mode() } else { false }
	mut mutable_insights := unsafe { &SelectorInsights(insights) }

	mut style_sheet_index := uint(0)
	for sheet in scope.stylesheets_for_cascade_origin(cascade_origin) {
		mut rule_caches := scope.rule_caches_for_origin_mut(cascade_origin) or { continue }
		mut context := RuleCacheBuildContext{
			scope: &scope
			rule_caches: rule_caches
			sheet: sheet
			cascade_origin: cascade_origin
			insights: mutable_insights
			style_sheet_index: style_sheet_index
			fold_id_and_class_name_case: fold_id_and_class_name_case
		}
		sheet.for_each_effective_rule_with_context(.preorder, voidptr(&context), style_scope_cache_style_rule)

		// Loosely based on https://drafts.csswg.org/css-animations-2/#keyframe-processing
		sheet.for_each_effective_rule_with_context(.preorder, voidptr(rule_caches.main), style_scope_cache_keyframes_rule)
		style_sheet_index++
	}
}

pub fn (scope &StyleScope) have_size_container_queries() bool {
	scope.build_rule_cache_if_needed()
	return scope.has_size_container_queries
}

fn style_scope_collect_boundary_selector_dependencies(scope_rule &CSSRule, mut invalidation_data StyleInvalidationData, mut insights SelectorInsights) {
	mut current_scope_rule := ?&CSSRule(scope_rule)
	for {
		current := current_scope_rule or { break }
		mut mutable_current := unsafe { &CSSRule(current) }
		if start_selectors := mutable_current.scope_start_selectors_for_matching() {
			for selector in start_selectors.selectors {
				invalidation_data.build_invalidation_sets_for_scope_boundary_selector(selector)
				StyleScope.collect_selector_insights(selector, mut insights)
			}
		}
		if end_selectors := mutable_current.scope_end_selectors_for_matching() {
			for selector in end_selectors.selectors {
				invalidation_data.build_invalidation_sets_for_scope_boundary_selector(selector)
				StyleScope.collect_selector_insights(selector, mut insights)
			}
		}
		current_scope_rule = current.parent_scope_rule()
	}
}

fn style_scope_keyframe_property_value(property CSSStyleProperty, property_id PropertyID) ?&dom.StyleValue {
	if value := property.style_value {
		return value
	}
	return parse_css_value(ParsingParams{}, property.value, property_id)
}

fn style_scope_keyframe_property_is_animatable(property_id PropertyID) bool {
	return is_animatable_property(property_id)
}

fn style_scope_resolve_keyframe_set_from_rule(rule &CSSRule) &KeyFrameSet {
	mut keyframe_set := &KeyFrameSet{
		keyframes_by_key: map[int]ResolvedKeyFrame{}
	}
	mut animated_properties := map[PropertyID]bool{}
	mut animated_custom_properties := map[string]bool{}
	rules := rule.css_rules() or { return keyframe_set }

	// Forwards pass, resolve all the user-specified keyframe properties.
	for keyframe_rule in rules.rules {
		if keyframe_rule.type_ != .keyframe {
			continue
		}
		keyframe_key := keyframe_rule.kind_data().keyframe_key or { continue }
		key := int(keyframe_key.value() * animation_key_frame_key_scale_factor)
		keyframe_style := keyframe_rule.style() or { continue }
		mut resolved_keyframe := ResolvedKeyFrame{
			properties: map[PropertyID]&dom.StyleValue{}
			custom_properties: map[string]&dom.StyleValue{}
			use_initial_properties: map[PropertyID]bool{}
			use_initial_custom_properties: map[string]bool{}
		}

		for property in keyframe_style.properties {
			property_id := property_id_from_string(property.name) or { continue }

			if property_id == .animation_timing_function {
				property_value := style_scope_keyframe_property_value(property, property_id) or {
					continue
				}
				typed := style_value_logic_from_dom(property_id, property_value) or { continue }
				first := if typed is StyleValueList && typed.size() > 0 {
					typed.value_at(0, false)
				} else {
					typed
				}
				if first is EasingStyleValue || first is KeywordStyleValue {
					resolved_keyframe.easing = ResolvedKeyframeEasing(EasingFunction.from_css_style_value(first))
				} else {
					resolved_keyframe.easing = ResolvedKeyframeEasing(UnresolvedKeyframeEasing{
						value: dom_style_value_from_value_logic(first)
					})
				}
				continue
			}
			if property_id == .animation_composition {
				property_value := style_scope_keyframe_property_value(property, property_id) or {
					continue
				}
				resolved_keyframe.composite = match property_value.css_text.trim_space() {
					'add' { CompositeOperation.add }
					'accumulate' { CompositeOperation.accumulate }
					else { CompositeOperation.replace }
				}
				continue
			}
			if !style_scope_keyframe_property_is_animatable(property_id) {
				continue
			}

			property_value := style_scope_keyframe_property_value(property, property_id) or {
				continue
			}
			// Unresolved properties will be resolved in collect_animation_into()
			// V closures capture value types by value. Collect the expansion first so the
			// mutations below update this keyframe rather than closure-local map copies.
			for longhand in expand_property_longhands(property_id, property_value) {
				animated_properties[longhand.id] = true
				resolved_keyframe.properties[longhand.id] = unsafe { longhand.value }
			}
		}

		for name, property in keyframe_style.custom_properties {
			animated_custom_properties[name] = true
			resolved_keyframe.custom_properties[name] = unsafe { property.value }
		}

		if existing_keyframe := keyframe_set.keyframes_by_key[key] {
			mut merged_keyframe := existing_keyframe
			for property_id, value in resolved_keyframe.properties {
				merged_keyframe.properties[property_id] = unsafe { value }
			}
			for name, value in resolved_keyframe.custom_properties {
				merged_keyframe.custom_properties[name] = unsafe { value }
			}
			if easing := resolved_keyframe.easing {
				merged_keyframe.easing = easing
			}
			if composite := resolved_keyframe.composite {
				merged_keyframe.composite = composite
			}
			keyframe_set.keyframes_by_key[key] = merged_keyframe
		} else {
			keyframe_set.keyframes_by_key[key] = resolved_keyframe
		}
	}

	style_scope_generate_initial_and_final_keyframes(mut keyframe_set, animated_properties,
		animated_custom_properties)
	return keyframe_set
}

fn style_scope_generate_initial_and_final_keyframes(mut keyframe_set KeyFrameSet, animated_properties map[PropertyID]bool, animated_custom_properties map[string]bool) {
	final_key := 100 * animation_key_frame_key_scale_factor
	if 0 !in keyframe_set.keyframes_by_key {
		keyframe_set.keyframes_by_key[0] = ResolvedKeyFrame{
			properties: map[PropertyID]&dom.StyleValue{}
			custom_properties: map[string]&dom.StyleValue{}
			use_initial_properties: map[PropertyID]bool{}
			use_initial_custom_properties: map[string]bool{}
		}
	}
	if final_key !in keyframe_set.keyframes_by_key {
		keyframe_set.keyframes_by_key[final_key] = ResolvedKeyFrame{
			properties: map[PropertyID]&dom.StyleValue{}
			custom_properties: map[string]&dom.StyleValue{}
			use_initial_properties: map[PropertyID]bool{}
			use_initial_custom_properties: map[string]bool{}
		}
	}

	mut initial := keyframe_set.keyframes_by_key[0] or { ResolvedKeyFrame{} }
	mut final := keyframe_set.keyframes_by_key[final_key] or { ResolvedKeyFrame{} }
	for property_id, _ in animated_properties {
		if property_id !in initial.properties {
			initial.use_initial_properties[property_id] = true
		}
		if property_id !in final.properties {
			final.use_initial_properties[property_id] = true
		}
	}
	for name, _ in animated_custom_properties {
		if name !in initial.custom_properties {
			initial.use_initial_custom_properties[name] = true
		}
		if name !in final.custom_properties {
			final.use_initial_custom_properties[name] = true
		}
	}
	keyframe_set.keyframes_by_key[0] = initial
	keyframe_set.keyframes_by_key[final_key] = final
}

fn style_scope_add_keyframes_rule_to_cache(mut rule_cache RuleCache, rule &CSSRule) {
	if rule.type_ != .keyframes {
		return
	}
	keyframe_set := style_scope_resolve_keyframe_set_from_rule(rule)
	rule_cache.rules_by_animation_keyframes[rule.keyframes_name()] = keyframe_set
}

fn (mut scope StyleScope) rule_caches_for_origin_mut(cascade_origin CascadeOrigin) ?&RuleCaches {
	match cascade_origin {
		.author {
			return scope.author_rule_cache
		}
		.user {
			return scope.user_rule_cache
		}
		.user_agent {
			return scope.user_agent_rule_cache
		}
		else {
			return none
		}
	}
}

fn (scope &StyleScope) rule_caches_for_origin(cascade_origin CascadeOrigin) ?&RuleCaches {
	match cascade_origin {
		.author {
			return scope.author_rule_cache
		}
		.user {
			return scope.user_rule_cache
		}
		.user_agent {
			return scope.user_agent_rule_cache
		}
		else {
			return none
		}
	}
}

pub fn (scope &StyleScope) rule_cache_for_cascade_origin(cascade_origin CascadeOrigin, qualified_layer_name ?string) ?&RuleCache {
	scope.build_rule_cache_if_needed()

	rule_caches_by_layer := scope.rule_caches_for_origin(cascade_origin) or { return none }
	if layer_name := qualified_layer_name {
		return rule_caches_by_layer.by_layer[layer_name] or { return none }
	}
	return rule_caches_by_layer.main
}

pub fn StyleScope.collect_selector_insights(selector Selector, mut insights SelectorInsights) {
	for compound_selector in selector.compound_selectors() {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ == .pseudo_class {
				if simple_selector.pseudo_class().type_ == .local_link {
					insights.has_local_link_selectors = true
				}
				if simple_selector.pseudo_class().type_ == .has {
					insights.has_has_selectors = true
					for argument_selector in simple_selector.pseudo_class().argument_selector_list.selectors {
						for relative_compound_selector in argument_selector.compound_selectors() {
							if relative_compound_selector.combinator in [.next_sibling, .subsequent_sibling] {
								insights.has_has_selectors_with_relative_selector_that_has_sibling_combinator = true
								break
							}
						}
					}
				}
				for argument_selector in simple_selector.pseudo_class().argument_selector_list.selectors {
					StyleScope.collect_selector_insights(argument_selector, mut insights)
				}
			} else if simple_selector.type_ == .pseudo_element
				&& simple_selector.pseudo_element().type_ == .slotted {
				if argument_selector := simple_selector.pseudo_element().compound_selector {
					StyleScope.collect_selector_insights(argument_selector, mut insights)
				}
			}
		}
	}
}

struct StyleScopeLayerNode {
mut:
	children       map[string]&StyleScopeLayerNode
	children_order []string
}

fn StyleScopeLayerNode.new() &StyleScopeLayerNode {
	return &StyleScopeLayerNode{
		children: map[string]&StyleScopeLayerNode{}
	}
}

fn (mut node StyleScopeLayerNode) ensure_child(name string) &StyleScopeLayerNode {
	if name !in node.children {
		node.children[name] = StyleScopeLayerNode.new()
		node.children_order << name
	}
	return node.children[name] or { StyleScopeLayerNode.new() }
}

fn flatten_layer_names_tree(mut layer_names []string, parent_qualified_name string, name string, node &StyleScopeLayerNode) {
	qualified_name := if parent_qualified_name.len == 0 {
		name
	} else if name.len == 0 {
		parent_qualified_name
	} else {
		'${parent_qualified_name}.${name}'
	}

	for child_name in node.children_order {
		child := node.children[child_name] or { continue }
		flatten_layer_names_tree(mut layer_names, qualified_name, child_name, child)
	}

	layer_names << qualified_name
}

pub fn (mut scope StyleScope) build_qualified_layer_names_cache() {
	mut root := StyleScopeLayerNode.new()

	mut insert_layer_name := fn [mut root] (internal_qualified_name string) {
		mut node := root
		for part in internal_qualified_name.split('.') {
			if part.len == 0 {
				continue
			}
			node = node.ensure_child(part)
		}
	}

	// Walk all style sheets, identifying when we first see a @layer name, and add its qualified name to the list.
	// TODO: Separate the light and shadow-dom layers.
	scope.for_each_stylesheet(.author, fn [mut insert_layer_name] (sheet &CSSStyleSheet) {
		// NOTE: Postorder so that a @layer block is iterated after its children,
		// because we want those children to occur before it in the list.
		sheet.for_each_effective_rule(.postorder, fn [mut insert_layer_name] (rule &CSSRule) {
			match rule.type_ {
				.import_rule {
					mut mutable_rule := unsafe { &CSSRule(rule) }
					// https://drafts.csswg.org/css-cascade-5/#at-import
					// The layer is added to the layer order even if the import
					// fails to load the stylesheet, but is subject to any import
					// conditions (just as if declared by an @layer rule wrapped
					// in the appropriate conditional group rules).
					if layer_name := mutable_rule.internal_qualified_layer_name() {
						if rule.matches() {
							insert_layer_name(layer_name)
						}
					}
				}
				.layer_block {
					if layer_name := style_scope_layer_block_internal_qualified_name(rule) {
						insert_layer_name(layer_name)
					}
				}
				.layer_statement {
					for layer_name in style_scope_layer_statement_internal_qualified_name_list(rule) {
						insert_layer_name(layer_name)
					}
				}
				else {
					// Ignore everything else.
				}
			}
		})
	})

	// Now, produce a flat list of qualified names to use later.
	scope.qualified_layer_names_in_order.clear()
	flatten_layer_names_tree(mut scope.qualified_layer_names_in_order, '', '', root)
}

pub fn (scope &StyleScope) may_have_has_selectors() bool {
	if !scope.has_valid_rule_cache() {
		return true
	}

	scope.build_rule_cache_if_needed()
	insights := scope.selector_insights or { return false }
	return insights.has_has_selectors
}

pub fn (scope &StyleScope) have_has_selectors() bool {
	scope.build_rule_cache_if_needed()
	insights := scope.selector_insights or { return false }
	return insights.has_has_selectors
}

pub fn (scope &StyleScope) have_local_link_selectors() bool {
	scope.build_rule_cache_if_needed()
	insights := scope.selector_insights or { return false }
	return insights.has_local_link_selectors
}

pub fn (scope &StyleScope) may_have_has_selectors_with_relative_selector_that_has_sibling_combinator() bool {
	if !scope.has_valid_rule_cache() {
		return true
	}

	scope.build_rule_cache_if_needed()
	insights := scope.selector_insights or { return false }
	return insights.has_has_selectors_with_relative_selector_that_has_sibling_combinator
}

pub fn (scope &StyleScope) get_pseudo_class_rule_cache(pseudo_class PseudoClass) ?&RuleCache {
	scope.build_rule_cache_if_needed()
	return scope.pseudo_class_rule_cache[pseudo_class] or { return none }
}

pub fn (scope &StyleScope) for_each_active_css_style_sheet(callback fn(&CSSStyleSheet)) {
	style_scope_for_each_active_css_style_sheet_boundary(scope, callback)
}

pub fn (scope &StyleScope) for_each_active_css_style_sheet_with_context(context voidptr, callback fn (voidptr, &CSSStyleSheet)) {
	style_scope_for_each_active_css_style_sheet_boundary_with_context(scope, context, callback)
}

fn merge_pending_has_invalidation_mutation_features(mut target PendingHasInvalidationMutationFeatures, source &PendingHasInvalidationMutationFeatures) {
	target.is_conservative = target.is_conservative || source.is_conservative
	target.may_affect_sibling_relationships = target.may_affect_sibling_relationships
		|| source.may_affect_sibling_relationships
	target.may_affect_pseudo_classes = target.may_affect_pseudo_classes
		|| source.may_affect_pseudo_classes
	for tag_name, _ in source.tag_names {
		target.tag_names[tag_name] = true
	}
	for id, _ in source.ids {
		target.ids[id] = true
	}
	for class_name, _ in source.class_names {
		target.class_names[class_name] = true
	}
	for attribute_name, _ in source.attribute_names {
		target.attribute_names[attribute_name] = true
	}
	for pseudo_class, _ in source.pseudo_classes {
		target.pseudo_classes[pseudo_class] = true
	}
}

fn collect_pending_has_invalidation_features_from_element(mut features PendingHasInvalidationMutationFeatures, element &dom.Element) {
	features.tag_names[element.local_name()] = true
	if (element.namespace_uri() or { '' }) != 'http://www.w3.org/1999/xhtml' {
		features.tag_names[element.lowercased_local_name()] = true
	}
	if id := element.id() {
		features.ids[id] = true
	}
	for class_name in element.class_names() {
		features.class_names[class_name] = true
	}
	if attributes := element.attribute_list() {
		for index := 0; index < attributes.length(); index++ {
			attribute := attributes.item(index) or { continue }
			name := attribute.local_name()
			features.attribute_names[name] = true
			if (element.namespace_uri() or { '' }) != 'http://www.w3.org/1999/xhtml' {
				features.attribute_names[name.to_lower()] = true
			}
		}
	}
}

fn collect_pending_has_invalidation_features_from_subtree(mut features PendingHasInvalidationMutationFeatures, node &dom.Node) {
	if element := node.as_element() {
		collect_pending_has_invalidation_features_from_element(mut features, element)
	}
	for child in node.children {
		collect_pending_has_invalidation_features_from_subtree(mut features, child)
	}
}

fn collect_pending_has_invalidation_mutation_features(mutation_root &dom.Node, includes_descendants bool) &PendingHasInvalidationMutationFeatures {
	mut features := PendingHasInvalidationMutationFeatures.new()
	features.may_affect_sibling_relationships = includes_descendants
	features.may_affect_pseudo_classes = true
	if includes_descendants {
		collect_pending_has_invalidation_features_from_subtree(mut features, mutation_root)
	} else if element := mutation_root.as_element() {
		collect_pending_has_invalidation_features_from_element(mut features, element)
	}
	return features
}

fn collect_pending_has_invalidation_mutation_features_from_properties(properties []InvalidationProperty) &PendingHasInvalidationMutationFeatures {
	mut features := PendingHasInvalidationMutationFeatures.new()
	collect_pending_has_invalidation_properties_into(mut features, properties)
	return features
}

fn collect_pending_has_invalidation_properties_into(mut features PendingHasInvalidationMutationFeatures,
	properties []InvalidationProperty) {
	for property in properties {
		match property.type_ {
			.class { features.class_names[property.name()] = true }
			.id { features.ids[property.name()] = true }
			.tag_name { features.tag_names[property.name()] = true }
			.attribute { features.attribute_names[property.name()] = true }
			.invalidate_self, .invalidate_whole_subtree {
				features.is_conservative = true
			}
			.pseudo_class { features.pseudo_classes[property.pseudo_class] = true }
		}
	}
}

fn (mut scope StyleScope) record_pending_has_invalidation_features(node &dom.Node, features &PendingHasInvalidationMutationFeatures) {
	node_id := node.unique_id().value()
	if existing := scope.pending_has_invalidation_features[node_id] {
		mut stored := unsafe { existing }
		merge_pending_has_invalidation_mutation_features(mut stored, features)
		scope.pending_has_invalidation_features[node_id] = stored
		return
	}
	scope.pending_nodes_for_style_invalidation_due_to_presence_of_has << node
	scope.pending_has_invalidation_features[node_id] = features
	if document := scope.document() {
		style_scope_set_needs_invalidation_of_elements_affected_by_has(document)
	}
}

pub fn (mut scope StyleScope) record_conservative_pending_has_invalidation(node &dom.Node, may_affect_sibling_relationships bool) {
	mut features := PendingHasInvalidationMutationFeatures.new()
	features.is_conservative = true
	features.may_affect_sibling_relationships = may_affect_sibling_relationships
	features.may_affect_pseudo_classes = true
	scope.record_pending_has_invalidation_features(node, features)
}

fn (scope &StyleScope) pending_has_invalidation_covers_all_child_list_mutation_features(parent &dom.Node) bool {
	mutation_features := scope.pending_has_invalidation_features[parent.unique_id().value()] or {
		return false
	}
	if mutation_features.is_conservative {
		return true
	}
	data := scope.style_invalidation_data or { return false }
	if !mutation_features.may_affect_sibling_relationships {
		return false
	}
	for tag_name, _ in data.tag_names_used_in_has_selectors {
		if !mutation_features.tag_names[tag_name] {
			return false
		}
	}
	for id, _ in data.ids_used_in_has_selectors {
		if !mutation_features.ids[id] {
			return false
		}
	}
	for class_name, _ in data.class_names_used_in_has_selectors {
		if !mutation_features.class_names[class_name] {
			return false
		}
	}
	for attribute_name, _ in data.attribute_names_used_in_has_selectors {
		if !mutation_features.attribute_names[attribute_name] {
			return false
		}
	}
	if data.pseudo_classes_used_in_has_selectors.len > 0
		&& !mutation_features.may_affect_pseudo_classes {
		return false
	}
	return true
}

fn (scope &StyleScope) has_featureless_sensitive_has_selectors() bool {
	data := scope.style_invalidation_data or { return false }
	return data.has_selectors_sensitive_to_featureless_subtree_changes
}

pub fn (mut scope StyleScope) record_pending_has_invalidation_mutation_features(node &dom.Node, mutation_root &dom.Node, includes_descendants bool) {
	if mut features := scope.pending_has_invalidation_features[node.unique_id().value()] {
		features.may_affect_sibling_relationships = features.may_affect_sibling_relationships
			|| includes_descendants
		features.may_affect_pseudo_classes = true
		if includes_descendants {
			collect_pending_has_invalidation_features_from_subtree(mut features, mutation_root)
		} else if element := mutation_root.as_element() {
			collect_pending_has_invalidation_features_from_element(mut features, element)
		}
		return
	}
	features := collect_pending_has_invalidation_mutation_features(mutation_root, includes_descendants)
	scope.record_pending_has_invalidation_features(node, features)
}

pub fn (mut scope StyleScope) record_pending_has_invalidation_mutation_properties(node &dom.Node, properties []InvalidationProperty) {
	if mut features := scope.pending_has_invalidation_features[node.unique_id().value()] {
		// Parser attributes and later mutations often add features to the same
		// queued node. Keep that record rather than creating five throwaway maps
		// and merging them into the record which already owns these features.
		collect_pending_has_invalidation_properties_into(mut features, properties)
		return
	}
	features := collect_pending_has_invalidation_mutation_features_from_properties(properties)
	scope.record_pending_has_invalidation_features(node, features)
}

pub fn (mut scope StyleScope) schedule_ancestors_style_invalidation_due_to_presence_of_has(node &dom.Node) {
	node_id := node.unique_id().value()
	if node_id in scope.pending_has_invalidation_features {
		return
	}
	mut features := PendingHasInvalidationMutationFeatures.new()
	features.is_conservative = true
	scope.record_pending_has_invalidation_features(node, features)
}

fn (mut scope StyleScope) clear_pending_has_invalidations() {
	// Cleared arrays and maps keep their scanned backing storage. Detach the
	// completed generation so stale nodes cannot keep its document alive.
	scope.pending_nodes_for_style_invalidation_due_to_presence_of_has = []&dom.Node{}
	scope.pending_has_invalidation_features = map[i64]&PendingHasInvalidationMutationFeatures{}
}

fn selector_may_match_pending_has_mutation_features(selector Selector, features &PendingHasInvalidationMutationFeatures) bool {
	if features.is_conservative {
		return true
	}
	mut saw_concrete_feature := false
	mut concrete_feature_found := false
	mut must_be_conservative := false
	for compound_selector in selector.compound_selectors() {
		if compound_selector.combinator in [.next_sibling, .subsequent_sibling]
			&& features.may_affect_sibling_relationships {
			must_be_conservative = true
		}
		if compound_selector.simple_selectors.len == 0 {
			must_be_conservative = true
			continue
		}
		for simple_selector in compound_selector.simple_selectors {
			match simple_selector.type_ {
				.universal, .nesting, .invalid, .pseudo_element {
					must_be_conservative = true
				}
				.tag_name {
					saw_concrete_feature = true
					concrete_feature_found = concrete_feature_found
						|| features.tag_names[simple_selector.qualified_name().name.lowercase_name]
				}
				.id {
					saw_concrete_feature = true
					concrete_feature_found = concrete_feature_found
						|| features.ids[simple_selector.name().name]
				}
				.class {
					saw_concrete_feature = true
					concrete_feature_found = concrete_feature_found
						|| features.class_names[simple_selector.name().name]
				}
				.attribute {
					saw_concrete_feature = true
					concrete_feature_found = concrete_feature_found
						|| features.attribute_names[simple_selector.attribute().qualified_name.name.lowercase_name]
				}
				.pseudo_class {
					pseudo_class := simple_selector.pseudo_class()
					if pseudo_class.type_ in [.is_, .where] {
						saw_concrete_feature = true
						for argument_selector in pseudo_class.argument_selector_list.selectors {
							if selector_may_match_pending_has_mutation_features(argument_selector, features) {
								concrete_feature_found = true
								break
							}
						}
					} else if pseudo_class.type_ in [.active, .enabled, .defined, .disabled, .empty,
						.placeholder_shown, .checked, .dir, .lang, .link, .any_link, .local_link,
						.required, .optional, .read_only, .read_write, .paused, .playing,
						.muted, .seeking, .buffering, .stalled] {
						saw_concrete_feature = true
						css_pseudo_class := css_pseudo_class_from_selector_pseudo_class(pseudo_class.type_)
						concrete_feature_found = concrete_feature_found
							|| features.may_affect_pseudo_classes
							|| features.pseudo_classes[css_pseudo_class]
					} else {
						must_be_conservative = true
					}
				}
			}
		}
	}
	if must_be_conservative {
		return true
	}
	return !saw_concrete_feature || concrete_feature_found
}

fn compound_may_match_has_anchor_ignoring_has(compound_selector CompoundSelector, anchor &dom.Element) bool {
	for simple_selector in compound_selector.simple_selectors {
		match simple_selector.type_ {
			.universal {}
			.nesting, .invalid, .pseudo_element {
				return true
			}
			.tag_name {
				if anchor.local_name() != simple_selector.qualified_name().name.lowercase_name {
					return false
				}
			}
			.id {
				if anchor.id() or { '' } != simple_selector.name().name {
					return false
				}
			}
			.class {
				if !anchor.has_class(simple_selector.name().name) {
					return false
				}
			}
			.attribute {
				mut has_attribute := false
				if attributes := anchor.attribute_list() {
					for index := 0; index < attributes.length(); index++ {
						attribute := attributes.item(index) or { continue }
						if attribute.local_name() == simple_selector.attribute().qualified_name.name.lowercase_name {
							has_attribute = true
							break
						}
					}
				}
				if !has_attribute {
					return false
				}
			}
			.pseudo_class {
				if simple_selector.pseudo_class().type_ == .has {
					continue
				}
				if simple_selector.pseudo_class().type_ == .root {
					document_element := anchor.document().document_element() or { return false }
					if anchor != document_element {
						return false
					}
					continue
				}
				return true
			}
		}
	}
	return true
}

fn selector_has_rule_may_be_affected_by_mutation(selector Selector, anchor &dom.Element, features &PendingHasInvalidationMutationFeatures) (bool, bool) {
	mut found_has_rule := false
	for compound_selector in selector.compound_selectors() {
		for simple_selector in compound_selector.simple_selectors {
			if simple_selector.type_ != .pseudo_class {
				continue
			}
			pseudo_class := simple_selector.pseudo_class()
			if pseudo_class.type_ == .has
				&& compound_may_match_has_anchor_ignoring_has(compound_selector, anchor) {
				found_has_rule = true
				for argument_selector in pseudo_class.argument_selector_list.selectors {
					if selector_may_match_pending_has_mutation_features(argument_selector, features) {
						return true, true
					}
				}
			}
			for argument_selector in pseudo_class.argument_selector_list.selectors {
				nested_found, nested_affected := selector_has_rule_may_be_affected_by_mutation(argument_selector,
					anchor, features)
				found_has_rule = found_has_rule || nested_found
				if nested_affected {
					return found_has_rule, true
				}
			}
		}
	}
	return found_has_rule, false
}

fn matching_rule_vector_has_rule_may_be_affected(rules []&MatchingRule, anchor &dom.Element, features &PendingHasInvalidationMutationFeatures) (bool, bool) {
	mut found_has_rule := false
	for rule in rules {
		found, affected := selector_has_rule_may_be_affected_by_mutation(rule.selector, anchor,
			features)
		found_has_rule = found_has_rule || found
		if affected {
			return found_has_rule, true
		}
	}
	return found_has_rule, false
}

fn has_rule_that_may_be_affected_by_mutation(scope &StyleScope, anchor &dom.Element, features &PendingHasInvalidationMutationFeatures) bool {
	cache := scope.get_pseudo_class_rule_cache(.has) or { return true }
	mut found_has_rule := false
	for _, rules in cache.rules_by_id {
		found, affected := matching_rule_vector_has_rule_may_be_affected(rules, anchor, features)
		found_has_rule = found_has_rule || found
		if affected {
			return true
		}
	}
	for _, rules in cache.rules_by_class {
		found, affected := matching_rule_vector_has_rule_may_be_affected(rules, anchor, features)
		found_has_rule = found_has_rule || found
		if affected {
			return true
		}
	}
	for _, rules in cache.rules_by_tag_name {
		found, affected := matching_rule_vector_has_rule_may_be_affected(rules, anchor, features)
		found_has_rule = found_has_rule || found
		if affected {
			return true
		}
	}
	for _, rules in cache.rules_by_attribute_name {
		found, affected := matching_rule_vector_has_rule_may_be_affected(rules, anchor, features)
		found_has_rule = found_has_rule || found
		if affected {
			return true
		}
	}
	for _, rules in cache.rules_by_pseudo_element {
		found, affected := matching_rule_vector_has_rule_may_be_affected(rules, anchor, features)
		found_has_rule = found_has_rule || found
		if affected {
			return true
		}
	}
	for rules in [cache.root_rules, cache.slotted_rules, cache.part_rules, cache.other_rules] {
		found, affected := matching_rule_vector_has_rule_may_be_affected(rules, anchor, features)
		found_has_rule = found_has_rule || found
		if affected {
			return true
		}
	}
	return !found_has_rule
}

pub fn (mut scope StyleScope) invalidate_style_of_elements_affected_by_has() {
	if scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0 {
		return
	}

	nodes := scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.clone()
	features_by_node := scope.pending_has_invalidation_features.clone()
	scope.clear_pending_has_invalidations()

	// It's ok to call have_has_selectors() instead of may_have_has_selectors()
	// here and force rule cache build, because it's going to be built soon
	// anyway, since we could get here only from update_style().
	if !scope.have_has_selectors() {
		return
	}

	document := scope.document() or { return }
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.record_has_ancestor_walk_invocation()
	should_scan_ancestor_siblings := scope.may_have_has_selectors_with_relative_selector_that_has_sibling_combinator()
	mut elements_already_invalidated_for_has := map[i64]bool{}
	for node in nodes {
		mut elements_skipped_by_has_feature_filter := map[i64]bool{}
		features := features_by_node[node.unique_id().value()] or {
			mut conservative := PendingHasInvalidationMutationFeatures.new()
			conservative.is_conservative = true
			conservative
		}
		mut has_scope_ancestors := []&dom.Element{}
		mut should_delay_ancestor_sibling_scans := false
		mut ancestor := ?&dom.Node(node)
		for {
			current := ancestor or { break }
			if !current.is_element() {
				ancestor = current.parent_or_shadow_host()
				continue
			}
			element := current.as_element() or {
				ancestor = current.parent_or_shadow_host()
				continue
			}
			is_in_has_scope := element.in_has_scope
				|| element.affected_by_has_pseudo_class_in_subject_position
				|| element.affected_by_has_pseudo_class_in_non_subject_position
			if !is_in_has_scope {
				break
			}
			has_scope_ancestors << element
			should_delay_ancestor_sibling_scans = should_delay_ancestor_sibling_scans
				|| element.in_subtree_of_has_pseudo_class_relative_selector_with_sibling_combinator
				|| element.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator
			ancestor = current.parent_or_shadow_host()
		}

		for element in has_scope_ancestors {
			element_id := element.as_node().unique_id().value()
			if elements_already_invalidated_for_has[element_id] {
				continue
			}
			mutable_document.record_has_ancestor_walk_visit()

			can_skip_unchanged_has_fanout := element.as_node().root().as_shadow_root() == none
				&& element.as_node().assigned_slot_internal() == none && !element.is_shadow_host()
			mut should_invalidate_element := true
			if element.affected_by_has_pseudo_class_in_non_subject_position
				&& can_skip_unchanged_has_fanout {
				should_invalidate_element = has_rule_that_may_be_affected_by_mutation(scope,
					element, features)
			}
			if should_invalidate_element {
				elements_already_invalidated_for_has[element_id] = true
				if !has_argument_results_unchanged(element) {
					mut mutable_element := unsafe { &dom.Element(element) }
					mutable_element.invalidate_style_if_affected_by_has()
				}
			} else {
				elements_skipped_by_has_feature_filter[element_id] = true
			}

			parent := element.as_node().parent_or_shadow_host() or { return }

			// If any ancestor's sibling was tested against selectors like
			// ".a:has(+ .b)" or ".a:has(~ .b)" its style might be affected by
			// the change in descendant node.
			if !should_scan_ancestor_siblings {
				continue
			}
			is_in_sibling_subtree := element.in_subtree_of_has_pseudo_class_relative_selector_with_sibling_combinator
				|| element.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator
			if should_delay_ancestor_sibling_scans && !is_in_sibling_subtree {
				continue
			}
			for child in parent.children {
				ancestor_sibling_element := child.as_element() or { continue }
				mutable_document.record_has_ancestor_sibling_element_check()
				if ancestor_sibling_element.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator {
					sibling_id := ancestor_sibling_element.as_node().unique_id().value()
					if elements_skipped_by_has_feature_filter[sibling_id] {
						continue
					}
					if elements_already_invalidated_for_has[sibling_id] {
						continue
					}
					elements_already_invalidated_for_has[sibling_id] = true
					if !has_argument_results_unchanged(ancestor_sibling_element) {
						mut mutable_sibling := unsafe { &dom.Element(ancestor_sibling_element) }
						mutable_sibling.invalidate_style_if_affected_by_has()
					}
				}
			}
		}
	}
}

fn style_scope_pseudo_classes_with_rule_cache() [7]PseudoClass {
	return [PseudoClass.hover, .active, .focus, .focus_within, .focus_visible, .has, .target]!
}

fn style_scope_absolutized_selectors_for_rule(rule &CSSRule) SelectorList {
	if rule.type_ == .style {
		mut mutable_rule := unsafe { &CSSRule(rule) }
		return mutable_rule.absolutized_selectors()
	}
	if rule.type_ == .nested_declarations {
		mut ancestor := rule.parent_rule
		for {
			parent := ancestor or { break }
			if parent.type_ == .style {
				mut mutable_parent := unsafe { &CSSRule(parent) }
				return mutable_parent.absolutized_selectors()
			}
			if parent.type_ == .scope {
				return SelectorList{
					selectors: [selector_from_compound_selectors([CompoundSelector{
						combinator: .no_combinator
						simple_selectors: [SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{
								type_: .where
								argument_selector_list: SelectorList{
									selectors: [selector_from_compound_selectors([CompoundSelector{
										combinator: .no_combinator
										simple_selectors: [SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{
												type_: .scope
											})]
									}])]
								}
							})]
					}])]
				}
			}
			ancestor = parent.parent_rule
		}
	}
	return SelectorList{}
}

fn style_scope_layer_block_internal_qualified_name(rule &CSSRule) ?string {
	internal_name := rule.kind_data().layer_internal or { return none }
	mut mutable_rule := unsafe { &CSSRule(rule) }
	parent_name := mutable_rule.parent_layer_internal_qualified_name()
	if parent_name.len == 0 {
		return internal_name
	}
	return '${parent_name}.${internal_name}'
}

fn style_scope_layer_statement_internal_qualified_name_list(rule &CSSRule) []string {
	layer := rule.kind_data().layer or { return []string{} }
	mut names := []string{}
	mut mutable_rule := unsafe { &CSSRule(rule) }
	parent_name := mutable_rule.parent_layer_internal_qualified_name()
	for raw_name in layer.split(',') {
		name := raw_name.trim_space()
		if name.len == 0 {
			continue
		}
		if parent_name.len == 0 {
			names << name
		} else {
			names << '${parent_name}.${name}'
		}
	}
	return names
}

fn style_scope_set_needs_invalidation_of_elements_affected_by_has(document &dom.Document) {
	// Stands in for C++ Document::set_needs_invalidation_of_elements_affected_by_has().
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.needs_invalidation_of_elements_affected_by_has = true
}

fn style_scope_for_each_active_css_style_sheet_boundary(scope &StyleScope, callback fn(&CSSStyleSheet)) {
	// Concrete CSSStyleSheet objects remain CSS-owned to avoid a dom -> css
	// dependency. Sheets installed directly by CSS-aware callers come first:
	// shadow scopes store theirs on the scope, document scopes in the
	// document's opaque author-sheet holder. The document or shadow root CSS
	// style sheets follow in tree order, then the adopted style sheets.
	if node := scope.node {
		if node.as_shadow_root() != none {
			for sheet in scope.author_style_sheets {
				if !sheet.base.disabled {
					callback(sheet)
				}
			}
			if list := scope.style_sheets {
				for sheet in list.sheets {
					if !sheet.base.disabled {
						callback(sheet)
					}
				}
			}
			if adopted := adopted_style_sheets_list_if_created(node) {
				for sheet in adopted.items() {
					if !sheet.base.disabled {
						callback(sheet)
					}
				}
			}
			return
		}
	}
	document := scope.document() or { return }
	for sheet in css_author_style_sheets_for(document).sheets {
		if sheet.base.disabled {
			continue
		}
		callback(sheet)
	}
	if list := scope.style_sheets {
		for sheet in list.sheets {
			if sheet.base.disabled {
				continue
			}
			callback(sheet)
		}
	}
	if adopted := adopted_style_sheets_list_if_created(unsafe { &dom.Node(document) }) {
		for sheet in adopted.items() {
			if !sheet.base.disabled {
				callback(sheet)
			}
		}
	}
	callback(dynamic_view_transition_style_sheet_for_document(document))
}

fn style_scope_for_each_active_css_style_sheet_boundary_with_context(scope &StyleScope, context voidptr, callback fn (voidptr, &CSSStyleSheet)) {
	// Concrete CSSStyleSheet objects remain CSS-owned to avoid a dom -> css
	// dependency. Sheets installed directly by CSS-aware callers come first:
	// shadow scopes store theirs on the scope, document scopes in the
	// document's opaque author-sheet holder. The document or shadow root CSS
	// style sheets follow in tree order, then the adopted style sheets.
	if node := scope.node {
		if node.as_shadow_root() != none {
			for sheet in scope.author_style_sheets {
				if !sheet.base.disabled {
					callback(context, sheet)
				}
			}
			if list := scope.style_sheets {
				for sheet in list.sheets {
					if !sheet.base.disabled {
						callback(context, sheet)
					}
				}
			}
			if adopted := adopted_style_sheets_list_if_created(node) {
				for sheet in adopted.items() {
					if !sheet.base.disabled {
						callback(context, sheet)
					}
				}
			}
			return
		}
	}
	document := scope.document() or { return }
	for sheet in css_author_style_sheets_for(document).sheets {
		if sheet.base.disabled {
			continue
		}
		callback(context, sheet)
	}
	if list := scope.style_sheets {
		for sheet in list.sheets {
			if sheet.base.disabled {
				continue
			}
			callback(context, sheet)
		}
	}
	if adopted := adopted_style_sheets_list_if_created(unsafe { &dom.Node(document) }) {
		for sheet in adopted.items() {
			if !sheet.base.disabled {
				callback(context, sheet)
			}
		}
	}
	callback(context, dynamic_view_transition_style_sheet_for_document(document))
}

fn style_scope_pseudo_element_from_dom(pseudo_element dom.PseudoElement) PseudoElement {
	return match pseudo_element {
		.after { .after }
		.backdrop { .backdrop }
		.before { .before }
		.details_content { .details_content }
		.file_selector_button { .file_selector_button }
		.first_letter { .first_letter }
		.first_line { .first_line }
		.marker { .marker }
		.part { .part }
		.placeholder { .placeholder }
		.selection { .selection }
		.slider_fill { .slider_fill }
		.slider_thumb { .slider_thumb }
		.slider_track { .slider_track }
		.slotted { .slotted }
		.view_transition { .view_transition }
		.view_transition_group { .view_transition_group }
		.view_transition_image_pair { .view_transition_image_pair }
		.view_transition_new { .view_transition_new }
		.view_transition_old { .view_transition_old }
		.highlight { .highlight }
		.target_text { .target_text }
		.spelling_error { .spelling_error }
		.grammar_error { .grammar_error }
		.search_text { .search_text }
		.known_pseudo_element_count { .known_pseudo_element_count }
		.unknown_webkit { .unknown_webkit }
	}
}

fn style_scope_pseudo_element_from_abstract_element(abstract_element dom.AbstractElement) ?PseudoElement {
	if pseudo := abstract_element.pseudo_element() {
		return style_scope_pseudo_element_from_dom(pseudo)
	}
	return none
}

fn style_scope_mut_shadow_root_option(root ?&dom.ShadowRoot) ?&dom.ShadowRoot {
	if value := root {
		return unsafe { &dom.ShadowRoot(value) }
	}
	return none
}

fn style_scope_mut_css_rule(rule &CSSRule) &CSSRule {
	return unsafe { &CSSRule(rule) }
}

fn style_scope_mut_css_style_sheet(sheet &CSSStyleSheet) &CSSStyleSheet {
	return unsafe { &CSSStyleSheet(sheet) }
}

fn style_scope_optional_shadow_root_equal(left ?&dom.ShadowRoot, right ?&dom.ShadowRoot) bool {
	if left == none && right == none {
		return true
	}
	if l := left {
		if r := right {
			return voidptr(l) == voidptr(r)
		}
	}
	return false
}

fn style_scope_shadow_root_has_value(value ?&dom.ShadowRoot) bool {
	if _ := value {
		return true
	}
	return false
}

fn style_scope_shadow_root_is_none(value ?&dom.ShadowRoot) bool {
	return !style_scope_shadow_root_has_value(value)
}

fn style_scope_filter_namespace_rule(element_namespace_uri ?string, rule &MatchingRule) bool {
	if default_namespace := rule.default_namespace {
		if element_namespace := element_namespace_uri {
			return element_namespace == default_namespace
		}
		return false
	}
	return true
}

fn style_scope_add_rule_to_run(style_computer &StyleComputer, abstract_element dom.AbstractElement, rule_to_run &MatchingRule, rule_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	// FIXME: This needs to be revised when adding support for the ::shadow
	// selector, as it needs to cross shadow boundaries.
	from_user_agent_or_user_stylesheet := rule_to_run.cascade_origin == .user_agent || rule_to_run.cascade_origin == .user

	// NOTE: Inside shadow trees, we only match rules that are defined in the
	// shadow tree's style sheets. Exceptions are:
	// - the shadow tree's shadow host, which needs to match :host rules from
	//   inside the shadow root.
	// - ::slotted() rules, which need to match elements assigned to slots from
	//   inside the shadow root.
	// - UA or User style sheets don't have a scope, so they are always relevant.
	mut rule_is_relevant_for_current_scope := style_scope_optional_shadow_root_equal(rule_root, shadow_root)
	if shadow_root_for_element := element_shadow_root {
		rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope || style_scope_optional_shadow_root_equal(rule_root, shadow_root_for_element)
	}
	rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope || from_user_agent_or_user_stylesheet || rule_to_run.slotted || rule_to_run.contains_part_pseudo_element
	if root := shadow_root {
		rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope || (style_scope_shadow_root_is_none(rule_root) && root.uses_document_style_sheets())
	}

	if !rule_is_relevant_for_current_scope {
		return
	}

	selector := rule_to_run.selector
	if selector.can_use_ancestor_filter() && style_computer.should_reject_with_ancestor_filter(selector) {
		return
	}

	_ = abstract_element
	rules_to_run << ScopedMatchingRule{
		rule: rule_to_run
		shadow_root: style_scope_mut_shadow_root_option(rule_root)
	}
}

fn style_scope_selector_targets_pseudo_element(selector Selector, pseudo_element PseudoElement) bool {
	// Read the same retained target as the public accessor without copying its payload.
	if selector.data_ == unsafe { nil } {
		return false
	}
	if target := selector.data_.pseudo_element {
		return target.type_ == pseudo_element
	}
	return false
}

fn style_scope_add_rules_to_run(style_computer &StyleComputer, abstract_element dom.AbstractElement, rules []&MatchingRule, rule_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	if rules.len == 0 {
		return
	}
	element_namespace_uri := abstract_element.element().namespace_uri()
	if queried_pseudo_element := style_scope_pseudo_element_from_abstract_element(abstract_element) {
		for rule in rules {
			// Only selectors targeting the queried pseudo-element can match. This avoids
			// evaluating ordinary selectors and selectors for a different pseudo-element.
			// FIXME: Once exportparts can forward pseudo-elements as parts, a bare
			// ::part(name) rule may need to match a different pseudo-element type.
			if !style_scope_selector_targets_pseudo_element(rule.selector, queried_pseudo_element) {
				continue
			}
			if !style_scope_filter_namespace_rule(element_namespace_uri, rule) {
				continue
			}
			style_scope_add_rule_to_run(style_computer, abstract_element, rule, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
		}
	} else {
		for rule in rules {
			if (rule.slotted || rule.contains_part_pseudo_element || !rule.contains_pseudo_element) && style_scope_filter_namespace_rule(element_namespace_uri, rule) {
				style_scope_add_rule_to_run(style_computer, abstract_element, rule, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
			}
		}
	}
}

fn style_scope_matching_slot_element(slot &dom.HTMLSlotElement) &dom.Element {
	// Stands in for C++ static_cast<HTML::HTMLSlotElement const&> as an Element.
	return unsafe { &dom.Element(slot) }
}

fn style_scope_slot_node(slot &dom.HTMLSlotElement) &dom.Node {
	// Stands in for the DOM helper that exposes HTMLSlotElement as a Node.
	return unsafe { &dom.Node(slot) }
}

fn style_scope_has_result_cache_boundary(style_computer &StyleComputer) &HasResultCache {
	// Share the map header as well as its storage. A shallow map copy retains
	// stale length/capacity and allocation pointers when another context grows
	// the cache. A heap-owned holder keeps every match and style-pass reset on
	// the same map without cloning its entries for each selector.
	return style_computer.has_result_cache_
}

fn style_scope_merge_attempted_pseudo_class_matches(mut attempted PseudoClassBitmap, context &MatchContext) {
	attempted.merge(context.attempted_pseudo_class_matches)
}

fn style_scope_add_slotted_rules_for_available_scopes(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, qualified_layer_name ?string, scope &StyleScope, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	_ = scope
	// Walk up the slot chain for nested slots. An element can be assigned to a
	// slot which is itself assigned to another slot in a parent shadow root. The
	// ::slotted() pseudo-element matches elements assigned "after flattening", so
	// we must collect slotted rules from every shadow root in the chain.
	mut slot := abstract_element.element().as_node().assigned_slot_internal()
	for {
		current_slot := slot or { break }
		slot_shadow_root := style_scope_slot_node(current_slot).root().as_shadow_root()
		if rule_cache := style_computer.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name, slot_shadow_root) {
			style_scope_add_rules_to_run(style_computer, abstract_element, rule_cache.slotted_rules, slot_shadow_root, shadow_root, element_shadow_root, mut rules_to_run)
		}
		slot = style_scope_slot_node(current_slot).assigned_slot_internal()
	}
}

fn style_scope_add_part_rules_from_scope(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, qualified_layer_name ?string, part_scope_shadow_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	if rule_cache := style_computer.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name, part_scope_shadow_root) {
		style_scope_add_rules_to_run(style_computer, abstract_element, rule_cache.part_rules, part_scope_shadow_root, shadow_root, element_shadow_root, mut rules_to_run)
	}
}

fn style_scope_add_part_rules_for_available_scopes(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, qualified_layer_name ?string, scope &StyleScope, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	_ = scope
	// ::part() can apply to anything in a shadow tree, that is either an element
	// with a `part` attribute or a pseudo-element. Rules from any ancestor style
	// scope can apply, including from the element's own shadow root (for
	// :host::part() within the shadow DOM's own stylesheet).
	if shadow_root == none {
		return
	}
	if style_scope_pseudo_element_from_abstract_element(abstract_element) == none && !abstract_element.element().has_part_names() {
		return
	}
	style_scope_add_part_rules_from_scope(style_computer, abstract_element, cascade_origin, qualified_layer_name, shadow_root, shadow_root, element_shadow_root, mut rules_to_run)
	for part_shadow_root in style_scope_flat_tree_ancestor_shadow_roots(abstract_element.element().as_node()) {
		style_scope_add_part_rules_from_scope(style_computer, abstract_element, cascade_origin, qualified_layer_name, part_shadow_root, shadow_root, element_shadow_root, mut rules_to_run)
	}
	style_scope_add_part_rules_from_scope(style_computer, abstract_element, cascade_origin, qualified_layer_name, none, shadow_root, element_shadow_root, mut rules_to_run)
}

fn style_scope_flat_tree_ancestor_shadow_roots(node &dom.Node) []&dom.ShadowRoot {
	mut roots := []&dom.ShadowRoot{}
	mut ancestor := node.flat_tree_parent()
	for {
		current := ancestor or { break }
		if shadow_root := current.as_shadow_root() {
			roots << shadow_root
		}
		ancestor = current.flat_tree_parent()
	}
	return roots
}

fn style_scope_elements_equal(left &dom.Element, right &dom.Element) bool {
	return voidptr(left) == voidptr(right)
}

fn style_scope_selector_list_matches_element(selectors SelectorList, element &dom.Element, subject &dom.Element, sheet ?&CSSStyleSheet, shadow_host ?&dom.Element, rule_root ?&dom.ShadowRoot, scope_root ?&dom.Element) bool {
	mut mutable_sheet := ?&CSSStyleSheet(none)
	if style_sheet := sheet {
		mutable_sheet = unsafe { &CSSStyleSheet(style_sheet) }
	}
	mut context := MatchContext{
		style_sheet_for_rule: mutable_sheet
		subject: unsafe { &dom.Element(subject) }
		collect_per_element_selector_involvement_metadata: true
	}
	if root := rule_root {
		context.rule_shadow_root = unsafe { &dom.ShadowRoot(root) }
	}
	mut scoping_root := ?&dom.ParentNode(none)
	if root := scope_root {
		scoping_root = unsafe { &dom.ParentNode(root) }
	}
	for selector in selectors.selectors {
		if matches(selector, element, shadow_host, mut context, none, scoping_root, .normal, none) {
			return true
		}
	}
	return false
}

fn style_scope_implicit_root(target &dom.Element, sheet ?&CSSStyleSheet, rule_root ?&dom.ShadowRoot) ?&dom.Element {
	if style_sheet := sheet {
		if owner := style_sheet.base.owner_node {
			if parent := owner.as_node().parent_element() {
				return parent
			}
		}
		if root := rule_root {
			return root.host()
		}
		if document := style_sheet.owning_document() {
			return document.document_element()
		}
	}
	root_node := target.as_node().root()
	if document := root_node.as_document() {
		return document.document_element()
	}
	if shadow_root := root_node.as_shadow_root() {
		return shadow_root.host()
	}
	return none
}

fn style_scope_find_root(scope_rule &CSSRule, target &dom.Element, sheet ?&CSSStyleSheet, shadow_host ?&dom.Element, rule_root ?&dom.ShadowRoot) ?&dom.Element {
	scope_style_sheet := if descriptor_sheet := scope_rule.parent_style_sheet {
		?&CSSStyleSheet(descriptor_sheet)
	} else {
		sheet
	}
	mut parent_scope_root := ?&dom.Element(none)
	if parent_scope_rule := scope_rule.parent_scope_rule() {
		parent_scope_root = style_scope_find_root(parent_scope_rule, target, sheet, shadow_host, rule_root)
		if parent_scope_root == none {
			return none
		}
	}

	mut mutable_scope_rule := unsafe { &CSSRule(scope_rule) }
	start_selectors := mutable_scope_rule.scope_start_selectors_for_matching() or {
		root := style_scope_implicit_root(target, scope_style_sheet, rule_root) or { return none }
		if !root.as_node().is_shadow_including_inclusive_ancestor_of(target.as_node()) {
			return none
		}
		if parent_root := parent_scope_root {
			if !parent_root.as_node().is_shadow_including_inclusive_ancestor_of(root.as_node()) {
				return none
			}
		}
		if style_scope_scope_limit_matches(scope_rule, root, target, scope_style_sheet, shadow_host, rule_root) {
			return none
		}
		return root
	}
	mut candidate := ?&dom.Element(target)
	for {
		current := candidate or { break }
		if parent_root := parent_scope_root {
			if !parent_root.as_node().is_shadow_including_inclusive_ancestor_of(current.as_node()) {
				break
			}
		}
		if style_scope_selector_list_matches_element(start_selectors, current, target, scope_style_sheet, shadow_host, rule_root, parent_scope_root)
			&& !style_scope_scope_limit_matches(scope_rule, current, target, scope_style_sheet, shadow_host, rule_root) {
			return current
		}
		candidate = current.as_node().parent_or_shadow_host_element()
	}
	return none
}

fn style_scope_scope_limit_matches(scope_rule &CSSRule, scope_root &dom.Element, target &dom.Element, sheet ?&CSSStyleSheet, shadow_host ?&dom.Element, rule_root ?&dom.ShadowRoot) bool {
	scope_style_sheet := if descriptor_sheet := scope_rule.parent_style_sheet {
		?&CSSStyleSheet(descriptor_sheet)
	} else {
		sheet
	}
	mut mutable_scope_rule := unsafe { &CSSRule(scope_rule) }
	end_selectors := mutable_scope_rule.scope_end_selectors_for_matching() or { return false }
	mut candidate := ?&dom.Element(target)
	for {
		current := candidate or { break }
		if style_scope_selector_list_matches_element(end_selectors, current, target, scope_style_sheet, shadow_host, rule_root, scope_root) {
			return true
		}
		if style_scope_elements_equal(current, scope_root) {
			break
		}
		candidate = current.as_node().parent_or_shadow_host_element()
	}
	return false
}

fn style_scope_root_for_matching_rule(rule &MatchingRule, target &dom.Element, shadow_host ?&dom.Element, rule_root ?&dom.ShadowRoot) ?&dom.Element {
	scope_rule := rule.scope_rule or { return none }
	return style_scope_find_root(scope_rule, target, rule.sheet, shadow_host, rule_root)
}

fn style_scope_proximity(target &dom.Element, root &dom.Element) int {
	mut proximity := 0
	mut candidate := ?&dom.Element(target)
	for {
		current := candidate or { return int(0x3fffffff) }
		if style_scope_elements_equal(current, root) {
			return proximity
		}
		proximity++
		candidate = current.as_node().parent_or_shadow_host_element()
	}
	return int(0x3fffffff)
}

// Consume the same ordered candidate buckets as matching_rule_buckets(),
// without allocating a temporary array of borrowed array headers.
fn style_scope_add_cached_rules_to_run(style_computer &StyleComputer, abstract_element dom.AbstractElement, cache &RuleCache, rule_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	selected := pseudo_subject_rule_cache(cache, abstract_element) or { return }
	style_scope_add_subject_rules_to_run(style_computer, abstract_element, selected, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
}

fn style_scope_add_subject_rules_to_run(style_computer &StyleComputer, abstract_element dom.AbstractElement, cache &RuleCache, rule_root ?&dom.ShadowRoot, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []ScopedMatchingRule) {
	// Empty buckets cannot contribute candidates or require element metadata.
	element := abstract_element.element()
	if cache.rules_by_class.len > 0 {
		for original_class_name in element.classes {
			class_name := cache.selector_name_bucket_key(original_class_name)
			if bucket := borrowed_string_rule_bucket(cache.rules_by_class, class_name) {
				style_scope_add_rules_to_run(style_computer, abstract_element, bucket, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
			}
		}
	}
	if cache.rules_by_id.len > 0 {
		if original_id := element.id() {
			id := cache.selector_name_bucket_key(original_id)
			if bucket := borrowed_string_rule_bucket(cache.rules_by_id, id) {
				style_scope_add_rules_to_run(style_computer, abstract_element, bucket, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
			}
		}
	}
	if cache.rules_by_tag_name.len > 0 {
		tag_name := element.lowercased_local_name()
		if bucket := borrowed_string_rule_bucket(cache.rules_by_tag_name, tag_name) {
			style_scope_add_rules_to_run(style_computer, abstract_element, bucket, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
		}
	}
	if cache.rules_by_pseudo_element.len > 0 {
		if pseudo := style_scope_pseudo_element_from_abstract_element(abstract_element) {
			if is_known_pseudo_element_type(pseudo) {
				if bucket := borrowed_pseudo_rule_bucket(cache.rules_by_pseudo_element, pseudo) {
					style_scope_add_rules_to_run(style_computer, abstract_element, bucket, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
				}
			} else {
				// NOTE: We don't cache rules for unknown pseudo-elements. They can't
				// match anything anyway.
			}
		}
	}

	if cache.root_rules.len > 0 && element.is_document_element() {
		style_scope_add_rules_to_run(style_computer, abstract_element, cache.root_rules, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
	}

	if cache.rules_by_attribute_name.len > 0 {
		if attrs := element.attributes_ {
			for attribute in attrs.attrs {
				name := rule_cache_attribute_bucket_name(attribute.name())
				if bucket := borrowed_string_rule_bucket(cache.rules_by_attribute_name, name) {
					style_scope_add_attribute_bucket_rules_to_run(style_computer, abstract_element, name, bucket, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
				}
			}
		}
	}

	style_scope_add_masked_other_rules(style_computer, abstract_element, cache, rule_root, shadow_root, element_shadow_root, mut rules_to_run)
}

pub fn style_computer_collect_matching_rules_in_scope(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, mut attempted_pseudo_class_matches PseudoClassBitmap, qualified_layer_name ?string, scope &StyleScope) []ScopedMatchingRule {
	return collect_matching_rules_with_storage(style_computer, abstract_element, cascade_origin,
		mut attempted_pseudo_class_matches, qualified_layer_name, scope, unsafe { nil })
}

fn collect_matching_rules_with_storage(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, mut attempted_pseudo_class_matches PseudoClassBitmap, qualified_layer_name ?string, scope &StyleScope, storage &platform.Arena) []ScopedMatchingRule {
	diagnostic_scope_start := begin_diagnostic_instruction_scope()
	defer { record_diagnostic_instruction_scope(3, diagnostic_scope_start) }

	scope.build_rule_cache_if_needed()

	root_node := abstract_element.element().as_node().root()
	shadow_root := root_node.as_shadow_root()
	element_shadow_root := abstract_element.element().shadow_root()
	scope_rule_root := if scope_node := scope.node {
		scope_node.as_shadow_root()
	} else {
		?&dom.ShadowRoot(none)
	}

	mut shadow_host := ?&dom.Element(none)
	if element_shadow_root != none {
		shadow_host = abstract_element.element()
	} else if root := shadow_root {
		shadow_host = root.host()
	}

	primary_cache := scope.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name)
	subject_node := abstract_element.element().as_node()
	// In the ordinary document tree there are no host, slot or part scopes
	// which could contribute a rule after an empty primary lookup.
	if !disable_pseudo_subject_rule_index && shadow_root == none && element_shadow_root == none
		&& subject_node.assigned_slot_internal() == none {
		if cache := primary_cache {
			if pseudo_subject_rule_cache(cache, abstract_element) == none { return []ScopedMatchingRule{} }
		} else {
			return []ScopedMatchingRule{}
		}
	}
	mut candidate_buffer := style_computer.acquire_matching_rule_candidates()
	mut rules_to_run := unsafe { candidate_buffer.rules }
	defer {
		style_computer.release_matching_rule_candidates(mut candidate_buffer, rules_to_run)
	}
	subject_is_reslotted_slot := subject_node.is_html_slot_element()
		&& subject_node.root().is_shadow_root()
	if rule_cache := primary_cache {
		style_scope_add_cached_rules_to_run(style_computer, abstract_element, rule_cache, scope_rule_root, shadow_root, element_shadow_root, mut rules_to_run)
	}
	// A shadow host also participates in the author scope of its own shadow
	// root, where :host and :host(...) rules are declared. Its ordinary tree
	// root (and therefore its primary style scope) is still the document or an
	// enclosing shadow root, so collect the host's own scope explicitly.
	if cascade_origin == .author {
		if own_root := element_shadow_root {
			own_scope := css_style_scope_for_shadow_root(own_root)
			if voidptr(own_scope) != voidptr(scope) {
				if own_cache := own_scope.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name) {
					style_scope_add_cached_rules_to_run(style_computer, abstract_element, own_cache, own_root, shadow_root, element_shadow_root, mut rules_to_run)
				}
			}
		}
	}

	if !subject_is_reslotted_slot {
		style_scope_add_slotted_rules_for_available_scopes(style_computer, abstract_element, cascade_origin, qualified_layer_name, scope, shadow_root, element_shadow_root, mut rules_to_run)
	}
	style_scope_add_part_rules_for_available_scopes(style_computer, abstract_element, cascade_origin, qualified_layer_name, scope, shadow_root, element_shadow_root, mut rules_to_run)

 record_diagnostic_instruction_scope(12, diagnostic_scope_start)
	// No selector can match when all ordinary, host, slot and part paths
	// produced no candidates. Keep the scratch-release defer, but avoid
	// constructing the per-match memo map for this empty result.
	if rules_to_run.len == 0 {
		return []ScopedMatchingRule{}
	}
 diagnostic_matches_start := begin_diagnostic_instruction_scope()
 defer { record_diagnostic_instruction_scope(13, diagnostic_matches_start) }

	mut matching_rules := []ScopedMatchingRule{}
	mut repeated_rule_matches := RepeatedRuleMatchMemo{}
	if disable_lazy_repeated_rule_memo {
		repeated_rule_matches.entries = map[u64]RepeatedRuleMatch{}
	}
	for scoped_rule_to_run in rules_to_run {
		// NOTE: When matching an element that is itself a shadow host against a
		// rule from outside its own shadow root, we must not use the element as
		// the shadow host for traversal (which would confine traversal to the
		// element itself). Instead, use the rule's shadow root's host, so that
		// combinators can traverse up to the enclosing shadow host (e.g. for
		// `:host(...) .descendant` selectors).
		rule_to_run := scoped_rule_to_run.rule
		rule_root := scoped_rule_to_run.shadow_root
		if container_rule := rule_to_run.container_rule {
			if !container_rule.container_rule_contains_size_feature()
				&& !container_rule.container_rule_contains_style_feature()
				&& !container_rule.container_rule_contains_scroll_state_feature()
				&& !container_rule.container_rule_matches(abstract_element) {
				continue
			}
		}
		mut shadow_host_to_use := shadow_host
		if abstract_element.element().is_shadow_host() && !style_scope_optional_shadow_root_equal(rule_root, abstract_element.element().shadow_root()) {
			if root := rule_root {
				shadow_host_to_use = root.host()
			} else {
				shadow_host_to_use = none
			}
		}

		selector := rule_to_run.selector
		mut rule_shadow_root_for_context := ?&dom.ShadowRoot(none)
		if root := rule_root {
			rule_shadow_root_for_context = unsafe { &dom.ShadowRoot(root) }
		}
		// Matching is synchronous. Reuse the context allocation while resetting
		// every rule's subject, shadow traversal state and attempted metadata.
		candidate_buffer.context = MatchContext{
			style_sheet_for_rule: rule_to_run.sheet
			subject: abstract_element.element()
			pseudo_argument: abstract_element.pseudo_argument
			rule_shadow_root: rule_shadow_root_for_context
			collect_per_element_selector_involvement_metadata: true
			has_result_cache: style_scope_has_result_cache_boundary(style_computer)
		}
		mut selector_scope := ?&dom.ParentNode(none)
		mut resolved_scope_root := ?&dom.Element(none)
		if rule_to_run.scope_rule != none {
			scope_root := style_scope_root_for_matching_rule(rule_to_run, abstract_element.element(), shadow_host_to_use, rule_root) or { continue }
			resolved_scope_root = unsafe { &dom.Element(scope_root) }
			selector_scope = unsafe { &dom.ParentNode(scope_root) }
			if style_scope_elements_equal(scope_root, abstract_element.element())
				&& !selector.contains_pseudo_class(.scope)
				&& !selector.contains_the_nesting_selector() {
				continue
			}
		}

		mut did_match := false
		if selector.is_slotted() {
			if abstract_element.element().as_node().assigned_slot_internal() == none
				|| subject_is_reslotted_slot {
				style_scope_merge_attempted_pseudo_class_matches(mut attempted_pseudo_class_matches, candidate_buffer.context)
				continue
			}
			// We're collecting rules for element, which is assigned to a slot.
			// For ::slotted() matching, slot should be used as a subject instead
			// of element, while element itself is saved in matching context, so
			// selector engine could switch back to it when matching inside
			// ::slotted() argument. For nested slots, find the slot that lives in
			// the same shadow root as the rule.
			mut matching_slot := ?&dom.HTMLSlotElement(none)
			mut slot := abstract_element.element().as_node().assigned_slot_internal()
			for {
				current_slot := slot or { break }
				if style_scope_optional_shadow_root_equal(style_scope_slot_node(current_slot).root().as_shadow_root(), rule_root) {
					matching_slot = unsafe { &dom.HTMLSlotElement(current_slot) }
					break
				}
				slot = style_scope_slot_node(current_slot).assigned_slot_internal()
			}
			if actual_slot := matching_slot {
				candidate_buffer.context.slotted_element = abstract_element.element()
				matching_slot_element := style_scope_matching_slot_element(actual_slot)
				candidate_buffer.context.subject = matching_slot_element

				mut slot_shadow_host := ?&dom.Element(none)
				if slot_shadow_root := style_scope_slot_node(actual_slot).root().as_shadow_root() {
					slot_shadow_host = slot_shadow_root.host()
				}
				did_match = matches(selector, matching_slot_element, slot_shadow_host, mut candidate_buffer.context, PseudoElement.slotted, selector_scope, .normal, none)
			}
		} else if rule_to_run.scope_rule == none && rule_root == none
			&& shadow_host_to_use == none && !selector.has_part_pseudo_element() {
			did_match = match_repeated_rule_selector(selector, abstract_element.element(),
				style_scope_pseudo_element_from_abstract_element(abstract_element),
				mut candidate_buffer.context, mut repeated_rule_matches, storage)
		} else {
			did_match = matches(selector, abstract_element.element(), shadow_host_to_use, mut candidate_buffer.context, style_scope_pseudo_element_from_abstract_element(abstract_element), selector_scope, .normal, none)
		}

		style_scope_merge_attempted_pseudo_class_matches(mut attempted_pseudo_class_matches, candidate_buffer.context)
		if did_match {
			if container_rule := rule_to_run.container_rule {
				contains_size_feature := container_rule.container_rule_contains_size_feature()
				contains_style_feature := container_rule.container_rule_contains_style_feature()
				if contains_size_feature || contains_style_feature || container_rule.container_rule_contains_scroll_state_feature() {
					mut subject := unsafe { &dom.Element(abstract_element.element()) }
					if contains_size_feature {
						subject.set_style_depends_on_size_container_query()
					}
					if contains_style_feature {
						subject.set_style_depends_on_style_container_query()
					}
					if !container_rule.container_rule_matches(abstract_element) {
						continue
					}
				}
			}
			// Reserve a small first block only after a selector has matched. Keep
			// the allocation in the same owner as subsequent result growth.
			if matching_rules.len == 0 {
				capacity := if rules_to_run.len < 8 { rules_to_run.len } else { 8 }
				if storage == unsafe { nil } {
					matching_rules.ensure_cap(capacity)
				} else {
					mut arena := unsafe { &platform.Arena(storage) }
					entry := arena.enter()
					matching_rules.ensure_cap(capacity)
					arena.leave(entry)
				}
			}
			append_scoped_matching_rule(mut matching_rules, ScopedMatchingRule{
				rule: rule_to_run
				shadow_root: style_scope_mut_shadow_root_option(rule_root)
				resolved_scope_root: resolved_scope_root
				scope_proximity: if root := resolved_scope_root {
					style_scope_proximity(abstract_element.element(), root)
				} else {
					int(0x3fffffff)
				}
			}, storage)
		}
	}

	return matching_rules
}

pub fn style_computer_collect_matching_rules_without_scope_boundary(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, mut attempted_pseudo_class_matches PseudoClassBitmap, qualified_layer_name ?string) []ScopedMatchingRule {
	scope := css_style_scope_for(abstract_element)
	return style_computer_collect_matching_rules_in_scope(style_computer, abstract_element, cascade_origin, mut attempted_pseudo_class_matches, qualified_layer_name, scope)
}

fn matching_rule_less_than(left ScopedMatchingRule, right ScopedMatchingRule) bool {
	left_specificity := left.rule.specificity
	right_specificity := right.rule.specificity
	if left_specificity == right_specificity {
		if left.scope_proximity != right.scope_proximity {
			return left.scope_proximity > right.scope_proximity
		}
		if left.rule.style_sheet_index == right.rule.style_sheet_index {
			return left.rule.rule_index < right.rule.rule_index
		}
		return left.rule.style_sheet_index < right.rule.style_sheet_index
	}
	return left_specificity < right_specificity
}

pub fn sort_matching_rules(mut matching_rules []ScopedMatchingRule) {
	for i := 1; i < matching_rules.len; i++ {
		mut j := i
		for j > 0 && matching_rule_less_than(matching_rules[j], matching_rules[j - 1]) {
			tmp := matching_rules[j - 1]
			matching_rules[j - 1] = matching_rules[j]
			matching_rules[j] = tmp
			j--
		}
	}
}

pub fn style_computer_build_matching_rule_set_impl(style_computer &StyleComputer, abstract_element dom.AbstractElement, mut attempted_pseudo_class_matches PseudoClassBitmap, did_match_any_pseudo_element_rules &bool, mode ComputeStyleMode, scope &StyleScope) MatchingRuleSet {
	return build_matching_rule_set_with_storage(style_computer, abstract_element,
		mut attempted_pseudo_class_matches, did_match_any_pseudo_element_rules, mode, scope, unsafe { nil })
}

fn build_matching_rule_set_with_storage(style_computer &StyleComputer, abstract_element dom.AbstractElement, mut attempted_pseudo_class_matches PseudoClassBitmap, did_match_any_pseudo_element_rules &bool, mode ComputeStyleMode, scope &StyleScope, storage &platform.Arena) MatchingRuleSet {
	// First, we collect all the CSS rules whose selectors match `element`:
	mut matching_rule_set := MatchingRuleSet{}
	matching_rule_set.user_agent_rules = collect_matching_rules_with_storage(style_computer, abstract_element, .user_agent, mut attempted_pseudo_class_matches, none, scope, storage)
	sort_matching_rules(mut matching_rule_set.user_agent_rules)
	matching_rule_set.user_rules = collect_matching_rules_with_storage(style_computer, abstract_element, .user, mut attempted_pseudo_class_matches, none, scope, storage)
	sort_matching_rules(mut matching_rule_set.user_rules)

	// @layer-ed author rules
	for layer_name in scope.qualified_layer_names_in_order {
		mut layer_rules := collect_matching_rules_with_storage(style_computer, abstract_element, .author, mut attempted_pseudo_class_matches, layer_name, scope, storage)
		sort_matching_rules(mut layer_rules)
		append_matching_layer(mut matching_rule_set.author_rules, LayerMatchingRules{
			qualified_layer_name: layer_name
			rules: layer_rules
		}, storage)
	}
	// Un-@layer-ed author rules
	mut unlayered_author_rules := collect_matching_rules_with_storage(style_computer, abstract_element, .author, mut attempted_pseudo_class_matches, none, scope, storage)
	sort_matching_rules(mut unlayered_author_rules)
	append_matching_layer(mut matching_rule_set.author_rules, LayerMatchingRules{
		qualified_layer_name: ''
		rules: unlayered_author_rules
	}, storage)

	if mode == .create_pseudo_element_style_if_needed {
		mut author_rules_has_any_rules := false
		for layer in matching_rule_set.author_rules {
			if layer.rules.len != 0 {
				author_rules_has_any_rules = true
				break
			}
		}
		unsafe {
			*did_match_any_pseudo_element_rules = author_rules_has_any_rules || matching_rule_set.user_rules.len != 0 || matching_rule_set.user_agent_rules.len != 0
		}
	}

	return matching_rule_set
}

pub fn style_computer_invalidation_plan_for_properties_impl(properties []InvalidationProperty, scope &StyleScope) &InvalidationPlan {
	mut result := InvalidationPlan.create()
	style_invalidation_data := scope.style_invalidation_data or { return result }
	for property in properties {
		if plan := style_invalidation_data.plan_for_property(property) {
			result.include_all_from(plan)
			if result.invalidate_whole_subtree {
				break
			}
		}
	}
	return result
}

pub fn style_computer_invalidation_property_used_in_has_selector_impl(property InvalidationProperty, scope &StyleScope) bool {
	style_invalidation_data := scope.style_invalidation_data or { return true }
	match property.type_ {
		.id {
			if style_invalidation_data.ids_used_in_has_selectors[property.name()] {
				return true
			}
		}
		.class {
			if style_invalidation_data.class_names_used_in_has_selectors[property.name()] {
				return true
			}
		}
		.attribute {
			if style_invalidation_data.attribute_names_used_in_has_selectors[property.name()] {
				return true
			}
		}
		.tag_name {
			if style_invalidation_data.tag_names_used_in_has_selectors[property.name()] {
				return true
			}
		}
		.pseudo_class {
			if style_invalidation_data.pseudo_classes_used_in_has_selectors[property.pseudo_class] {
				return true
			}
		}
		else {}
	}

	return false
}

pub fn style_computer_rule_cache_for_cascade_origin_without_scope_boundary(style_computer &StyleComputer, cascade_origin CascadeOrigin, qualified_layer_name ?string, shadow_root ?&dom.ShadowRoot) ?&RuleCache {
	if root := shadow_root {
		scope := css_style_scope_for_shadow_root(root)
		return scope.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name)
	}
	if style_computer.document_ == unsafe { nil } {
		return none
	}
	scope := css_style_scope_for_document(style_computer.document_)
	return scope.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name)
}
