module css

import dom

fn test_italic_font_style_endpoints_interpolate_discretely() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element('div') or { panic(err) }
	for pair in [['italic','normal'],['normal','italic'],['italic','oblique 20deg']] {
		from := parse_css_value(ParsingParams{},pair[0],.font_style) or { panic('from') }
		to := parse_css_value(ParsingParams{},pair[1],.font_style) or { panic('to') }
		assert interpolate_property(element,.font_style,from,to,0.3,.yes)?.css_text == pair[0]
		assert interpolate_property(element,.font_style,from,to,0.6,.yes)?.css_text == pair[1]
		assert interpolate_property(element,.font_style,from,to,1,.yes)?.css_text == pair[1]
	}
}
