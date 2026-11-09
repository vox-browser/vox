module layout

import os

const disable_extended_inline_measurement_roots = os.getenv('VOX_DISABLE_EXTENDED_INLINE_MEASUREMENT_ROOTS') != ''
const disable_marker_inline_measurement_reuse = os.getenv('VOX_DISABLE_MARKER_INLINE_MEASUREMENT_REUSE') != ''
const extended_inline_measurement_diagnostics = os.getenv('VOX_EXTENDED_INLINE_MEASUREMENT_DIAGNOSTICS') != ''
__global extended_inline_measurement_reported u8

fn inline_measurement_marker_is_external(node &Node) bool {
	if marker := node.as_list_item_marker_box() {
		return marker.list_style_position() == .outside
	}
	return false
}

// The outer list/table algorithm still sizes and positions this box. Its
// disposable inline question depends on the supplied content dimensions and
// the same closed inline children as an ordinary paragraph. An outside marker
// has its own formatting run and is skipped by InlineLevelIterator too.
fn measurement_inline_workspace_is_closed(root &Node) bool {
	marker_root := root.is_list_item_marker_box()
	if !root.is_list_item_box() && !root.display().is_table_cell() && !marker_root {
		return inline_layout_workspace_is_closed(root, true)
	}
	// Marker text is resolved by layout_list_item_marker() before this run.
	// Retain only its single text child, whose actual string and font owner
	// are revalidated on every hit. Images and authored nested content keep
	// their full algorithms.
	if marker_root && (disable_marker_inline_measurement_reuse || root.child_count() != 1
		|| !(root.first_child() or { return false }).is_text_node()) { return false }
	if root.is_svg_box() || root.is_replaced_box() || root.is_atomic_inline()
		|| root.is_floating() || root.is_positioned()
		|| root.computed_values().writing_mode() != .horizontal_tb
		|| line_clamp_is_active(root.computed_values()) { return false }
	if metrics := root.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	for child in root.children() {
		if root.is_list_item_box() && inline_measurement_marker_is_external(child) { continue }
		if !inline_layout_workspace_is_closed(child, false) { return false }
	}
	return true
}

fn report_extended_inline_measurement(root &Node) {
	if !extended_inline_measurement_diagnostics { return }
	kind, bit := if root.is_list_item_marker_box() { 'text marker', u8(4) }
		else if root.is_list_item_box() { 'list item', u8(1) }
		else if root.display().is_table_cell() { 'table cell', u8(2) }
		else { return }
	if extended_inline_measurement_reported & bit != 0 { return }
	extended_inline_measurement_reported |= bit
	eprintln('Vox inline measurement: reused principal lines of a ${kind}')
}
