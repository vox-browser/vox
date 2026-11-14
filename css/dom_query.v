module css

import dom
import os
import platform

const recompute_document_query_plans = os.getenv('VOX_RECOMPUTE_DOCUMENT_QUERY_PLANS') != ''
const document_query_plan_diagnostics = os.getenv('VOX_DOCUMENT_QUERY_PLAN_DIAGNOSTICS') != ''
__global document_query_plan_reported bool

// Only syntax belongs here. Match contexts, scope and DOM results remain local
// to each query so attribute changes, adoption and relational selectors stay live.
@[heap]
struct DocumentQueryPlan {
	selectors SelectorList
	independent ?[]CompoundSelector
	named_namespace bool
	// Every simple selector compares a name, an ID or a class. Outside quirks
	// mode such a match allocates nothing and needs no scratch workspace.
	scalar bool
}

// Same-binary control: open a scratch workspace for every query, as before.
const retain_scalar_query_scratch = os.getenv('VOX_RETAIN_SCALAR_QUERY_SCRATCH') != ''

fn independent_compounds_are_scalar(compounds ?[]CompoundSelector) bool {
	list := compounds or { return false }
	for compound in list {
		for simple in compound.simple_selectors {
			if simple.type_ !in [.tag_name, .universal, .id, .class] { return false }
		}
	}
	return true
}

fn (plan &DocumentQueryPlan) matches_without_workspace(document &dom.Document) bool {
	return plan.scalar && !retain_scalar_query_scratch && !recompute_document_query_plans
		&& document != unsafe { nil } && !document.in_quirks_mode()
}

// Whether every compound names a tag this document has never seen, so that
// no element below a connected root can match. Reads only names: the caller
// has not opened a workspace yet.
fn independent_query_tags_are_absent(root &dom.Node, compounds []CompoundSelector) bool {
	if retain_scalar_query_scratch || (!root.is_document()
		&& (retain_document_only_absence_queries || !root.is_connected())) {
		return false
	}
	document := root.document()
	for compound in compounds {
		mut absent := false
		for simple in compound.simple_selectors {
			if simple.type_ == .tag_name
				&& !document.has_seen_element_local_name(simple.qualified_name().name.lowercase_name) {
				absent = true
				break
			}
		}
		if !absent { return false }
	}
	return compounds.len > 0
}

fn (plan &DocumentQueryPlan) independent_compounds() ?[]CompoundSelector {
	if recompute_document_query_plans { return independent_query_compounds(plan.selectors) }
	if document_query_plan_diagnostics && !document_query_plan_reported {
		document_query_plan_reported = true
		eprintln('Vox document query: reused immutable selector classification')
	}
	return plan.independent
}

// Selector-matching entry points that the DOM needs (querySelector / matches / closest).
// These live in css because they need the selector parser and SelectorEngine. The callback bridge
// below lets the standard DOM APIs use them without creating a dom <-> css import cycle.

@[heap]
struct DocumentSelectorQueryState {
mut:
	parsed  map[string]SelectorList
	invalid map[string]bool
	plans map[string]&DocumentQueryPlan
}

fn (mut state DocumentSelectorQueryState) query_plan(text string) ?&DocumentQueryPlan {
	if cached := state.plans[text] { return cached }
	selectors := state.parse(text) or { return none }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	independent := independent_query_compounds(selectors)
	plan := &DocumentQueryPlan{
		selectors: selectors
		independent: independent
		named_namespace: selector_list_contains_named_namespace(selectors)
		scalar: independent_compounds_are_scalar(independent)
	}
	state.plans[text.clone()] = plan
	return plan
}

fn (mut state DocumentSelectorQueryState) parse(selector_text string) ?SelectorList {
	if selector_text in state.invalid {
		return none
	}
	if parsed := state.parsed[selector_text] {
		return parsed
	}
	// The document keeps parsed selectors for its lifetime. The first query
	// for a selector can come from a temporary scope, such as select sizing
	// inside a flex item's intrinsic layout probe: parse and grow both maps
	// outside it, from a persistent copy of the text the selector may slice.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	key := selector_text.clone()
	parsed := parse_query_selector_list(key) or {
		state.invalid[key] = true
		return none
	}
	state.parsed[key] = parsed
	return parsed
}

fn dom_selector_query_validate(target voidptr, selector_text string) bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	return state.parse(selector_text) != none
}

fn selector_list_contains_named_namespace(selectors SelectorList) bool {
	for selector in selectors.selectors {
		for compound_selector in selector.compound_selectors() {
			for simple_selector in compound_selector.simple_selectors {
				if simple_selector.type_ in [.tag_name, .universal]
					&& simple_selector.qualified_name().namespace_type == .named {
					return true
				}
				if simple_selector.type_ == .attribute
					&& simple_selector.attribute().qualified_name.namespace_type == .named {
					return true
				}
				if simple_selector.type_ == .pseudo_class
					&& selector_list_contains_named_namespace(simple_selector.pseudo_class().argument_selector_list) {
					return true
				}
			}
		}
	}
	return false
}

fn dom_selector_query_contains_named_namespace(target voidptr, selector_text string) bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	plan := state.query_plan(selector_text) or { return false }
	if !recompute_document_query_plans { return plan.named_namespace }
	scratch := platform.begin_thread_scratch('DOM selector namespace check')
	defer { scratch.finish() }
	return selector_list_contains_named_namespace(plan.selectors)
}

// These compounds only read element names and attributes. Their matching
// vectors cannot escape the callback; parsed selectors keep document storage.
fn independent_element_matches(element &dom.Element, selectors SelectorList) ?bool {
	scratch := platform.begin_thread_scratch('independent element match')
	defer { scratch.finish() }
	compounds := independent_query_compounds(selectors) or { return none }
	mut context := MatchContext{has_result_cache: unsafe { nil }}
	return independent_query_matches(element, compounds, mut context)
}

fn dom_selector_query_matches(target voidptr, selector_text string, element &dom.Element, scoping_root &dom.ParentNode) bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	plan := state.query_plan(selector_text) or { return false }
	return element_matches_query_plan(element, plan, scoping_root)
}

fn dom_selector_query_matches_checked(target voidptr, selector_text string, element &dom.Element, scoping_root &dom.ParentNode) !bool {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	plan := state.query_plan(selector_text) or {
		return error('SyntaxError: Failed to parse selector')
	}
	return element_matches_query_plan(element, plan, scoping_root)
}

fn element_matches_query_plan(element &dom.Element, plan &DocumentQueryPlan,
	scoping_root ?&dom.ParentNode) bool {
	if !recompute_document_query_plans && plan.independent == none {
		return general_query_matches(element, plan.selectors, scoping_root)
	}
	if plan.matches_without_workspace(element.document()) {
		if compounds := plan.independent {
			mut context := MatchContext{has_result_cache: unsafe { nil }}
			return independent_query_matches(element, compounds, mut context)
		}
	}
	scratch := platform.begin_thread_scratch('independent query plan match')
	if compounds := plan.independent_compounds() {
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		matched := independent_query_matches(element, compounds, mut context)
		scratch.finish()
		return matched
	}
	scratch.finish()
	return general_query_matches(element, plan.selectors, scoping_root)
}

// Parse/cache ownership is established by the caller before entering this
// workspace. A one-shot query publishes only its boolean; relational matching
// contexts and :has() memoization do not belong to the document's lifetime.
fn general_query_matches(element &dom.Element, selectors SelectorList,
	scoping_root ?&dom.ParentNode) bool {
	scratch := platform.begin_thread_scratch('general element match')
	defer { scratch.finish() }
	for selector in selectors.selectors {
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		if matches(selector, element, none, mut context, none, scoping_root, .normal, none) {
			return true
		}
	}
	return false
}

fn dom_selector_scope_query(target voidptr, selector_text string, root &dom.ParentNode,
	first bool) ?[]&dom.Node {
	mut state := unsafe { &DocumentSelectorQueryState(target) }
	plan := state.query_plan(selector_text) or { return none }
	if !recompute_document_query_plans {
		if compounds := plan.independent {
			if independent_query_tags_are_absent(root.as_node(), compounds) { return []&dom.Node{} }
		}
	}
	// Parsed selectors are document-owned. Only the independent matching walk
	// and its temporary vectors belong to this synchronous workspace.
	scratch := platform.begin_thread_scratch('independent DOM query')
	defer { scratch.finish() }
	compounds := plan.independent_compounds() or { return none }
	if !independent_query_may_match_document(root.as_node(), compounds) {
		scratch.leave()
		return []&dom.Node{}
	}
	mut context := MatchContext{has_result_cache: unsafe { nil }}
	mut nodes := []&dom.Node{}
	if first {
		if element := independent_query_first_in(root.as_node(), compounds, mut context) {
			nodes << element.as_node()
		}
	} else {
		mut elements := []&dom.Element{}
		independent_query_all_in(root.as_node(), compounds, mut context, mut elements)
		for element in elements { nodes << element.as_node() }
	}
	scratch.leave()
	return nodes.clone()
}

pub fn install_document_selector_query_hook(document &dom.Document) {
	if hook := document.selector_query_hook() {
		if hook.validate == dom_selector_query_validate
			&& hook.matches == dom_selector_query_matches
			&& hook.matches_checked == dom_selector_query_matches_checked
			&& hook.contains_named_namespace == dom_selector_query_contains_named_namespace
			&& hook.scope_query == dom_selector_scope_query {
			return
		}
	}
	persistent := platform.enter_persistent()
	state := &DocumentSelectorQueryState{
		parsed:  map[string]SelectorList{}
		invalid: map[string]bool{}
		plans: map[string]&DocumentQueryPlan{}
	}
	platform.leave_persistent(persistent)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_selector_query_hook(dom.DocumentSelectorQueryHook{
		target:                   voidptr(state)
		validate:                 dom_selector_query_validate
		matches:                  dom_selector_query_matches
		matches_checked:          dom_selector_query_matches_checked
		contains_named_namespace: dom_selector_query_contains_named_namespace
		scope_query:              dom_selector_scope_query
	})
}

// The error Element.matches() reports for a selector that does not parse,
// without matching anything.
pub fn require_document_selector(document &dom.Document, selector_text string) ! {
	_ = document_query_plan(document, selector_text) or {
		return error('SyntaxError: Failed to parse selector')
	}
}

fn parse_query_selector_list(selector_text string) ?SelectorList {
	return parse_selector_with_parser(selector_text, map[string]bool{})
}

// CSS-side callers and the DOM callback bridge belong to the same document.
// Share their immutable parsed selectors, while each match still reads live
// element state and creates its own relational matching context.
fn document_query_selector_list(document &dom.Document, selector_text string) ?SelectorList {
	plan := document_query_plan(document, selector_text) or { return none }
	return plan.selectors
}

fn document_query_plan(document &dom.Document, selector_text string) ?&DocumentQueryPlan {
	install_document_selector_query_hook(document)
	hook := document.selector_query_hook() or { return none }
	mut state := unsafe { &DocumentSelectorQueryState(hook.target) }
	return state.query_plan(selector_text)
}

fn element_matches_any(element &dom.Element, selectors SelectorList) bool {
	if result := independent_element_matches(element, selectors) { return result }
	return general_query_matches(element, selectors, none)
}

// https://dom.spec.whatwg.org/#dom-element-matches
pub fn element_matches_selector(element &dom.Element, selector_text string) bool {
	plan := document_query_plan(element.document(), selector_text) or { return false }
	return element_matches_query_plan(element, plan, none)
}

// Unplanned walks remain the comparison path for general queries.
fn query_selector_first_in(node &dom.Node, selectors SelectorList) ?&dom.Element {
	for child in node.children {
		if element := child.as_element() {
			if element_matches_any(element, selectors) {
				return element
			}
		}
		if found := query_selector_first_in(child, selectors) {
			return found
		}
	}
	return none
}

fn query_selector_all_in(node &dom.Node, selectors SelectorList, mut results []&dom.Element) {
	for child in node.children {
		if element := child.as_element() {
			if element_matches_any(element, selectors) {
				results << element
			}
		}
		query_selector_all_in(child, selectors, mut results)
	}
}

fn query_selector_first_with_plan(node &dom.Node, plan &DocumentQueryPlan) ?&dom.Element {
	for child in node.children {
		if element := child.as_element() {
			if element_matches_query_plan(element, plan, none) {
				return element
			}
		}
		if found := query_selector_first_with_plan(child, plan) {
			return found
		}
	}
	return none
}

fn query_selector_all_with_plan(node &dom.Node, plan &DocumentQueryPlan, mut results []&dom.Element) {
	for child in node.children {
		if element := child.as_element() {
			if element_matches_query_plan(element, plan, none) {
				results << element
			}
		}
		query_selector_all_with_plan(child, plan, mut results)
	}
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselector
// Returns the first descendant element of `root` (in tree order) that matches the selector.
pub fn query_selector(root &dom.Node, selector_text string) ?&dom.Element {
	plan := document_query_plan(root.document(), selector_text) or { return none }
	if !recompute_document_query_plans {
		if compounds := plan.independent {
			if independent_query_tags_are_absent(root, compounds) { return none }
		}
	}
	scratch := platform.begin_thread_scratch('independent DOM query')
	if compounds := plan.independent_compounds() {
		if !independent_query_may_match_document(root, compounds) {
			scratch.finish()
			return none
		}
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		found := independent_query_first_in(root, compounds, mut context)
		scratch.finish()
		return found
	}
	scratch.finish()
	if recompute_document_query_plans { return query_selector_first_in(root, plan.selectors) }
	return query_selector_first_with_plan(root, plan)
}

// https://dom.spec.whatwg.org/#dom-parentnode-queryselectorall
pub fn query_selector_all(root &dom.Node, selector_text string) []&dom.Element {
	// The universal selector matches every element in any namespace. Native
	// script hosts index whole documents this way, so skip the matcher.
	if selector_text == '*' {
		mut elements := []&dom.Element{}
		collect_descendant_elements(root, mut elements)
		return elements
	}
	plan := document_query_plan(root.document(), selector_text) or { return []&dom.Element{} }
	scratch := platform.begin_thread_scratch('independent DOM query')
	if compounds := plan.independent_compounds() {
		if !independent_query_may_match_document(root, compounds) {
			scratch.finish()
			return []&dom.Element{}
		}
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		mut results := []&dom.Element{}
		independent_query_all_in(root, compounds, mut context, mut results)
		scratch.leave()
		owned := results.clone()
		scratch.finish()
		return owned
	}
	scratch.finish()
	mut results := []&dom.Element{}
	if recompute_document_query_plans { query_selector_all_in(root, plan.selectors, mut results) }
	else { query_selector_all_with_plan(root, plan, mut results) }
	return results
}

fn collect_descendant_elements(root &dom.Node, mut elements []&dom.Element) {
	for child in root.children {
		if element := child.as_element() { elements << element }
		if child.children.len > 0 { collect_descendant_elements(child, mut elements) }
	}
}

// https://dom.spec.whatwg.org/#dom-element-closest
// Returns `element` or its nearest inclusive ancestor element that matches the selector.
pub fn closest_matching_selector(element &dom.Element, selector_text string) ?&dom.Element {
	plan := document_query_plan(element.document(), selector_text) or { return none }
	mut current := ?&dom.Element(element)
	for {
		candidate := current or { break }
		if element_matches_query_plan(candidate, plan, none) {
			return candidate
		}
		current = candidate.as_node().parent_element()
	}
	return none
}
