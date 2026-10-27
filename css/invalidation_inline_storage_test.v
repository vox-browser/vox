module css

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_default_and_single_invalidation_properties_need_no_map_allocation() {
	property := InvalidationProperty{type_: .class, value: 'inline', pseudo_class: .hover}
	duplicate := InvalidationProperty{type_: .class, value: 'inline', pseudo_class: .checked}
	key := property.key()
	mut retained := []InvalidationSet{len: 1024}
	mut matches := 0
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for index in 0 .. retained.len {
		mut set := InvalidationSet{}
		if set.is_empty() && !set.has_properties() && set.property_count() == 0
			&& set.additional_properties_ == none {
			matches++
		}
		// The canonical key is prepared outside the window. First insertion and
		// duplicate detection themselves need neither a map nor a map holder.
		set.add_stored_property(key, property)
		set.add_stored_property(key, duplicate)
		if set.has_properties() && set.property_count() == 1
			&& set.additional_properties_ == none && set.first_property_.pseudo_class == .hover {
			matches++
		}
		retained[index] = set
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert matches == 2048
	assert allocated == 0
	gc_collect()
	assert retained[1023].to_string() == '.inline'
	assert retained[1023].properties()[0].pseudo_class == .hover
}

fn test_invalidation_inline_slot_promotes_only_for_a_second_distinct_key() {
	mut set := InvalidationSet{}
	set.add_property(InvalidationProperty{type_: .class, value: '', pseudo_class: .hover})
	set.add_property(InvalidationProperty{type_: .class, value: '', pseudo_class: .checked})
	assert set.additional_properties_ == none
	assert set.first_property_key_ == '.'
	assert set.properties()[0].pseudo_class == .hover
	set.set_needs_invalidate_id('')
	assert set.additional_properties_ != none
	assert set.property_count() == 2
	set.set_needs_invalidate_tag_name('café.#[]')
	set.set_needs_invalidate_attribute('')
	set.set_needs_invalidate_pseudo_class(.hover)
	set.set_needs_invalidate_class('')
	set.set_needs_invalidate_id('')
	assert set.property_count() == 5
	assert set.to_string() == '., #, café.#[], [], :hover'
	assert set.properties()[0].pseudo_class == .hover
	gc_collect()
	assert set.properties()[1].type_ == .id
}

fn test_invalidation_overflow_keeps_header_growth_order_and_duplicate_payloads() {
	mut set := InvalidationSet{}
	for index in 0 .. 512 {
		set.add_property(InvalidationProperty{
			type_: .class
			value: 'feature-${index}'
			pseudo_class: .hover
		})
		set.add_property(InvalidationProperty{
			type_: .class
			value: 'feature-${index}'
			pseudo_class: .checked
		})
	}
	assert set.property_count() == 512
	properties := set.properties()
	assert properties.len == 512
	for index, property in properties {
		assert property.name() == 'feature-${index}'
		assert property.pseudo_class == .hover
	}
	gc_collect()
	assert set.property_count() == 512
	assert set.properties().last().name() == 'feature-511'
}

fn test_invalidation_inline_and_overflow_unions_own_independent_results_and_snapshots() {
	mut source := InvalidationSet{}
	source.set_needs_invalidate_whole_subtree()
	source.set_needs_invalidate_class('source')
	source.set_needs_invalidate_id('tail')
	mut result := InvalidationSet{}
	result.set_needs_invalidate_self()
	result.set_needs_invalidate_attribute('first')
	result.include_all_from(source)
	result.include_all_from(source)
	result.include_all_from(result)
	mut snapshot := result.properties()
	snapshot[0].value = 'snapshot-only'
	source.set_needs_invalidate_tag_name('source-only')
	result.set_needs_invalidate_class('result-only')
	assert source.to_string() == '*, .source, #tail, source-only'
	assert result.to_string() == '$, *, [first], .source, #tail, .result-only'
	source.clear_properties()
	result.clear_properties()
	gc_collect()
	assert !source.has_properties() && source.needs_invalidate_whole_subtree()
	assert !result.has_properties() && result.needs_invalidate_self()
	assert result.needs_invalidate_whole_subtree()
	assert !result.is_empty()
	assert result.additional_properties_ == none
	assert snapshot.len == 3
	assert snapshot[0].name() == 'snapshot-only'
	assert snapshot[1].name() == 'source'
	assert snapshot[2].name() == 'tail'
}

struct InlineInvalidationVisitCollector {
	stop_after int
mut:
	names []string
}

fn test_invalidation_flags_inline_and_overflow_callbacks_keep_order_and_early_stop() {
	mut set := InvalidationSet{}
	set.set_needs_invalidate_self()
	set.set_needs_invalidate_whole_subtree()
	set.set_needs_invalidate_class('first')
	set.set_needs_invalidate_id('second')
	set.set_needs_invalidate_tag_name('third')
	expected := [r'$', '*', '.first', '#second', 'third']
	for stop in 1 .. 6 {
		collector := &InlineInvalidationVisitCollector{stop_after: stop}
		set.for_each_property(fn [collector] (property InvalidationProperty) bool {
			unsafe {
				mut state := &InlineInvalidationVisitCollector(collector)
				state.names << property.to_string()
				return state.names.len < state.stop_after
			}
		})
		assert collector.names == expected[..stop]
	}
}

fn test_inline_invalidation_value_copies_and_registration_keep_independent_headers() {
	mut original := InvalidationSet{}
	original.set_needs_invalidate_class('inline')
	mut copy := original
	copy.set_needs_invalidate_id('copy-only')
	original.set_needs_invalidate_attribute('original-only')
	assert original.to_string() == '.inline, [original-only]'
	assert copy.to_string() == '.inline, #copy-only'
	mut reset_copy := copy
	reset_copy.set_needs_invalidate_whole_subtree()
	reset_copy.clear_properties()
	assert reset_copy.needs_invalidate_whole_subtree()
	assert !copy.needs_invalidate_whole_subtree()
	assert copy.to_string() == '.inline, #copy-only'
	copy.set_needs_invalidate_self()
	mut data := StyleInvalidationData.new()
	add_invalidation_plan_for_properties(mut data, copy, make_invalidate_self_invalidation())
	gc_collect()
	assert data.invalidation_plans.keys() == ['.inline', '#copy-only']
	assert data.invalidation_plan_properties['.inline'].name() == 'inline'
	assert data.invalidation_plan_properties['#copy-only'].type_ == .id
	assert r'$' !in data.invalidation_plans && '*' !in data.invalidation_plans
	assert original.to_string() == '.inline, [original-only]'
	assert copy.to_string() == '$, .inline, #copy-only'
}

// Keep the previous field-map traversal as an independent entry-snapshot
// oracle. Replacing the whole record leaves its original iteration header live.
struct LegacyInlineInvalidationIteration {
mut:
 properties_ map[string]InvalidationProperty
}

fn (set &LegacyInlineInvalidationIteration) for_each_property(callback fn (InvalidationProperty) bool) {
 for _, property in set.properties_ {
  if !callback(property) {
   return
  }
 }
}

struct LegacyInlineInvalidationCollector {
 target &LegacyInlineInvalidationIteration
mut:
 names []string
}

struct InlineInvalidationReplacementCollector {
 target &InvalidationSet
mut:
 names []string
}

fn test_invalidation_property_callback_replacement_keeps_legacy_iteration_entry_snapshot() {
 mut legacy := &LegacyInlineInvalidationIteration{}
 legacy.properties_['.old-first'] = InvalidationProperty.class('old-first')
 legacy.properties_['#old-tail'] = InvalidationProperty.id('old-tail')
 legacy_collector := &LegacyInlineInvalidationCollector{target: legacy}
 legacy.for_each_property(fn [legacy_collector] (property InvalidationProperty) bool {
  unsafe {
   mut state := &LegacyInlineInvalidationCollector(legacy_collector)
   state.names << property.to_string()
   if state.names.len == 1 {
    mut replacement := LegacyInlineInvalidationIteration{}
    replacement.properties_['[new-first]'] = InvalidationProperty.attribute('new-first')
    replacement.properties_['tag:new-tail'] = InvalidationProperty.tag_name('new-tail')
    mut target := &LegacyInlineInvalidationIteration(state.target)
    *target = replacement
    gc_collect()
   }
   return true
  }
 })
 mut set := &InvalidationSet{}
 set.set_needs_invalidate_class('old-first')
 set.set_needs_invalidate_id('old-tail')
 collector := &InlineInvalidationReplacementCollector{target: set}
 set.for_each_property(fn [collector] (property InvalidationProperty) bool {
  unsafe {
   mut state := &InlineInvalidationReplacementCollector(collector)
   state.names << property.to_string()
   if state.names.len == 1 {
    mut replacement := InvalidationSet{}
    replacement.set_needs_invalidate_attribute('new-first')
    replacement.set_needs_invalidate_tag_name('new-tail')
    mut target := &InvalidationSet(state.target)
    *target = replacement
    gc_collect()
   }
   return true
  }
 })
 assert legacy_collector.names == ['.old-first', '#old-tail']
 assert collector.names == legacy_collector.names
 assert set.to_string() == '[new-first], new-tail'
 assert legacy.properties_['[new-first]'].name() == 'new-first'
 assert legacy.properties_['tag:new-tail'].name() == 'new-tail'
 gc_collect()
 assert collector.names == ['.old-first', '#old-tail']
}
