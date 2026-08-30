module layout

import math

pub fn build_paint_tree(root LayoutNodeState) []string { mut result := root.paintables(); if result.len == 0 { result << '${root.id}:paintable' }; return result }
pub fn compute_columns_total_candidate_width(columns []f64, gap f64) f64 { return layout_sum(columns) + gap * f64(math.max(0, columns.len - 1)) }
pub fn css_clamp(value f64, minimum f64, maximum f64) f64 { return layout_clamp(value, minimum, maximum) }
pub fn dominant_baseline_offset(ascent f64, descent f64, baseline string) f64 { return match baseline { 'middle' { (ascent - descent) / 2 } 'text-after-edge', 'bottom' { -descent } else { ascent } } }
pub fn resolve_dominant_baseline_metric(ascent f64, descent f64, baseline string) f64 { return dominant_baseline_offset(ascent, descent, baseline) }
pub fn gap_to_px(gap f64, percentage_basis f64, percentage bool) f64 { return if percentage { gap * percentage_basis / 100.0 } else { gap } }
pub fn width_is_auto_or_indefinite_percentage(auto bool, percentage f64, basis_definite bool) bool { return auto || (percentage != 0 && !basis_definite) }
pub fn margin_box_rect(rect LayoutRect, top f64, right f64, bottom f64, left f64) LayoutRect { return LayoutRect{rect.x - left, rect.y - top, rect.width + left + right, rect.height + top + bottom} }
pub fn to_alignment(value string) StaticPositionAlignment { return match value { 'center' { .center } 'end', 'right', 'bottom' { .end } else { .start } } }

pub fn is_interword_space(character rune) bool { return character in [` `, `\t`, `\n`, `\r`] }
pub fn is_ignorable_whitespace(text string) bool { return text.runes().all(is_interword_space(it)) }
pub fn is_container_element(tag string) bool { return tag in ['object', 'embed', 'iframe', 'audio', 'video', 'canvas'] }
pub fn has_in_flow_block_children(kinds []string) bool { return kinds.any(it in ['block', 'flex', 'grid', 'table']) }
pub fn has_inline_or_in_flow_block_children(kinds []string) bool { return kinds.any(it == 'inline') || has_in_flow_block_children(kinds) }
pub fn insertion_parent_for_block_node(parent_kind string) string { return if parent_kind == 'inline' { 'anonymous-block-wrapper' } else { parent_kind } }
pub fn insertion_parent_for_inline_node(parent_kind string) string { return if parent_kind in ['block', 'flex', 'grid'] { 'anonymous-inline-wrapper' } else { parent_kind } }
pub fn wrap_in_anonymous(ids []string, kind string) string { return '${kind}(${ids.join(',')})' }
pub fn for_each_sequence_of_consecutive_children_matching(values []string, matcher string) [][]string { mut result := [][]string{}; mut current := []string{}; for value in values { if value.contains(matcher) { current << value } else if current.len > 0 { result << current.clone(); current.clear() } }; if current.len > 0 { result << current }; return result }

pub fn is_table_track(kind string) bool { return kind in ['table-row', 'table-column'] }
pub fn is_table_track_group(kind string) bool { return kind in ['table-row-group', 'table-header-group', 'table-footer-group', 'table-column-group'] }
pub fn is_table_row_group_column_group_or_caption(kind string) bool { return is_table_track_group(kind) || kind == 'table-caption' }
pub fn is_proper_table_child(kind string) bool { return kind in ['table-row-group', 'table-header-group', 'table-footer-group', 'table-row', 'table-column-group', 'table-column', 'table-caption'] }
pub fn is_not_proper_table_child(kind string) bool { return !is_proper_table_child(kind) }
pub fn is_not_table_row(kind string) bool { return kind != 'table-row' }
pub fn is_not_table_cell(kind string) bool { return kind !in ['table-cell', 'table-header-cell'] }
pub fn fixup_row(cells []string, expected_columns int) []string { mut result := cells.clone(); for result.len < expected_columns { result << 'anonymous-table-cell' }; return result }
