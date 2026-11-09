module main

import css
import dom

fn site_initial_sheet_fixture(address string, attributes string) &dom.Document {
	return site_initial_sheet_fixture_for_url(address, attributes, github_primer_stylesheet_url)
}

fn site_initial_sheet_fixture_for_url(address string, attributes string, stylesheet_url string) &dom.Document {
	media := if attributes.starts_with('media=') { '' } else { 'media="all"' }
	return parse_browser_navigation_document('<!doctype html><head><link rel="stylesheet" media="all" href="${stylesheet_url}"><style>@layer between{#target{color:blue!important;background-color:blue}}</style></head><body><section><link rel="stylesheet" ${media} href="${stylesheet_url}" ${attributes}></section><div id="target">text</div></body>', dom.URL{ value: address }, none)
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
	for stylesheet_url in [github_primer_stylesheet_url, github_primer_brand_stylesheet_url] {
		for attributes in ['disabled', 'media="print"', 'title="alternate"', 'integrity="hash"',
			'nonce="nonce"', 'id="observable"', 'onload="callback()"', 'onerror="callback()"',
			'crossorigin', 'crossorigin=""', 'crossorigin="use-credentials"',
			'referrerpolicy="no-referrer"'] {
			mut document := site_initial_sheet_fixture_for_url('https://github.com/', attributes, stylesheet_url)
			defer { document.finalize() }
			assert prepare_site_document_stylesheets(document) == 0, attributes
		}
	}
}

fn test_initial_stylesheet_dedup_requires_scripted_github_document() {
	for stylesheet_url in [github_primer_stylesheet_url, github_primer_brand_stylesheet_url] {
		mut document := site_initial_sheet_fixture_for_url('https://elsewhere.test/', '', stylesheet_url)
		defer { document.finalize() }
		assert prepare_site_document_stylesheets(document) == 0
		document.url = dom.URL{ value: 'https://github.com/' }
		document.set_scripting_enabled_by_embedder(false)
		assert prepare_site_document_stylesheets(document) == 0
	}
}

fn test_initial_brand_stylesheet_dedup_preserves_cascade_and_final_owner() {
	css.set_remote_link_style_sheet(github_primer_brand_stylesheet_url,
		'@layer primer-brand{#target{color:red!important;background-color:lime}}')
	mut document := site_initial_sheet_fixture_for_url('https://github.com/', '', github_primer_brand_stylesheet_url)
	defer { document.finalize() }
	before := css.query_selector_all(document.as_node(), 'link')
	assert before.len == 2
	removed := prepare_site_document_stylesheets(document)
	disabled := disable_github_initial_stylesheet_dedup || disable_github_brand_stylesheet_dedup
	assert removed == if disabled { 0 } else { 1 }
	after := css.query_selector_all(document.as_node(), 'link')
	assert after.len == if disabled { 2 } else { 1 }
	assert voidptr(after.last()) == voidptr(before.last())
	mut app := BrowserApp{ document: document }
	app.relayout(320, 312)
	target := document.get_element_by_id('target')?
	style := css.up_to_date_computed_properties_for_element(target)
	assert style.color_or_fallback(.color, css.ColorResolutionContext{}, css.ComputedColor.transparent()) == css.ComputedColor.rgb(255, 0, 0)
	assert style.color_or_fallback(.background_color, css.ColorResolutionContext{}, css.ComputedColor.transparent()) == css.ComputedColor.rgb(0, 0, 255)
	assert prepare_site_document_stylesheets(document) == 0
}

fn test_initial_stylesheet_families_preserve_interleaved_layer_order() {
	css.set_remote_link_style_sheet(github_primer_brand_stylesheet_url,
		'@layer primer-brand{#target{color:red!important;background-color:red}}')
	css.set_remote_link_style_sheet(github_primer_stylesheet_url,
		'@layer primer-react{#target{color:lime!important;background-color:lime}}@layer primer.components.IssueLabel{}')
	for brand_first in [true, false] {
		first := if brand_first {
			github_primer_brand_stylesheet_url
		} else {
			github_primer_stylesheet_url
		}
		second := if brand_first {
			github_primer_stylesheet_url
		} else {
			github_primer_brand_stylesheet_url
		}
		mut document := parse_browser_navigation_document('<!doctype html><head><link rel="stylesheet" href="${first}"><link rel="stylesheet" href="${second}"></head><body><link rel="stylesheet" href="${second}"><link rel="stylesheet" href="${first}"><div id="target">text</div></body>', dom.URL{ value: 'https://github.com/' }, none)
		defer { document.finalize() }
		expected_removed := if disable_github_initial_stylesheet_dedup {
			0
		} else if disable_github_brand_stylesheet_dedup {
			1
		} else {
			2
		}
		assert prepare_site_document_stylesheets(document) == expected_removed
		mut app := BrowserApp{ document: document }
		app.relayout(320, 312)
		target := document.get_element_by_id('target')?
		style := css.up_to_date_computed_properties_for_element(target)
		first_color := if brand_first {
			css.ComputedColor.rgb(255, 0, 0)
		} else {
			css.ComputedColor.rgb(0, 255, 0)
		}
		second_color := if brand_first {
			css.ComputedColor.rgb(0, 255, 0)
		} else {
			css.ComputedColor.rgb(255, 0, 0)
		}
		assert style.color_or_fallback(.color, css.ColorResolutionContext{}, css.ComputedColor.transparent()) == first_color
		assert style.color_or_fallback(.background_color, css.ColorResolutionContext{}, css.ComputedColor.transparent()) == second_color
	}
}

fn test_initial_brand_dedup_requires_reviewed_asset_and_multiple_owners() {
	for unknown in [
		github_primer_brand_stylesheet_url.replace('6485cac7edcdca27', 'unreviewed'),
		github_primer_brand_stylesheet_url + '?changed=1',
	] {
		mut document := site_initial_sheet_fixture_for_url('https://github.com/', '', unknown)
		defer { document.finalize() }
		assert prepare_site_document_stylesheets(document) == 0
		assert css.query_selector_all(document.as_node(), 'link').len == 2
	}
	mut single := parse_browser_navigation_document('<!doctype html><link rel="stylesheet" href="${github_primer_brand_stylesheet_url}"><div>text</div>', dom.URL{ value: 'https://github.com/' }, none)
	defer { single.finalize() }
	assert prepare_site_document_stylesheets(single) == 0
	assert css.query_selector_all(single.as_node(), 'link').len == 1
}
