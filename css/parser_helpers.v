module css

import dom
import encoding

// Direct translation of Libraries/LibWeb/CSS/Parser/Helpers.cpp. JavaScript
// realm ownership is represented by ParsingParams' document boundary in V;
// the parsing and decoding algorithms themselves remain typed.

pub fn parse_css_stylesheet(context ParsingParams, css_text string, location ?string, media_list ?&MediaList) &CSSStyleSheet {
	if css_text.len == 0 {
		rule_list := CSSRuleList.create([]&CSSRule{})
		media := media_list or { MediaList.create_empty() }
		mut style_sheet := CSSStyleSheet.create(rule_list, media, location)
		style_sheet.set_source_text('')
		return style_sheet
	}
	mut parser := RuleSelectorParser.create_for_stylesheet(context, css_text)
	mut style_sheet := parser.parse_as_css_stylesheet(location, media_list)
	style_sheet.set_source_text(css_text)
	return style_sheet
}

pub fn parse_css_property_declaration_block(context ParsingParams, css_text string) &CSSStyleProperties {
	if css_text.len == 0 {
		return CSSStyleProperties.create()
	}
	return parse_css_property_declaration_block_with_params(context, css_text)
}

pub fn parse_css_type(context ParsingParams, text string, value_type ValueType) ?&dom.StyleValue {
	if text.len == 0 {
		return none
	}
	mut parser := Parser.with_context(context, text)
	value := parser.parse_as_type(value_type) or { return none }
	return dom_style_value_from_value_logic(value)
}

pub fn parse_css_descriptor(context ParsingParams, at_rule_id AtRuleID, descriptor_id DescriptorID, text string) ?&dom.StyleValue {
	if text.len == 0 {
		return none
	}
	mut parser := Parser.with_context(context, text)
	value := parser.parse_descriptor_value(at_rule_id, descriptor_id) or { return none }
	return dom_style_value_from_value_logic(value)
}

pub fn parse_css_rule(context ParsingParams, css_text string) ?&CSSRule {
	mut parser := RuleSelectorParser.create(context, css_text, 'utf-8')
	return parser.parse_as_css_rule()
}

pub fn parse_selector_for_nested_style_rule(context ParsingParams, selector_text string, nesting_parent StyleNestingParent) ?SelectorList {
	mut parser := RuleSelectorParser.create(context, selector_text, 'utf-8')
	selectors := parser.parse_as_relative_selector(.standard) or { return none }
	return adapt_nested_relative_selector_list(selectors, nesting_parent)
}

pub fn parse_media_query_list(context ParsingParams, text string) []&MediaQuery {
	_ = context
	return parse_css_media_query_list_value_logic(text)
}

pub fn parse_component_values_list(parsing_params ParsingParams, text string) []ComponentValue {
	mut parser := RuleSelectorParser.create(parsing_params, text, 'utf-8')
	return parser.parse_as_list_of_component_values()
}

// https://drafts.csswg.org/css-syntax/#css-decode-bytes
pub fn css_decode_bytes(environment_encoding ?string, mime_type_charset ?string, encoded_string []u8) !string {
	mut fallback := ''
	if charset := mime_type_charset {
		fallback = encoding.get_an_encoding(charset) or { '' }
	}
	if fallback == '' {
		scan_length := if encoded_string.len < 1024 { encoded_string.len } else { 1024 }
		pattern_start := '@charset "'.bytes()
		if scan_length >= pattern_start.len && encoded_string[..pattern_start.len] == pattern_start {
			mut end_index := -1
			for index := pattern_start.len; index + 1 < scan_length; index++ {
				if encoded_string[index] == `"` && encoded_string[index + 1] == `;` {
					end_index = index
					break
				}
			}
			if end_index >= 0 {
				label_bytes := encoded_string[pattern_start.len..end_index]
				mut valid := true
				for byte in label_bytes {
					if (byte < 0x01 || byte > 0x21) && (byte < 0x23 || byte > 0x7f) {
						valid = false
						break
					}
				}
				if valid {
					label := label_bytes.bytestr()
					fallback = encoding.get_an_encoding(label) or { '' }
					if fallback in ['UTF-16BE', 'UTF-16LE'] {
						fallback = 'utf-8'
					}
				}
			}
		}
	}
	if fallback == '' {
		fallback = environment_encoding or { 'utf-8' }
	}
	decoder := encoding.TextDecoder.construct(fallback, encoding.TextDecoderOptions{})!
	return decoder.decode(encoded_string, encoding.TextDecodeOptions{})!
}
