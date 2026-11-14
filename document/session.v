module main

import browsernet
import browserjs
import browsersettings
import css
import dom
import html
import layout
import platform

// The pointer embed preserves the shell's existing field access while making
// navigation and cache transfers move one stable owner. Document callbacks
// capture this owner, never the shell's currently selected document.
type DocumentSessionRef = &DocumentSession

enum DocumentSessionState {
	active
	suspended
	retired
}

@[heap]
struct DocumentSession {
	BrowserMediaOwner
mut:
	state                 DocumentSessionState
	document              &dom.Document      = unsafe { nil }
	js_runtime            &browserjs.Runtime = unsafe { nil }
	image_request_loader  ?&BrowserImageRequestLoader
	script_request_loader ?&BrowserScriptRequestLoader
	child_document_host   ?&BrowserChildDocumentHost
	cached_navigable      &dom.Navigable = unsafe { nil }
	page_showing          bool
	force_dark_setting    ?bool
	markup                string
	content_type          string
	source_label          string
	load_status           string
	js_messages           []string
	animation_epoch_ns    u64
	adblock_tokens        BrowserAdblockTokenCache

	// A worker's destination stays with its document even while that document
	// is cached. Replacements cannot consume an outgoing page's completions.
	background_resource_results     chan PreloadedResource
	background_resource_scope       ?&browsernet.RequestScope
	resource_cache                  map[string]PreloadedResource
	background_resource_jobs        int
	background_resource_pending     map[string]bool
	script_stylesheet_requests      map[string]bool
	script_stylesheet_links         map[dom.UniqueNodeID]string
	script_stylesheet_responses     map[string]PreloadedResource
	script_stylesheet_scan_version  u64
	script_image_requests           map[string]bool
	script_image_scan_version       u64
	nonrendered_image_preloads      map[string]bool
	background_image_scope_document voidptr
	background_image_scope_adblock  bool
	background_image_scope_ids      map[string]int

	scroll_y               f64
	page_zoom              f64 = 1
	applied_page_zoom      f64 = 1
	content_height         f64
	pending_editing_scroll ?&dom.InputEventsTarget
	hovered_link           string
	initial_layout_pending bool
	document_presented     bool

	// Adopted geometry and the exact recording lease belong to the session.
	// Suspension drops these replay views but preserves the DOM's layout;
	// resumption records that retained layout for the current viewport.
	root_box                              layout.BlockBox
	paint_tree_storage                    voidptr = unsafe { nil }
	paint_commands                        []layout.PaintCommand
	paint_display_list                    &dom.DisplayList = unsafe { nil }
	paint_scene                           voidptr
	paint_commands_pending                bool
	paint_commands_have_backdrop_filter   bool
	paint_status_key                      PaintStatusKey
	paint_status_text                     string
	chromium_raster_plan                  layout.ChromiumRasterLayerPlan
	chromium_raster_tiles                 [][]i32
	chromium_raster_grids                 []ChromiumRasterGrid
	chromium_background_uses_local_origin bool
	scroll_raster_keys                    ScrollRasterKeyFrame
	scroll_raster_content_eligible        bool
	scroll_raster_frame_deferred          bool
	// A check box background deferred to its border's native GPU pass, with
	// the command as drawn and as it was submitted.
	rounded_rect_underlay ?layout.PaintCommand
	// draw_command's working copy of each command, one per nesting depth.
	draw_command_copies              []&layout.PaintCommand
	rounded_rect_underlay_source     ?layout.PaintCommand
	background_image_border          ?layout.PaintCommand
	background_image_border_consumed bool
}

fn new_document_session() &DocumentSession {
	// A navigation may start inside an outgoing document's task/frame arena.
	// The owner and its result channel must survive that allocation scope.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	return &DocumentSession{ background_resource_results: chan PreloadedResource{cap: max_cached_resources} }
}

fn (app &BrowserApp) document_session() &DocumentSession {
	return &DocumentSession(app.DocumentSessionRef)
}

fn (mut session DocumentSession) media_owner() &BrowserMediaOwner {
	// Fixtures can supply document directly through the promoted field. Keep
	// the narrow media owner bound without requiring a browser-shell callback.
	if !session.BrowserMediaOwner.closed && !session.BrowserMediaOwner.retiring {
		session.BrowserMediaOwner.media_document = session.document
	}
	return &session.BrowserMediaOwner
}

fn (mut session DocumentSession) adopt_runtime(runtime &browserjs.Runtime) {
	if session.state == .retired {
		mut abandoned := unsafe { &browserjs.Runtime(runtime) }
		abandoned.close()
		return
	}
	session.js_runtime = runtime
}

fn (mut session DocumentSession) activate(document &dom.Document) {
	assert session.state == .active && session.document == unsafe { nil }
	session.document = document
	session.BrowserMediaOwner.media_document = document
	if navigable := document.navigable() {
		session.apply_browser_force_dark(navigable, browsersettings.current().force_dark_enabled)
	}
}

fn (mut session DocumentSession) unbind_runtime() {
	if session.js_runtime != unsafe { nil } && session.js_runtime.engine == .libjs {
		mut event_loop := html.main_thread_event_loop()
		// Retiring a different session must not unbind the incoming realm.
		event_loop.unbind_vm(session.js_runtime.libjs_vm())
	}
}

fn (mut session DocumentSession) suspend() bool {
	if session.state != .active || session.document == unsafe { nil } { return false }
	session.cached_navigable = session.document.navigable() or { return false }
	session.page_showing = session.document.document_page_showing()
	session.state = .suspended
	html.suspend_document_for_back_forward_cache(session.document)
	if session.js_runtime != unsafe { nil } {
		// The navigation that led away has already been consumed. Do not replay
		// the compact facade's old request when this realm resumes.
		session.js_runtime.evaluate_host('typeof __ladybirdClearNavigation==="function"&&__ladybirdClearNavigation()') or {}
	}
	session.unbind_runtime()
	session.release_document_rendering()
	return true
}

fn (session &DocumentSession) can_resume() bool {
	return session.state == .suspended && session.document != unsafe { nil }
		&& html.can_reactivate_back_forward_cached_document(session.document)
}

// The shell publishes this session before calling resume: pageshow handlers
// can synchronously inspect the active document, realm and resource owners.
fn (mut session DocumentSession) resume(navigable &dom.Navigable) bool {
	if !session.can_resume() { return false }
	// Refresh cached style before pageshow can query it. A settings change
	// while this owner was suspended only invalidated the active document.
	session.apply_browser_force_dark(navigable, browsersettings.current().force_dark_enabled)
	session.state = .active
	if session.js_runtime != unsafe { nil } && session.js_runtime.engine == .libjs {
		mut event_loop := html.main_thread_event_loop()
		event_loop.bind_vm(session.js_runtime.libjs_vm())
	}
	html.reactivate_back_forward_cached_document(session.document, navigable, session.page_showing)
	return true
}

// Every exit path uses this operation, including replacement, cache eviction
// and tab closure. Mark first so reentrant callbacks cannot retire twice or
// install new services. Publishers close before their final storage lease.
fn (mut session DocumentSession) retire() {
	if session.state == .retired { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	session.state = .retired
	session.BrowserMediaOwner.begin_retirement()
	if mut loader := session.image_request_loader { loader.cancel() }
	if mut loader := session.script_request_loader { loader.cancel() }
	if mut children := session.child_document_host { children.close() }
	session.unbind_runtime()
	if session.js_runtime != unsafe { nil } { session.js_runtime.close() }
	session.close_media_playback()
	session.retire_background_resources()
	session.adblock_tokens.release()
	if session.document != unsafe { nil } {
		_ = css.discard_native_document_computed_styles(session.document)
	}
	session.release_document_rendering()
	if session.document != unsafe { nil } {
		mut document := session.document
		if !document.has_been_destroyed() { document.destroy_a_document_and_its_descendants() }
		document.finalize()
		// DOM retires its current layout publisher before releasing storage.
		// Do not retain a raw layout handle across deactivation: it may already
		// have been retired by the navigable's active-document transition.
		document.release_native_storage()
	}
	// Clear the complete owner, rather than another list of document fields.
	// Workers may still hold the old channel; never close their destination.
	session = DocumentSession{ BrowserMediaOwner: BrowserMediaOwner{ closed: true }, state: .retired }
}
