module css

import dom
import os

// Attribute-value invalidation. An attribute change invalidates through the
// plan registered for the attribute's name, which is the union of every
// selector mentioning that name. One `[class^=a]>[class^=b]` rule therefore
// made each `class` change restyle every descendant carrying a class
// attribute, although the change only added or removed an unrelated token.
//
// `class`, `data-*` and `aria-*` attributes reach style through attribute
// selectors, class selectors and attr() alone. Class selectors invalidate
// through the changed tokens and attr() through the element itself. When each
// attribute selector naming the attribute gives the same answer for the old
// and the new value, no selector's result depends on the change, and the
// name's plan is not applied.
const retain_attribute_name_invalidation = os.getenv('VOX_RETAIN_ATTRIBUTE_NAME_INVALIDATION') != ''
const attribute_value_invalidation_diagnostics = os.getenv('VOX_ATTRIBUTE_VALUE_INVALIDATION_DIAGNOSTICS') != ''

// Distinct value tests kept for one attribute name. A name with more keeps
// the name's plan for every change.
const attribute_value_test_limit = 64

__global attribute_value_invalidation_counts [2]u64
__global attribute_value_invalidation_reported u64

// Attribute changes whose name plan was skipped and applied in this process.
pub fn attribute_value_invalidation_statistics() (u64, u64) {
	return attribute_value_invalidation_counts[0], attribute_value_invalidation_counts[1]
}

pub fn report_attribute_value_invalidation() {
	if !attribute_value_invalidation_diagnostics { return }
	total := attribute_value_invalidation_counts[0] + attribute_value_invalidation_counts[1]
	if total == attribute_value_invalidation_reported { return }
	attribute_value_invalidation_reported = total
	eprintln('VOX_ATTRIBUTE_VALUE_INVALIDATION skipped=${attribute_value_invalidation_counts[0]} applied=${attribute_value_invalidation_counts[1]}')
}

pub struct AttributeValueTests {
pub mut:
	tests []SelectorAttribute
	// A selector in a named namespace, or more tests than the limit.
	imprecise bool
}

fn (mut insights SelectorInsights) record_attribute_value_test(attribute SelectorAttribute) {
	name := attribute.qualified_name.name.lowercase_name
	mut entry := insights.attribute_value_tests[name] or { AttributeValueTests{} }
	if entry.imprecise { return }
	if attribute.qualified_name.namespace_type == .named {
		entry.imprecise = true
		entry.tests = []SelectorAttribute{}
		insights.attribute_value_tests[name.clone()] = entry
		return
	}
	for existing in entry.tests {
		if existing.match_type == attribute.match_type && existing.case_type == attribute.case_type
			&& existing.value == attribute.value
			&& existing.qualified_name.namespace_type == attribute.qualified_name.namespace_type
			&& existing.qualified_name.name.name == attribute.qualified_name.name.name {
			return
		}
	}
	if entry.tests.len >= attribute_value_test_limit {
		entry.imprecise = true
		entry.tests = []SelectorAttribute{}
		insights.attribute_value_tests[name.clone()] = entry
		return
	}
	// The selector belongs to its style sheet; the rule cache can outlive it.
	entry.tests << SelectorAttribute{
		match_type:     attribute.match_type
		case_type:      attribute.case_type
		value:          attribute.value.clone()
		qualified_name: SelectorQualifiedName{
			namespace_type: attribute.qualified_name.namespace_type
			name:           SelectorName{
				name:           attribute.qualified_name.name.name.clone()
				lowercase_name: name.clone()
			}
		}
	}
	insights.attribute_value_tests[name.clone()] = entry
}

// Whether every attribute selector of this scope naming `name` gives the same
// answer for an attribute of `element` before and after the change.
pub fn (scope &StyleScope) attribute_change_keeps_selector_matches(element &dom.Element, name string,
	old_present bool, old_value string, new_present bool, new_value string) bool {
	if retain_attribute_name_invalidation { return false }
	// The insights are those of the rule cache that owns the plans.
	if _ := scope.style_invalidation_data {
		insights := scope.selector_insights or { return false }
		entry := insights.attribute_value_tests[name] or { return true }
		if entry.imprecise { return false }
		for test in entry.tests {
			sensitivity := selector_attribute_case_sensitivity(test, element)
			before := old_present && selector_attribute_matches_value(test, old_value, sensitivity)
			after := new_present && selector_attribute_matches_value(test, new_value, sensitivity)
			if before != after {
				if attribute_value_invalidation_diagnostics
					&& os.getenv('VOX_ATTRIBUTE_VALUE_INVALIDATION_DIAGNOSTICS') == 'reasons' {
					eprintln('VOX_ATTRIBUTE_VALUE_INVALIDATION applied name=${name} element=${element.local_name()} test=${int(test.match_type)}:${test.value.limit(40)} styled=${element.el_computed_properties() != none} old=${old_present}:${old_value.limit(60)} new=${new_present}:${new_value.limit(60)}')
				}
				return false
			}
		}
		return true
	}
	return false
}

fn style_computer_attribute_change_keeps_selectors_callback(_ voidptr, element &dom.Element, name string,
	old_present bool, old_value string, new_present bool, new_value string, dom_scope &dom.StyleScope) bool {
	// A scope without CSS state has computed no style and has no plan.
	if dom_scope.css_handle == unsafe { nil } { return true }
	scope := unsafe { &StyleScope(dom_scope.css_handle) }
	return scope.attribute_change_keeps_selector_matches(element, name, old_present, old_value,
		new_present, new_value)
}

fn style_computer_attribute_change_decided_callback(_ voidptr, skipped bool) {
	attribute_value_invalidation_counts[if skipped { 0 } else { 1 }]++
}
