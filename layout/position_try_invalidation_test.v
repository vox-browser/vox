module layout

import css
import dom
import html

fn test_position_try_layout_tracks_media_and_rule_changes() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#anchor{anchor-name:--a;margin-left:100px;width:100px;height:100px}#target{position:absolute;width:100px;height:100px;left:999999px;position-try-fallbacks:--a}</style><style id="rules" media="print">@position-try --a{left:anchor(--a left)}</style><div id="anchor"></div><div id="target"></div>')
	defer { document.finalize() }
	target := document.get_element_by_id('target') or { panic('target') }
	run_document_layout(document,800,600) or { panic('layout') }
	assert target.get_bounding_client_rect().x == 999999
	mut sheet := css.style_element_sheet(document.get_element_by_id('rules') or { panic('rules') }) or { panic('sheet') }
	mut style := document.get_element_by_id('rules') or { panic('rules') }
	style.set_attribute_value('media','')
	run_document_layout(document,800,600) or { panic('layout') }
	assert target.get_bounding_client_rect().x == 100
	sheet = css.style_element_sheet(style) or { panic('sheet') }
	sheet.insert_rule('@position-try --a{left:anchor(--a right)}',1)!
	run_document_layout(document,800,600) or { panic('layout') }
	assert target.get_bounding_client_rect().x == 200
}

fn test_inserted_shadow_position_try_rules_invalidate_the_host_and_slotted_targets() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><div id="host"><div id="slotted"></div></div>')
	defer { document.finalize() }
	mut host := document.get_element_by_id('host') or { panic('host') }
	mut shadow := host.attach_shadow(dom.ShadowRootInit{mode:.open})!
	shadow.set_inner_html('<style>:host,::slotted(*){position:absolute;left:999999px;width:100px;height:100px;position-try-fallbacks:--a}</style><slot></slot>')!
	run_document_layout(document,800,600) or { panic('layout') }
	assert host.get_bounding_client_rect().x == 999999
	style := unsafe { &dom.ParentNode(shadow) }.query_selector('style') or { panic('style') }
	mut sheet := css.style_element_sheet(style) or { panic('sheet') }
	sheet.insert_rule('@position-try --a{left:100px}',0)!
	run_document_layout(document,800,600) or { panic('layout') }
	assert host.get_bounding_client_rect().x == 100
}
