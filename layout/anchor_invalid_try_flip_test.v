module layout

import css
import dom
import html

fn test_flip_to_an_invalid_anchor_query_uses_resolved_static_insets() {
	mut document := html.parse_document('<!doctype html><style>#cb{position:relative;width:200px;height:200px}#main>div,#ref{position:absolute}</style><div id="cb"><div id="main"></div><div id="ref">X</div></div>')
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	container := document.get_element_by_id('cb') or { panic('cb') }
	main := document.get_element_by_id('main') or { panic('main') }
	mut target := document.create_element('div')!
	target.set_attribute_value('id','target')
	target.as_node().set_text_content('X')!
	main.as_node().append_child(target.as_node())!
	sheet := document.create_element('style')!
	sheet.as_node().set_text_content('@position-try --pt{left:10px;top:anchor(top)}#target{left:9999px;position-try-fallbacks:--pt flip-block}')!
	container.as_node().append_child(sheet.as_node())!
	run_document_layout(document,800,600) or { panic('layout') }
	style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(target,none))
	reference := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(document.get_element_by_id('ref') or { panic('ref') },none))
	assert style.get_property_value('left') == '10px'
	assert style.get_property_value('top') == reference.get_property_value('top')
	assert style.get_property_value('bottom') == reference.get_property_value('bottom')
}
