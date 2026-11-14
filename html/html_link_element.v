// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLLinkElement.{h,cpp}. Networking and platform DNS/socket
// work enter through hooks; relationship processing, requests, stylesheet/icon
// state, preloads, media/disabled behavior, and events remain local.
module html

import css
import dom
import fetch
import mimesniff

pub enum LinkResourceKind {
	stylesheet
	icon
	preload
	module_preload
	dns_prefetch
	preconnect
	other
}

pub struct LinkResourceResponse {
pub:
	status       u16 = 200
	content_type string
	body         []u8
	// Keep the first request URL for CSSOM href, separate from the final
	// response URL used to resolve relative stylesheet resources.
	original_url ?dom.URL
	url          ?dom.URL
	origin_clean bool = true
}

// V counterparts of HTMLLinkElement::LinkProcessingOptions and the Fetch
// request fields written by create_link_request/setup steps. Fetch itself is
// kept behind LinkResourceFetchHook, but the observable request construction
// and dispatch decisions stay explicit here.
pub struct LinkProcessingOptions {
pub mut:
	href                         string
	integrity                    string
	type_                        string
	cryptographic_nonce_metadata string
	destination                  ?string
	crossorigin                  CORSSettingAttribute
	referrer_policy              string
	base_url                     dom.URL
	document                     ?&dom.Document
	fetch_priority               string
}

pub struct LinkRequest {
pub mut:
	url             dom.URL
	destination     ?string
	crossorigin     CORSSettingAttribute
	integrity       string
	nonce           string
	referrer_policy string
	priority        string
	initiator       string = 'link'
	render_blocking bool
	kind            LinkResourceKind
}

pub type LinkResourceFetchHook = fn(dom.URL, LinkResourceKind, CORSSettingAttribute) !LinkResourceResponse

pub type LinkConnectionHook = fn(dom.URL) !

pub type LinkFaviconDecodeHook = fn([]u8, dom.URL, &dom.Document) !

__global (
	link_fallback_favicon_fetch_hook LinkResourceFetchHook
	link_favicon_decode_hook         LinkFaviconDecodeHook
)

fn decode_favicon(favicon_data []u8, favicon_url dom.URL, document &dom.Document) !bool {
	if favicon_data.len == 0 {
		return error('Failed to decode empty favicon')
	}
	if link_favicon_decode_hook != unsafe { nil } {
		link_favicon_decode_hook(favicon_data.clone(), favicon_url, document)!
	}
	return true
}

@[heap]
pub struct HTMLLinkElementModel {
mut:
	element_                      ?&dom.HTMLLinkElement
	base_url_                     dom.URL
	event_target_                 &dom.EventTarget = unsafe { nil }
	rel_                          string
	href_                         string
	type_                         string
	type_attribute_present_       bool
	media_                        string
	sizes_                        string
	disabled_                     bool
	connected_                    bool = true
	crossorigin_                  CORSSettingAttribute
	fetch_hook_                   ?LinkResourceFetchHook
	external_stylesheet_fetcher_  bool
	dns_prefetch_hook_            ?LinkConnectionHook
	preconnect_hook_              ?LinkConnectionHook
	loaded_icon_                  ?[]u8
	loaded_icon_url_              ?dom.URL
	loaded_style_sheet_           ?string
	preloaded_response_           ?LinkResourceResponse
	stylesheet_loading_           bool
	stylesheet_failed_            bool
	explicitly_enabled_           bool
	parser_inserted_              bool
	parser_document_              ?&dom.Document
	was_enabled_when_created_     bool
	integrity_                    string
	as_                           string
	referrer_policy_              string
	fetch_priority_               string
	cryptographic_nonce_          string
	document_load_event_delaying_ bool
	document_load_event_delayer_  ?dom.DocumentLoadEventDelayer
	event_counts_                 map[string]int
}

pub fn HTMLLinkElementModel.create(base_url dom.URL) &HTMLLinkElementModel {
	return &HTMLLinkElementModel{
		base_url_: base_url
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
	event := dom.Event.create(name, dom.EventInit{})
	if element := link.element_ {
		unsafe { &dom.EventTarget(element) }
		.dispatch_event(event)
	} else {
		link.event_target_.dispatch_event(event)
	}
}

fn link_dom_element(element &dom.HTMLLinkElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn link_model_has_loaded_icon(target voidptr) bool {
	model := unsafe { &HTMLLinkElementModel(target) }
	return model.has_loaded_icon()
}

fn link_model_load_favicon(target voidptr) bool {
	model := unsafe { &HTMLLinkElementModel(target) }
	data := model.loaded_icon() or { return false }
	url := model.loaded_icon_url() or { return false }
	element := model.element_ or { return false }
	return decode_favicon(data, url, link_dom_element(element).document()) or { false }
}

fn html_link_element_adopted_from_callback(target voidptr, old_document &dom.Document) {
	mut model := unsafe { &HTMLLinkElementModel(target) }
	model.adopted_from(old_document)
}

fn attach_html_link_element_model(element &dom.HTMLLinkElement, model &HTMLLinkElementModel) {
	mut mutable_model := unsafe { &HTMLLinkElementModel(model) }
	mutable_model.element_ = element
	mut mutable_element := unsafe { &dom.HTMLLinkElement(element) }
	mutable_element.link_element_model_ = voidptr(model)
	mutable_element.link_has_loaded_icon_callback_ = link_model_has_loaded_icon
	mutable_element.link_load_favicon_callback_ = link_model_load_favicon
	mutable_element.link_type_attribute_changed_callback_ = link_model_type_attribute_changed
	mut node := link_dom_element(element).as_node()
	node.set_adopted_from_hook(dom.NodeAdoptedFromHook{
		target: voidptr(model)
		callback: html_link_element_adopted_from_callback
	})
}

pub fn html_link_element_model_for_dom_element(element &dom.HTMLLinkElement) &HTMLLinkElementModel {
	if element.link_element_model_ != unsafe { nil } {
		model := unsafe { &HTMLLinkElementModel(element.link_element_model_) }
		attach_html_link_element_model(element, model)
		return model
	}
	dom_element := link_dom_element(element)
	mut model := HTMLLinkElementModel.create(dom_element.document().base_url())
	model.rel_ = dom_element.get_attribute_value('rel')
	model.href_ = dom_element.get_attribute_value('href')
	model.type_ = dom_element.get_attribute_value('type')
	model.type_attribute_present_ = dom_element.get_attribute_ns(none, 'type') != none
	model.media_ = dom_element.get_attribute_value('media')
	model.sizes_ = dom_element.get_attribute_value('sizes')
	model.disabled_ = dom_element.has_attribute('disabled')
	model.crossorigin_ = cors_setting_attribute_from_keyword(dom_element.get_attribute('crossorigin'))
	model.integrity_ = dom_element.get_attribute_ns(none, 'integrity') or { '' }
	model.as_ = ascii_lowercase_string(dom_element.get_attribute_value('as'))
	model.referrer_policy_ = ascii_lowercase_string(dom_element.get_attribute_value('referrerpolicy'))
	model.fetch_priority_ = ascii_lowercase_string(dom_element.get_attribute_value('fetchpriority'))
	model.cryptographic_nonce_ = unsafe { &dom.HTMLElement(element) }.cryptographic_nonce()
	model.connected_ = dom_element.as_node().is_browsing_context_connected()
	attach_html_link_element_model(element, model)
	return model
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
	link.type_attribute_present_ = true
}

fn link_model_type_attribute_changed(target voidptr, old_value ?string, value ?string) {
	mut model := unsafe { &HTMLLinkElementModel(target) }
	model.type_ = value or { '' }
	model.type_attribute_present_ = value != none
	if element := model.element_ {
		model.connected_ = link_dom_element(element).as_node().is_browsing_context_connected()
	}
	if model.connected_ && model.has_relation('stylesheet') && old_value != value
		&& !(is_supported_style_sheet_type_attribute(old_value) && is_supported_style_sheet_type_attribute(value)) {
		model.fetch_and_process_linked_resource()
	}
}

pub fn is_supported_style_sheet_type_attribute(value ?string) bool {
	type_ := value or { return true }
	mime := mimesniff.MimeType.parse(type_) or { return false }
	return mime.essence() == 'text/css'
}

fn (link &HTMLLinkElementModel) supports_style_sheet_type() bool {
	if element := link.element_ {
		return is_supported_style_sheet_type_attribute(link_dom_element(element).get_attribute_ns(none, 'type'))
	}
	return is_supported_style_sheet_type_attribute(if link.type_attribute_present_ { ?string(link.type_) } else { none })
}

fn (mut link HTMLLinkElementModel) clear_loaded_style_sheet() {
	link.loaded_style_sheet_ = none
	if element := link.element_ {
		mut dom_link := unsafe { &dom.HTMLLinkElement(element) }
		dom_link.remove_linked_style_sheet()
	}
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

pub fn (mut link HTMLLinkElementModel) set_as(value string) {
	link.as_ = ascii_lowercase_string(value)
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

pub fn (mut link HTMLLinkElementModel) set_parser_document(document &dom.Document) {
	link.parser_document_ = document
	link.parser_inserted_ = true
}

pub fn (mut link HTMLLinkElementModel) set_was_enabled_when_created_by_parser(value bool) {
	link.was_enabled_when_created_ = value
}

pub fn (link &HTMLLinkElementModel) should_fetch_and_process_resource_type() bool {
	return link.has_relation('stylesheet') || link.has_relation('icon') || link.has_relation('preload')
		|| link.has_relation('modulepreload') || link.has_relation('dns-prefetch')
		|| link.has_relation('preconnect')
}

pub fn (mut link HTMLLinkElementModel) fetch_and_process_linked_resource() {
	if !link.should_fetch_and_process_resource_type() {
		return
	}
	// A relationship containing anything outside the pure speculative-fetch
	// set uses the default algorithm. Otherwise preload wins over preconnect,
	// and preconnect wins over DNS prefetch.
	if link.has_relation('stylesheet') || link.has_relation('icon') || link.has_relation('alternate') {
		link.default_fetch_and_process_linked_resource()
	} else if link.has_relation('modulepreload') {
		link.fetch_and_process_linked_modulepreload_resource()
	} else if link.has_relation('preload') {
		link.fetch_and_process_linked_preload_resource()
	} else if link.has_relation('preconnect') {
		link.fetch_and_process_linked_preconnect_resource()
	} else if link.has_relation('dns-prefetch') {
		link.fetch_and_process_linked_dns_prefetch_resource()
	}
}

pub fn (link &HTMLLinkElementModel) create_link_options() &LinkProcessingOptions {
	return &LinkProcessingOptions{
		href: link.href_
		integrity: link.integrity_
		type_: link.type_
		cryptographic_nonce_metadata: link.cryptographic_nonce_
		crossorigin: link.crossorigin_
		referrer_policy: link.referrer_policy_
		base_url: link.base_url_
		document: if element := link.element_ {
			link_dom_element(element).document()} else {
			none}
		fetch_priority: link.fetch_priority_
	}
}

pub fn (link &HTMLLinkElementModel) create_link_request(options &LinkProcessingOptions) ?&LinkRequest {
	assert options.href != ''
	url := dom.dom_url_parse(options.href, options.base_url, 'UTF-8') or { return none }
	if document := link.resource_document() {
		if document.is_svg_image_document() && url.scheme() != 'data' { return none }
	}
	return &LinkRequest{
		url: url
		destination: options.destination
		crossorigin: options.crossorigin
		integrity: options.integrity
		nonce: options.cryptographic_nonce_metadata
		referrer_policy: options.referrer_policy
		priority: options.fetch_priority
	}
}

pub fn (mut link HTMLLinkElementModel) linked_resource_fetch_setup_steps(mut request LinkRequest) bool {
	if link.has_relation('icon') {
		return link.icon_linked_resource_fetch_setup_steps(mut request)
	}
	if link.has_relation('stylesheet') {
		return link.stylesheet_linked_resource_fetch_setup_steps(mut request)
	}
	return true
}

pub fn (mut link HTMLLinkElementModel) icon_linked_resource_fetch_setup_steps(mut request LinkRequest) bool {
	request.destination = 'image'
	request.kind = .icon
	return true
}

pub fn (mut link HTMLLinkElementModel) stylesheet_linked_resource_fetch_setup_steps(mut request LinkRequest) bool {
	if !link.supports_style_sheet_type() {
		link.clear_loaded_style_sheet()
		link.cancel_pending_stylesheet_load()
		return false
	}
	if link.disabled_ {
		return false
	}
	request.destination = 'style'
	request.kind = .stylesheet
	link.stylesheet_loading_ = true
	if element := link.element_ {
		mut dom_element := link_dom_element(element)
		mut document := unsafe { &dom.Document(dom_element.document()) }
		link.begin_delaying_document_load_event(document)
		if link.contributes_a_script_blocking_style_sheet() {
			document.append_to_script_blocking_style_sheet_set(dom_element)
		}
		if link.is_implicitly_potentially_render_blocking() {
			dom_element.block_rendering()
		}
		request.render_blocking = document.is_render_blocking_element(dom_element)
	} else {
		link.document_load_event_delaying_ = true
	}
	return true
}

fn (mut link HTMLLinkElementModel) begin_delaying_document_load_event(document &dom.Document) {
	if mut delayer := link.document_load_event_delayer_ {
		delayer.finish()
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	link.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new_with_reason(mut mutable_document, .style_sheet_request)
	link.document_load_event_delaying_ = true
}

fn (mut link HTMLLinkElementModel) stop_delaying_document_load_event() {
	if mut delayer := link.document_load_event_delayer_ {
		delayer.finish()
	}
	link.document_load_event_delayer_ = none
	link.document_load_event_delaying_ = false
}

fn (mut link HTMLLinkElementModel) cancel_pending_stylesheet_load() {
	if !link.stylesheet_loading_ && !link.document_load_event_delaying_ {
		return
	}
	link.stylesheet_loading_ = false
	if element := link.element_ {
		mut dom_element := link_dom_element(element)
		mut document := unsafe { &dom.Document(dom_element.document()) }
		document.remove_from_script_blocking_style_sheet_set(dom_element)
		dom_element.unblock_rendering()
	}
	link.stop_delaying_document_load_event()
}

pub fn (mut link HTMLLinkElementModel) adopted_from(_ &dom.Document) {
	element := link.element_ or { return }
	new_document := link_dom_element(element).document()
	link.base_url_ = new_document.base_url()
	mut was_delaying := false
	if mut delayer := link.document_load_event_delayer_ {
		delayer.finish()
		was_delaying = true
	}
	if was_delaying {
		mut mutable_new_document := unsafe { &dom.Document(new_document) }
		link.document_load_event_delayer_ = dom.DocumentLoadEventDelayer.new_with_reason(mut mutable_new_document, .style_sheet_request)
		link.document_load_event_delaying_ = true
	}
}

pub fn (mut link HTMLLinkElementModel) default_fetch_and_process_linked_resource() {
	if link.href_ == '' {
		return
	}
	options := link.create_link_options()
	mut request := link.create_link_request(options) or { return }
	if !link.linked_resource_fetch_setup_steps(mut request) {
		return
	}
	request.initiator = if link.has_relation('stylesheet') { 'css' } else { 'link' }
	fetch_resource := link.fetch_hook_ or {
		// Browser adapters with asynchronous stylesheet transport complete the
		// same model later; absence of a synchronous hook is not a failure.
		if link.external_stylesheet_fetcher_ && request.kind == .stylesheet { return }
		link.process_linked_resource(false, request.url, LinkResourceResponse{ origin_clean: false })
		return
	}
	response := fetch_resource(request.url, request.kind, request.crossorigin) or {
		link.process_linked_resource(false, request.url, LinkResourceResponse{ origin_clean: false })
		return
	}
	success := response.status >= 200 && response.status < 300
	link.process_linked_resource(success, request.url, response)
}

pub fn (mut link HTMLLinkElementModel) set_external_stylesheet_fetcher(enabled bool) {
	link.external_stylesheet_fetcher_ = enabled
}

pub fn (link &HTMLLinkElementModel) is_stylesheet_loading() bool {
	return link.stylesheet_loading_
}

pub fn (mut link HTMLLinkElementModel) fetch_and_process_linked_dns_prefetch_resource() {
	if document := link.resource_document() {
		if document.is_svg_image_document() { return }
	}
	if link.href_ == '' {
		return
	}
	url := dom.dom_url_parse(link.href_, link.base_url_, 'UTF-8') or { return }
	if hook := link.dns_prefetch_hook_ {
		hook(url) or {}
	}
}

pub fn (mut link HTMLLinkElementModel) fetch_and_process_linked_preconnect_resource() {
	options := link.create_link_options()
	link.preconnect(options)
}

fn request_destination_from_preload_destination(destination ?string) ?RequestDestination {
	value := destination or { return none }
	return match value {
		'audio' { RequestDestination.audio }
		'font' { RequestDestination.font }
		'image' { RequestDestination.image }
		'script' { RequestDestination.script }
		'style' { RequestDestination.style }
		'track' { RequestDestination.track }
		else { none }
	}
}

pub fn (mut link HTMLLinkElementModel) fetch_and_process_linked_preload_resource() {
	destination := translate_a_preload_destination(link.as_) or { return }
	if destination == 'script' {
		if document := link.resource_document() {
			if !document.is_scripting_enabled_by_embedder() { return }
		}
	}
	mut options := link.create_link_options()
	options.destination = if destination == '' { none } else { destination }
	link.preload(mut options)
}

fn media_attribute_matches_environment(document ?&dom.Document, media string) bool {
	if media == '' {
		return true
	}
	queries := if actual_document := document {
		css.parse_media_query_list(css.ParsingParams{
			document: actual_document
		}, media)
	} else {
		css.parse_media_query_list(css.ParsingParams{}, media)
	}
	for query in queries {
		if query.evaluate(document) {
			return true
		}
	}
	return false
}

fn module_preload_destination_from_as_attribute(as_attribute string) ?fetch.Destination {
	value := ascii_lowercase_string(as_attribute)
	return match value {
		'audioworklet' { fetch.Destination.audio_worklet }
		'paintworklet' { fetch.Destination.paint_worklet }
		'script' { fetch.Destination.script }
		'serviceworker' { fetch.Destination.service_worker }
		'sharedworker' { fetch.Destination.shared_worker }
		'worker' { fetch.Destination.worker }
		'style' { fetch.Destination.style }
		'json' { fetch.Destination.json }
		'text' { fetch.Destination.text }
		'audio', 'document', 'embed', 'fetch', 'font', 'frame', 'iframe', 'image',
		'manifest', 'object', 'report', 'track', 'video', 'webidentity', 'xslt' {
			none
		}
		else { fetch.Destination.script }
	}
}

fn (link &HTMLLinkElementModel) resource_document() ?&dom.Document {
	if element := link.element_ {
		return link_dom_element(element).document()
	}
	return link.parser_document_
}

fn ignore_modulepreload_fetch_complete(_ ?&Script) {}

// https://html.spec.whatwg.org/multipage/links.html#link-type-modulepreload:fetch-and-process-the-linked-resource
pub fn (mut link HTMLLinkElementModel) fetch_and_process_linked_modulepreload_resource() {
	document := link.resource_document()
	if actual_document := document {
		if !actual_document.is_scripting_enabled_by_embedder() { return }
	}
	if !media_attribute_matches_environment(document, link.media_) || link.href_ == '' {
		return
	}
	destination := module_preload_destination_from_as_attribute(link.as_) or {
		link.fire_event('error')
		return
	}
	url := dom.dom_url_parse(link.href_, link.base_url_, 'UTF-8') or { return }
	actual_document := document or {
		link.fire_event('error')
		return
	}
	settings_pointer := actual_document.relevant_settings_object()
	if settings_pointer == unsafe { nil } {
		link.fire_event('error')
		return
	}
	settings := unsafe { &EnvironmentSettingsObject(settings_pointer) }
	mut integrity_metadata := link.integrity_
	has_integrity_attribute := if element := link.element_ {
		link_dom_element(element).has_attribute_ns(none, 'integrity')
	} else {
		link.integrity_ != ''
	}
	if !has_integrity_attribute {
		integrity_metadata = resolve_a_module_integrity_metadata(url, settings)
	}
	nonce := if element := link.element_ {
		unsafe { &dom.HTMLElement(element) }.cryptographic_nonce()
	} else {
		link.cryptographic_nonce_
	}
	options := ScriptFetchOptions{
		cryptographic_nonce: nonce
		integrity_metadata: integrity_metadata
		parser_metadata: .not_parser_inserted
		credentials_mode: if link.crossorigin_ == .use_credentials {
			fetch.CredentialsMode.include
		} else {
			fetch.CredentialsMode.same_origin
		}
		referrer_policy: link.referrer_policy_
		fetch_priority: fetch.request_priority_from_string(link.fetch_priority_) or {
			fetch.Priority.auto
		}
	}
	success := fetch_modulepreload_module_script_graph(settings.realm(), url, destination,
		settings, options, ignore_modulepreload_fetch_complete)
	link.fire_event(if success { 'load' } else { 'error' })
}

pub fn (mut link HTMLLinkElementModel) preconnect(options &LinkProcessingOptions) {
	if document := link.resource_document() {
		if document.is_svg_image_document() { return }
	}
	if options.href == '' {
		return
	}
	url := dom.dom_url_parse(options.href, options.base_url, 'UTF-8') or { return }
	if url.scheme() !in ['http', 'https'] {
		return
	}
	if hook := link.preconnect_hook_ {
		hook(url) or {}
	}
}

fn link_type_matches_destination(type_ string, destination ?string) bool {
	if type_ == '' || destination == none {
		return true
	}
	essence := ascii_lowercase_string(type_.split(';')[0].trim_space())
	dest := destination or { return true }
	return match dest {
		'audio', 'video' { essence.starts_with('audio/') || essence.starts_with('video/') }
		'script' {
			essence in ['text/javascript', 'application/javascript', 'application/ecmascript',
				'text/ecmascript']
		}
		'image' { essence.starts_with('image/') }
		'font' {
			essence.starts_with('font/') || essence in ['application/font-woff',
				'application/vnd.ms-fontobject']
		}
		'style' { essence == 'text/css' }
		'track' { essence == 'text/vtt' }
		else { false }
	}
}

pub fn (mut link HTMLLinkElementModel) preload(mut options LinkProcessingOptions) {
	if destination := options.destination {
		if destination == 'script' {
			if document := options.document {
				if !document.is_scripting_enabled_by_embedder() { return }
			}
		}
	}
	if !link_type_matches_destination(options.type_, options.destination) || options.href == '' {
		return
	}
	mut request := link.create_link_request(options) or { return }
	request.kind = .preload
	fetch_resource := link.fetch_hook_ or {
		link.fire_event('error')
		return
	}
	potential_request := create_potential_cors_request(request.url, request_destination_from_preload_destination(options.destination), options.crossorigin, .no)
	key := create_a_preload_key(potential_request)
	mut entry := &PreloadEntry{
		integrity_metadata: options.integrity
	}
	if document := options.document {
		store_preloaded_resource(document, key, entry)
	}
	response := fetch_resource(request.url, .preload, request.crossorigin) or {
		link.fire_event('error')
		return
	}
	link.complete_preload_response(mut entry, true, response)
}

fn (mut link HTMLLinkElementModel) complete_preload_response(mut entry PreloadEntry, succeeded bool, response LinkResourceResponse) {
	if !succeeded { link.fire_event('error'); return }
	entry.set_response(response)
	if response.status < 200 || response.status >= 300 {
		link.fire_event('error')
		return
	}
	link.preloaded_response_ = response
	link.fire_event('load')
}

// A browser transport can supply a preload without installing a stylesheet.
// Its completion still populates the native preload map and fires on its link.
pub fn (mut link HTMLLinkElementModel) process_preload_response(succeeded bool, response LinkResourceResponse) {
	mut options := link.create_link_options()
	destination := translate_a_preload_destination(link.as_) or { return }
	options.destination = destination
	if !media_attribute_matches_environment(link.resource_document(), link.media_) { return }
	if !link_type_matches_destination(options.type_, options.destination) || options.href == '' { return }
	request := link.create_link_request(options) or { return }
	potential := create_potential_cors_request(request.url, request_destination_from_preload_destination(options.destination), options.crossorigin, .no)
	key := create_a_preload_key(potential)
	mut entry := &PreloadEntry{integrity_metadata:options.integrity}
	if document := options.document { store_preloaded_resource(document, key, entry) }
	link.complete_preload_response(mut entry, succeeded, response)
}

pub fn (mut link HTMLLinkElementModel) process_linked_resource(success bool, url dom.URL, response LinkResourceResponse) {
	if link.has_relation('icon') {
		link.process_icon_resource(success, url, response.body)
	} else if link.has_relation('stylesheet') {
		link.process_stylesheet_resource(success, LinkResourceResponse{
			...response
			original_url: url
		})
	}
}

pub fn (mut link HTMLLinkElementModel) process_icon_resource(success bool, url dom.URL, body []u8) {
	if !success {
		return
	}
	link.loaded_icon_ = body.clone()
	link.loaded_icon_url_ = url
	if element := link.element_ {
		mut document := unsafe { &dom.Document(link_dom_element(element).document()) }
		document.check_favicon_after_loading_link_resource()
	}
}

pub fn (mut link HTMLLinkElementModel) process_stylesheet_resource(request_succeeded bool, response LinkResourceResponse) {
	if element := link.element_ {
		if !link_dom_element(element).document().is_fully_active() {
			return
		}
	}
	// An ineligible link cancels its load; it must not regain an empty sheet
	// when an older asynchronous request completes after a type change.
	if !link.supports_style_sheet_type() {
		link.clear_loaded_style_sheet()
		link.cancel_pending_stylesheet_load()
		return
	}
	mut success := request_succeeded
	mut assume_css_in_quirks_mode := false
	if document := link.resource_document() {
		if resource_url := response.url {
			assume_css_in_quirks_mode = document.in_quirks_mode()
				&& document.origin().is_same_origin(resource_url.origin())
		}
	}
	// Only the response metadata determines the resource's type. An absent
	// or invalid Content-Type retains the interoperable CSS fallback.
	if mime := mimesniff.MimeType.parse(response.content_type) {
		if mime.essence() != 'text/css' && !assume_css_in_quirks_mode {
			success = false
		}
	}
	link.clear_loaded_style_sheet()
	// Failed connected links still expose an empty sheet, with the response's
	// origin-clean state. A removed link must not regain a sheet on completion.
	connected := if element := link.element_ {
		link_dom_element(element).as_node().is_browsing_context_connected()
	} else { link.connected_ }
	if success || connected {
		css_text := if success { response.body.bytestr() } else { '' }
		link.loaded_style_sheet_ = css_text
		if element := link.element_ {
			location := response.original_url or {
				response.url or {
					dom.dom_url_parse(link.href_, link.base_url_, 'utf-8') or { link.base_url_ }
				}
			}
			resource_url := response.url or { location }
			mut sheet := css.install_link_style_sheet_with_base(element, css_text,
				location.serialize(), link.has_relation('alternate') && !link.explicitly_enabled_,
				resource_url.serialize())
			sheet.base.origin_clean = response.origin_clean
			mut dom_link := unsafe { &dom.HTMLLinkElement(element) }
			dom_link.linked_style_sheet_from_resource_ = true
			if link.explicitly_enabled_ {
				sheet.set_disabled(false)
			}
		}
	}
	if success {
		link.stylesheet_failed_ = false
		link.fire_event('load')
	} else {
		link.stylesheet_failed_ = true
		link.fire_event('error')
	}
	link.stylesheet_loading_ = false
	if element := link.element_ {
		mut dom_element := link_dom_element(element)
		mut document := unsafe { &dom.Document(dom_element.document()) }
		document.remove_from_script_blocking_style_sheet_set(dom_element)
		dom_element.unblock_rendering()
	}
	link.finished_loading_critical_style_subresources(link.stylesheet_failed_)
}

pub fn (mut link HTMLLinkElementModel) finished_loading_critical_style_subresources(_ bool) {
	link.stop_delaying_document_load_event()
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

pub fn (link &HTMLLinkElementModel) loaded_icon_url() ?dom.URL {
	return link.loaded_icon_url_
}

pub fn (link &HTMLLinkElementModel) preloaded_response() ?LinkResourceResponse {
	return link.preloaded_response_
}

pub fn (link &HTMLLinkElementModel) contributes_a_script_blocking_style_sheet() bool {
	return link.parser_inserted_ && link.was_enabled_when_created_
}

pub fn (link &HTMLLinkElementModel) is_implicitly_potentially_render_blocking() bool {
	return link.parser_inserted_
}

pub fn (mut link HTMLLinkElementModel) removed() {
	link.connected_ = false
	link.stylesheet_loading_ = false
	link.stop_delaying_document_load_event()
}

pub fn html_link_element_inserted(element &dom.HTMLLinkElement) {
	mut dom_element := link_dom_element(element)
	dom_element.inserted()
	if dom_element.document().get_browsing_context() == none {
		return
	}
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.connected_ = dom_element.as_node().is_browsing_context_connected()
	if model.should_fetch_and_process_resource_type() && model.connected_ {
		model.fetch_and_process_linked_resource()
	}
}

pub fn html_link_element_removed_from(element &dom.HTMLLinkElement, old_parent ?&dom.Node, old_root &dom.Node) {
	mut dom_element := link_dom_element(element)
	dom_element.removed_from(old_parent, old_root)
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	if model.loaded_style_sheet_ != none {
		model.loaded_style_sheet_ = none
		dom_element.unblock_rendering()
	}
	mut dom_link := unsafe { &dom.HTMLLinkElement(element) }
	dom_link.remove_linked_style_sheet()
	model.removed()
}

pub fn html_link_element_finished_loading_critical_style_subresources(element &dom.HTMLLinkElement, any_failed bool) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.finished_loading_critical_style_subresources(any_failed)
}

pub fn html_link_element_attribute_changed(element &dom.HTMLLinkElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := link_dom_element(element)
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	dom_element.attribute_changed(name, old_value, value, namespace_)
	if name == 'type' {
		// Element's actual attribute dispatch calls the model hook above.
		return
	}
	old_relations := link_relation_tokens(model.rel_)
	if name == 'rel' {
		model.rel_ = value or { '' }
	}
	if value == none && name == 'disabled' {
		model.explicitly_enabled_ = true
	}
	match name {
		'href' {
			model.href_ = value or { '' }
		}
		'media' {
			model.media_ = value or { '' }
		}
		'sizes' {
			model.sizes_ = value or { '' }
		}
		'crossorigin' {
			model.crossorigin_ = cors_setting_attribute_from_keyword(value)
		}
		'integrity' {
			if namespace_ == none { model.integrity_ = value or { '' } }
		}
		'as' {
			model.as_ = ascii_lowercase_string(value or { '' })
		}
		'referrerpolicy' {
			model.referrer_policy_ = ascii_lowercase_string(value or { '' })
		}
		'fetchpriority' {
			model.fetch_priority_ = ascii_lowercase_string(value or { '' })
		}
		'disabled' {
			model.disabled_ = value != none
		}
		else {}
	}
	if model.has_relation('stylesheet') && model.loaded_style_sheet_ != none {
		if name == 'disabled' {
			model.loaded_style_sheet_ = none
			mut dom_link := unsafe { &dom.HTMLLinkElement(element) }
			dom_link.remove_linked_style_sheet()
		} else if name == 'media' {
			mut dom_link := unsafe { &dom.HTMLLinkElement(element) }
			dom_link.set_linked_style_sheet_media(value or { '' })
		}
	}
	model.connected_ = dom_element.as_node().is_browsing_context_connected()
	if !model.should_fetch_and_process_resource_type() || !model.connected_ {
		return
	}
	mut should_fetch := name == 'href'
	if !should_fetch && (model.has_relation('preconnect') || model.has_relation('stylesheet')) {
		should_fetch = name == 'crossorigin'
	}
	if !should_fetch && model.has_relation('preload') {
		should_fetch = name == 'as'
	}
	if !should_fetch && model.has_relation('modulepreload') {
		should_fetch = name == 'rel' && 'modulepreload' !in old_relations
	}
	if !should_fetch && model.has_relation('stylesheet') {
		should_fetch = name == 'disabled' || 'stylesheet' !in old_relations
	}
	if should_fetch {
		model.fetch_and_process_linked_resource()
	}
}

pub fn html_link_element_create_link_options(element &dom.HTMLLinkElement) &LinkProcessingOptions {
	model := html_link_element_model_for_dom_element(element)
	return model.create_link_options()
}

pub fn html_link_element_create_link_request(element &dom.HTMLLinkElement, options &LinkProcessingOptions) ?&LinkRequest {
	model := html_link_element_model_for_dom_element(element)
	return model.create_link_request(options)
}

pub fn html_link_element_default_fetch_and_process_linked_resource(element &dom.HTMLLinkElement) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.default_fetch_and_process_linked_resource()
}

pub fn html_link_element_fetch_and_process_linked_dns_prefetch_resource(element &dom.HTMLLinkElement) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.fetch_and_process_linked_dns_prefetch_resource()
}

pub fn html_link_element_fetch_and_process_linked_preconnect_resource(element &dom.HTMLLinkElement) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.fetch_and_process_linked_preconnect_resource()
}

pub fn html_link_element_fetch_and_process_linked_preload_resource(element &dom.HTMLLinkElement) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.fetch_and_process_linked_preload_resource()
}

pub fn html_link_element_fetch_and_process_linked_modulepreload_resource(element &dom.HTMLLinkElement) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.fetch_and_process_linked_modulepreload_resource()
}

pub fn html_link_element_linked_resource_fetch_setup_steps(element &dom.HTMLLinkElement, mut request LinkRequest) bool {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	return model.linked_resource_fetch_setup_steps(mut request)
}

pub fn html_link_element_icon_linked_resource_fetch_setup_steps(element &dom.HTMLLinkElement, mut request LinkRequest) bool {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	return model.icon_linked_resource_fetch_setup_steps(mut request)
}

pub fn html_link_element_stylesheet_linked_resource_fetch_setup_steps(element &dom.HTMLLinkElement, mut request LinkRequest) bool {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	return model.stylesheet_linked_resource_fetch_setup_steps(mut request)
}

pub fn html_link_element_preconnect(element &dom.HTMLLinkElement, options &LinkProcessingOptions) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.preconnect(options)
}

pub fn html_link_element_preload(element &dom.HTMLLinkElement, mut options LinkProcessingOptions) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.preload(mut options)
}

pub fn html_link_element_process_icon_resource(element &dom.HTMLLinkElement, success bool, url dom.URL, body []u8) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.process_icon_resource(success, url, body)
}

pub fn html_link_element_process_stylesheet_resource(element &dom.HTMLLinkElement, success bool, response LinkResourceResponse) {
	mut model := unsafe { &HTMLLinkElementModel(html_link_element_model_for_dom_element(element)) }
	model.process_stylesheet_resource(success, response)
}

pub fn html_link_element_load_favicon_and_use_if_window_is_active(element &dom.HTMLLinkElement) bool {
	model := html_link_element_model_for_dom_element(element)
	data := model.loaded_icon() or { return false }
	url := model.loaded_icon_url() or { return false }
	return decode_favicon(data, url, link_dom_element(element).document()) or { false }
}

pub fn set_link_favicon_decode_hook(hook LinkFaviconDecodeHook) {
	link_favicon_decode_hook = hook
}

pub fn set_link_fallback_favicon_fetch_hook(hook LinkResourceFetchHook) {
	link_fallback_favicon_fetch_hook = hook
}

pub fn html_link_element_load_fallback_favicon_if_needed(document &dom.Document) {
	document_url := dom.URL{ value: document.url_string() }
	if document.has_active_favicon() || document_url.scheme() !in ['http', 'https'] {
		return
	}
	url := dom.dom_url_parse('/favicon.ico', document_url, document.encoding_or_default()) or {
		return
	}
	if link_fallback_favicon_fetch_hook != unsafe { nil } {
		link_fallback_favicon_fetch_hook(url, .icon, .use_credentials) or { return }
	}
}
