module css

import dom
import os

const disable_static_has_descendants = os.getenv('VOX_DISABLE_STATIC_HAS_DESCENDANTS') != ''
const static_has_descendant_diagnostics = os.getenv('VOX_STATIC_HAS_DESCENDANT_DIAGNOSTICS') != ''
__global static_has_descendants_reported bool

// A single static descendant compound reads only each candidate element.
// Reuse the ordinary compound matcher without rebuilding the general relative
// matching context for every visited descendant. Pseudos, combinators and
// shadow/part matching keep their full traversal.
fn static_has_descendant_compound(selector Selector, shadow_host ?&dom.Element,
	context &MatchContext) ?CompoundSelector {
	if disable_static_has_descendants || shadow_host != none
		|| context.rule_shadow_root != none || context.slotted_element != none
		|| context.part_owning_parent != none || context.for_host_part_matching { return none }
	compounds := selector.compound_selectors()
	if compounds.len != 1 || compounds[0].combinator != .descendant { return none }
	for simple in compounds[0].simple_selectors {
		if simple.type_ !in [.class, .id, .tag_name, .universal, .attribute] { return none }
	}
	if static_has_descendant_diagnostics && !static_has_descendants_reported {
		static_has_descendants_reported = true
		eprintln('Vox has: matched static descendant compounds with unchanged traversal metadata')
	}
	return compounds[0]
}

fn has_static_matching_descendant(compound CompoundSelector, node &dom.Node,
	mut context MatchContext) bool {
	for child in node.children {
		if element := child.as_element() {
			if context.inside_has_argument_match && context.collect_per_element_selector_involvement_metadata {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_in_has_scope(true)
			}
			if fast_matches_compound_selector(compound, element, none, mut context) { return true }
		}
		if child.children.len > 0 && has_static_matching_descendant(compound, child, mut context) { return true }
	}
	return false
}
