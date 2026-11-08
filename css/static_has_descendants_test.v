module css

import dom

fn static_has_oracle(selector Selector, anchor &dom.Element, fast bool) (bool, PseudoClassBitmap) {
	mut context := MatchContext{
		inside_has_argument_match: true
		collect_per_element_selector_involvement_metadata: true
		has_result_cache: unsafe { nil }
	}
	if fast {
		compound := static_has_descendant_compound(selector, none, context) or { panic('ineligible') }
		return has_static_matching_descendant(compound, anchor.as_node(), mut context), context.attempted_pseudo_class_matches
	}
	// This relative matcher invokes the ordinary per-element matching algorithm
	// without entering the specialized descendant-search entry point.
	mut pending := anchor.as_node().children.clone()
	for pending.len > 0 {
		node := pending[0]
		pending.delete(0)
		if element := node.as_element() {
			mut mutable_element := unsafe { &dom.Element(element) }
			mutable_element.set_in_has_scope(true)
			if matches(selector, element, none, mut context, none, none, .relative, anchor) {
				return true, context.attempted_pseudo_class_matches
			}
		}
		pending.prepend(node.children)
	}
	return false, context.attempted_pseudo_class_matches
}

fn test_static_has_descendants_preserve_matches_tree_order_and_involvement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_document_type(.html)
	mut anchor := document.create_element('section')!
	mut branch := document.create_element('div')!
	mut match_node := document.create_element('span')!
	match_node.set_attribute_value('class', 'flag')
	match_node.set_attribute_value('data-x', 'yes')
	mut later := document.create_element('span')!
	mut rootnode := anchor.as_node()
	rootnode.append_child(branch.as_node())!
	mut branch_node := branch.as_node()
	branch_node.append_child(document.create_text_node('before').as_node())!
	branch_node.append_child(match_node.as_node())!
	rootnode.append_child(later.as_node())!
	for text in ['.flag', '.flag[data-x="yes"]', '[data-x]', '[data-missing]', 'SPAN.flag', '.missing'] {
		selector := parse_selector_with_parser(':has(${text})', map[string]bool{})?.selectors[0].compound_selectors()[0].simple_selectors[0].pseudo_class().argument_selector_list.selectors[0]
		mut elements := [branch, match_node, later]
		for fast in [false, true] {
			for mut element in elements { element.set_in_has_scope(false) }
			matched, attempts := static_has_oracle(selector, anchor, fast)
			assert matched == !text.contains('missing')
			assert attempts == PseudoClassBitmap{}
			assert branch.in_has_scope && match_node.in_has_scope
			assert later.in_has_scope == !matched
		}
	}
}
