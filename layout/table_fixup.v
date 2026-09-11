// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom

fn table_track_group(display css.Display) bool {
	return display.is_table_row_group() || display.is_table_header_group()
		|| display.is_table_footer_group() || display.is_table_column_group()
}

fn proper_table_child(node &Node) bool {
	display := node.display()
	return table_track_group(display) || display.is_table_row() || display.is_table_column()
		|| display.is_table_caption()
}

fn table_non_root_box(node &Node) bool {
	if !node.is_box() || !node.has_style() {
		return false
	}
	display := node.display()
	return display.is_table_row() || display.is_table_column()
		|| display.is_table_row_group() || display.is_table_header_group()
		|| display.is_table_footer_group() || display.is_table_column_group()
		|| display.is_table_cell() || display.is_table_caption()
}

fn tabular_container(node &Node) bool {
	if !node.is_box() || !node.has_style() {
		return false
	}
	display := node.display()
	return display.is_table_inside() || display.is_table_row()
		|| display.is_table_row_group() || display.is_table_header_group()
		|| display.is_table_footer_group()
}

fn ignorable_table_whitespace(node &Node) bool {
	if text := node.as_text_node() {
		return string_is_ascii_whitespace(text.source_text_)
	}
	// Tree construction has already collected inline text runs in anonymous
	// block containers. For the table fixup whitespace rules that anonymous
	// wrapper is transparent: a wrapper containing only collapsible whitespace
	// is the same ignorable sequence as its text descendants.
	if !node.is_anonymous() || !node.has_children() {
		return false
	}
	for child in node.children() {
		if !ignorable_table_whitespace(child) {
			return false
		}
	}
	return true
}

enum AnonymousTableBoxKind {
	box
	cell
}

fn anonymous_table_box(document &dom.Document, parent &Node, display css.Display, kind AnonymousTableBoxKind) &Node {
	style := parent.computed_values().clone_for_anonymous_with_display(display)
	mut wrapper := if kind == .cell {
		unsafe { &Node(BlockContainer.new(document, none, style)) }
	} else {
		unsafe { &Node(Box.new(document, none, style)) }
	}
	wrapper.anonymous_ = true
	return wrapper
}

fn flush_table_fixup_sequence(mut rebuilt []&Node, mut sequence []&Node, parent &Node, document &dom.Document, matcher fn (&Node) bool, display css.Display, kind AnonymousTableBoxKind) {
	if sequence.len == 0 {
		return
	}
	// Whitespace after the last matching table-internal box stays outside the
	// generated wrapper. Only whitespace between two such boxes is discarded.
	mut trailing_start := sequence.len
	for trailing_start > 0 && !matcher(sequence[trailing_start - 1]) {
		trailing_start--
	}
	trailing := sequence[trailing_start..].clone()
	sequence.trim(trailing_start)
	mut all_whitespace := true
	for child in sequence {
		if !ignorable_table_whitespace(child) {
			all_whitespace = false
			break
		}
	}
	if all_whitespace {
		rebuilt << sequence
		rebuilt << trailing
		sequence.clear()
		return
	}
	mut wrapper := anonymous_table_box(document, parent, display, kind)
	wrapper_style := wrapper.as_node_with_style() or { return }
	attach_children_maintaining_inline_invariant(mut wrapper, sequence.clone(), document, wrapper_style.computed_values())
	rebuilt << wrapper
	rebuilt << trailing
	sequence.clear()
}

fn wrap_table_child_sequences(mut parent Node, document &dom.Document, matcher fn (&Node) bool, display css.Display, kind AnonymousTableBoxKind) {
	original := parent.children_.clone()
	mut rebuilt := []&Node{}
	mut sequence := []&Node{}
	for child in original {
		if matcher(child) || (sequence.len > 0 && ignorable_table_whitespace(child)) {
			sequence << child
			continue
		}
		flush_table_fixup_sequence(mut rebuilt, mut sequence, parent, document, matcher, display, kind)
		rebuilt << child
	}
	flush_table_fixup_sequence(mut rebuilt, mut sequence, parent, document, matcher, display, kind)
	parent.replace_children(rebuilt)
}

fn table_not_proper_child(node &Node) bool {
	return !node.has_style() || !proper_table_child(node)
}

fn table_not_row(node &Node) bool {
	return !node.has_style() || !node.display().is_table_row()
}

fn table_not_cell(node &Node) bool {
	return !node.has_style() || !node.display().is_table_cell()
}

fn table_is_cell(node &Node) bool {
	return node.has_style() && node.display().is_table_cell()
}

fn table_is_row(node &Node) bool {
	return node.has_style() && node.display().is_table_row()
}

fn table_is_proper_child(node &Node) bool {
	return node.has_style() && proper_table_child(node)
}

fn remove_irrelevant_table_children(mut node Node) {
	if node.display().is_table_column() {
		node.replace_children([]&Node{})
	} else if node.display().is_table_column_group() {
		mut kept := []&Node{}
		for child in node.children_ {
			if child.display().is_table_column() {
				kept << child
			}
		}
		node.replace_children(kept)
	}
	// Discard whitespace between two table-internal siblings. Also discard
	// leading/trailing whitespace of authored tabular containers when its one
	// immediate sibling is table-internal (CSS Tables fixup step 1).
	original := node.children_.clone()
	mut kept := []&Node{}
	for index, child in original {
		previous_is_table_non_root := index > 0 && table_non_root_box(original[index - 1])
		next_is_table_non_root := index + 1 < original.len
			&& table_non_root_box(original[index + 1])
		between_table_non_roots := previous_is_table_non_root && next_is_table_non_root
		at_tabular_edge := child.is_box() && tabular_container(node) && !node.is_anonymous()
			&& (index == 0 || index == original.len - 1)
			&& (if index > 0 { previous_is_table_non_root } else { next_is_table_non_root })
		if ignorable_table_whitespace(child) && (between_table_non_roots || at_tabular_edge) {
			continue
		}
		kept << child
	}
	if kept.len != original.len {
		node.replace_children(kept)
	}
	for child in node.children_.clone() {
		mut mutable_child := unsafe { &Node(child) }
		remove_irrelevant_table_children(mut mutable_child)
	}
}

fn generate_table_child_wrappers(mut node Node, document &dom.Document) {
	for child in node.children_.clone() {
		mut mutable_child := unsafe { &Node(child) }
		generate_table_child_wrappers(mut mutable_child, document)
	}
	if node.display().is_table_inside() {
		wrap_table_child_sequences(mut node, document, table_not_proper_child, css.Display.from_internal(.table_row), .box)
	}
	if node.display().is_table_row_group() || node.display().is_table_header_group()
		|| node.display().is_table_footer_group() {
		wrap_table_child_sequences(mut node, document, table_not_row, css.Display.from_internal(.table_row), .box)
	}
	if node.display().is_table_row() {
		wrap_table_child_sequences(mut node, document, table_not_cell, css.Display.from_internal(.table_cell), .cell)
	}
}

fn generate_missing_table_parents(mut node Node, document &dom.Document) {
	if !node.display().is_table_row() {
		wrap_table_child_sequences(mut node, document, table_is_cell, css.Display.from_internal(.table_row), .box)
	}
	if !node.display().is_table_inside() && !node.display().is_table_row_group()
		&& !node.display().is_table_header_group() && !node.display().is_table_footer_group()
		&& !node.display().is_table_column_group() {
		display := if node.display().is_inline_outside() {
			css.Display.from_short(.inline_table)
		} else {
			css.Display.from_short(.table)
		}
		wrap_table_child_sequences(mut node, document, table_is_row, display, .box)
		wrap_table_child_sequences(mut node, document, table_is_proper_child, display, .box)
	}
	for child in node.children_.clone() {
		mut mutable_child := unsafe { &Node(child) }
		generate_missing_table_parents(mut mutable_child, document)
	}
}

fn wrap_table_roots(mut node Node, document &dom.Document) {
	mut rebuilt := []&Node{}
	for child in node.children_.clone() {
		if child.display().is_table_inside() && !node.is_table_wrapper() {
			child_styled := child.as_node_with_style() or {
				rebuilt << child
				continue
			}
			mut table_style := unsafe { &css.ComputedProperties(child_styled.computed_values()) }
			style := table_style.take_properties_for_table_wrapper()
			mut mutable_child_style := unsafe { &NodeWithStyle(child_styled) }
			mutable_child_style.computed_values_ = css.resolve_computed_values_for_document(table_style, document)
			mut wrapper := unsafe { &Node(TableWrapper.new(document, none, style)) }
			wrapper.anonymous_ = true
			wrapper.append_child(child)
			mut table_root := unsafe { &Node(child) }
			table_root.set_has_been_wrapped_in_table_wrapper(true)
			rebuilt << wrapper
		} else {
			rebuilt << child
		}
	}
	node.replace_children(rebuilt)
	for child in node.children_.clone() {
		mut mutable_child := unsafe { &Node(child) }
		wrap_table_roots(mut mutable_child, document)
	}
}

fn append_missing_table_cells(mut table Node, document &dom.Document) {
	mut rows := []&Node{}
	collect_typed_table_rows(table, mut rows)
	placements, column_count := calculate_table_cell_placements(rows)
	if column_count == 0 {
		return
	}
	for row_index, row in rows {
		mut occupied := map[int]bool{}
		for placement in placements {
			if row_index >= placement.row && row_index < placement.row + placement.row_span {
				for column in placement.column .. placement.column + placement.column_span {
					occupied[column] = true
				}
			}
		}
		mut mutable_row := unsafe { &Node(row) }
		for column in 0 .. column_count {
			if occupied[column] {
				continue
			}
			cell := anonymous_table_box(document, row, css.Display.from_internal(.table_cell), .cell)
			// Upstream missing-cells fixup explicitly centers a zero-height cell so
			// its used border box grows symmetrically to the row height.
			if styled := cell.as_node_with_style() {
				mut computed := unsafe { &css.MutableComputedValues(styled.computed_values()) }
				computed.set_vertical_align(.middle)
			}
			mutable_row.append_child(cell)
		}
	}
}

fn fix_missing_cells_in_tables(mut node Node, document &dom.Document) {
	if node.display().is_table_inside() {
		append_missing_table_cells(mut node, document)
	}
	for child in node.children_.clone() {
		mut mutable_child := unsafe { &Node(child) }
		fix_missing_cells_in_tables(mut mutable_child, document)
	}
}

fn fixup_table_tree(mut root Node, document &dom.Document) {
	remove_irrelevant_table_children(mut root)
	generate_table_child_wrappers(mut root, document)
	// A row generated by the first rule can itself require cells from the
	// third rule. Run the child-wrapper pass again over those new boxes.
	generate_table_child_wrappers(mut root, document)
	generate_missing_table_parents(mut root, document)
	fix_missing_cells_in_tables(mut root, document)
	wrap_table_roots(mut root, document)
}
