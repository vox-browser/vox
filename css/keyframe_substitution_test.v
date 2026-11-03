module css

import dom

fn test_keyframe_lengths_substitute_target_variables_before_computation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{width: 1024, height: 768})
	mut root := document.create_element('html')!
	mut target := document.create_element('div')!
	document.as_node().append_child(root.as_node())!
	root.as_node().append_child(target.as_node())!
	add_document_author_style_sheet(document, 'html{--collapsed:56px;--travel:204px} div{width:764px;position:sticky;inset-inline-start:260px}')
	mut computer := StyleComputer.new(document)
	root_style := computer.compute_style(dom.AbstractElement.new(root, none))
	root.set_computed_properties(none, computed_properties_to_dom(root_style))
	subject := dom.AbstractElement.new(target, none)
	base := computer.compute_style(subject)
	target.set_computed_properties(none, computed_properties_to_dom(base))
	keyframe := ResolvedKeyFrame{properties: {
		PropertyID.width: parse_css_value(ParsingParams{}, 'calc(100vw - calc(var(--collapsed) + var(--travel)))', .width) or { panic('parse width') }
		.inset_inline_start: parse_css_value(ParsingParams{}, 'calc(var(--collapsed) + var(--travel))', .inset_inline_start) or { panic('parse inset') }
	}}
	values := computer.compute_keyframe_values(subject, keyframe, base)
	width := values[.width] or { panic('width') }
	left := values[.left] or { panic('left') }
	assert !width.css_text.contains('var(')
	context := LengthResolutionContext.for_element(&subject)
	assert LengthPercentage.from_style_value(width).to_px(context, CSSPixels.new(1024)).to_double() == 764
	assert LengthPercentage.from_style_value(left).to_px(context, CSSPixels.new(1024)).to_double() == 260
	assert (keyframe.properties[.width] or { panic('specified width') }).css_text.contains('var(')
}
