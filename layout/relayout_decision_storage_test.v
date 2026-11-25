module layout

import css
import dom
import html
import platform

fn test_fresh_subtree_decisions_survive_geometry_workspace_retirement_and_growth() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	owner := document.native_storage()
	mut allocations := document.enter_native_storage()
	mut state := LayoutState.new()
	mut nodes := []&NodeWithStyle{}
	for index in 0 .. 128 {
		mut node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
		node.set_layout_index(u32(index))
		nodes << node
	}
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(160)),
		AvailableSize.make_indefinite())
	// Each independent context can first populate or grow the shared index
	// inside a different workspace. Later contexts must still be able to write it.
	for batch in 0 .. 8 {
		mut work := begin_document_geometry_scratch(document)
		for node in nodes[batch * 16 .. (batch + 1) * 16] {
			mut values := state.get_mutable(node)
			values.set_content_width(CSSPixels.new(160))
			values.set_had_clearance(true)
			box := unsafe { &Node(node) }
			_ = layout_inside_independent_formatting_context_with_mode(mut state, box,
				mut values, .normal, space)
			values.set_had_clearance(false)
			key := u64(voidptr(box))
			assert state.subtree_layout_decisions_[key] == .fresh
			assert owner.arena.contains(unsafe { &state.subtree_layout_decisions_[key] })
		}
		work.finish()
		for node in nodes[..(batch + 1) * 16] {
			key := u64(voidptr(node))
			assert state.subtree_layout_decisions_[key] == .fresh
			record := state.relayout_records_[node.layout_index()] or { panic('missing relayout record') }
			assert record.space == space
			assert record.before.had_clearance()
			assert record.after.had_clearance()
		}
	}
	assert state.subtree_layout_decisions_.len == nodes.len
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_subtree_layout_comparison_reuses_empty_rare_inputs() {
	missing := &UsedValues{}
	empty := &UsedValues{rare_: &UsedValuesRareData{}}
	margin := &UsedValues{rare_: &UsedValuesRareData{collapsed_flow_margin_bottom_: CSSPixels.new(4)}}
	mut arena := platform.new_arena('subtree input comparison fixture')
	defer { arena.release() }
	entry := arena.enter()
	defer { arena.leave(entry) }
	before := arena.usage().used
	for _ in 0 .. 256 {
		assert subtree_layout_inputs_match(missing, missing)
		assert subtree_layout_inputs_match(missing, empty)
		assert subtree_layout_inputs_difference(missing, empty) == ''
		assert !subtree_layout_inputs_match(margin, missing)
		assert subtree_layout_inputs_difference(margin, missing) == 'collapsed-margin'
	}
	assert arena.usage().used == before
}

fn test_native_layout_pass_slots_and_maps_retire_on_relayout_and_navigation() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(false)
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>
		#column{display:flex;flex-direction:column;height:280px}
		.item{display:flow-root;flex:1}
		</style><div id="column"><div class="item">Retained content</div>
		<div class="item"><input value="editable"></div></div>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	mut previous := unsafe { &LayoutState(nil) }
	for width in [420, 380, 460] {
		previous_arena := if previous != unsafe { nil } {
			previous.used_values_store.layout_pass_arena
		} else {
			unsafe { &platform.Arena(nil) }
		}
		_ = layout_document_typed_in_viewport(document, width, 400)
		result := document_layout_result(document) or { panic('missing document layout') }
		state := result.state
		arena := state.used_values_store.layout_pass_arena
		assert arena != unsafe { nil }
		assert arena.contains(state.used_values_store.pages.data)
		assert arena.contains(state.used_values_store.retained_arena)
		assert state.used_values_store.retained_arena.storage.chunks.len > 0
		assert arena.contains(state.used_values_store.retained_arena.storage.chunks[0])
		assert state.used_values_store.pages.any(it != unsafe { nil } && arena.contains(it))
		mut containing_blocks := 0
		for page in state.used_values_store.pages {
			if page == unsafe { nil } { continue }
			for slot in page.entries {
				if slot == unsafe { nil } { continue }
				assert arena.contains(slot)
				values := unsafe { &UsedValues(slot) }
				if containing := values.containing_block_used_values_ {
					assert arena.contains(containing)
					containing_blocks++
				}
			}
		}
		assert containing_blocks > 0
		assert state.relayout_records_.len > 0
		assert state.text_control_layouts_.len > 0
		for index, record in state.relayout_records_ {
			assert arena.contains(unsafe { &state.relayout_records_[index] })
			assert record.before.containing_block_used_values_ == none
			assert record.after.containing_block_used_values_ == none
			if rare := record.before.rare_ {
				assert !arena.contains(rare)
			}
		}
		for index, record in state.text_control_layouts_ {
			assert arena.contains(unsafe { &state.text_control_layouts_[index] })
			assert record.before.containing_block_used_values_ == none
		}
		if previous != unsafe { nil } {
			assert previous.used_values_store.layout_pass_arena == unsafe { nil }
			assert previous_arena.usage().capacity == 0
			assert previous.used_values_store.pages.len == 0
			assert previous.used_values_store.retained_arena == unsafe { nil }
			assert previous.relayout_records_.len == 0
			assert previous.first_relayout_records_.len == 0
			assert previous.text_control_layouts_.len == 0
		}
		// The viewport has no independent-context record. A cloned attempt
		// must leave the active pass readable after rejecting that root.
		mut attempt_allocations := document.enter_native_storage()
		attempt := try_incremental_relayout(document, result.root, state, state.committed_pass_,
			[result.root])
		attempt_allocations.finish()
		assert attempt.state == unsafe { nil }
		assert voidptr(attempt.failed) == voidptr(result.root)
		assert arena.usage().used > 0
		previous = state
	}
	final_arena := previous.used_values_store.layout_pass_arena
	document.retains_layout_while_inactive = true
	document.did_stop_being_active_document_in_navigable()
	assert voidptr(previous.used_values_store.layout_pass_arena) == voidptr(final_arena)
	assert previous.used_values_store.pages.len > 0
	document.retains_layout_while_inactive = false
	document.did_stop_being_active_document_in_navigable()
	assert previous.used_values_store.layout_pass_arena == unsafe { nil }
	assert previous.used_values_store.pages.len == 0
	assert final_arena.usage().capacity == 0
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	document.release_native_storage()
}
