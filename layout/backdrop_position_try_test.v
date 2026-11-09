module layout

import css
import dom
import html

fn test_backdrop_resolved_style_uses_its_position_try_layout_geometry() {
	url := dom.URL{value:'https://backdrop-try.test/'}
	mut document := html.parse_navigation_document('<!doctype html><style>@position-try --a{left:300px}dialog::backdrop{width:100px;height:100px;left:9999px;position-try-fallbacks:--a}</style><dialog id="dialog">Dialog</dialog>',url,url.origin(),none)!
	defer { document.finalize() }
	dialog := document.get_element_by_id('dialog') or { panic('dialog') }
	html.html_dialog_element_show_modal(unsafe { &dom.HTMLDialogElement(dialog) })!
	run_document_layout(document,800,600) or { panic('layout') }
	style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(dialog,.backdrop))
	assert style.get_property_value('left') == '300px'
}
