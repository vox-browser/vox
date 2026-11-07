module main

import browserhistory
import css
import dom
import encoding.base64
import encoding.binary
import gg
import html
import os
import page

const new_tab_test_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='

fn new_tab_test_cache_icon(mut app BrowserApp, address string) {
	app.resource_cache[address] = PreloadedResource{
		url: address
		body: base64.decode(new_tab_test_png).bytestr()
		request_type: 'image'
	}
}

fn new_tab_test_record(mut app BrowserApp, address string, title string, visited_at i64) ! {
	app.browsing_history.record_with_favicon(address, title, 'data:image/png;base64,${new_tab_test_png}', visited_at)!
}

$if macos {
	#include "@VMODROOT/native_address_bar_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_close(voidptr)
}

fn new_tab_test_app() &BrowserApp {
	mut app := &BrowserApp{
		page_model: page.Page.create(1) or { panic(err) }
		browsing_history: browserhistory.open('', browserhistory.now()) or { panic(err) }
		viewport_width: 800
		viewport_height: 600
		navigation_results: chan NavigationResult{cap: 4}
		background_resource_results: chan PreloadedResource{cap: max_cached_resources}
	}
	app.install_chrome_widget_input_bridge()
	app.initialize_browser_tabs()
	return app
}

fn new_tab_test_close(mut app BrowserApp) {
	for mut tab in app.tabs.pages { tab.dispose_browser_tab() }
}

fn test_new_tab_renders_centered_history_shortcuts_and_keeps_address_focus() {
	mut window := voidptr(0)
	$if macos { window = C.native_test_address_window() }
	defer {
		$if macos { C.native_test_address_close(window) }
	}
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	now := browserhistory.now()
	new_tab_test_record(mut app, 'https://docs.example/start', 'Docs', now - 200)!
	new_tab_test_record(mut app, 'https://news.example/', 'News', now - 100)!
	new_tab_test_record(mut app, 'https://docs.example/guide', 'Documentation', now)!
	app.activate_tab_chrome('tab-new')
	mut tab := app.active_browser_tab()
	assert tab.browser_tab_title() == 'New Tab'
	assert tab.address == ''
	assert tab.address_active
	assert tab.history.len == 1
	assert tab.history[0].url == browser_new_tab_url
	assert app.browsing_history.visits.len == 3
	tab.address = 'unfinished search'
	tab.cancel_address_bar()
	assert tab.address == ''
	tab.focus_address_bar()
	links := css.query_selector_all(tab.document.as_node(), '.site-tile')
	assert links.len == 2
	assert links[0].get_attribute_value('href') == 'https://docs.example/guide'
	assert links[0].text_content()?.contains('Documentation')
	first := links[0].get_bounding_client_rect()
	second := links[1].get_bounding_client_rect()
	assert css.query_selector_all(tab.document.as_node(), 'h1, h2').len == 0
	assert first.width == 160
	assert first.x + first.width <= second.x
	assert first.x + (second.x + second.width - first.x) / 2 == 400
	assert first.y > 200 && first.y + first.height < 600
	x := f32(first.x + first.width / 2)
	y := f32(first.y + first.height / 2) + tab.page_top()
	assert tab.link_at_point(x, y)? == 'https://docs.example/guide'
	tab.blur_address_bar()
	dom.run_focusing_steps_for_node(links[0].as_node(), none, .key)
	assert voidptr(tab.document.focused_area()?) == voidptr(links[0].as_node())
}

fn test_new_tab_refreshes_shared_history_and_regenerates_after_reload_and_back() {
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	app.navigate('about:newtab', true)
	assert css.query_selector(app.document.as_node(), '.empty') != none
	new_tab_test_record(mut app, 'https://example.com/', '', browserhistory.now())!
	app.poll_browser_new_tab_page()
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 1
	assert css.query_selector(app.document.as_node(), '.site-title')?.text_content()? == 'example.com'
	app.reload()
	assert app.address == ''
	assert app.history.len == 1
	app.install_loaded_page(LoadedPage{
		url: 'https://second.example/'
		markup: '<!doctype html><link rel="icon" href="data:image/png;base64,${new_tab_test_png}"><title>Second</title>'
		content_type: 'text/html'
	}, true)
	app.history_go(-1)
	assert app.source_label == browser_new_tab_url
	assert app.address == ''
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 2
	app.browsing_history.clear_since(0)!
	app.poll_browser_new_tab_page()
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 0
	assert css.query_selector(app.document.as_node(), '.empty') != none
}

fn test_new_tab_escapes_history_labels_and_wraps_shortcuts_on_narrow_viewports() {
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	title := '<img src=x onerror=alert(1)> & "Quoted"'
	address := 'https://example.com/?a=1&b=%22'
	new_tab_test_record(mut app, address, title, browserhistory.now())!
	for index in 0 .. 9 {
		new_tab_test_record(mut app, 'https://site${index}.example/', 'Site ${index}', browserhistory.now() - index - 1)!
	}
	app.navigate('chrome://newtab/', true)
	assert css.query_selector_all(app.document.as_node(), '.site-tile').len == 8
	assert css.query_selector_all(app.document.as_node(), 'img.site-favicon').len == 8
	assert css.query_selector_all(app.document.as_node(), 'script, img:not(.site-favicon)').len == 0
	link := css.query_selector(app.document.as_node(), '.site-tile')?
	assert link.get_attribute_value('href') == address
	assert link.get_attribute_value('title') == title
	assert css.query_selector(app.document.as_node(), '.site-title')?.text_content()? == title
	for width in [240, 360, 800] {
		app.relayout(width, 600 + app.chrome_height())
		links := css.query_selector_all(app.document.as_node(), '.site-tile')
		for tile in links {
			rect := tile.get_bounding_client_rect()
			assert rect.x >= 0 && rect.x + rect.width <= width
		}
		assert links[0].get_bounding_client_rect().y < links[links.len - 1].get_bounding_client_rect().y
	}
}

fn test_new_tab_displays_decoded_favicons_and_multiline_titles() {
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	address := 'https://docs.example/guide'
	icon := 'https://cdn.example/icon.png?theme=light&size=32'
	title := 'Documentation and reference for the Vox browser engine'
	app.install_loaded_page(LoadedPage{
		url: address
		markup: '<!doctype html><base href="https://cdn.example/assets/"><link rel="shortcut ICON" href="../icon.png?theme=light&amp;size=32"><link rel="icon" href="file:///private/icon.png"><title>${title}</title>'
		content_type: 'text/html'
	}, true)
	assert app.browsing_history.visits[0].favicon_url == icon
	new_tab_test_cache_icon(mut app, icon)
	app.navigate('about:newtab', true)
	image := css.query_selector(app.document.as_node(), '.site-favicon')?
	assert image.get_attribute_value('src') == icon
	assert image.get_attribute_value('referrerpolicy') == 'no-referrer'
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	assert model.current_request().state() == .completely_available
	assert model.natural_width() == 1
	assert app.paint_commands.any(it.kind == 'draw_replaced_image' && it.image().image_url == icon)
	label := css.query_selector(app.document.as_node(), '.site-title')?
	assert label.text_content()? == title
	assert label.get_bounding_client_rect().height > 20
	assert label.get_bounding_client_rect().height <= 60
	// History changes refresh the existing page, including its image requests.
	new_tab_test_cache_icon(mut app, 'https://second.example/favicon.ico')
	app.browsing_history.record('https://second.example/', 'Second site', browserhistory.now())!
	app.poll_browser_new_tab_page()
	app.relayout(800, 600 + app.chrome_height())
	assert css.query_selector_all(app.document.as_node(), '.site-favicon').len == 2
	assert app.paint_commands.any(it.kind == 'draw_replaced_image' && it.image().image_url == 'https://second.example/favicon.ico')
}

fn test_new_tab_favicon_defaults_to_the_site_origin_and_rejects_unsafe_metadata() {
	for icon in ['', 'javascript:alert(1)', 'file:///etc/passwd', 'https://user:secret@example.com/icon.png'] {
		assert browser_new_tab_favicon_url(browserhistory.MostVisitedSite{
			url: 'https://www.example.com:8443/guide?q=1#part'
			favicon_url: icon
		}) == 'https://www.example.com:8443/favicon.ico'
	}
	icon := 'data:image/png;base64,${new_tab_test_png}'
	assert browser_new_tab_favicon_url(browserhistory.MostVisitedSite{
		url: 'https://example.com/'
		favicon_url: icon
	}) == icon
}

fn test_new_tab_ico_favicons_reach_the_paint_resource_cache() {
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	icon_url := 'https://curl.se/favicon.ico'
	bytes := os.read_bytes('${@VMODROOT}/pixel_tests/sites/curl/curl.se/favicon.ico')!
	app.resource_cache[icon_url] = PreloadedResource{url: icon_url, body: bytes.bytestr(), request_type: 'image'}
	app.browsing_history.record('https://curl.se/', 'curl documentation', browserhistory.now())!
	app.navigate('about:newtab', true)
	image := css.query_selector(app.document.as_node(), '.site-favicon')?
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	assert model.current_request().state() == .completely_available
	assert model.natural_width() == 32
	assert app.paint_commands.any(it.kind == 'draw_replaced_image' && it.image().image_url == icon_url)
	expected := model.current_image_frame()?.bitmap()
	// Model availability alone does not prove that the native/portable paint
	// loader can decode the URL's bytes into its own resource cache.
	for native in [false, true] {
		mut painter := BrowserApp{ctx: gg.new_context(native_rendering: native)}
		paint_image := painter.create_image_from_resource_bytes(icon_url, bytes)!
		assert paint_image.ok && paint_image.width == 32 && paint_image.height == 32
		cached := painter.ctx.get_cached_image_by_idx(paint_image.id)
		pixels := unsafe { (&u8(cached.data)).vbytes(32 * 32 * 4) }
		assert pixels == expected.data
		assert pixels.any(it != 0)
		assert paint_image.nr_channels == if native { 6 } else { 4 }
		if native { assert !paint_image.simg_ok }
	}
}

fn test_new_tab_starts_uncached_favicon_requests_in_the_background() {
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	app.browsing_history.record('https://vox-favicon-test.invalid/', 'Uncached icon', browserhistory.now())!
	app.navigate('about:newtab', true)
	loader := app.image_request_loader?
	assert loader.pending.len == 1
	assert loader.active_fetches == 1
	image := css.query_selector(app.document.as_node(), '.site-favicon')?
	model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(image) })
	assert model.has_fetch_hook()
	assert model.current_request().state() != .completely_available
}

fn new_tab_test_ico(frame []u8, width u8, height u8) []u8 {
	mut icon := []u8{len: 22}
	icon[2] = 1
	icon[4] = 1
	icon[6] = width
	icon[7] = height
	binary.little_endian_put_u32_at(mut icon, u32(frame.len), 14)
	binary.little_endian_put_u32_at(mut icon, 22, 18)
	icon << frame
	return icon
}

fn test_favicons_decode_png_and_masked_bitmap_ico_frames() {
	png_icon := new_tab_test_ico(base64.decode(new_tab_test_png), 1, 1)
	png := browser_decode_raster_image_bytes(png_icon)!
	assert png.width == 1 && png.height == 1
	// Two bottom-up BGRA rows followed by the ICO AND transparency mask.
	mut dib := []u8{len: 40}
	binary.little_endian_put_u32_at(mut dib, 40, 0)
	binary.little_endian_put_u32_at(mut dib, 2, 4)
	binary.little_endian_put_u32_at(mut dib, 4, 8)
	dib[12] = 1
	dib[14] = 32
	dib << [u8(255), 0, 0, 255, 255, 255, 255, 255, 0, 0, 255, 255, 0, 255, 0, 255]
	dib << [u8(0), 0, 0, 0, 0x40, 0, 0, 0]
	bitmap := browser_decode_raster_image_bytes(new_tab_test_ico(dib, 2, 2))!
	assert bitmap.width == 2 && bitmap.height == 2
	assert bitmap.data == [u8(255), 0, 0, 255, 0, 255, 0, 0, 0, 0, 255, 255, 255, 255, 255, 255]
	for invalid in [png_icon[..10], new_tab_test_ico([u8(0)], 1, 1), new_tab_test_ico(dib[..41], 2, 2)] {
		if _ := browser_decode_raster_image_bytes(invalid) { assert false, 'Truncated ICO accepted' }
	}
	// Real multi-frame icons exercise frame selection and palette decoding.
	for path in ['curl/curl.se', 'ffmpeg/ffmpeg.org', 'daring-fireball/daringfireball.net'] {
		icon := browser_decode_raster_image_bytes(os.read_bytes('${@VMODROOT}/pixel_tests/sites/${path}/favicon.ico')!)!
		assert icon.width == 32 && icon.height == 32
	}
}

fn test_initial_page_is_new_tab_and_explicit_blank_remains_empty() {
	address, markup, _ := initial_document('')
	assert address == browser_new_tab_url
	assert markup.contains('New Tab')
	mut app := new_tab_test_app()
	defer { new_tab_test_close(mut app) }
	app.navigate('about:blank', true)
	assert app.document.url_string() == 'about:blank'
	assert css.query_selector(app.document.as_node(), '.sites') == none
	assert resolve_url('about:newtab', '') == browser_new_tab_url
	assert !is_browser_new_tab_url('https://newtab/')
}
