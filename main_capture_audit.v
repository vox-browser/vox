module main

import adblock
import crypto.sha256
import css
import dom
import html
import json2
import os
import platform

// Observe a normally active window after a benchmark's memory endpoint. The
// screenshot launch mode intentionally changes document activity, so it cannot
// serve as the content check for an ordinary scripted browsing measurement.
fn (mut app BrowserApp) schedule_native_observation() bool {
	delay_text := os.getenv('VOX_NATIVE_OBSERVATION_DELAY_MS')
	if delay_text == '' { return false }
	delay := delay_text.int()
	if delay <= 0 { return false }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	screenshot := os.getenv('VOX_NATIVE_OBSERVATION_SCREENSHOT')
	mut timer := platform.Timer.create_single_shot(delay, fn [app, screenshot] () {
		active := app.active_browser_tab()
		active.write_capture_audit_if_requested()
		if screenshot != '' { schedule_native_screenshot(screenshot) }
	})
	timer.start()
	return true
}

// Optional observer output for reproducible native capture benchmarks. Reading
// this snapshot does not materialize image/font state or force another layout.
// Error descriptions opt into JavaScript string conversion; ordinary captures
// only count errors. Selectors and output paths belong to the test caller.
struct CaptureAuditSelector {
	name         string
	selector     string
	limit        int = 100
	attributes   []string
	layout_depth int
}

struct CaptureAuditConfig {
	selectors               []CaptureAuditSelector
	describe_native_errors  bool
	describe_paint_geometry bool
}

struct CaptureAuditPaintGeometry {
	index         int
	kind          string
	x             f64
	y             f64
	width         f64
	height        f64
	transform     [6]f64
	svg_transform [6]f64
	path_sha256   string
	path_segments int
}

struct CaptureAuditImage {
	model_present  bool
	complete       bool
	current_src    string
	natural_width  u32
	natural_height u32
	paint_decoded  bool
	paint_width    int
	paint_height   int
}

struct CaptureAuditElement {
	tag             string
	text            string
	text_utf8_bytes int
	text_sha256     string
	rect            dom.Rect
	attributes      map[string]string
	image           ?CaptureAuditImage
	media           ?CaptureAuditMedia
	layout          []CaptureAuditLayout
}

struct CaptureAuditMedia {
	current_src   string
	current_time  f64
	duration      f64
	paused        bool
	ready_state   string
	network_state string
	error_message string
	frame_width   u32
	frame_height  u32
	frame_sha256  string
}

fn (app &BrowserApp) capture_audit_media(element &dom.Element) ?CaptureAuditMedia {
	for player in app.media_players {
		if voidptr(player.element) == voidptr(element) {
			mut width := u32(0)
			mut height := u32(0)
			mut frame_hash := ''
			if frame := player.frame {
				width = frame.width
				height = frame.height
				if bitmap := frame.rgba_bitmap { frame_hash = sha256.sum(bitmap.data).hex() }
			}
			media := player.media
			return CaptureAuditMedia{
				current_src:   media.current_src()
				current_time:  media.current_time()
				duration:      media.duration()
				paused:        media.paused()
				ready_state:   media.ready_state().str()
				network_state: media.network_state().str()
				error_message: if error_ := media.error() { error_.message() } else { '' }
				frame_width:   width
				frame_height:  height
				frame_sha256:  frame_hash
			}
		}
	}
	return none
}

struct CaptureAuditSelection {
	name     string
	selector string
	count    int
	elements []CaptureAuditElement
}

struct CaptureAuditFontFace {
	family              string
	style               string
	weight              string
	status              string
	parsed_font_present bool
	source_path         string
	declared_sources    []string
}

struct CaptureAudit {
	url                    string
	title                  string
	ready                  string
	visibility             string
	fully_active           bool
	viewport_width         int
	viewport_height        int
	font_set_present       bool
	fonts_status           string
	font_faces             []CaptureAuditFontFace
	paint_commands         int
	paint_geometry         []CaptureAuditPaintGeometry
	javascript_diagnostics []string
	// Native HTML timer/event exceptions bypass the compact bridge log.
	native_reported_error_count int
	native_reported_errors      []string
	selections                  []CaptureAuditSelection
	note                        string = 'Retained DOM/layout/image snapshot. Document-only captures collect after PNG encoding; other captures collect when scheduled. Collection is included in process-exit instruction totals.'
}

fn (app &BrowserApp) capture_audit_image(element &dom.Element) ?CaptureAuditImage {
	if !element.is_html_element() || element.local_name() != 'img' { return none }
	image := unsafe { &dom.HTMLImageElement(element) }
	mut model_present := false
	mut complete := false
	mut current_src := ''
	mut natural_width := u32(0)
	mut natural_height := u32(0)
	if image.image_element_model_ != unsafe { nil } {
		model_present = true
		model := unsafe { &html.HTMLImageElementModel(image.image_element_model_) }
		complete = model.complete()
		current_src = model.current_src()
		natural_width = model.natural_width()
		natural_height = model.natural_height()
	}
	mut paint_decoded := false
	mut paint_width := 0
	mut paint_height := 0
	if app.ctx != unsafe { nil } && app.document != unsafe { nil } {
		source := resolve_document_reference(element.get_attribute_value('src'), app.document.base_url().serialize())
		key := app.document.url.serialize() + '\n' + adblock.is_enabled().str() + '\n' + source
		if image_id := app.background_image_ids[key] {
			decoded := app.ctx.get_cached_image_by_idx(image_id)
			if decoded.ok {
				paint_decoded = true
				paint_width = decoded.width
				paint_height = decoded.height
			}
		}
	}
	return CaptureAuditImage{model_present, complete, current_src, natural_width, natural_height, paint_decoded, paint_width, paint_height}
}

fn (app &BrowserApp) collect_capture_audit(config CaptureAuditConfig) !CaptureAudit {
	if app.document == unsafe { nil } { return error('Capture audit requires a document') }
	mut selections := []CaptureAuditSelection{}
	for query in config.selectors {
		if query.name == '' || query.selector == '' || query.limit < 0 || query.limit > 1000
			|| query.layout_depth < 0 || query.layout_depth > 4 {
			return error('Invalid capture audit selector configuration')
		}
		list := unsafe { &dom.ParentNode(app.document) }.query_selector_all(query.selector)!
		mut elements := []CaptureAuditElement{}
		limit := if list.length() < query.limit { list.length() } else { query.limit }
		for index in 0 .. limit {
			node := list.item(index) or { continue }
			element := node.as_element() or { continue }
			text := node.text_content() or { '' }
			mut attributes := map[string]string{}
			for name in query.attributes {
				if value := element.get_attribute(name) { attributes[name] = value }
			}
			elements << CaptureAuditElement{
				tag:             element.local_name()
				text:            text
				text_utf8_bytes: text.len
				text_sha256:     sha256.hexhash(text)
				rect:            element.bounding_client_rect_assuming_layout_clean()
				attributes:      attributes
				image:           app.capture_audit_image(element)
				media:           app.capture_audit_media(element)
				layout:          app.capture_audit_layout(element, query.layout_depth)
			}
		}
		selections << CaptureAuditSelection{query.name, query.selector, list.length(), elements}
	}
	mut font_set_present := false
	mut fonts_status := 'unmaterialized'
	mut font_faces := []CaptureAuditFontFace{}
	if owner := app.document.existing_font_face_set() {
		if owner.font_face_set_record() != unsafe { nil } {
			font_set_present = true
			fonts := unsafe { &css.FontFaceSet(owner.font_face_set_record()) }
			fonts_status = fonts.status().str()
			for face in fonts.set_entries() {
				parsed := face.parsed_font != unsafe { nil }
				font_faces << CaptureAuditFontFace{
					family:              face.family()
					style:               face.style()
					weight:              face.weight()
					status:              face.status().str()
					parsed_font_present: parsed
					source_path:         if parsed { face.parsed_font.source_path } else { '' }
					declared_sources:    face.urls.map(it.value)
				}
			}
		}
	}
	mut native_reported_error_count := 0
	mut native_reported_errors := []string{}
	record := app.document.relevant_settings_object()
	if record != unsafe { nil } {
		settings := unsafe { &html.EnvironmentSettingsObject(record) }
		if scope := settings.window_or_worker_global_scope() {
			native_reported_error_count = scope.reported_errors().len
			if config.describe_native_errors {
				for reason in scope.reported_errors() {
					native_reported_errors << reason.to_string_value()
				}
			}
		}
	}
	mut paint_geometry := []CaptureAuditPaintGeometry{}
	if config.describe_paint_geometry {
		for index, command in app.paint_commands {
			if paint_geometry.len >= 256 { break }
			if command.kind != 'draw_svg_path' { continue }
			svg := command.svg()
			paint_geometry << CaptureAuditPaintGeometry{
				index:         index
				kind:          command.kind
				x:             command.x
				y:             command.y
				width:         command.width
				height:        command.height
				transform:     command.transform
				svg_transform: svg.path_transform
				path_sha256:   sha256.hexhash(svg.path)
				path_segments: svg.path_data.len / 12
			}
		}
	}
	return CaptureAudit{
		url:                         app.document.url.serialize()
		title:                       app.document.title()
		ready:                       app.document.readiness().str()
		visibility:                  app.document.visibility_state()
		fully_active:                app.document.is_fully_active()
		viewport_width:              app.viewport_width
		viewport_height:             app.viewport_height
		font_set_present:            font_set_present
		fonts_status:                fonts_status
		font_faces:                  font_faces
		paint_commands:              app.paint_commands.len
		paint_geometry:              paint_geometry
		javascript_diagnostics:      app.js_messages.clone()
		native_reported_error_count: native_reported_error_count
		native_reported_errors:      native_reported_errors
		selections:                  selections
	}
}

fn (app &BrowserApp) write_capture_audit_if_requested() {
	path := os.getenv('VOX_CAPTURE_AUDIT_PATH')
	if path == '' { return }
	config_path := os.getenv('VOX_CAPTURE_AUDIT_CONFIG')
	config := if config_path != '' {
		encoded := os.read_file(config_path) or {
			eprintln('Vox capture audit: ${err.msg()}')
			return
		}
		json2.decode[CaptureAuditConfig](encoded) or {
			eprintln('Vox capture audit: ${err.msg()}')
			return
		}
	} else {
		CaptureAuditConfig{}
	}
	audit := app.collect_capture_audit(config) or {
		eprintln('Vox capture audit: ${err.msg()}')
		return
	}
	write_capture_audit_json(path, audit) or { eprintln('Vox capture audit: ${err.msg()}') }
}
