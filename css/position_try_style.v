module css

import dom

struct PositionTryStyleOverride {
	target dom.AbstractElement
	declaration &CSSStyleProperties
}

pub fn compute_position_try_style(target dom.AbstractElement, declaration &CSSStyleProperties) &ComputedProperties {
	mut computer := css_style_computer_for(target.element().document())
	previous := computer.position_try_override_
	computer.position_try_override_ = PositionTryStyleOverride{target:target,declaration:declaration}
	defer { computer.position_try_override_ = previous }
	return computer.compute_style(target)
}

pub fn install_position_try_style(mut target dom.AbstractElement, properties &ComputedProperties) {
	target.set_computed_properties(computed_properties_to_dom(properties))
}

@[heap]
struct PositionTryRuleLookup {
	name string
	scope &StyleScope
mut:
	rule ?&CSSRule
	layer_index int = -1
}

fn position_try_rule_in_scope(scope &StyleScope, name string) ?&CSSRule {
	scope.build_rule_cache_if_needed()
	lookup := &PositionTryRuleLookup{name:name,scope:scope}
	for sheet in scope.stylesheets_for_cascade_origin(.author) {
		sheet.for_each_effective_rule(.preorder,fn [lookup] (rule &CSSRule) {
			if rule.type_ == .position_try && rule.position_try_name() == lookup.name {
				mut mutable_rule := unsafe { &CSSRule(rule) }
				index := lookup.scope.custom_function_layer_index(mutable_rule.qualified_layer_name())
				if index >= lookup.layer_index {
					mut found := unsafe { &PositionTryRuleLookup(lookup) }
					found.rule = rule
					found.layer_index = index
				}
			}
		})
	}
	if rule := lookup.rule { return rule }
	node := scope.node or { return none }
	shadow := node.as_shadow_root() or { return none }
	host := shadow.host() or { return none }
	return position_try_rule_in_scope(css_style_scope_for_node(host.as_node()),name)
}

pub fn position_try_rule_for_element(target dom.AbstractElement, name string) ?&CSSRule {
	properties := target.computed_properties() or { return none }
	computed := computed_properties_from_dom(properties) or { return none }
	scope := if root := computed.position_try_reference_scope_ { css_style_scope_for_scope_node(root) }
		else { style_scope_for_abstract_element(target) }
	return position_try_rule_in_scope(scope,name)
}

fn position_try_reference_scope(element dom.AbstractElement, cascaded &CascadedProperties) &dom.Node {
	if shadow := cascaded.property_source_shadow_root(.position_try_fallbacks) { return unsafe { &dom.Node(shadow) } }
	source := cascaded.property_source(.position_try_fallbacks)
	if source != unsafe { nil } {
		declaration := unsafe { &CSSStyleProperties(source) }
		if declaration.parent_rule != none { return element.document().as_node() }
	}
	return element.element().as_node().root()
}
