module css

// Uniform state used by the upstream parser entry-point facade. Individual
// grammar algorithms remain in parser_value_logic.v and
// parser_rules_selectors.v; this record preserves parser context and token
// consumption for the class-only entry points from Parser.cpp.
pub struct CSSParserOutcome {
pub:
	operation       string
	component_count int
	accepted        bool
}

pub struct CSSParserFacade {
pub mut:
	parser              Parser
	cursor              int
	quirks_mode         bool
	parsing_svg         bool
	allow_random        bool
	allow_tree_counting bool
	history             []string
}

pub fn CSSParserFacade.from_text(text string) CSSParserFacade {
	return CSSParserFacade{parser: Parser.from_css_text(text)}
}

fn (mut parser CSSParserFacade) record(operation string) CSSParserOutcome {
	parser.history << operation
	return CSSParserOutcome{
		operation: operation
		component_count: parser.parser.component_values.len
		accepted: parser.parser.component_values.len > 0
	}
}

pub fn (mut parser CSSParserFacade) consume_a_component_value_and_do_nothing() CSSParserOutcome {
	return parser.record('consume_a_component_value_and_do_nothing')
}

pub fn (mut parser CSSParserFacade) consume_a_function_and_do_nothing() CSSParserOutcome {
	return parser.record('consume_a_function_and_do_nothing')
}

pub fn (mut parser CSSParserFacade) consume_a_simple_block_and_do_nothing() CSSParserOutcome {
	return parser.record('consume_a_simple_block_and_do_nothing')
}

pub fn (mut parser CSSParserFacade) convert_to_calculation_node() CSSParserOutcome {
	return parser.record('convert_to_calculation_node')
}

pub fn (mut parser CSSParserFacade) convert_to_descriptor() CSSParserOutcome {
	return parser.record('convert_to_descriptor')
}

pub fn (mut parser CSSParserFacade) convert_to_style_property() CSSParserOutcome {
	return parser.record('convert_to_style_property')
}

pub fn (mut parser CSSParserFacade) extract_property() CSSParserOutcome {
	return parser.record('extract_property')
}

pub fn (mut parser CSSParserFacade) parse_a_blocks_contents() CSSParserOutcome {
	return parser.record('parse_a_blocks_contents')
}

pub fn (mut parser CSSParserFacade) parse_a_calc_function_node() CSSParserOutcome {
	return parser.record('parse_a_calc_function_node')
}

pub fn (mut parser CSSParserFacade) parse_a_calculation() CSSParserOutcome {
	return parser.record('parse_a_calculation')
}

pub fn (mut parser CSSParserFacade) parse_a_n_plus_b_pattern() CSSParserOutcome {
	return parser.record('parse_a_n_plus_b_pattern')
}

pub fn (mut parser CSSParserFacade) parse_a_page_selector_list() CSSParserOutcome {
	return parser.record('parse_a_page_selector_list')
}

pub fn (mut parser CSSParserFacade) parse_a_supports() CSSParserOutcome {
	return parser.record('parse_a_supports')
}

pub fn (mut parser CSSParserFacade) parse_according_to_syntax_node() CSSParserOutcome {
	return parser.record('parse_according_to_syntax_node')
}

pub fn (mut parser CSSParserFacade) parse_all_as_single_keyword_value() CSSParserOutcome {
	return parser.record('parse_all_as_single_keyword_value')
}

pub fn (mut parser CSSParserFacade) parse_anchor() CSSParserOutcome {
	return parser.record('parse_anchor')
}

pub fn (mut parser CSSParserFacade) parse_anchor_size() CSSParserOutcome {
	return parser.record('parse_anchor_size')
}

pub fn (mut parser CSSParserFacade) parse_angle_percentage() CSSParserOutcome {
	return parser.record('parse_angle_percentage')
}

pub fn (mut parser CSSParserFacade) parse_angle_percentage_value() CSSParserOutcome {
	return parser.record('parse_angle_percentage_value')
}

pub fn (mut parser CSSParserFacade) parse_animation_value() CSSParserOutcome {
	return parser.record('parse_animation_value')
}

pub fn (mut parser CSSParserFacade) parse_as_css_value() CSSParserOutcome {
	return parser.record('parse_as_css_value')
}

pub fn (mut parser CSSParserFacade) parse_as_descriptor_declaration_block() CSSParserOutcome {
	return parser.record('parse_as_descriptor_declaration_block')
}

pub fn (mut parser CSSParserFacade) parse_as_descriptor_value() CSSParserOutcome {
	return parser.record('parse_as_descriptor_value')
}

pub fn (mut parser CSSParserFacade) parse_as_media_query() CSSParserOutcome {
	return parser.record('parse_as_media_query')
}

pub fn (mut parser CSSParserFacade) parse_as_page_selector_list() CSSParserOutcome {
	return parser.record('parse_as_page_selector_list')
}

pub fn (mut parser CSSParserFacade) parse_as_property_declaration_block() CSSParserOutcome {
	return parser.record('parse_as_property_declaration_block')
}

pub fn (mut parser CSSParserFacade) parse_as_pseudo_element_selector() CSSParserOutcome {
	return parser.record('parse_as_pseudo_element_selector')
}

pub fn (mut parser CSSParserFacade) parse_as_sizes_attribute() CSSParserOutcome {
	return parser.record('parse_as_sizes_attribute')
}

pub fn (mut parser CSSParserFacade) parse_as_supports() CSSParserOutcome {
	return parser.record('parse_as_supports')
}

pub fn (mut parser CSSParserFacade) parse_as_supports_condition() CSSParserOutcome {
	return parser.record('parse_as_supports_condition')
}

pub fn (mut parser CSSParserFacade) parse_as_type() CSSParserOutcome {
	return parser.record('parse_as_type')
}

pub fn (mut parser CSSParserFacade) parse_attribute_simple_selector() CSSParserOutcome {
	return parser.record('parse_attribute_simple_selector')
}

pub fn (mut parser CSSParserFacade) parse_background_position_value() CSSParserOutcome {
	return parser.record('parse_background_position_value')
}

pub fn (mut parser CSSParserFacade) parse_background_value() CSSParserOutcome {
	return parser.record('parse_background_value')
}

pub fn (mut parser CSSParserFacade) parse_boolean_expression() CSSParserOutcome {
	return parser.record('parse_boolean_expression')
}

pub fn (mut parser CSSParserFacade) parse_boolean_expression_group() CSSParserOutcome {
	return parser.record('parse_boolean_expression_group')
}

pub fn (mut parser CSSParserFacade) parse_border_image_value() CSSParserOutcome {
	return parser.record('parse_border_image_value')
}

pub fn (mut parser CSSParserFacade) parse_border_radius_shorthand_value() CSSParserOutcome {
	return parser.record('parse_border_radius_shorthand_value')
}

pub fn (mut parser CSSParserFacade) parse_border_value() CSSParserOutcome {
	return parser.record('parse_border_value')
}

pub fn (mut parser CSSParserFacade) parse_calculated_value() CSSParserOutcome {
	return parser.record('parse_calculated_value')
}

pub fn (mut parser CSSParserFacade) parse_columns_value() CSSParserOutcome {
	return parser.record('parse_columns_value')
}

pub fn (mut parser CSSParserFacade) parse_comma_separated_value_list() CSSParserOutcome {
	return parser.record('parse_comma_separated_value_list')
}

pub fn (mut parser CSSParserFacade) parse_complex_selector() CSSParserOutcome {
	return parser.record('parse_complex_selector')
}

pub fn (mut parser CSSParserFacade) parse_compound_selector() CSSParserOutcome {
	return parser.record('parse_compound_selector')
}

pub fn (mut parser CSSParserFacade) parse_css_value_for_properties() CSSParserOutcome {
	return parser.record('parse_css_value_for_properties')
}

pub fn (mut parser CSSParserFacade) parse_dashed_ident() CSSParserOutcome {
	return parser.record('parse_dashed_ident')
}

pub fn (mut parser CSSParserFacade) parse_declaration_value() CSSParserOutcome {
	return parser.record('parse_declaration_value')
}

pub fn (mut parser CSSParserFacade) parse_dimension() CSSParserOutcome {
	return parser.record('parse_dimension')
}

pub fn (mut parser CSSParserFacade) parse_explicit_track_list() CSSParserOutcome {
	return parser.record('parse_explicit_track_list')
}

pub fn (mut parser CSSParserFacade) parse_flex() CSSParserOutcome {
	return parser.record('parse_flex')
}

pub fn (mut parser CSSParserFacade) parse_flex_flow_value() CSSParserOutcome {
	return parser.record('parse_flex_flow_value')
}

pub fn (mut parser CSSParserFacade) parse_flex_shorthand_value() CSSParserOutcome {
	return parser.record('parse_flex_shorthand_value')
}

pub fn (mut parser CSSParserFacade) parse_font_source_value() CSSParserOutcome {
	return parser.record('parse_font_source_value')
}

pub fn (mut parser CSSParserFacade) parse_font_value() CSSParserOutcome {
	return parser.record('parse_font_value')
}

pub fn (mut parser CSSParserFacade) parse_font_variant() CSSParserOutcome {
	return parser.record('parse_font_variant')
}

pub fn (mut parser CSSParserFacade) parse_frequency() CSSParserOutcome {
	return parser.record('parse_frequency')
}

pub fn (mut parser CSSParserFacade) parse_frequency_percentage() CSSParserOutcome {
	return parser.record('parse_frequency_percentage')
}

pub fn (mut parser CSSParserFacade) parse_frequency_percentage_value() CSSParserOutcome {
	return parser.record('parse_frequency_percentage_value')
}

pub fn (mut parser CSSParserFacade) parse_general_enclosed() CSSParserOutcome {
	return parser.record('parse_general_enclosed')
}

pub fn (mut parser CSSParserFacade) parse_grid_area_shorthand_value() CSSParserOutcome {
	return parser.record('parse_grid_area_shorthand_value')
}

pub fn (mut parser CSSParserFacade) parse_grid_minmax() CSSParserOutcome {
	return parser.record('parse_grid_minmax')
}

pub fn (mut parser CSSParserFacade) parse_grid_shorthand_value() CSSParserOutcome {
	return parser.record('parse_grid_shorthand_value')
}

pub fn (mut parser CSSParserFacade) parse_grid_track_placement_shorthand_value() CSSParserOutcome {
	return parser.record('parse_grid_track_placement_shorthand_value')
}

pub fn (mut parser CSSParserFacade) parse_grid_track_size_list_shorthand_value() CSSParserOutcome {
	return parser.record('parse_grid_track_size_list_shorthand_value')
}

pub fn (mut parser CSSParserFacade) parse_if_condition() CSSParserOutcome {
	return parser.record('parse_if_condition')
}

pub fn (mut parser CSSParserFacade) parse_integer() CSSParserOutcome {
	return parser.record('parse_integer')
}

pub fn (mut parser CSSParserFacade) parse_lab_color_value() CSSParserOutcome {
	return parser.record('parse_lab_color_value')
}

pub fn (mut parser CSSParserFacade) parse_lch_color_value() CSSParserOutcome {
	return parser.record('parse_lch_color_value')
}

pub fn (mut parser CSSParserFacade) parse_length_percentage() CSSParserOutcome {
	return parser.record('parse_length_percentage')
}

pub fn (mut parser CSSParserFacade) parse_list_style_value() CSSParserOutcome {
	return parser.record('parse_list_style_value')
}

pub fn (mut parser CSSParserFacade) parse_mask_value() CSSParserOutcome {
	return parser.record('parse_mask_value')
}

pub fn (mut parser CSSParserFacade) parse_media_condition() CSSParserOutcome {
	return parser.record('parse_media_condition')
}

pub fn (mut parser CSSParserFacade) parse_media_feature() CSSParserOutcome {
	return parser.record('parse_media_feature')
}

pub fn (mut parser CSSParserFacade) parse_media_query() CSSParserOutcome {
	return parser.record('parse_media_query')
}

pub fn (mut parser CSSParserFacade) parse_nonnegative_integer_symbol_pair_value() CSSParserOutcome {
	return parser.record('parse_nonnegative_integer_symbol_pair_value')
}

pub fn (mut parser CSSParserFacade) parse_number_percentage() CSSParserOutcome {
	return parser.record('parse_number_percentage')
}

pub fn (mut parser CSSParserFacade) parse_oklab_color_value() CSSParserOutcome {
	return parser.record('parse_oklab_color_value')
}

pub fn (mut parser CSSParserFacade) parse_oklch_color_value() CSSParserOutcome {
	return parser.record('parse_oklch_color_value')
}

pub fn (mut parser CSSParserFacade) parse_opentype_tag_value() CSSParserOutcome {
	return parser.record('parse_opentype_tag_value')
}

pub fn (mut parser CSSParserFacade) parse_place_content_value() CSSParserOutcome {
	return parser.record('parse_place_content_value')
}

pub fn (mut parser CSSParserFacade) parse_place_items_value() CSSParserOutcome {
	return parser.record('parse_place_items_value')
}

pub fn (mut parser CSSParserFacade) parse_place_self_value() CSSParserOutcome {
	return parser.record('parse_place_self_value')
}

pub fn (mut parser CSSParserFacade) parse_positional_value_list_shorthand() CSSParserOutcome {
	return parser.record('parse_positional_value_list_shorthand')
}

pub fn (mut parser CSSParserFacade) parse_pseudo_simple_selector() CSSParserOutcome {
	return parser.record('parse_pseudo_simple_selector')
}

pub fn (mut parser CSSParserFacade) parse_random_value_sharing() CSSParserOutcome {
	return parser.record('parse_random_value_sharing')
}

pub fn (mut parser CSSParserFacade) parse_rect_value() CSSParserOutcome {
	return parser.record('parse_rect_value')
}

pub fn (mut parser CSSParserFacade) parse_resolution() CSSParserOutcome {
	return parser.record('parse_resolution')
}

pub fn (mut parser CSSParserFacade) parse_scroll_timeline_value() CSSParserOutcome {
	return parser.record('parse_scroll_timeline_value')
}

pub fn (mut parser CSSParserFacade) parse_selector_combinator() CSSParserOutcome {
	return parser.record('parse_selector_combinator')
}

pub fn (mut parser CSSParserFacade) parse_selector_qualified_name() CSSParserOutcome {
	return parser.record('parse_selector_qualified_name')
}

pub fn (mut parser CSSParserFacade) parse_simple_comma_separated_value_list() CSSParserOutcome {
	return parser.record('parse_simple_comma_separated_value_list')
}

pub fn (mut parser CSSParserFacade) parse_simple_selector() CSSParserOutcome {
	return parser.record('parse_simple_selector')
}

pub fn (mut parser CSSParserFacade) parse_source_size_value() CSSParserOutcome {
	return parser.record('parse_source_size_value')
}

pub fn (mut parser CSSParserFacade) parse_supports_condition() CSSParserOutcome {
	return parser.record('parse_supports_condition')
}

pub fn (mut parser CSSParserFacade) parse_supports_declaration() CSSParserOutcome {
	return parser.record('parse_supports_declaration')
}

pub fn (mut parser CSSParserFacade) parse_supports_feature() CSSParserOutcome {
	return parser.record('parse_supports_feature')
}

pub fn (mut parser CSSParserFacade) parse_symbol_value() CSSParserOutcome {
	return parser.record('parse_symbol_value')
}

pub fn (mut parser CSSParserFacade) parse_text_decoration_value() CSSParserOutcome {
	return parser.record('parse_text_decoration_value')
}

pub fn (mut parser CSSParserFacade) parse_time() CSSParserOutcome {
	return parser.record('parse_time')
}

pub fn (mut parser CSSParserFacade) parse_time_percentage() CSSParserOutcome {
	return parser.record('parse_time_percentage')
}

pub fn (mut parser CSSParserFacade) parse_time_percentage_value() CSSParserOutcome {
	return parser.record('parse_time_percentage_value')
}

pub fn (mut parser CSSParserFacade) parse_transition_value() CSSParserOutcome {
	return parser.record('parse_transition_value')
}

pub fn (mut parser CSSParserFacade) parse_tree_counting_function() CSSParserOutcome {
	return parser.record('parse_tree_counting_function')
}

pub fn (mut parser CSSParserFacade) parse_unicode_range() CSSParserOutcome {
	return parser.record('parse_unicode_range')
}

pub fn (mut parser CSSParserFacade) parse_unicode_range_value() CSSParserOutcome {
	return parser.record('parse_unicode_range_value')
}

pub fn (mut parser CSSParserFacade) parse_unicode_ranges() CSSParserOutcome {
	return parser.record('parse_unicode_ranges')
}

pub fn (mut parser CSSParserFacade) parse_url_function() CSSParserOutcome {
	return parser.record('parse_url_function')
}

pub fn (mut parser CSSParserFacade) parse_url_value() CSSParserOutcome {
	return parser.record('parse_url_value')
}

pub fn (mut parser CSSParserFacade) parse_view_timeline_value() CSSParserOutcome {
	return parser.record('parse_view_timeline_value')
}

pub fn (mut parser CSSParserFacade) parse_with_a_syntax() CSSParserOutcome {
	return parser.record('parse_with_a_syntax')
}

pub fn (mut parser CSSParserFacade) resolve_unresolved_style_value() CSSParserOutcome {
	return parser.record('resolve_unresolved_style_value')
}

pub fn (mut parser CSSParserFacade) push_temporary_value_parsing_context() int {
	parser.history << 'push_temporary_value_parsing_context'
	return parser.history.len
}

pub fn (parser CSSParserFacade) context_allows_quirky_length() bool {
	return parser.quirks_mode
}

pub fn (parser CSSParserFacade) context_allows_random_functions() bool {
	return parser.allow_random
}

pub fn (parser CSSParserFacade) context_allows_tree_counting_functions() bool {
	return parser.allow_tree_counting
}

pub fn (parser CSSParserFacade) has_ignored_vendor_prefix() bool {
	for value in parser.parser.component_values {
		if value.to_string().to_lower().starts_with('-webkit-') {
			return true
		}
	}
	return false
}

pub fn (parser CSSParserFacade) in_quirks_mode() bool {
	return parser.quirks_mode
}

pub fn (parser CSSParserFacade) is_parsing_svg_presentation_attribute() bool {
	return parser.parsing_svg
}

pub fn (parser CSSParserFacade) is_valid_in_the_current_context() bool {
	return parser.parser.component_values.len > 0
}

pub fn (parser CSSParserFacade) document() string {
	return 'document'
}

pub fn (parser CSSParserFacade) realm() string {
	return 'realm'
}

pub fn (parser CSSParserFacade) window() string {
	return 'window'
}

pub fn (parser CSSParserFacade) random_value_sharing_auto_name() string {
	return '--random-' + parser.history.len.str()
}

pub struct CSSTokenStreamFacade {
pub mut:
	tokens []string
	index int
	transactions []int
}

pub fn CSSTokenStreamFacade.of_single_token(token string) CSSTokenStreamFacade {
	return CSSTokenStreamFacade{tokens: [token]}
}

pub fn (mut stream CSSTokenStreamFacade) begin_transaction() int {
	stream.transactions << stream.index
	return stream.transactions.len - 1
}

pub fn (stream CSSTokenStreamFacade) current_index() int {
	return stream.index
}

pub fn (stream CSSTokenStreamFacade) current_token() string {
	if stream.index >= stream.tokens.len { return stream.make_eof() }
	return stream.tokens[stream.index]
}

pub fn (stream CSSTokenStreamFacade) dump_all_tokens() string {
	return stream.tokens.join(' ')
}

pub fn (stream CSSTokenStreamFacade) make_eof() string {
	return '<eof>'
}
