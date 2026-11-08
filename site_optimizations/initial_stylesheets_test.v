module main

import css
import dom

fn site_initial_sheet_fixture(address string, attributes string) &dom.Document {
	media := if attributes.starts_with('media=') { '' } else { 'media="all"' }
	return parse_browser_navigation_document('<!doctype html><head><link rel="stylesheet" media="all" href="${github_primer_stylesheet_url}"><style>@layer between{#target{color:blue!important;background-color:blue}}</style><link rel="stylesheet" ${media} href="${github_primer_stylesheet_url}" ${attributes}></head><body><div id="target">text</div></body>', dom.URL{ value: address }, none)
}

fn test_initial_github_stylesheet_dedup_preserves_normal_and_important_layer_order() {
	css.set_remote_link_style_sheet(github_primer_stylesheet_url,
		'@layer primer-react{#target{color:red!important;background-color:lime}}@layer primer.components.IssueLabel{#target{height:18px}}')
	mut document := site_initial_sheet_fixture('https://github.com/vlang/v', '')
	defer { document.finalize() }
	removed := prepare_site_document_stylesheets(document)
	assert removed == if disable_github_initial_stylesheet_dedup { 0 } else { 1 }
	mut app := BrowserApp{ document: document }
	app.relayout(320, 312)
	target := document.get_element_by_id('target')?
	style := css.up_to_date_computed_properties_for_element(target)
	assert style.color_or_fallback(.color, css.ColorResolutionContext{}, css.ComputedColor.transparent()) == css.ComputedColor.rgb(255, 0, 0)
	assert style.color_or_fallback(.background_color, css.ColorResolutionContext{}, css.ComputedColor.transparent()) == css.ComputedColor.rgb(0, 0, 255)
}

fn test_initial_github_stylesheet_dedup_keeps_conditional_and_named_owners() {
	for attributes in ['disabled', 'media="print"', 'title="alternate"', 'integrity="hash"',
		'nonce="nonce"', 'id="observable"', 'onload="callback()"', 'onerror="callback()"'] {
		mut document := site_initial_sheet_fixture('https://github.com/vlang/v', attributes)
		defer { document.finalize() }
		assert prepare_site_document_stylesheets(document) == 0, attributes
	}
}

fn test_initial_stylesheet_dedup_requires_scripted_github_document() {
	mut document := site_initial_sheet_fixture('https://elsewhere.test/', '')
	defer { document.finalize() }
	assert prepare_site_document_stylesheets(document) == 0
	document.url = dom.URL{ value: 'https://github.com/vlang/v' }
	document.set_scripting_enabled_by_embedder(false)
	assert prepare_site_document_stylesheets(document) == 0
}
