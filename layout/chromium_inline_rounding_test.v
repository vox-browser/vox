module layout

import css
import dom
import html

fn chromium_rounding_document(markup string, chromium bool) &dom.Document {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:13px Helvetica}</style>${markup}')
	if chromium {
		document.set_font_rendering_policy(.chromium)
	}
	_ = layout_document_typed_in_viewport(document, 400, 300)
	return document
}

fn chromium_rounding_rect(document &dom.Document, id string) dom.Rect {
	element := css.query_selector(document.as_node(), '#${id}') or { panic('missing ${id}') }
	return element.get_bounding_client_rect()
}

// LayoutNG converts a fixed relative offset with LayoutUnit(float), which
// truncates -11.2px to -11.1875px; LibWeb rounds it to -11.203125px.
fn test_chromium_relative_offsets_truncate_toward_zero() {
	markup := '<div style="padding-top:20px"><span id="r" style="position:relative;top:-11.2px">x</span></div>'
	mut chromium := chromium_rounding_document(markup, true)
	defer { chromium.finalize() }
	mut libweb := chromium_rounding_document(markup, false)
	defer { libweb.finalize() }
	unshifted_markup := '<div style="padding-top:20px"><span id="r">x</span></div>'
	mut reference := chromium_rounding_document(unshifted_markup, true)
	defer { reference.finalize() }
	base := chromium_rounding_rect(reference, 'r').y
	assert chromium_rounding_rect(chromium, 'r').y - base == -11.1875
	assert chromium_rounding_rect(libweb, 'r').y - base == -11.203125
}
