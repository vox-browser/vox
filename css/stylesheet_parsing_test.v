module css

// Stylesheet rule parsing. This exercises the fix to the rule-consumption path: the port's token
// stream normalizes {}-blocks into SimpleBlock component values, so consume_a_qualified_rule /
// consume_an_at_rule / consume_a_block must detect a curly-block component value (not a raw
// <{-token>). Before the fix parse_css_stylesheet_contents_with_parser returned zero rules.

fn parse_rules(css_text string) []&CSSRule {
	return parse_css_stylesheet_contents_with_parser(css_text, map[string]bool{})
}

fn decl_of(rule &CSSRule) &CSSStyleProperties {
	return rule.style() or { panic('rule has no style declaration') }
}

fn test_single_style_rule() {
	rules := parse_rules('p { color: red; font-size: 14px }')
	assert rules.len == 1
	assert rules[0].selector_text() == 'p'
	d := decl_of(rules[0])
	assert d.length() == 2
	assert d.get_property_value('color') == 'red'
	assert d.get_property_value('font-size') == '14px'
}

fn test_css_style_properties_reconstructs_shorthands_like_upstream() {
	rules := parse_rules('.box { margin: 1px 2px !important; float: left }')
	mut declaration := decl_of(rules[0])
	assert declaration.get_property_value('margin') == '1px 2px'
	assert declaration.get_property_priority('margin') == 'important'
	assert declaration.css_float() == 'left'
	assert declaration.serialized() == 'margin: 1px 2px !important; float: left;'

	// A shorthand cannot be represented when its component importance flags
	// differ. CSSStyleProperties.cpp returns the empty string in this case.
	declaration.set_property('margin-left', '3px', '')!
	assert declaration.get_property_value('margin') == ''
	assert declaration.get_property_priority('margin') == ''

	declaration.set_css_float('right')!
	assert declaration.get_property_value('float') == 'right'
}

fn test_css_style_properties_typed_set_and_declaration_replacement() {
	mut declaration := CSSStyleProperties.create()
	margin := parse_css_value(ParsingParams{}, '4px 8px', .margin) or {
		panic('failed to parse margin')
	}
	declaration.set_property_style_value(PropertyNameAndID.from_id(.margin), margin)!
	assert declaration.get_property_value('margin') == '4px 8px'
	assert declaration.serialized() == 'margin: 4px 8px;'

	declaration.set_declarations_from_text('padding: 1px; --theme: green !important')
	assert declaration.get_property_value('margin') == ''
	assert declaration.get_property_value('padding') == '1px'
	assert declaration.get_property_value('--theme') == 'green'
	assert declaration.get_property_priority('--theme') == 'important'
	assert declaration.custom_property_count() == 1
	assert declaration.serialized() == '--theme: green !important; padding: 1px;'

	declaration.empty_the_declarations()
	assert declaration.length() == 0
}

fn test_multiple_rules_and_selector_groups() {
	rules := parse_rules('h1 { margin: 0 } .a, .b > i { color: blue }')
	assert rules.len == 2
	assert rules[0].selector_text() == 'h1'
	assert rules[1].selector_text() == '.a, .b > i'
	assert decl_of(rules[1]).get_property_value('color') == 'blue'
}

fn test_empty_rule_and_whitespace() {
	rules := parse_rules('   .empty {}   div{color:green}  ')
	assert rules.len == 2
	assert rules[0].selector_text() == '.empty'
	assert decl_of(rules[0]).length() == 0
	assert rules[1].selector_text() == 'div'
	assert decl_of(rules[1]).get_property_value('color') == 'green'
}

fn test_stylesheet_object() {
	sheet := parse_css_stylesheet_with_parser('a { color: red } b { color: blue }', ?string(none))
	assert sheet.css_rules().length() == 2
}

fn test_font_face_unicode_ranges_use_the_component_value_parser() {
	mut unicode_parser := Parser.from_css_text('U+4??, U+1000-10ff')
	mut unicode_tokens := ComponentValueStream.new(unicode_parser.component_values)
	direct_ranges := unicode_parser.parse_unicode_ranges(mut unicode_tokens)
	assert direct_ranges.len == 2
	rules := parse_rules('@font-face { font-family: Old; font-family: Test; src: url(test.woff2); unicode-range: U+4??, U+1000-10ff }')
	assert rules.len == 1
	font_face := rules[0].font_face_rule_ref() or { panic('missing font-face rule') }
	assert font_face.is_valid()
	assert font_face.descriptors().font_family() == 'Test'
	assert font_face.descriptors().src() == 'url("test.woff2")'
	// Gfx::UnicodeRange::to_string() formats with `U+{:X}`, without zero padding.
	assert font_face.descriptors().unicode_range() == 'U+400-4FF, U+1000-10FF'
	ranges := font_face.font_face().unicode_ranges()
	assert ranges.len == 2
	assert ranges[0] == UnicodeRange{ start: 0x400, end: 0x4ff }
	assert ranges[1] == UnicodeRange{ start: 0x1000, end: 0x10ff }

	invalid_rules := parse_rules('@font-face { font-family: Test; src: url(test.woff2); unicode-range: U+4?F }')
	assert invalid_rules.len == 1
	invalid_font_face := invalid_rules[0].font_face_rule_ref() or {
		panic('missing invalid-case font-face rule')
	}
	assert invalid_font_face.descriptors().descriptor(.unicode_range) == none
}

fn test_font_face_sources_use_the_component_value_parser() {
	rules := parse_rules('@font-face { font-family: Test; src: bogus(), local("System Font"), url("font).woff2") format("WOFF2") tech(color-colrv1, palettes), src("remote.woff" integrity("sha256-test")) format(woff); }')
	assert rules.len == 1
	font_face := rules[0].font_face_rule_ref() or { panic('missing font-face rule') }
	assert font_face.descriptors().src() == 'local("System Font"), url("font).woff2") format(woff2) tech(color-colrv1, palettes), src("remote.woff" integrity("sha256-test")) format(woff)'

	sources := font_face.font_face().sources()
	assert sources.len == 3
	assert sources[0].kind == .local
	assert sources[0].value == 'System Font'
	assert sources[1].kind == .url
	assert sources[1].value == 'font).woff2'
	assert sources[1].format or { '' } == 'woff2'
	assert sources[1].tech == [FontTech.color_colrv1, .palettes]
	assert sources[2].kind == .url
	assert sources[2].value == 'remote.woff'
	assert sources[2].format or { '' } == 'woff'
	remote_url := sources[2].url or { panic('missing parsed src() URL') }
	assert remote_url.type_ == .src
	assert remote_url.request_url_modifiers().len == 1

	// A malformed/unsupported fallback is dropped without discarding later supported sources.
	fallback_rules := parse_rules('@font-face { font-family: Test; src: url("wrong.woff") tech(color-colrv1) format(woff), local(serif), url("good.woff") format(woff); }')
	fallback_face := fallback_rules[0].font_face_rule_ref() or { panic('missing fallback font-face rule') }
	assert fallback_face.descriptors().src() == 'url("good.woff") format(woff)'
	assert fallback_face.font_face().sources().len == 1

	// Legacy variation format strings imply tech(variations); unlike an explicit unsupported
	// tech(), this mapping is retained by Ladybird's parser.
	legacy_rules := parse_rules('@font-face { font-family: Test; src: url(font.woff2) format("woff2-variations"); }')
	legacy_face := legacy_rules[0].font_face_rule_ref() or { panic('missing legacy font-face rule') }
	assert legacy_face.descriptors().src() == 'url("font.woff2") format(woff2) tech(variations)'
	assert legacy_face.font_face().sources()[0].tech == [FontTech.variations]

	unsupported_rules := parse_rules('@font-face { font-family: Test; src: url(font.woff2) tech(variations); }')
	unsupported_face := unsupported_rules[0].font_face_rule_ref() or {
		panic('missing unsupported font-face rule')
	}
	assert unsupported_face.descriptors().descriptor(.src) == none
}

fn test_font_face_src_cssom_setter_uses_the_component_value_parser() {
	mut descriptors := CSSFontFaceDescriptors.create([]FontFaceDescriptor{})
	descriptors.set_src('invalid(), src("font.woff2") format("woff2")')!
	assert descriptors.src() == 'src("font.woff2") format(woff2)'
	descriptors.set_src('url(font.woff2) format("woff2-variations")')!
	assert descriptors.src() == 'url("font.woff2") format(woff2) tech(variations)'
	connected_rule := CSSFontFaceRule.create(descriptors)
	connected_sources := connected_rule.font_face().sources()
	assert connected_sources.len == 1
	assert connected_sources[0].tech == [FontTech.variations]

	// No supported entries is a parse error and leaves the previous descriptor untouched.
	descriptors.set_src('url("font.woff2") format("svg")')!
	assert descriptors.src() == 'url("font.woff2") format(woff2) tech(variations)'

	constructed := FontFaceObject.construct_impl('Test', FontFaceSource.from_string('url(font.woff2) format("woff2-variations")'), FontFaceDescriptors{})
	assert constructed.status() != .error
	assert constructed.urls.len == 1
	assert constructed.urls[0].tech == [FontTech.variations]
}

fn test_font_face_family_uses_the_typed_family_name_parser() {
	rules := parse_rules('@font-face { font-family: Test\\ Family; src: url(font.woff2); }')
	font_face := rules[0].font_face_rule_ref() or { panic('missing escaped-family font-face rule') }
	assert font_face.descriptors().font_family() == 'Test\\ Family'
	assert font_face.font_face().font_family() == 'Test Family'

	// Generic families and CSS-wide keywords are not <family-name> values unless quoted.
	invalid_rules := parse_rules('@font-face { font-family: serif; src: url(font.woff2); }')
	invalid_face := invalid_rules[0].font_face_rule_ref() or {
		panic('missing generic-family font-face rule')
	}
	assert invalid_face.descriptors().descriptor(.font_family) == none
	assert !invalid_face.is_valid()

	constructed := FontFaceObject.construct_impl('inherit', FontFaceSource.from_string('url(font.woff2)'), FontFaceDescriptors{})
	assert constructed.status() == .error
}

fn test_font_face_style_uses_the_typed_font_style_parser() {
	italic_rules := parse_rules('@font-face { font-family: Italic; src: url(italic.woff2); font-style: italic; }')
	italic_face := italic_rules[0].font_face_rule_ref() or { panic('missing italic font-face rule') }
	assert italic_face.font_face().slope() or { -1 } == 1

	oblique_rules := parse_rules('@font-face { font-family: Oblique; src: url(oblique.woff2); font-style: oblique 20deg; }')
	oblique_face := oblique_rules[0].font_face_rule_ref() or { panic('missing oblique font-face rule') }
	assert oblique_face.descriptors().font_style() == 'oblique 20deg'
	assert oblique_face.font_face().slope() or { -1 } == 2

	// The property grammar permits at most one angle and constrains a literal angle to [-90deg, 90deg].
	invalid_rules := parse_rules('@font-face { font-family: Invalid; src: url(invalid.woff2); font-style: oblique 10deg 20deg; }')
	invalid_face := invalid_rules[0].font_face_rule_ref() or {
		panic('missing invalid-style font-face rule')
	}
	assert invalid_face.descriptors().descriptor(.font_style) == none

	out_of_range_rules := parse_rules('@font-face { font-family: Invalid; src: url(invalid.woff2); font-style: oblique 91deg; }')
	out_of_range_face := out_of_range_rules[0].font_face_rule_ref() or {
		panic('missing out-of-range font-face rule')
	}
	assert out_of_range_face.descriptors().descriptor(.font_style) == none
}

fn test_font_face_weight_uses_the_typed_number_parser() {
	rules := parse_rules('@font-face { font-family: Weighted; src: url(weighted.woff2); font-weight: 700 450.5; }')
	font_face := rules[0].font_face_rule_ref() or { panic('missing weighted font-face rule') }
	weight := font_face.font_face().weight() or { panic('missing parsed font weight') }
	assert weight.min == 450
	assert weight.max == 700

	calculated_rules := parse_rules('@font-face { font-family: Calculated; src: url(calculated.woff2); font-weight: calc(400 + 50); }')
	calculated_face := calculated_rules[0].font_face_rule_ref() or {
		panic('missing calculated-weight font-face rule')
	}
	calculated_weight := calculated_face.font_face().weight() or {
		panic('missing calculated font weight')
	}
	assert calculated_weight.min == 450
	assert calculated_weight.max == 450

	invalid_rules := parse_rules('@font-face { font-family: Invalid; src: url(invalid.woff2); font-weight: bolder; }')
	invalid_face := invalid_rules[0].font_face_rule_ref() or {
		panic('missing invalid-weight font-face rule')
	}
	assert invalid_face.descriptors().descriptor(.font_weight) == none
}

fn test_font_face_width_uses_the_typed_percentage_parser() {
	rules := parse_rules('@font-face { font-family: Width; src: url(width.woff2); font-width: 62.5%; }')
	font_face := rules[0].font_face_rule_ref() or { panic('missing width font-face rule') }
	assert font_face.font_face().width() or { -1 } == 62

	keyword_rules := parse_rules('@font-face { font-family: Width; src: url(width.woff2); font-width: extra-condensed; }')
	keyword_face := keyword_rules[0].font_face_rule_ref() or {
		panic('missing keyword-width font-face rule')
	}
	assert keyword_face.font_face().width() or { -1 } == 62

	// The current upstream descriptor accepts one font-width value, and percentages are non-negative.
	for css_text in [
		'@font-face { font-family: Invalid; src: url(invalid.woff2); font-width: 50% 100%; }',
		'@font-face { font-family: Invalid; src: url(invalid.woff2); font-width: -1%; }',
	] {
		invalid_rules := parse_rules(css_text)
		invalid_face := invalid_rules[0].font_face_rule_ref() or {
			panic('missing invalid-width font-face rule')
		}
		assert invalid_face.descriptors().descriptor(.font_width) == none
	}
}

fn test_font_face_open_type_settings_use_typed_property_values() {
	rules := parse_rules('@font-face { font-family: Features; src: url(features.woff2); font-feature-settings: "liga" on, "liga" 3, "kern" off, "a b " 2; font-variation-settings: "wght" 450, "wght" 475, "wdth" 87.5; }')
	font_face := rules[0].font_face_rule_ref() or { panic('missing feature-settings font-face rule') }
	assert font_face.descriptors().font_feature_settings() == '"liga", "liga" 3, "kern" 0, "a b " 2'
	assert font_face.descriptors().font_variation_settings() == '"wght" 450, "wght" 475, "wdth" 87.5'

	features := font_face.font_face().font_feature_settings() or {
		panic('missing parsed font feature settings')
	}
	assert features['liga'] == 3
	assert features['kern'] == 0
	assert features['a b '] == 2
	variations := font_face.font_face().font_variation_settings() or {
		panic('missing parsed font variation settings')
	}
	assert variations['wght'] == 475
	assert variations['wdth'] == 87.5

	// The descriptor reuses the property grammar but rejects property-only CSS-wide and
	// unresolved substitution values. Invalid replacements do not overwrite a CSSOM value.
	mut descriptors := CSSFontFaceDescriptors.create([]FontFaceDescriptor{})
	descriptors.set_font_feature_settings('"liga" on')!
	assert descriptors.font_feature_settings() == '"liga"'
	descriptors.set_font_feature_settings('inherit')!
	descriptors.set_font_feature_settings('var(--features)')!
	descriptors.set_font_feature_settings('"liga" -1')!
	assert descriptors.font_feature_settings() == '"liga"'

	normal_rules := parse_rules('@font-face { font-family: Normal; src: url(normal.woff2); font-feature-settings: normal; font-variation-settings: normal; }')
	normal_face := normal_rules[0].font_face_rule_ref() or {
		panic('missing normal-settings font-face rule')
	}
	assert normal_face.font_face().font_feature_settings() == none
	assert normal_face.font_face().font_variation_settings() == none
}

fn test_font_face_metadata_descriptors_use_typed_component_values() {
	rules := parse_rules('@font-face { font-family: Metadata; src: url(metadata.woff2); ascent-override: calc(10% + 5%); descent-override: -1%; line-gap-override: 20%; font-display: s\\77 ap; font-language-override: "ABCDE"; font-named-instance: ""; }')
	font_face := rules[0].font_face_rule_ref() or { panic('missing metadata font-face rule') }
	assert font_face.descriptors().ascent_override() == '15%'
	assert font_face.descriptors().descriptor(.descent_override) == none
	assert font_face.descriptors().line_gap_override() == '20%'
	assert font_face.descriptors().font_display() == 'swap'
	assert font_face.descriptors().font_language_override() == '"ABCDE"'
	assert font_face.descriptors().font_named_instance() == '""'

	parsed := font_face.font_face()
	assert parsed.ascent_override()?.value() == 15
	assert parsed.descent_override() == none
	assert parsed.line_gap_override()?.value() == 20
	assert parsed.font_display() == .swap
	assert parsed.font_language_override()? == 'ABCDE'
	assert parsed.font_named_instance()? == ''
}

fn test_page_rule_retains_descriptors_and_margin_rules() {
	rules := parse_rules('@page chapter:left { margin: 1cm; size: A4; @top-center { content: "Chapter"; } }')
	assert rules.len == 1
	page := rules[0]
	assert page.type_ == .page
	assert page.page_selector_text() == 'chapter:left'
	descriptors := page.page_descriptors or { panic('missing page descriptors') }
	// Parser::DescriptorList::append() expands the `margin` shorthand descriptor,
	// so only the longhands are recorded and the shorthand reads back as empty.
	assert descriptors.margin() == ''
	assert descriptors.margin_top() == '1cm'
	assert descriptors.margin_left() == '1cm'
	assert descriptors.size() == 'a4'
	margin_rules := page.css_rules() or { panic('missing page margin rule list') }
	assert margin_rules.length() == 1
	margin_rule := margin_rules.item(0) or { panic('missing page margin rule') }
	assert margin_rule.type_ == .margin
	assert margin_rule.margin_rule_name() == 'top-center'
	assert margin_rule.style()?.get_property_value('content') == '"Chapter"'
}

fn test_stylesheet_location_is_retained_for_style_resource_urls() {
	sheet := parse_css_stylesheet_with_parser('a { background-image: url("sprite.png") }', 'https://example.test/assets/site.css')
	rule := sheet.css_rules().item(0) or { panic('missing style rule') }
	declaration := decl_of(rule)
	assert declaration.properties.len == 1
	value := declaration.properties[0].style_value or { panic('missing parsed style value') }
	assert value.base_url or { '' } == 'https://example.test/assets/site.css'
	typed := typed_style_value_logic_from_dom(value) or { panic('missing typed style value') }
	absolutized := typed.absolutized(ComputationContext{})
	assert absolutized.serialize(.normal).contains('https://example.test/assets/sprite.png')
}

fn test_empty_and_comma_only_media_preludes() {
	sheet := parse_css_stylesheet_with_parser('@media { .first { display: block } } @media ,, { .invalid { display: block } }', ?string(none))
	rules := sheet.css_rules()
	assert rules.length() == 2
	empty_media := rules.item(0) or { panic('missing empty media rule') }
	invalid_media := rules.item(1) or { panic('missing invalid media rule') }
	assert empty_media.condition_matches()
	assert !invalid_media.condition_matches()
}

fn test_media_query_parser_matches_upstream_list_and_media_type_recovery() {
	mut empty_parser := Parser.from_css_text('   ')
	assert empty_parser.parse_as_media_query_list().len == 0
	empty_query := empty_parser.parse_as_media_query() or { panic('empty query becomes not all') }
	assert empty_query.to_string() == 'not all'

	mut parser := Parser.from_css_text('screen and (min-width: 600px), television, print')
	queries := parser.parse_as_media_query_list()
	assert queries.len == 3
	assert queries[0].to_string() == 'screen and (min-width: 600px)'
	assert queries[0].matches()
	assert queries[1].to_string() == 'television'
	assert !queries[1].matches()
	assert queries[2].to_string() == 'print'
	assert !queries[2].matches()
	assert parser.parse_as_media_query() == none

	mut invalid_parser := Parser.from_css_text('screen and (color) or (monochrome)')
	invalid_query := invalid_parser.parse_as_media_query() or { panic('invalid query becomes not all') }
	assert invalid_query.to_string() == 'not all'

	mut only_parser := Parser.from_css_text('only screen')
	only_query := only_parser.parse_as_media_query() or { panic('only query') }
	assert only_query.to_string() == 'screen'
}

fn test_media_feature_values_keep_typed_units_and_calculations() {
	min_em := parse_media_query_from_text('(min-width: 40em)') or { panic('40em query') }
	max_em := parse_media_query_from_text('(min-width: 60em)') or { panic('60em query') }
	assert min_em.matches()
	assert !max_em.matches()

	min_inches := parse_media_query_from_text('(min-width: 8in)') or { panic('8in query') }
	max_inches := parse_media_query_from_text('(min-width: 9in)') or { panic('9in query') }
	assert min_inches.matches()
	assert !max_inches.matches()

	low_resolution := parse_media_query_from_text('(min-resolution: 96dpi)') or {
		panic('96dpi query')
	}
	high_resolution := parse_media_query_from_text('(min-resolution: 192dpi)') or {
		panic('192dpi query')
	}
	assert low_resolution.matches()
	assert !high_resolution.matches()

	calculated := parse_media_query_from_text('(min-width: calc(30em + 10px))') or {
		panic('calculated query')
	}
	assert calculated.matches()
}

fn test_parser_supports_entry_uses_boolean_expression_grammar() {
	mut parser := Parser.from_css_text('(display: grid) and (color: red)')
	supports := parser.parse_as_supports() or { panic('valid supports condition') }
	assert supports.matches_condition()

	mut unsupported_parser := Parser.from_css_text('(display: definitely-not-a-display)')
	unsupported := unsupported_parser.parse_as_supports() or {
		panic('syntactically valid supports condition')
	}
	assert !unsupported.matches_condition()
	assert unsupported.condition.kind == .in_parens
	assert unsupported.condition.children[0].kind == .supports_declaration

	// Unknown declarations are syntactically valid <supports-decl> nodes whose
	// match result is false; they are not reclassified as <general-enclosed>.
	mut unknown_parser := Parser.from_css_text('(definitely-unknown-property: value)')
	unknown := unknown_parser.parse_as_supports() or { panic('unknown supports declaration') }
	assert !unknown.matches_condition()
	assert unknown.condition.kind == .in_parens
	assert unknown.condition.children[0].kind == .supports_declaration

	mut custom_parser := Parser.from_css_text('(--anything: arbitrary tokens)')
	custom := custom_parser.parse_as_supports() or { panic('custom-property supports declaration') }
	assert custom.matches_condition()
	assert custom.condition.children[0].kind == .supports_declaration

	mut mixed_parser := Parser.from_css_text('(display: grid) and (color: red) or (width: 1px)')
	assert mixed_parser.parse_as_supports() == none
}

fn test_if_condition_uses_shared_boolean_expression_parser() {
	mut parser := Parser.from_css_text('supports(display: grid) and media(min-width: 1px)')
	mut tokens := SupportsTokenStream.from_values(parser.component_values)
	condition := parser.parse_if_condition(mut tokens) or { panic('valid if() condition') }
	assert condition.kind == .and
	assert condition.evaluate_to_boolean(BooleanExpressionEvaluationContext{})
	assert !tokens.has_next_token()

	mut else_parser := Parser.from_css_text('else')
	mut else_tokens := SupportsTokenStream.from_values(else_parser.component_values)
	else_condition := else_parser.parse_if_condition(mut else_tokens) or {
		panic('else condition')
	}
	assert else_condition.kind == .constant
	assert else_condition.evaluate_to_boolean(BooleanExpressionEvaluationContext{})

	mut mixed_parser := Parser.from_css_text('supports(display: grid) and media(width) or supports(color: red)')
	mut mixed_tokens := SupportsTokenStream.from_values(mixed_parser.component_values)
	assert mixed_parser.parse_if_condition(mut mixed_tokens) == none
}

fn test_non_overridable_counter_styles_are_only_allowed_in_ua_stylesheets() {
	text := '@counter-style disclosure-open { system: cyclic; symbols: "x"; suffix: " "; }'
	assert parse_rules(text).len == 0
	ua_rules := parse_css_stylesheet_contents_with_params(ParsingParams{
		is_ua_style_sheet: .yes
	}, text)
	assert ua_rules.len == 1
	rule := ua_rules[0].counter_style_rule_value() or { panic('missing counter-style rule') }
	assert rule.name() == 'disclosure-open'
}

fn test_selector_retains_typed_compound_selectors() {
	selector := selector_from_text('main > .storylink:is(a, button)')
	assert selector.data_ != unsafe { nil }
	compound_selectors := selector.compound_selectors()
	assert compound_selectors.len == 2
	assert compound_selectors[0].simple_selectors[0].type_ == .tag_name
	assert compound_selectors[1].combinator == .immediate_child
	assert compound_selectors[1].simple_selectors[1].type_ == .pseudo_class
	assert compound_selectors[1].simple_selectors[1].pseudo_class().argument_selector_list.selectors.len == 2
}

fn test_nested_selector_absolutization_rewrites_typed_tree() {
	selector := selector_from_text('& > .title:is(&, a)')
	assert selector.contains_the_nesting_selector()
	selector_for_nesting := SimpleSelector.with_pseudo_class(.pseudo_class, PseudoClassSelector{
			type_: .is_
			argument_selector_list: SelectorList{
				selectors: [selector_from_text('.parent')]
			}
		})
	absolutized := selector.absolutized(selector_for_nesting) or {
		panic('failed to absolutize nested selector')
	}
	assert !absolutized.contains_the_nesting_selector()
	assert absolutized.serialize().contains('.parent')
}

fn selector_text_of(selector string) ?string {
	rules := parse_rules('${selector} {}')
	if rules.len != 1 {
		return none
	}
	return rules[0].selector_text()
}

// Token::to_string() serializes a <number> from its value, so it drops the
// explicit `+` in `:nth-child(2n+1)`. Upstream never notices, because
// Parser::parse_a_selector_list() consumes the component values directly rather
// than rebuilding the prelude as text; this parser does rebuild it, so the
// numeric tokens have to come from their original source text.
fn test_an_plus_b_keeps_an_explicit_plus_sign() {
	assert selector_text_of(':nth-child(2n+1)')? == ':nth-child(2n+1)'
	assert selector_text_of(':nth-child(2n +1)')? == ':nth-child(2n+1)'
	assert selector_text_of(':nth-child( 2n+1 )')? == ':nth-child(2n+1)'
	assert selector_text_of(':nth-child(+2n+1)')? == ':nth-child(2n+1)'
	assert selector_text_of(':nth-child(-n+3)')? == ':nth-child(-n+3)'
	assert selector_text_of(':nth-child(n+1)')? == ':nth-child(n+1)'
	assert selector_text_of(':nth-last-of-type(-2n+3)')? == ':nth-last-of-type(-2n+3)'
	// The An+B value is normalized on the way out.
	assert selector_text_of(':nth-child(3n+0)')? == ':nth-child(3n)'
	assert selector_text_of(':nth-child(0n+5)')? == ':nth-child(5)'
	assert selector_text_of(':nth-child(-1n+2)')? == ':nth-child(-n+2)'
	assert selector_text_of(':nth-child(2N+1)')? == ':nth-child(2n+1)'
	// Negative offsets were already reaching the parser intact.
	assert selector_text_of(':nth-child(2n-1)')? == ':nth-child(2n-1)'
	// Identifier escapes still decode, which the original source text would not.
	assert selector_text_of('[\\61 =b]')? == '[a="b"]'
}

// Selector::SimpleSelector::serialize() emits a namespace prefix only for a
// named namespace or the null namespace. Unlike an attribute selector, the
// any-namespace prefix of a type or universal selector is dropped.
fn test_any_namespace_prefix_is_dropped_for_type_selectors() {
	assert selector_text_of('*|div')? == 'div'
	assert selector_text_of('*|*')? == '*'
	assert selector_text_of('|div')? == '|div'
	assert selector_text_of('div')? == 'div'
	// An attribute selector keeps it.
	assert selector_text_of('[*|a]')? == '[*|a]'
	assert selector_text_of('[|a]')? == '[a]'
}

// Both the ANPlusB and ANPlusBOf parameter types serialize as "the result of
// serializing the value using the rules to serialize an <an+b> value", so the
// `of S` argument does not appear.
fn test_nth_child_of_selector_is_not_serialized() {
	assert selector_text_of(':nth-child(2n of .a)')? == ':nth-child(2n)'
	assert selector_text_of(':nth-child(2n+1 of .a)')? == ':nth-child(2n+1)'
	assert selector_text_of(':nth-last-child(3 of div, .b)')? == ':nth-last-child(3)'
	// `of S` is only allowed on nth-child/nth-last-child.
	assert selector_text_of(':nth-of-type(2n of .a)') == none
}

// Parser::parse_pseudo_element_selector() records the authored spelling of an
// aliased pseudo-element, so it round-trips instead of collapsing to the
// canonical name it aliases.
fn test_aliased_pseudo_elements_keep_their_authored_name() {
	assert selector_text_of('::-webkit-progress-bar')? == '::-webkit-progress-bar'
	assert selector_text_of('::-webkit-meter-bar')? == '::-webkit-meter-bar'
	assert selector_text_of('::-moz-placeholder')? == '::-moz-placeholder'
	assert selector_text_of('::-WEBKIT-PROGRESS-BAR')? == '::-webkit-progress-bar'
	// A canonical name serializes canonically.
	assert selector_text_of('::slider-track')? == '::slider-track'
	assert selector_text_of('::before')? == '::before'
	assert selector_text_of('::BEFORE')? == '::before'
}

// A selector is parsed from text here, so "consume an escaped code point" has to
// decode the numeric form: `\31 23` is the identifier `123`, and the whitespace
// that terminates the escape belongs to it rather than separating tokens.
fn test_numeric_escapes_decode_in_selectors() {
	assert selector_text_of('\\31 23')? == '\\31 23'
	assert selector_text_of('[a=\\31 23]')? == '[a="123"]'
	assert selector_text_of('[a=\\31 23 i]')? == '[a="123" i]'
	assert selector_text_of('.\\41 BC')? == '.ABC'
	assert selector_text_of('.\\000041')? == '.A'
	// Single-character escapes keep working.
	assert selector_text_of('.a\\ b')? == '.a\\ b'
	assert selector_text_of('.\\@x')? == '.\\@x'
}

fn css_text_of(rule_text string) ?string {
	rules := parse_rules(rule_text)
	if rules.len < 1 {
		return none
	}
	return rules[0].css_text()
}

// "In addition to nested style rules, this specification allows nested group
// rules inside of style rules". CSSStyleRule is itself a CSSGroupingRule, so a
// nested style rule is a valid child of a style rule; the port only accepted
// @media, @supports and @layer and dropped nested style rules on the floor.
fn test_style_rules_nest_inside_style_rules() {
	assert css_text_of('a { & b { color: red } }')? == 'a {\n  & b { color: red; }\n}'
	// A relative selector without a combinator gains the implicit `&`.
	assert css_text_of('a { .x { color: red } }')? == 'a {\n  & .x { color: red; }\n}'
	assert css_text_of('a { > b { color: red } }')? == 'a {\n  & > b { color: red; }\n}'
	// Declarations come before the nested rules.
	assert css_text_of('a { color: red; & > b { color: blue } }')? ==
		'a {\n  color: red;\n  & > b { color: blue; }\n}'
	// Nesting composes with group rules and with itself.
	assert css_text_of('a { & b { & c { color: red } } }')? ==
		'a {\n  & b {\n  & c { color: red; }\n}\n}'
	assert css_text_of('a { @media screen { & b { color: red } } }')? ==
		'a {\n  @media screen {\n  & b { color: red; }\n}\n}'
}

// Keyframe names retain their logical identifier or string value. The rule
// serializer then inserts that name verbatim inside quotes.
fn test_keyframes_name_uses_logical_token_value() {
	assert css_text_of('@keyframes a { from { opacity: 0 } }')? == '@keyframes "a" { 0% { opacity: 0; } }'
	assert css_text_of('@keyframes \\31 a { from { opacity: 0 } }')? == '@keyframes "1a" { 0% { opacity: 0; } }'
	quoted := parse_css_stylesheet_with_parser('@keyframes "123fade" { from { opacity: 0 } }', none)
	quoted_rule := quoted.css_rules().item(0) or { panic('missing quoted keyframes rule') }
	assert quoted_rule.keyframes_name() == '123fade'
	assert quoted_rule.css_text() == '@keyframes "123fade" { 0% { opacity: 0; } }'
}

fn test_keyframes_reject_css_animations_level_one_properties() {
	assert css_text_of('@keyframes allowed {
		from {
			margin-top: 10px;
			animation-timing-function: ease;
			animation-composition: add;
			animation: ignored 1s;
			animation-name: ignored;
			animation-duration: 1s;
			animation-iteration-count: 2;
			animation-direction: reverse;
			animation-play-state: paused;
			animation-delay: 1s;
			animation-fill-mode: both;
			animation-timeline: auto;
		}
	}')? == '@keyframes "allowed" { 0% { margin-top: 10px; animation-timing-function: ease; animation-composition: add; } }'
}

// CSSImportRule::serialized() performs "serialize a URL" on the rule's location,
// which wraps it in `url(...)` with the URL serialized as a string.
fn test_import_rule_serializes_its_url() {
	assert css_text_of('@import url(a.css);')? == '@import url("a.css");'
	assert css_text_of('@import url(a.css) screen;')? == '@import url("a.css") screen;'
}

// Gfx::UnicodeRange::to_string() formats each code point with `U+{:X}`, without
// zero padding.
fn test_unicode_range_is_not_zero_padded() {
	assert css_text_of('@font-face { font-family: X; unicode-range: U+0-7F, U+100-1FF }')? ==
		'@font-face { font-family: X; unicode-range: U+0-7F, U+100-1FF; }'
	assert css_text_of('@font-face { font-family: X; unicode-range: U+41 }')? ==
		'@font-face { font-family: X; unicode-range: U+41; }'
}

// Parser::DescriptorList::append() expands a shorthand descriptor into its
// longhands before the "only the last instance of each descriptor" rule applies.
fn test_page_margin_descriptor_expands_to_longhands() {
	assert css_text_of('@page { margin: 1cm }')? ==
		'@page { margin-top: 1cm; margin-right: 1cm; margin-bottom: 1cm; margin-left: 1cm; }'
	assert css_text_of('@page { margin: 1cm 2cm }')? ==
		'@page { margin-top: 1cm; margin-right: 2cm; margin-bottom: 1cm; margin-left: 2cm; }'
	// A later longhand replaces only its own entry, and moves to the end.
	assert css_text_of('@page { margin: 1cm; margin-top: 2cm }')? ==
		'@page { margin-right: 1cm; margin-bottom: 1cm; margin-left: 1cm; margin-top: 2cm; }'
	assert css_text_of('@page :left { margin: 0 }')? ==
		'@page :left { margin-top: 0px; margin-right: 0px; margin-bottom: 0px; margin-left: 0px; }'
}

// A custom property keeps its declared value verbatim: "set decl's original text
// to the segment of the original source text string corresponding to the tokens
// of decl's value", and UnresolvedStyleValue serializes that text.
fn test_custom_property_keeps_its_original_source_text() {
	assert css_text_of('a { --x: Foo Bar }')? == 'a { --x: Foo Bar; }'
	assert css_text_of('a { --x: 1px  2px }')? == 'a { --x: 1px  2px; }'
	assert css_text_of('a { --x: calc( 1px  +  2px ) }')? == 'a { --x: calc( 1px  +  2px ); }'
	assert css_text_of("a { --x: 'a  b' }")? == "a { --x: 'a  b'; }"
	assert css_text_of('a { --x: a /* c */ b }')? == 'a { --x: a /* c */ b; }'
	assert css_text_of('a { --x: url( a.png ) }')? == 'a { --x: url( a.png ); }'
	assert css_text_of('a { --x: a,  b }')? == 'a { --x: a,  b; }'
}
