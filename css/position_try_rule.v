module css

// https://drafts.csswg.org/css-anchor-position-1/#accepted-position-try-properties
pub fn is_accepted_position_try_property(property PropertyID) bool {
	return property in [.margin,.margin_top,.margin_right,.margin_bottom,.margin_left,
		.margin_block,.margin_block_start,.margin_block_end,.margin_inline,.margin_inline_start,.margin_inline_end,
		.inset,.top,.left,.right,.bottom,.inset_block,.inset_block_start,.inset_block_end,
		.inset_inline,.inset_inline_start,.inset_inline_end,.width,.height,.min_width,.max_width,.min_height,.max_height,
		.block_size,.min_block_size,.max_block_size,.inline_size,.min_inline_size,.max_inline_size,
		.place_self,.align_self,.justify_self,.position_anchor,.position_area]
}

pub fn (declaration &CSSStyleProperties) is_position_try_descriptors() bool {
	return if owner := declaration.parent_rule { owner.type_ == .position_try } else { false }
}

fn (mut declaration CSSStyleProperties) filter_position_try_descriptors() {
	if !declaration.is_position_try_descriptors() { return }
	declaration.clear_typed_properties_cache()
	declaration.properties = declaration.properties.filter(!it.important &&
		is_accepted_position_try_property(property_id_from_string(it.name) or { PropertyID.color }))
	declaration.custom_properties.clear()
}

pub fn CSSRule.create_position_try(name string, declaration &CSSStyleProperties) &CSSRule {
	mut rule := CSSRule.create(.position_try)
	rule.kind_data_ = &CSSRuleKindData{position_try_name:name}
	rule.declaration = declaration
	mut properties := unsafe { &CSSStyleProperties(declaration) }
	properties.set_parent_rule(rule)
	properties.filter_position_try_descriptors()
	return rule
}

pub fn (rule &CSSRule) position_try_name() string {
	return serialize_an_identifier(rule.kind_data().position_try_name)
}

fn (rule &CSSRule) serialized_position_try_rule() string {
	text := if declaration := rule.declaration { declaration.serialized() } else { '' }
	return '@position-try ${rule.position_try_name()} { ${text}${if text == "" { "" } else { " " }}}'
}

fn (mut parser RuleSelectorParser) convert_to_position_try_rule(rule AtRule) ?&CSSRule {
	if !rule.is_block_rule { return none }
	mut tokens := ParserTokenStream.from_values(rule.prelude)
	tokens.discard_whitespace()
	name := tokens.consume_a_token()
	if !name.is(.ident) || !name.token().ident().starts_with('--') || name.token().ident().len < 3 { return none }
	tokens.discard_whitespace()
	if tokens.has_next_token() { return none }
	declaration := parser.convert_to_style_declaration(declarations_from_at_rule(rule))
	return CSSRule.create_position_try(name.token().ident(),declaration)
}
