module main

import css
import dom
import html
import os
import time

fn script_stylesheet_test_document() &dom.Document {
	address := dom.URL{value: 'https://script-styles.test/pol/catalog'}
	mut document := html.parse_navigation_document('<!doctype html><html><head><link id="mobile-css" rel="stylesheet" href="mobile.css"></head><body><p id="text">text</p></body></html>',
		address, address.origin(), none) or { panic(err) }
	document.set_scripting_enabled_by_embedder(false)
	document.set_viewport_rect(dom.Rect{width: 1024, height: 768})
	return document
}

// 4chan's catalog inserts its theme link after the initial resources. The
// stylesheet the browser fetched for it restyles the document once it arrives.
fn test_script_inserted_stylesheet_links_restyle_the_document_when_fetched() {
	mut document := script_stylesheet_test_document()
	defer { document.finalize() }
	theme_url := 'https://script-styles.test/css/catalog_theme.css'
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 2}
		// The test supplies the responses instead of the network.
		script_stylesheet_requests:  {
			theme_url:                                  true
			'https://script-styles.test/pol/mobile.css': true
		}
	}
	app.relayout(1024, 768 + app.chrome_height())
	text := document.get_element_by_id('text') or { panic('missing text') }
	assert !css.up_to_date_computed_properties_for_element(text).display().is_none()
	mut link := document.create_element_ns(dom.namespace_html_uri, 'link') or { panic(err) }
	link.set_attribute_value('rel', 'stylesheet')
	link.set_attribute_value('href', '/css/catalog_theme.css')
	mobile := document.get_element_by_id('mobile-css') or { panic('missing mobile link') }
	mut head := mobile.as_node().parent_node() or { panic('missing head') }
	head.pre_insert(link.as_node(), mobile.as_node()) or { panic(err) }
	app.request_script_inserted_stylesheets()
	assert app.script_stylesheet_scan_version == document.dom_tree_version()
	app.background_resource_results <- PreloadedResource{
		url:          theme_url
		body:         '#text { display: none }'
		source_url:   document.url.serialize()
		request_type: 'stylesheet'
	}
	app.poll_background_resources()
	assert css.has_remote_link_style_sheet(theme_url)
	assert css.up_to_date_computed_properties_for_element(text).display().is_none()
	sheet := css.style_sheet_for_owner_node(document, link) or { panic('missing theme sheet') }
	assert sheet.css_rules().length() == 1
	// An unrelated image response does not register a stylesheet.
	image := PreloadedResource{url: 'https://script-styles.test/a.png', body: 'png', request_type: 'image'}
	assert !app.install_script_inserted_stylesheet(image)
}

// A theme stylesheet the disk cache already holds is installed as soon as its
// link is found, so the first layout uses it instead of a later relayout.
fn test_disk_cached_script_inserted_stylesheet_installs_without_a_request() {
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	cache := os.join_path(os.temp_dir(), 'vox-script-styles-${os.getpid()}-${time.sys_mono_now()}')
	os.setenv('LADYBIRD_CACHE_DIR', cache, true)
	defer {
		if previous := previous_cache {
			os.setenv('LADYBIRD_CACHE_DIR', previous, true)
		} else {
			os.unsetenv('LADYBIRD_CACHE_DIR')
		}
		os.rmdir_all(cache) or {}
	}
	theme_url := 'https://script-styles.test/css/cached_theme.css'
	cache_resource(theme_url, '#text { display: none }')
	mut document := script_stylesheet_test_document()
	defer { document.finalize() }
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 2}
		script_stylesheet_requests:  {
			'https://script-styles.test/pol/mobile.css': true
		}
	}
	mut link := document.create_element_ns(dom.namespace_html_uri, 'link') or { panic(err) }
	link.set_attribute_value('rel', 'stylesheet')
	link.set_attribute_value('href', '/css/cached_theme.css')
	mobile := document.get_element_by_id('mobile-css') or { panic('missing mobile link') }
	mut head := mobile.as_node().parent_node() or { panic('missing head') }
	head.pre_insert(link.as_node(), mobile.as_node()) or { panic(err) }
	assert app.request_script_inserted_stylesheets()
	assert css.has_remote_link_style_sheet(theme_url)
	select {
		_ := <-app.background_resource_results {
			assert false, 'the cached sheet was requested again'
		}
		else {}
	}
	app.relayout(1024, 768 + app.chrome_height())
	text := document.get_element_by_id('text') or { panic('missing text') }
	assert css.up_to_date_computed_properties_for_element(text).display().is_none()
}
