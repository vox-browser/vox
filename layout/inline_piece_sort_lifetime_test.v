module layout

import css
import dom

#include "inline_piece_lifetime_test.h"

fn C.vox_inline_piece_watch_owner(u32, voidptr)
fn C.vox_inline_piece_collect(u32)
fn C.vox_inline_piece_run_worker(fn ())
fn C.vox_inline_piece_owners_alive() u32

__global inline_piece_lifetime_retained []InlineBoxPiece

struct InlinePieceLifetimeScene {
	document  &dom.Document
	container &BlockContainer
	outer     &InlineNode
	inner     &InlineNode
	state     &LayoutState
	used      &UsedValues
}

fn inline_piece_lifetime_style(display css.DisplayShort, mode css.WritingMode, direction css.Direction) &css.ComputedProperties {
	values := css.ComputedProperties.new()
	mut mutable := unsafe { &css.MutableComputedValues(values) }
	mutable.set_display(css.Display.from_short(display))
	mutable.set_writing_mode(mode)
	mutable.set_direction(direction)
	return values
}

fn inline_piece_lifetime_scene(mode css.WritingMode, direction css.Direction) InlinePieceLifetimeScene {
	document := dom.Document.create(dom.url_about_blank())
	mut container := BlockContainer.new(document, none, inline_piece_lifetime_style(.block, mode, direction))
	container.set_children_are_inline(true)
	mut outer := InlineNode.new(document, none, inline_piece_lifetime_style(.inline_, mode, direction))
	mut inner := InlineNode.new(document, none, inline_piece_lifetime_style(.inline_, mode, direction))
	dom_text := document.create_text_node('abcd')
	text := TextNode.new(document, dom_text.as_node(), 'abcd')
	inner.append_child(unsafe { &Node(text) })
	outer.append_child(unsafe { &Node(inner) })
	container.append_child(unsafe { &Node(outer) })
	// Constructors resolve raw CSS into document-owned values. Install and
	// verify this fixture's writing context on those resolved node values.
	for node in [unsafe { &Node(container) }, unsafe { &Node(outer) }, unsafe { &Node(inner) }] {
		mut values := unsafe { &css.MutableComputedValues(node.computed_values()) }
		display := css.Display.from_short(if node.is_inline_node() { css.DisplayShort.inline_ } else { css.DisplayShort.block })
		values.set_display(display)
		assert node.display() == display
		values.set_writing_mode(mode)
		values.set_direction(direction)
		assert node.computed_values().writing_mode() == mode
		assert node.computed_values().direction() == direction
	}
	assert container.is_block_container()
	assert !container.is_inline_node()
	assert outer.is_inline_node() && inner.is_inline_node()
	assign_layout_indexes(unsafe { &Node(container) })
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	_ = state.get_mutable(unsafe { &NodeWithStyle(outer) })
	_ = state.get_mutable(unsafe { &NodeWithStyle(inner) })
	for line in 0 .. 2 {
		mut box := LineBox.new(direction, mode)
		box.fragments_ << LineBoxFragment.new(unsafe { &Node(text) }, line * 2, 2,
			CSSPixels.new(10), CSSPixels.new(5 + line * 20), CSSPixels.new(20),
			CSSPixels.new(10), CSSPixels.new(0), direction, mode, none)
		used.line_boxes << box
	}
	return InlinePieceLifetimeScene{document, container, outer, inner, state, used}
}

fn inline_piece_lifetime_compute(scene InlinePieceLifetimeScene) []InlineBoxPiece {
	return compute_inline_box_pieces(unsafe { &Node(scene.container) }, scene.used, scene.state)
}

fn inline_piece_lifetime_watch(scene InlinePieceLifetimeScene) {
	$if gcboehm ? {
		C.vox_inline_piece_watch_owner(0, scene.document)
		C.vox_inline_piece_watch_owner(1, scene.container)
	}
}

fn inline_piece_lifetime_discard_worker() {
	scene := inline_piece_lifetime_scene(.horizontal_tb, .ltr)
	pieces := inline_piece_lifetime_compute(scene)
	assert pieces.len == 4
	inline_piece_lifetime_watch(scene)
}

fn inline_piece_lifetime_retain_worker() {
	scene := inline_piece_lifetime_scene(.horizontal_tb, .ltr)
	inline_piece_lifetime_retained = inline_piece_lifetime_compute(scene)
	assert inline_piece_lifetime_retained.len == 4
	inline_piece_lifetime_watch(scene)
}

fn inline_piece_lifetime_read_worker() {
	assert inline_piece_lifetime_retained.len == 4
	for index, piece in inline_piece_lifetime_retained {
		assert piece.line_index == index / 2
		assert piece.node.document_.url.serialize() == 'about:blank'
		assert piece.node.parent() != none
	}
}

fn inline_piece_lifetime_release_worker() {
	inline_piece_lifetime_retained = []InlineBoxPiece{}
}

fn test_inline_piece_sort_callbacks_release_discarded_actual_fragment_tree() {
	$if gcboehm ? {
		C.vox_inline_piece_run_worker(inline_piece_lifetime_discard_worker)
		for _ in 0 .. 8 { C.vox_inline_piece_collect(8) }
		assert C.vox_inline_piece_owners_alive() == 0
	} $else {
		inline_piece_lifetime_discard_worker()
	}
}

fn test_returned_inline_pieces_retain_live_nodes_until_the_returned_array_is_released() {
	$if gcboehm ? {
		C.vox_inline_piece_run_worker(inline_piece_lifetime_retain_worker)
		for _ in 0 .. 8 { C.vox_inline_piece_collect(8) }
		assert C.vox_inline_piece_owners_alive() == 3
		C.vox_inline_piece_run_worker(inline_piece_lifetime_read_worker)
		C.vox_inline_piece_run_worker(inline_piece_lifetime_release_worker)
		for _ in 0 .. 8 { C.vox_inline_piece_collect(8) }
		assert C.vox_inline_piece_owners_alive() == 0
	} $else {
		inline_piece_lifetime_retain_worker()
		gc_collect()
		inline_piece_lifetime_read_worker()
		inline_piece_lifetime_release_worker()
		assert inline_piece_lifetime_retained.len == 0
	}
}

fn test_inline_piece_depth_sort_orders_deepest_then_original_discovery_index() {
	mut order := [InlineBoxPieceDepthOrder{2, 1}, InlineBoxPieceDepthOrder{3, 3},
		InlineBoxPieceDepthOrder{1, 3}, InlineBoxPieceDepthOrder{0, 1}]
	order.sort_with_compare(compare_inline_box_piece_depth)
	assert order.map(it.index) == [1, 3, 0, 2]
	first := order[0]
	assert compare_inline_box_piece_depth(&first, &first) == 0
}

fn test_inline_piece_emission_preserves_original_equal_key_comparison() {
	first := InlineBoxPieceEmissionOrder{9, 1, 2, 3}
	second := InlineBoxPieceEmissionOrder{4, 1, 2, 3}
	assert compare_inline_box_piece_emission(&first, &second) == 0
	assert compare_inline_box_piece_emission(&second, &first) == 0
	mut order := [InlineBoxPieceEmissionOrder{0, 1, 2, 0}, InlineBoxPieceEmissionOrder{1, 0, 2, 2},
		InlineBoxPieceEmissionOrder{2, 0, 1, 4}, InlineBoxPieceEmissionOrder{3, 0, 2, 1}]
	order.sort_with_compare(compare_inline_box_piece_emission)
	assert order.map(it.index) == [2, 3, 1, 0]
}

fn test_actual_nested_inline_pieces_keep_line_outer_inner_order_in_all_writing_directions() {
	for mode in [css.WritingMode.horizontal_tb, .vertical_rl, .vertical_lr] {
		for direction in [css.Direction.ltr, .rtl] {
			scene := inline_piece_lifetime_scene(mode, direction)
			pieces := inline_piece_lifetime_compute(scene)
			assert pieces.len == 4
			for line in 0 .. 2 {
				assert pieces[line * 2].line_index == line
				assert pieces[line * 2 + 1].line_index == line
				assert layout_nodes_same(pieces[line * 2].node, unsafe { &Node(scene.outer) })
				assert layout_nodes_same(pieces[line * 2 + 1].node, unsafe { &Node(scene.inner) })
				assert pieces[line * 2 + 1].corners.inline_start.to_double() == 10
				assert pieces[line * 2 + 1].corners.inline_end.to_double() == 30
				assert pieces[line * 2 + 1].corners.block_start.to_double() == 5 + line * 20
				assert pieces[line * 2 + 1].corners.block_end.to_double() == 15 + line * 20
			}
		}
	}
}
