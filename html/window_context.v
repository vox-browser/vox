// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BrowsingContext.{h,cpp}, Location.{h,cpp},
// WindowProxy.{h,cpp}, and the browsing-context-facing algorithms in
// Window.{h,cpp}. VM object internal methods and browser chrome operations are
// represented by explicit properties and host hooks.
module html

import dom

pub struct LocationNavigation {
pub:
	url              dom.URL
	history_behavior HistoryHandlingBehavior
}

pub type LocationNavigateHook = fn (dom.URL, HistoryHandlingBehavior) !

pub type LocationReloadHook = fn ()

@[heap]
pub struct LocationModel {
mut:
	document_      ?&dom.Document
	entry_origin_  dom.Origin
	navigate_hook_ ?LocationNavigateHook
	reload_hook_   ?LocationReloadHook
	navigations_   []LocationNavigation
	reload_count_  u32
}

pub fn LocationModel.create(document ?&dom.Document, entry_origin dom.Origin) &LocationModel {
	return &LocationModel{
		document_:     document
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
		url:              url
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
	copy := location.url().with_protocol(value)
	if copy.scheme() !in ['http', 'https'] {
		return
	}
	location.navigate(copy, .push)!
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
	mut copy := location.url()
	old_fragment := copy.fragment() or { '' }
	input := if value.starts_with('#') { value[1..] } else { value }
	copy.set_fragment(input)
	if input == old_fragment {
		return
	}
	location.navigate(copy, .push)!
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
	document_                ?&dom.Document
	window_                  ?&WindowModel
	window_proxy_            ?&WindowProxyModel
	group_                   ?&BrowsingContextGroup
	parent_                  ?&BrowsingContextModel
	opener_browsing_context_ ?&BrowsingContextModel
	children_                []&BrowsingContextModel
	target_name_             string
	is_auxiliary_            bool
	is_popup_                bool
	discarded_               bool
	fully_active_override_   bool = true
}

pub fn BrowsingContextModel.create(document ?&dom.Document, parent ?&BrowsingContextModel, target_name string) &BrowsingContextModel {
	context := &BrowsingContextModel{
		document_:    document
		parent_:      parent
		target_name_: target_name
	}
	if mut parent_context := parent {
		parent_context.children_ << context
	}
	return context
}

pub fn (context &BrowsingContextModel) active_document() ?&dom.Document {
	return context.document_
}

pub fn (context &BrowsingContextModel) active_window() ?&WindowModel {
	return context.window_
}

pub fn (context &BrowsingContextModel) window_proxy() ?&WindowProxyModel {
	return context.window_proxy_
}

pub fn (mut context BrowsingContextModel) set_active_document(document ?&dom.Document) {
	context.document_ = document
}

pub fn (mut context BrowsingContextModel) set_active_window(window ?&WindowModel) {
	context.window_ = window
}

pub fn (mut context BrowsingContextModel) set_window_proxy(proxy ?&WindowProxyModel) {
	context.window_proxy_ = proxy
}

pub fn (context &BrowsingContextModel) group() ?&BrowsingContextGroup {
	return context.group_
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

pub fn (context &BrowsingContextModel) opener() ?&BrowsingContextModel {
	return context.opener_browsing_context_
}

pub fn (mut context BrowsingContextModel) set_popup(value bool) {
	context.is_popup_ = value
}

pub fn (context &BrowsingContextModel) is_popup() bool {
	return context.is_popup_
}

pub fn (context &BrowsingContextModel) is_top_level() bool {
	return context.parent_ == none
}

pub fn (context &BrowsingContextModel) top_level_browsing_context() ?&BrowsingContextModel {
	if !context.fully_active_override_ || context.discarded_ {
		return none
	}
	mut current := context
	for {
		parent := current.parent_ or { return current }
		current = parent
	}
	return none
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
	context.window_ = none
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
	window_ &WindowModel = unsafe { nil }
}

pub fn WindowProxyModel.create(window &WindowModel) &WindowProxyModel {
	return &WindowProxyModel{
		window_: window
	}
}

pub fn (proxy &WindowProxyModel) window() &WindowModel {
	return proxy.window_
}

pub fn (mut proxy WindowProxyModel) set_window(window &WindowModel) {
	proxy.window_ = window
}

pub fn (proxy &WindowProxyModel) associated_browsing_context() &BrowsingContextModel {
	return proxy.window_.browsing_context()
}

pub fn (proxy &WindowProxyModel) is_extensible() bool {
	return true
}

pub fn (proxy &WindowProxyModel) prevent_extensions() bool {
	return false
}

pub fn (proxy &WindowProxyModel) get_own_property(caller_origin dom.Origin, key string) !WindowProxyPropertyResult {
	if index := window_property_array_index(key) {
		children := proxy.window_.browsing_context().children()
		if index < children.len {
			child_proxy := children[index].window_proxy() or { return WindowProxyPropertyResult{} }
			return WindowProxyPropertyResult{
				found:      true
				descriptor: WindowProxyProperty{
					value:        dom.js_object(voidptr(child_proxy))
					enumerable:   true
					configurable: true
				}
			}
		}
		if proxy.window_.same_origin(caller_origin) {
			return WindowProxyPropertyResult{}
		}
		return error("SecurityError: cannot access indexed property '${key}' on cross-origin WindowProxy")
	}
	if proxy.window_.same_origin(caller_origin) {
		value := proxy.window_.named_property(key)
		if value.is_undefined() {
			return WindowProxyPropertyResult{}
		}
		return WindowProxyPropertyResult{
			found:      true
			descriptor: WindowProxyProperty{
				value:        value
				writable:     true
				enumerable:   true
				configurable: true
			}
		}
	}
	if key in window_cross_origin_property_names {
		return WindowProxyPropertyResult{
			found:      true
			descriptor: WindowProxyProperty{
				value:        proxy.window_.named_property(key)
				configurable: true
			}
		}
	}
	if child := proxy.window_.named_child(key) {
		child_proxy := child.window_proxy() or { return WindowProxyPropertyResult{} }
		return WindowProxyPropertyResult{
			found:      true
			descriptor: WindowProxyProperty{
				value:        dom.js_object(voidptr(child_proxy))
				configurable: true
			}
		}
	}
	return error("SecurityError: cannot access property '${key}' on cross-origin WindowProxy")
}

pub fn (proxy &WindowProxyModel) define_own_property(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	if !proxy.window_.same_origin(caller_origin) {
		return error("SecurityError: cannot define property '${key}' on cross-origin WindowProxy")
	}
	if _ := window_property_array_index(key) {
		return false
	}
	mut window := unsafe { &WindowModel(proxy.window_) }
	window.set_named_property(key, value)
	return true
}

pub fn (proxy &WindowProxyModel) set(caller_origin dom.Origin, key string, value dom.JSValue) !bool {
	if proxy.window_.same_origin(caller_origin) {
		if _ := window_property_array_index(key) {
			return false
		}
		mut window := unsafe { &WindowModel(proxy.window_) }
		window.set_named_property(key, value)
		return true
	}
	if key == 'location' && value.kind == .string {
		mut location := unsafe { &LocationModel(proxy.window_.location()) }
		location.set_href(value.string_data)!
		return true
	}
	return error("SecurityError: cannot set property '${key}' on cross-origin WindowProxy")
}

pub fn (proxy &WindowProxyModel) delete(caller_origin dom.Origin, key string) !bool {
	if !proxy.window_.same_origin(caller_origin) {
		return error("SecurityError: cannot delete property '${key}' on cross-origin WindowProxy")
	}
	if index := window_property_array_index(key) {
		return index >= proxy.window_.length()
	}
	mut window := unsafe { &WindowModel(proxy.window_) }
	return window.delete_named_property(key)
}

pub fn (proxy &WindowProxyModel) own_property_keys(caller_origin dom.Origin) []string {
	mut keys := []string{cap: proxy.window_.length() + 16}
	for index in 0 .. proxy.window_.length() {
		keys << index.str()
	}
	if proxy.window_.same_origin(caller_origin) {
		keys << proxy.window_.supported_property_names()
	} else {
		keys << window_cross_origin_property_names
	}
	return deduplicated_strings(keys)
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
}

pub struct PostedWindowMessage {
pub:
	data          dom.JSValue
	origin        string
	target_origin string
}

@[heap]
pub struct WindowModel {
	dom.EventTarget
mut:
	document_              &dom.Document                 = unsafe { nil }
	browsing_context_      &BrowsingContextModel         = unsafe { nil }
	window_proxy_          &WindowProxyModel             = unsafe { nil }
	location_              &LocationModel                = unsafe { nil }
	history_               &History                      = unsafe { nil }
	navigation_            &Navigation                   = unsafe { nil }
	navigator_             &Navigator                    = unsafe { nil }
	custom_elements_       &CustomElementRegistry        = unsafe { nil }
	animation_driver_      &AnimationFrameCallbackDriver = unsafe { nil }
	close_watcher_manager_ &CloseWatcherManager          = unsafe { nil }
	name_                  string
	status_                string
	closed_                bool
	opener_disowned_       bool
	named_properties_      map[string]dom.JSValue
	posted_messages_       []PostedWindowMessage
	stop_count_            u32
	focus_count_           u32
}

pub fn WindowModel.create(document &dom.Document, context &BrowsingContextModel) !&WindowModel {
	mut history := History.create(document.url, dom.js_null())!
	mut navigation := Navigation.create(document)
	history.set_navigation(navigation)
	mut window := &WindowModel{
		document_:              document
		browsing_context_:      context
		history_:               history
		navigation_:            navigation
		navigator_:             Navigator.create(NavigatorHostConfiguration{})
		custom_elements_:       CustomElementRegistry.create(document)
		animation_driver_:      &AnimationFrameCallbackDriver{}
		close_watcher_manager_: CloseWatcherManager.create()
	}
	proxy := WindowProxyModel.create(window)
	location := LocationModel.create(document, document.origin())
	window.window_proxy_ = proxy
	window.location_ = location
	mut mutable_context := unsafe { &BrowsingContextModel(context) }
	mutable_context.set_active_document(document)
	mutable_context.set_active_window(window)
	mutable_context.set_window_proxy(proxy)
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
	return window.document_
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
	return window.custom_elements_
}

pub fn (window &WindowModel) close_watcher_manager() &CloseWatcherManager {
	return window.close_watcher_manager_
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
	return window.document_.origin().is_same_origin(origin)
}

pub fn (mut window WindowModel) close() {
	if window.closed_ {
		return
	}
	context := window.browsing_context_
	script_closable := context.is_auxiliary_ || window.history_.length() or { u64(2) } <= 1
	if !context.is_top_level() || !script_closable {
		return
	}
	window.closed_ = true
	mut mutable_context := unsafe { &BrowsingContextModel(context) }
	mutable_context.remove()
}

pub fn (window &WindowModel) closed() bool {
	return window.closed_ || window.browsing_context_.has_navigable_been_destroyed()
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
	return window.browsing_context_.length()
}

pub fn (window &WindowModel) top() ?&WindowProxyModel {
	top_context := window.browsing_context_.top_level_browsing_context() or { return none }
	return top_context.window_proxy()
}

pub fn (window &WindowModel) parent() ?&WindowProxyModel {
	parent_context := window.browsing_context_.parent() or { return window.window_proxy_ }
	return parent_context.window_proxy()
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
	return window.animation_driver_.add(callback)
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

pub fn (mut window WindowModel) post_message(message dom.JSValue, source_origin dom.Origin, options WindowPostMessageOptions) ! {
	mut target_origin := options.target_origin
	if target_origin == '/' {
		target_origin = source_origin.serialize()
	} else if target_origin != '*' {
		parsed := dom.dom_url_parse(target_origin, source_origin_url(source_origin), 'UTF-8') or {
			return error("SyntaxError: Invalid target origin '${target_origin}'")
		}
		target_origin = parsed.origin().serialize()
	}
	if target_origin != '*' && target_origin != window.document_.origin().serialize() {
		return
	}
	mut transfer := []StructuredTransfer{cap: options.transfer.len}
	for port in options.transfer {
		transfer << StructuredTransfer(MessagePortTransfer{
			value: port
		})
	}
	record := structured_serialize_with_transfer(message, transfer)!
	deserialized := structured_deserialize_with_transfer(record)!
	data := deserialized.deserialized
	window.posted_messages_ << PostedWindowMessage{
		data:          data
		origin:        source_origin.serialize()
		target_origin: target_origin
	}
	mut event := MessageEvent.create('message', MessageEventInit{
		data:   data
		origin: source_origin
	})
	window.EventTarget.dispatch_event(unsafe { &dom.Event(event) })
}

fn source_origin_url(origin dom.Origin) dom.URL {
	if origin.value == 'opaque' {
		return dom.url_about_blank()
	}
	return dom.URL{origin.value + '/'}
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
			dom.js_undefined()
		}
	}
}

pub fn (window &WindowModel) supported_property_names() []string {
	mut names := window.named_properties_.keys()
	for child in window.browsing_context_.children() {
		if child.target_name() != '' && child.target_name() !in names {
			names << child.target_name()
		}
	}
	return names
}
