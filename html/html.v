// Stub module for HTML-related functions called by Document
module html

import dom

// --- Realm / Global Object stubs ---

@[heap]
pub struct Realm {}

@[heap]
pub struct EnvironmentSettingsObject {
pub mut:
	execution_ready bool
}

@[heap]
pub struct Agent {
pub mut:
	event_loop &EventLoop = unsafe { nil }
}

@[heap]
pub struct EventLoop {
pub mut:
	termination_nesting_level int
}

pub fn (mut el EventLoop) increment_termination_nesting_level() {
	el.termination_nesting_level++
}

pub fn (mut el EventLoop) decrement_termination_nesting_level() {
	el.termination_nesting_level--
}

pub fn (el &EventLoop) task_queue() &TaskQueue {
	return &TaskQueue{}
}

@[heap]
pub struct TaskQueue {}

pub fn (tq &TaskQueue) remove_tasks_matching(predicate fn (&Task) bool) {
	// Stub
}

@[heap]
pub struct Task {
pub mut:
	document_ &dom.Document = unsafe { nil }
}

pub fn (t &Task) document() &dom.Document {
	return t.document_
}

pub struct TaskSource {
pub:
	value int
}

pub const dom_manipulation_task_source = TaskSource{1}

pub fn relevant_realm(doc &dom.Document) &Realm {
	return &Realm{}
}

pub fn relevant_global_object(doc &dom.Document) &dom.Window {
	if doc.window != unsafe { nil } {
		return doc.window
	}
	return &dom.Window{}
}

pub fn relevant_agent(doc &dom.Document) &Agent {
	return &Agent{
		event_loop: &EventLoop{}
	}
}

pub fn relevant_settings_object(w &dom.Window) &EnvironmentSettingsObject {
	return &EnvironmentSettingsObject{}
}

pub fn entry_global_object() &dom.Window {
	return &dom.Window{}
}

// --- URL matching stubs ---

pub fn url_matches_about_blank(url dom.URL) bool {
	return url.value == 'about:blank'
}

pub fn url_matches_about_srcdoc(url dom.URL) bool {
	return url.value == 'about:srcdoc'
}

// --- History / navigation stubs ---

pub fn perform_url_and_history_update_steps(doc &dom.Document, url dom.URL) {
	// Stub
}

// --- Event loop stubs ---

pub fn main_thread_event_loop() &EventLoop {
	return &EventLoop{}
}

pub fn queue_global_task(source TaskSource, global_obj voidptr, callback fn ()) {
	// Stub: would queue a task
}

// --- Structured deserialization ---

pub fn structured_deserialize(serialized voidptr, realm &Realm, memory voidptr) ?voidptr {
	return none
}

// --- High-resolution time ---

pub fn current_high_resolution_time(global_obj &dom.Window) f64 {
	return 0.0
}

// --- Event names ---
pub const event_load = 'load'
pub const event_unload = 'unload'
pub const event_pagehide = 'pagehide'
pub const event_readystatechange = 'readystatechange'
pub const event_visibilitychange = 'visibilitychange'

// --- Tag names ---
pub const tag_html = 'html'
pub const tag_head = 'head'
pub const tag_body = 'body'
pub const tag_div = 'div'
pub const tag_title = 'title'

// --- Attribute names ---
pub const attr_text = 'text'
pub const attr_link = 'link'
pub const attr_vlink = 'vlink'
pub const attr_alink = 'alink'
pub const attr_bgcolor = 'bgcolor'
pub const attr_href = 'href'
pub const attr_target = 'target'
pub const attr_content = 'content'
pub const attr_name = 'name'
pub const attr_media = 'media'

// --- Namespace ---
pub const namespace_html = 'http://www.w3.org/1999/xhtml'

// --- DocumentReadyState (HTML version) ---
pub enum DocumentReadyState {
	loading
	interactive
	complete
}

// --- VisibilityState (HTML version) ---
pub enum VisibilityState {
	visible
	hidden
}

// --- NavigableContainer stubs ---

@[heap]
pub struct NavigableContainer {
pub mut:
	document_ &dom.Document = unsafe { nil }
}

pub fn (nc &NavigableContainer) content_navigable() ?&dom.Navigable {
	return none
}

pub fn (nc &NavigableContainer) document() &dom.Document {
	return nc.document_
}

// --- MessagePort stubs ---

@[heap]
pub struct MessagePort {}

pub fn message_port_for_each(callback fn (&MessagePort)) {
	// Stub
}

// --- HTMLDocument stubs ---

@[heap]
pub struct HTMLDocument {
	dom.Document
}

pub fn html_document_create(realm &Realm) &HTMLDocument {
	return &HTMLDocument{}
}

// --- HTMLParser stubs ---

pub fn html_parser_create_for_scripting(doc &dom.Document) &dom.HTMLParser {
	return &dom.HTMLParser{}
}

// --- History stubs ---

pub fn history_create(realm &Realm) &dom.History {
	return &dom.History{}
}

// --- all_navigables ---

pub fn all_navigables() []&dom.Navigable {
	return []
}

// --- HTMLFrameSetElement type check ---

pub fn is_html_frame_set_element(node &dom.Node) bool {
	// Stub: would check if node is HTMLFrameSetElement
	return false
}

// --- HTMLIFrameElement stubs ---

@[heap]
pub struct HTMLIFrameElement {
	dom.HTMLElement
}

pub fn run_iframe_load_event_steps(iframe &HTMLIFrameElement) {
	// Stub
}

// --- NavigableContainer cast ---

pub fn as_navigable_container(node &dom.Node) ?&NavigableContainer {
	// Stub: would dynamic cast Node to NavigableContainer
	_ = node
	return none
}

// --- TemporaryExecutionContext ---

pub struct TemporaryExecutionContext {}

pub fn temporary_execution_context(realm &Realm) TemporaryExecutionContext {
	return TemporaryExecutionContext{}
}
