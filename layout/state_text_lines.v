// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/Layout/*.
// This module is an incremental V port. Functions whose dependencies have not
// been ported yet keep their source signature and comments and return neutral
// stub values so the rest of libweb_v can compile against Layout.

module layout

// ---- LayoutState.h (69 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LayoutState.h:124
// Original signature: UsedValues::NodeWithStyle const& node() const
pub fn layout_state_h_124_node() LayoutStub {
	return layout_stub('LayoutState.h:124 node')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:125
// Original signature: UsedValues::NodeWithStyle& node()
pub fn layout_state_h_125_node() LayoutStub {
	return layout_stub('LayoutState.h:125 node')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:126
// Original signature: UsedValues::void set_node(NodeWithStyle const&, UsedValues const* containing_block_used_values);
pub fn layout_state_h_126_set_node() LayoutStub {
	return layout_stub('LayoutState.h:126 set_node')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:128
// Original signature: UsedValues::UsedValues const* containing_block_used_values() const
pub fn layout_state_h_128_containing_block_used_values() LayoutStub {
	return layout_stub('LayoutState.h:128 containing_block_used_values')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:130
// Original signature: UsedValues::CSSPixels content_width() const
pub fn layout_state_h_130_content_width() LayoutStub {
	return layout_stub('LayoutState.h:130 content_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:131
// Original signature: UsedValues::CSSPixels content_height() const
pub fn layout_state_h_131_content_height() LayoutStub {
	return layout_stub('LayoutState.h:131 content_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:132
// Original signature: UsedValues::void set_content_width(CSSPixels);
pub fn layout_state_h_132_set_content_width() LayoutStub {
	return layout_stub('LayoutState.h:132 set_content_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:133
// Original signature: UsedValues::void set_content_height(CSSPixels);
pub fn layout_state_h_133_set_content_height() LayoutStub {
	return layout_stub('LayoutState.h:133 set_content_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:135
// Original signature: UsedValues::CSSPixelSize content_size() const
pub fn layout_state_h_135_content_size() LayoutStub {
	return layout_stub('LayoutState.h:135 content_size')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:137
// Original signature: UsedValues::void set_indefinite_content_width();
pub fn layout_state_h_137_set_indefinite_content_width() LayoutStub {
	return layout_stub('LayoutState.h:137 set_indefinite_content_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:138
// Original signature: UsedValues::void set_indefinite_content_height();
pub fn layout_state_h_138_set_indefinite_content_height() LayoutStub {
	return layout_stub('LayoutState.h:138 set_indefinite_content_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:140
// Original signature: UsedValues::void set_has_definite_width(bool has_definite_width)
pub fn layout_state_h_140_set_has_definite_width() LayoutStub {
	return layout_stub('LayoutState.h:140 set_has_definite_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:141
// Original signature: UsedValues::void set_has_definite_height(bool has_definite_height)
pub fn layout_state_h_141_set_has_definite_height() LayoutStub {
	return layout_stub('LayoutState.h:141 set_has_definite_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:143
// Original signature: UsedValues::bool has_definite_width() const
pub fn layout_state_h_143_has_definite_width() LayoutStub {
	return layout_stub('LayoutState.h:143 has_definite_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:144
// Original signature: UsedValues::bool has_definite_height() const
pub fn layout_state_h_144_has_definite_height() LayoutStub {
	return layout_stub('LayoutState.h:144 has_definite_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:149
// Original signature: UsedValues::AvailableSpace available_inner_space_or_constraints_from(AvailableSpace const& outer_space) const;
// Returns the available space for content inside this layout box.
// If the space in an axis is indefinite, and the outer space is an intrinsic sizing constraint,
// the constraint is used in that axis instead.
pub fn layout_state_h_149_available_inner_space_or_constraints_from() LayoutStub {
	return layout_stub('LayoutState.h:149 available_inner_space_or_constraints_from')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:151
// Original signature: UsedValues::void materialize_from_paintable(Painting::PaintableBox const&);
pub fn layout_state_h_151_materialize_from_paintable() LayoutStub {
	return layout_stub('LayoutState.h:151 materialize_from_paintable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:153
// Original signature: UsedValues::void set_content_offset(CSSPixelPoint new_offset)
pub fn layout_state_h_153_set_content_offset() LayoutStub {
	return layout_stub('LayoutState.h:153 set_content_offset')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:154
// Original signature: UsedValues::void set_content_x(CSSPixels x)
pub fn layout_state_h_154_set_content_x() LayoutStub {
	return layout_stub('LayoutState.h:154 set_content_x')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:155
// Original signature: UsedValues::void set_content_y(CSSPixels y)
pub fn layout_state_h_155_set_content_y() LayoutStub {
	return layout_stub('LayoutState.h:155 set_content_y')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:197
// Original signature: UsedValues::CSSPixels margin_box_left() const
pub fn layout_state_h_197_margin_box_left() LayoutStub {
	return layout_stub('LayoutState.h:197 margin_box_left')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:198
// Original signature: UsedValues::CSSPixels margin_box_right() const
pub fn layout_state_h_198_margin_box_right() LayoutStub {
	return layout_stub('LayoutState.h:198 margin_box_right')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:199
// Original signature: UsedValues::CSSPixels margin_box_top() const
pub fn layout_state_h_199_margin_box_top() LayoutStub {
	return layout_stub('LayoutState.h:199 margin_box_top')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:200
// Original signature: UsedValues::CSSPixels margin_box_bottom() const
pub fn layout_state_h_200_margin_box_bottom() LayoutStub {
	return layout_stub('LayoutState.h:200 margin_box_bottom')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:202
// Original signature: UsedValues::CSSPixels margin_box_width() const
pub fn layout_state_h_202_margin_box_width() LayoutStub {
	return layout_stub('LayoutState.h:202 margin_box_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:203
// Original signature: UsedValues::CSSPixels margin_box_height() const
pub fn layout_state_h_203_margin_box_height() LayoutStub {
	return layout_stub('LayoutState.h:203 margin_box_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:205
// Original signature: UsedValues::CSSPixels border_box_left() const
pub fn layout_state_h_205_border_box_left() LayoutStub {
	return layout_stub('LayoutState.h:205 border_box_left')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:206
// Original signature: UsedValues::CSSPixels border_box_right() const
pub fn layout_state_h_206_border_box_right() LayoutStub {
	return layout_stub('LayoutState.h:206 border_box_right')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:207
// Original signature: UsedValues::CSSPixels border_box_top() const
pub fn layout_state_h_207_border_box_top() LayoutStub {
	return layout_stub('LayoutState.h:207 border_box_top')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:208
// Original signature: UsedValues::CSSPixels border_box_bottom() const
pub fn layout_state_h_208_border_box_bottom() LayoutStub {
	return layout_stub('LayoutState.h:208 border_box_bottom')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:210
// Original signature: UsedValues::CSSPixels border_box_width() const
pub fn layout_state_h_210_border_box_width() LayoutStub {
	return layout_stub('LayoutState.h:210 border_box_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:211
// Original signature: UsedValues::CSSPixels border_box_height() const
pub fn layout_state_h_211_border_box_height() LayoutStub {
	return layout_stub('LayoutState.h:211 border_box_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:215
// Original signature: UsedValues::void add_floating_descendant(Box const& box)
pub fn layout_state_h_215_add_floating_descendant() LayoutStub {
	return layout_stub('LayoutState.h:215 add_floating_descendant')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:216
// Original signature: UsedValues::auto const& floating_descendants() const
pub fn layout_state_h_216_floating_descendants() LayoutStub {
	return layout_stub('LayoutState.h:216 floating_descendants')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:218
// Original signature: UsedValues::void set_override_borders_data(Painting::PaintableBox::BordersDataWithElementKind const&_borders_data)
pub fn layout_state_h_218_set_override_borders_data() LayoutStub {
	return layout_stub('LayoutState.h:218 set_override_borders_data')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:219
// Original signature: UsedValues::auto const&_borders_data() const
pub fn layout_state_h_219_borders_data() LayoutStub {
	return layout_stub('LayoutState.h:219 _borders_data')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:221
// Original signature: UsedValues::void set_table_cell_coordinates(Painting::PaintableBox::TableCellCoordinates const& table_cell_coordinates)
pub fn layout_state_h_221_set_table_cell_coordinates() LayoutStub {
	return layout_stub('LayoutState.h:221 set_table_cell_coordinates')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:222
// Original signature: UsedValues::auto const& table_cell_coordinates() const
pub fn layout_state_h_222_table_cell_coordinates() LayoutStub {
	return layout_stub('LayoutState.h:222 table_cell_coordinates')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:224
// Original signature: UsedValues::void set_computed_svg_path(Gfx::Path const& svg_path)
pub fn layout_state_h_224_set_computed_svg_path() LayoutStub {
	return layout_stub('LayoutState.h:224 set_computed_svg_path')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:225
// Original signature: UsedValues::auto& computed_svg_path()
pub fn layout_state_h_225_computed_svg_path() LayoutStub {
	return layout_stub('LayoutState.h:225 computed_svg_path')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:227
// Original signature: UsedValues::void set_computed_svg_transforms(Painting::SVGGraphicsPaintable::ComputedTransforms const& computed_transforms)
pub fn layout_state_h_227_set_computed_svg_transforms() LayoutStub {
	return layout_stub('LayoutState.h:227 set_computed_svg_transforms')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:228
// Original signature: UsedValues::auto const& computed_svg_transforms() const
pub fn layout_state_h_228_computed_svg_transforms() LayoutStub {
	return layout_stub('LayoutState.h:228 computed_svg_transforms')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:230
// Original signature: UsedValues::void set_grid_template_columns(RefPtr<CSS::GridTrackSizeListStyleValue const> used_values_for_grid_template_columns)
pub fn layout_state_h_230_set_grid_template_columns() LayoutStub {
	return layout_stub('LayoutState.h:230 set_grid_template_columns')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:231
// Original signature: UsedValues::auto const& grid_template_columns() const
pub fn layout_state_h_231_grid_template_columns() LayoutStub {
	return layout_stub('LayoutState.h:231 grid_template_columns')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:233
// Original signature: UsedValues::void set_grid_template_rows(RefPtr<CSS::GridTrackSizeListStyleValue const> used_values_for_grid_template_rows)
pub fn layout_state_h_233_set_grid_template_rows() LayoutStub {
	return layout_stub('LayoutState.h:233 set_grid_template_rows')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:234
// Original signature: UsedValues::auto const& grid_template_rows() const
pub fn layout_state_h_234_grid_template_rows() LayoutStub {
	return layout_stub('LayoutState.h:234 grid_template_rows')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:236
// Original signature: UsedValues::void set_static_position_rect(StaticPositionRect const& static_position_rect)
pub fn layout_state_h_236_set_static_position_rect() LayoutStub {
	return layout_stub('LayoutState.h:236 set_static_position_rect')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:247
// Original signature: UsedValues::AvailableSize available_width_inside() const;
pub fn layout_state_h_247_available_width_inside() LayoutStub {
	return layout_stub('LayoutState.h:247 available_width_inside')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:248
// Original signature: UsedValues::AvailableSize available_height_inside() const;
pub fn layout_state_h_248_available_height_inside() LayoutStub {
	return layout_stub('LayoutState.h:248 available_height_inside')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:250
// Original signature: UsedValues::bool use_collapsing_borders_model() const
pub fn layout_state_h_250_use_collapsing_borders_model() LayoutStub {
	return layout_stub('LayoutState.h:250 use_collapsing_borders_model')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:252
// Original signature: UsedValues::CSSPixels border_left_collapsed() const
// Implement the collapsing border model https://www.w3.org/TR/CSS22/tables.html#collapsing-borders.
pub fn layout_state_h_252_border_left_collapsed() LayoutStub {
	return layout_stub('LayoutState.h:252 border_left_collapsed')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:253
// Original signature: UsedValues::CSSPixels border_right_collapsed() const
pub fn layout_state_h_253_border_right_collapsed() LayoutStub {
	return layout_stub('LayoutState.h:253 border_right_collapsed')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:254
// Original signature: UsedValues::CSSPixels border_top_collapsed() const
pub fn layout_state_h_254_border_top_collapsed() LayoutStub {
	return layout_stub('LayoutState.h:254 border_top_collapsed')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:255
// Original signature: UsedValues::CSSPixels border_bottom_collapsed() const
pub fn layout_state_h_255_border_bottom_collapsed() LayoutStub {
	return layout_stub('LayoutState.h:255 border_bottom_collapsed')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:281
// Original signature: LayoutState::LayoutState() = default;
pub fn layout_state_h_281_layout_state_layout_state() LayoutStub {
	return layout_stub('LayoutState.h:281 LayoutState::LayoutState')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:282
// Original signature: LayoutState::explicit LayoutState(NodeWithStyle const& subtree_root);
pub fn layout_state_h_282_layout_state() LayoutStub {
	return layout_stub('LayoutState.h:282 LayoutState')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:283
// Original signature: LayoutState::~LayoutState();
pub fn layout_state_h_283_layout_state_destroy_layout_state() LayoutStub {
	return layout_stub('LayoutState.h:283 LayoutState::~LayoutState')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:286
// Original signature: LayoutState::void commit(Box& root);
// Commits the used values produced by layout and builds a paintable tree.
pub fn layout_state_h_286_commit() LayoutStub {
	return layout_stub('LayoutState.h:286 commit')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:288
// Original signature: LayoutState::void ensure_capacity(u32 node_count);
pub fn layout_state_h_288_ensure_capacity() LayoutStub {
	return layout_stub('LayoutState.h:288 ensure_capacity')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:290
// Original signature: LayoutState::UsedValues& get_mutable(NodeWithStyle const&);
pub fn layout_state_h_290_get_mutable() LayoutStub {
	return layout_stub('LayoutState.h:290 get_mutable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:291
// Original signature: LayoutState::UsedValues const& get(NodeWithStyle const&) const;
pub fn layout_state_h_291_get() LayoutStub {
	return layout_stub('LayoutState.h:291 get')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:293
// Original signature: LayoutState::UsedValues& populate_from_paintable(NodeWithStyle const&, Painting::PaintableBox const&);
pub fn layout_state_h_293_populate_from_paintable() LayoutStub {
	return layout_stub('LayoutState.h:293 populate_from_paintable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:294
// Original signature: LayoutState::UsedValues& populate_node_from(LayoutState const& source, NodeWithStyle const& node);
pub fn layout_state_h_294_populate_node_from() LayoutStub {
	return layout_stub('LayoutState.h:294 populate_node_from')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:296
// Original signature: LayoutState::UsedValues const* try_get(NodeWithStyle const&) const;
pub fn layout_state_h_296_try_get() LayoutStub {
	return layout_stub('LayoutState.h:296 try_get')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:297
// Original signature: LayoutState::UsedValues* try_get_mutable(NodeWithStyle const&);
pub fn layout_state_h_297_try_get_mutable() LayoutStub {
	return layout_stub('LayoutState.h:297 try_get_mutable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:298
// Original signature: LayoutState::UsedValues const* try_get(Node const&) const;
pub fn layout_state_h_298_try_get() LayoutStub {
	return layout_stub('LayoutState.h:298 try_get')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:301
// Original signature: LayoutState::UsedValues& ensure_used_values_for(NodeWithStyle const&);
pub fn layout_state_h_301_ensure_used_values_for() LayoutStub {
	return layout_stub('LayoutState.h:301 ensure_used_values_for')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:302
// Original signature: LayoutState::void resolve_relative_positions();
pub fn layout_state_h_302_resolve_relative_positions() LayoutStub {
	return layout_stub('LayoutState.h:302 resolve_relative_positions')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.h:308
// Original signature: inline CSSPixels clamp_to_max_dimension_value(CSSPixels value)
pub fn layout_state_h_308_clamp_to_max_dimension_value() LayoutStub {
	return layout_stub('LayoutState.h:308 clamp_to_max_dimension_value')
}

// ---- LayoutState.cpp (24 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:24
// Original signature: LayoutState::LayoutState(NodeWithStyle const& subtree_root) : m_subtree_root(&subtree_root)
pub fn layout_state_cpp_24_layout_state_layout_state() LayoutStub {
	return layout_stub('LayoutState.cpp:24 LayoutState::LayoutState')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:29
// Original signature: LayoutState::~LayoutState()
pub fn layout_state_cpp_29_layout_state_destroy_layout_state() LayoutStub {
	return layout_stub('LayoutState.cpp:29 LayoutState::~LayoutState')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:33
// Original signature: void LayoutState::ensure_capacity(u32 node_count)
pub fn layout_state_cpp_33_layout_state_ensure_capacity() LayoutStub {
	return layout_stub('LayoutState.cpp:33 LayoutState::ensure_capacity')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:38
// Original signature: LayoutState::UsedValues& LayoutState::get_mutable(NodeWithStyle const& node)
pub fn layout_state_cpp_38_layout_state_get_mutable() LayoutStub {
	return layout_stub('LayoutState.cpp:38 LayoutState::get_mutable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:43
// Original signature: LayoutState::UsedValues const& LayoutState::get(NodeWithStyle const& node) const
pub fn layout_state_cpp_43_layout_state_get() LayoutStub {
	return layout_stub('LayoutState.cpp:43 LayoutState::get')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:48
// Original signature: LayoutState::UsedValues& LayoutState::populate_from_paintable(NodeWithStyle const& node, Painting::PaintableBox const& paintable)
// NOTE: We skip set_node() here since it performs size resolution that requires a containing block,
// and materialize_from_paintable() overwrites all computed sizes immediately after.
pub fn layout_state_cpp_48_layout_state_populate_from_paintable() LayoutStub {
	return layout_stub('LayoutState.cpp:48 LayoutState::populate_from_paintable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:61
// Original signature: LayoutState::UsedValues& LayoutState::populate_node_from(LayoutState const& source, NodeWithStyle const& node)
pub fn layout_state_cpp_61_layout_state_populate_node_from() LayoutStub {
	return layout_stub('LayoutState.cpp:61 LayoutState::populate_node_from')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:73
// Original signature: LayoutState::UsedValues& LayoutState::ensure_used_values_for(NodeWithStyle const& node)
// During subtree layout, only the subtree root and nodes inside the subtree are allowed.
// For the subtree root, ancestor values are not available in the throwaway state.
pub fn layout_state_cpp_73_layout_state_ensure_used_values_for() LayoutStub {
	return layout_stub('LayoutState.cpp:73 LayoutState::ensure_used_values_for')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:96
// Original signature: LayoutState::UsedValues const* LayoutState::try_get(NodeWithStyle const& node) const
pub fn layout_state_cpp_96_layout_state_try_get() LayoutStub {
	return layout_stub('LayoutState.cpp:96 LayoutState::try_get')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:101
// Original signature: LayoutState::UsedValues* LayoutState::try_get_mutable(NodeWithStyle const& node)
pub fn layout_state_cpp_101_layout_state_try_get_mutable() LayoutStub {
	return layout_stub('LayoutState.cpp:101 LayoutState::try_get_mutable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:106
// Original signature: LayoutState::UsedValues const* LayoutState::try_get(Node const& node) const
pub fn layout_state_cpp_106_layout_state_try_get() LayoutStub {
	return layout_stub('LayoutState.cpp:106 LayoutState::try_get')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:117
// Original signature: static CSSPixelRect measure_scrollable_overflow(Box const& box, ContainedBoxesMap const& contained_boxes_map)
// The scrollable overflow area is the union of:
// - The scroll container's own padding box.
// - All line boxes directly contained by the scroll container.
// - The border boxes of all boxes for which it is the containing block and whose border boxes are positioned not
// wholly in the negative scrollable overflow region,
// FIXME: accounting for transforms by projecting each box onto the plane of the element that establishes its 3D
// rendering context. [CSS3-TRANSFORMS]
// https://drafts.csswg.org/css-position/#fixed-positioning-containing-block
// [..] As a result, parts of fixed-positioned boxes that extend outside the layout viewport/page area
// cannot be scrolled to and will not print.
// FIXME: Properly establish the fixed positioning containing block for `position: fixed`
// NOTE: Here we check that the child is not wholly in the negative scrollable overflow region.
// Border boxes with zero area do not affect the scrollable overflow area.
// - The scrollable overflow areas of all of the above boxes (including zero-area boxes and accounting for
// transforms as described above), provided they themselves have overflow: visible (i.e. do not themselves
// trap the overflow) and that scrollable overflow is not already clipped (e.g. by the clip property or the
// contain property).
// Scrollable overflow is already clipped by the contain property.
// FIXME: - The margin areas of grid item and flex item boxes for which the box establishes a containing block.
// - Additional padding added to the scrollable overflow rectangle as necessary to enable scroll positions that
// satisfy the requirements of both place-content: start and place-content: end alignment.
// Additionally, due to Web-compatibility constraints (caused by authors exploiting legacy bugs to
// surreptitiously
// hide content from visual readers but not search engines and/or speech output), UAs must clip any content in
// the
// unreachable scrollable overflow region.
// https://drafts.csswg.org/css-overflow-3/#unreachable-scrollable-overflow-region
// Unless otherwise adjusted (e.g. by content alignment [css-align-3]), the area beyond the scroll origin in
// either
// axis is considered the unreachable scrollable overflow region: content rendered here is not accessible to the
// reader, see ? 2.2 Scrollable Overflow.
// FIXME: The scroll origin and overflow directions are determined by ( block-start, inline-start ) or ( main-
// start,
// cross-start) for flex containers. Currently we assume the top-left of the absolute padding box.
pub fn layout_state_cpp_117_measure_scrollable_overflow() LayoutStub {
	return layout_stub('LayoutState.cpp:117 measure_scrollable_overflow')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:226
// Original signature: void LayoutState::resolve_relative_positions()
// This function resolves relative position offsets of fragments that belong to inline paintables.
// It runs *after* the paint tree has been constructed, so it modifies paintable node & fragment offsets
// directly.
// Collect effective relative position offset from inline-flow parent chain.
pub fn layout_state_cpp_226_layout_state_resolve_relative_positions() LayoutStub {
	return layout_stub('LayoutState.cpp:226 LayoutState::resolve_relative_positions')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:262
// Original signature: static void build_paint_tree(Node& node, Painting::Paintable* parent_paintable = nullptr)
pub fn layout_state_cpp_262_build_paint_tree() LayoutStub {
	return layout_stub('LayoutState.cpp:262 build_paint_tree')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:278
// Original signature: void LayoutState::commit(Box& root)
// Cache existing paintables before clearing.
// InlineNodes are excluded because they can span multiple lines, with a separate
// InlinePaintable created for each line via create_paintable_for_line_with_index().
// This 1:N relationship between layout node and paintables, combined with the
// dynamic nature of fragment relocation, makes simple 1:1 caching inapplicable.
// Go through the layout tree and detach all paintables. The layout tree should only point to the new paintable
// tree
// which we're about to build.
// After this point, we should have a clean slate to build the new paint tree.
// Inline nodes might have a continuation chain; add all inline nodes that are part of it.
// Try to reuse cached paintable for Box nodes
// Fall back to creating new if no reusable paintable
// For boxes, transfer all the state needed for painting.
// Create paintables for inline nodes without fragments to make possible querying their geometry.
// Resolve relative positions for regular boxes (not line box fragments):
// NOTE: This needs to occur before fragments are transferred into the corresponding inline paintables, because
// after this transfer, the containing_line_box_fragment will no longer be valid.
// Atomic inline case:
// We know that `node` is an atomic inline because `containing_line_box_fragments` refers to the
// line box fragment in the parent block container that contains it.
// The fragment has the final offset for the atomic inline, so we just need to copy it from there.
// Not an atomic inline, much simpler case.
// Apply relative position inset if appropriate.
// Measure size of paintables created for inline nodes.
// FIXME: If this paintable does not have any fragment we do no know the y offset. It should be where text should
// start if there had been any for this node. Pick y offset of the leftmost fragment in the inclusive subtree in
// the meantime.
// Build a map from each containing block to the boxes it contains.
// Measure overflow in scroll containers.
// The scroll offset can become invalid if the scrollable overflow rectangle has changed after layout.
// For example, if the scroll container has been scrolled to the very end and is then resized to become larger
// (scrollable overflow rect become smaller), the scroll offset would be out of bounds.
// https://drafts.csswg.org/css-position/#insets
// For sticky positioned boxes, the inset is instead relative to the relevant scrollport's size.
// Negative values are allowed.
pub fn layout_state_cpp_278_layout_state_commit() LayoutStub {
	return layout_stub('LayoutState.cpp:278 LayoutState::commit')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:584
// Original signature: void LayoutState::UsedValues::set_node(NodeWithStyle const& node, UsedValues const* containing_block_used_values)
// NOTE: In the code below, we decide if `node` has definite width and/or height.
// This attempts to cover all the *general* cases where CSS considers sizes to be definite.
// If `node` has definite values for min/max-width or min/max-height and a definite
// preferred size in the same axis, we clamp the preferred size here as well.
// There are additional cases where CSS considers values to be definite. We model all of
// those by having our engine consider sizes to be definite *once they are assigned to
// the UsedValues by calling set_content_width() or set_content_height().
// box-sizing: content-box and/or automatic size don't require any adjustment.
// box-sizing: border-box requires us to subtract the relevant border and padding from the size.
// A size that can be determined without performing layout; that is,
// a <length>,
// a measure of text (without consideration of line-wrapping),
// a size of the initial containing block,
// or a <percentage> or other formula (such as the "stretch-fit" sizing of non-replaced blocks [CSS2]) that is
// resolved solely against definite sizes.
// NOTE: The width of a non-flex-item block is considered definite if it's auto and the containing block has
// definite width.
// This should have been covered by the Size::is_auto() branch above.
pub fn layout_state_cpp_584_layout_state_used_values_set_node() LayoutStub {
	return layout_stub('LayoutState.cpp:584 LayoutState::UsedValues::set_node')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:717
// Original signature: void LayoutState::UsedValues::materialize_from_paintable(Painting::PaintableBox const& paintable)
pub fn layout_state_cpp_717_layout_state_used_values_materialize_from_paintable() LayoutStub {
	return layout_stub('LayoutState.cpp:717 LayoutState::UsedValues::materialize_from_paintable')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:753
// Original signature: void LayoutState::UsedValues::set_content_width(CSSPixels width)
// Negative widths are not allowed in CSS. We have a bug somewhere! Clamp to 0 to avoid doing too much damage.
// FIXME: We should not do this! Definiteness of widths should be determined early,
// and not changed later (except for some special cases in flex layout..)
pub fn layout_state_cpp_753_layout_state_used_values_set_content_width() LayoutStub {
	return layout_stub('LayoutState.cpp:753 LayoutState::UsedValues::set_content_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:766
// Original signature: void LayoutState::UsedValues::set_content_height(CSSPixels height)
// Negative heights are not allowed in CSS. We have a bug somewhere! Clamp to 0 to avoid doing too much damage.
pub fn layout_state_cpp_766_layout_state_used_values_set_content_height() LayoutStub {
	return layout_stub('LayoutState.cpp:766 LayoutState::UsedValues::set_content_height')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:776
// Original signature: AvailableSize LayoutState::UsedValues::available_width_inside() const
pub fn layout_state_cpp_776_layout_state_used_values_available_width_inside() LayoutStub {
	return layout_stub('LayoutState.cpp:776 LayoutState::UsedValues::available_width_inside')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:787
// Original signature: AvailableSize LayoutState::UsedValues::available_height_inside() const
pub fn layout_state_cpp_787_layout_state_used_values_available_height_inside() LayoutStub {
	return layout_stub('LayoutState.cpp:787 LayoutState::UsedValues::available_height_inside')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:798
// Original signature: AvailableSpace LayoutState::UsedValues::available_inner_space_or_constraints_from(AvailableSpace const& outer_space) const
pub fn layout_state_cpp_798_layout_state_used_values_available_inner_space_or_constraints_from() LayoutStub {
	return layout_stub('LayoutState.cpp:798 LayoutState::UsedValues::available_inner_space_or_constraints_from')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:810
// Original signature: void LayoutState::UsedValues::set_indefinite_content_width()
pub fn layout_state_cpp_810_layout_state_used_values_set_indefinite_content_width() LayoutStub {
	return layout_stub('LayoutState.cpp:810 LayoutState::UsedValues::set_indefinite_content_width')
}

// Translated from Libraries/LibWeb/Layout/LayoutState.cpp:815
// Original signature: void LayoutState::UsedValues::set_indefinite_content_height()
pub fn layout_state_cpp_815_layout_state_used_values_set_indefinite_content_height() LayoutStub {
	return layout_stub('LayoutState.cpp:815 LayoutState::UsedValues::set_indefinite_content_height')
}

// ---- TextNode.h (24 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TextNode.h:22
// Original signature: TextNode::GC_DECLARE_ALLOCATOR(TextNode);
pub fn text_node_h_22_text_node_gc_declare_allocator() LayoutStub {
	return layout_stub('TextNode.h:22 TextNode::GC_DECLARE_ALLOCATOR')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:25
// Original signature: TextNode::TextNode(DOM::Document&, DOM::Text&);
pub fn text_node_h_25_text_node_text_node() LayoutStub {
	return layout_stub('TextNode.h:25 TextNode::TextNode')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:26
// Original signature: TextNode::virtual ~TextNode();
pub fn text_node_h_26_destroy_text_node() LayoutStub {
	return layout_stub('TextNode.h:26 ~TextNode')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:28
// Original signature: TextNode::DOM::Text const& dom_node() const
pub fn text_node_h_28_dom_node() LayoutStub {
	return layout_stub('TextNode.h:28 dom_node')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:30
// Original signature: TextNode::Utf16String const& text_for_rendering() const;
pub fn text_node_h_30_text_for_rendering() LayoutStub {
	return layout_stub('TextNode.h:30 text_for_rendering')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:46
// Original signature: ChunkIterator::ChunkIterator(TextNode const&, bool should_wrap_lines, bool should_respect_linebreaks);
pub fn text_node_h_46_chunk_iterator_chunk_iterator() LayoutStub {
	return layout_stub('TextNode.h:46 ChunkIterator::ChunkIterator')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:47
// Original signature: ChunkIterator::ChunkIterator(TextNode const&, Utf16View const&, Unicode::Segmenter& grapheme_segmenter, Unicode::Segmenter& line_segmenter, CSS::WordBreak, bool should_wrap_lines, bool should_respect_linebreaks);
pub fn text_node_h_47_chunk_iterator_chunk_iterator() LayoutStub {
	return layout_stub('TextNode.h:47 ChunkIterator::ChunkIterator')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:49
// Original signature: ChunkIterator::bool should_wrap_lines() const
pub fn text_node_h_49_should_wrap_lines() LayoutStub {
	return layout_stub('TextNode.h:49 should_wrap_lines')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:50
// Original signature: ChunkIterator::bool should_respect_linebreaks() const
pub fn text_node_h_50_should_respect_linebreaks() LayoutStub {
	return layout_stub('TextNode.h:50 should_respect_linebreaks')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:51
// Original signature: ChunkIterator::bool should_collapse_whitespace() const
pub fn text_node_h_51_should_collapse_whitespace() LayoutStub {
	return layout_stub('TextNode.h:51 should_collapse_whitespace')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:53
// Original signature: ChunkIterator::Optional<Chunk> next();
pub fn text_node_h_53_next() LayoutStub {
	return layout_stub('TextNode.h:53 next')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:54
// Original signature: ChunkIterator::Optional<Chunk> peek(size_t);
pub fn text_node_h_54_peek() LayoutStub {
	return layout_stub('TextNode.h:54 peek')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:56
// Original signature: ChunkIterator::Chunk create_empty_chunk();
pub fn text_node_h_56_create_empty_chunk() LayoutStub {
	return layout_stub('TextNode.h:56 create_empty_chunk')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:59
// Original signature: ChunkIterator::Optional<Chunk> next_without_peek();
pub fn text_node_h_59_next_without_peek() LayoutStub {
	return layout_stub('TextNode.h:59 next_without_peek')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:60
// Original signature: ChunkIterator::Optional<Chunk> try_commit_chunk(size_t start, size_t end, bool has_breaking_newline, bool has_breaking_tab, bool can_break_after, Gfx::Font const&, Gfx::GlyphRun::TextType) const;
pub fn text_node_h_60_try_commit_chunk() LayoutStub {
	return layout_stub('TextNode.h:60 try_commit_chunk')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:62
// Original signature: ChunkIterator::[[nodiscard]] bool is_at_line_break_opportunity() const;
pub fn text_node_h_62_is_at_line_break_opportunity() LayoutStub {
	return layout_stub('TextNode.h:62 is_at_line_break_opportunity')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:63
// Original signature: ChunkIterator::[[nodiscard]] Gfx::Font const& font_for_space(size_t at_index) const;
pub fn text_node_h_63_font_for_space() LayoutStub {
	return layout_stub('TextNode.h:63 font_for_space')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:81
// Original signature: TextNode::void invalidate_text_for_rendering();
pub fn text_node_h_81_invalidate_text_for_rendering() LayoutStub {
	return layout_stub('TextNode.h:81 invalidate_text_for_rendering')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:83
// Original signature: TextNode::Unicode::Segmenter& grapheme_segmenter() const;
pub fn text_node_h_83_grapheme_segmenter() LayoutStub {
	return layout_stub('TextNode.h:83 grapheme_segmenter')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:84
// Original signature: TextNode::Unicode::Segmenter& line_segmenter() const;
pub fn text_node_h_84_line_segmenter() LayoutStub {
	return layout_stub('TextNode.h:84 line_segmenter')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:86
// Original signature: TextNode::virtual GC::Ptr<Painting::Paintable> create_paintable() const;
pub fn text_node_h_86_create_paintable() LayoutStub {
	return layout_stub('TextNode.h:86 create_paintable')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:89
// Original signature: TextNode::virtual bool is_text_node() const
pub fn text_node_h_89_is_text_node() LayoutStub {
	return layout_stub('TextNode.h:89 is_text_node')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:91
// Original signature: TextNode::void compute_text_for_rendering();
pub fn text_node_h_91_compute_text_for_rendering() LayoutStub {
	return layout_stub('TextNode.h:91 compute_text_for_rendering')
}

// Translated from Libraries/LibWeb/Layout/TextNode.h:99
// Original signature: inline bool Node::fast_is<TextNode>() const
pub fn text_node_h_99_function() LayoutStub {
	return layout_stub('TextNode.h:99 function')
}

// ---- TextNode.cpp (21 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:24
// Original signature: TextNode::TextNode(DOM::Document& document, DOM::Text& text) : Node(document, &text)
pub fn text_node_cpp_24_text_node_text_node() LayoutStub {
	return layout_stub('TextNode.cpp:24 TextNode::TextNode')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:29
// Original signature: TextNode::~TextNode() = default;
pub fn text_node_cpp_29_text_node_destroy_text_node() LayoutStub {
	return layout_stub('TextNode.cpp:29 TextNode::~TextNode')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:32
// Original signature: static Utf16String apply_math_auto_text_transform(Utf16String const& string)
// https://w3c.github.io/mathml-core/#new-text-transform-values
// https://w3c.github.io/mathml-core/#italic-mappings
pub fn text_node_cpp_32_apply_math_auto_text_transform() LayoutStub {
	return layout_stub('TextNode.cpp:32 apply_math_auto_text_transform')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:274
// Original signature: static Utf16String apply_text_transform(Utf16String const& string, CSS::TextTransform text_transform, Optional<StringView> const& locale)
pub fn text_node_cpp_274_apply_text_transform() LayoutStub {
	return layout_stub('TextNode.cpp:274 apply_text_transform')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:297
// Original signature: void TextNode::invalidate_text_for_rendering()
pub fn text_node_cpp_297_text_node_invalidate_text_for_rendering() LayoutStub {
	return layout_stub('TextNode.cpp:297 TextNode::invalidate_text_for_rendering')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:304
// Original signature: Utf16String const& TextNode::text_for_rendering() const
pub fn text_node_cpp_304_text_node_text_for_rendering() LayoutStub {
	return layout_stub('TextNode.cpp:304 TextNode::text_for_rendering')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:311
// Original signature: void TextNode::compute_text_for_rendering()
// Apply text-transform
// FIXME: This can generate more code points than there were before; we need to find a better way to map the
// resulting paintable fragments' offsets into the original text node data.
// See: https://github.com/LadybirdBrowser/ladybird/issues/6177
// The logic below deals with converting whitespace characters. If we don't have them, return early.
// https://drafts.csswg.org/css-text-4/#white-space-phase-1
// If white-space-collapse is set to collapse or preserve-breaks, white space characters are considered
// collapsible
// and are processed by performing the following steps:
// 1. FIXME: Any sequence of collapsible spaces and tabs immediately preceding or following a segment break is
// removed.
// 2. Collapsible segment breaks are transformed for rendering according to the segment break transformation
// rules.
// https://drafts.csswg.org/css-text-4/#line-break-transform
// FIXME: When white-space-collapse is not collapse, segment breaks are not collapsible. For values other than
// collapse or preserve-spaces (which transforms them into spaces), segment breaks are instead transformed
// into a preserved line feed (U+000A).
// When white-space-collapse is collapse, segment breaks are collapsible, and are collapsed as follows:
// 1. FIXME: First, any collapsible segment break immediately following another collapsible segment break is
// removed.
// 2. FIXME: Then any remaining segment break is either transformed into a space (U+0020) or removed depending
// on the context before and after the break. The rules for this operation are UA-defined in this
// level.
// 3. Every collapsible tab is converted to a collapsible space (U+0020).
// 4. Any collapsible space immediately following another collapsible space-even one outside the boundary of the
// inline containing that space, provided both spaces are within the same inline formatting context-is
// collapsed to have zero advance width. (It is invisible, but retains its soft wrap opportunity, if any.)
// AD-HOC: This is handled by TextNode::ChunkIterator by removing the space.
// If white-space-collapse is set to preserve-spaces, each tab and segment break is converted to a space.
// AD-HOC: Prevent allocating a StringBuilder for a single space/newline/tab.
// AD-HOC: It's important to not change the amount of code units in the resulting transformed text, so
// ChunkIterator
// can pass views to this string with associated code unit offsets that still match the original text.
pub fn text_node_cpp_311_text_node_compute_text_for_rendering() LayoutStub {
	return layout_stub('TextNode.cpp:311 TextNode::compute_text_for_rendering')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:399
// Original signature: Unicode::Segmenter& TextNode::grapheme_segmenter() const
// Fast path: For ASCII text, every character is its own grapheme.
// We can use a trivial segmenter that avoids all ICU overhead.
pub fn text_node_cpp_399_text_node_grapheme_segmenter() LayoutStub {
	return layout_stub('TextNode.cpp:399 TextNode::grapheme_segmenter')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:416
// Original signature: Unicode::Segmenter& TextNode::line_segmenter() const
pub fn text_node_cpp_416_text_node_line_segmenter() LayoutStub {
	return layout_stub('TextNode.cpp:416 TextNode::line_segmenter')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:426
// Original signature: static bool is_interword_space(u32 code_point)
pub fn text_node_cpp_426_is_interword_space() LayoutStub {
	return layout_stub('TextNode.cpp:426 is_interword_space')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:431
// Original signature: TextNode::ChunkIterator::ChunkIterator(TextNode const& text_node, bool should_wrap_lines, bool should_respect_linebreaks) : ChunkIterator(text_node, text_node.text_for_rendering(), text_node.grapheme_segmenter(), text_node.line_segmenter(), text_node.computed_values().word_break(), should_wrap_lines, should_respect_linebreaks)
pub fn text_node_cpp_431_text_node_chunk_iterator_chunk_iterator() LayoutStub {
	return layout_stub('TextNode.cpp:431 TextNode::ChunkIterator::ChunkIterator')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:436
// Original signature: TextNode::ChunkIterator::ChunkIterator(TextNode const& text_node, Utf16View const& text, Unicode::Segmenter& grapheme_segmenter, Unicode::Segmenter& line_segmenter, CSS::WordBreak word_break, bool should_wrap_lines, bool should_respect_linebreaks) : m_should_wrap_lines(should_wrap_lines) , m_should_respect_linebreaks(should_respect_linebreaks) , m_view(text) , m_font_cascade_list(text_node.computed_values().font_list()) , m_grapheme_segmenter(grapheme_segmenter) , m_line_segmenter(line_segmenter) , m_word_break(word_break)
pub fn text_node_cpp_436_text_node_chunk_iterator_chunk_iterator() LayoutStub {
	return layout_stub('TextNode.cpp:436 TextNode::ChunkIterator::ChunkIterator')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:450
// Original signature: static Gfx::GlyphRun::TextType text_type_for_code_point(u32 code_point)
// Fast path for ASCII using a lookup table.
// Each ASCII character has a statically known bidi class.
// clang-format off
// 0x00-0x0F: Control characters (BN=Common, S/B/WS=ContextDependent)
// 0x10-0x1F: Control characters
// 0x20-0x2F: Space and punctuation
// 0x30-0x3F: Digits and punctuation
// 0x40-0x4F: @ and uppercase letters
// 0x50-0x5F: Uppercase letters and punctuation
// 0x60-0x6F: ` and lowercase letters
// 0x70-0x7F: Lowercase letters and punctuation
// clang-format on
pub fn text_node_cpp_450_text_type_for_code_point() LayoutStub {
	return layout_stub('TextNode.cpp:450 text_type_for_code_point')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:521
// Original signature: Optional<TextNode::Chunk> TextNode::ChunkIterator::next()
pub fn text_node_cpp_521_text_node_chunk_iterator_next() LayoutStub {
	return layout_stub('TextNode.cpp:521 TextNode::ChunkIterator::next')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:528
// Original signature: Optional<TextNode::Chunk> TextNode::ChunkIterator::peek(size_t count)
pub fn text_node_cpp_528_text_node_chunk_iterator_peek() LayoutStub {
	return layout_stub('TextNode.cpp:528 TextNode::ChunkIterator::peek')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:540
// Original signature: TextNode::Chunk TextNode::ChunkIterator::create_empty_chunk()
pub fn text_node_cpp_540_text_node_chunk_iterator_create_empty_chunk() LayoutStub {
	return layout_stub('TextNode.cpp:540 TextNode::ChunkIterator::create_empty_chunk')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:550
// Original signature: bool TextNode::ChunkIterator::is_at_line_break_opportunity() const
// https://drafts.csswg.org/css-text-4/#word-break-property
// This property specifies soft wrap opportunities between and within "words", i.e. where it is "normal" and
// permissible to break lines of text. It focuses on breaks between letters, and does not define whether and how
// soft wrap opportunities are created by white space and other space separators (though auto-phrase may suppress
// some), nor around punctuation.
// https://drafts.csswg.org/css-text-4/#valdef-word-break-normal
// Words break according to their customary rules, as described above. Korean, which commonly exhibits two
// different behaviors, allows breaks between any two consecutive Hangul/Hanja. For Ethiopic, which also
// exhibits two different behaviors, such breaks within words are not allowed.
// https://drafts.csswg.org/css-text-4/#valdef-word-break-break-word
// For compatibility with legacy content, the word-break property also supports a deprecated break-word
// keyword. When specified, this has the same effect as word-break: normal and overflow-wrap: anywhere,
// regardless of the actual value of the overflow-wrap property.
// https://drafts.csswg.org/css-text-4/#valdef-word-break-break-all
// Breaking is allowed within "words": specifically, in addition to soft wrap opportunities allowed for normal,
// any typographic letter units (and any typographic character units resolving to the NU ("numeric"),
// AL ("alphabetic"), or SA ("Southeast Asian") line breaking classes [UAX14]) are instead treated as ID
// ("ideographic characters") for the purpose of line-breaking. Hyphenation is not applied.
// https://drafts.csswg.org/css-text-4/#valdef-word-break-keep-all
// Breaking is forbidden within "words": implicit soft wrap opportunities between typographic letter units
// (or other typographic character units belonging to the NU, AL, AI, or ID Unicode line breaking classes
// [UAX14])
// are suppressed, i.e. breaks are prohibited between pairs of such characters (regardless of line-break
// settings other than anywhere) except where opportunities exist due to ?6.1.1.1 Lexical Word Breaking.
// Otherwise this option is equivalent to normal. In this style, sequences of CJK characters do not break.
pub fn text_node_cpp_550_text_node_chunk_iterator_is_at_line_break_opportunity() LayoutStub {
	return layout_stub('TextNode.cpp:550 TextNode::ChunkIterator::is_at_line_break_opportunity')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:634
// Original signature: Gfx::Font const& TextNode::ChunkIterator::font_for_space(size_t at_index) const
// 1. Prefer the last non-whitespace font in this node/run.
// 2. Look ahead to the next non-space to infer the base font of this run.
// Text is coming from an emoji face; we'll fall back to (3).
// 3. No text around (leading/trailing/all spaces) - pick the first *text* face in the cascade.
pub fn text_node_cpp_634_text_node_chunk_iterator_font_for_space() LayoutStub {
	return layout_stub('TextNode.cpp:634 TextNode::ChunkIterator::font_for_space')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:657
// Original signature: Optional<TextNode::Chunk> TextNode::ChunkIterator::next_without_peek()
// https://drafts.csswg.org/css-text-4/#collapsible-white-space
// consume any consecutive tabs
// Newline encountered, and we're supposed to preserve them.
// If we have accumulated some code points in the current chunk, commit them now and continue with the newline
// next time.
// Otherwise, commit the newline!
// If both this code point and the previous code point are collapsible, skip code points until we're at a non-
// collapsible code point.
// Whitespace encountered, and we're allowed to break on whitespace.
// If we have accumulated some code points in the current chunk, commit them now and continue with the whitespace
// next time.
// Otherwise, commit the whitespace!
// Try to output whatever's left at the end of the text node.
pub fn text_node_cpp_657_text_node_chunk_iterator_next_without_peek() LayoutStub {
	return layout_stub('TextNode.cpp:657 TextNode::ChunkIterator::next_without_peek')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:777
// Original signature: Optional<TextNode::Chunk> TextNode::ChunkIterator::try_commit_chunk(size_t start, size_t end, bool has_breaking_newline, bool has_breaking_tab, bool can_break_after, Gfx::Font const& font, Gfx::GlyphRun::TextType text_type) const
pub fn text_node_cpp_777_text_node_chunk_iterator_try_commit_chunk() LayoutStub {
	return layout_stub('TextNode.cpp:777 TextNode::ChunkIterator::try_commit_chunk')
}

// Translated from Libraries/LibWeb/Layout/TextNode.cpp:800
// Original signature: GC::Ptr<Painting::Paintable> TextNode::create_paintable() const
pub fn text_node_cpp_800_text_node_create_paintable() LayoutStub {
	return layout_stub('TextNode.cpp:800 TextNode::create_paintable')
}

// ---- LineBox.h (16 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LineBox.h:22
// Original signature: LineBox::CSSPixels width() const;
pub fn line_box_h_22_width() LayoutStub {
	return layout_stub('LineBox.h:22 width')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:23
// Original signature: LineBox::CSSPixels height() const;
pub fn line_box_h_23_height() LayoutStub {
	return layout_stub('LineBox.h:23 height')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:24
// Original signature: LineBox::CSSPixels bottom() const;
pub fn line_box_h_24_bottom() LayoutStub {
	return layout_stub('LineBox.h:24 bottom')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:26
// Original signature: LineBox::CSSPixels inline_length() const
pub fn line_box_h_26_inline_length() LayoutStub {
	return layout_stub('LineBox.h:26 inline_length')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:27
// Original signature: LineBox::CSSPixels block_length() const
pub fn line_box_h_27_block_length() LayoutStub {
	return layout_stub('LineBox.h:27 block_length')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:28
// Original signature: LineBox::CSSPixels baseline() const
pub fn line_box_h_28_baseline() LayoutStub {
	return layout_stub('LineBox.h:28 baseline')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:30
// Original signature: LineBox::void add_fragment(Node const& layout_node, size_t start, size_t length, CSSPixels leading_size, CSSPixels trailing_size, CSSPixels leading_margin, CSSPixels trailing_margin, CSSPixels content_width, CSSPixels content_height, CSSPixels border_box_top, CSSPixels border_box_bottom, RefPtr<Gfx::GlyphRun> glyph_run =
pub fn line_box_h_30_add_fragment() LayoutStub {
	return layout_stub('LineBox.h:30 add_fragment')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:32
// Original signature: LineBox::Vector<LineBoxFragment> const& fragments() const
pub fn line_box_h_32_fragments() LayoutStub {
	return layout_stub('LineBox.h:32 fragments')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:33
// Original signature: LineBox::Vector<LineBoxFragment>& fragments()
pub fn line_box_h_33_fragments() LayoutStub {
	return layout_stub('LineBox.h:33 fragments')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:35
// Original signature: LineBox::CSSPixels get_trailing_whitespace_width() const;
pub fn line_box_h_35_get_trailing_whitespace_width() LayoutStub {
	return layout_stub('LineBox.h:35 get_trailing_whitespace_width')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:36
// Original signature: LineBox::void trim_trailing_whitespace();
pub fn line_box_h_36_trim_trailing_whitespace() LayoutStub {
	return layout_stub('LineBox.h:36 trim_trailing_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:38
// Original signature: LineBox::bool is_empty_or_ends_in_whitespace() const;
pub fn line_box_h_38_is_empty_or_ends_in_whitespace() LayoutStub {
	return layout_stub('LineBox.h:38 is_empty_or_ends_in_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:39
// Original signature: LineBox::bool is_empty() const
pub fn line_box_h_39_is_empty() LayoutStub {
	return layout_stub('LineBox.h:39 is_empty')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:41
// Original signature: LineBox::AvailableSize original_available_width() const
pub fn line_box_h_41_original_available_width() LayoutStub {
	return layout_stub('LineBox.h:41 original_available_width')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:53
// Original signature: LineBox::CSSPixels calculate_or_trim_trailing_whitespace(RemoveTrailingWhitespace);
pub fn line_box_h_53_calculate_or_trim_trailing_whitespace() LayoutStub {
	return layout_stub('LineBox.h:53 calculate_or_trim_trailing_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBox.h:64
// Original signature: LineBox::AvailableSize m_original_available_width
// The amount of available width that was originally available when creating this line box. Used for text
// justification.
pub fn line_box_h_64_function() LayoutStub {
	return layout_stub('LineBox.h:64 function')
}

// ---- LineBox.cpp (8 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:19
// Original signature: CSSPixels LineBox::width() const
pub fn line_box_cpp_19_line_box_width() LayoutStub {
	return layout_stub('LineBox.cpp:19 LineBox::width')
}

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:26
// Original signature: CSSPixels LineBox::height() const
pub fn line_box_cpp_26_line_box_height() LayoutStub {
	return layout_stub('LineBox.cpp:26 LineBox::height')
}

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:33
// Original signature: CSSPixels LineBox::bottom() const
pub fn line_box_cpp_33_line_box_bottom() LayoutStub {
	return layout_stub('LineBox.cpp:33 LineBox::bottom')
}

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:40
// Original signature: void LineBox::add_fragment(Node const& layout_node, size_t start, size_t length, CSSPixels leading_size, CSSPixels trailing_size, CSSPixels leading_margin, CSSPixels trailing_margin, CSSPixels content_width, CSSPixels content_height, CSSPixels border_box_top, CSSPixels border_box_bottom, RefPtr<Gfx::GlyphRun> glyph_run)
// The fragment we're adding is from the last Layout::Node on the line.
// Expand the last fragment instead of adding a new one with the same Layout::Node.
pub fn line_box_cpp_40_line_box_add_fragment() LayoutStub {
	return layout_stub('LineBox.cpp:40 LineBox::add_fragment')
}

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:63
// Original signature: CSSPixels LineBox::calculate_or_trim_trailing_whitespace(RemoveTrailingWhitespace should_remove)
// No text to trim, but we may have removed whitespace-only fragments.
// Trim trailing whitespace characters from the last fragment.
// Track trimmed whitespace for selection purposes, but don't overwrite a value
// that was already set during line breaking (for wrapped lines).
pub fn line_box_cpp_63_line_box_calculate_or_trim_trailing_whitespace() LayoutStub {
	return layout_stub('LineBox.cpp:63 LineBox::calculate_or_trim_trailing_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:134
// Original signature: CSSPixels LineBox::get_trailing_whitespace_width() const
pub fn line_box_cpp_134_line_box_get_trailing_whitespace_width() LayoutStub {
	return layout_stub('LineBox.cpp:134 LineBox::get_trailing_whitespace_width')
}

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:139
// Original signature: void LineBox::trim_trailing_whitespace()
pub fn line_box_cpp_139_line_box_trim_trailing_whitespace() LayoutStub {
	return layout_stub('LineBox.cpp:139 LineBox::trim_trailing_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBox.cpp:144
// Original signature: bool LineBox::is_empty_or_ends_in_whitespace() const
pub fn line_box_cpp_144_line_box_is_empty_or_ends_in_whitespace() LayoutStub {
	return layout_stub('LineBox.cpp:144 LineBox::is_empty_or_ends_in_whitespace')
}

// ---- LineBoxFragment.h (31 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:21
// Original signature: LineBoxFragment::LineBoxFragment(Node const& layout_node, size_t start, size_t length, CSSPixels inline_offset, CSSPixels block_offset, CSSPixels inline_length, CSSPixels block_length, CSSPixels border_box_top, CSS::Direction, CSS::WritingMode, RefPtr<Gfx::GlyphRun>);
pub fn line_box_fragment_h_21_line_box_fragment_line_box_fragment() LayoutStub {
	return layout_stub('LineBoxFragment.h:21 LineBoxFragment::LineBoxFragment')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:23
// Original signature: LineBoxFragment::Node const& layout_node() const
pub fn line_box_fragment_h_23_layout_node() LayoutStub {
	return layout_stub('LineBoxFragment.h:23 layout_node')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:24
// Original signature: LineBoxFragment::size_t start() const
pub fn line_box_fragment_h_24_start() LayoutStub {
	return layout_stub('LineBoxFragment.h:24 start')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:25
// Original signature: LineBoxFragment::size_t length_in_code_units() const
pub fn line_box_fragment_h_25_length_in_code_units() LayoutStub {
	return layout_stub('LineBoxFragment.h:25 length_in_code_units')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:27
// Original signature: LineBoxFragment::CSSPixelPoint offset() const;
pub fn line_box_fragment_h_27_offset() LayoutStub {
	return layout_stub('LineBoxFragment.h:27 offset')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:28
// Original signature: LineBoxFragment::CSSPixels inline_offset() const
pub fn line_box_fragment_h_28_inline_offset() LayoutStub {
	return layout_stub('LineBoxFragment.h:28 inline_offset')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:29
// Original signature: LineBoxFragment::CSSPixels block_offset() const
pub fn line_box_fragment_h_29_block_offset() LayoutStub {
	return layout_stub('LineBoxFragment.h:29 block_offset')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:30
// Original signature: LineBoxFragment::void set_inline_offset(CSSPixels inline_offset)
pub fn line_box_fragment_h_30_set_inline_offset() LayoutStub {
	return layout_stub('LineBoxFragment.h:30 set_inline_offset')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:31
// Original signature: LineBoxFragment::void set_block_offset(CSSPixels block_offset)
pub fn line_box_fragment_h_31_set_block_offset() LayoutStub {
	return layout_stub('LineBoxFragment.h:31 set_block_offset')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:34
// Original signature: LineBoxFragment::void set_baseline(CSSPixels y)
// The baseline of a fragment is the number of pixels from the top to the text baseline.
pub fn line_box_fragment_h_34_set_baseline() LayoutStub {
	return layout_stub('LineBoxFragment.h:34 set_baseline')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:35
// Original signature: LineBoxFragment::CSSPixels baseline() const
pub fn line_box_fragment_h_35_baseline() LayoutStub {
	return layout_stub('LineBoxFragment.h:35 baseline')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:37
// Original signature: LineBoxFragment::CSSPixelSize size() const;
pub fn line_box_fragment_h_37_size() LayoutStub {
	return layout_stub('LineBoxFragment.h:37 size')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:38
// Original signature: LineBoxFragment::CSSPixels width() const
pub fn line_box_fragment_h_38_width() LayoutStub {
	return layout_stub('LineBoxFragment.h:38 width')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:39
// Original signature: LineBoxFragment::CSSPixels height() const
pub fn line_box_fragment_h_39_height() LayoutStub {
	return layout_stub('LineBoxFragment.h:39 height')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:40
// Original signature: LineBoxFragment::CSSPixels inline_length() const
pub fn line_box_fragment_h_40_inline_length() LayoutStub {
	return layout_stub('LineBoxFragment.h:40 inline_length')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:41
// Original signature: LineBoxFragment::CSSPixels block_length() const
pub fn line_box_fragment_h_41_block_length() LayoutStub {
	return layout_stub('LineBoxFragment.h:41 block_length')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:42
// Original signature: LineBoxFragment::void set_inline_length(CSSPixels inline_length)
pub fn line_box_fragment_h_42_set_inline_length() LayoutStub {
	return layout_stub('LineBoxFragment.h:42 set_inline_length')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:43
// Original signature: LineBoxFragment::void set_block_length(CSSPixels block_length)
pub fn line_box_fragment_h_43_set_block_length() LayoutStub {
	return layout_stub('LineBoxFragment.h:43 set_block_length')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:45
// Original signature: LineBoxFragment::CSSPixels border_box_top() const
pub fn line_box_fragment_h_45_border_box_top() LayoutStub {
	return layout_stub('LineBoxFragment.h:45 border_box_top')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:47
// Original signature: LineBoxFragment::bool ends_in_whitespace() const;
pub fn line_box_fragment_h_47_ends_in_whitespace() LayoutStub {
	return layout_stub('LineBoxFragment.h:47 ends_in_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:48
// Original signature: LineBoxFragment::bool is_justifiable_whitespace() const;
pub fn line_box_fragment_h_48_is_justifiable_whitespace() LayoutStub {
	return layout_stub('LineBoxFragment.h:48 is_justifiable_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:49
// Original signature: LineBoxFragment::Utf16View text() const;
pub fn line_box_fragment_h_49_text() LayoutStub {
	return layout_stub('LineBoxFragment.h:49 text')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:51
// Original signature: LineBoxFragment::bool is_atomic_inline() const;
pub fn line_box_fragment_h_51_is_atomic_inline() LayoutStub {
	return layout_stub('LineBoxFragment.h:51 is_atomic_inline')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:53
// Original signature: LineBoxFragment::RefPtr<Gfx::GlyphRun> glyph_run() const
pub fn line_box_fragment_h_53_glyph_run() LayoutStub {
	return layout_stub('LineBoxFragment.h:53 glyph_run')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:54
// Original signature: LineBoxFragment::CSS::WritingMode writing_mode() const
pub fn line_box_fragment_h_54_writing_mode() LayoutStub {
	return layout_stub('LineBoxFragment.h:54 writing_mode')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:55
// Original signature: LineBoxFragment::void append_glyph_run(RefPtr<Gfx::GlyphRun> const&, CSSPixels run_width);
pub fn line_box_fragment_h_55_append_glyph_run() LayoutStub {
	return layout_stub('LineBoxFragment.h:55 append_glyph_run')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:57
// Original signature: LineBoxFragment::bool has_trailing_whitespace() const
pub fn line_box_fragment_h_57_has_trailing_whitespace() LayoutStub {
	return layout_stub('LineBoxFragment.h:57 has_trailing_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:58
// Original signature: LineBoxFragment::void set_has_trailing_whitespace(bool value)
pub fn line_box_fragment_h_58_set_has_trailing_whitespace() LayoutStub {
	return layout_stub('LineBoxFragment.h:58 set_has_trailing_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:61
// Original signature: LineBoxFragment::CSS::Direction resolve_glyph_run_direction(Gfx::GlyphRun::TextType) const;
pub fn line_box_fragment_h_61_resolve_glyph_run_direction() LayoutStub {
	return layout_stub('LineBoxFragment.h:61 resolve_glyph_run_direction')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:62
// Original signature: LineBoxFragment::void append_glyph_run_ltr(RefPtr<Gfx::GlyphRun> const&, CSSPixels run_width);
pub fn line_box_fragment_h_62_append_glyph_run_ltr() LayoutStub {
	return layout_stub('LineBoxFragment.h:62 append_glyph_run_ltr')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.h:63
// Original signature: LineBoxFragment::void append_glyph_run_rtl(RefPtr<Gfx::GlyphRun> const&, CSSPixels run_width);
pub fn line_box_fragment_h_63_append_glyph_run_rtl() LayoutStub {
	return layout_stub('LineBoxFragment.h:63 append_glyph_run_rtl')
}

// ---- LineBoxFragment.cpp (11 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:15
// Original signature: LineBoxFragment::LineBoxFragment(Node const& layout_node, size_t start, size_t length_in_code_units, CSSPixels inline_offset, CSSPixels block_offset, CSSPixels inline_length, CSSPixels block_length, CSSPixels border_box_top, CSS::Direction direction, CSS::WritingMode writing_mode, RefPtr<Gfx::GlyphRun> glyph_run) : m_layout_node(layout_node) , m_start(start) , m_length_in_code_units(length_in_code_units) , m_inline_offset(inline_offset) , m_block_offset(block_offset) , m_inline_length(inline_length) , m_block_length(block_length) , m_border_box_top(border_box_top) , m_direction(direction) , m_writing_mode(writing_mode) , m_glyph_run(move(glyph_run))
pub fn line_box_fragment_cpp_15_line_box_fragment_line_box_fragment() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:15 LineBoxFragment::LineBoxFragment')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:37
// Original signature: CSSPixelPoint LineBoxFragment::offset() const
pub fn line_box_fragment_cpp_37_line_box_fragment_offset() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:37 LineBoxFragment::offset')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:44
// Original signature: CSSPixelSize LineBoxFragment::size() const
pub fn line_box_fragment_cpp_44_line_box_fragment_size() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:44 LineBoxFragment::size')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:51
// Original signature: bool LineBoxFragment::ends_in_whitespace() const
pub fn line_box_fragment_cpp_51_line_box_fragment_ends_in_whitespace() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:51 LineBoxFragment::ends_in_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:58
// Original signature: bool LineBoxFragment::is_justifiable_whitespace() const
pub fn line_box_fragment_cpp_58_line_box_fragment_is_justifiable_whitespace() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:58 LineBoxFragment::is_justifiable_whitespace')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:63
// Original signature: Utf16View LineBoxFragment::text() const
pub fn line_box_fragment_cpp_63_line_box_fragment_text() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:63 LineBoxFragment::text')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:70
// Original signature: bool LineBoxFragment::is_atomic_inline() const
pub fn line_box_fragment_cpp_70_line_box_fragment_is_atomic_inline() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:70 LineBoxFragment::is_atomic_inline')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:75
// Original signature: CSS::Direction LineBoxFragment::resolve_glyph_run_direction(Gfx::GlyphRun::TextType text_type) const
pub fn line_box_fragment_cpp_75_line_box_fragment_resolve_glyph_run_direction() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:75 LineBoxFragment::resolve_glyph_run_direction')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:91
// Original signature: void LineBoxFragment::append_glyph_run(RefPtr<Gfx::GlyphRun> const& glyph_run, CSSPixels run_width)
pub fn line_box_fragment_cpp_91_line_box_fragment_append_glyph_run() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:91 LineBoxFragment::append_glyph_run')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:103
// Original signature: void LineBoxFragment::append_glyph_run_ltr(RefPtr<Gfx::GlyphRun> const& glyph_run, CSSPixels run_width)
pub fn line_box_fragment_cpp_103_line_box_fragment_append_glyph_run_ltr() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:103 LineBoxFragment::append_glyph_run_ltr')
}

// Translated from Libraries/LibWeb/Layout/LineBoxFragment.cpp:139
// Original signature: void LineBoxFragment::append_glyph_run_rtl(RefPtr<Gfx::GlyphRun> const& glyph_run, CSSPixels run_width)
pub fn line_box_fragment_cpp_139_line_box_fragment_append_glyph_run_rtl() LayoutStub {
	return layout_stub('LineBoxFragment.cpp:139 LineBoxFragment::append_glyph_run_rtl')
}

// ---- LineBuilder.h (17 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:14
// Original signature: LineBuilder::AK_MAKE_NONCOPYABLE(LineBuilder);
pub fn line_builder_h_14_line_builder_ak_make_noncopyable() LayoutStub {
	return layout_stub('LineBuilder.h:14 LineBuilder::AK_MAKE_NONCOPYABLE')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:15
// Original signature: LineBuilder::AK_MAKE_NONMOVABLE(LineBuilder);
pub fn line_builder_h_15_line_builder_ak_make_nonmovable() LayoutStub {
	return layout_stub('LineBuilder.h:15 LineBuilder::AK_MAKE_NONMOVABLE')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:18
// Original signature: LineBuilder::LineBuilder(InlineFormattingContext&, LayoutState&, LayoutState::UsedValues& containing_block_used_values, CSS::Direction, CSS::WritingMode);
pub fn line_builder_h_18_line_builder_line_builder() LayoutStub {
	return layout_stub('LineBuilder.h:18 LineBuilder::LineBuilder')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:25
// Original signature: LineBuilder::void break_line(ForcedBreak, Optional<CSSPixels> next_item_width =
pub fn line_builder_h_25_break_line() LayoutStub {
	return layout_stub('LineBuilder.h:25 break_line')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:26
// Original signature: LineBuilder::void append_box(Box const&, CSSPixels leading_size, CSSPixels trailing_size, CSSPixels leading_margin, CSSPixels trailing_margin);
pub fn line_builder_h_26_append_box() LayoutStub {
	return layout_stub('LineBuilder.h:26 append_box')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:27
// Original signature: LineBuilder::void append_text_chunk(TextNode const&, size_t offset_in_node, size_t length_in_node, CSSPixels leading_size, CSSPixels trailing_size, CSSPixels leading_margin, CSSPixels trailing_margin, CSSPixels content_width, CSSPixels content_height, RefPtr<Gfx::GlyphRun>);
pub fn line_builder_h_27_append_text_chunk() LayoutStub {
	return layout_stub('LineBuilder.h:27 append_text_chunk')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:39
// Original signature: LineBuilder::void update_last_line();
pub fn line_builder_h_39_update_last_line() LayoutStub {
	return layout_stub('LineBuilder.h:39 update_last_line')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:41
// Original signature: LineBuilder::void remove_last_line_if_empty();
pub fn line_builder_h_41_remove_last_line_if_empty() LayoutStub {
	return layout_stub('LineBuilder.h:41 remove_last_line_if_empty')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:43
// Original signature: LineBuilder::void set_trailing_whitespace_on_previous_line();
pub fn line_builder_h_43_set_trailing_whitespace_on_previous_line() LayoutStub {
	return layout_stub('LineBuilder.h:43 set_trailing_whitespace_on_previous_line')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:45
// Original signature: LineBuilder::CSSPixels current_block_offset() const
pub fn line_builder_h_45_current_block_offset() LayoutStub {
	return layout_stub('LineBuilder.h:45 current_block_offset')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:47
// Original signature: LineBuilder::void recalculate_available_space();
pub fn line_builder_h_47_recalculate_available_space() LayoutStub {
	return layout_stub('LineBuilder.h:47 recalculate_available_space')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:48
// Original signature: LineBuilder::CSSPixels y_for_float_to_be_inserted_here(Box const&);
pub fn line_builder_h_48_y_for_float_to_be_inserted_here() LayoutStub {
	return layout_stub('LineBuilder.h:48 y_for_float_to_be_inserted_here')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:50
// Original signature: LineBuilder::void did_introduce_clearance(CSSPixels);
pub fn line_builder_h_50_did_introduce_clearance() LayoutStub {
	return layout_stub('LineBuilder.h:50 did_introduce_clearance')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:53
// Original signature: LineBuilder::void begin_new_line(bool increment_y, bool is_first_break_in_sequence = true, ForcedBreak = ForcedBreak::No);
pub fn line_builder_h_53_begin_new_line() LayoutStub {
	return layout_stub('LineBuilder.h:53 begin_new_line')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:55
// Original signature: LineBuilder::bool should_break(CSSPixels next_item_width);
pub fn line_builder_h_55_should_break() LayoutStub {
	return layout_stub('LineBuilder.h:55 should_break')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:57
// Original signature: LineBuilder::LineBox& ensure_last_line_box();
pub fn line_builder_h_57_ensure_last_line_box() LayoutStub {
	return layout_stub('LineBuilder.h:57 ensure_last_line_box')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.h:62
// Original signature: LineBuilder::AvailableSize m_available_width_for_current_line
pub fn line_builder_h_62_function() LayoutStub {
	return layout_stub('LineBuilder.h:62 function')
}

// ---- LineBuilder.cpp (13 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:13
// Original signature: LineBuilder::LineBuilder(InlineFormattingContext& context, LayoutState& layout_state, LayoutState::UsedValues& containing_block_used_values, CSS::Direction direction, CSS::WritingMode writing_mode) : m_context(context) , m_layout_state(layout_state) , m_containing_block_used_values(containing_block_used_values) , m_direction(direction) , m_writing_mode(writing_mode)
pub fn line_builder_cpp_13_line_builder_line_builder() LayoutStub {
	return layout_stub('LineBuilder.cpp:13 LineBuilder::LineBuilder')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:27
// Original signature: void LineBuilder::break_line(ForcedBreak forced_break, Optional<CSSPixels> next_item_width)
// FIXME: Respect inline direction.
pub fn line_builder_cpp_27_line_builder_break_line() LayoutStub {
	return layout_stub('LineBuilder.cpp:27 LineBuilder::break_line')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:50
// Original signature: void LineBuilder::begin_new_line(bool increment_y, bool is_first_break_in_sequence, ForcedBreak forced_break)
// First break is simple, just go to the start of the next line.
// We're doing more than one break in a row.
// This means we're trying to squeeze past intruding floats.
// Scan 1px at a time until we find a Y value where a new line can fit.
// FIXME: This is super dumb and inefficient.
pub fn line_builder_cpp_50_line_builder_begin_new_line() LayoutStub {
	return layout_stub('LineBuilder.cpp:50 LineBuilder::begin_new_line')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:86
// Original signature: LineBox& LineBuilder::ensure_last_line_box()
pub fn line_builder_cpp_86_line_builder_ensure_last_line_box() LayoutStub {
	return layout_stub('LineBuilder.cpp:86 LineBuilder::ensure_last_line_box')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:94
// Original signature: void LineBuilder::append_box(Box const& box, CSSPixels leading_size, CSSPixels trailing_size, CSSPixels leading_margin, CSSPixels trailing_margin)
pub fn line_builder_cpp_94_line_builder_append_box() LayoutStub {
	return layout_stub('LineBuilder.cpp:94 LineBuilder::append_box')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:108
// Original signature: void LineBuilder::append_text_chunk(TextNode const& text_node, size_t offset_in_node, size_t length_in_node, CSSPixels leading_size, CSSPixels trailing_size, CSSPixels leading_margin, CSSPixels trailing_margin, CSSPixels content_width, CSSPixels content_height, RefPtr<Gfx::GlyphRun> glyph_run)
pub fn line_builder_cpp_108_line_builder_append_text_chunk() LayoutStub {
	return layout_stub('LineBuilder.cpp:108 LineBuilder::append_text_chunk')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:117
// Original signature: CSSPixels LineBuilder::y_for_float_to_be_inserted_here(Box const& box)
// Determine the current line width and subtract trailing whitespace, since those have not yet been removed while
// placing floating boxes.
// If there's already inline content on the current line, check if the new float can fit
// alongside the content. If not, place it on the next line.
// Then, look for the next Y position where we can fit the new float.
// New floats will always be placed vertically at or below the lowest float.
// This applies to all floats, so the last inserted float will always be the lowest.
pub fn line_builder_cpp_117_line_builder_y_for_float_to_be_inserted_here() LayoutStub {
	return layout_stub('LineBuilder.cpp:117 LineBuilder::y_for_float_to_be_inserted_here')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:182
// Original signature: bool LineBuilder::should_break(CSSPixels next_item_width)
// If we don't have a single line box yet *and* there are no floats intruding
// at this Y coordinate, we don't need to break before inserting anything.
pub fn line_builder_cpp_182_line_builder_should_break() LayoutStub {
	return layout_stub('LineBuilder.cpp:182 LineBuilder::should_break')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:200
// Original signature: void LineBuilder::update_last_line()
// FIXME: Respect inline direction.
// If (after justification, if any) the inline contents of a line box are too long to fit within it,
// then the contents are start-aligned: any content that doesn't fit overflows the line box's end edge.
// This should have been replaced before this point.
// The CSS specification calls this AD (A+D, Ascent + Descent).
// Remember the baseline used for this fragment. This will be used when painting the fragment.
// NOTE: For fragments with a <length> vertical-align, shift the line box baseline down by the length.
// This ensures that we make enough vertical space on the line for any manually-aligned fragments.
// Start with the "strut", an imaginary zero-width box at the start of each line box.
// Align the vertical midpoint of the box with the baseline of the parent box
// plus half the x-height of the parent.
// https://drafts.csswg.org/css-inline/#valdef-baseline-shift-sub
// Lower by the offset appropriate for subscripts of the parent's box.
// The UA may use the parent's font metrics to find this offset; otherwise it defaults to dropping by one fifth
// of the parent's used font-size.
// FIXME: Use font metrics to find a more appropriate offset, if possible
// https://drafts.csswg.org/css-inline/#valdef-baseline-shift-super
// Raise by the offset appropriate for superscripts of the parent's box.
// The UA may use the parent's font metrics to find this offset; otherwise it defaults to raising by one third of
// the parent's used font-size.
// FIXME: These are all 'baseline'
// FIXME: Support inline-table elements.
// 3. The line box height is the distance between the uppermost box top and the lowermost box bottom.
pub fn line_builder_cpp_200_line_builder_update_last_line() LayoutStub {
	return layout_stub('LineBuilder.cpp:200 LineBuilder::update_last_line')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:414
// Original signature: void LineBuilder::remove_last_line_if_empty()
// If there's an empty line box at the bottom, just remove it instead of giving it height.
pub fn line_builder_cpp_414_line_builder_remove_last_line_if_empty() LayoutStub {
	return layout_stub('LineBuilder.cpp:414 LineBuilder::remove_last_line_if_empty')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:424
// Original signature: void LineBuilder::recalculate_available_space()
pub fn line_builder_cpp_424_line_builder_recalculate_available_space() LayoutStub {
	return layout_stub('LineBuilder.cpp:424 LineBuilder::recalculate_available_space')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:434
// Original signature: void LineBuilder::did_introduce_clearance(CSSPixels clearance)
// If clearance was introduced but our current line box starts beyond it, we don't need to do anything.
// Increase the height of the previous line box so it matches the clearance, because the element's height is
// first
// determined by the bottom of the last line box (after trimming empty/whitespace boxes).
// The current line box will start directly after any cleared floats.
pub fn line_builder_cpp_434_line_builder_did_introduce_clearance() LayoutStub {
	return layout_stub('LineBuilder.cpp:434 LineBuilder::did_introduce_clearance')
}

// Translated from Libraries/LibWeb/Layout/LineBuilder.cpp:452
// Original signature: void LineBuilder::set_trailing_whitespace_on_previous_line()
// When a line breaks at whitespace, that whitespace is not added to any line. For text
// selection purposes, we record this on the last fragment of the previous line.
pub fn line_builder_cpp_452_line_builder_set_trailing_whitespace_on_previous_line() LayoutStub {
	return layout_stub('LineBuilder.cpp:452 LineBuilder::set_trailing_whitespace_on_previous_line')
}

// ---- InlineLevelIterator.h (15 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:20
// Original signature: InlineLevelIterator::AK_MAKE_NONCOPYABLE(InlineLevelIterator);
pub fn inline_level_iterator_h_20_inline_level_iterator_ak_make_noncopyable() LayoutStub {
	return layout_stub('InlineLevelIterator.h:20 InlineLevelIterator::AK_MAKE_NONCOPYABLE')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:21
// Original signature: InlineLevelIterator::AK_MAKE_NONMOVABLE(InlineLevelIterator);
pub fn inline_level_iterator_h_21_inline_level_iterator_ak_make_nonmovable() LayoutStub {
	return layout_stub('InlineLevelIterator.h:21 InlineLevelIterator::AK_MAKE_NONMOVABLE')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:53
// Original signature: InlineLevelIterator::InlineLevelIterator(Layout::InlineFormattingContext&, LayoutState&, Layout::BlockContainer const& containing_block, LayoutState::UsedValues const& containing_block_used_values, LayoutMode);
pub fn inline_level_iterator_h_53_inline_level_iterator_inline_level_iterator() LayoutStub {
	return layout_stub('InlineLevelIterator.h:53 InlineLevelIterator::InlineLevelIterator')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:55
// Original signature: InlineLevelIterator::Optional<Item> next();
pub fn inline_level_iterator_h_55_next() LayoutStub {
	return layout_stub('InlineLevelIterator.h:55 next')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:56
// Original signature: InlineLevelIterator::CSSPixels next_non_whitespace_sequence_width();
pub fn inline_level_iterator_h_56_next_non_whitespace_sequence_width() LayoutStub {
	return layout_stub('InlineLevelIterator.h:56 next_non_whitespace_sequence_width')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:59
// Original signature: InlineLevelIterator::void generate_all_items();
pub fn inline_level_iterator_h_59_generate_all_items() LayoutStub {
	return layout_stub('InlineLevelIterator.h:59 generate_all_items')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:60
// Original signature: InlineLevelIterator::Optional<Item> generate_next_item();
pub fn inline_level_iterator_h_60_generate_next_item() LayoutStub {
	return layout_stub('InlineLevelIterator.h:60 generate_next_item')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:61
// Original signature: InlineLevelIterator::Gfx::GlyphRun::TextType resolve_text_direction_from_context();
pub fn inline_level_iterator_h_61_resolve_text_direction_from_context() LayoutStub {
	return layout_stub('InlineLevelIterator.h:61 resolve_text_direction_from_context')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:62
// Original signature: InlineLevelIterator::void skip_to_next();
pub fn inline_level_iterator_h_62_skip_to_next() LayoutStub {
	return layout_stub('InlineLevelIterator.h:62 skip_to_next')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:63
// Original signature: InlineLevelIterator::void compute_next();
pub fn inline_level_iterator_h_63_compute_next() LayoutStub {
	return layout_stub('InlineLevelIterator.h:63 compute_next')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:65
// Original signature: InlineLevelIterator::void enter_text_node(Layout::TextNode const&);
pub fn inline_level_iterator_h_65_enter_text_node() LayoutStub {
	return layout_stub('InlineLevelIterator.h:65 enter_text_node')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:67
// Original signature: InlineLevelIterator::void enter_node_with_box_model_metrics(Layout::NodeWithStyleAndBoxModelMetrics const&);
pub fn inline_level_iterator_h_67_enter_node_with_box_model_metrics() LayoutStub {
	return layout_stub('InlineLevelIterator.h:67 enter_node_with_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:68
// Original signature: InlineLevelIterator::void exit_node_with_box_model_metrics();
pub fn inline_level_iterator_h_68_exit_node_with_box_model_metrics() LayoutStub {
	return layout_stub('InlineLevelIterator.h:68 exit_node_with_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:70
// Original signature: InlineLevelIterator::void add_extra_box_model_metrics_to_item(Item&, bool add_leading_metrics, bool add_trailing_metrics);
pub fn inline_level_iterator_h_70_add_extra_box_model_metrics_to_item() LayoutStub {
	return layout_stub('InlineLevelIterator.h:70 add_extra_box_model_metrics_to_item')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.h:72
// Original signature: InlineLevelIterator::Layout::Node const* next_inline_node_in_pre_order(Layout::Node const& current, Layout::Node const* stay_within);
pub fn inline_level_iterator_h_72_next_inline_node_in_pre_order() LayoutStub {
	return layout_stub('InlineLevelIterator.h:72 next_inline_node_in_pre_order')
}

// ---- InlineLevelIterator.cpp (13 translated function stubs) ----

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:18
// Original signature: InlineLevelIterator::InlineLevelIterator(Layout::InlineFormattingContext& inline_formatting_context, Layout::LayoutState& layout_state, Layout::BlockContainer const& containing_block, LayoutState::UsedValues const& containing_block_used_values, LayoutMode layout_mode) : m_inline_formatting_context(inline_formatting_context) , m_layout_state(layout_state) , m_containing_block(containing_block) , m_containing_block_used_values(containing_block_used_values) , m_next_node(containing_block.first_child()) , m_layout_mode(layout_mode)
pub fn inline_level_iterator_cpp_18_inline_level_iterator_inline_level_iterator() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:18 InlineLevelIterator::InlineLevelIterator')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:30
// Original signature: void InlineLevelIterator::generate_all_items()
// Track accumulated width for tab calculations.
// Reset on forced breaks since tabs measure from line start.
pub fn inline_level_iterator_cpp_30_inline_level_iterator_generate_all_items() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:30 InlineLevelIterator::generate_all_items')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:49
// Original signature: void InlineLevelIterator::enter_node_with_box_model_metrics(Layout::NodeWithStyleAndBoxModelMetrics const& node)
// FIXME: It's really weird that *this* is where we assign box model metrics for these layout nodes..
// Now's our chance to resolve the inset properties for this node.
pub fn inline_level_iterator_cpp_49_inline_level_iterator_enter_node_with_box_model_metrics() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:49 InlineLevelIterator::enter_node_with_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:85
// Original signature: void InlineLevelIterator::exit_node_with_box_model_metrics()
pub fn inline_level_iterator_cpp_85_inline_level_iterator_exit_node_with_box_model_metrics() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:85 InlineLevelIterator::exit_node_with_box_model_metrics')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:101
// Original signature: Layout::Node const* InlineLevelIterator::next_inline_node_in_pre_order(Layout::Node const& current, Layout::Node const* stay_within)
// This is similar to Layout::Node::next_in_pre_order() but will not descend into inline-block nodes.
// If node is the last node on the "box model node stack", pop it off.
pub fn inline_level_iterator_cpp_101_inline_level_iterator_next_inline_node_in_pre_order() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:101 InlineLevelIterator::next_inline_node_in_pre_order')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:134
// Original signature: void InlineLevelIterator::compute_next()
// NOTE: It is possible to encounter SVGMaskBox nodes while doing layout of formatting context established by
// <foreignObject> with a mask.
// We should skip and let SVGFormattingContext take care of them.
pub fn inline_level_iterator_cpp_134_inline_level_iterator_compute_next() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:134 InlineLevelIterator::compute_next')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:148
// Original signature: void InlineLevelIterator::skip_to_next()
pub fn inline_level_iterator_cpp_148_inline_level_iterator_skip_to_next() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:148 InlineLevelIterator::skip_to_next')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:161
// Original signature: Optional<InlineLevelIterator::Item> InlineLevelIterator::next()
pub fn inline_level_iterator_cpp_161_inline_level_iterator_next() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:161 InlineLevelIterator::next')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:168
// Original signature: CSSPixels InlineLevelIterator::next_non_whitespace_sequence_width()
pub fn inline_level_iterator_cpp_168_inline_level_iterator_next_non_whitespace_sequence_width() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:168 InlineLevelIterator::next_non_whitespace_sequence_width')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:190
// Original signature: Gfx::GlyphRun::TextType InlineLevelIterator::resolve_text_direction_from_context()
// Search forward in the pre-generated chunks array to find the next chunk with known direction.
// Since chunks are pre-generated, this is just O(1) array access per iteration.
pub fn inline_level_iterator_cpp_190_inline_level_iterator_resolve_text_direction_from_context() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:190 InlineLevelIterator::resolve_text_direction_from_context')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:224
// Original signature: Optional<InlineLevelIterator::Item> InlineLevelIterator::generate_next_item()
// Track chunk position locally
// Get the next chunk from the pre-generated array
// Create an empty chunk for editable empty text fields
// Advance the index so the next call will move to the next node
// FIXME: We should apply word spacing to all word-separator characters not just breaking tabs
// Use the accumulated width we've been tracking during pre-generation.
// This accounts for items that would appear before this tab on the same line.
// https://drafts.csswg.org/css-text/#tab-size-property
// https://drafts.csswg.org/css-text/#white-space-phase-2
// if fragments have added to the width, calculate the net distance to the next tab stop, otherwise the shift
// will just be the tab width
// If this distance is less than 0.5ch, then the subsequent tab stop is used instead
// account for consecutive tabs
// remove tabs, we don't want to render them when we shape the text
// NOTE: We never consider `content: ""` to be collapsible whitespace.
pub fn inline_level_iterator_cpp_224_inline_level_iterator_generate_next_item() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:224 InlineLevelIterator::generate_next_item')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:417
// Original signature: void InlineLevelIterator::enter_text_node(Layout::TextNode const& text_node)
// https://drafts.csswg.org/css-text-4/#collapse
// Pre-generate all chunks for this text node upfront.
// This allows O(1) peek() and next() operations instead of lazy generation with O(n) queue operations.
pub fn inline_level_iterator_cpp_417_inline_level_iterator_enter_text_node() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:417 InlineLevelIterator::enter_text_node')
}

// Translated from Libraries/LibWeb/Layout/InlineLevelIterator.cpp:446
// Original signature: void InlineLevelIterator::add_extra_box_model_metrics_to_item(Item& item, bool add_leading_metrics, bool add_trailing_metrics)
pub fn inline_level_iterator_cpp_446_inline_level_iterator_add_extra_box_model_metrics_to_item() LayoutStub {
	return layout_stub('InlineLevelIterator.cpp:446 InlineLevelIterator::add_extra_box_model_metrics_to_item')
}
