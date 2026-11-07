module main

import browserjs
import css
import dom
import html
import webidl

@[heap]
struct DocumentFontConstructionObservation {
mut:
	called bool
	realm  u64
	ready  &webidl.Promise = unsafe { nil }
	set    voidptr
	window voidptr
}

fn test_native_document_fonts_are_constructed_with_the_real_owner_before_dom_initialization() {
	mut observation := &DocumentFontConstructionObservation{}
	dom.install_document_font_face_set_factory(fn [observation] (document &dom.Document) dom.FontFaceSet {
		mut observed := unsafe { &DocumentFontConstructionObservation(observation) }
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		assert settings != unsafe { nil }
		assert settings.responsible_document() == none
		assert document.document_element() == none
		assert document.get_selection() == none
		assert voidptr(html.settings_object_of_realm(html.entry_realm()) or {
			panic('missing active owner')
		}) == voidptr(settings)
		set := css.css_style_computer_for(document).font_face_set_
		observed.called = true
		observed.realm = u64(voidptr(settings.realm()))
		observed.ready = set.ready()
		observed.set = voidptr(set)
		observed.window = voidptr(document.get_window() or { panic('missing owner Window') })
		assert webidl.promise_realm(observed.ready) == observed.realm
		assert observed.realm != 0
		return set
	})
	defer {
		dom.install_document_font_face_set_factory(fn (document &dom.Document) dom.FontFaceSet {
			return css.css_style_computer_for(document).font_face_set_
		})
	}
	mut document :=
		parse_browser_navigation_document('<!doctype html><style>@font-face{font-family:Example;src:url(example.ttf)}</style><p>parsed</p>', dom.URL{value: 'https://creation.example/'}, none)
	assert observation.called
	assert document.document_element() != none
	assert observation.set == document.fonts().font_face_set_record()
	assert voidptr(observation.ready) == voidptr(document.fonts().ready())
	assert observation.window == voidptr(document.get_window() or { panic('missing owner Window') })
	assert webidl.promise_realm(document.fonts().ready()) == observation.realm
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert voidptr(settings.responsible_document()?) == voidptr(document)
}

fn test_navigation_reuses_only_the_initial_same_origin_window_without_changing_prior_promises() {
	page := &dom.Page{}
	creator :=
		parse_browser_navigation_document('<p>creator</p>', dom.URL{value: 'https://creation.example/creator'}, none)
	initial := html.BrowsingContextModel.create_a_new_browsing_context_and_document(page, creator,
		none)!
	mut initial_document := unsafe { &dom.Document(initial.document) }
	initial_ready := initial_document.fonts().ready()
	initial_set := initial_document.fonts().font_face_set_record()
	initial_settings := initial.document.relevant_settings_object()
	initial_window := initial.document.get_window()?
	initial_proxy := initial.browsing_context.window_proxy()?
	assert webidl.promise_realm(initial_ready) != 0
	first := html.parse_navigation_document('<style>p{color:red}</style><p>first</p>', dom.URL{value: 'https://creation.example/first'},
		creator.origin(), initial.document)!
	mut first_document := unsafe { &dom.Document(first) }
	first_ready := first_document.fonts().ready()
	assert voidptr(first.get_window()?) == voidptr(initial_window)
	assert first.relevant_settings_object() == initial_settings
	assert voidptr(initial.browsing_context.window_proxy()?) == voidptr(initial_proxy)
	assert first_document.fonts().font_face_set_record() != initial_set
	assert webidl.promise_realm(first_ready) == webidl.promise_realm(initial_ready)
	assert voidptr(initial_document.fonts().ready()) == voidptr(initial_ready)
	second := html.parse_navigation_document('<p>second</p>', dom.URL{value: 'https://creation.example/second'},
		creator.origin(), first)!
	mut second_document := unsafe { &dom.Document(second) }
	assert voidptr(second.get_window()?) != voidptr(initial_window)
	assert second.relevant_settings_object() != initial_settings
	assert voidptr(initial.browsing_context.window_proxy()?) == voidptr(initial_proxy)
	assert voidptr(initial_proxy.window()) == voidptr(second.get_window()?)
	assert webidl.promise_realm(second_document.fonts().ready()) != webidl.promise_realm(first_ready)
	assert voidptr(first_document.fonts().ready()) == voidptr(first_ready)
	assert voidptr(initial.browsing_context.active_document()?) == voidptr(second)
	assert voidptr(second.get_browsing_context()?) == voidptr(first.get_browsing_context()?)
}

fn test_initial_cross_origin_navigation_gets_a_new_font_owner_and_native_wrapper_keeps_ready_identity() {
	$if !darwin { return }
	first :=
		parse_browser_navigation_document('<p>first</p>', dom.URL{value: 'https://creation.example/'}, none)
	mut first_document := unsafe { &dom.Document(first) }
	first_document.set_is_initial_about_blank(true)
	second := html.parse_navigation_document('<style>p{color:blue}</style><p>second</p>', dom.URL{value: 'https://elsewhere.example/'},
		dom.URL{value: 'https://elsewhere.example/'}.origin(), first)!
	mut second_document := unsafe { &dom.Document(second) }
	assert first.relevant_settings_object() != second.relevant_settings_object()
	ready := second_document.fonts().ready()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	runtime.evaluate_host('globalThis.document={}')!
	mut host := browserjs.FontFaceHost.create(second)
	host.install(mut runtime)!
	assert runtime.evaluate_host('document.fonts.ready===document.fonts.ready')! == 'true'
	assert voidptr(second_document.fonts().ready()) == voidptr(ready)
	assert webidl.promise_realm(ready) != 0
}

fn test_standalone_late_window_attachment_preserves_an_already_exposed_ready_capability() {
	mut document := dom.Document.create(dom.URL{value: 'https://creation.example/standalone'})
	ready := document.fonts().ready()
	set := document.fonts().font_face_set_record()
	assert webidl.promise_realm(ready) == 0
	_ = html.WindowModel.create_top_level(document, none, 'late standalone')!
	assert voidptr(document.fonts().ready()) == voidptr(ready)
	assert document.fonts().font_face_set_record() == set
}
