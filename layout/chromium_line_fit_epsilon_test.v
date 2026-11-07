module layout

import css
import html

// Blink's LineBreaker fits content that overflows the available width by one
// LayoutUnit (AvailableWidthToFit adds 1/64px). A 4chan catalog teaser line
// measuring 150.015625px stays on its 150px line in Brave; a 1/32px overflow
// still wraps. LibWeb keeps its exact comparison.
fn test_chromium_line_accepts_one_layout_unit_of_overflow() {
	for chromium in [true, false] {
		for second_width, fits_in_chromium in {
			'50px':        true
			'50.015625px': true
			'50.03125px':  false
		} {
			mut document := html.parse_document('<!doctype html><style>
				body { margin:0; font:10px/12px monospace }
				#line { width:150px }
				span { display:inline-block; height:12px; vertical-align:top }
			</style><div id="line"><span id="first" style="width:100px"></span><span id="second" style="width:${second_width}"></span></div>')
			if chromium {
				document.set_font_rendering_policy(.chromium)
			}
			defer { document.finalize() }
			_ = layout_document_typed_in_viewport(document, 300, 100)
			first := css.query_selector(document.as_node(), '#first') or { panic('first missing') }
			second := css.query_selector(document.as_node(), '#second') or { panic('second missing') }
			assert first.get_bounding_client_rect().y == 0
			fits := if chromium { fits_in_chromium } else { second_width == '50px' }
			y := second.get_bounding_client_rect().y
			assert (y == 0) == fits, 'chromium=${chromium} width=${second_width} y=${y}'
		}
	}
}

// The catalog teaser that exposed the tolerance: Brave measures the second
// line, a bold item followed by plain text, at 150.015625px and keeps it on a
// 150px line, while a 149.984375px line moves "the" down.
fn test_chromium_catalog_teaser_line_fits_within_one_layout_unit() {
	$if !macos {
		return
	}
	for width, the_on_second_line in {
		'149.984375px': false
		'150px':        true
		'150.015625px': true
	} {
		mut document := html.parse_document('<!doctype html><style>
			body { margin:0 }
			div { width:${width}; font:10pt arial, helvetica, sans-serif; text-align:center }
		</style><div><b>Democrats the Real Racists</b>: Why doesn\'t the <span id="far">far</span> right join the democrats</div>')
		document.set_font_rendering_policy(.chromium)
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 300)
		far := css.query_selector(document.as_node(), '#far') or { panic('far missing') }
		rect := far.get_bounding_client_rect()
		// "far" starts the third line; it follows "the" when "the" wraps too.
		assert rect.y > 25 && rect.y < 40, 'width=${width} y=${rect.y}'
		assert (rect.x < 35) == the_on_second_line, 'width=${width} x=${rect.x}'
	}
}
