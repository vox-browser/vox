module css

fn test_invalidation_union_retains_feature_order_flags_and_self_union() {
	mut left := InvalidationSet{}
	left.set_needs_invalidate_self()
	left.set_needs_invalidate_class('same')
	left.set_needs_invalidate_id('same')
	mut right := InvalidationSet{}
	right.set_needs_invalidate_whole_subtree()
	right.set_needs_invalidate_id('same')
	right.set_needs_invalidate_tag_name('same')
	right.set_needs_invalidate_attribute('same')
	right.set_needs_invalidate_pseudo_class(.hover)
	left.include_all_from(right)
	left.include_all_from(right)
	left.include_all_from(left)
	left.include_all_from(InvalidationSet{})
	gc_collect()
	assert left.needs_invalidate_self() && left.needs_invalidate_whole_subtree()
	assert left.properties().len == 5
	assert left.to_string() == '$, *, .same, #same, same, [same], :hover'
	assert right.properties().len == 4
	assert !right.needs_invalidate_self() && right.needs_invalidate_whole_subtree()
}

fn test_invalidation_union_preserves_first_payload_for_duplicate_key() {
	mut left := InvalidationSet{}
	left.add_property(InvalidationProperty{
		type_: .class
		value: 'duplicate'
		pseudo_class: .hover
	})
	mut right := InvalidationSet{}
	right.add_property(InvalidationProperty{
		type_: .class
		value: 'duplicate'
		pseudo_class: .checked
	})
	right.set_needs_invalidate_id('new')
	left.include_all_from(right)
	assert left.properties().len == 2
	assert left.properties()[0].pseudo_class == .hover
	assert left.properties()[1].type_ == .id
	assert right.properties()[0].pseudo_class == .checked
}

fn test_invalidation_union_owns_result_map_after_source_and_result_mutations() {
	mut source := InvalidationSet{}
	source.set_needs_invalidate_class('original')
	mut result := InvalidationSet{}
	result.include_all_from(source)
	source.set_needs_invalidate_id('source-only')
	result.set_needs_invalidate_attribute('result-only')
	gc_collect()
	assert source.to_string() == '.original, #source-only'
	assert result.to_string() == '.original, [result-only]'
	result.properties_.clear()
	gc_collect()
	assert result.is_empty()
	assert source.properties().len == 2
	assert source.to_string() == '.original, #source-only'
}
