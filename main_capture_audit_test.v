module main

import crypto.sha256
import css
import dom
import html
import json

fn test_capture_audit_reads_retained_text_attributes_counts_and_geometry() {
	mut document := html.parse_document('<!doctype html><title>Capture</title><style>body{margin:0}.row{width:70px;height:20px}</style><div class="row" data-key="one">Первый</div><div class="row" data-key="two">Second</div>')
	mut app := BrowserApp{document: document, js_messages: ['retained diagnostic']}
	app.relayout(200, 232)
	before_list := document.cached_display_list() or { panic('missing retained display list') }
	audit := app.collect_capture_audit(CaptureAuditConfig{selectors: [
		CaptureAuditSelector{name: 'rows', selector: '.row', limit: 1, attributes: ['data-key', 'missing']},
		CaptureAuditSelector{name: 'count', selector: '.row', limit: 0},
	]})!
	assert audit.title == 'Capture'
	assert audit.viewport_width == 200 && audit.viewport_height == 120
	assert audit.javascript_diagnostics == ['retained diagnostic']
	assert audit.selections.len == 2
	assert audit.selections[0].count == 2
	assert audit.selections[0].elements.len == 1
	row := audit.selections[0].elements[0]
	assert row.text == 'Первый'
	assert row.text_utf8_bytes == 'Первый'.len
	assert row.text_sha256 == sha256.hexhash('Первый')
	assert row.rect.width == 70 && row.rect.height == 20
	assert row.attributes == {'data-key': 'one'}
	assert row.image == none
	assert audit.selections[1].count == 2 && audit.selections[1].elements.len == 0
	assert voidptr(document.cached_display_list() or { panic('missing retained list') }) == voidptr(before_list)
	decoded := json.decode(CaptureAudit, json.encode(audit))!
	assert decoded.selections[0].elements[0].text == 'Первый'
}

fn test_capture_audit_does_not_materialize_missing_image_or_font_state() {
	mut document := html.parse_document('<!doctype html><img id="image" src="https://unavailable.invalid/a.png">')
	css.install_document_selector_query_hook(document)
	image := document.get_element_by_id('image') or { panic('missing image') }
	image_dom := unsafe { &dom.HTMLImageElement(image) }
	before_model := image_dom.image_element_model_
	mut before_fonts := voidptr(0)
	if owner := document.existing_font_face_set() {
		before_fonts = owner.font_face_set_record()
	}
	app := BrowserApp{document: document}
	audit := app.collect_capture_audit(CaptureAuditConfig{selectors: [
		CaptureAuditSelector{name: 'images', selector: 'img'},
	]})!
	assert audit.selections[0].count == 1
	state := audit.selections[0].elements[0].image or { panic('missing image audit') }
	assert state.model_present == (before_model != unsafe { nil })
	assert !state.paint_decoded && state.paint_width == 0 && state.paint_height == 0
	assert image_dom.image_element_model_ == before_model
	mut after_fonts := voidptr(0)
	if owner := document.existing_font_face_set() {
		after_fonts = owner.font_face_set_record()
	}
	assert after_fonts == before_fonts
}

fn test_capture_audit_rejects_invalid_config_and_retains_empty_selector_results() {
	mut document := html.parse_document('<!doctype html><p>Content</p>')
	css.install_document_selector_query_hook(document)
	app := BrowserApp{document: document}
	for config in [
		CaptureAuditSelector{name: '', selector: 'p'},
		CaptureAuditSelector{name: 'rows', selector: ''},
		CaptureAuditSelector{name: 'rows', selector: 'p', limit: -1},
		CaptureAuditSelector{name: 'rows', selector: 'p', limit: 1001},
		CaptureAuditSelector{name: 'rows', selector: '['},
	] {
		if _ := app.collect_capture_audit(CaptureAuditConfig{selectors: [config]}) {
			assert false, 'invalid audit config accepted'
		}
	}
	audit := app.collect_capture_audit(CaptureAuditConfig{selectors: [
		CaptureAuditSelector{name: 'missing', selector: '.missing'},
	]})!
	assert audit.selections[0].count == 0 && audit.selections[0].elements.len == 0
}
