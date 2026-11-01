module page

import css
import dom
import html
import layout

fn test_reduced_transparency_defaults_and_page_boundaries() {
	mut detached := dom.Document.create(dom.url_about_blank())
	defer { detached.finalize() }
	assert !detached.prefers_reduced_transparency()
	assert !(&dom.Page{}).prefers_reduced_transparency()

	mut first := Page.create(1)!
	second := Page.create(1)!
	mut document := html.parse_document('<!doctype html><body></body>')
	defer { document.finalize() }
	document.set_page(unsafe { &dom.Page(first) })
	assert !first.client().prefers_reduced_transparency()
	assert !document.prefers_reduced_transparency()
	first.set_prefers_reduced_transparency(true)
	assert first.client().prefers_reduced_transparency()
	assert document.prefers_reduced_transparency()
	assert !second.prefers_reduced_transparency()
	document.set_page(unsafe { &dom.Page(second) })
	assert !document.prefers_reduced_transparency()
}

fn test_cached_css_and_window_queries_recheck_the_page_preference() {
	mut model := Page.create(1)!
	mut document := html.parse_document('<!doctype html><body></body>')
	defer { document.finalize() }
	document.set_page(unsafe { &dom.Page(model) })
	window := html.WindowModel.create_top_level(document, none, 'transparency')!
	mut reduce := css.MediaList.create([css.MediaQueryListEntry{
		text: '(prefers-reduced-transparency: reduce)'
	}])
	mut normal := css.MediaList.create([css.MediaQueryListEntry{
		text: '(prefers-reduced-transparency: no-preference)'
	}])
	mut boolean := css.MediaList.create([css.MediaQueryListEntry{
		text: '(prefers-reduced-transparency)'
	}])
	query := window.match_media('(prefers-reduced-transparency: reduce)')
	for expected in [false, true, false] {
		model.set_prefers_reduced_transparency(expected)
		document.evaluate_media_queries_and_report_changes()
		assert reduce.evaluate(document) == expected
		assert normal.evaluate(document) == !expected
		assert boolean.evaluate(document) == expected
		assert query.matches() == expected
		feature := window.query_media_feature(.prefers_reduced_transparency) or {
			panic('missing transparency feature')
		}
		assert feature == css.MediaFeatureValue.from_ident(if expected {
			'reduce'
		} else {
			'no-preference'
		})
	}
}

fn test_preference_changes_invalidate_attached_styles_once_and_relayout_media_rules() {
	mut model := Page.create(1)!
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:10px;height:10px}@media(prefers-reduced-transparency:reduce){#target{width:20px}}</style><div id="target"></div>')
	defer { document.finalize() }
	document.set_page(unsafe { &dom.Page(model) })
	target := document.get_element_by_id('target') or { panic('missing target') }
	for expected in [false, true, false] {
		before := document.style_environment_version()
		changed := model.prefers_reduced_transparency() != expected
		model.set_prefers_reduced_transparency(expected)
		assert document.style_environment_version() == before + if changed {
			u64(1)
		} else {
			u64(0)
		}
		model.set_prefers_reduced_transparency(expected)
		assert document.style_environment_version() == before + if changed {
			u64(1)
		} else {
			u64(0)
		}
		_ = layout.layout_document_typed_in_viewport(document, 100, 100)
		assert target.get_bounding_client_rect().width == if expected { 20 } else { 10 }
	}
}
