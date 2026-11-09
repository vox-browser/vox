module css

import dom

fn test_corner_keywords_compute_to_superellipse_values() {
 mut document := dom.Document.create(dom.url_about_blank())
 defer { document.finalize() }
 add_document_author_style_sheet(document,'.target { corner-shape:bevel; }')
 mut element := document.create_element('div') or { panic(err) }
 element.set_attribute_value('class','target')
 mut computer := StyleComputer.new(document)
 style := computer.compute_style(dom.AbstractElement.new(element,none))
 for id in [PropertyID.corner_top_left_shape,.corner_top_right_shape,.corner_bottom_left_shape,.corner_bottom_right_shape] {
  assert property_requires_computation_with_cascaded_value(id)
  assert (style.property(id,.no) or { panic('corner') }).css_text == 'superellipse(0)', string_from_property_id(id)
  assert (typed_style_value_logic_from_dom(style.property(id,.no)?)?).serialize(.resolved_value) == 'superellipse(0)'
 }
}
