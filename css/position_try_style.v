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
mut:
	rule ?&CSSRule
}

pub fn position_try_rule_for_element(target dom.AbstractElement, name string) ?&CSSRule {
	scope := style_scope_for_abstract_element(target)
	lookup := &PositionTryRuleLookup{name:name}
	for sheet in scope.stylesheets_for_cascade_origin(.author) {
		sheet.for_each_effective_rule(.preorder,fn [lookup] (rule &CSSRule) {
			if rule.type_ == .position_try && rule.position_try_name() == lookup.name {
				mut found := unsafe { &PositionTryRuleLookup(lookup) }
				found.rule = rule
			}
		})
	}
	return lookup.rule
}

