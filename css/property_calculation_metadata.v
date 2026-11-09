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
		'-webkit-flex-direction' {
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
	if name == 'grid-lanes-direction' { return .grid_lanes_direction }
	if name == 'fit-tolerance' { return .fit_tolerance }

	if name == 'overscroll-behavior-x' { return .overscroll_behavior_x }
	if name == 'overscroll-behavior-y' { return .overscroll_behavior_y }
	if name == 'overscroll-behavior-inline' { return .overscroll_behavior_inline }
	if name == 'overscroll-behavior-block' { return .overscroll_behavior_block }
	if name == 'overscroll-behavior' { return .overscroll_behavior }

	if name == 'alignment-baseline' { return .alignment_baseline }
	if name == 'baseline-shift' { return .baseline_shift }
	if name == 'baseline-source' { return .baseline_source }

	if name == 'border-shape' { return .border_shape }
	if name == 'text-orientation' { return .text_orientation }
	if name == 'forced-color-adjust' { return .forced_color_adjust }
	if name == 'font-palette' { return .font_palette }
	if name == 'font-size-adjust' { return .font_size_adjust }
	if name == 'position-try' { return .position_try }
	if name == 'animation-range' { return .animation_range }
	if name == 'animation-range-end' { return .animation_range_end }
	if name == 'animation-range-start' { return .animation_range_start }
	if name == 'text-box-trim' { return .text_box_trim }
	if name == 'text-box-edge' { return .text_box_edge }
	if name == 'font-synthesis' { return .font_synthesis }
	if name == 'font-synthesis-weight' { return .font_synthesis_weight }
	if name == 'font-synthesis-style' { return .font_synthesis_style }
	if name == 'font-synthesis-small-caps' { return .font_synthesis_small_caps }
	if name == 'font-synthesis-position' { return .font_synthesis_position }
	if name == 'hyphens' { return .hyphens }
	// Keep bucket selection scalar; wrap the result once after a full match.
	mut value := PropertyID.webkit_box_orient
	mut found := false
	match name.len {
		1 {
			match name[0] {
				0x64 {
					match name {
						'd' {
							value = PropertyID.d
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'r' {
							value = PropertyID.r
							found = true
						}
						else {}
					}
				}
				0x78 {
					match name {
						'x' {
							value = PropertyID.x
							found = true
						}
						else {}
					}
				}
				0x79 {
					match name {
						'y' {
							value = PropertyID.y
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		2 {
			match name[0] {
				0x63 {
					match name {
						'cx' {
							value = PropertyID.cx
							found = true
						}
						'cy' {
							value = PropertyID.cy
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'rx' {
							value = PropertyID.rx
							found = true
						}
						'ry' {
							value = PropertyID.ry
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		3 {
			match name[0] {
				0x61 {
					match name {
						'all' {
							value = PropertyID.all
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'gap' {
							value = PropertyID.gap
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'top' {
							value = PropertyID.top
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		4 {
			match name[0] {
				0x63 {
					match name {
						'clip' {
							value = PropertyID.clip
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fill' {
							value = PropertyID.fill
							found = true
						}
						'flex' {
							value = PropertyID.flex
							found = true
						}
						'font' {
							value = PropertyID.font
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid' {
							value = PropertyID.grid
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'left' {
							value = PropertyID.left
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'mask' {
							value = PropertyID.mask
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		5 {
			match name[0] {
				0x63 {
					match name {
						'clear' {
							value = PropertyID.clear
							found = true
						}
						'color' {
							value = PropertyID.color
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'float' {
							value = PropertyID.float_
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inset' {
							value = PropertyID.inset
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'order' {
							value = PropertyID.order
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'right' {
							value = PropertyID.right
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scale' {
							value = PropertyID.scale
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'width' {
							value = PropertyID.width
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		6 {
			match name[0] {
				0x62 {
					match name {
						'border' {
							value = PropertyID.border
							found = true
						}
						'bottom' {
							value = PropertyID.bottom
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'cursor' {
							value = PropertyID.cursor
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'filter' {
							value = PropertyID.filter
							found = true
						}
						else {}
					}
				}
				0x68 {
					match name {
						'height' {
							value = PropertyID.height
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin' {
							value = PropertyID.margin
							found = true
						}
						else {}
					}
				}
				0x71 {
					match name {
						'quotes' {
							value = PropertyID.quotes
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'resize' {
							value = PropertyID.resize
							found = true
						}
						'rotate' {
							value = PropertyID.rotate
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'stroke' {
							value = PropertyID.stroke
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'widows' {
							value = PropertyID.widows
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		7 {
			match name[0] {
				0x63 {
					match name {
						'columns' {
							value = PropertyID.columns
							found = true
						}
						'contain' {
							value = PropertyID.contain
							found = true
						}
						'content' {
							value = PropertyID.content
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'display' {
							value = PropertyID.display
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'opacity' {
							value = PropertyID.opacity
							found = true
						}
						'orphans' {
							value = PropertyID.orphans
							found = true
						}
						'outline' {
							value = PropertyID.outline
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding' {
							value = PropertyID.padding
							found = true
						}
						else {}
					}
				}
				0x72 {
					match name {
						'row-gap' {
							value = PropertyID.row_gap
							found = true
						}
						else {}
					}
				}
				0x7a {
					match name {
						'z-index' {
							value = PropertyID.z_index
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		8 {
			match name[0] {
				0x63 {
					match name {
						'continue' {
							value = PropertyID.continue_
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-row' {
							value = PropertyID.grid_row
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'overflow' {
							value = PropertyID.overflow
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'position' {
							value = PropertyID.position
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'tab-size' {
							value = PropertyID.tab_size
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		9 {
			match name[0] {
				0x61 {
					match name {
						'animation' {
							value = PropertyID.animation
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'clip-path' {
							value = PropertyID.clip_path
							found = true
						}
						'clip-rule' {
							value = PropertyID.clip_rule
							found = true
						}
						'container' {
							value = PropertyID.container
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'direction' {
							value = PropertyID.direction
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fill-rule' {
							value = PropertyID.fill_rule
							found = true
						}
						'flex-flow' {
							value = PropertyID.flex_flow
							found = true
						}
						'flex-grow' {
							value = PropertyID.flex_grow
							found = true
						}
						'flex-wrap' {
							value = PropertyID.flex_wrap
							found = true
						}
						'font-size' {
							value = PropertyID.font_size
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-area' {
							value = PropertyID.grid_area
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'isolation' {
							value = PropertyID.isolation
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'mask-clip' {
							value = PropertyID.mask_clip
							found = true
						}
						'mask-mode' {
							value = PropertyID.mask_mode
							found = true
						}
						'mask-size' {
							value = PropertyID.mask_size
							found = true
						}
						'mask-type' {
							value = PropertyID.mask_type
							found = true
						}
						'max-lines' {
							value = PropertyID.max_lines
							found = true
						}
						'max-width' {
							value = PropertyID.max_width
							found = true
						}
						'min-width' {
							value = PropertyID.min_width
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-wrap' {
							value = PropertyID.text_wrap
							found = true
						}
						'transform' {
							value = PropertyID.transform
							found = true
						}
						'translate' {
							value = PropertyID.translate
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		10 {
			match name[0] {
				0x61 {
					match name {
						'align-self' {
							value = PropertyID.align_self
							found = true
						}
						'appearance' {
							value = PropertyID.appearance
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'background' {
							value = PropertyID.background
							found = true
						}
						'block-size' {
							value = PropertyID.block_size
							found = true
						}
						'border-top' {
							value = PropertyID.border_top
							found = true
						}
						'box-shadow' {
							value = PropertyID.box_shadow
							found = true
						}
						'box-sizing' {
							value = PropertyID.box_sizing
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'column-gap' {
							value = PropertyID.column_gap
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'flex-basis' {
							value = PropertyID.flex_basis
							found = true
						}
						'font-style' {
							value = PropertyID.font_style
							found = true
						}
						'font-width' {
							value = PropertyID.font_width
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'line-clamp' {
							value = PropertyID.line_clamp
							found = true
						}
						'list-style' {
							value = PropertyID.list_style
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-top' {
							value = PropertyID.margin_top
							found = true
						}
						'mask-image' {
							value = PropertyID.mask_image
							found = true
						}
						'math-depth' {
							value = PropertyID.math_depth
							found = true
						}
						'math-shift' {
							value = PropertyID.math_shift
							found = true
						}
						'math-style' {
							value = PropertyID.math_style
							found = true
						}
						'max-height' {
							value = PropertyID.max_height
							found = true
						}
						'min-height' {
							value = PropertyID.min_height
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'object-fit' {
							value = PropertyID.object_fit
							found = true
						}
						'overflow-x' {
							value = PropertyID.overflow_x
							found = true
						}
						'overflow-y' {
							value = PropertyID.overflow_y
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'place-self' {
							value = PropertyID.place_self
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'stop-color' {
							value = PropertyID.stop_color
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-align' {
							value = PropertyID.text_align
							found = true
						}
						'transition' {
							value = PropertyID.transition
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'visibility' {
							value = PropertyID.visibility
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'word-break' {
							value = PropertyID.word_break
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		11 {
			match name[0] {
				0x61 {
					match name {
						'align-items' {
							value = PropertyID.align_items
							found = true
						}
						'anchor-name' {
							value = PropertyID.anchor_name
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'border-left' {
							value = PropertyID.border_left
							found = true
						}
						'break-after' {
							value = PropertyID.break_after
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'caret-color' {
							value = PropertyID.caret_color
							found = true
						}
						'column-fill' {
							value = PropertyID.column_fill
							found = true
						}
						'column-rule' {
							value = PropertyID.column_rule
							found = true
						}
						'column-span' {
							value = PropertyID.column_span
							found = true
						}
						'counter-set' {
							value = PropertyID.counter_set
							found = true
						}
						else {}
					}
				}
				0x65 {
					match name {
						'empty-cells' {
							value = PropertyID.empty_cells
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'flex-shrink' {
							value = PropertyID.flex_shrink
							found = true
						}
						'flood-color' {
							value = PropertyID.flood_color
							found = true
						}
						'font-family' {
							value = PropertyID.font_family
							found = true
						}
						'font-weight' {
							value = PropertyID.font_weight
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-column' {
							value = PropertyID.grid_column
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inline-size' {
							value = PropertyID.inline_size
							found = true
						}
						'inset-block' {
							value = PropertyID.inset_block
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'line-height' {
							value = PropertyID.line_height
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-left' {
							value = PropertyID.margin_left
							found = true
						}
						'mask-origin' {
							value = PropertyID.mask_origin
							found = true
						}
						'mask-repeat' {
							value = PropertyID.mask_repeat
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-top' {
							value = PropertyID.padding_top
							found = true
						}
						'paint-order' {
							value = PropertyID.paint_order
							found = true
						}
						'perspective' {
							value = PropertyID.perspective
							found = true
						}
						'place-items' {
							value = PropertyID.place_items
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-anchor' {
							value = PropertyID.text_anchor
							found = true
						}
						'text-indent' {
							value = PropertyID.text_indent
							found = true
						}
						'text-shadow' {
							value = PropertyID.text_shadow
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'user-select' {
							value = PropertyID.user_select
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'white-space' {
							value = PropertyID.white_space
							found = true
						}
						'will-change' {
							value = PropertyID.will_change
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		12 {
			match name[0] {
				0x61 {
					match name {
						'accent-color' {
							value = PropertyID.accent_color
							found = true
						}
						'anchor-scope' {
							value = PropertyID.anchor_scope
							found = true
						}
						'aspect-ratio' {
							value = PropertyID.aspect_ratio
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'border-block' {
							value = PropertyID.border_block
							found = true
						}
						'border-color' {
							value = PropertyID.border_color
							found = true
						}
						'border-image' {
							value = PropertyID.border_image
							found = true
						}
						'border-right' {
							value = PropertyID.border_right
							found = true
						}
						'border-style' {
							value = PropertyID.border_style
							found = true
						}
						'border-width' {
							value = PropertyID.border_width
							found = true
						}
						'break-before' {
							value = PropertyID.break_before
							found = true
						}
						'break-inside' {
							value = PropertyID.break_inside
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'caption-side' {
							value = PropertyID.caption_side
							found = true
						}
						'color-scheme' {
							value = PropertyID.color_scheme
							found = true
						}
						'column-count' {
							value = PropertyID.column_count
							found = true
						}
						'column-width' {
							value = PropertyID.column_width
							found = true
						}
						'corner-shape' {
							value = PropertyID.corner_shape
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'fill-opacity' {
							value = PropertyID.fill_opacity
							found = true
						}
						'font-kerning' {
							value = PropertyID.font_kerning
							found = true
						}
						'font-variant' {
							value = PropertyID.font_variant
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-row-end' {
							value = PropertyID.grid_row_end
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inset-inline' {
							value = PropertyID.inset_inline
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'justify-self' {
							value = PropertyID.justify_self
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-block' {
							value = PropertyID.margin_block
							found = true
						}
						'margin-right' {
							value = PropertyID.margin_right
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-left' {
							value = PropertyID.padding_left
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'shape-margin' {
							value = PropertyID.shape_margin
							found = true
						}
						'stop-opacity' {
							value = PropertyID.stop_opacity
							found = true
						}
						'stroke-width' {
							value = PropertyID.stroke_width
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'table-layout' {
							value = PropertyID.table_layout
							found = true
						}
						'text-justify' {
							value = PropertyID.text_justify
							found = true
						}
						'touch-action' {
							value = PropertyID.touch_action
							found = true
						}
						else {}
					}
				}
				0x75 {
					match name {
						'unicode-bidi' {
							value = PropertyID.unicode_bidi
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'word-spacing' {
							value = PropertyID.word_spacing
							found = true
						}
						'writing-mode' {
							value = PropertyID.writing_mode
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		13 {
			match name[0] {
				0x61 {
					match name {
						'align-content' {
							value = PropertyID.align_content
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'border-bottom' {
							value = PropertyID.border_bottom
							found = true
						}
						'border-inline' {
							value = PropertyID.border_inline
							found = true
						}
						'border-radius' {
							value = PropertyID.border_radius
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'column-height' {
							value = PropertyID.column_height
							found = true
						}
						'counter-reset' {
							value = PropertyID.counter_reset
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'flood-opacity' {
							value = PropertyID.flood_opacity
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-template' {
							value = PropertyID.grid_template
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'justify-items' {
							value = PropertyID.justify_items
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-bottom' {
							value = PropertyID.margin_bottom
							found = true
						}
						'margin-inline' {
							value = PropertyID.margin_inline
							found = true
						}
						'mask-position' {
							value = PropertyID.mask_position
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'outline-color' {
							value = PropertyID.outline_color
							found = true
						}
						'outline-style' {
							value = PropertyID.outline_style
							found = true
						}
						'outline-width' {
							value = PropertyID.outline_width
							found = true
						}
						'overflow-wrap' {
							value = PropertyID.overflow_wrap
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-block' {
							value = PropertyID.padding_block
							found = true
						}
						'padding-right' {
							value = PropertyID.padding_right
							found = true
						}
						'place-content' {
							value = PropertyID.place_content
							found = true
						}
						'position-area' {
							value = PropertyID.position_area
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin' {
							value = PropertyID.scroll_margin
							found = true
						}
						'shape-outside' {
							value = PropertyID.shape_outside
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-overflow' {
							value = PropertyID.text_overflow
							found = true
						}
						'transform-box' {
							value = PropertyID.transform_box
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'vector-effect' {
							value = PropertyID.vector_effect
							found = true
						}
						'view-timeline' {
							value = PropertyID.view_timeline
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		14 {
			match name[0] {
				0x61 {
					match name {
						'animation-name' {
							value = PropertyID.animation_name
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'block-ellipsis' {
							value = PropertyID.block_ellipsis
							found = true
						}
						'border-spacing' {
							value = PropertyID.border_spacing
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'container-name' {
							value = PropertyID.container_name
							found = true
						}
						'container-type' {
							value = PropertyID.container_type
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'flex-direction' {
							value = PropertyID.flex_direction
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-auto-flow' {
							value = PropertyID.grid_auto_flow
							found = true
						}
						'grid-auto-rows' {
							value = PropertyID.grid_auto_rows
							found = true
						}
						'grid-row-start' {
							value = PropertyID.grid_row_start
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'letter-spacing' {
							value = PropertyID.letter_spacing
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'mask-composite' {
							value = PropertyID.mask_composite
							found = true
						}
						'max-block-size' {
							value = PropertyID.max_block_size
							found = true
						}
						'min-block-size' {
							value = PropertyID.min_block_size
							found = true
						}
						'mix-blend-mode' {
							value = PropertyID.mix_blend_mode
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'outline-offset' {
							value = PropertyID.outline_offset
							found = true
						}
						'overflow-block' {
							value = PropertyID.overflow_block
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-bottom' {
							value = PropertyID.padding_bottom
							found = true
						}
						'padding-inline' {
							value = PropertyID.padding_inline
							found = true
						}
						'pointer-events' {
							value = PropertyID.pointer_events
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-padding' {
							value = PropertyID.scroll_padding
							found = true
						}
						'stroke-linecap' {
							value = PropertyID.stroke_linecap
							found = true
						}
						'stroke-opacity' {
							value = PropertyID.stroke_opacity
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-rendering' {
							value = PropertyID.text_rendering
							found = true
						}
						'text-transform' {
							value = PropertyID.text_transform
							found = true
						}
						'text-wrap-mode' {
							value = PropertyID.text_wrap_mode
							found = true
						}
						'timeline-scope' {
							value = PropertyID.timeline_scope
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'vertical-align' {
							value = PropertyID.vertical_align
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		15 {
			match name[0] {
				0x61 {
					match name {
						'animation-delay' {
							value = PropertyID.animation_delay
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'backdrop-filter' {
							value = PropertyID.backdrop_filter
							found = true
						}
						'background-clip' {
							value = PropertyID.background_clip
							found = true
						}
						'background-size' {
							value = PropertyID.background_size
							found = true
						}
						'border-collapse' {
							value = PropertyID.border_collapse
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-column-end' {
							value = PropertyID.grid_column_end
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'image-rendering' {
							value = PropertyID.image_rendering
							found = true
						}
						'inset-block-end' {
							value = PropertyID.inset_block_end
							found = true
						}
						else {}
					}
				}
				0x6a {
					match name {
						'justify-content' {
							value = PropertyID.justify_content
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'list-style-type' {
							value = PropertyID.list_style_type
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'max-inline-size' {
							value = PropertyID.max_inline_size
							found = true
						}
						'min-inline-size' {
							value = PropertyID.min_inline_size
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'object-position' {
							value = PropertyID.object_position
							found = true
						}
						'overflow-inline' {
							value = PropertyID.overflow_inline
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'position-anchor' {
							value = PropertyID.position_anchor
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-behavior' {
							value = PropertyID.scroll_behavior
							found = true
						}
						'scroll-timeline' {
							value = PropertyID.scroll_timeline
							found = true
						}
						'scrollbar-color' {
							value = PropertyID.scrollbar_color
							found = true
						}
						'scrollbar-width' {
							value = PropertyID.scrollbar_width
							found = true
						}
						'shape-rendering' {
							value = PropertyID.shape_rendering
							found = true
						}
						'stroke-linejoin' {
							value = PropertyID.stroke_linejoin
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-decoration' {
							value = PropertyID.text_decoration
							found = true
						}
						'text-wrap-style' {
							value = PropertyID.text_wrap_style
							found = true
						}
						'transform-style' {
							value = PropertyID.transform_style
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		16 {
			match name[0] {
				0x62 {
					match name {
						'background-color' {
							value = PropertyID.background_color
							found = true
						}
						'background-image' {
							value = PropertyID.background_image
							found = true
						}
						'border-block-end' {
							value = PropertyID.border_block_end
							found = true
						}
						'border-top-color' {
							value = PropertyID.border_top_color
							found = true
						}
						'border-top-style' {
							value = PropertyID.border_top_style
							found = true
						}
						'border-top-width' {
							value = PropertyID.border_top_width
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'corner-top-shape' {
							value = PropertyID.corner_top_shape
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inset-inline-end' {
							value = PropertyID.inset_inline_end
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'list-style-image' {
							value = PropertyID.list_style_image
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-block-end' {
							value = PropertyID.margin_block_end
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'page-break-after' {
							value = PropertyID.page_break_after
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-snap-stop' {
							value = PropertyID.scroll_snap_stop
							found = true
						}
						'scroll-snap-type' {
							value = PropertyID.scroll_snap_type
							found = true
						}
						'scrollbar-gutter' {
							value = PropertyID.scrollbar_gutter
							found = true
						}
						'stroke-dasharray' {
							value = PropertyID.stroke_dasharray
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'transform-origin' {
							value = PropertyID.transform_origin
							found = true
						}
						'transition-delay' {
							value = PropertyID.transition_delay
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'white-space-trim' {
							value = PropertyID.white_space_trim
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		17 {
			match name[0] {
				0x62 {
					match name {
						'background-origin' {
							value = PropertyID.background_origin
							found = true
						}
						'background-repeat' {
							value = PropertyID.background_repeat
							found = true
						}
						'border-inline-end' {
							value = PropertyID.border_inline_end
							found = true
						}
						'border-left-color' {
							value = PropertyID.border_left_color
							found = true
						}
						'border-left-style' {
							value = PropertyID.border_left_style
							found = true
						}
						'border-left-width' {
							value = PropertyID.border_left_width
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'column-rule-color' {
							value = PropertyID.column_rule_color
							found = true
						}
						'column-rule-style' {
							value = PropertyID.column_rule_style
							found = true
						}
						'column-rule-width' {
							value = PropertyID.column_rule_width
							found = true
						}
						'corner-left-shape' {
							value = PropertyID.corner_left_shape
							found = true
						}
						'counter-increment' {
							value = PropertyID.counter_increment
							found = true
						}
						else {}
					}
				}
				0x64 {
					match name {
						'dominant-baseline' {
							value = PropertyID.dominant_baseline
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'font-variant-caps' {
							value = PropertyID.font_variant_caps
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-auto-columns' {
							value = PropertyID.grid_auto_columns
							found = true
						}
						'grid-column-start' {
							value = PropertyID.grid_column_start
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inset-block-start' {
							value = PropertyID.inset_block_start
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-inline-end' {
							value = PropertyID.margin_inline_end
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-block-end' {
							value = PropertyID.padding_block_end
							found = true
						}
						'page-break-before' {
							value = PropertyID.page_break_before
							found = true
						}
						'page-break-inside' {
							value = PropertyID.page_break_inside
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-top' {
							value = PropertyID.scroll_margin_top
							found = true
						}
						'scroll-snap-align' {
							value = PropertyID.scroll_snap_align
							found = true
						}
						'stroke-dashoffset' {
							value = PropertyID.stroke_dashoffset
							found = true
						}
						'stroke-miterlimit' {
							value = PropertyID.stroke_miterlimit
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		18 {
			match name[0] {
				0x2d {
					match name {
						'-webkit-box-orient' {
							value = PropertyID.webkit_box_orient
							found = true
						}
						'-webkit-line-clamp' {
							value = PropertyID.webkit_line_clamp
							found = true
						}
						else {}
					}
				}
				0x61 {
					match name {
						'animation-duration' {
							value = PropertyID.animation_duration
							found = true
						}
						'animation-timeline' {
							value = PropertyID.animation_timeline
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'border-block-color' {
							value = PropertyID.border_block_color
							found = true
						}
						'border-block-start' {
							value = PropertyID.border_block_start
							found = true
						}
						'border-block-style' {
							value = PropertyID.border_block_style
							found = true
						}
						'border-block-width' {
							value = PropertyID.border_block_width
							found = true
						}
						'border-image-slice' {
							value = PropertyID.border_image_slice
							found = true
						}
						'border-image-width' {
							value = PropertyID.border_image_width
							found = true
						}
						'border-right-color' {
							value = PropertyID.border_right_color
							found = true
						}
						'border-right-style' {
							value = PropertyID.border_right_style
							found = true
						}
						'border-right-width' {
							value = PropertyID.border_right_width
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'content-visibility' {
							value = PropertyID.content_visibility
							found = true
						}
						'corner-right-shape' {
							value = PropertyID.corner_right_shape
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'font-variant-emoji' {
							value = PropertyID.font_variant_emoji
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-template-rows' {
							value = PropertyID.grid_template_rows
							found = true
						}
						else {}
					}
				}
				0x69 {
					match name {
						'inset-inline-start' {
							value = PropertyID.inset_inline_start
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-block-start' {
							value = PropertyID.margin_block_start
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-inline-end' {
							value = PropertyID.padding_inline_end
							found = true
						}
						'perspective-origin' {
							value = PropertyID.perspective_origin
							found = true
						}
						'position-try-order' {
							value = PropertyID.position_try_order
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-left' {
							value = PropertyID.scroll_margin_left
							found = true
						}
						'scroll-padding-top' {
							value = PropertyID.scroll_padding_top
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'view-timeline-axis' {
							value = PropertyID.view_timeline_axis
							found = true
						}
						'view-timeline-name' {
							value = PropertyID.view_timeline_name
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		19 {
			match name[0] {
				0x61 {
					match name {
						'animation-direction' {
							value = PropertyID.animation_direction
							found = true
						}
						'animation-fill-mode' {
							value = PropertyID.animation_fill_mode
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'backface-visibility' {
							value = PropertyID.backface_visibility
							found = true
						}
						'background-position' {
							value = PropertyID.background_position
							found = true
						}
						'border-bottom-color' {
							value = PropertyID.border_bottom_color
							found = true
						}
						'border-bottom-style' {
							value = PropertyID.border_bottom_style
							found = true
						}
						'border-bottom-width' {
							value = PropertyID.border_bottom_width
							found = true
						}
						'border-image-outset' {
							value = PropertyID.border_image_outset
							found = true
						}
						'border-image-repeat' {
							value = PropertyID.border_image_repeat
							found = true
						}
						'border-image-source' {
							value = PropertyID.border_image_source
							found = true
						}
						'border-inline-color' {
							value = PropertyID.border_inline_color
							found = true
						}
						'border-inline-start' {
							value = PropertyID.border_inline_start
							found = true
						}
						'border-inline-style' {
							value = PropertyID.border_inline_style
							found = true
						}
						'border-inline-width' {
							value = PropertyID.border_inline_width
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'color-interpolation' {
							value = PropertyID.color_interpolation
							found = true
						}
						'corner-bottom-shape' {
							value = PropertyID.corner_bottom_shape
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'font-optical-sizing' {
							value = PropertyID.font_optical_sizing
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-template-areas' {
							value = PropertyID.grid_template_areas
							found = true
						}
						else {}
					}
				}
				0x6c {
					match name {
						'list-style-position' {
							value = PropertyID.list_style_position
							found = true
						}
						else {}
					}
				}
				0x6d {
					match name {
						'margin-inline-start' {
							value = PropertyID.margin_inline_start
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-block-start' {
							value = PropertyID.padding_block_start
							found = true
						}
						'position-visibility' {
							value = PropertyID.position_visibility
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-block' {
							value = PropertyID.scroll_margin_block
							found = true
						}
						'scroll-margin-right' {
							value = PropertyID.scroll_margin_right
							found = true
						}
						'scroll-padding-left' {
							value = PropertyID.scroll_padding_left
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'transition-behavior' {
							value = PropertyID.transition_behavior
							found = true
						}
						'transition-duration' {
							value = PropertyID.transition_duration
							found = true
						}
						'transition-property' {
							value = PropertyID.transition_property
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'view-timeline-inset' {
							value = PropertyID.view_timeline_inset
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		20 {
			match name[0] {
				0x61 {
					match name {
						'animation-play-state' {
							value = PropertyID.animation_play_state
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'box-decoration-break' {
							value = PropertyID.box_decoration_break
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'corner-end-end-shape' {
							value = PropertyID.corner_end_end_shape
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'font-variant-numeric' {
							value = PropertyID.font_variant_numeric
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'overflow-clip-margin' {
							value = PropertyID.overflow_clip_margin
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'padding-inline-start' {
							value = PropertyID.padding_inline_start
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-bottom' {
							value = PropertyID.scroll_margin_bottom
							found = true
						}
						'scroll-margin-inline' {
							value = PropertyID.scroll_margin_inline
							found = true
						}
						'scroll-padding-block' {
							value = PropertyID.scroll_padding_block
							found = true
						}
						'scroll-padding-right' {
							value = PropertyID.scroll_padding_right
							found = true
						}
						'scroll-timeline-axis' {
							value = PropertyID.scroll_timeline_axis
							found = true
						}
						'scroll-timeline-name' {
							value = PropertyID.scroll_timeline_name
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-decoration-line' {
							value = PropertyID.text_decoration_line
							found = true
						}
						else {}
					}
				}
				0x76 {
					match name {
						'view-transition-name' {
							value = PropertyID.view_transition_name
							found = true
						}
						else {}
					}
				}
				0x77 {
					match name {
						'white-space-collapse' {
							value = PropertyID.white_space_collapse
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		21 {
			match name[0] {
				0x61 {
					match name {
						'animation-composition' {
							value = PropertyID.animation_composition
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'background-attachment' {
							value = PropertyID.background_attachment
							found = true
						}
						'background-blend-mode' {
							value = PropertyID.background_blend_mode
							found = true
						}
						'background-position-x' {
							value = PropertyID.background_position_x
							found = true
						}
						'background-position-y' {
							value = PropertyID.background_position_y
							found = true
						}
						'border-end-end-radius' {
							value = PropertyID.border_end_end_radius
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'corner-top-left-shape' {
							value = PropertyID.corner_top_left_shape
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'font-feature-settings' {
							value = PropertyID.font_feature_settings
							found = true
						}
						'font-variant-position' {
							value = PropertyID.font_variant_position
							found = true
						}
						else {}
					}
				}
				0x67 {
					match name {
						'grid-template-columns' {
							value = PropertyID.grid_template_columns
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-padding-bottom' {
							value = PropertyID.scroll_padding_bottom
							found = true
						}
						'scroll-padding-inline' {
							value = PropertyID.scroll_padding_inline
							found = true
						}
						'shape-image-threshold' {
							value = PropertyID.shape_image_threshold
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-decoration-color' {
							value = PropertyID.text_decoration_color
							found = true
						}
						'text-decoration-style' {
							value = PropertyID.text_decoration_style
							found = true
						}
						'text-underline-offset' {
							value = PropertyID.text_underline_offset
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		22 {
			match name[0] {
				0x2d {
					match name {
						'-webkit-font-smoothing' {
							value = PropertyID.webkit_font_smoothing
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'border-block-end-color' {
							value = PropertyID.border_block_end_color
							found = true
						}
						'border-block-end-style' {
							value = PropertyID.border_block_end_style
							found = true
						}
						'border-block-end-width' {
							value = PropertyID.border_block_end_width
							found = true
						}
						'border-top-left-radius' {
							value = PropertyID.border_top_left_radius
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'contain-intrinsic-size' {
							value = PropertyID.contain_intrinsic_size
							found = true
						}
						'corner-block-end-shape' {
							value = PropertyID.corner_block_end_shape
							found = true
						}
						'corner-end-start-shape' {
							value = PropertyID.corner_end_start_shape
							found = true
						}
						'corner-start-end-shape' {
							value = PropertyID.corner_start_end_shape
							found = true
						}
						'corner-top-right-shape' {
							value = PropertyID.corner_top_right_shape
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'font-language-override' {
							value = PropertyID.font_language_override
							found = true
						}
						'font-variant-ligatures' {
							value = PropertyID.font_variant_ligatures
							found = true
						}
						else {}
					}
				}
				0x70 {
					match name {
						'position-try-fallbacks' {
							value = PropertyID.position_try_fallbacks
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		23 {
			match name[0] {
				0x2d {
					match name {
						'-webkit-text-fill-color' {
							value = PropertyID.webkit_text_fill_color
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'border-end-start-radius' {
							value = PropertyID.border_end_start_radius
							found = true
						}
						'border-inline-end-color' {
							value = PropertyID.border_inline_end_color
							found = true
						}
						'border-inline-end-style' {
							value = PropertyID.border_inline_end_style
							found = true
						}
						'border-inline-end-width' {
							value = PropertyID.border_inline_end_width
							found = true
						}
						'border-start-end-radius' {
							value = PropertyID.border_start_end_radius
							found = true
						}
						'border-top-right-radius' {
							value = PropertyID.border_top_right_radius
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'contain-intrinsic-width' {
							value = PropertyID.contain_intrinsic_width
							found = true
						}
						'corner-inline-end-shape' {
							value = PropertyID.corner_inline_end_shape
							found = true
						}
						else {}
					}
				}
				0x66 {
					match name {
						'font-variant-alternates' {
							value = PropertyID.font_variant_alternates
							found = true
						}
						'font-variant-east-asian' {
							value = PropertyID.font_variant_east_asian
							found = true
						}
						'font-variation-settings' {
							value = PropertyID.font_variation_settings
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-block-end' {
							value = PropertyID.scroll_margin_block_end
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-underline-position' {
							value = PropertyID.text_underline_position
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		24 {
			match name[0] {
				0x62 {
					match name {
						'border-block-start-color' {
							value = PropertyID.border_block_start_color
							found = true
						}
						'border-block-start-style' {
							value = PropertyID.border_block_start_style
							found = true
						}
						'border-block-start-width' {
							value = PropertyID.border_block_start_width
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'contain-intrinsic-height' {
							value = PropertyID.contain_intrinsic_height
							found = true
						}
						'corner-block-start-shape' {
							value = PropertyID.corner_block_start_shape
							found = true
						}
						'corner-bottom-left-shape' {
							value = PropertyID.corner_bottom_left_shape
							found = true
						}
						'corner-start-start-shape' {
							value = PropertyID.corner_start_start_shape
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'overflow-clip-margin-top' {
							value = PropertyID.overflow_clip_margin_top
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-inline-end' {
							value = PropertyID.scroll_margin_inline_end
							found = true
						}
						'scroll-padding-block-end' {
							value = PropertyID.scroll_padding_block_end
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-decoration-skip-ink' {
							value = PropertyID.text_decoration_skip_ink
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		25 {
			match name[0] {
				0x61 {
					match name {
						'animation-iteration-count' {
							value = PropertyID.animation_iteration_count
							found = true
						}
						'animation-timing-function' {
							value = PropertyID.animation_timing_function
							found = true
						}
						else {}
					}
				}
				0x62 {
					match name {
						'border-bottom-left-radius' {
							value = PropertyID.border_bottom_left_radius
							found = true
						}
						'border-inline-start-color' {
							value = PropertyID.border_inline_start_color
							found = true
						}
						'border-inline-start-style' {
							value = PropertyID.border_inline_start_style
							found = true
						}
						'border-inline-start-width' {
							value = PropertyID.border_inline_start_width
							found = true
						}
						'border-start-start-radius' {
							value = PropertyID.border_start_start_radius
							found = true
						}
						else {}
					}
				}
				0x63 {
					match name {
						'corner-bottom-right-shape' {
							value = PropertyID.corner_bottom_right_shape
							found = true
						}
						'corner-inline-start-shape' {
							value = PropertyID.corner_inline_start_shape
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'overflow-clip-margin-left' {
							value = PropertyID.overflow_clip_margin_left
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-block-start' {
							value = PropertyID.scroll_margin_block_start
							found = true
						}
						'scroll-padding-inline-end' {
							value = PropertyID.scroll_padding_inline_end
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'text-decoration-thickness' {
							value = PropertyID.text_decoration_thickness
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		26 {
			match name[0] {
				0x62 {
					match name {
						'border-bottom-right-radius' {
							value = PropertyID.border_bottom_right_radius
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'overflow-clip-margin-block' {
							value = PropertyID.overflow_clip_margin_block
							found = true
						}
						'overflow-clip-margin-right' {
							value = PropertyID.overflow_clip_margin_right
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-margin-inline-start' {
							value = PropertyID.scroll_margin_inline_start
							found = true
						}
						'scroll-padding-block-start' {
							value = PropertyID.scroll_padding_block_start
							found = true
						}
						else {}
					}
				}
				0x74 {
					match name {
						'transition-timing-function' {
							value = PropertyID.transition_timing_function
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		27 {
			match name[0] {
				0x63 {
					match name {
						'color-interpolation-filters' {
							value = PropertyID.color_interpolation_filters
							found = true
						}
						else {}
					}
				}
				0x6f {
					match name {
						'overflow-clip-margin-bottom' {
							value = PropertyID.overflow_clip_margin_bottom
							found = true
						}
						'overflow-clip-margin-inline' {
							value = PropertyID.overflow_clip_margin_inline
							found = true
						}
						else {}
					}
				}
				0x73 {
					match name {
						'scroll-padding-inline-start' {
							value = PropertyID.scroll_padding_inline_start
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		28 {
			match name[0] {
				0x63 {
					match name {
						'contain-intrinsic-block-size' {
							value = PropertyID.contain_intrinsic_block_size
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		29 {
			match name[0] {
				0x63 {
					match name {
						'contain-intrinsic-inline-size' {
							value = PropertyID.contain_intrinsic_inline_size
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		30 {
			match name[0] {
				0x6f {
					match name {
						'overflow-clip-margin-block-end' {
							value = PropertyID.overflow_clip_margin_block_end
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		31 {
			match name[0] {
				0x6f {
					match name {
						'overflow-clip-margin-inline-end' {
							value = PropertyID.overflow_clip_margin_inline_end
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		32 {
			match name[0] {
				0x6f {
					match name {
						'overflow-clip-margin-block-start' {
							value = PropertyID.overflow_clip_margin_block_start
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		33 {
			match name[0] {
				0x6f {
					match name {
						'overflow-clip-margin-inline-start' {
							value = PropertyID.overflow_clip_margin_inline_start
							found = true
						}
						else {}
					}
				}
				else {}
			}
		}
		else {}
	}
	if !found { return none }
	return value
}

pub fn string_from_property_id(property_id PropertyID) string {
	return match property_id {
		.grid_lanes_direction { 'grid-lanes-direction' }
		.fit_tolerance { 'fit-tolerance' }

		.overscroll_behavior_x { 'overscroll-behavior-x' }
		.overscroll_behavior_y { 'overscroll-behavior-y' }
		.overscroll_behavior_inline { 'overscroll-behavior-inline' }
		.overscroll_behavior_block { 'overscroll-behavior-block' }
		.overscroll_behavior { 'overscroll-behavior' }

		.alignment_baseline { 'alignment-baseline' }
		.baseline_shift { 'baseline-shift' }
		.baseline_source { 'baseline-source' }

		.border_shape { 'border-shape' }
		.text_orientation { 'text-orientation' }
		.forced_color_adjust { 'forced-color-adjust' }
		.font_palette { 'font-palette' }
		.font_size_adjust { 'font-size-adjust' }
		.animation_range { 'animation-range' }
		.animation_range_start { 'animation-range-start' }
		.animation_range_end { 'animation-range-end' }
		.text_box_trim { 'text-box-trim' }
		.text_box_edge { 'text-box-edge' }
		.font_synthesis { 'font-synthesis' }
		.font_synthesis_weight { 'font-synthesis-weight' }
		.font_synthesis_style { 'font-synthesis-style' }
		.font_synthesis_small_caps { 'font-synthesis-small-caps' }
		.font_synthesis_position { 'font-synthesis-position' }
		.hyphens { 'hyphens' }
		.webkit_box_orient { '-webkit-box-orient' }
		.webkit_font_smoothing { '-webkit-font-smoothing' }
		.webkit_line_clamp { '-webkit-line-clamp' }
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
		.block_ellipsis { 'block-ellipsis' }
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
		.box_decoration_break { 'box-decoration-break' }
		.box_shadow { 'box-shadow' }
		.box_sizing { 'box-sizing' }
		.backface_visibility { 'backface-visibility' }
		.break_after { 'break-after' }
		.break_before { 'break-before' }
		.break_inside { 'break-inside' }
		.caption_side { 'caption-side' }
		.caret_color { 'caret-color' }
		.clear { 'clear' }
		.clip { 'clip' }
		.clip_path { 'clip-path' }
		.clip_rule { 'clip-rule' }
		.color { 'color' }
		.color_interpolation { 'color-interpolation' }
		.color_interpolation_filters { 'color-interpolation-filters' }
		.color_scheme { 'color-scheme' }
		.column_count { 'column-count' }
		.column_fill { 'column-fill' }
		.column_gap { 'column-gap' }
		.column_height { 'column-height' }
		.column_rule { 'column-rule' }
		.column_rule_color { 'column-rule-color' }
		.column_rule_style { 'column-rule-style' }
		.column_rule_width { 'column-rule-width' }
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
		.continue_ { 'continue' }
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
		.line_clamp { 'line-clamp' }
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
		.max_lines { 'max-lines' }
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
		.page_break_after { 'page-break-after' }
		.page_break_before { 'page-break-before' }
		.page_break_inside { 'page-break-inside' }
		.paint_order { 'paint-order' }
		.perspective { 'perspective' }
		.perspective_origin { 'perspective-origin' }
		.place_content { 'place-content' }
		.place_items { 'place-items' }
		.place_self { 'place-self' }
		.position_try { 'position-try' }
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
		.scroll_margin { 'scroll-margin' }
		.scroll_margin_block { 'scroll-margin-block' }
		.scroll_margin_block_end { 'scroll-margin-block-end' }
		.scroll_margin_block_start { 'scroll-margin-block-start' }
		.scroll_margin_bottom { 'scroll-margin-bottom' }
		.scroll_margin_inline { 'scroll-margin-inline' }
		.scroll_margin_inline_end { 'scroll-margin-inline-end' }
		.scroll_margin_inline_start { 'scroll-margin-inline-start' }
		.scroll_margin_left { 'scroll-margin-left' }
		.scroll_margin_right { 'scroll-margin-right' }
		.scroll_margin_top { 'scroll-margin-top' }
		.scroll_padding { 'scroll-padding' }
		.scroll_padding_block { 'scroll-padding-block' }
		.scroll_padding_block_end { 'scroll-padding-block-end' }
		.scroll_padding_block_start { 'scroll-padding-block-start' }
		.scroll_padding_bottom { 'scroll-padding-bottom' }
		.scroll_padding_inline { 'scroll-padding-inline' }
		.scroll_padding_inline_end { 'scroll-padding-inline-end' }
		.scroll_padding_inline_start { 'scroll-padding-inline-start' }
		.scroll_padding_left { 'scroll-padding-left' }
		.scroll_padding_right { 'scroll-padding-right' }
		.scroll_padding_top { 'scroll-padding-top' }
		.scroll_snap_align { 'scroll-snap-align' }
		.scroll_snap_stop { 'scroll-snap-stop' }
		.scroll_snap_type { 'scroll-snap-type' }
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
				.background_color, .border_bottom_color, .border_color, .border_left_color, .border_right_color, .border_top_color, .color {
					true
				}
				else { false }
			}
		}
		.unitless_length {
			match property_id {
				.background_position, .border_bottom_width, .border_left_width, .border_right_width, .border_spacing, .border_top_width, .border_width, .bottom, .clip, .cx, .cy, .font_size, .height, .left, .letter_spacing, .margin, .margin_bottom, .margin_left, .margin_right, .margin_top, .max_height, .max_width, .min_height, .min_width, .padding, .padding_bottom, .padding_left, .padding_right, .padding_top, .r, .right, .rx, .ry, .text_indent, .top, .vertical_align, .width, .word_spacing, .x, .y {
					true
				}
				else { false }
			}
		}
	}
}

pub fn is_inherited_property(property_id PropertyID) bool {
	return match property_id {
		.text_orientation { true }
		.forced_color_adjust { true }
		.font_palette { true }
		.font_size_adjust { true }
		.text_box_edge { true }
		.font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position { true }
		.hyphens { true }
		.block_ellipsis { true }
		.webkit_font_smoothing, .webkit_text_fill_color, .accent_color, .border_collapse, .border_spacing, .caption_side, .caret_color, .clip_rule, .color, .color_interpolation, .color_interpolation_filters, .color_scheme, .cursor, .direction, .dominant_baseline, .empty_cells, .fill, .fill_opacity, .fill_rule, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_size, .font_style, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight, .font_width, .image_rendering, .letter_spacing, .line_height, .list_style_image, .list_style_position, .list_style_type, .math_depth, .math_shift, .math_style, .orphans, .overflow_wrap, .paint_order, .pointer_events, .quotes, .scrollbar_color, .shape_rendering, .stroke, .stroke_dasharray, .stroke_dashoffset, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .text_align, .text_anchor, .text_decoration_line, .text_decoration_skip_ink, .text_indent, .text_justify, .text_rendering, .text_shadow, .text_transform, .text_underline_offset, .text_underline_position, .text_wrap_mode, .text_wrap_style, .visibility, .white_space_collapse, .widows, .word_break, .word_spacing, .writing_mode {
			true
		}
		else { false }
	}
}

pub fn property_initial_value_string(property_id PropertyID) string {
	return match property_id {
		.grid_lanes_direction, .fit_tolerance { 'normal' }

		.overscroll_behavior_x, .overscroll_behavior_y, .overscroll_behavior_inline, .overscroll_behavior_block, .overscroll_behavior { 'auto' }

		.alignment_baseline { 'baseline' }
		.baseline_shift { '0px' }
		.baseline_source { 'auto' }

		.border_shape { 'none' }
		.text_orientation { 'mixed' }
		.forced_color_adjust { 'auto' }
		.font_palette { 'normal' }
		.font_size_adjust { 'none' }
		.animation_range { 'normal' }
		.animation_range_start { 'normal' }
		.animation_range_end { 'normal' }
		.text_box_trim { 'none' }
		.text_box_edge { 'auto' }
		.font_synthesis { 'weight style small-caps position' }
		.font_synthesis_weight { 'auto' }
		.font_synthesis_style { 'auto' }
		.font_synthesis_small_caps { 'auto' }
		.font_synthesis_position { 'auto' }
		.hyphens { 'manual' }
		.webkit_box_orient { 'horizontal' }
		.webkit_font_smoothing { 'auto' }
		.webkit_line_clamp { 'none' }
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
		.block_ellipsis { 'no-ellipsis' }
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
		.box_decoration_break { 'slice' }
		.box_shadow { 'none' }
		.box_sizing { 'content-box' }
		.backface_visibility { 'visible' }
		.break_after { 'auto' }
		.break_before { 'auto' }
		.break_inside { 'auto' }
		.caption_side { 'top' }
		.caret_color { 'auto' }
		.clear { 'none' }
		.clip { 'auto' }
		.clip_path { 'none' }
		.clip_rule { 'nonzero' }
		.color { 'canvastext' }
		.color_interpolation { 'srgb' }
		.color_interpolation_filters { 'linearrgb' }
		.color_scheme { 'normal' }
		.column_count { 'auto' }
		.column_fill { 'balance' }
		.column_gap { 'normal' }
		.column_height { 'auto' }
		.column_rule { 'medium none currentColor' }
		.column_rule_color { 'currentColor' }
		.column_rule_style { 'none' }
		.column_rule_width { 'medium' }
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
		.continue_ { 'auto' }
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
		.line_clamp { 'none' }
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
		.max_lines { 'none' }
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
		.page_break_after { 'auto' }
		.page_break_before { 'auto' }
		.page_break_inside { 'auto' }
		.paint_order { 'normal' }
		.perspective { 'none' }
		.perspective_origin { '50% 50%' }
		.place_content { 'normal' }
		.place_items { 'normal' }
		.place_self { 'normal' }
		.position_try { 'normal none' }
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
		.scroll_margin, .scroll_margin_block, .scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			'0'
		}
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			'auto'
		}
		.scroll_snap_align { 'none' }
		.scroll_snap_stop { 'normal' }
		.scroll_snap_type { 'none' }
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
		.grid_lanes_direction { AnimationType.discrete }
		.fit_tolerance { AnimationType.by_computed_value }

		.overscroll_behavior_x, .overscroll_behavior_y, .overscroll_behavior_inline, .overscroll_behavior_block { AnimationType.discrete }

		.alignment_baseline, .baseline_source { AnimationType.discrete }
		.baseline_shift { AnimationType.by_computed_value }

		.border_shape {
			AnimationType.by_computed_value
		}
		.text_orientation {
			AnimationType.discrete
		}
		.forced_color_adjust {
			AnimationType.discrete
		}
		.font_palette {
			AnimationType.by_computed_value
		}
		.font_size_adjust {
			AnimationType.by_computed_value
		}
		.animation_range_start, .animation_range_end {
			AnimationType.none_
		}
		.text_box_trim, .text_box_edge {
			AnimationType.discrete
		}
		.font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position {
			AnimationType.discrete
		}
		.hyphens { AnimationType.discrete }
		.backface_visibility { AnimationType.discrete }
		.scroll_snap_align, .scroll_snap_stop, .scroll_snap_type { AnimationType.discrete }
		.scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			AnimationType.by_computed_value
		}
		.scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			AnimationType.by_computed_value
		}
		.block_ellipsis, .continue_, .webkit_box_orient { AnimationType.discrete }
		.max_lines { AnimationType.by_computed_value }
		.box_decoration_break, .column_fill { AnimationType.discrete }
		.break_after, .break_before, .break_inside { AnimationType.discrete }
		.column_rule_color, .column_rule_width { AnimationType.by_computed_value }
		.column_rule_style { AnimationType.discrete }
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_width {
			AnimationType.by_computed_value
		}
		.webkit_text_fill_color, .accent_color, .aspect_ratio, .background_color, .block_size, .border_block_end_color, .border_block_end_width, .border_block_start_color, .border_block_start_width, .border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_width, .border_end_end_radius, .border_end_start_radius, .border_image_outset, .border_image_slice, .border_image_width, .border_inline_end_color, .border_inline_end_width, .border_inline_start_color, .border_inline_start_width, .border_left_color, .border_left_width, .border_right_color, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_top_color, .border_top_left_radius, .border_top_right_radius, .border_top_width, .bottom, .caret_color, .clip, .clip_path, .color, .column_count, .column_gap, .column_height, .column_width, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .counter_increment, .counter_reset, .counter_set, .cx, .cy, .fill, .fill_opacity, .flex_basis, .flex_grow, .flex_shrink, .flood_color, .flood_opacity, .font_size, .font_weight, .font_width, .grid_auto_columns, .grid_auto_rows, .height, .inline_size, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .line_height, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .opacity, .order, .orphans, .outline_color, .outline_offset, .outline_style, .outline_width, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective, .perspective_origin, .r, .right, .row_gap, .rx, .ry, .scrollbar_color, .scrollbar_width, .shape_image_threshold, .shape_margin, .shape_outside, .stop_color, .stop_opacity, .stroke, .stroke_dashoffset, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .text_decoration_color, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform_origin, .vertical_align, .widows, .width, .word_spacing, .x, .y, .z_index {
			AnimationType.by_computed_value
		}
		.webkit_font_smoothing, .align_content, .align_items, .align_self, .anchor_name, .anchor_scope, .appearance, .background_attachment, .background_blend_mode, .background_image, .background_repeat, .border_block_end_style, .border_block_start_style, .border_bottom_style, .border_collapse, .border_image_repeat, .border_image_source, .border_inline_end_style, .border_inline_start_style, .border_left_style, .border_right_style, .border_top_style, .box_sizing, .caption_side, .clear, .clip_rule, .color_interpolation, .color_interpolation_filters, .color_scheme, .column_span, .content, .cursor, .dominant_baseline, .empty_cells, .fill_rule, .flex_direction, .flex_wrap, .float_, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .grid_auto_flow, .grid_column_end, .grid_column_start, .grid_row_end, .grid_row_start, .grid_template_areas, .image_rendering, .isolation, .justify_content, .justify_items, .justify_self, .list_style_image, .list_style_position, .list_style_type, .mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_repeat, .mask_type, .mix_blend_mode, .object_fit, .overflow_block, .overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .paint_order, .pointer_events, .position, .position_anchor, .position_area, .position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .scrollbar_gutter, .shape_rendering, .stroke_linecap, .stroke_linejoin, .table_layout, .text_align, .text_anchor, .text_decoration_line, .text_decoration_style, .text_justify, .text_overflow, .text_rendering, .text_transform, .text_underline_position, .text_wrap_mode, .text_wrap_style, .touch_action, .transform_box, .transform_style, .user_select, .vector_effect, .view_transition_name, .white_space_collapse, .white_space_trim, .word_break {
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
		.grid_lanes_direction, .fit_tolerance { true }

		.overscroll_behavior_x, .overscroll_behavior_y, .overscroll_behavior_inline, .overscroll_behavior_block, .overscroll_behavior { true }

		.alignment_baseline, .baseline_shift, .baseline_source { true }

		.border_shape { true }
		.text_orientation { true }
		.forced_color_adjust { true }
		.font_palette { true }
		.font_size_adjust { true }
		.text_box_trim, .text_box_edge { true }
		.font_synthesis, .font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position { true }
		.hyphens { true }
		.backface_visibility { true }
		.scroll_snap_align, .scroll_snap_stop, .scroll_snap_type { true }
		.color_interpolation_filters { true }
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			true
		}
		.scroll_margin, .scroll_margin_block, .scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			true
		}
		.block_ellipsis, .continue_, .line_clamp, .max_lines, .webkit_box_orient, .webkit_line_clamp {
			true
		}
		.box_decoration_break, .column_fill { true }
		.break_after, .break_before, .break_inside { true }
		.column_rule, .column_rule_color, .column_rule_style, .column_rule_width { true }
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_width {
			true
		}
		.text_decoration_skip_ink { true }
		.d { true }
		.vector_effect { true }
		.webkit_font_smoothing, .webkit_text_fill_color, .accent_color, .align_content, .align_items, .align_self, .all, .anchor_name, .anchor_scope, .appearance, .aspect_ratio, .backdrop_filter, .background, .background_attachment, .background_blend_mode, .background_clip, .background_color, .background_image, .background_origin, .background_position, .background_position_x, .background_position_y, .background_repeat, .background_size, .block_size, .border, .border_block, .border_block_color, .border_block_end, .border_block_end_color, .border_block_end_style, .border_block_end_width, .border_block_start, .border_block_start_color, .border_block_start_style, .border_block_start_width, .border_block_style, .border_block_width, .border_bottom, .border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_style, .border_bottom_width, .border_collapse, .border_color, .border_end_end_radius, .border_end_start_radius, .border_image, .border_image_outset, .border_image_repeat, .border_image_slice, .border_image_source, .border_image_width, .border_inline, .border_inline_color, .border_inline_end, .border_inline_end_color, .border_inline_end_style, .border_inline_end_width, .border_inline_start, .border_inline_start_color, .border_inline_start_style, .border_inline_start_width, .border_inline_style, .border_inline_width, .border_left, .border_left_color, .border_left_style, .border_left_width, .border_radius, .border_right, .border_right_color, .border_right_style, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_style, .border_top, .border_top_color, .border_top_left_radius, .border_top_right_radius, .border_top_style, .border_top_width, .border_width, .bottom, .box_shadow, .box_sizing, .caption_side, .caret_color, .clear, .clip, .clip_path, .clip_rule, .color, .color_interpolation, .color_scheme, .column_count, .column_gap, .column_height, .column_span, .column_width, .columns, .content, .content_visibility, .corner_block_end_shape, .corner_block_start_shape, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_bottom_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_inline_end_shape, .corner_inline_start_shape, .corner_left_shape, .corner_right_shape, .corner_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .corner_top_shape, .counter_increment, .counter_reset, .counter_set, .cursor, .cx, .cy, .display, .dominant_baseline, .empty_cells, .fill, .fill_opacity, .fill_rule, .filter, .flex, .flex_basis, .flex_direction, .flex_flow, .flex_grow, .flex_shrink, .flex_wrap, .float_, .flood_color, .flood_opacity, .font, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_size, .font_style, .font_variant, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight, .font_width, .gap, .grid, .grid_area, .grid_auto_columns, .grid_auto_flow, .grid_auto_rows, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start, .grid_template, .grid_template_areas, .grid_template_columns, .grid_template_rows, .height, .image_rendering, .inline_size, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .isolation, .justify_content, .justify_items, .justify_self, .left, .letter_spacing, .line_height, .list_style, .list_style_image, .list_style_position, .list_style_type, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .mask, .mask_clip, .mask_composite, .mask_image, .mask_mode, .mask_origin, .mask_position, .mask_repeat, .mask_size, .mask_type, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .mix_blend_mode, .object_fit, .object_position, .opacity, .order, .orphans, .outline, .outline_color, .outline_offset, .outline_style, .outline_width, .overflow, .overflow_block, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .paint_order, .perspective, .perspective_origin, .place_content, .place_items, .place_self, .pointer_events, .position, .position_anchor, .position_area, .position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .r, .right, .rotate, .row_gap, .rx, .ry, .scale, .scrollbar_color, .scrollbar_gutter, .scrollbar_width, .shape_image_threshold, .shape_margin, .shape_outside, .shape_rendering, .stop_color, .stop_opacity, .stroke, .stroke_dasharray, .stroke_dashoffset, .stroke_linecap, .stroke_linejoin, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .table_layout, .text_align, .text_anchor, .text_decoration, .text_decoration_color, .text_decoration_line, .text_decoration_style, .text_decoration_thickness, .text_indent, .text_justify, .text_overflow, .text_rendering, .text_shadow, .text_transform, .text_underline_offset, .text_underline_position, .text_wrap, .text_wrap_mode, .text_wrap_style, .top, .touch_action, .transform, .transform_box, .transform_origin, .transform_style, .translate, .user_select, .vertical_align, .view_transition_name, .visibility, .white_space, .white_space_collapse, .white_space_trim, .widows, .width, .word_break, .word_spacing, .x, .y, .z_index {
			true
		}
		else { false }
	}
}

pub fn property_multiplicity(property_id PropertyID) PropertyMultiplicity {
	return match property_id {
		.animation_range, .animation_range_start, .animation_range_end {
			PropertyMultiplicity.coordinating_list
		}
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
		.grid_lanes_direction, .fit_tolerance { true }

		.alignment_baseline, .baseline_shift, .baseline_source { true }

		.text_orientation { true }
		.font_size_adjust { true }
		// SVG path data changes the path bounds stored in layout UsedValues.
		.d { true }
		.text_box_trim, .text_box_edge { true }
		.font_synthesis, .font_synthesis_weight, .font_synthesis_style, .font_synthesis_small_caps, .font_synthesis_position { true }
		.hyphens { true }
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			true
		}
		.scroll_margin, .scroll_margin_block, .scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			true
		}
		.block_ellipsis, .continue_, .line_clamp, .max_lines, .webkit_box_orient, .webkit_line_clamp {
			true
		}
		.box_decoration_break, .column_fill { true }
		.break_after, .break_before, .break_inside { true }
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_size, .contain_intrinsic_width {
			true
		}
		.container { true }
		.align_content, .align_items, .align_self, .all, .anchor_name, .appearance, .aspect_ratio, .block_size, .border, .border_block, .border_block_end, .border_block_end_style, .border_block_end_width, .border_block_start, .border_block_start_style, .border_block_start_width, .border_block_style, .border_block_width, .border_bottom, .border_bottom_style, .border_bottom_width, .border_collapse, .border_image, .border_inline, .border_inline_end, .border_inline_end_style, .border_inline_end_width, .border_inline_start, .border_inline_start_style, .border_inline_start_width, .border_inline_style, .border_inline_width, .border_left, .border_left_style, .border_left_width, .border_right, .border_right_style, .border_right_width, .border_spacing, .border_style, .border_top, .border_top_style, .border_top_width, .border_width, .bottom, .box_sizing, .caption_side, .clear, .column_count, .column_gap, .column_height, .column_span, .column_width, .columns, .contain, .container_type, .content, .content_visibility, .corner_block_end_shape, .corner_block_start_shape, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_bottom_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_inline_end_shape, .corner_inline_start_shape, .corner_left_shape, .corner_right_shape, .corner_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .corner_top_shape, .counter_increment, .counter_reset, .counter_set, .cx, .cy, .direction, .display, .dominant_baseline, .empty_cells, .flex, .flex_basis, .flex_direction, .flex_flow, .flex_grow, .flex_shrink, .flex_wrap, .float_, .font, .font_family, .font_feature_settings, .font_kerning, .font_language_override, .font_optical_sizing, .font_size, .font_style, .font_variant, .font_variant_alternates, .font_variant_caps, .font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric, .font_variant_position, .font_variation_settings, .font_weight, .font_width, .gap, .grid, .grid_area, .grid_auto_columns, .grid_auto_flow, .grid_auto_rows, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start, .grid_template, .grid_template_areas, .grid_template_columns, .grid_template_rows, .height, .inline_size, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .isolation, .justify_content, .justify_items, .justify_self, .left, .letter_spacing, .line_height, .list_style, .list_style_image, .list_style_position, .list_style_type, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .math_depth, .math_shift, .math_style, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .order, .orphans, .overflow, .overflow_block, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .overflow_inline, .overflow_wrap, .overflow_x, .overflow_y, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .paint_order, .perspective, .place_content, .place_items, .place_self, .position, .position_anchor, .position_area, .position_try_fallbacks, .position_try_order, .position_visibility, .quotes, .r, .right, .row_gap, .rx, .ry, .shape_margin, .shape_outside, .shape_rendering, .tab_size, .table_layout, .text_align, .text_anchor, .text_indent, .text_justify, .text_transform, .text_underline_offset, .text_underline_position, .text_wrap, .text_wrap_mode, .text_wrap_style, .top, .transform_style, .unicode_bidi, .vertical_align, .visibility, .white_space, .white_space_collapse, .white_space_trim, .widows, .width, .word_break, .word_spacing, .writing_mode, .x, .y {
			true
		}
		else { false }
	}
}

pub fn property_affects_stacking_context(property_id PropertyID) bool {
	return match property_id {
		.all, .backdrop_filter, .backface_visibility, .clip_path, .contain, .container_type, .filter, .mask_image, .opacity, .rotate, .scale, .transform, .translate, .view_transition_name, .will_change, .z_index {
			true
		}
		else { false }
	}
}

pub fn property_requires_computation_with_inherited_value(property_id PropertyID) bool {
	return match property_id {
		.background_attachment, .background_blend_mode, .background_clip, .background_origin, .background_position_x, .background_position_y, .background_repeat, .background_size {
			true
		}
		else { false }
	}
}

pub fn property_requires_computation_with_initial_value(property_id PropertyID) bool {
	return match property_id {
		.background_attachment, .background_blend_mode, .background_clip, .background_color, .background_origin, .background_position_x, .background_position_y, .background_repeat, .background_size, .border_block_end_width, .border_block_start_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_left_width, .border_right_width, .border_top_width, .color, .column_rule_width, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .fill, .flood_color, .font_size, .font_weight, .font_width, .letter_spacing, .outline_width, .stop_color, .word_spacing {
			true
		}
		else { false }
	}
}

pub fn property_requires_computation_with_cascaded_value(property_id PropertyID) bool {
	return match property_id {
		.fit_tolerance { true }

		.baseline_shift { true }

		.border_shape { true }
		.font_palette { true }
		.font_size_adjust { true }
		.animation_range_start, .animation_range_end { true }
		.scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			true
		}
		.scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			true
		}
		.max_lines { true }
		.contain_intrinsic_block_size, .contain_intrinsic_height, .contain_intrinsic_inline_size, .contain_intrinsic_width {
			true
		}
		.webkit_text_fill_color, .accent_color, .animation_delay, .animation_duration, .animation_iteration_count, .animation_name, .animation_timeline, .animation_timing_function, .aspect_ratio, .backdrop_filter, .background_attachment, .background_blend_mode, .background_clip, .background_color, .background_image, .background_origin, .background_position_x, .background_position_y, .background_repeat, .background_size, .block_size, .border_block_end_color, .border_block_end_width, .border_block_start_color, .border_block_start_width, .border_bottom_color, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_width, .border_end_end_radius, .border_end_start_radius, .border_image_outset, .border_image_slice, .border_image_source, .border_image_width, .border_inline_end_color, .border_inline_end_width, .border_inline_start_color, .border_inline_start_width, .border_left_color, .border_left_width, .border_right_color, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_top_color, .border_top_left_radius, .border_top_right_radius, .border_top_width, .bottom, .box_shadow, .caret_color, .clip, .clip_path, .color, .column_count, .column_gap, .column_height, .column_rule_color, .column_rule_width, .column_width, .content, .corner_bottom_left_shape, .corner_bottom_right_shape, .corner_end_end_shape, .corner_end_start_shape, .corner_start_end_shape, .corner_start_start_shape, .corner_top_left_shape, .corner_top_right_shape, .counter_increment, .counter_reset, .counter_set, .cursor, .cx, .cy, .fill, .fill_opacity, .filter, .flex_basis, .flex_grow, .flex_shrink, .flood_color, .flood_opacity, .font_feature_settings, .font_size, .font_style, .font_variation_settings, .font_weight, .font_width, .grid_auto_columns, .grid_auto_rows, .grid_template_columns, .grid_template_rows, .height, .inline_size, .inset_block_end, .inset_block_start, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .line_height, .list_style_image, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .mask_image, .mask_position, .mask_size, .math_depth, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .object_position, .opacity, .order, .orphans, .outline_color, .outline_offset, .outline_width, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective, .perspective_origin, .position_area, .r, .right, .rotate, .row_gap, .rx, .ry, .scale, .scrollbar_color, .shape_image_threshold, .shape_margin, .shape_outside, .stop_color, .stop_opacity, .stroke, .stroke_dasharray, .stroke_dashoffset, .stroke_miterlimit, .stroke_opacity, .stroke_width, .tab_size, .text_decoration_color, .text_decoration_thickness, .text_indent, .text_shadow, .text_underline_offset, .top, .transform, .transform_origin, .transition_delay, .transition_duration, .transition_timing_function, .translate, .vertical_align, .view_timeline_inset, .widows, .width, .word_spacing, .x, .y, .z_index {
			true
		}
		else { false }
	}
}

fn property_is_positional_value_list_shorthand(property_id PropertyID) bool {
	return match property_id {
		.overscroll_behavior { true }

		.contain_intrinsic_size { true }
		.border_block_color, .border_block_style, .border_block_width, .border_color, .border_inline_color, .border_inline_style, .border_inline_width, .border_style, .border_width, .corner_block_end_shape, .corner_block_start_shape, .corner_bottom_shape, .corner_inline_end_shape, .corner_inline_start_shape, .corner_left_shape, .corner_right_shape, .corner_shape, .corner_top_shape, .gap, .inset, .inset_block, .inset_inline, .margin, .margin_block, .margin_inline, .overflow, .padding, .padding_block, .padding_inline, .scroll_margin, .scroll_margin_block, .scroll_margin_inline, .scroll_padding, .scroll_padding_block, .scroll_padding_inline {
			true
		}
		else { false }
	}
}

pub fn property_maximum_value_count(property_id PropertyID) uint {
	return match property_id {
		.grid_lanes_direction { 3 }

		.overscroll_behavior { 2 }

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
		.fit_tolerance { ValueType.length }

		.baseline_shift { ValueType.length }

		.animation_range_start, .animation_range_end {
			ValueType.length
		}
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			ValueType.length
		}
		.background_position, .background_position_x, .background_position_y, .background_size, .block_size, .border_bottom_left_radius, .border_bottom_right_radius, .border_end_end_radius, .border_end_start_radius, .border_image_width, .border_radius, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .bottom, .column_gap, .cx, .cy, .flex_basis, .font_size, .gap, .grid, .grid_auto_columns, .grid_auto_rows, .grid_template, .grid_template_columns, .grid_template_rows, .height, .inline_size, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .line_height, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .mask_position, .mask_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .object_position, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective_origin, .r, .right, .row_gap, .rx, .ry, .shape_margin, .stroke_dasharray, .stroke_dashoffset, .stroke_width, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform, .transform_origin, .translate, .vertical_align, .view_timeline_inset, .width, .word_spacing, .x, .y {
			ValueType.length
		}
		else { none }
	}
}

pub fn property_accepts_type(property_id PropertyID, value_type ValueType) bool {
	return match property_id {
		.fit_tolerance { value_type in [.length,.percentage] }

		.baseline_shift { value_type in [.length,.percentage] }

		.font_palette {
			value_type == .string
		}
		.font_size_adjust {
			value_type == .number
		}
		.animation_range_start, .animation_range_end {
			value_type in [.length, .percentage]
		}
		.text_box_edge {
			value_type == .string
		}
		.font_synthesis {
			value_type == .string
		}
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			value_type in [.length, .percentage]
		}
		.scroll_margin, .scroll_margin_block, .scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			value_type == .length
		}
		.block_ellipsis {
			value_type == .string
		}
		.max_lines {
			value_type == .integer
		}
		.webkit_text_fill_color, .accent_color, .background_color, .border_block_color, .border_block_end_color, .border_block_start_color, .border_bottom_color, .border_color, .border_inline_color, .border_inline_end_color, .border_inline_start_color, .border_left_color, .border_right_color, .border_top_color, .caret_color, .color, .column_rule_color, .flood_color, .outline_color, .stop_color, .text_decoration_color {
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
		.border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_right_width, .border_spacing, .border_top_width, .border_width, .column_height, .column_rule_width, .column_width, .outline_offset, .outline_width, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .perspective {
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
		.grid_lanes_direction { lowercase_value in ['normal','row','column','fill-reverse','track-reverse'] }
		.fit_tolerance { lowercase_value in ['normal','infinite'] }

		.overscroll_behavior_x, .overscroll_behavior_y, .overscroll_behavior_inline, .overscroll_behavior_block { lowercase_value in ['auto','contain','none','chain'] }

		.alignment_baseline { lowercase_value in ['baseline','text-bottom','alphabetic','ideographic','middle','central','mathematical','hanging','text-top'] }
		.baseline_source { lowercase_value in ['auto','first','last'] }
		.baseline_shift { lowercase_value in ['sub','super','top','center','bottom'] }

		.border_shape {
			lowercase_value in ['none']
		}
		.text_orientation {
			lowercase_value in ['mixed', 'upright', 'sideways']
		}
		.forced_color_adjust {
			lowercase_value in ['auto', 'none']
		}
		.font_palette {
			lowercase_value in ['normal', 'light', 'dark']
		}
		.font_size_adjust {
			lowercase_value in ['none']
		}
		.animation_range_start, .animation_range_end {
			lowercase_value in ['normal']
		}
		.text_box_trim {
			lowercase_value in ['none', 'trim-start', 'trim-end', 'trim-both']
		}
		.font_synthesis_weight, .font_synthesis_small_caps, .font_synthesis_position {
			lowercase_value in ['auto', 'none']
		}
		.font_synthesis_style {
			lowercase_value in ['auto', 'none', 'oblique-only']
		}
		.hyphens { lowercase_value in ['none', 'manual', 'auto'] }
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			lowercase_value == 'auto'
		}
		.block_ellipsis {
			lowercase_value in ['no-ellipsis', 'auto']
		}
		.continue_ {
			lowercase_value in ['auto', 'discard', 'collapse', '-webkit-legacy']
		}
		.max_lines {
			lowercase_value == 'none'
		}
		.webkit_box_orient {
			lowercase_value in ['horizontal', 'vertical']
		}
		.webkit_font_smoothing {
			lowercase_value in ['auto', 'none', 'antialiased', 'subpixel-antialiased']
		}
		.box_decoration_break {
			lowercase_value in ['slice', 'clone']
		}
		.column_fill {
			lowercase_value in ['auto', 'balance', 'balance-all']
		}
		.break_after, .break_before {
			lowercase_value in ['auto', 'avoid', 'avoid-page', 'page', 'left', 'right', 'recto',
				'verso', 'avoid-column', 'column', 'avoid-region', 'region']
		}
		.break_inside {
			lowercase_value in ['auto', 'avoid', 'avoid-page', 'avoid-column', 'avoid-region']
		}
		.accent_color, .animation_duration, .aspect_ratio, .border_image_width, .bottom, .caret_color, .clip, .column_count, .column_height, .column_width, .grid, .grid_area, .grid_auto_columns, .grid_auto_rows, .grid_column, .grid_column_end, .grid_column_start, .grid_row, .grid_row_end, .grid_row_start, .grid_template, .grid_template_columns, .grid_template_rows, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .right, .rx, .ry, .text_underline_offset, .top, .z_index {
			lowercase_value in ['auto']
		}
		.position_anchor {
			lowercase_value in ['normal', 'none', 'auto']
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
			lowercase_value in ['auto', 'button', 'checkbox', 'listbox', 'menulist', 'meter',
				'menulist-button', 'none', 'push-button', 'progress-bar', 'radio', 'searchfield',
				'slider-horizontal', 'square-button', 'textarea', 'textfield']
		}
		.background_attachment {
			lowercase_value in ['fixed', 'local', 'scroll']
		}
		.background_blend_mode, .mix_blend_mode {
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
			lowercase_value in ['repeat-x', 'repeat-y', 'no-repeat', 'repeat', 'round', 'space']
		}
		.background_size, .mask_size {
			lowercase_value in ['auto', 'cover', 'contain']
		}
		.block_size, .height, .inline_size, .min_block_size, .min_height, .min_inline_size, .min_width, .width {
			lowercase_value in ['auto', 'stretch', 'max-content', 'min-content']
		}
		.border_block_end_style, .border_block_start_style, .border_block_style, .border_bottom_style, .border_inline_end_style, .border_inline_start_style, .border_inline_style, .border_left_style, .border_right_style, .border_style, .border_top_style, .column_rule_style {
			lowercase_value in ['none', 'hidden', 'dotted', 'dashed', 'solid', 'double', 'groove',
				'ridge', 'inset', 'outset']
		}
		.border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_right_width, .border_top_width, .border_width, .column_rule_width, .outline_width {
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
		.backface_visibility {
			lowercase_value in ['visible', 'hidden']
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
		.color_interpolation, .color_interpolation_filters {
			lowercase_value in ['auto', 'linearrgb', 'srgb']
		}
		.color_scheme {
			lowercase_value in ['normal', 'light', 'dark']
		}
		.column_gap, .font_language_override, .font_variant_alternates, .font_variant_east_asian, .font_variant_numeric, .font_variation_settings, .gap, .letter_spacing, .line_height, .row_gap, .word_spacing {
			lowercase_value in ['normal']
		}
		.contain {
			lowercase_value in ['none', 'strict', 'content', 'size', 'inline-size', 'layout', 'style',
				'paint']
		}
		.container_name {
			lowercase_value in ['none']
		}
		.container_type {
			lowercase_value in ['normal', 'size', 'inline-size', 'scroll-state']
		}
		.content {
			lowercase_value in ['normal', 'none', 'open-quote', 'close-quote', 'no-open-quote',
				'no-close-quote']
		}
		.content_visibility {
			lowercase_value in ['visible', 'auto', 'hidden']
		}
		.cursor {
			lowercase_value in ['auto', 'default', 'none', 'context-menu', 'help', 'pointer',
				'progress', 'wait', 'cell', 'crosshair', 'text', 'vertical-text', 'alias', 'copy',
				'move', 'no-drop', 'not-allowed', 'grab', 'grabbing', 'e-resize', 'n-resize',
				'ne-resize', 'nw-resize', 's-resize', 'se-resize', 'sw-resize', 'w-resize',
				'ew-resize', 'ns-resize', 'nesw-resize', 'nwse-resize', 'col-resize', 'row-resize',
				'all-scroll', 'zoom-in', 'zoom-out']
		}
		.direction {
			lowercase_value in ['ltr', 'rtl']
		}
		.display {
			lowercase_value in ['list-item', 'block', 'inline', 'run-in', 'flow', 'flow-root', 'table',
				'flex', 'grid', 'ruby', 'math', 'table-row-group', 'table-header-group',
				'table-footer-group', 'table-row', 'table-cell', 'table-column-group', 'table-column',
				'table-caption', 'ruby-base', 'ruby-text', 'ruby-base-container',
				'ruby-text-container', 'contents', 'none', 'inline-block', 'inline-table',
				'inline-flex', 'inline-grid', '-webkit-box', '-webkit-inline-box']
		}
		.dominant_baseline {
			lowercase_value in ['auto', 'text-bottom', 'alphabetic', 'ideographic', 'middle',
				'central', 'mathematical', 'hanging', 'text-top']
		}
		.empty_cells {
			lowercase_value in ['show', 'hide']
		}
		.flex_basis {
			lowercase_value in ['auto', 'content', 'stretch', 'max-content', 'min-content']
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
			lowercase_value in ['math', 'xx-small', 'x-small', 'small', 'medium', 'large', 'x-large',
				'xx-large', 'xxx-large', 'smaller', 'larger']
		}
		.font_variant_caps {
			lowercase_value in ['normal', 'small-caps', 'all-small-caps', 'petite-caps',
				'all-petite-caps', 'unicase', 'titling-caps']
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
			lowercase_value in ['ultra-condensed', 'extra-condensed', 'condensed', 'semi-condensed',
				'normal', 'semi-expanded', 'expanded', 'extra-expanded', 'ultra-expanded']
		}
		.image_rendering {
			lowercase_value in ['auto', 'crisp-edges', 'high-quality', 'pixelated', 'smooth',
				'optimizespeed=pixelated', 'optimizequality=smooth']
		}
		.isolation {
			lowercase_value in ['auto', 'isolate']
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
		.list_style_position {
			lowercase_value in ['inside', 'outside']
		}
		.mask_clip {
			lowercase_value in ['no-clip', 'content-box', 'padding-box', 'border-box', 'fill-box',
				'stroke-box', 'view-box']
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
			lowercase_value in ['stretch', 'max-content', 'min-content', 'none']
		}
		.object_fit {
			lowercase_value in ['fill', 'contain', 'cover', 'none', 'scale-down']
		}
		.outline_style {
			lowercase_value in ['auto', 'none', 'dotted', 'dashed', 'solid', 'double', 'groove',
				'ridge', 'inset', 'outset']
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
			lowercase_value in ['auto', 'bounding-box', 'visiblepainted', 'visiblefill',
				'visiblestroke', 'visible', 'painted', 'fill', 'stroke', 'all', 'none']
		}
		.position {
			lowercase_value in ['absolute', 'fixed', 'relative', 'static', 'sticky']
		}
		.position_area {
			lowercase_value in ['none', 'left', 'center', 'right', 'span-left', 'span-right',
				'x-start', 'x-end', 'span-x-start', 'span-x-end', 'self-x-start', 'self-x-end',
				'span-self-x-start', 'span-self-x-end', 'span-all', 'top', 'bottom', 'span-top',
				'span-bottom', 'y-start', 'y-end', 'span-y-start', 'span-y-end', 'self-y-start',
				'self-y-end', 'span-self-y-start', 'span-self-y-end', 'block-start', 'block-end',
				'span-block-start', 'span-block-end', 'inline-start', 'inline-end',
				'span-inline-start', 'span-inline-end', 'self-block-start', 'self-block-end',
				'span-self-block-start', 'span-self-block-end', 'self-inline-start', 'self-inline-end',
				'span-self-inline-start', 'span-self-inline-end', 'start', 'end', 'span-start',
				'span-end', 'self-start', 'self-end', 'span-self-start', 'span-self-end']
		}
		.position_try_fallbacks {
			lowercase_value in ['none', 'flip-block', 'flip-inline', 'flip-start']
		}
		.position_try_order {
			lowercase_value in ['normal', 'most-width', 'most-height', 'most-block-size',
				'most-inline-size']
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
		.scroll_snap_align {
			lowercase_value in ['none', 'start', 'end', 'center']
		}
		.scroll_snap_stop {
			lowercase_value in ['normal', 'always']
		}
		.scroll_snap_type {
			lowercase_value in ['none', 'x', 'y', 'block', 'inline', 'both', 'mandatory', 'proximity']
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
			lowercase_value in ['center', 'justify', 'start', 'end', 'left', 'right', 'match-parent',
				'-libweb-center', '-libweb-inherit-or-center', '-libweb-left', '-libweb-right']
		}
		.text_anchor {
			lowercase_value in ['start', 'middle', 'end']
		}
		.text_decoration_line {
			lowercase_value in ['none', 'underline', 'overline', 'line-through', 'blink',
				'spelling-error', 'grammar-error']
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
			lowercase_value in ['capitalize', 'full-size-kana', 'full-width', 'lowercase', 'math-auto',
				'none', 'uppercase']
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
			lowercase_value in ['auto', 'manipulation', 'none', 'pan-down', 'pan-left', 'pan-right',
				'pan-up', 'pan-x', 'pan-y']
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
			lowercase_value in ['bidi-override', 'embed', 'isolate', 'isolate-override', 'normal',
				'plaintext']
		}
		.user_select {
			lowercase_value in ['all', 'auto', 'contain', 'none', 'text']
		}
		.vector_effect {
			lowercase_value in ['none', 'non-scaling-stroke']
		}
		.vertical_align {
			lowercase_value in ['baseline', 'bottom', 'middle', 'sub', 'super', 'text-bottom',
				'text-top', 'top']
		}
		.visibility {
			lowercase_value in ['collapse', 'hidden', 'visible']
		}
		.white_space {
			lowercase_value in ['normal', 'pre', 'pre-line', 'pre-wrap']
		}
		.white_space_collapse {
			lowercase_value in ['collapse', 'discard', 'preserve', 'preserve-breaks',
				'preserve-spaces', 'break-spaces']
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
			lowercase_value in ['horizontal-tb', 'vertical-rl', 'vertical-lr', 'sideways-rl',
				'sideways-lr']
		}
		else { false }
	}
}

pub fn property_accepted_type_ranges(property_id PropertyID) map[ValueType]AcceptedTypeRange {
	mut ranges := map[ValueType]AcceptedTypeRange{}
	match property_id {
		.fit_tolerance {
            ranges[.length] = AcceptedTypeRange{min:0,max:math.max_f32}
            ranges[.percentage] = AcceptedTypeRange{min:0,max:math.max_f32}
        }

		.font_size_adjust {
			ranges[.number] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
		}
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
		.border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_right_width, .border_spacing, .border_top_width, .border_width, .column_height, .column_rule_width, .column_width, .outline_width, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .perspective {
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
		.outline_offset, .scroll_margin, .scroll_margin_block, .scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			ranges[.length] = AcceptedTypeRange{
				min: -math.max_f32
				max: math.max_f32
			}
		}
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			ranges[.length] = AcceptedTypeRange{
				min: 0
				max: math.max_f32
			}
			ranges[.percentage] = AcceptedTypeRange{
				min: 0
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
		.column_count, .max_lines, .orphans, .widows {
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
		.fit_tolerance { value.raw_value() >= 0 }

		.baseline_shift { true }

		.animation_range_start, .animation_range_end {
			true
		}
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			value.raw_value() >= 0
		}
		.scroll_margin, .scroll_margin_block, .scroll_margin_block_end, .scroll_margin_block_start, .scroll_margin_bottom, .scroll_margin_inline, .scroll_margin_inline_end, .scroll_margin_inline_start, .scroll_margin_left, .scroll_margin_right, .scroll_margin_top {
			true
		}
		.background_position_x, .background_position_y, .bottom, .cx, .cy, .inset, .inset_block, .inset_block_end, .inset_block_start, .inset_inline, .inset_inline_end, .inset_inline_start, .left, .letter_spacing, .margin, .margin_block, .margin_block_end, .margin_block_start, .margin_bottom, .margin_inline, .margin_inline_end, .margin_inline_start, .margin_left, .margin_right, .margin_top, .outline_offset, .right, .text_decoration_thickness, .text_indent, .text_underline_offset, .top, .transform_origin, .translate, .vertical_align, .word_spacing, .x, .y {
			true
		}
		.background_size, .block_size, .border_block_end_width, .border_block_start_width, .border_block_width, .border_bottom_left_radius, .border_bottom_right_radius, .border_bottom_width, .border_end_end_radius, .border_end_start_radius, .border_image_outset, .border_image_width, .border_inline_end_width, .border_inline_start_width, .border_inline_width, .border_left_width, .border_radius, .border_right_width, .border_spacing, .border_start_end_radius, .border_start_start_radius, .border_top_left_radius, .border_top_right_radius, .border_top_width, .border_width, .column_gap, .column_height, .column_rule_width, .column_width, .flex_basis, .font_size, .gap, .grid, .grid_auto_columns, .grid_auto_rows, .grid_template, .grid_template_columns, .grid_template_rows, .height, .inline_size, .line_height, .mask_size, .max_block_size, .max_height, .max_inline_size, .max_width, .min_block_size, .min_height, .min_inline_size, .min_width, .outline_width, .overflow_clip_margin, .overflow_clip_margin_block, .overflow_clip_margin_block_end, .overflow_clip_margin_block_start, .overflow_clip_margin_bottom, .overflow_clip_margin_inline, .overflow_clip_margin_inline_end, .overflow_clip_margin_inline_start, .overflow_clip_margin_left, .overflow_clip_margin_right, .overflow_clip_margin_top, .padding, .padding_block, .padding_block_end, .padding_block_start, .padding_bottom, .padding_inline, .padding_inline_end, .padding_inline_start, .padding_left, .padding_right, .padding_top, .perspective, .r, .row_gap, .rx, .ry, .shape_margin, .stroke_dashoffset, .stroke_width, .tab_size, .width {
			value.raw_value() >= 0
		}
		else { false }
	}
}

pub fn property_accepts_number(property_id PropertyID, value f64) bool {
	return match property_id {
		.font_size_adjust {
			value >= 0
		}
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
		.fit_tolerance { value.value() >= 0 }

		.baseline_shift { true }

		.animation_range_start, .animation_range_end {
			true
		}
		.scroll_padding, .scroll_padding_block, .scroll_padding_block_end, .scroll_padding_block_start, .scroll_padding_bottom, .scroll_padding_inline, .scroll_padding_inline_end, .scroll_padding_inline_start, .scroll_padding_left, .scroll_padding_right, .scroll_padding_top {
			value.value() >= 0
		}
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
