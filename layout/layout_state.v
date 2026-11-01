module layout

import css
import painting
import svg
import platform

// Translation of Ladybird's Layout::LayoutState + LayoutState::UsedValues (Layout/LayoutState.h) — the
// per-box geometry produced by a formatting context: content size, offset within the containing block,
// and the used margin/border/padding/inset. The persistent Box holds no geometry; a formatting context
// reads/writes UsedValues in a LayoutState and commits them to paintables at the end.
//
// Rare SVG, grid, table, and static-position state is allocated only on first
// use so the per-node common case remains compact.

// https://www.w3.org/TR/css-sizing-3/#available — a size can be constrained to min-/max-content.
pub enum SizeConstraint {
	none
	min_content
	max_content
}

struct GridSubgridAxisData {
	tracks     []GridTrack
	line_names [][]css.GridLineName
	gap        CSSPixels
}

struct GridSubgridNodeData {
mut:
	columns ?GridSubgridAxisData
	rows    ?GridSubgridAxisData
}

@[heap]
struct UsedValuesRareData {
mut:
	static_position_rect_         ?StaticPositionRect
	relative_inset_basis_width_   ?CSSPixels
	relative_inset_basis_height_  ?CSSPixels
	abspos_containing_block_rect_ ?css.CSSPixelRect
	used_grid_template_columns    []CSSPixels
	used_grid_template_rows       []CSSPixels
	used_grid_column_line_names   [][]string
	used_grid_row_line_names      [][]string
	used_grid_columns_are_subgrid bool
	used_grid_rows_are_subgrid    bool
	computed_svg_path_            ?svg.Path
	has_computed_svg_transforms   bool
	svg_viewbox_transform_        svg.AffineTransform
	svg_local_transform_          svg.AffineTransform
	svg_transform_                svg.AffineTransform
	svg_viewport_transform_       ?svg.AffineTransform
	svg_rendering_disabled_       bool
	override_borders_data_        ?painting.BordersDataWithElementKind
	table_cell_coordinates_       ?painting.TableCellCoordinates
	uses_collapsing_borders_model_ bool
	is_collapsed_borders_table_box_ bool
	hidden_by_collapsed_columns_ bool
	has_line_clamp_point_         bool
	is_invisible_for_line_clamp_  bool
	derived_first_baseline_       ?CSSPixels
	derived_last_baseline_        ?CSSPixels
}

// Empty zero-capacity arrays have no writable backing storage to escape
// through the public grid getters. Retain eager copies for every other case.
fn (rare &UsedValuesRareData) can_share_for_measurement() bool {
	return rare.used_grid_template_columns.cap == 0
		&& rare.used_grid_template_rows.cap == 0
		&& rare.used_grid_column_line_names.cap == 0
		&& rare.used_grid_row_line_names.cap == 0
}

fn (rare &UsedValuesRareData) clone() &UsedValuesRareData {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	return &UsedValuesRareData{
		static_position_rect_: rare.static_position_rect_
		relative_inset_basis_width_: rare.relative_inset_basis_width_
		relative_inset_basis_height_: rare.relative_inset_basis_height_
		abspos_containing_block_rect_: rare.abspos_containing_block_rect_
		used_grid_template_columns: rare.used_grid_template_columns.clone()
		used_grid_template_rows: rare.used_grid_template_rows.clone()
		used_grid_column_line_names: rare.used_grid_column_line_names.clone()
		used_grid_row_line_names: rare.used_grid_row_line_names.clone()
		used_grid_columns_are_subgrid: rare.used_grid_columns_are_subgrid
		used_grid_rows_are_subgrid: rare.used_grid_rows_are_subgrid
		computed_svg_path_: rare.computed_svg_path_
		has_computed_svg_transforms: rare.has_computed_svg_transforms
		svg_viewbox_transform_: rare.svg_viewbox_transform_
		svg_local_transform_: rare.svg_local_transform_
		svg_transform_: rare.svg_transform_
		svg_viewport_transform_: rare.svg_viewport_transform_
		svg_rendering_disabled_: rare.svg_rendering_disabled_
		override_borders_data_: rare.override_borders_data_
		table_cell_coordinates_: rare.table_cell_coordinates_
		uses_collapsing_borders_model_: rare.uses_collapsing_borders_model_
		is_collapsed_borders_table_box_: rare.is_collapsed_borders_table_box_
		hidden_by_collapsed_columns_: rare.hidden_by_collapsed_columns_
		has_line_clamp_point_: rare.has_line_clamp_point_
		is_invisible_for_line_clamp_: rare.is_invisible_for_line_clamp_
		derived_first_baseline_: rare.derived_first_baseline_
		derived_last_baseline_: rare.derived_last_baseline_
	}
}

@[heap]
pub struct UsedValues {
pub mut:
	node_                         &NodeWithStyle = unsafe { nil }
	containing_block_used_values_ ?&UsedValues
	content_width_                CSSPixels
	content_height_               CSSPixels
	has_definite_width_           bool
	has_definite_height_          bool
	width_constraint              SizeConstraint = .none
	height_constraint             SizeConstraint = .none
	// Offset from the top-left of the containing block's content area to this box's content area.
	offset css.CSSPixelPoint
	// Used values of the box-model edges.
	margin_left                  CSSPixels
	margin_right                 CSSPixels
	margin_top                   CSSPixels
	margin_bottom                CSSPixels
	border_left                  CSSPixels
	border_right                 CSSPixels
	border_top                   CSSPixels
	border_bottom                CSSPixels
	padding_left                 CSSPixels
	padding_right                CSSPixels
	padding_top                  CSSPixels
	padding_bottom               CSSPixels
	inset_left                   CSSPixels
	inset_right                  CSSPixels
	inset_top                    CSSPixels
	inset_bottom                 CSSPixels
	line_boxes                   []LineBox
	containing_line_box_fragment ?LineBoxFragmentCoordinate
	scrollable_overflow_rect_    ?css.CSSPixelRect
	has_scrollable_overflow_     bool
mut:
	rare_ ?&UsedValuesRareData
	rare_is_shared_ bool
	line_boxes_are_shared_ bool
	// Inline formatting publishes this small immutable scalar snapshot without
	// allocating the unrelated SVG, table, and grid state.
	inline_end_static_position_snapshot_ &StaticPositionRect = unsafe { nil }
	inline_end_snapshot_arena_ &MeasurementUsedValuesArena = unsafe { nil }
}

// Table layout derives row, row-group, table, and wrapper baselines. Other
// boxes never carry them, so they live with the rare state.
fn (mut u UsedValues) set_derived_baselines(first ?CSSPixels, last ?CSSPixels) {
	if first == none && last == none && u.rare_ == none {
		return
	}
	mut rare := u.ensure_rare_data()
	rare.derived_first_baseline_ = first
	rare.derived_last_baseline_ = last
}

fn (u &UsedValues) derived_first_baseline() ?CSSPixels {
	rare := u.rare_ or { return none }
	return rare.derived_first_baseline_
}

fn (u &UsedValues) derived_last_baseline() ?CSSPixels {
	rare := u.rare_ or { return none }
	return rare.derived_last_baseline_
}

fn (mut u UsedValues) ensure_rare_data() &UsedValuesRareData {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	if rare := u.rare_ {
		if u.rare_is_shared_ {
			owned := rare.clone()
			u.rare_ = owned
			u.rare_is_shared_ = false
			return owned
		}
		return rare
	}
	rare := &UsedValuesRareData{}
	u.rare_ = rare
	return rare
}

pub fn (u &UsedValues) has_rare_data() bool {
	return u.rare_ != none || u.inline_end_static_position_snapshot_ != unsafe { nil }
}

pub fn (u &UsedValues) has_line_clamp_point() bool {
	rare := u.rare_ or { return false }
	return rare.has_line_clamp_point_
}

pub fn (mut u UsedValues) set_has_line_clamp_point(value bool) {
	if u.has_line_clamp_point() == value { return }
	mut rare := u.ensure_rare_data()
	rare.has_line_clamp_point_ = value
}

pub fn (u &UsedValues) is_invisible_for_line_clamp() bool {
	rare := u.rare_ or { return false }
	return rare.is_invisible_for_line_clamp_
}

pub fn (mut u UsedValues) set_invisible_for_line_clamp(value bool) {
	if u.is_invisible_for_line_clamp() == value { return }
	mut rare := u.ensure_rare_data()
	rare.is_invisible_for_line_clamp_ = value
}

pub fn (u &UsedValues) node() &NodeWithStyle {
	return u.node_
}

pub fn (u &UsedValues) containing_block_used_values() ?&UsedValues {
	return u.containing_block_used_values_
}

pub fn (u &UsedValues) use_collapsing_borders_model() bool {
	rare := u.rare_ or { return false }
	return rare.uses_collapsing_borders_model_
}

pub fn (mut u UsedValues) set_use_collapsing_borders_model(value bool) {
	if u.use_collapsing_borders_model() == value { return }
	mut rare := u.ensure_rare_data()
	rare.uses_collapsing_borders_model_ = value
}

pub fn (u &UsedValues) is_collapsed_borders_table_box() bool {
	rare := u.rare_ or { return false }
	return rare.is_collapsed_borders_table_box_
}

pub fn (mut u UsedValues) set_is_collapsed_borders_table_box(value bool) {
	if u.is_collapsed_borders_table_box() == value { return }
	mut rare := u.ensure_rare_data()
	rare.is_collapsed_borders_table_box_ = value
}

// CSS 2.2 removes a table cell from the display when every column that it
// spans has visibility: collapse. Layout still measures the cell, while the
// retained paint tree uses this bit to omit the cell and its descendants.
pub fn (u &UsedValues) hidden_by_collapsed_columns() bool {
	rare := u.rare_ or { return false }
	return rare.hidden_by_collapsed_columns_
}

pub fn (mut u UsedValues) set_hidden_by_collapsed_columns(value bool) {
	if u.hidden_by_collapsed_columns() == value { return }
	mut rare := u.ensure_rare_data()
	rare.hidden_by_collapsed_columns_ = value
}

pub fn (u &UsedValues) override_borders_data() ?painting.BordersDataWithElementKind {
	rare := u.rare_ or { return none }
	return rare.override_borders_data_
}

pub fn (mut u UsedValues) set_override_borders_data(override_borders_data painting.BordersDataWithElementKind) {
	mut rare := u.ensure_rare_data()
	rare.override_borders_data_ = override_borders_data
	rare.uses_collapsing_borders_model_ = true
}

pub fn (mut u UsedValues) clear_override_borders_data() {
	mut rare := u.ensure_rare_data()
	rare.override_borders_data_ = none
}

pub fn (u &UsedValues) table_cell_coordinates() ?painting.TableCellCoordinates {
	rare := u.rare_ or { return none }
	return rare.table_cell_coordinates_
}

pub fn (mut u UsedValues) set_table_cell_coordinates(table_cell_coordinates painting.TableCellCoordinates) {
	mut rare := u.ensure_rare_data()
	rare.table_cell_coordinates_ = table_cell_coordinates
}

pub fn (mut u UsedValues) set_grid_template_columns(columns []CSSPixels) {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	mut rare := u.ensure_rare_data()
	rare.used_grid_template_columns = columns.clone()
}

pub fn (u &UsedValues) grid_template_columns() []CSSPixels {
	rare := u.rare_ or { return []CSSPixels{} }
	return rare.used_grid_template_columns
}

// getComputedStyle() reports the used grid-template sizes and explicit line
// names, so the grid formatting context retains them in rare layout state.
pub fn (mut u UsedValues) set_grid_template_rows(rows []CSSPixels) {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	mut rare := u.ensure_rare_data()
	rare.used_grid_template_rows = rows.clone()
}

pub fn (u &UsedValues) grid_template_rows() []CSSPixels {
	rare := u.rare_ or { return []CSSPixels{} }
	return rare.used_grid_template_rows
}

pub fn (mut u UsedValues) set_grid_line_names(columns [][]string, rows [][]string) {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	mut rare := u.ensure_rare_data()
	rare.used_grid_column_line_names = own_grid_line_names(columns)
	rare.used_grid_row_line_names = own_grid_line_names(rows)
}

fn own_grid_line_names(source [][]string) [][]string {
	mut result := [][]string{cap: source.len}
	for line in source {
		mut names := []string{cap: line.len}
		for name in line { names << name.clone() }
		result << names
	}
	return result
}

pub fn (u &UsedValues) grid_column_line_names() [][]string {
	rare := u.rare_ or { return [][]string{} }
	return rare.used_grid_column_line_names
}

pub fn (u &UsedValues) grid_row_line_names() [][]string {
	rare := u.rare_ or { return [][]string{} }
	return rare.used_grid_row_line_names
}

pub fn (mut u UsedValues) set_grid_subgridded_axes(columns bool, rows bool) {
	if u.grid_columns_are_subgrid() == columns && u.grid_rows_are_subgrid() == rows { return }
	mut rare := u.ensure_rare_data()
	rare.used_grid_columns_are_subgrid = columns
	rare.used_grid_rows_are_subgrid = rows
}

pub fn (u &UsedValues) grid_columns_are_subgrid() bool {
	rare := u.rare_ or { return false }
	return rare.used_grid_columns_are_subgrid
}

pub fn (u &UsedValues) grid_rows_are_subgrid() bool {
	rare := u.rare_ or { return false }
	return rare.used_grid_rows_are_subgrid
}

// Flex/Grid call FormattingContext::compute_inset() with the resolved item's
// containing-area size. Preserve that explicit percentage basis instead of
// substituting the parent box.
pub fn (mut u UsedValues) set_relative_inset_basis(width CSSPixels, height CSSPixels) {
	mut rare := u.ensure_rare_data()
	rare.relative_inset_basis_width_ = width
	rare.relative_inset_basis_height_ = height
}

pub fn (u &UsedValues) relative_inset_basis_width() ?CSSPixels {
	rare := u.rare_ or { return none }
	return rare.relative_inset_basis_width_
}

pub fn (u &UsedValues) relative_inset_basis_height() ?CSSPixels {
	rare := u.rare_ or { return none }
	return rare.relative_inset_basis_height_
}

pub fn (u &UsedValues) scrollable_overflow_rect() ?css.CSSPixelRect {
	return u.scrollable_overflow_rect_
}

pub fn (u &UsedValues) has_scrollable_overflow() bool {
	return u.has_scrollable_overflow_
}

pub fn (mut u UsedValues) set_containing_block_used_values(containing_block ?&UsedValues) {
	u.containing_block_used_values_ = containing_block
}

// LayoutState::UsedValues::set_node(). Resolve every generally-definite size
// before a formatting context runs. Formatting-context-specific definiteness
// is still established later by set_content_width()/set_content_height(), as
// in LibWeb.
fn (mut u UsedValues) set_node(node &NodeWithStyle, containing_block_used_values ?&UsedValues) {
	u.node_ = node
	u.containing_block_used_values_ = containing_block_used_values
	computed := node.computed_values()

	if width := resolve_definite_size(node, computed, computed.size_value(.width), containing_block_used_values, true, u) {
		// Constraints clamp a resolved axis; an indefinite axis has no size to
		// clamp until its formatting context resolves it later.
		min_width := resolve_definite_size(node, computed, computed.size_value(.min_width), containing_block_used_values, true, u)
		max_width := resolve_definite_size(node, computed, computed.size_value(.max_width), containing_block_used_values, true, u)
		u.content_width_ = clamp_to_max_dimension_value(width)
		u.has_definite_width_ = true
		if minimum := min_width {
			if u.content_width_.raw_value() < minimum.raw_value() {
				u.content_width_ = clamp_to_max_dimension_value(minimum)
			}
		}
		if maximum := max_width {
			if u.content_width_.raw_value() > maximum.raw_value() {
				u.content_width_ = clamp_to_max_dimension_value(maximum)
			}
		}
	}
	if height := resolve_definite_size(node, computed, computed.size_value(.height), containing_block_used_values, false, u) {
		min_height := resolve_definite_size(node, computed, computed.size_value(.min_height), containing_block_used_values, false, u)
		max_height := resolve_definite_size(node, computed, computed.size_value(.max_height), containing_block_used_values, false, u)
		u.content_height_ = clamp_to_max_dimension_value(height)
		u.has_definite_height_ = true
		if minimum := min_height {
			if u.content_height_.raw_value() < minimum.raw_value() {
				u.content_height_ = clamp_to_max_dimension_value(minimum)
			}
		}
		if maximum := max_height {
			if u.content_height_.raw_value() > maximum.raw_value() {
				u.content_height_ = clamp_to_max_dimension_value(maximum)
			}
		}
	}
}

// Size resolves its actual payload, which can differ from its public tag.
// A missing payload and absolute/percentage leaves never read node metrics.
fn definite_size_needs_node_metrics(size css.Size) bool {
	if value := size.length_percentage_ {
		return !value.is_percentage() && !(value.is_length() && value.length().is_absolute())
	}
	return false
}

fn resolve_definite_size(node &NodeWithStyle, computed &css.ComputedProperties, size css.Size, containing_block_used_values ?&UsedValues, width bool, used_values &UsedValues) ?CSSPixels {
	// Automatic heights stay indefinite until their formatting context runs.
	if !width && size.is_auto() { return none }

	containing_block_has_definite_size := if containing_block := containing_block_used_values {
		if width {
			containing_block.has_definite_width()
		} else {
			containing_block.has_definite_height()
		}
	} else {
		false
	}

	if size.is_auto() {
		parent := unsafe { &Node(node) }.parent() or { return none }
		if width && !unsafe { &Node(node) }.is_floating() && !unsafe { &Node(node) }.is_absolutely_positioned() && computed.display().is_block_outside() && !parent.is_floating() && (parent.display().is_flow_root_inside() || parent.display().is_flow_inside()) {
			if containing_block := containing_block_used_values {
				if containing_block_has_definite_size {
					available_width := containing_block.content_width().to_double()
					resolved := available_width - used_values.margin_left.to_double() - used_values.margin_right.to_double() - used_values.padding_left.to_double() - used_values.padding_right.to_double() - used_values.border_left.to_double() - used_values.border_right.to_double()
					return clamp_to_max_dimension_value(CSSPixels.nearest_value_for(resolved))
				}
			}
		}
		return none
	}

	if !size.is_length() && !size.is_percentage() && !size.is_calculated() {
		return none
	}
	if size.contains_percentage() && !containing_block_has_definite_size {
		return none
	}
	mut needs_metrics := definite_size_needs_node_metrics(size)
	if !needs_metrics && computed.box_sizing() != .content_box {
		start_padding := computed.size_value(if width { .padding_left } else { .padding_top })
		end_padding := computed.size_value(if width { .padding_right } else { .padding_bottom })
		needs_metrics = definite_size_needs_node_metrics(start_padding)
			|| definite_size_needs_node_metrics(end_padding)
	}
	mut context := css.LengthResolutionContext{}
	if needs_metrics {
		context = css.LengthResolutionContext.for_document(node.document())
		font_size := CSSPixels.nearest_value_for(computed.resolved_font_size_px())
		font_metrics := layout_font_metrics_for_node(node)
		context.font_metrics.font_size = font_size
		context.font_metrics.x_height = CSSPixels.nearest_value_for(f64(font_metrics.x_height))
		context.font_metrics.cap_height = font_size.scaled(0.75)
		context.font_metrics.zero_advance = CSSPixels.nearest_value_for(f64(font_metrics.advance_of_ascii_zero))
		context.font_metrics.line_height = computed.line_height()
	}
	reference_value := if containing_block := containing_block_used_values {
		if width { containing_block.content_width() } else { containing_block.content_height() }
	} else {
		CSSPixels.new(0)
	}
	resolved := size.to_px(context, reference_value)
	return clamp_to_max_dimension_value(adjust_size_for_box_sizing(computed, size, resolved, width, containing_block_used_values, context))
}

fn adjust_size_for_box_sizing(computed &css.ComputedProperties, computed_size css.Size, unadjusted CSSPixels, width bool, containing_block_used_values ?&UsedValues, context css.LengthResolutionContext) CSSPixels {
	if computed.box_sizing() == .content_box || computed_size.is_auto() {
		return unadjusted
	}
	containing_block_width := if containing_block := containing_block_used_values {
		containing_block.content_width()
	} else {
		CSSPixels.new(0)
	}
	mut border_and_padding := CSSPixels.new(0)
	if width {
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .border_left_width, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .padding_left, containing_block_width, context, false))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .border_right_width, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .padding_right, containing_block_width, context, false))
	} else {
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .border_top_width, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .padding_top, containing_block_width, context, false))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .border_bottom_width, containing_block_width, context, true))
		border_and_padding = border_and_padding.plus(resolve_computed_edge(computed, .padding_bottom, containing_block_width, context, false))
	}
	return unadjusted.minus(border_and_padding)
}

fn resolve_computed_edge(computed &css.ComputedProperties, property_id css.PropertyID, containing_block_width CSSPixels, context css.LengthResolutionContext, is_border bool) CSSPixels {
	if is_border {
		values := unsafe { &css.ComputedValues(computed) }
		return values.border_data(property_id).width
	}
	size := computed.size_value(property_id)
	if !size.is_length() && !size.is_percentage() && !size.is_calculated() {
		return CSSPixels.new(0)
	}
	return size.to_px(context, containing_block_width)
}

// --- Content size ---
pub fn (u &UsedValues) content_width() CSSPixels {
	return u.content_width_
}

pub fn (u &UsedValues) content_height() CSSPixels {
	return u.content_height_
}

pub fn (mut u UsedValues) set_content_width(width CSSPixels) {
	u.content_width_ = if width.raw_value() < 0 {
		CSSPixels.new(0)
	} else {
		clamp_to_max_dimension_value(width)
	}
	u.has_definite_width_ = true
}

pub fn (mut u UsedValues) set_content_height(height CSSPixels) {
	u.content_height_ = if height.raw_value() < 0 {
		CSSPixels.new(0)
	} else {
		clamp_to_max_dimension_value(height)
	}
}

pub fn (u &UsedValues) content_size() css.CSSPixelSize {
	return css.CSSPixelSize.from_values(u.content_width_.to_double(), u.content_height_.to_double())
}

pub fn (mut u UsedValues) set_indefinite_content_width() {
	u.has_definite_width_ = false
}

pub fn (mut u UsedValues) set_indefinite_content_height() {
	u.has_definite_height_ = false
}

pub fn (mut u UsedValues) set_has_definite_width(has_definite_width bool) {
	u.has_definite_width_ = has_definite_width
}

pub fn (mut u UsedValues) set_has_definite_height(has_definite_height bool) {
	u.has_definite_height_ = has_definite_height
}

// A size is definite only if flagged AND not under a min-/max-content constraint.
pub fn (u &UsedValues) has_definite_width() bool {
	return u.has_definite_width_ && u.width_constraint == .none
}

pub fn (u &UsedValues) has_definite_height() bool {
	return u.has_definite_height_ && u.height_constraint == .none
}

fn (u &UsedValues) available_width_inside() AvailableSize {
	return match u.width_constraint {
		.min_content {
			AvailableSize.make_min_content()
		}
		.max_content {
			AvailableSize.make_max_content()
		}
		.none {
			if u.has_definite_width() {
				AvailableSize.make_definite(u.content_width_)
			} else {
				AvailableSize.make_indefinite()
			}
		}
	}
}

fn (u &UsedValues) available_height_inside() AvailableSize {
	return match u.height_constraint {
		.min_content {
			AvailableSize.make_min_content()
		}
		.max_content {
			AvailableSize.make_max_content()
		}
		.none {
			if u.has_definite_height() {
				AvailableSize.make_definite(u.content_height_)
			} else {
				AvailableSize.make_indefinite()
			}
		}
	}
}

pub fn (u &UsedValues) available_inner_space_or_constraints_from(outer_space AvailableSpace) AvailableSpace {
	mut width := u.available_width_inside()
	mut height := u.available_height_inside()
	if width.is_indefinite() && outer_space.width.is_intrinsic_sizing_constraint() {
		width = outer_space.width
	}
	if height.is_indefinite() && outer_space.height.is_intrinsic_sizing_constraint() {
		height = outer_space.height
	}
	return AvailableSpace.new(width, height)
}

// --- Offset ---
pub fn (mut u UsedValues) set_content_offset(new_offset css.CSSPixelPoint) {
	u.offset = new_offset
}

pub fn (mut u UsedValues) set_content_x(x CSSPixels) {
	u.offset = css.CSSPixelPoint.from_values(x.to_double(), u.offset.y().to_double())
}

pub fn (mut u UsedValues) set_content_y(y CSSPixels) {
	u.offset = css.CSSPixelPoint.from_values(u.offset.x().to_double(), y.to_double())
}

// Offset from the viewport's top-left to this box's content area (sum of offsets up the containing-block chain).
pub fn (u &UsedValues) cumulative_offset() css.CSSPixelPoint {
	if u.containing_block_used_values_ == none { return u.offset }
	mut cursor := unsafe { u }
	mut x, mut y := i64(0), i64(0)
	mut extent_x, mut extent_y := i64(0), i64(0)
	for {
		dx, dy := i64(cursor.offset.x().raw_value()), i64(cursor.offset.y().raw_value())
		x += dx
		y += dy
		extent_x += if dx < 0 { -dx } else { dx }
		extent_y += if dy < 0 { -dy } else { dy }
		if parent := cursor.containing_block_used_values_ {
			cursor = parent
		} else { break }
	}
	// This conservative bound proves that no intermediate addition can
	// saturate, regardless of traversal order. Keep exact root-to-leaf
	// saturation for large mixed-sign chains; saturation is not associative.
	limit := i64(css.CSSPixels.max().raw_value())
	if extent_x <= limit && extent_y <= limit {
		return css.CSSPixelPoint.new(CSSPixels.from_raw(int(x)), CSSPixels.from_raw(int(y)))
	}
	return cumulative_offset_with_saturation(u)
}

fn cumulative_offset_with_saturation(u &UsedValues) css.CSSPixelPoint {
	if containing_block := u.containing_block_used_values_ {
		return css_pixel_point_add(cumulative_offset_with_saturation(containing_block), u.offset)
	}
	return u.offset
}

pub fn (mut u UsedValues) set_static_position_rect(position StaticPositionRect) {
	mut rare := u.ensure_rare_data()
	rare.static_position_rect_ = position
}

pub fn (mut u UsedValues) set_inline_end_static_position_rect(position StaticPositionRect) {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	if u.inline_end_snapshot_arena_ != unsafe { nil } {
		mut arena := u.inline_end_snapshot_arena_
		u.inline_end_static_position_snapshot_ = arena.allocate_inline_end_snapshot(position)
	} else {
		u.inline_end_static_position_snapshot_ = &StaticPositionRect{
			rect: position.rect
			horizontal_alignment: position.horizontal_alignment
			vertical_alignment: position.vertical_alignment
		}
	}
}

pub fn (u &UsedValues) inline_end_static_position_rect() ?StaticPositionRect {
	if u.inline_end_static_position_snapshot_ == unsafe { nil } { return none }
	return *u.inline_end_static_position_snapshot_
}

pub fn (mut u UsedValues) set_abspos_containing_block_rect(rect css.CSSPixelRect) {
	mut rare := u.ensure_rare_data()
	rare.abspos_containing_block_rect_ = rect
}

pub fn (u &UsedValues) abspos_containing_block_rect() ?css.CSSPixelRect {
	rare := u.rare_ or { return none }
	return rare.abspos_containing_block_rect_
}

pub fn (u &UsedValues) static_position() css.CSSPixelPoint {
	rare := u.rare_ or { return css.CSSPixelPoint{} }
	position := rare.static_position_rect_ or { return css.CSSPixelPoint{} }
	return position.aligned_position_for_box_with_size(css.CSSPixelSize.new(u.margin_box_width(), u.margin_box_height()))
}

// SVGGraphicsPaintable::ComputedTransforms and the path materialized by
// SVGFormattingContext. Painting consumes the same state instead of reparsing
// geometry independently.
pub fn (mut u UsedValues) set_computed_svg_path(path svg.Path) {
	mut rare := u.ensure_rare_data()
	rare.computed_svg_path_ = path
}

pub fn (u &UsedValues) computed_svg_path() ?svg.Path {
	rare := u.rare_ or { return none }
	return rare.computed_svg_path_
}

pub fn (mut u UsedValues) set_computed_svg_transforms(viewbox_transform svg.AffineTransform, local_transform svg.AffineTransform, svg_transform svg.AffineTransform) {
	mut rare := u.ensure_rare_data()
	rare.has_computed_svg_transforms = true
	rare.svg_viewbox_transform_ = viewbox_transform
	rare.svg_local_transform_ = local_transform
	rare.svg_transform_ = svg_transform
}

pub fn (u &UsedValues) has_computed_svg_transforms() bool {
	rare := u.rare_ or { return false }
	return rare.has_computed_svg_transforms
}

pub fn (u &UsedValues) svg_viewbox_transform() svg.AffineTransform {
	rare := u.rare_ or { return svg.AffineTransform{} }
	return rare.svg_viewbox_transform_
}

pub fn (u &UsedValues) svg_local_transform() svg.AffineTransform {
	rare := u.rare_ or { return svg.AffineTransform{} }
	return rare.svg_local_transform_
}

pub fn (u &UsedValues) svg_transform() svg.AffineTransform {
	rare := u.rare_ or { return svg.AffineTransform{} }
	return rare.svg_transform_
}

pub fn (mut u UsedValues) set_svg_viewport_transform(transform svg.AffineTransform) {
	mut rare := u.ensure_rare_data()
	rare.svg_viewport_transform_ = transform
}

pub fn (u &UsedValues) svg_viewport_transform() ?svg.AffineTransform {
	rare := u.rare_ or { return none }
	return rare.svg_viewport_transform_
}

pub fn (mut u UsedValues) set_svg_rendering_disabled(disabled bool) {
	if u.svg_rendering_disabled() == disabled { return }
	mut rare := u.ensure_rare_data()
	rare.svg_rendering_disabled_ = disabled
}

pub fn (u &UsedValues) svg_rendering_disabled() bool {
	rare := u.rare_ or { return false }
	return rare.svg_rendering_disabled_
}

// --- Margin box (margin + border + padding + content) ---
fn collapsed_border_part_after_line(width CSSPixels) CSSPixels {
	if width.raw_value() <= 0 {
		return CSSPixels.new(0)
	}
	return css.css_pixels_floor(width.divided_by_float(2.0))
}

fn collapsed_border_part_before_line(width CSSPixels) CSSPixels {
	if width.raw_value() <= 0 {
		return CSSPixels.new(0)
	}
	return width.minus(collapsed_border_part_after_line(width))
}

// Blink divides each winning collapsed border in LayoutUnit precision on
// both sides. LibWeb gives the whole-pixel remainder to the preceding side.
fn (u &UsedValues) uses_fractional_collapsed_border_shares() bool {
	return u.node_ != unsafe { nil }
		&& unsafe { &Node(u.node_) }.document().font_rendering_policy() == .chromium
}

fn (u &UsedValues) collapsed_border_part_after_line(width CSSPixels) CSSPixels {
	if u.uses_fractional_collapsed_border_shares() {
		return CSSPixels.from_raw(width.raw_value() / 2)
	}
	return collapsed_border_part_after_line(width)
}

fn (u &UsedValues) collapsed_border_part_before_line(width CSSPixels) CSSPixels {
	if u.uses_fractional_collapsed_border_shares() {
		return CSSPixels.from_raw(width.raw_value() / 2)
	}
	return collapsed_border_part_before_line(width)
}

fn (u &UsedValues) collapsed_border_share(width CSSPixels, start_edge bool) CSSPixels {
	return if start_edge != u.is_collapsed_borders_table_box() {
		u.collapsed_border_part_after_line(width)
	} else {
		u.collapsed_border_part_before_line(width)
	}
}

fn (u &UsedValues) border_left_collapsed() CSSPixels {
	return if u.use_collapsing_borders_model() {
		u.collapsed_border_share(u.border_left, true)
	} else {
		u.border_left
	}
}

fn (u &UsedValues) border_right_collapsed() CSSPixels {
	return if u.use_collapsing_borders_model() {
		u.collapsed_border_share(u.border_right, false)
	} else {
		u.border_right
	}
}

fn (u &UsedValues) border_top_collapsed() CSSPixels {
	return if u.use_collapsing_borders_model() {
		u.collapsed_border_share(u.border_top, true)
	} else {
		u.border_top
	}
}

fn (u &UsedValues) border_bottom_collapsed() CSSPixels {
	return if u.use_collapsing_borders_model() {
		u.collapsed_border_share(u.border_bottom, false)
	} else {
		u.border_bottom
	}
}

pub fn (u &UsedValues) margin_box_left() CSSPixels {
	return css_pixels_sum3(u.margin_left, u.border_left_collapsed(), u.padding_left)
}

pub fn (u &UsedValues) margin_box_right() CSSPixels {
	return css_pixels_sum3(u.margin_right, u.border_right_collapsed(), u.padding_right)
}

pub fn (u &UsedValues) margin_box_top() CSSPixels {
	return css_pixels_sum3(u.margin_top, u.border_top_collapsed(), u.padding_top)
}

pub fn (u &UsedValues) margin_box_bottom() CSSPixels {
	return css_pixels_sum3(u.margin_bottom, u.border_bottom_collapsed(), u.padding_bottom)
}

pub fn (u &UsedValues) margin_box_width() CSSPixels {
	return css_pixels_sum3(u.margin_box_left(), u.content_width_, u.margin_box_right())
}

pub fn (u &UsedValues) margin_box_height() CSSPixels {
	return css_pixels_sum3(u.margin_box_top(), u.content_height_, u.margin_box_bottom())
}

// --- Border box (border + padding + content) ---
pub fn (u &UsedValues) border_box_left() CSSPixels {
	return css_pixels_sum2(u.border_left_collapsed(), u.padding_left)
}

pub fn (u &UsedValues) border_box_right() CSSPixels {
	return css_pixels_sum2(u.border_right_collapsed(), u.padding_right)
}

pub fn (u &UsedValues) border_box_top() CSSPixels {
	return css_pixels_sum2(u.border_top_collapsed(), u.padding_top)
}

pub fn (u &UsedValues) border_box_bottom() CSSPixels {
	return css_pixels_sum2(u.border_bottom_collapsed(), u.padding_bottom)
}

pub fn (u &UsedValues) border_box_width() CSSPixels {
	return css_pixels_sum3(u.border_box_left(), u.content_width_, u.border_box_right())
}

pub fn (u &UsedValues) border_box_height() CSSPixels {
	return css_pixels_sum3(u.border_box_top(), u.content_height_, u.border_box_bottom())
}

pub fn (u &UsedValues) padding_box_width() CSSPixels {
	return css_pixels_sum3(u.padding_left, u.content_width_, u.padding_right)
}

pub fn (u &UsedValues) padding_box_height() CSSPixels {
	return css_pixels_sum3(u.padding_top, u.content_height_, u.padding_bottom)
}

// --- LayoutState ---

// Sparse, index-based two-level page table from LayoutState.h. Layout state is
// rebuilt on each pass, so pages are allocated only on the first write while
// lookup remains O(1) without hashing.
const layout_state_page_bits = u32(4)
const layout_state_page_size = u32(1) << layout_state_page_bits
const layout_state_page_mask = layout_state_page_size - 1

// Intrinsic probes return scalar dimensions, not their geometry records. Pool
// those records in stable chunks and release the chunks at the probe boundary.
// The chunks remain scanned while live: line boxes and rare data still belong
// to the ordinary V heap and can also be shared with the source layout state.
const measurement_arena_chunk_size = 16
const measurement_chunk_pool_capacity = 64
const inline_end_snapshot_chunk_size = 64

// Published positions contain only scalar geometry. Measurement snapshots can
// be released with their probe; retained positions use ordinary GC ownership.
@[heap]
struct InlineEndSnapshotChunk {
mut:
	values [inline_end_snapshot_chunk_size]StaticPositionRect
	used int
}

$if gcboehm ? {
	#include "@DIR/../platform/boehm_gc.h"

	fn C.GC_free(voidptr)
}

fn free_measurement_allocation(pointer voidptr) {
	if pointer == unsafe { nil } { return }
	$if gcboehm ? {
		C.GC_free(pointer)
	} $else {
		unsafe { free(pointer) }
	}
}

@[heap]
struct MeasurementUsedValuesChunk {
mut:
	values [measurement_arena_chunk_size]UsedValues
	used   int
}

@[heap]
struct MeasurementUsedValuesArena {
mut:
	chunks []&MeasurementUsedValuesChunk
	inline_end_snapshots []&InlineEndSnapshotChunk
	chunk_pool_ &MeasurementUsedValuesChunkPool = unsafe { nil }
	pool_lease_active_ bool
}

// Only inactive, fully cleared chunks can enter this bounded free list. Each
// nested intrinsic probe keeps its own active arena until its scalar result
// has been consumed. The document layout closes the pool before publication.
@[heap]
struct MeasurementUsedValuesChunkPool {
mut:
	chunks []&MeasurementUsedValuesChunk
	active_arenas int
	closed bool
	scratch_metadata_ &platform.Arena = unsafe { nil }
	scratch_slots_ []&MeasurementScratchSlot
	scratch_depth_ int
	scratch_enabled_ bool
	intrinsic_seed_order_ &LayoutTreeOrder = unsafe { nil }
	intrinsic_seed_stamps_ []u32
	intrinsic_seed_epoch_ u32
	inline_measurements_ map[u64][]&InlineMeasurementLayout
}

fn (mut pool MeasurementUsedValuesChunkPool) take() &MeasurementUsedValuesChunk {
	if !pool.closed && pool.chunks.len > 0 {
		return pool.chunks.pop()
	}
	return unsafe { &MeasurementUsedValuesChunk(vcalloc(int(sizeof(MeasurementUsedValuesChunk)))) }
}

fn (mut pool MeasurementUsedValuesChunkPool) put(chunk &MeasurementUsedValuesChunk) {
	if pool.closed || pool.chunks.len >= measurement_chunk_pool_capacity {
		free_measurement_allocation(chunk)
		return
	}
	// This is the same zeroed, scanned storage as vcalloc on first allocation.
	// Clear every stale GC edge before keeping the inactive chunk in the pool;
	// allocate() constructs each UsedValues record again before exposing it.
	unsafe { C.memset(chunk, 0, uint(sizeof(MeasurementUsedValuesChunk))) }
	pool.chunks << chunk
}

fn (mut pool MeasurementUsedValuesChunkPool) release() {
	assert pool.active_arenas == 0
	pool.release_scratch()
	pool.closed = true
	// In preallocated document layout the vector belongs to the enclosing
	// geometry workspace, which has already retired at this boundary.
	$if !prealloc { unsafe { pool.intrinsic_seed_stamps_.free() } }
	pool.intrinsic_seed_stamps_ = []u32{}
	pool.intrinsic_seed_order_ = unsafe { nil }
	pool.inline_measurements_ = map[u64][]&InlineMeasurementLayout{}
	for chunk in pool.chunks {
		free_measurement_allocation(chunk)
	}
	unsafe { pool.chunks.free() }
	pool.chunks = []&MeasurementUsedValuesChunk{}
}

fn (mut arena MeasurementUsedValuesArena) begin_pool_lease() {
	if arena.chunk_pool_ == unsafe { nil } || arena.pool_lease_active_ { return }
	mut pool := arena.chunk_pool_
	if pool.closed { return }
	pool.active_arenas++
	arena.pool_lease_active_ = true
}

// Committed geometry needs the same stable, scanned slots as intrinsic probes,
// but its pointers can escape into paintables. Keep these chunks GC-owned for
// their full lifetime; only the separate measurement arena is explicitly freed.
@[heap]
struct RetainedUsedValuesArena {
mut:
	storage MeasurementUsedValuesArena
}

fn (mut arena MeasurementUsedValuesArena) allocate() &UsedValues {
	mut value := arena.allocate_slot()
	unsafe { *value = UsedValues{inline_end_snapshot_arena_: arena} }
	return value
}

fn (mut arena MeasurementUsedValuesArena) allocate_populated(source &UsedValues) &UsedValues {
	mut value := arena.allocate_slot()
	unsafe { *value = UsedValues{
		node_: source.node_
		content_width_: source.content_width_
		content_height_: source.content_height_
		has_definite_width_: source.has_definite_width_
		has_definite_height_: source.has_definite_height_
		width_constraint: source.width_constraint
		height_constraint: source.height_constraint
		offset: source.offset
		margin_left: source.margin_left
		margin_right: source.margin_right
		margin_top: source.margin_top
		margin_bottom: source.margin_bottom
		border_left: source.border_left
		border_right: source.border_right
		border_top: source.border_top
		border_bottom: source.border_bottom
		padding_left: source.padding_left
		padding_right: source.padding_right
		padding_top: source.padding_top
		padding_bottom: source.padding_bottom
		inset_left: source.inset_left
		inset_right: source.inset_right
		inset_top: source.inset_top
		inset_bottom: source.inset_bottom
		inline_end_snapshot_arena_: arena
	} }
	return value
}

// Both callers immediately initialize the selected slot before publishing it.
fn (mut arena MeasurementUsedValuesArena) allocate_slot() &UsedValues {
	mut chunk := if arena.chunks.len == 0
		|| arena.chunks.last().used == measurement_arena_chunk_size {
		// Keep unused slots zeroed and scanned, then construct each record on
		// first use below. A normal struct literal eagerly constructs all sixteen
		// records before copying them into the chunk, including their array and
		// optional defaults, which would be overwritten when the slot is used.
		new_chunk := if arena.chunk_pool_ != unsafe { nil } {
			arena.begin_pool_lease()
			arena.chunk_pool_.take()
		} else {
			unsafe { &MeasurementUsedValuesChunk(vcalloc(int(sizeof(MeasurementUsedValuesChunk)))) }
		}
		arena.chunks << new_chunk
		new_chunk
	} else {
		arena.chunks.last()
	}
	index := chunk.used
	chunk.used++
	return unsafe { &chunk.values[index] }
}

fn (mut arena MeasurementUsedValuesArena) allocate_inline_end_snapshot(position StaticPositionRect) &StaticPositionRect {
	mut chunk := if arena.inline_end_snapshots.len == 0
		|| arena.inline_end_snapshots.last().used == inline_end_snapshot_chunk_size {
		new_chunk := unsafe { &InlineEndSnapshotChunk(vcalloc(int(sizeof(InlineEndSnapshotChunk)))) }
		arena.inline_end_snapshots << new_chunk
		new_chunk
	} else {
		arena.inline_end_snapshots.last()
	}
	index := chunk.used
	chunk.used++
	chunk.values[index] = position
	return unsafe { &chunk.values[index] }
}

fn (mut arena MeasurementUsedValuesArena) release() {
	for chunk in arena.inline_end_snapshots {
		free_measurement_allocation(chunk)
	}
	unsafe { arena.inline_end_snapshots.free() }
	arena.inline_end_snapshots = []&InlineEndSnapshotChunk{}
	for chunk in arena.chunks {
		if arena.chunk_pool_ != unsafe { nil } {
			arena.chunk_pool_.put(chunk)
		} else {
			free_measurement_allocation(chunk)
		}
	}
	unsafe { arena.chunks.free() }
	arena.chunks = []&MeasurementUsedValuesChunk{}
	if arena.pool_lease_active_ {
		arena.chunk_pool_.active_arenas--
		arena.pool_lease_active_ = false
	}
}

@[heap]
struct UsedValuesPage {
mut:
	// A missing entry is a null pointer. Keeping the slots in the page avoids
	// a second allocation and the much larger optional-pointer records.
	// voidptr also avoids the compatibility compiler's invalid C assignment
	// when constructing a heap record containing a fixed reference array.
	entries [layout_state_page_size]voidptr
}

fn UsedValuesPage.new() &UsedValuesPage {
	return &UsedValuesPage{}
}

@[heap]
struct UsedValuesPagedStore {
mut:
	pages []&UsedValuesPage
	measurement_arena ?&MeasurementUsedValuesArena
	retained_arena &RetainedUsedValuesArena = unsafe { nil }
}

fn (mut store UsedValuesPagedStore) ensure_capacity(count u32) {
	required_page_count := int((count + layout_state_page_size - 1) >> layout_state_page_bits)
	old_length := store.pages.len
	if required_page_count <= old_length {
		return
	}
	// grow_len leaves the new slots uninitialized. Fill them before exposing
	// the directory to a lookup, allocation, or traversal.
	unsafe { store.pages.grow_len(required_page_count - old_length) }
	for index in old_length .. required_page_count {
		store.pages[index] = unsafe { &UsedValuesPage(nil) }
	}
}

fn (store &UsedValuesPagedStore) get(index u32) ?&UsedValues {
	value := store.find(index)
	if value == unsafe { nil } {
		return none
	}
	return value
}

// Internal hits only need a nullable pointer. Materialize the optional at
// the get() boundary for callers that expose absence as an optional value.
fn (store &UsedValuesPagedStore) find(index u32) &UsedValues {
	page_index := int(index >> layout_state_page_bits)
	if page_index >= store.pages.len {
		return unsafe { nil }
	}
	page := store.pages[page_index]
	if page == unsafe { nil } {
		return unsafe { nil }
	}
	entry := page.entries[int(index & layout_state_page_mask)]
	return unsafe { &UsedValues(entry) }
}

fn (mut store UsedValuesPagedStore) allocate(index u32) &UsedValues {
	return store.allocate_with_source(index, unsafe { nil })
}

fn (mut store UsedValuesPagedStore) allocate_with_source(index u32, source &UsedValues) &UsedValues {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	page_index := int(index >> layout_state_page_bits)
	if page_index >= store.pages.len {
		store.ensure_capacity(index + 1)
	}
	mut page := store.pages[page_index]
	if page == unsafe { nil } {
		page = UsedValuesPage.new()
		store.pages[page_index] = page
	}
	entry := if mut arena := store.measurement_arena {
		if source == unsafe { nil } { arena.allocate() } else { arena.allocate_populated(source) }
	} else {
		if store.retained_arena == unsafe { nil } {
			store.retained_arena = &RetainedUsedValuesArena{}
		}
		mut retained := if source == unsafe { nil } {
			store.retained_arena.storage.allocate()
		} else {
			store.retained_arena.storage.allocate_populated(source)
		}
		// A retained paintable can outlive the state. Its scalar snapshot stays
		// GC-owned without retaining every other arena chunk through a back edge.
		retained.inline_end_snapshot_arena_ = unsafe { nil }
		retained
	}
	page.entries[int(index & layout_state_page_mask)] = voidptr(entry)
	return entry
}

fn (store &UsedValuesPagedStore) for_each(callback fn (&UsedValues)) {
	for page in store.pages {
		if page == unsafe { nil } {
			continue
		}
		for entry in page.entries {
			if entry == unsafe { nil } {
				continue
			}
			callback(unsafe { &UsedValues(entry) })
		}
	}
}

// Optional per-state indexes stay absent during ordinary block/inline layout
// and intrinsic probes. Each index owns its mutable map once first written.
@[heap]
struct LayoutStateSubgridStorage {
mut:
	values map[u32]GridSubgridNodeData
}

@[heap]
struct LayoutStateHeightDependencyStorage {
mut:
	values map[u32]bool
}

@[heap]
pub struct LayoutState {
pub mut:
	used_values_store UsedValuesPagedStore
	subtree_root      ?&NodeWithStyle
mut:
	subgrid_storage_ &LayoutStateSubgridStorage = unsafe { nil }
	height_dependency_storage_ &LayoutStateHeightDependencyStorage = unsafe { nil }
	measurement_chunk_pool_ &MeasurementUsedValuesChunkPool = unsafe { nil }
	block_layouts_ map[u64]&RetainedBlockLayout
	previous_block_layouts_ map[u64]&RetainedBlockLayout
	block_layout_rejections_ map[u64]bool
	block_paint_owners_ map[u64]&RetainedBlockLayout
	inline_layouts_ map[u64]&RetainedInlineLayout
	previous_inline_layouts_ map[u64]&RetainedInlineLayout
	paint_coordinates_ &PaintCoordinateSession = unsafe { nil }
	measurement_scratch_ MeasurementScratchScope
}

pub fn LayoutState.new() &LayoutState {
	return &LayoutState{}
}

pub fn LayoutState.new_for_subtree(subtree_root &NodeWithStyle) &LayoutState {
	return &LayoutState{
		subtree_root: subtree_root
		used_values_store: UsedValuesPagedStore{
			measurement_arena: &MeasurementUsedValuesArena{}
		}
	}
}

// Document geometry opts into a pool scoped to this single layout pass.
fn (mut state LayoutState) enable_measurement_chunk_pool() {
	assert state.used_values_store.measurement_arena == none
	assert state.measurement_chunk_pool_ == unsafe { nil }
	state.measurement_chunk_pool_ = &MeasurementUsedValuesChunkPool{}
}

fn (mut state LayoutState) release_measurement_chunk_pool() {
	if state.measurement_chunk_pool_ == unsafe { nil } { return }
	state.measurement_chunk_pool_.release()
	state.measurement_chunk_pool_ = unsafe { nil }
}

fn (mut source LayoutState) new_measurement_for_subtree(subtree_root &NodeWithStyle) &LayoutState {
	mut scratch := MeasurementScratchScope{}
	mut chunk_pool := source.measurement_chunk_pool_
	$if prealloc {
		if chunk_pool != unsafe { nil } && chunk_pool.scratch_enabled_ {
			scratch = chunk_pool.enter_scratch()
			// Whole-probe storage replaces the separate record-chunk free list.
			chunk_pool = unsafe { nil }
		}
	}
	return &LayoutState{
		measurement_scratch_: scratch
		subtree_root: subtree_root
		measurement_chunk_pool_: source.measurement_chunk_pool_
		used_values_store: UsedValuesPagedStore{
			measurement_arena: &MeasurementUsedValuesArena{
				chunk_pool_: chunk_pool
			}
		}
	}
}

// Only call this when the probe's scalar result has been computed and none of
// its UsedValues pointers escape. Committed layout keeps its ordinary heap.
fn (mut state LayoutState) release_measurement() {
	mut arena := state.used_values_store.measurement_arena or { return }
	for page in state.used_values_store.pages {
		free_measurement_allocation(page)
	}
	unsafe { state.used_values_store.pages.free() }
	state.used_values_store.pages = []&UsedValuesPage{}
	arena.release()
	// This releases `state` too. Finish through a value copy and never touch
	// the retired receiver afterwards.
	mut scratch := state.measurement_scratch_
	scratch.finish()
}

pub fn (mut state LayoutState) ensure_capacity(node_count u32) {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	state.used_values_store.ensure_capacity(node_count)
}

// The UsedValues for `node`, creating an empty one on first access (Layout::LayoutState::get_mutable).
pub fn (mut state LayoutState) get_mutable(node &NodeWithStyle) &UsedValues {
	mut values := state.ensure_used_values_for(node)
	values.ensure_mutable_line_boxes()
	return values
}

// Scalar box updates do not modify line buffers. Retained-layout replay and
// overflow computation use this private path to preserve immutable cache data.
fn (mut state LayoutState) mutable_box_values(node &NodeWithStyle) &UsedValues {
	return state.ensure_used_values_for(node)
}

// A validated retained snapshot already contains every resolved size. Preserve
// an existing record's address, or allocate raw storage, instead of resolving
// computed sizes which would immediately be overwritten by this complete copy.
fn (mut state LayoutState) restore_retained_values(node &NodeWithStyle,
	snapshot &UsedValues, containing ?&UsedValues) &UsedValues {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	mut values := state.used_values_store.get(node.layout_index()) or {
		state.used_values_store.allocate(node.layout_index())
	}
	unsafe { *values = *snapshot }
	values.containing_block_used_values_ = containing
	values.borrow_retained_line_boxes(snapshot.line_boxes)
	if rare := snapshot.rare_ {
		values.rare_ = rare.clone()
		values.rare_is_shared_ = false
	}
	return values
}

pub fn (mut state LayoutState) get(node &NodeWithStyle) &UsedValues {
	return state.ensure_used_values_for(node)
}

fn (mut state LayoutState) ensure_subgrid_storage() &LayoutStateSubgridStorage {
	if state.subgrid_storage_ == unsafe { nil } {
		state.subgrid_storage_ = &LayoutStateSubgridStorage{}
	}
	return state.subgrid_storage_
}

fn (state &LayoutState) cached_definite_height_dependency(index u32) ?bool {
	if state.height_dependency_storage_ == unsafe { nil } {
		return none
	}
	return state.height_dependency_storage_.values[index] or { return none }
}

fn (mut state LayoutState) cache_definite_height_dependency(index u32, depends bool) {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	if state.height_dependency_storage_ == unsafe { nil } {
		state.height_dependency_storage_ = &LayoutStateHeightDependencyStorage{}
	}
	state.height_dependency_storage_.values[index] = depends
}

fn (mut state LayoutState) set_subgrid_axis_data(node &NodeWithStyle, columns bool, axis GridSubgridAxisData) {
	mut retained_scope := retain_geometry_allocations()
	defer { retained_scope.finish() }
	mut storage := state.ensure_subgrid_storage()
	mut data := storage.values[node.layout_index()] or { GridSubgridNodeData{} }
	mut line_names := [][]css.GridLineName{cap: axis.line_names.len}
	for line in axis.line_names {
		mut names := []css.GridLineName{cap: line.len}
		for name in line { names << css.GridLineName{name: name.name.clone(), implicit: name.implicit} }
		line_names << names
	}
	owned := GridSubgridAxisData{tracks: axis.tracks.clone(), line_names: line_names, gap: axis.gap}
	if columns {
		data.columns = owned
	} else {
		data.rows = owned
	}
	storage.values[node.layout_index()] = data
}

fn (state &LayoutState) subgrid_axis_data(node &NodeWithStyle, columns bool) ?GridSubgridAxisData {
	if state.subgrid_storage_ == unsafe { nil } {
		return none
	}
	data := state.subgrid_storage_.values[node.layout_index()] or { return none }
	return if columns { data.columns } else { data.rows }
}

// LayoutState::populate_node_from(). Intrinsic sizing and partial subtree
// layout need the already-resolved geometry of an ancestor without making
// that ancestor part of the throwaway subtree. Keep the copied node and box
// metrics, but sever its containing-block pointer exactly like LibWeb does.
pub fn (mut state LayoutState) populate_node_from(mut source LayoutState, node &NodeWithStyle) &UsedValues {
	index := node.layout_index()
	if state.used_values_store.find(index) != unsafe { nil } {
		panic('VERIFY(!m_used_values_store.get(index))')
	}
	mut source_values := source.get(node)
	mut values := state.used_values_store.allocate_with_source(index, source_values)
	values.line_boxes = if source_values.line_boxes_are_shared_ {
		copy_retained_inline_lines(source_values.line_boxes)
	} else {
		source_values.line_boxes.clone()
	}
	values.containing_line_box_fragment = source_values.containing_line_box_fragment
	if source_values.inline_end_static_position_snapshot_ != unsafe { nil } {
		if source_values.inline_end_snapshot_arena_ == unsafe { nil } {
			values.inline_end_static_position_snapshot_ = source_values.inline_end_static_position_snapshot_
		} else {
			// An independently releasable source probe cannot lend arena storage.
			values.set_inline_end_static_position_rect(*source_values.inline_end_static_position_snapshot_)
		}
	}
	if source_rare := source_values.rare_ {
		if source_rare.can_share_for_measurement() {
			// Both owners detach before a rare-field mutation, preserving the
			// snapshot even when the committed source changes first.
			source_values.rare_is_shared_ = true
			values.rare_ = source_rare
			values.rare_is_shared_ = true
		} else {
			values.rare_ = source_rare.clone()
		}
	}
	if source.subgrid_storage_ != unsafe { nil } {
		if subgrid := source.subgrid_storage_.values[index] {
			mut storage := state.ensure_subgrid_storage()
			storage.values[index] = subgrid
		}
	}
	values.containing_block_used_values_ = none
	return values
}

fn (mut state LayoutState) ensure_used_values_for(node &NodeWithStyle) &UsedValues {
	index := node.layout_index()
	existing_values := state.used_values_store.find(index)
	if existing_values != unsafe { nil } {
		return existing_values
	}
	node_as_node := unsafe { &Node(node) }
	if subtree_root := state.subtree_root {
		root_as_node := unsafe { &Node(subtree_root) }
		if voidptr(subtree_root) != voidptr(node) && !root_as_node.is_inclusive_ancestor_of(node_as_node) {
			panic('LayoutState subtree root ${layout_debug_class_name(root_as_node)} <${layout_debug_tag(root_as_node)}> does not contain ${layout_debug_class_name(node_as_node)} <${layout_debug_tag(node_as_node)}>')
		}
	}
	mut containing_block_used_values := ?&UsedValues(none)
	if subtree_root := state.subtree_root {
		if voidptr(subtree_root) == voidptr(node) {
			if containing_block := node_as_node.containing_block() {
				if containing_block_node := unsafe { &Node(containing_block) }.as_node_with_style() {
					containing_block_used_values = state.try_get(containing_block_node)
				}
			}
		} else if !node_as_node.is_viewport() {
			containing_block := node_as_node.containing_block() or {
				panic('VERIFY(node.containing_block())')
			}
			containing_block_node := unsafe { &Node(containing_block) }.as_node_with_style() or {
				panic('containing block must have style')
			}
			containing_block_used_values = state.ensure_used_values_for(containing_block_node)
		}
	} else if !node_as_node.is_viewport() {
		if containing_block := node_as_node.containing_block() {
			containing_block_node := unsafe { &Node(containing_block) }.as_node_with_style() or {
				panic('containing block must have style')
			}
			containing_block_used_values = state.ensure_used_values_for(containing_block_node)
		}
	}
	mut used_values := state.used_values_store.allocate(index)
	used_values.set_node(node, containing_block_used_values)
	return used_values
}

// The UsedValues for `node`, or none if it has none yet (Layout::LayoutState::try_get_mutable).
pub fn (state &LayoutState) try_get(node &NodeWithStyle) ?&UsedValues {
	return state.used_values_store.get(node.layout_index())
}

pub fn (state &LayoutState) try_get_mutable(node &NodeWithStyle) ?&UsedValues {
	mut values := state.used_values_store.get(node.layout_index()) or { return none }
	values.ensure_mutable_line_boxes()
	return values
}

// --- CSSPixels helpers (the port's CSSPixels has no arithmetic operators) ---
// Raw fixed-point values fit exactly in i64 even with five operands. Clamp
// once after adding every contribution, so large edges can cancel margins
// without an intermediate saturation or a floating-point round trip.
fn css_pixels_sum2(a CSSPixels, b CSSPixels) CSSPixels {
	return a.plus(b)
}

fn css_pixels_sum3(a CSSPixels, b CSSPixels, c CSSPixels) CSSPixels {
	return css_pixels_from_wide_raw_sum(i64(a.raw_value()) + i64(b.raw_value()) + i64(c.raw_value()))
}

fn css_pixels_sum5(a CSSPixels, b CSSPixels, c CSSPixels, d CSSPixels, e CSSPixels) CSSPixels {
	return css_pixels_from_wide_raw_sum(i64(a.raw_value()) + i64(b.raw_value()) + i64(c.raw_value()) + i64(d.raw_value()) + i64(e.raw_value()))
}

fn css_pixels_from_wide_raw_sum(value i64) CSSPixels {
	if value > i64(CSSPixels.max().raw_value()) {
		return CSSPixels.max()
	}
	if value < i64(CSSPixels.min().raw_value()) {
		return CSSPixels.min()
	}
	return CSSPixels.from_raw(int(value))
}

fn css_pixel_point_add(a css.CSSPixelPoint, b css.CSSPixelPoint) css.CSSPixelPoint {
	return a.plus(b)
}

pub fn clamp_to_max_dimension_value(value CSSPixels) CSSPixels {
	if value.might_be_saturated() {
		return CSSPixels.nearest_value_for(f64(css.css_pixels_max_dimension_value))
	}
	return value
}
