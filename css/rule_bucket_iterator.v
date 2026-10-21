module css

import dom

// Borrow matching buckets one at a time. Read-only selector walks need neither
// an outer array of headers nor copies of the rule vectors. Keep the same
// class/id/tag/pseudo/root/attribute/fallback order as matching_rule_buckets().
struct RuleBucketIterator {
	cache   &RuleCache
	element dom.AbstractElement
mut:
	stage int
	index int
}

fn rule_bucket_iterator(cache &RuleCache, element dom.AbstractElement) RuleBucketIterator {
	// The caller keeps the cache alive for this synchronous traversal; a cache
	// allocated on its stack is just as valid as a retained stylesheet cache.
	return RuleBucketIterator{ cache: unsafe { cache }, element: element }
}

fn (mut iterator RuleBucketIterator) next() ?[]&MatchingRule {
	cache := iterator.cache
	element := iterator.element.element()
	for {
		match iterator.stage {
			0 {
				for iterator.index < element.classes.len {
					name := cache.selector_name_bucket_key(element.classes[iterator.index])
					iterator.index++
					if name in cache.rules_by_class { return unsafe { cache.rules_by_class[name] } }
				}
				iterator.stage++
				iterator.index = 0
			}
			1 {
				iterator.stage++
				if original := element.id() {
					name := cache.selector_name_bucket_key(original)
					if name in cache.rules_by_id { return unsafe { cache.rules_by_id[name] } }
				}
			}
			2 {
				iterator.stage++
				name := element.lowercased_local_name()
				if name in cache.rules_by_tag_name {
					return unsafe { cache.rules_by_tag_name[name] }
				}
			}
			3 {
				iterator.stage++
				if pseudo := style_scope_pseudo_element_from_abstract_element(iterator.element) {
					if is_known_pseudo_element_type(pseudo) && pseudo in cache.rules_by_pseudo_element {
						return unsafe { cache.rules_by_pseudo_element[pseudo] }
					}
				}
			}
			4 {
				iterator.stage++
				if element.is_document_element() { return unsafe { cache.root_rules } }
			}
			5 {
				if attrs := element.attributes_ {
					for iterator.index < attrs.attrs.len {
						name := rule_cache_attribute_bucket_name(attrs.attrs[iterator.index].name())
						iterator.index++
						if name in cache.rules_by_attribute_name {
							return unsafe { cache.rules_by_attribute_name[name] }
						}
					}
				}
				iterator.stage++
			}
			6 {
				iterator.stage++
				return unsafe { cache.other_rules }
			}
			else { return none }
		}
	}
	return none
}
