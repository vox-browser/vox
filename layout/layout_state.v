module layout

import css
import painting
import svg

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
	line_names [][]string
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
	inline_end_static_position_rect_ ?StaticPositionRect
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
}

fn (rare &UsedValuesRareData) clone() &UsedValuesRareData {
	return &UsedValuesRareData{
		static_position_rect_: rare.static_position_rect_
		inline_end_static_position_rect_: rare.inline_end_static_position_rect_
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
	derived_first_baseline_      ?CSSPixels
	derived_last_baseline_       ?CSSPixels
	scrollable_overflow_rect_    ?css.CSSPixelRect
	has_scrollable_overflow_     bool
mut:
	rare_ ?&UsedValuesRareData
}

fn (mut u UsedValues) set_derived_baselines(first ?CSSPixels, last ?CSSPixels) {
	u.derived_first_baseline_ = first
	u.derived_last_baseline_ = last
}

fn (u &UsedValues) derived_first_baseline() ?CSSPixels {
	return u.derived_first_baseline_
}

fn (u &UsedValues) derived_last_baseline() ?CSSPixels {
	return u.derived_last_baseline_
}

fn (mut u UsedValues) ensure_rare_data() &UsedValuesRareData {
	if rare := u.rare_ {
		return rare
	}
	rare := &UsedValuesRareData{}
	u.rare_ = rare
	return rare
}

pub fn (u &UsedValues) has_rare_data() bool {
	return u.rare_ != none
}

pub fn (u &UsedValues) has_line_clamp_point() bool {
	rare := u.rare_ or { return false }
	return rare.has_line_clamp_point_
}

pub fn (mut u UsedValues) set_has_line_clamp_point(value bool) {
	mut rare := u.ensure_rare_data()
	rare.has_line_clamp_point_ = value
}

pub fn (u &UsedValues) is_invisible_for_line_clamp() bool {
	rare := u.rare_ or { return false }
	return rare.is_invisible_for_line_clamp_
}

pub fn (mut u UsedValues) set_invisible_for_line_clamp(value bool) {
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
	mut rare := u.ensure_rare_data()
	rare.uses_collapsing_borders_model_ = value
}

pub fn (u &UsedValues) is_collapsed_borders_table_box() bool {
	rare := u.rare_ or { return false }
	return rare.is_collapsed_borders_table_box_
}

pub fn (mut u UsedValues) set_is_collapsed_borders_table_box(value bool) {
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
	mut rare := u.ensure_rare_data()
	rare.used_grid_template_rows = rows.clone()
}

pub fn (u &UsedValues) grid_template_rows() []CSSPixels {
	rare := u.rare_ or { return []CSSPixels{} }
	return rare.used_grid_template_rows
}

pub fn (mut u UsedValues) set_grid_line_names(columns [][]string, rows [][]string) {
	mut rare := u.ensure_rare_data()
	rare.used_grid_column_line_names = columns.clone()
	rare.used_grid_row_line_names = rows.clone()
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

	min_width := resolve_definite_size(node, computed, computed.size_value(.min_width), containing_block_used_values, true, u)
	max_width := resolve_definite_size(node, computed, computed.size_value(.max_width), containing_block_used_values, true, u)
	min_height := resolve_definite_size(node, computed, computed.size_value(.min_height), containing_block_used_values, false, u)
	max_height := resolve_definite_size(node, computed, computed.size_value(.max_height), containing_block_used_values, false, u)

	if width := resolve_definite_size(node, computed, computed.size_value(.width), containing_block_used_values, true, u) {
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

fn resolve_definite_size(node &NodeWithStyle, computed &css.ComputedProperties, size css.Size, containing_block_used_values ?&UsedValues, width bool, used_values &UsedValues) ?CSSPixels {
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
	mut context := css.LengthResolutionContext.for_document(node.document())
	font_size := CSSPixels.nearest_value_for(computed.resolved_font_size_px())
	font_metrics := layout_font_metrics_for_node(node)
	context.font_metrics.font_size = font_size
	context.font_metrics.x_height = CSSPixels.nearest_value_for(f64(font_metrics.x_height))
	context.font_metrics.cap_height = font_size.scaled(0.75)
	context.font_metrics.zero_advance = CSSPixels.nearest_value_for(f64(font_metrics.advance_of_ascii_zero))
	context.font_metrics.line_height = computed.line_height()
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
	if containing_block := u.containing_block_used_values_ {
		return css_pixel_point_add(containing_block.cumulative_offset(), u.offset)
	}
	return u.offset
}

pub fn (mut u UsedValues) set_static_position_rect(position StaticPositionRect) {
	mut rare := u.ensure_rare_data()
	rare.static_position_rect_ = position
}

pub fn (mut u UsedValues) set_inline_end_static_position_rect(position StaticPositionRect) {
	mut rare := u.ensure_rare_data()
	rare.inline_end_static_position_rect_ = position
}

pub fn (u &UsedValues) inline_end_static_position_rect() ?StaticPositionRect {
	rare := u.rare_ or { return none }
	return rare.inline_end_static_position_rect_
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

fn (u &UsedValues) collapsed_border_share(width CSSPixels, start_edge bool) CSSPixels {
	return if start_edge != u.is_collapsed_borders_table_box() {
		collapsed_border_part_after_line(width)
	} else {
		collapsed_border_part_before_line(width)
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
	return css_pixels_sum([u.margin_left, u.border_left_collapsed(), u.padding_left])
}

pub fn (u &UsedValues) margin_box_right() CSSPixels {
	return css_pixels_sum([u.margin_right, u.border_right_collapsed(), u.padding_right])
}

pub fn (u &UsedValues) margin_box_top() CSSPixels {
	return css_pixels_sum([u.margin_top, u.border_top_collapsed(), u.padding_top])
}

pub fn (u &UsedValues) margin_box_bottom() CSSPixels {
	return css_pixels_sum([u.margin_bottom, u.border_bottom_collapsed(), u.padding_bottom])
}

pub fn (u &UsedValues) margin_box_width() CSSPixels {
	return css_pixels_sum([u.margin_box_left(), u.content_width_, u.margin_box_right()])
}

pub fn (u &UsedValues) margin_box_height() CSSPixels {
	return css_pixels_sum([u.margin_box_top(), u.content_height_, u.margin_box_bottom()])
}

// --- Border box (border + padding + content) ---
pub fn (u &UsedValues) border_box_left() CSSPixels {
	return css_pixels_sum([u.border_left_collapsed(), u.padding_left])
}

pub fn (u &UsedValues) border_box_right() CSSPixels {
	return css_pixels_sum([u.border_right_collapsed(), u.padding_right])
}

pub fn (u &UsedValues) border_box_top() CSSPixels {
	return css_pixels_sum([u.border_top_collapsed(), u.padding_top])
}

pub fn (u &UsedValues) border_box_bottom() CSSPixels {
	return css_pixels_sum([u.border_bottom_collapsed(), u.padding_bottom])
}

pub fn (u &UsedValues) border_box_width() CSSPixels {
	return css_pixels_sum([u.border_box_left(), u.content_width_, u.border_box_right()])
}

pub fn (u &UsedValues) border_box_height() CSSPixels {
	return css_pixels_sum([u.border_box_top(), u.content_height_, u.border_box_bottom()])
}

pub fn (u &UsedValues) padding_box_width() CSSPixels {
	return css_pixels_sum([u.padding_left, u.content_width_, u.padding_right])
}

pub fn (u &UsedValues) padding_box_height() CSSPixels {
	return css_pixels_sum([u.padding_top, u.content_height_, u.padding_bottom])
}

// --- LayoutState ---

// Sparse, index-based two-level page table from LayoutState.h. Layout state is
// rebuilt on each pass, so pages are allocated only on the first write while
// lookup remains O(1) without hashing.
const layout_state_page_bits = u32(4)
const layout_state_page_size = u32(1) << layout_state_page_bits
const layout_state_page_mask = layout_state_page_size - 1

@[heap]
struct UsedValuesPage {
mut:
	entries []?&UsedValues
}

fn UsedValuesPage.new() &UsedValuesPage {
	return &UsedValuesPage{
		entries: []?&UsedValues{len: int(layout_state_page_size), init: none}
	}
}

@[heap]
struct UsedValuesPagedStore {
mut:
	pages []?&UsedValuesPage
}

fn (mut store UsedValuesPagedStore) ensure_capacity(count u32) {
	required_page_count := int((count + layout_state_page_size - 1) >> layout_state_page_bits)
	for store.pages.len < required_page_count {
		store.pages << none
	}
}

fn (store &UsedValuesPagedStore) get(index u32) ?&UsedValues {
	page_index := int(index >> layout_state_page_bits)
	if page_index >= store.pages.len {
		return none
	}
	page := store.pages[page_index] or { return none }
	return page.entries[int(index & layout_state_page_mask)] or { return none }
}

fn (mut store UsedValuesPagedStore) allocate(index u32) &UsedValues {
	page_index := int(index >> layout_state_page_bits)
	if page_index >= store.pages.len {
		store.ensure_capacity(index + 1)
	}
	mut page := store.pages[page_index] or {
		new_page := UsedValuesPage.new()
		store.pages[page_index] = new_page
		new_page
	}
	entry := &UsedValues{}
	page.entries[int(index & layout_state_page_mask)] = entry
	return entry
}

fn (store &UsedValuesPagedStore) for_each(callback fn (&UsedValues)) {
	for maybe_page in store.pages {
		page := maybe_page or { continue }
		for maybe_entry in page.entries {
			entry := maybe_entry or { continue }
			callback(entry)
		}
	}
}

@[heap]
pub struct LayoutState {
pub mut:
	used_values_store UsedValuesPagedStore
	subtree_root      ?&NodeWithStyle
mut:
	subgrid_data map[u32]GridSubgridNodeData
}

pub fn LayoutState.new() &LayoutState {
	return &LayoutState{}
}

pub fn LayoutState.new_for_subtree(subtree_root &NodeWithStyle) &LayoutState {
	return &LayoutState{
		subtree_root: subtree_root
	}
}

pub fn (mut state LayoutState) ensure_capacity(node_count u32) {
	state.used_values_store.ensure_capacity(node_count)
}

// The UsedValues for `node`, creating an empty one on first access (Layout::LayoutState::get_mutable).
pub fn (mut state LayoutState) get_mutable(node &NodeWithStyle) &UsedValues {
	return state.ensure_used_values_for(node)
}

pub fn (mut state LayoutState) get(node &NodeWithStyle) &UsedValues {
	return state.ensure_used_values_for(node)
}

fn (mut state LayoutState) set_subgrid_axis_data(node &NodeWithStyle, columns bool, axis GridSubgridAxisData) {
	mut data := state.subgrid_data[node.layout_index()] or { GridSubgridNodeData{} }
	if columns {
		data.columns = axis
	} else {
		data.rows = axis
	}
	state.subgrid_data[node.layout_index()] = data
}

fn (state &LayoutState) subgrid_axis_data(node &NodeWithStyle, columns bool) ?GridSubgridAxisData {
	data := state.subgrid_data[node.layout_index()] or { return none }
	return if columns { data.columns } else { data.rows }
}

// LayoutState::populate_node_from(). Intrinsic sizing and partial subtree
// layout need the already-resolved geometry of an ancestor without making
// that ancestor part of the throwaway subtree. Keep the copied node and box
// metrics, but sever its containing-block pointer exactly like LibWeb does.
pub fn (mut state LayoutState) populate_node_from(mut source LayoutState, node &NodeWithStyle) &UsedValues {
	index := node.layout_index()
	if state.used_values_store.get(index) != none {
		panic('VERIFY(!m_used_values_store.get(index))')
	}
	source_values := source.get(node)
	mut values := state.used_values_store.allocate(index)
	values.node_ = source_values.node_
	values.content_width_ = source_values.content_width_
	values.content_height_ = source_values.content_height_
	values.has_definite_width_ = source_values.has_definite_width_
	values.has_definite_height_ = source_values.has_definite_height_
	values.width_constraint = source_values.width_constraint
	values.height_constraint = source_values.height_constraint
	values.offset = source_values.offset
	values.margin_left = source_values.margin_left
	values.margin_right = source_values.margin_right
	values.margin_top = source_values.margin_top
	values.margin_bottom = source_values.margin_bottom
	values.border_left = source_values.border_left
	values.border_right = source_values.border_right
	values.border_top = source_values.border_top
	values.border_bottom = source_values.border_bottom
	values.padding_left = source_values.padding_left
	values.padding_right = source_values.padding_right
	values.padding_top = source_values.padding_top
	values.padding_bottom = source_values.padding_bottom
	values.inset_left = source_values.inset_left
	values.inset_right = source_values.inset_right
	values.inset_top = source_values.inset_top
	values.inset_bottom = source_values.inset_bottom
	values.line_boxes = source_values.line_boxes.clone()
	values.containing_line_box_fragment = source_values.containing_line_box_fragment
	if source_rare := source_values.rare_ {
		values.rare_ = source_rare.clone()
	}
	if subgrid := source.subgrid_data[index] {
		state.subgrid_data[index] = subgrid
	}
	values.containing_block_used_values_ = none
	return values
}

fn (mut state LayoutState) ensure_used_values_for(node &NodeWithStyle) &UsedValues {
	index := node.layout_index()
	if used_values := state.used_values_store.get(index) {
		return used_values
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
	return state.used_values_store.get(node.layout_index())
}

// --- CSSPixels helpers (the port's CSSPixels has no arithmetic operators) ---
fn css_pixels_sum(values []CSSPixels) CSSPixels {
	mut total := 0.0
	for value in values {
		total += value.to_double()
	}
	return CSSPixels.nearest_value_for(total)
}

fn css_pixel_point_add(a css.CSSPixelPoint, b css.CSSPixelPoint) css.CSSPixelPoint {
	return css.CSSPixelPoint.from_values(a.x().to_double() + b.x().to_double(), a.y().to_double() + b.y().to_double())
}

pub fn clamp_to_max_dimension_value(value CSSPixels) CSSPixels {
	if value.might_be_saturated() {
		return CSSPixels.nearest_value_for(f64(css.css_pixels_max_dimension_value))
	}
	return value
}
