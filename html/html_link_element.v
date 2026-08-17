// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLLinkElement.{h,cpp}. Networking and platform DNS/socket
// work enter through hooks; relationship processing, requests, stylesheet/icon
// state, preloads, media/disabled behavior, and events remain local.
module html

import dom

pub enum LinkResourceKind {
	stylesheet
	icon
	preload
	dns_prefetch
	preconnect
	other
}

pub struct LinkResourceResponse {
pub:
	status       u16 = 200
	content_type string
	body         []u8
}

pub type LinkResourceFetchHook = fn (dom.URL, LinkResourceKind, CORSSettingAttribute) !LinkResourceResponse

pub type LinkConnectionHook = fn (dom.URL) !

@[heap]
pub struct HTMLLinkElementModel {
mut:
	base_url_                 dom.URL
	event_target_             &dom.EventTarget = unsafe { nil }
	rel_                      string
	href_                     string
	type_                     string
	media_                    string
	sizes_                    string
	disabled_                 bool
	connected_                bool = true
	crossorigin_              CORSSettingAttribute
	fetch_hook_               ?LinkResourceFetchHook
	dns_prefetch_hook_        ?LinkConnectionHook
	preconnect_hook_          ?LinkConnectionHook
	loaded_icon_              ?[]u8
	loaded_icon_url_          ?dom.URL
	loaded_style_sheet_       ?string
	preloaded_response_       ?LinkResourceResponse
	stylesheet_loading_       bool
	stylesheet_failed_        bool
	explicitly_enabled_       bool
	parser_inserted_          bool
	was_enabled_when_created_ bool
	event_counts_             map[string]int
}

pub fn HTMLLinkElementModel.create(base_url dom.URL) &HTMLLinkElementModel {
	return &HTMLLinkElementModel{
		base_url_:     base_url
		event_target_: dom.EventTarget.new()
	}
}

fn link_relation_tokens(rel string) []string {
	mut result := []string{}
	for token in rel.fields() {
		lower := ascii_lowercase_string(token)
		if lower !in result {
			result << lower
		}
	}
	return result
}

fn (link &HTMLLinkElementModel) has_relation(name string) bool {
	return name in link_relation_tokens(link.rel_)
}

fn (mut link HTMLLinkElementModel) fire_event(name string) {
	link.event_counts_[name]++
	link.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (link &HTMLLinkElementModel) event_target() &dom.EventTarget {
	return link.event_target_
}

pub fn (link &HTMLLinkElementModel) event_count(name string) int {
	return link.event_counts_[name]
}

pub fn (mut link HTMLLinkElementModel) set_fetch_hook(hook ?LinkResourceFetchHook) {
	link.fetch_hook_ = hook
}

pub fn (mut link HTMLLinkElementModel) set_connection_hooks(dns ?LinkConnectionHook, preconnect ?LinkConnectionHook) {
	link.dns_prefetch_hook_ = dns
	link.preconnect_hook_ = preconnect
}

pub fn (mut link HTMLLinkElementModel) set_rel(value string) {
	link.rel_ = value
}

pub fn (link &HTMLLinkElementModel) rel() string {
	return link.rel_
}

pub fn (link &HTMLLinkElementModel) rel_list() []string {
	return link_relation_tokens(link.rel_)
}

pub fn (mut link HTMLLinkElementModel) set_href(value string) {
	link.href_ = value
}

pub fn (link &HTMLLinkElementModel) href() string {
	return link.href_
}

pub fn (mut link HTMLLinkElementModel) set_type(value string) {
	link.type_ = value
}

pub fn (link &HTMLLinkElementModel) type_() string {
	return link.type_
}

pub fn (mut link HTMLLinkElementModel) set_media(value string) {
	link.media_ = value
}

pub fn (link &HTMLLinkElementModel) media() string {
	return link.media_
}

pub fn (mut link HTMLLinkElementModel) set_sizes(value string) {
	link.sizes_ = value
}

pub fn (link &HTMLLinkElementModel) sizes() []string {
	return link_relation_tokens(link.sizes_)
}

pub fn (mut link HTMLLinkElementModel) set_crossorigin(value ?string) {
	link.crossorigin_ = cors_setting_attribute_from_keyword(value)
}

pub fn (mut link HTMLLinkElementModel) set_disabled(value bool) {
	link.disabled_ = value
	if !value {
		link.explicitly_enabled_ = true
	}
}

pub fn (mut link HTMLLinkElementModel) set_connected(value bool) {
	link.connected_ = value
}

pub fn (mut link HTMLLinkElementModel) set_parser_state(inserted bool, enabled_when_created bool) {
	link.parser_inserted_ = inserted
	link.was_enabled_when_created_ = enabled_when_created
}

pub fn (link &HTMLLinkElementModel) should_fetch_and_process_resource_type() bool {
	if !link.connected_ || link.href_ == '' {
		return false
	}
	return link.has_relation('stylesheet') || link.has_relation('icon')
		|| link.has_relation('preload') || link.has_relation('dns-prefetch')
		|| link.has_relation('preconnect')
}

pub fn (mut link HTMLLinkElementModel) fetch_and_process_linked_resource() {
	if !link.should_fetch_and_process_resource_type() {
		return
	}
	url := dom.dom_url_parse(link.href_, link.base_url_, 'UTF-8') or {
		link.fire_event('error')
		return
	}
	if link.has_relation('dns-prefetch') {
		if hook := link.dns_prefetch_hook_ {
			hook(url) or { link.fire_event('error') }
		}
	}
	if link.has_relation('preconnect') {
		if hook := link.preconnect_hook_ {
			hook(url) or { link.fire_event('error') }
		}
	}
	mut kind := LinkResourceKind.other
	if link.has_relation('stylesheet') {
		if link.disabled_ {
			return
		}
		kind = .stylesheet
		link.stylesheet_loading_ = true
	} else if link.has_relation('icon') {
		kind = .icon
	} else if link.has_relation('preload') {
		kind = .preload
	} else {
		return
	}
	fetch := link.fetch_hook_ or {
		link.stylesheet_loading_ = false
		link.stylesheet_failed_ = kind == .stylesheet
		link.fire_event('error')
		return
	}

	response := fetch(url, kind, link.crossorigin_) or {
		link.stylesheet_loading_ = false
		link.stylesheet_failed_ = kind == .stylesheet
		link.fire_event('error')
		return
	}
	if response.status < 200 || response.status >= 300 {
		link.stylesheet_loading_ = false
		link.stylesheet_failed_ = kind == .stylesheet
		link.fire_event('error')
		return
	}
	match kind {
		.stylesheet {
			mime := ascii_lowercase_string(response.content_type.split(';')[0].trim_space())
			if mime != '' && mime != 'text/css' {
				link.stylesheet_loading_ = false
				link.stylesheet_failed_ = true
				link.fire_event('error')
				return
			}
			link.loaded_style_sheet_ = response.body.bytestr()
			link.stylesheet_loading_ = false
			link.stylesheet_failed_ = false
			link.fire_event('load')
		}
		.icon {
			link.loaded_icon_ = response.body.clone()
			link.loaded_icon_url_ = url
			link.fire_event('load')
		}
		.preload {
			link.preloaded_response_ = response
			link.fire_event('load')
		}
		else {}
	}
}

pub fn (link &HTMLLinkElementModel) sheet() ?string {
	return link.loaded_style_sheet_
}

pub fn (link &HTMLLinkElementModel) has_loaded_icon() bool {
	return link.loaded_icon_ != none
}

pub fn (link &HTMLLinkElementModel) loaded_icon() ?[]u8 {
	return link.loaded_icon_
}

pub fn (link &HTMLLinkElementModel) preloaded_response() ?LinkResourceResponse {
	return link.preloaded_response_
}

pub fn (link &HTMLLinkElementModel) contributes_a_script_blocking_style_sheet() bool {
	return link.has_relation('stylesheet') && !link.disabled_
		&& (link.stylesheet_loading_ || (link.parser_inserted_ && link.was_enabled_when_created_))
}

pub fn (link &HTMLLinkElementModel) is_implicitly_potentially_render_blocking() bool {
	return link.has_relation('stylesheet') && !link.disabled_ && !link.has_relation('alternate')
}

pub fn (mut link HTMLLinkElementModel) removed() {
	link.connected_ = false
	link.stylesheet_loading_ = false
}
