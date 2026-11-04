module css

import dom
import platform

// The raw property graph is sufficient until Layout materializes its resolved
// values. Keep the wide layout-only cache off ordinary/pseudo style records.
@[heap]
struct ComputedLayoutCache {
mut:
	resolved_edge_memo_                            ResolvedBoxEdgeMemo
	computed_values_display_                       Display = Display.new()
	computed_values_display_before_transformation_ Display = Display.new()
	computed_values_position_                      Positioning
	computed_values_position_anchor_               ?string
	computed_values_float_                         Float
	computed_values_clear_                         Clear
	computed_values_direction_                     Direction
	computed_values_writing_mode_                  WritingMode
	computed_values_overflow_x_                    Overflow
	computed_values_overflow_y_                    Overflow
	computed_values_font_size_                     CSSPixels
	computed_values_font_weight_                   f64
	computed_values_font_language_override_        ?string
	computed_values_caret_color_                   Color = Color{0, 0, 0, 255}
	computed_values_color_                         Color = Color{0, 0, 0, 255}
	computed_values_accent_color_                  ?Color
	computed_values_color_scheme_                  PreferredColorScheme
	computed_values_width_                         Size
	computed_values_min_width_                     Size
	computed_values_max_width_                     Size
	computed_values_height_                        Size
	computed_values_min_height_                    Size
	computed_values_max_height_                    Size
	computed_values_inset_                         LengthBox
	computed_values_margin_                        LengthBox
	computed_values_padding_                       LengthBox
	computed_values_overflow_clip_margin_          LengthBox
	computed_values_border_left_                   BorderData
	computed_values_border_top_                    BorderData
	computed_values_border_right_                  BorderData
	computed_values_border_bottom_                 BorderData
	computed_values_has_noninitial_border_radii_   bool
	computed_values_border_bottom_left_radius_     BorderRadiusData
	computed_values_border_bottom_right_radius_    BorderRadiusData
	computed_values_border_top_left_radius_        BorderRadiusData
	computed_values_border_top_right_radius_       BorderRadiusData
	computed_values_flex_direction_                FlexDirection
	computed_values_flex_wrap_                     FlexWrap
	computed_values_flex_basis_                    FlexBasis
	computed_values_flex_grow_                     f32
	computed_values_flex_shrink_                   f32
	computed_values_order_                         int
	computed_values_align_content_                 AlignContent
	computed_values_align_items_                   AlignItems
	computed_values_align_self_                    AlignSelf
	computed_values_justify_content_               JustifyContent
	computed_values_justify_items_                 JustifyItems
	computed_values_justify_self_                  JustifySelf
	computed_values_text_align_                    TextAlign
	computed_values_text_justify_                  TextJustify
	computed_values_text_transform_                TextTransform
	computed_values_text_wrap_mode_                TextWrapMode
	computed_values_white_space_collapse_          WhiteSpaceCollapse
	computed_values_word_break_                    WordBreak
	computed_values_hyphens_                       Hyphens
	computed_values_visibility_                    Visibility
	computed_values_box_sizing_                    BoxSizing
	computed_values_vertical_align_                VerticalAlign
	computed_values_caption_side_                  CaptionSide
	computed_values_content_visibility_            ContentVisibility
	computed_values_user_select_                   UserSelect
	computed_values_table_layout_                  TableLayout
	computed_values_border_collapse_               BorderCollapse
	computed_values_contain_                       Containment
	computed_values_aspect_ratio_                  AspectRatio
	computed_values_column_gap_                    GapValue
	computed_values_row_gap_                       GapValue
	computed_values_grid_auto_columns_             GridTrackSizeList
	computed_values_grid_auto_rows_                GridTrackSizeList
	computed_values_grid_auto_flow_                GridAutoFlow
	computed_values_appearance_                    Appearance
	computed_values_opacity_                       f32
	computed_values_z_index_                       ?int
	computed_values_image_rendering_               ImageRendering
	computed_values_pointer_events_                PointerEvents
	computed_values_list_style_position_           ListStylePosition
	computed_values_grid_column_end_               GridTrackPlacement
	computed_values_grid_column_start_             GridTrackPlacement
	computed_values_grid_row_end_                  GridTrackPlacement
	computed_values_grid_row_start_                GridTrackPlacement
	computed_values_column_span_                   ColumnSpan
	computed_values_break_after_                   BreakBetween
	computed_values_break_before_                  BreakBetween
	computed_values_break_inside_                  BreakInside
	computed_values_box_decoration_break_          BoxDecorationBreak
	computed_values_column_fill_                   ColumnFill
	computed_values_block_ellipsis_                BlockEllipsis
	computed_values_continue_                      ContinueValue
	computed_values_max_lines_                     ?int
	computed_values_webkit_box_orient_             WebkitBoxOrient
	computed_values_empty_cells_                   EmptyCells
	computed_values_object_fit_                    ObjectFit
	computed_values_object_position_               Position
	computed_values_unicode_bidi_                  UnicodeBidi
	computed_values_isolation_                     Isolation
	computed_values_mix_blend_mode_                MixBlendMode
	computed_values_mask_type_                     MaskType
	computed_values_stop_opacity_                  f32
	computed_values_fill_opacity_                  f32
	computed_values_stroke_linecap_                StrokeLinecap
	computed_values_stroke_linejoin_               StrokeLinejoin
	computed_values_stroke_miterlimit_             f64
	computed_values_stroke_opacity_                f32
	computed_values_fill_rule_                     FillRule
	computed_values_clip_rule_                     ClipRule
	computed_values_shape_rendering_               ShapeRendering
	computed_values_text_anchor_                   TextAnchor
	computed_values_outline_offset_                Length
	computed_values_outline_style_                 OutlineStyle
	computed_values_scrollbar_width_               ScrollbarWidth
	computed_values_resize_                        Resize
	computed_values_border_spacing_horizontal_     Length
	computed_values_border_spacing_vertical_       Length
	computed_values_color_interpolation_           ColorInterpolation
	computed_values_color_interpolation_filters_   ColorInterpolation = .srgb_linear
	computed_values_clip_                          Clip
	computed_values_cursor_                        []CursorData
	computed_values_background_color_clip_         BackgroundBox
	computed_values_background_color_              Color
	computed_values_background_layers_             []BackgroundLayerData
	computed_values_tab_size_                      TabSize
	computed_values_text_decoration_line_          []TextDecorationLine
	computed_values_text_decoration_skip_ink_      TextDecorationSkipInk
	computed_values_text_decoration_thickness_     TextDecorationThickness
	computed_values_text_decoration_style_         TextDecorationStyle
	computed_values_text_decoration_color_         Color = Color{0, 0, 0, 255}
	computed_values_text_indent_                   TextIndentData
	computed_values_text_overflow_                 TextOverflow
	computed_values_text_underline_offset_         CSSPixels
	computed_values_text_underline_position_       TextUnderlinePosition
	computed_values_white_space_trim_              WhiteSpaceTrimData
	computed_values_word_spacing_                  CSSPixels
	computed_values_letter_spacing_                CSSPixels
	computed_values_backface_visibility_           BackfaceVisibility
	computed_values_quotes_                        QuotesData
	computed_values_dominant_baseline_             ?BaselineMetric
	computed_values_container_name_                []string
	computed_values_container_type_                ContainerType
	computed_values_view_transition_name_          ?string
	computed_values_touch_action_                  TouchActionData
	computed_values_stroke_dasharray_              []StrokeDasharrayItem
	computed_values_flood_opacity_                 f32
	computed_values_paint_order_                   PaintOrderList
	computed_values_math_shift_                    MathShift
	computed_values_math_style_                    MathStyle
	computed_values_math_depth_                    int
	computed_values_will_change_                   WillChange
	computed_values_stroke_dashoffset_             LengthPercentage
	computed_values_stroke_width_                  LengthPercentage
	computed_values_rx_                            LengthPercentageOrAuto
	computed_values_ry_                            LengthPercentageOrAuto
	computed_values_column_count_                  ?int
	computed_values_column_width_                  Size
	computed_values_column_height_                 Size
	computed_values_column_rule_color_             Color = Color{0, 0, 0, 255}
	computed_values_column_rule_style_             LineStyle
	computed_values_column_rule_width_             CSSPixels
	computed_values_outline_width_                 CSSPixels
	computed_values_transition_delay_              Time
	computed_values_webkit_text_fill_color_        Color = Color{0, 0, 0, 255}
	computed_values_stop_color_                    Color = Color{0, 0, 0, 255}
	computed_values_flood_color_                   Color = Color{0, 0, 0, 255}
	computed_values_outline_color_                 Color = Color{0, 0, 0, 255}
	// Explicit absence avoids constructing unused paint owners in the old compiler.
	computed_values_fill_                          ?SVGPaint = ?SVGPaint(none)
	computed_values_stroke_                        ?SVGPaint = ?SVGPaint(none)
	computed_values_text_shadow_                   []ShadowData
	computed_values_box_shadow_                    []ShadowData
	computed_values_scrollbar_color_               ScrollbarColorData
	computed_values_counter_increment_             []CounterData
	computed_values_counter_reset_                 []CounterData
	computed_values_counter_set_                   []CounterData
	rare_data_ &ComputedLayoutRareData = unsafe { nil }
	rare_data_writable_ bool
	resolution_provenance &ComputedGeometryProvenance = unsafe { nil }
	layout_coordinate_scale_ f64 = 1.0
	document_resolution_owner &dom.Document = unsafe { nil }
	writable_owner_identity                        u64
	// The style that created this snapshot, by address and serial number (an
	// address alone can be reused by a later style). Readers reach a snapshot
	// only through its style, so its creator may overwrite it in place.
	owner_identity u64
	owner_serial   u64
}

__global css_layout_cache_owner_serials u64

fn (mut c ComputedProperties) layout_cache_owner_serial() u64 {
	if c.layout_cache_owner_serial_ == 0 {
		css_layout_cache_owner_serials++
		c.layout_cache_owner_serial_ = css_layout_cache_owner_serials
	}
	return c.layout_cache_owner_serial_
}

// Restyling an animation target re-resolves the same style on every frame.
// Only that resolve rewrites the style's own snapshot in place; every other
// write keeps copy-on-write, so a snapshot that a value copy of the style may
// share is never changed under it.
__global css_layout_cache_reuse_style = unsafe { voidptr(0) }

fn begin_layout_cache_reuse(style &ComputedProperties) voidptr {
	previous := css_layout_cache_reuse_style
	css_layout_cache_reuse_style = voidptr(style)
	return previous
}

fn end_layout_cache_reuse(previous voidptr) {
	css_layout_cache_reuse_style = previous
}

fn (c &ComputedProperties) reuses_computed_layout_cache(identity u64) bool {
	return voidptr(c) == css_layout_cache_reuse_style && c.owns_computed_layout_cache(identity)
}

fn (c &ComputedProperties) owns_computed_layout_cache(identity u64) bool {
	cache := c.computed_layout_cache_
	return cache != unsafe { nil } && cache.owner_identity == identity && cache.owner_serial != 0
		&& cache.owner_serial == c.layout_cache_owner_serial_
}

__global (
	initial_computed_layout_cache &ComputedLayoutCache
)

fn default_computed_layout_cache() &ComputedLayoutCache {
	if initial_computed_layout_cache == unsafe { nil } {
		persistent := platform.enter_persistent()
		initial_computed_layout_cache = &ComputedLayoutCache{}
		platform.leave_persistent(persistent)
	}
	return initial_computed_layout_cache
}

fn (c &ComputedProperties) computed_layout_cache() &ComputedLayoutCache {
	if c.computed_layout_cache_ != unsafe { nil } { return c.computed_layout_cache_ }
	return default_computed_layout_cache()
}

// A snapshot is copied before its first write, except while an animation
// frame restyles the style that created it (begin_layout_cache_reuse): every
// frame then reuses one snapshot instead of allocating another.
fn (mut c ComputedProperties) ensure_computed_layout_cache() &ComputedLayoutCache {
	identity := u64(voidptr(c))
	if c.computed_layout_cache_ != unsafe { nil }
		&& (c.computed_layout_cache_.writable_owner_identity == identity
		|| c.reuses_computed_layout_cache(identity)) {
		c.computed_layout_cache_.resolution_provenance = unsafe { nil }
		return c.computed_layout_cache_
	}
	// Document storage owns the style and its resolved snapshot. Temporary
	// animation/layout scopes must still keep this snapshot outside themselves.
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	previous := c.computed_layout_cache()
	c.computed_layout_cache_ = &ComputedLayoutCache{
		...previous
		resolution_provenance: unsafe { nil }
		rare_data_writable_: false
		writable_owner_identity: 0
		owner_identity: identity
		owner_serial: c.layout_cache_owner_serial()
	}
	return c.computed_layout_cache_
}

// Copying a style shares its snapshot. Neither style then overwrites it in
// place: the next write by either takes a copy, as before reuse existed.
fn (c &ComputedProperties) share_computed_layout_cache() {
	if c.computed_layout_cache_ != unsafe { nil } {
		unsafe {
			c.computed_layout_cache_.owner_serial = 0
		}
	}
}

fn (mut c ComputedProperties) begin_computed_layout_cache_write() bool {
	identity := u64(voidptr(c))
	if c.computed_layout_cache_ != unsafe { nil }
		&& c.computed_layout_cache_.writable_owner_identity == identity {
		return false
	}
	if c.reuses_computed_layout_cache(identity) {
		c.computed_layout_cache_.writable_owner_identity = identity
		return true
	}
	persistent := platform.enter_persistent_if(platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent) }
	previous := c.computed_layout_cache()
	c.computed_layout_cache_ = &ComputedLayoutCache{
		...previous
		rare_data_writable_: false
		writable_owner_identity: identity
		owner_identity: identity
		owner_serial: c.layout_cache_owner_serial()
	}
	return true
}

fn (mut c ComputedProperties) finish_computed_layout_cache_write(owns_scope bool) {
	if owns_scope {
		c.computed_layout_cache_.writable_owner_identity = 0
		c.computed_layout_cache_.rare_data_writable_ = false
	}
}
