module main

import browserjs
import css
import dom
import gg
import html
import page
import time

fn initial_capture_font_fixture() (&BrowserApp, &css.FontFaceSet, &css.FontFaceObject) {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:70px;height:20px;background:green}</style><p id="target">Initial font layout</p>')
	mut fonts := css.css_style_computer_for(document).font_face_set_
	face := &css.FontFaceObject{family_:'PendingCaptureFixture',status_:.loading}
	fonts.add(face) or { panic(err) }
	assert fonts.loading_fonts().len == 1
	return &BrowserApp{
		document:document
		ctx:&gg.Context{native_rendering:true}
		screenshot_path:'unused-capture.png'
	}, fonts, face
}

fn complete_initial_capture_font(mut fonts css.FontFaceSet, mut face css.FontFaceObject) {
	fonts.loading_fonts_.clear()
	face.status_ = .loaded
}

fn test_capture_defers_initial_geometry_until_face_requests_settle_without_waiting_for_ready() {
	mut app, mut fonts, mut face := initial_capture_font_fixture()
	defer { app.document.finalize() }
	app.begin_frame_preparation()
	app.prepare_initial_document_layout(320,240 + app.chrome_height())
	assert app.initial_layout_pending
	assert app.document.layout_engine_handle() == unsafe { nil }
	assert app.document.cached_display_list() == none
	assert capture_retry_needs_frame(voidptr(app)) == 0
	app.finish_frame_preparation()
	assert app.initial_layout_pending
	assert !app.document_pixels_ready_for_frame()
	assert app.document.layout_engine_handle() == unsafe { nil }
	complete_initial_capture_font(mut fonts, mut face)
	// The ready promise still depends on layout; it must not hold geometry.
	assert fonts.status() == .loading
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	assert !app.initial_layout_pending
	assert app.document.layout_is_up_to_date()
	assert app.document.cached_display_list() != none
	assert app.paint_generation == 1
	assert app.document.get_element_by_id('target')?.get_bounding_client_rect().width == 70
}

fn test_forced_geometry_bypasses_a_withheld_capture_opportunity_in_nested_preparation() {
	mut app, mut fonts, mut face := initial_capture_font_fixture()
	defer { app.document.finalize() }
	app.page_model = page.Page.create(1) or { panic(err) }
	app.document.set_page(unsafe { &dom.Page(app.page_model) })
	app.begin_frame_preparation()
	app.begin_frame_preparation()
	app.prepare_initial_document_layout(320,240 + app.chrome_height())
	assert !app.page_model.client().has_rendering_opportunity()
	assert app.document.get_element_by_id('target')?.get_bounding_client_rect().width == 70
	assert app.document.layout_is_up_to_date()
	app.finish_frame_preparation()
	// A geometry consumer can flush fallback layout without making the fonts
	// ready for capture. Keep the host opportunity withheld until they settle.
	assert app.initial_layout_pending
	assert app.frame_preparation_depth == 1
	assert !app.page_model.client().has_rendering_opportunity()
	assert capture_retry_needs_frame(voidptr(app)) == 0
	complete_initial_capture_font(mut fonts, mut face)
	app.finish_frame_preparation()
	assert !app.initial_layout_pending
	assert app.page_model.client().has_rendering_opportunity()
	assert app.paint_generation == 1
}

fn test_capture_withholds_a_rendering_grant_already_queued_before_document_installation() {
	mut app, mut fonts, mut face := initial_capture_font_fixture()
	defer { app.document.finalize() }
	app.page_model = page.Page.create(1) or { panic(err) }
	mut client := app.page_model.client()
	client.set_manual_rendering_opportunities(true)
	client.rendering_opportunity(time.sys_mono_now(), 16)
	assert client.has_rendering_opportunity()
	app.begin_frame_preparation()
	app.prepare_initial_document_layout(320,240 + app.chrome_height())
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	assert !client.has_rendering_opportunity()
	complete_initial_capture_font(mut fonts, mut face)
	app.deliver_rendering_opportunity(time.sys_mono_now(), 16)
	assert !client.has_rendering_opportunity()
	app.finish_frame_preparation()
	assert client.has_rendering_opportunity()
	assert !app.initial_layout_pending
}

fn test_background_capture_installation_completes_in_its_next_ready_frame() {
	mut app, mut fonts, mut face := initial_capture_font_fixture()
	defer { app.document.finalize() }
	app.prepare_initial_document_layout(320,240 + app.chrome_height())
	assert app.initial_layout_pending
	assert !app.document_pixels_ready_for_frame()
	complete_initial_capture_font(mut fonts, mut face)
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	assert !app.initial_layout_pending
	assert app.paint_generation == 1
}

fn test_initial_font_layout_keeps_navigation_scripted_tree_and_portable_callers_synchronous() {
	for kind in ['navigation','scripted','tree-dump','portable','existing-geometry'] {
		mut app, _, _ := initial_capture_font_fixture()
		defer { app.document.finalize() }
		if kind == 'navigation' { app.screenshot_path = '' }
		if kind == 'scripted' { app.js_runtime = browserjs.Runtime.create() }
		if kind == 'tree-dump' { app.layout_tree_only = true }
		if kind == 'portable' { app.ctx = unsafe { nil } }
		if kind == 'existing-geometry' { app.relayout(320,240 + app.chrome_height()) }
		app.begin_frame_preparation()
		app.prepare_initial_document_layout(320,240 + app.chrome_height())
		assert !app.initial_layout_pending
		assert app.document.layout_is_up_to_date()
		app.finish_frame_preparation()
		if app.js_runtime != unsafe { nil } { app.js_runtime.close() }
	}
}

fn test_completed_local_css_faces_do_not_defer_initial_capture_layout() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>@font-face{font-family:InitialFace;src:url("file:///System/Library/Fonts/Supplemental/Arial.ttf")}html{font-family:InitialFace,sans-serif}</style><p>Initial face</p>')
		defer { document.finalize() }
		mut app := BrowserApp{document:document,ctx:&gg.Context{native_rendering:true},screenshot_path:'unused-capture.png'}
		app.begin_frame_preparation()
		app.prepare_initial_document_layout(320,240 + app.chrome_height())
		fonts := css.css_style_computer_for(document).font_face_set_
		assert fonts.set_entries().len == 1
		assert fonts.set_entries()[0].status() == .loaded
		assert !app.initial_layout_pending
		assert document.layout_is_up_to_date()
		app.finish_frame_preparation()
		assert app.paint_generation == 1
	}
}

fn test_capture_rechecks_style_selected_fonts_before_committing_initial_geometry() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><style>@font-face{font-family:NextCaptureFont;src:url("file:///System/Library/Fonts/Supplemental/Arial.ttf")}#target{width:70px;height:20px}</style><p id="target">New font selection</p>')
	defer { document.finalize() }
	_ = html.WindowModel.create_top_level(document, none, 'capture-font-cycle') or { panic(err) }
	mut fonts := css.css_style_computer_for(document).font_face_set_
	mut pending := &css.FontFaceObject{family_:'PendingCaptureFixture',status_:.loading}
	fonts.add(pending) or { panic(err) }
	mut app := BrowserApp{document:document,ctx:&gg.Context{native_rendering:true},screenshot_path:'unused-capture.png'}
	app.begin_frame_preparation()
	app.prepare_initial_document_layout(320,240 + app.chrome_height())
	app.finish_frame_preparation()
	assert app.initial_layout_pending
	complete_initial_capture_font(mut fonts, mut pending)
	mut target := document.get_element_by_id('target')?
	target.set_attribute_value('style', 'font-family:NextCaptureFont')
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	assert app.initial_layout_pending
	assert fonts.loading_fonts().len > 0
	assert document.layout_engine_handle() == unsafe { nil }
	mut loop := html.main_thread_event_loop()
	mut queue := loop.task_queue()
	for _ in 0 .. 100 {
		task := queue.take_first_runnable() or { break }
		task.execute()
	}
	assert fonts.loading_fonts().len == 0
	app.begin_frame_preparation()
	app.finish_frame_preparation()
	assert !app.initial_layout_pending
	assert document.layout_is_up_to_date()
	assert app.paint_generation == 1
	assert target.get_bounding_client_rect().width == 70
}

fn test_deferred_native_rendering_preserves_queued_and_active_opportunities() {
	mut client := page.PageClient.create()
	client.set_manual_rendering_opportunities(true)
	client.rendering_opportunity(123_000_000, 16)
	client.defer_rendering_opportunities(true)
	assert !client.has_rendering_opportunity()
	assert client.last_rendering_frame_time_nanoseconds() == 123_000_000
	client.defer_rendering_opportunities(false)
	assert client.has_rendering_opportunity()
	client.will_begin_rendering_update()
	client.defer_rendering_opportunities(true)
	assert !client.has_rendering_opportunity()
	client.defer_rendering_opportunities(false)
	assert client.has_rendering_opportunity()
	client.did_finish_rendering_update()
	assert !client.has_rendering_opportunity()
}
