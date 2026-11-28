module css

import dom
import os
import platform

// General scope queries. querySelector() and querySelectorAll() with a
// selector list that is not made of independent compounds (a combinator,
// :not(), :has(), ...) returned to the DOM's own walk, which asked the
// selector hook about each element. Every question found the plan again by
// hashing the whole selector text, opened a scratch workspace, and tried
// each selector of the list. Observer libraries query with one list of all
// their selectors, several kilobytes long, after every DOM change.
//
// Walk once here instead. Outside quirks mode an element can only match a
// selector whose subject compound requires one of the element's classes, its
// ID, one of its attributes or its tag name, or requires none of them; the
// list is bucketed by that requirement the first time a plan is walked.
const retain_general_scope_walk = os.getenv('VOX_RETAIN_GENERAL_SCOPE_WALK') != ''

__global general_scope_query_counts [2]u64

// General scope walks, and selector matches they attempted, in this process.
pub fn general_scope_query_statistics() (u64, u64) {
	return general_scope_query_counts[0], general_scope_query_counts[1]
}

// Indexes into a plan's selector list by the feature its subject requires.
@[heap]
struct QuerySubjectBuckets {
mut:
	by_class     map[string][]int
	by_id        map[string][]int
	by_attribute map[string][]int
	by_tag       map[string][]int
	other        []int
}

// Names of HTML elements and their attributes are already lower case.
fn query_bucket_name(name string) string {
	for character in name {
		if character >= `A` && character <= `Z` { return name.to_lower() }
	}
	return name
}

fn query_subject_buckets(selectors SelectorList) &QuerySubjectBuckets {
	mut buckets := &QuerySubjectBuckets{}
	for index, selector in selectors.selectors {
		compounds := selector.compound_selectors()
		if compounds.len == 0 {
			buckets.other << index
			continue
		}
		subject := compounds[compounds.len - 1]
		mut id := ''
		mut class := ''
		mut attribute := ''
		mut tag := ''
		for simple in subject.simple_selectors {
			match simple.type_ {
				.id { if id == '' { id = simple.name().name } }
				.class { if class == '' { class = simple.name().name } }
				.attribute {
					if attribute == '' { attribute = simple.attribute().qualified_name.name.lowercase_name }
				}
				.tag_name { if tag == '' { tag = simple.qualified_name().name.lowercase_name } }
				else {}
			}
		}
		// The rarest requirement first: an ID, a class, an attribute, a tag name.
		if id != '' {
			buckets.by_id[id.clone()] << index
		} else if class != '' {
			buckets.by_class[class.clone()] << index
		} else if attribute != '' {
			buckets.by_attribute[attribute.clone()] << index
		} else if tag != '' {
			buckets.by_tag[tag.clone()] << index
		} else {
			buckets.other << index
		}
	}
	return buckets
}

fn (plan &DocumentQueryPlan) subject_buckets() &QuerySubjectBuckets {
	if plan.buckets != unsafe { nil } { return plan.buckets }
	// The plan is kept for the document's lifetime; so are its buckets.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { &DocumentQueryPlan(plan) }
	owner.buckets = query_subject_buckets(plan.selectors)
	return owner.buckets
}

struct GeneralScopeWalk {
	plan    &DocumentQueryPlan
	buckets &QuerySubjectBuckets
	scope   &dom.ParentNode
	// Quirks mode matches classes and IDs without regard to case: every
	// selector is a candidate there.
	bucketed bool
	first    bool
mut:
	nodes []&dom.Node
}

fn (walk &GeneralScopeWalk) any_matches(element &dom.Element, indexes []int) bool {
	for index in indexes {
		general_scope_query_counts[1]++
		mut context := MatchContext{has_result_cache: unsafe { nil }}
		if matches(walk.plan.selectors.selectors[index], element, none, mut context, none,
			walk.scope, .normal, none) {
			return true
		}
	}
	return false
}

fn (walk &GeneralScopeWalk) element_matches(element &dom.Element) bool {
	if !walk.bucketed {
		for index in 0 .. walk.plan.selectors.selectors.len {
			if walk.any_matches(element, [index]) { return true }
		}
		return false
	}
	buckets := walk.buckets
	if buckets.other.len > 0 && walk.any_matches(element, buckets.other) { return true }
	if buckets.by_id.len > 0 {
		if id := element.id() {
			if indexes := buckets.by_id[id] {
				if walk.any_matches(element, indexes) { return true }
			}
		}
	}
	if buckets.by_class.len > 0 {
		for class in element.classes {
			if indexes := buckets.by_class[class] {
				if walk.any_matches(element, indexes) { return true }
			}
		}
	}
	if buckets.by_attribute.len > 0 {
		if attributes := element.attributes_ {
			for attribute in attributes.attrs {
				if indexes := buckets.by_attribute[query_bucket_name(attribute.local_name_)] {
					if walk.any_matches(element, indexes) { return true }
				}
			}
		}
	}
	if buckets.by_tag.len > 0 {
		if indexes := buckets.by_tag[query_bucket_name(element.local_name())] {
			if walk.any_matches(element, indexes) { return true }
		}
	}
	return false
}

// Descendants in tree order; true once a first-match walk has its element.
fn (mut walk GeneralScopeWalk) visit(node &dom.Node) bool {
	for child in node.children {
		if element := child.as_element() {
			if walk.element_matches(element) {
				walk.nodes << child
				if walk.first { return true }
			}
		}
		if child.children.len > 0 && walk.visit(child) { return true }
	}
	return false
}

// The elements below `root` matching a plan that needs the general matcher,
// or none when the DOM's own walk is requested.
fn general_scope_query(plan &DocumentQueryPlan, root &dom.ParentNode, first bool) ?[]&dom.Node {
	if retain_general_scope_walk || recompute_document_query_plans { return none }
	node := root.as_node()
	document := node.document()
	bucketed := document != unsafe { nil } && !document.in_quirks_mode()
	buckets := plan.subject_buckets()
	general_scope_query_counts[0]++
	scratch := platform.begin_thread_scratch('general DOM query')
	mut walk := GeneralScopeWalk{
		plan:     plan
		buckets:  buckets
		scope:    root
		bucketed: bucketed
		first:    first
	}
	walk.visit(node)
	scratch.leave()
	owned := walk.nodes.clone()
	scratch.finish()
	return owned
}
