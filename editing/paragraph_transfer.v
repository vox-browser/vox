// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ParagraphTransfer.{h,cpp}.
module editing

import dom

pub enum ParagraphTransferStyle {
	match_destination
	preserve_markup
	preserve_visual_appearance
}

pub enum ParagraphTransferSeam {
	preserve
	coalesce_destination_text
}

pub struct ParagraphTransferOptions {
pub:
	source_style      ParagraphTransferStyle = .preserve_markup
	destination_style ParagraphTransferStyle = .preserve_markup
	seam              ParagraphTransferSeam  = .preserve
}

pub struct ParagraphTransferResult {
pub:
	first_node            &dom.Node
	last_node             &dom.Node
	start                 dom.BoundaryPoint
	end                   dom.BoundaryPoint
	destination_text_seam ?dom.BoundaryPoint
}

fn prepare_paragraph_transfer_style(source_paragraph &dom.Node, destination dom.BoundaryPoint, options ParagraphTransferOptions) {
	mut mutable_source := unsafe { &dom.Node(source_paragraph) }
	if options.source_style == .match_destination {
		remove_single_run_legacy_font_style(mut mutable_source)
	} else if options.source_style == .preserve_visual_appearance {
		materialize_single_run_legacy_font_style(mut mutable_source)
	}
	if options.destination_style == .preserve_visual_appearance {
		if destination_paragraph := inserted_content_containing_block(destination.node) {
			mut mutable_destination := unsafe { &dom.Node(destination_paragraph) }
			materialize_single_run_legacy_font_style(mut mutable_destination)
		}
	}
}

pub fn transfer_paragraph_contents(source_paragraph &dom.Node, destination dom.BoundaryPoint, options ParagraphTransferOptions) ParagraphTransferResult {
	assert source_paragraph.parent() != none
	mut tracked_destination := MutationTrackedRange.new(dom.Range.create_from_boundary_points(destination.node,
		destination.offset, destination.node, destination.offset))
	prepare_paragraph_transfer_style(source_paragraph, destination, options)

	if !source_paragraph.has_children() {
		mut mutable_source := unsafe { &dom.Node(source_paragraph) }
		mutable_source.remove(false)
		insertion_point := tracked_destination.range().start()
		tracked_destination.release()
		return ParagraphTransferResult{
			first_node: insertion_point.node
			last_node: insertion_point.node
			start: insertion_point
			end: insertion_point
			destination_text_seam: none
		}
	}

	first_moved_node := source_paragraph.first_child() or { panic('source paragraph lost its first child') }
	last_moved_node := source_paragraph.last_child() or { panic('source paragraph lost its last child') }
	insertion_point := tracked_destination.range().start()
	source_is_at_destination := if source_parent := source_paragraph.parent() {
		source_parent == insertion_point.node && source_paragraph.index() == insertion_point.offset
	} else {
		false
	}
	if source_is_at_destination {
		unwrap_node_preserving_ranges(source_paragraph)
	} else {
		mut insertion_offset := insertion_point.offset
		for source_paragraph.first_child() != none {
			child := source_paragraph.first_child() or { break }
			move_node_preserving_ranges(child, insertion_point.node, insertion_offset)
			insertion_offset++
		}
		mut mutable_source := unsafe { &dom.Node(source_paragraph) }
		mutable_source.remove(false)
	}

	mut start := tracked_destination.range().start()
	mut end := end_boundary_of_node(last_moved_node)
	mut destination_text_seam := ?dom.BoundaryPoint(none)
	if options.seam == .coalesce_destination_text && first_moved_node.is_text() {
		destination_text := unsafe { &dom.Text(first_moved_node) }
		if previous := first_moved_node.previous_sibling() {
			if previous.is_text() {
				inserted_text := unsafe { &dom.Text(previous) }
				inserted_length := inserted_text.length_in_utf16_code_units()
				mut mutable_destination_text := unsafe { &dom.Text(destination_text) }
				mutable_destination_text.insert_data(0, inserted_text.data()) or { panic(err) }
				mut mutable_inserted_text := unsafe { &dom.Node(inserted_text.as_node()) }
				mutable_inserted_text.remove(false)
				seam := dom.BoundaryPoint{
					node: destination_text.as_node()
					offset: inserted_length
				}
				destination_text_seam = seam
				start = seam
				end = end_boundary_of_node(last_moved_node)
			}
		}
	}
	tracked_destination.release()
	return ParagraphTransferResult{
		first_node: first_moved_node
		last_node: last_moved_node
		start: start
		end: end
		destination_text_seam: destination_text_seam
	}
}
