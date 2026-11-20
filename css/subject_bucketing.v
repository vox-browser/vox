module css

import os

// Rules whose subject compound names no id, class or tag are tried against
// every element. On the archived github.com/vlang/v page about twenty such
// rules failed for every element: `:link`, `:visited`, `:any-link`,
// `:heading(n)`, and `:where(...)` arguments combining a class with other
// conditions. A positive top-level `:link`, `:any-link`, `:local-link` or
// `:visited` can only hold for an a or area element (matches_link_pseudo_class
// in every namespace) and `:heading` only for h1 to h6, so these rules go to
// those tag buckets. The full selector is still matched for each candidate,
// and the matched list is sorted, so only the candidate sets shrink. Attempted
// pseudo-class bits for these classes do not drive restyling (state changes
// invalidate hover, target and the focus classes).
const disable_pseudo_class_tag_buckets = os.getenv('VOX_DISABLE_PSEUDO_CLASS_TAG_BUCKETS') != ''

const link_subject_tag_names = ['a', 'area']

$if test {
	__global subject_bucketing_disabled_for_test bool
}

fn subject_bucketing_enabled() bool {
	$if test {
		if subject_bucketing_disabled_for_test { return false }
	}
	return !disable_pseudo_class_tag_buckets
}

fn pseudo_class_subject_tag_buckets(compound CompoundSelector) ?[]string {
	if !subject_bucketing_enabled() { return none }
	for simple in compound.simple_selectors {
		if simple.type_ != .pseudo_class { continue }
		pseudo := simple.pseudo_class()
		match pseudo.type_ {
			.link, .any_link, .local_link, .visited { return link_subject_tag_names }
			.heading {
				if pseudo.levels.len == 0 { return ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'] }
				mut names := []string{}
				for level in pseudo.levels {
					if level >= 1 && level <= 6 {
						name := 'h${level}'
						if name !in names { names << name }
					}
				}
				// No heading has another level: the rule matches nothing.
				return names
			}
			else {}
		}
	}
	return none
}

// The id, class or tag of a compound that every subject must have, preferring
// ids and classes as the outer bucketing does.
fn subject_compound_bucket(compound CompoundSelector) ?SimplifiedSelectorForBucketing {
	if !subject_bucketing_enabled() { return none }
	mut tag := ?SimplifiedSelectorForBucketing(none)
	for index := compound.simple_selectors.len - 1; index >= 0; index-- {
		simple := compound.simple_selectors[index]
		match simple.type_ {
			.id, .class {
				return SimplifiedSelectorForBucketing{
					type_: simple.type_
					name:  simple.name().name
				}
			}
			.tag_name {
				if tag == none {
					tag = SimplifiedSelectorForBucketing{
						type_: .tag_name
						name:  simple.qualified_name().name.lowercase_name
					}
				}
			}
			else {}
		}
	}
	return tag
}
