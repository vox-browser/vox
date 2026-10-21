module css

import platform

fn test_repeated_selector_dependencies_do_not_retain_discarded_graph_copies() {
	selectors := [selector_from_text('.owner > .first + [tail]'),
		selector_from_text('.owner > .second + [tail]'),
		selector_from_text('.owner:has(> #flag:checked) .second + [tail]')]
	mut reference := StyleInvalidationData{}
	for selector in selectors {
		_ = build_invalidation_sets_for_selector_impl(mut reference, selector, .no,
			make_invalidate_self_invalidation())
	}
	mut storage := platform.new_arena('repeated selector dependencies')
	entry := storage.enter()
	mut data := StyleInvalidationData{}
	for selector in selectors { build_owned_selector_invalidation(mut data, selector, false) }
	before := storage.usage().used
	for _ in 0 .. 128 {
		for selector in selectors { build_owned_selector_invalidation(mut data, selector, false) }
	}
	growth := storage.usage().used - before
	storage.leave(entry)
	$if prealloc { assert growth == 0, '${growth} bytes for already-covered dependencies' }
	assert_owned_invalidation_matches_reference(&data, &reference)
	storage.release()
}

fn test_whole_subtree_selector_union_does_not_copy_discarded_rule_payloads() {
	selector := selector_from_text('.owner > .child + [tail]')
	mut data := StyleInvalidationData{}
	mut reference := StyleInvalidationData{}
	for boundary in [true, false, true] {
		build_owned_selector_invalidation(mut data, selector, boundary)
		root := if boundary { make_invalidate_whole_subtree_invalidation() } else { make_invalidate_self_invalidation() }
		_ = build_invalidation_sets_for_selector_impl(mut reference, selector, .no, root)
		assert_owned_invalidation_matches_reference(&data, &reference)
	}
	mut destination := InvalidationPlan{invalidate_whole_subtree: true}
	self := InvalidationPlan{invalidate_self: true}
	assert !invalidation_plan_covers(&destination, &self)
	destination.include_all_from(&self)
	assert invalidation_plan_covers(&destination, &self)
}
