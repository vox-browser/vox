// Generated from Ladybird Libraries/LibWeb/CSS/Properties.json,
// LogicalPropertyGroups.json, and Enums.json by
// tools/generate_css_calculation_metadata.py. Do not edit by hand.
module css

import math

fn canonical_property_name_from_metadata(name string) string {
	return match name {
		'-moz-appearance', '-webkit-appearance' {
			'appearance'
		}
		'-webkit-align-content' {
			'align-content'
		}
		'-webkit-align-items', '-webkit-box-align' {
			'align-items'
		}
		'-webkit-align-self' {
			'align-self'
		}
		'-webkit-animation' {
			'animation'
		}
		'-webkit-animation-delay' {
			'animation-delay'
		}
		'-webkit-animation-direction' {
			'animation-direction'
		}
		'-webkit-animation-duration' {
			'animation-duration'
		}
		'-webkit-animation-fill-mode' {
			'animation-fill-mode'
		}
		'-webkit-animation-iteration-count' {
			'animation-iteration-count'
		}
		'-webkit-animation-name' {
			'animation-name'
		}
		'-webkit-animation-play-state' {
			'animation-play-state'
		}
		'-webkit-animation-timing-function' {
			'animation-timing-function'
		}
		'-webkit-background-clip' {
			'background-clip'
		}
		'-webkit-background-origin' {
			'background-origin'
		}
		'-webkit-background-size' {
			'background-size'
		}
		'-webkit-border-bottom-left-radius' {
			'border-bottom-left-radius'
		}
		'-webkit-border-bottom-right-radius' {
			'border-bottom-right-radius'
		}
		'-webkit-border-radius' {
			'border-radius'
		}
		'-webkit-border-top-left-radius' {
			'border-top-left-radius'
		}
		'-webkit-border-top-right-radius' {
			'border-top-right-radius'
		}
		'-webkit-box-flex', '-webkit-flex-grow' {
			'flex-grow'
		}
		'-webkit-box-ordinal-group', '-webkit-order' {
			'order'
		}
		'-webkit-box-orient', '-webkit-flex-direction' {
			'flex-direction'
		}
		'-webkit-box-pack', '-webkit-justify-content' {
			'justify-content'
		}
		'-webkit-box-shadow' {
			'box-shadow'
		}
		'-webkit-box-sizing' {
			'box-sizing'
		}
		'-webkit-filter' {
			'filter'
		}
		'-webkit-flex' {
			'flex'
		}
		'-webkit-flex-basis' {
			'flex-basis'
		}
		'-webkit-flex-flow' {
			'flex-flow'
		}
		'-webkit-flex-shrink' {
			'flex-shrink'
		}
		'-webkit-flex-wrap' {
			'flex-wrap'
		}
		'-webkit-mask' {
			'mask'
		}
		'-webkit-mask-clip' {
			'mask-clip'
		}
		'-webkit-mask-composite' {
			'mask-composite'
		}
		'-webkit-mask-image' {
			'mask-image'
		}
		'-webkit-mask-origin' {
			'mask-origin'
		}
		'-webkit-mask-position' {
			'mask-position'
		}
		'-webkit-mask-repeat' {
			'mask-repeat'
		}
		'-webkit-mask-size' {
			'mask-size'
		}
		'-webkit-perspective' {
			'perspective'
		}
		'-webkit-perspective-origin' {
			'perspective-origin'
		}
		'-webkit-transform' {
			'transform'
		}
		'-webkit-transform-origin' {
			'transform-origin'
		}
		'-webkit-transform-style' {
			'transform-style'
		}
		'-webkit-transition' {
			'transition'
		}
		'-webkit-transition-delay' {
			'transition-delay'
		}
		'-webkit-transition-duration' {
			'transition-duration'
		}
		'-webkit-transition-property' {
			'transition-property'
		}
		'-webkit-transition-timing-function' {
			'transition-timing-function'
		}
		'-webkit-user-select' {
			'user-select'
		}
		'font-stretch' {
			'font-width'
		}
		'grid-column-gap' {
			'column-gap'
		}
		'grid-gap' {
			'gap'
		}
		'grid-row-gap' {
			'row-gap'
		}
		'word-wrap' {
			'overflow-wrap'
		}
		else { name }
	}
}

fn property_id_from_canonical_name(name string) ?PropertyID {
	return match name {
		'-webkit-text-fill-color' {
			PropertyID.webkit_text_fill_color
		}
		'accent-color' {
			PropertyID.accent_color
		}
		'align-content' {
			PropertyID.align_content
		}
		'align-items' {
			PropertyID.align_items
		}
		'align-self' {
			PropertyID.align_self
		}
		'all' {
			PropertyID.all
		}
		'anchor-name' {
			PropertyID.anchor_name
		}
		'anchor-scope' {
			PropertyID.anchor_scope
		}
		'animation' {
			PropertyID.animation
		}
		'animation-composition' {
			PropertyID.animation_composition
		}
		'animation-delay' {
			PropertyID.animation_delay
		}
		'animation-direction' {
			PropertyID.animation_direction
		}
		'animation-duration' {
			PropertyID.animation_duration
		}
		'animation-fill-mode' {
			PropertyID.animation_fill_mode
		}
		'animation-iteration-count' {
			PropertyID.animation_iteration_count
		}
		'animation-name' {
			PropertyID.animation_name
		}
		'animation-play-state' {
			PropertyID.animation_play_state
		}
		'animation-timeline' {
			PropertyID.animation_timeline
		}
		'animation-timing-function' {
			PropertyID.animation_timing_function
		}
		'appearance' {
			PropertyID.appearance
		}
		'aspect-ratio' {
			PropertyID.aspect_ratio
		}
		'backdrop-filter' {
			PropertyID.backdrop_filter
		}
		'background' {
			PropertyID.background
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
		'background-color' {
			PropertyID.background_color
		}
		'background-image' {
			PropertyID.background_image
		}
		'background-origin' {
			PropertyID.background_origin
		}
		'background-position' {
			PropertyID.background_position
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
		'border' {
			PropertyID.border
		}
		'border-block' {
			PropertyID.border_block
		}
		'border-block-color' {
			PropertyID.border_block_color
		}
		'border-block-end' {
			PropertyID.border_block_end
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
		'border-block-start' {
			PropertyID.border_block_start
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
		'border-block-style' {
			PropertyID.border_block_style
		}
		'border-block-width' {
			PropertyID.border_block_width
		}
		'border-bottom' {
			PropertyID.border_bottom
		}
		'border-bottom-color' {
			PropertyID.border_bottom_color
		}
		'border-bottom-left-radius' {
			PropertyID.border_bottom_left_radius
		}
		'border-bottom-right-radius' {
			PropertyID.border_bottom_right_radius
		}
		'border-bottom-style' {
			PropertyID.border_bottom_style
		}
		'border-bottom-width' {
			PropertyID.border_bottom_width
		}
		'border-collapse' {
			PropertyID.border_collapse
		}
		'border-color' {
			PropertyID.border_color
		}
		'border-end-end-radius' {
			PropertyID.border_end_end_radius
		}
		'border-end-start-radius' {
			PropertyID.border_end_start_radius
		}
		'border-image' {
			PropertyID.border_image
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
		'border-inline' {
			PropertyID.border_inline
		}
		'border-inline-color' {
			PropertyID.border_inline_color
		}
		'border-inline-end' {
			PropertyID.border_inline_end
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
		'border-inline-start' {
			PropertyID.border_inline_start
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
		'border-inline-style' {
			PropertyID.border_inline_style
		}
		'border-inline-width' {
			PropertyID.border_inline_width
		}
		'border-left' {
			PropertyID.border_left
		}
		'border-left-color' {
			PropertyID.border_left_color
		}
		'border-left-style' {
			PropertyID.border_left_style
		}
		'border-left-width' {
			PropertyID.border_left_width
		}
		'border-radius' {
			PropertyID.border_radius
		}
		'border-right' {
			PropertyID.border_right
		}
		'border-right-color' {
			PropertyID.border_right_color
		}
		'border-right-style' {
			PropertyID.border_right_style
		}
		'border-right-width' {
			PropertyID.border_right_width
		}
		'border-spacing' {
			PropertyID.border_spacing
		}
		'border-start-end-radius' {
			PropertyID.border_start_end_radius
		}
		'border-start-start-radius' {
			PropertyID.border_start_start_radius
		}
		'border-style' {
			PropertyID.border_style
		}
		'border-top' {
			PropertyID.border_top
		}
		'border-top-color' {
			PropertyID.border_top_color
		}
		'border-top-left-radius' {
			PropertyID.border_top_left_radius
		}
		'border-top-right-radius' {
			PropertyID.border_top_right_radius
		}
		'border-top-style' {
			PropertyID.border_top_style
		}
		'border-top-width' {
			PropertyID.border_top_width
		}
		'border-width' {
			PropertyID.border_width
		}
		'bottom' {
			PropertyID.bottom
		}
		'box-shadow' {
			PropertyID.box_shadow
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
		'clip' {
			PropertyID.clip
		}
		'clip-path' {
			PropertyID.clip_path
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
		'column-count' {
			PropertyID.column_count
		}
		'column-gap' {
			PropertyID.column_gap
		}
		'column-height' {
			PropertyID.column_height
		}
		'column-span' {
			PropertyID.column_span
		}
		'column-width' {
			PropertyID.column_width
		}
		'columns' {
			PropertyID.columns
		}
		'contain' {
			PropertyID.contain
		}
		'contain-intrinsic-block-size' {
			PropertyID.contain_intrinsic_block_size
		}
		'contain-intrinsic-height' {
			PropertyID.contain_intrinsic_height
		}
		'contain-intrinsic-inline-size' {
			PropertyID.contain_intrinsic_inline_size
		}
		'contain-intrinsic-size' {
			PropertyID.contain_intrinsic_size
		}
		'contain-intrinsic-width' {
			PropertyID.contain_intrinsic_width
		}
		'container' {
			PropertyID.container
		}
		'container-name' {
			PropertyID.container_name
		}
		'container-type' {
			PropertyID.container_type
		}
		'content' {
			PropertyID.content
		}
		'content-visibility' {
			PropertyID.content_visibility
		}
		'corner-block-end-shape' {
			PropertyID.corner_block_end_shape
		}
		'corner-block-start-shape' {
			PropertyID.corner_block_start_shape
		}
		'corner-bottom-left-shape' {
			PropertyID.corner_bottom_left_shape
		}
		'corner-bottom-right-shape' {
			PropertyID.corner_bottom_right_shape
		}
		'corner-bottom-shape' {
			PropertyID.corner_bottom_shape
		}
		'corner-end-end-shape' {
			PropertyID.corner_end_end_shape
		}
		'corner-end-start-shape' {
			PropertyID.corner_end_start_shape
		}
		'corner-inline-end-shape' {
			PropertyID.corner_inline_end_shape
		}
		'corner-inline-start-shape' {
			PropertyID.corner_inline_start_shape
		}
		'corner-left-shape' {
			PropertyID.corner_left_shape
		}
		'corner-right-shape' {
			PropertyID.corner_right_shape
		}
		'corner-shape' {
			PropertyID.corner_shape
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
		'corner-top-shape' {
			PropertyID.corner_top_shape
		}
		'counter-increment' {
			PropertyID.counter_increment
		}
		'counter-reset' {
			PropertyID.counter_reset
		}
		'counter-set' {
			PropertyID.counter_set
		}
		'cursor' {
			PropertyID.cursor
		}
		'cx' {
			PropertyID.cx
		}
		'cy' {
			PropertyID.cy
		}
		'd' {
			PropertyID.d
		}
		'direction' {
			PropertyID.direction
		}
		'display' {
			PropertyID.display
		}
		'dominant-baseline' {
			PropertyID.dominant_baseline
		}
		'empty-cells' {
			PropertyID.empty_cells
		}
		'fill' {
			PropertyID.fill
		}
		'fill-opacity' {
			PropertyID.fill_opacity
		}
		'fill-rule' {
			PropertyID.fill_rule
		}
		'filter' {
			PropertyID.filter
		}
		'flex' {
			PropertyID.flex
		}
		'flex-basis' {
			PropertyID.flex_basis
		}
		'flex-direction' {
			PropertyID.flex_direction
		}
		'flex-flow' {
			PropertyID.flex_flow
		}
		'flex-grow' {
			PropertyID.flex_grow
		}
		'flex-shrink' {
			PropertyID.flex_shrink
		}
		'flex-wrap' {
			PropertyID.flex_wrap
		}
		'float' {
			PropertyID.float_
		}
		'flood-color' {
			PropertyID.flood_color
		}
		'flood-opacity' {
			PropertyID.flood_opacity
		}
		'font' {
			PropertyID.font
		}
		'font-family' {
			PropertyID.font_family
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
		'font-size' {
			PropertyID.font_size
		}
		'font-style' {
			PropertyID.font_style
		}
		'font-variant' {
			PropertyID.font_variant
		}
		'font-variant-alternates' {
			PropertyID.font_variant_alternates
		}
		'font-variant-caps' {
			PropertyID.font_variant_caps
		}
		'font-variant-east-asian' {
			PropertyID.font_variant_east_asian
		}
		'font-variant-emoji' {
			PropertyID.font_variant_emoji
		}
		'font-variant-ligatures' {
			PropertyID.font_variant_ligatures
		}
		'font-variant-numeric' {
			PropertyID.font_variant_numeric
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
		'gap' {
			PropertyID.gap
		}
		'grid' {
			PropertyID.grid
		}
		'grid-area' {
			PropertyID.grid_area
		}
		'grid-auto-columns' {
			PropertyID.grid_auto_columns
		}
		'grid-auto-flow' {
			PropertyID.grid_auto_flow
		}
		'grid-auto-rows' {
			PropertyID.grid_auto_rows
		}
		'grid-column' {
			PropertyID.grid_column
		}
		'grid-column-end' {
			PropertyID.grid_column_end
		}
		'grid-column-start' {
			PropertyID.grid_column_start
		}
		'grid-row' {
			PropertyID.grid_row
		}
		'grid-row-end' {
			PropertyID.grid_row_end
		}
		'grid-row-start' {
			PropertyID.grid_row_start
		}
		'grid-template' {
			PropertyID.grid_template
		}
		'grid-template-areas' {
			PropertyID.grid_template_areas
		}
		'grid-template-columns' {
			PropertyID.grid_template_columns
		}
		'grid-template-rows' {
			PropertyID.grid_template_rows
		}
		'height' {
			PropertyID.height
		}
		'image-rendering' {
			PropertyID.image_rendering
		}
		'inline-size' {
			PropertyID.inline_size
		}
		'inset' {
			PropertyID.inset
		}
		'inset-block' {
			PropertyID.inset_block
		}
		'inset-block-end' {
			PropertyID.inset_block_end
		}
		'inset-block-start' {
			PropertyID.inset_block_start
		}
		'inset-inline' {
			PropertyID.inset_inline
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
		'justify-content' {
			PropertyID.justify_content
		}
		'justify-items' {
			PropertyID.justify_items
		}
		'justify-self' {
			PropertyID.justify_self
		}
		'left' {
			PropertyID.left
		}
		'letter-spacing' {
			PropertyID.letter_spacing
		}
		'line-height' {
			PropertyID.line_height
		}
		'list-style' {
			PropertyID.list_style
		}
		'list-style-image' {
			PropertyID.list_style_image
		}
		'list-style-position' {
			PropertyID.list_style_position
		}
		'list-style-type' {
			PropertyID.list_style_type
		}
		'margin' {
			PropertyID.margin
		}
		'margin-block' {
			PropertyID.margin_block
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
		'margin-inline' {
			PropertyID.margin_inline
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
		'mask' {
			PropertyID.mask
		}
		'mask-clip' {
			PropertyID.mask_clip
		}
		'mask-composite' {
			PropertyID.mask_composite
		}
		'mask-image' {
			PropertyID.mask_image
		}
		'mask-mode' {
			PropertyID.mask_mode
		}
		'mask-origin' {
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
		'mask-type' {
			PropertyID.mask_type
		}
		'math-depth' {
			PropertyID.math_depth
		}
		'math-shift' {
			PropertyID.math_shift
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
		'outline' {
			PropertyID.outline
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
		'overflow' {
			PropertyID.overflow
		}
		'overflow-block' {
			PropertyID.overflow_block
		}
		'overflow-clip-margin' {
			PropertyID.overflow_clip_margin
		}
		'overflow-clip-margin-block' {
			PropertyID.overflow_clip_margin_block
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
		'overflow-clip-margin-inline' {
			PropertyID.overflow_clip_margin_inline
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
		'overflow-wrap' {
			PropertyID.overflow_wrap
		}
		'overflow-x' {
			PropertyID.overflow_x
		}
		'overflow-y' {
			PropertyID.overflow_y
		}
		'padding' {
			PropertyID.padding
		}
		'padding-block' {
			PropertyID.padding_block
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
		'padding-inline' {
			PropertyID.padding_inline
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
		'paint-order' {
			PropertyID.paint_order
		}
		'perspective' {
			PropertyID.perspective
		}
		'perspective-origin' {
			PropertyID.perspective_origin
		}
		'place-content' {
			PropertyID.place_content
		}
		'place-items' {
			PropertyID.place_items
		}
		'place-self' {
			PropertyID.place_self
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
		'quotes' {
			PropertyID.quotes
		}
		'r' {
			PropertyID.r
		}
		'resize' {
			PropertyID.resize
		}
		'right' {
			PropertyID.right
		}
		'rotate' {
			PropertyID.rotate
		}
		'row-gap' {
			PropertyID.row_gap
		}
		'rx' {
			PropertyID.rx
		}
		'ry' {
			PropertyID.ry
		}
		'scale' {
			PropertyID.scale
		}
		'scroll-behavior' {
			PropertyID.scroll_behavior
		}
		'scroll-timeline' {
			PropertyID.scroll_timeline
		}
		'scroll-timeline-axis' {
			PropertyID.scroll_timeline_axis
		}
		'scroll-timeline-name' {
			PropertyID.scroll_timeline_name
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
		'shape-image-threshold' {
			PropertyID.shape_image_threshold
		}
		'shape-margin' {
			PropertyID.shape_margin
		}
		'shape-outside' {
			PropertyID.shape_outside
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
		'stroke' {
			PropertyID.stroke
		}
		'stroke-dasharray' {
			PropertyID.stroke_dasharray
		}
		'stroke-dashoffset' {
			PropertyID.stroke_dashoffset
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
		'stroke-opacity' {
			PropertyID.stroke_opacity
		}
		'stroke-width' {
			PropertyID.stroke_width
		}
		'tab-size' {
			PropertyID.tab_size
		}
		'table-layout' {
			PropertyID.table_layout
		}
		'text-align' {
			PropertyID.text_align
		}
		'text-anchor' {
			PropertyID.text_anchor
		}
		'text-decoration' {
			PropertyID.text_decoration
		}
		'text-decoration-color' {
			PropertyID.text_decoration_color
		}
		'text-decoration-line' {
			PropertyID.text_decoration_line
		}
		'text-decoration-skip-ink' {
			PropertyID.text_decoration_skip_ink
		}
		'text-decoration-style' {
			PropertyID.text_decoration_style
		}
		'text-decoration-thickness' {
			PropertyID.text_decoration_thickness
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
		'text-shadow' {
			PropertyID.text_shadow
		}
		'text-transform' {
			PropertyID.text_transform
		}
		'text-underline-offset' {
			PropertyID.text_underline_offset
		}
		'text-underline-position' {
			PropertyID.text_underline_position
		}
		'text-wrap' {
			PropertyID.text_wrap
		}
		'text-wrap-mode' {
			PropertyID.text_wrap_mode
		}
		'text-wrap-style' {
			PropertyID.text_wrap_style
		}
		'timeline-scope' {
			PropertyID.timeline_scope
		}
		'top' {
			PropertyID.top
		}
		'touch-action' {
			PropertyID.touch_action
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
		'transition' {
			PropertyID.transition
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
		'unicode-bidi' {
			PropertyID.unicode_bidi
		}
		'user-select' {
			PropertyID.user_select
		}
		'vector-effect' {
			PropertyID.vector_effect
		}
		'vertical-align' {
			PropertyID.vertical_align
		}
		'view-timeline' {
			PropertyID.view_timeline
		}
		'view-timeline-axis' {
			PropertyID.view_timeline_axis
		}
		'view-timeline-inset' {
			PropertyID.view_timeline_inset
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
		'white-space' {
			PropertyID.white_space
		}
		'white-space-collapse' {
			PropertyID.white_space_collapse
		}
		'white-space-trim' {
			PropertyID.white_space_trim
		}
		'widows' {
			PropertyID.widows
		}
		'width' {
			PropertyID.width
		}
		'will-change' {
			PropertyID.will_change
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
		'x' {
			PropertyID.x
		}
		'y' {
			PropertyID.y
		}
		'z-index' {
			PropertyID.z_index
		}
		else { none }
	}
}

pub fn string_from_property_id(property_id PropertyID) string {
	return match property_id {
		.webkit_text_fill_color { '-webkit-text-fill-color' }
		.accent_color { 'accent-color' }
		.align_content { 'align-content' }
		.align_items { 'align-items' }
		.align_self { 'align-self' }
		.all { 'all' }
		.anchor_name { 'anchor-name' }
		.anchor_scope { 'anchor-scope' }
		.animation { 'animation' }
		.animation_composition { 'animation-composition' }
		.animation_delay { 'animation-delay' }
		.animation_direction { 'animation-direction' }
		.animation_duration { 'animation-duration' }
		.animation_fill_mode { 'animation-fill-mode' }
		.animation_iteration_count { 'animation-iteration-count' }
		.animation_name { 'animation-name' }
		.animation_play_state { 'animation-play-state' }
		.animation_timeline { 'animation-timeline' }
		.animation_timing_function { 'animation-timing-function' }
		.appearance { 'appearance' }
		.aspect_ratio { 'aspect-ratio' }
		.backdrop_filter { 'backdrop-filter' }
		.background { 'background' }
		.background_attachment { 'background-attachment' }
		.background_blend_mode { 'background-blend-mode' }
		.background_clip { 'background-clip' }
		.background_color { 'background-color' }
		.background_image { 'background-image' }
		.background_origin { 'background-origin' }
		.background_position { 'background-position' }
		.background_position_x { 'background-position-x' }
		.background_position_y { 'background-position-y' }
		.background_repeat { 'background-repeat' }
		.background_size { 'background-size' }
		.block_size { 'block-size' }
		.border { 'border' }
		.border_block { 'border-block' }
		.border_block_color { 'border-block-color' }
		.border_block_end { 'border-block-end' }
		.border_block_end_color { 'border-block-end-color' }
		.border_block_end_style { 'border-block-end-style' }
		.border_block_end_width { 'border-block-end-width' }
		.border_block_start { 'border-block-start' }
		.border_block_start_color { 'border-block-start-color' }
		.border_block_start_style { 'border-block-start-style' }
		.border_block_start_width { 'border-block-start-width' }
		.border_block_style { 'border-block-style' }
		.border_block_width { 'border-block-width' }
		.border_bottom { 'border-bottom' }
		.border_bottom_color { 'border-bottom-color' }
		.border_bottom_left_radius { 'border-bottom-left-radius' }
		.border_bottom_right_radius { 'border-bottom-right-radius' }
		.border_bottom_style { 'border-bottom-style' }
		.border_bottom_width { 'border-bottom-width' }
		.border_collapse { 'border-collapse' }
		.border_color { 'border-color' }
		.border_end_end_radius { 'border-end-end-radius' }
		.border_end_start_radius { 'border-end-start-radius' }
		.border_image { 'border-image' }
		.border_image_outset { 'border-image-outset' }
		.border_image_repeat { 'border-image-repeat' }
		.border_image_slice { 'border-image-slice' }
		.border_image_source { 'border-image-source' }
		.border_image_width { 'border-image-width' }
		.border_inline { 'border-inline' }
		.border_inline_color { 'border-inline-color' }
		.border_inline_end { 'border-inline-end' }
		.border_inline_end_color { 'border-inline-end-color' }
		.border_inline_end_style { 'border-inline-end-style' }
		.border_inline_end_width { 'border-inline-end-width' }
		.border_inline_start { 'border-inline-start' }
		.border_inline_start_color { 'border-inline-start-color' }
		.border_inline_start_style { 'border-inline-start-style' }
		.border_inline_start_width { 'border-inline-start-width' }
		.border_inline_style { 'border-inline-style' }
		.border_inline_width { 'border-inline-width' }
		.border_left { 'border-left' }
		.border_left_color { 'border-left-color' }
		.border_left_style { 'border-left-style' }
		.border_left_width { 'border-left-width' }
		.border_radius { 'border-radius' }
		.border_right { 'border-right' }
		.border_right_color { 'border-right-color' }
		.border_right_style { 'border-right-style' }
		.border_right_width { 'border-right-width' }
		.border_spacing { 'border-spacing' }
		.border_start_end_radius { 'border-start-end-radius' }
		.border_start_start_radius { 'border-start-start-radius' }
		.border_style { 'border-style' }
		.border_top { 'border-top' }
		.border_top_color { 'border-top-color' }
		.border_top_left_radius { 'border-top-left-radius' }
		.border_top_right_radius { 'border-top-right-radius' }
		.border_top_style { 'border-top-style' }
		.border_top_width { 'border-top-width' }
		.border_width { 'border-width' }
		.bottom { 'bottom' }
		.box_shadow { 'box-shadow' }
		.box_sizing { 'box-sizing' }
		.caption_side { 'caption-side' }
		.caret_color { 'caret-color' }
		.clear { 'clear' }
		.clip { 'clip' }
		.clip_path { 'clip-path' }
		.clip_rule { 'clip-rule' }
		.color { 'color' }
		.color_interpolation { 'color-interpolation' }
		.color_scheme { 'color-scheme' }
		.column_count { 'column-count' }
		.column_gap { 'column-gap' }
		.column_height { 'column-height' }
		.column_span { 'column-span' }
		.column_width { 'column-width' }
		.columns { 'columns' }
		.contain { 'contain' }
		.contain_intrinsic_block_size { 'contain-intrinsic-block-size' }
		.contain_intrinsic_height { 'contain-intrinsic-height' }
		.contain_intrinsic_inline_size { 'contain-intrinsic-inline-size' }
		.contain_intrinsic_size { 'contain-intrinsic-size' }
		.contain_intrinsic_width { 'contain-intrinsic-width' }
		.container { 'container' }
		.container_name { 'container-name' }
		.container_type { 'container-type' }
		.content { 'content' }
		.content_visibility { 'content-visibility' }
		.corner_block_end_shape { 'corner-block-end-shape' }
		.corner_block_start_shape { 'corner-block-start-shape' }
		.corner_bottom_left_shape { 'corner-bottom-left-shape' }
		.corner_bottom_right_shape { 'corner-bottom-right-shape' }
		.corner_bottom_shape { 'corner-bottom-shape' }
		.corner_end_end_shape { 'corner-end-end-shape' }
		.corner_end_start_shape { 'corner-end-start-shape' }
		.corner_inline_end_shape { 'corner-inline-end-shape' }
		.corner_inline_start_shape { 'corner-inline-start-shape' }
		.corner_left_shape { 'corner-left-shape' }
		.corner_right_shape { 'corner-right-shape' }
		.corner_shape { 'corner-shape' }
		.corner_start_end_shape { 'corner-start-end-shape' }
		.corner_start_start_shape { 'corner-start-start-shape' }
		.corner_top_left_shape { 'corner-top-left-shape' }
		.corner_top_right_shape { 'corner-top-right-shape' }
		.corner_top_shape { 'corner-top-shape' }
		.counter_increment { 'counter-increment' }
		.counter_reset { 'counter-reset' }
		.counter_set { 'counter-set' }
		.cursor { 'cursor' }
		.cx { 'cx' }
		.cy { 'cy' }
		.d { 'd' }
		.direction { 'direction' }
		.display { 'display' }
		.dominant_baseline { 'dominant-baseline' }
		.empty_cells { 'empty-cells' }
		.fill { 'fill' }
		.fill_opacity { 'fill-opacity' }
		.fill_rule { 'fill-rule' }
		.filter { 'filter' }
		.flex { 'flex' }
		.flex_basis { 'flex-basis' }
		.flex_direction { 'flex-direction' }
		.flex_flow { 'flex-flow' }
		.flex_grow { 'flex-grow' }
		.flex_shrink { 'flex-shrink' }
		.flex_wrap { 'flex-wrap' }
		.float_ { 'float' }
		.flood_color { 'flood-color' }
		.flood_opacity { 'flood-opacity' }
		.font { 'font' }
		.font_family { 'font-family' }
		.font_feature_settings { 'font-feature-settings' }
		.font_kerning { 'font-kerning' }
		.font_language_override { 'font-language-override' }
		.font_optical_sizing { 'font-optical-sizing' }
		.font_size { 'font-size' }
		.font_style { 'font-style' }
		.font_variant { 'font-variant' }
		.font_variant_alternates { 'font-variant-alternates' }
		.font_variant_caps { 'font-variant-caps' }
		.font_variant_east_asian { 'font-variant-east-asian' }
		.font_variant_emoji { 'font-variant-emoji' }
		.font_variant_ligatures { 'font-variant-ligatures' }
		.font_variant_numeric { 'font-variant-numeric' }
		.font_variant_position { 'font-variant-position' }
		.font_variation_settings { 'font-variation-settings' }
		.font_weight { 'font-weight' }
		.font_width { 'font-width' }
		.gap { 'gap' }
		.grid { 'grid' }
		.grid_area { 'grid-area' }
		.grid_auto_columns { 'grid-auto-columns' }
		.grid_auto_flow { 'grid-auto-flow' }
		.grid_auto_rows { 'grid-auto-rows' }
		.grid_column { 'grid-column' }
		.grid_column_end { 'grid-column-end' }
		.grid_column_start { 'grid-column-start' }
		.grid_row { 'grid-row' }
		.grid_row_end { 'grid-row-end' }
		.grid_row_start { 'grid-row-start' }
		.grid_template { 'grid-template' }
		.grid_template_areas { 'grid-template-areas' }
		.grid_template_columns { 'grid-template-columns' }
		.grid_template_rows { 'grid-template-rows' }
		.height { 'height' }
		.image_rendering { 'image-rendering' }
		.inline_size { 'inline-size' }
		.inset { 'inset' }
		.inset_block { 'inset-block' }
		.inset_block_end { 'inset-block-end' }
		.inset_block_start { 'inset-block-start' }
		.inset_inline { 'inset-inline' }
		.inset_inline_end { 'inset-inline-end' }
		.inset_inline_start { 'inset-inline-start' }
		.isolation { 'isolation' }
		.justify_content { 'justify-content' }
		.justify_items { 'justify-items' }
		.justify_self { 'justify-self' }
		.left { 'left' }
		.letter_spacing { 'letter-spacing' }
		.line_height { 'line-height' }
		.list_style { 'list-style' }
		.list_style_image { 'list-style-image' }
		.list_style_position { 'list-style-position' }
		.list_style_type { 'list-style-type' }
		.margin { 'margin' }
		.margin_block { 'margin-block' }
		.margin_block_end { 'margin-block-end' }
		.margin_block_start { 'margin-block-start' }
		.margin_bottom { 'margin-bottom' }
		.margin_inline { 'margin-inline' }
		.margin_inline_end { 'margin-inline-end' }
		.margin_inline_start { 'margin-inline-start' }
		.margin_left { 'margin-left' }
		.margin_right { 'margin-right' }
		.margin_top { 'margin-top' }
		.mask { 'mask' }
		.mask_clip { 'mask-clip' }
		.mask_composite { 'mask-composite' }
		.mask_image { 'mask-image' }
		.mask_mode { 'mask-mode' }
		.mask_origin { 'mask-origin' }
		.mask_position { 'mask-position' }
		.mask_repeat { 'mask-repeat' }
		.mask_size { 'mask-size' }
		.mask_type { 'mask-type' }
		.math_depth { 'math-depth' }
		.math_shift { 'math-shift' }
		.math_style { 'math-style' }
		.max_block_size { 'max-block-size' }
		.max_height { 'max-height' }
		.max_inline_size { 'max-inline-size' }
		.max_width { 'max-width' }
		.min_block_size { 'min-block-size' }
		.min_height { 'min-height' }
		.min_inline_size { 'min-inline-size' }
		.min_width { 'min-width' }
		.mix_blend_mode { 'mix-blend-mode' }
		.object_fit { 'object-fit' }
		.object_position { 'object-position' }
		.opacity { 'opacity' }
		.order { 'order' }
		.orphans { 'orphans' }
		.outline { 'outline' }
		.outline_color { 'outline-color' }
		.outline_offset { 'outline-offset' }
		.outline_style { 'outline-style' }
		.outline_width { 'outline-width' }
		.overflow { 'overflow' }
		.overflow_block { 'overflow-block' }
		.overflow_clip_margin { 'overflow-clip-margin' }
		.overflow_clip_margin_block { 'overflow-clip-margin-block' }
		.overflow_clip_margin_block_end { 'overflow-clip-margin-block-end' }
		.overflow_clip_margin_block_start { 'overflow-clip-margin-block-start' }
		.overflow_clip_margin_bottom { 'overflow-clip-margin-bottom' }
		.overflow_clip_margin_inline { 'overflow-clip-margin-inline' }
		.overflow_clip_margin_inline_end { 'overflow-clip-margin-inline-end' }
		.overflow_clip_margin_inline_start { 'overflow-clip-margin-inline-start' }
		.overflow_clip_margin_left { 'overflow-clip-margin-left' }
		.overflow_clip_margin_right { 'overflow-clip-margin-right' }
		.overflow_clip_margin_top { 'overflow-clip-margin-top' }
		.overflow_inline { 'overflow-inline' }
		.overflow_wrap { 'overflow-wrap' }
		.overflow_x { 'overflow-x' }
		.overflow_y { 'overflow-y' }
		.padding { 'padding' }
		.padding_block { 'padding-block' }
		.padding_block_end { 'padding-block-end' }
		.padding_block_start { 'padding-block-start' }
		.padding_bottom { 'padding-bottom' }
		.padding_inline { 'padding-inline' }
		.padding_inline_end { 'padding-inline-end' }
		.padding_inline_start { 'padding-inline-start' }
		.padding_left { 'padding-left' }
		.padding_right { 'padding-right' }
		.padding_top { 'padding-top' }
		.paint_order { 'paint-order' }
		.perspective { 'perspective' }
		.perspective_origin { 'perspective-origin' }
		.place_content { 'place-content' }
		.place_items { 'place-items' }
		.place_self { 'place-self' }
		.pointer_events { 'pointer-events' }
		.position { 'position' }
		.position_anchor { 'position-anchor' }
		.position_area { 'position-area' }
		.position_try_fallbacks { 'position-try-fallbacks' }
		.position_try_order { 'position-try-order' }
		.position_visibility { 'position-visibility' }
		.quotes { 'quotes' }
		.r { 'r' }
		.resize { 'resize' }
		.right { 'right' }
		.rotate { 'rotate' }
		.row_gap { 'row-gap' }
		.rx { 'rx' }
		.ry { 'ry' }
		.scale { 'scale' }
		.scroll_behavior { 'scroll-behavior' }
		.scroll_timeline { 'scroll-timeline' }
		.scroll_timeline_axis { 'scroll-timeline-axis' }
		.scroll_timeline_name { 'scroll-timeline-name' }
		.scrollbar_color { 'scrollbar-color' }
		.scrollbar_gutter { 'scrollbar-gutter' }
		.scrollbar_width { 'scrollbar-width' }
		.shape_image_threshold { 'shape-image-threshold' }
		.shape_margin { 'shape-margin' }
		.shape_outside { 'shape-outside' }
		.shape_rendering { 'shape-rendering' }
		.stop_color { 'stop-color' }
		.stop_opacity { 'stop-opacity' }
		.stroke { 'stroke' }
		.stroke_dasharray { 'stroke-dasharray' }
		.stroke_dashoffset { 'stroke-dashoffset' }
		.stroke_linecap { 'stroke-linecap' }
		.stroke_linejoin { 'stroke-linejoin' }
		.stroke_miterlimit { 'stroke-miterlimit' }
		.stroke_opacity { 'stroke-opacity' }
		.stroke_width { 'stroke-width' }
		.tab_size { 'tab-size' }
		.table_layout { 'table-layout' }
		.text_align { 'text-align' }
		.text_anchor { 'text-anchor' }
		.text_decoration { 'text-decoration' }
		.text_decoration_color { 'text-decoration-color' }
		.text_decoration_line { 'text-decoration-line' }
		.text_decoration_skip_ink { 'text-decoration-skip-ink' }
		.text_decoration_style { 'text-decoration-style' }
		.text_decoration_thickness { 'text-decoration-thickness' }
		.text_indent { 'text-indent' }
		.text_justify { 'text-justify' }
		.text_overflow { 'text-overflow' }
		.text_rendering { 'text-rendering' }
		.text_shadow { 'text-shadow' }
		.text_transform { 'text-transform' }
		.text_underline_offset { 'text-underline-offset' }
		.text_underline_position { 'text-underline-position' }
		.text_wrap { 'text-wrap' }
		.text_wrap_mode { 'text-wrap-mode' }
		.text_wrap_style { 'text-wrap-style' }
		.timeline_scope { 'timeline-scope' }
		.top { 'top' }
		.touch_action { 'touch-action' }
		.transform { 'transform' }
		.transform_box { 'transform-box' }
		.transform_origin { 'transform-origin' }
		.transform_style { 'transform-style' }
		.transition { 'transition' }
		.transition_behavior { 'transition-behavior' }
		.transition_delay { 'transition-delay' }
		.transition_duration { 'transition-duration' }
		.transition_property { 'transition-property' }
		.transition_timing_function { 'transition-timing-function' }
		.translate { 'translate' }
		.unicode_bidi { 'unicode-bidi' }
		.user_select { 'user-select' }
		.vector_effect { 'vector-effect' }
		.vertical_align { 'vertical-align' }
		.view_timeline { 'view-timeline' }
		.view_timeline_axis { 'view-timeline-axis' }
		.view_timeline_inset { 'view-timeline-inset' }
		.view_timeline_name { 'view-timeline-name' }
		.view_transition_name { 'view-transition-name' }
		.visibility { 'visibility' }
		.white_space { 'white-space' }
		.white_space_collapse { 'white-space-collapse' }
		.white_space_trim { 'white-space-trim' }
		.widows { 'widows' }
		.width { 'width' }
		.will_change { 'will-change' }
		.word_break { 'word-break' }
		.word_spacing { 'word-spacing' }
		.writing_mode { 'writing-mode' }
		.x { 'x' }
		.y { 'y' }
		.z_index { 'z-index' }
	}
}

pub enum PropertyQuirk {
	hashless_hex_color
	unitless_length
}

pub fn property_has_quirk(property_id PropertyID, quirk PropertyQuirk) bool {
	return match quirk {
		.hashless_hex_color {
			match property_id {
				.background_color, .border_bottom_color, .border_color, .border_left_color, .border_right_color, .border_top_color, .color { true }
				else { false }
			}
		}
		.unitless_length {
			match property_id {
				.background_position, .border_bottom_width, .border_left_width, .border_right_width, .border_spacing, .border_top_width, .border_width, .bottom, .clip, .cx, .cy, .font_size, .height, .left, .letter_spacing, .margin, .margin_bottom, .margin_left, .margin_right, .margin_top, .max_height, .max_width, .min_height, .min_width, .padding, .padding_bottom, .padding_left, .padding_right, .padding_top, .r, .right, .rx, .ry, .text_indent, .top, .vertical_align, .width, .word_spacing, .x, .y { true }
				else { false }
			}
		}
	}
}

pub fn is_inherited_property(property_id PropertyID) bool {
	return match property_id {
		.webkit_text_fill_color, .accent_color, .border_collapse, .border_spacing, .caption_side, .caret_color, .clip_rule, .color, .color_interpolation, .color_scheme, .cursor, .direction, .dominant_baseline, .empty_cells, .fill, .fill_opacity, .fill_rule, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_size, .font_style, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight, .font_width, .image_rendering, .letter_spacing, .line_height, .list_style_image, .list_style_position, .list_style_type, .math_depth, .math_shift, .math_style, .orphans, .overflow_wrap, .paint_order, .pointer_events, .quotes, .scrollbar_color, .shape_rendering, .stroke, .stroke_dasharray, .stroke_dashoffset, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .text_align, .text_anchor, .text_decoration_line, .text_decoration_skip_ink, .text_indent, .text_justify, .text_rendering, .text_shadow, .text_transform, .text_underline_offset, .text_underline_position, .text_wrap_mode, .text_wrap_style, .visibility, .white_space_collapse, .widows, .word_break, .word_spacing, .writing_mode { true }
		else { false }
	}
}

pub fn property_initial_value_string(property_id PropertyID) string {
	return match property_id {
		.webkit_text_fill_color { 'currentColor' }
		.accent_color { 'auto' }
		.align_content { 'normal' }
		.align_items { 'normal' }
		.align_self { 'auto' }
		.all { 'initial' }
		.anchor_name { 'none' }
		.anchor_scope { 'none' }
		.animation { 'none 0s ease 1 normal running 0s none' }
		.animation_composition { 'replace' }
		.animation_delay { '0s' }
		.animation_direction { 'normal' }
		.animation_duration { '0s' }
		.animation_fill_mode { 'none' }
		.animation_iteration_count { '1' }
		.animation_name { 'none' }
		.animation_play_state { 'running' }
		.animation_timeline { 'auto' }
		.animation_timing_function { 'ease' }
		.appearance { 'none' }
		.aspect_ratio { 'auto' }
		.backdrop_filter { 'none' }
		.background { 'transparent' }
		.background_attachment { 'scroll' }
		.background_blend_mode { 'normal' }
		.background_clip { 'border-box' }
		.background_color { 'transparent' }
		.background_image { 'none' }
		.background_origin { 'padding-box' }
		.background_position { '0% 0%' }
		.background_position_x { '0%' }
		.background_position_y { '0%' }
		.background_repeat { 'repeat' }
		.background_size { 'auto' }
		.block_size { 'auto' }
		.border { 'medium currentcolor none' }
		.border_block { 'medium currentcolor none' }
		.border_block_color { 'currentcolor' }
		.border_block_end { 'medium currentcolor none' }
		.border_block_end_color { 'currentcolor' }
		.border_block_end_style { 'none' }
		.border_block_end_width { 'medium' }
		.border_block_start { 'medium currentcolor none' }
		.border_block_start_color { 'currentcolor' }
		.border_block_start_style { 'none' }
		.border_block_start_width { 'medium' }
		.border_block_style { 'none' }
		.border_block_width { 'medium' }
		.border_bottom { 'medium currentcolor none' }
		.border_bottom_color { 'currentcolor' }
		.border_bottom_left_radius { '0' }
		.border_bottom_right_radius { '0' }
		.border_bottom_style { 'none' }
		.border_bottom_width { 'medium' }
		.border_collapse { 'separate' }
		.border_color { 'currentcolor' }
		.border_end_end_radius { '0' }
		.border_end_start_radius { '0' }
		.border_image { 'none 100% / 1 / 0 stretch' }
		.border_image_outset { '0' }
		.border_image_repeat { 'stretch' }
		.border_image_slice { '100%' }
		.border_image_source { 'none' }
		.border_image_width { '1' }
		.border_inline { 'medium currentcolor none' }
		.border_inline_color { 'currentcolor' }
		.border_inline_end { 'medium currentcolor none' }
		.border_inline_end_color { 'currentcolor' }
		.border_inline_end_style { 'none' }
		.border_inline_end_width { 'medium' }
		.border_inline_start { 'medium currentcolor none' }
		.border_inline_start_color { 'currentcolor' }
		.border_inline_start_style { 'none' }
		.border_inline_start_width { 'medium' }
		.border_inline_style { 'none' }
		.border_inline_width { 'medium' }
		.border_left { 'medium currentcolor none' }
		.border_left_color { 'currentcolor' }
		.border_left_style { 'none' }
		.border_left_width { 'medium' }
		.border_radius { '0' }
		.border_right { 'medium currentcolor none' }
		.border_right_color { 'currentcolor' }
		.border_right_style { 'none' }
		.border_right_width { 'medium' }
		.border_spacing { '0' }
		.border_start_end_radius { '0' }
		.border_start_start_radius { '0' }
		.border_style { 'none' }
		.border_top { 'medium currentcolor none' }
		.border_top_color { 'currentcolor' }
		.border_top_left_radius { '0' }
		.border_top_right_radius { '0' }
		.border_top_style { 'none' }
		.border_top_width { 'medium' }
		.border_width { 'medium' }
		.bottom { 'auto' }
		.box_shadow { 'none' }
		.box_sizing { 'content-box' }
		.caption_side { 'top' }
		.caret_color { 'auto' }
		.clear { 'none' }
		.clip { 'auto' }
		.clip_path { 'none' }
		.clip_rule { 'nonzero' }
		.color { 'canvastext' }
		.color_interpolation { 'srgb' }
		.color_scheme { 'normal' }
		.column_count { 'auto' }
		.column_gap { 'normal' }
		.column_height { 'auto' }
		.column_span { 'none' }
		.column_width { 'auto' }
		.columns { 'auto auto / auto' }
		.contain { 'none' }
		.contain_intrinsic_block_size { 'none' }
		.contain_intrinsic_height { 'none' }
		.contain_intrinsic_inline_size { 'none' }
		.contain_intrinsic_size { 'none' }
		.contain_intrinsic_width { 'none' }
		.container { 'none' }
		.container_name { 'none' }
		.container_type { 'normal' }
		.content { 'normal' }
		.content_visibility { 'visible' }
		.corner_block_end_shape { 'round round' }
		.corner_block_start_shape { 'round round' }
		.corner_bottom_left_shape { 'round' }
		.corner_bottom_right_shape { 'round' }
		.corner_bottom_shape { 'round round' }
		.corner_end_end_shape { 'round' }
		.corner_end_start_shape { 'round' }
		.corner_inline_end_shape { 'round round' }
		.corner_inline_start_shape { 'round round' }
		.corner_left_shape { 'round round' }
		.corner_right_shape { 'round round' }
		.corner_shape { 'round round round round' }
		.corner_start_end_shape { 'round' }
		.corner_start_start_shape { 'round' }
		.corner_top_left_shape { 'round' }
		.corner_top_right_shape { 'round' }
		.corner_top_shape { 'round round' }
		.counter_increment { 'none' }
		.counter_reset { 'none' }
		.counter_set { 'none' }
		.cursor { 'auto' }
		.cx { '0' }
		.cy { '0' }
		.d { 'none' }
		.direction { 'ltr' }
		.display { 'inline' }
		.dominant_baseline { 'auto' }
		.empty_cells { 'show' }
		.fill { 'black' }
		.fill_opacity { '1' }
		.fill_rule { 'nonzero' }
		.filter { 'none' }
		.flex { '0 1 auto' }
		.flex_basis { 'auto' }
		.flex_direction { 'row' }
		.flex_flow { 'row nowrap' }
		.flex_grow { '0' }
		.flex_shrink { '1' }
		.flex_wrap { 'nowrap' }
		.float_ { 'none' }
		.flood_color { 'black' }
		.flood_opacity { '1' }
		.font { 'normal medium serif' }
		.font_family { 'serif' }
		.font_feature_settings { 'normal' }
		.font_kerning { 'auto' }
		.font_language_override { 'normal' }
		.font_optical_sizing { 'auto' }
		.font_size { 'medium' }
		.font_style { 'normal' }
		.font_variant { 'normal' }
		.font_variant_alternates { 'normal' }
		.font_variant_caps { 'normal' }
		.font_variant_east_asian { 'normal' }
		.font_variant_emoji { 'normal' }
		.font_variant_ligatures { 'normal' }
		.font_variant_numeric { 'normal' }
		.font_variant_position { 'normal' }
		.font_variation_settings { 'normal' }
		.font_weight { 'normal' }
		.font_width { 'normal' }
		.gap { 'normal' }
		.grid { 'auto' }
		.grid_area { 'auto' }
		.grid_auto_columns { 'auto' }
		.grid_auto_flow { 'row' }
		.grid_auto_rows { 'auto' }
		.grid_column { 'auto' }
		.grid_column_end { 'auto' }
		.grid_column_start { 'auto' }
		.grid_row { 'auto' }
		.grid_row_end { 'auto' }
		.grid_row_start { 'auto' }
		.grid_template { 'auto' }
		.grid_template_areas { 'none' }
		.grid_template_columns { 'none' }
		.grid_template_rows { 'none' }
		.height { 'auto' }
		.image_rendering { 'auto' }
		.inline_size { 'auto' }
		.inset { 'auto' }
		.inset_block { 'auto' }
		.inset_block_end { 'auto' }
		.inset_block_start { 'auto' }
		.inset_inline { 'auto' }
		.inset_inline_end { 'auto' }
		.inset_inline_start { 'auto' }
		.isolation { 'auto' }
		.justify_content { 'normal' }
		.justify_items { 'legacy' }
		.justify_self { 'auto' }
		.left { 'auto' }
		.letter_spacing { 'normal' }
		.line_height { 'normal' }
		.list_style { 'outside none disc' }
		.list_style_image { 'none' }
		.list_style_position { 'outside' }
		.list_style_type { 'disc' }
		.margin { '0' }
		.margin_block { '0' }
		.margin_block_end { '0' }
		.margin_block_start { '0' }
		.margin_bottom { '0' }
		.margin_inline { '0' }
		.margin_inline_end { '0' }
		.margin_inline_start { '0' }
		.margin_left { '0' }
		.margin_right { '0' }
		.margin_top { '0' }
		.mask { 'none' }
		.mask_clip { 'border-box' }
		.mask_composite { 'add' }
		.mask_image { 'none' }
		.mask_mode { 'match-source' }
		.mask_origin { 'border-box' }
		.mask_position { '0% 0%' }
		.mask_repeat { 'repeat' }
		.mask_size { 'auto' }
		.mask_type { 'luminance' }
		.math_depth { '0' }
		.math_shift { 'normal' }
		.math_style { 'normal' }
		.max_block_size { 'none' }
		.max_height { 'none' }
		.max_inline_size { 'none' }
		.max_width { 'none' }
		.min_block_size { '0' }
		.min_height { 'auto' }
		.min_inline_size { '0' }
		.min_width { 'auto' }
		.mix_blend_mode { 'normal' }
		.object_fit { 'fill' }
		.object_position { '50% 50%' }
		.opacity { '1' }
		.order { '0' }
		.orphans { '2' }
		.outline { 'medium currentColor none' }
		.outline_color { 'currentColor' }
		.outline_offset { '0' }
		.outline_style { 'none' }
		.outline_width { 'medium' }
		.overflow { 'visible' }
		.overflow_block { 'visible' }
		.overflow_clip_margin { '0px' }
		.overflow_clip_margin_block { '0px' }
		.overflow_clip_margin_block_end { '0px' }
		.overflow_clip_margin_block_start { '0px' }
		.overflow_clip_margin_bottom { '0px' }
		.overflow_clip_margin_inline { '0px' }
		.overflow_clip_margin_inline_end { '0px' }
		.overflow_clip_margin_inline_start { '0px' }
		.overflow_clip_margin_left { '0px' }
		.overflow_clip_margin_right { '0px' }
		.overflow_clip_margin_top { '0px' }
		.overflow_inline { 'visible' }
		.overflow_wrap { 'normal' }
		.overflow_x { 'visible' }
		.overflow_y { 'visible' }
		.padding { '0' }
		.padding_block { '0' }
		.padding_block_end { '0' }
		.padding_block_start { '0' }
		.padding_bottom { '0' }
		.padding_inline { '0' }
		.padding_inline_end { '0' }
		.padding_inline_start { '0' }
		.padding_left { '0' }
		.padding_right { '0' }
		.padding_top { '0' }
		.paint_order { 'normal' }
		.perspective { 'none' }
		.perspective_origin { '50% 50%' }
		.place_content { 'normal' }
		.place_items { 'normal' }
		.place_self { 'normal' }
		.pointer_events { 'auto' }
		.position { 'static' }
		.position_anchor { 'normal' }
		.position_area { 'none' }
		.position_try_fallbacks { 'none' }
		.position_try_order { 'normal' }
		.position_visibility { 'anchors-visible' }
		.quotes { 'auto' }
		.r { '0' }
		.resize { 'none' }
		.right { 'auto' }
		.rotate { 'none' }
		.row_gap { 'normal' }
		.rx { 'auto' }
		.ry { 'auto' }
		.scale { 'none' }
		.scroll_behavior { 'auto' }
		.scroll_timeline { 'none block' }
		.scroll_timeline_axis { 'block' }
		.scroll_timeline_name { 'none' }
		.scrollbar_color { 'auto' }
		.scrollbar_gutter { 'auto' }
		.scrollbar_width { 'auto' }
		.shape_image_threshold { '0' }
		.shape_margin { '0' }
		.shape_outside { 'none' }
		.shape_rendering { 'auto' }
		.stop_color { 'black' }
		.stop_opacity { '1' }
		.stroke { 'none' }
		.stroke_dasharray { 'none' }
		.stroke_dashoffset { '0px' }
		.stroke_linecap { 'butt' }
		.stroke_linejoin { 'miter' }
		.stroke_miterlimit { '4' }
		.stroke_opacity { '1' }
		.stroke_width { '1px' }
		.tab_size { '8' }
		.table_layout { 'auto' }
		.text_align { 'start' }
		.text_anchor { 'start' }
		.text_decoration { 'none' }
		.text_decoration_color { 'currentcolor' }
		.text_decoration_line { 'none' }
		.text_decoration_skip_ink { 'auto' }
		.text_decoration_style { 'solid' }
		.text_decoration_thickness { 'auto' }
		.text_indent { '0' }
		.text_justify { 'auto' }
		.text_overflow { 'clip' }
		.text_rendering { 'auto' }
		.text_shadow { 'none' }
		.text_transform { 'none' }
		.text_underline_offset { 'auto' }
		.text_underline_position { 'auto' }
		.text_wrap { 'wrap' }
		.text_wrap_mode { 'wrap' }
		.text_wrap_style { 'auto' }
		.timeline_scope { 'none' }
		.top { 'auto' }
		.touch_action { 'auto' }
		.transform { 'none' }
		.transform_box { 'view-box' }
		.transform_origin { '50% 50%' }
		.transform_style { 'flat' }
		.transition { 'none' }
		.transition_behavior { 'normal' }
		.transition_delay { '0s' }
		.transition_duration { '0s' }
		.transition_property { 'all' }
		.transition_timing_function { 'ease' }
		.translate { 'none' }
		.unicode_bidi { 'normal' }
		.user_select { 'auto' }
		.vector_effect { 'none' }
		.vertical_align { 'baseline' }
		.view_timeline { 'none' }
		.view_timeline_axis { 'block' }
		.view_timeline_inset { 'auto' }
		.view_timeline_name { 'none' }
		.view_transition_name { 'none' }
		.visibility { 'visible' }
		.white_space { 'normal' }
		.white_space_collapse { 'collapse' }
		.white_space_trim { 'none' }
		.widows { '2' }
		.width { 'auto' }
		.will_change { 'auto' }
		.word_break { 'normal' }
		.word_spacing { 'normal' }
		.writing_mode { 'horizontal-tb' }
		.x { '0' }
		.y { '0' }
		.z_index { 'auto' }
	}
}

fn animation_type_from_longhand_property(property_id PropertyID) AnimationType {
	return match property_id {
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_width {
			AnimationType.by_computed_value
		}
		.webkit_text_fill_color, .accent_color, .aspect_ratio, .background_color, .block_size, .border_block_end_color, .border_block_end_width, .border_block_start_color, .border_block_start_width, .border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_width, .border_end_end_radius, .border_end_start_radius, .border_image_outset, .border_image_slice, .border_image_width, .border_inline_end_color, .border_inline_end_width, .border_inline_start_color, .border_inline_start_width, .border_left_color, .border_left_width, .border_right_color, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_top_color, .border_top_left_radius, .border_top_right_radius, .border_top_width, .bottom, .caret_color, .clip, .clip_path, .color, .column_count, .column_gap, .column_height, .column_width, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .counter_increment, .counter_reset, .counter_set, .cx, .cy, .fill, .fill_opacity, .flex_basis, .flex_grow, .flex_shrink, .flood_color, .flood_opacity, .font_size, .font_weight, .font_width, .grid_auto_columns, .grid_auto_rows, .height, .inline_size, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .line_height, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .opacity, .order, .orphans, .outline_color, .outline_offset, .outline_style, .outline_width, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective, .perspective_origin, .r, .right, .row_gap, .rx, .ry, .scrollbar_color, .scrollbar_width, .shape_image_threshold, .shape_margin, .shape_outside, .stop_color, .stop_opacity, .stroke, .stroke_dashoffset, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .text_decoration_color, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform_origin, .vertical_align, .widows, .width, .word_spacing, .x, .y, .z_index {
			AnimationType.by_computed_value
		}
		.align_content, .align_items, .align_self, .anchor_name, .anchor_scope, .appearance, .background_attachment, .background_blend_mode, .background_image, .background_repeat, .border_block_end_style, .border_block_start_style, .border_bottom_style, .border_collapse, .border_image_repeat, .border_image_source, .border_inline_end_style, .border_inline_start_style, .border_left_style, .border_right_style, .border_top_style, .box_sizing, .caption_side, .clear, .clip_rule, .color_interpolation, .color_scheme, .column_span, .content, .cursor, .dominant_baseline, .empty_cells, .fill_rule, .flex_direction, .flex_wrap, .float_, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .grid_auto_flow, .grid_column_end, .grid_column_start, .grid_row_end, .grid_row_start, .grid_template_areas, .image_rendering, .isolation, .justify_content, .justify_items, .justify_self, .list_style_image, .list_style_position, .list_style_type, .mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_repeat, .mask_type, .mix_blend_mode, .object_fit, .overflow_block, .overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .paint_order, .pointer_events, .position, .position_anchor, .position_area, .position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .scrollbar_gutter, .shape_rendering, .stroke_linecap, .stroke_linejoin, .table_layout, .text_align, .text_anchor, .text_decoration_line, .text_decoration_style, .text_justify, .text_overflow, .text_rendering, .text_transform, .text_underline_position, .text_wrap_mode, .text_wrap_style, .touch_action, .transform_box, .transform_style, .user_select, .vector_effect, .view_transition_name, .white_space_collapse, .white_space_trim, .word_break {
			AnimationType.discrete
		}
		.animation_composition, .animation_delay, .animation_direction, .animation_duration, .animation_fill_mode, .animation_iteration_count, .animation_name, .animation_play_state, .animation_timeline, .animation_timing_function, .contain, .container_name, .container_type, .direction, .math_depth, .math_shift, .math_style, .resize, .scroll_behavior, .scroll_timeline_axis, .scroll_timeline_name, .timeline_scope, .transition_behavior, .transition_delay, .transition_duration, .transition_property, .transition_timing_function, .unicode_bidi, .view_timeline_axis, .view_timeline_inset, .view_timeline_name, .will_change, .writing_mode {
			AnimationType.none_
		}
		.backdrop_filter, .box_shadow, .content_visibility, .display, .filter, .font_style, .font_variation_settings, .grid_template_columns, .grid_template_rows, .rotate, .scale, .stroke_dasharray, .text_shadow, .transform, .translate, .visibility {
			AnimationType.custom
		}
		.background_clip, .background_origin, .background_position_x, .background_position_y, .background_size, .mask_position, .mask_size, .object_position {
			AnimationType.repeatable_list
		}
		.text_decoration_skip_ink { AnimationType.discrete }
		.d { AnimationType.by_computed_value }
		else { .none_ }
	}
}

pub fn is_animatable_property(property_id PropertyID) bool {
	return match property_id {
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_width { true }
		.text_decoration_skip_ink { true }
		.d { true }
		.vector_effect { true }
		.webkit_text_fill_color, .accent_color, .align_content, .align_items, .align_self, .all, .anchor_name, .anchor_scope, .appearance, .aspect_ratio, .backdrop_filter, .background, .background_attachment, .background_blend_mode, .background_clip, .background_color, .background_image, .background_origin, .background_position, .background_position_x, .background_position_y, .background_repeat, .background_size, .block_size, .border, .border_block, .border_block_color, .border_block_end, .border_block_end_color, .border_block_end_style, .border_block_end_width, .border_block_start, .border_block_start_color, .border_block_start_style, .border_block_start_width, .border_block_style, .border_block_width, .border_bottom, .border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_style, .border_bottom_width, .border_collapse, .border_color, .border_end_end_radius, .border_end_start_radius, .border_image, .border_image_outset, .border_image_repeat, .border_image_slice, .border_image_source, .border_image_width, .border_inline, .border_inline_color, .border_inline_end, .border_inline_end_color, .border_inline_end_style, .border_inline_end_width, .border_inline_start, .border_inline_start_color, .border_inline_start_style, .border_inline_start_width, .border_inline_style, .border_inline_width, .border_left, .border_left_color, .border_left_style, .border_left_width, .border_radius, .border_right, .border_right_color, .border_right_style, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_style, .border_top, .border_top_color, .border_top_left_radius, .border_top_right_radius, .border_top_style, .border_top_width, .border_width, .bottom, .box_shadow, .box_sizing, .caption_side, .caret_color, .clear, .clip, .clip_path, .clip_rule, .color, .color_interpolation, .color_scheme, .column_count, .column_gap, .column_height, .column_span, .column_width, .columns, .content, .content_visibility, .corner_block_end_shape, .corner_block_start_shape, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_bottom_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_inline_end_shape, .corner_inline_start_shape, .corner_left_shape, .corner_right_shape, .corner_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .corner_top_shape, .counter_increment, .counter_reset, .counter_set, .cursor, .cx, .cy, .display, .dominant_baseline, .empty_cells, .fill, .fill_opacity, .fill_rule, .filter, .flex, .flex_basis, .flex_direction, .flex_flow, .flex_grow, .flex_shrink, .flex_wrap, .float_, .flood_color, .flood_opacity, .font, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_size, .font_style, .font_variant, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight, .font_width, .gap, .grid, .grid_area, .grid_auto_columns, .grid_auto_flow, .grid_auto_rows, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start, .grid_template, .grid_template_areas, .grid_template_columns, .grid_template_rows, .height, .image_rendering, .inline_size, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .isolation, .justify_content, .justify_items, .justify_self, .left, .letter_spacing, .line_height, .list_style, .list_style_image, .list_style_position, .list_style_type, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .mask, .mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position, .mask_repeat, .mask_size, .mask_type, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .mix_blend_mode, .object_fit, .object_position, .opacity, .order, .orphans, .outline, .outline_color, .outline_offset, .outline_style, .outline_width, .overflow, .overflow_block, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .paint_order, .perspective, .perspective_origin, .place_content, .place_items, .place_self, .pointer_events, .position, .position_anchor, .position_area, .position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .r, .right, .rotate, .row_gap, .rx, .ry, .scale, .scrollbar_color, .scrollbar_gutter, .scrollbar_width, .shape_image_threshold, .shape_margin, .shape_outside, .shape_rendering, .stop_color, .stop_opacity, .stroke, .stroke_dasharray, .stroke_dashoffset, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .table_layout, .text_align, .text_anchor, .text_decoration, .text_decoration_color, .text_decoration_line, .text_decoration_style, .text_decoration_thickness, .text_indent, .text_justify, .text_overflow, .text_rendering, .text_shadow, .text_transform, .text_underline_offset, .text_underline_position, .text_wrap, .text_wrap_mode, .text_wrap_style, .top, .touch_action, .transform, .transform_box, .transform_origin, .transform_style, .translate, .user_select, .vertical_align, .view_transition_name, .visibility, .white_space, .white_space_collapse, .white_space_trim, .widows, .width, .word_break, .word_spacing, .x, .y, .z_index { true }
		else { false }
	}
}

pub fn property_multiplicity(property_id PropertyID) PropertyMultiplicity {
	return match property_id {
		.animation, .animation_composition, .animation_delay, .animation_direction, .animation_duration, .animation_fill_mode, .animation_iteration_count, .animation_name, .animation_play_state, .animation_timeline, .animation_timing_function, .background, .background_attachment, .background_blend_mode, .background_clip, .background_image, .background_origin, .background_position, .background_position_x, .background_position_y, .background_repeat, .background_size, .mask, .mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position, .mask_repeat, .mask_size, .scroll_timeline, .scroll_timeline_axis, .scroll_timeline_name, .transition, .transition_behavior, .transition_delay, .transition_duration, .transition_property, .transition_timing_function, .view_timeline, .view_timeline_axis, .view_timeline_inset, .view_timeline_name {
			PropertyMultiplicity.coordinating_list
		}
		.backdrop_filter, .box_shadow, .container_name, .counter_increment, .counter_reset, .counter_set, .filter, .font_family, .font_feature_settings, .font_variation_settings, .quotes, .will_change {
			PropertyMultiplicity.list
		}
		else { .single }
	}
}

pub fn property_affects_layout(property_id PropertyID) bool {
	return match property_id {
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_size, .contain_intrinsic_width { true }
		.container { true }
		.align_content, .align_items, .align_self, .all, .anchor_name, .appearance, .aspect_ratio, .block_size, .border, .border_block, .border_block_end, .border_block_end_style, .border_block_end_width, .border_block_start, .border_block_start_style, .border_block_start_width, .border_block_style, .border_block_width, .border_bottom, .border_bottom_style, .border_bottom_width, .border_collapse, .border_image, .border_inline, .border_inline_end, .border_inline_end_style, .border_inline_end_width, .border_inline_start, .border_inline_start_style, .border_inline_start_width, .border_inline_style, .border_inline_width, .border_left, .border_left_style, .border_left_width, .border_right, .border_right_style, .border_right_width, .border_spacing, .border_style, .border_top, .border_top_style, .border_top_width, .border_width, .bottom, .box_sizing, .caption_side, .clear, .column_count, .column_gap, .column_height, .column_span, .column_width, .columns, .contain, .container_type, .content, .content_visibility, .corner_block_end_shape, .corner_block_start_shape, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_bottom_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_inline_end_shape, .corner_inline_start_shape, .corner_left_shape, .corner_right_shape, .corner_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .corner_top_shape, .counter_increment, .counter_reset, .counter_set, .cx, .cy, .direction, .display, .dominant_baseline, .empty_cells, .flex, .flex_basis, .flex_direction, .flex_flow, .flex_grow, .flex_shrink, .flex_wrap, .float_, .font, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_size, .font_style, .font_variant, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight, .font_width, .gap, .grid, .grid_area, .grid_auto_columns, .grid_auto_flow, .grid_auto_rows, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start, .grid_template, .grid_template_areas, .grid_template_columns, .grid_template_rows, .height, .inline_size, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .isolation, .justify_content, .justify_items, .justify_self, .left, .letter_spacing, .line_height, .list_style, .list_style_image, .list_style_position, .list_style_type, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .math_depth, .math_shift, .math_style, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .order, .orphans, .overflow, .overflow_block, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .paint_order, .perspective, .place_content, .place_items, .place_self, .position, .position_anchor, .position_area, .position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .r, .right, .row_gap, .rx, .ry, .shape_margin, .shape_outside, .shape_rendering, .tab_size, .table_layout, .text_align, .text_anchor, .text_indent, .text_justify, .text_transform, .text_underline_offset, .text_underline_position, .text_wrap, .text_wrap_mode, .text_wrap_style, .top, .transform_style, .unicode_bidi, .vertical_align, .visibility, .white_space, .white_space_collapse, .white_space_trim, .widows, .width, .word_break, .word_spacing, .writing_mode, .x, .y { true }
		else { false }
	}
}

pub fn property_affects_stacking_context(property_id PropertyID) bool {
	return match property_id {
		.all, .backdrop_filter, .clip_path, .contain, .container_type, .filter, .mask_image, .opacity, .rotate, .scale, .transform, .translate, .view_transition_name, .will_change, .z_index { true }
		else { false }
	}
}

pub fn property_requires_computation_with_inherited_value(property_id PropertyID) bool {
	return match property_id {
		.background_attachment, .background_blend_mode, .background_clip, .background_origin, .background_position_x, .background_position_y, .background_repeat, .background_size { true }
		else { false }
	}
}

pub fn property_requires_computation_with_initial_value(property_id PropertyID) bool {
	return match property_id {
		.background_attachment, .background_blend_mode, .background_clip, .background_color, .background_origin, .background_position_x, .background_position_y, .background_repeat, .background_size, .border_block_end_width, .border_block_start_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_left_width, .border_right_width, .border_top_width, .color, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .fill, .flood_color, .font_size, .font_weight, .font_width, .letter_spacing, .outline_width, .stop_color, .word_spacing { true }
		else { false }
	}
}

pub fn property_requires_computation_with_cascaded_value(property_id PropertyID) bool {
	return match property_id {
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_width { true }
		.webkit_text_fill_color, .accent_color, .animation_delay, .animation_duration, .animation_iteration_count, .animation_name, .animation_timeline, .animation_timing_function, .aspect_ratio, .backdrop_filter, .background_attachment, .background_blend_mode, .background_clip, .background_color, .background_image, .background_origin, .background_position_x, .background_position_y, .background_repeat, .background_size, .block_size, .border_block_end_color, .border_block_end_width, .border_block_start_color, .border_block_start_width, .border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_width, .border_end_end_radius, .border_end_start_radius, .border_image_outset, .border_image_slice, .border_image_source, .border_image_width, .border_inline_end_color, .border_inline_end_width, .border_inline_start_color, .border_inline_start_width, .border_left_color, .border_left_width, .border_right_color, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_top_color, .border_top_left_radius, .border_top_right_radius, .border_top_width, .bottom, .box_shadow, .caret_color, .clip, .clip_path, .color, .column_count, .column_gap, .column_height, .column_width, .content, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .counter_increment, .counter_reset, .counter_set, .cursor, .cx, .cy, .fill, .fill_opacity, .filter, .flex_basis, .flex_grow, .flex_shrink, .flood_color, .flood_opacity, .font_feature_settings, .font_size, .font_style, .font_variation_settings, .font_weight, .font_width, .grid_auto_columns, .grid_auto_rows, .grid_template_columns, .grid_template_rows, .height, .inline_size, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .line_height, .list_style_image, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .mask_image, .mask_position, .mask_size, .math_depth, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .object_position, .opacity, .order, .orphans, .outline_color, .outline_offset, .outline_width, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective, .perspective_origin, .position_area, .r, .right, .rotate, .row_gap, .rx, .ry, .scale, .scrollbar_color, .shape_image_threshold, .shape_margin, .shape_outside, .stop_color, .stop_opacity, .stroke, .stroke_dasharray, .stroke_dashoffset, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .text_decoration_color, .text_decoration_thickness, .text_indent, .text_shadow, .text_underline_offset, .top, .transform, .transform_origin, .transition_delay, .transition_duration, .transition_timing_function, .translate, .vertical_align, .view_timeline_inset, .widows, .width, .word_spacing, .x, .y, .z_index { true }
		else { false }
	}
}

fn property_is_positional_value_list_shorthand(property_id PropertyID) bool {
	return match property_id {
		.contain_intrinsic_size { true }
		.border_block_color, .border_block_style, .border_block_width, .border_color, .border_inline_color, .border_inline_style, .border_inline_width, .border_style, .border_width, .corner_block_end_shape, .corner_block_start_shape, .corner_bottom_shape, .corner_inline_end_shape, .corner_inline_start_shape, .corner_left_shape, .corner_right_shape, .corner_shape, .corner_top_shape, .gap, .inset, .inset_block, .inset_inline, .margin, .margin_block, .margin_inline, .overflow, .padding, .padding_block, .padding_inline { true }
		else { false }
	}
}

pub fn property_maximum_value_count(property_id PropertyID) usize {
	return match property_id {
		.background_position, .border_image_outset, .border_image_width, .grid_template_columns, .grid_template_rows {
			4
		}
		.background_repeat, .background_size, .border_bottom_left_radius, .border_bottom_right_radius, .border_image_repeat, .border_spacing, .border_top_left_radius, .border_top_right_radius, .mask_repeat, .mask_size, .touch_action {
			2
		}
		.display, .transform_origin {
			3
		}
		else { 1 }
	}
}

pub fn resolve_legacy_value_alias(property_id PropertyID, keyword Keyword) ?Keyword {
	return match property_id {
		.overflow {
			match keyword {
				.overlay { Keyword.auto }
				else { none }
			}
		}
		.overflow_block {
			match keyword {
				.overlay { Keyword.auto }
				else { none }
			}
		}
		.overflow_inline {
			match keyword {
				.overlay { Keyword.auto }
				else { none }
			}
		}
		.overflow_x {
			match keyword {
				.overlay { Keyword.auto }
				else { none }
			}
		}
		.overflow_y {
			match keyword {
				.overlay { Keyword.auto }
				else { none }
			}
		}
		.text_justify {
			match keyword {
				.distribute { Keyword.inter_character }
				else { none }
			}
		}
		else { none }
	}
}

pub fn property_resolves_percentages_relative_to(property_id PropertyID) ?ValueType {
	return match property_id {
		.background_position, .background_position_x, .background_position_y, .background_size, .block_size, .border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius, .border_image_width, .border_radius, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .bottom, .column_gap, .cx, .cy, .flex_basis, .font_size, .gap, .grid, .grid_auto_columns, .grid_auto_rows, .grid_template, .grid_template_columns, .grid_template_rows, .height, .inline_size, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .line_height, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .mask_position, .mask_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .object_position, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective_origin, .r, .right, .row_gap, .rx, .ry, .shape_margin, .stroke_dasharray, .stroke_dashoffset, .stroke_width, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform, .transform_origin, .translate, .vertical_align, .view_timeline_inset, .width, .word_spacing, .x, .y {
			ValueType.length
		}
		else { none }
	}
}

pub fn property_accepts_type(property_id PropertyID, value_type ValueType) bool {
	return match property_id {
		.webkit_text_fill_color, .accent_color, .background_color, .border_block_color, .border_block_end_color, .border_block_start_color, .border_bottom_color, .border_color, .border_inline_color, .border_inline_end_color, .border_inline_start_color, .border_left_color, .border_right_color, .border_top_color, .caret_color, .color, .flood_color, .outline_color, .stop_color, .text_decoration_color {
			value_type == .color
		}
		.anchor_name, .anchor_scope, .position_anchor, .position_try_fallbacks, .scroll_timeline_name, .view_timeline_name {
			value_type == .dashed_ident
		}
		.animation_delay, .animation_duration, .transition_delay, .transition_duration {
			value_type == .time
		}
		.animation_iteration_count, .flex_grow, .flex_shrink, .font_weight, .stroke_miterlimit {
			value_type == .number
		}
		.animation_name {
			value_type in [.string, .custom_ident]
		}
		.animation_timeline {
			value_type in [.dashed_ident, .scroll_function, .view_function]
		}
		.animation_timing_function, .transition_timing_function {
			value_type == .easing_function
		}
		.aspect_ratio {
			value_type == .ratio
		}
		.background_image, .border_image_source, .list_style_image {
			value_type == .image
		}
		.background_position {
			value_type == .background_position
		}
		.background_position_x, .background_position_y, .background_size, .border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius, .border_radius, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .column_gap, .cx, .cy, .font_size, .gap, .inset, .inset_block, .inset_inline, .letter_spacing, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .mask_size, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .r, .row_gap, .rx, .ry, .shape_margin, .text_decoration_thickness, .text_indent, .text_underline_offset, .transform_origin, .translate, .vertical_align, .word_spacing, .x, .y {
			value_type in [.length, .percentage]
		}
		.block_size, .flex_basis, .height, .inline_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .width {
			value_type in [.fit_content, .length, .percentage]
		}
		.border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_right_width, .border_spacing, .border_top_width, .border_width, .column_height, .column_width, .outline_offset, .outline_width, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .perspective {
			value_type == .length
		}
		.border_image_outset, .tab_size {
			value_type in [.length, .number]
		}
		.border_image_slice {
			value_type in [.number, .percentage]
		}
		.border_image_width {
			value_type in [.length, .percentage, .number]
		}
		.bottom, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start, .left, .right, .top {
			value_type in [.length, .percentage, .anchor]
		}
		.clip {
			value_type == .rect
		}
		.clip_path {
			value_type in [.basic_shape, .url]
		}
		.container_name {
			value_type == .custom_ident
		}
		.color_scheme, .grid_area, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start, .transition_property, .view_transition_name, .will_change {
			value_type == .custom_ident
		}
		.column_count, .math_depth, .order, .orphans, .widows, .z_index {
			value_type == .integer
		}
		.content {
			value_type in [.counter, .image, .string]
		}
		.corner_block_end_shape, .corner_block_start_shape, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_bottom_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_inline_end_shape, .corner_inline_start_shape, .corner_left_shape, .corner_right_shape, .corner_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .corner_top_shape {
			value_type == .corner_shape
		}
		.counter_increment, .counter_reset, .counter_set {
			value_type in [.custom_ident, .integer]
		}
		.cursor {
			value_type in [.url, .number]
		}
		.fill, .stroke {
			value_type == .paint
		}
		.fill_opacity, .flood_opacity, .opacity, .shape_image_threshold, .stop_opacity, .stroke_opacity {
			value_type == .opacity
		}
		.font_family {
			value_type in [.custom_ident, .string]
		}
		.font_feature_settings {
			value_type in [.integer, .opentype_tag]
		}
		.font_language_override, .font_variant, .grid_template_areas, .quotes {
			value_type == .string
		}
		.font_style {
			value_type == .font_style
		}
		.font_variant_alternates {
			value_type == .font_variant_alternates
		}
		.font_variant_east_asian {
			value_type == .font_variant_east_asian
		}
		.font_variant_ligatures {
			value_type == .font_variant_ligatures
		}
		.font_variant_numeric {
			value_type == .font_variant_numeric
		}
		.font_variation_settings {
			value_type in [.number, .opentype_tag]
		}
		.font_width {
			value_type == .percentage
		}
		.grid, .grid_auto_columns, .grid_auto_rows, .grid_template, .grid_template_columns, .grid_template_rows {
			value_type in [.length, .percentage, .string]
		}
		.line_height, .stroke_dashoffset, .stroke_width {
			value_type in [.length, .number, .percentage]
		}
		.list_style_type {
			value_type in [.counter_style, .string]
		}
		.mask_image {
			value_type in [.image, .url]
		}
		.mask_position, .object_position, .perspective_origin {
			value_type == .position
		}
		.transform {
			value_type == .transform_list
		}
		.view_timeline_inset {
			value_type == .view_timeline_inset
		}
		else { false }
	}
}

fn property_custom_ident_blacklist(property_id PropertyID) []string {
	return match property_id {
		.animation_name, .counter_increment, .counter_reset, .counter_set, .transition_property {
			['none']
		}
		.color_scheme {
			['normal', 'light', 'dark', 'only']
		}
		.container_name {
			['none', 'and', 'not', 'or']
		}
		.grid_area, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start {
			['auto', 'span']
		}
		.view_transition_name {
			['auto', 'none']
		}
		.will_change {
			['all', 'auto', 'contents', 'none', 'scroll-position', 'will-change']
		}
		else { [] }
	}
}

fn property_accepts_keyword_string(property_id PropertyID, value string) bool {
	lowercase_value := to_ascii_lowercase(value)
	return match property_id {
		.accent_color, .animation_duration, .aspect_ratio, .border_image_width, .bottom, .caret_color, .clip, .column_count, .column_height, .column_width, .grid, .grid_area, .grid_auto_columns, .grid_auto_rows, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start, .grid_template, .grid_template_columns, .grid_template_rows, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .right, .rx, .ry, .text_underline_offset, .top, .z_index {
			lowercase_value in ['auto']
		}
		.position_anchor {
			lowercase_value in ['normal', 'none', 'auto']
		}
		.align_content {
			lowercase_value in ['normal', 'start', 'flex-start', 'end', 'flex-end', 'center', 'space-between', 'space-around', 'space-evenly', 'stretch']
		}
		.align_items {
			lowercase_value in ['baseline', 'center', 'end', 'flex-end', 'flex-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe']
		}
		.align_self {
			lowercase_value in ['auto', 'baseline', 'center', 'end', 'flex-end', 'flex-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe']
		}
		.anchor_name, .animation_name, .backdrop_filter, .background_image, .border_image_source, .box_shadow, .clip_path, .counter_increment, .counter_reset, .counter_set, .filter, .flex, .grid_template_areas, .list_style_image, .list_style_type, .mask_image, .perspective, .scroll_timeline_name, .text_shadow, .transform, .transition_property, .view_timeline_name, .view_transition_name {
			lowercase_value in ['none']
		}
		.anchor_scope, .column_span {
			lowercase_value in ['none', 'all']
		}
		.animation_composition {
			lowercase_value in ['replace', 'add', 'accumulate']
		}
		.animation_direction {
			lowercase_value in ['normal', 'reverse', 'alternate', 'alternate-reverse']
		}
		.animation_fill_mode {
			lowercase_value in ['none', 'forwards', 'backwards', 'both']
		}
		.animation_iteration_count {
			lowercase_value in ['infinite']
		}
		.animation_play_state {
			lowercase_value in ['running', 'paused']
		}
		.animation_timeline, .font_optical_sizing, .quotes {
			lowercase_value in ['auto', 'none']
		}
		.animation_timing_function, .transition_timing_function {
			lowercase_value in ['linear', 'ease', 'ease-in', 'ease-out', 'ease-in-out']
		}
		.appearance {
			lowercase_value in ['auto', 'button', 'checkbox', 'listbox', 'menulist', 'meter', 'menulist-button', 'none', 'push-button', 'progress-bar', 'radio', 'searchfield', 'slider-horizontal', 'square-button', 'textarea', 'textfield']
		}
		.background_attachment {
			lowercase_value in ['fixed', 'local', 'scroll']
		}
		.background_blend_mode, .mix_blend_mode {
			lowercase_value in ['normal', 'multiply', 'screen', 'overlay', 'darken', 'lighten', 'color-dodge', 'color-burn', 'hard-light', 'soft-light', 'difference', 'exclusion', 'hue', 'saturation', 'color', 'luminosity', 'plus-darker', 'plus-lighter']
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
			lowercase_value in ['repeat-x', 'repeat-y', 'no-repeat', 'repeat', 'round', 'space']
		}
		.background_size, .mask_size {
			lowercase_value in ['auto', 'cover', 'contain']
		}
		.block_size, .height, .inline_size, .min_block_size, .min_height, .min_inline_size, .min_width, .width {
			lowercase_value in ['auto', 'max-content', 'min-content']
		}
		.border_block_end_style, .border_block_start_style, .border_block_style, .border_bottom_style, .border_inline_end_style, .border_inline_start_style, .border_inline_style, .border_left_style, .border_right_style, .border_style, .border_top_style {
			lowercase_value in ['none', 'hidden', 'dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset']
		}
		.border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_right_width, .border_top_width, .border_width, .outline_width {
			lowercase_value in ['thin', 'medium', 'thick']
		}
		.border_collapse {
			lowercase_value in ['separate', 'collapse']
		}
		.border_image_repeat {
			lowercase_value in ['stretch', 'repeat', 'round', 'space']
		}
		.border_image_slice {
			lowercase_value in ['fill']
		}
		.box_sizing {
			lowercase_value in ['border-box', 'content-box']
		}
		.caption_side {
			lowercase_value in ['top', 'bottom']
		}
		.clear {
			lowercase_value in ['none', 'left', 'right', 'both', 'inline-start', 'inline-end']
		}
		.clip_rule, .fill_rule {
			lowercase_value in ['nonzero', 'evenodd']
		}
		.color_interpolation {
			lowercase_value in ['auto', 'linearrgb', 'srgb']
		}
		.color_scheme {
			lowercase_value in ['normal', 'light', 'dark']
		}
		.column_gap, .font_language_override, .font_variant_alternates, .font_variant_east_asian, .font_variant_numeric, .font_variation_settings, .gap, .letter_spacing, .line_height, .row_gap, .word_spacing {
			lowercase_value in ['normal']
		}
		.contain {
			lowercase_value in ['none', 'strict', 'content', 'size', 'inline-size', 'layout', 'style', 'paint']
		}
		.container_name {
			lowercase_value in ['none']
		}
		.container_type {
			lowercase_value in ['normal', 'size', 'inline-size', 'scroll-state']
		}
		.content {
			lowercase_value in ['normal', 'none', 'open-quote', 'close-quote', 'no-open-quote', 'no-close-quote']
		}
		.content_visibility {
			lowercase_value in ['visible', 'auto', 'hidden']
		}
		.cursor {
			lowercase_value in ['auto', 'default', 'none', 'context-menu', 'help', 'pointer', 'progress', 'wait', 'cell', 'crosshair', 'text', 'vertical-text', 'alias', 'copy', 'move', 'no-drop', 'not-allowed', 'grab', 'grabbing', 'e-resize', 'n-resize', 'ne-resize', 'nw-resize', 's-resize', 'se-resize', 'sw-resize', 'w-resize', 'ew-resize', 'ns-resize', 'nesw-resize', 'nwse-resize', 'col-resize', 'row-resize', 'all-scroll', 'zoom-in', 'zoom-out']
		}
		.direction {
			lowercase_value in ['ltr', 'rtl']
		}
		.display {
			lowercase_value in ['list-item', 'block', 'inline', 'run-in', 'flow', 'flow-root', 'table', 'flex', 'grid', 'ruby', 'math', 'table-row-group', 'table-header-group', 'table-footer-group', 'table-row', 'table-cell', 'table-column-group', 'table-column', 'table-caption', 'ruby-base', 'ruby-text', 'ruby-base-container', 'ruby-text-container', 'contents', 'none', 'inline-block', 'inline-table', 'inline-flex', 'inline-grid']
		}
		.dominant_baseline {
			lowercase_value in ['auto', 'text-bottom', 'alphabetic', 'ideographic', 'middle', 'central', 'mathematical', 'hanging', 'text-top']
		}
		.empty_cells {
			lowercase_value in ['show', 'hide']
		}
		.flex_basis {
			lowercase_value in ['auto', 'content', 'max-content', 'min-content']
		}
		.flex_direction {
			lowercase_value in ['row', 'row-reverse', 'column', 'column-reverse']
		}
		.flex_wrap {
			lowercase_value in ['nowrap', 'wrap', 'wrap-reverse']
		}
		.float_ {
			lowercase_value in ['none', 'left', 'right', 'inline-start', 'inline-end']
		}
		.font_feature_settings {
			lowercase_value in ['normal', 'on', 'off']
		}
		.font_kerning {
			lowercase_value in ['auto', 'normal', 'none']
		}
		.font_size {
			lowercase_value in ['math', 'xx-small', 'x-small', 'small', 'medium', 'large', 'x-large', 'xx-large', 'xxx-large', 'smaller', 'larger']
		}
		.font_variant_caps {
			lowercase_value in ['normal', 'small-caps', 'all-small-caps', 'petite-caps', 'all-petite-caps', 'unicase', 'titling-caps']
		}
		.font_variant_emoji {
			lowercase_value in ['normal', 'text', 'emoji', 'unicode']
		}
		.font_variant_ligatures {
			lowercase_value in ['normal', 'none']
		}
		.font_variant_position {
			lowercase_value in ['normal', 'sub', 'super']
		}
		.font_weight {
			lowercase_value in ['bold', 'bolder', 'lighter', 'normal']
		}
		.font_width {
			lowercase_value in ['ultra-condensed', 'extra-condensed', 'condensed', 'semi-condensed', 'normal', 'semi-expanded', 'expanded', 'extra-expanded', 'ultra-expanded']
		}
		.image_rendering {
			lowercase_value in ['auto', 'crisp-edges', 'high-quality', 'pixelated', 'smooth', 'optimizespeed=pixelated', 'optimizequality=smooth']
		}
		.isolation {
			lowercase_value in ['auto', 'isolate']
		}
		.justify_content {
			lowercase_value in ['normal', 'start', 'end', 'flex-start', 'flex-end', 'center', 'space-between', 'space-around', 'space-evenly', 'stretch', 'left', 'right']
		}
		.justify_items {
			lowercase_value in ['baseline', 'center', 'end', 'flex-end', 'flex-start', 'legacy', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe', 'left', 'right']
		}
		.justify_self {
			lowercase_value in ['auto', 'baseline', 'center', 'end', 'flex-end', 'flex-start', 'normal', 'safe', 'self-end', 'self-start', 'start', 'stretch', 'unsafe', 'left', 'right']
		}
		.list_style_position {
			lowercase_value in ['inside', 'outside']
		}
		.mask_clip {
			lowercase_value in ['no-clip', 'content-box', 'padding-box', 'border-box', 'fill-box', 'stroke-box', 'view-box']
		}
		.mask_composite {
			lowercase_value in ['add', 'subtract', 'intersect', 'exclude']
		}
		.mask_mode {
			lowercase_value in ['alpha', 'luminance', 'match-source']
		}
		.mask_origin {
			lowercase_value in ['content-box', 'padding-box', 'border-box', 'fill-box', 'stroke-box', 'view-box']
		}
		.mask_type {
			lowercase_value in ['luminance', 'alpha']
		}
		.math_depth {
			lowercase_value in ['auto-add']
		}
		.math_shift, .math_style {
			lowercase_value in ['normal', 'compact']
		}
		.max_block_size, .max_height, .max_inline_size, .max_width {
			lowercase_value in ['max-content', 'min-content', 'none']
		}
		.object_fit {
			lowercase_value in ['fill', 'contain', 'cover', 'none', 'scale-down']
		}
		.outline_style {
			lowercase_value in ['auto', 'none', 'dotted', 'dashed', 'solid', 'double', 'groove', 'ridge', 'inset', 'outset']
		}
		.overflow, .overflow_block, .overflow_inline, .overflow_x, .overflow_y {
			lowercase_value in ['overlay', 'auto', 'clip', 'hidden', 'scroll', 'visible']
		}
		.overflow_wrap {
			lowercase_value in ['anywhere', 'break-word', 'normal']
		}
		.paint_order {
			lowercase_value in ['normal', 'fill', 'stroke', 'markers']
		}
		.pointer_events {
			lowercase_value in ['auto', 'all', 'none']
		}
		.position {
			lowercase_value in ['absolute', 'fixed', 'relative', 'static', 'sticky']
		}
		.position_area {
			lowercase_value in ['none', 'left', 'center', 'right', 'span-left', 'span-right', 'x-start', 'x-end', 'span-x-start', 'span-x-end', 'self-x-start', 'self-x-end', 'span-self-x-start', 'span-self-x-end', 'span-all', 'top', 'bottom', 'span-top', 'span-bottom', 'y-start', 'y-end', 'span-y-start', 'span-y-end', 'self-y-start', 'self-y-end', 'span-self-y-start', 'span-self-y-end', 'block-start', 'block-end', 'span-block-start', 'span-block-end', 'inline-start', 'inline-end', 'span-inline-start', 'span-inline-end', 'self-block-start', 'self-block-end', 'span-self-block-start', 'span-self-block-end', 'self-inline-start', 'self-inline-end', 'span-self-inline-start', 'span-self-inline-end', 'start', 'end', 'span-start', 'span-end', 'self-start', 'self-end', 'span-self-start', 'span-self-end']
		}
		.position_try_fallbacks {
			lowercase_value in ['none', 'flip-block', 'flip-inline', 'flip-start']
		}
		.position_try_order {
			lowercase_value in ['normal', 'most-width', 'most-height', 'most-block-size', 'most-inline-size']
		}
		.position_visibility {
			lowercase_value in ['always', 'anchors-valid', 'anchors-visible', 'no-overflow']
		}
		.resize {
			lowercase_value in ['none', 'both', 'horizontal', 'vertical', 'inline', 'block']
		}
		.scroll_behavior {
			lowercase_value in ['auto', 'smooth']
		}
		.scroll_timeline_axis, .view_timeline_axis {
			lowercase_value in ['block', 'inline', 'x', 'y']
		}
		.scrollbar_width {
			lowercase_value in ['auto', 'thin', 'none']
		}
		.shape_rendering {
			lowercase_value in ['auto', 'optimizespeed', 'crispedges', 'geometricprecision']
		}
		.stroke_linecap {
			lowercase_value in ['butt', 'square', 'round']
		}
		.stroke_linejoin {
			lowercase_value in ['miter', 'round', 'bevel']
		}
		.table_layout {
			lowercase_value in ['auto', 'fixed']
		}
		.text_align {
			lowercase_value in ['center', 'justify', 'start', 'end', 'left', 'right', 'match-parent', '-libweb-center', '-libweb-inherit-or-center', '-libweb-left', '-libweb-right']
		}
		.text_anchor {
			lowercase_value in ['start', 'middle', 'end']
		}
		.text_decoration_line {
			lowercase_value in ['none', 'underline', 'overline', 'line-through', 'blink', 'spelling-error', 'grammar-error']
		}
		.text_decoration_skip_ink {
			lowercase_value in ['all', 'auto', 'none']
		}
		.text_decoration_style {
			lowercase_value in ['dashed', 'dotted', 'double', 'solid', 'wavy']
		}
		.text_decoration_thickness {
			lowercase_value in ['auto', 'from-font']
		}
		.text_indent {
			lowercase_value in ['each-line', 'hanging']
		}
		.text_justify {
			lowercase_value in ['distribute', 'auto', 'none', 'inter-word', 'inter-character']
		}
		.text_overflow {
			lowercase_value in ['clip', 'ellipsis']
		}
		.text_rendering {
			lowercase_value in ['auto', 'optimizespeed', 'optimizelegibility', 'geometricprecision']
		}
		.text_transform {
			lowercase_value in ['capitalize', 'full-size-kana', 'full-width', 'lowercase', 'math-auto', 'none', 'uppercase']
		}
		.text_underline_position {
			lowercase_value in ['auto', 'from-font', 'under', 'left', 'right']
		}
		.text_wrap_mode {
			lowercase_value in ['wrap', 'nowrap']
		}
		.text_wrap_style {
			lowercase_value in ['auto', 'balance', 'stable', 'pretty']
		}
		.touch_action {
			lowercase_value in ['auto', 'manipulation', 'none', 'pan-down', 'pan-left', 'pan-right', 'pan-up', 'pan-x', 'pan-y']
		}
		.transform_box {
			lowercase_value in ['content-box', 'border-box', 'fill-box', 'stroke-box', 'view-box']
		}
		.transform_origin {
			lowercase_value in ['bottom', 'center', 'left', 'right', 'top']
		}
		.transform_style {
			lowercase_value in ['flat', 'preserve-3d']
		}
		.transition_behavior {
			lowercase_value in ['normal', 'allow-discrete']
		}
		.unicode_bidi {
			lowercase_value in ['bidi-override', 'embed', 'isolate', 'isolate-override', 'normal', 'plaintext']
		}
		.user_select {
			lowercase_value in ['all', 'auto', 'contain', 'none', 'text']
		}
		.vector_effect {
			lowercase_value in ['none', 'non-scaling-stroke']
		}
		.vertical_align {
			lowercase_value in ['baseline', 'bottom', 'middle', 'sub', 'super', 'text-bottom', 'text-top', 'top']
		}
		.visibility {
			lowercase_value in ['collapse', 'hidden', 'visible']
		}
		.white_space {
			lowercase_value in ['normal', 'pre', 'pre-line', 'pre-wrap']
		}
		.white_space_collapse {
			lowercase_value in ['collapse', 'discard', 'preserve', 'preserve-breaks', 'preserve-spaces', 'break-spaces']
		}
		.white_space_trim {
			lowercase_value in ['none', 'discard-before', 'discard-after', 'discard-inner']
		}
		.will_change {
			lowercase_value in ['auto', 'scroll-position', 'contents']
		}
		.word_break {
			lowercase_value in ['normal', 'keep-all', 'break-all', 'break-word']
		}
		.writing_mode {
			lowercase_value in ['horizontal-tb', 'vertical-rl', 'vertical-lr', 'sideways-rl', 'sideways-lr']
		}
		else { false }
	}
}

pub fn property_accepted_type_ranges(property_id PropertyID) map[ValueType]AcceptedTypeRange {
	mut ranges := map[ValueType]AcceptedTypeRange{}
	match property_id {
		.animation_delay {
			ranges[.time] = AcceptedTypeRange{
				min: -math.max_f32
				max: math.max_f32
			}
		}
		.animation_duration, .transition_duration {
			ranges[.time] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.animation_iteration_count, .flex_grow, .flex_shrink, .stroke_miterlimit {
			ranges[.number] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.background_position_x, .background_position_y, .bottom, .cx, .cy, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .right, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform_origin, .translate, .vertical_align, .word_spacing, .x, .y {
			ranges[.length] = AcceptedTypeRange{
				min: -math.max_f32
				max: math.max_f32
			}
			ranges[.percentage] = AcceptedTypeRange{
				min: -math.max_f32
				max: math.max_f32
			}
		}
		.background_size, .block_size, .border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius, .border_radius, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .column_gap, .flex_basis, .font_size, .gap, .grid, .grid_auto_columns, .grid_auto_rows, .grid_template, .grid_template_columns, .grid_template_rows, .height, .inline_size, .mask_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .r, .row_gap, .rx, .ry, .shape_margin, .width {
			ranges[.length] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.percentage] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_right_width, .border_spacing, .border_top_width, .border_width, .column_height, .column_width, .outline_width, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .perspective {
			ranges[.length] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.border_image_outset, .tab_size {
			ranges[.length] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.number] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.border_image_slice {
			ranges[.number] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.percentage] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.border_image_width {
			ranges[.length] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.percentage] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.number] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.column_count, .orphans, .widows {
			ranges[.integer] = AcceptedTypeRange{
				min: 1
				max: f64(2147483647)
			}
		}
		.counter_increment, .counter_reset, .counter_set, .order, .z_index {
			ranges[.integer] = AcceptedTypeRange{
				min: f64(-2147483647 - 1)
				max: f64(2147483647)
			}
		}
		.cursor {
			ranges[.number] = AcceptedTypeRange{
				min: -math.max_f32
				max: math.max_f32
			}
		}
		.fill_opacity, .flood_opacity, .opacity, .shape_image_threshold, .stop_opacity, .stroke_opacity {
			ranges[.number] = AcceptedTypeRange{
				min: 0
				max: 1
			}
			ranges[.percentage] = AcceptedTypeRange{
				min: 0
				max: 100
			}
		}
		.font_feature_settings {
			ranges[.integer] = AcceptedTypeRange{
				min: 0
				max: f64(2147483647)
			}
		}
		.font_weight {
			ranges[.number] = AcceptedTypeRange{
				min: 1
				max: 1000
			}
		}
		.font_width {
			ranges[.percentage] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.line_height, .stroke_dashoffset, .stroke_width {
			ranges[.length] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.number] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.percentage] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
		.outline_offset {
			ranges[.length] = AcceptedTypeRange{
				min: -math.max_f32
				max: math.max_f32
			}
		}
		else {}
	}
	return ranges
}

pub fn property_accepts_angle(property_id PropertyID, value Angle) bool {
	_ = property_id
	_ = value
	return false
}

pub fn property_accepts_flex(property_id PropertyID, value Flex) bool {
	_ = property_id
	_ = value
	return false
}

pub fn property_accepts_frequency(property_id PropertyID, value Frequency) bool {
	_ = property_id
	_ = value
	return false
}

pub fn property_accepts_integer(property_id PropertyID, value i64) bool {
	return match property_id {
		.column_count, .orphans, .widows {
			value >= 1
		}
		.counter_increment, .counter_reset, .counter_set, .math_depth, .order, .z_index {
			true
		}
		.font_feature_settings {
			value >= 0
		}
		else { false }
	}
}

pub fn property_accepts_length(property_id PropertyID, value Length) bool {
	return match property_id {
		.background_position_x, .background_position_y, .bottom, .cx, .cy, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .outline_offset, .right, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform_origin, .translate, .vertical_align, .word_spacing, .x, .y {
			true
		}
		.background_size, .block_size, .border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_width, .border_end_end_radius, .border_end_start_radius, .border_image_outset, .border_image_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_radius, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .border_top_width, .border_width, .column_gap, .column_height, .column_width, .flex_basis, .font_size, .gap, .grid, .grid_auto_columns, .grid_auto_rows, .grid_template, .grid_template_columns, .grid_template_rows, .height, .inline_size, .line_height, .mask_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .outline_width, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective, .r, .row_gap, .rx, .ry, .shape_margin, .stroke_dashoffset, .stroke_width, .tab_size, .width {
			value.raw_value() >= 0
		}
		else { false }
	}
}

pub fn property_accepts_number(property_id PropertyID, value f64) bool {
	return match property_id {
		.animation_iteration_count, .border_image_outset, .border_image_slice, .border_image_width, .flex_grow, .flex_shrink, .line_height, .stroke_dashoffset, .stroke_miterlimit, .stroke_width, .tab_size {
			value >= 0
		}
		.cursor, .font_variation_settings {
			true
		}
		.font_weight {
			value >= 1 && value <= 1000
		}
		else { false }
	}
}

pub fn property_accepts_percentage(property_id PropertyID, value Percentage) bool {
	return match property_id {
		.background_position_x, .background_position_y, .bottom, .cx, .cy, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .right, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform_origin, .translate, .vertical_align, .word_spacing, .x, .y {
			true
		}
		.background_size, .block_size, .border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius, .border_image_slice, .border_image_width, .border_radius, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .column_gap, .flex_basis, .font_size, .font_width, .gap, .grid, .grid_auto_columns, .grid_auto_rows, .grid_template, .grid_template_columns, .grid_template_rows, .height, .inline_size, .line_height, .mask_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .r, .row_gap, .rx, .ry, .shape_margin, .stroke_dashoffset, .stroke_width, .width {
			value.value() >= 0
		}
		else { false }
	}
}

pub fn property_accepts_resolution(property_id PropertyID, value Resolution) bool {
	_ = property_id
	_ = value
	return false
}

pub fn property_accepts_time(property_id PropertyID, value Time) bool {
	return match property_id {
		.animation_delay, .transition_delay {
			true
		}
		.animation_duration, .transition_duration {
			value.raw_value() >= 0
		}
		else { false }
	}
}
