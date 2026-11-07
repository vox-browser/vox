module css

import dom
import math

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
		id_: property_id
	}
}

pub fn property_is_shorthand(property_id PropertyID) bool {
	return longhands_for_shorthand_local(property_id).len > 0
}

pub enum PropertyMultiplicity {
	single
	list
	coordinating_list
}

pub fn property_is_single_valued(property_id PropertyID) bool {
	return !property_is_list_valued(property_id)
}

pub fn property_is_list_valued(property_id PropertyID) bool {
	return property_multiplicity(property_id) != .single
}

pub const number_of_longhand_properties = 364

pub fn first_longhand_property_id() PropertyID {
	return .accent_color
}

pub fn last_longhand_property_id() PropertyID {
	return .webkit_font_smoothing
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
		233 { PropertyID.border_block_end_color }
		234 { PropertyID.border_block_end_style }
		235 { PropertyID.border_block_end_width }
		236 { PropertyID.border_block_start_color }
		237 { PropertyID.border_block_start_style }
		238 { PropertyID.border_block_start_width }
		239 { PropertyID.border_inline_end_color }
		240 { PropertyID.border_inline_end_style }
		241 { PropertyID.border_inline_end_width }
		242 { PropertyID.border_inline_start_color }
		243 { PropertyID.border_inline_start_style }
		244 { PropertyID.border_inline_start_width }
		245 { PropertyID.border_end_end_radius }
		246 { PropertyID.border_end_start_radius }
		247 { PropertyID.border_start_end_radius }
		248 { PropertyID.border_start_start_radius }
		249 { PropertyID.corner_end_end_shape }
		250 { PropertyID.corner_end_start_shape }
		251 { PropertyID.corner_start_end_shape }
		252 { PropertyID.corner_start_start_shape }
		253 { PropertyID.object_position }
		254 { PropertyID.overflow_block }
		255 { PropertyID.overflow_clip_margin_block_end }
		256 { PropertyID.overflow_clip_margin_block_start }
		257 { PropertyID.overflow_clip_margin_bottom }
		258 { PropertyID.overflow_clip_margin_inline_end }
		259 { PropertyID.overflow_clip_margin_inline_start }
		260 { PropertyID.overflow_clip_margin_left }
		261 { PropertyID.overflow_clip_margin_right }
		262 { PropertyID.overflow_clip_margin_top }
		263 { PropertyID.overflow_inline }
		264 { PropertyID.perspective }
		265 { PropertyID.perspective_origin }
		266 { PropertyID.position_area }
		267 { PropertyID.position_try_fallbacks }
		268 { PropertyID.position_try_order }
		269 { PropertyID.scrollbar_color }
		270 { PropertyID.scrollbar_gutter }
		271 { PropertyID.tab_size }
		272 { PropertyID.text_underline_position }
		273 { PropertyID.timeline_scope }
		274 { PropertyID.transform_origin }
		275 { PropertyID.vertical_align }
		276 { PropertyID.will_change }
		277 { PropertyID.dominant_baseline }
		278 { PropertyID.display }
		279 { PropertyID.flex_basis }
		280 { PropertyID.quotes }
		281 { PropertyID.box_shadow }
		282 { PropertyID.text_shadow }
		283 { PropertyID.list_style_type }
		284 { PropertyID.clip }
		285 { PropertyID.stroke_dasharray }
		286 { PropertyID.font_family }
		287 { PropertyID.grid_column_start }
		288 { PropertyID.grid_column_end }
		289 { PropertyID.grid_row_start }
		290 { PropertyID.grid_row_end }
		291 { PropertyID.grid_auto_flow }
		292 { PropertyID.grid_auto_columns }
		293 { PropertyID.grid_auto_rows }
		294 { PropertyID.grid_template_columns }
		295 { PropertyID.grid_template_rows }
		296 { PropertyID.grid_template_areas }
		297 { PropertyID.filter }
		298 { PropertyID.backdrop_filter }
		299 { PropertyID.counter_increment }
		300 { PropertyID.counter_reset }
		301 { PropertyID.counter_set }
		302 { PropertyID.cursor }
		303 { PropertyID.font_size }
		304 { PropertyID.fill }
		305 { PropertyID.stroke }
		306 { PropertyID.font_variant_ligatures }
		307 { PropertyID.font_variant_numeric }
		308 { PropertyID.font_variant_east_asian }
		309 { PropertyID.clip_path }
		310 { PropertyID.shape_outside }
		311 { PropertyID.content }
		312 { PropertyID.font_variant_alternates }
		313 { PropertyID.text_decoration_skip_ink }
		314 { PropertyID.container_name }
		315 { PropertyID.d }
		316 { PropertyID.contain_intrinsic_block_size }
		317 { PropertyID.contain_intrinsic_height }
		318 { PropertyID.contain_intrinsic_inline_size }
		319 { PropertyID.contain_intrinsic_width }
		320 { PropertyID.column_rule_color }
		321 { PropertyID.column_rule_style }
		322 { PropertyID.column_rule_width }
		323 { PropertyID.break_after }
		324 { PropertyID.break_before }
		325 { PropertyID.break_inside }
		326 { PropertyID.box_decoration_break }
		327 { PropertyID.column_fill }
		328 { PropertyID.block_ellipsis }
		329 { PropertyID.continue_ }
		330 { PropertyID.max_lines }
		331 { PropertyID.webkit_box_orient }
		332 { PropertyID.scroll_margin_block_end }
		333 { PropertyID.scroll_margin_block_start }
		334 { PropertyID.scroll_margin_bottom }
		335 { PropertyID.scroll_margin_inline_end }
		336 { PropertyID.scroll_margin_inline_start }
		337 { PropertyID.scroll_margin_left }
		338 { PropertyID.scroll_margin_right }
		339 { PropertyID.scroll_margin_top }
		340 { PropertyID.scroll_padding_block_end }
		341 { PropertyID.scroll_padding_block_start }
		342 { PropertyID.scroll_padding_bottom }
		343 { PropertyID.scroll_padding_inline_end }
		344 { PropertyID.scroll_padding_inline_start }
		345 { PropertyID.scroll_padding_left }
		346 { PropertyID.scroll_padding_right }
		347 { PropertyID.scroll_padding_top }
		348 { PropertyID.scroll_snap_align }
		349 { PropertyID.scroll_snap_stop }
		350 { PropertyID.scroll_snap_type }
		351 { PropertyID.color_interpolation_filters }
		352 { PropertyID.backface_visibility }
		353 { PropertyID.vector_effect }
		354 { PropertyID.hyphens }
		355 { PropertyID.font_synthesis_weight }
		356 { PropertyID.font_synthesis_style }
		357 { PropertyID.font_synthesis_small_caps }
		358 { PropertyID.font_synthesis_position }
		359 { PropertyID.text_box_trim }
		360 { PropertyID.text_box_edge }
		361 { PropertyID.animation_range_start }
		362 { PropertyID.animation_range_end }
		363 { PropertyID.webkit_font_smoothing }
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

pub fn parse_custom_property_value(value string) &dom.StyleValue {
	return parse_custom_property_components(parse_component_values_for_value_logic(value), value)
}

fn parse_custom_property_components(values []ComponentValue, original_text string) &dom.StyleValue {
	mut tokens := ComponentValueStream.new(values)
	if keyword := parse_css_wide_keyword_value(mut tokens) {
		tokens.consume_whitespace()
		if tokens.is_empty() {
			return dom_style_value_from_value_logic(keyword)
		}
	}
	return dom_style_value_from_value_logic(StyleValue(UnresolvedStyleValue.create_with_original_source_text(values, original_text)))
}

fn cssom_style_property_as_style_property(property CSSStyleProperty) ?StyleProperty {
	property_id := property_id_from_string(property.name) or { return none }
	value := property.style_value or {
		parsed := parse_css_value_logic(property_id, property.value) or { return none }
		dom_style_value_from_value_logic(parsed)
	}
	return StyleProperty{
		important: if property.important { Important.yes } else { Important.no }
		property_id: property_id
		value: value
	}
}

fn (mut properties CSSStyleProperties) clear_typed_properties_cache() {
	properties.typed_properties_cache_ = none
	properties.typed_importance_mask_ = 0
}

fn cssom_expanded_longhands_for_shorthand(shorthand PropertyID) []PropertyID {
	return generated_expanded_longhands_for_shorthand(shorthand)
}

// Generated `shorthands_for_longhand()`/`property_maps_to_shorthand()` data,
// derived from the same canonical shorthand table retained by this port.
fn cssom_shorthands_for_longhand(longhand PropertyID) []PropertyID {
	return generated_shorthands_for_longhand(longhand)
}

fn cssom_style_property_index(properties &CSSStyleProperties, property_id PropertyID) ?int {
	name := string_from_property_id(property_id)
	for index, property in properties.properties {
		if property.name == name {
			return index
		}
	}
	return none
}

fn cssom_make_shorthand_value(shorthand PropertyID, declarations []StyleProperty) ?StyleValue {
	longhand_ids := longhands_for_shorthand_local(shorthand)
	mut values := []StyleValue{cap: longhand_ids.len}
	for longhand_id in longhand_ids {
		if property_is_shorthand(longhand_id) {
			values << cssom_make_shorthand_value(longhand_id, declarations) or { return none }
			continue
		}
		mut found := false
		for declaration in declarations {
			if declaration.property_id == longhand_id {
				values << style_value_logic_from_dom(longhand_id, declaration.value) or { return none }
				found = true
				break
			}
		}
		if !found {
			return none
		}
	}
	return StyleValue(ShorthandStyleValue.create(shorthand, longhand_ids, values))
}

// https://www.w3.org/TR/cssom/#serialize-a-css-value (list overload).
fn cssom_serialize_a_css_value_list(declarations []StyleProperty) string {
	if declarations.len == 0 {
		return ''
	}
	for shorthand in cssom_shorthands_for_longhand(declarations[0].property_id) {
		expanded := cssom_expanded_longhands_for_shorthand(shorthand)
		if expanded.len != declarations.len {
			continue
		}
		mut exact_match := true
		for longhand in expanded {
			if !declarations.any(it.property_id == longhand) {
				exact_match = false
				break
			}
		}
		if !exact_match {
			continue
		}
		value := cssom_make_shorthand_value(shorthand, declarations) or { return '' }
		return value.serialize(.normal)
	}
	return ''
}

fn cssom_mark_serialized(property_id PropertyID, mut already_serialized map[PropertyID]bool) {
	already_serialized[property_id] = true
	if property_is_shorthand(property_id) {
		for longhand in longhands_for_shorthand_local(property_id) {
			cssom_mark_serialized(longhand, mut already_serialized)
		}
	}
}

// https://www.w3.org/TR/cssom/#serialize-a-css-declaration-block
fn css_style_properties_serialized(properties &CSSStyleProperties) string {
	mut declarations := []string{}
	mut already_serialized := map[PropertyID]bool{}

	// LibWeb stores custom properties separately, so they precede the ordinary
	// declaration loop exactly as in CSSStyleProperties.cpp.
	for name, property in properties.custom_properties {
		declarations << serialize_a_css_declaration(name, dom_style_value_to_css_text(property.value), property.important)
	}

	for source_property in properties.properties {
		property := cssom_style_property_as_style_property(source_property) or { continue }
		if already_serialized[property.property_id] {
			continue
		}

		for shorthand in cssom_shorthands_for_longhand(property.property_id) {
			mut longhands := []StyleProperty{}
			for candidate_source in properties.properties {
				candidate := cssom_style_property_as_style_property(candidate_source) or { continue }
				if !already_serialized[candidate.property_id] && shorthand in cssom_shorthands_for_longhand(candidate.property_id) {
					longhands << candidate
				}
			}

			required := cssom_expanded_longhands_for_shorthand(shorthand)
			mut all_required_present := true
			for required_id in required {
				if !longhands.any(it.property_id == required_id) {
					all_required_present = false
					break
				}
			}
			if !all_required_present || longhands.len == 0 {
				continue
			}

			important := longhands[0].important
			if longhands.any(it.important != important) {
				continue
			}

			first_index := cssom_style_property_index(properties, longhands[0].property_id) or { continue }
			last_index := cssom_style_property_index(properties, longhands[longhands.len - 1].property_id) or { continue }
			mut conflicts_with_logical_mapping := false
			for index in first_index .. last_index + 1 {
				between := cssom_style_property_as_style_property(properties.properties[index]) or { continue }
				if longhands.any(it.property_id == between.property_id) {
					continue
				}
				between_group := logical_property_group_for_property(between.property_id) or { continue }
				between_is_logical := property_is_logical_alias(between.property_id)
				for current in longhands {
					if current_group := logical_property_group_for_property(current.property_id) {
						if current_group == between_group && property_is_logical_alias(current.property_id) != between_is_logical {
							conflicts_with_logical_mapping = true
							break
						}
					}
				}
				if conflicts_with_logical_mapping {
					break
				}
			}
			if conflicts_with_logical_mapping {
				continue
			}

			value := cssom_serialize_a_css_value_list(longhands)
			if value.len == 0 {
				continue
			}
			declarations << serialize_a_css_declaration(string_from_property_id(shorthand), value, important)
			for longhand in longhands {
				cssom_mark_serialized(longhand.property_id, mut already_serialized)
			}
		}

		if !already_serialized[property.property_id] {
			serialized_property_id := if property_is_legacy_shorthand(property.property_id) {
				longhands_for_shorthand_local(property.property_id)[0]
			} else {
				property.property_id
			}
			declarations << serialize_a_css_declaration(string_from_property_id(serialized_property_id), properties.serialize_a_css_value(property), property.important)
			cssom_mark_serialized(property.property_id, mut already_serialized)
		}
	}
	return declarations.join(' ')
}

fn parse_css_property_declaration_block_for_style_properties(context ParsingParams, block string) &CSSStyleProperties {
	return parse_css_property_declaration_block_with_params(ParsingParams{
		document: context.document
		rule_context: [RuleContext.style]
		declared_namespaces: context.declared_namespaces.clone()
	}, block)
}

fn set_dom_inline_style_declarations(target voidptr, text string) {
	mut properties := unsafe { &CSSStyleProperties(target) }
	properties.set_declarations_from_text(text)
}

// Element::inline_style() retains one parsed CSSStyleProperties object. The DOM
// side stores it opaquely to avoid a module cycle, while all CSS consumers share
// the typed declarations just as the C++ implementation does.
fn inline_style_for_abstract_element(abstract_element dom.AbstractElement) ?&CSSStyleProperties {
	if abstract_element.pseudo_element() != none {
		return none
	}
	mut element := unsafe { &dom.Element(abstract_element.element()) }
	mut bridge := element.el_inline_style() or {
		if !element.has_attribute('style') {
			return none
		}
		element.style_for_bindings()
	}
	if bridge.css_handle != unsafe { nil } {
		return unsafe { &CSSStyleProperties(bridge.css_handle) }
	}
	text := element.get_attribute('style') or { '' }
	properties := parse_css_property_declaration_block_for_style_properties(ParsingParams{
		document: element.document()
	}, text)
	mut mutable_properties := unsafe { properties }
	mutable_properties.set_owner_node(abstract_element)
	bridge.css_handle = voidptr(properties)
	bridge.set_declarations_callback = set_dom_inline_style_declarations
	return properties
}

// Element::style(): the element's inline style declaration, created when the
// element has no style attribute yet.
pub fn element_style(element &dom.Element) &CSSStyleProperties {
	if existing := inline_style_for_element(element) {
		return existing
	}
	mut mutable_element := unsafe { &dom.Element(element) }
	mutable_element.style_for_bindings()
	return inline_style_for_element(element) or {
		panic('Element.style must provide an inline style declaration')
	}
}

pub fn inline_style_for_element(element &dom.Element) ?&CSSStyleProperties {
	return inline_style_for_abstract_element(dom.AbstractElement.new(element, none))
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
	mut builder := CSSOMDeclarationBuilder{}
	for property in properties {
		append_parsed_cssom_declaration(voidptr(&builder), property)
	}
	publish_cssom_declarations(voidptr(&builder), voidptr(declaration))
	for name, property in custom_properties {
		declaration.custom_properties[name] = property
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

$if test {
	fn css_style_properties_to_cssom_properties(properties []StyleProperty) []CSSStyleProperty {
		mut result := []CSSStyleProperty{}
		for property in properties {
			result << CSSStyleProperty{
				name: string_from_property_id(property.property_id)
				value: dom_style_value_to_css_text(property.value)
				important: property.important == .yes
				style_value: unsafe { property.value }
			}
		}
		return result
	}
}

// https://drafts.csswg.org/cssom/#concept-declarations-specified-order
pub fn convert_declarations_to_specified_order(declarations []StyleProperty) []StyleProperty {
	// The specified order for declarations is the same as specified, but with shorthand properties expanded into their
	// longhand properties, in canonical order. If a property is specified more than once (after shorthand expansion), only
	// the one with greatest cascading order must be represented, at the same relative position as it was specified.
	mut specified_order_declarations := []StyleProperty{}

	for declaration in declarations {
		for longhand in expand_property_longhands(declaration.property_id, declaration.value) {
			mut existing_entry_index := ?int(none)
			for index, existing_declaration in specified_order_declarations {
				if existing_declaration.property_id == longhand.id {
					existing_entry_index = index
					break
				}
			}

			if index := existing_entry_index {
				// If there is an existing entry for this property and it is a higher cascading order than the current entry, skip the current entry.
				if specified_order_declarations[index].important == .yes && declaration.important == .no {
					continue
				}

				// Otherwise the existing entry has a lower cascading order and is removed.
				specified_order_declarations.delete(index)
			}

			specified_order_declarations << StyleProperty{
				important: declaration.important
				property_id: longhand.id
				value: unsafe { longhand.value }
			}
		}
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
		mut bridge := element.style_for_bindings()
		bridge.is_updating_ = true
		element.set_attribute_value('style', css_style_properties_serialized(properties))
		bridge.is_updating_ = false
	}

	// 6. Unset declaration block's updating flag.
	properties.set_is_updating(false)
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-csstext
pub fn (properties &CSSStyleProperties) css_text() string {
	properties.ensure_declarations_parsed()
	// 1. If the computed flag is set, then return the empty string.
	if properties.is_computed() {
		return ''
	}

	// 2. Return the result of serializing the declarations.
	return css_style_properties_serialized(properties)
}

pub fn (properties &CSSStyleProperties) item(index uint) string {
	properties.ensure_declarations_parsed()
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

pub fn (properties &CSSStyleProperties) item_value(index uint) ?string {
	properties.ensure_declarations_parsed()
	value := properties.item(index)
	if value.len == 0 {
		return none
	}
	return value
}

pub fn (properties &CSSStyleProperties) get_property(property_id PropertyID) ?StyleProperty {
	properties.ensure_declarations_parsed()
	return properties.get_property_internal(PropertyNameAndID.from_id(property_id))
}

fn computed_custom_property_for_cssom(owner dom.AbstractElement, name string) ?&dom.CSSStyleValue_ {
	element := owner.element()
	if element.as_node().is_connected() && owner.document().get_browsing_context() != none {
		mut document := unsafe { &dom.Document(owner.document()) }
		mut computer := css_style_computer_for(document)
		if document.element_needs_style_update(element) { document.update_style() }
		computer.materialize_hidden_styles_for_query(element)
	}
	if value := owner.get_custom_property(name) {
		return value
	}
	// A pseudo without its own custom-property data still inherits from its
	// originating element (including values supplied through ::slotted()).
	if owner.pseudo_element() != none {
		if inherit_from := owner.element_to_inherit_style_from() {
			return inherit_from.get_custom_property(name)
		}
	}
	return none
}

pub fn (properties &CSSStyleProperties) custom_property(custom_property_name string) ?StyleProperty {
	properties.ensure_declarations_parsed()
	if properties.is_computed() {
		owner := properties.owner_node or { return none }
		value := computed_custom_property_for_cssom(owner, custom_property_name) or {
			initial_value := owner.document().custom_property_initial_value(custom_property_name) or {
				return none
			}
			return StyleProperty{
				property_id: .color
				value: parse_custom_property_value(initial_value)
			}
		}
		if value.guaranteed_invalid {
			return none
		}
		retained_value := dom_style_value_from_custom_property_bridge(value) or {
			parse_custom_property_value(value.css_text)
		}
		return StyleProperty{
			property_id: .color
			value: retained_value
		}
	}

	if value := properties.custom_properties[custom_property_name] {
		return value
	}
	return none
}

// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-setproperty
pub fn (mut properties CSSStyleProperties) set_property(property_name string, value string, priority string) ! {
	properties.ensure_declarations_parsed()
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
	properties.ensure_declarations_parsed()
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
		if !is_valid_optional_declaration_value(parse_component_values_for_value_logic(value)) {
			return
		}
		properties.custom_properties[property.name()] = StyleProperty{
			important: if priority.len != 0 { Important.yes } else { Important.no }
			property_id: .color
			value: parse_custom_property_value(value)
		}
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
		for longhand in expand_property_longhands(property_id, component_value_list) {
			// 1. Let longhand result be the result of set the CSS declaration longhand with the appropriate value(s) from component value list,
			//    with the important flag set if priority is not the empty string, and unset otherwise, and with the list of declarations being the declarations.
			// 2. If longhand result is true, let updated be true.
			updated = properties.set_a_css_declaration(longhand.id, longhand.value, if priority.len != 0 {
				Important.yes
			} else {
				Important.no
			}) || updated
		}
	} else {
		// 9. Otherwise,
		// let updated be the result of set the CSS declaration property with value component value list,
		// with the important flag set if priority is not the empty string, and unset otherwise,
		// and with the list of declarations being the declarations.
		updated = properties.set_a_css_declaration_with_serialized(property_id, component_value_list, if priority.len != 0 {
			Important.yes
		} else {
			Important.no
		}, value)
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

// CSSStyleProperties::set_property_style_value(). This is the typed-OM entry
// point: keep the parsed StyleValue graph and expand shorthands directly,
// without serializing and reparsing it through set_property().
pub fn (mut properties CSSStyleProperties) set_property_style_value(property PropertyNameAndID, style_value &dom.StyleValue) ! {
	properties.ensure_declarations_parsed()
	if properties.is_computed() {
		return error('NoModificationAllowedError: Cannot modify properties in result of getComputedStyle()')
	}

	if property.is_custom_property() {
		properties.custom_properties.delete(property.name())
		properties.custom_properties[property.name()] = StyleProperty{
			property_id: .color
			value: unsafe { style_value }
		}
		properties.update_style_attribute()
		properties.invalidate_owners(.style_sheet_changed)
		return
	}
	properties.clear_typed_properties_cache()

	property_id := property.id() or { return }
	typed := style_value_logic_from_dom(property_id, style_value) or {
		return error("Setting ${property.name()} to '${style_value.css_text}' is not allowed.")
	}
	if property_is_positional_value_list_shorthand(property_id) && typed !is ShorthandStyleValue && typed !is UnresolvedStyleValue && typed !is PendingSubstitutionStyleValue && typed !is GuaranteedInvalidStyleValue && !typed.is_css_wide_keyword() {
		return error("Setting ${property.name()} to '${typed.serialize(.normal)}' is not allowed.")
	}

	for longhand in expand_property_longhands(property_id, style_value) {
		for index, existing in properties.properties {
			if existing.name == string_from_property_id(longhand.id) {
				properties.properties.delete(index)
				break
			}
		}
		properties.properties << CSSStyleProperty{
			name: string_from_property_id(longhand.id)
			value: dom_style_value_to_css_text(longhand.value)
			style_value: unsafe { longhand.value }
		}
	}

	properties.update_style_attribute()
	properties.invalidate_owners(.style_sheet_changed)
}

pub fn (mut properties CSSStyleProperties) set_a_css_declaration(property_id PropertyID, value &dom.StyleValue, important Important) bool {
	properties.ensure_declarations_parsed()
	return properties.set_a_css_declaration_with_serialized(property_id, value, important, dom_style_value_to_css_text(value))
}

fn (mut properties CSSStyleProperties) set_a_css_declaration_with_serialized(property_id PropertyID, value &dom.StyleValue, important Important, serialized_value string) bool {
	new_property := CSSStyleProperty{
		name: string_from_property_id(property_id)
		value: serialized_value
		important: important == .yes
		style_value: unsafe { value }
	}

	for index, property in properties.properties {
		if property.name == new_property.name {
			mut needs_append := false
			if group := logical_property_group_for_property(property_id) {
				is_logical_alias := property_is_logical_alias(property_id)
				for later_property in properties.properties[index + 1..] {
					later_property_id := property_id_from_string(later_property.name) or {
						continue
					}
					if later_group := logical_property_group_for_property(later_property_id) {
						if later_group == group && property_is_logical_alias(later_property_id) != is_logical_alias {
							needs_append = true
							break
						}
					}
				}
			}

			if !needs_append {
				if property.important == new_property.important && property.value == new_property.value {
					return false
				}
				properties.clear_typed_properties_cache()
				properties.properties[index] = new_property
				return true
			}

			properties.properties.delete(index)
			break
		}
	}

	properties.clear_typed_properties_cache()
	properties.properties << new_property
	return true
}

pub fn (mut properties CSSStyleProperties) remove_property(property_name string) !string {
	properties.ensure_declarations_parsed()
	property := css_style_property_name_and_id_from_name(property_name) or { return '' }
	return properties.remove_property_internal(property)!
}

pub fn (mut properties CSSStyleProperties) remove_property_internal(property PropertyNameAndID) !string {
	properties.ensure_declarations_parsed()
	if properties.is_readonly() {
		return error('NoModificationAllowedError: Cannot modify readonly CSSStyleProperties')
	}

	mut removed := false
	mut removed_value := ''
	if property.is_custom_property() {
		if value := properties.custom_properties[property.name()] {
			removed_value = dom_style_value_to_css_text(value.value)
			properties.custom_properties.delete(property.name())
			removed = true
		}
	} else {
		property_name := string_from_property_id(property.id() or { PropertyID.color })
		for index, existing in properties.properties {
			if existing.name == property_name {
				properties.clear_typed_properties_cache()
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
	properties.ensure_declarations_parsed()
	if properties.is_readonly() {
		return error('NoModificationAllowedError: Cannot modify readonly CSSStyleProperties')
	}
	properties.set_declarations_from_text(css_text)
	properties.update_style_attribute()
	properties.invalidate_owners(.style_sheet_changed)
}

// CSSStyleProperties::empty_the_declarations().
pub fn (mut properties CSSStyleProperties) empty_the_declarations() {
	properties.ensure_declarations_parsed()
	properties.clear_typed_properties_cache()
	properties.properties.clear()
	properties.custom_properties.clear()
}

// CSSStyleProperties::set_the_declarations(). Parsed declarations are put in
// specified order, expanding shorthands and retaining only the winner at its
// specified relative position.
pub fn (mut properties CSSStyleProperties) set_the_declarations(property_values []StyleProperty, custom_property_values map[string]StyleProperty) {
	properties.ensure_declarations_parsed()
	properties.clear_typed_properties_cache()
	mut builder := CSSOMDeclarationBuilder{}
	for property in property_values {
		append_parsed_cssom_declaration(voidptr(&builder), property)
	}
	publish_cssom_declarations(voidptr(&builder), voidptr(properties))
	properties.custom_properties.clear()
	for name, property in custom_property_values {
		properties.custom_properties[name] = property
	}
}

// CSSStyleProperties::set_declarations_from_text().
pub fn (mut properties CSSStyleProperties) set_declarations_from_text(css_text string) {
	properties.ensure_declarations_parsed()
	properties.empty_the_declarations()
	context := if owner_node := properties.owner_node {
		ParsingParams{
			document: owner_node.element().document()
		}
	} else {
		ParsingParams{}
	}
	parsed := parse_css_property_declaration_block_for_style_properties(context, css_text)
	properties.clear_typed_properties_cache()
	properties.properties = parsed.properties.clone()
	properties.custom_properties = parsed.custom_properties.clone()
}

pub fn (properties &CSSStyleProperties) get_property_internal(property PropertyNameAndID) ?StyleProperty {
	properties.ensure_declarations_parsed()
	if property.is_custom_property() {
		return properties.get_direct_property(property)
	}

	// https://drafts.csswg.org/cssom/#dom-cssstyledeclaration-getpropertyvalue
	// A shorthand is observable only when every component longhand exists and
	// has the same importance. Reconstruct the same retained
	// ShorthandStyleValue as CSSStyleProperties.cpp instead of returning the
	// first serialized declaration that happens to share its name.
	property_id := property.id() or { return none }
	if property_is_shorthand(property_id) {
		longhand_ids := longhands_for_shorthand_local(property_id)
		mut longhand_values := []StyleValue{cap: longhand_ids.len}
		mut important := ?Important(none)
		for longhand_id in longhand_ids {
			declaration := properties.get_property_internal(PropertyNameAndID.from_id(longhand_id)) or {
				return none
			}
			if previous := important {
				if previous != declaration.important {
					return none
				}
			} else {
				important = declaration.important
			}
			value := style_value_logic_from_dom(longhand_id, declaration.value) or { return none }
			longhand_values << value
		}

		// CSS Values 5 pending-substitution serialization. All component
		// longhands created from one unresolved shorthand retain the same
		// original value. V value sums preserve that value rather than a C++
		// RefPtr, so structural equality is the corresponding identity test.
		if longhand_values.len > 0 && longhand_values[0] is PendingSubstitutionStyleValue {
			first_pending := longhand_values[0] as PendingSubstitutionStyleValue
			original := first_pending.original_shorthand_value_ref()
			mut all_from_same_original := true
			for value in longhand_values {
				if value !is PendingSubstitutionStyleValue {
					all_from_same_original = false
					break
				}
				pending := value as PendingSubstitutionStyleValue
				if !pending.original_shorthand_value_ref().equals(original) {
					all_from_same_original = false
					break
				}
			}
			if all_from_same_original {
				return StyleProperty{
					important: important or { Important.no }
					property_id: property_id
					value: dom_style_value_from_value_logic(original)
				}
			}
		}
		for value in longhand_values {
			if value is PendingSubstitutionStyleValue || value is UnresolvedStyleValue {
				return none
			}
		}

		return StyleProperty{
			important: important or { Important.no }
			property_id: property_id
			value: dom_style_value_from_value_logic(StyleValue(ShorthandStyleValue.create(property_id, longhand_ids, longhand_values)))
		}
	}

	return properties.get_direct_property(property)
}

// CSSStyleProperties::get_direct_property().
pub fn (properties &CSSStyleProperties) get_direct_property(property PropertyNameAndID) ?StyleProperty {
	properties.ensure_declarations_parsed()
	if properties.is_computed() {
		owner := properties.owner_node or { return none }
		element := owner.element()
		if !element.is_connected() {
			return none
		}
		mut document := unsafe { &dom.Document(owner.document()) }
		if document.get_browsing_context() == none {
			return none
		}

		// Ensure Document::update_style() reaches the translated StyleComputer.
		mut style_computer := css_style_computer_for(document)
		if property.is_custom_property() {
			if document.element_needs_style_update(element) {
				document.update_style()
			}
			style_computer.materialize_hidden_styles_for_query(element)
			return properties.custom_property(property.name())
		}

		property_id := property.id() or { return none }
		needs_layout := generated_property_needs_layout_for_getcomputedstyle(property_id)
		needs_layout_node := generated_property_needs_layout_node_for_resolved_value(property_id) || property_is_logical_alias(property_id) || property_is_shorthand(property_id)
		scope := css_style_scope_for(owner)
		needs_container_query_layout := scope.have_size_container_queries()
			&& element.style_depends_on_size_container_query()
			&& !document.layout_is_up_to_date()
		if needs_layout || needs_layout_node || needs_container_query_layout {
			document.update_layout(.resolved_css_style_declaration_property)
		} else if document.element_needs_style_update(element) {
			document.update_style()
		}

		style_computer.materialize_hidden_styles_for_query(element)
		layout_node_with_style := owner.layout_node() or {
			// Ordinary elements retain their completed style even without a box.
			// A flush callback can dirty that record again, and synthetic pseudos
			// still need the one-off computation with their ancestor chain seeded.
			computed := if owner.pseudo_element() == none
				&& !document.element_needs_style_update(element) {
				computed_properties_for_element(element) or {
					style_computer.compute_style_with_seeded_ancestors(owner)
				}
			} else {
				style_computer.compute_style_with_seeded_ancestors(owner)
			}
			value := computed.property(property_id, .yes) or { return none }
			return StyleProperty{
				property_id: property_id
				value: value
			}
		}
		layout_node := layout_node_with_style.layout_node_ or { return none }
		value := properties.style_value_for_computed_property(layout_node, property_id) or {
			return none
		}
		return StyleProperty{
			property_id: property_id
			value: value
		}
	}
	property_name := string_from_property_id(property.id() or { return none })
	for existing in properties.properties {
		if existing.name == property_name {
			return StyleProperty{
				important: if existing.important { Important.yes } else { Important.no }
				property_id: property.id() or { PropertyID.color }
				value: existing.style_value or {
					css_style_properties_empty_dom_style_value()
				}
			}
		}
	}
	return none
}

fn cssom_style_value_for_px(value f64) &dom.StyleValue {
	return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(value))))
}

fn cssom_style_value_for_length_percentage(value LengthPercentage) &dom.StyleValue {
	if value.is_percentage() {
		return dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(value.percentage())))
	}
	if value.is_length() {
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(value.length())))
	}
	return dom_style_value_from_value_logic(StyleValue(value.calculated()))
}

fn cssom_style_value_for_length_percentage_or_auto(value LengthPercentageOrAuto) &dom.StyleValue {
	if value.is_auto() {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto)))
	}
	return cssom_style_value_for_length_percentage(value.length_percentage())
}

fn cssom_style_value_for_size(value Size) &dom.StyleValue {
	if value.is_none() {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_)))
	}
	if value.is_percentage() {
		return dom_style_value_from_value_logic(StyleValue(PercentageStyleValue.create(value.percentage())))
	}
	if value.is_length() {
		return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(value.length())))
	}
	if value.is_auto() {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto)))
	}
	if value.is_calculated() {
		return dom_style_value_from_value_logic(StyleValue(value.calculated()))
	}
	if value.is_min_content() {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.min_content)))
	}
	if value.is_max_content() {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.max_content)))
	}
	if value.is_fit_content() {
		if available_space := value.fit_content_available_space() {
			return dom_style_value_from_value_logic(StyleValue(FunctionStyleValue.create('fit-content', style_value_logic_for_length_percentage(available_space))))
		}
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.fit_content)))
	}
	return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.auto)))
}

fn style_value_logic_for_length_percentage(value LengthPercentage) StyleValue {
	if value.is_percentage() {
		return StyleValue(PercentageStyleValue.create(value.percentage()))
	}
	if value.is_length() {
		return StyleValue(LengthStyleValue.create(value.length()))
	}
	return StyleValue(value.calculated())
}

fn cssom_resolve_color_style_value(style_value &dom.StyleValue, context ColorResolutionContext) &dom.StyleValue {
	typed := style_value_logic_from_dom(.color, style_value) or { return unsafe { style_value } }
	if typed is ColorFunctionStyleValue || typed is LabColorStyleValue || typed is OKLabColorStyleValue || typed is LCHColorStyleValue || typed is OKLCHColorStyleValue {
		if !is_relative_color(typed) {
			return unsafe { style_value }
		}
	}
	if is_missing_component_form(typed) {
		return unsafe { style_value }
	}
	if resolved := cssom_resolve_typed_color(typed, context) {
		return dom_style_value_from_value_logic(resolved)
	}
	color := typed.to_color(context) or { return unsafe { style_value } }
	return dom_style_value_from_value_logic(StyleValue(ColorStyleValue.create_from_color(color, .modern, none)))
}

// The resolved value of a color that keeps a form of its own: a relative
// color, which only resolves with the current color of its use, and the
// branch light-dark() selects.
fn cssom_resolve_typed_color(typed StyleValue, context ColorResolutionContext) ?StyleValue {
	if typed is LightDarkStyleValue {
		dark := if scheme := context.color_scheme { scheme == .dark } else { false }
		branch := if dark { typed.dark[0] } else { typed.light[0] }
		resolved := cssom_resolve_typed_color(branch.absolutized(ComputationContext{
			color_scheme: context.color_scheme
		}), context) or {
			color := branch.to_color(context)?
			return StyleValue(ColorStyleValue.create_from_color(color, .modern, none))
		}
		return resolved
	}
	if is_relative_color(typed) {
		resolved := resolve_relative_color_for_use(typed, context)
		if is_relative_color(resolved) {
			return none
		}
		return cssom_resolve_typed_color(resolved, context) or { resolved }
	}
	if typed is ColorFunctionStyleValue || typed is LabColorStyleValue || typed is OKLabColorStyleValue
		|| typed is LCHColorStyleValue || typed is OKLCHColorStyleValue || is_missing_component_form(typed) {
		return typed
	}
	return none
}

fn cssom_style_value_for_shadow(shadow_type ShadowType, shadows []ShadowData) &dom.StyleValue {
	if shadows.len == 0 {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_)))
	}
	mut values := []StyleValue{cap: shadows.len}
	for shadow in shadows {
		color := Color.rgba(shadow.color.red(), shadow.color.green(), shadow.color.blue(), shadow.color.alpha())
		values << StyleValue(ShadowStyleValue.create(shadow_type, StyleValue(ColorStyleValue.create_from_color(color, .modern, none)), StyleValue(LengthStyleValue.create(shadow.offset_x)), StyleValue(LengthStyleValue.create(shadow.offset_y)), StyleValue(LengthStyleValue.create(shadow.blur_radius)), StyleValue(LengthStyleValue.create(shadow.spread_distance)), if shadow.inset {
			ShadowPlacement.inner
		} else {
			ShadowPlacement.outer
		}))
	}
	if values.len == 1 {
		return dom_style_value_from_value_logic(values[0])
	}
	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(values, .comma, .yes)))
}

fn cssom_multiply_transform_matrices(left FloatMatrix4x4, right FloatMatrix4x4) FloatMatrix4x4 {
	mut values := [16]f64{}
	for row in 0 .. 4 {
		for column in 0 .. 4 {
			mut value := 0.0
			for index in 0 .. 4 {
				value += left.at(row, index) * right.at(index, column)
			}
			values[row * 4 + column] = value
		}
	}
	return FloatMatrix4x4.from_values(values[0], values[1], values[2], values[3], values[4], values[5], values[6], values[7], values[8], values[9], values[10], values[11], values[12], values[13], values[14], values[15])
}

// "For grid-template-columns and grid-template-rows the resolved value is the
// used value." The grid formatting context records the final track base sizes;
// a box that never ran one has none, and falls back to the computed value.
fn cssom_resolved_grid_template(used_track_sizes []f64, line_names [][]string, is_subgrid bool) ?&dom.StyleValue {
	if used_track_sizes.len == 0 {
		return none
	}
	mut track_size_list := if is_subgrid {
		GridTrackSizeList.make_subgrid()
	} else {
		GridTrackSizeList{}
	}
	for index in 0 .. used_track_sizes.len + 1 {
		if index < line_names.len && (line_names[index].len > 0 || is_subgrid) {
			mut names := GridLineNames{}
			for name in line_names[index] {
				names.append(name)
			}
			track_size_list.append_line_names(names)
		}
		if index < used_track_sizes.len && !is_subgrid {
			track_size_list.append_explicit_track(ExplicitGridTrack.from_grid_size(GridSize.from_size(Size.make_px(CSSPixels.nearest_value_for(used_track_sizes[index])))))
		}
	}
	return dom_style_value_from_value_logic(StyleValue(GridTrackSizeListStyleValue.create(track_size_list)))
}

fn cssom_resolved_transform(computed &ComputedProperties, layout_node &dom.LayoutNode) ?&dom.StyleValue {
	computed_value := computed.property(.transform, .yes) or { return none }
	parsed := style_value_logic_from_dom(.transform, computed_value) or { return none }
	if parsed.to_keyword() == .none_ {
		return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.none_)))
	}
	mut transformations := []TransformationStyleValue{}
	if parsed is TransformationStyleValue {
		transformations << parsed
	} else if parsed is StyleValueList {
		for value in parsed.values() {
			if value !is TransformationStyleValue {
				return none
			}
			transformations << (value as TransformationStyleValue)
		}
	} else {
		return none
	}

	paintable_box := TransformPaintableBox{
		reference_box: TransformReferenceBox{
			width: CSSPixels.nearest_value_for(layout_node.border_box_.width / if node := layout_node.dom_node() { node.document().layout_coordinate_scale() } else { 1.0 })
			height: CSSPixels.nearest_value_for(layout_node.border_box_.height / if node := layout_node.dom_node() { node.document().layout_coordinate_scale() } else { 1.0 })
		}
		length_resolution_context: length_resolution_context_from_layout_node(layout_node) or {
			LengthResolutionContext.default()
		}
	}
	mut transform := FloatMatrix4x4.identity()
	for transformation in transformations {
		matrix := transformation.to_matrix(paintable_box) or { return none }
		transform = cssom_multiply_transform_matrices(transform, matrix)
	}

	epsilon := 1.1920929e-7
	is_2d := math.abs(transform.at(0, 2)) <= epsilon && math.abs(transform.at(1, 2)) <= epsilon && math.abs(transform.at(2, 0)) <= epsilon && math.abs(transform.at(2, 1)) <= epsilon && math.abs(transform.at(2, 3)) <= epsilon && math.abs(transform.at(3, 0)) <= epsilon && math.abs(transform.at(3, 1)) <= epsilon && math.abs(transform.at(3, 2)) <= epsilon && math.abs(math.abs(transform.at(2, 2)) - 1) <= epsilon && math.abs(math.abs(transform.at(3, 3)) - 1) <= epsilon
	if is_2d {
		return dom_style_value_from_value_logic(StyleValue(TransformationStyleValue.create(.transform, .matrix, [
			StyleValue(NumberStyleValue.create(transform.at(0, 0))),
			StyleValue(NumberStyleValue.create(transform.at(1, 0))),
			StyleValue(NumberStyleValue.create(transform.at(0, 1))),
			StyleValue(NumberStyleValue.create(transform.at(1, 1))),
			StyleValue(NumberStyleValue.create(transform.at(0, 3))),
			StyleValue(NumberStyleValue.create(transform.at(1, 3))),
		])))
	}
	mut values := []StyleValue{cap: 16}
	for column in 0 .. 4 {
		for row in 0 .. 4 {
			values << StyleValue(NumberStyleValue.create(transform.at(row, column)))
		}
	}
	return dom_style_value_from_value_logic(StyleValue(TransformationStyleValue.create(.transform, .matrix3d, values)))
}

fn cssom_resolved_animation_duration(computed &ComputedProperties) ?&dom.StyleValue {
	timeline_value := computed.property(.animation_timeline, .yes) or { return none }
	duration_value := computed.property(.animation_duration, .yes) or { return none }
	timeline := style_value_logic_from_dom(.animation_timeline, timeline_value) or { return none }
	duration := style_value_logic_from_dom(.animation_duration, duration_value) or { return none }
	if timeline !is StyleValueList || duration !is StyleValueList {
		return unsafe { duration_value }
	}
	timeline_list := timeline as StyleValueList
	duration_list := duration as StyleValueList
	if timeline_list.size() != 1 || timeline_list.values()[0].to_keyword() != .auto {
		return unsafe { duration_value }
	}
	mut resolved := []StyleValue{cap: duration_list.size()}
	for value in duration_list.values() {
		if value.to_keyword() == .auto {
			resolved << StyleValue(TimeStyleValue.create(Time.make_seconds(0)))
		} else {
			resolved << value
		}
	}
	return dom_style_value_from_value_logic(StyleValue(StyleValueList.create(resolved, .comma, .yes)))
}

fn cssom_resolved_border_width(computed &ComputedProperties, width_property PropertyID, style_property PropertyID) &dom.StyleValue {
	if style := computed.property(style_property, .yes) {
		keyword := computed_interpolation_style_value_keyword(style) or { Keyword.invalid }
		if keyword in [.none_, .hidden] {
			return cssom_style_value_for_px(0)
		}
	}
	length := computed.length(width_property)
	return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(length)))
}

// CSSStyleProperties::style_value_for_computed_property(). This is the CSSOM
// resolved-value algorithm, consuming the geometry mirrored by
// layout/dom_layout_bridge.v instead of a second independently computed box.
pub fn (properties &CSSStyleProperties) style_value_for_computed_property(layout_node &dom.LayoutNode, property_id PropertyID) ?&dom.StyleValue {
	owner := properties.owner_node or { return none }
	dom_computed := owner.computed_properties() or { return none }
	computed := computed_properties_from_dom(dom_computed) or { return none }

	if property_is_logical_alias(property_id) {
		physical := map_logical_alias_to_physical_property(property_id, LogicalAliasMappingContext{
			writing_mode: computed.writing_mode()
			direction: computed.direction()
		})
		return properties.style_value_for_computed_property(layout_node, physical)
	}

	display_allows_used_value := !computed.display().is_none() && !computed.display().is_contents() && layout_node.has_geometry_
	margin := computed.length_box(.margin_left, .margin_top, .margin_right, .margin_bottom, LengthPercentageOrAuto.make_auto())
	padding := computed.length_box(.padding_left, .padding_top, .padding_right, .padding_bottom, LengthPercentageOrAuto.from_length(Length.make_px(0)))
	inset := computed.length_box(.left, .top, .right, .bottom, LengthPercentageOrAuto.make_auto())

	match property_id {
		.background_color, .border_bottom_color, .border_left_color, .border_right_color, .border_top_color, .caret_color, .color, .column_rule_color, .outline_color, .text_decoration_color, .webkit_text_fill_color {
			value := computed.property(property_id, .yes) or { return none }
			return cssom_resolve_color_style_value(value, color_resolution_context_for_layout_node(layout_node))
		}
		.box_shadow {
			return cssom_style_value_for_shadow(.normal, computed.box_shadow(layout_node))
		}
		.text_shadow {
			return cssom_style_value_for_shadow(.text, computed.text_shadow(layout_node))
		}
		.line_height {
			value := computed.property(property_id, .yes) or { return none }
			if keyword := computed_interpolation_style_value_keyword(value) {
				if keyword == .normal {
					return value
				}
			}
			return cssom_style_value_for_px(computed.line_height().to_double())
		}
		.height {
			if display_allows_used_value {
				used := if computed.box_sizing() == .border_box {
					layout_node.border_box_.height
				} else {
					layout_node.content_height_
				}
				return cssom_style_value_for_px(used / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_size(computed.size_value(.height))
		}
		.width {
			if display_allows_used_value {
				used := if computed.box_sizing() == .border_box {
					layout_node.border_box_.width
				} else {
					layout_node.content_width_
				}
				return cssom_style_value_for_px(used / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_size(computed.size_value(.width))
		}
		.margin_bottom {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().margin_bottom / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(margin.bottom())
		}
		.margin_left {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().margin_left / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(margin.left())
		}
		.margin_right {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().margin_right / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(margin.right())
		}
		.margin_top {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().margin_top / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(margin.top())
		}
		.padding_bottom {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().padding_bottom / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(padding.bottom())
		}
		.padding_left {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().padding_left / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(padding.left())
		}
		.padding_right {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().padding_right / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(padding.right())
		}
		.padding_top {
			if display_allows_used_value {
				return cssom_style_value_for_px(layout_node.box_model().padding_top / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(padding.top())
		}
		.bottom {
			if cssom_should_use_resolved_inset(layout_node, inset.bottom(), inset.top()) {
				return cssom_style_value_for_px(layout_node.box_model().inset_bottom / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(inset.bottom())
		}
		.left {
			if cssom_should_use_resolved_inset(layout_node, inset.left(), inset.right()) {
				return cssom_style_value_for_px(layout_node.box_model().inset_left / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(inset.left())
		}
		.right {
			if cssom_should_use_resolved_inset(layout_node, inset.right(), inset.left()) {
				return cssom_style_value_for_px(layout_node.box_model().inset_right / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(inset.right())
		}
		.top {
			if cssom_should_use_resolved_inset(layout_node, inset.top(), inset.bottom()) {
				return cssom_style_value_for_px(layout_node.box_model().inset_top / owner.document().layout_coordinate_scale())
			}
			return cssom_style_value_for_length_percentage_or_auto(inset.top())
		}
		.grid_template_columns {
			grid := layout_node.used_grid_data()
			if resolved := cssom_resolved_grid_template(grid.columns,
				grid.column_line_names, grid.columns_are_subgrid) {
				return resolved
			}
		}
		.grid_template_rows {
			grid := layout_node.used_grid_data()
			if resolved := cssom_resolved_grid_template(grid.rows,
				grid.row_line_names, grid.rows_are_subgrid) {
				return resolved
			}
		}
		.transform {
			return cssom_resolved_transform(computed, layout_node)
		}
		.animation_duration {
			return cssom_resolved_animation_duration(computed)
		}
		.border_bottom_width {
			return cssom_resolved_border_width(computed, .border_bottom_width, .border_bottom_style)
		}
		.border_left_width {
			return cssom_resolved_border_width(computed, .border_left_width, .border_left_style)
		}
		.border_right_width {
			return cssom_resolved_border_width(computed, .border_right_width, .border_right_style)
		}
		.border_top_width {
			return cssom_resolved_border_width(computed, .border_top_width, .border_top_style)
		}
		.contain {
			containment := computed.contain()
			if containment.layout_containment && containment.style_containment && containment.paint_containment {
				if containment.size_containment {
					return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.strict)))
				}
				if !containment.inline_size_containment {
					return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.content)))
				}
			}
		}
		.letter_spacing {
			if computed.letter_spacing().to_double() == 0 {
				return dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.normal)))
			}
		}
		.z_index {
			if z_index := computed.z_index() {
				return dom_style_value_from_value_logic(StyleValue(NumberStyleValue.create(z_index)))
			}
		}
		else {}
	}

	if !property_is_shorthand(property_id) {
		return computed.property(property_id, .yes)
	}
	longhand_ids := longhands_for_shorthand_local(property_id)
	mut values := []StyleValue{cap: longhand_ids.len}
	for longhand_id in longhand_ids {
		longhand := properties.style_value_for_computed_property(layout_node, longhand_id) or {
			return none
		}
		values << (style_value_logic_from_dom(longhand_id, longhand) or { return none })
	}
	return dom_style_value_from_value_logic(StyleValue(ShorthandStyleValue.create(property_id, longhand_ids, values)))
}

fn cssom_should_use_resolved_inset(layout_node &dom.LayoutNode, start LengthPercentageOrAuto, end LengthPercentageOrAuto) bool {
	if !layout_node.is_positioned_ || layout_node.is_sticky_position_ || !layout_node.has_geometry_ {
		return false
	}
	return start.is_percentage() || start.is_calculated() || start.is_auto() || end.is_auto()
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
	properties.ensure_declarations_parsed()
	property := css_style_property_name_and_id_from_name(property_name) or { return '' }
	if property.is_custom_property() {
		if properties.is_computed() {
			custom := properties.custom_property(property.name()) or { return '' }
			return dom_style_value_to_css_text(custom.value)
		}
		if value := properties.custom_properties[property.name()] {
			return dom_style_value_to_css_text(value.value)
		}
		return ''
	}
	if style_property := properties.get_property_internal(property) {
		return properties.serialize_a_css_value(style_property)
	}
	return ''
}

// https://www.w3.org/TR/cssom/#serialize-a-css-value
pub fn (properties &CSSStyleProperties) serialize_a_css_value(declaration StyleProperty) string {
	if typed := typed_style_value_logic_from_dom(declaration.value) {
		return typed.serialize(if properties.is_computed() {
			SerializationMode.resolved_value
		} else {
			SerializationMode.normal
		})
	}
	return declaration.value.css_text
}

// CSSStyleProperties::css_float()/set_css_float().
pub fn (properties &CSSStyleProperties) css_float() string {
	return properties.get_property_value('float')
}

pub fn (mut properties CSSStyleProperties) set_css_float(value string) ! {
	properties.set_property('float', value, '')!
}

pub fn (properties &CSSStyleProperties) custom_property_count() uint {
	properties.ensure_declarations_parsed()
	return uint(properties.custom_properties.len)
}

pub fn (properties &CSSStyleProperties) property_priority(property_name string) string {
	properties.ensure_declarations_parsed()
	property := css_style_property_name_and_id_from_name(property_name) or { return '' }
	if property.is_custom_property() {
		if value := properties.custom_properties[property.name()] {
			if value.important == .yes {
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
	properties.ensure_declarations_parsed()
	return properties.property_value(property_name)
}

pub fn (properties &CSSStyleProperties) get_property_priority(property_name string) string {
	properties.ensure_declarations_parsed()
	return properties.property_priority(property_name)
}

fn (properties &CSSStyleProperties) invalidate_owners(reason StyleInvalidationReason) {
	mapped_reason := css_style_declarations_to_dom_invalidation_reason(reason)
	if owner_node := properties.owner_node {
		mut node := unsafe { &dom.Node(owner_node.element()) }
		node.invalidate_style(mapped_reason)
	}
	if parent_rule := properties.parent_rule {
		if parent_style_sheet := parent_rule.parent_style_sheet {
			if parent_rule.type_ in [.style, .nested_declarations] {
				invalidate_style_for_style_sheet_owners(parent_style_sheet, mapped_reason, .no, none)
				return
			}
			mut mutable_parent_style_sheet := unsafe { &CSSStyleSheet(parent_style_sheet) }
			mutable_parent_style_sheet.invalidate_owners(mapped_reason)
		}
	}
}

fn css_style_declarations_to_dom_invalidation_reason(reason StyleInvalidationReason) dom.StyleInvalidationReason {
	return match reason {
		.base_url_changed { dom.StyleInvalidationReason.base_url_changed }
		.hover_changed, .style_sheet_changed, .dom_mutation {
			dom.StyleInvalidationReason.style_change
		}
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
			reified_values := reify_serialized_style_map_value(property, property_value.css_text, false)
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
		return [
			StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic(serialized_value))).reify(property.name()),
		]
	}
	if property_value := property_map.get_style_value(property) {
		if property_value.css_text.len > 0 {
			reified_values := reify_serialized_style_map_value(property, property_value.css_text, true)
			if reified_values.len > 0 {
				return reified_values
			}
			return [
				StyleValue(UnresolvedStyleValue.create(parse_component_values_for_value_logic(property_value.css_text))).reify(property.name()),
			]
		}
		return [
			StyleValue(UnresolvedStyleValue.create([]ComponentValue{})).reify(property.name()),
		]
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
			for name, _ in data.all_values() {
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
	if element := property_map.element {
		if property.is_custom_property() {
			value := element.get_custom_property(property.name()) or {
				initial_value := element.document().custom_property_initial_value(property.name()) or {
					return none
				}
				return &dom.StyleValue{
					css_text: initial_value
				}
			}
			if value.guaranteed_invalid {
				return none
			}
			return &dom.StyleValue{
				css_text: value.css_text
			}
		}
		property_id := property.id() or { return none }
		dom_computed := element.computed_properties() or { return none }
		computed := computed_properties_from_dom(dom_computed) or { return none }
		return computed.property(property_id, .yes)
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
				return dom_style_value_to_css_text(value.value)
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
		props.custom_properties[property.name()] = StyleProperty{
			property_id: .color
			value: parse_custom_property_value(serialized_values.join(', '))
		}
		props.update_style_attribute()
		props.invalidate_owners(.style_sheet_changed)
	} else if values_to_set.len == 1 {
		props.set_a_css_declaration_with_serialized(property.id() or { PropertyID.color }, values_to_set[0], .no, serialized_values[0])
		props.update_style_attribute()
		props.invalidate_owners(.style_sheet_changed)
	} else {
		props.set_a_css_declaration_with_serialized(property.id() or { PropertyID.color }, css_style_properties_empty_dom_style_value(), .no, serialized_values.join(', '))
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
	props.set_a_css_declaration_with_serialized(property.id() or { PropertyID.color }, css_style_properties_empty_dom_style_value(), .no, serialized_value)
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
