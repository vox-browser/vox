module css

import dom

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
		main:     RuleCache.new()
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
	has_has_selectors bool
}

pub fn StyleInvalidationData.new() &StyleInvalidationData {
	return &StyleInvalidationData{
		invalidation_plans:                    map[string]&InvalidationPlan{}
		invalidation_plan_properties:          map[string]InvalidationProperty{}
		ids_used_in_has_selectors:             map[string]bool{}
		class_names_used_in_has_selectors:     map[string]bool{}
		attribute_names_used_in_has_selectors: map[string]bool{}
		tag_names_used_in_has_selectors:       map[string]bool{}
		pseudo_classes_used_in_has_selectors:  map[CSSPseudoClass]bool{}
	}
}

pub fn RuleCache.new() &RuleCache {
	return &RuleCache{
		rules_by_id:                  map[string][]MatchingRule{}
		rules_by_class:               map[string][]MatchingRule{}
		rules_by_tag_name:            map[string][]MatchingRule{}
		rules_by_attribute_name:      map[string][]MatchingRule{}
		rules_by_pseudo_element:      map[PseudoElement][]MatchingRule{}
		rules_by_animation_keyframes: map[string]bool{}
	}
}

fn style_scope_push_rule(mut bucket map[string][]MatchingRule, key string, matching_rule MatchingRule) {
	mut rules := bucket[key] or { []MatchingRule{} }
	rules << matching_rule
	bucket[key] = rules
}

fn style_scope_push_pseudo_element_rule(mut bucket map[PseudoElement][]MatchingRule, key PseudoElement, matching_rule MatchingRule) {
	mut rules := bucket[key] or { []MatchingRule{} }
	rules << matching_rule
	bucket[key] = rules
}

pub fn (rule MatchingRule) visit_edges() {
	// C++ traces shadow_root/rule/sheet for LibGC. V references are handled by
	// the translated runtime, so this is intentionally a no-op.
	_ = rule
}

pub fn (cache &RuleCache) visit_edges() {
	// C++ walks all rule vectors and animation keyframe sets for LibGC. The V
	// port does not expose a CSS GC visitor here yet.
	_ = cache
}

pub fn (rule MatchingRule) declaration() ?&CSSStyleProperties {
	css_rule := rule.rule or { return none }
	if css_rule.type_ == .style || css_rule.type_ == .nested_declarations {
		return css_rule.style()
	}
	return none
}

pub fn (rule MatchingRule) absolutized_selectors() SelectorList {
	css_rule := rule.rule or { return SelectorList{
		selectors: [rule.selector]
	} }

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

pub fn (rule MatchingRule) qualified_layer_name() string {
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

	pseudo_class := simple_selector.pseudo_class
	if pseudo_class.type_ != .is_ && pseudo_class.type_ != .where {
		return none
	}

	if pseudo_class.argument_selector_list.selectors.len != 1 {
		return none
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
			name:  inner_simple_selector.name.name
		}
	}
	if inner_simple_selector.type_ == .tag_name {
		return SimplifiedSelectorForBucketing{
			type_: inner_simple_selector.type_
			name:  inner_simple_selector.qualified_name.name.lowercase_name
		}
	}
	return none
}

pub fn (mut cache RuleCache) add_rule(matching_rule MatchingRule, pseudo_element ?PseudoElement, contains_root_pseudo_class bool) {
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
		cache.other_rules << matching_rule
		return
	}
	last_compound_selector := compound_selectors[compound_selectors.len - 1]

	// NOTE: We traverse the simple selectors in reverse order to make sure that
	// class/ID buckets are preferred over tag buckets in the common case of
	// div.foo or div#foo selectors.
	for i := last_compound_selector.simple_selectors.len - 1; i >= 0; i-- {
		simple_selector := last_compound_selector.simple_selectors[i]
		if simple_selector.type_ == .id {
			style_scope_push_rule(mut cache.rules_by_id, simple_selector.name.name, matching_rule)
			return
		}
		if simple_selector.type_ == .class {
			style_scope_push_rule(mut cache.rules_by_class, simple_selector.name.name,
				matching_rule)
			return
		}
		if simple_selector.type_ == .tag_name {
			style_scope_push_rule(mut cache.rules_by_tag_name,
				simple_selector.qualified_name.name.lowercase_name, matching_rule)
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
				style_scope_push_rule(mut cache.rules_by_class, simplified.name, matching_rule)
				return
			}
			if simplified.type_ == .id {
				style_scope_push_rule(mut cache.rules_by_id, simplified.name, matching_rule)
				return
			}
		}
	}

	if matching_rule.contains_pseudo_element {
		if pseudo := pseudo_element {
			if is_known_pseudo_element_type(pseudo) {
				style_scope_push_pseudo_element_rule(mut cache.rules_by_pseudo_element, pseudo,
					matching_rule)
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
				style_scope_push_rule(mut cache.rules_by_attribute_name,
					simple_selector.attribute.qualified_name.name.lowercase_name, matching_rule)
				return
			}
		}
		cache.other_rules << matching_rule
	}
}

pub fn (cache &RuleCache) matching_rule_buckets(abstract_element dom.AbstractElement) [][]MatchingRule {
	element := abstract_element.element()
	mut buckets := [][]MatchingRule{}
	for class_name in element.classes {
		if class_name in cache.rules_by_class {
			buckets << (cache.rules_by_class[class_name] or { []MatchingRule{} })
		}
	}
	if id := element.id() {
		if id in cache.rules_by_id {
			buckets << (cache.rules_by_id[id] or { []MatchingRule{} })
		}
	}
	tag_name := element.lowercased_local_name()
	if tag_name in cache.rules_by_tag_name {
		buckets << (cache.rules_by_tag_name[tag_name] or { []MatchingRule{} })
	}
	if pseudo := style_scope_pseudo_element_from_abstract_element(abstract_element) {
		if is_known_pseudo_element_type(pseudo) {
			if pseudo in cache.rules_by_pseudo_element {
				buckets << (cache.rules_by_pseudo_element[pseudo] or { []MatchingRule{} })
			}
		} else {
			// NOTE: We don't cache rules for unknown pseudo-elements. They can't
			// match anything anyway.
		}
	}

	if element.is_document_element() {
		buckets << cache.root_rules
	}

	mut attribute_buckets := [][]MatchingRule{}
	element.for_each_attribute(fn [cache, mut attribute_buckets] (attribute &dom.Attr_) {
		name := attribute.name().to_lower()
		if name in cache.rules_by_attribute_name {
			attribute_buckets << (cache.rules_by_attribute_name[name] or { []MatchingRule{} })
		}
	})
	buckets << attribute_buckets

	buckets << cache.other_rules
	return buckets
}

pub fn (cache &RuleCache) for_each_matching_rules(abstract_element dom.AbstractElement, callback fn ([]MatchingRule) RuleCacheIterationDecision) {
	for bucket in cache.matching_rule_buckets(abstract_element) {
		if callback(bucket) == .break_ {
			return
		}
	}
}

pub fn StyleScope.new(node &dom.Node) &StyleScope {
	mut scope := &StyleScope{
		node: node
	}
	scope.qualified_layer_names_in_order << ''
	return scope
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
	return scope.author_rule_cache != none
}

pub fn (mut scope StyleScope) build_rule_cache() {
	scope.author_rule_cache = RuleCaches.new()
	scope.user_rule_cache = RuleCaches.new()
	scope.user_agent_rule_cache = RuleCaches.new()

	scope.selector_insights = &SelectorInsights{}
	scope.style_invalidation_data = StyleInvalidationData.new()

	if document := scope.document() {
		if user_style_source := style_scope_user_style_source_boundary(document) {
			scope.user_style_sheet = parse_css_stylesheet_with_parser(user_style_source, none)
		}
	}

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
}

pub fn (mut scope StyleScope) invalidate_rule_cache() {
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
}

pub fn (scope &StyleScope) build_rule_cache_if_needed() {
	if scope.has_valid_rule_cache() {
		return
	}
	mut mutable_scope := unsafe { &StyleScope(scope) }
	mutable_scope.build_rule_cache()
}

fn style_scope_user_agent_stylesheet(name string) ?&CSSStyleSheet {
	source := user_agent_style_sheet_source(name) or { return none }
	return parse_css_stylesheet_with_parser(source, none)
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
		}
		.user {
			if sheet := scope.user_style_sheet {
				sheets << sheet
			}
		}
		.author {
			style_scope_for_each_active_css_style_sheet_boundary(scope, fn [mut sheets] (sheet &CSSStyleSheet) {
				sheets << sheet
			})
		}
		else {}
	}

	return sheets
}

pub fn (scope &StyleScope) for_each_stylesheet(cascade_origin CascadeOrigin, callback fn (&CSSStyleSheet)) {
	for sheet in scope.stylesheets_for_cascade_origin(cascade_origin) {
		callback(sheet)
	}
}

pub fn (mut scope StyleScope) make_rule_cache_for_cascade_origin(cascade_origin CascadeOrigin, insights &SelectorInsights) {
	mut scope_shadow_root := ?&dom.ShadowRoot(none)
	if node := scope.node {
		scope_shadow_root = node.as_shadow_root()
	}
	mut mutable_insights := unsafe { &SelectorInsights(insights) }

	mut style_sheet_index := usize(0)
	for sheet in scope.stylesheets_for_cascade_origin(cascade_origin) {
		mut rule_caches := scope.rule_caches_for_origin_mut(cascade_origin) or { continue }
		mut rule_index := usize(0)
		sheet.for_each_effective_style_producing_rule(fn [mut scope, mut rule_caches, sheet, cascade_origin, scope_shadow_root, mut mutable_insights, mut rule_index, style_sheet_index] (rule &CSSRule) {
			absolutized_selectors := style_scope_absolutized_selectors_for_rule(rule)
			if style_invalidation_data := scope.style_invalidation_data {
				mut mutable_invalidation_data := unsafe { &StyleInvalidationData(style_invalidation_data) }
				for selector in absolutized_selectors.selectors {
					mutable_invalidation_data.build_invalidation_sets_for_selector(selector)
				}
			}

			for selector in absolutized_selectors.selectors {
				mut matching_rule := MatchingRule{
					shadow_root:       style_scope_mut_shadow_root_option(scope_shadow_root)
					rule:              style_scope_mut_css_rule(rule)
					sheet:             style_scope_mut_css_style_sheet(sheet)
					default_namespace: sheet.default_namespace()
					selector:          selector
					style_sheet_index: style_sheet_index
					rule_index:        rule_index
					specificity:       selector.specificity()
					cascade_origin:    cascade_origin
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
								pseudo_element = simple_selector.pseudo_element.type_
								matching_rule.slotted = simple_selector.pseudo_element.type_ == .slotted
								matching_rule.contains_part_pseudo_element = simple_selector.pseudo_element.type_ == .part
							}
						}
						if !contains_root_pseudo_class {
							if simple_selector.type_ == .pseudo_class
								&& simple_selector.pseudo_class.type_ == .root {
								contains_root_pseudo_class = true
							}
						}
					}
				}

				for pseudo_class in style_scope_pseudo_classes_with_rule_cache() {
					mut pseudo_class_cache := scope.pseudo_class_rule_cache[pseudo_class] or {
						continue
					}
					if selector.contains_pseudo_class(pseudo_class) {
						// For pseudo class rule caches we intentionally pass no
						// pseudo-element, because we don't want to bucket pseudo
						// class rules by pseudo-element type.
						pseudo_class_cache.add_rule(matching_rule, none, contains_root_pseudo_class)
					}
				}

				rule_cache.add_rule(matching_rule, pseudo_element, contains_root_pseudo_class)
			}
			rule_index++
		})

		// Loosely based on https://drafts.csswg.org/css-animations-2/#keyframe-processing
		sheet.for_each_effective_keyframes_at_rule(fn [mut rule_caches] (rule &CSSRule) {
			style_scope_add_keyframes_rule_to_cache(mut rule_caches.main, rule)
		})
		style_sheet_index++
	}
}

fn style_scope_keyframe_property_value(property CSSStyleProperty, property_id PropertyID) ?&dom.StyleValue {
	if value := property.style_value {
		return value
	}
	return parse_css_value(ParsingParams{}, property.value, property_id)
}

fn style_scope_keyframe_property_is_animatable(property_id PropertyID) bool {
	return match property_id {
		.color { true }
		else { false }
	}
}

fn style_scope_resolve_keyframe_set_from_rule(rule &CSSRule) &KeyFrameSet {
	mut keyframe_set := &KeyFrameSet{
		keyframes_by_key: map[int]ResolvedKeyFrame{}
	}
	mut animated_properties := map[PropertyID]bool{}
	rules := rule.css_rules() or { return keyframe_set }

	// Forwards pass, resolve all the user-specified keyframe properties.
	for keyframe_rule in rules.rules {
		if keyframe_rule.type_ != .keyframe {
			continue
		}
		keyframe_key := keyframe_rule.keyframe_key or { continue }
		key := int(keyframe_key.value() * animation_key_frame_key_scale_factor)
		keyframe_style := keyframe_rule.style() or { continue }
		mut resolved_keyframe := ResolvedKeyFrame{
			properties: map[PropertyID]&dom.StyleValue{}
		}

		for property in keyframe_style.properties {
			property_id := property_id_from_string(property.name) or { continue }

			if property_id == .animation_timeline {
				// Boundary: the current V PropertyID set does not contain
				// animation-timing-function or animation-composition yet, so the
				// C++ easing/composite special cases cannot be represented here.
				continue
			}
			if !style_scope_keyframe_property_is_animatable(property_id) {
				continue
			}

			property_value := style_scope_keyframe_property_value(property, property_id) or { continue }
			// Unresolved properties will be resolved in collect_animation_into()
			StyleComputer.for_each_property_expanding_shorthands(property_id, property_value, fn [mut animated_properties, mut resolved_keyframe] (shorthand_id PropertyID, shorthand_value &dom.StyleValue) {
				animated_properties[shorthand_id] = true
				resolved_keyframe.properties[shorthand_id] = unsafe { shorthand_value }
			})
		}

		if key !in keyframe_set.keyframes_by_key {
			keyframe_set.keyframes_by_key[key] = resolved_keyframe
		}
	}

	style_scope_generate_initial_and_final_keyframes(mut keyframe_set, animated_properties)
	return keyframe_set
}

fn style_scope_generate_initial_and_final_keyframes(mut keyframe_set KeyFrameSet, animated_properties map[PropertyID]bool) {
	_ = keyframe_set
	_ = animated_properties
	// Boundary: Animations::KeyframeEffect::generate_initial_and_final_frames()
	// needs the animated element's computed style in the full engine. This cache
	// builder only has the @keyframes rule, so it preserves user-specified frames
	// and leaves synthesized 0%/100% values to the animation application path.
}

fn style_scope_add_keyframes_rule_to_cache(mut rule_cache RuleCache, rule &CSSRule) {
	if rule.type_ != .keyframes {
		return
	}
	keyframe_set := style_scope_resolve_keyframe_set_from_rule(rule)
	_ = keyframe_set
	// Boundary: RuleCache::rules_by_animation_keyframes is still map[string]bool
	// in the shared V type, while C++ stores KeyFrameSet. Mark the rule as
	// present here; callers can switch this to the resolved set once the shared
	// RuleCache field is widened.
	rule_cache.rules_by_animation_keyframes[rule.keyframes_name()] = true
}

fn (mut scope StyleScope) rule_caches_for_origin_mut(cascade_origin CascadeOrigin) ?&RuleCaches {
	match cascade_origin {
		.author { return scope.author_rule_cache }
		.user { return scope.user_rule_cache }
		.user_agent { return scope.user_agent_rule_cache }
		else { return none }
	}
}

fn (scope &StyleScope) rule_caches_for_origin(cascade_origin CascadeOrigin) ?&RuleCaches {
	match cascade_origin {
		.author { return scope.author_rule_cache }
		.user { return scope.user_rule_cache }
		.user_agent { return scope.user_agent_rule_cache }
		else { return none }
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
				if simple_selector.pseudo_class.type_ == .has {
					insights.has_has_selectors = true
				}
				for argument_selector in simple_selector.pseudo_class.argument_selector_list.selectors {
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

pub fn (scope &StyleScope) get_pseudo_class_rule_cache(pseudo_class PseudoClass) ?&RuleCache {
	scope.build_rule_cache_if_needed()
	return scope.pseudo_class_rule_cache[pseudo_class] or { return none }
}

pub fn (scope &StyleScope) for_each_active_css_style_sheet(callback fn (&CSSStyleSheet)) {
	style_scope_for_each_active_css_style_sheet_boundary(scope, callback)
}

pub fn (mut scope StyleScope) schedule_ancestors_style_invalidation_due_to_presence_of_has(node &dom.Node) {
	node_id := node.unique_id().value()
	for existing in scope.pending_nodes_for_style_invalidation_due_to_presence_of_has {
		if existing.unique_id().value() == node_id {
			if document := scope.document() {
				style_scope_set_needs_invalidation_of_elements_affected_by_has(document)
			}
			return
		}
	}
	scope.pending_nodes_for_style_invalidation_due_to_presence_of_has << node
	if document := scope.document() {
		style_scope_set_needs_invalidation_of_elements_affected_by_has(document)
	}
}

pub fn (mut scope StyleScope) invalidate_style_of_elements_affected_by_has() {
	if scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.len == 0 {
		return
	}

	nodes := scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.clone()
	scope.pending_nodes_for_style_invalidation_due_to_presence_of_has.clear()

	// It's ok to call have_has_selectors() instead of may_have_has_selectors()
	// here and force rule cache build, because it's going to be built soon
	// anyway, since we could get here only from update_style().
	if !scope.have_has_selectors() {
		return
	}

	mut elements_already_invalidated_for_has := map[i64]bool{}
	for node in nodes {
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

			element_id := element.as_node().unique_id().value()
			if elements_already_invalidated_for_has[element_id] {
				break
			}
			elements_already_invalidated_for_has[element_id] = true

			mut mutable_element := unsafe { &dom.Element(element) }
			mutable_element.invalidate_style_if_affected_by_has()

			parent := current.parent_or_shadow_host() or { return }

			// If any ancestor's sibling was tested against selectors like
			// ".a:has(+ .b)" or ".a:has(~ .b)" its style might be affected by
			// the change in descendant node.
			for child in parent.children {
				ancestor_sibling_element := child.as_element() or { continue }
				if ancestor_sibling_element.affected_by_has_pseudo_class_with_relative_selector_that_has_sibling_combinator {
					sibling_id := ancestor_sibling_element.as_node().unique_id().value()
					if elements_already_invalidated_for_has[sibling_id] {
						continue
					}
					elements_already_invalidated_for_has[sibling_id] = true
					mut mutable_sibling := unsafe { &dom.Element(ancestor_sibling_element) }
					mutable_sibling.invalidate_style_if_affected_by_has()
				}
			}

			ancestor = current.parent_or_shadow_host()
		}
	}
}

fn style_scope_pseudo_classes_with_rule_cache() []PseudoClass {
	return [.hover, .active, .focus, .focus_within, .focus_visible, .target]
}

fn style_scope_absolutized_selectors_for_rule(rule &CSSRule) SelectorList {
	if rule.type_ == .style {
		mut mutable_rule := unsafe { &CSSRule(rule) }
		return mutable_rule.absolutized_selectors()
	}
	if rule.type_ == .nested_declarations {
		parent_style_rule := rule.parent_style_rule() or { return SelectorList{} }
		mut mutable_parent := unsafe { &CSSRule(parent_style_rule) }
		return mutable_parent.absolutized_selectors()
	}
	return SelectorList{}
}

fn style_scope_layer_block_internal_qualified_name(rule &CSSRule) ?string {
	internal_name := rule.layer_internal or { return none }
	mut mutable_rule := unsafe { &CSSRule(rule) }
	parent_name := mutable_rule.parent_layer_internal_qualified_name()
	if parent_name.len == 0 {
		return internal_name
	}
	return '${parent_name}.${internal_name}'
}

fn style_scope_layer_statement_internal_qualified_name_list(rule &CSSRule) []string {
	layer := rule.layer or { return []string{} }
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

fn style_scope_user_style_source_boundary(document &dom.Document) ?string {
	_ = document
	// Boundary for C++ document().page().user_style(). The V Page/UserStyle
	// plumbing is not connected to css.StyleScope yet.
	return none
}

fn style_scope_for_each_active_css_style_sheet_boundary(scope &StyleScope, callback fn (&CSSStyleSheet)) {
	_ = scope
	_ = callback
	// Boundary for C++ StyleScope::for_each_active_css_style_sheet(), which
	// calls DOM::ShadowRoot::for_each_active_css_style_sheet() or
	// DOM::Document::for_each_active_css_style_sheet(). DOM currently exposes
	// DOM-local CSSStyleSheet placeholders, not css.CSSStyleSheet objects.
}

fn style_scope_pseudo_element_from_dom(pseudo_element dom.PseudoElement) PseudoElement {
	return match pseudo_element {
		.before { .before }
		.after { .after }
		.first_line { .first_line }
		.first_letter { .first_letter }
		.marker { .marker }
		.placeholder { .placeholder }
		.selection { .selection }
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
			return l == r
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

fn style_scope_filter_namespace_rule(element_namespace_uri ?string, rule MatchingRule) bool {
	if default_namespace := rule.default_namespace {
		if element_namespace := element_namespace_uri {
			return element_namespace == default_namespace
		}
		return false
	}
	return true
}

fn style_scope_add_rule_to_run(style_computer &StyleComputer, abstract_element dom.AbstractElement, rule_to_run MatchingRule, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []MatchingRule) {
	// FIXME: This needs to be revised when adding support for the ::shadow
	// selector, as it needs to cross shadow boundaries.
	rule_root := rule_to_run.shadow_root
	from_user_agent_or_user_stylesheet := rule_to_run.cascade_origin == .user_agent
		|| rule_to_run.cascade_origin == .user

	// NOTE: Inside shadow trees, we only match rules that are defined in the
	// shadow tree's style sheets. Exceptions are:
	// - the shadow tree's shadow host, which needs to match :host rules from
	//   inside the shadow root.
	// - ::slotted() rules, which need to match elements assigned to slots from
	//   inside the shadow root.
	// - UA or User style sheets don't have a scope, so they are always relevant.
	mut rule_is_relevant_for_current_scope := style_scope_optional_shadow_root_equal(rule_root,
		shadow_root)
	if shadow_root_for_element := element_shadow_root {
		rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope
			|| style_scope_optional_shadow_root_equal(rule_root, shadow_root_for_element)
	}
	rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope
		|| from_user_agent_or_user_stylesheet || rule_to_run.slotted
		|| rule_to_run.contains_part_pseudo_element
	if root := shadow_root {
		rule_is_relevant_for_current_scope = rule_is_relevant_for_current_scope
			|| (style_scope_shadow_root_is_none(rule_root) && root.uses_document_style_sheets())
	}

	if !rule_is_relevant_for_current_scope {
		return
	}

	selector := rule_to_run.selector
	if selector.can_use_ancestor_filter()
		&& style_computer.should_reject_with_ancestor_filter(selector) {
		return
	}

	_ = abstract_element
	rules_to_run << rule_to_run
}

fn style_scope_add_rules_to_run(style_computer &StyleComputer, abstract_element dom.AbstractElement, rules []MatchingRule, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []MatchingRule) {
	element_namespace_uri := abstract_element.element().namespace_uri()
	if style_scope_pseudo_element_from_abstract_element(abstract_element) != none {
		for rule in rules {
			if rule.contains_pseudo_element
				&& style_scope_filter_namespace_rule(element_namespace_uri, rule) {
				style_scope_add_rule_to_run(style_computer, abstract_element, rule, shadow_root,
					element_shadow_root, mut rules_to_run)
			}
		}
	} else {
		for rule in rules {
			if (rule.slotted || rule.contains_part_pseudo_element || !rule.contains_pseudo_element)
				&& style_scope_filter_namespace_rule(element_namespace_uri, rule) {
				style_scope_add_rule_to_run(style_computer, abstract_element, rule, shadow_root,
					element_shadow_root, mut rules_to_run)
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

fn style_scope_has_result_cache_boundary(style_computer &StyleComputer) map[string]HasMatchResult {
	_ = style_computer
	// Boundary for StyleComputer::m_has_result_cache. computed_interpolation.v
	// still stores the cache as map[string]bool, while SelectorEngine's V
	// MatchContext expects map[string]HasMatchResult.
	return map[string]HasMatchResult{}
}

fn style_scope_merge_attempted_pseudo_class_matches(mut attempted PseudoClassBitmap, context MatchContext) {
	attempted.merge(context.attempted_pseudo_class_matches)
}

fn style_scope_add_slotted_rules_for_available_scopes(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, qualified_layer_name ?string, scope &StyleScope, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []MatchingRule) {
	_ = qualified_layer_name
	// Walk up the slot chain for nested slots. An element can be assigned to a
	// slot which is itself assigned to another slot in a parent shadow root. The
	// ::slotted() pseudo-element matches elements assigned "after flattening", so
	// we must collect slotted rules from every shadow root in the chain.
	mut slot := abstract_element.element().as_node().assigned_slot_internal()
	for {
		current_slot := slot or { break }
		slot_shadow_root := style_scope_slot_node(current_slot).root().as_shadow_root()
		if style_scope_shadow_root_matches_current_scope(scope, slot_shadow_root) {
			if rule_cache := scope.rule_cache_for_cascade_origin(cascade_origin,
				qualified_layer_name)
			{
				style_scope_add_rules_to_run(style_computer, abstract_element,
					rule_cache.slotted_rules, shadow_root, element_shadow_root, mut rules_to_run)
			}
		}
		slot = style_scope_slot_node(current_slot).assigned_slot_internal()
	}
}

fn style_scope_add_part_rules_for_available_scopes(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, qualified_layer_name ?string, scope &StyleScope, shadow_root ?&dom.ShadowRoot, element_shadow_root ?&dom.ShadowRoot, mut rules_to_run []MatchingRule) {
	// ::part() can apply to anything in a shadow tree, that is either an element
	// with a `part` attribute or a pseudo-element. Rules from any ancestor style
	// scope can apply, including from the element's own shadow root (for
	// :host::part() within the shadow DOM's own stylesheet).
	if shadow_root == none {
		return
	}
	if style_scope_pseudo_element_from_abstract_element(abstract_element) == none
		&& abstract_element.element().parts.len == 0 {
		return
	}
	if rule_cache := scope.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name) {
		style_scope_add_rules_to_run(style_computer, abstract_element, rule_cache.part_rules,
			shadow_root, element_shadow_root, mut rules_to_run)
	}
	for part_shadow_root in style_scope_flat_tree_ancestor_shadow_roots(abstract_element.element().as_node()) {
		if style_scope_shadow_root_matches_current_scope(scope, part_shadow_root) {
			if rule_cache := scope.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name) {
				style_scope_add_rules_to_run(style_computer, abstract_element, rule_cache.part_rules,
					shadow_root, element_shadow_root, mut rules_to_run)
			}
		}
	}
	// Boundary: C++ then also checks ancestor shadow-root style scopes and the
	// document style scope through StyleComputer::rule_cache_for_cascade_origin().
	// The V DOM currently exposes DOM-local StyleScope placeholders rather than
	// css.StyleScope, so this in-scope helper can only add caches reachable from
	// the StyleScope passed by the caller.
}

fn style_scope_shadow_root_matches_current_scope(scope &StyleScope, shadow_root ?&dom.ShadowRoot) bool {
	// Local fallback for obtaining shadow_root->style_scope(). If this StyleScope
	// was constructed with the same shadow root node, the current scope is
	// usable; otherwise DOM's StyleScope placeholder is not the css one.
	root := shadow_root or { return false }
	node := scope.node or { return false }
	scope_root := node.as_shadow_root() or { return false }
	return scope_root == root
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

pub fn style_computer_collect_matching_rules_in_scope(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, mut attempted_pseudo_class_matches PseudoClassBitmap, qualified_layer_name ?string, scope &StyleScope) []MatchingRule {
	scope.build_rule_cache_if_needed()

	root_node := abstract_element.element().as_node().root()
	shadow_root := root_node.as_shadow_root()
	element_shadow_root := abstract_element.element().shadow_root()

	mut shadow_host := ?&dom.Element(none)
	if element_shadow_root != none {
		shadow_host = abstract_element.element()
	} else if root := shadow_root {
		shadow_host = root.host()
	}

	mut rules_to_run := []MatchingRule{}
	if rule_cache := scope.rule_cache_for_cascade_origin(cascade_origin, qualified_layer_name) {
		for bucket in rule_cache.matching_rule_buckets(abstract_element) {
			style_scope_add_rules_to_run(style_computer, abstract_element, bucket, shadow_root,
				element_shadow_root, mut rules_to_run)
		}
	}

	style_scope_add_slotted_rules_for_available_scopes(style_computer, abstract_element,
		cascade_origin, qualified_layer_name, scope, shadow_root, element_shadow_root, mut
		rules_to_run)
	style_scope_add_part_rules_for_available_scopes(style_computer, abstract_element,
		cascade_origin, qualified_layer_name, scope, shadow_root, element_shadow_root, mut
		rules_to_run)

	mut matching_rules := []MatchingRule{}
	for rule_to_run in rules_to_run {
		// NOTE: When matching an element that is itself a shadow host against a
		// rule from outside its own shadow root, we must not use the element as
		// the shadow host for traversal (which would confine traversal to the
		// element itself). Instead, use the rule's shadow root's host, so that
		// combinators can traverse up to the enclosing shadow host (e.g. for
		// `:host(...) .descendant` selectors).
		rule_root := rule_to_run.shadow_root
		mut shadow_host_to_use := shadow_host
		if abstract_element.element().is_shadow_host()
			&& !style_scope_optional_shadow_root_equal(rule_root, abstract_element.element().shadow_root()) {
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
		mut context := MatchContext{
			style_sheet_for_rule:                              rule_to_run.sheet
			subject:                                           abstract_element.element()
			rule_shadow_root:                                  rule_shadow_root_for_context
			collect_per_element_selector_involvement_metadata: true
			has_result_cache:                                  style_scope_has_result_cache_boundary(style_computer)
		}

		mut did_match := false
		if selector.is_slotted() {
			if abstract_element.element().as_node().assigned_slot_internal() == none {
				style_scope_merge_attempted_pseudo_class_matches(mut attempted_pseudo_class_matches,
					context)
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
				if style_scope_optional_shadow_root_equal(style_scope_slot_node(current_slot).root().as_shadow_root(),
					rule_root)
				{
					matching_slot = unsafe { &dom.HTMLSlotElement(current_slot) }
					break
				}
				slot = style_scope_slot_node(current_slot).assigned_slot_internal()
			}
			if actual_slot := matching_slot {
				context.slotted_element = abstract_element.element()
				matching_slot_element := style_scope_matching_slot_element(actual_slot)
				context.subject = matching_slot_element

				mut slot_shadow_host := ?&dom.Element(none)
				if slot_shadow_root := style_scope_slot_node(actual_slot).root().as_shadow_root() {
					slot_shadow_host = slot_shadow_root.host()
				}
				did_match = matches(selector, matching_slot_element, slot_shadow_host, mut context,
					PseudoElement.slotted, none, .normal, none)
			}
		} else {
			did_match = matches(selector, abstract_element.element(), shadow_host_to_use, mut
				context, style_scope_pseudo_element_from_abstract_element(abstract_element), none,
				.normal, none)
		}

		style_scope_merge_attempted_pseudo_class_matches(mut attempted_pseudo_class_matches,
			context)
		if did_match {
			matching_rules << rule_to_run
		}
	}

	return matching_rules
}

pub fn style_computer_collect_matching_rules_without_scope_boundary(style_computer &StyleComputer, abstract_element dom.AbstractElement, cascade_origin CascadeOrigin, mut attempted_pseudo_class_matches PseudoClassBitmap, qualified_layer_name ?string) []MatchingRule {
	_ = style_computer
	_ = abstract_element
	_ = cascade_origin
	_ = attempted_pseudo_class_matches
	_ = qualified_layer_name
	// Boundary for C++ StyleComputer::rule_cache_for_cascade_origin() fetching
	// document().style_scope() or shadow_root->style_scope(). DOM currently has
	// a DOM-local StyleScope placeholder, not css.StyleScope.
	return []MatchingRule{}
}

fn matching_rule_less_than(left MatchingRule, right MatchingRule) bool {
	left_specificity := left.selector.specificity()
	right_specificity := right.selector.specificity()
	if left_specificity == right_specificity {
		if left.style_sheet_index == right.style_sheet_index {
			return left.rule_index < right.rule_index
		}
		return left.style_sheet_index < right.style_sheet_index
	}
	return left_specificity < right_specificity
}

pub fn sort_matching_rules(mut matching_rules []MatchingRule) {
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
	// First, we collect all the CSS rules whose selectors match `element`:
	mut matching_rule_set := MatchingRuleSet{}
	matching_rule_set.user_agent_rules = style_computer_collect_matching_rules_in_scope(style_computer,
		abstract_element, .user_agent, mut attempted_pseudo_class_matches, none, scope)
	sort_matching_rules(mut matching_rule_set.user_agent_rules)
	matching_rule_set.user_rules = style_computer_collect_matching_rules_in_scope(style_computer,
		abstract_element, .user, mut attempted_pseudo_class_matches, none, scope)
	sort_matching_rules(mut matching_rule_set.user_rules)

	// @layer-ed author rules
	for layer_name in scope.qualified_layer_names_in_order {
		mut layer_rules := style_computer_collect_matching_rules_in_scope(style_computer,
			abstract_element, .author, mut attempted_pseudo_class_matches, layer_name, scope)
		sort_matching_rules(mut layer_rules)
		matching_rule_set.author_rules << LayerMatchingRules{
			qualified_layer_name: layer_name
			rules:                layer_rules
		}
	}
	// Un-@layer-ed author rules
	mut unlayered_author_rules := style_computer_collect_matching_rules_in_scope(style_computer,
		abstract_element, .author, mut attempted_pseudo_class_matches, none, scope)
	sort_matching_rules(mut unlayered_author_rules)
	matching_rule_set.author_rules << LayerMatchingRules{
		qualified_layer_name: ''
		rules:                unlayered_author_rules
	}

	if mode == .create_pseudo_element_style_if_needed {
		mut author_rules_has_any_rules := false
		for layer in matching_rule_set.author_rules {
			if layer.rules.len != 0 {
				author_rules_has_any_rules = true
				break
			}
		}
		unsafe {
			*did_match_any_pseudo_element_rules = author_rules_has_any_rules
				|| matching_rule_set.user_rules.len != 0 || matching_rule_set.user_agent_rules.len != 0
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
	_ = style_computer
	_ = cascade_origin
	_ = qualified_layer_name
	_ = shadow_root
	// Boundary for C++ StyleComputer::rule_cache_for_cascade_origin(). The missing
	// dependency is the css.StyleScope reachable from DOM::Document/ShadowRoot.
	return none
}
