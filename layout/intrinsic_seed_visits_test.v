module layout

import css
import dom

fn seed_visits_fixture() (&dom.Document, []&Box) {
	document := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut boxes := []&Box{}
	for _ in 0 .. 67 { boxes << Box.new(document, none, style) }
	mut outer := unsafe { &Node(boxes[0]) }
	outer.append_child(unsafe { &Node(boxes[1]) })
	outer.append_child(unsafe { &Node(boxes[2]) })
	boxes[1].containing_block_ = boxes[0]
	boxes[2].containing_block_ = boxes[0]
	mut measured := unsafe { &Node(boxes[2]) }
	for index in 3 .. boxes.len {
		boxes[index].containing_block_ = if index % 2 == 0 { boxes[1] } else { boxes[2] }
		measured.append_child(unsafe { &Node(boxes[index]) })
	}
	assert assign_layout_indexes(outer) == u32(boxes.len)
	return document, boxes
}

fn seed_visits_source(boxes []&Box) &LayoutState {
	mut source := LayoutState.new()
	for index in 0 .. 2 {
		mut value := source.get_mutable(unsafe { &NodeWithStyle(boxes[index]) })
		value.set_content_width(CSSPixels.new(200 - index * 50))
		value.set_content_height(CSSPixels.new(100 - index * 25))
		value.set_has_definite_height(true)
	}
	source.enable_measurement_chunk_pool()
	source.prepare_intrinsic_seed_visits(unsafe { &Node(boxes[0]) })
	return source
}

fn seed_visits_assert_matches_general(mut source LayoutState, root &Node, boxes []&Box) {
	styled := root.as_node_with_style() or { panic('missing styled root') }
	mut actual := source.new_measurement_for_subtree(styled)
	defer { actual.release_measurement() }
	mut expected := source.new_measurement_for_subtree(styled)
	defer { expected.release_measurement() }
	populate_intrinsic_containing_block_chain(mut actual, mut source, root)
	populate_intrinsic_external_containing_blocks(mut actual, mut source, root, root)
	populate_intrinsic_containing_block_chain(mut expected, mut source, root)
	mut visited := map[u32]bool{}
	populate_intrinsic_external_containing_blocks_once(mut expected, mut source, root, root, mut visited)
	for box in boxes {
		value := unsafe { &NodeWithStyle(box) }
		if a := actual.try_get(value) {
			b := expected.try_get(value) or { panic('unexpected seeded value') }
			assert a.content_width() == b.content_width()
			assert a.content_height() == b.content_height()
			assert a.has_definite_width() == b.has_definite_width()
			assert a.has_definite_height() == b.has_definite_height()
			assert a.containing_block_used_values() == none
		} else { assert expected.try_get(value) == none }
	}
}

fn test_seed_visits_match_general_hoisted_chains_and_copy_current_source_values() {
	mut document, boxes := seed_visits_fixture()
	defer { document.finalize() }
	mut source := seed_visits_source(boxes)
	defer { source.release_measurement_chunk_pool() }
	root := unsafe { &Node(boxes[2]) }
	seed_visits_assert_matches_general(mut source, root, boxes)
	mut first := source.new_measurement_for_subtree(unsafe { &NodeWithStyle(boxes[2]) })
	defer { first.release_measurement() }
	populate_intrinsic_external_containing_blocks(mut first, mut source, root, root)
	outside := unsafe { &NodeWithStyle(boxes[1]) }
	assert first.get(outside).content_width() == CSSPixels.new(150)
	mut current := source.get_mutable(outside)
	current.set_content_width(CSSPixels.new(333))
	current.set_indefinite_content_height()
	seed_visits_assert_matches_general(mut source, root, boxes)
	assert first.get(outside).content_width() == CSSPixels.new(150)
	assert first.get(outside).has_definite_height()
	if !disable_intrinsic_seed_visits {
		assert source.measurement_chunk_pool_.intrinsic_seed_epoch_ == 3
		assert source.measurement_chunk_pool_.intrinsic_seed_stamps_.len == boxes.len
	}
}

fn test_seed_visits_wrap_clears_old_epochs_before_visiting_again() {
	mut document, boxes := seed_visits_fixture()
	defer { document.finalize() }
	mut source := seed_visits_source(boxes)
	defer { source.release_measurement_chunk_pool() }
	mut pool := source.measurement_chunk_pool_
	pool.intrinsic_seed_epoch_ = u32(0xffffffff)
	for mut stamp in pool.intrinsic_seed_stamps_ { stamp = 1 }
	seed_visits_assert_matches_general(mut source, unsafe { &Node(boxes[2]) }, boxes)
	if !disable_intrinsic_seed_visits { assert pool.intrinsic_seed_epoch_ == 1 }
}

fn test_seed_visits_nested_measurements_keep_outer_geometry_independent() {
	mut document, boxes := seed_visits_fixture()
	defer { document.finalize() }
	mut source := seed_visits_source(boxes)
	defer { source.release_measurement_chunk_pool() }
	mut outer := source.new_measurement_for_subtree(unsafe { &NodeWithStyle(boxes[2]) })
	defer { outer.release_measurement() }
	populate_intrinsic_external_containing_blocks(mut outer, mut source, unsafe { &Node(boxes[2]) }, unsafe { &Node(boxes[2]) })
	seed_visits_assert_matches_general(mut outer, unsafe { &Node(boxes[4]) }, boxes)
	assert outer.get(unsafe { &NodeWithStyle(boxes[1]) }).content_width() == CSSPixels.new(150)
	assert outer.try_get(unsafe { &NodeWithStyle(boxes[2]) }) == none
}

fn test_seed_visits_mutated_reindexed_and_closed_trees_use_general_fallback() {
	mut document, boxes := seed_visits_fixture()
	defer { document.finalize() }
	mut source := seed_visits_source(boxes)
	root := unsafe { &Node(boxes[2]) }
	seed_visits_assert_matches_general(mut source, root, boxes)
	mut parent := unsafe { &Node(boxes[0]) }
	mut extra := Box.new(document, none, css.ComputedProperties.new())
	parent.append_child(unsafe { &Node(extra) })
	assert !parent.tree_order_.valid
	epoch := source.measurement_chunk_pool_.intrinsic_seed_epoch_
	seed_visits_assert_matches_general(mut source, root, boxes)
	assert source.measurement_chunk_pool_.intrinsic_seed_epoch_ == epoch
	assert assign_layout_indexes(parent) == u32(boxes.len + 1)
	seed_visits_assert_matches_general(mut source, root, boxes)
	assert source.measurement_chunk_pool_.intrinsic_seed_epoch_ == epoch
	source.release_measurement_chunk_pool()
	assert source.measurement_chunk_pool_ == unsafe { nil }
	seed_visits_assert_matches_general(mut source, root, boxes)
}
