module css

import dom

fn test_svg_paint_fallback_colors_are_absolutized_with_computed_values() {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', [
		'font-size: 16px',
		'fill: url(#missing-fill) rgb(0 calc(255 * sign(1em - 1px)) 0)',
		'stroke: url(#missing-stroke) rgb(0 calc(255 * sign(1em - 1px)) 0)',
	].join('; '))
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	fill_value := computed.property(.fill, .no) or { panic('missing fill') }
	stroke_value := computed.property(.stroke, .no) or { panic('missing stroke') }
	assert !fill_value.css_text.contains('calc(')
	assert !stroke_value.css_text.contains('calc(')

	values := resolve_computed_values_for_document(computed, document)
	fill := values.fill() or { panic('missing resolved fill') }
	stroke := values.stroke() or { panic('missing resolved stroke') }
	assert fill.is_url()
	assert stroke.is_url()
	assert fill.fallback_color()? == Color{0, 255, 0, 255}
	assert stroke.fallback_color()? == Color{0, 255, 0, 255}
}

fn test_svg_paint_url_serialization_uses_a_noncollapsible_value_list() {
	paint := parse_css_value_logic(.fill, 'url(#paint) red') or { panic('paint did not parse') }
	paint_list := match paint {
		StyleValueList { paint }
		else { panic('paint is not a value list') }
	}
	assert paint_list.values().len == 2
	assert paint_list.values()[0] is URLStyleValue
	assert paint.serialize(.normal) == 'url("#paint") red'

	url_only := parse_css_value_logic(.stroke, 'url(#paint) none') or {
		panic('paint did not parse')
	}
	url_only_list := match url_only {
		StyleValueList { url_only }
		else { panic('paint is not a value list') }
	}
	assert url_only_list.values().len == 1
	assert url_only.serialize(.normal) == 'url("#paint")'
}
