module css

fn test_invalidation_membership_keeps_feature_kinds_distinct_and_order_stable() {
	mut set := InvalidationSet{}
	set.set_needs_invalidate_class('name')
	set.set_needs_invalidate_id('name')
	set.set_needs_invalidate_tag_name('name')
	set.set_needs_invalidate_attribute('name')
	set.set_needs_invalidate_pseudo_class(.hover)
	set.set_needs_invalidate_class('name')
	set.set_needs_invalidate_pseudo_class(.hover)
	assert set.properties().len == 5
	assert set.to_string() == '.name, #name, name, [name], :hover'
}

fn test_invalidation_union_keeps_flags_and_deduplicates_large_feature_sets() {
	mut left := InvalidationSet{}
	mut right := InvalidationSet{}
	left.set_needs_invalidate_self()
	right.set_needs_invalidate_whole_subtree()
	for i in 0 .. 1024 {
		left.set_needs_invalidate_class('item-${i}')
		right.set_needs_invalidate_class('item-${i + 512}')
	}
	left.include_all_from(right)
	assert left.needs_invalidate_self()
	assert left.needs_invalidate_whole_subtree()
	assert left.properties().len == 1536
	assert right.properties().len == 1024
	left.set_needs_invalidate_class('item-1535')
	assert left.properties().len == 1536
	properties := left.properties()
	assert properties[0].name() == 'item-0'
	assert properties.last().name() == 'item-1535'
}
