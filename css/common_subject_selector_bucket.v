module css

import os

const disable_common_subject_selector_buckets = os.getenv('VOX_DISABLE_COMMON_SUBJECT_SELECTOR_BUCKETS') != ''

fn subject_bucket_name(simple SimpleSelector) ?SimplifiedSelectorForBucketing {
	return match simple.type_ {
		.class, .id {
			SimplifiedSelectorForBucketing{ type_: simple.type_, name: simple.name().name }
		}
		.tag_name {
			SimplifiedSelectorForBucketing{ type_: .tag_name, name: simple.qualified_name().name.lowercase_name }
		}
		else { none }
	}
}

// A positive class/id/type in every alternative's subject compound is a
// necessary condition for :is() or :where() to match. Earlier compounds are
// ancestors or siblings and cannot supply a subject bucket. The full selector
// still performs matching, specificity and invalidation.
fn common_is_where_subject_bucket(selectors []Selector) ?SimplifiedSelectorForBucketing {
	if disable_common_subject_selector_buckets || selectors.len < 2 { return none }
	first := selectors[0].compound_selectors()
	if first.len == 0 { return none }
	subject := first[first.len - 1]
	for index := subject.simple_selectors.len - 1; index >= 0; index-- {
		candidate := subject_bucket_name(subject.simple_selectors[index]) or { continue }
		mut common := true
		for alternative in selectors[1..] {
			compounds := alternative.compound_selectors()
			if compounds.len == 0 {
				common = false
				break
			}
			mut found := false
			for simple in compounds[compounds.len - 1].simple_selectors {
				other := subject_bucket_name(simple) or { continue }
				if other.type_ == candidate.type_ && other.name == candidate.name {
					found = true
					break
				}
			}
			if !found {
				common = false
				break
			}
		}
		if common { return candidate }
	}
	return none
}
