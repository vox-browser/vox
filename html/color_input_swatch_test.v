module html

import css
import dom

// Ladybird a468d7109e4d76dc47d80eb0ceaf1886ce62b0d7.
fn test_color_input_registers_styleable_swatch_and_wrapper() {
	document := parse_document('<input id="color" type="color" value="#123456">')
	host := document.get_element_by_id('color') or { panic('missing color input') }
	mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(host) })
	well := model.color_well_element_ or { panic('missing swatch') }
	wrapper := well.as_node().parent_element() or { panic('missing swatch wrapper') }
	assert well.associated_shadow_host_pseudo_element()? == int(css.PseudoElement.color_swatch)
	assert wrapper.associated_shadow_host_pseudo_element()? == int(css.PseudoElement.webkit_color_swatch_wrapper)
	assert host.element_reference_pseudo_element(int(css.PseudoElement.color_swatch))? == well
	assert host.element_reference_pseudo_element(int(css.PseudoElement.webkit_color_swatch_wrapper))? == wrapper
	assert wrapper.get_attribute_value('style') == ''
	assert well.get_attribute_value('style') == 'background-color:#123456;'
	model.set_value('#aabbcc')!
	assert well.get_attribute_value('style') == 'background-color:#aabbcc;'

	css.add_document_author_style_sheet(document, 'input::-webkit-color-swatch-wrapper { padding: 8px; } input::color-swatch { border: 3px solid red; min-width: 11px; }')
	computer := css.StyleComputer.new(document)
	computed_wrapper := computer.compute_style(dom.AbstractElement.new(wrapper, none))
	computed_well := computer.compute_style(dom.AbstractElement.new(well, none))
	assert (computed_wrapper.property(.padding_top, .no) or { panic('padding') }).css_text == '8px'
	assert (computed_well.property(.border_top_width, .no) or { panic('border') }).css_text == '3px'
	assert (computed_well.property(.min_width, .no) or { panic('min-width') }).css_text == '11px'
	assert (computed_well.property(.background_color, .no) or { panic('background') }).css_text == 'rgb(170, 187, 204)'
}
