module main

import color
import browserjs
import css
import dom
import domurl
import encoding
import fetch
import fileapi
import geolocation
import geometry
import gg
import highresolutiontime
import html
import http
import infra
import layout
import mimesniff
import namespace_
import net.http as vhttp
import net.urllib
import os
import page
import referrerpolicy
import selection
import sri
import storageapi
import url
import webvtt
import x.json2

const initial_width = 1024
const initial_height = 768
const toolbar_height = 88.0
const page_margin = 28.0
const status_bar_height = 24.0

const demo_markup = '<!doctype html>
<html>
<head>
  <title>Ladybird V</title>
  <style>
    html { background: #e8edf3; color: #172033; font-size: 16px; }
    body { width: 760px; margin: 28px auto; padding: 36px; background: white;
           border: 1px solid #cbd5e1; border-radius: 14px; }
    h1 { color: #5b21b6; font-size: 34px; margin: 0 0 12px; }
    h2 { color: #334155; margin-top: 28px; }
    p { line-height: 1.55; margin: 10px 0; }
    .badge { display: block; width: 280px; padding: 10px 14px; margin: 20px 0;
             color: white; background: #6d28d9; border-radius: 8px; }
    .js-button { display: block; width: 320px; padding: 10px 14px; margin: 12px 0;
                 color: white; background: #0f766e; border-radius: 8px; }
    code { color: #9f1239; background: #fff1f2; padding: 2px 5px; }
  </style>
</head>
<body>
  <h1>Ladybird, rendered by V</h1>
  <p>This native window was compiled from the translated LibWeb V modules.</p>
  <div class="badge">HTML → DOM → CSS → Layout → Paint</div>
  <h2>A working vertical slice</h2>
  <p>The document was parsed by <code>html.parse_document</code>, styled by the translated CSS
     engine, laid out by <code>layout.layout_document</code>, and painted into this window.</p>
  <p id="js-status">JavaScript has not run.</p>
  <div id="js-button" class="js-button">Click to test JavaScript events</div>
  <p>Open a local HTML file by passing its path to the executable. Scroll with the mouse wheel,
     arrow keys, or Page Up/Page Down.</p>
  <script>
    document.getElementById("js-status").textContent = "JavaScript executed and changed this DOM node.";
    document.getElementById("js-button").addEventListener("click", function () {
      this.textContent = "JavaScript click handler executed.";
      console.log("click handler ran");
    });
    console.log("JavaScriptCore DOM bridge ready");
  </script>
</body>
</html>'

struct BrowserApp {
mut:
	ctx                   &gg.Context        = unsafe { nil }
	page_model            &page.Page         = unsafe { nil }
	js_runtime            &browserjs.Runtime = unsafe { nil }
	document              &dom.Document      = unsafe { nil }
	root_box              layout.BlockBox
	markup                string
	source_label          string
	address               string
	address_cursor        int
	address_active        bool
	address_select        bool
	viewport_width        int
	scroll_y              f64
	content_height        f64
	paint_commands        []layout.PaintCommand
	status                string
	load_status           string
	js_messages           []string
	history               []HistoryEntry
	history_index         int = -1
	hovered_link          string
	navigation_results    chan NavigationResult
	navigation_generation int
}

struct HistoryEntry {
	url    string
	markup string
}

struct LoadedPage {
	url          string
	markup       string
	status       string
	content_type string
}

struct NavigationResult {
	generation  int
	add_history bool
	resolved    string
	loaded      ?LoadedPage
	error       string
}

// Keep the root executable linked against the translated support modules too. The visible page
// pipeline below directly exercises HTML, DOM, CSS, and Layout; these references make accidental
// breakage at the other translated root boundaries a build-time failure.
fn link_translated_modules() {
	_ = color.from_named_css_color_string
	_ = css.StyleInvalidationReason.dom_mutation
	_ = dom.NodeType.invalid
	_ = domurl.url_encode
	_ = encoding.TextEncoder.create
	_ = fetch.is_ok_status
	_ = fileapi.Blob.create
	_ = fileapi.File.construct
	_ = fileapi.FileList.create
	_ = geolocation.GeolocationCoordinates.create
	_ = geometry.DOMPoint.construct
	_ = highresolutiontime.coarsen_time
	_ = html.event_load
	_ = http.HeaderList.create
	_ = referrerpolicy.from_string
	_ = infra.ascii_whitespace
	_ = layout.translated_layout_function_count
	_ = layout.AvailableSize.make_indefinite()
	_ = mimesniff.javascript_mime_type_essence_strings
	_ = namespace_.html
	_ = selection.selection_create
	_ = sri.do_bytes_match_metadata_list
	_ = storageapi.registered_endpoints
	_ = url.percent_encode
	_ = webvtt.ScrollSetting.empty
}

fn html_escape(value string) string {
	return value.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn initial_document() (string, string, string) {
	for argument in os.args[1..] {
		if argument == '--headless-smoke' || argument.starts_with('-psn_') {
			continue
		}
		if argument.trim_space().starts_with('<') {
			return 'about:srcdoc', argument, 'command-line HTML'
		}
		mut file_name := argument
		if file_name.starts_with('file://') {
			file_name = file_name['file://'.len..]
		}
		if os.is_file(file_name) {
			markup := os.read_file(file_name) or {
				return 'about:error', '<h1>Could not read file</h1><p>${html_escape(err.msg())}</p>', file_name
			}
			real_path := os.real_path(file_name)
			return 'file://${real_path}', markup, real_path
		}
		return argument, '', argument
	}
	return 'about:home', demo_markup, 'built-in translated-engine demo'
}

fn resolve_url(reference string, base string) string {
	trimmed := reference.trim_space()
	if trimmed == '' {
		return base
	}
	if trimmed.contains('://') || trimmed.starts_with('about:') || trimmed.starts_with('file:') {
		return trimmed
	}
	if os.is_file(trimmed) {
		return 'file://${os.real_path(trimmed)}'
	}
	if base != '' && (trimmed.starts_with('/') || trimmed.starts_with('./')
		|| trimmed.starts_with('../') || trimmed.starts_with('?')
		|| trimmed.starts_with('#')) {
		base_url := urllib.parse(base) or { return trimmed }
		reference_url := urllib.parse(trimmed) or { return trimmed }
		return (base_url.resolve_reference(&reference_url) or { return trimmed }).str()
	}
	if !trimmed.contains(' ') && (trimmed.contains('.') || trimmed.starts_with('localhost')) {
		return 'https://${trimmed}'
	}
	return 'https://duckduckgo.com/html/?q=${urllib.query_escape(trimmed)}'
}

fn resolve_document_reference(reference string, base string) string {
	trimmed := reference.trim_space()
	if trimmed == '' {
		return base
	}
	if trimmed.contains('://') || trimmed.starts_with('about:') || trimmed.starts_with('file:') {
		return trimmed
	}
	base_url := urllib.parse(base) or { return resolve_url(trimmed, '') }
	reference_url := urllib.parse(trimmed) or { return resolve_url(trimmed, '') }
	return (base_url.resolve_reference(&reference_url) or { return resolve_url(trimmed, '') }).str()
}

fn tls_ca_bundle() string {
	if configured := os.getenv_opt('SSL_CERT_FILE') {
		if os.is_file(configured) {
			return configured
		}
	}
	for candidate in ['/etc/ssl/cert.pem', '/etc/ssl/certs/ca-certificates.crt',
		'/opt/homebrew/etc/ca-certificates/cert.pem'] {
		if os.is_file(candidate) {
			return candidate
		}
	}
	return ''
}

fn fetch_page(address string, base string) !LoadedPage {
	resolved := resolve_url(address, base)
	if resolved == 'about:home' || resolved == 'about:blank' {
		return LoadedPage{
			url:          resolved
			markup:       if resolved == 'about:home' {
				demo_markup
			} else {
				'<html><body></body></html>'
			}
			status:       'Loaded locally'
			content_type: 'text/html'
		}
	}
	if resolved.starts_with('file://') {
		file_name := resolved['file://'.len..]
		markup := os.read_file(file_name)!
		return LoadedPage{
			url:          resolved
			markup:       markup
			status:       'Local file'
			content_type: 'text/html'
		}
	}
	if !resolved.starts_with('http://') && !resolved.starts_with('https://') {
		return error('Unsupported URL scheme')
	}
	response := vhttp.fetch(
		url:        resolved
		method:     .get
		user_agent: 'Ladybird V/0.1'
		validate:   true
		verify:     tls_ca_bundle()
	)!
	content_type := response.header.get(.content_type) or { 'text/html' }
	if response.status_code < 200 || response.status_code >= 400 {
		return error('HTTP ${response.status_code} ${response.status_msg}')
	}
	markup := if content_type.to_lower().contains('html') {
		response.body
	} else {
		'<html><body><h1>${html_escape(content_type)}</h1><pre>${html_escape(response.body)}</pre></body></html>'
	}
	return LoadedPage{
		url:          resolved
		markup:       markup
		status:       'HTTP ${response.status_code} · ${response.body.len} bytes'
		content_type: content_type
	}
}

fn fetch_text_resource(reference string, base string) !string {
	resolved := resolve_document_reference(reference, base)
	if resolved.starts_with('file://') {
		return os.read_file(resolved['file://'.len..])
	}
	response := vhttp.fetch(
		url:        resolved
		method:     .get
		user_agent: 'Ladybird V/0.1'
		validate:   true
		verify:     tls_ca_bundle()
	)!
	if response.status_code < 200 || response.status_code >= 400 {
		return error('HTTP ${response.status_code}')
	}
	return response.body
}

fn fetch_page_in_background(resolved string, base string, generation int, add_history bool, results chan NavigationResult) {
	loaded := fetch_page(resolved, base) or {
		results <- NavigationResult{
			generation:  generation
			add_history: add_history
			resolved:    resolved
			error:       err.msg()
		}
		return
	}
	results <- NavigationResult{
		generation:  generation
		add_history: add_history
		resolved:    resolved
		loaded:      loaded
	}
}

fn clamp(value f64, low f64, high f64) f64 {
	if value < low {
		return low
	}
	if value > high {
		return high
	}
	return value
}

fn document_title(document &dom.Document) string {
	root := unsafe { &dom.Node(document) }
	title := css.query_selector(root, 'title') or { return '' }
	return title.as_node().text_content() or { '' }
}

fn install_external_styles(document &dom.Document, base_url string) []string {
	root := unsafe { &dom.Node(document) }
	mut messages := []string{}
	for link in css.query_selector_all(root, 'link[rel][href]') {
		if link.get_attribute_value('rel').to_lower().split(' ').filter(it != '').all(it != 'stylesheet') {
			continue
		}
		href := link.get_attribute_value('href')
		stylesheet := fetch_text_resource(href, base_url) or {
			messages << 'Stylesheet ${href}: ${err.msg()}'
			continue
		}
		style := document.create_element('style') or { continue }
		mut style_node := unsafe { &dom.Node(style) }
		style_node.set_text_content(stylesheet) or { continue }
		head := css.query_selector(root, 'head') or { document.document_element() or { continue } }
		mut head_node := unsafe { &dom.Node(head) }
		head_node.append_child(style.as_node()) or { continue }
	}
	return messages
}

fn script_sources(document &dom.Document, base_url string, mut messages []string) []string {
	root := unsafe { &dom.Node(document) }
	mut sources := []string{}
	for script_element in css.query_selector_all(root, 'script') {
		type_ := script_element.get_attribute_value('type').trim_space().to_lower()
		if type_ != '' && type_ !in ['text/javascript', 'application/javascript', 'module'] {
			continue
		}
		if src := script_element.get_attribute('src') {
			source := fetch_text_resource(src, base_url) or {
				messages << 'Script ${src}: ${err.msg()}'
				continue
			}
			sources << source
		} else {
			sources << (script_element.as_node().text_content() or { '' })
		}
	}
	return sources
}

fn javascript_initial_state(document &dom.Document, current_url string) map[string]json2.Any {
	root := unsafe { &dom.Node(document) }
	body := css.query_selector(root, 'body')
	mut elements := map[string]json2.Any{}
	for element in css.query_selector_all(root, '[id]') {
		id := element.get_attribute_value('id')
		if id == '' {
			continue
		}
		state := {
			'id':          json2.Any(id)
			'textContent': json2.Any(element.as_node().text_content() or { '' })
			'innerHTML':   json2.Any(element.inner_html() or { '' })
			'className':   json2.Any(element.get_attribute_value('class'))
			'styleText':   json2.Any(element.get_attribute_value('style'))
			'onclick':     json2.Any(element.get_attribute_value('onclick'))
		}
		elements[id] = json2.Any(state)
	}
	return {
		'title':         json2.Any(document_title(document))
		'bodyHTML':      json2.Any(if body_element := body {
			body_element.inner_html() or { '' }
		} else {
			''
		})
		'bodyText':      json2.Any(if body_element := body {
			body_element.as_node().text_content() or { '' }
		} else {
			''
		})
		'bodyHTMLDirty': json2.Any(false)
		'bodyTextDirty': json2.Any(false)
		'location':      json2.Any(current_url)
		'navigate':      json2.Any('')
		'logs':          json2.Any([]json2.Any{})
		'elements':      json2.Any(elements)
	}
}

fn javascript_program(state map[string]json2.Any, scripts []string) string {
	state_json := json2.encode(state)
	scripts_json := json2.encode(scripts)
	return [
		'(function () {',
		'const __state = ${state_json};',
		'const __listeners = Object.create(null);',
		'function __listenerKey(s, n) { return (s && s.id ? s.id : "document") + ":" + n; }',
		'function __styleProxy(s) {',
		'  const values = Object.create(null);',
		'  String(s.styleText || "").split(";").forEach(function (part) { const i = part.indexOf(":"); if (i > 0) values[part.slice(0, i).trim()] = part.slice(i + 1).trim(); });',
		'  return new Proxy(values, { set: function (o, p, v) { o[p] = String(v); s.styleText = Object.keys(o).map(function (k) { return k + ": " + o[k]; }).join("; "); return true; }, get: function (o, p) { if (p === "cssText") return s.styleText; return o[p] || ""; } });',
		'}',
		'function __element(s) {',
		'  if (!s.__object) {',
		'    const o = { getAttribute: function (n) { if (n === "class") return s.className; if (n === "style") return s.styleText; return null; }, setAttribute: function (n, v) { if (n === "class") s.className = String(v); if (n === "style") s.styleText = String(v); }, addEventListener: function (n, f) { (__listeners[__listenerKey(s, n)] ||= []).push(f); } };',
		'    Object.defineProperties(o, { id: { get: function () { return s.id; } }, textContent: { get: function () { return s.textContent; }, set: function (v) { s.textContent = String(v); s.innerHTML = ""; } }, innerHTML: { get: function () { return s.innerHTML; }, set: function (v) { s.innerHTML = String(v); } }, className: { get: function () { return s.className; }, set: function (v) { s.className = String(v); } } });',
		'    o.style = __styleProxy(s); Object.defineProperty(s, "__object", { value: o, writable: true, configurable: true });',
		'  } return s.__object;',
		'}',
		'const document = { getElementById: function (id) { const s = __state.elements[String(id)]; return s ? __element(s) : null; }, querySelector: function (q) { return q && q[0] === "#" ? this.getElementById(q.slice(1)) : null; }, addEventListener: function (n, f) { (__listeners[__listenerKey(null, n)] ||= []).push(f); }, createElement: function () { return __element({ id: "", textContent: "", innerHTML: "", className: "", styleText: "", onclick: "" }); } };',
		'Object.defineProperty(document, "title", { get: function () { return __state.title; }, set: function (v) { __state.title = String(v); } });',
		'document.body = {}; Object.defineProperties(document.body, { innerHTML: { get: function () { return __state.bodyHTML; }, set: function (v) { __state.bodyHTML = String(v); __state.bodyHTMLDirty = true; __state.bodyTextDirty = false; } }, textContent: { get: function () { return __state.bodyText; }, set: function (v) { __state.bodyText = String(v); __state.bodyHTML = ""; __state.bodyTextDirty = true; __state.bodyHTMLDirty = false; } } });',
		'const console = { log: function () { __state.logs.push(Array.prototype.map.call(arguments, String).join(" ")); }, warn: function () { this.log.apply(this, arguments); }, error: function () { this.log.apply(this, arguments); } };',
		'const location = {}; Object.defineProperty(location, "href", { get: function () { return __state.location; }, set: function (v) { __state.navigate = String(v); } });',
		'const window = globalThis; window.window = window; window.document = document; window.console = console; window.location = location; window.alert = function (v) { console.log(v); }; window.setTimeout = function (f) { if (typeof f === "function") f(); return 1; }; window.addEventListener = document.addEventListener;',
		'window.__ladybirdSnapshot = function () { return JSON.stringify(__state); };',
		'window.__ladybirdClearLogs = function () { __state.logs = []; __state.bodyHTMLDirty = false; __state.bodyTextDirty = false; };',
		'window.__ladybirdDispatch = function (name, id) { const s = __state.elements[String(id)] || null; const target = s ? __element(s) : document; const event = { type: name, target: target, defaultPrevented: false, preventDefault: function () { this.defaultPrevented = true; } }; for (const listener of (__listeners[__listenerKey(s, name)] || [])) { try { listener.call(target, event); } catch (e) { console.error(e); } } if (s && name === "click" && s.onclick) { try { Function("event", s.onclick).call(target, event); } catch (e) { console.error(e); } } __state.defaultPrevented = event.defaultPrevented; return window.__ladybirdSnapshot(); };',
		'const __scripts = ${scripts_json}; for (const __source of __scripts) { try { (0, eval)(__source); } catch (e) { console.error(e && e.stack ? e.stack : e); } }',
		'for (const __name of ["DOMContentLoaded", "load"]) window.__ladybirdDispatch(__name, "");',
		'return window.__ladybirdSnapshot();',
		'})()',
	].join('\n')
}

fn json_string_property(object map[string]json2.Any, name string) ?string {
	value := object[name] or { return none }
	if value is string {
		return value
	}
	return none
}

fn json_bool_property(object map[string]json2.Any, name string) bool {
	value := object[name] or { return false }
	return if value is bool { value } else { false }
}

fn apply_javascript_state(document &dom.Document, encoded string, mut messages []string) ?string {
	value := json2.decode[json2.Any](encoded) or {
		messages << 'JavaScript bridge result: ${err.msg()}'
		return none
	}
	if value !is map[string]json2.Any {
		return none
	}
	state := value as map[string]json2.Any
	root := unsafe { &dom.Node(document) }
	body := css.query_selector(root, 'body')
	if json_bool_property(state, 'bodyHTMLDirty') {
		body_html := json_string_property(state, 'bodyHTML') or { '' }
		if mut body_element := body {
			if body_html != (body_element.inner_html() or { '' }) {
				body_element.set_inner_html(body_html) or { messages << err.msg() }
			}
		}
	} else if json_bool_property(state, 'bodyTextDirty') {
		body_text := json_string_property(state, 'bodyText') or { '' }
		if mut body_element := body {
			if body_text != (body_element.as_node().text_content() or { '' }) {
				mut body_node := unsafe { &dom.Node(body_element) }
				body_node.set_text_content(body_text) or { messages << err.msg() }
			}
		}
	}
	if element_values := state['elements'] {
		if element_values is map[string]json2.Any {
			for id, item in element_values as map[string]json2.Any {
				if item !is map[string]json2.Any {
					continue
				}
				mut element := document.get_element_by_id(id) or { continue }
				element_state := item as map[string]json2.Any
				if inner_html := json_string_property(element_state, 'innerHTML') {
					if inner_html != (element.inner_html() or { '' }) {
						element.set_inner_html(inner_html) or { messages << err.msg() }
					}
				}
				if text := json_string_property(element_state, 'textContent') {
					current_text := element.as_node().text_content() or { '' }
					if text != current_text && (json_string_property(element_state, 'innerHTML') or {
						''
					}) == '' {
						mut node := unsafe { &dom.Node(element) }
						node.set_text_content(text) or { messages << err.msg() }
					}
				}
				if class_name := json_string_property(element_state, 'className') {
					element.set_attribute_value('class', class_name)
				}
				if style_text := json_string_property(element_state, 'styleText') {
					element.set_attribute_value('style', style_text)
				}
			}
		}
	}
	if logs := state['logs'] {
		if logs is []json2.Any {
			for entry in logs as []json2.Any {
				if entry is string {
					messages << entry
				}
			}
		}
	}
	if title := json_string_property(state, 'title') {
		if mut title_element := css.query_selector(root, 'title') {
			mut title_node := unsafe { &dom.Node(title_element) }
			title_node.set_text_content(title) or {}
		}
	}
	return json_string_property(state, 'navigate')
}

fn run_document_javascript(document &dom.Document, current_url string, runtime &browserjs.Runtime, mut messages []string) ?string {
	sources := script_sources(document, current_url, mut messages)
	if sources.len == 0 {
		return none
	}
	result := runtime.evaluate(javascript_program(javascript_initial_state(document, current_url),
		sources)) or {
		messages << 'JavaScript: ${err.msg()}'
		return none
	}
	navigation := apply_javascript_state(document, result, mut messages)
	runtime.evaluate('__ladybirdClearLogs()') or {}
	return navigation
}

fn javascript_default_prevented(encoded string) bool {
	value := json2.decode[json2.Any](encoded) or { return false }
	if value !is map[string]json2.Any {
		return false
	}
	object := value as map[string]json2.Any
	prevented := object['defaultPrevented'] or { return false }
	return if prevented is bool { prevented } else { false }
}

fn (mut app BrowserApp) dispatch_javascript_event(name string, element &dom.Element) bool {
	if app.js_runtime == unsafe { nil } {
		return false
	}
	id := element.get_attribute_value('id')
	if id == '' {
		return false
	}
	result := app.js_runtime.evaluate('__ladybirdDispatch(${json2.encode(name)}, ${json2.encode(id)})') or {
		app.js_messages << 'JavaScript event: ${err.msg()}'
		return false
	}
	navigation := apply_javascript_state(app.document, result, mut app.js_messages)
	app.js_runtime.evaluate('__ladybirdClearLogs()') or {}
	app.relayout(app.viewport_width)
	if destination := navigation {
		if destination != '' {
			app.navigate(resolve_document_reference(destination, app.address), true)
		}
	}
	return javascript_default_prevented(result)
}

fn (mut app BrowserApp) relayout(window_width int) {
	if app.document == unsafe { nil } {
		return
	}
	available_width := if window_width > 360 { window_width - int(page_margin * 2.0) } else { 320 }
	app.root_box = layout.layout_document(app.document, f64(available_width))
	app.paint_commands = app.root_box.paint_commands()
	root_rect := app.root_box.border_box()
	app.content_height = root_rect.y + root_rect.height + page_margin * 2.0
	app.viewport_width = window_width
	app.status = '${app.load_status} · ${app.paint_commands.len} paints · ${int(root_rect.width)}×${int(root_rect.height)} CSS px'
}

fn (mut app BrowserApp) install_loaded_page(loaded LoadedPage, add_history bool) {
	app.markup = loaded.markup
	app.source_label = loaded.url
	app.address = loaded.url
	app.address_cursor = app.address.runes().len
	app.address_select = false
	app.scroll_y = 0
	app.load_status = loaded.status
	app.js_messages = []
	app.document = html.parse_document(loaded.markup)
	app.js_messages << install_external_styles(app.document, loaded.url)
	if app.js_runtime != unsafe { nil } {
		app.js_runtime.close()
	}
	app.js_runtime = browserjs.Runtime.create()
	javascript_navigation := run_document_javascript(app.document, loaded.url, app.js_runtime, mut
		app.js_messages)
	app.page_model.load(loaded.url)
	if add_history {
		if app.history_index + 1 < app.history.len {
			app.history = app.history[..app.history_index + 1].clone()
		}
		app.history << HistoryEntry{
			url:    loaded.url
			markup: loaded.markup
		}
		app.history_index = app.history.len - 1
	}
	app.relayout(if app.viewport_width > 0 { app.viewport_width } else { initial_width })
	title := document_title(app.document)
	gg.set_window_title(if title != '' { '${title} — Ladybird V' } else { 'Ladybird V' })
	if destination := javascript_navigation {
		if destination != '' && destination != loaded.url {
			app.navigate(resolve_document_reference(destination, loaded.url), true)
		}
	}
}

fn error_markup(address string, message string) string {
	return '<!doctype html><html><head><title>Navigation error</title><style>body{font-family:sans-serif;padding:40px;color:#172033}h1{color:#b91c1c}code{background:#f1f5f9;padding:4px}</style></head><body><h1>Could not load page</h1><p><code>${html_escape(address)}</code></p><p>${html_escape(message)}</p></body></html>'
}

fn (mut app BrowserApp) navigate(address string, add_history bool) {
	base := if app.history_index >= 0 && app.history_index < app.history.len {
		app.history[app.history_index].url
	} else {
		''
	}
	resolved := resolve_url(address, base)
	app.load_status = 'Loading ${resolved}'
	app.status = app.load_status
	app.navigation_generation++
	if app.ctx != unsafe { nil } {
		spawn fetch_page_in_background(resolved, base, app.navigation_generation, add_history,
			app.navigation_results)
		return
	}
	loaded := fetch_page(resolved, base) or {
		app.install_loaded_page(LoadedPage{
			url:          resolved
			markup:       error_markup(resolved, err.msg())
			status:       'Navigation error'
			content_type: 'text/html'
		}, add_history)
		return
	}
	app.install_loaded_page(loaded, add_history)
}

fn (mut app BrowserApp) poll_navigation() {
	select {
		result := <-app.navigation_results {
			if result.generation != app.navigation_generation {
				return
			}
			if loaded := result.loaded {
				app.install_loaded_page(loaded, result.add_history)
			} else {
				app.install_loaded_page(LoadedPage{
					url:          result.resolved
					markup:       error_markup(result.resolved, result.error)
					status:       'Navigation error'
					content_type: 'text/html'
				}, result.add_history)
			}
		}
		else {}
	}
}

fn (mut app BrowserApp) history_go(delta int) {
	target := app.history_index + delta
	if target < 0 || target >= app.history.len {
		return
	}
	app.history_index = target
	app.navigation_generation++
	entry := app.history[target]
	app.page_model.traverse_the_history_by_delta(delta)
	app.install_loaded_page(LoadedPage{
		url:          entry.url
		markup:       entry.markup
		status:       'History'
		content_type: 'text/html'
	}, false)
}

fn (mut app BrowserApp) reload() {
	if app.history_index < 0 || app.history_index >= app.history.len {
		return
	}
	app.page_model.reload()
	app.navigate(app.history[app.history_index].url, false)
}

fn (app &BrowserApp) maximum_scroll(window_height int) f64 {
	return if app.content_height + toolbar_height + status_bar_height > f64(window_height) {
		app.content_height + toolbar_height + status_bar_height - f64(window_height)
	} else {
		0.0
	}
}

fn (mut app BrowserApp) scroll_by(delta f64, window_height int) {
	app.scroll_y = clamp(app.scroll_y + delta, 0.0, app.maximum_scroll(window_height))
}

fn paint_color(serialized string, opacity f64) gg.Color {
	parsed := css.parse_color_string(serialized) or { return gg.rgba(15, 23, 42, 255) }
	alpha := clamp(f64(parsed.a) * opacity, 0.0, 255.0)
	return gg.rgba(parsed.r, parsed.g, parsed.b, u8(int(alpha + 0.5)))
}

fn (mut app BrowserApp) draw_command(command layout.PaintCommand, page_x f32, page_y f32, window_height int) {
	x := page_x + f32(command.x)
	y := page_y + f32(command.y - app.scroll_y)
	w := f32(command.width)
	h := f32(command.height)
	if y + h < f32(toolbar_height) || y > f32(window_height - int(status_bar_height)) {
		return
	}
	match command.kind {
		'fill_rect' {
			fill := paint_color(command.color, command.opacity)
			if command.radius > 0.0 {
				app.ctx.draw_rounded_rect_filled(x, y, w, h, f32(command.radius), fill)
			} else {
				app.ctx.draw_rect_filled(x, y, w, h, fill)
			}
		}
		'fill_gradient' {
			if gradient := command.gradient {
				if gradient.colors.len > 0 {
					first := gradient.colors[0]
					app.ctx.draw_rect_filled(x, y, w, h, gg.rgba(first.r, first.g, first.b, u8(int(clamp(f64(first.a) * command.opacity,
						0.0, 255.0)))))
				}
			}
		}
		'draw_text' {
			font_size := int(clamp(command.height * 0.78, 10.0, 42.0))
			app.ctx.draw_text(int(x), int(y), command.text,
				color: paint_color(command.color, command.opacity)
				size:  font_size
			)
		}
		else {}
	}
}

fn (mut app BrowserApp) draw_chrome_button(x f32, label string, enabled bool) {
	background := if enabled { gg.rgb(51, 65, 85) } else { gg.rgb(30, 41, 59) }
	foreground := if enabled { gg.rgb(241, 245, 249) } else { gg.rgb(100, 116, 139) }
	app.ctx.draw_rounded_rect_filled(x, 12, 36, 34, 7, background)
	app.ctx.draw_text(int(x) + 11, 18, label, color: foreground, size: 17)
}

fn address_for_display(address string, cursor int, active bool, max_characters int) string {
	mut runes := address.runes()
	mut visible_cursor := cursor
	if active {
		position := if cursor < 0 {
			0
		} else if cursor > runes.len {
			runes.len
		} else {
			cursor
		}
		runes.insert(position, `|`)
		visible_cursor = position + 1
	}
	if runes.len <= max_characters {
		return runes.string()
	}
	start := if visible_cursor > max_characters { visible_cursor - max_characters } else { 0 }
	end := if start + max_characters < runes.len { start + max_characters } else { runes.len }
	return runes[start..end].string()
}

fn (mut app BrowserApp) draw() {
	app.poll_navigation()
	window := gg.window_size()
	if window.width > 0 && window.width != app.viewport_width {
		app.relayout(window.width)
		app.scroll_y = clamp(app.scroll_y, 0.0, app.maximum_scroll(window.height))
	}
	app.ctx.begin()
	app.ctx.draw_rect_filled(0, 0, f32(window.width), f32(window.height), gg.rgb(232, 237, 243))
	page_y := f32(toolbar_height + page_margin)
	for command in app.paint_commands {
		app.draw_command(command, f32(page_margin), page_y, window.height)
	}

	// Draw chrome last so scrolled page content cannot paint over it.
	app.ctx.draw_rect_filled(0, 0, f32(window.width), f32(toolbar_height), gg.rgb(23, 32, 51))
	app.draw_chrome_button(12, '‹', app.history_index > 0)
	app.draw_chrome_button(54, '›', app.history_index + 1 < app.history.len)
	app.draw_chrome_button(96, '↻', app.history_index >= 0)
	app.draw_chrome_button(138, '⌂', true)
	address_x := f32(184)
	address_width := f32(window.width - 252)
	address_color := if app.address_active { gg.rgb(255, 255, 255) } else { gg.rgb(241, 245, 249) }
	app.ctx.draw_rounded_rect_filled(address_x, 12, address_width, 34, 8, address_color)
	if app.address_select {
		app.ctx.draw_rounded_rect_filled(address_x + 5, 16, address_width - 10, 26, 5, gg.rgb(219,
			234, 254))
	}
	visible_address := address_for_display(app.address, app.address_cursor, app.address_active,
		int(address_width / 8.0) - 2)
	app.ctx.draw_text(int(address_x) + 10, 19, visible_address,
		color: gg.rgb(15, 23, 42)
		size:  14
	)
	app.ctx.draw_rounded_rect_filled(f32(window.width - 60), 12, 48, 34, 8, gg.rgb(109, 40, 217))
	app.ctx.draw_text(window.width - 48, 20, 'Go', color: gg.rgb(255, 255, 255), size: 14)
	app.ctx.draw_text(14, 58, 'V · HTML/DOM/CSS/Layout · JavaScriptCore',
		color: gg.rgb(196, 181, 253)
		size:  13
	)
	app.ctx.draw_text(348, 58, app.status, color: gg.rgb(148, 163, 184), size: 12)

	status_y := window.height - int(status_bar_height)
	app.ctx.draw_rect_filled(0, f32(status_y), f32(window.width), f32(status_bar_height), gg.rgb(30,
		41, 59))
	footer := if app.hovered_link != '' {
		app.hovered_link
	} else if app.js_messages.len > 0 {
		'Console: ${app.js_messages.last()}'
	} else {
		app.source_label
	}
	app.ctx.draw_text(12, status_y + 4, footer, color: gg.rgb(203, 213, 225), size: 12)
	app.ctx.end()
}

fn (app &BrowserApp) element_at_window_point(mouse_x f32, mouse_y f32) ?&dom.Element {
	if mouse_y < f32(toolbar_height)
		|| mouse_y >= f32(gg.window_size().height) - f32(status_bar_height) {
		return none
	}
	document_x := f64(mouse_x - f32(page_margin))
	document_y := f64(mouse_y - f32(toolbar_height + page_margin)) + app.scroll_y
	root := unsafe { &dom.Node(app.document) }
	return app.root_box.element_at_point(document_x, document_y, root)
}

fn (app &BrowserApp) link_at_point(mouse_x f32, mouse_y f32) ?string {
	mut element := app.element_at_window_point(mouse_x, mouse_y) or { return none }
	for {
		if element.local_name() == 'a' {
			href := element.get_attribute_value('href')
			if href != '' {
				return resolve_document_reference(href, app.address)
			}
		}
		element = element.as_node().parent_element() or { break }
	}
	return none
}

fn (mut app BrowserApp) handle_click(x f32, y f32) {
	if y >= 12 && y <= 46 {
		if x >= 12 && x < 48 {
			app.history_go(-1)
			return
		}
		if x >= 54 && x < 90 {
			app.history_go(1)
			return
		}
		if x >= 96 && x < 132 {
			app.reload()
			return
		}
		if x >= 138 && x < 174 {
			app.navigate('about:home', true)
			return
		}
		window := gg.window_size()
		if x >= 184 && x < f32(window.width - 68) {
			app.address_active = true
			app.address_select = true
			app.address_cursor = app.address.runes().len
			return
		}
		if x >= f32(window.width - 60) {
			app.navigate(app.address, true)
			app.address_active = false
			return
		}
	}
	app.address_active = false
	app.address_select = false
	if mut target := app.element_at_window_point(x, y) {
		for {
			if target.get_attribute_value('id') != '' {
				if app.dispatch_javascript_event('click', target) {
					return
				}
				break
			}
			target = target.as_node().parent_element() or { break }
		}
	}
	if destination := app.link_at_point(x, y) {
		app.navigate(destination, true)
	}
}

fn (mut app BrowserApp) handle_event(event &gg.Event) {
	match event.typ {
		.mouse_scroll {
			app.scroll_by(-f64(event.scroll_y) * 42.0, event.window_height)
		}
		.resized {
			app.relayout(event.window_width)
			app.scroll_y = clamp(app.scroll_y, 0.0, app.maximum_scroll(event.window_height))
		}
		.mouse_move {
			app.hovered_link = app.link_at_point(event.mouse_x, event.mouse_y) or { '' }
		}
		else {}
	}
}

fn (mut app BrowserApp) handle_character(code u32) {
	if !app.address_active || code < 32 || code == 127 {
		return
	}
	mut runes := app.address.runes()
	if app.address_select {
		runes.clear()
		app.address_cursor = 0
		app.address_select = false
	}
	position := if app.address_cursor < 0 {
		0
	} else if app.address_cursor > runes.len {
		runes.len
	} else {
		app.address_cursor
	}
	runes.insert(position, rune(code))
	app.address_cursor = position + 1
	app.address = runes.string()
}

fn (mut app BrowserApp) handle_key(key gg.KeyCode, modifier gg.Modifier) {
	height := gg.window_size().height
	command := modifier.has(.super) || modifier.has(.ctrl)
	if command && key == .l {
		app.address_active = true
		app.address_select = true
		app.address_cursor = app.address.runes().len
		return
	}
	if command && key == .r {
		app.reload()
		return
	}
	if app.address_active {
		mut runes := app.address.runes()
		match key {
			.enter {
				app.address_active = false
				app.address_select = false
				app.navigate(app.address, true)
			}
			.backspace {
				if app.address_select {
					app.address = ''
					app.address_cursor = 0
					app.address_select = false
				} else if app.address_cursor > 0 && runes.len > 0 {
					runes.delete(app.address_cursor - 1)
					app.address_cursor--
					app.address = runes.string()
				}
			}
			.delete {
				if app.address_cursor < runes.len {
					runes.delete(app.address_cursor)
					app.address = runes.string()
				}
			}
			.left {
				app.address_cursor = if app.address_cursor > 0 { app.address_cursor - 1 } else { 0 }
				app.address_select = false
			}
			.right {
				app.address_cursor = if app.address_cursor < runes.len {
					app.address_cursor + 1
				} else {
					runes.len
				}
				app.address_select = false
			}
			.home {
				app.address_cursor = 0
				app.address_select = false
			}
			.end {
				app.address_cursor = runes.len
				app.address_select = false
			}
			.escape {
				app.address_active = false
				app.address_select = false
			}
			else {}
		}
		return
	}
	match key {
		.up { app.scroll_by(-42.0, height) }
		.down { app.scroll_by(42.0, height) }
		.page_up { app.scroll_by(-f64(height) * 0.8, height) }
		.page_down { app.scroll_by(f64(height) * 0.8, height) }
		.home { app.scroll_y = 0.0 }
		.end { app.scroll_y = app.maximum_scroll(height) }
		.escape { app.ctx.quit() }
		else {}
	}
}

fn main() {
	link_translated_modules()
	initial_url, markup, source_label := initial_document()
	page_model := page.Page.create(1.0) or { panic(err) }
	mut app := &BrowserApp{
		markup:             markup
		source_label:       source_label
		page_model:         page_model
		navigation_results: chan NavigationResult{cap: 4}
	}
	if markup != '' {
		app.install_loaded_page(LoadedPage{
			url:          initial_url
			markup:       markup
			status:       'Loaded locally'
			content_type: 'text/html'
		}, true)
	} else {
		app.navigate(initial_url, true)
	}

	if '--headless-smoke' in os.args {
		if app.source_label == 'about:home' {
			js_status := app.document.get_element_by_id('js-status') or {
				panic('headless smoke: JavaScript target element is missing')
			}
			if (js_status.as_node().text_content() or { '' }) != 'JavaScript executed and changed this DOM node.' {
				panic('headless smoke: JavaScript did not mutate the translated DOM')
			}
			println('javascript DOM mutation: passed')
			js_button := app.document.get_element_by_id('js-button') or {
				panic('headless smoke: JavaScript event target is missing')
			}
			app.dispatch_javascript_event('click', js_button)
			if (js_button.as_node().text_content() or { '' }) != 'JavaScript click handler executed.' {
				panic('headless smoke: JavaScript click handler did not mutate the translated DOM')
			}
			println('javascript click event: passed')
		}
		println('Ladybird V smoke check passed')
		println('source: ${app.source_label}')
		println(app.status)
		for message in app.js_messages {
			println('console: ${message}')
		}
		return
	}

	app.ctx = gg.new_context(
		width:            initial_width
		height:           initial_height
		min_width:        640
		min_height:       480
		window_title:     'Ladybird V'
		bg_color:         gg.rgb(232, 237, 243)
		native_rendering: true
		frame_fn:         fn (mut app BrowserApp) {
			app.draw()
		}
		event_fn:         fn (event &gg.Event, mut app BrowserApp) {
			app.handle_event(event)
		}
		click_fn:         fn (x f32, y f32, _ gg.MouseButton, mut app BrowserApp) {
			app.handle_click(x, y)
		}
		char_fn:          fn (code u32, mut app BrowserApp) {
			app.handle_character(code)
		}
		keydown_fn:       fn (key gg.KeyCode, modifier gg.Modifier, mut app BrowserApp) {
			app.handle_key(key, modifier)
		}
		user_data:        app
	)
	app.ctx.run()
}
