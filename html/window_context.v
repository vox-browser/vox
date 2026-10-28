// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BrowsingContext.{h,cpp}, Location.{h,cpp},
// WindowProxy.{h,cpp}, and the browsing-context-facing algorithms in
// Window.{h,cpp}. VM object internal methods and browser chrome operations are
// represented by explicit properties and host hooks.
module html

import css
import dom
import fileapi
import highresolutiontime
import platform
import speech

pub struct LocationNavigation {
pub:
	url              dom.URL
	history_behavior HistoryHandlingBehavior
}

pub type LocationNavigateHook = fn(dom.URL, HistoryHandlingBehavior) !

pub type LocationReloadHook = fn()

@[heap]
pub struct LocationModel {
	dom.Location
mut:
	document_                   ?&dom.Document
	entry_origin_               dom.Origin
	prototype_                  dom.JSValue = dom.JSValue{ kind: .null_ }
	properties_                 map[string]dom.JSValue
	deleted_default_properties_ map[string]bool
	navigate_hook_              ?LocationNavigateHook
	reload_hook_                ?LocationReloadHook
	navigations_                []LocationNavigation
	reload_count_               u32
}

pub fn (location &LocationModel) cross_origin_property_descriptor_map() []CrossOriginProperty {
	_ = location
	return cross_origin_properties(.location)
}

pub fn (location &LocationModel) is_html_location() bool {
	_ = location
	return true
}

const location_default_property_names = [
	'href',
	'origin',
	'protocol',
	'host',
	'hostname',
	'port',
	'pathname',
	'search',
	'hash',
	'assign',
	'replace',
	'reload',
	'toString',
]

fn js_values_are_same(left dom.JSValue, right dom.JSValue) bool {
	if left.kind != right.kind {
		return false
	}
	return match left.kind {
		.undefined, .null_ { true }
		.boolean { left.boolean_data == right.boolean_data }
		.number { left.number_data == right.number_data }
		.string { left.string_data == right.string_data }
		.object { left.object_data == right.object_data }
		.runtime_value { left.native_same_value(right) or { panic(err) } }
	}
}

fn (location &LocationModel) is_same_origin_with(caller_origin dom.Origin) bool {
	document := location.document_ or { return true }
	return document.origin().is_same_origin(caller_origin)
}

fn (location &LocationModel) default_property_value(name string) !dom.JSValue {
	return match name {
		'href', 'toString' { dom.js_string(location.href()!) }
		'origin' { dom.js_string(location.origin()!) }
		'protocol' { dom.js_string(location.protocol()!) }
		'host' { dom.js_string(location.host()!) }
		'hostname' { dom.js_string(location.hostname()!) }
		'port' { dom.js_string(location.port()!) }
		'pathname' { dom.js_string(location.pathname()!) }
		'search' { dom.js_string(location.search()!) }
		'hash' { dom.js_string(location.hash()!) }
		'assign', 'replace', 'reload' { dom.js_string('[host function ${name}]') }
		else { dom.js_undefined() }
	}
}

// 7.10.5.1 [[GetPrototypeOf]]. The caller origin is explicit in the V model
// because there is no ambient JavaScript current realm.
pub fn (location &LocationModel) internal_get_prototype_of(caller_origin dom.Origin) dom.JSValue {
	if location.is_same_origin_with(caller_origin) {
		return location.prototype_
	}
	return dom.js_null()
}

// 7.10.5.2 [[SetPrototypeOf]].
pub fn (mut location LocationModel) internal_set_prototype_of(prototype dom.JSValue) bool {
	return js_values_are_same(location.prototype_, prototype)
}

// 7.10.5.3 [[IsExtensible]].
pub fn (location &LocationModel) internal_is_extensible() bool {
	return true
}

// 7.10.5.4 [[PreventExtensions]].
pub fn (mut location LocationModel) internal_prevent_extensions() bool {
	return false
}

// 7.10.5.5 [[GetOwnProperty]].
pub fn (location &LocationModel) internal_get_own_property(caller_origin dom.Origin, key string) !WindowProxyPropertyResult {
	if location.is_same_origin_with(caller_origin) {
		if value := location.properties_[key] {
			return WindowProxyPropertyResult{
				found: true
				descriptor: WindowProxyProperty{
					value: value
					writable: true
					enumerable: true
					configurable: true
				}
			}
		}
		if key in location_default_property_names && key !in location.deleted_default_properties_ {
			return WindowProxyPropertyResult{
				found: true
				descriptor: WindowProxyProperty{
					value: location.default_property_value(key)!
					writable: key in ['href', 'protocol', 'host', 'hostname', 'port', 'pathname',
						'search', 'hash']
					enumerable: true
					configurable: true
				}
			}
		}
		return WindowProxyPropertyResult{}
	}
	if key == 'href' || key == 'replace' {
		return WindowProxyPropertyResult{
			found: true
			descriptor: WindowProxyProperty{
				value: if key == 'replace' {
					dom.js_string('[host function replace]')} else {
					dom.js_undefined()}
				writable: key == 'href'
				configurable: true
			}
		}
	}
	fallback := cross_origin_property_fallback(key)!
	return WindowProxyPropertyResult{
		found: true
		descriptor: fallback
	}
}

// 7.10.5.6 [[DefineOwnProperty]].
pub fn (mut location LocationModel) internal_define_own_property(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	if !location.is_same_origin_with(caller_origin) {
		return error("SecurityError: cannot define property '${key}' on cross-origin Location")
	}
	location.properties_[key] = value
	location.deleted_default_properties_.delete(key)
	return true
}

// 7.10.5.7 [[Get]].
pub fn (location &LocationModel) internal_get(caller_origin dom.Origin, key string) !dom.JSValue {
	descriptor := location.internal_get_own_property(caller_origin, key)!
	if !descriptor.found {
		return dom.js_undefined()
	}
	return descriptor.descriptor.value
}

// 7.10.5.8 [[Set]].
pub fn (mut location LocationModel) internal_set(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	if location.is_same_origin_with(caller_origin) {
		if key == 'href' && value.kind == .string {
			location.set_href(value.string_data)!
			return true
		}
		location.properties_[key] = value
		location.deleted_default_properties_.delete(key)
		return true
	}
	if key == 'href' && value.kind == .string {
		location.set_href(value.string_data)!
		return true
	}
	return error("SecurityError: cannot set property '${key}' on cross-origin Location")
}

// 7.10.5.9 [[Delete]].
pub fn (mut location LocationModel) internal_delete(caller_origin dom.Origin, key string) !bool {
	if !location.is_same_origin_with(caller_origin) {
		return error("SecurityError: cannot delete property '${key}' on cross-origin Location")
	}
	location.properties_.delete(key)
	if key in location_default_property_names {
		location.deleted_default_properties_[key] = true
	}
	return true
}

// 7.10.5.10 [[OwnPropertyKeys]].
pub fn (location &LocationModel) internal_own_property_keys(caller_origin dom.Origin) []string {
	if !location.is_same_origin_with(caller_origin) {
		return ['href', 'replace']
	}
	mut keys := location.properties_.keys()
	for key in location_default_property_names {
		if key !in location.deleted_default_properties_ && key !in keys {
			keys << key
		}
	}
	return keys
}

pub fn LocationModel.create(document ?&dom.Document, entry_origin dom.Origin) &LocationModel {
	return &LocationModel{
		Location: dom.Location{}
		document_: document
		entry_origin_: entry_origin
	}
}

pub fn (mut location LocationModel) set_relevant_document(document ?&dom.Document) {
	location.document_ = document
}

pub fn (mut location LocationModel) set_entry_origin(origin dom.Origin) {
	location.entry_origin_ = origin
}

pub fn (mut location LocationModel) set_navigate_hook(hook ?LocationNavigateHook) {
	location.navigate_hook_ = hook
}

pub fn (mut location LocationModel) set_reload_hook(hook ?LocationReloadHook) {
	location.reload_hook_ = hook
}

pub fn (location &LocationModel) relevant_document() ?&dom.Document {
	return location.document_
}

pub fn (location &LocationModel) url() dom.URL {
	document := location.document_ or { return dom.url_about_blank() }
	return document.url
}

fn (location &LocationModel) require_same_origin() ! {
	document := location.document_ or { return }
	if !document.origin().is_same_origin(location.entry_origin_) {
		return error("SecurityError: Location's relevant document is not same origin with the entry settings object's origin")
	}
}

fn (mut location LocationModel) navigate(url dom.URL, behavior HistoryHandlingBehavior) ! {
	if location.document_ == none {
		return
	}
	location.navigations_ << LocationNavigation{
		url: url
		history_behavior: behavior
	}
	if hook := location.navigate_hook_ {
		hook(url, behavior)!
		return
	}
	mut document := location.document_ or { return }
	document.set_url(url)
}

pub fn (location &LocationModel) href() !string {
	location.require_same_origin()!
	return location.url().serialize()
}

pub fn (mut location LocationModel) set_href(value string) ! {
	document := location.document_ or { return }
	url := document.encoding_parse_url(value) or {
		return error("SyntaxError: Invalid URL '${value}'")
	}
	location.navigate(url, .push)!
}

pub fn (location &LocationModel) origin() !string {
	location.require_same_origin()!
	return location.url().origin().serialize()
}

pub fn (location &LocationModel) protocol() !string {
	location.require_same_origin()!
	return '${location.url().scheme()}:'
}

pub fn (mut location LocationModel) set_protocol(value string) ! {
	if location.document_ == none {
		return
	}
	location.require_same_origin()!
	working_copy := location.url().with_protocol(value)
	if working_copy.scheme() !in ['http', 'https'] {
		return
	}
	location.navigate(working_copy, .push)!
}

pub fn (location &LocationModel) host() !string {
	location.require_same_origin()!
	url := location.url()
	host := url.host() or { return '' }
	port := url.port() or { return host }
	return '${host}:${port}'
}

pub fn (mut location LocationModel) set_host(value string) ! {
	if location.document_ == none {
		return
	}
	location.require_same_origin()!
	url := location.url()
	if url.has_an_opaque_path() {
		return
	}
	location.navigate(url.with_host(value), .push)!
}

pub fn (location &LocationModel) hostname() !string {
	location.require_same_origin()!
	return location.url().serialized_host()
}

pub fn (mut location LocationModel) set_hostname(value string) ! {
	if location.document_ == none {
		return
	}
	location.require_same_origin()!
	url := location.url()
	if url.has_an_opaque_path() {
		return
	}
	location.navigate(url.with_hostname(value), .push)!
}

pub fn (location &LocationModel) port() !string {
	location.require_same_origin()!
	port := location.url().port() or { return '' }
	return port.str()
}

pub fn (mut location LocationModel) set_port(value string) ! {
	if location.document_ == none {
		return
	}
	location.require_same_origin()!
	url := location.url()
	if url.cannot_have_a_username_or_password_or_port() {
		return
	}
	if value != '' {
		for character in value {
			if character < `0` || character > `9` {
				return
			}
		}
		port := value.u32()
		if port > 65535 {
			return
		}
	}
	location.navigate(url.with_port(value), .push)!
}

pub fn (location &LocationModel) pathname() !string {
	location.require_same_origin()!
	return location.url().serialize_path()
}

pub fn (mut location LocationModel) set_pathname(value string) ! {
	if location.document_ == none {
		return
	}
	location.require_same_origin()!
	url := location.url()
	if url.has_an_opaque_path() {
		return
	}
	pathname := if value == '' || value.starts_with('/') { value } else { '/${value}' }
	location.navigate(url.with_pathname(pathname), .push)!
}

pub fn (location &LocationModel) search() !string {
	location.require_same_origin()!
	query := location.url().query() or { return '' }
	return if query == '' { '' } else { '?${query}' }
}

pub fn (mut location LocationModel) set_search(value string) ! {
	if location.document_ == none {
		return
	}
	location.require_same_origin()!
	query := if value == '' {
		?string(none)
	} else if value.starts_with('?') {
		?string(value[1..])
	} else {
		?string(value)
	}
	location.navigate(location.url().with_query(query), .push)!
}

pub fn (location &LocationModel) hash() !string {
	location.require_same_origin()!
	fragment := location.url().fragment() or { return '' }
	return if fragment == '' { '' } else { '#${fragment}' }
}

pub fn (mut location LocationModel) set_hash(value string) ! {
	if location.document_ == none {
		return
	}
	location.require_same_origin()!
	mut working_copy := location.url()
	old_fragment := working_copy.fragment() or { '' }
	input := if value.starts_with('#') { value[1..] } else { value }
	working_copy.set_fragment(input)
	if input == old_fragment {
		return
	}
	location.navigate(working_copy, .push)!
}

pub fn (mut location LocationModel) reload() {
	if location.document_ == none {
		return
	}
	location.reload_count_++
	if hook := location.reload_hook_ {
		hook()
	}
}

pub fn (mut location LocationModel) replace(value string) ! {
	document := location.document_ or { return }
	url := document.encoding_parse_url(value) or {
		return error("SyntaxError: Invalid URL '${value}'")
	}
	location.navigate(url, .replace)!
}

pub fn (mut location LocationModel) assign(value string) ! {
	document := location.document_ or { return }
	location.require_same_origin()!
	url := document.encoding_parse_url(value) or {
		return error("SyntaxError: Invalid URL '${value}'")
	}
	location.navigate(url, .push)!
}

pub fn (location &LocationModel) navigations() []LocationNavigation {
	return location.navigations_.clone()
}

pub fn (location &LocationModel) reload_count() u32 {
	return location.reload_count_
}

@[heap]
pub struct BrowsingContextModel {
mut:
	page_                      ?&dom.Page
	// Retain the same actual native identity independently of the active
	// Document slot. Source BC-owned metadata lives on this native owner.
	native_browsing_context_    ?&dom.BrowsingContext
	document_                  ?&dom.Document
	window_proxy_              ?&WindowProxyModel
	group_                     ?&BrowsingContextGroup
	parent_                    ?&BrowsingContextModel
	opener_browsing_context_   ?&BrowsingContextModel
	children_                  []&BrowsingContextModel
	target_name_               string
	is_auxiliary_              bool
	is_popup_                  bool
	popup_sandboxing_flag_set_ SandboxingFlagSet
	discarded_                 bool
	fully_active_override_     bool = true
	top_level_traversable_     ?&TraversableNavigable
	container_                 ?&dom.Element
}

pub struct BrowsingContextAndDocument {
pub:
	browsing_context &BrowsingContextModel
	document         &dom.Document
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#determining-the-origin
pub fn determine_the_origin(url ?dom.URL, sandbox_flags SandboxingFlagSet, source_origin ?dom.Origin) dom.Origin {
	if sandbox_flags.contains(.sandboxed_origin) {
		return dom.origin_create_opaque()
	}
	url_value := url or { return dom.origin_create_opaque() }
	if url_matches_about_srcdoc(url_value) {
		return source_origin or {
			panic('source origin must be present when determining the origin of about:srcdoc')
		}
	}
	if url_matches_about_blank(url_value) {
		if inherited_origin := source_origin {
			return inherited_origin
		}
	}
	return url_value.origin()
}

// https://html.spec.whatwg.org/multipage/browsers.html#determining-the-creation-sandboxing-flags
pub fn determine_the_creation_sandboxing_flags(context &BrowsingContextModel, embedder ?&dom.Element) SandboxingFlagSet {
	if element := embedder {
		mut flags := SandboxingFlagSet{}
		if element.local_name() == 'iframe' && (element.namespace_uri() or { '' }) == namespace_html {
			iframe := unsafe { &dom.HTMLIFrameElement(element) }
			flags = flags.union(html_iframe_element_model_for_dom_element(iframe).iframe_sandboxing_flag_set())
		}
		document_flags := element.document().active_sandboxing_flag_set()
		if document_flags.sandboxed_document_domain {
			flags = flags.union(SandboxingFlagSet{ bits: u32(SandboxingFlag.sandboxed_document_domain) })
		}
		if document_flags.sandboxed_forms {
			flags = flags.union(SandboxingFlagSet{ bits: u32(SandboxingFlag.sandboxed_forms) })
		}
		return flags
	}
	return context.popup_sandboxing_flag_set()
}

pub fn BrowsingContextModel.create(document ?&dom.Document, parent ?&BrowsingContextModel, target_name string) &BrowsingContextModel {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut context := &BrowsingContextModel{
		document_:    document
		parent_:      parent
		target_name_: target_name
	}
	if active := document {
		if active.has_page() { context.page_ = active.page() }
	} else if ancestor := parent {
		context.page_ = ancestor.page()
	}
	if mut parent_context := parent {
		parent_context.children_ << context
	}
	return context
}

// BrowsingContext.cpp constructor m_page precedes the initial Window/Document.
pub fn BrowsingContextModel.create_for_page(page &dom.Page, parent ?&BrowsingContextModel, target_name string) &BrowsingContextModel {
	mut context := BrowsingContextModel.create(none, parent, target_name)
	context.page_ = page
	return context
}

pub fn BrowsingContextModel.create_a_new_browsing_context_and_document(page &dom.Page, creator ?&dom.Document, embedder ?&dom.Element) !BrowsingContextAndDocument {
	context := BrowsingContextModel.create_for_page(page, none, '')

	// 2. Let unsafeContextCreationTime be the unsafe shared current time.
	unsafe_context_creation_time := highresolutiontime.unsafe_shared_current_time()

	// Steps 3–5 snapshot the supplied creator's origin and document base URL.
	mut creator_origin := ?dom.Origin(none)
	mut creator_base_url := ?dom.URL(none)
	if creator_document := creator {
		creator_origin = creator_document.origin()
		creator_base_url = creator_document.base_url()
	}
	mut mutable_context := unsafe { &BrowsingContextModel(context) }
	mutable_context.set_container(embedder)
	sandbox_flags := determine_the_creation_sandboxing_flags(context, embedder)
	origin := determine_the_origin(dom.url_about_blank(), sandbox_flags, creator_origin)
	// Source steps 10–15 construct the Window realm and settings first. The
	// actual Document constructor then allocates fonts in that owning realm.
	mut document := create_initial_document(context, origin, embedder)!
	document.set_document_type(.html)
	document.set_content_type('text/html')
	document.set_quirks_mode(.yes)
	document.set_active_sandboxing_flag_bits(sandbox_flags.bits)

	// 14. Let loadTimingInfo be a new document load timing info with its navigation start time set to the result of
	//     calling coarsen time with unsafeContextCreationTime and the new environment settings object's cross-origin
	//     isolated capability.
	// NB: A window settings object's cross-origin isolated capability is always "No" for now.
	document.set_load_timing_info(dom.DocumentLoadTimingInfo{
		navigation_start_time: highresolutiontime.coarsen_time(unsafe_context_creation_time, false)
	})
	document.set_is_initial_about_blank(true)
	document.set_about_base_url(creator_base_url)
	document.set_allow_declarative_shadow_roots(true)
	if creator_document := creator {
		document.set_referrer(creator_document.url_string())
	}
	// BrowsingContext.cpp steps 21–24 complete the initial about:blank.
	document.set_ready_for_post_load_tasks(true)
	document.populate_with_html_head_and_body()!
	if embedder == none {
		document.set_supported_color_schemes(['light', 'dark'], false)
	}
	document.make_active()
	document.completely_finish_loading()
	mutable_context.set_active_document(document)
	return BrowsingContextAndDocument{
		browsing_context: context
		document: document
	}
}

pub fn BrowsingContextModel.create_a_new_auxiliary_browsing_context_and_document(page &dom.Page, opener &BrowsingContextModel) !BrowsingContextAndDocument {
	opener_document := opener.active_document() or {
		return error('InvalidStateError: opener has no active Document')
	}
	opener_navigable := opener_document.navigable() or {
		return error('InvalidStateError: opener active Document has no node navigable')
	}
	top_level_traversable := opener_navigable.top_level_traversable()
	if !top_level_traversable.is_top_level_traversable() {
		return error('InvalidStateError: opener logical top-level navigable is not a traversable')
	}
	top_native := top_level_traversable.active_browsing_context() or {
		return error('InvalidStateError: opener has no active top-level browsing context')
	}
	top := browsing_context_model_for_native(top_native)
	group := top.group_ or {
		return error('InvalidStateError: opener top-level browsing context has no group')
	}
	result := BrowsingContextModel.create_a_new_browsing_context_and_document(page, opener_document, none)!
	mut context := result.browsing_context
	context.is_auxiliary_ = true
	mut native := result.document.get_browsing_context() or {
		panic('Source auxiliary Document requires its actual BrowsingContext')
	}
	mut mutable_group := unsafe { &BrowsingContextGroup(group) }
	mutable_group.append(native)
	context.set_opener(opener)
	native.virtual_browsing_context_group_id_ = top_native.virtual_browsing_context_group_id_
	native.opener_origin_at_creation_ = opener_document.origin()
	context.top_level_traversable_ = top.top_level_traversable_
	return result
}

pub fn (context &BrowsingContextModel) active_document() ?&dom.Document {
	return context.document_
}

pub fn (context &BrowsingContextModel) active_window() ?&WindowModel {
	proxy := context.window_proxy() or { return none }
	return proxy.window()
}

pub fn (context &BrowsingContextModel) window_proxy() ?&WindowProxyModel {
	return context.window_proxy_
}

pub fn (mut context BrowsingContextModel) set_active_document(document ?&dom.Document) {
	context.document_ = document
	context.update_native_context_window_proxy()
}

pub fn (mut context BrowsingContextModel) set_active_window(window &WindowModel) {
	mut proxy := context.window_proxy() or { panic('Source active Window requires a WindowProxy') }
	proxy.set_window(window)
}

pub fn (mut context BrowsingContextModel) set_window_proxy(proxy ?&WindowProxyModel) {
	context.window_proxy_ = proxy
	context.update_native_context_window_proxy()
}

// This native record and the actual typed constructor represent the same
// Source BrowsingContext. Keep identity independent of its current Window.
fn (context &BrowsingContextModel) register_native_identity(native &dom.BrowsingContext) {
	mut mutable_native := unsafe { &dom.BrowsingContext(native) }
	if mutable_native.html_model_handle_ != unsafe { nil }
		&& mutable_native.html_model_handle_ != voidptr(context) {
		panic('Native BrowsingContext belongs to another actual HTML model identity')
	}
	if existing := context.native_browsing_context_ {
		if voidptr(existing) != voidptr(native) {
			panic('HTML BrowsingContext already owns another actual native identity')
		}
	}
	mut mutable_context := unsafe { &BrowsingContextModel(context) }
	mutable_context.native_browsing_context_ = native
	mutable_native.html_model_handle_ = voidptr(context)
	if group := context.group_ {
		mut mutable_group := unsafe { &BrowsingContextGroup(group) }
		mutable_group.append(native)
	}
}

fn browsing_context_model_for_native(native &dom.BrowsingContext) &BrowsingContextModel {
	if native.html_model_handle_ == unsafe { nil } {
		panic('Native BrowsingContext has no actual HTML model identity')
	}
	return unsafe { &BrowsingContextModel(native.html_model_handle_) }
}

// Document.cpp create_and_initialize and initial BC construction associate
// the Document with the supplied actual context. Missing per-Document slots
// reuse its retained owner; only the explicit first-construction adapter
// allocates the native representation of this already-created typed context.
fn (context &BrowsingContextModel) associate_native_identity_with_document(document &dom.Document) {
	mut mutable_document := unsafe { &dom.Document(document) }
	if document.get_browsing_context() == none {
		native := context.native_browsing_context_ or {
			&dom.BrowsingContext{
				active_document_: document
			}
		}
		mutable_document.set_browsing_context(native)
	}
	context.register_native_identity(document.get_browsing_context() or {
		panic('Source Window construction requires its native BrowsingContext')
	})
}

// The typed context and Document's native context describe the same source
// BrowsingContext. Keep its actual WindowProxy identity at this bridge.
fn (context &BrowsingContextModel) update_native_context_window_proxy() {
	document := context.active_document() or { return }
	mut native := document.get_browsing_context() or { return }
	context.register_native_identity(native)
	native.active_document_ = document
	if proxy := context.window_proxy() {
		native.window_proxy_ = proxy.dom_proxy()
	} else {
		native.window_proxy_ = none
	}
}

pub fn (context &BrowsingContextModel) group() ?&BrowsingContextGroup {
	return context.group_
}

pub fn (context &BrowsingContextModel) page() ?&dom.Page {
	if owner := context.page_ { return owner }
	if document := context.active_document() {
		if document.has_page() { return document.page() }
	}
	// Existing standalone context/group constructors predate explicit ownership.
	group := context.group_ or { return none }
	return group.page()
}

pub fn (context &BrowsingContextModel) virtual_browsing_context_group_id() u64 {
	native := context.native_browsing_context_ or { return 0 }
	return native.virtual_browsing_context_group_id_
}

pub fn (context &BrowsingContextModel) opener_origin_at_creation() ?dom.Origin {
	native := context.native_browsing_context_ or { return none }
	return native.opener_origin_at_creation_
}

pub fn (mut context BrowsingContextModel) set_group(group ?&BrowsingContextGroup) {
	context.group_ = group
}

pub fn (context &BrowsingContextModel) parent() ?&BrowsingContextModel {
	return context.parent_
}

pub fn (context &BrowsingContextModel) children() []&BrowsingContextModel {
	return context.children_.clone()
}

pub fn (context &BrowsingContextModel) target_name() string {
	return context.target_name_
}

pub fn (mut context BrowsingContextModel) set_target_name(value string) {
	context.target_name_ = value
}

pub fn (mut context BrowsingContextModel) set_opener(opener ?&BrowsingContextModel) {
	context.opener_browsing_context_ = opener
	context.is_auxiliary_ = opener != none
}

pub fn (context &BrowsingContextModel) opener_browsing_context() ?&BrowsingContextModel {
	return context.opener_browsing_context_
}

pub fn (mut context BrowsingContextModel) set_opener_browsing_context(opener ?&BrowsingContextModel) {
	context.set_opener(opener)
}

pub fn (context &BrowsingContextModel) opener() ?&BrowsingContextModel {
	return context.opener_browsing_context_
}

pub fn (mut context BrowsingContextModel) set_popup(value bool) {
	context.is_popup_ = value
}

pub fn (context &BrowsingContextModel) is_popup() bool {
	return context.is_popup_
}

pub fn (context &BrowsingContextModel) is_auxiliary() bool {
	return context.is_auxiliary_
}

pub fn (mut context BrowsingContextModel) set_is_popup(value bool) {
	context.set_popup(value)
}

pub fn (context &BrowsingContextModel) popup_sandboxing_flag_set() SandboxingFlagSet {
	return context.popup_sandboxing_flag_set_
}

pub fn (mut context BrowsingContextModel) set_popup_sandboxing_flag_set(value SandboxingFlagSet) {
	context.popup_sandboxing_flag_set_ = value
}

pub fn (context &BrowsingContextModel) is_top_level() bool {
	return context.parent_ == none
}

pub fn (context &BrowsingContextModel) top_level_browsing_context() ?&BrowsingContextModel {
	if !context.fully_active_override_ || context.discarded_ {
		return none
	}
	mut current := unsafe { context }
	for {
		parent := current.parent_ or { return current }
		current = parent
	}
	return none
}

pub fn (mut context BrowsingContextModel) set_top_level_traversable(traversable ?&TraversableNavigable) {
	context.top_level_traversable_ = traversable
}

pub fn (context &BrowsingContextModel) container() ?&dom.Element {
	return context.container_
}

pub fn (mut context BrowsingContextModel) set_container(container ?&dom.Element) {
	context.container_ = container
	document := context.document_ or { return }
	mut navigable := document.cached_navigable() or { return }
	if element := container {
		navigable.container_ = unsafe { &dom.Node(element) }
		navigable.container_document_ = element.document()
	} else {
		navigable.container_ = none
		navigable.container_document_ = none
	}
}

pub fn (context &BrowsingContextModel) top_level_traversable() ?&TraversableNavigable {
	mut current := unsafe { context }
	for {
		if traversable := current.top_level_traversable_ {
			return traversable
		}
		current = current.parent_ or { return none }
	}
	return none
}

pub fn (_ &BrowsingContextModel) the_one_permitted_sandboxed_navigator() ?&BrowsingContextModel {
	// Upstream intentionally leaves this origin-model hook unimplemented.
	return none
}

pub fn (_ &BrowsingContextModel) set_the_one_permitted_sandboxed_navigator(_ ?&BrowsingContextModel) {
	// The corresponding upstream hook is intentionally a FIXME/no-op.
}

pub fn (context &BrowsingContextModel) is_ancestor_of(descendant &BrowsingContextModel) bool {
	if !descendant.fully_active_override_ || descendant.discarded_ {
		return false
	}
	mut current := descendant.parent_
	for current != none {
		candidate := current or { break }
		if voidptr(candidate) == voidptr(context) {
			return true
		}
		current = candidate.parent_
	}
	return false
}

fn browsing_context_is_familiar(a &BrowsingContextModel, b &BrowsingContextModel, mut visited []voidptr) bool {
	for item in visited {
		if item == voidptr(b) {
			return false
		}
	}
	visited << voidptr(b)
	a_document := a.document_ or { return false }
	b_document := b.document_ or { return false }
	if a_document.origin().is_same_origin(b_document.origin()) {
		return true
	}
	if top := a.top_level_browsing_context() {
		if voidptr(top) == voidptr(b) {
			return true
		}
	}
	if opener := b.opener_browsing_context_ {
		if browsing_context_is_familiar(a, opener, mut visited) {
			return true
		}
	}
	mut ancestor := b.parent_
	for ancestor != none {
		candidate := ancestor or { break }
		if document := candidate.document_ {
			if document.origin().is_same_origin(a_document.origin()) {
				return true
			}
		}
		ancestor = candidate.parent_
	}
	return false
}

pub fn (context &BrowsingContextModel) is_familiar_with(other &BrowsingContextModel) bool {
	mut visited := []voidptr{}
	return browsing_context_is_familiar(context, other, mut visited)
}

pub fn (context &BrowsingContextModel) choose_a_browsing_context(name string) ?&BrowsingContextModel {
	lower_name := ascii_lowercase_string(name)
	if lower_name == '' || lower_name == '_self' {
		return context
	}
	if lower_name == '_parent' {
		return context.parent_ or { context }
	}
	if lower_name == '_top' {
		return context.top_level_browsing_context()
	}
	if lower_name == '_blank' {
		return none
	}
	group := context.group_ or { return none }
	for candidate in group.model_browsing_context_set() {
		if candidate.target_name_ == name && context.is_familiar_with(candidate) {
			return candidate
		}
	}
	return none
}

pub fn (mut context BrowsingContextModel) remove() {
	if mut group := context.group_ {
		group.remove_model(&context)
	}
	if mut parent := context.parent_ {
		parent.children_ = parent.children_.filter(voidptr(it) != voidptr(&context))
	}
	context.group_ = none
	context.parent_ = none
	context.window_proxy_ = none
	context.discarded_ = true
}

pub fn (mut context BrowsingContextModel) set_fully_active_override(value bool) {
	context.fully_active_override_ = value
}

pub fn (context &BrowsingContextModel) is_fully_active() bool {
	return context.fully_active_override_ && !context.discarded_ && context.document_ != none
}

pub fn (context &BrowsingContextModel) has_navigable_been_destroyed() bool {
	return context.discarded_ || context.document_ == none
}

pub fn (context &BrowsingContextModel) length() int {
	return context.children_.len
}

pub struct WindowProxyProperty {
pub:
	value        dom.JSValue
	writable     bool
	enumerable   bool
	configurable bool
}

pub struct WindowProxyPropertyResult {
pub:
	found      bool
	descriptor WindowProxyProperty
}

const window_cross_origin_property_names = [
	'window',
	'self',
	'location',
	'close',
	'closed',
	'focus',
	'blur',
	'frames',
	'length',
	'top',
	'opener',
	'parent',
	'postMessage',
]

fn window_property_array_index(key string) ?int {
	if key == '' {
		return none
	}
	for character in key {
		if character < `0` || character > `9` {
			return none
		}
	}
	if key.len > 1 && key[0] == `0` {
		return none
	}
	return key.int()
}

@[heap]
pub struct WindowProxyModel {
mut:
	dom_proxy_ &dom.WindowProxy = unsafe { nil }
}

pub fn WindowProxyModel.create(window &WindowModel) &WindowProxyModel {
	dom_proxy := &dom.WindowProxy{}
	dom_proxy.set_window(unsafe { &dom.Window(window) })
	return &WindowProxyModel{
		dom_proxy_: dom_proxy
	}
}

pub fn (proxy &WindowProxyModel) dom_proxy() &dom.WindowProxy {
	return proxy.dom_proxy_
}

// The native and typed records are the same Source WindowProxy identity.
// Resolve only actual registered proxy records, without casting a bare DOM
// proxy to a larger HTML object.
fn window_proxy_model_for_native(native &dom.WindowProxy) &WindowProxyModel {
	for window in all_windows() {
		proxy := window.window_proxy_
		if proxy != unsafe { nil } && voidptr(proxy.dom_proxy()) == voidptr(native) {
			return proxy
		}
	}
	panic('Native WindowProxy has no actual HTML model identity')
}

pub fn (proxy &WindowProxyModel) window() &WindowModel {
	native := proxy.dom_proxy_.window() or { panic('Source WindowProxy requires an associated Window') }
	for window in all_windows() {
		if voidptr(window) == voidptr(native) {
			return window
		}
	}
	panic('WindowProxy Window has no actual HTML model identity')
}

pub fn (proxy &WindowProxyModel) is_universal_global_scope_mixin() bool {
	_ = proxy
	return true
}

pub fn (proxy &WindowProxyModel) is_html_window_proxy() bool {
	_ = proxy
	return true
}

pub fn (mut proxy WindowProxyModel) set_window(window &WindowModel) {
	proxy.dom_proxy_.set_window(unsafe { &dom.Window(window) })
}

pub fn (proxy &WindowProxyModel) associated_browsing_context() &BrowsingContextModel {
	return proxy.window().browsing_context()
}

pub fn (proxy &WindowProxyModel) is_extensible() bool {
	return true
}

pub fn (proxy &WindowProxyModel) prevent_extensions() bool {
	return false
}

// 7.4.1 [[GetPrototypeOf]]. The caller origin is explicit in the V model.
pub fn (proxy &WindowProxyModel) internal_get_prototype_of(caller_origin dom.Origin) dom.JSValue {
	if proxy.window().same_origin(caller_origin) {
		return proxy.window().prototype()
	}
	return dom.js_null()
}

// 7.4.2 [[SetPrototypeOf]].
pub fn (mut proxy WindowProxyModel) internal_set_prototype_of(prototype dom.JSValue) bool {
	return js_values_are_same(proxy.window().prototype(), prototype)
}

// 7.4.3 [[IsExtensible]].
pub fn (proxy &WindowProxyModel) internal_is_extensible() bool {
	return true
}

// 7.4.4 [[PreventExtensions]].
pub fn (mut proxy WindowProxyModel) internal_prevent_extensions() bool {
	return false
}

pub fn (proxy &WindowProxyModel) get_own_property(caller_origin dom.Origin, key string) !WindowProxyPropertyResult {
	if index := window_property_array_index(key) {
		children := proxy.window().associated_document().document_tree_child_navigables()
		if index < children.len {
			mut value := dom.js_null()
			if native := children[index].active_window_proxy() {
				value = dom.js_object(voidptr(window_proxy_model_for_native(native)))
			}
			return WindowProxyPropertyResult{
				found: true
				descriptor: WindowProxyProperty{
					value: value
					enumerable: true
					configurable: true
				}
			}
		}
		if proxy.window().same_origin(caller_origin) {
			return WindowProxyPropertyResult{}
		}
		return error("SecurityError: cannot access indexed property '${key}' on cross-origin WindowProxy")
	}
	if proxy.window().same_origin(caller_origin) {
		value := proxy.window().named_property(key)
		if value.is_undefined() {
			return WindowProxyPropertyResult{}
		}
		return WindowProxyPropertyResult{
			found: true
			descriptor: WindowProxyProperty{
				value: value
				writable: true
				enumerable: true
				configurable: true
			}
		}
	}
	if key in window_cross_origin_property_names {
		return WindowProxyPropertyResult{
			found: true
			descriptor: WindowProxyProperty{
				value: proxy.window().named_property(key)
				configurable: true
			}
		}
	}
	if child := proxy.window().named_child(key) {
		child_proxy := child.window_proxy() or { return WindowProxyPropertyResult{} }
		return WindowProxyPropertyResult{
			found: true
			descriptor: WindowProxyProperty{
				value: dom.js_object(voidptr(child_proxy))
				configurable: true
			}
		}
	}
	return error("SecurityError: cannot access property '${key}' on cross-origin WindowProxy")
}

pub fn (proxy &WindowProxyModel) define_own_property(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	if !proxy.window().same_origin(caller_origin) {
		return error("SecurityError: cannot define property '${key}' on cross-origin WindowProxy")
	}
	if _ := window_property_array_index(key) {
		return false
	}
	mut window := unsafe { &WindowModel(proxy.window()) }
	window.set_named_property(key, value)
	return true
}

pub fn (proxy &WindowProxyModel) set(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	if proxy.window().same_origin(caller_origin) {
		if _ := window_property_array_index(key) {
			return false
		}
		mut window := unsafe { &WindowModel(proxy.window()) }
		window.set_named_property(key, value)
		return true
	}
	if key == 'location' && value.kind == .string {
		mut location := unsafe { &LocationModel(proxy.window().location()) }
		location.set_href(value.string_data)!
		return true
	}
	return error("SecurityError: cannot set property '${key}' on cross-origin WindowProxy")
}

pub fn (proxy &WindowProxyModel) delete(caller_origin dom.Origin, key string) !bool {
	if !proxy.window().same_origin(caller_origin) {
		return error("SecurityError: cannot delete property '${key}' on cross-origin WindowProxy")
	}
	if index := window_property_array_index(key) {
		return index >= proxy.window().length()
	}
	mut window := unsafe { &WindowModel(proxy.window()) }
	return window.delete_named_property(key)
}

pub fn (proxy &WindowProxyModel) own_property_keys(caller_origin dom.Origin) []string {
	mut keys := []string{cap: proxy.window().length() + 16}
	for index in 0 .. proxy.window().length() {
		keys << index.str()
	}
	if proxy.window().same_origin(caller_origin) {
		keys << proxy.window().supported_property_names()
		keys << proxy.window().ordinary_property_names()
	} else {
		keys << window_cross_origin_property_names
	}
	return deduplicated_strings(keys)
}

// 7.4.5 [[GetOwnProperty]].
pub fn (proxy &WindowProxyModel) internal_get_own_property(caller_origin dom.Origin, key string) !WindowProxyPropertyResult {
	return proxy.get_own_property(caller_origin, key)
}

// 7.4.6 [[DefineOwnProperty]].
pub fn (proxy &WindowProxyModel) internal_define_own_property(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	return proxy.define_own_property(caller_origin, key, value)
}

// 7.4.7 [[Get]].
pub fn (proxy &WindowProxyModel) internal_get(caller_origin dom.Origin, key string) !dom.JSValue {
	result := proxy.get_own_property(caller_origin, key)!
	if !result.found {
		return dom.js_undefined()
	}
	return result.descriptor.value
}

// 7.4.8 [[Set]].
pub fn (proxy &WindowProxyModel) internal_set(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	return proxy.set(caller_origin, key, value)
}

// 7.4.9 [[Delete]].
pub fn (proxy &WindowProxyModel) internal_delete(caller_origin dom.Origin, key string) !bool {
	return proxy.delete(caller_origin, key)
}

// 7.4.10 [[OwnPropertyKeys]].
pub fn (proxy &WindowProxyModel) internal_own_property_keys(caller_origin dom.Origin) []string {
	return proxy.own_property_keys(caller_origin)
}

fn deduplicated_strings(values []string) []string {
	mut output := []string{}
	for value in values {
		if value !in output {
			output << value
		}
	}
	return output
}

pub struct WindowPostMessageOptions {
pub:
	target_origin string = '/'
	transfer      []&MessagePort
	source        ?&dom.WindowProxy
}

pub struct PostedWindowMessage {
pub:
	data          dom.JSValue
	origin        string
	target_origin string
}

@[heap]
pub struct WindowModel {
	dom.Window
mut:
	browsing_context_                         &BrowsingContextModel = unsafe { nil }
	window_proxy_                             &WindowProxyModel = unsafe { nil }
	location_                                 &LocationModel = unsafe { nil }
	history_                                  &History = unsafe { nil }
	navigation_                               &Navigation = unsafe { nil }
	navigator_                                &Navigator = unsafe { nil }
	animation_driver_                         &AnimationFrameCallbackDriver = unsafe { nil }
	close_watcher_manager_model_              &CloseWatcherManager = unsafe { nil }
	global_scope_                             &WindowOrWorkerGlobalScopeMixin = unsafe { nil }
	screen_                                   ?&css.Screen
	speech_synthesis_                         ?&speech.SpeechSynthesis
	external_                                 ?&External
	local_storage_                            ?&Storage
	session_storage_                          ?&Storage
	local_storage_bottle_                     ?&StorageBottle
	session_storage_bottle_                   ?&StorageBottle
	storage_hub_                              ?&StorageHub
	cookie_store_                             voidptr = unsafe { nil }
	cookie_store_created_                     bool
	idle_request_callbacks_                   map[u32]&WindowIdleCallback
	idle_request_callback_order_              []u32
	runnable_idle_callbacks_                  map[u32]&WindowIdleCallback
	runnable_idle_callback_order_             []u32
	idle_callback_identifier_                 u32
	pdf_viewer_plugin_objects_                []&Plugin
	pdf_viewer_mime_type_objects_             []&MimeType
	host_configuration_                       WindowHostConfiguration
	interfaces_initialized_                   bool
	resolved_module_set_                      []SpecifierResolution
	window_x_                                 int
	window_y_                                 int
	outer_width_                              int = 800
	outer_height_                             int = 600
	device_pixel_ratio_                       f64 = 1.0
	name_                                     string
	status_                                   string
	opener_disowned_                          bool
	prototype_                                dom.JSValue = dom.JSValue{ kind: .null_ }
	named_properties_                         map[string]dom.JSValue
	named_collections_                        []&WindowNamedCollection
	posted_messages_                          []PostedWindowMessage
	stop_count_                               u32
	focus_count_                              u32
	scripting_realm_                          &ScriptingRealm = unsafe { nil }
	environment_settings_                    &WindowEnvironmentSettingsObject = unsafe { nil }
}

pub fn (window &WindowModel) prototype() dom.JSValue {
	return window.prototype_
}

fn document_entry_associated_document(fallback &dom.Document) &dom.Document {
	if html_scripting_execution_context_stack.len == 0 {
		return fallback
	}
	return entry_settings_object().responsible_document() or { fallback }
}

fn document_update_url_and_history(document &dom.Document, url dom.URL) ! {
	perform_url_and_history_update_steps(document, url, none, .replace)!
}

fn document_open_window(target voidptr, url string, name string, features string) ?&dom.WindowProxy {
	mut window := unsafe { &WindowModel(target) }
	result := window.window_open_steps(url, name, features) or { return none }
	proxy := result.window_proxy or { return none }
	return proxy.dom_proxy()
}

fn document_declarative_refresh_navigate(_ voidptr, document &dom.Document, url dom.URL) {
	host := document.navigable() or { return }
	mut navigable := navigable_model_for_host(host) or { return }
	if navigable.has_been_destroyed() {
		return
	}
	navigable.navigate(NavigableNavigateParams{
		url: url
		source_document: document
		history_handling: .replace
	}) or {}
}

fn document_initial_about_blank_opened(target voidptr) {
	window := unsafe { &WindowModel(target) }
	mut navigation := unsafe { &Navigation(window.navigation()) }
	navigation.set_was_initial_about_blank_opened(true)
}

fn document_open_stop_loading(target voidptr) {
	window := unsafe { &WindowModel(target) }
	mut navigable := unsafe { &NavigableModel(window.navigable_model()) }
	navigable.clear_pending_navigations()
	if navigable.ongoing_navigation().kind == .navigation {
		navigable.stop_loading()
	}
}

fn document_begin_temporary_execution_context(target voidptr) voidptr {
	mut window := unsafe { &WindowModel(target) }
	if window.scripting_realm_ == unsafe { nil } {
		window.scripting_realm_ = &ScriptingRealm{}
	}
	mut realm := window.scripting_realm_
	return voidptr(TemporaryExecutionContext.create(mut realm, .no))
}

fn document_end_temporary_execution_context(_ voidptr, context_handle voidptr) {
	mut context := unsafe { &TemporaryExecutionContext(context_handle) }
	context.close()
}

fn document_register_with_event_loop(_ voidptr, document &dom.Document) {
	mut event_loop := main_thread_event_loop()
	event_loop.register_document(document)
}

fn document_unregister_from_event_loop(_ voidptr, document &dom.Document) {
	mut event_loop := main_thread_event_loop()
	event_loop.unregister_document(document)
}

fn document_navigable_did_change(_ voidptr, _ &dom.Document) {
	mut event_loop := main_thread_event_loop()
	event_loop.document_navigable_did_change()
}

fn document_remove_tasks_from_event_loop(_ voidptr, document &dom.Document) {
	mut event_loop := main_thread_event_loop()
	mut queue := event_loop.task_queue()
	queue.remove_tasks_matching(fn [document] (task &Task) bool {
		task_document := task.document() or { return false }
		return voidptr(task_document) == voidptr(document)
	})
	mut index := 0
	for index < event_loop.microtask_queue.len {
		task := event_loop.microtask_queue[index]
		if target := task.document() {
			if voidptr(target) == voidptr(document) {
				task.cancel()
				event_loop.microtask_queue.delete(index)
				continue
			}
		}
		index++
	}
}

fn document_increment_event_loop_termination_nesting(_ voidptr, _ &dom.Document) {
	mut event_loop := main_thread_event_loop()
	event_loop.increment_termination_nesting_level()
}

fn document_decrement_event_loop_termination_nesting(_ voidptr, _ &dom.Document) {
	mut event_loop := main_thread_event_loop()
	event_loop.decrement_termination_nesting_level()
}

fn document_set_execution_ready(target voidptr, _ &dom.Document) {
	window := unsafe { &WindowModel(target) }
	if window.environment_settings_ == unsafe { nil } {
		return
	}
	mut settings := window.environment_settings_.settings
	settings.environment_.execution_ready = true
}

fn document_relevant_settings_object(target voidptr, _ &dom.Document) voidptr {
	window := unsafe { &WindowModel(target) }
	if window.environment_settings_ == unsafe { nil } {
		return unsafe { nil }
	}
	return voidptr(window.environment_settings_.settings)
}

fn document_settings_scripting_enabled(settings_pointer voidptr) bool {
	return is_scripting_enabled_for_settings(unsafe { &EnvironmentSettingsObject(settings_pointer) })
}

fn document_settings_has_cross_site_ancestor(settings_pointer voidptr) bool {
	return unsafe { &EnvironmentSettingsObject(settings_pointer) }.has_cross_site_ancestor()
}

fn document_structured_deserialize(target voidptr, record dom.DOMSerializationRecord) ?dom.JSValue {
	window := unsafe { &WindowModel(target) }
	return window.history().deserialize_state(SerializationRecord{
		// SessionHistoryEntry::classic_history_api_state is always a
		// StorageSerializationRecord, including across the DOM cycle boundary.
		type_: .storage
		data:  record.data.clone()
	}) or { return none }
}

fn document_queue_intersection_observer_task(_ voidptr, document &dom.Document) {
	queue_a_task(.intersection_observer, main_thread_event_loop(), document, fn [document] () {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.notify_intersection_observers()
	})
}

fn document_queue_selectionchange_event_task(_ voidptr, target &dom.Document, document &dom.Document) {
	queue_a_task(.user_interaction, main_thread_event_loop(), document, fn [target, document] () {
		mut mutable_target := unsafe { &dom.Document(target) }
		dom.fire_a_selectionchange_event(mut mutable_target, document)
	})
}

fn task_source_from_dom(source dom.TaskSource) TaskSource {
	return match source {
		.dom_manipulation { .dom_manipulation }
		.user_interaction { .user_interaction }
		.networking { .networking }
	}
}

fn document_queue_an_element_task(_ voidptr, element &dom.Element, source dom.TaskSource, steps fn ()) {
	queue_an_element_task(element, task_source_from_dom(source), steps)
}

fn document_run_unloading_cleanup_steps(target voidptr, document &dom.Document) {
	html_popover_close_watcher_managers.delete(u64(voidptr(document)))
	mut window := unsafe { &WindowModel(target) }
	mut mutable_document := unsafe { &dom.Document(document) }
	if window.global_scope_ != unsafe { nil } {
		if window.global_scope_.make_disappear_all_web_sockets() {
			mutable_document.make_unsalvageable('websocket')
		}
		if !mutable_document.salvageable {
			window.global_scope_.forcibly_close_all_event_sources()
			window.global_scope_.clear_map_of_active_timers()
		}
	}
	if window.environment_settings_ != unsafe { nil } {
		run_blob_url_unloading_cleanup_steps(document)
		mut store := fileapi.legacy_blob_url_store()
		store.run_unloading_cleanup_steps(window.environment_settings_.settings.environment().id)
	}
	mutable_document.fully_exit_fullscreen()
}

fn document_timer_visibility_state_changed(target voidptr, _ &dom.Document) {
	window := unsafe { &WindowModel(target) }
	if window.global_scope_ == unsafe { nil } {
		return
	}
	mut scope := window.global_scope_
	scope.document_visibility_state_changed()
}

fn document_timer_audio_play_state_changed(target voidptr, _ &dom.Document) {
	window := unsafe { &WindowModel(target) }
	if window.global_scope_ == unsafe { nil } {
		return
	}
	mut scope := window.global_scope_
	scope.document_audio_play_state_changed()
}

pub fn WindowModel.create(document &dom.Document, context &BrowsingContextModel) !&WindowModel {
	return WindowModel.create_with_global(document, context, none)
}

fn WindowModel.create_with_global(document &dom.Document, context &BrowsingContextModel, existing_global ?&WindowModel) !&WindowModel {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut document_with_html_hooks := unsafe { &dom.Document(document) }
	context.associate_native_identity_with_document(document)
	if document.cached_navigable() == none {
		mut node_navigable := &dom.Navigable{
			active_document_: document
			is_top_level_traversable_: context.is_top_level()
		}
		if parent_context := context.parent() {
			if parent_document := parent_context.active_document() {
				node_navigable.parent_ = parent_document.cached_navigable()
			}
		}
		if context.is_top_level() {
			node_navigable.traversable_navigable_ = node_navigable
		} else if parent := node_navigable.parent_ {
			node_navigable.traversable_navigable_ = parent.traversable_navigable()
		}
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.set_cached_navigable(node_navigable)
	}
	host_navigable := document.cached_navigable() or {
		return error('WindowModel.create failed to establish a navigable')
	}
	_ = NavigableModel.create(host_navigable, context)!
	mut history := History.create(document.url, dom.js_null())!
	history.set_associated_document(document)
	mut navigation := Navigation.create(document)
	history.set_navigation(navigation)
	close_watcher_manager := CloseWatcherManager.create()
	custom_element_registry := if document.custom_element_registry() == unsafe { nil } {
		CustomElementRegistry.create(document)
	} else {
		unsafe { &CustomElementRegistry(document.custom_element_registry()) }
	}
	mut document_with_registry := unsafe { &dom.Document(document) }
	document_with_registry.set_custom_element_registry(voidptr(custom_element_registry))
	window_pointer := existing_global or {
		&WindowModel{
			animation_driver_: &AnimationFrameCallbackDriver{}
			global_scope_: WindowOrWorkerGlobalScopeMixin.create(document.origin(), false, false)
			scripting_realm_: &ScriptingRealm{}
			device_pixel_ratio_: html_display_device_pixel_ratio
		}
	}
	mut window := unsafe { &WindowModel(window_pointer) }
	window.set_associated_document(document)
	window.Window.close_watcher_manager_ = unsafe { &dom.CloseWatcherManager(close_watcher_manager) }
	window.browsing_context_ = context
	window.history_ = history
	window.navigation_ = navigation
	window.navigator_ = Navigator.create(NavigatorHostConfiguration{
		associated_document: document
	})
	window.close_watcher_manager_model_ = close_watcher_manager
	window.global_scope_.origin_ = document.origin()
	document_with_html_hooks.set_html_navigation_hook(dom.DocumentHTMLNavigationHook{
		target:                    voidptr(window)
		entry_associated_document: document_entry_associated_document
		update_url_and_history:    document_update_url_and_history
		open_window:               document_open_window
		declarative_refresh_navigate: document_declarative_refresh_navigate
		initial_about_blank_opened: document_initial_about_blank_opened
		open_stop_loading:          document_open_stop_loading
	})
	mut top_level_creation_url := document.url
	mut top_level_origin := document.origin()
	if parent_context := context.parent() {
		if parent_document := parent_context.active_document() {
			parent_settings_pointer := parent_document.relevant_settings_object()
			if parent_settings_pointer != unsafe { nil } {
				parent_settings := unsafe { &EnvironmentSettingsObject(parent_settings_pointer) }
				if inherited_url := parent_settings.fetch_request_client_top_level_creation_url() {
					top_level_creation_url = inherited_url
				}
				if inherited_origin := parent_settings.fetch_request_client_top_level_origin() {
					top_level_origin = inherited_origin
				}
			}
		}
	}
	if window.environment_settings_ == unsafe { nil } {
		mut window_realm := window.scripting_realm_
		_ = WindowEnvironmentSettingsObject.setup(window, document.url, mut window_realm, none,
			top_level_creation_url, top_level_origin)
	}
	install_view_transition_promise_context(document, window)
	mut timer_scope := window.global_scope_
	timer_scope.associated_window_ = window
	document_with_html_hooks.set_temporary_execution_context_hook(dom.DocumentTemporaryExecutionContextHook{
		target: voidptr(window)
		begin:  document_begin_temporary_execution_context
		end:    document_end_temporary_execution_context
	})
	document_with_html_hooks.set_lifecycle_hook(document_lifecycle_hook(window))
	document_with_html_hooks.set_base_csp_check(dom_base_csp_check)
	document_with_html_hooks.set_meta_csp_enforce(dom_meta_csp_enforce)
	document_with_html_hooks.set_meta_element_metadata_callback(html_meta_element_update_metadata)
	timer_scope.document_visibility_state_changed()
	proxy := context.window_proxy() or { WindowProxyModel.create(window) }
	mut mutable_proxy := unsafe { &WindowProxyModel(proxy) }
	mutable_proxy.set_window(window)
	location := LocationModel.create(document, document.origin())
	window.window_proxy_ = proxy
	window.location_ = location
	window.Window.location_ = unsafe { &dom.Location(location) }
	document_with_html_hooks.set_window(unsafe { &dom.Window(window) })
	mut mutable_context := unsafe { &BrowsingContextModel(context) }
	mutable_context.set_active_document(document)
	mutable_context.set_window_proxy(proxy)
	mutable_context.set_active_window(window)
	register_window_model(window)
	return window
}

pub fn WindowModel.create_top_level(document &dom.Document, group ?&BrowsingContextGroup, target_name string) !&WindowModel {
	context := BrowsingContextModel.create(document, none, target_name)
	if mut value := group {
		value.append_model(context)
	}
	return WindowModel.create(document, context)
}

pub fn (window &WindowModel) associated_document() &dom.Document {
	return window.Window.associated_document() or { panic('Window has no associated Document') }
}

pub fn (window &WindowModel) window_or_worker_global_scope() &WindowOrWorkerGlobalScopeMixin {
	return window.global_scope_
}

pub fn (window &WindowModel) this_impl() &dom.EventTarget {
	return unsafe { &dom.EventTarget(window) }
}

pub fn (window &WindowModel) extract_an_origin() ?dom.Origin {
	origin := window.associated_document().origin()
	return if origin.is_opaque() { none } else { origin }
}

pub fn (mut window WindowModel) append_resolved_module(resolution SpecifierResolution) {
	window.resolved_module_set_ << resolution
}

pub fn (window &WindowModel) resolved_module_set() []SpecifierResolution {
	return window.resolved_module_set_.clone()
}

pub fn (window &WindowModel) cross_origin_property_descriptor_map() []CrossOriginProperty {
	_ = window
	return cross_origin_properties(.window)
}

pub fn (window &WindowModel) is_universal_global_scope_mixin() bool {
	_ = window
	return true
}

pub fn (window &WindowModel) is_html_window() bool {
	_ = window
	return true
}

pub fn (window &WindowModel) global_event_handlers_to_event_target(_ string) &dom.EventTarget {
	return unsafe { &dom.EventTarget(window) }
}

pub fn (window &WindowModel) window_event_handlers_to_event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(window) }
}

pub fn (window &WindowModel) browsing_context() &BrowsingContextModel {
	return window.browsing_context_
}

pub fn (window &WindowModel) window() &WindowProxyModel {
	return window.window_proxy_
}

pub fn (window &WindowModel) self() &WindowProxyModel {
	return window.window_proxy_
}

pub fn (window &WindowModel) frames() &WindowProxyModel {
	return window.window_proxy_
}

pub fn (window &WindowModel) location() &LocationModel {
	return window.location_
}

pub fn (window &WindowModel) history() &History {
	return window.history_
}

pub fn (window &WindowModel) navigation() &Navigation {
	return window.navigation_
}

pub fn (window &WindowModel) navigator() &Navigator {
	return window.navigator_
}

pub fn (window &WindowModel) custom_elements() &CustomElementRegistry {
	registry := window.associated_document().custom_element_registry()
	assert registry != voidptr(0)
	return unsafe { &CustomElementRegistry(registry) }
}

pub fn (window &WindowModel) close_watcher_manager() &CloseWatcherManager {
	return window.close_watcher_manager_model_
}

// https://html.spec.whatwg.org/multipage/interaction.html#history-action-activation
pub fn (window &WindowModel) has_history_action_activation() bool {
	return window.Window.has_history_action_activation()
}

pub fn (mut window WindowModel) set_last_activation_timestamp(timestamp dom.DOMHighResTimeStamp) {
	window.Window.set_last_activation_timestamp(timestamp)
}

pub fn (window &WindowModel) last_activation_timestamp() dom.DOMHighResTimeStamp {
	return window.Window.last_activation_timestamp
}

pub fn (mut window WindowModel) set_last_history_action_activation_timestamp(timestamp dom.DOMHighResTimeStamp) {
	window.Window.set_last_history_action_activation_timestamp(timestamp)
}

pub fn (window &WindowModel) last_history_action_activation_timestamp() dom.DOMHighResTimeStamp {
	return window.Window.last_history_action_activation_timestamp
}

// https://html.spec.whatwg.org/multipage/interaction.html#consume-history-action-user-activation
pub fn (mut window WindowModel) consume_history_action_user_activation() {
	window.Window.consume_history_action_user_activation()
}

pub fn (window &WindowModel) name() string {
	return window.name_
}

pub fn (mut window WindowModel) set_name(value string) {
	window.name_ = value
	window.browsing_context_.set_target_name(value)
}

pub fn (window &WindowModel) status() string {
	return window.status_
}

pub fn (mut window WindowModel) set_status(value string) {
	window.status_ = value
}

pub fn (window &WindowModel) same_origin(origin dom.Origin) bool {
	return window.associated_document().origin().is_same_origin(origin)
}

pub fn (mut window WindowModel) close() {
	if window.closed() {
		return
	}
	context := window.browsing_context_
	script_closable := context.is_auxiliary_ || window.history_.length() or { u64(2) } <= 1
	if !context.is_top_level() || !script_closable {
		return
	}
	mut navigable := window.Window.navigable() or { return }
	navigable.set_closing(true)
	mut mutable_context := unsafe { &BrowsingContextModel(context) }
	mutable_context.remove()
}

pub fn (window &WindowModel) closed() bool {
	return window.Window.closed()
}

pub fn (mut window WindowModel) stop() {
	window.stop_count_++
}

pub fn (window &WindowModel) stop_count() u32 {
	return window.stop_count_
}

pub fn (mut window WindowModel) focus() {
	if window.closed() {
		return
	}
	window.focus_count_++
}

pub fn (mut window WindowModel) blur() {
	// The HTML Standard deliberately specifies this as a no-op.
}

pub fn (window &WindowModel) focus_count() u32 {
	return window.focus_count_
}

pub fn (window &WindowModel) length() int {
	return int(window.Window.length())
}

pub fn (window &WindowModel) top() ?&WindowProxyModel {
	native := window.Window.top() or { return none }
	return window_proxy_model_for_native(native)
}

pub fn (window &WindowModel) parent() ?&WindowProxyModel {
	native := window.Window.parent() or { return none }
	return window_proxy_model_for_native(native)
}

pub fn (window &WindowModel) opener() ?&WindowProxyModel {
	if window.opener_disowned_ {
		return none
	}
	opener := window.browsing_context_.opener() or { return none }
	return opener.window_proxy()
}

pub fn (mut window WindowModel) disown_opener() {
	window.opener_disowned_ = true
	window.browsing_context_.set_opener(none)
}

pub fn (window &WindowModel) locationbar() &BarProp {
	top := window.browsing_context_.top_level_browsing_context() or { return BarProp.create(none) }
	return BarProp.create(top.is_popup())
}

pub fn (window &WindowModel) menubar() &BarProp {
	return window.locationbar()
}

pub fn (window &WindowModel) personalbar() &BarProp {
	return window.locationbar()
}

pub fn (window &WindowModel) scrollbars() &BarProp {
	return window.locationbar()
}

pub fn (window &WindowModel) statusbar() &BarProp {
	return window.locationbar()
}

pub fn (window &WindowModel) toolbar() &BarProp {
	return window.locationbar()
}

pub fn (mut window WindowModel) request_animation_frame(callback AnimationFrameCallback) u32 {
	handle := window.animation_driver_.add(callback)
	window.associated_document().request_frame()
	return handle
}

pub fn (mut window WindowModel) cancel_animation_frame(handle u32) {
	window.animation_driver_.remove(handle)
}

pub fn (mut window WindowModel) run_animation_frame_callbacks(now f64) {
	window.animation_driver_.run(now)
}

pub fn (window &WindowModel) has_animation_frame_callbacks() bool {
	return window.animation_driver_.has_callbacks()
}

pub fn (window &WindowModel) has_pending_animation_frame_callback(handle u32) bool {
	return window.animation_driver_.has_pending_callback(handle)
}

pub fn (mut window WindowModel) window_post_message_steps(message dom.JSValue, source_origin dom.Origin, options WindowPostMessageOptions) ! {
	// The serialized record and task capture outlive the current script work.
	// Put them in the recipient's retained payload even inside a scratch scope.
	mut storage := window.associated_document().native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	parsed_target := window_post_message_target_origin(source_origin, options.target_origin)!
	target_origin := parsed_target.origin
	mut transfer := []StructuredTransfer{cap: options.transfer.len}
	for port in options.transfer {
		transfer << StructuredTransfer(MessagePortTransfer{
			value: port
		})
	}
	record := structured_serialize_with_transfer(message, transfer)!
	mut target := &window
	// Snapshot the sender and serialize now; check the recipient's origin only
	// when its posted-message task runs, after any intervening navigation.
	source := options.source
	queue_global_task(.posted_message, &window.Window, fn [mut target, target_origin, source_origin, source, record] () {
		target.deliver_posted_window_message(record, target_origin, source_origin, source)
	})
}

// Window::prepare_post_message parses targetOrigin without a base URL. Keeping
// an Origin record also distinguishes unrelated opaque origins from "null".
pub struct WindowPostMessageTargetOrigin {
pub:
	origin ?dom.Origin
}

pub fn window_post_message_target_origin(source_origin dom.Origin, target_origin string) !WindowPostMessageTargetOrigin {
	if target_origin == '*' { return WindowPostMessageTargetOrigin{} }
	if target_origin == '/' { return WindowPostMessageTargetOrigin{origin: source_origin} }
	url := dom.URL{ value: target_origin }
	_ = url.parsed() or { return error("SyntaxError: Invalid target origin '${target_origin}'") }
	return WindowPostMessageTargetOrigin{origin: url.origin()}
}

fn (mut window WindowModel) deliver_posted_window_message(record SerializedTransferRecord, target_origin ?dom.Origin, source_origin dom.Origin, source ?&dom.WindowProxy) {
	mut storage := window.associated_document().native_storage()
	mut allocation_scope := platform.RetainedArenaScope{}
	if storage != unsafe { nil } { allocation_scope = storage.enter_nested() }
	defer { allocation_scope.finish() }
	if origin := target_origin {
		if !origin.is_same_origin(window.associated_document().origin()) { return }
	}
	event_source := if proxy := source { ?MessageEventSource(WindowMessageEventSource{value: proxy}) } else { none }
	deserialized := structured_deserialize_with_transfer(record) or {
		mut event := MessageEvent.create('messageerror', MessageEventInit{origin: source_origin, source: event_source})
		event.set_is_trusted(true)
		dom.EventDispatcher.dispatch(unsafe { &dom.EventTarget(window) }, unsafe { &dom.Event(event) }, false)
		return
	}
	data := deserialized.deserialized
	window.posted_messages_ << PostedWindowMessage{
		data: data
		origin: source_origin.serialize()
		target_origin: if origin := target_origin { origin.serialize() } else { '*' }
	}
	mut event := MessageEvent.create('message', MessageEventInit{
		data: data
		origin: source_origin
		source: event_source
		ports: deserialized.transferred_ports
	})
	event.set_is_trusted(true)
	// Firing a message event targets the Window itself. The legacy Document
	// override belongs to Window's virtual dispatch path, not these fire steps.
	dom.EventDispatcher.dispatch(unsafe { &dom.EventTarget(window) }, unsafe { &dom.Event(event) }, false)
}

pub fn (mut window WindowModel) post_message(message dom.JSValue, source_origin dom.Origin, options WindowPostMessageOptions) ! {
	window.window_post_message_steps(message, source_origin, options)!
}

pub fn (window &WindowModel) posted_messages() []PostedWindowMessage {
	return window.posted_messages_.clone()
}

pub fn (mut window WindowModel) set_named_property(name string, value dom.JSValue) {
	window.named_properties_[name] = value
}

pub fn (mut window WindowModel) delete_named_property(name string) bool {
	if name !in window.named_properties_ {
		return true
	}
	window.named_properties_.delete(name)
	return true
}

pub fn (window &WindowModel) named_child(name string) ?&BrowsingContextModel {
	for child in window.browsing_context_.children() {
		if child.target_name() == name {
			return child
		}
	}
	return none
}

pub fn (window &WindowModel) named_property(name string) dom.JSValue {
	if value := window.named_properties_[name] {
		return value
	}
	if child := window.named_child(name) {
		if proxy := child.window_proxy() {
			return dom.js_object(voidptr(proxy))
		}
	}
	return match name {
		'window', 'self', 'frames' {
			dom.js_object(voidptr(window.window_proxy_))
		}
		'location' {
			dom.js_object(voidptr(window.location_))
		}
		'closed' {
			dom.js_bool(window.closed())
		}
		'length' {
			dom.js_number(window.length())
		}
		'top' {
			if proxy := window.top() {
				dom.js_object(voidptr(proxy))
			} else {
				dom.js_null()
			}
		}
		'parent' {
			if proxy := window.parent() {
				dom.js_object(voidptr(proxy))
			} else {
				dom.js_null()
			}
		}
		'opener' {
			if proxy := window.opener() {
				dom.js_object(voidptr(proxy))
			} else {
				dom.js_null()
			}
		}
		'close', 'focus', 'blur', 'postMessage' {
			dom.js_string('[host function ${name}]')
		}
		else {
			if window.is_supported_property_name(name) {
				window.named_item_value(name)
			} else {
				dom.js_undefined()
			}
		}
	}
}

pub fn (window &WindowModel) is_supported_property_name(name string) bool {
	document := window.associated_document()
	if document.element_by_id_map().contains(name) {
		return true
	}
	for element in document.potentially_named_elements() {
		if element.get_name() or { '' } == name {
			return true
		}
	}
	return name in window.document_tree_child_navigable_target_name_property_set()
}

pub fn (window &WindowModel) supported_property_names() []string {
	mut names := []string{}
	for name, _ in window.document_tree_child_navigable_target_name_property_set() {
		if name !in names {
			names << name
		}
	}
	for element in window.associated_document().potentially_named_elements() {
		if element_name := element.get_name() {
			if element_name != '' && element_name !in names {
				names << element_name
			}
		}
	}
	for id in window.associated_document().element_ids() {
		if id != '' && id !in names {
			names << id
		}
	}
	return names
}

fn (window &WindowModel) ordinary_property_names() []string {
	return window.named_properties_.keys()
}
