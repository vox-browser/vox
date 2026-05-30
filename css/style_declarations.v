module css

import dom

pub enum ComputedDeclarationFlag {
	no
	yes
}

pub enum ReadonlyDeclarationFlag {
	no
	yes
}

pub fn PropertyNameAndID.from_id(property_id PropertyID) PropertyNameAndID {
	return PropertyNameAndID{
		name_: string_from_property_id(property_id)
		id_:   property_id
	}
}

pub fn string_from_property_id(property_id PropertyID) string {
	return match property_id {
		.accent_color { 'accent-color' }
		.anchor_name { 'anchor-name' }
		.anchor_scope { 'anchor-scope' }
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
		.aspect_ratio { 'aspect-ratio' }
		.background_color { 'background-color' }
		.background_image { 'background-image' }
		.background_attachment { 'background-attachment' }
		.background_blend_mode { 'background-blend-mode' }
		.background_clip { 'background-clip' }
		.background_origin { 'background-origin' }
		.background_position_x { 'background-position-x' }
		.background_position_y { 'background-position-y' }
		.background_repeat { 'background-repeat' }
		.background_size { 'background-size' }
		.block_size { 'block-size' }
		.bottom { 'bottom' }
		.border_bottom_color { 'border-bottom-color' }
		.border_bottom_style { 'border-bottom-style' }
		.border_bottom_width { 'border-bottom-width' }
		.border_collapse { 'border-collapse' }
		.border_left_color { 'border-left-color' }
		.border_left_style { 'border-left-style' }
		.border_left_width { 'border-left-width' }
		.border_right_color { 'border-right-color' }
		.border_right_style { 'border-right-style' }
		.border_right_width { 'border-right-width' }
		.border_top_color { 'border-top-color' }
		.border_top_style { 'border-top-style' }
		.border_top_width { 'border-top-width' }
		.border_bottom_left_radius { 'border-bottom-left-radius' }
		.border_bottom_right_radius { 'border-bottom-right-radius' }
		.border_top_left_radius { 'border-top-left-radius' }
		.border_top_right_radius { 'border-top-right-radius' }
		.border_image_outset { 'border-image-outset' }
		.border_image_repeat { 'border-image-repeat' }
		.border_image_slice { 'border-image-slice' }
		.border_image_source { 'border-image-source' }
		.border_image_width { 'border-image-width' }
		.border_spacing { 'border-spacing' }
		.box_sizing { 'box-sizing' }
		.caption_side { 'caption-side' }
		.caret_color { 'caret-color' }
		.clear { 'clear' }
		.clip_rule { 'clip-rule' }
		.color { 'color' }
		.color_interpolation { 'color-interpolation' }
		.color_scheme { 'color-scheme' }
		.content_visibility { 'content-visibility' }
		.contain { 'contain' }
		.container_type { 'container-type' }
		.direction { 'direction' }
		.empty_cells { 'empty-cells' }
		.corner_bottom_left_shape { 'corner-bottom-left-shape' }
		.corner_bottom_right_shape { 'corner-bottom-right-shape' }
		.corner_top_left_shape { 'corner-top-left-shape' }
		.corner_top_right_shape { 'corner-top-right-shape' }
		.fill_opacity { 'fill-opacity' }
		.fill_rule { 'fill-rule' }
		.flood_color { 'flood-color' }
		.flood_opacity { 'flood-opacity' }
		.float_ { 'float' }
		.font_feature_settings { 'font-feature-settings' }
		.font_kerning { 'font-kerning' }
		.font_language_override { 'font-language-override' }
		.font_optical_sizing { 'font-optical-sizing' }
		.font_style { 'font-style' }
		.font_variant_caps { 'font-variant-caps' }
		.font_variant_emoji { 'font-variant-emoji' }
		.font_variant_position { 'font-variant-position' }
		.font_variation_settings { 'font-variation-settings' }
		.font_weight { 'font-weight' }
		.font_width { 'font-width' }
		.height { 'height' }
		.flex_grow { 'flex-grow' }
		.flex_shrink { 'flex-shrink' }
		.flex_direction { 'flex-direction' }
		.flex_wrap { 'flex-wrap' }
		.align_content { 'align-content' }
		.align_items { 'align-items' }
		.align_self { 'align-self' }
		.justify_content { 'justify-content' }
		.justify_items { 'justify-items' }
		.justify_self { 'justify-self' }
		.appearance { 'appearance' }
		.column_span { 'column-span' }
		.column_count { 'column-count' }
		.column_width { 'column-width' }
		.column_height { 'column-height' }
		.column_gap { 'column-gap' }
		.row_gap { 'row-gap' }
		.image_rendering { 'image-rendering' }
		.inline_size { 'inline-size' }
		.inset_block_end { 'inset-block-end' }
		.inset_block_start { 'inset-block-start' }
		.inset_inline_end { 'inset-inline-end' }
		.inset_inline_start { 'inset-inline-start' }
		.isolation { 'isolation' }
		.left { 'left' }
		.letter_spacing { 'letter-spacing' }
		.line_height { 'line-height' }
		.list_style_image { 'list-style-image' }
		.list_style_position { 'list-style-position' }
		.mask_clip { 'mask-clip' }
		.mask_composite { 'mask-composite' }
		.mask_image { 'mask-image' }
		.mask_mode { 'mask-mode' }
		.mask_origin { 'mask-origin' }
		.mask_position { 'mask-position' }
		.mask_repeat { 'mask-repeat' }
		.mask_size { 'mask-size' }
		.margin_block_end { 'margin-block-end' }
		.margin_block_start { 'margin-block-start' }
		.margin_bottom { 'margin-bottom' }
		.margin_inline_end { 'margin-inline-end' }
		.margin_inline_start { 'margin-inline-start' }
		.margin_left { 'margin-left' }
		.margin_right { 'margin-right' }
		.margin_top { 'margin-top' }
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
		.opacity { 'opacity' }
		.order { 'order' }
		.orphans { 'orphans' }
		.overflow_wrap { 'overflow-wrap' }
		.outline_color { 'outline-color' }
		.outline_offset { 'outline-offset' }
		.outline_style { 'outline-style' }
		.outline_width { 'outline-width' }
		.overflow_x { 'overflow-x' }
		.overflow_y { 'overflow-y' }
		.pointer_events { 'pointer-events' }
		.paint_order { 'paint-order' }
		.padding_block_end { 'padding-block-end' }
		.padding_block_start { 'padding-block-start' }
		.padding_bottom { 'padding-bottom' }
		.padding_inline_end { 'padding-inline-end' }
		.padding_inline_start { 'padding-inline-start' }
		.padding_left { 'padding-left' }
		.padding_right { 'padding-right' }
		.padding_top { 'padding-top' }
		.position { 'position' }
		.position_anchor { 'position-anchor' }
		.position_visibility { 'position-visibility' }
		.shape_margin { 'shape-margin' }
		.shape_image_threshold { 'shape-image-threshold' }
		.shape_rendering { 'shape-rendering' }
		.stop_color { 'stop-color' }
		.stop_opacity { 'stop-opacity' }
		.stroke_linecap { 'stroke-linecap' }
		.stroke_linejoin { 'stroke-linejoin' }
		.stroke_miterlimit { 'stroke-miterlimit' }
		.stroke_opacity { 'stroke-opacity' }
		.stroke_width { 'stroke-width' }
		.stroke_dashoffset { 'stroke-dashoffset' }
		.rotate { 'rotate' }
		.scale { 'scale' }
		.scroll_behavior { 'scroll-behavior' }
		.scrollbar_width { 'scrollbar-width' }
		.right { 'right' }
		.scroll_timeline_axis { 'scroll-timeline-axis' }
		.scroll_timeline_name { 'scroll-timeline-name' }
		.table_layout { 'table-layout' }
		.text_align { 'text-align' }
		.text_anchor { 'text-anchor' }
		.text_decoration_color { 'text-decoration-color' }
		.text_decoration_line { 'text-decoration-line' }
		.text_decoration_style { 'text-decoration-style' }
		.text_decoration_thickness { 'text-decoration-thickness' }
		.text_underline_offset { 'text-underline-offset' }
		.text_indent { 'text-indent' }
		.text_justify { 'text-justify' }
		.text_overflow { 'text-overflow' }
		.text_rendering { 'text-rendering' }
		.text_transform { 'text-transform' }
		.text_wrap_mode { 'text-wrap-mode' }
		.text_wrap_style { 'text-wrap-style' }
		.transform { 'transform' }
		.transform_box { 'transform-box' }
		.transform_style { 'transform-style' }
		.transition_behavior { 'transition-behavior' }
		.transition_delay { 'transition-delay' }
		.transition_duration { 'transition-duration' }
		.transition_property { 'transition-property' }
		.transition_timing_function { 'transition-timing-function' }
		.translate { 'translate' }
		.top { 'top' }
		.unicode_bidi { 'unicode-bidi' }
		.user_select { 'user-select' }
		.touch_action { 'touch-action' }
		.view_timeline_inset { 'view-timeline-inset' }
		.view_timeline_axis { 'view-timeline-axis' }
		.view_timeline_name { 'view-timeline-name' }
		.view_transition_name { 'view-transition-name' }
		.visibility { 'visibility' }
		.width { 'width' }
		.webkit_text_fill_color { '-webkit-text-fill-color' }
		.white_space_collapse { 'white-space-collapse' }
		.white_space_trim { 'white-space-trim' }
		.word_break { 'word-break' }
		.word_spacing { 'word-spacing' }
		.writing_mode { 'writing-mode' }
		.widows { 'widows' }
		.z_index { 'z-index' }
		.cx { 'cx' }
		.cy { 'cy' }
		.x { 'x' }
		.y { 'y' }
		.r { 'r' }
		.rx { 'rx' }
		.ry { 'ry' }
		.resize { 'resize' }
	}
}

pub fn property_is_shorthand(property_id PropertyID) bool {
	_ = property_id
	return false
}

pub fn property_is_single_valued(property_id PropertyID) bool {
	return !property_is_list_valued(property_id)
}

pub fn property_is_list_valued(property_id PropertyID) bool {
	return match property_id {
		.anchor_name, .anchor_scope, .animation_composition, .animation_delay,
		.animation_direction, .animation_duration, .animation_fill_mode,
		.animation_iteration_count, .animation_name, .animation_play_state, .animation_timeline,
		.animation_timing_function, .background_image, .background_attachment,
		.background_blend_mode, .background_clip, .background_origin, .background_position_x,
		.background_position_y, .background_repeat, .background_size, .font_feature_settings,
		.font_variation_settings, .mask_image, .mask_clip, .mask_composite, .mask_mode,
		.mask_origin, .mask_position, .mask_repeat, .mask_size, .scroll_timeline_axis,
		.scroll_timeline_name, .transition_behavior, .transition_delay, .transition_duration,
		.transition_property, .transition_timing_function, .view_timeline_axis,
		.view_timeline_inset, .view_timeline_name {
			true
		}
		else {
			false
		}
	}
}

pub const number_of_longhand_properties = 233

pub fn first_longhand_property_id() PropertyID {
	return .accent_color
}

pub fn last_longhand_property_id() PropertyID {
	return .border_spacing
}

fn property_id_from_longhand_index(index int) ?PropertyID {
	return match index {
		0 { PropertyID.accent_color }
		1 { PropertyID.anchor_name }
		2 { PropertyID.anchor_scope }
		3 { PropertyID.animation_composition }
		4 { PropertyID.animation_delay }
		5 { PropertyID.animation_direction }
		6 { PropertyID.animation_duration }
		7 { PropertyID.animation_fill_mode }
		8 { PropertyID.animation_iteration_count }
		9 { PropertyID.animation_name }
		10 { PropertyID.animation_play_state }
		11 { PropertyID.animation_timeline }
		12 { PropertyID.animation_timing_function }
		13 { PropertyID.aspect_ratio }
		14 { PropertyID.background_color }
		15 { PropertyID.background_image }
		16 { PropertyID.border_bottom_color }
		17 { PropertyID.border_bottom_width }
		18 { PropertyID.border_left_color }
		19 { PropertyID.border_left_width }
		20 { PropertyID.border_right_color }
		21 { PropertyID.border_right_width }
		22 { PropertyID.border_top_color }
		23 { PropertyID.border_top_width }
		24 { PropertyID.border_image_source }
		25 { PropertyID.caret_color }
		26 { PropertyID.clear }
		27 { PropertyID.color }
		28 { PropertyID.color_scheme }
		29 { PropertyID.content_visibility }
		30 { PropertyID.corner_bottom_left_shape }
		31 { PropertyID.corner_bottom_right_shape }
		32 { PropertyID.corner_top_left_shape }
		33 { PropertyID.corner_top_right_shape }
		34 { PropertyID.fill_opacity }
		35 { PropertyID.flood_color }
		36 { PropertyID.flood_opacity }
		37 { PropertyID.float_ }
		38 { PropertyID.font_feature_settings }
		39 { PropertyID.font_style }
		40 { PropertyID.font_variation_settings }
		41 { PropertyID.font_weight }
		42 { PropertyID.font_width }
		43 { PropertyID.letter_spacing }
		44 { PropertyID.line_height }
		45 { PropertyID.list_style_image }
		46 { PropertyID.mask_image }
		47 { PropertyID.math_depth }
		48 { PropertyID.math_style }
		49 { PropertyID.mix_blend_mode }
		50 { PropertyID.object_fit }
		51 { PropertyID.opacity }
		52 { PropertyID.order }
		53 { PropertyID.orphans }
		54 { PropertyID.outline_color }
		55 { PropertyID.outline_offset }
		56 { PropertyID.outline_style }
		57 { PropertyID.outline_width }
		58 { PropertyID.overflow_x }
		59 { PropertyID.overflow_y }
		60 { PropertyID.pointer_events }
		61 { PropertyID.position }
		62 { PropertyID.position_anchor }
		63 { PropertyID.shape_image_threshold }
		64 { PropertyID.stop_color }
		65 { PropertyID.stop_opacity }
		66 { PropertyID.stroke_opacity }
		67 { PropertyID.rotate }
		68 { PropertyID.scale }
		69 { PropertyID.scroll_timeline_name }
		70 { PropertyID.transform }
		71 { PropertyID.transition_behavior }
		72 { PropertyID.transition_delay }
		73 { PropertyID.transition_duration }
		74 { PropertyID.transition_property }
		75 { PropertyID.transition_timing_function }
		76 { PropertyID.translate }
		77 { PropertyID.view_timeline_inset }
		78 { PropertyID.view_timeline_name }
		79 { PropertyID.webkit_text_fill_color }
		80 { PropertyID.word_spacing }
		81 { PropertyID.caption_side }
		82 { PropertyID.direction }
		83 { PropertyID.empty_cells }
		84 { PropertyID.table_layout }
		85 { PropertyID.unicode_bidi }
		86 { PropertyID.visibility }
		87 { PropertyID.z_index }
		88 { PropertyID.clip_rule }
		89 { PropertyID.color_interpolation }
		90 { PropertyID.fill_rule }
		91 { PropertyID.mask_type }
		92 { PropertyID.shape_rendering }
		93 { PropertyID.stroke_linecap }
		94 { PropertyID.stroke_linejoin }
		95 { PropertyID.text_anchor }
		96 { PropertyID.border_bottom_style }
		97 { PropertyID.border_left_style }
		98 { PropertyID.border_right_style }
		99 { PropertyID.border_top_style }
		100 { PropertyID.isolation }
		101 { PropertyID.border_collapse }
		102 { PropertyID.user_select }
		103 { PropertyID.box_sizing }
		104 { PropertyID.list_style_position }
		105 { PropertyID.transform_style }
		106 { PropertyID.text_align }
		107 { PropertyID.text_justify }
		108 { PropertyID.text_overflow }
		109 { PropertyID.text_rendering }
		110 { PropertyID.text_transform }
		111 { PropertyID.text_wrap_mode }
		112 { PropertyID.text_wrap_style }
		113 { PropertyID.white_space_collapse }
		114 { PropertyID.white_space_trim }
		115 { PropertyID.word_break }
		116 { PropertyID.font_kerning }
		117 { PropertyID.font_language_override }
		118 { PropertyID.font_optical_sizing }
		119 { PropertyID.font_variant_caps }
		120 { PropertyID.font_variant_emoji }
		121 { PropertyID.font_variant_position }
		122 { PropertyID.flex_direction }
		123 { PropertyID.flex_wrap }
		124 { PropertyID.align_content }
		125 { PropertyID.align_items }
		126 { PropertyID.align_self }
		127 { PropertyID.justify_content }
		128 { PropertyID.justify_items }
		129 { PropertyID.justify_self }
		130 { PropertyID.appearance }
		131 { PropertyID.column_span }
		132 { PropertyID.image_rendering }
		133 { PropertyID.transform_box }
		134 { PropertyID.touch_action }
		135 { PropertyID.writing_mode }
		136 { PropertyID.view_transition_name }
		137 { PropertyID.scrollbar_width }
		138 { PropertyID.resize }
		139 { PropertyID.contain }
		140 { PropertyID.container_type }
		141 { PropertyID.text_decoration_line }
		142 { PropertyID.text_decoration_style }
		143 { PropertyID.paint_order }
		144 { PropertyID.overflow_wrap }
		145 { PropertyID.scroll_behavior }
		146 { PropertyID.math_shift }
		147 { PropertyID.border_image_repeat }
		148 { PropertyID.mask_composite }
		149 { PropertyID.mask_mode }
		150 { PropertyID.mask_origin }
		151 { PropertyID.scroll_timeline_axis }
		152 { PropertyID.view_timeline_axis }
		153 { PropertyID.position_visibility }
		154 { PropertyID.background_attachment }
		155 { PropertyID.background_blend_mode }
		156 { PropertyID.background_clip }
		157 { PropertyID.background_origin }
		158 { PropertyID.background_repeat }
		159 { PropertyID.mask_clip }
		160 { PropertyID.mask_repeat }
		161 { PropertyID.flex_grow }
		162 { PropertyID.flex_shrink }
		163 { PropertyID.column_count }
		164 { PropertyID.column_width }
		165 { PropertyID.column_height }
		166 { PropertyID.column_gap }
		167 { PropertyID.row_gap }
		168 { PropertyID.widows }
		169 { PropertyID.stroke_miterlimit }
		170 { PropertyID.stroke_width }
		171 { PropertyID.stroke_dashoffset }
		172 { PropertyID.text_decoration_color }
		173 { PropertyID.text_decoration_thickness }
		174 { PropertyID.text_underline_offset }
		175 { PropertyID.text_indent }
		176 { PropertyID.shape_margin }
		177 { PropertyID.cx }
		178 { PropertyID.cy }
		179 { PropertyID.x }
		180 { PropertyID.y }
		181 { PropertyID.r }
		182 { PropertyID.rx }
		183 { PropertyID.ry }
		184 { PropertyID.background_position_x }
		185 { PropertyID.background_position_y }
		186 { PropertyID.background_size }
		187 { PropertyID.mask_position }
		188 { PropertyID.mask_size }
		189 { PropertyID.border_image_outset }
		190 { PropertyID.border_image_slice }
		191 { PropertyID.border_image_width }
		192 { PropertyID.border_bottom_left_radius }
		193 { PropertyID.border_bottom_right_radius }
		194 { PropertyID.border_top_left_radius }
		195 { PropertyID.border_top_right_radius }
		196 { PropertyID.block_size }
		197 { PropertyID.height }
		198 { PropertyID.inline_size }
		199 { PropertyID.max_block_size }
		200 { PropertyID.max_height }
		201 { PropertyID.max_inline_size }
		202 { PropertyID.max_width }
		203 { PropertyID.min_block_size }
		204 { PropertyID.min_height }
		205 { PropertyID.min_inline_size }
		206 { PropertyID.min_width }
		207 { PropertyID.width }
		208 { PropertyID.bottom }
		209 { PropertyID.left }
		210 { PropertyID.right }
		211 { PropertyID.top }
		212 { PropertyID.inset_block_end }
		213 { PropertyID.inset_block_start }
		214 { PropertyID.inset_inline_end }
		215 { PropertyID.inset_inline_start }
		216 { PropertyID.margin_block_end }
		217 { PropertyID.margin_block_start }
		218 { PropertyID.margin_bottom }
		219 { PropertyID.margin_inline_end }
		220 { PropertyID.margin_inline_start }
		221 { PropertyID.margin_left }
		222 { PropertyID.margin_right }
		223 { PropertyID.margin_top }
		224 { PropertyID.padding_block_end }
		225 { PropertyID.padding_block_start }
		226 { PropertyID.padding_bottom }
		227 { PropertyID.padding_inline_end }
		228 { PropertyID.padding_inline_start }
		229 { PropertyID.padding_left }
		230 { PropertyID.padding_right }
		231 { PropertyID.padding_top }
		232 { PropertyID.border_spacing }
		else { none }
	}
}

fn css_style_declarations_is_valid_css_property(property string) bool {
	return property_id_from_string(property) != none || is_a_custom_property_name_string(property)
}

fn css_style_property_name_and_id_from_name(name string) ?PropertyNameAndID {
	if name.starts_with('--') && !is_a_custom_property_name_string(name) {
		return none
	}
	return PropertyNameAndID.from_name(name)
}

fn css_style_properties_empty_dom_style_value() &dom.StyleValue {
	return &dom.StyleValue{}
}

fn dom_style_value_to_css_text(value &dom.StyleValue) string {
	return value.css_text
}

fn css_style_properties_length(properties &CSSStyleProperties) int {
	if properties.is_computed() {
		if properties.owner_node == none {
			return 0
		}
		return number_of_longhand_properties
	}
	return properties.length()
}

fn custom_property_is_important(serialized_value string) bool {
	return custom_property_priority_start(serialized_value) != none
}

fn custom_property_value_without_priority(serialized_value string) string {
	priority_start := custom_property_priority_start(serialized_value) or {
		return serialized_value.trim_space()
	}
	return serialized_value[..priority_start].trim_space()
}

fn custom_property_value_with_priority(value string, important Important) string {
	if important == .yes {
		return '${value} !important'
	}
	return value
}

fn custom_property_priority_start(serialized_value string) ?int {
	mut end := serialized_value.len
	for end > 0 && is_ascii_whitespace_byte(serialized_value[end - 1]) {
		end--
	}

	if end < 'important'.len {
		return none
	}

	important_start := end - 'important'.len
	if !equals_ignoring_ascii_case(serialized_value[important_start..end], 'important') {
		return none
	}

	mut bang_end := important_start
	for bang_end > 0 && is_ascii_whitespace_byte(serialized_value[bang_end - 1]) {
		bang_end--
	}

	if bang_end == 0 || serialized_value[bang_end - 1] != `!` {
		return none
	}

	return bang_end - 1
}

fn parse_custom_property_value(value string) string {
	mut parser := Parser.from_css_text(value)
	return StyleValue(UnresolvedStyleValue.create(parser.component_values)).serialize(.normal)
}

fn css_style_properties_serialized(properties &CSSStyleProperties) string {
	mut declarations := []string{}
	for name, value in properties.custom_properties {
		declarations << serialize_a_css_declaration(name,
			custom_property_value_without_priority(value), if custom_property_is_important(value) {
			Important.yes
		} else {
			Important.no
		})
	}
	for property in properties.properties {
		declarations << serialize_a_css_declaration(property.name, property.value, if property.important {
			Important.yes
		} else {
			Important.no
		})
	}
	return declarations.join(' ')
}

fn parse_css_property_declaration_block_for_style_properties(context ParsingParams, block string) &CSSStyleProperties {
	mut body := block.trim_space()
	if body.starts_with('{') && body.ends_with('}') {
		body = body[1..body.len - 1]
	}

	mut parser := RuleSelectorParser.create(context, body, 'utf-8')
	mut input := parser.token_stream
	mut style := CSSStyleProperties.create()
	for {
		input.discard_whitespace()
		if !input.has_next_token() {
			break
		}
		if input.next_token().is(.semicolon) {
			input.discard_a_token()
			continue
		}
		if declaration := parser.consume_a_declaration(mut input, .no, .no) {
			property := css_style_property_name_and_id_from_name(declaration.name) or { continue }
			value := if original := declaration.original_value_text {
				original
			} else {
				parser_component_values_to_string(declaration.value).trim_space()
			}

			if property.is_custom_property() {
				style.custom_properties[property.name()] = custom_property_value_with_priority(value,
					declaration.important)
				continue
			}

			property_id := property.id() or { continue }
			style.properties << CSSStyleProperty{
				name:        string_from_property_id(property_id)
				value:       value
				important:   declaration.important == .yes
				style_value: parse_css_value(context, value, property_id)
			}
		} else {
			parser.consume_the_remnants_of_a_bad_declaration(mut input, .no)
		}
	}
	return style
}

fn serialized_text_from_mutable_style_property_map_value(value MutableStylePropertyMapValue) !string {
	return match value {
		CSSStyleValue { value.to_string()! }
		string { value }
	}
}

// https://drafts.csswg.org/cssom/#dom-cssstylerule-style
pub fn CSSStyleProperties.create_from_declarations(properties []StyleProperty, custom_properties map[string]StyleProperty) &CSSStyleProperties {
	// The style attribute must return a CSSStyleProperties object for the style rule, with the following properties:
	//     computed flag: Unset.
	//     readonly flag: Unset.
	//     declarations: The declared declarations in the rule, in specified order.
	//     parent CSS rule: The context object.
	//     owner node: Null.
	mut declaration := CSSStyleProperties.create()
	declaration.properties =
		css_style_properties_to_cssom_properties(convert_declarations_to_specified_order(properties))
	for name, property in custom_properties {
		declaration.custom_properties[name] = custom_property_value_with_priority(dom_style_value_to_css_text(property.value),
			property.important)
	}
	return declaration
}

// https://drafts.csswg.org/cssom/#dom-window-getcomputedstyle
pub fn CSSStyleProperties.create_resolved_style(element_reference ?dom.AbstractElement) &CSSStyleProperties {
	// 6. Return a live CSSStyleProperties object with the following properties:
	//    computed flag: Set.
	//    readonly flag: Set.
	//    declarations: decls.
	//    parent CSS rule: Null.
	//    owner node: obj.
	// AD-HOC: Rather than instantiate with a list of decls, they're generated on demand.
	mut declaration := CSSStyleProperties.create()
	declaration.computed = true
	declaration.readonly = true
	declaration.owner_node = element_reference
	return declaration
}

// https://drafts.csswg.org/cssom/#dom-elementcssinlinestyle-style
pub fn CSSStyleProperties.create_element_inline_style(element_reference dom.AbstractElement, properties []StyleProperty, custom_properties map[string]StyleProperty) &CSSStyleProperties {
	// The style attribute must return a CSS declaration block object whose readonly flag is unset, whose parent CSS
	// rule is null, and whose owner node is the context object.
	mut declaration := CSSStyleProperties.create_from_declarations(properties, custom_properties)
	declaration.owner_node = element_reference
	return declaration
}

fn css_style_properties_to_cssom_properties(properties []StyleProperty) []CSSStyleProperty {
	mut result := []CSSStyleProperty{}
	for property in properties {
		result << CSSStyleProperty{
			name:        string_from_property_id(property.property_id)
			value:       dom_style_value_to_css_text(property.value)
			important:   property.important == .yes
			style_value: unsafe { property.value }
		}
	}
	return result
}

// https://drafts.csswg.org/cssom/#concept-declarations-specified-order
pub fn convert_declarations_to_specified_order(declarations []StyleProperty) []StyleProperty {
	// The specified order for declarations is the same as specified, but with shorthand properties expanded into their
	// longhand properties, in canonical order. If a property is specified more than once (after shorthand expansion), only
	// the one with greatest cascading order must be represented, at the same relative position as it was specified.
	mut specified_order_declarations := []StyleProperty{}

	for declaration in declarations {
		StyleComputer.for_each_property_expanding_shorthands(declaration.property_id,
			declaration.value, fn [declaration, mut specified_order_declarations] (longhand_id PropertyID, longhand_property_value &dom.StyleValue) {
			mut existing_entry_index := ?int(none)
			for index, existing_declaration in specified_order_declarations {
				if existing_declaration.property_id == longhand_id {
					existing_entry_index = index
					break
				}
			}

			if index := existing_entry_index {
				// If there is an existing entry for this property and it is a higher cascading order than the current entry, skip the current entry.
				if specified_order_declarations[index].important == .yes
					&& declaration.important == .no {
					return
				}

				// Otherwise the existing entry has a lower cascading order and is removed.
				specified_order_declarations.delete(index)
			}

			specified_order_declarations << StyleProperty{
				important:   declaration.important
				property_id: longhand_id
				value:       unsafe { longhand_property_value }
			}
		})
	}

	return specified_order_declarations
}

pub fn (properties &CSSStyleProperties) is_computed() bool {
	return properties.computed
}

pub fn (properties &CSSStyleProperties) is_readonly() bool {
	return properties.readonly
}

pub fn (properties &CSSStyleProperties) owner_node() ?dom.AbstractElement {
	return properties.owner_node
}

pub fn (mut properties CSSStyleProperties) set_owner_node(owner_node ?dom.AbstractElement) {
	properties.owner_node = owner_node
}

pub fn (properties &CSSStyleProperties) is_updating() bool {
	return properties.updating
}

pub fn (mut properties CSSStyleProperties) set_is_updating(updating bool) {
	properties.updating = updating
}

// https://drafts.csswg.org/cssom/#update-style-attribute-for
pub fn (mut properties CSSStyleProperties) update_style_attribute() {
	// 1. Assert: declaration block's computed flag is unset.
	if properties.is_computed() {
		panic('VERIFY(!is_computed())')
	}

	// 2. Let owner node be declaration block's owner node.
	// 3. If owner node is null, then return.
	if properties.owner_node == none {
		return
	}

	// 4. Set declaration block's updating flag.
	properties.set_is_updating(true)

	// 5. Set an attribute value for owner node using "style" and the result of serializing declaration block.
	if owner_node := properties.owner_node {
		mut element := unsafe { &dom.Element(owner_node.element()) }
		element.set_attribute_value('style', css_style_properties_serialized(properties))
	}

	// 6. Unset declaration block's updating flag.
	properties.set_is_updating(false)
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-csstext
pub fn (properties &CSSStyleProperties) css_text() string {
	// 1. If the computed flag is set, then return the empty string.
	if properties.is_computed() {
		return ''
	}

	// 2. Return the result of serializing the declarations.
	return css_style_properties_serialized(properties)
}

pub fn (properties &CSSStyleProperties) item(index usize) string {
	// The item(index) method must return the property name of the CSS declaration at position index.
	// If there is no indexth object in the collection, then the method must return the empty string.
	custom_properties_count := properties.custom_properties.len

	if int(index) >= css_style_properties_length(properties) {
		return ''
	}

	if properties.is_computed() {
		if property_id := property_id_from_longhand_index(int(index)) {
			return string_from_property_id(property_id)
		}
		return ''
	}

	if int(index) < custom_properties_count {
		mut keys := properties.custom_properties.keys()
		keys.sort()
		return keys[index]
	}

	return properties.properties[int(index) - custom_properties_count].name
}

pub fn (properties &CSSStyleProperties) item_value(index usize) ?string {
	value := properties.item(index)
	if value.len == 0 {
		return none
	}
	return value
}

pub fn (properties &CSSStyleProperties) get_property(property_id PropertyID) ?StyleProperty {
	return properties.get_property_internal(PropertyNameAndID.from_id(property_id))
}

pub fn (properties &CSSStyleProperties) custom_property(custom_property_name string) ?StyleProperty {
	if properties.is_computed() {
		// Boundary: computed custom property lookup requires DOM::Element custom_property_data().
		return none
	}

	if value := properties.custom_properties[custom_property_name] {
		return StyleProperty{
			property_id: .color
			value:       css_style_properties_empty_dom_style_value()
			important:   if custom_property_is_important(value) {
				Important.yes
			} else {
				Important.no
			}
		}
	}
	return none
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-setproperty
pub fn (mut properties CSSStyleProperties) set_property(property_name string, value string, priority string) ! {
	// 1. If the computed flag is set, then throw a NoModificationAllowedError exception.
	if properties.is_computed() {
		return error('NoModificationAllowedError: Cannot modify properties in result of getComputedStyle()')
	}

	// 2. If property is not a custom property, follow these substeps:
	//    1. Let property be property converted to ASCII lowercase.
	//    2. If property is not a case-sensitive match for a supported CSS property, then return.
	// NB: This is handled inside PropertyNameAndID::from_string().
	property := css_style_property_name_and_id_from_name(property_name) or { return }

	// NB: The remaining steps are implemented in set_property_internal().
	properties.set_property_internal(property, value, priority)!
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-setproperty
pub fn (mut properties CSSStyleProperties) set_property_internal(property PropertyNameAndID, value string, priority string) ! {
	// NB: Steps 1 and 2 only apply to the IDL method that invokes this.

	// 3. If value is the empty string, invoke removeProperty() with property as argument and return.
	if value.len == 0 {
		properties.remove_property_internal(property)!
		return
	}

	// 4. If priority is not the empty string and is not an ASCII case-insensitive match for the string "important", then return.
	if priority.len != 0 && !equals_ignoring_ascii_case(priority, 'important') {
		return
	}

	if property.is_custom_property() {
		serialized := custom_property_value_with_priority(parse_custom_property_value(value), if priority.len != 0 {
			Important.yes
		} else {
			Important.no
		})
		properties.custom_properties[property.name()] = serialized
		properties.update_style_attribute()
		properties.invalidate_owners(.style_sheet_changed)
		return
	}

	property_id := property.id() or { return }

	// 5. Let component value list be the result of parsing value for property property.
	context := if owner_node := properties.owner_node {
		ParsingParams{
			document: owner_node.element().document()
		}
	} else {
		ParsingParams{}
	}
	component_value_list := parse_css_value(context, value, property_id) or {
		// 6. If component value list is null, then return.
		return
	}

	// 7. Let updated be false.
	mut updated := false

	// 8. If property is a shorthand property,
	if property_is_shorthand(property_id) {
		// then for each longhand property longhand that property maps to, in canonical order, follow these substeps:
		StyleComputer.for_each_property_expanding_shorthands(property_id, component_value_list, fn [priority, mut properties, mut updated] (longhand_property_id PropertyID, longhand_value &dom.StyleValue) {
			// 1. Let longhand result be the result of set the CSS declaration longhand with the appropriate value(s) from component value list,
			//    with the important flag set if priority is not the empty string, and unset otherwise, and with the list of declarations being the declarations.
			// 2. If longhand result is true, let updated be true.
			updated =
				properties.set_a_css_declaration(longhand_property_id, longhand_value, if priority.len != 0 { Important.yes } else { Important.no })
				|| updated
		})
	}
	// 9. Otherwise,
	else {
		// let updated be the result of set the CSS declaration property with value component value list,
		// with the important flag set if priority is not the empty string, and unset otherwise,
		// and with the list of declarations being the declarations.
		updated = properties.set_a_css_declaration_with_serialized(property_id,
			component_value_list, if priority.len != 0 { Important.yes } else { Important.no },
			value)
	}

	// 10. If updated is true, update style attribute for the CSS declaration block.
	if updated {
		properties.update_style_attribute()

		// Non-standard: Invalidate style for the owners of our containing sheet, if any.
		properties.invalidate_owners(.style_sheet_changed)
	}
}

pub fn (mut properties CSSStyleProperties) set_property_by_id(property_id PropertyID, css_text string, priority string) ! {
	properties.set_property_internal(PropertyNameAndID.from_id(property_id), css_text, priority)!
}

pub fn (mut properties CSSStyleProperties) set_a_css_declaration(property_id PropertyID, value &dom.StyleValue, important Important) bool {
	return properties.set_a_css_declaration_with_serialized(property_id, value, important,
		dom_style_value_to_css_text(value))
}

fn (mut properties CSSStyleProperties) set_a_css_declaration_with_serialized(property_id PropertyID, value &dom.StyleValue, important Important, serialized_value string) bool {
	mut new_property := CSSStyleProperty{
		name:        string_from_property_id(property_id)
		value:       serialized_value
		important:   important == .yes
		style_value: unsafe { value }
	}

	for index, property in properties.properties {
		if property.name == new_property.name {
			if property.important == new_property.important && property.value == new_property.value {
				return false
			}
			properties.properties[index] = new_property
			return true
		}
	}

	properties.properties << new_property
	return true
}

pub fn (mut properties CSSStyleProperties) remove_property(property_name string) !string {
	property := css_style_property_name_and_id_from_name(property_name) or { return '' }
	return properties.remove_property_internal(property)!
}

pub fn (mut properties CSSStyleProperties) remove_property_internal(property PropertyNameAndID) !string {
	if properties.is_readonly() {
		return error('NoModificationAllowedError: Cannot modify readonly CSSStyleProperties')
	}

	mut removed := false
	mut removed_value := ''
	if property.is_custom_property() {
		if value := properties.custom_properties[property.name()] {
			removed_value = custom_property_value_without_priority(value)
			properties.custom_properties.delete(property.name())
			removed = true
		}
	} else {
		property_name := string_from_property_id(property.id() or { PropertyID.color })
		for index, existing in properties.properties {
			if existing.name == property_name {
				removed_value = existing.value
				properties.properties.delete(index)
				removed = true
				break
			}
		}
	}

	if removed {
		properties.update_style_attribute()
		properties.invalidate_owners(.style_sheet_changed)
	}
	return removed_value
}

pub fn (mut properties CSSStyleProperties) set_css_text(css_text string) ! {
	if properties.is_readonly() {
		return error('NoModificationAllowedError: Cannot modify readonly CSSStyleProperties')
	}
	context := if owner_node := properties.owner_node {
		ParsingParams{
			document: owner_node.element().document()
		}
	} else {
		ParsingParams{}
	}
	new_properties := parse_css_property_declaration_block_for_style_properties(context, css_text)
	properties.properties = new_properties.properties
	properties.custom_properties = new_properties.custom_properties.clone()
	properties.update_style_attribute()
	properties.invalidate_owners(.style_sheet_changed)
}

pub fn (properties &CSSStyleProperties) get_property_internal(property PropertyNameAndID) ?StyleProperty {
	if property.is_custom_property() {
		return properties.custom_property(property.name())
	}
	property_name := string_from_property_id(property.id() or { PropertyID.color })
	for existing in properties.properties {
		if existing.name == property_name {
			return StyleProperty{
				important:   if existing.important { Important.yes } else { Important.no }
				property_id: property.id() or { PropertyID.color }
				value:       existing.style_value or {
					css_style_properties_empty_dom_style_value()
				}
			}
		}
	}
	return none
}

pub fn (properties &CSSStyleProperties) get_property_style_value(property PropertyNameAndID) ?&dom.StyleValue {
	if style_property := properties.get_property_internal(property) {
		return style_property.value
	}
	return none
}

pub fn (properties &CSSStyleProperties) has_property(property PropertyNameAndID) bool {
	return properties.get_property_internal(property) != none
}

pub fn (properties &CSSStyleProperties) property_value(property_name string) string {
	property := css_style_property_name_and_id_from_name(property_name) or { return '' }
	if property.is_custom_property() {
		if value := properties.custom_properties[property.name()] {
			return custom_property_value_without_priority(value)
		}
		return ''
	}
	property_id := property.id() or { return '' }
	property_id_name := string_from_property_id(property_id)
	for existing in properties.properties {
		if existing.name == property_id_name {
			return existing.value
		}
	}
	if style_property := properties.get_property_internal(property) {
		return dom_style_value_to_css_text(style_property.value)
	}
	return ''
}

pub fn (properties &CSSStyleProperties) property_priority(property_name string) string {
	property := css_style_property_name_and_id_from_name(property_name) or { return '' }
	if property.is_custom_property() {
		if value := properties.custom_properties[property.name()] {
			if custom_property_is_important(value) {
				return 'important'
			}
		}
		return ''
	}
	if style_property := properties.get_property_internal(property) {
		if style_property.important == .yes {
			return 'important'
		}
	}
	return ''
}

pub fn (properties &CSSStyleProperties) get_property_value(property_name string) string {
	return properties.property_value(property_name)
}

pub fn (properties &CSSStyleProperties) get_property_priority(property_name string) string {
	return properties.property_priority(property_name)
}

fn (properties &CSSStyleProperties) invalidate_owners(reason StyleInvalidationReason) {
	mapped_reason := css_style_declarations_to_dom_invalidation_reason(reason)
	if owner_node := properties.owner_node {
		mut node := unsafe { &dom.Node(owner_node.element()) }
		node.invalidate_style(mapped_reason)
	}
	if parent_rule := properties.parent_rule {
		if mut parent_style_sheet := parent_rule.parent_style_sheet {
			parent_style_sheet.invalidate_owners(mapped_reason)
		}
	}
}

fn css_style_declarations_to_dom_invalidation_reason(reason StyleInvalidationReason) dom.StyleInvalidationReason {
	return match reason {
		.base_url_changed { dom.StyleInvalidationReason.base_url_changed }
		.hover_changed, .style_sheet_changed, .dom_mutation { dom.StyleInvalidationReason.style_change }
	}
}

@[heap]
pub struct StylePropertyMapReadOnly {
pub mut:
	element     ?dom.AbstractElement
	declaration ?&CSSStyleProperties
}

pub fn StylePropertyMapReadOnly.create_computed_style(element dom.AbstractElement) &StylePropertyMapReadOnly {
	return &StylePropertyMapReadOnly{
		element: element
	}
}

pub fn StylePropertyMapReadOnly.create_for_declaration(declaration &CSSStyleProperties) &StylePropertyMapReadOnly {
	return &StylePropertyMapReadOnly{
		declaration: declaration
	}
}

fn reify_serialized_style_map_value(property PropertyNameAndID, serialized_value string, parse_multiple bool) []CSSStyleValue {
	return CSSStyleValue.parse_a_css_style_value(property.name(), serialized_value, parse_multiple) or {
		return []CSSStyleValue{}
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-get
pub fn (mut property_map StylePropertyMapReadOnly) get(property_name string) ?CSSStyleValue {
	// The get(property) method, when called on a StylePropertyMapReadOnly this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := css_style_property_name_and_id_from_name(property_name) or { return none }

	// 3. Let props be the value of this's [[declarations]] internal slot.
	// 4. If props[property] exists, subdivide into iterations props[property], then reify the first item of the result and return it.
	if serialized_value := property_map.get_serialized_style_value(property) {
		reified_values := reify_serialized_style_map_value(property, serialized_value, false)
		if reified_values.len > 0 {
			return reified_values[0]
		}
		return StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic(serialized_value))).reify(property.name())
	}
	if property_value := property_map.get_style_value(property) {
		if property_value.css_text.len > 0 {
			reified_values := reify_serialized_style_map_value(property, property_value.css_text,
				false)
			if reified_values.len > 0 {
				return reified_values[0]
			}
			return StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic(property_value.css_text))).reify(property.name())
		}
		return StyleValue(UnresolvedStyleValue.create([]ComponentValue{})).reify(property.name())
	}

	// 5. Otherwise, return undefined.
	return none
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-getall
pub fn (mut property_map StylePropertyMapReadOnly) get_all(property_name string) []CSSStyleValue {
	// The getAll(property) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := css_style_property_name_and_id_from_name(property_name) or {
		return []CSSStyleValue{}
	}

	// 3. Let props be the value of this's [[declarations]] internal slot.
	// 4. If props[property] exists, subdivide into iterations props[property], then reify each item of the result, and return the list.
	if serialized_value := property_map.get_serialized_style_value(property) {
		reified_values := reify_serialized_style_map_value(property, serialized_value, true)
		if reified_values.len > 0 {
			return reified_values
		}
		return [StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic(serialized_value))).reify(property.name())]
	}
	if property_value := property_map.get_style_value(property) {
		if property_value.css_text.len > 0 {
			reified_values :=
				reify_serialized_style_map_value(property, property_value.css_text, true)
			if reified_values.len > 0 {
				return reified_values
			}
			return [StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic(property_value.css_text))).reify(property.name())]
		}
		return [StyleValue(UnresolvedStyleValue.create([]ComponentValue{})).reify(property.name())]
	}

	// 5. Otherwise, return an empty list.
	return []CSSStyleValue{}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-has
pub fn (mut property_map StylePropertyMapReadOnly) has(property_name string) bool {
	// The has(property) method, when called on a StylePropertyMapReadOnly this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := css_style_property_name_and_id_from_name(property_name) or { return false }

	// 3. Let props be the value of this's [[declarations]] internal slot.
	// 4. If props[property] exists, return true. Otherwise, return false.
	if _ := property_map.element {
		// From https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap we need to include:
		// "the name and computed value of every longhand CSS property supported by the User Agent, every
		// registered custom property, and every non-registered custom property which is not set to its initial
		// value on this"
		if property.is_custom_property() {
			element := property_map.element or { return false }
			if data := element.custom_property_data() {
				if _ := data.get(property.name()) {
					return true
				}
			}
			return element.document().get_registered_custom_property(property.name()) != none
		}
		return true
	}
	if declaration := property_map.declaration {
		return declaration.has_property(property)
	}
	return false
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymapreadonly-size
pub fn (property_map &StylePropertyMapReadOnly) size() u32 {
	// The size attribute, on getting from a StylePropertyMapReadOnly this, must perform the following steps:

	// 1. Return the size of the value of this's [[declarations]] internal slot.
	if _ := property_map.element {
		// From https://drafts.css-houdini.org/css-typed-om-1/#dom-element-computedstylemap we need to include:
		// "the name and computed value of every longhand CSS property supported by the User Agent, every
		// registered custom property, and every non-registered custom property which is not set to its initial
		// value on this"
		element := property_map.element or { return number_of_longhand_properties }
		mut custom_properties := map[string]bool{}
		if data := element.custom_property_data() {
			for name, _ in data.properties {
				custom_properties[name] = true
			}
		}
		for name, _ in element.document().registered_property_set() {
			custom_properties[name] = true
		}
		return number_of_longhand_properties + u32(custom_properties.len)
	}
	if declaration := property_map.declaration {
		return u32(declaration.length())
	}
	return 0
}

pub fn (mut property_map StylePropertyMapReadOnly) get_style_value(property PropertyNameAndID) ?&dom.StyleValue {
	if _ := property_map.element {
		_ = property
		// Boundary: computed property extraction from DOM::Element requires computed style values to expose CSS::StyleValue.
		return none
	}
	if declaration := property_map.declaration {
		return declaration.get_property_style_value(property)
	}
	return none
}

fn (mut property_map StylePropertyMapReadOnly) get_serialized_style_value(property PropertyNameAndID) ?string {
	if declaration := property_map.declaration {
		if property.is_custom_property() {
			if value := declaration.custom_properties[property.name()] {
				return custom_property_value_without_priority(value)
			}
			return none
		}
		property_name := string_from_property_id(property.id() or { return none })
		for existing in declaration.properties {
			if existing.name == property_name {
				return existing.value
			}
		}
	}
	return none
}

pub type MutableStylePropertyMapValue = CSSStyleValue | string

@[heap]
pub struct MutableStylePropertyMap {
pub mut:
	declaration &CSSStyleProperties = unsafe { nil }
}

pub fn MutableStylePropertyMap.create(declaration &CSSStyleProperties) &MutableStylePropertyMap {
	return &MutableStylePropertyMap{
		declaration: declaration
	}
}

fn any_have_non_matching_associated_property(property string, values []MutableStylePropertyMapValue) bool {
	for value in values {
		if value is CSSStyleValue {
			if associated_property := value.associated_property {
				if associated_property != property {
					return true
				}
			}
		}
	}
	return false
}

fn mutable_style_property_map_value_is_unresolved(property PropertyNameAndID, value MutableStylePropertyMapValue) bool {
	return match value {
		CSSStyleValue {
			if source_value := value.source_value() {
				source_value.type_() == .unresolved
			} else {
				property.is_custom_property()
			}
		}
		string {
			property.is_custom_property()
		}
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#create-an-internal-representation
fn create_an_internal_representation(property PropertyNameAndID, value MutableStylePropertyMapValue) !&dom.StyleValue {
	// To create an internal representation, given a string property and a string or CSSStyleValue value:
	return match value {
		CSSStyleValue {
			internal_representation := value.create_an_internal_representation(property, .yes)!
			dom_style_value_from_value_logic(internal_representation)
		}
		string {
			// If value is a USVString,
			//     Parse a CSSStyleValue with property property, cssText value, and parseMultiple set to false, and
			//     return the result.
			if property.is_custom_property() {
				mut parser := Parser.from_css_text(value)
				dom_style_value_from_value_logic(StyleValue(UnresolvedStyleValue.create(parser.component_values)))
			} else {
				parse_css_value(ParsingParams{}, value, property.id() or { PropertyID.color }) or {
					return error("Could not parse '${value}' for '${property.name()}'")
				}
			}
		}
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-set
pub fn (mut property_map MutableStylePropertyMap) set(property_name string, values []MutableStylePropertyMapValue) ! {
	// The set(property, ...values) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := css_style_property_name_and_id_from_name(property_name) or {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. If property is a single-valued property and values has more than one item, throw a TypeError.
	// NB: Custom properties should all be single-valued.
	if (property.is_custom_property() || property_is_single_valued(property.id() or {
		PropertyID.color
	})) && values.len > 1 {
		return error("Property '${property_name}' only accepts a single value")
	}

	// 4. If any of the items in values have a non-null [[associatedProperty]] internal slot, and that slot's value is
	//    anything other than property, throw a TypeError.
	if any_have_non_matching_associated_property(property.name(), values) {
		return error('One of the passed CSSStyleValues has a different associated property')
	}

	// 5. If the size of values is two or more, and one or more of the items are a CSSUnparsedValue or
	//    CSSVariableReferenceValue object, throw a TypeError.
	// FIXME: This is done as part of step 9, because we need to detect if a string value would be an CSSUnparsedValue
	//        or CSSVariableReferenceValue. Spec issue: https://github.com/w3c/css-houdini-drafts/issues/1157

	// 6. Let props be the value of this's [[declarations]] internal slot.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }

	// 7. If props[property] exists, remove it.
	props.remove_property(property.name())!

	// 8. Let values to set be an empty list.
	mut values_to_set := []&dom.StyleValue{}

	// 9. For each value in values, create an internal representation for property and value, and append the result to values to set.
	mut serialized_values := []string{}
	for value in values {
		if values.len >= 2 && mutable_style_property_map_value_is_unresolved(property, value) {
			return error('Cannot provide multiple values if one is an CSSUnparsedValue or CSSVariableReferenceValue')
		}
		internal_representation := create_an_internal_representation(property, value)!
		values_to_set << internal_representation
		serialized_values << serialized_text_from_mutable_style_property_map_value(value)!
	}

	// 10. Set props[property] to values to set.
	// NOTE: The property is deleted then added back so that it gets put at the end of the ordered map, which gives the
	//       expected behavior in the face of shorthand properties.
	if property.is_custom_property() {
		props.custom_properties[property.name()] =
			parse_custom_property_value(serialized_values.join(', '))
		props.update_style_attribute()
		props.invalidate_owners(.style_sheet_changed)
	} else if values_to_set.len == 1 {
		props.set_a_css_declaration_with_serialized(property.id() or { PropertyID.color },
			values_to_set[0], .no, serialized_values[0])
		props.update_style_attribute()
		props.invalidate_owners(.style_sheet_changed)
	} else {
		props.set_a_css_declaration_with_serialized(property.id() or { PropertyID.color },
			css_style_properties_empty_dom_style_value(), .no, serialized_values.join(', '))
		props.update_style_attribute()
		props.invalidate_owners(.style_sheet_changed)
	}
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-append
pub fn (mut property_map MutableStylePropertyMap) append(property_name string, values []MutableStylePropertyMapValue) ! {
	// The append(property, ...values) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	// 2. If property is not a valid CSS property, throw a TypeError.
	property := css_style_property_name_and_id_from_name(property_name) or {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. If property is not a list-valued property, throw a TypeError.
	if !property_is_list_valued(property.id() or { PropertyID.color }) {
		return error("'${property_name}' is not a list-valued property")
	}

	// 4. If any of the items in values have a non-null [[associatedProperty]] internal slot, and that slot's value is
	//    anything other than property, throw a TypeError.
	if any_have_non_matching_associated_property(property.name(), values) {
		return error('One of the passed CSSStyleValues has a different associated property')
	}

	// 5. If any of the items in values are a CSSUnparsedValue or CSSVariableReferenceValue object, throw a TypeError.
	// FIXME: This is done as part of step 10, because we need to detect if a string value would be an CSSUnparsedValue
	//        or CSSVariableReferenceValue. Spec issue: https://github.com/w3c/css-houdini-drafts/issues/1157

	// 6. Let props be the value of this's [[declarations]] internal slot.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }

	// 7. If props[property] does not exist, set props[property] to an empty list.
	// 8. If props[property] contains a var() reference, throw a TypeError.
	// 9. Let temp values be an empty list.
	mut value_list := []&dom.StyleValue{}
	if existing_value := props.get_property_style_value(property) {
		value_list << existing_value
	}

	// 10. For each value in values, create an internal representation with property and value, and append the returned value to temp values.
	mut serialized_values := []string{}
	for value in values {
		if mutable_style_property_map_value_is_unresolved(property, value) {
			return error('Cannot append a CSSUnparsedValue or CSSVariableReferenceValue')
		}
		value_list << create_an_internal_representation(property, value)!
		serialized_values << serialized_text_from_mutable_style_property_map_value(value)!
	}

	// 11. Append the entries of temp values to props[property].
	mut serialized_value := ''
	existing := props.property_value(property.name())
	if existing.len != 0 {
		serialized_value = existing
	}
	if serialized_value.len != 0 && serialized_values.len != 0 {
		serialized_value += ', '
	}
	serialized_value += serialized_values.join(', ')
	props.set_a_css_declaration_with_serialized(property.id() or { PropertyID.color },
		css_style_properties_empty_dom_style_value(), .no, serialized_value)
	props.update_style_attribute()
	props.invalidate_owners(.style_sheet_changed)
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-delete
pub fn (mut property_map MutableStylePropertyMap) delete_(property string) ! {
	// The delete(property) method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. If property is not a custom property name string, set property to property ASCII lowercased.
	mut property_name := property
	if !is_a_custom_property_name_string(property_name) {
		property_name = property_name.to_lower()
	}

	// 2. If property is not a valid CSS property, throw a TypeError.
	if !css_style_declarations_is_valid_css_property(property_name) {
		return error("'${property_name}' is not a valid CSS property")
	}

	// 3. If this's [[declarations]] internal slot contains property, remove it.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }
	props.remove_property(property_name)!
}

// https://drafts.css-houdini.org/css-typed-om-1/#dom-stylepropertymap-clear
pub fn (mut property_map MutableStylePropertyMap) clear() ! {
	// The clear() method, when called on a StylePropertyMap this, must perform the following steps:

	// 1. Remove all of the declarations in this's [[declarations]] internal slot.
	mut props := unsafe { &CSSStyleProperties(property_map.declaration) }
	props.set_css_text('')!
}
