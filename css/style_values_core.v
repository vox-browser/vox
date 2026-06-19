// Translated from core LibWeb/CSS StyleValue and Typed OM classes.
module css

import dom
import math

// --- Small local stubs for parser/JS/WebIDL-only pieces ---

pub struct CalculationContext {
pub mut:
	property PropertyNameAndID
}

pub fn CalculationContext.for_property(property PropertyNameAndID) CalculationContext {
	return CalculationContext{
		property: property
	}
}

pub struct CalculationNode {
pub mut:
	serialization string
}

pub fn Color.black() Color {
	return Color.rgb(0, 0, 0)
}

pub fn (c Color) red() u8 {
	return c.r
}

pub fn (c Color) green() u8 {
	return c.g
}

pub fn (c Color) blue() u8 {
	return c.b
}

pub fn (c Color) alpha() u8 {
	return c.a
}

pub fn (c Color) luminosity() u8 {
	return u8(int(math.round(f64(c.red()) * 0.2126 + f64(c.green()) * 0.7152 +
		f64(c.blue()) * 0.0722)))
}

pub fn (c Color) contrast_ratio(other Color) f64 {
	l1 := c.luminosity()
	l2 := other.luminosity()
	darkest := f64(if l1 < l2 { l1 } else { l2 }) / 255.0
	brightest := f64(if l1 > l2 { l1 } else { l2 }) / 255.0
	return (brightest + 0.05) / (darkest + 0.05)
}

pub fn (c Color) darkened(amount f64) Color {
	return Color.rgba(u8(int(f64(c.red()) * amount)), u8(int(f64(c.green()) * amount)),
		u8(int(f64(c.blue()) * amount)), c.alpha())
}

pub fn (c Color) inverted() Color {
	return Color.rgba(~c.red(), ~c.green(), ~c.blue(), c.alpha())
}

pub fn (c Color) serialize() string {
	if c.a == 255 {
		return 'rgb(${c.r} ${c.g} ${c.b})'
	}
	return 'rgb(${c.r} ${c.g} ${c.b} / ${serialize_a_number(f64(c.a) / 255.0)})'
}

pub struct ComputationContext {
pub mut:
	length_resolution_context LengthResolutionContext = LengthResolutionContext.default()
	color_scheme              ?PreferredColorScheme
	abstract_element          ?&dom.AbstractElement
}

pub enum PerformTypeCheck {
	no
	yes
}

pub struct PropertyNameAndID {
pub mut:
	name_      string
	id_        ?PropertyID
	is_custom_ bool
}

pub fn PropertyNameAndID.from_name(name string) ?PropertyNameAndID {
	lowercase_name := to_ascii_lowercase(name)
	if is_a_custom_property_name_string(name) {
		return PropertyNameAndID{
			name_:      name
			is_custom_: true
		}
	}
	property_id := match lowercase_name {
		'accent-color' {
			PropertyID.accent_color
		}
		'anchor-name' {
			PropertyID.anchor_name
		}
		'anchor-scope' {
			PropertyID.anchor_scope
		}
		'align-content', '-webkit-align-content' {
			PropertyID.align_content
		}
		'align-items', '-webkit-align-items', '-webkit-box-align' {
			PropertyID.align_items
		}
		'align-self', '-webkit-align-self' {
			PropertyID.align_self
		}
		'animation-composition' {
			PropertyID.animation_composition
		}
		'animation-delay', '-webkit-animation-delay' {
			PropertyID.animation_delay
		}
		'animation-direction', '-webkit-animation-direction' {
			PropertyID.animation_direction
		}
		'animation-duration', '-webkit-animation-duration' {
			PropertyID.animation_duration
		}
		'animation-fill-mode', '-webkit-animation-fill-mode' {
			PropertyID.animation_fill_mode
		}
		'animation-iteration-count', '-webkit-animation-iteration-count' {
			PropertyID.animation_iteration_count
		}
		'animation-name' {
			PropertyID.animation_name
		}
		'-webkit-animation-name' {
			PropertyID.animation_name
		}
		'animation-play-state', '-webkit-animation-play-state' {
			PropertyID.animation_play_state
		}
		'animation-timeline' {
			PropertyID.animation_timeline
		}
		'animation-timing-function', '-webkit-animation-timing-function' {
			PropertyID.animation_timing_function
		}
		'aspect-ratio' {
			PropertyID.aspect_ratio
		}
		'appearance', '-moz-appearance', '-webkit-appearance' {
			PropertyID.appearance
		}
		'background-color' {
			PropertyID.background_color
		}
		'background-attachment' {
			PropertyID.background_attachment
		}
		'background-blend-mode' {
			PropertyID.background_blend_mode
		}
		'background-clip' {
			PropertyID.background_clip
		}
		'background-image' {
			PropertyID.background_image
		}
		'background-origin' {
			PropertyID.background_origin
		}
		'background-position-x' {
			PropertyID.background_position_x
		}
		'background-position-y' {
			PropertyID.background_position_y
		}
		'background-repeat' {
			PropertyID.background_repeat
		}
		'background-size' {
			PropertyID.background_size
		}
		'block-size' {
			PropertyID.block_size
		}
		'bottom' {
			PropertyID.bottom
		}
		'border-bottom-color' {
			PropertyID.border_bottom_color
		}
		'border-bottom-width' {
			PropertyID.border_bottom_width
		}
		'border-bottom-style' {
			PropertyID.border_bottom_style
		}
		'border-bottom-left-radius' {
			PropertyID.border_bottom_left_radius
		}
		'border-bottom-right-radius' {
			PropertyID.border_bottom_right_radius
		}
		'border-block-end-color' {
			PropertyID.border_block_end_color
		}
		'border-block-end-style' {
			PropertyID.border_block_end_style
		}
		'border-block-end-width' {
			PropertyID.border_block_end_width
		}
		'border-block-start-color' {
			PropertyID.border_block_start_color
		}
		'border-block-start-style' {
			PropertyID.border_block_start_style
		}
		'border-block-start-width' {
			PropertyID.border_block_start_width
		}
		'border-end-end-radius' {
			PropertyID.border_end_end_radius
		}
		'border-end-start-radius' {
			PropertyID.border_end_start_radius
		}
		'border-left-color' {
			PropertyID.border_left_color
		}
		'border-left-width' {
			PropertyID.border_left_width
		}
		'border-left-style' {
			PropertyID.border_left_style
		}
		'border-inline-end-color' {
			PropertyID.border_inline_end_color
		}
		'border-inline-end-style' {
			PropertyID.border_inline_end_style
		}
		'border-inline-end-width' {
			PropertyID.border_inline_end_width
		}
		'border-inline-start-color' {
			PropertyID.border_inline_start_color
		}
		'border-inline-start-style' {
			PropertyID.border_inline_start_style
		}
		'border-inline-start-width' {
			PropertyID.border_inline_start_width
		}
		'border-right-color' {
			PropertyID.border_right_color
		}
		'border-right-width' {
			PropertyID.border_right_width
		}
		'border-right-style' {
			PropertyID.border_right_style
		}
		'border-top-color' {
			PropertyID.border_top_color
		}
		'border-top-width' {
			PropertyID.border_top_width
		}
		'border-top-style' {
			PropertyID.border_top_style
		}
		'border-top-left-radius' {
			PropertyID.border_top_left_radius
		}
		'border-top-right-radius' {
			PropertyID.border_top_right_radius
		}
		'border-start-end-radius' {
			PropertyID.border_start_end_radius
		}
		'border-start-start-radius' {
			PropertyID.border_start_start_radius
		}
		'border-image-outset' {
			PropertyID.border_image_outset
		}
		'border-image-repeat' {
			PropertyID.border_image_repeat
		}
		'border-image-slice' {
			PropertyID.border_image_slice
		}
		'border-image-source' {
			PropertyID.border_image_source
		}
		'border-image-width' {
			PropertyID.border_image_width
		}
		'border-spacing' {
			PropertyID.border_spacing
		}
		'border-collapse' {
			PropertyID.border_collapse
		}
		'box-sizing' {
			PropertyID.box_sizing
		}
		'caption-side' {
			PropertyID.caption_side
		}
		'caret-color' {
			PropertyID.caret_color
		}
		'clear' {
			PropertyID.clear
		}
		'clip-rule' {
			PropertyID.clip_rule
		}
		'color' {
			PropertyID.color
		}
		'color-interpolation' {
			PropertyID.color_interpolation
		}
		'color-scheme' {
			PropertyID.color_scheme
		}
		'content-visibility' {
			PropertyID.content_visibility
		}
		'contain' {
			PropertyID.contain
		}
		'container-type' {
			PropertyID.container_type
		}
		'column-span' {
			PropertyID.column_span
		}
		'column-count' {
			PropertyID.column_count
		}
		'column-width' {
			PropertyID.column_width
		}
		'column-height' {
			PropertyID.column_height
		}
		'column-gap' {
			PropertyID.column_gap
		}
		'row-gap' {
			PropertyID.row_gap
		}
		'direction' {
			PropertyID.direction
		}
		'empty-cells' {
			PropertyID.empty_cells
		}
		'corner-bottom-left-shape' {
			PropertyID.corner_bottom_left_shape
		}
		'corner-bottom-right-shape' {
			PropertyID.corner_bottom_right_shape
		}
		'corner-end-end-shape' {
			PropertyID.corner_end_end_shape
		}
		'corner-end-start-shape' {
			PropertyID.corner_end_start_shape
		}
		'corner-start-end-shape' {
			PropertyID.corner_start_end_shape
		}
		'corner-start-start-shape' {
			PropertyID.corner_start_start_shape
		}
		'corner-top-left-shape' {
			PropertyID.corner_top_left_shape
		}
		'corner-top-right-shape' {
			PropertyID.corner_top_right_shape
		}
		'fill-opacity' {
			PropertyID.fill_opacity
		}
		'fill-rule' {
			PropertyID.fill_rule
		}
		'flood-color' {
			PropertyID.flood_color
		}
		'flood-opacity' {
			PropertyID.flood_opacity
		}
		'float' {
			PropertyID.float_
		}
		'font-feature-settings' {
			PropertyID.font_feature_settings
		}
		'font-kerning' {
			PropertyID.font_kerning
		}
		'font-language-override' {
			PropertyID.font_language_override
		}
		'font-optical-sizing' {
			PropertyID.font_optical_sizing
		}
		'font-style' {
			PropertyID.font_style
		}
		'font-variant-caps' {
			PropertyID.font_variant_caps
		}
		'font-variant-emoji' {
			PropertyID.font_variant_emoji
		}
		'font-variant-position' {
			PropertyID.font_variant_position
		}
		'font-variation-settings' {
			PropertyID.font_variation_settings
		}
		'font-weight' {
			PropertyID.font_weight
		}
		'font-width' {
			PropertyID.font_width
		}
		'height' {
			PropertyID.height
		}
		'flex-grow', '-webkit-box-flex', '-webkit-flex-grow' {
			PropertyID.flex_grow
		}
		'flex-shrink', '-webkit-flex-shrink' {
			PropertyID.flex_shrink
		}
		'flex-direction', '-webkit-flex-direction', '-webkit-box-orient' {
			PropertyID.flex_direction
		}
		'flex-wrap', '-webkit-flex-wrap' {
			PropertyID.flex_wrap
		}
		'image-rendering' {
			PropertyID.image_rendering
		}
		'inline-size' {
			PropertyID.inline_size
		}
		'inset-block-end' {
			PropertyID.inset_block_end
		}
		'inset-block-start' {
			PropertyID.inset_block_start
		}
		'inset-inline-end' {
			PropertyID.inset_inline_end
		}
		'inset-inline-start' {
			PropertyID.inset_inline_start
		}
		'isolation' {
			PropertyID.isolation
		}
		'left' {
			PropertyID.left
		}
		'justify-content', '-webkit-justify-content', '-webkit-box-pack' {
			PropertyID.justify_content
		}
		'justify-items' {
			PropertyID.justify_items
		}
		'justify-self' {
			PropertyID.justify_self
		}
		'letter-spacing' {
			PropertyID.letter_spacing
		}
		'line-height' {
			PropertyID.line_height
		}
		'list-style-position' {
			PropertyID.list_style_position
		}
		'list-style-image' {
			PropertyID.list_style_image
		}
		'math-shift' {
			PropertyID.math_shift
		}
		'mask-composite', '-webkit-mask-composite' {
			PropertyID.mask_composite
		}
		'mask-clip' {
			PropertyID.mask_clip
		}
		'mask-image' {
			PropertyID.mask_image
		}
		'mask-mode' {
			PropertyID.mask_mode
		}
		'mask-origin', '-webkit-mask-origin' {
			PropertyID.mask_origin
		}
		'mask-position' {
			PropertyID.mask_position
		}
		'mask-repeat' {
			PropertyID.mask_repeat
		}
		'mask-size' {
			PropertyID.mask_size
		}
		'margin-block-end' {
			PropertyID.margin_block_end
		}
		'margin-block-start' {
			PropertyID.margin_block_start
		}
		'margin-bottom' {
			PropertyID.margin_bottom
		}
		'margin-inline-end' {
			PropertyID.margin_inline_end
		}
		'margin-inline-start' {
			PropertyID.margin_inline_start
		}
		'margin-left' {
			PropertyID.margin_left
		}
		'margin-right' {
			PropertyID.margin_right
		}
		'margin-top' {
			PropertyID.margin_top
		}
		'mask-type' {
			PropertyID.mask_type
		}
		'math-depth' {
			PropertyID.math_depth
		}
		'math-style' {
			PropertyID.math_style
		}
		'max-block-size' {
			PropertyID.max_block_size
		}
		'max-height' {
			PropertyID.max_height
		}
		'max-inline-size' {
			PropertyID.max_inline_size
		}
		'max-width' {
			PropertyID.max_width
		}
		'min-block-size' {
			PropertyID.min_block_size
		}
		'min-height' {
			PropertyID.min_height
		}
		'min-inline-size' {
			PropertyID.min_inline_size
		}
		'min-width' {
			PropertyID.min_width
		}
		'mix-blend-mode' {
			PropertyID.mix_blend_mode
		}
		'object-fit' {
			PropertyID.object_fit
		}
		'object-position' {
			PropertyID.object_position
		}
		'opacity' {
			PropertyID.opacity
		}
		'order' {
			PropertyID.order
		}
		'orphans' {
			PropertyID.orphans
		}
		'outline-color' {
			PropertyID.outline_color
		}
		'outline-offset' {
			PropertyID.outline_offset
		}
		'outline-style' {
			PropertyID.outline_style
		}
		'outline-width' {
			PropertyID.outline_width
		}
		'overflow-x' {
			PropertyID.overflow_x
		}
		'overflow-y' {
			PropertyID.overflow_y
		}
		'overflow-block' {
			PropertyID.overflow_block
		}
		'overflow-clip-margin-block-end' {
			PropertyID.overflow_clip_margin_block_end
		}
		'overflow-clip-margin-block-start' {
			PropertyID.overflow_clip_margin_block_start
		}
		'overflow-clip-margin-bottom' {
			PropertyID.overflow_clip_margin_bottom
		}
		'overflow-clip-margin-inline-end' {
			PropertyID.overflow_clip_margin_inline_end
		}
		'overflow-clip-margin-inline-start' {
			PropertyID.overflow_clip_margin_inline_start
		}
		'overflow-clip-margin-left' {
			PropertyID.overflow_clip_margin_left
		}
		'overflow-clip-margin-right' {
			PropertyID.overflow_clip_margin_right
		}
		'overflow-clip-margin-top' {
			PropertyID.overflow_clip_margin_top
		}
		'overflow-inline' {
			PropertyID.overflow_inline
		}
		'overflow-wrap', 'word-wrap' {
			PropertyID.overflow_wrap
		}
		'paint-order' {
			PropertyID.paint_order
		}
		'perspective' {
			PropertyID.perspective
		}
		'perspective-origin' {
			PropertyID.perspective_origin
		}
		'padding-block-end' {
			PropertyID.padding_block_end
		}
		'padding-block-start' {
			PropertyID.padding_block_start
		}
		'padding-bottom' {
			PropertyID.padding_bottom
		}
		'padding-inline-end' {
			PropertyID.padding_inline_end
		}
		'padding-inline-start' {
			PropertyID.padding_inline_start
		}
		'padding-left' {
			PropertyID.padding_left
		}
		'padding-right' {
			PropertyID.padding_right
		}
		'padding-top' {
			PropertyID.padding_top
		}
		'pointer-events' {
			PropertyID.pointer_events
		}
		'position' {
			PropertyID.position
		}
		'position-anchor' {
			PropertyID.position_anchor
		}
		'position-area' {
			PropertyID.position_area
		}
		'position-try-fallbacks' {
			PropertyID.position_try_fallbacks
		}
		'position-try-order' {
			PropertyID.position_try_order
		}
		'position-visibility' {
			PropertyID.position_visibility
		}
		'shape-margin' {
			PropertyID.shape_margin
		}
		'shape-image-threshold' {
			PropertyID.shape_image_threshold
		}
		'shape-rendering' {
			PropertyID.shape_rendering
		}
		'stop-color' {
			PropertyID.stop_color
		}
		'stop-opacity' {
			PropertyID.stop_opacity
		}
		'stroke-opacity' {
			PropertyID.stroke_opacity
		}
		'stroke-linecap' {
			PropertyID.stroke_linecap
		}
		'stroke-linejoin' {
			PropertyID.stroke_linejoin
		}
		'stroke-miterlimit' {
			PropertyID.stroke_miterlimit
		}
		'stroke-width' {
			PropertyID.stroke_width
		}
		'stroke-dashoffset' {
			PropertyID.stroke_dashoffset
		}
		'rotate' {
			PropertyID.rotate
		}
		'resize' {
			PropertyID.resize
		}
		'right' {
			PropertyID.right
		}
		'scroll-behavior' {
			PropertyID.scroll_behavior
		}
		'scale' {
			PropertyID.scale
		}
		'scrollbar-color' {
			PropertyID.scrollbar_color
		}
		'scrollbar-gutter' {
			PropertyID.scrollbar_gutter
		}
		'scrollbar-width' {
			PropertyID.scrollbar_width
		}
		'scroll-timeline-axis' {
			PropertyID.scroll_timeline_axis
		}
		'scroll-timeline-name' {
			PropertyID.scroll_timeline_name
		}
		'table-layout' {
			PropertyID.table_layout
		}
		'tab-size' {
			PropertyID.tab_size
		}
		'text-align' {
			PropertyID.text_align
		}
		'text-anchor' {
			PropertyID.text_anchor
		}
		'text-decoration-color' {
			PropertyID.text_decoration_color
		}
		'text-decoration-line' {
			PropertyID.text_decoration_line
		}
		'text-decoration-style' {
			PropertyID.text_decoration_style
		}
		'text-decoration-thickness' {
			PropertyID.text_decoration_thickness
		}
		'text-underline-offset' {
			PropertyID.text_underline_offset
		}
		'text-underline-position' {
			PropertyID.text_underline_position
		}
		'text-indent' {
			PropertyID.text_indent
		}
		'text-justify' {
			PropertyID.text_justify
		}
		'text-overflow' {
			PropertyID.text_overflow
		}
		'text-rendering' {
			PropertyID.text_rendering
		}
		'text-transform' {
			PropertyID.text_transform
		}
		'text-wrap-mode' {
			PropertyID.text_wrap_mode
		}
		'text-wrap-style' {
			PropertyID.text_wrap_style
		}
		'transform' {
			PropertyID.transform
		}
		'transform-box' {
			PropertyID.transform_box
		}
		'transform-origin' {
			PropertyID.transform_origin
		}
		'transform-style' {
			PropertyID.transform_style
		}
		'transition-behavior' {
			PropertyID.transition_behavior
		}
		'transition-delay' {
			PropertyID.transition_delay
		}
		'transition-duration' {
			PropertyID.transition_duration
		}
		'transition-property' {
			PropertyID.transition_property
		}
		'transition-timing-function' {
			PropertyID.transition_timing_function
		}
		'translate' {
			PropertyID.translate
		}
		'timeline-scope' {
			PropertyID.timeline_scope
		}
		'unicode-bidi' {
			PropertyID.unicode_bidi
		}
		'user-select' {
			PropertyID.user_select
		}
		'touch-action' {
			PropertyID.touch_action
		}
		'top' {
			PropertyID.top
		}
		'view-timeline-inset' {
			PropertyID.view_timeline_inset
		}
		'view-timeline-axis' {
			PropertyID.view_timeline_axis
		}
		'view-timeline-name' {
			PropertyID.view_timeline_name
		}
		'view-transition-name' {
			PropertyID.view_transition_name
		}
		'visibility' {
			PropertyID.visibility
		}
		'vertical-align' {
			PropertyID.vertical_align
		}
		'width' {
			PropertyID.width
		}
		'will-change' {
			PropertyID.will_change
		}
		'-webkit-text-fill-color' {
			PropertyID.webkit_text_fill_color
		}
		'white-space-collapse' {
			PropertyID.white_space_collapse
		}
		'white-space-trim' {
			PropertyID.white_space_trim
		}
		'word-break' {
			PropertyID.word_break
		}
		'word-spacing' {
			PropertyID.word_spacing
		}
		'writing-mode' {
			PropertyID.writing_mode
		}
		'widows' {
			PropertyID.widows
		}
		'z-index' {
			PropertyID.z_index
		}
		'cx' {
			PropertyID.cx
		}
		'cy' {
			PropertyID.cy
		}
		'x' {
			PropertyID.x
		}
		'y' {
			PropertyID.y
		}
		'r' {
			PropertyID.r
		}
		'rx' {
			PropertyID.rx
		}
		'ry' {
			PropertyID.ry
		}
		'dominant-baseline' {
			PropertyID.dominant_baseline
		}
		'display' {
			PropertyID.display
		}
		'flex-basis' {
			PropertyID.flex_basis
		}
		'quotes' {
			PropertyID.quotes
		}
		'box-shadow', '-webkit-box-shadow' {
			PropertyID.box_shadow
		}
		'text-shadow' {
			PropertyID.text_shadow
		}
		'list-style-type' {
			PropertyID.list_style_type
		}
		else {
			return none
		}
	}

	return PropertyNameAndID{
		name_: lowercase_name
		id_:   property_id
	}
}

pub fn (p PropertyNameAndID) name() string {
	return p.name_
}

pub fn (p PropertyNameAndID) id() ?PropertyID {
	return p.id_
}

pub fn (p PropertyNameAndID) is_custom_property() bool {
	return p.is_custom_
}

pub fn property_id_from_string(name string) ?PropertyID {
	if property := PropertyNameAndID.from_name(name) {
		return property.id()
	}
	return none
}

pub fn property_accepts_type(property_id PropertyID, value_type ValueType) bool {
	return match property_id {
		.animation_delay, .animation_duration {
			value_type == .time
		}
		.animation_iteration_count {
			value_type == .number
		}
		.animation_name {
			value_type in [.custom_ident, .string]
		}
		.animation_timing_function {
			value_type == .easing_function
		}
		.aspect_ratio {
			value_type == .ratio
		}
		.anchor_name, .anchor_scope, .position_anchor, .position_try_fallbacks,
		.scroll_timeline_name, .timeline_scope, .view_timeline_name {
			value_type == .dashed_ident
		}
		.accent_color, .background_color, .border_block_end_color, .border_block_start_color,
		.border_bottom_color, .border_inline_end_color, .border_inline_start_color,
		.border_left_color, .border_right_color, .border_top_color, .caret_color, .color,
		.flood_color, .outline_color, .stop_color, .text_decoration_color, .webkit_text_fill_color {
			value_type == .color
		}
		.background_image, .border_image_source, .list_style_image {
			value_type == .image
		}
		.mask_image {
			value_type in [.image, .url]
		}
		.color_scheme {
			value_type == .custom_ident
		}
		.view_transition_name {
			value_type == .custom_ident
		}
		.font_language_override, .quotes, .list_style_type {
			value_type == .string
		}
		.background_attachment, .background_blend_mode, .background_clip, .background_origin,
		.background_repeat, .border_block_end_style, .border_block_start_style,
		.border_bottom_style, .border_collapse, .border_image_repeat, .border_inline_end_style,
		.border_inline_start_style, .border_left_style, .border_right_style, .border_top_style,
		.box_sizing, .caption_side, .clip_rule, .color_interpolation, .content_visibility,
		.direction, .empty_cells, .fill_rule, .font_kerning, .font_optical_sizing,
		.font_variant_caps, .font_variant_emoji, .font_variant_position, .flex_direction,
		.flex_wrap, .align_content, .align_items, .align_self, .justify_content, .justify_items,
		.justify_self, .appearance, .column_span, .image_rendering, .transform_box, .touch_action,
		.writing_mode, .scrollbar_width, .resize, .contain, .container_type, .text_decoration_line,
		.text_decoration_style, .paint_order, .overflow_block, .overflow_inline, .overflow_wrap,
		.position_area, .position_try_order, .scroll_behavior, .scrollbar_color, .scrollbar_gutter,
		.text_underline_position, .math_shift, .isolation, .list_style_position, .mask_clip,
		.mask_composite, .mask_mode, .mask_origin, .mask_repeat, .mask_type {
			false
		}
		.clear, .float_, .mix_blend_mode, .object_fit, .outline_style, .overflow_x, .overflow_y,
		.pointer_events, .position, .position_visibility, .scroll_timeline_axis, .shape_rendering,
		.stroke_linecap, .stroke_linejoin, .table_layout, .text_align, .text_anchor, .text_justify,
		.text_overflow, .text_rendering, .text_transform, .text_wrap_mode, .text_wrap_style,
		.transform_style, .unicode_bidi, .user_select, .view_timeline_axis, .visibility,
		.white_space_collapse, .white_space_trim, .word_break {
			false
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape,
		.corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape,
		.corner_top_left_shape, .corner_top_right_shape {
			value_type == .corner_shape
		}
		.fill_opacity, .flood_opacity, .opacity, .shape_image_threshold, .stop_opacity,
		.stroke_opacity {
			value_type in [.number, .percentage, .opacity]
		}
		.animation_timeline {
			value_type in [.dashed_ident, .scroll_function, .view_function]
		}
		.order, .orphans, .z_index {
			value_type == .integer
		}
		.column_count, .widows {
			value_type == .integer
		}
		.view_timeline_inset {
			value_type == .view_timeline_inset
		}
		.object_position, .perspective_origin {
			value_type == .position
		}
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .perspective {
			value_type == .length
		}
		.tab_size {
			value_type in [.length, .number]
		}
		.transform_origin, .vertical_align, .flex_basis {
			value_type in [.length, .percentage]
		}
		.will_change {
			value_type == .custom_ident
		}
		.border_block_end_width, .border_block_start_width, .border_bottom_width,
		.border_inline_end_width, .border_inline_start_width, .border_left_width,
		.border_right_width, .border_top_width, .outline_offset, .outline_width {
			value_type == .length
		}
		.column_width, .column_height {
			value_type == .length
		}
		.font_feature_settings, .font_variation_settings {
			value_type == .opentype_tag
		}
		.font_style {
			value_type == .font_style
		}
		.font_weight {
			value_type == .number
		}
		.flex_grow, .flex_shrink, .stroke_miterlimit {
			value_type == .number
		}
		.font_width {
			value_type == .percentage
		}
		.line_height {
			value_type in [.length, .number, .percentage]
		}
		.letter_spacing, .word_spacing {
			value_type in [.length, .percentage]
		}
		.background_position_x, .background_position_y, .background_size, .mask_size {
			value_type in [.length, .percentage]
		}
		.mask_position {
			value_type == .position
		}
		.block_size, .height, .inline_size, .min_block_size, .min_height, .min_inline_size,
		.min_width, .width, .max_block_size, .max_height, .max_inline_size, .max_width {
			value_type in [.anchor_size, .fit_content, .length, .percentage]
		}
		.bottom, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start,
		.left, .right, .top {
			value_type in [.anchor, .length, .percentage]
		}
		.margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end,
		.margin_inline_start, .margin_left, .margin_right, .margin_top {
			value_type in [.anchor_size, .length, .percentage]
		}
		.padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end,
		.padding_inline_start, .padding_left, .padding_right, .padding_top {
			value_type in [.length, .percentage]
		}
		.border_spacing {
			value_type == .length
		}
		.border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius,
		.border_end_start_radius, .border_start_end_radius, .border_start_start_radius,
		.border_top_left_radius, .border_top_right_radius {
			value_type in [.length, .percentage]
		}
		.border_image_outset {
			value_type in [.length, .number]
		}
		.border_image_slice {
			value_type in [.number, .percentage]
		}
		.border_image_width {
			value_type in [.length, .number, .percentage]
		}
		.column_gap, .row_gap, .shape_margin, .cx, .cy, .x, .y, .r, .rx, .ry,
		.text_decoration_thickness, .text_underline_offset, .text_indent {
			value_type in [.length, .percentage]
		}
		.stroke_width, .stroke_dashoffset {
			value_type in [.length, .number, .percentage]
		}
		.math_depth {
			value_type == .integer
		}
		.math_style {
			false
		}
		.transform {
			value_type in [.transform_function, .transform_list]
		}
		.rotate, .scale, .translate {
			value_type == .transform_function
		}
		.transition_delay, .transition_duration {
			value_type == .time
		}
		.transition_timing_function {
			value_type == .easing_function
		}
		.animation_composition, .animation_direction, .animation_fill_mode, .animation_play_state,
		.transition_behavior, .transition_property, .dominant_baseline, .display, .box_shadow,
		.text_shadow {
			false
		}
	}
}

fn is_position_area_keyword_string(value string) bool {
	return value in [
		'left',
		'center',
		'right',
		'span-left',
		'span-right',
		'x-start',
		'x-end',
		'span-x-start',
		'span-x-end',
		'self-x-start',
		'self-x-end',
		'span-self-x-start',
		'span-self-x-end',
		'span-all',
		'top',
		'bottom',
		'span-top',
		'span-bottom',
		'y-start',
		'y-end',
		'span-y-start',
		'span-y-end',
		'self-y-start',
		'self-y-end',
		'span-self-y-start',
		'span-self-y-end',
		'block-start',
		'block-end',
		'span-block-start',
		'span-block-end',
		'inline-start',
		'inline-end',
		'span-inline-start',
		'span-inline-end',
		'self-block-start',
		'self-block-end',
		'span-self-block-start',
		'span-self-block-end',
		'self-inline-start',
		'self-inline-end',
		'span-self-inline-start',
		'span-self-inline-end',
		'start',
		'end',
		'span-start',
		'span-end',
		'self-start',
		'self-end',
		'span-self-start',
		'span-self-end',
	]
}

fn is_try_tactic_keyword_string(value string) bool {
	return value in ['flip-block', 'flip-inline', 'flip-start']
}

fn property_accepts_keyword_string(property_id PropertyID, value string) bool {
	lowercase_value := to_ascii_lowercase(value)
	if is_css_wide_keyword_string(lowercase_value) {
		return true
	}
	return match property_id {
		.animation_composition {
			lowercase_value in ['replace', 'add', 'accumulate']
		}
		.animation_delay {
			false
		}
		.animation_direction {
			lowercase_value in ['normal', 'reverse', 'alternate', 'alternate-reverse']
		}
		.animation_duration {
			lowercase_value == 'auto'
		}
		.animation_fill_mode {
			lowercase_value in ['none', 'forwards', 'backwards', 'both']
		}
		.animation_iteration_count {
			lowercase_value == 'infinite'
		}
		.animation_name {
			lowercase_value == 'none'
		}
		.animation_play_state {
			lowercase_value in ['running', 'paused']
		}
		.animation_timing_function {
			lowercase_value in ['linear', 'ease-in', 'ease-out', 'ease-in-out', 'ease']
		}
		.aspect_ratio {
			lowercase_value == 'auto'
		}
		.anchor_name {
			lowercase_value == 'none'
		}
		.anchor_scope {
			lowercase_value in ['none', 'all']
		}
		.align_content {
			lowercase_value in ['normal', 'start', 'flex-start', 'end', 'flex-end', 'center',
				'space-between', 'space-around', 'space-evenly', 'stretch']
		}
		.align_items {
			lowercase_value in ['baseline', 'center', 'end', 'flex-end', 'flex-start', 'normal',
				'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe']
		}
		.align_self {
			lowercase_value in ['auto', 'baseline', 'center', 'end', 'flex-end', 'flex-start',
				'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe']
		}
		.appearance {
			lowercase_value in ['auto', 'button', 'checkbox', 'listbox', 'menulist', 'meter',
				'menulist-button', 'none', 'push-button', 'progress-bar', 'radio', 'searchfield',
				'slider-horizontal', 'square-button', 'textarea', 'textfield']
		}
		.position_anchor {
			lowercase_value == 'auto'
		}
		.scroll_timeline_name, .view_timeline_name {
			lowercase_value == 'none'
		}
		.view_timeline_inset {
			false
		}
		.view_transition_name {
			lowercase_value == 'none'
		}
		.accent_color, .caret_color {
			if lowercase_value == 'auto' {
				true
			} else if keyword := keyword_from_string(lowercase_value) {
				KeywordStyleValue.is_color(keyword)
			} else {
				false
			}
		}
		.background_color, .border_block_end_color, .border_block_start_color,
		.border_bottom_color, .border_inline_end_color, .border_inline_start_color,
		.border_left_color, .border_right_color, .border_top_color, .color, .flood_color,
		.outline_color, .stop_color, .text_decoration_color, .webkit_text_fill_color {
			if keyword := keyword_from_string(lowercase_value) {
				KeywordStyleValue.is_color(keyword)
			} else {
				false
			}
		}
		.background_image, .border_image_source, .list_style_image, .mask_image {
			lowercase_value == 'none'
		}
		.background_attachment {
			lowercase_value in ['fixed', 'local', 'scroll']
		}
		.background_blend_mode {
			lowercase_value in ['normal', 'multiply', 'screen', 'overlay', 'darken', 'lighten',
				'color-dodge', 'color-burn', 'hard-light', 'soft-light', 'difference', 'exclusion',
				'hue', 'saturation', 'color', 'luminosity', 'plus-darker', 'plus-lighter']
		}
		.background_clip, .background_origin {
			lowercase_value in ['border-box', 'content-box', 'padding-box', 'text']
		}
		.background_position_x {
			lowercase_value in ['center', 'left', 'right']
		}
		.background_position_y {
			lowercase_value in ['center', 'bottom', 'top']
		}
		.background_repeat, .mask_repeat {
			lowercase_value in ['no-repeat', 'repeat', 'round', 'space', 'repeat-x', 'repeat-y']
		}
		.background_size, .mask_size {
			lowercase_value in ['auto', 'cover', 'contain']
		}
		.object_position, .perspective_origin, .transform_origin {
			lowercase_value in ['bottom', 'center', 'left', 'right', 'top']
		}
		.color_scheme {
			// color-scheme = normal | [ light | dark | <custom-ident> ]+ && only?
			lowercase_value in ['normal', 'light', 'dark']
		}
		.content_visibility {
			// content-visibility = visible | auto | hidden
			lowercase_value in ['visible', 'auto', 'hidden']
		}
		.contain {
			lowercase_value in ['none', 'strict', 'content', 'size', 'inline-size', 'layout', 'style',
				'paint']
		}
		.container_type {
			lowercase_value in ['normal', 'size', 'inline-size', 'scroll-state']
		}
		.column_span {
			lowercase_value in ['none', 'all']
		}
		.column_count, .column_width, .column_height {
			lowercase_value == 'auto'
		}
		.column_gap, .row_gap {
			lowercase_value == 'normal'
		}
		.clip_rule, .fill_rule {
			lowercase_value in ['nonzero', 'evenodd']
		}
		.color_interpolation {
			lowercase_value in ['auto', 'linearrgb', 'srgb']
		}
		.caption_side {
			lowercase_value in ['top', 'bottom']
		}
		.direction {
			lowercase_value in ['ltr', 'rtl']
		}
		.empty_cells {
			lowercase_value in ['show', 'hide']
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape,
		.corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape,
		.corner_top_left_shape, .corner_top_right_shape {
			lowercase_value in ['round', 'scoop', 'bevel', 'notch', 'square', 'squircle']
		}
		.animation_timeline {
			// animation-timeline = auto | none | <dashed-ident> | scroll() | view()
			lowercase_value in ['auto', 'none']
		}
		.border_block_end_width, .border_block_start_width, .border_bottom_width,
		.border_inline_end_width, .border_inline_start_width, .border_left_width,
		.border_right_width, .border_top_width, .outline_width {
			lowercase_value in ['thin', 'medium', 'thick']
		}
		.border_block_end_style, .border_block_start_style, .border_bottom_style,
		.border_inline_end_style, .border_inline_start_style, .border_left_style,
		.border_right_style, .border_top_style {
			lowercase_value in ['none', 'hidden', 'dotted', 'dashed', 'solid', 'double', 'groove',
				'ridge', 'inset', 'outset']
		}
		.border_image_repeat {
			lowercase_value in ['stretch', 'repeat', 'round', 'space']
		}
		.border_image_slice {
			lowercase_value == 'fill'
		}
		.border_image_width {
			lowercase_value == 'auto'
		}
		.block_size, .height, .inline_size, .min_block_size, .min_height, .min_inline_size,
		.min_width, .width {
			lowercase_value in ['auto', 'fit-content', 'max-content', 'min-content']
		}
		.max_block_size, .max_height, .max_inline_size, .max_width {
			lowercase_value in ['fit-content', 'max-content', 'min-content', 'none']
		}
		.bottom, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start,
		.left, .right, .top, .margin_block_end, .margin_block_start, .margin_bottom,
		.margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top {
			lowercase_value == 'auto'
		}
		.border_spacing, .padding_block_end, .padding_block_start, .padding_bottom,
		.overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .padding_inline_end,
		.padding_inline_start, .padding_left, .padding_right, .padding_top, .tab_size {
			false
		}
		.perspective {
			lowercase_value == 'none'
		}
		.position_area {
			lowercase_value == 'none' || is_position_area_keyword_string(lowercase_value)
		}
		.position_try_fallbacks {
			lowercase_value == 'none' || is_position_area_keyword_string(lowercase_value)
				|| is_try_tactic_keyword_string(lowercase_value)
		}
		.position_try_order {
			lowercase_value in ['normal', 'most-width', 'most-height', 'most-block-size',
				'most-inline-size']
		}
		.border_collapse {
			lowercase_value in ['collapse', 'separate']
		}
		.box_sizing {
			lowercase_value in ['border-box', 'content-box']
		}
		.outline_offset {
			false
		}
		.order, .orphans, .widows {
			false
		}
		.border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius,
		.border_end_start_radius, .border_image_outset, .border_start_end_radius,
		.border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .flex_grow,
		.flex_shrink, .stroke_miterlimit, .stroke_width, .stroke_dashoffset, .shape_margin, .cx,
		.cy, .x, .y, .r {
			false
		}
		.rx, .ry, .text_underline_offset {
			lowercase_value == 'auto'
		}
		.text_decoration_thickness {
			lowercase_value in ['auto', 'from-font']
		}
		.text_indent {
			lowercase_value in ['each-line', 'hanging']
		}
		.outline_style {
			lowercase_value in ['auto', 'none', 'dotted', 'dashed', 'solid', 'double', 'groove',
				'ridge', 'inset', 'outset']
		}
		.overflow_block, .overflow_inline, .overflow_x, .overflow_y {
			lowercase_value in ['auto', 'clip', 'hidden', 'scroll', 'visible', 'overlay']
		}
		.overflow_wrap {
			lowercase_value in ['anywhere', 'break-word', 'normal']
		}
		.pointer_events {
			lowercase_value in ['auto', 'all', 'none']
		}
		.paint_order {
			lowercase_value in ['normal', 'fill', 'stroke', 'markers']
		}
		.clear {
			lowercase_value in ['none', 'left', 'right', 'both', 'inline-start', 'inline-end']
		}
		.float_ {
			lowercase_value in ['none', 'left', 'right', 'inline-start', 'inline-end']
		}
		.position {
			lowercase_value in ['absolute', 'fixed', 'relative', 'static', 'sticky']
		}
		.table_layout {
			lowercase_value in ['auto', 'fixed']
		}
		.unicode_bidi {
			lowercase_value in ['bidi-override', 'embed', 'isolate', 'isolate-override', 'normal',
				'plaintext']
		}
		.visibility {
			lowercase_value in ['collapse', 'hidden', 'visible']
		}
		.z_index {
			lowercase_value == 'auto'
		}
		.mix_blend_mode {
			lowercase_value in ['normal', 'multiply', 'screen', 'overlay', 'darken', 'lighten',
				'color-dodge', 'color-burn', 'hard-light', 'soft-light', 'difference', 'exclusion',
				'hue', 'saturation', 'color', 'luminosity', 'plus-darker', 'plus-lighter']
		}
		.object_fit {
			lowercase_value in ['fill', 'contain', 'cover', 'none', 'scale-down']
		}
		.isolation {
			lowercase_value in ['auto', 'isolate']
		}
		.list_style_position {
			lowercase_value in ['inside', 'outside']
		}
		.mask_type {
			lowercase_value in ['luminance', 'alpha']
		}
		.mask_clip {
			lowercase_value in ['content-box', 'padding-box', 'border-box', 'fill-box', 'stroke-box',
				'view-box', 'no-clip']
		}
		.mask_position {
			lowercase_value in ['center', 'left', 'right', 'top', 'bottom']
		}
		.mask_composite {
			lowercase_value in ['add', 'subtract', 'intersect', 'exclude']
		}
		.mask_mode {
			lowercase_value in ['alpha', 'luminance', 'match-source']
		}
		.mask_origin {
			lowercase_value in ['content-box', 'padding-box', 'border-box', 'fill-box', 'stroke-box',
				'view-box']
		}
		.scroll_timeline_axis, .view_timeline_axis {
			lowercase_value in ['block', 'inline', 'x', 'y']
		}
		.position_visibility {
			lowercase_value in ['always', 'anchors-valid', 'anchors-visible', 'no-overflow']
		}
		.shape_rendering {
			lowercase_value in ['auto', 'optimizespeed', 'crispedges', 'geometricprecision']
		}
		.stroke_linecap {
			lowercase_value in ['butt', 'round', 'square']
		}
		.stroke_linejoin {
			lowercase_value in ['miter', 'round', 'bevel']
		}
		.text_anchor {
			lowercase_value in ['start', 'middle', 'end']
		}
		.text_decoration_line {
			lowercase_value in ['none', 'underline', 'overline', 'line-through', 'blink',
				'spelling-error', 'grammar-error']
		}
		.text_decoration_style {
			lowercase_value in ['dashed', 'dotted', 'double', 'solid', 'wavy']
		}
		.text_align {
			lowercase_value in ['center', 'justify', 'start', 'end', 'left', 'right', 'match-parent',
				'-libweb-center', '-libweb-inherit-or-center', '-libweb-left', '-libweb-right']
		}
		.text_justify {
			lowercase_value in ['auto', 'none', 'inter-word', 'inter-character']
		}
		.text_overflow {
			lowercase_value in ['clip', 'ellipsis']
		}
		.text_rendering {
			lowercase_value in ['auto', 'optimizespeed', 'optimizelegibility', 'geometricprecision']
		}
		.text_transform {
			lowercase_value in ['capitalize', 'full-size-kana', 'full-width', 'lowercase',
				'math-auto', 'none', 'uppercase']
		}
		.text_wrap_mode {
			lowercase_value in ['wrap', 'nowrap']
		}
		.text_wrap_style {
			lowercase_value in ['auto', 'balance', 'stable', 'pretty']
		}
		.transform_style {
			lowercase_value in ['flat', 'preserve-3d']
		}
		.transform_box {
			lowercase_value in ['content-box', 'border-box', 'fill-box', 'stroke-box', 'view-box']
		}
		.touch_action {
			lowercase_value in ['auto', 'manipulation', 'none', 'pan-down', 'pan-left', 'pan-right',
				'pan-up', 'pan-x', 'pan-y']
		}
		.writing_mode {
			lowercase_value in ['horizontal-tb', 'vertical-rl', 'vertical-lr', 'sideways-rl',
				'sideways-lr']
		}
		.scrollbar_width {
			lowercase_value in ['auto', 'thin', 'none']
		}
		.resize {
			lowercase_value in ['none', 'both', 'horizontal', 'vertical', 'inline', 'block']
		}
		.user_select {
			lowercase_value in ['all', 'auto', 'contain', 'none', 'text']
		}
		.white_space_collapse {
			lowercase_value in ['collapse', 'discard', 'preserve', 'preserve-breaks',
				'preserve-spaces', 'break-spaces']
		}
		.white_space_trim {
			lowercase_value in ['none', 'discard-before', 'discard-after', 'discard-inner']
		}
		.word_break {
			lowercase_value in ['normal', 'keep-all', 'break-all', 'break-word']
		}
		.font_feature_settings, .font_variation_settings {
			lowercase_value == 'normal'
		}
		.font_kerning {
			lowercase_value in ['auto', 'normal', 'none']
		}
		.font_language_override {
			lowercase_value == 'normal'
		}
		.font_optical_sizing {
			lowercase_value in ['auto', 'none']
		}
		.font_style {
			lowercase_value in ['normal', 'italic', 'left', 'right', 'oblique']
		}
		.font_variant_caps {
			lowercase_value in ['normal', 'small-caps', 'all-small-caps', 'petite-caps',
				'all-petite-caps', 'unicase', 'titling-caps']
		}
		.font_variant_emoji {
			lowercase_value in ['normal', 'text', 'emoji', 'unicode']
		}
		.font_variant_position {
			lowercase_value in ['normal', 'sub', 'super']
		}
		.font_weight {
			lowercase_value in ['normal', 'bold', 'bolder', 'lighter']
		}
		.font_width {
			lowercase_value in ['ultra-condensed', 'extra-condensed', 'condensed', 'semi-condensed',
				'normal', 'semi-expanded', 'expanded', 'extra-expanded', 'ultra-expanded']
		}
		.flex_direction {
			lowercase_value in ['row', 'row-reverse', 'column', 'column-reverse']
		}
		.flex_wrap {
			lowercase_value in ['nowrap', 'wrap', 'wrap-reverse']
		}
		.image_rendering {
			lowercase_value in ['auto', 'crisp-edges', 'high-quality', 'pixelated', 'smooth',
				'optimizespeed', 'optimizequality']
		}
		.justify_content {
			lowercase_value in ['normal', 'start', 'end', 'flex-start', 'flex-end', 'center',
				'space-between', 'space-around', 'space-evenly', 'stretch', 'left', 'right']
		}
		.justify_items {
			lowercase_value in ['baseline', 'center', 'end', 'flex-end', 'flex-start', 'legacy',
				'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe', 'left',
				'right']
		}
		.justify_self {
			lowercase_value in ['auto', 'baseline', 'center', 'end', 'flex-end', 'flex-start',
				'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe', 'left',
				'right']
		}
		.letter_spacing, .line_height, .word_spacing {
			lowercase_value == 'normal'
		}
		.math_depth {
			lowercase_value == 'auto-add'
		}
		.math_style {
			lowercase_value in ['normal', 'compact']
		}
		.math_shift {
			lowercase_value in ['normal', 'compact']
		}
		.fill_opacity, .flood_opacity, .opacity, .shape_image_threshold, .stop_opacity,
		.stroke_opacity {
			false
		}
		.rotate, .scale, .transform, .translate {
			lowercase_value == 'none'
		}
		.transition_behavior {
			lowercase_value in ['normal', 'allow-discrete']
		}
		.transition_timing_function {
			lowercase_value in ['linear', 'ease-in', 'ease-out', 'ease-in-out', 'ease']
		}
		.transition_property {
			lowercase_value == 'none'
		}
		.transition_delay, .transition_duration {
			false
		}
		.scroll_behavior {
			lowercase_value in ['auto', 'smooth']
		}
		.scrollbar_color {
			lowercase_value == 'auto'
		}
		.scrollbar_gutter {
			lowercase_value in ['auto', 'stable', 'both-edges']
		}
		.text_underline_position {
			lowercase_value in ['auto', 'from-font', 'under', 'left', 'right']
		}
		.timeline_scope {
			lowercase_value in ['none', 'all']
		}
		.vertical_align {
			lowercase_value in ['baseline', 'sub', 'super', 'text-top', 'text-bottom', 'middle',
				'top', 'bottom']
		}
		.will_change {
			lowercase_value in ['auto', 'scroll-position', 'contents']
		}
		.dominant_baseline {
			lowercase_value in ['auto', 'text-bottom', 'alphabetic', 'ideographic', 'middle',
				'central', 'mathematical', 'hanging', 'text-top']
		}
		.flex_basis {
			lowercase_value in ['auto', 'content', 'min-content', 'max-content', 'fit-content']
		}
		.quotes {
			lowercase_value in ['auto', 'none']
		}
		.box_shadow, .text_shadow {
			lowercase_value == 'none'
		}
		.list_style_type {
			lowercase_value == 'none'
		}
		.display {
			lowercase_value in ['block', 'inline', 'run-in', 'flow', 'flow-root', 'table', 'flex',
				'grid', 'ruby', 'math', 'list-item', 'table-row-group', 'table-header-group',
				'table-footer-group', 'table-row', 'table-cell', 'table-column-group',
				'table-column', 'table-caption', 'ruby-base', 'ruby-text', 'ruby-base-container',
				'ruby-text-container', 'contents', 'none', 'inline-block', 'inline-table',
				'inline-flex', 'inline-grid']
		}
	}
}

fn property_accepts_custom_ident(property_id PropertyID, value string) bool {
	lowercase_value := to_ascii_lowercase(value)
	if lowercase_value.len == 0 || is_css_wide_keyword_string(lowercase_value) {
		return false
	}
	return match property_id {
		.animation_name {
			lowercase_value !in ['default', 'none']
		}
		.border_block_end_color, .border_block_end_style, .border_block_end_width,
		.border_block_start_color, .border_block_start_style, .border_block_start_width,
		.border_end_end_radius, .border_end_start_radius, .border_inline_end_color,
		.border_inline_end_style, .border_inline_end_width, .border_inline_start_color,
		.border_inline_start_style, .border_inline_start_width, .border_start_end_radius,
		.border_start_start_radius, .corner_end_end_shape, .corner_end_start_shape,
		.corner_start_end_shape, .corner_start_start_shape {
			false
		}
		.object_position, .overflow_block, .overflow_clip_margin_block_end,
		.overflow_clip_margin_block_start, .overflow_clip_margin_bottom,
		.overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start,
		.overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top,
		.overflow_inline, .perspective, .perspective_origin, .position_area, .position_try_order,
		.scrollbar_color, .scrollbar_gutter, .tab_size, .text_underline_position,
		.transform_origin, .vertical_align {
			false
		}
		.accent_color, .background_attachment, .background_blend_mode, .background_clip,
		.background_color, .background_image, .background_origin, .background_position_x,
		.background_position_y, .background_repeat, .background_size, .border_bottom_color,
		.border_bottom_style, .border_bottom_left_radius, .border_bottom_right_radius,
		.border_collapse, .border_image_outset, .border_image_repeat, .border_image_slice,
		.border_image_source, .border_image_width, .border_left_color, .border_left_style,
		.border_right_color, .border_right_style, .border_top_color, .border_top_style,
		.border_top_left_radius, .border_top_right_radius, .border_spacing, .block_size, .bottom,
		.box_sizing, .caption_side, .caret_color, .clear, .clip_rule, .color, .color_interpolation,
		.direction, .empty_cells, .fill_rule, .float_, .flood_color, .font_kerning,
		.font_language_override, .font_optical_sizing, .font_variant_caps, .font_variant_emoji,
		.font_variant_position, .flex_grow, .flex_shrink, .flex_direction, .flex_wrap,
		.align_content, .align_items, .align_self, .justify_content, .justify_items, .justify_self,
		.appearance, .column_span, .column_count, .column_width, .column_height, .column_gap,
		.row_gap, .height, .image_rendering, .inline_size, .inset_block_end, .inset_block_start,
		.inset_inline_end, .inset_inline_start, .isolation, .left, .list_style_image,
		.list_style_position, .margin_block_end, .margin_block_start, .margin_bottom,
		.margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top,
		.mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position,
		.mask_repeat, .mask_size, .mask_type, .max_block_size, .max_height, .max_inline_size,
		.max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .mix_blend_mode,
		.object_fit, .outline_color, .outline_style, .overflow_x, .overflow_y, .overflow_wrap,
		.padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end,
		.padding_inline_start, .padding_left, .padding_right, .padding_top, .paint_order,
		.pointer_events, .position, .position_visibility, .right, .scroll_timeline_axis,
		.shape_margin, .shape_rendering, .stop_color, .stroke_linecap, .stroke_linejoin,
		.stroke_miterlimit, .stroke_width, .stroke_dashoffset, .table_layout, .text_align,
		.text_anchor, .text_decoration_color, .text_decoration_line, .text_decoration_style,
		.text_decoration_thickness, .text_underline_offset, .text_indent, .text_justify,
		.text_overflow, .text_rendering, .text_transform, .text_wrap_mode, .text_wrap_style, .top,
		.transform_box, .transform_style, .touch_action, .width, .writing_mode, .scrollbar_width,
		.resize, .scroll_behavior, .math_shift, .contain, .container_type, .unicode_bidi,
		.user_select, .view_timeline_axis, .view_timeline_inset, .visibility,
		.webkit_text_fill_color, .white_space_collapse, .white_space_trim, .word_break, .widows,
		.cx, .cy, .x, .y, .r, .rx, .ry, .dominant_baseline, .display, .flex_basis, .quotes,
		.box_shadow, .text_shadow {
			false
		}
		.color_scheme {
			// color-scheme accepts `light` and `dark` as keywords, but excludes
			// them from the <custom-ident> branch.
			lowercase_value !in ['normal', 'light', 'dark', 'only']
		}
		.view_transition_name {
			lowercase_value !in ['auto', 'none']
		}
		.content_visibility {
			false
		}
		.corner_bottom_left_shape, .corner_bottom_right_shape, .corner_top_left_shape,
		.corner_top_right_shape {
			false
		}
		.animation_timeline {
			// The named timeline branch is a <dashed-ident>, represented by
			// CustomIdentStyleValue until a dedicated DashedIdent StyleValue exists.
			value.starts_with('--')
		}
		.animation_composition, .animation_delay, .animation_direction, .animation_duration,
		.animation_fill_mode, .animation_iteration_count, .animation_play_state,
		.animation_timing_function, .aspect_ratio, .border_bottom_width, .border_left_width,
		.border_right_width, .border_top_width, .font_feature_settings, .font_style,
		.font_variation_settings, .font_weight, .font_width, .letter_spacing, .line_height,
		.math_depth, .math_style, .fill_opacity, .flood_opacity, .opacity, .order, .orphans,
		.outline_offset, .outline_width, .shape_image_threshold, .stop_opacity, .stroke_opacity,
		.rotate, .scale, .transform, .transition_behavior, .transition_delay, .transition_duration,
		.transition_timing_function, .translate, .word_spacing, .z_index {
			false
		}
		.transition_property, .list_style_type {
			lowercase_value != 'none'
		}
		.anchor_name, .position_try_fallbacks, .scroll_timeline_name, .timeline_scope,
		.view_timeline_name {
			value.starts_with('--') && lowercase_value != 'none'
		}
		.anchor_scope {
			value.starts_with('--') && lowercase_value !in ['none', 'all']
		}
		.position_anchor {
			value.starts_with('--') && lowercase_value != 'auto'
		}
		.will_change {
			lowercase_value !in ['all', 'auto', 'contents', 'none', 'scroll-position', 'will-change']
		}
	}
}

fn property_accepts_style_value(property_id PropertyID, value StyleValue) bool {
	if value.is_css_wide_keyword() {
		return true
	}
	return match value {
		KeywordStyleValue {
			property_accepts_keyword_string(property_id, value.to_string())
		}
		AnchorSizeStyleValue {
			property_accepts_type(property_id, .anchor_size)
		}
		AnchorStyleValue {
			property_accepts_type(property_id, .anchor)
		}
		CustomIdentStyleValue {
			property_accepts_custom_ident(property_id, value.custom_ident())
		}
		ColorStyleValue {
			property_accepts_type(property_id, .color)
		}
		EasingStyleValue {
			property_accepts_type(property_id, .easing_function)
		}
		BackgroundSizeStyleValue {
			property_id in [.background_size, .mask_size]
		}
		BorderImageSliceStyleValue {
			property_id == .border_image_slice
		}
		BorderRadiusStyleValue {
			property_id in [.border_bottom_left_radius, .border_bottom_right_radius,
				.border_end_end_radius, .border_end_start_radius, .border_start_end_radius,
				.border_start_start_radius, .border_top_left_radius, .border_top_right_radius]
		}
		EdgeStyleValue {
			property_id in [.background_position_x, .background_position_y]
		}
		FontStyleStyleValue {
			property_accepts_type(property_id, .font_style)
		}
		ImageStyleValue {
			property_accepts_type(property_id, .image)
		}
		NumberStyleValue {
			property_accepts_type(property_id, .number)
				&& property_accepts_number(property_id, value.number())
		}
		IntegerStyleValue {
			property_accepts_type(property_id, .integer)
				&& property_accepts_integer(property_id, value.integer())
		}
		OpenTypeTaggedStyleValue {
			property_accepts_type(property_id, .opentype_tag)
		}
		PercentageStyleValue {
			property_accepts_type(property_id, .percentage)
				&& property_accepts_percentage(property_id, value.percentage())
		}
		PositionStyleValue {
			property_accepts_type(property_id, .position)
		}
		RatioStyleValue {
			property_accepts_type(property_id, .ratio)
		}
		ScrollbarColorStyleValue {
			property_id == .scrollbar_color
		}
		ScrollbarGutterStyleValue {
			property_id == .scrollbar_gutter
		}
		StringStyleValue {
			property_accepts_type(property_id, .string)
		}
		StubStyleValue {
			match value.type_ {
				.anchor {
					property_accepts_type(property_id, .anchor)
				}
				.anchor_size {
					property_accepts_type(property_id, .anchor_size)
				}
				.fit_content {
					property_accepts_type(property_id, .fit_content)
				}
				.keyword {
					property_accepts_keyword_string(property_id, value.serialize(.normal))
				}
				else {
					false
				}
			}
		}
		SuperellipseStyleValue {
			property_accepts_type(property_id, .corner_shape)
		}
		TimeStyleValue {
			property_accepts_type(property_id, .time)
				&& property_accepts_time(property_id, value.time())
		}
		TransformationStyleValue {
			property_accepts_type(property_id, .transform_function)
		}
		RepeatStyleStyleValue {
			property_id in [.background_repeat, .mask_repeat]
		}
		TextIndentStyleValue {
			property_id == .text_indent
		}
		TextUnderlinePositionStyleValue {
			property_id == .text_underline_position
		}
		URLStyleValue {
			property_accepts_type(property_id, .url)
		}
		StyleValueList {
			if property_is_list_valued(property_id)
				|| property_id in [.border_image_outset, .border_image_repeat, .border_image_width, .border_spacing, .scrollbar_color, .scrollbar_gutter, .transform_origin] {
				for item in value.values() {
					if !property_accepts_style_value(property_id, item) {
						return false
					}
				}
				true
			} else if property_accepts_type(property_id, .transform_list) {
				for item in value.values() {
					if !property_accepts_style_value(property_id, item) {
						return false
					}
				}
				true
			} else {
				false
			}
		}
		else {
			false
		}
	}
}

pub fn property_accepts_keyword(property_id PropertyID, keyword Keyword) bool {
	return property_accepts_keyword_string(property_id, string_from_keyword(keyword))
}

pub fn property_accepts_number(property_id PropertyID, value f64) bool {
	return match property_id {
		.animation_iteration_count {
			value >= 0
		}
		.font_weight {
			value >= 1 && value <= 1000
		}
		.flex_grow, .flex_shrink, .border_image_outset, .border_image_slice, .border_image_width,
		.stroke_miterlimit, .stroke_width, .stroke_dashoffset, .tab_size {
			value >= 0
		}
		else {
			true
		}
	}
}

pub fn property_accepts_integer(property_id PropertyID, value i64) bool {
	return match property_id {
		.column_count, .orphans, .widows { value >= 1 }
		else { true }
	}
}

pub fn property_accepts_percentage(property_id PropertyID, value Percentage) bool {
	return match property_id {
		.background_size, .mask_size, .block_size, .border_bottom_left_radius,
		.border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius,
		.border_image_slice, .border_image_width, .border_start_end_radius,
		.border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .height,
		.inline_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size,
		.min_height, .min_inline_size, .min_width, .padding_block_end, .padding_block_start,
		.padding_bottom, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right,
		.padding_top, .width, .column_gap, .row_gap, .shape_margin, .r, .rx, .ry, .stroke_width,
		.stroke_dashoffset {
			value.value() >= 0
		}
		else {
			true
		}
	}
}

pub fn property_accepts_angle(property_id PropertyID, value Angle) bool {
	_ = property_id
	_ = value
	return true
}

pub fn property_accepts_flex(property_id PropertyID, value Flex) bool {
	_ = property_id
	_ = value
	return true
}

pub fn property_accepts_frequency(property_id PropertyID, value Frequency) bool {
	_ = property_id
	_ = value
	return true
}

pub fn property_accepts_length(property_id PropertyID, value Length) bool {
	return match property_id {
		.background_size, .mask_size, .block_size, .border_block_end_width,
		.border_block_start_width, .border_bottom_left_radius, .border_bottom_right_radius,
		.border_bottom_width, .border_end_end_radius, .border_end_start_radius,
		.border_image_outset, .border_image_width, .border_inline_end_width,
		.border_inline_start_width, .border_left_width, .border_right_width, .border_spacing,
		.border_start_end_radius, .border_start_start_radius, .border_top_left_radius,
		.border_top_right_radius, .border_top_width, .height, .inline_size, .max_block_size,
		.max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size,
		.min_width, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start,
		.overflow_clip_margin_bottom, .overflow_clip_margin_inline_end,
		.overflow_clip_margin_inline_start, .overflow_clip_margin_left,
		.overflow_clip_margin_right, .overflow_clip_margin_top, .padding_block_end,
		.padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start,
		.padding_left, .padding_right, .padding_top, .perspective, .tab_size, .width,
		.column_width, .column_height, .column_gap, .row_gap, .shape_margin, .r, .rx, .ry,
		.stroke_width, .stroke_dashoffset, .flex_basis {
			value.raw_value() >= 0
		}
		else {
			true
		}
	}
}

pub fn property_accepts_resolution(property_id PropertyID, value Resolution) bool {
	_ = property_id
	_ = value
	return true
}

pub fn property_accepts_time(property_id PropertyID, value Time) bool {
	return match property_id {
		.animation_duration, .transition_duration { value.to_seconds() >= 0 }
		else { true }
	}
}

fn to_ascii_lowercase(value string) string {
	mut bytes := value.bytes()
	for i, byte in bytes {
		if byte >= `A` && byte <= `Z` {
			bytes[i] = byte + 0x20
		}
	}
	return bytes.bytestr()
}

fn component_value_from_text(text string) ComponentValue {
	return ComponentValue.from_token(Token.create_ident(text, text))
}

pub fn (value_type ValueType) to_string() string {
	return value_type_to_string(value_type)
}

// --- Units helpers used by CSSUnitValue and NumericType ---

pub enum DimensionType {
	angle
	flex
	frequency
	length
	resolution
	time
}

pub fn string_to_angle_unit(unit string) ?AngleUnit {
	return match to_ascii_lowercase(unit) {
		'deg' { AngleUnit.deg }
		'grad' { AngleUnit.grad }
		'rad' { AngleUnit.rad }
		'turn' { AngleUnit.turn }
		else { none }
	}
}

pub fn string_to_frequency_unit(unit string) ?FrequencyUnit {
	return match to_ascii_lowercase(unit) {
		'hz' { FrequencyUnit.hz }
		'khz' { FrequencyUnit.khz }
		else { none }
	}
}

pub fn string_to_flex_unit(unit string) ?FlexUnit {
	return match to_ascii_lowercase(unit) {
		'fr' { FlexUnit.fr }
		else { none }
	}
}

pub fn string_to_resolution_unit(unit string) ?ResolutionUnit {
	return match to_ascii_lowercase(unit) {
		'dpcm' { ResolutionUnit.dpcm }
		'dpi' { ResolutionUnit.dpi }
		'dppx' { ResolutionUnit.dppx }
		'x' { ResolutionUnit.x }
		else { none }
	}
}

pub fn string_to_time_unit(unit string) ?TimeUnit {
	return match to_ascii_lowercase(unit) {
		'ms' { TimeUnit.ms }
		's' { TimeUnit.s }
		else { none }
	}
}

pub fn string_to_length_unit(unit string) ?LengthUnit {
	return match to_ascii_lowercase(unit) {
		'cap' { LengthUnit.cap }
		'ch' { LengthUnit.ch }
		'cm' { LengthUnit.cm }
		'dvb' { LengthUnit.dvb }
		'dvh' { LengthUnit.dvh }
		'dvi' { LengthUnit.dvi }
		'dvmax' { LengthUnit.dvmax }
		'dvmin' { LengthUnit.dvmin }
		'dvw' { LengthUnit.dvw }
		'em' { LengthUnit.em }
		'ex' { LengthUnit.ex }
		'ic' { LengthUnit.ic }
		'in' { LengthUnit.in_ }
		'lh' { LengthUnit.lh }
		'lvb' { LengthUnit.lvb }
		'lvh' { LengthUnit.lvh }
		'lvi' { LengthUnit.lvi }
		'lvmax' { LengthUnit.lvmax }
		'lvmin' { LengthUnit.lvmin }
		'lvw' { LengthUnit.lvw }
		'mm' { LengthUnit.mm }
		'pc' { LengthUnit.pc }
		'pt' { LengthUnit.pt }
		'px' { LengthUnit.px }
		'q' { LengthUnit.q }
		'rcap' { LengthUnit.rcap }
		'rch' { LengthUnit.rch }
		'rem' { LengthUnit.rem }
		'rex' { LengthUnit.rex }
		'ric' { LengthUnit.ric }
		'rlh' { LengthUnit.rlh }
		'svb' { LengthUnit.svb }
		'svh' { LengthUnit.svh }
		'svi' { LengthUnit.svi }
		'svmax' { LengthUnit.svmax }
		'svmin' { LengthUnit.svmin }
		'svw' { LengthUnit.svw }
		'vb' { LengthUnit.vb }
		'vh' { LengthUnit.vh }
		'vi' { LengthUnit.vi }
		'vmax' { LengthUnit.vmax }
		'vmin' { LengthUnit.vmin }
		'vw' { LengthUnit.vw }
		else { none }
	}
}

pub fn canonical_angle_unit() AngleUnit {
	return .deg
}

pub fn canonical_frequency_unit() FrequencyUnit {
	return .hz
}

pub fn canonical_flex_unit() FlexUnit {
	return .fr
}

pub fn canonical_resolution_unit() ResolutionUnit {
	return .dppx
}

pub fn canonical_time_unit() TimeUnit {
	return .s
}

pub fn canonical_length_unit() LengthUnit {
	return .px
}

pub fn dimension_for_unit(unit string) ?DimensionType {
	if _ := string_to_angle_unit(unit) {
		return .angle
	}
	if _ := string_to_flex_unit(unit) {
		return .flex
	}
	if _ := string_to_frequency_unit(unit) {
		return .frequency
	}
	if _ := string_to_length_unit(unit) {
		return .length
	}
	if _ := string_to_resolution_unit(unit) {
		return .resolution
	}
	if _ := string_to_time_unit(unit) {
		return .time
	}
	return none
}

// --- NumericType ---

pub enum NumericBaseType {
	length
	angle
	time
	frequency
	resolution
	flex
	percent
}

pub struct NumericType {
pub mut:
	length_      ?int
	angle_       ?int
	time_        ?int
	frequency_   ?int
	resolution_  ?int
	flex_        ?int
	percent_     ?int
	percent_hint ?NumericBaseType
}

pub fn NumericType.new() NumericType {
	return NumericType{}
}

pub fn NumericType.with_type(type_ NumericBaseType, power int) NumericType {
	mut numeric_type := NumericType.new()
	numeric_type.set_exponent(type_, power)
	return numeric_type
}

pub fn NumericType.base_type_from_value_type(value_type ValueType) ?NumericBaseType {
	return match value_type {
		.angle { NumericBaseType.angle }
		.flex { NumericBaseType.flex }
		.frequency { NumericBaseType.frequency }
		.length { NumericBaseType.length }
		.percentage { NumericBaseType.percent }
		.resolution { NumericBaseType.resolution }
		.time { NumericBaseType.time }
		else { none }
	}
}

pub fn NumericType.base_type_name(base_type NumericBaseType) string {
	return match base_type {
		.length { 'length' }
		.angle { 'angle' }
		.time { 'time' }
		.frequency { 'frequency' }
		.resolution { 'resolution' }
		.flex { 'flex' }
		.percent { 'percent' }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-create-a-type
pub fn NumericType.create_from_unit(unit string) ?NumericType {
	// To create a type from a string unit, follow the appropriate branch of the following:

	// unit is "number"
	if to_ascii_lowercase(unit) == 'number' {
		// Return an empty map.
		return NumericType.new()
	}

	// unit is "percent"
	if to_ascii_lowercase(unit) == 'percent' {
		// Return [ "percent" -> 1 ].
		return NumericType.with_type(.percent, 1)
	}

	if dimension := dimension_for_unit(unit) {
		return match dimension {
			// unit is a <length> unit
			.length {
				NumericType.with_type(.length, 1)
			}
			// unit is an <angle> unit
			.angle {
				NumericType.with_type(.angle, 1)
			}
			// unit is a <time> unit
			.time {
				NumericType.with_type(.time, 1)
			}
			// unit is a <frequency> unit
			.frequency {
				NumericType.with_type(.frequency, 1)
			}
			// unit is a <resolution> unit
			.resolution {
				NumericType.with_type(.resolution, 1)
			}
			// unit is a <flex> unit
			.flex {
				NumericType.with_type(.flex, 1)
			}
		}
	}

	// anything else: return failure.
	return none
	// In all cases, the associated percent hint is null.
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-type-from-a-unit-map
pub fn NumericType.create_from_unit_map(unit_map map[string]int) ?NumericType {
	// To create a type from a unit map unit map:

	// 1. Let types be an initially empty list.
	mut types := []NumericType{}

	// 2. For each unit -> power in unit map:
	for unit, power in unit_map {
		// 1. Let type be the result of creating a type from unit.
		mut type_ := NumericType.create_from_unit(unit) or { return none }

		// 2. Set type's sole value to power.
		sole_type := type_.first_present_base_type() or { return none }
		type_.set_exponent(sole_type, power)

		// 3. Append type to types.
		types << type_
	}

	// 3. Return the result of multiplying all the items of types.
	if types.len == 0 {
		return none
	}
	mut result := types[0]
	for i := 1; i < types.len; i++ {
		if multiplied_type := result.multiplied_by(types[i]) {
			result = multiplied_type
		} else {
			return none
		}
	}
	return result
}

pub fn (t NumericType) exponent(type_ NumericBaseType) ?int {
	return match type_ {
		.length { t.length_ }
		.angle { t.angle_ }
		.time { t.time_ }
		.frequency { t.frequency_ }
		.resolution { t.resolution_ }
		.flex { t.flex_ }
		.percent { t.percent_ }
	}
}

pub fn (mut t NumericType) set_exponent(type_ NumericBaseType, exponent int) {
	match type_ {
		.length { t.length_ = exponent }
		.angle { t.angle_ = exponent }
		.time { t.time_ = exponent }
		.frequency { t.frequency_ = exponent }
		.resolution { t.resolution_ = exponent }
		.flex { t.flex_ = exponent }
		.percent { t.percent_ = exponent }
	}
}

fn numeric_base_types() []NumericBaseType {
	return [.length, .angle, .time, .frequency, .resolution, .flex, .percent]
}

fn (t NumericType) first_present_base_type() ?NumericBaseType {
	for base_type in numeric_base_types() {
		if _ := t.exponent(base_type) {
			return base_type
		}
	}
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-add-two-types
pub fn (t NumericType) added_to(other NumericType) ?NumericType {
	// To add two types type1 and type2, perform the following steps:

	// 1. Replace type1 with a fresh copy of type1, and type2 with a fresh copy of type2.
	//    Let finalType be a new type with an initially empty ordered map and an initially null percent hint.
	mut type1 := t
	mut type2 := other
	mut final_type := NumericType.new()

	// 2. If both type1 and type2 have non-null percent hints with different values
	if hint1 := type1.percent_hint {
		if hint2 := type2.percent_hint {
			if hint1 != hint2 {
				// The types cannot be added. Return failure.
				return none
			}
		}
	}
	//    If type1 has a non-null percent hint hint and type2 does not
	if hint1 := type1.percent_hint {
		if type2.percent_hint == none {
			// Apply the percent hint hint to type2.
			type2.apply_percent_hint(hint1)
		}
	}
	//    Vice versa if type2 has a non-null percent hint and type1 does not.
	else if hint2 := type2.percent_hint {
		if type1.percent_hint == none {
			type1.apply_percent_hint(hint2)
		}
	}
	// Otherwise, continue to the next step.

	// 3. If all the entries of type1 with non-zero values are contained in type2 with the same value, and vice-versa
	if type2.contains_all_the_non_zero_entries_of_other_with_the_same_value(type1)
		&& type1.contains_all_the_non_zero_entries_of_other_with_the_same_value(type2) {
		// Copy all of type1's entries to finalType, and then copy all of type2's entries to finalType that
		// finalType does not already contain. Set finalType's percent hint to type1's percent hint. Return finalType.
		final_type.copy_all_entries_from(type1, false)
		final_type.copy_all_entries_from(type2, true)
		final_type.percent_hint = type1.percent_hint
		return final_type
	}
	//    If type1 and/or type2 contain "percent" with a non-zero value,
	//    and type1 and/or type2 contain a key other than "percent" with a non-zero value
	any_percent_is_non_zero := optional_non_zero(type1.exponent(.percent))
		|| optional_non_zero(type2.exponent(.percent))
	any_non_percent_is_non_zero := type1.contains_a_key_other_than_percent_with_a_non_zero_value()
		|| type2.contains_a_key_other_than_percent_with_a_non_zero_value()
	if any_percent_is_non_zero && any_non_percent_is_non_zero {
		// For each base type other than "percent" hint:
		for hint in numeric_base_types() {
			if hint == .percent {
				continue
			}

			// 1. Provisionally apply the percent hint hint to both type1 and type2.
			mut provisional_type1 := type1
			provisional_type1.apply_percent_hint(hint)
			mut provisional_type2 := type2
			provisional_type2.apply_percent_hint(hint)

			// 2. If, afterwards, all the entries of type1 with non-zero values are contained in type2
			//    with the same value, and vice versa, then copy all of type1's entries to finalType,
			//    and then copy all of type2's entries to finalType that finalType does not already contain.
			//    Set finalType's percent hint to hint. Return finalType.
			if provisional_type2.contains_all_the_non_zero_entries_of_other_with_the_same_value(provisional_type1)
				&& provisional_type1.contains_all_the_non_zero_entries_of_other_with_the_same_value(provisional_type2) {
				final_type.copy_all_entries_from(provisional_type1, false)
				final_type.copy_all_entries_from(provisional_type2, true)
				final_type.percent_hint = hint
				return final_type
			}

			// 3. Otherwise, revert type1 and type2 to their state at the start of this loop.
			// NOTE: We did the modifications to provisional_type1/2 so this is a no-op.
		}

		// If the loop finishes without returning finalType, then the types cannot be added. Return failure.
		return none
	}
	// Otherwise, the types cannot be added. Return failure.
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-multiply-two-types
pub fn (t NumericType) multiplied_by(other NumericType) ?NumericType {
	// To multiply two types type1 and type2, perform the following steps:

	// 1. Replace type1 with a fresh copy of type1, and type2 with a fresh copy of type2.
	//    Let finalType be a new type with an initially empty ordered map and an initially null percent hint.
	mut type1 := t
	mut type2 := other
	mut final_type := NumericType.new()

	// 2. If both type1 and type2 have non-null percent hints with different values,
	//    the types cannot be multiplied. Return failure.
	if hint1 := type1.percent_hint {
		if hint2 := type2.percent_hint {
			if hint1 != hint2 {
				return none
			}
		}
	}

	// 3. If type1 has a non-null percent hint hint and type2 does not, apply the percent hint hint to type2.
	if hint1 := type1.percent_hint {
		if type2.percent_hint == none {
			type2.apply_percent_hint(hint1)
		}
	}
	//    Vice versa if type2 has a non-null percent hint and type1 does not.
	else if hint2 := type2.percent_hint {
		if type1.percent_hint == none {
			type1.apply_percent_hint(hint2)
		}
	}

	// 4. Copy all of type1's entries to finalType, then for each baseType -> power of type2:
	final_type.copy_all_entries_from(type1, false)
	for base_type in numeric_base_types() {
		power := type2.exponent(base_type) or { continue }

		// 1. If finalType[baseType] exists, increment its value by power.
		if exponent := final_type.exponent(base_type) {
			final_type.set_exponent(base_type, exponent + power)
		}
		// 2. Otherwise, set finalType[baseType] to power.
		else {
			final_type.set_exponent(base_type, power)
		}
	}
	//    Set finalType's percent hint to type1's percent hint.
	final_type.percent_hint = type1.percent_hint

	// 5. Return finalType.
	return final_type
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-invert-a-type
pub fn (t NumericType) inverted() NumericType {
	// To invert a type type, perform the following steps:

	// 1. Let result be a new type with an initially empty ordered map and a percent hint matching that of type.
	mut result := NumericType.new()
	result.percent_hint = t.percent_hint

	// 2. For each unit -> exponent of type, set result[unit] to (-1 * exponent).
	for base_type in numeric_base_types() {
		power := t.exponent(base_type) or { continue }
		result.set_exponent(base_type, -1 * power)
	}

	// 3. Return result.
	return result
}

// https://drafts.csswg.org/css-values-4/#css-consistent-typec
pub fn (t NumericType) has_consistent_type_with(other NumericType) bool {
	// Two or more calculations have a consistent type if adding the types does not result in failure.
	return t.added_to(other) != none
}

// https://drafts.csswg.org/css-values-4/#css-consistent-typec
pub fn (t NumericType) consistent_type(other NumericType) ?NumericType {
	// The consistent type is the result of the type addition.
	return t.added_to(other)
}

// https://drafts.csswg.org/css-values-4/#css-make-a-type-consistent
pub fn (t NumericType) made_consistent_with(input NumericType) ?NumericType {
	mut base := t

	// 1. If both base and input have different non-null percent hints, they cannot be made consistent. Return failure.
	if base_hint := base.percent_hint {
		if input_hint := input.percent_hint {
			if base_hint != input_hint {
				return none
			}
		}
	}

	// 2. If base has a null percent hint set base's percent hint to input's percent hint.
	if base.percent_hint == none {
		base.percent_hint = input.percent_hint
	}

	// 3. Return base.
	return base
}

// https://drafts.css-houdini.org/css-typed-om-1/#apply-the-percent-hint
pub fn (mut t NumericType) apply_percent_hint(hint NumericBaseType) {
	// To apply the percent hint hint to a type without a percent hint, perform the following steps:
	if t.percent_hint != none {
		return
	}

	// 1. Set type's percent hint to hint.
	t.percent_hint = hint

	// 2. If type does not contain hint, set type[hint] to 0.
	if t.exponent(hint) == none {
		t.set_exponent(hint, 0)
	}

	// 3. If hint is anything other than "percent", and type contains "percent",
	//    add type["percent"] to type[hint], then set type["percent"] to 0.
	if hint != .percent {
		if percent := t.exponent(.percent) {
			hint_exponent := t.exponent(hint) or { 0 }
			t.set_exponent(hint, percent + hint_exponent)
			t.set_exponent(.percent, 0)
		}
	}

	// 4. Return type.
}

fn (t NumericType) contains_all_the_non_zero_entries_of_other_with_the_same_value(other NumericType) bool {
	for base_type in numeric_base_types() {
		other_exponent := other.exponent(base_type) or { continue }
		this_exponent := t.exponent(base_type) or { 0 }
		if other_exponent != 0 && this_exponent != other_exponent {
			return false
		}
	}
	return true
}

fn (t NumericType) contains_a_key_other_than_percent_with_a_non_zero_value() bool {
	for base_type in numeric_base_types() {
		if base_type == .percent {
			continue
		}
		if exponent := t.exponent(base_type) {
			if exponent != 0 {
				return true
			}
		}
	}
	return false
}

fn (mut t NumericType) copy_all_entries_from(other NumericType, skip_if_already_present bool) {
	for base_type in numeric_base_types() {
		exponent := other.exponent(base_type) or { continue }
		if skip_if_already_present && t.exponent(base_type) != none {
			continue
		}
		t.set_exponent(base_type, exponent)
	}
}

pub fn (t NumericType) entry_with_value_1_while_all_others_are_0() ?NumericBaseType {
	mut result := ?NumericBaseType(none)
	for base_type in numeric_base_types() {
		type_exponent := t.exponent(base_type)
		if optional_equals(type_exponent, 1) {
			if result != none {
				return none
			}
			result = base_type
		} else if exponent := type_exponent {
			if exponent != 0 {
				return none
			}
		}
	}
	return result
}

fn numeric_base_type_matches_value_type(base_type NumericBaseType, value_type ValueType) bool {
	return match base_type {
		.length { value_type == .length }
		.angle { value_type == .angle }
		.time { value_type == .time }
		.frequency { value_type == .frequency }
		.resolution { value_type == .resolution }
		.flex { value_type == .flex }
		.percent { value_type == .percentage }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
fn (t NumericType) matches_dimension_base(type_ NumericBaseType, percentages_resolve_as ?ValueType) bool {
	// A type matches <length> if its only non-zero entry is [ "length" -> 1 ].
	// Similarly for <angle>, <time>, <frequency>, <resolution>, and <flex>.
	entry := t.entry_with_value_1_while_all_others_are_0() or { return false }
	if entry != type_ {
		return false
	}

	// If the context in which the value is used allows <percentage> values, and those percentages are resolved
	// against another type, then for the type to be considered matching it must either have a null percent hint,
	// or the percent hint must match the other type.
	if resolves_as := percentages_resolve_as {
		if hint := t.percent_hint {
			return numeric_base_type_matches_value_type(hint, resolves_as)
		}
		return true
	}

	// If the context does not allow <percentage> values to be mixed with <length>/etc values (or does not allow
	// <percentage> values at all, such as border-width), then for the type to be considered matching the percent
	// hint must be null.
	return t.percent_hint == none
}

pub fn (t NumericType) matches_angle(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.angle, percentages_resolve_as)
}

pub fn (t NumericType) matches_angle_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.angle, percentages_resolve_as)
}

pub fn (t NumericType) matches_flex(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.flex, percentages_resolve_as)
}

pub fn (t NumericType) matches_frequency(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.frequency, percentages_resolve_as)
}

pub fn (t NumericType) matches_frequency_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.frequency, percentages_resolve_as)
}

pub fn (t NumericType) matches_length(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.length, percentages_resolve_as)
}

pub fn (t NumericType) matches_length_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.length, percentages_resolve_as)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
pub fn (t NumericType) matches_percentage() bool {
	// A type matches <percentage> if its only non-zero entry is [ "percent" -> 1 ], and its percent hint is either
	// null or "percent".
	if hint := t.percent_hint {
		if hint != .percent {
			return false
		}
	}

	entry := t.entry_with_value_1_while_all_others_are_0() or { return false }
	return entry == NumericBaseType.percent
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
fn (t NumericType) matches_dimension_percentage(type_ NumericBaseType, percentages_resolve_as ?ValueType) bool {
	// A type matches <length-percentage> if it matches <length> or matches <percentage>.
	// Same for <angle-percentage>, <time-percentage>, etc.
	return t.matches_percentage() || t.matches_dimension_base(type_, percentages_resolve_as)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericvalue-match
pub fn (t NumericType) matches_number(percentages_resolve_as ?ValueType) bool {
	// A type matches <number> if it has no non-zero entries.
	for base_type in numeric_base_types() {
		if exponent := t.exponent(base_type) {
			if exponent != 0 {
				return false
			}
		}
	}

	// If the context in which the value is used allows <percentage> values, and those percentages are resolved
	// against a type other than <number>, then for the type to be considered matching the percent hint must
	// either be null or match the other type.
	if resolves_as := percentages_resolve_as {
		if resolves_as != .number {
			if hint := t.percent_hint {
				return numeric_base_type_matches_value_type(hint, resolves_as)
			}
			return true
		}
	}

	// If the context allows <percentage> values, but either does not resolve them against another type or resolves
	// them against a <number>, then for the type to be considered matching the percent hint must either be null
	// or "percent".
	if resolves_as := percentages_resolve_as {
		if resolves_as != .number {
			return true
		}
		if hint := t.percent_hint {
			return hint == .percent
		}
		return true
	}

	// If the context does not allow <percentage> values, then for the type to be considered matching the percent
	// hint must be null.
	return t.percent_hint == none
}

pub fn (t NumericType) matches_resolution(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.resolution, percentages_resolve_as)
}

pub fn (t NumericType) matches_time(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_base(.time, percentages_resolve_as)
}

pub fn (t NumericType) matches_time_percentage(percentages_resolve_as ?ValueType) bool {
	return t.matches_dimension_percentage(.time, percentages_resolve_as)
}

pub fn (t NumericType) matches_dimension() bool {
	// This is not a spec algorithm.
	// A type should match `<dimension>` if there are no non-zero entries,
	// or it has a single non-zero entry (other than percent) which is equal to 1.

	mut number_of_one_exponents := 0
	for base_type in numeric_base_types() {
		type_exponent := t.exponent(base_type) or { continue }

		if type_exponent == 1 {
			if base_type == .percent {
				return false
			}
			number_of_one_exponents++
		} else if type_exponent != 0 {
			return false
		}
	}

	return number_of_one_exponents == 0 || number_of_one_exponents == 1
}

pub fn (t NumericType) dump() string {
	mut result := '{ hint: '
	if hint := t.percent_hint {
		result += NumericType.base_type_name(hint)
	} else {
		result += 'none'
	}

	for base_type in numeric_base_types() {
		if type_exponent := t.exponent(base_type) {
			result += ', "${NumericType.base_type_name(base_type)}" -> ${type_exponent}'
		}
	}

	result += ' }'
	return result
}

pub fn (t NumericType) to_string() string {
	return t.dump()
}

fn optional_non_zero(value ?int) bool {
	if actual := value {
		return actual != 0
	}
	return false
}

fn optional_equals(value ?int, expected int) bool {
	if actual := value {
		return actual == expected
	}
	return false
}

// https://drafts.css-houdini.org/css-typed-om-1/#product-of-two-unit-maps
pub fn product_of_two_unit_maps(units1 map[string]int, units2 map[string]int) map[string]int {
	// 1. Let result be a copy of units1.
	mut result := units1.clone()

	// 2. For each unit -> power in units2:
	for unit, power in units2 {
		// 1. If result[unit] exists, increment result[unit] by power.
		// 2. Otherwise, set result[unit] to power.
		result[unit] = result[unit] + power
	}

	// 3. Return result.
	return result
}

// --- Keywords ---

pub enum Keyword {
	invalid
	inherit
	initial
	revert
	revert_layer
	unset
	all
	auto_add
	auto
	none_
	visible
	hidden
	dotted
	dashed
	solid
	double_
	groove
	ridge
	inset
	outset
	clip
	no_clip
	scroll
	repeat
	no_repeat
	repeat_x
	repeat_y
	fill
	stroke
	markers
	contain
	cover
	scale_down
	multiply
	screen
	overlay
	darken
	lighten
	color_dodge
	color_burn
	hard_light
	soft_light
	difference
	exclusion
	hue
	saturation
	color
	luminosity
	plus_darker
	plus_lighter
	inline_start
	inline_end
	top
	bottom
	collapse
	show
	hide
	ltr
	rtl
	embed
	isolate
	bidi_override
	isolate_override
	plaintext
	nonzero
	evenodd
	linearrgb
	srgb
	luminance
	alpha
	match_source
	optimizespeed
	crispedges
	geometricprecision
	butt
	miter
	start
	middle
	end_
	center
	justify
	match_parent
	libweb_center
	libweb_inherit_or_center
	libweb_left
	libweb_right
	inter_word
	inter_character
	ellipsis
	optimizelegibility
	capitalize
	full_size_kana
	full_width
	lowercase
	math_auto
	uppercase
	nowrap
	wrap
	balance
	stable
	pretty
	discard
	preserve
	preserve_breaks
	preserve_spaces
	break_spaces
	discard_before
	discard_after
	discard_inner
	keep_all
	break_all
	break_word
	anywhere
	small_caps
	all_small_caps
	petite_caps
	all_petite_caps
	unicase
	titling_caps
	emoji
	unicode
	sub
	super
	flex_start
	flex_end
	space_between
	space_around
	space_evenly
	self_start
	self_end
	stretch
	baseline
	safe
	unsafe_
	legacy
	row
	row_reverse
	column
	column_reverse
	wrap_reverse
	button
	checkbox
	listbox
	menulist
	meter
	menulist_button
	push_button
	progress_bar
	radio
	searchfield
	slider_horizontal
	square_button
	textarea
	textfield
	crisp_edges
	high_quality
	pixelated
	smooth
	optimizequality
	fill_box
	stroke_box
	view_box
	manipulation
	pan_down
	pan_left
	pan_right
	pan_up
	pan_x
	pan_y
	horizontal_tb
	vertical_rl
	vertical_lr
	sideways_rl
	sideways_lr
	thin
	horizontal
	vertical
	block
	inline_
	x
	y
	strict
	content
	size
	inline_size
	layout
	style
	paint
	scroll_state
	separate
	border_box
	padding_box
	content_box
	inside
	outside
	flat
	preserve_3d
	text
	absolute
	fixed
	local
	relative
	static_
	sticky
	normal
	from_font
	compact
	hanging
	each_line
	underline
	overline
	line_through
	blink
	spelling_error
	grammar_error
	wavy
	bold
	bolder
	lighter
	italic
	linear
	ease
	ease_in
	ease_out
	ease_in_out
	left
	right
	oblique
	round
	space
	scoop
	bevel
	notch
	square
	squircle
	infinity
	negative_infinity
	allow_discrete
	reverse
	alternate
	alternate_reverse
	running
	paused
	forwards
	backwards
	both
	infinite
	replace
	add
	subtract
	intersect
	exclude
	accumulate
	light
	dark
	always
	anchors_valid
	anchors_visible
	no_overflow
	accentcolor
	accentcolortext
	activeborder
	activecaption
	activetext
	appworkspace
	background
	buttonborder
	buttonface
	buttonhighlight
	buttonshadow
	buttontext
	canvas
	canvastext
	captiontext
	currentcolor
	field
	fieldtext
	graytext
	highlight
	highlighttext
	inactiveborder
	inactivecaption
	inactivecaptiontext
	infobackground
	infotext
	libweb_buttonfacedisabled
	libweb_buttonfacehover
	libweb_link
	libweb_palette_active_link
	libweb_palette_active_window_border1
	libweb_palette_active_window_border2
	libweb_palette_active_window_title
	libweb_palette_base
	libweb_palette_base_text
	libweb_palette_button
	libweb_palette_button_text
	libweb_palette_desktop_background
	libweb_palette_focus_outline
	libweb_palette_highlight_window_border1
	libweb_palette_highlight_window_border2
	libweb_palette_highlight_window_title
	libweb_palette_hover_highlight
	libweb_palette_inactive_selection
	libweb_palette_inactive_selection_text
	libweb_palette_inactive_window_border1
	libweb_palette_inactive_window_border2
	libweb_palette_inactive_window_title
	libweb_palette_link
	libweb_palette_menu_base
	libweb_palette_menu_base_text
	libweb_palette_menu_selection
	libweb_palette_menu_selection_text
	libweb_palette_menu_stripe
	libweb_palette_moving_window_border1
	libweb_palette_moving_window_border2
	libweb_palette_moving_window_title
	libweb_palette_rubber_band_border
	libweb_palette_rubber_band_fill
	libweb_palette_ruler
	libweb_palette_ruler_active_text
	libweb_palette_ruler_border
	libweb_palette_ruler_inactive_text
	libweb_palette_selection
	libweb_palette_selection_text
	libweb_palette_syntax_comment
	libweb_palette_syntax_control_keyword
	libweb_palette_syntax_identifier
	libweb_palette_syntax_keyword
	libweb_palette_syntax_number
	libweb_palette_syntax_operator
	libweb_palette_syntax_preprocessor_statement
	libweb_palette_syntax_preprocessor_value
	libweb_palette_syntax_punctuation
	libweb_palette_syntax_string
	libweb_palette_syntax_type
	libweb_palette_text_cursor
	libweb_palette_threed_highlight
	libweb_palette_threed_shadow1
	libweb_palette_threed_shadow2
	libweb_palette_visited_link
	libweb_palette_window
	libweb_palette_window_text
	linktext
	mark
	marktext
	menu
	menutext
	scrollbar
	selecteditem
	selecteditemtext
	threeddarkshadow
	threedface
	threedhighlight
	threedlightshadow
	threedshadow
	visitedtext
	window
	windowframe
	windowtext
	text_bottom
	alphabetic
	ideographic
	central
	mathematical
	text_top
}

pub fn (keyword Keyword) is_css_wide_keyword() bool {
	return keyword in [.inherit, .initial, .revert, .unset, .revert_layer]
}

pub fn is_css_wide_keyword_string(value string) bool {
	return match to_ascii_lowercase(value) {
		'inherit', 'initial', 'revert', 'revert-layer', 'unset' { true }
		else { false }
	}
}

pub fn string_from_keyword(keyword Keyword) string {
	return match keyword {
		.invalid { '' }
		.inherit { 'inherit' }
		.initial { 'initial' }
		.revert { 'revert' }
		.revert_layer { 'revert-layer' }
		.unset { 'unset' }
		.all { 'all' }
		.auto_add { 'auto-add' }
		.auto { 'auto' }
		.none_ { 'none' }
		.visible { 'visible' }
		.hidden { 'hidden' }
		.dotted { 'dotted' }
		.dashed { 'dashed' }
		.solid { 'solid' }
		.double_ { 'double' }
		.groove { 'groove' }
		.ridge { 'ridge' }
		.inset { 'inset' }
		.outset { 'outset' }
		.clip { 'clip' }
		.no_clip { 'no-clip' }
		.scroll { 'scroll' }
		.repeat { 'repeat' }
		.no_repeat { 'no-repeat' }
		.repeat_x { 'repeat-x' }
		.repeat_y { 'repeat-y' }
		.fill { 'fill' }
		.stroke { 'stroke' }
		.markers { 'markers' }
		.contain { 'contain' }
		.cover { 'cover' }
		.scale_down { 'scale-down' }
		.multiply { 'multiply' }
		.screen { 'screen' }
		.overlay { 'overlay' }
		.darken { 'darken' }
		.lighten { 'lighten' }
		.color_dodge { 'color-dodge' }
		.color_burn { 'color-burn' }
		.hard_light { 'hard-light' }
		.soft_light { 'soft-light' }
		.difference { 'difference' }
		.exclusion { 'exclusion' }
		.hue { 'hue' }
		.saturation { 'saturation' }
		.color { 'color' }
		.luminosity { 'luminosity' }
		.plus_darker { 'plus-darker' }
		.plus_lighter { 'plus-lighter' }
		.inline_start { 'inline-start' }
		.inline_end { 'inline-end' }
		.top { 'top' }
		.bottom { 'bottom' }
		.collapse { 'collapse' }
		.show { 'show' }
		.hide { 'hide' }
		.ltr { 'ltr' }
		.rtl { 'rtl' }
		.embed { 'embed' }
		.isolate { 'isolate' }
		.bidi_override { 'bidi-override' }
		.isolate_override { 'isolate-override' }
		.plaintext { 'plaintext' }
		.nonzero { 'nonzero' }
		.evenodd { 'evenodd' }
		.linearrgb { 'linearrgb' }
		.srgb { 'srgb' }
		.luminance { 'luminance' }
		.alpha { 'alpha' }
		.match_source { 'match-source' }
		.optimizespeed { 'optimizespeed' }
		.crispedges { 'crispedges' }
		.geometricprecision { 'geometricprecision' }
		.butt { 'butt' }
		.miter { 'miter' }
		.start { 'start' }
		.middle { 'middle' }
		.end_ { 'end' }
		.center { 'center' }
		.justify { 'justify' }
		.match_parent { 'match-parent' }
		.libweb_center { '-libweb-center' }
		.libweb_inherit_or_center { '-libweb-inherit-or-center' }
		.libweb_left { '-libweb-left' }
		.libweb_right { '-libweb-right' }
		.inter_word { 'inter-word' }
		.inter_character { 'inter-character' }
		.ellipsis { 'ellipsis' }
		.optimizelegibility { 'optimizelegibility' }
		.capitalize { 'capitalize' }
		.full_size_kana { 'full-size-kana' }
		.full_width { 'full-width' }
		.lowercase { 'lowercase' }
		.math_auto { 'math-auto' }
		.uppercase { 'uppercase' }
		.nowrap { 'nowrap' }
		.wrap { 'wrap' }
		.balance { 'balance' }
		.stable { 'stable' }
		.pretty { 'pretty' }
		.discard { 'discard' }
		.preserve { 'preserve' }
		.preserve_breaks { 'preserve-breaks' }
		.preserve_spaces { 'preserve-spaces' }
		.break_spaces { 'break-spaces' }
		.discard_before { 'discard-before' }
		.discard_after { 'discard-after' }
		.discard_inner { 'discard-inner' }
		.keep_all { 'keep-all' }
		.break_all { 'break-all' }
		.break_word { 'break-word' }
		.anywhere { 'anywhere' }
		.small_caps { 'small-caps' }
		.all_small_caps { 'all-small-caps' }
		.petite_caps { 'petite-caps' }
		.all_petite_caps { 'all-petite-caps' }
		.unicase { 'unicase' }
		.titling_caps { 'titling-caps' }
		.emoji { 'emoji' }
		.unicode { 'unicode' }
		.sub { 'sub' }
		.super { 'super' }
		.flex_start { 'flex-start' }
		.flex_end { 'flex-end' }
		.space_between { 'space-between' }
		.space_around { 'space-around' }
		.space_evenly { 'space-evenly' }
		.self_start { 'self-start' }
		.self_end { 'self-end' }
		.stretch { 'stretch' }
		.baseline { 'baseline' }
		.safe { 'safe' }
		.unsafe_ { 'unsafe' }
		.legacy { 'legacy' }
		.row { 'row' }
		.row_reverse { 'row-reverse' }
		.column { 'column' }
		.column_reverse { 'column-reverse' }
		.wrap_reverse { 'wrap-reverse' }
		.button { 'button' }
		.checkbox { 'checkbox' }
		.listbox { 'listbox' }
		.menulist { 'menulist' }
		.meter { 'meter' }
		.menulist_button { 'menulist-button' }
		.push_button { 'push-button' }
		.progress_bar { 'progress-bar' }
		.radio { 'radio' }
		.searchfield { 'searchfield' }
		.slider_horizontal { 'slider-horizontal' }
		.square_button { 'square-button' }
		.textarea { 'textarea' }
		.textfield { 'textfield' }
		.crisp_edges { 'crisp-edges' }
		.high_quality { 'high-quality' }
		.pixelated { 'pixelated' }
		.smooth { 'smooth' }
		.optimizequality { 'optimizequality' }
		.fill_box { 'fill-box' }
		.stroke_box { 'stroke-box' }
		.view_box { 'view-box' }
		.manipulation { 'manipulation' }
		.pan_down { 'pan-down' }
		.pan_left { 'pan-left' }
		.pan_right { 'pan-right' }
		.pan_up { 'pan-up' }
		.pan_x { 'pan-x' }
		.pan_y { 'pan-y' }
		.horizontal_tb { 'horizontal-tb' }
		.vertical_rl { 'vertical-rl' }
		.vertical_lr { 'vertical-lr' }
		.sideways_rl { 'sideways-rl' }
		.sideways_lr { 'sideways-lr' }
		.thin { 'thin' }
		.horizontal { 'horizontal' }
		.vertical { 'vertical' }
		.block { 'block' }
		.inline_ { 'inline' }
		.x { 'x' }
		.y { 'y' }
		.strict { 'strict' }
		.content { 'content' }
		.size { 'size' }
		.inline_size { 'inline-size' }
		.layout { 'layout' }
		.style { 'style' }
		.paint { 'paint' }
		.scroll_state { 'scroll-state' }
		.separate { 'separate' }
		.border_box { 'border-box' }
		.padding_box { 'padding-box' }
		.content_box { 'content-box' }
		.inside { 'inside' }
		.outside { 'outside' }
		.flat { 'flat' }
		.preserve_3d { 'preserve-3d' }
		.text { 'text' }
		.absolute { 'absolute' }
		.fixed { 'fixed' }
		.local { 'local' }
		.relative { 'relative' }
		.static_ { 'static' }
		.sticky { 'sticky' }
		.normal { 'normal' }
		.from_font { 'from-font' }
		.compact { 'compact' }
		.hanging { 'hanging' }
		.each_line { 'each-line' }
		.underline { 'underline' }
		.overline { 'overline' }
		.line_through { 'line-through' }
		.blink { 'blink' }
		.spelling_error { 'spelling-error' }
		.grammar_error { 'grammar-error' }
		.wavy { 'wavy' }
		.bold { 'bold' }
		.bolder { 'bolder' }
		.lighter { 'lighter' }
		.italic { 'italic' }
		.linear { 'linear' }
		.ease { 'ease' }
		.ease_in { 'ease-in' }
		.ease_out { 'ease-out' }
		.ease_in_out { 'ease-in-out' }
		.left { 'left' }
		.right { 'right' }
		.oblique { 'oblique' }
		.round { 'round' }
		.space { 'space' }
		.scoop { 'scoop' }
		.bevel { 'bevel' }
		.notch { 'notch' }
		.square { 'square' }
		.squircle { 'squircle' }
		.infinity { 'infinity' }
		.negative_infinity { '-infinity' }
		.allow_discrete { 'allow-discrete' }
		.reverse { 'reverse' }
		.alternate { 'alternate' }
		.alternate_reverse { 'alternate-reverse' }
		.running { 'running' }
		.paused { 'paused' }
		.forwards { 'forwards' }
		.backwards { 'backwards' }
		.both { 'both' }
		.infinite { 'infinite' }
		.replace { 'replace' }
		.add { 'add' }
		.subtract { 'subtract' }
		.intersect { 'intersect' }
		.exclude { 'exclude' }
		.accumulate { 'accumulate' }
		.light { 'light' }
		.dark { 'dark' }
		.always { 'always' }
		.anchors_valid { 'anchors-valid' }
		.anchors_visible { 'anchors-visible' }
		.no_overflow { 'no-overflow' }
		.accentcolor { 'accentcolor' }
		.accentcolortext { 'accentcolortext' }
		.activeborder { 'activeborder' }
		.activecaption { 'activecaption' }
		.activetext { 'activetext' }
		.appworkspace { 'appworkspace' }
		.background { 'background' }
		.buttonborder { 'buttonborder' }
		.buttonface { 'buttonface' }
		.buttonhighlight { 'buttonhighlight' }
		.buttonshadow { 'buttonshadow' }
		.buttontext { 'buttontext' }
		.canvas { 'canvas' }
		.canvastext { 'canvastext' }
		.captiontext { 'captiontext' }
		.currentcolor { 'currentcolor' }
		.field { 'field' }
		.fieldtext { 'fieldtext' }
		.graytext { 'graytext' }
		.highlight { 'highlight' }
		.highlighttext { 'highlighttext' }
		.inactiveborder { 'inactiveborder' }
		.inactivecaption { 'inactivecaption' }
		.inactivecaptiontext { 'inactivecaptiontext' }
		.infobackground { 'infobackground' }
		.infotext { 'infotext' }
		.libweb_buttonfacedisabled { '-libweb-buttonfacedisabled' }
		.libweb_buttonfacehover { '-libweb-buttonfacehover' }
		.libweb_link { '-libweb-link' }
		.libweb_palette_active_link { '-libweb-palette-active-link' }
		.libweb_palette_active_window_border1 { '-libweb-palette-active-window-border1' }
		.libweb_palette_active_window_border2 { '-libweb-palette-active-window-border2' }
		.libweb_palette_active_window_title { '-libweb-palette-active-window-title' }
		.libweb_palette_base { '-libweb-palette-base' }
		.libweb_palette_base_text { '-libweb-palette-base-text' }
		.libweb_palette_button { '-libweb-palette-button' }
		.libweb_palette_button_text { '-libweb-palette-button-text' }
		.libweb_palette_desktop_background { '-libweb-palette-desktop-background' }
		.libweb_palette_focus_outline { '-libweb-palette-focus-outline' }
		.libweb_palette_highlight_window_border1 { '-libweb-palette-highlight-window-border1' }
		.libweb_palette_highlight_window_border2 { '-libweb-palette-highlight-window-border2' }
		.libweb_palette_highlight_window_title { '-libweb-palette-highlight-window-title' }
		.libweb_palette_hover_highlight { '-libweb-palette-hover-highlight' }
		.libweb_palette_inactive_selection { '-libweb-palette-inactive-selection' }
		.libweb_palette_inactive_selection_text { '-libweb-palette-inactive-selection-text' }
		.libweb_palette_inactive_window_border1 { '-libweb-palette-inactive-window-border1' }
		.libweb_palette_inactive_window_border2 { '-libweb-palette-inactive-window-border2' }
		.libweb_palette_inactive_window_title { '-libweb-palette-inactive-window-title' }
		.libweb_palette_link { '-libweb-palette-link' }
		.libweb_palette_menu_base { '-libweb-palette-menu-base' }
		.libweb_palette_menu_base_text { '-libweb-palette-menu-base-text' }
		.libweb_palette_menu_selection { '-libweb-palette-menu-selection' }
		.libweb_palette_menu_selection_text { '-libweb-palette-menu-selection-text' }
		.libweb_palette_menu_stripe { '-libweb-palette-menu-stripe' }
		.libweb_palette_moving_window_border1 { '-libweb-palette-moving-window-border1' }
		.libweb_palette_moving_window_border2 { '-libweb-palette-moving-window-border2' }
		.libweb_palette_moving_window_title { '-libweb-palette-moving-window-title' }
		.libweb_palette_rubber_band_border { '-libweb-palette-rubber-band-border' }
		.libweb_palette_rubber_band_fill { '-libweb-palette-rubber-band-fill' }
		.libweb_palette_ruler { '-libweb-palette-ruler' }
		.libweb_palette_ruler_active_text { '-libweb-palette-ruler-active-text' }
		.libweb_palette_ruler_border { '-libweb-palette-ruler-border' }
		.libweb_palette_ruler_inactive_text { '-libweb-palette-ruler-inactive-text' }
		.libweb_palette_selection { '-libweb-palette-selection' }
		.libweb_palette_selection_text { '-libweb-palette-selection-text' }
		.libweb_palette_syntax_comment { '-libweb-palette-syntax-comment' }
		.libweb_palette_syntax_control_keyword { '-libweb-palette-syntax-control-keyword' }
		.libweb_palette_syntax_identifier { '-libweb-palette-syntax-identifier' }
		.libweb_palette_syntax_keyword { '-libweb-palette-syntax-keyword' }
		.libweb_palette_syntax_number { '-libweb-palette-syntax-number' }
		.libweb_palette_syntax_operator { '-libweb-palette-syntax-operator' }
		.libweb_palette_syntax_preprocessor_statement { '-libweb-palette-syntax-preprocessor-statement' }
		.libweb_palette_syntax_preprocessor_value { '-libweb-palette-syntax-preprocessor-value' }
		.libweb_palette_syntax_punctuation { '-libweb-palette-syntax-punctuation' }
		.libweb_palette_syntax_string { '-libweb-palette-syntax-string' }
		.libweb_palette_syntax_type { '-libweb-palette-syntax-type' }
		.libweb_palette_text_cursor { '-libweb-palette-text-cursor' }
		.libweb_palette_threed_highlight { '-libweb-palette-threed-highlight' }
		.libweb_palette_threed_shadow1 { '-libweb-palette-threed-shadow1' }
		.libweb_palette_threed_shadow2 { '-libweb-palette-threed-shadow2' }
		.libweb_palette_visited_link { '-libweb-palette-visited-link' }
		.libweb_palette_window { '-libweb-palette-window' }
		.libweb_palette_window_text { '-libweb-palette-window-text' }
		.linktext { 'linktext' }
		.mark { 'mark' }
		.marktext { 'marktext' }
		.menu { 'menu' }
		.menutext { 'menutext' }
		.scrollbar { 'scrollbar' }
		.selecteditem { 'selecteditem' }
		.selecteditemtext { 'selecteditemtext' }
		.threeddarkshadow { 'threeddarkshadow' }
		.threedface { 'threedface' }
		.threedhighlight { 'threedhighlight' }
		.threedlightshadow { 'threedlightshadow' }
		.threedshadow { 'threedshadow' }
		.visitedtext { 'visitedtext' }
		.window { 'window' }
		.windowframe { 'windowframe' }
		.windowtext { 'windowtext' }
		.text_bottom { 'text-bottom' }
		.alphabetic { 'alphabetic' }
		.ideographic { 'ideographic' }
		.central { 'central' }
		.mathematical { 'mathematical' }
		.text_top { 'text-top' }
	}
}

pub fn keyword_from_string(input string) ?Keyword {
	return match to_ascii_lowercase(input) {
		'inherit' { Keyword.inherit }
		'initial' { Keyword.initial }
		'revert' { Keyword.revert }
		'revert-layer' { Keyword.revert_layer }
		'unset' { Keyword.unset }
		'all' { Keyword.all }
		'auto-add' { Keyword.auto_add }
		'auto' { Keyword.auto }
		'none' { Keyword.none_ }
		'visible' { Keyword.visible }
		'hidden' { Keyword.hidden }
		'dotted' { Keyword.dotted }
		'dashed' { Keyword.dashed }
		'solid' { Keyword.solid }
		'double' { Keyword.double_ }
		'groove' { Keyword.groove }
		'ridge' { Keyword.ridge }
		'inset' { Keyword.inset }
		'outset' { Keyword.outset }
		'clip' { Keyword.clip }
		'no-clip' { Keyword.no_clip }
		'scroll' { Keyword.scroll }
		'repeat' { Keyword.repeat }
		'no-repeat' { Keyword.no_repeat }
		'repeat-x' { Keyword.repeat_x }
		'repeat-y' { Keyword.repeat_y }
		'fill' { Keyword.fill }
		'stroke' { Keyword.stroke }
		'markers' { Keyword.markers }
		'contain' { Keyword.contain }
		'cover' { Keyword.cover }
		'scale-down' { Keyword.scale_down }
		'multiply' { Keyword.multiply }
		'screen' { Keyword.screen }
		'overlay' { Keyword.overlay }
		'darken' { Keyword.darken }
		'lighten' { Keyword.lighten }
		'color-dodge' { Keyword.color_dodge }
		'color-burn' { Keyword.color_burn }
		'hard-light' { Keyword.hard_light }
		'soft-light' { Keyword.soft_light }
		'difference' { Keyword.difference }
		'exclusion' { Keyword.exclusion }
		'hue' { Keyword.hue }
		'saturation' { Keyword.saturation }
		'color' { Keyword.color }
		'luminosity' { Keyword.luminosity }
		'plus-darker' { Keyword.plus_darker }
		'plus-lighter' { Keyword.plus_lighter }
		'inline-start' { Keyword.inline_start }
		'inline-end' { Keyword.inline_end }
		'top' { Keyword.top }
		'bottom' { Keyword.bottom }
		'collapse' { Keyword.collapse }
		'show' { Keyword.show }
		'hide' { Keyword.hide }
		'ltr' { Keyword.ltr }
		'rtl' { Keyword.rtl }
		'embed' { Keyword.embed }
		'isolate' { Keyword.isolate }
		'bidi-override' { Keyword.bidi_override }
		'isolate-override' { Keyword.isolate_override }
		'plaintext' { Keyword.plaintext }
		'nonzero' { Keyword.nonzero }
		'evenodd' { Keyword.evenodd }
		'linearrgb' { Keyword.linearrgb }
		'srgb' { Keyword.srgb }
		'luminance' { Keyword.luminance }
		'alpha' { Keyword.alpha }
		'match-source' { Keyword.match_source }
		'optimizespeed' { Keyword.optimizespeed }
		'crispedges' { Keyword.crispedges }
		'geometricprecision' { Keyword.geometricprecision }
		'butt' { Keyword.butt }
		'miter' { Keyword.miter }
		'start' { Keyword.start }
		'middle' { Keyword.middle }
		'end' { Keyword.end_ }
		'center' { Keyword.center }
		'justify' { Keyword.justify }
		'match-parent' { Keyword.match_parent }
		'-libweb-center' { Keyword.libweb_center }
		'-libweb-inherit-or-center' { Keyword.libweb_inherit_or_center }
		'-libweb-left' { Keyword.libweb_left }
		'-libweb-right' { Keyword.libweb_right }
		'inter-word' { Keyword.inter_word }
		'inter-character' { Keyword.inter_character }
		'ellipsis' { Keyword.ellipsis }
		'optimizelegibility' { Keyword.optimizelegibility }
		'capitalize' { Keyword.capitalize }
		'full-size-kana' { Keyword.full_size_kana }
		'full-width' { Keyword.full_width }
		'lowercase' { Keyword.lowercase }
		'math-auto' { Keyword.math_auto }
		'uppercase' { Keyword.uppercase }
		'nowrap' { Keyword.nowrap }
		'wrap' { Keyword.wrap }
		'balance' { Keyword.balance }
		'stable' { Keyword.stable }
		'pretty' { Keyword.pretty }
		'discard' { Keyword.discard }
		'preserve' { Keyword.preserve }
		'preserve-breaks' { Keyword.preserve_breaks }
		'preserve-spaces' { Keyword.preserve_spaces }
		'break-spaces' { Keyword.break_spaces }
		'discard-before' { Keyword.discard_before }
		'discard-after' { Keyword.discard_after }
		'discard-inner' { Keyword.discard_inner }
		'keep-all' { Keyword.keep_all }
		'break-all' { Keyword.break_all }
		'break-word' { Keyword.break_word }
		'anywhere' { Keyword.anywhere }
		'small-caps' { Keyword.small_caps }
		'all-small-caps' { Keyword.all_small_caps }
		'petite-caps' { Keyword.petite_caps }
		'all-petite-caps' { Keyword.all_petite_caps }
		'unicase' { Keyword.unicase }
		'titling-caps' { Keyword.titling_caps }
		'emoji' { Keyword.emoji }
		'unicode' { Keyword.unicode }
		'sub' { Keyword.sub }
		'super' { Keyword.super }
		'flex-start' { Keyword.flex_start }
		'flex-end' { Keyword.flex_end }
		'space-between' { Keyword.space_between }
		'space-around' { Keyword.space_around }
		'space-evenly' { Keyword.space_evenly }
		'self-start' { Keyword.self_start }
		'self-end' { Keyword.self_end }
		'stretch' { Keyword.stretch }
		'baseline' { Keyword.baseline }
		'safe' { Keyword.safe }
		'unsafe' { Keyword.unsafe_ }
		'legacy' { Keyword.legacy }
		'row' { Keyword.row }
		'row-reverse' { Keyword.row_reverse }
		'column' { Keyword.column }
		'column-reverse' { Keyword.column_reverse }
		'wrap-reverse' { Keyword.wrap_reverse }
		'button' { Keyword.button }
		'checkbox' { Keyword.checkbox }
		'listbox' { Keyword.listbox }
		'menulist' { Keyword.menulist }
		'meter' { Keyword.meter }
		'menulist-button' { Keyword.menulist_button }
		'push-button' { Keyword.push_button }
		'progress-bar' { Keyword.progress_bar }
		'radio' { Keyword.radio }
		'searchfield' { Keyword.searchfield }
		'slider-horizontal' { Keyword.slider_horizontal }
		'square-button' { Keyword.square_button }
		'textarea' { Keyword.textarea }
		'textfield' { Keyword.textfield }
		'crisp-edges' { Keyword.crisp_edges }
		'high-quality' { Keyword.high_quality }
		'pixelated' { Keyword.pixelated }
		'smooth' { Keyword.smooth }
		'optimizequality' { Keyword.optimizequality }
		'fill-box' { Keyword.fill_box }
		'stroke-box' { Keyword.stroke_box }
		'view-box' { Keyword.view_box }
		'manipulation' { Keyword.manipulation }
		'pan-down' { Keyword.pan_down }
		'pan-left' { Keyword.pan_left }
		'pan-right' { Keyword.pan_right }
		'pan-up' { Keyword.pan_up }
		'pan-x' { Keyword.pan_x }
		'pan-y' { Keyword.pan_y }
		'horizontal-tb' { Keyword.horizontal_tb }
		'vertical-rl' { Keyword.vertical_rl }
		'vertical-lr' { Keyword.vertical_lr }
		'sideways-rl' { Keyword.sideways_rl }
		'sideways-lr' { Keyword.sideways_lr }
		'thin' { Keyword.thin }
		'horizontal' { Keyword.horizontal }
		'vertical' { Keyword.vertical }
		'block' { Keyword.block }
		'inline' { Keyword.inline_ }
		'x' { Keyword.x }
		'y' { Keyword.y }
		'strict' { Keyword.strict }
		'content' { Keyword.content }
		'size' { Keyword.size }
		'inline-size' { Keyword.inline_size }
		'layout' { Keyword.layout }
		'style' { Keyword.style }
		'paint' { Keyword.paint }
		'scroll-state' { Keyword.scroll_state }
		'separate' { Keyword.separate }
		'border-box' { Keyword.border_box }
		'padding-box' { Keyword.padding_box }
		'content-box' { Keyword.content_box }
		'inside' { Keyword.inside }
		'outside' { Keyword.outside }
		'flat' { Keyword.flat }
		'preserve-3d' { Keyword.preserve_3d }
		'text' { Keyword.text }
		'absolute' { Keyword.absolute }
		'fixed' { Keyword.fixed }
		'local' { Keyword.local }
		'relative' { Keyword.relative }
		'static' { Keyword.static_ }
		'sticky' { Keyword.sticky }
		'normal' { Keyword.normal }
		'from-font' { Keyword.from_font }
		'compact' { Keyword.compact }
		'hanging' { Keyword.hanging }
		'each-line' { Keyword.each_line }
		'underline' { Keyword.underline }
		'overline' { Keyword.overline }
		'line-through' { Keyword.line_through }
		'blink' { Keyword.blink }
		'spelling-error' { Keyword.spelling_error }
		'grammar-error' { Keyword.grammar_error }
		'wavy' { Keyword.wavy }
		'bold' { Keyword.bold }
		'bolder' { Keyword.bolder }
		'lighter' { Keyword.lighter }
		'italic' { Keyword.italic }
		'linear' { Keyword.linear }
		'ease' { Keyword.ease }
		'ease-in' { Keyword.ease_in }
		'ease-out' { Keyword.ease_out }
		'ease-in-out' { Keyword.ease_in_out }
		'left' { Keyword.left }
		'right' { Keyword.right }
		'oblique' { Keyword.oblique }
		'round' { Keyword.round }
		'space' { Keyword.space }
		'scoop' { Keyword.scoop }
		'bevel' { Keyword.bevel }
		'notch' { Keyword.notch }
		'square' { Keyword.square }
		'squircle' { Keyword.squircle }
		'infinity' { Keyword.infinity }
		'-infinity' { Keyword.negative_infinity }
		'allow-discrete' { Keyword.allow_discrete }
		'reverse' { Keyword.reverse }
		'alternate' { Keyword.alternate }
		'alternate-reverse' { Keyword.alternate_reverse }
		'running' { Keyword.running }
		'paused' { Keyword.paused }
		'forwards' { Keyword.forwards }
		'backwards' { Keyword.backwards }
		'both' { Keyword.both }
		'infinite' { Keyword.infinite }
		'replace' { Keyword.replace }
		'add' { Keyword.add }
		'subtract' { Keyword.subtract }
		'intersect' { Keyword.intersect }
		'exclude' { Keyword.exclude }
		'accumulate' { Keyword.accumulate }
		'light' { Keyword.light }
		'dark' { Keyword.dark }
		'always' { Keyword.always }
		'anchors-valid' { Keyword.anchors_valid }
		'anchors-visible' { Keyword.anchors_visible }
		'no-overflow' { Keyword.no_overflow }
		'accentcolor' { Keyword.accentcolor }
		'accentcolortext' { Keyword.accentcolortext }
		'activeborder' { Keyword.activeborder }
		'activecaption' { Keyword.activecaption }
		'activetext' { Keyword.activetext }
		'appworkspace' { Keyword.appworkspace }
		'background' { Keyword.background }
		'buttonborder' { Keyword.buttonborder }
		'buttonface' { Keyword.buttonface }
		'buttonhighlight' { Keyword.buttonhighlight }
		'buttonshadow' { Keyword.buttonshadow }
		'buttontext' { Keyword.buttontext }
		'canvas' { Keyword.canvas }
		'canvastext' { Keyword.canvastext }
		'captiontext' { Keyword.captiontext }
		'currentcolor' { Keyword.currentcolor }
		'field' { Keyword.field }
		'fieldtext' { Keyword.fieldtext }
		'graytext' { Keyword.graytext }
		'highlight' { Keyword.highlight }
		'highlighttext' { Keyword.highlighttext }
		'inactiveborder' { Keyword.inactiveborder }
		'inactivecaption' { Keyword.inactivecaption }
		'inactivecaptiontext' { Keyword.inactivecaptiontext }
		'infobackground' { Keyword.infobackground }
		'infotext' { Keyword.infotext }
		'-libweb-buttonfacedisabled' { Keyword.libweb_buttonfacedisabled }
		'-libweb-buttonfacehover' { Keyword.libweb_buttonfacehover }
		'-libweb-link' { Keyword.libweb_link }
		'-libweb-palette-active-link' { Keyword.libweb_palette_active_link }
		'-libweb-palette-active-window-border1' { Keyword.libweb_palette_active_window_border1 }
		'-libweb-palette-active-window-border2' { Keyword.libweb_palette_active_window_border2 }
		'-libweb-palette-active-window-title' { Keyword.libweb_palette_active_window_title }
		'-libweb-palette-base' { Keyword.libweb_palette_base }
		'-libweb-palette-base-text' { Keyword.libweb_palette_base_text }
		'-libweb-palette-button' { Keyword.libweb_palette_button }
		'-libweb-palette-button-text' { Keyword.libweb_palette_button_text }
		'-libweb-palette-desktop-background' { Keyword.libweb_palette_desktop_background }
		'-libweb-palette-focus-outline' { Keyword.libweb_palette_focus_outline }
		'-libweb-palette-highlight-window-border1' { Keyword.libweb_palette_highlight_window_border1 }
		'-libweb-palette-highlight-window-border2' { Keyword.libweb_palette_highlight_window_border2 }
		'-libweb-palette-highlight-window-title' { Keyword.libweb_palette_highlight_window_title }
		'-libweb-palette-hover-highlight' { Keyword.libweb_palette_hover_highlight }
		'-libweb-palette-inactive-selection' { Keyword.libweb_palette_inactive_selection }
		'-libweb-palette-inactive-selection-text' { Keyword.libweb_palette_inactive_selection_text }
		'-libweb-palette-inactive-window-border1' { Keyword.libweb_palette_inactive_window_border1 }
		'-libweb-palette-inactive-window-border2' { Keyword.libweb_palette_inactive_window_border2 }
		'-libweb-palette-inactive-window-title' { Keyword.libweb_palette_inactive_window_title }
		'-libweb-palette-link' { Keyword.libweb_palette_link }
		'-libweb-palette-menu-base' { Keyword.libweb_palette_menu_base }
		'-libweb-palette-menu-base-text' { Keyword.libweb_palette_menu_base_text }
		'-libweb-palette-menu-selection' { Keyword.libweb_palette_menu_selection }
		'-libweb-palette-menu-selection-text' { Keyword.libweb_palette_menu_selection_text }
		'-libweb-palette-menu-stripe' { Keyword.libweb_palette_menu_stripe }
		'-libweb-palette-moving-window-border1' { Keyword.libweb_palette_moving_window_border1 }
		'-libweb-palette-moving-window-border2' { Keyword.libweb_palette_moving_window_border2 }
		'-libweb-palette-moving-window-title' { Keyword.libweb_palette_moving_window_title }
		'-libweb-palette-rubber-band-border' { Keyword.libweb_palette_rubber_band_border }
		'-libweb-palette-rubber-band-fill' { Keyword.libweb_palette_rubber_band_fill }
		'-libweb-palette-ruler' { Keyword.libweb_palette_ruler }
		'-libweb-palette-ruler-active-text' { Keyword.libweb_palette_ruler_active_text }
		'-libweb-palette-ruler-border' { Keyword.libweb_palette_ruler_border }
		'-libweb-palette-ruler-inactive-text' { Keyword.libweb_palette_ruler_inactive_text }
		'-libweb-palette-selection' { Keyword.libweb_palette_selection }
		'-libweb-palette-selection-text' { Keyword.libweb_palette_selection_text }
		'-libweb-palette-syntax-comment' { Keyword.libweb_palette_syntax_comment }
		'-libweb-palette-syntax-control-keyword' { Keyword.libweb_palette_syntax_control_keyword }
		'-libweb-palette-syntax-identifier' { Keyword.libweb_palette_syntax_identifier }
		'-libweb-palette-syntax-keyword' { Keyword.libweb_palette_syntax_keyword }
		'-libweb-palette-syntax-number' { Keyword.libweb_palette_syntax_number }
		'-libweb-palette-syntax-operator' { Keyword.libweb_palette_syntax_operator }
		'-libweb-palette-syntax-preprocessor-statement' { Keyword.libweb_palette_syntax_preprocessor_statement }
		'-libweb-palette-syntax-preprocessor-value' { Keyword.libweb_palette_syntax_preprocessor_value }
		'-libweb-palette-syntax-punctuation' { Keyword.libweb_palette_syntax_punctuation }
		'-libweb-palette-syntax-string' { Keyword.libweb_palette_syntax_string }
		'-libweb-palette-syntax-type' { Keyword.libweb_palette_syntax_type }
		'-libweb-palette-text-cursor' { Keyword.libweb_palette_text_cursor }
		'-libweb-palette-threed-highlight' { Keyword.libweb_palette_threed_highlight }
		'-libweb-palette-threed-shadow1' { Keyword.libweb_palette_threed_shadow1 }
		'-libweb-palette-threed-shadow2' { Keyword.libweb_palette_threed_shadow2 }
		'-libweb-palette-visited-link' { Keyword.libweb_palette_visited_link }
		'-libweb-palette-window' { Keyword.libweb_palette_window }
		'-libweb-palette-window-text' { Keyword.libweb_palette_window_text }
		'linktext' { Keyword.linktext }
		'mark' { Keyword.mark }
		'marktext' { Keyword.marktext }
		'menu' { Keyword.menu }
		'menutext' { Keyword.menutext }
		'scrollbar' { Keyword.scrollbar }
		'selecteditem' { Keyword.selecteditem }
		'selecteditemtext' { Keyword.selecteditemtext }
		'threeddarkshadow' { Keyword.threeddarkshadow }
		'threedface' { Keyword.threedface }
		'threedhighlight' { Keyword.threedhighlight }
		'threedlightshadow' { Keyword.threedlightshadow }
		'threedshadow' { Keyword.threedshadow }
		'visitedtext' { Keyword.visitedtext }
		'window' { Keyword.window }
		'windowframe' { Keyword.windowframe }
		'windowtext' { Keyword.windowtext }
		'text-bottom' { Keyword.text_bottom }
		'alphabetic' { Keyword.alphabetic }
		'ideographic' { Keyword.ideographic }
		'central' { Keyword.central }
		'mathematical' { Keyword.mathematical }
		'text-top' { Keyword.text_top }
		else { none }
	}
}

// --- StyleValue ---

pub enum StyleValueType {
	add_function
	anchor
	anchor_size
	angle
	background_size
	basic_shape
	border_image_slice
	border_radius
	border_radius_rect
	calculated
	color_interpolation_method
	color_scheme
	color
	conic_gradient
	content
	counter
	counter_style
	counter_definitions
	counter_style_system
	cursor
	custom_ident
	display
	easing
	edge
	filter_value_list
	fit_content
	flex
	font_source
	font_style
	font_variant_alternates_function
	frequency
	grid_auto_flow
	grid_template_area
	grid_track_placement
	grid_track_size_list
	guaranteed_invalid
	image
	integer
	keyword
	length
	linear_gradient
	number
	open_type_tagged
	pending_substitution
	percentage
	position
	radial_gradient
	radial_size
	random_value_sharing
	ratio
	rect
	repeat_style
	resolution
	scrollbar_color
	scrollbar_gutter
	scroll_function
	shadow
	shorthand
	string
	superellipse
	text_indent
	text_underline_position
	time
	transformation
	tree_counting_function
	tuple
	unicode_range
	unresolved
	url
	value_list
	view_function
}

pub type DimensionStyleValue = AngleStyleValue
	| FlexStyleValue
	| FrequencyStyleValue
	| LengthStyleValue
	| PercentageStyleValue
	| ResolutionStyleValue
	| TimeStyleValue

pub type StyleValue = KeywordStyleValue
	| AddFunctionStyleValue
	| AnchorSizeStyleValue
	| AnchorStyleValue
	| AngleStyleValue
	| CalculatedStyleValue
	| BackgroundSizeStyleValue
	| BasicShapeStyleValue
	| BorderImageSliceStyleValue
	| BorderRadiusRectStyleValue
	| BorderRadiusStyleValue
	| ColorFunctionStyleValue
	| ColorInterpolationMethodStyleValue
	| ColorMixStyleValue
	| ColorSchemeStyleValue
	| ColorStyleValue
	| ConicGradientStyleValue
	| ContentStyleValue
	| CursorStyleValue
	| CustomIdentStyleValue
	| DisplayStyleValue
	| EasingStyleValue
	| EdgeStyleValue
	| FilterValueListStyleValue
	| FlexStyleValue
	| FontSourceStyleValue
	| FontStyleStyleValue
	| FontVariantAlternatesFunctionStyleValue
	| FrequencyStyleValue
	| GuaranteedInvalidStyleValue
	| HSLColorStyleValue
	| HWBColorStyleValue
	| ImageStyleValue
	| IntegerStyleValue
	| LabColorStyleValue
	| LCHColorStyleValue
	| LengthStyleValue
	| LightDarkStyleValue
	| LinearGradientStyleValue
	| NumberStyleValue
	| OKLabColorStyleValue
	| OKLCHColorStyleValue
	| OpenTypeTaggedStyleValue
	| PendingSubstitutionStyleValue
	| PercentageStyleValue
	| PositionStyleValue
	| RadialGradientStyleValue
	| RadialSizeStyleValue
	| RandomValueSharingStyleValue
	| RatioStyleValue
	| RectStyleValue
	| RepeatStyleStyleValue
	| ResolutionStyleValue
	| RGBColorStyleValue
	| ScrollFunctionStyleValue
	| ScrollbarColorStyleValue
	| ScrollbarGutterStyleValue
	| ShadowStyleValue
	| ShorthandStyleValue
	| StringStyleValue
	| StyleValueList
	| StubStyleValue
	| SuperellipseStyleValue
	| TextIndentStyleValue
	| TextUnderlinePositionStyleValue
	| TimeStyleValue
	| TransformationStyleValue
	| TreeCountingFunctionStyleValue
	| TupleStyleValue
	| UnicodeRangeStyleValue
	| UnresolvedStyleValue
	| URLStyleValue
	| ViewFunctionStyleValue

pub type StyleValueVector = []StyleValue

pub fn (style_value StyleValue) type_() StyleValueType {
	return match style_value {
		AddFunctionStyleValue { .add_function }
		AnchorSizeStyleValue { .anchor_size }
		AnchorStyleValue { .anchor }
		AngleStyleValue { .angle }
		BackgroundSizeStyleValue { .background_size }
		BasicShapeStyleValue { .basic_shape }
		BorderImageSliceStyleValue { .border_image_slice }
		BorderRadiusRectStyleValue { .border_radius_rect }
		BorderRadiusStyleValue { .border_radius }
		CalculatedStyleValue { .calculated }
		ColorFunctionStyleValue { .color }
		ColorInterpolationMethodStyleValue { .color_interpolation_method }
		ColorMixStyleValue { .color }
		ColorSchemeStyleValue { .color_scheme }
		ColorStyleValue { .color }
		ConicGradientStyleValue { .conic_gradient }
		ContentStyleValue { .content }
		CursorStyleValue { .cursor }
		CustomIdentStyleValue { .custom_ident }
		DisplayStyleValue { .display }
		EasingStyleValue { .easing }
		EdgeStyleValue { .edge }
		FilterValueListStyleValue { .filter_value_list }
		FlexStyleValue { .flex }
		FontSourceStyleValue { .font_source }
		FontStyleStyleValue { .font_style }
		FontVariantAlternatesFunctionStyleValue { .font_variant_alternates_function }
		FrequencyStyleValue { .frequency }
		GuaranteedInvalidStyleValue { .guaranteed_invalid }
		HSLColorStyleValue { .color }
		HWBColorStyleValue { .color }
		ImageStyleValue { .image }
		IntegerStyleValue { .integer }
		KeywordStyleValue { .keyword }
		LabColorStyleValue { .color }
		LCHColorStyleValue { .color }
		LengthStyleValue { .length }
		LightDarkStyleValue { .color }
		LinearGradientStyleValue { .linear_gradient }
		NumberStyleValue { .number }
		OKLabColorStyleValue { .color }
		OKLCHColorStyleValue { .color }
		OpenTypeTaggedStyleValue { .open_type_tagged }
		PendingSubstitutionStyleValue { .pending_substitution }
		PercentageStyleValue { .percentage }
		PositionStyleValue { .position }
		RadialGradientStyleValue { .radial_gradient }
		RadialSizeStyleValue { .radial_size }
		RandomValueSharingStyleValue { .random_value_sharing }
		RatioStyleValue { .ratio }
		RectStyleValue { .rect }
		RepeatStyleStyleValue { .repeat_style }
		ResolutionStyleValue { .resolution }
		RGBColorStyleValue { .color }
		ScrollFunctionStyleValue { .scroll_function }
		ScrollbarColorStyleValue { .scrollbar_color }
		ScrollbarGutterStyleValue { .scrollbar_gutter }
		ShadowStyleValue { .shadow }
		ShorthandStyleValue { .shorthand }
		StringStyleValue { .string }
		StyleValueList { .value_list }
		StubStyleValue { style_value.type_ }
		SuperellipseStyleValue { .superellipse }
		TextIndentStyleValue { .text_indent }
		TextUnderlinePositionStyleValue { .text_underline_position }
		TimeStyleValue { .time }
		TransformationStyleValue { .transformation }
		TreeCountingFunctionStyleValue { .tree_counting_function }
		TupleStyleValue { .tuple }
		UnicodeRangeStyleValue { .unicode_range }
		UnresolvedStyleValue { .unresolved }
		URLStyleValue { .url }
		ViewFunctionStyleValue { .view_function }
	}
}

pub fn (style_value StyleValue) is_keyword() bool {
	return style_value.type_() == .keyword
}

pub fn (style_value StyleValue) is_integer() bool {
	return style_value.type_() == .integer
}

pub fn (style_value StyleValue) is_number() bool {
	return style_value.type_() == .number
}

pub fn (style_value StyleValue) is_percentage() bool {
	return style_value.type_() == .percentage
}

pub fn (style_value StyleValue) is_ratio() bool {
	return style_value.type_() == .ratio
}

pub fn (style_value StyleValue) is_calculated() bool {
	return style_value.type_() == .calculated
}

pub fn (style_value StyleValue) is_string() bool {
	return style_value.type_() == .string
}

pub fn (style_value StyleValue) is_custom_ident() bool {
	return style_value.type_() == .custom_ident
}

pub fn (style_value StyleValue) is_dimension() bool {
	return match style_value {
		AngleStyleValue, FlexStyleValue, FrequencyStyleValue, LengthStyleValue,
		PercentageStyleValue, ResolutionStyleValue, TimeStyleValue {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value StyleValue) as_keyword() KeywordStyleValue {
	value := style_value
	if value is KeywordStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_integer() IntegerStyleValue {
	value := style_value
	if value is IntegerStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_number() NumberStyleValue {
	value := style_value
	if value is NumberStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_percentage() PercentageStyleValue {
	value := style_value
	if value is PercentageStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_ratio() RatioStyleValue {
	value := style_value
	if value is RatioStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_calculated() CalculatedStyleValue {
	value := style_value
	if value is CalculatedStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_string() StringStyleValue {
	value := style_value
	if value is StringStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_custom_ident() CustomIdentStyleValue {
	value := style_value
	if value is CustomIdentStyleValue {
		return value
	}
	panic('VERIFY_NOT_REACHED')
}

pub fn (style_value StyleValue) as_dimension() DimensionStyleValue {
	return match style_value {
		AngleStyleValue { DimensionStyleValue(style_value) }
		FlexStyleValue { DimensionStyleValue(style_value) }
		FrequencyStyleValue { DimensionStyleValue(style_value) }
		LengthStyleValue { DimensionStyleValue(style_value) }
		PercentageStyleValue { DimensionStyleValue(style_value) }
		ResolutionStyleValue { DimensionStyleValue(style_value) }
		TimeStyleValue { DimensionStyleValue(style_value) }
		else { panic('VERIFY_NOT_REACHED') }
	}
}

// https://www.w3.org/TR/css-values-4/#common-keywords
// https://drafts.csswg.org/css-cascade-4/#valdef-all-revert
pub fn (style_value StyleValue) is_css_wide_keyword() bool {
	return style_value.is_inherit() || style_value.is_initial() || style_value.is_revert()
		|| style_value.is_unset() || style_value.is_revert_layer()
}

pub fn (style_value StyleValue) is_inherit() bool {
	return style_value.to_keyword() == .inherit
}

pub fn (style_value StyleValue) is_initial() bool {
	return style_value.to_keyword() == .initial
}

pub fn (style_value StyleValue) is_revert() bool {
	return style_value.to_keyword() == .revert
}

pub fn (style_value StyleValue) is_revert_layer() bool {
	return style_value.to_keyword() == .revert_layer
}

pub fn (style_value StyleValue) is_unset() bool {
	return style_value.to_keyword() == .unset
}

pub fn (style_value StyleValue) has_auto() bool {
	return style_value.is_keyword() && style_value.as_keyword().keyword() == .auto
}

pub fn (style_value StyleValue) has_color() bool {
	return match style_value {
		KeywordStyleValue {
			style_value.has_color()
		}
		ColorFunctionStyleValue, ColorMixStyleValue, ColorStyleValue, HSLColorStyleValue,
		HWBColorStyleValue, LabColorStyleValue, LCHColorStyleValue, LightDarkStyleValue,
		OKLabColorStyleValue, OKLCHColorStyleValue, RGBColorStyleValue {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value StyleValue) absolutized(context ComputationContext) StyleValue {
	return match style_value {
		AddFunctionStyleValue { style_value.absolutized(context) }
		BackgroundSizeStyleValue { style_value.absolutized(context) }
		BasicShapeStyleValue { style_value.absolutized(context) }
		BorderRadiusRectStyleValue { style_value.absolutized(context) }
		BorderRadiusStyleValue { style_value.absolutized(context) }
		CalculatedStyleValue { style_value.absolutized(context) }
		ColorFunctionStyleValue { style_value.absolutized(context) }
		ColorInterpolationMethodStyleValue { StyleValue(style_value.absolutized(context)) }
		ColorMixStyleValue { style_value.absolutized(context) }
		ConicGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		CursorStyleValue { style_value.absolutized(context) }
		EasingStyleValue { style_value.absolutized(context) }
		EdgeStyleValue { style_value.absolutized(context) }
		FilterValueListStyleValue { style_value.absolutized(context) }
		FontStyleStyleValue { style_value.absolutized(context) }
		FontVariantAlternatesFunctionStyleValue { style_value.absolutized(context) }
		HSLColorStyleValue { StyleValue(style_value.absolutized(context)) }
		HWBColorStyleValue { StyleValue(style_value.absolutized(context)) }
		ImageStyleValue { StyleValue(style_value.absolutized(context)) }
		LengthStyleValue { StyleValue(style_value.absolutized(context)) }
		LightDarkStyleValue { style_value.absolutized(context) }
		LinearGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		KeywordStyleValue { style_value.absolutized(context) }
		OpenTypeTaggedStyleValue { style_value.absolutized(context) }
		PositionStyleValue { style_value.absolutized(context) }
		RadialGradientStyleValue { StyleValue(style_value.absolutized(context)) }
		RadialSizeStyleValue { style_value.absolutized(context) }
		RandomValueSharingStyleValue { style_value.absolutized(context) }
		RGBColorStyleValue { StyleValue(style_value.absolutized(context)) }
		ShadowStyleValue { style_value.absolutized(context) }
		StyleValueList { style_value.absolutized(context) }
		SuperellipseStyleValue { style_value.absolutized(context) }
		TextIndentStyleValue { style_value.absolutized(context) }
		TransformationStyleValue { StyleValue(style_value.absolutized(context)) }
		TreeCountingFunctionStyleValue { style_value.absolutized(context) }
		TupleStyleValue { style_value.absolutized(context) }
		ViewFunctionStyleValue { style_value.absolutized(context) }
		else { style_value }
	}
}

pub fn (style_value StyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	return match style_value {
		ColorFunctionStyleValue { style_value.to_color(color_resolution_context) }
		ColorMixStyleValue { style_value.to_color(color_resolution_context) }
		KeywordStyleValue { style_value.to_color(color_resolution_context) }
		ColorStyleValue { style_value.color() }
		HSLColorStyleValue { style_value.to_color(color_resolution_context) }
		HWBColorStyleValue { style_value.to_color(color_resolution_context) }
		LabColorStyleValue { style_value.to_color(color_resolution_context) }
		LCHColorStyleValue { style_value.to_color(color_resolution_context) }
		LightDarkStyleValue { style_value.to_color(color_resolution_context) }
		OKLabColorStyleValue { style_value.to_color(color_resolution_context) }
		OKLCHColorStyleValue { style_value.to_color(color_resolution_context) }
		RGBColorStyleValue { style_value.to_color(color_resolution_context) }
		else { none }
	}
}

pub fn (style_value StyleValue) to_keyword() Keyword {
	if style_value.is_keyword() {
		return style_value.as_keyword().keyword()
	}
	return .invalid
}

pub fn (style_value StyleValue) serialize(mode SerializationMode) string {
	return match style_value {
		AddFunctionStyleValue { style_value.serialize(mode) }
		AnchorSizeStyleValue { style_value.serialize(mode) }
		AnchorStyleValue { style_value.serialize(mode) }
		AngleStyleValue { style_value.serialize(mode) }
		BackgroundSizeStyleValue { style_value.serialize(mode) }
		BasicShapeStyleValue { style_value.serialize(mode) }
		BorderImageSliceStyleValue { style_value.serialize(mode) }
		BorderRadiusRectStyleValue { style_value.serialize(mode) }
		BorderRadiusStyleValue { style_value.serialize(mode) }
		CalculatedStyleValue { style_value.serialize(mode) }
		ColorFunctionStyleValue { style_value.serialize(mode) }
		ColorInterpolationMethodStyleValue { style_value.serialize(mode) }
		ColorMixStyleValue { style_value.serialize(mode) }
		ColorSchemeStyleValue { style_value.serialize(mode) }
		ColorStyleValue { style_value.serialize(mode) }
		ConicGradientStyleValue { style_value.serialize(mode) }
		ContentStyleValue { style_value.serialize(mode) }
		CursorStyleValue { style_value.serialize(mode) }
		CustomIdentStyleValue { style_value.serialize(mode) }
		DisplayStyleValue { style_value.serialize(mode) }
		EasingStyleValue { style_value.serialize(mode) }
		EdgeStyleValue { style_value.serialize(mode) }
		FilterValueListStyleValue { style_value.serialize(mode) }
		FlexStyleValue { style_value.serialize(mode) }
		FontSourceStyleValue { style_value.serialize(mode) }
		FontStyleStyleValue { style_value.serialize(mode) }
		FontVariantAlternatesFunctionStyleValue { style_value.serialize(mode) }
		FrequencyStyleValue { style_value.serialize(mode) }
		GuaranteedInvalidStyleValue { style_value.serialize(mode) }
		HSLColorStyleValue { style_value.serialize(mode) }
		HWBColorStyleValue { style_value.serialize(mode) }
		ImageStyleValue { style_value.serialize(mode) }
		IntegerStyleValue { style_value.serialize(mode) }
		KeywordStyleValue { style_value.serialize(mode) }
		LabColorStyleValue { style_value.serialize(mode) }
		LCHColorStyleValue { style_value.serialize(mode) }
		LengthStyleValue { style_value.serialize(mode) }
		LightDarkStyleValue { style_value.serialize(mode) }
		LinearGradientStyleValue { style_value.serialize(mode) }
		NumberStyleValue { style_value.serialize(mode) }
		OKLabColorStyleValue { style_value.serialize(mode) }
		OKLCHColorStyleValue { style_value.serialize(mode) }
		OpenTypeTaggedStyleValue { style_value.serialize(mode) }
		PendingSubstitutionStyleValue { style_value.serialize(mode) }
		PercentageStyleValue { style_value.serialize(mode) }
		PositionStyleValue { style_value.serialize(mode) }
		RadialGradientStyleValue { style_value.serialize(mode) }
		RadialSizeStyleValue { style_value.serialize(mode) }
		RandomValueSharingStyleValue { style_value.serialize(mode) }
		RatioStyleValue { style_value.serialize(mode) }
		RectStyleValue { style_value.serialize(mode) }
		RepeatStyleStyleValue { style_value.serialize(mode) }
		ResolutionStyleValue { style_value.serialize(mode) }
		RGBColorStyleValue { style_value.serialize(mode) }
		ScrollFunctionStyleValue { style_value.serialize(mode) }
		ScrollbarColorStyleValue { style_value.serialize(mode) }
		ScrollbarGutterStyleValue { style_value.serialize(mode) }
		ShadowStyleValue { style_value.serialize(mode) }
		ShorthandStyleValue { style_value.serialize(mode) }
		StringStyleValue { style_value.serialize(mode) }
		StyleValueList { style_value.serialize(mode) }
		StubStyleValue { style_value.serialize(mode) }
		SuperellipseStyleValue { style_value.serialize(mode) }
		TextIndentStyleValue { style_value.serialize(mode) }
		TextUnderlinePositionStyleValue { style_value.serialize(mode) }
		TimeStyleValue { style_value.serialize(mode) }
		TransformationStyleValue { style_value.serialize(mode) }
		TreeCountingFunctionStyleValue { style_value.serialize(mode) }
		TupleStyleValue { style_value.serialize(mode) }
		UnicodeRangeStyleValue { style_value.serialize(mode) }
		UnresolvedStyleValue { style_value.serialize(mode) }
		URLStyleValue { style_value.serialize(mode) }
		ViewFunctionStyleValue { style_value.serialize(mode) }
	}
}

pub fn (style_value StyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value StyleValue) to_string_with_mode(mode SerializationMode) string {
	return style_value.serialize(mode)
}

pub fn (style_value StyleValue) tokenize() []ComponentValue {
	// This is an inefficient way of producing ComponentValues, but it's guaranteed to work for types that round-trip.
	// FIXME: Implement better versions in the subclasses.
	if style_value.is_dimension() {
		return style_value.as_dimension().tokenize()
	}
	if style_value is KeywordStyleValue {
		return style_value.tokenize()
	}
	if style_value is NumberStyleValue {
		return style_value.tokenize()
	}
	if style_value is IntegerStyleValue {
		return style_value.tokenize()
	}
	if style_value is StyleValueList {
		return style_value.tokenize()
	}
	if style_value is RatioStyleValue {
		return style_value.tokenize()
	}
	if style_value is GuaranteedInvalidStyleValue {
		return style_value.tokenize()
	}
	if style_value is PendingSubstitutionStyleValue {
		return style_value.tokenize()
	}
	if style_value is UnresolvedStyleValue {
		return style_value.tokenize()
	}
	return parse_component_values_for_value_logic(style_value.to_string())
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-as-a-cssstylevalue
pub fn (style_value StyleValue) reify(associated_property string) CSSStyleValue {
	// 1. Return a new CSSStyleValue object representing value whose [[associatedProperty]] internal slot is set to property.
	if style_value.is_dimension() {
		return style_value.as_dimension().reify(associated_property)
	}
	if style_value is KeywordStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is NumberStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is IntegerStyleValue {
		return style_value.reify(associated_property)
	}
	if style_value is StyleValueList {
		return style_value.reify(associated_property)
	}
	return CSSStyleValue.create(associated_property, style_value)
}

// https://drafts.css-houdini.org/css-typed-om-1/#subdivide-into-iterations
pub fn (style_value StyleValue) subdivide_into_iterations(property PropertyNameAndID) StyleValueVector {
	// To subdivide into iterations a CSS value whole value for a property property, execute the following steps:
	// 1. If property is a single-valued property, return a list containing whole value.
	// 2. Otherwise, divide whole value into individual iterations, as appropriate for property, and return a list
	//    containing the iterations in order.
	// NB: We do this by type. By default, we assume step 1 applies. For step 2, override this method.
	return match style_value {
		StyleValueList {
			style_value.subdivide_into_iterations(property)
		}
		else {
			[style_value]
		}
	}
}

pub fn (style_value StyleValue) equals(other StyleValue) bool {
	return style_value == other
}

pub fn int_from_style_value(style_value StyleValue) i64 {
	if style_value.is_integer() {
		return style_value.as_integer().integer()
	}

	if style_value.is_calculated() {
		return style_value.as_calculated().resolve_integer(CalculationResolutionContext{}) or { 0 }
	}

	panic('VERIFY_NOT_REACHED')
}

pub fn number_from_style_value(style_value StyleValue, percentage_basis ?f64) f64 {
	if style_value.is_number() {
		return style_value.as_number().number()
	}

	if style_value.is_calculated() {
		calculated_style_value := style_value.as_calculated()

		if calculated_style_value.resolves_to_number() {
			return calculated_style_value.resolve_number(CalculationResolutionContext{}) or { 0.0 }
		}

		if calculated_style_value.resolves_to_percentage() {
			basis := percentage_basis or { panic('VERIFY_NOT_REACHED') }
			percentage := calculated_style_value.resolve_percentage(CalculationResolutionContext{}) or {
				Percentage.new(0)
			}
			return percentage.as_fraction() * basis
		}

		panic('VERIFY_NOT_REACHED')
	}

	if style_value.is_percentage() {
		basis := percentage_basis or { panic('VERIFY_NOT_REACHED') }
		return basis * style_value.as_percentage().percentage().as_fraction()
	}

	panic('VERIFY_NOT_REACHED')
}

pub fn string_from_style_value(style_value StyleValue) string {
	if style_value.is_string() {
		return style_value.as_string().string_value()
	}

	if style_value.is_custom_ident() {
		return style_value.as_custom_ident().custom_ident()
	}

	panic('VERIFY_NOT_REACHED')
}

// --- DimensionStyleValue ---

pub fn (style_value DimensionStyleValue) raw_value() f64 {
	return match style_value {
		AngleStyleValue { style_value.raw_value() }
		FlexStyleValue { style_value.raw_value() }
		FrequencyStyleValue { style_value.raw_value() }
		LengthStyleValue { style_value.raw_value() }
		PercentageStyleValue { style_value.raw_value() }
		ResolutionStyleValue { style_value.raw_value() }
		TimeStyleValue { style_value.raw_value() }
	}
}

pub fn (style_value DimensionStyleValue) unit_name() string {
	return match style_value {
		AngleStyleValue { style_value.unit_name() }
		FlexStyleValue { style_value.unit_name() }
		FrequencyStyleValue { style_value.unit_name() }
		LengthStyleValue { style_value.unit_name() }
		PercentageStyleValue { style_value.unit_name() }
		ResolutionStyleValue { style_value.unit_name() }
		TimeStyleValue { style_value.unit_name() }
	}
}

pub fn (style_value DimensionStyleValue) tokenize() []ComponentValue {
	return [
		component_value_from_text('${serialize_a_number(style_value.raw_value())}${style_value.unit_name()}'),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-numeric-value
pub fn (style_value DimensionStyleValue) reify(associated_property string) CSSStyleValue {
	_ = associated_property
	// NB: Steps 1 and 2 do not apply here.
	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	// FIXME: Reify computed value correctly. That sounds like it should work by computing the value properly before we
	//        reach this point.
	return CSSStyleValue.from_numeric(CSSUnitValue.create(style_value.raw_value(),
		style_value.unit_name()))
}

// --- KeywordStyleValue ---

pub struct KeywordStyleValue {
pub mut:
	keyword_ Keyword = .invalid
}

pub fn KeywordStyleValue.create(keyword Keyword) KeywordStyleValue {
	return KeywordStyleValue{
		keyword_: keyword
	}
}

pub fn (style_value KeywordStyleValue) keyword() Keyword {
	return style_value.keyword_
}

pub fn (style_value KeywordStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return string_from_keyword(style_value.keyword())
}

pub fn (style_value KeywordStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn KeywordStyleValue.is_color(keyword Keyword) bool {
	return match keyword {
		.accentcolor, .accentcolortext, .activeborder, .activecaption, .activetext, .appworkspace,
		.background, .buttonborder, .buttonface, .buttonhighlight, .buttonshadow, .buttontext,
		.canvas, .canvastext, .captiontext, .currentcolor, .field, .fieldtext, .graytext,
		.highlight, .highlighttext, .inactiveborder, .inactivecaption, .inactivecaptiontext,
		.infobackground, .infotext, .libweb_buttonfacedisabled, .libweb_buttonfacehover,
		.libweb_link, .libweb_palette_active_link, .libweb_palette_active_window_border1,
		.libweb_palette_active_window_border2, .libweb_palette_active_window_title,
		.libweb_palette_base, .libweb_palette_base_text, .libweb_palette_button,
		.libweb_palette_button_text, .libweb_palette_desktop_background,
		.libweb_palette_focus_outline, .libweb_palette_highlight_window_border1,
		.libweb_palette_highlight_window_border2, .libweb_palette_highlight_window_title,
		.libweb_palette_hover_highlight, .libweb_palette_inactive_selection,
		.libweb_palette_inactive_selection_text, .libweb_palette_inactive_window_border1,
		.libweb_palette_inactive_window_border2, .libweb_palette_inactive_window_title,
		.libweb_palette_link, .libweb_palette_menu_base, .libweb_palette_menu_base_text,
		.libweb_palette_menu_selection, .libweb_palette_menu_selection_text,
		.libweb_palette_menu_stripe, .libweb_palette_moving_window_border1,
		.libweb_palette_moving_window_border2, .libweb_palette_moving_window_title,
		.libweb_palette_rubber_band_border, .libweb_palette_rubber_band_fill,
		.libweb_palette_ruler, .libweb_palette_ruler_active_text, .libweb_palette_ruler_border,
		.libweb_palette_ruler_inactive_text, .libweb_palette_selection,
		.libweb_palette_selection_text, .libweb_palette_syntax_comment,
		.libweb_palette_syntax_control_keyword, .libweb_palette_syntax_identifier,
		.libweb_palette_syntax_keyword, .libweb_palette_syntax_number,
		.libweb_palette_syntax_operator, .libweb_palette_syntax_preprocessor_statement,
		.libweb_palette_syntax_preprocessor_value, .libweb_palette_syntax_punctuation,
		.libweb_palette_syntax_string, .libweb_palette_syntax_type, .libweb_palette_text_cursor,
		.libweb_palette_threed_highlight, .libweb_palette_threed_shadow1,
		.libweb_palette_threed_shadow2, .libweb_palette_visited_link, .libweb_palette_window,
		.libweb_palette_window_text, .linktext, .mark, .marktext, .menu, .menutext, .scrollbar,
		.selecteditem, .selecteditemtext, .threeddarkshadow, .threedface, .threedhighlight,
		.threedlightshadow, .threedshadow, .visitedtext, .window, .windowframe, .windowtext {
			true
		}
		else {
			false
		}
	}
}

pub fn (style_value KeywordStyleValue) has_color() bool {
	return KeywordStyleValue.is_color(style_value.keyword())
}

pub fn (style_value KeywordStyleValue) to_color(color_resolution_context ColorResolutionContext) ?Color {
	if style_value.keyword() == .currentcolor {
		return color_resolution_context.current_color or { Color.black() }
	}

	scheme := color_resolution_context.color_scheme or { PreferredColorScheme.light }

	// Calculate accent_color_text based on contrast to accent_color
	if style_value.keyword() == .accentcolortext {
		// min_contrast = 10.2 is a magic number which provides the best accessibility trade-off based on:
		// 1. https://webaim.org/resources/contrastchecker/
		// 2. Current implementation of luminosity() and contrast_ratio() methods for Color instances
		//
		// the baseline colors with the least contrast from black and white are #757575 and #767676
		// which score over 4.5 ratio for #fff and #000 accent_color_text values correspondingly
		min_contrast := 10.2
		system_accent_text := SystemColor.accent_color_text(scheme)

		accent_color := color_resolution_context.accent_color or {
			SystemColor.accent_color(scheme)
		}

		if accent_color.contrast_ratio(system_accent_text) < min_contrast {
			return system_accent_text.inverted()
		}

		return system_accent_text
	}

	// First, handle <system-color>s, since they do not strictly require a node.
	// https://www.w3.org/TR/css-color-4/#css-system-colors
	// https://www.w3.org/TR/css-color-4/#deprecated-system-colors
	match style_value.keyword() {
		.accentcolor {
			return color_resolution_context.accent_color or { SystemColor.accent_color(scheme) }
		}
		.buttonborder, .activeborder, .inactiveborder, .threeddarkshadow, .threedhighlight,
		.threedlightshadow, .threedshadow, .windowframe {
			return SystemColor.button_border(scheme)
		}
		.buttonface, .buttonhighlight, .buttonshadow, .threedface {
			return SystemColor.button_face(scheme)
		}
		.buttontext {
			return SystemColor.button_text(scheme)
		}
		.canvas, .appworkspace, .background, .inactivecaption, .infobackground, .menu, .scrollbar,
		.window {
			return SystemColor.canvas(scheme)
		}
		.canvastext, .activecaption, .captiontext, .infotext, .menutext, .windowtext {
			return SystemColor.canvas_text(scheme)
		}
		.field {
			return SystemColor.field(scheme)
		}
		.fieldtext {
			return SystemColor.field_text(scheme)
		}
		.graytext, .inactivecaptiontext {
			return SystemColor.gray_text(scheme)
		}
		.highlight {
			return SystemColor.highlight(scheme)
		}
		.highlighttext {
			return SystemColor.highlight_text(scheme)
		}
		.mark {
			return SystemColor.mark(scheme)
		}
		.marktext {
			return SystemColor.mark_text(scheme)
		}
		.selecteditem {
			return SystemColor.selected_item(scheme)
		}
		.selecteditemtext {
			return SystemColor.selected_item_text(scheme)
		}
		.libweb_buttonfacedisabled {
			return SystemColor.button_face(scheme).with_alpha(128)
		}
		.libweb_buttonfacehover {
			return SystemColor.button_face(scheme).darkened(0.8)
		}
		else {}
	}

	// Boundary: C++ resolves link colors and -libweb-palette-* colors through the document/page palette.
	// The V ColorResolutionContext does not carry a Document yet, so it follows the C++ no-document fallback.
	if style_value.has_color() {
		return Color.black()
	}
	return none
}

pub fn (style_value KeywordStyleValue) absolutized(context ComputationContext) StyleValue {
	_ = context
	if !style_value.has_color() {
		return StyleValue(style_value)
	}

	// The currentcolor keyword computes to itself.
	// https://drafts.csswg.org/css-color-4/#resolving-other-colors
	if style_value.keyword() == .currentcolor {
		return StyleValue(style_value)
	}

	resolved_color := style_value.to_color(ColorResolutionContext{
		color_scheme: context.color_scheme
	}) or { return StyleValue(style_value) }
	return StyleValue(ColorStyleValue.create(resolved_color))
}

pub fn (style_value KeywordStyleValue) tokenize() []ComponentValue {
	keyword_string := string_from_keyword(style_value.keyword_)
	return [
		ComponentValue.from_token(Token.create_ident(keyword_string, keyword_string)),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-ident
pub fn (style_value KeywordStyleValue) reify(associated_property string) CSSStyleValue {
	_ = associated_property
	// 1. Return a new CSSKeywordValue with its value internal slot set to the serialization of ident.
	return CSSStyleValue.from_keyword(CSSKeywordValue.create(string_from_keyword(style_value.keyword_)))
}

pub fn (style_value KeywordStyleValue) properties_equal(other KeywordStyleValue) bool {
	return style_value.keyword_ == other.keyword_
}

// --- LengthStyleValue ---

pub struct LengthStyleValue {
pub mut:
	length_ Length
}

pub fn LengthStyleValue.create(length Length) LengthStyleValue {
	return LengthStyleValue{
		length_: length
	}
}

pub fn (style_value LengthStyleValue) length() Length {
	return style_value.length_
}

pub fn (style_value LengthStyleValue) raw_value() f64 {
	return style_value.length_.raw_value()
}

pub fn (style_value LengthStyleValue) unit_name() string {
	return style_value.length_.unit_name()
}

pub fn (style_value LengthStyleValue) serialize(mode SerializationMode) string {
	return style_value.length_.serialize(mode)
}

pub fn (style_value LengthStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value LengthStyleValue) absolutized(computation_context ComputationContext) LengthStyleValue {
	if length := style_value.length_.absolutize(computation_context.length_resolution_context) {
		return LengthStyleValue.create(length)
	}
	return style_value
}

// --- NumberStyleValue ---

pub struct NumberStyleValue {
pub mut:
	value_ f64
}

pub fn NumberStyleValue.create(value f64) NumberStyleValue {
	return NumberStyleValue{
		value_: value
	}
}

pub fn (style_value NumberStyleValue) number() f64 {
	return style_value.value_
}

pub fn (style_value NumberStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return serialize_a_number(style_value.value_)
}

pub fn (style_value NumberStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value NumberStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_number(Number.with_type(.number, style_value.value_),
			style_value.serialize(.normal))),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-numeric-value
pub fn (style_value NumberStyleValue) reify(associated_property string) CSSStyleValue {
	// NB: Step 1 does not apply here.
	// 2. If num is the unitless value 0 and num is a <dimension>, return a new CSSUnitValue with its value internal
	//    slot set to 0, and its unit internal slot set to "px".
	if style_value.value_ == 0 {
		// NB: Determine whether the associated property expects 0 to be a <length>.
		// FIXME: Do this for registered custom properties.
		if property_id := property_id_from_string(associated_property) {
			if property_accepts_type(property_id, .length) {
				return CSSStyleValue.from_numeric(CSSUnitValue.create(0, 'px'))
			}
		}
	}

	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	return CSSStyleValue.from_numeric(CSSUnitValue.create(style_value.value_, 'number'))
}

// --- RatioStyleValue ---

pub struct RatioStyleValue {
pub mut:
	ratio_ Ratio
}

pub fn RatioStyleValue.create(ratio Ratio) RatioStyleValue {
	return RatioStyleValue{
		ratio_: ratio
	}
}

pub fn (style_value RatioStyleValue) ratio() Ratio {
	return style_value.ratio_
}

pub fn (style_value RatioStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.ratio_.to_string()
}

pub fn (style_value RatioStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_number(Number.with_type(.number,
			style_value.ratio_.numerator()), serialize_a_number(style_value.ratio_.numerator()))),
		ComponentValue.from_token(Token.create_whitespace(' ')),
		ComponentValue.from_token(Token.create_delim(u32(`/`), '/')),
		ComponentValue.from_token(Token.create_whitespace(' ')),
		ComponentValue.from_token(Token.create_number(Number.with_type(.number,
			style_value.ratio_.denominator()), serialize_a_number(style_value.ratio_.denominator()))),
	]
}

// --- IntegerStyleValue ---

pub struct IntegerStyleValue {
pub mut:
	value_ i64
}

pub fn IntegerStyleValue.create(value i64) IntegerStyleValue {
	return IntegerStyleValue{
		value_: value
	}
}

pub fn (style_value IntegerStyleValue) integer() i64 {
	return style_value.value_
}

pub fn (style_value IntegerStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return '${style_value.value_}'
}

pub fn (style_value IntegerStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

pub fn (style_value IntegerStyleValue) tokenize() []ComponentValue {
	return [
		ComponentValue.from_token(Token.create_number(Number.with_type(.integer,
			f64(style_value.value_)), style_value.serialize(.normal))),
	]
}

// https://drafts.css-houdini.org/css-typed-om-1/#reify-a-numeric-value
pub fn (style_value IntegerStyleValue) reify(associated_property string) CSSStyleValue {
	// NB: Step 1 does not apply here.
	// 2. If num is the unitless value 0 and num is a <dimension>, return a new CSSUnitValue with its value internal
	//    slot set to 0, and its unit internal slot set to "px".
	if style_value.value_ == 0 {
		// NB: Determine whether the associated property expects 0 to be a <length>.
		// FIXME: Do this for registered custom properties.
		if property_id := property_id_from_string(associated_property) {
			if property_accepts_type(property_id, .length) {
				return CSSStyleValue.from_numeric(CSSUnitValue.create(0, 'px'))
			}
		}
	}

	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	return CSSStyleValue.from_numeric(CSSUnitValue.create(f64(style_value.value_), 'number'))
}

// --- AngleStyleValue ---

pub struct AngleStyleValue {
pub mut:
	angle_ Angle
}

pub fn AngleStyleValue.create(angle Angle) AngleStyleValue {
	return AngleStyleValue{
		angle_: angle
	}
}

pub fn (style_value AngleStyleValue) angle() Angle {
	return style_value.angle_
}

pub fn (style_value AngleStyleValue) raw_value() f64 {
	return style_value.angle_.raw_value()
}

pub fn (style_value AngleStyleValue) unit_name() string {
	return style_value.angle_.unit_name()
}

pub fn (style_value AngleStyleValue) serialize(mode SerializationMode) string {
	return style_value.angle_.serialize(mode)
}

pub fn (style_value AngleStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

// --- PercentageStyleValue ---

pub struct PercentageStyleValue {
pub mut:
	percentage_ Percentage
}

pub fn PercentageStyleValue.create(percentage Percentage) PercentageStyleValue {
	return PercentageStyleValue{
		percentage_: percentage
	}
}

pub fn (style_value PercentageStyleValue) percentage() Percentage {
	return style_value.percentage_
}

pub fn (style_value PercentageStyleValue) raw_value() f64 {
	return style_value.percentage_.value()
}

pub fn (style_value PercentageStyleValue) unit_name() string {
	return 'percent'
}

pub fn (style_value PercentageStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.percentage_.to_string()
}

pub fn (style_value PercentageStyleValue) to_string() string {
	return style_value.serialize(.normal)
}

// --- Additional dimension style value wrappers needed by CSSUnitValue ---

pub struct FlexStyleValue {
pub mut:
	flex_ Flex
}

pub fn FlexStyleValue.create(flex Flex) FlexStyleValue {
	return FlexStyleValue{
		flex_: flex
	}
}

pub fn (style_value FlexStyleValue) flex() Flex {
	return style_value.flex_
}

pub fn (style_value FlexStyleValue) raw_value() f64 {
	return style_value.flex_.raw_value()
}

pub fn (style_value FlexStyleValue) unit_name() string {
	return style_value.flex_.unit_name()
}

pub fn (style_value FlexStyleValue) serialize(mode SerializationMode) string {
	return style_value.flex_.serialize(mode)
}

pub struct FrequencyStyleValue {
pub mut:
	frequency_ Frequency
}

pub fn FrequencyStyleValue.create(frequency Frequency) FrequencyStyleValue {
	return FrequencyStyleValue{
		frequency_: frequency
	}
}

pub fn (style_value FrequencyStyleValue) frequency() Frequency {
	return style_value.frequency_
}

pub fn (style_value FrequencyStyleValue) raw_value() f64 {
	return style_value.frequency_.raw_value()
}

pub fn (style_value FrequencyStyleValue) unit_name() string {
	return style_value.frequency_.unit_name()
}

pub fn (style_value FrequencyStyleValue) serialize(mode SerializationMode) string {
	return style_value.frequency_.serialize(mode)
}

pub struct ResolutionStyleValue {
pub mut:
	resolution_ Resolution
}

pub fn ResolutionStyleValue.create(resolution Resolution) ResolutionStyleValue {
	return ResolutionStyleValue{
		resolution_: resolution
	}
}

pub fn (style_value ResolutionStyleValue) resolution() Resolution {
	return style_value.resolution_
}

pub fn (style_value ResolutionStyleValue) raw_value() f64 {
	return style_value.resolution_.raw_value()
}

pub fn (style_value ResolutionStyleValue) unit_name() string {
	return style_value.resolution_.unit_name()
}

pub fn (style_value ResolutionStyleValue) serialize(mode SerializationMode) string {
	return style_value.resolution_.serialize(mode)
}

pub struct TimeStyleValue {
pub mut:
	time_ Time
}

pub fn TimeStyleValue.create(time Time) TimeStyleValue {
	return TimeStyleValue{
		time_: time
	}
}

pub fn (style_value TimeStyleValue) time() Time {
	return style_value.time_
}

pub fn (style_value TimeStyleValue) raw_value() f64 {
	return style_value.time_.raw_value()
}

pub fn (style_value TimeStyleValue) unit_name() string {
	return style_value.time_.unit_name()
}

pub fn (style_value TimeStyleValue) serialize(mode SerializationMode) string {
	return style_value.time_.serialize(mode)
}

// --- Explicit stubs for called but untranslated StyleValue subclasses ---

pub struct ColorStyleValue {
pub mut:
	color_ Color
}

pub fn ColorStyleValue.create(color Color) ColorStyleValue {
	return ColorStyleValue{
		color_: color
	}
}

pub fn (style_value ColorStyleValue) color() Color {
	return style_value.color_
}

pub fn (style_value ColorStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.color_.serialize()
}

pub struct CustomIdentStyleValue {
pub mut:
	custom_ident_ string
}

pub fn CustomIdentStyleValue.create(custom_ident string) CustomIdentStyleValue {
	return CustomIdentStyleValue{
		custom_ident_: custom_ident
	}
}

pub fn (style_value CustomIdentStyleValue) custom_ident() string {
	return style_value.custom_ident_
}

pub fn (style_value CustomIdentStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return serialize_an_identifier(style_value.custom_ident_)
}

pub struct StringStyleValue {
pub mut:
	string_value_ string
}

pub fn StringStyleValue.create(value string) StringStyleValue {
	return StringStyleValue{
		string_value_: value
	}
}

pub fn (style_value StringStyleValue) string_value() string {
	return style_value.string_value_
}

pub fn (style_value StringStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return serialize_a_string(style_value.string_value_)
}

pub struct UnresolvedStyleValue {
pub mut:
	tokens []ComponentValue
}

pub fn UnresolvedStyleValue.create(tokens []ComponentValue) UnresolvedStyleValue {
	return UnresolvedStyleValue{
		tokens: tokens
	}
}

pub fn (style_value UnresolvedStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	mut parts := []string{}
	for token in style_value.tokens {
		parts << token.to_string()
	}
	return parts.join(' ')
}

// https://drafts.csswg.org/css-variables/#guaranteed-invalid-value
pub struct GuaranteedInvalidStyleValue {}

pub fn GuaranteedInvalidStyleValue.create() GuaranteedInvalidStyleValue {
	return GuaranteedInvalidStyleValue{}
}

pub fn (style_value GuaranteedInvalidStyleValue) serialize(mode SerializationMode) string {
	_ = style_value
	_ = mode
	return ''
}

pub fn (style_value GuaranteedInvalidStyleValue) tokenize() []ComponentValue {
	_ = style_value
	return [ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
}

pub struct URLStyleValue {
pub mut:
	url_ URL
}

pub fn URLStyleValue.create(url URL) URLStyleValue {
	return URLStyleValue{
		url_: url
	}
}

pub fn (style_value URLStyleValue) url() URL {
	return style_value.url_
}

pub fn (style_value URLStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.url_.to_string()
}

// https://drafts.csswg.org/css-values-5/#pending-substitution-value
pub struct PendingSubstitutionStyleValue {
pub mut:
	original_shorthand_value StyleValue
}

pub fn PendingSubstitutionStyleValue.create(original_shorthand_value StyleValue) PendingSubstitutionStyleValue {
	return PendingSubstitutionStyleValue{
		original_shorthand_value: original_shorthand_value
	}
}

pub fn (style_value PendingSubstitutionStyleValue) serialize(mode SerializationMode) string {
	_ = style_value
	_ = mode
	return ''
}

pub fn (style_value PendingSubstitutionStyleValue) tokenize() []ComponentValue {
	_ = style_value
	// Not sure what to do here, but this isn't valid so returning GIV seems the most correct.
	return [ComponentValue.from_guaranteed_invalid(GuaranteedInvalidValue{})]
}

pub fn (style_value PendingSubstitutionStyleValue) original_shorthand_value_ref() StyleValue {
	return style_value.original_shorthand_value
}

pub struct StubStyleValue {
pub mut:
	type_         StyleValueType
	serialization string
}

pub fn StubStyleValue.create(type_ StyleValueType, serialization string) StubStyleValue {
	return StubStyleValue{
		type_:         type_
		serialization: serialization
	}
}

pub fn (style_value StubStyleValue) serialize(mode SerializationMode) string {
	_ = mode
	return style_value.serialization
}

pub fn (c CalculatedStyleValue) resolves_to_number() bool {
	if numeric_type := c.numeric_type() {
		return numeric_type.matches_number(none)
	}
	return true
}

pub fn (c CalculatedStyleValue) resolves_to_percentage() bool {
	if numeric_type := c.numeric_type() {
		return numeric_type.matches_percentage()
	}
	return c.serialization.trim_space().ends_with('%)')
}

// --- CSSStyleValue ---

pub enum CSSStyleValueKind {
	style
	keyword
	numeric
	transform
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssstylevalue
pub struct CSSStyleValue {
pub mut:
	kind_               CSSStyleValueKind
	associated_property ?string
	source_value_       ?StyleValue
	keyword_value_      ?CSSKeywordValue
	numeric_value_      ?CSSNumericValue
	transform_value_    ?CSSTransformValue
}

pub fn CSSStyleValue.create(associated_property string, source_value StyleValue) CSSStyleValue {
	return CSSStyleValue{
		kind_:               .style
		associated_property: associated_property
		source_value_:       source_value
	}
}

pub fn CSSStyleValue.from_source(source_value StyleValue) CSSStyleValue {
	return CSSStyleValue{
		kind_:         .style
		source_value_: source_value
	}
}

pub fn CSSStyleValue.from_keyword(value CSSKeywordValue) CSSStyleValue {
	return CSSStyleValue{
		kind_:          .keyword
		keyword_value_: value
	}
}

pub fn CSSStyleValue.from_numeric(value CSSNumericValue) CSSStyleValue {
	return CSSStyleValue{
		kind_:          .numeric
		numeric_value_: value
	}
}

pub fn CSSStyleValue.from_transform(value CSSTransformValue) CSSStyleValue {
	return CSSStyleValue{
		kind_:            .transform
		transform_value_: value
	}
}

pub fn (value CSSStyleValue) source_value() ?StyleValue {
	return value.source_value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssstylevalue-parse
pub fn CSSStyleValue.parse(property string, css_text string) !CSSStyleValue {
	// The parse(property, cssText) method, when invoked, must parse a CSSStyleValue with property property, cssText
	// cssText, and parseMultiple set to false, and return the result.
	result := CSSStyleValue.parse_a_css_style_value(property, css_text, false)!
	return result[0]
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssstylevalue-parseall
pub fn CSSStyleValue.parse_all(property string, css_text string) ![]CSSStyleValue {
	// The parseAll(property, cssText) method, when invoked, must parse a CSSStyleValue with property property, cssText
	// cssText, and parseMultiple set to true, and return the result.
	return CSSStyleValue.parse_a_css_style_value(property, css_text, true)!
}

// https://drafts.css-houdini.org/css-typed-om-1/#parse-a-cssstylevalue
pub fn CSSStyleValue.parse_a_css_style_value(property_name string, css_text string, parse_multiple bool) ![]CSSStyleValue {
	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := PropertyNameAndID.from_name(property_name) or {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. Attempt to parse cssText according to property's grammar.
	//    If this fails, throw a TypeError.
	//    Otherwise, let whole value be the parsed result.
	mut parser := Parser.from_css_text(css_text)
	whole_value := if property.is_custom_property() {
		StyleValue(UnresolvedStyleValue.create(parser.component_values))
	} else {
		property_id := property.id() or {
			return error("'${property_name}' is not a valid CSS property")
		}
		parser.parse_css_value(property_id) or {
			return error("Failed to parse '${css_text}' as a value for '${property.name()}' property")
		}
	}

	// 4. Subdivide into iterations whole value, according to property, and let values be the result.
	values := whole_value.subdivide_into_iterations(property)

	// 5. For each value in values, replace it with the result of reifying value for property.
	mut reified_values := []CSSStyleValue{cap: values.len}
	for value in values {
		reified_values << value.reify(property.name())
	}

	// 6. If parseMultiple is false, return values[0]. Otherwise, return values.
	// FIXME: We need to somehow store the source css_text on the returned CSSStyleValue.
	//        https://github.com/w3c/css-houdini-drafts/issues/1156
	if !parse_multiple {
		if reified_values.len == 0 {
			return error("Failed to parse '${css_text}' as a value for '${property.name()}' property")
		}
		return [reified_values[0]]
	}
	return reified_values
}

// https://drafts.css-houdini.org/css-typed-om-1/#stylevalue-serialization
pub fn (value CSSStyleValue) to_string() !string {
	// FIXME: if the value was constructed from a USVString
	{
		// the serialization is the USVString from which the value was constructed.
	}
	// otherwise, if the value was constructed using an IDL constructor
	{
		// the serialization is specified in the sections below.
	}
	if source_value := value.source_value_ {
		return source_value.to_string()
	}
	if keyword_value := value.keyword_value_ {
		return keyword_value.to_string()
	}
	if numeric_value := value.numeric_value_ {
		return numeric_value.to_string()
	}
	if transform_value := value.transform_value_ {
		return transform_value.to_string()!
	}
	{
		// the serialization is specified in section 6.7 Serialization from CSSOM Values below.
	}
	return ''
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (value CSSStyleValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	_ = property
	_ = perform_type_check
	// If value is a direct CSSStyleValue,
	//     Return value's associated value.
	if source_value := value.source_value_ {
		return source_value
	}
	if keyword_value := value.keyword_value_ {
		return keyword_value.create_an_internal_representation(property, perform_type_check)!
	}
	if numeric_value := value.numeric_value_ {
		return numeric_value.create_an_internal_representation(property, perform_type_check)!
	}
	if transform_value := value.transform_value_ {
		return transform_value.create_an_internal_representation(property, perform_type_check)!
	}
	return error('Missing CSSStyleValue.create_an_internal_representation() overload')
}

// --- CSSKeywordValue ---

pub type CSSKeywordish = CSSKeywordValue | string

// https://drafts.css-houdini.org/css-typed-om-1/#csskeywordvalue
pub struct CSSKeywordValue {
pub mut:
	value_ string
}

pub fn CSSKeywordValue.create(value string) CSSKeywordValue {
	return CSSKeywordValue{
		value_: value
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csskeywordvalue-csskeywordvalue
pub fn CSSKeywordValue.construct_impl(value string) !CSSKeywordValue {
	// 1. If value is an empty string, throw a TypeError.
	if value.len == 0 {
		return error('Cannot create a CSSKeywordValue with an empty string as the value')
	}

	// 2. Otherwise, return a new CSSKeywordValue with its value internal slot set to value.
	return CSSKeywordValue.create(value)
}

pub fn (value CSSKeywordValue) value() string {
	return value.value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-csskeywordvalue-value
pub fn (mut value CSSKeywordValue) set_value(new_value string) ! {
	// 1. If value is an empty string, throw a TypeError.
	if new_value.len == 0 {
		return error('Cannot set CSSKeywordValue.value to an empty string')
	}

	// 2. Otherwise, set this's value internal slot, to value.
	value.value_ = new_value
}

// https://drafts.css-houdini.org/css-typed-om-1/#keywordvalue-serialization
pub fn (value CSSKeywordValue) serialize() string {
	// To serialize a CSSKeywordValue this:
	// 1. Return this's value internal slot.
	// AD-HOC: Serialize it as an identifier. Spec issue: https://github.com/w3c/csswg-drafts/issues/12545
	return serialize_an_identifier(value.value_)
}

pub fn (value CSSKeywordValue) to_string() string {
	return value.serialize()
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (value CSSKeywordValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	matches_grammar := fn [value, property] () bool {
		// https://drafts.css-houdini.org/css-typed-om-1/#cssstylevalue-match-a-grammar
		// A CSSKeywordValue matches an <ident> specified in a grammar if its value internal slot matches the
		// identifier.
		// If case-folding rules are in effect normally for that <ident> (such as Auto matching the keyword auto
		// specified in the grammar for width), they apply to this comparison as well.
		if is_css_wide_keyword_string(value.value_) {
			return true
		}
		if property.is_custom_property() {
			// FIXME: If this is a registered custom property, check if that allows the keyword.
			return true
		}
		property_id := property.id() or { return false }
		keyword_from_string(value.value_) or { return false }
		return property_accepts_keyword_string(property_id, value.value_)
	}()
	if perform_type_check == .yes && !matches_grammar {
		return error("Property '${property.name()}' does not accept the keyword '${value.value_}'")
	}

	//     If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	// NB: Non-applicable.

	//     Return the value.
	if keyword := keyword_from_string(value.value_) {
		return StyleValue(KeywordStyleValue.create(keyword))
	}
	return StyleValue(CustomIdentStyleValue.create(value.value_))
}

// https://drafts.css-houdini.org/css-typed-om-1/#rectify-a-keywordish-value
pub fn rectify_a_keywordish_value(keywordish CSSKeywordish) CSSKeywordValue {
	// To rectify a keywordish value val, perform the following steps:
	return match keywordish {
		// 1. If val is a CSSKeywordValue, return val.
		CSSKeywordValue { keywordish }
		// 2. If val is a DOMString, return a new CSSKeywordValue with its value internal slot set to val.
		string { CSSKeywordValue.create(keywordish) }
	}
}

// --- CSSNumericValue ---

pub struct CSSNumericType {
pub mut:
	length       ?int
	angle        ?int
	time         ?int
	frequency    ?int
	resolution   ?int
	flex         ?int
	percent      ?int
	percent_hint ?NumericBaseType
}

pub struct SumValueItem {
pub mut:
	value    f64
	unit_map map[string]int
}

pub type SumValue = []SumValueItem

pub struct CSSNumericSerializationParams {
pub mut:
	minimum   ?f64
	maximum   ?f64
	nested    bool
	parenless bool
}

pub struct CSSMathValueStub {
pub mut:
	type_         NumericType
	serialization string
}

pub fn CSSMathValueStub.create(type_ NumericType, serialization string) CSSMathValueStub {
	return CSSMathValueStub{
		type_:         type_
		serialization: serialization
	}
}

pub type CSSNumericValue = CSSUnitValue
	| CSSMathClamp
	| CSSMathInvert
	| CSSMathMax
	| CSSMathMin
	| CSSMathNegate
	| CSSMathProduct
	| CSSMathSum
	| CSSMathValueStub

pub type CSSNumberish = CSSUnitValue
	| CSSMathClamp
	| CSSMathInvert
	| CSSMathMax
	| CSSMathMin
	| CSSMathNegate
	| CSSMathProduct
	| CSSMathSum
	| CSSMathValueStub
	| f64

pub fn (value CSSNumericValue) type_() NumericType {
	return match value {
		CSSUnitValue { value.type_ }
		CSSMathValueStub { value.type_ }
		CSSMathSum { value.type_ }
		CSSMathProduct { value.type_ }
		CSSMathNegate { value.type_ }
		CSSMathInvert { value.type_ }
		CSSMathMin { value.type_ }
		CSSMathMax { value.type_ }
		CSSMathClamp { value.type_ }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-add
pub fn (value CSSNumericValue) add(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathSum object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.

	// NB: We reorder the steps a little to avoid the awkward prepending.
	mut values := []CSSNumericValue{}
	if value is CSSMathSum {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues and have the same unit, return a new CSSUnitValue whose unit
	//    internal slot is set to that unit, and value internal slot is set to the sum of the value internal slots of
	//    the items in values. This addition must be done "left to right".
	if all_values_are_css_unit_values_with_the_same_unit(values) {
		return CSSNumericValue(apply_math_operation_on_css_unit_values(values, fn (a f64, b f64) f64 {
			return a + b
		}))
	}

	// 4. Let type be the result of adding the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.added_to(values[i].type_()) or {
			return error('Unable to add numeric values with inconsistent types')
		}
	}

	// 5. Return a new CSSMathSum object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathSum.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-sub
pub fn (value CSSNumericValue) sub(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item, then negating the value.
	mut values := []CSSNumberish{}
	for item in initial_values {
		values << rectify_a_numberish_value(item).negate()
	}

	// 2. Return the result of calling the add() internal algorithm with this and values.
	return value.add(values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssmath-negate-a-cssnumericvalue
pub fn (value CSSNumericValue) negate() CSSNumberish {
	// 1. If this is a CSSMathNegate object, return this's value internal slot.
	if value is CSSMathNegate {
		return css_numberish_from_numeric_value(value.value())
	}

	// 2. If this is a CSSUnitValue object, return a new CSSUnitValue with the same unit internal slot as this, and a
	//    value internal slot set to the negation of this's.
	value_to_negate := value
	if value_to_negate is CSSUnitValue {
		return CSSNumberish(CSSUnitValue.create(-value_to_negate.value(), value_to_negate.unit()))
	}

	// 3. Otherwise, return a new CSSMathNegate object whose value internal slot is set to this.
	return CSSNumberish(CSSMathNegate.create(value.type_(), value))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-mul
pub fn (value CSSNumericValue) mul(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathProduct object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.

	// NB: We reorder the steps a little to avoid the awkward prepending.
	mut values := []CSSNumericValue{}
	if value is CSSMathProduct {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues with unit internal slot set to "number", return a new
	//    CSSUnitValue whose unit internal slot is set to "number", and value internal slot is set to the product of the
	//    value internal slots of the items in values.
	// 4. If all of the items in values are CSSUnitValues with unit internal slot set to "number" except one which is
	//    set to unit, return a new CSSUnitValue whose unit internal slot is set to unit, and value internal slot is set
	//    to the product of the value internal slots of the items in values.
	if all_values_are_css_unit_values(values) {
		mut multiple_units_found := false
		mut non_number_unit_index := ?int(none)
		for i, item in values {
			unit_value := item as CSSUnitValue
			unit := unit_value.unit()
			if unit == 'number' {
				continue
			}
			if non_number_unit_index != none {
				multiple_units_found = true
				break
			}
			non_number_unit_index = i
		}
		if !multiple_units_found {
			mut product := 1.0
			for item in values {
				product *= (item as CSSUnitValue).value()
			}
			unit := if index := non_number_unit_index {
				(values[index] as CSSUnitValue).unit()
			} else {
				'number'
			}
			return CSSNumericValue(CSSUnitValue.create(product, unit))
		}
	}

	// 5. Let type be the result of multiplying the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.multiplied_by(values[i].type_()) or {
			return error('Unable to multiply numeric values with inconsistent types')
		}
	}

	// 6. Return a new CSSMathProduct object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathProduct.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-div
pub fn (value CSSNumericValue) div(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item, then inverting the value.
	mut values := []CSSNumberish{}
	for item in initial_values {
		values << rectify_a_numberish_value(item).invert()!
	}

	// 2. Return the result of calling the mul() internal algorithm with this and values.
	return value.mul(values)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssmath-invert-a-cssnumericvalue
pub fn (value CSSNumericValue) invert() !CSSNumberish {
	// 1. If this is a CSSMathInvert object, return this's value internal slot.
	if value is CSSMathInvert {
		return css_numberish_from_numeric_value(value.value())
	}

	// 2. If this is a CSSUnitValue object with unit internal slot set to "number":
	value_to_invert := value
	if value_to_invert is CSSUnitValue {
		if value_to_invert.unit() == 'number' {
			// 1. If this's value internal slot is set to 0 or -0, throw a RangeError.
			if value_to_invert.value() == 0 {
				return error('Zero has no multiplicative inverse')
			}

			// 2. Else return a new CSSUnitValue with the unit internal slot set to "number", and a value internal slot set
			//    to 1 divided by this's CSSUnitValue/value internal slot.
			return CSSNumberish(CSSUnitValue.create(1.0 / value_to_invert.value(), 'number'))
		}
	}

	// 3. Otherwise, return a new CSSMathInvert object whose value internal slot is set to this.
	return CSSNumberish(CSSMathInvert.create(value.type_().inverted(), value))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-min
pub fn (value CSSNumericValue) min(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathMin object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.
	mut values := []CSSNumericValue{}
	if value is CSSMathMin {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues and have the same unit, return a new CSSUnitValue whose unit
	//    internal slot is set to that unit, and value internal slot is set to the minimum of the value internal slots
	//    of the items in values.
	if all_values_are_css_unit_values_with_the_same_unit(values) {
		return CSSNumericValue(apply_math_operation_on_css_unit_values(values, fn (a f64, b f64) f64 {
			return math.min(a, b)
		}))
	}

	// 4. Let type be the result of adding the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.added_to(values[i].type_()) or {
			return error('Unable to compare numeric values with inconsistent types')
		}
	}

	// 5. Return a new CSSMathMin object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathMin.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-max
pub fn (value CSSNumericValue) max(initial_values []CSSNumberish) !CSSNumericValue {
	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. If this is a CSSMathMax object, prepend the items in this's values internal slot to values.
	//    Otherwise, prepend this to values.
	mut values := []CSSNumericValue{}
	if value is CSSMathMax {
		values << value.values().values()
	} else {
		values << value
	}
	for item in initial_values {
		values << rectify_a_numberish_value(item)
	}

	// 3. If all of the items in values are CSSUnitValues and have the same unit, return a new CSSUnitValue whose unit
	//    internal slot is set to that unit, and value internal slot is set to the maximum of the value internal slots
	//    of the items in values.
	if all_values_are_css_unit_values_with_the_same_unit(values) {
		return CSSNumericValue(apply_math_operation_on_css_unit_values(values, fn (a f64, b f64) f64 {
			return math.max(a, b)
		}))
	}

	// 4. Let type be the result of adding the types of every item in values. If type is failure, throw a TypeError.
	mut type_ := values[0].type_()
	for i := 1; i < values.len; i++ {
		type_ = type_.added_to(values[i].type_()) or {
			return error('Unable to compare numeric values with inconsistent types')
		}
	}

	// 5. Return a new CSSMathMax object whose values internal slot is set to values.
	return CSSNumericValue(CSSMathMax.create(type_, CSSNumericArray.create(values)))
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-equals
pub fn (value CSSNumericValue) equals_for_bindings(values []CSSNumberish) bool {
	// The equals(...values) method, when called on a CSSNumericValue this, must perform the following steps:

	// 1. Replace each item of values with the result of rectifying a numberish value for the item.
	// 2. For each item in values, if the item is not an equal numeric value to this, return false.
	for item in values {
		rectified_value := rectify_a_numberish_value(item)
		if !value.is_equal_numeric_value(rectified_value) {
			return false
		}
	}

	// 3. Return true.
	return true
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-to
pub fn (value CSSNumericValue) to(unit string) !CSSUnitValue {
	// The to(unit) method converts an existing CSSNumericValue this into another one with the specified unit, if
	// possible. When called, it must perform the following steps:

	// 1. Let type be the result of creating a type from unit. If type is failure, throw a SyntaxError.
	if NumericType.create_from_unit(unit) == none {
		return error("Unrecognized unit '${unit}'")
	}

	// 2. Let sum be the result of creating a sum value from this. If sum is failure, throw a TypeError.
	sum := value.create_a_sum_value() or {
		return error("Unable to create a sum from input '${value.to_string()}'")
	}

	// 3. If sum has more than one item, throw a TypeError.
	//    Otherwise, let item be the result of creating a CSSUnitValue from the sole item in sum, then converting it to
	//    unit. If item is failure, throw a TypeError.
	if sum.len > 1 {
		return error('Sum contains more than one item')
	}
	item := CSSUnitValue.create_from_sum_value_item(sum[0]) or {
		return error("Unable to create CSSUnitValue from input '${value.to_string()}'")
	}

	converted_item := item.converted_to_unit(unit) or {
		return error("Unable to convert input '${value.to_string()}' to unit '${unit}'")
	}

	// 4. Return item.
	return converted_item
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-type
pub fn (value CSSNumericValue) type_for_bindings() CSSNumericType {
	// 1. Let result be a new CSSNumericType.
	mut result := CSSNumericType{}
	type_ := value.type_()

	// 2. For each baseType -> power in the type of this,
	if power := type_.length_ {
		if power != 0 {
			result.length = power
		}
	}
	if power := type_.angle_ {
		if power != 0 {
			result.angle = power
		}
	}
	if power := type_.time_ {
		if power != 0 {
			result.time = power
		}
	}
	if power := type_.frequency_ {
		if power != 0 {
			result.frequency = power
		}
	}
	if power := type_.resolution_ {
		if power != 0 {
			result.resolution = power
		}
	}
	if power := type_.flex_ {
		if power != 0 {
			result.flex = power
		}
	}
	if power := type_.percent_ {
		if power != 0 {
			result.percent = power
		}
	}

	// 3. If the percent hint of this is not null,
	if percent_hint := type_.percent_hint {
		// 1. Set result[percentHint] to the percent hint of this.
		result.percent_hint = percent_hint
	}

	// 4. Return result.
	return result
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssnumericvalue
pub fn (value CSSNumericValue) serialize(params CSSNumericSerializationParams) string {
	// To serialize a CSSNumericValue this, given an optional minimum, a numeric value, and optional maximum, a numeric value:
	// 1. If this is a CSSUnitValue, serialize a CSSUnitValue from this, passing minimum and maximum. Return the result.
	return match value {
		CSSUnitValue {
			value.serialize_unit_value(params.minimum, params.maximum)
		}
		// 2. Otherwise, serialize a CSSMathValue from this, and return the result.
		CSSMathValueStub {
			value.serialization
		}
		CSSMathSum {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathProduct {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathNegate {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathInvert {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathMin {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathMax {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
		CSSMathClamp {
			value.serialize_math_value(if params.nested { .yes } else { .no }, if params.parenless {
				.without
			} else {
				.with
			})
		}
	}
}

pub fn (value CSSNumericValue) to_string() string {
	return value.serialize(CSSNumericSerializationParams{})
}

pub fn (value CSSNumericValue) is_equal_numeric_value(other CSSNumericValue) bool {
	return match value {
		CSSUnitValue {
			other_value := other
			if other_value is CSSUnitValue {
				value.unit() == other_value.unit() && value.value() == other_value.value()
			} else {
				false
			}
		}
		CSSMathValueStub {
			other_value := other
			if other_value is CSSMathValueStub {
				value.type_ == other_value.type_ && value.serialization == other_value.serialization
			} else {
				false
			}
		}
		CSSMathSum {
			value.is_equal_numeric_value(other)
		}
		CSSMathProduct {
			value.is_equal_numeric_value(other)
		}
		CSSMathNegate {
			value.is_equal_numeric_value(other)
		}
		CSSMathInvert {
			value.is_equal_numeric_value(other)
		}
		CSSMathMin {
			value.is_equal_numeric_value(other)
		}
		CSSMathMax {
			value.is_equal_numeric_value(other)
		}
		CSSMathClamp {
			value.is_equal_numeric_value(other)
		}
	}
}

pub fn (value CSSNumericValue) create_a_sum_value() ?SumValue {
	return match value {
		CSSUnitValue { value.create_a_sum_value() }
		CSSMathValueStub { none }
		CSSMathSum { value.create_a_sum_value() }
		CSSMathProduct { value.create_a_sum_value() }
		CSSMathNegate { value.create_a_sum_value() }
		CSSMathInvert { value.create_a_sum_value() }
		CSSMathMin { value.create_a_sum_value() }
		CSSMathMax { value.create_a_sum_value() }
		CSSMathClamp { value.create_a_sum_value() }
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericvalue-parse
pub fn CSSNumericValue.parse(css_text string) !CSSNumericValue {
	// The parse(cssText) method, when called, must perform the following steps:

	// 1. Parse a component value from cssText and let result be the result. If result is a syntax error, throw a
	//    SyntaxError and abort this algorithm.
	mut parser := RuleSelectorParser.create(ParsingParams{}, css_text, 'utf-8')
	result := parser.parse_as_component_value() or {
		return error('SyntaxError: Unable to parse input as a component value.')
	}

	// 2. If result is not a <number-token>, <percentage-token>, <dimension-token>, or a math function, throw a
	//    SyntaxError and abort this algorithm.
	if !(result.is(.number) || result.is(.percentage) || result.is(.dimension)
		|| css_numeric_value_is_math_function(result)) {
		return error('SyntaxError: Input not a <number-token>, <percentage-token>, <dimension-token>, or a math function.')
	}

	// 3. If result is a <dimension-token> and creating a type from result's unit returns failure, throw a SyntaxError
	//    and abort this algorithm.
	if result.is(.dimension) {
		if NumericType.create_from_unit(result.token().dimension_unit()) == none {
			return error('SyntaxError: Input is <dimension> with an unrecognized unit.')
		}
	}

	// 4. Reify a numeric value result, and return the result.
	return css_numeric_value_reify_component_value(result)!
}

fn css_numeric_value_is_math_function(component_value ComponentValue) bool {
	if !component_value.is_function() {
		return false
	}

	return match to_ascii_lowercase(component_value.function().name) {
		'abs', 'acos', 'asin', 'atan', 'atan2', 'clamp', 'calc', 'cos', 'exp', 'hypot', 'log',
		'max', 'min', 'mod', 'pow', 'random', 'rem', 'round', 'sign', 'sin', 'sqrt', 'tan' {
			true
		}
		else {
			false
		}
	}
}

fn css_numeric_value_reify_component_value(numeric_value ComponentValue) !CSSNumericValue {
	// To reify a numeric value num:
	// 1. If num is a math function, reify a math expression from num and return the result.
	if numeric_value.is_function() {
		return css_numeric_value_reify_math_function(numeric_value)!
	}

	// 2. If num is the unitless value 0 and num is a <dimension>, return a new CSSUnitValue with its value internal
	//    slot set to 0, and its unit internal slot set to "px".
	// FIXME: What does this mean? We just have a component value, it doesn't have any knowledge about whether 0 should
	//        be interpreted as a dimension.

	// 3. Return a new CSSUnitValue with its value internal slot set to the numeric value of num, and its unit internal
	//    slot set to "number" if num is a <number>, "percent" if num is a <percentage>, and num's unit if num is a
	//    <dimension>.
	//    If the value being reified is a computed value, the unit used must be the appropriate canonical unit for the
	//    value's type, with the numeric value scaled accordingly.
	// NB: The computed value part is irrelevant here, I think.
	if numeric_value.is(.number) {
		return CSSNumericValue(CSSUnitValue.create(numeric_value.token().number_value(), 'number'))
	}
	if numeric_value.is(.percentage) {
		return CSSNumericValue(CSSUnitValue.create(numeric_value.token().percentage(), 'percent'))
	}
	if !numeric_value.is(.dimension) {
		panic('VERIFY_NOT_REACHED')
	}
	return CSSNumericValue(CSSUnitValue.create(numeric_value.token().dimension_value(),
		numeric_value.token().dimension_unit()))
}

fn css_numeric_value_reify_single_component(values []ComponentValue) !CSSNumericValue {
	components := remove_whitespace_from_component_values(values)
	if components.len != 1 {
		return error('SyntaxError: Unable to parse input as a calculation tree.')
	}
	return css_numeric_value_reify_component_value(components[0])!
}

fn css_numeric_value_reify_math_function(numeric_value ComponentValue) !CSSNumericValue {
	function := numeric_value.function()
	name := to_ascii_lowercase(function.name)

	// The C++ implementation parses every math function through CalculatedStyleValue and then reifies the resulting
	// CalculationNode tree. This port has the Typed OM math classes but not the full calculation parser yet, so wire the
	// directly representable functions and keep the upstream SyntaxError behavior for the remaining function grammar.
	if name == 'calc' {
		return css_numeric_value_reify_single_component(function.value)!
	}

	arguments := parse_a_comma_separated_list_of_component_values_for_value_logic(function.value)
	if name == 'min' || name == 'max' {
		if arguments.len == 0 {
			return error('SyntaxError: Unable to parse input as a calculation tree.')
		}
		mut values := []CSSNumericValue{}
		for argument in arguments {
			values << css_numeric_value_reify_single_component(argument)!
		}
		if name == 'min' {
			return CSSNumericValue(CSSMathMin.add_all_types_into_math_min(values)!)
		}
		return CSSNumericValue(CSSMathMax.add_all_types_into_math_max(values)!)
	}

	if name == 'clamp' {
		if arguments.len != 3 {
			return error('SyntaxError: Unable to parse input as a calculation tree.')
		}
		lower :=
			css_numberish_from_numeric_value(css_numeric_value_reify_single_component(arguments[0])!)
		value :=
			css_numberish_from_numeric_value(css_numeric_value_reify_single_component(arguments[1])!)
		upper :=
			css_numberish_from_numeric_value(css_numeric_value_reify_single_component(arguments[2])!)
		return CSSNumericValue(CSSMathClamp.construct_impl(lower, value, upper)!)
	}

	return error('SyntaxError: Unable to parse input as a calculation tree.')
}

// https://drafts.css-houdini.org/css-typed-om-1/#rectify-a-numberish-value
pub fn rectify_a_numberish_value(numberish CSSNumberish) CSSNumericValue {
	// To rectify a numberish value num, optionally to a given unit unit (defaulting to "number"), perform the following steps:
	return rectify_a_numberish_value_with_unit(numberish, none)
}

pub fn rectify_a_numberish_value_with_unit(numberish CSSNumberish, unit ?string) CSSNumericValue {
	// To rectify a numberish value num, optionally to a given unit unit (defaulting to "number"), perform the following steps:
	return match numberish {
		// 1. If num is a CSSNumericValue, return num.
		CSSUnitValue { CSSNumericValue(numberish) }
		CSSMathValueStub { CSSNumericValue(numberish) }
		CSSMathSum { CSSNumericValue(numberish) }
		CSSMathProduct { CSSNumericValue(numberish) }
		CSSMathNegate { CSSNumericValue(numberish) }
		CSSMathInvert { CSSNumericValue(numberish) }
		CSSMathMin { CSSNumericValue(numberish) }
		CSSMathMax { CSSNumericValue(numberish) }
		CSSMathClamp { CSSNumericValue(numberish) }
		// 2. If num is a double, return a new CSSUnitValue with its value internal slot set to num and its unit
		//    internal slot set to unit.
		f64 { CSSNumericValue(CSSUnitValue.create(numberish, unit or { 'number' })) }
	}
}

fn all_values_are_css_unit_values(values []CSSNumericValue) bool {
	for value in values {
		if value !is CSSUnitValue {
			return false
		}
	}
	return true
}

fn all_values_are_css_unit_values_with_the_same_unit(values []CSSNumericValue) bool {
	if values.len == 0 {
		return false
	}
	first_value := values[0]
	if first_value !is CSSUnitValue {
		return false
	}
	first := first_value as CSSUnitValue
	for value in values {
		if value !is CSSUnitValue {
			return false
		}
		unit_value := value as CSSUnitValue
		if unit_value.unit() != first.unit() {
			return false
		}
	}
	return true
}

fn apply_math_operation_on_css_unit_values(values []CSSNumericValue, operation fn (f64, f64) f64) CSSUnitValue {
	first_unit_value := values[0] as CSSUnitValue
	unit := first_unit_value.unit()

	mut result := first_unit_value.value()
	for i := 1; i < values.len; i++ {
		result = operation(result, (values[i] as CSSUnitValue).value())
	}
	return CSSUnitValue.create(result, unit)
}

fn numeric_values_join(values []CSSNumericValue, separator string) string {
	mut parts := []string{}
	for value in values {
		parts << value.to_string()
	}
	return parts.join(separator)
}

// --- CSSUnitValue ---

pub type NumericPrimitiveValue = Angle
	| Flex
	| Frequency
	| Length
	| Number
	| Percentage
	| Resolution
	| Time

// https://drafts.css-houdini.org/css-typed-om-1/#cssunitvalue
pub struct CSSUnitValue {
pub mut:
	value_ f64
	unit_  string
	type_  NumericType
}

pub fn CSSUnitValue.create(value f64, unit string) CSSUnitValue {
	// The type of a CSSUnitValue is the result of creating a type from its unit internal slot.
	// https://drafts.css-houdini.org/css-typed-om-1/#type-of-a-cssunitvalue
	numeric_type := NumericType.create_from_unit(unit) or { NumericType.new() }
	return CSSUnitValue{
		value_: value
		// AD-HOC: WPT expects the unit to be lowercase but this does not seem to be specified anywhere.
		unit_: to_ascii_lowercase(unit)
		type_: numeric_type
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-cssunitvalue-from-a-sum-value-item
pub fn CSSUnitValue.create_from_sum_value_item(item SumValueItem) ?CSSUnitValue {
	// 1. If item has more than one entry in its unit map, return failure.
	if item.unit_map.len > 1 {
		return none
	}

	// 2. If item has no entries in its unit map, return a new CSSUnitValue whose unit internal slot is set to
	//    "number", and whose value internal slot is set to item's value.
	if item.unit_map.len == 0 {
		return CSSUnitValue.create(item.value, 'number')
	}

	// 3. Otherwise, item has a single entry in its unit map. If that entry's value is anything other than 1, return
	//    failure.
	for unit, power in item.unit_map {
		if power != 1 {
			return none
		}

		// 4. Otherwise, return a new CSSUnitValue whose unit internal slot is set to that entry's key, and whose value
		//    internal slot is set to item's value.
		return CSSUnitValue.create(item.value, unit)
	}
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssunitvalue-cssunitvalue
pub fn CSSUnitValue.construct_impl(value f64, unit string) !CSSUnitValue {
	// 1. If creating a type from unit returns failure, throw a TypeError and abort this algorithm.
	numeric_type := NumericType.create_from_unit(unit) or {
		return error("Cannot create CSSUnitValue with unrecognized unit '${unit}'")
	}

	// 2. Return a new CSSUnitValue with its value internal slot set to value and its unit set to unit.
	return CSSUnitValue{
		value_: value
		unit_:  to_ascii_lowercase(unit)
		type_:  numeric_type
	}
}

pub fn (unit_value CSSUnitValue) value() f64 {
	return unit_value.value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssunitvalue-value
pub fn (mut unit_value CSSUnitValue) set_value(value f64) {
	// AD-HOC: No definition: https://github.com/w3c/css-houdini-drafts/issues/1146
	unit_value.value_ = value
}

pub fn (unit_value CSSUnitValue) unit() string {
	return unit_value.unit_
}

// https://drafts.css-houdini.org/css-typed-om-1/#serialize-a-cssunitvalue
pub fn (unit_value CSSUnitValue) serialize_unit_value(minimum ?f64, maximum ?f64) string {
	// To serialize a CSSUnitValue this, with optional arguments minimum, a numeric value, and maximum, a numeric value:

	// 1. Let value and unit be this's value and unit internal slots.

	// 4. If minimum was passed and this is less than minimum, or if maximum was passed and this is greater than
	//    maximum, or either minimum and/or maximum were passed and the relative size of this and minimum/maximum cannot
	//    be determined with the available information at this time, prepend "calc(" to s, then append ")" to s.
	// NB: This step is done first to avoid prepending to the StringBuilder.
	// FIXME: "or either minimum and/or maximum were passed and the relative size of this and minimum/maximum cannot be determined with the available information at this time"
	needs_calc_wrapper := (minimum != none && unit_value.value_ < minimum or { 0 }) || (maximum != none && unit_value.value_ > maximum or {
		0
	})

	mut serialized := ''
	if needs_calc_wrapper {
		serialized += 'calc('
	}

	// 2. Set s to the result of serializing a <number> from value, per CSSOM section 6.7.2 Serializing CSS Values.
	serialized += serialize_a_number(unit_value.value_)

	// 3. If unit is:
	// -> "number"
	if unit_value.unit_ == 'number' {
		// Do nothing.
	}
	// -> "percent"
	else if unit_value.unit_ == 'percent' {
		// Append "%" to s.
		serialized += '%'
	}
	// -> anything else
	else {
		// Append unit to s.
		serialized += to_ascii_lowercase(unit_value.unit_)
	}

	if needs_calc_wrapper {
		serialized += ')'
	}

	// 5. Return s.
	return serialized
}

// https://drafts.css-houdini.org/css-typed-om-1/#convert-a-cssunitvalue
pub fn (unit_value CSSUnitValue) converted_to_unit(unit string) ?CSSUnitValue {
	// 1. Let old unit be the value of this's unit internal slot, and old value be the value of this's value internal
	//    slot.
	old_unit := unit_value.unit_
	old_value := unit_value.value_
	new_unit := to_ascii_lowercase(unit)

	// 2. If old unit and unit are not compatible units, return failure.
	mut ratio := 1.0
	// NB: If the units are identical, they are always compatible. That also covers cases of `number` and `percent`
	//     which are not actually units.
	if old_unit != new_unit {
		old_dimension_type := dimension_for_unit(old_unit) or { return none }
		new_dimension_type := dimension_for_unit(new_unit) or { return none }
		if old_dimension_type != new_dimension_type {
			return none
		}

		match new_dimension_type {
			.angle {
				from := string_to_angle_unit(old_unit) or { return none }
				to := string_to_angle_unit(new_unit) or { return none }
				if !angle_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_angle_units(from, to)
			}
			.flex {
				from := string_to_flex_unit(old_unit) or { return none }
				to := string_to_flex_unit(new_unit) or { return none }
				if !flex_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_flex_units(from, to)
			}
			.frequency {
				from := string_to_frequency_unit(old_unit) or { return none }
				to := string_to_frequency_unit(new_unit) or { return none }
				if !frequency_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_frequency_units(from, to)
			}
			.length {
				from := string_to_length_unit(old_unit) or { return none }
				to := string_to_length_unit(new_unit) or { return none }
				if !length_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_length_units(from, to)
			}
			.resolution {
				from := string_to_resolution_unit(old_unit) or { return none }
				to := string_to_resolution_unit(new_unit) or { return none }
				if !resolution_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_resolution_units(from, to)
			}
			.time {
				from := string_to_time_unit(old_unit) or { return none }
				to := string_to_time_unit(new_unit) or { return none }
				if !time_units_are_compatible(from, to) {
					return none
				}
				ratio = ratio_between_time_units(from, to)
			}
		}
	}

	// 3. Return a new CSSUnitValue whose unit internal slot is set to unit, and whose value internal slot is set to
	//    old value multiplied by the conversion ratio between old unit and unit.
	return CSSUnitValue.create(old_value * ratio, new_unit)
}

pub fn (unit_value CSSUnitValue) is_equal_numeric_value(other CSSNumericValue) bool {
	// NB: Only steps 1 and 2 are relevant.
	// 1. If value1 and value2 are not members of the same interface, return false.
	other_unit_value := other
	if other_unit_value !is CSSUnitValue {
		return false
	}
	other_value := other_unit_value as CSSUnitValue

	// 2. If value1 and value2 are both CSSUnitValues, return true if they have equal unit and value internal slots,
	//    or false otherwise.
	return unit_value.unit_ == other_value.unit_ && unit_value.value_ == other_value.value_
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-a-sum-value
pub fn (unit_value CSSUnitValue) create_a_sum_value() ?SumValue {
	// 1. Let unit be the value of this's unit internal slot, and value be the value of this's value internal slot.
	mut unit := unit_value.unit_
	mut value := unit_value.value_

	// 2. If unit is a member of a set of compatible units, and is not the set's canonical unit, multiply value
	//    by the conversion ratio between unit and the canonical unit, and change unit to the canonical unit.
	if dimension_type := dimension_for_unit(unit) {
		match dimension_type {
			.angle {
				angle_unit := string_to_angle_unit(unit) or { return none }
				canonical_unit := canonical_angle_unit()
				if angle_unit != canonical_unit
					&& angle_units_are_compatible(angle_unit, canonical_unit) {
					value *= ratio_between_angle_units(angle_unit, canonical_unit)
					unit = angle_unit_name(canonical_unit)
				}
			}
			.flex {
				flex_unit := string_to_flex_unit(unit) or { return none }
				canonical_unit := canonical_flex_unit()
				if flex_unit != canonical_unit
					&& flex_units_are_compatible(flex_unit, canonical_unit) {
					value *= ratio_between_flex_units(flex_unit, canonical_unit)
					unit = flex_unit_name(canonical_unit)
				}
			}
			.frequency {
				frequency_unit := string_to_frequency_unit(unit) or { return none }
				canonical_unit := canonical_frequency_unit()
				if frequency_unit != canonical_unit
					&& frequency_units_are_compatible(frequency_unit, canonical_unit) {
					value *= ratio_between_frequency_units(frequency_unit, canonical_unit)
					unit = to_ascii_lowercase(frequency_unit_name(canonical_unit))
				}
			}
			.length {
				length_unit := string_to_length_unit(unit) or { return none }
				canonical_unit := canonical_length_unit()
				if length_unit != canonical_unit
					&& length_units_are_compatible(length_unit, canonical_unit) {
					value *= ratio_between_length_units(length_unit, canonical_unit)
					unit = length_unit_name(canonical_unit)
				}
			}
			.resolution {
				resolution_unit := string_to_resolution_unit(unit) or { return none }
				canonical_unit := canonical_resolution_unit()
				if resolution_unit != canonical_unit
					&& resolution_units_are_compatible(resolution_unit, canonical_unit) {
					value *= ratio_between_resolution_units(resolution_unit, canonical_unit)
					unit = resolution_unit_name(canonical_unit)
				}
			}
			.time {
				time_unit := string_to_time_unit(unit) or { return none }
				canonical_unit := canonical_time_unit()
				if time_unit != canonical_unit
					&& time_units_are_compatible(time_unit, canonical_unit) {
					value *= ratio_between_time_units(time_unit, canonical_unit)
					unit = time_unit_name(canonical_unit)
				}
			}
		}
	}

	// 3. If unit is "number", return [(value, [])].
	if unit == 'number' {
		return [SumValueItem{
			value:    value
			unit_map: map[string]int{}
		}]
	}

	// 4. Otherwise, return [(value, [unit -> 1])].
	return [SumValueItem{
		value:    value
		unit_map: {
			unit: 1
		}
	}]
}

fn create_numeric_value(value f64, unit string) ?NumericPrimitiveValue {
	if unit == 'number' {
		return NumericPrimitiveValue(Number.with_type(.number, value))
	}

	if unit == 'percent' {
		return NumericPrimitiveValue(Percentage.new(value))
	}

	if dimension_type := dimension_for_unit(unit) {
		match dimension_type {
			.angle {
				return NumericPrimitiveValue(Angle.new(value, string_to_angle_unit(unit) or {
					return none
				}))
			}
			.flex {
				return NumericPrimitiveValue(Flex.new(value, string_to_flex_unit(unit) or {
					return none
				}))
			}
			.frequency {
				return NumericPrimitiveValue(Frequency.new(value, string_to_frequency_unit(unit) or {
					return none
				}))
			}
			.length {
				return NumericPrimitiveValue(Length.new(value, string_to_length_unit(unit) or {
					return none
				}))
			}
			.resolution {
				return NumericPrimitiveValue(Resolution.new(value, string_to_resolution_unit(unit) or {
					return none
				}))
			}
			.time {
				return NumericPrimitiveValue(Time.new(value, string_to_time_unit(unit) or {
					return none
				}))
			}
		}
	}

	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
pub fn (unit_value CSSUnitValue) create_an_internal_representation(property PropertyNameAndID, perform_type_check PerformTypeCheck) !StyleValue {
	// If value is a CSSStyleValue subclass,
	//     If value does not match the grammar of a list-valued property iteration of property, throw a TypeError.
	//
	//     If any component of property's CSS grammar has a limited numeric range, and the corresponding part of value
	//     is a CSSUnitValue that is outside of that range, replace that value with the result of wrapping it in a
	//     fresh CSSMathSum whose values internal slot contains only that part of value.
	//
	//     Return the value.

	// NB: We store all custom properties as UnresolvedStyleValue, so we always need to create one here.
	if perform_type_check == .yes && property.is_custom_property() {
		token := if unit_value.unit_ == 'number' {
			component_value_from_text(serialize_a_number(unit_value.value_))
		} else if unit_value.unit_ == 'percent' {
			component_value_from_text('${serialize_a_number(unit_value.value_)}%')
		} else {
			component_value_from_text('${serialize_a_number(unit_value.value_)}${unit_value.unit_}')
		}
		return StyleValue(UnresolvedStyleValue.create([token]))
	}

	context := CalculationContext.for_property(property)
	wrap_in_math_sum := fn [context] (primitive NumericPrimitiveValue) StyleValue {
		serialization := match primitive {
			Number { primitive.serialize(.normal) }
			Percentage { primitive.serialize(.normal) }
			Angle { primitive.serialize(.normal) }
			Flex { primitive.serialize(.normal) }
			Frequency { primitive.serialize(.normal) }
			Length { primitive.serialize(.normal) }
			Resolution { primitive.serialize(.normal) }
			Time { primitive.serialize(.normal) }
		}

		type_ := NumericType.create_from_unit(match primitive {
			Number { 'number' }
			Percentage { 'percent' }
			Angle { primitive.unit_name() }
			Flex { primitive.unit_name() }
			Frequency { primitive.unit_name() }
			Length { primitive.unit_name() }
			Resolution { primitive.unit_name() }
			Time { primitive.unit_name() }
		}) or { NumericType.new() }
		return StyleValue(CalculatedStyleValue.create(CalculationNode{
			serialization: 'calc(${serialization})'
		}, type_, context))
	}

	value := create_numeric_value(unit_value.value_, unit_value.unit_) or {
		return error("Unrecognized unit '${unit_value.unit_}'.")
	}

	if perform_type_check == .no {
		return match value {
			Number { StyleValue(NumberStyleValue.create(value.value())) }
			Percentage { StyleValue(PercentageStyleValue.create(value)) }
			Angle { StyleValue(AngleStyleValue.create(value)) }
			Flex { StyleValue(FlexStyleValue.create(value)) }
			Frequency { StyleValue(FrequencyStyleValue.create(value)) }
			Length { StyleValue(LengthStyleValue.create(value)) }
			Resolution { StyleValue(ResolutionStyleValue.create(value)) }
			Time { StyleValue(TimeStyleValue.create(value)) }
		}
	}

	property_id := property.id() or {
		return error('Property does not accept values of this type.')
	}
	style_value := match value {
		Number {
			// NB: Number before Integer, because a custom property accepts either and we want to avoid rounding in that case.
			if property_accepts_type(property_id, .number) {
				if property_accepts_number(property_id, value.value()) {
					?StyleValue(StyleValue(NumberStyleValue.create(value.value())))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else if property_accepts_type(property_id, .integer) {
				// NB: Same rounding as CalculatedStyleValue::resolve_integer(). Maybe this should go somewhere central?
				integer := i64(math.round(value.value()))
				if property_accepts_integer(property_id, integer) {
					?StyleValue(StyleValue(IntegerStyleValue.create(integer)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Percentage {
			if property_accepts_type(property_id, .percentage) {
				if property_accepts_percentage(property_id, value) {
					?StyleValue(StyleValue(PercentageStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Angle {
			if property_accepts_type(property_id, .angle) {
				if property_accepts_angle(property_id, value) {
					?StyleValue(StyleValue(AngleStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Flex {
			if property_accepts_type(property_id, .flex) {
				if property_accepts_flex(property_id, value) {
					?StyleValue(StyleValue(FlexStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Frequency {
			if property_accepts_type(property_id, .frequency) {
				if property_accepts_frequency(property_id, value) {
					?StyleValue(StyleValue(FrequencyStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Length {
			if property_accepts_type(property_id, .length) {
				if property_accepts_length(property_id, value) {
					?StyleValue(StyleValue(LengthStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Resolution {
			if property_accepts_type(property_id, .resolution) {
				if property_accepts_resolution(property_id, value) {
					?StyleValue(StyleValue(ResolutionStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
		Time {
			if property_accepts_type(property_id, .time) {
				if property_accepts_time(property_id, value) {
					?StyleValue(StyleValue(TimeStyleValue.create(value)))
				} else {
					?StyleValue(wrap_in_math_sum(value))
				}
			} else {
				?StyleValue(none)
			}
		}
	}

	return style_value or { error('Property does not accept values of this type.') }
}

pub fn (unit_value CSSUnitValue) create_calculation_node(context CalculationContext) !CalculationNode {
	_ = context
	value := create_numeric_value(unit_value.value_, unit_value.unit_) or {
		return error('Unable to create calculation node from `${unit_value.value_}${unit_value.unit_}`.')
	}

	return CalculationNode{
		serialization: match value {
			Number { value.serialize(.normal) }
			Percentage { value.serialize(.normal) }
			Angle { value.serialize(.normal) }
			Flex { value.serialize(.normal) }
			Frequency { value.serialize(.normal) }
			Length { value.serialize(.normal) }
			Resolution { value.serialize(.normal) }
			Time { value.serialize(.normal) }
		}
	}
}

// --- CSSNumericArray ---

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericarray
pub struct CSSNumericArray {
pub mut:
	values_ []CSSNumericValue
}

pub fn CSSNumericArray.create(values []CSSNumericValue) CSSNumericArray {
	return CSSNumericArray{
		values_: values
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-cssnumericarray-length
pub fn (array CSSNumericArray) length() u32 {
	// The length attribute of CSSNumericArray indicates how many CSSNumericValues are contained within the CSSNumericArray.
	return u32(array.values_.len)
}

// https://drafts.css-houdini.org/css-typed-om-1/#cssnumericarray-indexed-property-getter
pub fn (array CSSNumericArray) item_value(index int) ?CSSNumericValue {
	// The indexed property getter of CSSNumericArray retrieves the CSSNumericValue at the provided index.
	if index < 0 || index >= array.values_.len {
		return none
	}
	return array.values_[index]
}

pub fn (array CSSNumericArray) values() []CSSNumericValue {
	return array.values_
}

// https://drafts.css-houdini.org/css-typed-om-1/#equal-numeric-value
pub fn (array CSSNumericArray) is_equal_numeric_values(other CSSNumericArray) bool {
	// NB: This is just step 3, moved here to reduce repetition.
	// 3. If value1 and value2 are both CSSMathSums, CSSMathProducts, CSSMathMins, or CSSMathMaxs:
	{
		// 1. If value1's values and value2s values internal slots have different sizes, return false.
		if array.values_.len != other.values_.len {
			return false
		}

		// 2. If any item in value1's values internal slot is not an equal numeric value to the item in value2's values
		//    internal slot at the same index, return false.
		for index := 0; index < array.values_.len; index++ {
			if !array.values_[index].is_equal_numeric_value(other.values_[index]) {
				return false
			}
		}

		// 3. Return true.
		return true
	}
}
