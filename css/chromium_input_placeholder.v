module css

import dom

fn adjust_chromium_input_placeholder_style(mut properties ComputedProperties, element dom.AbstractElement) {
	pseudo := element.pseudo_element() or { return }
	if pseudo != .placeholder
		|| element.element().document().font_rendering_policy() != .chromium
		|| !element.element().is_html_element() || element.element().local_name() != 'input' {
		return
	}
	// Blink's html.css forces line-height:initial !important on input
	// placeholders. The placeholder property whitelist omits line-height, so
	// apply this UA override after inheritance instead of admitting author rules.
	properties.set_property(.line_height,
		dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.normal))), .no, .yes)
}
