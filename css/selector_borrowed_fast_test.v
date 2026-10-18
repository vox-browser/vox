module css

import dom

fn borrow_selector(text string) Selector {
 list := parse_selector_with_parser(text, map[string]bool{}) or { panic('invalid: ${text}') }
 return list.selectors[0]
}
fn borrow_element(document &dom.Document, namespace string, tag string) &dom.Element {
 return document.create_element_ns(namespace, tag) or { panic(err) }
}
fn borrow_append(parent &dom.Element, child &dom.Element) {
 mut node := parent.as_node()
 node.append_child(child.as_node()) or { panic(err) }
}
fn borrow_compare(selector Selector, element &dom.Element, shadow_host ?&dom.Element, collect bool) bool {
 assert selector.can_use_fast_matches()
 before := selector.serialize()
 mut old_context := MatchContext{subject: unsafe { &dom.Element(element) } collect_per_element_selector_involvement_metadata: collect has_result_cache: unsafe { nil }}
 mut new_context := MatchContext{subject: unsafe { &dom.Element(element) } collect_per_element_selector_involvement_metadata: collect has_result_cache: unsafe { nil }}
 expected := borrow_oracle_matches(selector, element, shadow_host, mut old_context)
 actual := fast_matches(selector, element, shadow_host, mut new_context)
 assert actual == expected, before
 assert new_context == old_context, before
 assert selector.serialize() == before
 return actual
}

fn test_borrowed_fast_selectors_preserve_all_simple_types_and_context() {
 for quirks in [false, true] {
  mut document := dom.Document.create(dom.url_about_blank())
  document.set_document_type(.html)
  if quirks { document.set_quirks_mode(.yes) }
  mut root := borrow_element(document, 'http://www.w3.org/1999/xhtml', 'div')
  root.set_attribute_value('id', 'ITEM')
  root.set_attribute_value('class', 'TARGET other β')
  root.set_attribute_value('data-x', 'Value two')
  mut document_node := unsafe { &dom.Node(document) }
  document_node.append_child(root.as_node()) or { panic(err) }
  mut svg := borrow_element(document, 'http://www.w3.org/2000/svg', 'linearGradient')
  svg.set_attribute_value('id', 'svg-id')
  svg.set_attribute_value('class', 'TARGET')
  borrow_append(root, svg)
  for text in ['*','div','DIV','span','#ITEM','#item','.TARGET','.target','.β','[id]','[missing]','[data-x="Value two"]','[data-x="value two" i]','[data-x~=two]','[data-x^=Value]','[data-x$=two]','[data-x*=lue]',':empty',':root',':first-child',':last-child',':only-child',':hover',':focus',':enabled',':disabled','linearGradient','lineargradient'] {
   selector := borrow_selector(text)
   for element in [root,svg] {
    for collect in [false,true] { _ = borrow_compare(selector,element,none,collect) }
   }
  }
  assert borrow_compare(borrow_selector('#ITEM.TARGET'),root,none,true)
  assert borrow_compare(borrow_selector('#item.target'),root,none,true) == quirks
  assert borrow_compare(borrow_selector('linearGradient.TARGET'),svg,none,true)
  assert !borrow_compare(borrow_selector('lineargradient'),svg,none,true)
 }
}

fn test_borrowed_fast_selectors_keep_child_backtracking_and_metadata() {
 document := dom.Document.create(dom.url_about_blank())
 mut root := borrow_element(document,'http://www.w3.org/1999/xhtml','div')
 root.set_attribute_value('class','a')
 mut far := borrow_element(document,'http://www.w3.org/1999/xhtml','div')
 far.set_attribute_value('class','b')
 mut near := borrow_element(document,'http://www.w3.org/1999/xhtml','div')
 near.set_attribute_value('class','b')
 mut leaf := borrow_element(document,'http://www.w3.org/1999/xhtml','span')
 leaf.set_attribute_value('class','leaf')
 borrow_append(root,far)
 borrow_append(far,near)
 borrow_append(near,leaf)
 for text,expected in {'.a > .b .leaf':true,'.a > .b > .leaf':false,'.b > .leaf':true,'.missing .leaf':false,'div div span.leaf':true,'span.leaf:first-child':true,'span.leaf:last-child':true} {
  for collect in [false,true] { assert borrow_compare(borrow_selector(text),leaf,none,collect)==expected,text }
 }
 assert borrow_compare(borrow_selector('div:first-child .leaf'),leaf,none,true)
 assert near.affected_by_structural_pseudo_class_in_non_subject_position
}

fn test_borrowed_fast_selectors_keep_shadow_guard_and_reuse_after_gc() {
 document := dom.Document.create(dom.url_about_blank())
 mut host := borrow_element(document,'http://www.w3.org/1999/xhtml','x-host')
 host.set_attribute_value('class','target')
 root := host.attach_shadow(dom.ShadowRootInit{mode:.open}) or { panic(err) }
 mut child := borrow_element(document,'http://www.w3.org/1999/xhtml','span')
 child.set_attribute_value('class','target')
 mut root_node := unsafe { &dom.Node(root) }
 root_node.append_child(child.as_node()) or { panic(err) }
 selector := borrow_selector('span.target:first-child')
 for _ in 0 .. 3 {
  gc_collect()
  assert borrow_compare(selector,child,host,true)
  assert !borrow_compare(borrow_selector('x-host.target'),host,host,true)
 }
}

fn borrow_oracle_matches(selector Selector, element_to_match &dom.Element, shadow_host ?&dom.Element, mut context MatchContext) bool {
	compound_selectors := selector.compound_selectors()
	if compound_selectors.len == 0 {
		return false
	}
	mut current := element_to_match
	mut compound_selector_index := compound_selectors.len - 1

	if !borrow_oracle_compound(compound_selectors[compound_selectors.len - 1], current, shadow_host, mut context) {
		return false
	}

	// NOTE: If we fail after following a child combinator, we may need to backtrack
	//       to the last matched descendant. We store the state here.
	mut backtrack_element := ?&dom.Element(none)
	mut backtrack_compound_selector_index := 0

	for {
		if compound_selector_index < 0 {
			return false
		}

		compound_selector := compound_selectors[compound_selector_index]
		match compound_selector.combinator {
			.no_combinator {
				return true
			}
			.descendant {
				backtrack_element = parent_element(current)
				backtrack_compound_selector_index = compound_selector_index
				compound_selector_index--
				if compound_selector_index < 0 {
					return false
				}
				left_compound_selector := compound_selectors[compound_selector_index]
				mut ancestor := parent_element(current)
				for ancestor != none {
					ancestor_element := ancestor or { break }
					if borrow_oracle_compound(left_compound_selector, ancestor_element, shadow_host, mut context) {
						current = ancestor_element
						break
					}
					ancestor = parent_element(ancestor_element)
				}
				if ancestor == none {
					return false
				}
			}
			.immediate_child {
				compound_selector_index--
				if compound_selector_index < 0 {
					return false
				}
				current = parent_element(current) or { return false }
				if !borrow_oracle_compound(compound_selectors[compound_selector_index], current, shadow_host, mut context) {
					if backtrack := backtrack_element {
						current = backtrack
						compound_selector_index = backtrack_compound_selector_index
						continue
					}
					return false
				}
			}
			else {
				return false
			}
		}
	}
	return false
}

fn borrow_oracle_compound(compound_selector CompoundSelector, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext) bool {
	for simple_selector in compound_selector.simple_selectors {
		if !borrow_oracle_simple(simple_selector, element, shadow_host, mut context) {
			return false
		}
	}
	return true
}

fn borrow_oracle_simple(simple_selector SimpleSelector, element &dom.Element, shadow_host ?&dom.Element, mut context MatchContext) bool {
	if should_block_shadow_host_matching(simple_selector, shadow_host, element) {
		return false
	}

	match simple_selector.type_ {
		.universal {
			return matches_namespace(simple_selector.qualified_name(), element, context.style_sheet_for_rule)
		}
		.tag_name {
			// https://html.spec.whatwg.org/multipage/semantics-other.html#case-sensitivity-of-selectors
			// When comparing a CSS element type selector to the names of HTML elements in HTML documents, the CSS element type selector must first be converted to ASCII lowercase. The
			// same selector when compared to other elements must be compared according to its original case. In both cases, to match the values must be identical to each other (and therefore
			// the comparison is case sensitive).
			if element.namespace_uri() or { '' } == selector_html_namespace && element.document() != unsafe { nil } && element.document().document_type() == .html {
				if simple_selector.qualified_name().name.lowercase_name != element.local_name() {
					return false
				}
			} else if simple_selector.qualified_name().name.name != element.local_name() {
				// NOTE: Any other elements are either SVG, XHTML or MathML, all of which are case-sensitive.
				return false
			}
			return matches_namespace(simple_selector.qualified_name(), element, context.style_sheet_for_rule)
		}
		.class {
			// Class selectors are matched case insensitively in quirks mode.
			// See: https://drafts.csswg.org/selectors-4/#class-html
			if element.document() != unsafe { nil } && element.document().in_quirks_mode() {
				return element.has_class_case_insensitive(simple_selector.name().name)
			}
			return element.has_class(simple_selector.name().name)
		}
		.id {
			id := element.id() or { return false }
			if element.document() != unsafe { nil } && element.document().in_quirks_mode() {
				return equals_ignoring_ascii_case(simple_selector.name().name, id)
			}
			return simple_selector.name().name == id
		}
		.attribute {
			return matches_attribute(simple_selector.attribute(), context.style_sheet_for_rule, element)
		}
		.pseudo_class {
			return matches_pseudo_class(simple_selector.pseudo_class(), element, shadow_host, mut context, none, .normal)
		}
		else {
			return false
		}
	}
}
