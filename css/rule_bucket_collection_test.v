module css

import dom

fn test_rule_bucket_collection_preserves_class_id_tag_attribute_and_fallback_order() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element('div')!
	element.set_attribute_value('class', 'card')
	element.set_attribute_value('id', 'target')
	element.set_attribute_value('title', 'hello')
	element.set_attribute_value_ns('É', 'value', 'x', 'urn:test')
	mut cache := RuleCache.new()
	class_rule := &MatchingRule{rule_index: 1}
	id_rule := &MatchingRule{rule_index: 2}
	tag_rule := &MatchingRule{rule_index: 3}
	attribute_rule := &MatchingRule{rule_index: 4}
	namespaced_rule := &MatchingRule{rule_index: 5}
	other_rule := &MatchingRule{rule_index: 6}
	cache.rules_by_class['card'] = [class_rule]
	cache.rules_by_id['target'] = [id_rule]
	cache.rules_by_tag_name['div'] = [tag_rule]
	cache.rules_by_attribute_name['title'] = [attribute_rule]
	cache.rules_by_attribute_name['x:é'] = [namespaced_rule]
	cache.other_rules = [other_rule]
	buckets := cache.matching_rule_buckets(dom.AbstractElement.new(element, none))
	assert buckets.len == 6
	for index, bucket in buckets {
		assert bucket.len == 1
		assert bucket[0].rule_index == uint(index + 1)
	}
	// No attributes means no synthesized attribute map and only the fallback.
	bare := document.create_element('span')!
	assert bare.attributes_ == none
	assert cache.matching_rule_buckets(dom.AbstractElement.new(bare, none)).len == 1
	assert bare.attributes_ == none
}

fn test_attribute_bucket_names_borrow_ascii_without_changing_existing_folding() {
	name := 'data-label'
	assert rule_cache_attribute_bucket_name(name).str == name.str
	assert rule_cache_attribute_bucket_name('viewBox') == 'viewbox'
	assert rule_cache_attribute_bucket_name('x:É') == 'x:é'
}
