// Copyright (c) 2018-2025, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2021-2023, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2021-2026, Sam Atkins <sam@ladybird.org>
// Copyright (c) 2023-2024, Shannon Booth <shannon@serenityos.org>
// Copyright (c) 2025, Jelle Raaijmakers <jelle@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/DOM/Document.cpp
@[has_globals]
module dom

import platform
import rand
import math
import strings
import time as vtime
import highresolutiontime
import httpcookie
import url as liburl
import viewtransition
import webidl
import webdriver

pub type XPathCreateExpressionCallback = fn (string, ?&XPathNSResolver) !&XPathExpression

pub type XPathEvaluateCallback = fn (string, &Node, ?&XPathNSResolver, u16, ?&XPathResult) !&XPathResult

pub type CustomElementDefinitionLookupCallback = fn (voidptr, ?string, string, ?string) ?&CustomElementDefinition

pub type CustomElementRegistryIsScopedCallback = fn (voidptr) bool

pub type CustomElementRegistryAppendDocumentCallback = fn (voidptr, &Document)

pub type GlobalCustomElementRegistryFactory = fn (&Document) voidptr

pub struct XPathBridge {
pub:
	create_expression XPathCreateExpressionCallback = unsafe { nil }
	evaluate          XPathEvaluateCallback = unsafe { nil }
}

__global (
	dom_all_navigables                          = []&Navigable{}
	dom_url_record_cache                        = map[string]&URLRecordSnapshot{}
	dom_xpath_bridge                            &XPathBridge
	dom_custom_element_definition_lookup        CustomElementDefinitionLookupCallback
	dom_custom_element_registry_is_scoped       CustomElementRegistryIsScopedCallback
	dom_custom_element_registry_append_document CustomElementRegistryAppendDocumentCallback
	dom_global_custom_element_registry_factory GlobalCustomElementRegistryFactory
	dom_element_activation_behavior_hooks       ElementActivationBehaviorHooks
	dom_style_sheet_scope_hooks                 StyleSheetScopeHooks
	dom_run_focusing_steps                      RunFocusingStepsCallback
)

// Simple color representation
pub struct Color {
pub mut:
	r u8
	g u8
	b u8
	a u8
}

pub type NodeLoadEventDelayCallback = fn (voidptr) bool

pub struct NodeLoadEventDelayHook {
pub:
	target   voidptr
	callback NodeLoadEventDelayCallback = unsafe { nil }
}

pub type NodeActiveWindowProxyCallback = fn (voidptr) ?&WindowProxy

pub type ViewportClientDidSetRectCallback = fn (voidptr, Rect)

pub struct ViewportClient {
pub:
	target                voidptr
	did_set_viewport_rect ViewportClientDidSetRectCallback = unsafe { nil }
}

pub fn (a ViewportClient) ==(b ViewportClient) bool {
	return a.target == b.target
}

// HTML owns navigable-container state, while DOM owns the named-property
// algorithm on Document. This hook exposes precisely the WindowProxy result
// needed by Document::named_item_value without creating a DOM -> HTML cycle.
pub struct NodeActiveWindowProxyHook {
pub:
	target   voidptr
	callback NodeActiveWindowProxyCallback = unsafe { nil }
}

pub type NodeAdoptedFromCallback = fn (voidptr, &Document)

// HTML element subclasses install this hook for adopting steps that own
// state outside the DOM module.
pub struct NodeAdoptedFromHook {
pub:
	target   voidptr
	callback NodeAdoptedFromCallback = unsafe { nil }
}

pub enum NodeIsSubtreeRoot {
	no
	yes
}

pub type NodeRemovedFromCallback = fn (voidptr, NodeIsSubtreeRoot, ?&Node, &Node)

pub type NodeMovedFromCallback = fn (voidptr, NodeIsSubtreeRoot, ?&Node)

// HTML element subclasses own several removing and moving algorithms. This
// hook preserves the DOM lifecycle arguments without introducing a DOM -> HTML
// module dependency.
pub struct NodeLifecycleHook {
pub:
	target       voidptr
	removed_from NodeRemovedFromCallback = unsafe { nil }
	moved_from   NodeMovedFromCallback = unsafe { nil }
}

pub const color_transparent = Color{0, 0, 0, 0}

pub fn (c Color) alpha() u8 {
	return c.a
}

// Compact URL representation used by the DOM layer.
pub struct URL {
pub mut:
	value string
mut:
	record_ &URLRecordSnapshot = unsafe { nil }
}

pub type URLFinishParsingHook = fn (liburl.URL) liburl.URL

__global dom_url_finish_parsing_hook URLFinishParsingHook

// HTML installs LibWeb DOMURL's actual finish step across the import cycle.
pub fn set_url_finish_parsing_hook(hook URLFinishParsingHook) {
	dom_url_finish_parsing_hook = hook
}

pub fn url_about_blank() URL {
	return URL{value: 'about:blank'}
}

pub fn (u URL) to_string() string {
	return u.serialize()
}

pub fn (u URL) serialize() string {
	snapshot := u.parsed_snapshot() or { return u.value }
	return snapshot.source.clone()
}

pub fn dom_url_parse(url string, base_url URL, encoding string) ?URL {
	// LibURL accepts an encoding for query parsing. The translated parser is
	// UTF-8 based, which is the forced encoding for non-special URLs and ws/wss;
	// callers currently pass UTF-8 for browser navigation.
	_ = encoding
	base := base_url.parsed() or { return none }
	mut parsed := liburl.parse_with_base(url, base) or { return none }
	if parsed.scheme == 'blob' && dom_url_finish_parsing_hook != unsafe { nil } {
		parsed = dom_url_finish_parsing_hook(parsed)
	}
	return url_from_record(parsed)
}

pub fn (a URL) ==(b URL) bool {
	return a.serialize() == b.serialize()
}

pub fn (u URL) fragment() ?string {
	parsed := u.parsed() or { return none }
	return parsed.fragment
}

pub fn (mut u URL) set_fragment(fragment ?string) {
	parsed := u.parsed() or { return }
	u = url_from_record(parsed.with_fragment(fragment))
}

pub fn url_from_record(record liburl.URL) URL {
	serialized := url_snapshot_source(record, none)
	return URL{
		value: serialized
		record_: &URLRecordSnapshot{ source: serialized, record: record.copy() }
	}
}

// Parsed DOM URLs own their actual value record. The serialized compatibility
// constructor still uses the basic-parser cache; it never receives another
// instance's Blob entry. Direct public value edits cannot reuse a stale record.
pub fn (u URL) parsed() ?liburl.URL {
	snapshot := u.parsed_snapshot() or { return none }
	return snapshot.record.copy()
}

pub fn (u URL) has_an_opaque_path() bool {
	snapshot := u.parsed_snapshot() or { return false }
	return snapshot.record.has_an_opaque_path
}

pub fn (u URL) cannot_have_a_username_or_password_or_port() bool {
	snapshot := u.parsed_snapshot() or { return true }
	return snapshot.record.cannot_have_a_username_or_password_or_port()
}

// URL's scheme, without the trailing ":".
pub fn (u URL) scheme() string {
	snapshot := u.parsed_snapshot() or { return '' }
	return snapshot.record.scheme
}

pub fn (u URL) username() string {
	snapshot := u.parsed_snapshot() or { return '' }
	return snapshot.record.username
}

pub fn (u URL) password() string {
	snapshot := u.parsed_snapshot() or { return '' }
	return snapshot.record.password
}

// URL's host, serialized (host without the port). Empty string when there is no host.
pub fn (u URL) serialized_host() string {
	snapshot := u.parsed_snapshot() or { return '' }
	host := snapshot.record.host or { return '' }
	return host.serialize()
}

// URL's host, or none when the URL has no host.
pub fn (u URL) host() ?string {
	serialized := u.serialized_host()
	return if serialized == '' { none } else { serialized }
}

// URL's port, or none when the URL has no explicit port.
pub fn (u URL) port() ?u16 {
	snapshot := u.parsed_snapshot() or { return none }
	return snapshot.record.port
}

// URL path serialized.
pub fn (u URL) serialize_path() string {
	snapshot := u.parsed_snapshot() or { return '' }
	return snapshot.record.serialize_path()
}

pub fn (u URL) basename() string {
	snapshot := u.parsed_snapshot() or { return '' }
	return snapshot.record.basename()
}

// URL's query, without the leading "?", or none when there is no query.
pub fn (u URL) query() ?string {
	snapshot := u.parsed_snapshot() or { return none }
	return snapshot.record.query
}

// --- WHATWG-URL component setters ---

// scheme start state override: replaces the scheme (a trailing ":" is stripped).
pub fn (u URL) with_protocol(protocol string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_scheme(protocol))
}

pub fn (u URL) with_username(username string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_username(username))
}

pub fn (u URL) with_password(password string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_password(password))
}

// host state override: the value may include a port ("host[:port]").
pub fn (u URL) with_host(host string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_host(host, false))
}

// hostname state override: replaces only the host, preserving any existing port.
pub fn (u URL) with_hostname(hostname string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_host(hostname, true))
}

// port state override: an empty value clears the port.
pub fn (u URL) with_port(port string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_port(port))
}

pub fn (u URL) with_pathname(pathname string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_path(pathname))
}

// query state override: the value is the query without a leading "?".
pub fn (u URL) with_query(query ?string) URL {
	parsed := u.parsed() or { return u }
	return url_from_record(parsed.with_query(query))
}

// https://url.spec.whatwg.org/#concept-url-origin
pub fn (u URL) origin() Origin {
	snapshot := u.parsed_snapshot() or { return origin_create_opaque() }
	return origin_from_liburl(snapshot.record.origin())
}

// DOM-facing representation of LibURL::Origin. `value` remains public for the
// translated serialization boundaries, while `typed` preserves tuple fields
// and, critically, the nonce identity of opaque origins.
pub struct Origin {
pub mut:
	value string
mut:
	typed ?liburl.Origin
}

pub fn origin_create_opaque() Origin {
	return origin_from_liburl(liburl.Origin.create_opaque(.standard))
}

pub fn origin_create_opaque_file() Origin {
	return origin_from_liburl(liburl.Origin.create_opaque(.file))
}

pub fn origin_from_tuple(scheme string, host string, port ?u16) Origin {
	return origin_from_liburl(liburl.Origin.tuple(scheme, liburl.Host.from_string(host), port, none))
}

pub fn origin_from_liburl(record liburl.Origin) Origin {
	return Origin{
		value: if record.is_opaque() { 'opaque' } else { record.serialize() }
		typed: record
	}
}

pub fn origin_from_ipc(value string) Origin {
	if value.starts_with('opaque:') || value.starts_with('opaque-file:') {
		prefix := if value.starts_with('opaque-file:') { 'opaque-file:' } else { 'opaque:' }
		hex := value[prefix.len..]
		if hex.len == 32 {
			mut nonce := [16]u8{}
			mut valid := true
			for index in 0 .. 16 {
				high := hex_digit_value(hex[index * 2]) or {
					valid = false
					break
				}
				low := hex_digit_value(hex[index * 2 + 1]) or {
					valid = false
					break
				}
				nonce[index] = (high << 4) | low
			}
			if valid {
				return origin_from_liburl(liburl.Origin.opaque(nonce, if prefix == 'opaque-file:' {
					liburl.OpaqueOriginType.file
				} else {
					liburl.OpaqueOriginType.standard
				}))
			}
		}
	}
	return Origin{ value: value }
}

pub fn (o Origin) serialize_for_ipc() string {
	if typed := o.typed {
		if opaque := typed.opaque_data() {
			mut hex := ''
			for byte in opaque.nonce {
				hex += '${byte:02x}'
			}
			prefix := if opaque.type_ == .file { 'opaque-file:' } else { 'opaque:' }
			return prefix + hex
		}
		return typed.serialize()
	}
	return o.value
}

pub fn (o Origin) liburl_origin() ?liburl.Origin {
	if typed := o.typed {
		return typed
	}
	if o.value in ['', 'opaque', 'opaque-file', 'null'] {
		return none
	}
	parsed := liburl.parse(o.value) or { return none }
	record := parsed.origin()
	if record.is_opaque() {
		return none
	}
	return record
}

pub fn (o Origin) is_opaque() bool {
	if typed := o.typed {
		return typed.is_opaque()
	}
	return o.value in ['', 'opaque', 'opaque-file', 'null']
}

pub fn (o Origin) is_opaque_file_origin() bool {
	if typed := o.typed {
		return typed.is_opaque_file_origin()
	}
	return o.value == 'opaque-file'
}

pub fn (o Origin) serialize() string {
	if typed := o.typed {
		return typed.serialize()
	}
	return if o.is_opaque() { 'null' } else { o.value }
}

pub fn (a Origin) is_same_origin(b Origin) bool {
	first := a.liburl_origin() or { return false }
	second := b.liburl_origin() or { return false }
	return first.is_same_origin(second)
}

pub fn (a Origin) is_same_origin_domain(b Origin) bool {
	first := a.liburl_origin() or { return false }
	second := b.liburl_origin() or { return false }
	return first.is_same_origin_domain(second)
}

pub fn (a Origin) is_same_site(b Origin) bool {
	first := a.liburl_origin() or { return false }
	second := b.liburl_origin() or { return false }
	return first.is_same_site(second)
}

pub fn (a Origin) ==(b Origin) bool {
	return a.is_same_origin(b)
}

// Stub pointer-like wrapper
pub struct Ptr[T] {
mut:
	inner ?&T
}

pub fn (p Ptr[T]) ptr() ?&T {
	return p.inner
}

pub fn (p Ptr[T]) is_null() bool {
	return p.inner == none
}

// Stub ref-counted wrapper
pub struct Ref[T] {
mut:
	inner &T
}

// Stub weak pointer
pub struct WeakPtr[T] {
mut:
	inner ?&T
}

// Node base. The behavioral translation lives in node.v.
@[heap]
pub struct Node {
	EventTarget
pub mut:
	node_type        NodeType
	document_        &Document = unsafe { nil }
	parent_          &Node = unsafe { nil }
	index_in_parent_ int = -1
	children         []&Node

	child_nodes_ &NodeList = unsafe { nil }
	layout_node_ &LayoutNode = unsafe { nil }
	paintable_   &Paintable = unsafe { nil }

	needs_layout_tree_update                           bool
	child_needs_layout_tree_update                     bool
	needs_style_update_                                bool
	child_needs_style_update_                          bool
	entire_subtree_needs_style_update_                 bool
	has_child_affected_by_backward_structural_changes_ bool
	in_editable_subtree_                               bool
	is_connected_                                      bool

	unique_id_                UniqueNodeID
mut:
	hooks_ &NodeHooks = unsafe { nil }
	cold_data_ &NodeColdData = unsafe { nil }
}

// Translation of the ParentNode mixin; its algorithms live in
// collections_ranges.v alongside the collection and selector machinery.
@[heap]
pub struct ParentNode {
	Node
pub mut:
	children_ &HTMLCollection = unsafe { nil }
}

// Element is defined in element.v

// Concrete HTML element storage shared with the HTML-side behavioral models.
@[heap]
pub struct HTMLHtmlElement {
	HTMLElement
}

@[heap]
pub struct HTMLHeadElement {
	HTMLElement
}

@[heap]
pub struct HTMLTitleElement {
	HTMLElement
}

@[heap]
pub struct HTMLElement {
	Element
mut:
	html_rare_data_ &HTMLElementRareData = unsafe { nil }
}

pub enum PopoverVisibilityState {
	hidden
	showing
}

@[heap]
pub struct HTMLBodyElement {
	HTMLElement
pub mut:
	background_url_ ?URL
}

@[heap]
pub struct HTMLBaseElement {
	HTMLElement
pub mut:
	frozen_base_url_             URL
	frozen_base_url_initialized_ bool
}

@[heap]
pub struct HTMLScriptElement {
	HTMLElement
pub mut:
	script_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLDialogElement {
	HTMLElement
pub mut:
	return_value_                           string
	is_modal_                               bool
	request_close_return_value_             ?string
	request_close_source_element_           ?&Element
	close_watcher_                          voidptr = unsafe { nil }
	enable_close_watcher_for_request_close_ bool
	dialog_toggle_task_id_                  u64
	dialog_toggle_old_state_                string
	previously_focused_element_             ?&Node
}

@[heap]
pub struct HTMLUnknownElement {
	HTMLElement
}

@[heap]
pub struct HTMLAreaElement {
	HTMLElement
pub mut:
	rel_list_ ?&DOMTokenList
}

@[heap]
pub struct HTMLAudioElement {
	HTMLElement
pub mut:
	media_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLBRElement {
	HTMLElement
}

@[heap]
pub struct HTMLButtonElement {
	HTMLElement
pub mut:
	command_for_element_  ?&Element
	button_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLCanvasElement {
	HTMLElement
}

@[heap]
pub struct HTMLDataElement {
	HTMLElement
}

@[heap]
pub struct HTMLDataListElement {
	HTMLElement
pub mut:
	options_ ?&HTMLCollection
}

@[heap]
pub struct HTMLDetailsElement {
	HTMLElement
pub mut:
	details_toggle_task_id_   u64
	details_toggle_old_state_ string
	summary_slot_             ?&HTMLSlotElement
	descendants_slot_         ?&HTMLSlotElement
}

@[heap]
pub struct HTMLDirectoryElement {
	HTMLElement
}

@[heap]
pub struct HTMLDivElement {
	HTMLElement
}

@[heap]
pub struct HTMLDListElement {
	HTMLElement
}

@[heap]
pub struct HTMLEmbedElement {
	HTMLElement
}

@[heap]
pub struct HTMLFontElement {
	HTMLElement
}

@[heap]
pub struct HTMLFormElement {
	HTMLElement
pub mut:
	associated_elements_ []&Element
}

@[heap]
pub struct HTMLFrameElement {
	HTMLElement
pub mut:
	frame_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLFrameSetElement {
	HTMLElement
}

@[heap]
pub struct HTMLHeadingElement {
	HTMLElement
}

@[heap]
pub struct HTMLHRElement {
	HTMLElement
}

@[heap]
pub struct HTMLIFrameElement {
	HTMLElement
pub mut:
	iframe_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLLabelElement {
	HTMLElement
pub mut:
	click_in_progress_ bool
}

@[heap]
pub struct HTMLLIElement {
	HTMLElement
}

pub type HTMLLinkHasLoadedIconCallback = fn (voidptr) bool

pub type HTMLLinkLoadFaviconCallback = fn (voidptr) bool

@[heap]
pub struct HTMLLinkElement {
	HTMLElement
pub mut:
	link_element_model_            voidptr = unsafe { nil }
	link_has_loaded_icon_callback_ HTMLLinkHasLoadedIconCallback = unsafe { nil }
	link_load_favicon_callback_    HTMLLinkLoadFaviconCallback   = unsafe { nil }
	// LinkStyle::sheet is CSS-owned, as with StyleElementBase's sheet.
	linked_style_sheet_               voidptr
	linked_style_sheet_scope_         ?&Node
	linked_style_sheet_from_resource_ bool
}

pub fn (mut link HTMLLinkElement) set_linked_style_sheet_media(media string) {
	if link.linked_style_sheet_ != unsafe { nil }
		&& dom_style_sheet_scope_hooks.set_media != unsafe { nil } {
		dom_style_sheet_scope_hooks.set_media(link.linked_style_sheet_, media)
	}
}

pub fn (mut link HTMLLinkElement) remove_linked_style_sheet() {
	if scope := link.linked_style_sheet_scope_ {
		if link.linked_style_sheet_ != unsafe { nil }
			&& dom_style_sheet_scope_hooks.remove_a_css_style_sheet != unsafe { nil } {
			dom_style_sheet_scope_hooks.remove_a_css_style_sheet(scope, link.linked_style_sheet_)
		}
	}
	link.linked_style_sheet_ = unsafe { nil }
	link.linked_style_sheet_scope_ = none
	link.linked_style_sheet_from_resource_ = false
}

pub fn (link &HTMLLinkElement) has_loaded_icon() bool {
	if link.link_element_model_ == unsafe { nil } || link.link_has_loaded_icon_callback_ == unsafe { nil } {
		return false
	}
	return link.link_has_loaded_icon_callback_(link.link_element_model_)
}

pub fn (link &HTMLLinkElement) load_favicon_and_use_if_window_is_active() bool {
	if link.link_element_model_ == unsafe { nil } || link.link_load_favicon_callback_ == unsafe { nil } {
		return false
	}
	return link.link_load_favicon_callback_(link.link_element_model_)
}

fn html_link_element_from_node(node &Node) &HTMLLinkElement {
	return unsafe { &HTMLLinkElement(node) }
}

fn collect_loaded_favicon_link_elements(node &Node, mut result []&HTMLLinkElement) {
	if node.is_html_link_element() {
		link := html_link_element_from_node(node)
		if link.has_loaded_icon() {
			result << link
		}
	}
	for child in node.children_as_vector() {
		collect_loaded_favicon_link_elements(child, mut result)
	}
}

@[heap]
pub struct HTMLMapElement {
	HTMLElement
pub mut:
	areas_ ?&HTMLCollection
}

@[heap]
pub struct HTMLMarqueeElement {
	HTMLElement
}

@[heap]
pub struct HTMLMenuElement {
	HTMLElement
}

@[heap]
pub struct HTMLMetaElement {
	HTMLElement
}

@[heap]
pub struct HTMLMeterElement {
	HTMLElement
pub mut:
	meter_value_element_ ?&Element
	cached_value_state_  u8
}

@[heap]
pub struct HTMLModElement {
	HTMLElement
}

@[heap]
pub struct HTMLObjectElement {
	HTMLElement
pub mut:
	object_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLOListElement {
	HTMLElement
}

@[heap]
pub struct HTMLOptGroupElement {
	HTMLElement
}

@[heap]
pub struct HTMLOptionElement {
	HTMLElement
pub mut:
	selected_                      bool
	dirty_                         bool
	selectedness_update_index_     u64
	selectedness_initialized_      bool
	cached_nearest_select_element_ ?&HTMLSelectElement
	label_changed_hook_            ?OptionElementLabelChangedHook
}

pub type OptionElementLabelChangedHook = fn (&HTMLOptionElement)

@[heap]
pub struct HTMLOutputElement {
	HTMLElement
pub mut:
	output_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLParagraphElement {
	HTMLElement
}

@[heap]
pub struct HTMLParamElement {
	HTMLElement
}

@[heap]
pub struct HTMLPictureElement {
	HTMLElement
}

@[heap]
pub struct HTMLPreElement {
	HTMLElement
}

@[heap]
pub struct HTMLProgressElement {
	HTMLElement
pub mut:
	progress_value_element_ ?&Element
}

@[heap]
pub struct HTMLQuoteElement {
	HTMLElement
}

@[heap]
pub struct HTMLSelectedContentElement {
	HTMLElement
pub mut:
	disabled_ bool
}

@[heap]
pub struct HTMLSourceElement {
	HTMLElement
}

@[heap]
pub struct HTMLSpanElement {
	HTMLElement
}

@[heap]
pub struct HTMLStyleElement {
	HTMLElement
}

@[heap]
pub struct HTMLSummaryElement {
	HTMLElement
}

@[heap]
pub struct HTMLTableCaptionElement {
	HTMLElement
}

@[heap]
pub struct HTMLTableCellElement {
	HTMLElement
}

@[heap]
pub struct HTMLTableColElement {
	HTMLElement
}

@[heap]
pub struct HTMLTableRowElement {
	HTMLElement
}

@[heap]
pub struct HTMLTableSectionElement {
	HTMLElement
}

@[heap]
pub struct HTMLTemplateElement {
	HTMLElement
mut:
	template_content &DocumentFragment = unsafe { nil }
}

// https://html.spec.whatwg.org/multipage/scripting.html#dom-template-content
// The template's contents: a DocumentFragment that holds the template's parsed children (the
// template element itself stays empty in the tree). Created lazily on first access.
pub fn (t &HTMLTemplateElement) content() &DocumentFragment {
	if isnil(t.template_content) {
		mut node_document := unsafe { &Document(t.document()) }
		owner_document := node_document.appropriate_template_contents_owner_document()
		frag := new_document_fragment(owner_document)
		mut mutable_fragment := unsafe { &DocumentFragment(frag) }
		mutable_fragment.set_host(unsafe { &Element(t) })
		unsafe {
			mut mutable_self := &HTMLTemplateElement(t)
			mutable_self.template_content = frag
		}
	}
	return t.template_content
}

pub fn html_template_element_adopted_from(template &HTMLTemplateElement, _ &Document) {
	mut node_document := unsafe { &Document(template.document()) }
	mut owner_document := node_document.appropriate_template_contents_owner_document()
	content := template.content()
	owner_document.adopt_node(content.as_node())
	// Keep the concrete embedded DocumentFragment storage in sync with Node's
	// adopting steps; this avoids losing the write through a temporary base view.
	mut mutable_content := unsafe { &DocumentFragment(content) }
	mutable_content.document_ = owner_document
}

pub fn html_template_element_cloned(template &HTMLTemplateElement, copy &Node, subtree bool) ! {
	if !subtree {
		return
	}
	copy_element := copy.as_element() or {
		return error('InvalidStateError: Template clone is not an element')
	}
	template_copy := unsafe { &HTMLTemplateElement(copy_element) }
	copy_content := template_copy.content()
	for child in template.content().as_node().children_as_vector() {
		child.clone_node(copy_content.as_node().document(), true, copy_content.as_node())!
	}
}

pub fn html_template_element_content_for_bindings(template &HTMLTemplateElement) &DocumentFragment {
	return template.content()
}

pub fn html_template_element_set_template_contents(template &HTMLTemplateElement, contents &DocumentFragment) {
	mut mutable_template := unsafe { &HTMLTemplateElement(template) }
	mutable_template.template_content = contents
}

@[heap]
pub struct HTMLTextAreaElement {
	HTMLElement
pub mut:
	text_area_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct HTMLTimeElement {
	HTMLElement
}

@[heap]
pub struct HTMLTrackElement {
	HTMLElement
pub mut:
	track_element_model_ voidptr = unsafe { nil }
	track_attribute_changed_hook_ ?TrackElementAttributeChangedHook
}

// HTML installs this on the actual lazy track owner without introducing a
// DOM-to-HTML package dependency. It travels with the element on adoption.
pub type TrackElementAttributeChangedHook = fn (&HTMLTrackElement, string, ?string)

@[heap]
pub struct HTMLUListElement {
	HTMLElement
}

@[heap]
pub struct HTMLVideoElement {
	HTMLElement
pub mut:
	media_element_model_ voidptr = unsafe { nil }
	video_element_model_ voidptr = unsafe { nil }
	video_poster_attribute_changed_hook_ ?VideoPosterAttributeChangedHook
}

// Installed by HTML on the lazy video owner; retained across document adoption.
pub type VideoPosterAttributeChangedHook = fn (&HTMLVideoElement, ?string)

@[heap]
pub struct SVGElement {
	Element
}

@[heap]
pub struct SVGAnimationElement {
	SVGElement
}

@[heap]
pub struct SVGSVGElement {
	SVGElement
}

@[heap]
pub struct SVGClipPathElement {
	SVGElement
}

@[heap]
pub struct SVGCircleElement {
	SVGElement
}

@[heap]
pub struct SVGDefsElement {
	SVGElement
}

@[heap]
pub struct SVGDescElement {
	SVGElement
}

@[heap]
pub struct SVGEllipseElement {
	SVGElement
}

@[heap]
pub struct SVGFEBlendElement {
	SVGElement
}

@[heap]
pub struct SVGFEColorMatrixElement {
	SVGElement
}

@[heap]
pub struct SVGFEComponentTransferElement {
	SVGElement
}

@[heap]
pub struct SVGFECompositeElement {
	SVGElement
}

@[heap]
pub struct SVGFEDisplacementMapElement {
	SVGElement
}

@[heap]
pub struct SVGFEDropShadowElement {
	SVGElement
}

@[heap]
pub struct SVGFEFloodElement {
	SVGElement
}

@[heap]
pub struct SVGFEFuncAElement {
	SVGElement
}

@[heap]
pub struct SVGFEFuncBElement {
	SVGElement
}

@[heap]
pub struct SVGFEFuncGElement {
	SVGElement
}

@[heap]
pub struct SVGFEFuncRElement {
	SVGElement
}

@[heap]
pub struct SVGFEGaussianBlurElement {
	SVGElement
}

@[heap]
pub struct SVGFEImageElement {
	SVGElement
}

@[heap]
pub struct SVGFEMergeElement {
	SVGElement
}

@[heap]
pub struct SVGFEMergeNodeElement {
	SVGElement
}

@[heap]
pub struct SVGFEMorphologyElement {
	SVGElement
}

@[heap]
pub struct SVGFEOffsetElement {
	SVGElement
}

@[heap]
pub struct SVGFETurbulenceElement {
	SVGElement
}

@[heap]
pub struct SVGFilterElement {
	SVGElement
}

@[heap]
pub struct SVGForeignObjectElement {
	SVGElement
}

@[heap]
pub struct SVGLineElement {
	SVGElement
}

@[heap]
pub struct SVGLinearGradientElement {
	SVGElement
}

@[heap]
pub struct SVGMaskElement {
	SVGElement
}

@[heap]
pub struct SVGMetadataElement {
	SVGElement
}

@[heap]
pub struct SVGPathElement {
	SVGElement
}

@[heap]
pub struct SVGPatternElement {
	SVGElement
}

@[heap]
pub struct SVGPolygonElement {
	SVGElement
}

@[heap]
pub struct SVGPolylineElement {
	SVGElement
}

@[heap]
pub struct SVGRadialGradientElement {
	SVGElement
}

@[heap]
pub struct SVGRectElement {
	SVGElement
}

@[heap]
pub struct SVGGElement {
	SVGElement
}

@[heap]
pub struct SVGStopElement {
	SVGElement
}

@[heap]
pub struct SVGStyleElement {
	SVGElement
}

@[heap]
pub struct SVGSymbolElement {
	SVGElement
}

@[heap]
pub struct SVGTextElement {
	SVGElement
}

@[heap]
pub struct SVGTextPathElement {
	SVGElement
}

@[heap]
pub struct SVGTitleElement {
	SVGElement
}

@[heap]
pub struct SVGTSpanElement {
	SVGElement
}

@[heap]
pub struct SVGUseElement {
	SVGElement
}

@[heap]
pub struct SVGScriptElement {
	SVGElement
pub mut:
	script_element_model_ voidptr = unsafe { nil }
}

@[heap]
pub struct SVGViewElement {
	SVGElement
}

@[heap]
pub struct SVGAElement {
	SVGElement
}

@[heap]
pub struct SVGImageElement {
	SVGElement
}

@[heap]
pub struct MathMLElement {
	Element
}

@[heap]
pub struct MathMLMiElement {
	MathMLElement
}

@[heap]
pub struct MathMLMspaceElement {
	MathMLElement
}

// DocumentType stub
@[heap]
pub struct DocumentType {
	Node
pub mut:
	name_      string
	public_id_ string
	system_id_ string
}

// Layout stubs
@[heap]
pub struct LayoutViewport {
pub mut:
	root_node       &LayoutNode = unsafe { nil }
	scrollbar_width string = 'auto'
}

pub fn (viewport &LayoutViewport) root_layout_node() ?&LayoutNode {
	if viewport.root_node == unsafe { nil } {
		return none
	}
	return viewport.root_node
}

pub type LayoutApplyStyleCallback = fn (voidptr, voidptr)

// Reports whether the embedder's retained paint transport took ownership of
// the compositor-only sample (instead of an ordinary style application).
pub type LayoutApplyAnimatedStyleCallback = fn (voidptr, voidptr) bool

pub type LayoutApplyColorStyleCallback = fn (voidptr, voidptr) bool

pub type LayoutSetNeedsLayoutUpdateCallback = fn (voidptr, bool)

pub type LayoutInvalidateTextForRenderingCallback = fn (voidptr)

pub struct VisualCaretStop {
pub:
	offset            int
	inline_coordinate f64
}

// A retained projection of one rendered line for a DOM Text node. Layout
// materializes this from committed geometry when a caret consumer requests it.
pub struct VisualLine {
pub:
	start_offset                        int
	end_offset                          int
	end_offset_with_trailing_whitespace int
	has_fragments                       bool
	owner_paintable                     u32
	line_index                          u32
	caret_stops                         []VisualCaretStop
}

@[heap]
pub struct LayoutNode {
pub mut:
	dom_node_                                       ?&Node
	parent_                                         ?&LayoutNode
	containing_block_                               ?&LayoutNode
	children_                                       []&LayoutNode
	is_anonymous_                                   bool
	is_text_node_                                   bool
	text_has_source_range_                          bool
	is_atomic_inline_                               bool
	is_replaced_box_                                bool
	display_                                        CSSDisplay_
	has_geometry_                                   bool
	is_viewport_                                    bool
	is_positioned_                                  bool
	is_sticky_position_                             bool
	is_fixed_position_                              bool
	is_scroll_container_                            bool
	establishes_fixed_positioning_containing_block_ bool
	overflow_x_                                     CSSOverflow_ = .visible
	visibility_                                     CSSVisibility_ = .visible
	content_visibility_                             CSSContentVisibility_ = .visible
	user_select_none_                               bool
	white_space_collapse_is_not_collapse_           bool
	needs_layout_update_                            bool
	is_editing_host_                                bool
	is_editable_or_editing_host_                    bool
	rendered_text_                                  string
	rendered_text_chunks_data_ &LayoutRenderedTextChunks = unsafe { nil }
	visual_lines_data_ &LayoutVisualLines = unsafe { nil }
	rare_data_ &LayoutNodeRareData = unsafe { nil }
	visual_lines_callback                           fn (voidptr) []VisualLine = unsafe { nil }
	paintables_                                     []&Paintable
	border_box_                                     Rect
	content_width_                                  f64
	content_height_                                 f64
	box_model_ &LayoutBoxModel = unsafe { nil }
	used_grid_data_ &LayoutGridData = unsafe { nil }
	// dom<->layout bridge: opaque handle to the real layout.Node this placeholder mirrors (dom can't
	// name the layout type). The layout module attaches these via attach_layout_nodes. See layout/dom_layout_bridge.v.
	layout_handle                    voidptr = unsafe { nil }
	callbacks_ &LayoutNodeCallbacks = unsafe { nil }
}

// The DOM/layout boundary needs resolved tracks only for grid containers.
// Publish a replacement record so value copies of LayoutNode retain their
// previous array headers, just as they did with inline fields.
pub struct LayoutGridData {
pub:
	columns             []f64
	rows                []f64
	column_line_names   [][]string
	row_line_names      [][]string
	columns_are_subgrid bool
	rows_are_subgrid    bool
}

pub fn (n &LayoutNode) used_grid_data() LayoutGridData {
	if n.used_grid_data_ == unsafe { nil } {
		return LayoutGridData{}
	}
	return *n.used_grid_data_
}

pub fn (mut n LayoutNode) set_used_grid_data(data LayoutGridData) {
	if data.columns.len == 0 && data.rows.len == 0
		&& data.column_line_names.len == 0 && data.row_line_names.len == 0
		&& !data.columns_are_subgrid && !data.rows_are_subgrid {
		n.used_grid_data_ = unsafe { nil }
		return
	}
	n.used_grid_data_ = &LayoutGridData{...data}
}

pub type SVGRelayoutCallback = fn (&SVGSVGBox)

@[heap]
pub struct SVGSVGBox {
pub mut:
	relayout_callback SVGRelayoutCallback = unsafe { nil }
}

pub type ViewportPaintableVoidCallback = fn (voidptr)

pub type ViewportPaintableRangeCallback = fn (voidptr, &Range)

pub type ViewportPaintableTextRangeRectsCallback = fn (voidptr, &Node, SelectionState, int, int) []DOMRect

pub type ViewportPaintableTransformClientRectsCallback = fn (voidptr, &Node, []CSSPixelRect_) []CSSPixelRect_

pub type ViewportPaintableScrollIntoViewGeometryCallback = fn (voidptr, &Node) ?ScrollIntoViewGeometry

pub type ViewportPaintableSelectionCallback = fn (voidptr) ?&Selection

pub type ViewportPaintableRecordDisplayListCallback = fn (voidptr) &DisplayList

pub type ViewportPaintableStackingContextCallback = fn (voidptr) &StackingContext

pub type ViewportPaintableHitTestCallback = fn (voidptr, f64, f64, HitTestType) ?HitTestResult

pub type ViewportPaintableHitTestAllCallback = fn (voidptr, f64, f64) []&Element

pub type ViewportPaintableLayoutQueryCallback = fn (voidptr, voidptr) bool

pub type DisplayListDumpCallback = fn (voidptr) string

// Painting is downstream of DOM, so the concrete viewport paintable and
// display list are retained behind callbacks instead of introducing a module
// cycle. Layout/Painting installs these callbacks when it commits a layout.
@[heap]
pub struct ViewportPaintable {
pub:
	target                                      voidptr = unsafe { nil }
	document                                    &Document = unsafe { nil }
	invalidate_scroll_state_callback            ViewportPaintableVoidCallback = unsafe { nil }
	refresh_scroll_state_callback               ViewportPaintableVoidCallback = unsafe { nil }
	assign_accumulated_visual_contexts_callback ViewportPaintableVoidCallback = unsafe { nil }
	refresh_compositor_visual_contexts_callback ViewportPaintableVoidCallback = unsafe { nil }
	selection_callback                          ViewportPaintableSelectionCallback = unsafe { nil }
	recompute_selection_states_callback         ViewportPaintableRangeCallback = unsafe { nil }
	text_range_rects_callback                   ViewportPaintableTextRangeRectsCallback = unsafe { nil }
	transform_client_rects_callback             ViewportPaintableTransformClientRectsCallback = unsafe { nil }
	scroll_into_view_geometry_callback          ViewportPaintableScrollIntoViewGeometryCallback = unsafe { nil }
	set_needs_repaint_callback                  ViewportPaintableVoidCallback = unsafe { nil }
	document_set_needs_repaint_callback         ViewportPaintableVoidCallback = unsafe { nil }
	invalidate_all_paint_caches_callback        ViewportPaintableVoidCallback = unsafe { nil }
	invalidate_hit_test_display_list_callback   ViewportPaintableVoidCallback = unsafe { nil }
	record_display_list_callback                ViewportPaintableRecordDisplayListCallback = unsafe { nil }
	build_stacking_context_tree_callback        ViewportPaintableVoidCallback = unsafe { nil }
	stacking_context_callback                   ViewportPaintableStackingContextCallback = unsafe { nil }
	invalidate_stacking_context_callback        ViewportPaintableVoidCallback = unsafe { nil }
	hit_test_callback                           ViewportPaintableHitTestCallback = unsafe { nil }
	hit_test_all_callback                       ViewportPaintableHitTestAllCallback = unsafe { nil }
	subtree_clipped_outside_viewport_callback   ViewportPaintableLayoutQueryCallback = unsafe { nil }
mut:
	paintable_boxes_with_auto_content_visibility_ []&PaintableBox
}

@[heap]
pub struct DisplayList {

	// Owned and interpreted by the module which installed the viewport
	// paintable callbacks.
pub:
	concrete_handle voidptr = unsafe { nil }
	command_count_  int
	dump_callback   DisplayListDumpCallback = unsafe { nil }
}

// CSS stubs
@[heap]
pub struct StyleComputer {

	// dom<->css bridge: opaque handle to the persistent css.StyleComputer for this document (Ladybird's
	// Document owns its StyleComputer). Set/read by the css module via unsafe cast. See css/dom_css_bridge.v.
pub mut:
	css_handle                                 voidptr = unsafe { nil }
	invalidation_property_used_in_has_callback StyleComputerInvalidationPropertyUsedInHasCallback = unsafe { nil }
	invalidation_plan_callback                 StyleComputerInvalidationPlanCallback = unsafe { nil }
	shadow_root_may_match_host_callback        StyleComputerShadowRootMayMatchHostCallback = unsafe { nil }
	recompute_style_callback                   StyleComputerRecomputeStyleCallback = unsafe { nil }
	recompute_inherited_style_callback         StyleComputerRecomputeInheritedStyleCallback = unsafe { nil }
	update_animated_style_callback             StyleComputerUpdateAnimatedStyleCallback = unsafe { nil }
	build_registered_properties_cache_callback StyleComputerBuildCacheCallback = unsafe { nil }
	build_counter_style_cache_callback         StyleComputerBuildCacheCallback = unsafe { nil }
}

@[heap]
pub struct FontComputer {}

@[heap]
pub struct StyleSheetList {
pub mut:
	sheets []&CSSStyleSheet
}

pub fn (mut list StyleSheetList) remove_a_css_style_sheet(sheet &CSSStyleSheet) {
	list.sheets = list.sheets.filter(it != sheet)
}

pub enum CSSStyleSheetLoadingState {
	loading
	loaded
	error
}

@[heap]
pub struct CSSStyleSheet {
pub mut:
	is_alternate          bool
	disabled              bool
	media                 string
	url                   string
	source_text_          ?string
	loading_state         CSSStyleSheetLoadingState = .loaded
	imported_style_sheets []&CSSStyleSheet
	css_handle voidptr = unsafe { nil }
	insert_view_transition_rule_callback fn (voidptr, string) voidptr = unsafe { nil }
	remove_view_transition_rule_callback fn (voidptr, voidptr) = unsafe { nil }
	set_view_transition_selector_callback fn (voidptr, string) = unsafe { nil }
}

// DOM owns pending-import identity while CSS owns the concrete rule behavior.
@[heap]
pub struct CSSImportRule {
pub:
	handle voidptr
}

pub fn (sheet &CSSStyleSheet) loading_state_value() CSSStyleSheetLoadingState {
	return sheet.loading_state
}

// CSS owns the concrete FontFaceSet. The DOM/CSS module boundary retains that
// actual platform object through an interface, rather than an empty DOM copy.
pub interface FontFaceSet {
	ready() &webidl.Promise
	event_target() &EventTarget
	font_face_set_record() voidptr
}

pub type DocumentFontFaceSetFactory = fn (&Document) FontFaceSet

__global document_font_face_set_factory_ ?DocumentFontFaceSetFactory

pub fn install_document_font_face_set_factory(factory DocumentFontFaceSetFactory) {
	document_font_face_set_factory_ = factory
}

// CSS owns the concrete VisualViewport. Retain its actual source record and
// EventTarget through the DOM/CSS module boundary instead of an empty facade.
pub interface VisualViewport {
	document() &Document
	event_target() &EventTarget
	visual_viewport_record() voidptr
	layout_viewport_size_for_resize() [2]int
	offset_left() f64
	offset_top() f64
	page_left() f64
	page_top() f64
	width() f64
	height() f64
	scale() f64
	set_onresize(?&CallbackType)
	onresize() ?&CallbackType
	set_onscroll(?&CallbackType)
	onscroll() ?&CallbackType
	set_onscrollend(?&CallbackType)
	onscrollend() ?&CallbackType
}

pub type DocumentVisualViewportFactory = fn (&Document) VisualViewport

__global document_visual_viewport_factory_ ?DocumentVisualViewportFactory

pub fn install_document_visual_viewport_factory(factory DocumentVisualViewportFactory) {
	document_visual_viewport_factory_ = factory
}

pub type MediaQueryListBoolCallback = fn (voidptr) bool

pub type MediaQueryListSetBoolCallback = fn (voidptr, bool)

pub type MediaQueryListDispatchChangeEventCallback = fn (voidptr, bool)

@[heap]
pub struct MediaQueryList {
pub:
	target                         voidptr
	matches_callback               MediaQueryListBoolCallback = unsafe { nil }
	evaluate_callback              MediaQueryListBoolCallback = unsafe { nil }
	has_changed_state_callback     MediaQueryListBoolCallback = unsafe { nil }
	set_has_changed_state_callback MediaQueryListSetBoolCallback = unsafe { nil }
	dispatch_change_event_callback MediaQueryListDispatchChangeEventCallback = unsafe { nil }
}

// The DOM can't import css, so Document::update_style() runs the CSS style pass through this registered
// callback. The css module installs it with `target` = the document pointer; update_style invokes it.
pub type DocumentStyleUpdateCallback = fn (voidptr) RequiredInvalidationAfterStyleChange

// Pseudo-class invalidation is implemented by CSS's selector/rule caches. This
// callback keeps Document's translated algorithm in DOM while crossing the
// unavoidable dom -> css module boundary without serializing selectors.
pub type DocumentPseudoClassInvalidationCallback = fn (voidptr, PseudoClass, &Node, ?&Node)

// CSS owns StyleScope and CSSStyleSheet in the V module graph. Keep the
// translated Document::evaluate_media_rules() entry point in DOM, and cross
// that module boundary through the document's CSS hook.
pub type DocumentEvaluateMediaRulesCallback = fn (voidptr)

pub type DocumentGetStyleSheetSourceCallback = fn (voidptr, &StyleSheetIdentifier) ?string

pub type DocumentSizeQueryInvalidationCallback = fn (voidptr, &Element)

pub struct DocumentStyleUpdateHook {
pub:
	target                      voidptr = unsafe { nil }
	callback                    DocumentStyleUpdateCallback = unsafe { nil }
	invalidate_for_pseudo_class DocumentPseudoClassInvalidationCallback = unsafe { nil }
	invalidate_size_dependents  DocumentSizeQueryInvalidationCallback = unsafe { nil }
	evaluate_media_rules        DocumentEvaluateMediaRulesCallback = unsafe { nil }
	get_style_sheet_source      DocumentGetStyleSheetSourceCallback = unsafe { nil }
}

// Animations imports css, so DOM cannot advance the css-owned default document
// timeline directly. This hook is the V representation of Document owning one
// StyleComputer and one default DocumentTimeline.
pub type DocumentCSSAnimationTimelineUpdateCallback = fn (voidptr, f64)

pub struct DocumentCSSAnimationTimelineUpdateHook {
pub:
	target   voidptr = unsafe { nil }
	callback DocumentCSSAnimationTimelineUpdateCallback = unsafe { nil }
}

pub type DocumentDispatchCSSAnimationEventCallback = fn (voidptr, &Document, &Animation)

pub struct DocumentCSSAnimationEventHook {
pub:
	target   voidptr = unsafe { nil }
	dispatch DocumentDispatchCSSAnimationEventCallback = unsafe { nil }
}

// CSS creates CSSTransition objects but cannot import HTML's scripting
// runtime. These callbacks preserve the TemporaryExecutionContext scope used
// by the C++ constructors without creating a module cycle.
pub type DocumentTemporaryExecutionContextBeginCallback = fn (voidptr) voidptr

pub type DocumentTemporaryExecutionContextEndCallback = fn (voidptr, voidptr)

pub struct DocumentTemporaryExecutionContextHook {
pub:
	target voidptr = unsafe { nil }
	begin  DocumentTemporaryExecutionContextBeginCallback = unsafe { nil }
	end    DocumentTemporaryExecutionContextEndCallback = unsafe { nil }
}

// Document lifecycle algorithms are owned by DOM, while task queues and
// environment settings are owned by HTML. C++ crosses that boundary directly;
// V uses this per-document vtable to avoid a dom -> html import cycle.
pub type DocumentLifecycleCallback = fn (voidptr, &Document)

pub type DocumentLifecycleObjectCallback = fn (voidptr, &Document) voidptr

pub type DocumentSettingsScriptingEnabledCallback = fn (voidptr) bool

pub type DocumentSettingsHasCrossSiteAncestorCallback = fn (voidptr) bool

pub type DocumentStructuredDeserializeCallback = fn (voidptr, DOMSerializationRecord) ?JSValue

pub type DocumentQueueIntersectionObserverTaskCallback = fn (voidptr, &Document)

pub type DocumentQueueSelectionchangeEventTaskCallback = fn (voidptr, &Document, &Document)

pub type DocumentQueueElementTaskCallback = fn (voidptr, &Element, TaskSource, fn ())

pub struct DocumentLifecycleHook {
pub:
	target                           voidptr = unsafe { nil }
	register_document                DocumentLifecycleCallback = unsafe { nil }
	unregister_document              DocumentLifecycleCallback = unsafe { nil }
	document_navigable_did_change     DocumentLifecycleCallback = unsafe { nil }
	remove_tasks_for_document        DocumentLifecycleCallback = unsafe { nil }
	increment_termination_nesting    DocumentLifecycleCallback = unsafe { nil }
	decrement_termination_nesting    DocumentLifecycleCallback = unsafe { nil }
	set_execution_ready              DocumentLifecycleCallback = unsafe { nil }
	relevant_settings_object         DocumentLifecycleObjectCallback = unsafe { nil }
	settings_scripting_enabled       DocumentSettingsScriptingEnabledCallback = unsafe { nil }
	settings_has_cross_site_ancestor  DocumentSettingsHasCrossSiteAncestorCallback = unsafe { nil }
	structured_deserialize           DocumentStructuredDeserializeCallback = unsafe { nil }
	queue_intersection_observer_task DocumentQueueIntersectionObserverTaskCallback = unsafe { nil }
	queue_selectionchange_event_task DocumentQueueSelectionchangeEventTaskCallback = unsafe { nil }
	queue_an_element_task            DocumentQueueElementTaskCallback = unsafe { nil }
	run_unloading_cleanup_steps      DocumentLifecycleCallback = unsafe { nil }
	timer_visibility_state_changed   DocumentLifecycleCallback = unsafe { nil }
	timer_audio_play_state_changed   DocumentLifecycleCallback = unsafe { nil }
}

// PageClient owns the cookie jar upstream. DOM cannot import the embedding
// page module in V, so this hook retains the same typed request/mutation
// boundary without moving cookie algorithms into Document.
pub type DocumentCookieVersionCallback = fn (voidptr, int) ?u64

pub type DocumentCookieRequestCallback = fn (voidptr, &liburl.URL, httpcookie.Source) httpcookie.VersionedCookie

pub type DocumentCookieSetCallback = fn (voidptr, &liburl.URL, httpcookie.ParsedCookie, httpcookie.Source)

pub type DocumentCookieVersionIndexRequestCallback = fn (voidptr, UniqueNodeID, string)

pub struct DocumentCookieClientHook {
pub:
	target                         voidptr = unsafe { nil }
	request_document_version       DocumentCookieVersionCallback = unsafe { nil }
	request_cookie                 DocumentCookieRequestCallback = unsafe { nil }
	set_cookie                     DocumentCookieSetCallback = unsafe { nil }
	request_document_version_index DocumentCookieVersionIndexRequestCallback = unsafe { nil }
}

pub type StyleComputerInvalidationPropertyUsedInHasCallback = fn (voidptr, InvalidationProperty, &StyleScope) bool

pub type StyleComputerInvalidationPlanCallback = fn (voidptr, []InvalidationProperty, &StyleScope) InvalidationPlan

pub type StyleComputerShadowRootMayMatchHostCallback = fn (voidptr, &ShadowRoot) bool

pub type StyleComputerRecomputeStyleCallback = fn (voidptr, &Element) RequiredInvalidationAfterStyleChange

pub type StyleComputerRecomputeInheritedStyleCallback = fn (voidptr, &Element) RequiredInvalidationAfterStyleChange

pub type StyleComputerUpdateAnimatedStyleCallback = fn (voidptr)

pub type StyleComputerBuildCacheCallback = fn (voidptr)

pub type StyleScopeMayHaveHasSelectorsCallback = fn (voidptr) bool

pub type StyleScopeMayHaveSiblingHasSelectorsCallback = fn (voidptr) bool

pub type StyleScopeHaveLocalLinkSelectorsCallback = fn (voidptr) bool

pub type StyleScopeSubtreeMayAffectHasCallback = fn (voidptr, &Node) bool

pub type StyleScopePendingHasInvalidationCoversChildListCallback = fn (voidptr, &Node) bool

pub type StyleScopeHasFeaturelessSensitiveHasSelectorsCallback = fn (voidptr) bool

pub type StyleScopeRecordHasMutationCallback = fn (voidptr, &Node, &Node, bool)

pub type StyleScopeRecordHasMutationPropertiesCallback = fn (voidptr, &Node, []InvalidationProperty)

pub type StyleScopeRecordConservativeHasInvalidationCallback = fn (voidptr, &Node, bool)

pub type StyleScopeScheduleHasInvalidationCallback = fn (voidptr, &Node)

pub type DocumentThemeColorParseCallback = fn (voidptr, string) ?string

pub type DocumentThemeColorMediaMatchesCallback = fn (voidptr, string) bool

// Document::update_style_for_element(): CSS owns style computation, which DOM cannot import. The callback updates the
// element's style (and its flat-tree inheritance chain) and answers whether the element then has style; in
// stop-at-display-none mode an element in a display:none subtree has none.
pub type DocumentUpdateStyleForElementCallback = fn (voidptr, &Element, bool) bool

pub struct DocumentUpdateStyleForElementHook {
pub:
	target                   voidptr = unsafe { nil }
	update_style_for_element DocumentUpdateStyleForElementCallback = unsafe { nil }
}

pub struct DocumentThemeColorHook {
pub:
	target        voidptr = unsafe { nil }
	parse_color   DocumentThemeColorParseCallback = unsafe { nil }
	media_matches DocumentThemeColorMediaMatchesCallback = unsafe { nil }
}

pub type DocumentLayoutUpdateCallback = fn (voidptr, &Document, f64, f64, bool) voidptr

pub type DocumentLayoutStyleUpdateCallback = fn (voidptr, &Document)

pub type DocumentRenderedTextCallback = fn (voidptr, &Document, &Element) string

pub struct DocumentLayoutUpdateHook {
pub:
	target   voidptr = unsafe { nil }
	callback DocumentLayoutUpdateCallback = unsafe { nil }
	style_did_update DocumentLayoutStyleUpdateCallback = unsafe { nil }
}

pub struct DocumentRenderedTextHook {
pub:
	target   voidptr = unsafe { nil }
	callback DocumentRenderedTextCallback = unsafe { nil }
}

// DOM cannot import ARIA/HTML, so Element::role_or_default() is supplied by
// the owning document's HTML implementation through this module boundary.
pub type DocumentElementAllowsNameFromContentCallback = fn (voidptr, &Element, bool) bool

pub type DocumentEmbeddedControlLabelValueCallback = fn (voidptr, &Element) ?string

pub struct DocumentAccessibilityRoleHook {
pub:
	target                           voidptr = unsafe { nil }
	element_allows_name_from_content DocumentElementAllowsNameFromContentCallback = unsafe { nil }
	embedded_control_label_value     DocumentEmbeddedControlLabelValueCallback = unsafe { nil }
}

// ContentSecurityPolicy depends on DOM for violation events, so DOM cannot
// import it back directly. HTML installs this callback on each document and
// supplies the translated CSP policy engine at the same boundary where C++
// obtains the document global object's PolicyList.
pub type DocumentInlineCSPCheckCallback = fn (voidptr, &Element, string, string) bool

pub type DocumentCSPInitializationCallback = fn (voidptr, &Document)

pub type DocumentBaseCSPCheckCallback = fn (&Document, URL) bool

pub type DocumentMetaCSPEnforceCallback = fn (&Document, string) string

pub type DocumentMetaElementMetadataCallback = fn (&HTMLMetaElement, ?string)

pub struct DocumentCSPHook {
pub:
	target       voidptr = unsafe { nil }
	inline_check DocumentInlineCSPCheckCallback = unsafe { nil }
	initialize   DocumentCSPInitializationCallback = unsafe { nil }
	base_check   DocumentBaseCSPCheckCallback = unsafe { nil }
	meta_enforce DocumentMetaCSPEnforceCallback = unsafe { nil }
}

// TrustedTypes depends on WebIDL and CSP, while DOM owns the injection sinks.
// The HTML embedding installs the translated TrustedTypes implementation here
// without introducing a DOM -> TrustedTypes -> WebIDL -> DOM import cycle.
pub type DocumentTrustedTypesHTMLCallback = fn (voidptr, &Document, string, string) !string

pub type DocumentTrustedTypesAttributeCallback = fn (voidptr, &Element, string, ?string, string) !string

pub struct DocumentTrustedTypesHook {
pub:
	target              voidptr = unsafe { nil }
	compliant_html      DocumentTrustedTypesHTMLCallback = unsafe { nil }
	compliant_attribute DocumentTrustedTypesAttributeCallback = unsafe { nil }
}

// HTML owns entry-realm state and session history, while DOM owns
// Document::open(). The hook keeps the translated algorithms on their upstream
// sides of that dependency-cycle boundary.
pub type DocumentEntryAssociatedDocumentCallback = fn (&Document) &Document

pub type DocumentURLAndHistoryUpdateCallback = fn (&Document, URL) !

pub type DocumentWindowOpenCallback = fn (voidptr, string, string, string) ?&WindowProxy

pub type DocumentDeclarativeRefreshNavigateCallback = fn (voidptr, &Document, URL)

pub type DocumentInitialAboutBlankOpenedCallback = fn (voidptr)

pub type DocumentOpenStopLoadingCallback = fn (voidptr)

pub struct DocumentHTMLNavigationHook {
pub:
	target                       voidptr = unsafe { nil }
	entry_associated_document    DocumentEntryAssociatedDocumentCallback = unsafe { nil }
	update_url_and_history       DocumentURLAndHistoryUpdateCallback = unsafe { nil }
	open_window                  DocumentWindowOpenCallback = unsafe { nil }
	declarative_refresh_navigate DocumentDeclarativeRefreshNavigateCallback = unsafe { nil }
	initial_about_blank_opened   DocumentInitialAboutBlankOpenedCallback = unsafe { nil }
	open_stop_loading            DocumentOpenStopLoadingCallback = unsafe { nil }
}

pub type DocumentFullscreenPopoverCallback = fn (voidptr, &Document, &Element)

pub type DocumentFullscreenContainerFlagCallback = fn (voidptr, &Node) bool

pub struct DocumentFullscreenHook {
pub:
	target                           voidptr = unsafe { nil }
	hide_popovers                    DocumentFullscreenPopoverCallback = unsafe { nil }
	container_iframe_fullscreen_flag DocumentFullscreenContainerFlagCallback = unsafe { nil }
}

// The DOM module cannot import css, so selector parsing and matching are supplied by the css module
// through a per-document callback bridge. Keeping this on Document also gives the css side a natural
// place to retain its parsed-selector cache.
pub type DocumentSelectorQueryValidateCallback = fn (voidptr, string) bool

pub type DocumentSelectorQueryMatchCallback = fn (voidptr, string, &Element, &ParentNode) bool

pub type DocumentSelectorQueryContainsNamedNamespaceCallback = fn (voidptr, string) bool

pub type DocumentSelectorScopeQueryCallback = fn (voidptr, string, &ParentNode, bool) ?[]&Node

pub struct DocumentSelectorQueryHook {
pub:
	target                   voidptr = unsafe { nil }
	validate                 DocumentSelectorQueryValidateCallback = unsafe { nil }
	matches                  DocumentSelectorQueryMatchCallback = unsafe { nil }
	contains_named_namespace DocumentSelectorQueryContainsNamedNamespaceCallback = unsafe { nil }
	scope_query              DocumentSelectorScopeQueryCallback = unsafe { nil }
}

pub enum ParserScriptingMode {
	normal
	disabled
	inert
	fragment
}

pub type DocumentHTMLFragmentParseCallback = fn (voidptr, &Element, string, AllowDeclarativeShadowRoots, ParserScriptingMode) ![]&Node

pub type DocumentFormControlSelectedTextCallback = fn (&Element) ?string

// FormAssociatedTextControlElement lives in HTML and implements DOM's
// InputEventsTarget interface upstream. DOM cannot import HTML in V, so keep
// the dynamic `as_if<FormAssociatedTextControlElement>` operation at this
// narrow module boundary.
pub type DocumentFormControlInputEventsTargetCallback = fn (&Node) ?&InputEventsTarget

pub type DocumentHTMLDocumentParseCallback = fn (voidptr, &Document, string)

pub type DocumentHTMLParserCreateForScriptingCallback = fn (voidptr, &Document) &HTMLParser

pub type DocumentEncodingSniffCallback = fn (voidptr, &Document, []u8, ?string) string

pub type DocumentLoadedHTMLParseCallback = fn (voidptr, &Document, []u8, ?string, URL) !

pub type DocumentLoadedTextParseCallback = fn (voidptr, &Document, []u8, ?string, URL) !string

pub type DocumentXMLDocumentParseCallback = fn (voidptr, &Document, string) bool

pub type HTMLParserVoidCallback = fn (voidptr)

pub type HTMLParserFeedCallback = fn (voidptr, string)

pub type HTMLParserRunCallback = fn (voidptr, bool)

pub type HTMLParserNestingLevelCallback = fn (voidptr) uint

pub type HTMLParserBoolCallback = fn (voidptr) bool

pub type HTMLParserEndStateScheduleCallback = fn (voidptr)

pub struct DocumentHTMLFragmentParsingHook {
pub:
	target                      voidptr = unsafe { nil }
	parse_fragment              DocumentHTMLFragmentParseCallback = unsafe { nil }
	parse_xml_fragment          DocumentHTMLFragmentParseCallback = unsafe { nil }
	parse_document              DocumentHTMLDocumentParseCallback = unsafe { nil }
	create_parser_for_scripting DocumentHTMLParserCreateForScriptingCallback = unsafe { nil }
	sniff_encoding              DocumentEncodingSniffCallback = unsafe { nil }
	parse_loaded_html           DocumentLoadedHTMLParseCallback = unsafe { nil }
	parse_loaded_text           DocumentLoadedTextParseCallback = unsafe { nil }
	parse_xml_document          DocumentXMLDocumentParseCallback = unsafe { nil }
}

pub type DocumentEditingExecCommandCallback = fn (voidptr, &Document, string, bool, string, string) !bool

pub type DocumentEditingQueryCommandCallback = fn (voidptr, &Document, string) !bool

pub type DocumentEditingQueryCommandValueCallback = fn (voidptr, &Document, string) !string

pub type DocumentEditingSanitizeClipboardHTMLCallback = fn (voidptr, &Range, string) !string

pub struct DocumentEditingCommandHook {
pub:
	target                  voidptr
	exec_command            DocumentEditingExecCommandCallback           = unsafe { nil }
	query_command_enabled   DocumentEditingQueryCommandCallback          = unsafe { nil }
	query_command_indeterm  DocumentEditingQueryCommandCallback          = unsafe { nil }
	query_command_state     DocumentEditingQueryCommandCallback          = unsafe { nil }
	query_command_supported DocumentEditingQueryCommandCallback          = unsafe { nil }
	query_command_value     DocumentEditingQueryCommandValueCallback     = unsafe { nil }
	sanitize_clipboard_html DocumentEditingSanitizeClipboardHTMLCallback = unsafe { nil }
}

pub type DocumentEditingHistoryCallback = fn (voidptr)

pub type DocumentEditingHistoryAvailabilityCallback = fn (voidptr) bool

// Editing owns the history objects; DOM reports raw mutations and selection
// changes through this hook without introducing a DOM -> Editing import cycle.
pub struct DocumentEditingHistoryHook {
pub:
	target              voidptr
	notify_dom_mutation DocumentEditingHistoryCallback = unsafe { nil }
	selection_changed   DocumentEditingHistoryCallback = unsafe { nil }
	can_undo            DocumentEditingHistoryAvailabilityCallback = unsafe { nil }
	can_redo            DocumentEditingHistoryAvailabilityCallback = unsafe { nil }
}

// Opaque view of one CSS::BackgroundLayerData entry. CSS owns the typed
// ComputedProperties object; retaining that address and the coordinated-layer
// index avoids serializing the value through text at the DOM/CSS cycle boundary.
pub struct BackgroundLayerData {
pub:
	computed_properties_handle voidptr = unsafe { nil }
	layer_index                int
}

pub type DocumentBackgroundLayersCallback = fn (voidptr, &Element) ?[]BackgroundLayerData

pub type DocumentBackgroundImageRenderingCallback = fn (voidptr, &Element) ImageRendering

pub type DocumentBackgroundColorCallback = fn (voidptr, &Element) Color

pub struct DocumentBackgroundStyleHook {
pub:
	target                     voidptr = unsafe { nil }
	background_color           DocumentBackgroundColorCallback = unsafe { nil }
	background_layers          DocumentBackgroundLayersCallback = unsafe { nil }
	background_image_rendering DocumentBackgroundImageRenderingCallback = unsafe { nil }
}

// The CSS module owns the typed scroll-margin values. DOM consumes their used
// pixel values while running the CSSOM View scroll-into-view algorithm through
// this cycle-breaking hook.
pub struct ScrollMarginData {
pub:
	top    f64
	right  f64
	bottom f64
	left   f64
}

pub type DocumentScrollMarginCallback = fn (voidptr, &Element) ScrollMarginData
pub type DocumentScrollPaddingCallback = fn (voidptr, &Node) ScrollMarginData

pub struct DocumentScrollStyleHook {
pub:
	target         voidptr = unsafe { nil }
	scroll_margin  DocumentScrollMarginCallback = unsafe { nil }
	scroll_padding DocumentScrollPaddingCallback = unsafe { nil }
}

pub type DocumentViewportScrollSnapCallback = fn (voidptr, CSSPixelPoint_, ScrollSnapSelectionStrategy_) ScrollSnapDestination_

pub struct DocumentViewportScrollSnapHook {
pub:
	target             voidptr = unsafe { nil }
	adjust_destination DocumentViewportScrollSnapCallback = unsafe { nil }
}

pub struct CSSSelector {
pub mut:
	text string
}

pub struct SelectorList {
pub mut:
	selectors                []CSSSelector
	contains_named_namespace bool
}

pub struct StyleScope {

	// dom<->css bridge: opaque handle to the persistent css.StyleScope for this document/shadow root.
	// Lazily created and cached by the CSS module. See css/dom_css_bridge.v.
pub mut:
	css_handle                         voidptr = unsafe { nil }
	may_have_has_selectors_callback    StyleScopeMayHaveHasSelectorsCallback = unsafe { nil }
	may_have_sibling_has_callback      StyleScopeMayHaveSiblingHasSelectorsCallback = unsafe { nil }
	have_local_link_selectors_callback StyleScopeHaveLocalLinkSelectorsCallback = unsafe { nil }
	subtree_may_affect_has_callback    StyleScopeSubtreeMayAffectHasCallback = unsafe { nil }
	pending_has_covers_child_list      StyleScopePendingHasInvalidationCoversChildListCallback = unsafe { nil }
	has_featureless_sensitive_callback StyleScopeHasFeaturelessSensitiveHasSelectorsCallback = unsafe { nil }
	record_has_mutation_callback       StyleScopeRecordHasMutationCallback = unsafe { nil }
	record_has_properties_callback     StyleScopeRecordHasMutationPropertiesCallback = unsafe { nil }
	record_conservative_has_callback   StyleScopeRecordConservativeHasInvalidationCallback = unsafe { nil }
	schedule_has_invalidation_callback StyleScopeScheduleHasInvalidationCallback = unsafe { nil }
	invalidate_user_style_callback      fn (voidptr) = unsafe { nil }
}

pub struct StyleValue {
pub mut:
	css_text string
	// The CSS module stores an opaque pointer to its typed css.StyleValue here.
	// DOM cannot name that type without creating a module cycle; CSS owns both
	// creating and reading the handle. Values constructed by DOM-only callers
	// leave this nil and are parsed by the CSS bridge on first use.
	css_value_handle voidptr = unsafe { nil }
	// Style resource URLs are resolved against the stylesheet that supplied the
	// declaration, which can differ from the owning document's base URL.
	base_url ?string
}

pub struct CustomPropertyRegistration {
pub mut:
	initial_value ?string
	syntax        string
	inherits      bool
}

@[heap]
pub struct CounterStyle {}

pub struct RandomCachingKey {}

pub struct ComponentValue {}

pub struct StyleSheetIdentifier {
pub mut:
	type_                 StyleSheetIdentifierType
	url                   ?string
	dom_element_unique_id ?UniqueNodeID
}

pub enum StyleSheetIdentifierType {
	style_element
	link_element
	import_rule
	user_agent
	user_style
}

// HTML stubs
@[heap]
pub struct Window {
	EventTarget
pub mut:
	associated_document_      &Document = unsafe { nil }
	location_                 &Location = unsafe { nil }
	scroll_x_                 f64
	scroll_y_                 f64
	current_event_            &Event = unsafe { nil }
	last_activation_timestamp DOMHighResTimeStamp = math.inf(1)
	last_history_action_activation_timestamp DOMHighResTimeStamp = math.inf(1)
	close_watcher_manager_    &CloseWatcherManager = unsafe { nil }
}

@[heap]
pub struct CloseWatcherManager {
pub:
	target                          voidptr = unsafe { nil }
	notify_user_activation_callback fn (voidptr) = unsafe { nil }
}

@[heap]
pub struct BrowsingContext {
pub mut:
	window_proxy_                      ?&WindowProxy
	active_document_                   ?&Document
	// Identity bridge to the actual HTML BrowsingContext representation.
	html_model_handle_                  voidptr = unsafe { nil }
	group_handle                       voidptr
	is_top_level_                      bool = true
	virtual_browsing_context_group_id_ u64
	opener_origin_at_creation_         ?Origin
	popup_sandboxing_flag_bits_        u32
}

// The concrete HTML parser lives in the html module, which imports dom. This
// callback-backed handle preserves the DOM::Document -> HTMLParser ownership
// and operations without introducing the reverse dom -> html import cycle.
@[heap]
pub struct HTMLParser {
pub:
	target                              voidptr = unsafe { nil }
	abort_callback                      HTMLParserVoidCallback = unsafe { nil }
	feed_callback                       HTMLParserFeedCallback = unsafe { nil }
	run_callback                        HTMLParserRunCallback = unsafe { nil }
	script_nesting_level_callback       HTMLParserNestingLevelCallback = unsafe { nil }
	is_script_created_callback          HTMLParserBoolCallback = unsafe { nil }
	insertion_point_is_defined_callback HTMLParserBoolCallback = unsafe { nil }
	update_insertion_point_callback     HTMLParserVoidCallback = unsafe { nil }
	insert_input_callback               HTMLParserFeedCallback = unsafe { nil }
	insert_eof_callback                 HTMLParserVoidCallback = unsafe { nil }
	schedule_resume_check_callback      HTMLParserVoidCallback = unsafe { nil }
	finish_loading_after_parse_callback HTMLParserVoidCallback = unsafe { nil }
}

@[heap]
pub struct History {
pub mut:
	index  int
	length int
	state  JSValue = js_null()
}

@[heap]
pub struct Location {}

@[heap]
pub struct WindowProxy {
mut:
	window_ ?&Window
}

@[heap]
pub struct NavigationParams {
pub mut:
	response_mime_type                         string = 'text/html'
	response_body                              []u8
	response_url                               URL = url_about_blank()
	request_current_url                        ?URL
	browsing_context                           ?&BrowsingContext
	origin                                     Origin = origin_create_opaque()
	needs_a_browsing_context_group_switch      bool
	would_switch_due_to_report_only            bool
	final_sandboxing_flag_bits                 u32
	policy_container                          ?&PolicyContainer
	about_base_url                            ?URL
	id                                        ?string
	opener_policy                              OpenerPolicy
	was_created_via_cross_origin_redirects     bool
	load_timing_info                           DocumentLoadTimingInfo
	create_top_level_browsing_context_target   voidptr = unsafe { nil }
	create_top_level_browsing_context_callback NavigationParamsCreateTopLevelBrowsingContextCallback = unsafe { nil }
	html_fragment_parsing_hook                 ?DocumentHTMLFragmentParsingHook
}

pub type NavigationParamsCreateTopLevelBrowsingContextCallback = fn (voidptr, &NavigationParams, &BrowsingContext) &BrowsingContext

@[heap]
pub struct SessionHistoryEntry {
pub mut:
	url                       URL
	classic_history_api_state DOMSerializationRecord
}

pub struct DOMSerializationRecord {
pub:
	data []u8
}

// Dependency-cycle-safe contract shared by CSS image values and the HTML image
// decoder. HTML's decoded image implementations satisfy this interface
// structurally, matching the C++ forward-declared DecodedImageData boundary.
pub interface SharedDecodedImageData {
	frame(frame_index uint) ?&DecodedImageFrame_
	frame_duration(frame_index uint) int
	frame_count() uint
	loop_count() uint
	is_animated() bool
	intrinsic_width() ?f64
	intrinsic_height() ?f64
	intrinsic_aspect_ratio() ?f64
}

pub enum SharedResourceRequestState {
	new_
	fetching
	finished
	failed
}

pub type SharedResourceRequestCallback = fn ()

pub type SharedResourceFetchCallback = fn (&SharedResourceRequest, URL)

pub type SharedResourceDecodeCallback = fn (URL, string, []u8) !SharedDecodedImageData

pub struct SharedResourceCallbacks {
	on_finish ?SharedResourceRequestCallback
	on_fail   ?SharedResourceRequestCallback
}

pub struct SharedResourceImageData {
pub:
	data SharedDecodedImageData
}

@[heap]
pub struct SharedResourceRequest {
pub:
	url      URL
	document &Document
mut:
	state_           SharedResourceRequestState
	callbacks        []SharedResourceCallbacks
	image_data_      ?SharedResourceImageData
	load_event_delay bool
	fetch_controller voidptr
	decode_callback  ?SharedResourceDecodeCallback
}

@[heap]
pub struct ListOfAvailableImages {}

@[heap]
pub struct Storage {}

pub type NavigableViewportScrollCallback = fn (voidptr, CSSPixelPoint_)

pub type NavigablePerformScrollCallback = fn (voidptr, CSSPixelPoint_) &Promise

pub type NavigablePerformScrollOptionsCallback = fn (voidptr, CSSPixelPoint_, ScrollBehavior, ScrollSnapSelectionStrategy_) &Promise

pub type NavigablePerformElementScrollCallback = fn (voidptr, &Element, CSSPixelPoint_, ScrollBehavior, ScrollSnapSelectionStrategy_) &Promise

pub type NavigableIsFocusedCallback = fn (voidptr) bool

pub type NavigableActiveDocumentChangedCallback = fn (voidptr, ?&Document)

pub type NavigableSetNeedsRepaintCallback = fn (voidptr)

pub type NavigableRenderScreenshotCallback = fn (voidptr, PaintConfig, ?UniqueNodeID) []u8

pub type NavigableResetMouseInputTrackingCallback = fn (voidptr)

pub type NavigableBooleanStateCallback = fn (voidptr) bool

// Navigable::choose_a_navigable() and Navigable::navigate() belong to the HTML navigable model, which DOM cannot
// import. The model installs these on its DOM identity so hyperlink following can reach it.
pub type NavigableChooseANavigableCallback = fn (voidptr, string, TokenizedFeatureNoOpener) ?&Navigable

pub type NavigableNavigateCallback = fn (voidptr, URL, &Document, string, UserNavigationInvolvement) !

// Page.cpp enters navigation without a source Document. Keep the complete
// UI-owned request across the acyclic DOM -> HTML navigable boundary.
pub enum NavigationHistoryBehavior {
	auto
	push
	replace
}

pub struct PageNavigationParams {
pub:
	url URL
	history_handling NavigationHistoryBehavior = .auto
	document_resource ?string
	navigation_id ?string
}

pub type NavigablePageNavigateCallback = fn (voidptr, PageNavigationParams) !

pub type NavigableReloadCallback = fn (voidptr)

pub type NavigableDownloadHyperlinkCallback = fn (voidptr, URL, UserNavigationInvolvement, &Element, ?string, Origin)

@[heap]
pub struct Navigable {
pub mut:
	navigation_observer_handles []voidptr
	active_document_            ?&Document
	parent_                     ?&Navigable
	traversable_navigable_      ?&Navigable
	container_                  ?&Node
	container_document_         ?&Document
	is_top_level_traversable_   bool
	// LocalNavigable::m_closing, inherited by LocalTraversableNavigable.
	is_closing_                 bool
	// LocalNavigable::m_has_been_destroyed, shared by its native/model owners.
	has_been_destroyed_          bool
	html_model_handle_          voidptr = unsafe { nil }
	viewport_scroll_callback_   NavigableViewportScrollCallback = unsafe { nil }
	perform_scroll_callback_    NavigablePerformScrollCallback = unsafe { nil }
	perform_scroll_options_callback_ NavigablePerformScrollOptionsCallback = unsafe { nil }
	perform_element_scroll_callback_ NavigablePerformElementScrollCallback = unsafe { nil }
	is_focused_callback_        NavigableIsFocusedCallback = unsafe { nil }
	active_document_changed_              NavigableActiveDocumentChangedCallback = unsafe { nil }
	set_needs_repaint_callback_           NavigableSetNeedsRepaintCallback = unsafe { nil }
	render_screenshot_callback_           NavigableRenderScreenshotCallback = unsafe { nil }
	reset_mouse_input_tracking_callback_ NavigableResetMouseInputTrackingCallback = unsafe { nil }
	has_session_history_entry_and_ready_callback_ NavigableBooleanStateCallback = unsafe { nil }
	delays_container_load_event_callback_         NavigableBooleanStateCallback = unsafe { nil }
	force_dark_enabled_callback_                  NavigableBooleanStateCallback = unsafe { nil }
	choose_a_navigable_callback_                  NavigableChooseANavigableCallback = unsafe { nil }
	navigate_callback_                            NavigableNavigateCallback = unsafe { nil }
	page_navigate_callback_                       NavigablePageNavigateCallback = unsafe { nil }
	reload_callback_                              NavigableReloadCallback = unsafe { nil }
	download_hyperlink_callback_                  NavigableDownloadHyperlinkCallback = unsafe { nil }
	input_method_composition_node_                 ?&Node
	input_method_composition_offset_               int
	input_method_last_marked_text_                 string
	input_method_composition_active_               bool
}

pub fn (n &Navigable) perform_scroll_of_viewport_scrolling_box(position CSSPixelPoint_) {
	if n.html_model_handle_ != unsafe { nil } && n.viewport_scroll_callback_ != unsafe { nil } {
		n.viewport_scroll_callback_(n.html_model_handle_, position)
	}
}

pub fn (n &Navigable) perform_a_scroll_of_the_viewport(position CSSPixelPoint_) &Promise {
	if n.html_model_handle_ != unsafe { nil } && n.perform_scroll_callback_ != unsafe { nil } {
		return n.perform_scroll_callback_(n.html_model_handle_, position)
	}
	return Promise.resolved(js_undefined())
}

pub fn (n &Navigable) perform_a_scroll_of_the_viewport_with_options(position CSSPixelPoint_, behavior ScrollBehavior, strategy ScrollSnapSelectionStrategy_) &Promise {
	if n.html_model_handle_ != unsafe { nil } && n.perform_scroll_options_callback_ != unsafe { nil } {
		return n.perform_scroll_options_callback_(n.html_model_handle_, position, behavior, strategy)
	}
	return n.perform_a_scroll_of_the_viewport(position)
}

pub fn (n &Navigable) perform_a_scroll_of_an_element(element &Element, position CSSPixelPoint_, behavior ScrollBehavior, strategy ScrollSnapSelectionStrategy_) &Promise {
	if n.html_model_handle_ != unsafe { nil } && n.perform_element_scroll_callback_ != unsafe { nil } {
		return n.perform_element_scroll_callback_(n.html_model_handle_, element, position, behavior, strategy)
	}
	return Promise.resolved(js_undefined())
}

@[heap]
pub struct NavigableContainer {
mut:
	content_navigable_ ?&Navigable
}

pub fn (nc &NavigableContainer) content_navigable() ?&Navigable {
	return nc.content_navigable_
}

@[heap]
pub struct DocumentTimeline {}

// Animations owns the concrete timeline objects, but Document owns the set of
// timelines associated with it. Keep the concrete pointer and update callback
// together so DOM can run every timeline before updating its animations
// without introducing a dom -> animations module cycle.
pub type AnimationTimelineUpdateCallback = fn (voidptr, f64)

pub struct AnimationTimelineHandle {
pub:
	target              voidptr = unsafe { nil }
	update_current_time AnimationTimelineUpdateCallback = unsafe { nil }
}

@[heap]
pub struct Animation {

	// The concrete Animations::Animation owns this DOM-cycle boundary identity.
	// Keeping its handle here lets bindings recover the translated object
	// without fabricating a second animation state machine.
pub mut:
	concrete_handle_ voidptr = unsafe { nil }
	concrete_kind_   ConcreteAnimationKind
}

pub enum ConcreteAnimationKind {
	web_animation
	css_animation
	css_transition
}

pub type DocumentCalculateGetAnimationsCallback = fn (voidptr, &Node) ![]&Animation

pub type DocumentUpdateAnimationsCallback = fn (voidptr, &Node, f64)

pub type DocumentRemoveReplacedAnimationsCallback = fn (voidptr, &Node)

pub type DocumentCompareAnimationsCallback = fn (voidptr, &Animation, &Animation) int

pub type DocumentAnimationEffectTargetsCallback = fn (voidptr) []AbstractElement

pub type DocumentAnimationEffectsForStyleCallback = fn (voidptr, AbstractElement) []voidptr

pub struct DocumentAnimationsHook {
pub:
	target                     voidptr = unsafe { nil }
	calculate_get_animations   DocumentCalculateGetAnimationsCallback = unsafe { nil }
	update_animations          DocumentUpdateAnimationsCallback = unsafe { nil }
	remove_replaced_animations DocumentRemoveReplacedAnimationsCallback = unsafe { nil }
	compare_animations         DocumentCompareAnimationsCallback = unsafe { nil }
	effect_targets             DocumentAnimationEffectTargetsCallback = unsafe { nil }
	effects_for_style          DocumentAnimationEffectsForStyleCallback = unsafe { nil }
}

pub struct PaintConfig {
pub:
	paint_overlay                   bool
	should_show_line_box_borders    bool
	force_dark_enabled              bool
	force_dark_foreground_threshold i32 = 150
	force_dark_background_threshold i32 = 205
	canvas_fill_rect                Rect
}

@[heap]
pub struct Selection {
pub mut:
	document_                   &Document = unsafe { nil }
	range_                      &Range = unsafe { nil }
	direction_                  SelectionDirection = .directionless
	focus_affinity_             TextAffinity = .downstream
	preferred_inline_coordinate_ ?f64
}

pub enum SelectionDirection {
	forwards
	backwards
	directionless
}

pub enum TextAffinity {
	downstream
	upstream
}

// IntersectionObserver is implemented in the intersectionobserver module, which
// imports DOM. These callbacks are the cycle-breaking equivalent of the typed
// C++ references kept by Document: the registration still owns exactly one
// observer identity and forwards every operation to that translated object.
pub struct IntersectionObserverObservationTarget {
pub:
	target                   &Element
	previous_threshold_index ?uint
	previous_is_intersecting bool
}

pub type IntersectionObserverObservationTargetsCallback = fn (voidptr) []IntersectionObserverObservationTarget

pub type IntersectionObserverObserveCallback = fn (voidptr, &Element)

pub type IntersectionObserverQueueEntryCallback = fn (voidptr, f64, Rect, Rect, Rect, bool, f64, &Element)

pub type IntersectionObserverNotifyCallback = fn (voidptr)

pub type IntersectionObserverRootBoundsCallback = fn (voidptr) Rect

pub type IntersectionObserverRootNodeCallback = fn (voidptr) ?&Node

pub type IntersectionObserverBoolCallback = fn (voidptr) bool

pub type IntersectionObserverThresholdsCallback = fn (voidptr) []f64

pub struct IntersectionObserverMarginValue {
pub:
	value         f64
	is_percentage bool
}

pub type IntersectionObserverMarginsCallback = fn (voidptr) []IntersectionObserverMarginValue

pub type IntersectionObserverUpdateTargetStateCallback = fn (voidptr, uint, uint, bool)

@[heap]
pub struct IntersectionObserver {
pub:
	target               voidptr = unsafe { nil }
	observation_targets_ IntersectionObserverObservationTargetsCallback = unsafe { nil }
	observe_target       IntersectionObserverObserveCallback = unsafe { nil }
	unobserve_target     IntersectionObserverObserveCallback = unsafe { nil }
	queue_entry_         IntersectionObserverQueueEntryCallback = unsafe { nil }
	notify               IntersectionObserverNotifyCallback = unsafe { nil }
	root_bounds          IntersectionObserverRootBoundsCallback = unsafe { nil }
	root_node            IntersectionObserverRootNodeCallback = unsafe { nil }
	is_implicit_root     IntersectionObserverBoolCallback = unsafe { nil }
	root_is_element      IntersectionObserverBoolCallback = unsafe { nil }
	thresholds           IntersectionObserverThresholdsCallback = unsafe { nil }
	scroll_margins       IntersectionObserverMarginsCallback = unsafe { nil }
	update_target_state  IntersectionObserverUpdateTargetStateCallback = unsafe { nil }
}

pub type ResizeObserverGatherAtDepthCallback = fn (voidptr, int)

pub type ResizeObserverBroadcastCallback = fn (voidptr) int

pub type ResizeObserverBoolCallback = fn (voidptr) bool

pub type ResizeObserverDocumentDestroyedCallback = fn (voidptr)

@[heap]
pub struct ResizeObserver {
pub:
	target                 voidptr = unsafe { nil }
	gather_at_depth        ResizeObserverGatherAtDepthCallback = unsafe { nil }
	broadcast              ResizeObserverBroadcastCallback = unsafe { nil }
	has_active             ResizeObserverBoolCallback = unsafe { nil }
	has_skipped            ResizeObserverBoolCallback = unsafe { nil }
	document_was_destroyed ResizeObserverDocumentDestroyedCallback = unsafe { nil }
}

// Other stubs
@[heap]
pub struct DOMImplementation {
pub mut:
	document_ &Document = unsafe { nil }
}

@[heap]
pub struct HTMLCollection {
pub mut:
	root                    &ParentNode = unsafe { nil }
	scope                   HTMLCollectionScope = .descendants
	filter                  fn (&Element) bool = always_accept_element
	sort                    fn (&Element, &Element) bool = never_sort_elements
	cached_elements         []&Element
	cached_dom_tree_version u64
	cache_generation        u64
	cache_initialized       bool
}

pub enum HTMLAllCollectionScope {
	children
	descendants
}

pub struct HTMLAllCollectionResult {
pub:
	element    ?&Element
	collection ?&HTMLCollection
}

// The three object variants returned by Document's legacy named getter.
// WebIDL converts each branch to the corresponding JavaScript object.
pub struct DocumentNamedItemResult {
pub:
	element      ?&Element
	collection   ?&HTMLCollection
	window_proxy ?&WindowProxy
}

pub fn (result DocumentNamedItemResult) to_js_value() JSValue {
	if value := result.window_proxy {
		return js_object(voidptr(value))
	}
	if value := result.element {
		return js_object(voidptr(value))
	}
	if value := result.collection {
		return js_object(voidptr(value))
	}
	return js_undefined()
}

// Translation of HTML/HTMLAllCollection.{h,cpp}. It lives in dom because the
// translated Document owns and exposes this platform collection.
@[heap]
pub struct HTMLAllCollection {
pub mut:
	root   &ParentNode = unsafe { nil }
	scope  HTMLAllCollectionScope = .descendants
	filter fn (&Element) bool = always_accept_element
}

@[heap]
pub struct NodeList {
pub mut:
	name_filter string
	root        &Document = unsafe { nil }
	node_root   &Node = unsafe { nil }
	nodes       []&Node
	is_live     bool
	live_scope  LiveNodeListScope = .children
	live_filter fn (&Node) bool = always_accept_node
}

@[heap]
pub struct NodeIterator {
pub mut:
	root                           &Node = unsafe { nil }
	reference_node_                &Node = unsafe { nil }
	pointer_before_reference_node_ bool = true
	what_to_show                   u32
	filter                         &NodeFilter = unsafe { nil }
	active                         bool
	traversal_pointer              ?NodePointer
}

@[heap]
pub struct TreeWalker {
pub mut:
	root         &Node = unsafe { nil }
	current      &Node = unsafe { nil }
	what_to_show u32
	filter       &NodeFilter = unsafe { nil }
	active       bool
}

@[heap]
pub struct NodeFilter {
pub mut:
	callback_ &CallbackType = unsafe { nil }
}

@[heap]
pub struct DocumentFragment {
	ParentNode
pub mut:
	host_           &Element = unsafe { nil }
	is_shadow_root_ bool
}

@[heap]
pub struct CharacterData {
	Node
pub mut:
	data_               string
	grapheme_segmenter_ &Segmenter = unsafe { nil }
	line_segmenter_     &Segmenter = unsafe { nil }
	word_segmenter_     &Segmenter = unsafe { nil }
}

@[heap]
pub struct Text {
	CharacterData
pub mut:
	max_length_        ?int
	is_password_input_ bool
}

@[heap]
pub struct CDATASection {
	Text
}

@[heap]
pub struct Comment {
	CharacterData
}

@[heap]
pub struct ProcessingInstruction {
	CharacterData
pub mut:
	target_ string
}

@[heap]
pub struct Attr {
	Node
pub mut:
	name_          string
	value_         string
	local_name_    string
	prefix__       ?string
	namespace_uri_ ?string
	owner_element_ &Element = unsafe { nil }
}

@[heap]
pub struct Event {

	// Which concrete event interface this is, so the base Event can be identified as a MouseEvent /
	// KeyboardEvent / PointerEvent etc. (V has no RTTI; the subclasses set this at construction).
pub mut:
	interface_                  EventInterface = .event
	type_                       string
	target_                     ?&EventTarget
	related_target_             ?&EventTarget
	current_target_             ?&EventTarget
	phase_                      EventPhase
	bubbles_                    bool
	cancelable_                 bool
	stop_propagation_           bool
	stop_immediate_propagation_ bool
	cancelled_                  bool
	in_passive_listener_        bool
	composed_                   bool
	initialized_                bool
	dispatched_                 bool
	is_trusted_                 bool
	path_                       []EventPathEntry
	touch_target_list_          TouchTargetList
	time_stamp_                 DOMHighResTimeStamp
mut:
	// Compact engine replay receipt; not a script-visible Event attribute.
	processed_click_handler_targets_ []&EventTarget
}

@[heap]
pub struct EventTarget {
pub mut:
	data EventTargetData
}

pub fn (et &EventTarget) dispatch_event(event &Event) bool {
	return event_target_dispatch_event(et, event)
}

@[heap]
pub struct Range {
pub mut:
	start_container_      &Node = unsafe { nil }
	end_container_        &Node = unsafe { nil }
	start_offset_         int
	end_offset_           int
	associated_selection_ &Selection = unsafe { nil }
}

@[heap]
pub struct ShadowRoot {
	DocumentFragment
pub mut:
	mode                               ShadowRootMode
	declarative                        bool
	clonable_                          bool
	serializable_                      bool
	delegates_focus_                   bool
	available_to_element_internals_    bool
	user_agent_internal_               bool
	uses_document_style_sheets_        bool
	slot_assignment_                   SlotAssignmentMode = .named
	style_scope_                       StyleScope
	adopted_style_sheets_              []&CSSStyleSheet
	adopted_css_style_sheets_handle    voidptr = unsafe { nil }
	style_sheets_                      &StyleSheetList = unsafe { nil }
	element_by_id_                     &ElementByIdMap = unsafe { nil }
	onslotchange_                      ?&CallbackType
	slot_registry_                     &SlotRegistry = unsafe { nil }
	custom_element_registry_           voidptr = unsafe { nil }
	keep_custom_element_registry_null_ bool
	anchor_name_map_                   AnchorNameMap
}

@[heap]
pub struct DocumentObserver {
pub mut:
	document_                           &Document = unsafe { nil }
	document_became_active_             ?fn ()
	document_became_inactive_           ?fn ()
	document_completely_loaded_         ?fn ()
	document_readiness_observer_        ?fn (DocumentReadyState)
	document_visibility_state_observer_ ?fn (VisibilityState)
	document_page_showing_observer_     ?fn (bool)
}

@[heap]
pub struct EditingHostManager {
	InputEventsTarget
pub mut:
	document_                       &Document = unsafe { nil }
	active_contenteditable_element_ &Node = unsafe { nil }
}

@[heap]
pub struct StyleInvalidator {
pub mut:
	pending_invalidations           map[UniqueNodeID][]PendingDescendantInvalidation
	active_descendant_invalidations []PendingDescendantInvalidation
}

pub type InputEventsTargetCursorPositionCallback = fn (voidptr) ?&Position

pub type InputEventsTargetHandleInsertCallback = fn (voidptr, string, string)

pub type InputEventsTargetHandleClipboardInsertCallback = fn (voidptr, string, string, ?string)

pub type InputEventsTargetHandleReturnCallback = fn (voidptr, string) EventResult

pub enum InputEventsTargetNavigationAction {
	start
	end
	line_start
	line_end
	document_start
	document_end
	previous_page
	next_page
	previous_character
	next_character
	previous_word
	next_word
	previous_line
	next_line
}

pub type InputEventsTargetNavigateCallback = fn (voidptr, InputEventsTargetNavigationAction, CollapseSelection)

pub type InputEventsTargetMouseSelectionScopeCallback = fn (voidptr) ?&Node

pub type InputEventsTargetSetSelectionBoundaryCallback = fn (voidptr, &Node, int, TextAffinity)

pub type InputEventsTargetHandleDeleteCallback = fn (voidptr, string)

pub type InputEventsTargetSelectAllCallback = fn (voidptr)

pub enum TextControlSelectionDirection {
	forward
	backward
	none
}

pub struct TextControlSelectionSnapshot {
pub mut:
	start     u32
	end       u32
	direction TextControlSelectionDirection
}

pub type InputEventsTargetSelectionCallback = fn (voidptr) TextControlSelectionSnapshot

pub type InputEventsTargetSetSelectionCallback = fn (voidptr, u32, u32, TextControlSelectionDirection)

pub type InputEventsTargetRelevantValueCallback = fn (voidptr) string

pub type InputEventsTargetReplaceRangeCallback = fn (voidptr, string, u32, u32) bool

@[heap]
pub struct InputEventsTarget {
pub:
	target                   voidptr = unsafe { nil }
	cursor_position_callback InputEventsTargetCursorPositionCallback = unsafe { nil }
	handle_insert_callback   InputEventsTargetHandleInsertCallback = unsafe { nil }
	handle_clipboard_insert_callback InputEventsTargetHandleClipboardInsertCallback = unsafe { nil }
	handle_return_callback   InputEventsTargetHandleReturnCallback = unsafe { nil }
	navigate_callback        InputEventsTargetNavigateCallback = unsafe { nil }
	mouse_selection_scope_callback InputEventsTargetMouseSelectionScopeCallback = unsafe { nil }
	set_selection_anchor_callback InputEventsTargetSetSelectionBoundaryCallback = unsafe { nil }
	set_selection_focus_callback InputEventsTargetSetSelectionBoundaryCallback = unsafe { nil }
	handle_delete_callback   InputEventsTargetHandleDeleteCallback = unsafe { nil }
	select_all_callback      InputEventsTargetSelectAllCallback = unsafe { nil }
	selection_callback       InputEventsTargetSelectionCallback = unsafe { nil }
	set_selection_callback   InputEventsTargetSetSelectionCallback = unsafe { nil }
	relevant_value_callback  InputEventsTargetRelevantValueCallback = unsafe { nil }
	replace_range_callback   InputEventsTargetReplaceRangeCallback = unsafe { nil }
	defer_cursor_scroll_callback fn (voidptr, bool) = unsafe { nil }
	flush_deferred_cursor_scroll_callback fn (voidptr, bool) = unsafe { nil }
}

pub fn (target &InputEventsTarget) defer_cursor_scroll(defer_scroll bool) {
	if target.target != unsafe { nil } && target.defer_cursor_scroll_callback != unsafe { nil } {
		target.defer_cursor_scroll_callback(target.target, defer_scroll)
	}
}

pub fn (target &InputEventsTarget) flush_deferred_cursor_scroll(allow_scroll bool) {
	if target.target != unsafe { nil } && target.flush_deferred_cursor_scroll_callback != unsafe { nil } {
		target.flush_deferred_cursor_scroll_callback(target.target, allow_scroll)
	}
}

pub fn (target &InputEventsTarget) cursor_position() ?&Position {
	if target.target == unsafe { nil } || target.cursor_position_callback == unsafe { nil } {
		return none
	}
	return target.cursor_position_callback(target.target)
}

pub fn (target &InputEventsTarget) handle_insert(input_type string, value string) {
	if target.target == unsafe { nil } || target.handle_insert_callback == unsafe { nil } {
		return
	}
	target.handle_insert_callback(target.target, input_type, value)
}

pub fn (target &InputEventsTarget) handle_insert_from_clipboard(input_type string, plain_text string, html ?string) {
	if target.target != unsafe { nil } && target.handle_clipboard_insert_callback != unsafe { nil } {
		target.handle_clipboard_insert_callback(target.target, input_type, plain_text, html)
		return
	}
	target.handle_insert(input_type, plain_text)
}

pub fn (target &InputEventsTarget) handle_return_key(input_type string) EventResult {
	if target.target == unsafe { nil } || target.handle_return_callback == unsafe { nil } {
		return .dropped
	}
	return target.handle_return_callback(target.target, input_type)
}

pub fn (target &InputEventsTarget) navigate(action InputEventsTargetNavigationAction, collapse CollapseSelection) {
	if target.target == unsafe { nil } || target.navigate_callback == unsafe { nil } {
		return
	}
	target.navigate_callback(target.target, action, collapse)
}

pub fn (target &InputEventsTarget) mouse_selection_scope() ?&Node {
	if target.target == unsafe { nil } || target.mouse_selection_scope_callback == unsafe { nil } {
		return none
	}
	return target.mouse_selection_scope_callback(target.target)
}

pub fn (target &InputEventsTarget) set_selection_anchor(node &Node, offset int, affinity TextAffinity) {
	if target.target == unsafe { nil } || target.set_selection_anchor_callback == unsafe { nil } {
		return
	}
	target.set_selection_anchor_callback(target.target, node, offset, affinity)
}

pub fn (target &InputEventsTarget) set_selection_focus(node &Node, offset int, affinity TextAffinity) {
	if target.target == unsafe { nil } || target.set_selection_focus_callback == unsafe { nil } {
		return
	}
	target.set_selection_focus_callback(target.target, node, offset, affinity)
}

pub fn (target &InputEventsTarget) move_cursor_to_start(collapse CollapseSelection) {
	target.navigate(.start, collapse)
}

pub fn (target &InputEventsTarget) move_cursor_to_end(collapse CollapseSelection) {
	target.navigate(.end, collapse)
}

pub fn (target &InputEventsTarget) move_cursor_to_start_of_document(collapse CollapseSelection) {
	target.navigate(.document_start, collapse)
}

pub fn (target &InputEventsTarget) move_cursor_to_end_of_document(collapse CollapseSelection) {
	target.navigate(.document_end, collapse)
}

pub fn (target &InputEventsTarget) move_cursor_to_previous_page(collapse CollapseSelection) {
	target.navigate(.previous_page, collapse)
}

pub fn (target &InputEventsTarget) move_cursor_to_next_page(collapse CollapseSelection) {
	target.navigate(.next_page, collapse)
}

pub fn (target &InputEventsTarget) decrement_cursor_position_offset(collapse CollapseSelection) {
	target.navigate(.previous_character, collapse)
}

pub fn (target &InputEventsTarget) increment_cursor_position_offset(collapse CollapseSelection) {
	target.navigate(.next_character, collapse)
}

pub fn (target &InputEventsTarget) decrement_cursor_position_to_previous_word(collapse CollapseSelection) {
	target.navigate(.previous_word, collapse)
}

pub fn (target &InputEventsTarget) increment_cursor_position_to_next_word(collapse CollapseSelection) {
	target.navigate(.next_word, collapse)
}

pub fn (target &InputEventsTarget) decrement_cursor_position_to_previous_line(collapse CollapseSelection) {
	target.navigate(.previous_line, collapse)
}

pub fn (target &InputEventsTarget) increment_cursor_position_to_next_line(collapse CollapseSelection) {
	target.navigate(.next_line, collapse)
}

pub fn (target &InputEventsTarget) handle_delete(input_type string) {
	if target.target == unsafe { nil } || target.handle_delete_callback == unsafe { nil } {
		return
	}
	target.handle_delete_callback(target.target, input_type)
}

pub fn (target &InputEventsTarget) select_all() {
	if target.target == unsafe { nil } || target.select_all_callback == unsafe { nil } {
		return
	}
	target.select_all_callback(target.target)
}

pub fn (target &InputEventsTarget) text_control_selection() ?TextControlSelectionSnapshot {
	if target.target == unsafe { nil } || target.selection_callback == unsafe { nil } {
		return none
	}
	return target.selection_callback(target.target)
}

pub fn (target &InputEventsTarget) set_text_control_selection(selection TextControlSelectionSnapshot) {
	if target.target == unsafe { nil } || target.set_selection_callback == unsafe { nil } {
		return
	}
	target.set_selection_callback(target.target, selection.start, selection.end, selection.direction)
}

pub fn (target &InputEventsTarget) text_control_relevant_value() ?string {
	if target.target == unsafe { nil } || target.relevant_value_callback == unsafe { nil } {
		return none
	}
	return target.relevant_value_callback(target.target)
}

pub fn (target &InputEventsTarget) replace_text_control_range(replacement string, start u32, end u32) bool {
	if target.target == unsafe { nil } || target.replace_range_callback == unsafe { nil } {
		return false
	}
	return target.replace_range_callback(target.target, replacement, start, end)
}

@[heap]
pub struct Position {
pub mut:
	node_   &Node = unsafe { nil }
	offset_ int
}

pub type EventCallbackExceptionReporter = fn (IError)

@[heap]
pub struct CallbackType {
pub mut:
	handle_event          ?fn (&Event, ?&EventTarget) JSValue
	handle_event_with_exception ?fn (&Event, ?&EventTarget) !JSValue
	// Bindings::report_exception_for_callback reports the original completion
	// through the callback object's associated Realm after invocation returns.
	report_exception      ?EventCallbackExceptionReporter
	// WebIDL::CallbackType.callback is the actual JavaScript object. Distinct
	// callback records can reference that same object with different incumbents.
	callback_identity_ voidptr
	call_no_args          ?fn () JSValue
	call_no_args_promise  ?fn () !&webidl.Promise
	call_with_arguments   ?fn ([]JSValue) JSValue
	accept_node           ?fn (&Node) int
	mutation_callback     ?fn ([]&MutationRecord, &MutationObserver)
	compiled_source_text_ string
	// The callback object's associated Realm global. DOM cannot import HTML's
	// WindowOrWorkerGlobalScope mixin, but Window itself is a DOM bridge type and
	// is sufficient for EventDispatcher's current-event bookkeeping.
	associated_window ?&Window
}

@[heap]
pub struct ViewTransition {
mut:
	transition_          &viewtransition.ViewTransition = unsafe { nil }
	transition_document_ &viewtransition.TransitionDocument = unsafe { nil }
	document_            &Document = unsafe { nil }
	dom_task_pending_    bool
	transition_root_pseudo_element_ &PseudoElementTreeNode_ = unsafe { nil }
	transition_pseudo_nodes_ []&PseudoElementTreeNode_
}

// Concrete HTML dispatch across the DOM/Page package boundary. Physical weak
// node lookup and automatic GC finalization remain separate integrations.
pub struct MediaElementPageCallbacks {
pub:
	target voidptr = unsafe { nil }
	mute_state_changed fn (voidptr) = unsafe { nil }
	is_playing_audio fn (voidptr, &Document) bool = unsafe { nil }
}

@[heap]
pub struct Page {
pub:
	target                               voidptr = unsafe { nil }
	did_create_document_callback         fn (voidptr, &Document) = unsafe { nil }
	did_update_resource_count_callback   fn (voidptr, int) = unsafe { nil }
	did_change_title_callback            fn (voidptr, string) = unsafe { nil }
	device_pixel_scale_callback          fn (voidptr) f64 = unsafe { nil }
	did_allocate_backing_stores_callback fn (voidptr, int, int) = unsafe { nil }
	did_update_editing_history_callback  fn (voidptr, bool, bool) = unsafe { nil }
	preferred_color_scheme_callback      fn (voidptr) string = unsafe { nil }
	prefers_reduced_transparency_callback fn (voidptr) bool = unsafe { nil }
	prefers_reduced_motion_callback       fn (voidptr) bool = unsafe { nil }
	user_style_callback                  fn (voidptr) ?string = unsafe { nil }
	request_frame_callback               fn (voidptr) = unsafe { nil }
	has_rendering_opportunity_callback   fn (voidptr) bool = unsafe { nil }
	will_begin_rendering_update_callback fn (voidptr) = unsafe { nil }
	did_finish_rendering_update_callback fn (voidptr) = unsafe { nil }
	local_root_navigable_callback        fn (voidptr) ?&Navigable = unsafe { nil }
	find_from_window_callback            fn (voidptr, string) bool = unsafe { nil }
	has_media_element_playing_audio_callback fn (voidptr, &Document) bool = unsafe { nil }
	media_element_audio_state_changed_callback fn (voidptr, &Document, UniqueNodeID, bool) = unsafe { nil }
	did_change_audio_play_state_callback fn (voidptr, bool) = unsafe { nil }
	is_audio_muted_callback fn (voidptr) bool = unsafe { nil }
	set_audio_muted_callback fn (voidptr, bool) = unsafe { nil }
	register_actual_media_element_callback fn (voidptr, &Document, UniqueNodeID, MediaElementPageCallbacks) = unsafe { nil }
	unregister_actual_media_element_callback fn (voidptr, UniqueNodeID) = unsafe { nil }
	create_screen_wake_lock_handle_callback fn (voidptr) voidptr = unsafe { nil }
	did_request_color_picker_callback    fn (voidptr, string, string) = unsafe { nil }
	did_request_file_picker_callback     fn (voidptr, string, string, bool) = unsafe { nil }
	did_request_external_url_callback    fn (voidptr, string, string, bool) = unsafe { nil }
	is_scripting_enabled_callback       fn (voidptr) bool = unsafe { nil }
mut:
	last_changed_title_ string
	title_change_count_ int
}

@[heap]
pub struct ConsoleClient {}

@[heap]
pub struct FormAssociatedElement {
pub:
	target                                    voidptr = unsafe { nil }
	element_id_changed_callback               fn (voidptr) = unsafe { nil }
	element_with_id_added_or_removed_callback fn (voidptr) = unsafe { nil }
}

@[heap]
pub struct ElementByIdMap {
pub mut:
	elements_by_id             map[string][]&Element
	cached_first_element_by_id map[string]&Element
}

pub enum PromiseState {
	pending
	fulfilled
	rejected
}

// A small observable promise record used by translated Web APIs until the
// LibJS promise job machinery is available. Resolution is intentionally
// idempotent, matching JavaScript promise settlement.
@[heap]
pub struct Promise {
pub mut:
	state_   PromiseState
	result_  JSValue
	handled_ bool
	// CSSOM View's ScrollResult is carried alongside the source snapshot's
	// legacy undefined fulfillment, then converted by the JavaScript binding.
	scroll_interrupted_ bool
mut:
	// Source-backed APIs expose this exact capability. The old standalone
	// observer interface reads it directly, without copying settlement state.
	native_promise_ ?&webidl.Promise
}

pub fn Promise.from_webidl(promise &webidl.Promise) &Promise {
	return &Promise{
		native_promise_: promise
	}
}

pub fn (promise &Promise) webidl_promise() ?&webidl.Promise {
	return promise.native_promise_
}

pub fn Promise.create() &Promise {
	return &Promise{}
}

pub fn Promise.resolved(value JSValue) &Promise {
	return &Promise{
		state_:  .fulfilled
		result_: value
	}
}

pub fn Promise.rejected(reason JSValue) &Promise {
	return &Promise{
		state_:  .rejected
		result_: reason
	}
}

pub fn (promise &Promise) state() PromiseState {
	if native := promise.native_promise_ {
		return match native.state {
			.pending { .pending }
			.fulfilled { .fulfilled }
			.rejected { .rejected }
		}
	}
	return promise.state_
}

pub fn (promise &Promise) result() JSValue {
	if native := promise.native_promise_ { return js_webidl_value(native.result) }
	return promise.result_
}

pub fn (mut promise Promise) resolve(value JSValue) {
	if pointer := promise.native_promise_ {
		mut native := unsafe { &webidl.Promise(pointer) }
		native.resolve(value.as_webidl_value() or { panic(err) })
		return
	}
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .fulfilled
	promise.result_ = value
}

pub fn (mut promise Promise) reject(reason JSValue) {
	if pointer := promise.native_promise_ {
		mut native := unsafe { &webidl.Promise(pointer) }
		native.reject(reason.as_webidl_value() or { panic(err) })
		return
	}
	if promise.state_ != .pending {
		return
	}
	promise.state_ = .rejected
	promise.result_ = reason
}

pub fn (mut promise Promise) mark_handled() {
	if pointer := promise.native_promise_ {
		mut native := unsafe { &webidl.Promise(pointer) }
		native.mark_as_handled()
		return
	}
	promise.handled_ = true
}

pub fn (promise &Promise) is_handled() bool {
	if native := promise.native_promise_ { return native.is_handled }
	return promise.handled_
}

@[heap]
pub struct AccessibilityTreeNode {
pub mut:
	value_    ?&Node
	children_ []&AccessibilityTreeNode
}

pub type XPathNamespaceResolver = fn (string) ?string

pub type XPathExpressionEvaluateCallback = fn (voidptr, &Node, u16, ?&XPathResult) !&XPathResult

pub enum XPathResultType as u16 {
	any                     = 0
	number                  = 1
	string                  = 2
	boolean                 = 3
	unordered_node_iterator = 4
	ordered_node_iterator   = 5
	unordered_node_snapshot = 6
	ordered_node_snapshot   = 7
	any_unordered_node      = 8
	first_ordered_node      = 9
}

@[heap]
pub struct XPathExpression {
pub:
	target            voidptr
	expression        string
	evaluate_callback XPathExpressionEvaluateCallback = unsafe { nil }
}

pub fn (expression &XPathExpression) evaluate(context_node &Node, type_ u16, result ?&XPathResult) !&XPathResult {
	if expression.target == unsafe { nil } || expression.evaluate_callback == unsafe { nil } {
		return error('NotSupportedError: XPath expression evaluator is not installed')
	}
	return expression.evaluate_callback(expression.target, context_node, type_, result)
}

@[heap]
pub struct XPathResult {
pub mut:
	target                  voidptr
	result_type_            XPathResultType
	number_value_           f64
	string_value_           string
	boolean_value_          bool
	invalid_iterator_state_ bool
	nodes                    []&Node
	iterator_index           int
}

pub fn (result &XPathResult) result_type() XPathResultType {
	return result.result_type_
}

pub fn (result &XPathResult) number_value() f64 {
	return result.number_value_
}

pub fn (result &XPathResult) string_value() string {
	return result.string_value_
}

pub fn (result &XPathResult) boolean_value() bool {
	return result.boolean_value_
}

pub fn (result &XPathResult) invalid_iterator_state() bool {
	return result.invalid_iterator_state_
}

pub fn (result &XPathResult) single_node_value() ?&Node {
	if result.nodes.len == 0 {
		return none
	}
	return result.nodes[0]
}

pub fn (result &XPathResult) snapshot_length() u32 {
	return u32(result.nodes.len)
}

pub fn (mut result XPathResult) iterate_next() ?&Node {
	if result.iterator_index >= result.nodes.len {
		return none
	}
	node := result.nodes[result.iterator_index]
	result.iterator_index++
	return node
}

pub fn (result &XPathResult) snapshot_item(index int) ?&Node {
	if index < 0 || index >= result.nodes.len {
		return none
	}
	return result.nodes[index]
}

@[heap]
pub struct XPathNSResolver {
pub:
	callback_ ?XPathNamespaceResolver
}

pub fn XPathNSResolver.create(callback XPathNamespaceResolver) &XPathNSResolver {
	return &XPathNSResolver{
		callback_: callback
	}
}

pub fn (resolver &XPathNSResolver) callback() XPathNamespaceResolver {
	return resolver.callback_ or { panic('XPathNSResolver has no callback') }
}

@[heap]
pub struct DOMRectReadOnly {}

@[heap]
pub struct Segmenter {
pub mut:
	segmented_text       string
	granularity          SegmenterGranularity = .grapheme
	ascii_line_fast_path bool
}

pub enum SegmenterGranularity {
	grapheme
	line
	word
}

pub fn (s &Segmenter) clone() &Segmenter {
	return &Segmenter{
		segmented_text: s.segmented_text
		granularity: s.granularity
		ascii_line_fast_path: s.ascii_line_fast_path
	}
}

pub fn (mut s Segmenter) set_segmented_text(text string) {
	if s.ascii_line_fast_path {
		assert segmenter_can_use_ascii_line_fast_path(text)
	}
	s.segmented_text = text
}

pub fn Segmenter.try_create_for_ascii_line(text string) ?&Segmenter {
	if !segmenter_can_use_ascii_line_fast_path(text) {
		return none
	}
	return &Segmenter{
		segmented_text: text
		granularity: .line
		ascii_line_fast_path: true
	}
}

pub fn (s &Segmenter) is_ascii_line_fast_path() bool {
	return s.ascii_line_fast_path
}

@[heap]
pub struct Timer {
pub:
	interval_ms int
	repeating   bool
pub mut:
	callback fn () = unsafe { nil }
	active   bool
mut:
	callback_context voidptr
	context_callback fn (voidptr) = unsafe { nil }
}

pub fn Timer.create_repeating(interval_ms int, callback fn ()) &Timer {
	return &Timer{
		interval_ms: interval_ms
		repeating: true
		callback: callback
	}
}

// Keep the receiver in the timer's ordinary managed object graph instead of
// allocating a captured callback with an independent executable lifetime.
pub fn Timer.create_repeating_with_context(interval_ms int, context voidptr, callback fn (voidptr)) &Timer {
	return &Timer{
		interval_ms: interval_ms
		repeating: true
		callback_context: context
		context_callback: callback
	}
}

pub fn Timer.create_single_shot(interval_ms int, callback fn ()) &Timer {
	return &Timer{
		interval_ms: interval_ms
		callback: callback
	}
}

// Stub Rect
pub struct Rect {
pub mut:
	x      f64
	y      f64
	width  f64
	height f64
}

pub fn (r Rect) size() [2]f64 {
	return [r.width, r.height]!
}

// --- Stub methods on types ---

// Node methods are in node.v. Element methods are in element.v.

// HTMLElement methods
pub fn (he &HTMLElement) has_attribute(name string) bool {
	return unsafe { &Element(he) }.has_attribute(name)
}

pub fn (he &HTMLElement) get_attribute(name string) ?string {
	return unsafe { &Element(he) }.get_attribute(name)
}

pub fn (he &HTMLElement) set_attribute(name string, value string) {
	mut element := unsafe { &Element(he) }
	element.set_attribute_value(name, value)
}

// BrowsingContext methods
pub fn (bc &BrowsingContext) window_proxy() &WindowProxy {
	if proxy := bc.window_proxy_ {
		return proxy
	}
	mut mutable_context := unsafe { &BrowsingContext(bc) }
	proxy := &WindowProxy{}
	mutable_context.window_proxy_ = proxy
	return proxy
}

pub fn (bc &BrowsingContext) active_document() ?&Document {
	return bc.active_document_
}

// WindowProxy methods
pub fn (wp &WindowProxy) set_window(w &Window) {
	mut mutable_proxy := unsafe { &WindowProxy(wp) }
	mutable_proxy.window_ = w
}

pub fn (wp &WindowProxy) window() ?&Window {
	return wp.window_
}

// Window methods
pub fn (w &Window) associated_document() ?&Document {
	if w.associated_document_ == unsafe { nil } {
		return none
	}
	return w.associated_document_
}

pub fn (mut w Window) set_associated_document(document &Document) {
	w.data.kind = .window
	w.associated_document_ = document
}

pub fn (w &Window) dispatch_event_simple(event_name string, bubbles bool) {
	event := Event.create(event_name, EventInit{
		bubbles: bubbles
	})
	event_target_dispatch_event(unsafe { &EventTarget(w) }, event)
}

pub fn (w &Window) fire_a_page_transition_event(event_name string, salvageable bool) {
	mut event := PageTransitionEvent.create(event_name, PageTransitionEventInit{
		EventInit: EventInit{
			bubbles: true
			cancelable: true
		}
		persisted: salvageable
	})
	mut base_event := unsafe { &Event(event) }
	base_event.set_is_trusted(true)
	event_target_dispatch_event(unsafe { &EventTarget(w) }, base_event)
}

pub fn (w &Window) has_transient_activation() bool {
	current_time := current_high_resolution_time(w)
	return current_time >= w.last_activation_timestamp && current_time < w.last_activation_timestamp + 5000
}

pub fn (w &Window) has_sticky_activation() bool {
	return current_high_resolution_time(w) >= w.last_activation_timestamp
}

pub fn (w &Window) dispatch_popstate_event(state JSValue) {
	mut event := PopStateEvent.create('popstate', PopStateEventInit{
		state: state
	})
	event.set_is_trusted(true)
	event_target_dispatch_event(unsafe { &EventTarget(w) }, unsafe { &Event(event) })
}

pub fn (w &Window) current_event() ?&Event {
	if w.current_event_ == unsafe { nil } {
		return none
	}
	return w.current_event_
}

pub fn (mut w Window) set_current_event(event ?&Event) {
	w.current_event_ = event or { unsafe { nil } }
}

pub fn (mut w Window) set_last_activation_timestamp(timestamp DOMHighResTimeStamp) {
	w.last_activation_timestamp = timestamp
}

pub fn (mut w Window) close_watcher_manager() &CloseWatcherManager {
	if w.close_watcher_manager_ == unsafe { nil } {
		w.close_watcher_manager_ = &CloseWatcherManager{}
	}
	return w.close_watcher_manager_
}

pub fn (manager &CloseWatcherManager) notify_about_user_activation() {
	if manager.target != unsafe { nil } && manager.notify_user_activation_callback != unsafe { nil } {
		manager.notify_user_activation_callback(manager.target)
	}
}

pub fn (w &Window) scroll_x() f64 {
	if w.associated_document_ != unsafe { nil } && w.associated_document_.cached_navigable() != none {
		return w.associated_document_.viewport_rect().x
	}
	return w.scroll_x_
}

pub fn (w &Window) scroll_y() f64 {
	if w.associated_document_ != unsafe { nil } && w.associated_document_.cached_navigable() != none {
		return w.associated_document_.viewport_rect().y
	}
	return w.scroll_y_
}

pub fn (mut w Window) scroll(x f64, y f64) &Promise {
	return w.scroll_with_options(x, y, .auto_, ScrollSnapSelectionStrategy_{})
}

pub fn (mut w Window) scroll_with_options(x f64, y f64, behavior ScrollBehavior, strategy ScrollSnapSelectionStrategy_) &Promise {
	if w.associated_document_ != unsafe { nil } {
		if navigable := w.associated_document_.cached_navigable() {
			mut document := w.associated_document_
			mut position := CSSPixelPoint_{x_: normalize_non_finite(x), y_: normalize_non_finite(y)}
			if position.x() != 0 || position.y() != 0 {
				document.update_layout(.window_scroll)
				paintable := document.as_node().paintable_box() or { return Promise.resolved(js_undefined()) }
				position = paintable.clamp_scroll_offset(position)
			}
			viewport := document.viewport_rect()
			// Window.cpp currently returns here even if a smooth operation is
			// in progress. Keep this pinned-source early return.
			if position.x() == viewport.x && position.y() == viewport.y {
				return Promise.resolved(js_undefined())
			}
			return navigable.perform_a_scroll_of_the_viewport_with_options(position, behavior, strategy)
		}
	}
	// Legacy detached DOM Window records carry no HTML navigable identity.
	w.scroll_x_ = x
	w.scroll_y_ = y
	return Promise.resolved(js_undefined())
}

// Navigable methods
pub fn (n &Navigable) container() ?&Node {
	return n.container_
}

pub fn (mut n Node) set_load_event_delay_hook(hook ?NodeLoadEventDelayHook) {
	if hook == none && n.hooks_ == unsafe { nil } { return }
	mut hooks := n.ensure_hooks()
	hooks.load_event_delay = hook
}

pub fn (n &Node) currently_delays_the_load_event() bool {
	if n.hooks_ == unsafe { nil } { return false }
	hook := n.hooks_.load_event_delay or { return false }
	if hook.callback == unsafe { nil } {
		return false
	}
	return hook.callback(hook.target)
}

pub fn (mut n Node) set_active_window_proxy_hook(hook ?NodeActiveWindowProxyHook) {
	if hook == none && n.hooks_ == unsafe { nil } { return }
	mut hooks := n.ensure_hooks()
	hooks.active_window_proxy = hook
}

pub fn (n &Node) active_window_proxy() ?&WindowProxy {
	if n.hooks_ == unsafe { nil } { return none }
	hook := n.hooks_.active_window_proxy or { return none }
	if hook.callback == unsafe { nil } {
		return none
	}
	return hook.callback(hook.target)
}

pub fn (n &Navigable) active_document() ?&Document {
	return n.active_document_
}

// These accessors mirror Navigable's remote-safe URL/origin interface. The V
// engine is currently single-process, so the values come from the local active
// document; callers do not need to depend on that implementation detail.
pub fn (n &Navigable) active_document_url() ?URL {
	document := n.active_document() or { return none }
	return document.url
}

pub fn (n &Navigable) active_document_origin() ?Origin {
	document := n.active_document() or { return none }
	return document.origin()
}

// LocalNavigable::active_document_has_cross_site_ancestor. HTML owns the actual
// relevant settings, reached through the same Document lifecycle bridge.
pub fn (n &Navigable) active_document_has_cross_site_ancestor() bool {
	document := n.active_document() or { panic('Source active cross-site ancestor requires an active Document') }
	hook := document.lifecycle_hook_ or { panic('Source active cross-site ancestor requires Document settings') }
	assert hook.settings_has_cross_site_ancestor != unsafe { nil }
	settings := document.relevant_settings_object()
	assert settings != unsafe { nil }
	return hook.settings_has_cross_site_ancestor(settings)
}

pub fn (n &Navigable) active_document_is_fully_active() bool {
	document := n.active_document() or { return false }
	return document.is_fully_active()
}

pub fn (n &Navigable) active_document_is(document &Document) bool {
	active_document := n.active_document() or { return false }
	return voidptr(active_document) == voidptr(document)
}

pub fn (n &Navigable) has_session_history_entry_and_ready_for_navigation() bool {
	if n.html_model_handle_ == unsafe { nil }
		|| n.has_session_history_entry_and_ready_callback_ == unsafe { nil } {
		return false
	}
	return n.has_session_history_entry_and_ready_callback_(n.html_model_handle_)
}

pub fn (n &Navigable) delays_the_load_event_of_its_container() bool {
	if n.html_model_handle_ == unsafe { nil }
		|| n.delays_container_load_event_callback_ == unsafe { nil } {
		return false
	}
	return n.delays_container_load_event_callback_(n.html_model_handle_)
}

pub fn (n &Navigable) force_dark_enabled() bool {
	if n.html_model_handle_ == unsafe { nil }
		|| n.force_dark_enabled_callback_ == unsafe { nil } {
		return false
	}
	return n.force_dark_enabled_callback_(n.html_model_handle_)
}

pub fn (n &Navigable) set_needs_repaint() {
	if n.html_model_handle_ != unsafe { nil } && n.set_needs_repaint_callback_ != unsafe { nil } {
		n.set_needs_repaint_callback_(n.html_model_handle_)
	}
}

pub fn (n &Navigable) render_screenshot(config PaintConfig, node_id ?UniqueNodeID) []u8 {
	if n.html_model_handle_ != unsafe { nil } && n.render_screenshot_callback_ != unsafe { nil } {
		return n.render_screenshot_callback_(n.html_model_handle_, config, node_id)
	}
	return []
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#the-rules-for-choosing-a-navigable
// Returns the chosen navigable, the first of the rules' return values.
pub fn (n &Navigable) choose_a_navigable(name string, no_opener TokenizedFeatureNoOpener) ?&Navigable {
	if n.html_model_handle_ == unsafe { nil } || n.choose_a_navigable_callback_ == unsafe { nil } {
		return none
	}
	return n.choose_a_navigable_callback_(n.html_model_handle_, name, no_opener)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#navigate
// The referrer policy is the keyword of a referrerpolicy attribute state; an invalid or empty keyword is the empty
// string state.
pub fn (n &Navigable) navigate(url URL, source_document &Document, referrer_policy string, user_involvement UserNavigationInvolvement) ! {
	if n.html_model_handle_ == unsafe { nil } || n.navigate_callback_ == unsafe { nil } {
		return error('InvalidStateError: navigable has no navigation model')
	}
	n.navigate_callback_(n.html_model_handle_, url, source_document, referrer_policy, user_involvement)!
}

pub fn (n &Navigable) navigate_from_page(params PageNavigationParams) ! {
	if n.html_model_handle_ == unsafe { nil } || n.page_navigate_callback_ == unsafe { nil } {
		return error('InvalidStateError: navigable has no navigation model')
	}
	n.page_navigate_callback_(n.html_model_handle_, params)!
}

pub fn (n &Navigable) reload() {
	if n.html_model_handle_ == unsafe { nil } || n.reload_callback_ == unsafe { nil } {
		panic('Navigable has no reload model')
	}
	n.reload_callback_(n.html_model_handle_)
}

pub fn (n &Navigable) download_hyperlink(url URL, user_involvement UserNavigationInvolvement,
	source_element &Element, proposed_filename ?string, interface_origin Origin) {
	if n.html_model_handle_ == unsafe { nil } || n.download_hyperlink_callback_ == unsafe { nil } {
		return
	}
	n.download_hyperlink_callback_(n.html_model_handle_, url, user_involvement, source_element,
		proposed_filename, interface_origin)
}

pub fn (n &Navigable) reset_mouse_input_tracking() {
	if n.html_model_handle_ != unsafe { nil }
		&& n.reset_mouse_input_tracking_callback_ != unsafe { nil } {
		n.reset_mouse_input_tracking_callback_(n.html_model_handle_)
	}
}

pub fn (n &Navigable) active_document_id() ?UniqueNodeID {
	document := n.active_document_ or { return none }
	return document.unique_id()
}

pub fn (mut n Navigable) set_active_document(document ?&Document) {
	if old_document := n.active_document_ {
		is_same_document := if new_document := document {
			voidptr(old_document) == voidptr(new_document)
		} else {
			false
		}
		if !is_same_document {
			if linked_navigable := old_document.navigable() {
				if voidptr(linked_navigable) == voidptr(&n) {
					mut mutable_old_document := unsafe { &Document(old_document) }
					mutable_old_document.set_navigable(none)
				}
			}
		}
	}
	n.active_document_ = document
	if new_document := document {
		mut mutable_new_document := unsafe { &Document(new_document) }
		mutable_new_document.set_navigable(&n)
	}
	if n.html_model_handle_ != unsafe { nil }
		&& n.active_document_changed_ != unsafe { nil } {
		n.active_document_changed_(n.html_model_handle_, document)
	}
}

pub fn (mut n Navigable) remove_from_all_navigables() {
	n.set_active_document(none)
	dom_all_navigables = dom_all_navigables.filter(voidptr(it) != voidptr(&n))
}

fn register_navigable(navigable &Navigable) {
	for registered in dom_all_navigables {
		if voidptr(registered) == voidptr(navigable) {
			return
		}
	}
	dom_all_navigables << navigable
}

fn all_navigables() []&Navigable {
	return dom_all_navigables.clone()
}

pub fn (n &Navigable) parent() ?&Navigable {
	return n.parent_
}

pub fn (n &Navigable) traversable_navigable() ?&Navigable {
	mut current := unsafe { n }
	for !current.is_traversable() {
		current = current.parent() or { return none }
	}
	return current
}

pub fn (n &Navigable) top_level_traversable() &Navigable {
	mut current := unsafe { n }
	for {
		current = current.parent() or { return current }
	}
	return current
}

pub fn (n &Navigable) container_document() ?&Document {
	return n.container_document_
}

pub fn (n &Navigable) is_top_level_traversable() bool {
	return n.is_top_level_traversable_
}

pub fn (n &Navigable) is_traversable() bool {
	return n.is_top_level_traversable_
}

pub fn (n &Navigable) is_focused() bool {
	if n.html_model_handle_ != unsafe { nil } && n.is_focused_callback_ != unsafe { nil } {
		return n.is_focused_callback_(n.html_model_handle_)
	}
	return false
}

// Navigable's virtual destroyed-state query on the actual local identity.
pub fn (n &Navigable) has_been_destroyed() bool {
	return n.has_been_destroyed_
}

// The flag assignment from LocalNavigable::set_has_been_destroyed. Its other
// scroll/hover/compositor teardown steps belong to the local HTML owner.
pub fn (mut n Navigable) set_has_been_destroyed() {
	n.has_been_destroyed_ = true
}

pub fn (n &Navigable) system_visibility_state() VisibilityState {
	return .visible
}

// History methods
pub fn (mut h History) set_state(state JSValue) {
	h.state = state
}

// SessionHistoryEntry methods/fields
pub fn (she &SessionHistoryEntry) get_classic_history_api_state() DOMSerializationRecord {
	return she.classic_history_api_state
}

// HTMLParser bridge methods. The callbacks are supplied by html when it
// installs the document parsing hook.
pub fn (p &HTMLParser) abort() {
	if p.abort_callback != unsafe { nil } {
		p.abort_callback(p.target)
	}
}

pub fn (p &HTMLParser) feed(text string) {
	if p.feed_callback != unsafe { nil } {
		p.feed_callback(p.target, text)
	}
}

pub fn (p &HTMLParser) run() {
	if p.run_callback != unsafe { nil } {
		p.run_callback(p.target, false)
	}
}

pub fn (p &HTMLParser) run_until_insertion_point() {
	if p.run_callback != unsafe { nil } {
		p.run_callback(p.target, true)
	}
}

pub fn (p &HTMLParser) script_nesting_level() uint {
	if p.script_nesting_level_callback == unsafe { nil } {
		return 0
	}
	return p.script_nesting_level_callback(p.target)
}

pub fn (p &HTMLParser) is_script_created() bool {
	if p.is_script_created_callback == unsafe { nil } {
		return false
	}
	return p.is_script_created_callback(p.target)
}

pub fn (p &HTMLParser) is_insertion_point_defined() bool {
	if p.insertion_point_is_defined_callback == unsafe { nil } {
		return false
	}
	return p.insertion_point_is_defined_callback(p.target)
}

pub fn (p &HTMLParser) update_insertion_point() {
	if p.update_insertion_point_callback != unsafe { nil } {
		p.update_insertion_point_callback(p.target)
	}
}

pub fn (p &HTMLParser) insert_input_at_insertion_point(input string) {
	if p.insert_input_callback != unsafe { nil } {
		p.insert_input_callback(p.target, input)
	}
}

pub fn (p &HTMLParser) insert_eof() {
	if p.insert_eof_callback != unsafe { nil } {
		p.insert_eof_callback(p.target)
	}
}

pub fn (p &HTMLParser) finish_loading_after_parse() {
	if p.finish_loading_after_parse_callback != unsafe { nil } {
		p.finish_loading_after_parse_callback(p.target)
	}
}

// ViewTransition methods
pub fn (vt &ViewTransition) phase() ViewTransitionPhase {
	if vt.transition_ == unsafe { nil } {
		return .done
	}
	return match vt.transition_.phase {
		.pending_capture { .pending_capture }
		.update_callback_called { .update_callback_called }
		.animating { .animating }
		.done { .done }
	}
}

fn (vt &ViewTransition) sync_document_state() {
	if vt.document_ == unsafe { nil } || vt.transition_document_ == unsafe { nil } {
		return
	}
	mut document := unsafe { &Document(vt.document_) }
	document.set_rendering_suppression_for_view_transitions(vt.transition_document_.rendering_suppression)
	document.set_show_view_transition_tree(vt.transition_document_.show_view_transition_tree)
	vt.sync_transition_pseudo_tree()
	if vt.phase() == .done && document.active_view_transition == vt {
		document.active_view_transition = unsafe { nil }
	}
}

pub fn (vt &ViewTransition) setup_view_transition() {
	if vt.transition_ == unsafe { nil } || vt.transition_document_ == unsafe { nil } {
		return
	}
	mut transition := unsafe { &viewtransition.ViewTransition(vt.transition_) }
	transition.setup_view_transition()
	mut transition_document := unsafe { &viewtransition.TransitionDocument(vt.transition_document_) }
	if !vt.queue_pending_dom_tasks() { transition_document.drain_dom_tasks() }
	vt.sync_document_state()
}

pub fn (vt &ViewTransition) handle_transition_frame() {
	if vt.transition_ == unsafe { nil } {
		return
	}
	mut transition := unsafe { &viewtransition.ViewTransition(vt.transition_) }
	// The pinned upstream handle_transition_frame() leaves animation activity
	// detection as a FIXME and retains its initial false value.
	transition.handle_transition_frame(false)
	vt.sync_document_state()
}

pub fn (vt &ViewTransition) skip_the_view_transition() {
	vt.skip_with_reason(webidl.string_value('AbortError: View transition was skipped'))
}

pub enum ViewTransitionPhase {
	pending_capture
	update_callback_called
	animating
	done
}

// MediaQueryList methods
pub fn (mql &MediaQueryList) matches() bool {
	return mql.target != unsafe { nil } && mql.matches_callback != unsafe { nil } && mql.matches_callback(mql.target)
}

pub fn (mql &MediaQueryList) evaluate() bool {
	return mql.target != unsafe { nil } && mql.evaluate_callback != unsafe { nil } && mql.evaluate_callback(mql.target)
}

pub fn (mql &MediaQueryList) dispatch_change_event(matches bool) {
	if mql.target != unsafe { nil } && mql.dispatch_change_event_callback != unsafe { nil } {
		mql.dispatch_change_event_callback(mql.target, matches)
	}
}

pub fn (mql &MediaQueryList) has_changed_state() bool {
	return mql.target != unsafe { nil } && mql.has_changed_state_callback != unsafe { nil } && mql.has_changed_state_callback(mql.target)
}

pub fn (mql &MediaQueryList) set_has_changed_state(value bool) {
	if mql.target != unsafe { nil } && mql.set_has_changed_state_callback != unsafe { nil } {
		mql.set_has_changed_state_callback(mql.target, value)
	}
}

// CSSStyleSheet methods
pub fn (ss &CSSStyleSheet) source_text() ?string {
	return ss.source_text_
}

// StyleSheetList methods
pub fn (ssl &StyleSheetList) get_sheets() []&CSSStyleSheet {
	return ssl.sheets.clone()
}

// ViewportPaintable methods
pub fn (vp &ViewportPaintable) invalidate_scroll_state() {
	if vp.target != unsafe { nil } && vp.invalidate_scroll_state_callback != unsafe { nil } {
		vp.invalidate_scroll_state_callback(vp.target)
	}
}

// Whether every transform of the layout node's box stays invisible: an ancestor
// clip in the committed paint tree lies entirely outside the viewport. Returns
// false whenever the painting bridge cannot prove that.
pub fn (vp &ViewportPaintable) layout_subtree_is_clipped_outside_viewport(layout_handle voidptr) bool {
	if vp.target == unsafe { nil } || vp.subtree_clipped_outside_viewport_callback == unsafe { nil }
		|| layout_handle == unsafe { nil } {
		return false
	}
	return vp.subtree_clipped_outside_viewport_callback(vp.target, layout_handle)
}

pub fn (vp &ViewportPaintable) refresh_scroll_state() {
	if vp.target != unsafe { nil } && vp.refresh_scroll_state_callback != unsafe { nil } {
		vp.refresh_scroll_state_callback(vp.target)
	}
}

// Without a narrower embedder hook, a full assignment covers compositor samples.
pub fn (vp &ViewportPaintable) refresh_compositor_visual_contexts() {
	if vp.target != unsafe { nil } && vp.refresh_compositor_visual_contexts_callback != unsafe { nil } {
		vp.refresh_compositor_visual_contexts_callback(vp.target)
	} else {
		vp.assign_accumulated_visual_contexts()
	}
}

pub fn (vp &ViewportPaintable) assign_accumulated_visual_contexts() {
	if vp.target != unsafe { nil } && vp.assign_accumulated_visual_contexts_callback != unsafe { nil } {
		vp.assign_accumulated_visual_contexts_callback(vp.target)
	}
}

pub fn (vp &ViewportPaintable) selection() ?&Selection {
	if vp.target != unsafe { nil } && vp.selection_callback != unsafe { nil } {
		return vp.selection_callback(vp.target)
	}
	return none
}

pub fn (vp &ViewportPaintable) is_viewport_paintable() bool {
	return true
}

// ViewportPaintable retains this filtered list after layout so the HTML event
// loop does not have to traverse the complete paint tree every frame.
pub fn (mut vp ViewportPaintable) set_paintable_boxes_with_auto_content_visibility(paintable_boxes []&PaintableBox) {
	vp.paintable_boxes_with_auto_content_visibility_ = paintable_boxes.clone()
}

pub fn (vp &ViewportPaintable) paintable_boxes_with_auto_content_visibility() []&PaintableBox {
	return vp.paintable_boxes_with_auto_content_visibility_.clone()
}

pub fn (vp &ViewportPaintable) recompute_selection_states(range &Range) {
	if vp.target != unsafe { nil } && vp.recompute_selection_states_callback != unsafe { nil } {
		vp.recompute_selection_states_callback(vp.target, range)
	}
}

pub fn (vp &ViewportPaintable) text_range_rects(node &Node, state SelectionState,
	start_offset int, end_offset int) []DOMRect {
	if vp.target != unsafe { nil } && vp.text_range_rects_callback != unsafe { nil } {
		return vp.text_range_rects_callback(vp.target, node, state, start_offset, end_offset)
	}
	return []DOMRect{}
}

pub fn (vp &ViewportPaintable) transform_client_rects(node &Node,
	rects []CSSPixelRect_) []CSSPixelRect_ {
	if vp.target != unsafe { nil } && vp.transform_client_rects_callback != unsafe { nil } {
		return vp.transform_client_rects_callback(vp.target, node, rects)
	}
	return rects.clone()
}

pub fn (vp &ViewportPaintable) set_needs_repaint() {
	vp.set_needs_repaint_with_invalidation(.paint_commands_and_hit_test_list)
}

pub fn (vp &ViewportPaintable) set_needs_repaint_with_invalidation(invalidation InvalidateDisplayList) {
	if vp.target != unsafe { nil } && vp.set_needs_repaint_callback != unsafe { nil } {
		if invalidation == .paint_commands_and_hit_test_list {
			vp.invalidate_hit_test_display_list()
		}
		vp.set_needs_repaint_callback(vp.target)
	}
}

// Document::set_needs_repaint() invalidates the assembled display list but does
// not invalidate any PaintableBox command cache. The downstream painting bridge
// still needs this notification so its next record does not reuse that list.
fn (vp &ViewportPaintable) document_set_needs_repaint() {
	if vp.target != unsafe { nil } && vp.document_set_needs_repaint_callback != unsafe { nil } {
		vp.document_set_needs_repaint_callback(vp.target)
	}
}

pub fn (vp &ViewportPaintable) invalidate_all_paint_caches() {
	if vp.target != unsafe { nil } && vp.invalidate_all_paint_caches_callback != unsafe { nil } {
		vp.invalidate_all_paint_caches_callback(vp.target)
	}
}

pub fn (vp &ViewportPaintable) invalidate_hit_test_display_list() {
	if vp.target != unsafe { nil }
		&& vp.invalidate_hit_test_display_list_callback != unsafe { nil } {
		vp.invalidate_hit_test_display_list_callback(vp.target)
	}
}

pub fn (vp &ViewportPaintable) record_display_list() ?&DisplayList {
	if vp.document != unsafe { nil } {
		mut document := unsafe { &Document(vp.document) }
		document.update_paint_and_hit_testing_properties_if_needed()
	}
	if vp.target != unsafe { nil } && vp.record_display_list_callback != unsafe { nil } {
		return vp.record_display_list_callback(vp.target)
	}
	return none
}

pub fn (vp &ViewportPaintable) build_stacking_context_tree_if_needed() {
	if vp.target != unsafe { nil } && vp.build_stacking_context_tree_callback != unsafe { nil } {
		vp.build_stacking_context_tree_callback(vp.target)
	}
}

pub fn (vp &ViewportPaintable) stacking_context() ?&StackingContext {
	if vp.target != unsafe { nil } && vp.stacking_context_callback != unsafe { nil } {
		return vp.stacking_context_callback(vp.target)
	}
	return none
}

pub fn (vp &ViewportPaintable) invalidate_stacking_context() {
	if vp.target != unsafe { nil } && vp.invalidate_stacking_context_callback != unsafe { nil } {
		vp.invalidate_stacking_context_callback(vp.target)
	}
}

pub fn (vp &ViewportPaintable) hit_test(x f64, y f64, type_ HitTestType) ?HitTestResult {
	if vp.document != unsafe { nil } {
		mut document := unsafe { &Document(vp.document) }
		document.update_paint_and_hit_testing_properties_if_needed()
	}
	if vp.target != unsafe { nil } && vp.hit_test_callback != unsafe { nil } {
		return vp.hit_test_callback(vp.target, x, y, type_)
	}
	return none
}

pub fn (vp &ViewportPaintable) hit_test_all(x f64, y f64, mut results []&Element) {
	if vp.document != unsafe { nil } {
		mut document := unsafe { &Document(vp.document) }
		document.update_paint_and_hit_testing_properties_if_needed()
	}
	if vp.target != unsafe { nil } && vp.hit_test_all_callback != unsafe { nil } {
		results << vp.hit_test_all_callback(vp.target, x, y)
	}
}

pub struct HitTestResult {
pub:
	// `element` remains the CSSOM/event compatibility target. Painting's source
	// result owns the exact DOM node as well, which is required for text cursor
	// placement inside a Text node.
	element             &Element = unsafe { nil }
	node                &Node = unsafe { nil }
	chrome_widget_id    string
	index_in_node       int
	caret_rect          ?CSSPixelRect_
	vertical_distance   ?f64
	horizontal_distance ?f64
}

pub fn retarget_from_ua_internal_shadow_root(element &Element) &Element {
	mut result := unsafe { &Element(element) }
	for {
		shadow_root := result.as_node().containing_shadow_root() or { return result }
		if !shadow_root.is_user_agent_internal() || shadow_root.host_ == unsafe { nil } {
			return result
		}
		result = shadow_root.host_
	}
	return result
}

pub enum HitTestType {
	exact
	text_cursor
}

@[heap]
pub struct StackingContext {
pub:
	concrete_handle voidptr = unsafe { nil }
	dump_callback   StackingContextDumpCallback = unsafe { nil }
}

pub fn (sc &StackingContext) dump() string {
	if sc.concrete_handle != unsafe { nil } && sc.dump_callback != unsafe { nil } {
		return sc.dump_callback(sc.concrete_handle)
	}
	return ''
}

pub type StackingContextDumpCallback = fn (voidptr) string

// DisplayList methods
pub fn (dl &DisplayList) command_count() int {
	return dl.command_count_
}

pub fn (dl &DisplayList) dump() string {
	if dl.concrete_handle != unsafe { nil } && dl.dump_callback != unsafe { nil } {
		return dl.dump_callback(dl.concrete_handle)
	}
	return ''
}

// IntersectionObserver methods
pub fn (io &IntersectionObserver) observation_targets() []IntersectionObserverObservationTarget {
	if io.observation_targets_ == unsafe { nil } {
		return []
	}
	return io.observation_targets_(io.target)
}

pub fn (io &IntersectionObserver) observe(element &Element) {
	if io.observe_target != unsafe { nil } {
		io.observe_target(io.target, element)
	}
}

pub fn (io &IntersectionObserver) unobserve(element &Element) {
	if io.unobserve_target != unsafe { nil } {
		io.unobserve_target(io.target, element)
	}
}

pub fn (ro &ResizeObserver) gather_active_observations_at_depth(depth int) {
	if ro.target != unsafe { nil } && ro.gather_at_depth != unsafe { nil } {
		ro.gather_at_depth(ro.target, depth)
	}
}

pub fn (ro &ResizeObserver) broadcast_active_resize_observations() int {
	if ro.target == unsafe { nil } || ro.broadcast == unsafe { nil } {
		return max_int
	}
	return ro.broadcast(ro.target)
}

pub fn (ro &ResizeObserver) has_active_observations() bool {
	return ro.target != unsafe { nil } && ro.has_active != unsafe { nil } && ro.has_active(ro.target)
}

pub fn (ro &ResizeObserver) has_skipped_observations() bool {
	return ro.target != unsafe { nil } && ro.has_skipped != unsafe { nil } && ro.has_skipped(ro.target)
}

// FormAssociatedElement methods
pub fn (fae &FormAssociatedElement) element_id_changed() {
	if fae.target != unsafe { nil } && fae.element_id_changed_callback != unsafe { nil } {
		fae.element_id_changed_callback(fae.target)
	}
}

pub fn (fae &FormAssociatedElement) element_with_id_was_added_or_removed() {
	if fae.target != unsafe { nil } && fae.element_with_id_added_or_removed_callback != unsafe { nil } {
		fae.element_with_id_added_or_removed_callback(fae.target)
	}
}

// Timer methods
pub fn (mut t Timer) start() {
	t.active = true
}

pub fn (mut t Timer) restart() {
	t.active = true
}

pub fn (mut t Timer) stop() {
	t.active = false
}

pub fn (mut t Timer) fire() {
	if !t.active || (t.callback == unsafe { nil } && t.context_callback == unsafe { nil }) {
		return
	}
	if !t.repeating {
		t.active = false
	}
	if t.context_callback != unsafe { nil } {
		t.context_callback(t.callback_context)
	} else {
		t.callback()
	}
}

pub fn (t &Timer) is_active() bool {
	return t.active
}

// NodeList extra fields
pub fn (nl &NodeList) items() []&Node {
	return nl.collection()
}

// NodeIterator/TreeWalker extra fields (adding to constructors above)

// Origin methods
pub fn (o &Origin) effective_domain() ?string {
	record := o.liburl_origin() or { return none }
	host := record.effective_domain() or { return none }
	return host.serialize()
}

// Document helper methods referenced by implementations
pub fn (d &Document) paintable_box() ?&ViewportPaintable {
	return d.paintable()
}

pub fn (d &Document) viewport_rect() Rect {
	return d.viewport_rect_
}

pub fn (mut d Document) set_viewport_rect(rect Rect) {
	scroll_offset_changed := d.viewport_rect_.x != rect.x || d.viewport_rect_.y != rect.y
	viewport_size_changed := d.viewport_rect_.width != rect.width || d.viewport_rect_.height != rect.height
	d.viewport_rect_ = rect
	if viewport_size_changed {
		d.set_needs_media_query_evaluation()
	}
	if scroll_offset_changed {
		d.invalidate_scroll_state()
		// LocalNavigable::perform_scroll_of_viewport_scrolling_box() retains the
		// display list upstream. Scroll snapshots are lowered into this port's
		// commands, so re-record them while keeping the scroll-independent
		// hit-test plan.
		d.mark_needs_repaint_internal(.paint_commands, true)
	}
}

pub fn (d &Document) is_svg_image_document() bool {
	return d.is_svg_image_document_
}

pub fn (mut d Document) set_is_svg_image_document(value bool) {
	d.is_svg_image_document_ = value
}

pub fn (d &Document) navigable() ?&Navigable {
	if d.navigable_ == unsafe { nil } {
		return none
	}
	return d.navigable_
}

pub fn (d &Document) in_quirks_mode() bool {
	return d.quirks_mode == .yes
}

pub fn (d &Document) for_each_shadow_including_descendant(callback fn (&Node) TraversalDecision) TraversalDecision {
	document_node := unsafe { &Node(d) }
	return document_node.for_each_shadow_including_descendant(callback)
}

pub fn (d &Document) visit_shadow_including_descendants(callback fn (&Node) TraversalDecision) TraversalDecision {
	document_node := unsafe { &Node(d) }
	return document_node.visit_shadow_including_descendants(callback)
}

pub fn (mut d Document) notify_each_document_observer_completely_loaded() {
	d.document_observers_being_notified = d.document_observers.clone()
	for observer in d.document_observers_being_notified {
		if callback := observer.document_completely_loaded() {
			callback()
		}
	}
	d.document_observers_being_notified.clear()
}

pub fn (mut d Document) notify_each_document_observer_visibility_state() {
	d.document_observers_being_notified = d.document_observers.clone()
	for observer in d.document_observers_being_notified {
		if callback := observer.document_visibility_state_observer() {
			callback(d.visibility_state)
		}
	}
	d.document_observers_being_notified.clear()
}

pub fn (mut d Document) notify_each_document_observer_became_inactive() {
	d.document_observers_being_notified = d.document_observers.clone()
	for observer in d.document_observers_being_notified {
		if callback := observer.document_became_inactive() {
			callback()
		}
	}
	d.document_observers_being_notified.clear()
}

pub fn (mut d Document) notify_each_document_observer_became_active() {
	d.document_observers_being_notified = d.document_observers.clone()
	for observer in d.document_observers_being_notified {
		if callback := observer.document_became_active() {
			callback()
		}
	}
	d.document_observers_being_notified.clear()
}

pub fn (mut d Document) notify_each_document_observer_readiness() {
	d.document_observers_being_notified = d.document_observers.clone()
	for observer in d.document_observers_being_notified {
		if callback := observer.document_readiness_observer() {
			callback(d.readiness)
		}
	}
	d.document_observers_being_notified.clear()
}

pub fn (mut d Document) notify_each_document_observer_page_showing() {
	d.document_observers_being_notified = d.document_observers.clone()
	for observer in d.document_observers_being_notified {
		if callback := observer.document_page_showing_observer() {
			callback(d.page_showing)
		}
	}
	d.document_observers_being_notified.clear()
}

pub fn (mut d Document) evaluate_media_rules() {
	hook := d.style_update_hook_ or { return }
	if hook.evaluate_media_rules != unsafe { nil } {
		hook.evaluate_media_rules(hook.target)
	}
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#unloading-document-cleanup-steps
pub fn (mut d Document) run_unloading_cleanup_steps() {
	hook := d.lifecycle_hook_ or {
		d.fully_exit_fullscreen()
		return
	}
	if hook.run_unloading_cleanup_steps != unsafe { nil } {
		hook.run_unloading_cleanup_steps(hook.target, d)
	} else {
		d.fully_exit_fullscreen()
	}
}

fn (mut d Document) mark_needs_repaint(invalidation InvalidateDisplayList) {
	d.mark_needs_repaint_internal(invalidation, false)
}

fn (mut d Document) mark_needs_repaint_internal(invalidation InvalidateDisplayList, viewport_scroll_only bool) {
	// Document repaint requests do not invalidate PaintableBox phase caches.
	// PaintCommands keeps the retained hit-test plan, while the full mode drops
	// it as well. No is used by compositor-only changes.
	if invalidation != .no {
		if viewport_scroll_only {
			d.cached_display_list_ = unsafe { nil }
		} else {
			d.invalidate_display_list()
		}
	} else if !viewport_scroll_only {
		d.paint_content_revision_++
	}
	d.needs_repaint = true
	if paintable := d.unsafe_paintable() {
		if invalidation == .paint_commands_and_hit_test_list {
			paintable.invalidate_hit_test_display_list()
		}
		paintable.document_set_needs_repaint()
	}
	d.request_frame()
}

pub fn (mut d Document) set_needs_repaint() {
	d.mark_needs_repaint(.paint_commands_and_hit_test_list)
}

pub fn (mut d Document) set_needs_repaint_with_invalidation(invalidation InvalidateDisplayList) {
	d.mark_needs_repaint(invalidation)
}

pub fn (d &Document) request_frame() {
	if d.page_ != unsafe { nil } {
		d.page_.client_request_frame()
	}
}

pub fn (mut d Document) insert_in_potentially_named_elements(element &Element) {
	if element !in d.potentially_named_elements {
		d.potentially_named_elements << element
	}
}

pub fn (mut d Document) remove_from_potentially_named_elements(element &Element) {
	d.potentially_named_elements = d.potentially_named_elements.filter(it != element)
}

pub fn (mut d Document) add_element_by_id(id string, element &Element) {
	mut id_map := unsafe { &ElementByIdMap(element.document_or_shadow_root_element_by_id_map()) }
	id_map.add(id, element)
}

pub fn (mut d Document) remove_element_by_id(id string, element &Element) {
	mut id_map := unsafe { &ElementByIdMap(element.document_or_shadow_root_element_by_id_map()) }
	id_map.remove(id, element)
}

pub fn (mut d Document) enqueue_custom_element_reaction_element(element &Element) {
	for queued in d.custom_element_reaction_backup_queue {
		if queued == element {
			return
		}
	}
	d.custom_element_reaction_backup_queue << element
	d.processing_custom_element_reaction_backup_queue = true
}

pub fn (mut d Document) append_child(child &Element) {
	mut document_node := unsafe { &Node(&d) }
	document_node.append_child(child.as_node()) or {}
}

pub fn (mut d Document) dispatch_event_simple(event_name string, bubbles bool) {
	document_node := unsafe { &Node(&d) }
	document_node.dispatch_event_simple(event_name, bubbles)
}

pub fn (d &Document) sanitize_clipboard_html(range &Range, html string) !string {
	hook := d.editing_command_hook_ or {
		return error('clipboard HTML sanitizer is not installed')
	}
	if hook.sanitize_clipboard_html == unsafe { nil } {
		return error('clipboard HTML sanitizer is not installed')
	}
	return hook.sanitize_clipboard_html(hook.target, range, html)
}

// XPath lives in its own package and imports DOM nodes, so Document reaches it
// through this narrow callback bridge instead of forming a package cycle.
pub fn install_xpath_bridge(create_expression XPathCreateExpressionCallback, evaluate XPathEvaluateCallback) {
	dom_xpath_bridge = &XPathBridge{
		create_expression: create_expression
		evaluate:          evaluate
	}
}

pub fn xpath_create_expression(expression string, resolver ?&XPathNSResolver) !&XPathExpression {
	if dom_xpath_bridge == unsafe { nil } || dom_xpath_bridge.create_expression == unsafe { nil } {
		return error('NotSupportedError: XPath evaluator is not installed')
	}
	return dom_xpath_bridge.create_expression(expression, resolver)
}

pub fn xpath_evaluate(expression string, context_node &Node, resolver ?&XPathNSResolver, type_ u16, result ?&XPathResult) !&XPathResult {
	if dom_xpath_bridge == unsafe { nil } || dom_xpath_bridge.evaluate == unsafe { nil } {
		return error('NotSupportedError: XPath evaluator is not installed')
	}
	return dom_xpath_bridge.evaluate(expression, context_node, resolver, type_, result)
}

pub const max_int = 2147483647

pub enum TraversalDecision {
	@continue
	skip_children_and_continue
	@break
}

// --- Inline stubs for html/css module functions (avoiding circular imports) ---

// html module constants
const tag_html_ = 'html'
const tag_head_ = 'head'
const tag_body_ = 'body'
const tag_div_ = 'div'

const event_unload_ = 'unload'
const event_pagehide_ = 'pagehide'
const event_readystatechange_ = 'readystatechange'
const event_visibilitychange_ = 'visibilitychange'

const namespace_html_ = 'http://www.w3.org/1999/xhtml'

// html module functions
fn url_matches_about_blank(url URL) bool {
	return url.value == 'about:blank'
}

fn url_matches_about_srcdoc(url URL) bool {
	return url.value == 'about:srcdoc'
}

fn is_html_frame_set_element(el &HTMLElement) bool {
	element := unsafe { &Element(el) }
	return element.namespace_uri() or { '' } == namespace_html_ && element.local_name() == 'frameset'
}

// https://w3c.github.io/hr-time/#dfn-current-high-resolution-time
fn current_high_resolution_time(global_obj &Window) f64 {
	// The current high resolution time given a global object current global must return the result of relative high
	// resolution time given unsafe shared current time and current global.
	mut context := highresolutiontime.TimeOriginContext{}
	if global_obj != unsafe { nil } && global_obj.associated_document_ != unsafe { nil } {
		// NB: A Window's relevant settings object, which HTML owns, answers its time origin with the associated
		//     Document's load timing info's navigation start time. Its cross-origin isolated capability is still
		//     always "No" upstream.
		context = highresolutiontime.TimeOriginContext{
			time_origin: global_obj.associated_document_.load_timing_info.navigation_start_time
		}
	}
	return highresolutiontime.relative_high_resolution_time(highresolutiontime.unsafe_shared_current_time(),
		context)
}

fn relevant_global_object_for_doc(doc &Document) &Window {
	if doc.window != unsafe { nil } {
		return doc.window
	}
	mut window := &Window{
		associated_document_: doc
	}
	window.data.kind = .window
	return window
}

fn as_navigable_container(node &Node) ?&NavigableContainer {
	for navigable in dom_all_navigables {
		container := navigable.container() or { continue }
		if voidptr(container) == voidptr(node) {
			return &NavigableContainer{
				content_navigable_: navigable
			}
		}
	}
	return none
}

fn html_entry_global_associated_document(document &Document) &Document {
	hook := document.html_navigation_hook_ or { return document }
	if hook.entry_associated_document == unsafe { nil } {
		return document
	}
	return hook.entry_associated_document(document)
}

fn html_perform_url_and_history_update_steps(document &Document, url URL) ! {
	hook := document.html_navigation_hook_ or {
		mut mutable_document := unsafe { &Document(document) }
		mutable_document.set_url(url)
		return
	}
	if hook.update_url_and_history == unsafe { nil } {
		mut mutable_document := unsafe { &Document(document) }
		mutable_document.set_url(url)
		return
	}
	hook.update_url_and_history(document, url)!
}

enum CssStyleInvalidationReason {
	base_url_changed
	hover_changed
	style_sheet_changed
	dom_mutation
}

// --- Enums ---
pub enum NodeType {
	invalid                     = 0
	element_node                = 1
	attribute_node              = 2
	text_node                   = 3
	cdata_section_node          = 4
	entity_reference_node       = 5
	entity_node                 = 6
	processing_instruction_node = 7
	comment_node                = 8
	document_node               = 9
	document_type_node          = 10
	document_fragment_node      = 11
	notation_node               = 12
}

pub enum QuirksMode {
	no
	limited
	yes
}

pub enum DocumentReadyState {
	loading
	interactive
	complete
}

pub enum VisibilityState {
	visible
	hidden
}

pub enum DocumentType_ {
	xml
	html
}

pub enum TemporaryDocumentForFragmentParsing {
	no
	yes
}

pub enum FocusTrigger {
	other
	click
	key
	focus
	script
}

pub enum ImageRendering {
	auto_
	crisp_edges
	high_quality
	pixelated
	smooth
}

pub enum PseudoClass {
	hover
	active
	focus
	focus_within
	focus_visible
	target
	visited
	link
}

pub enum PseudoElement {
	after
	backdrop
	before
	details_content
	file_selector_button
	first_letter
	first_line
	marker
	part
	placeholder
	selection
	slider_fill
	slider_thumb
	slider_track
	slotted
	view_transition
	view_transition_group
	view_transition_image_pair
	view_transition_new
	view_transition_old
	known_pseudo_element_count
	unknown_webkit
}

pub enum InvalidateLayoutTreeReason {
	document_add_an_element_to_the_top_layer
	document_request_an_element_to_be_removed_from_the_top_layer
	document_immediately_remove_element_from_the_top_layer
	document_pending_top_layer_removals_processed
}

pub enum UpdateLayoutReason {
	auto_scroll_selection
	child_document_style_update
	cursor_line_navigation
	debugging
	document_caret_position_from_point
	document_element_from_point
	document_elements_from_point
	document_find_matching_text
	document_readiness_complete
	document_set_design_mode
	dump_display_list
	element_check_visibility
	element_client_height
	element_client_width
	element_get_client_rects
	element_is_potentially_scrollable
	element_scroll
	element_scroll_height
	element_scroll_into_view
	element_scroll_left
	element_scroll_top
	element_scroll_width
	element_set_scroll_left
	element_set_scroll_top
	event_handler_dispatch_chrome_widget_event
	event_handler_handle_drag_and_drop
	event_handler_handle_mouse_down
	event_handler_handle_mouse_move
	event_handler_handle_mouse_up
	event_handler_handle_mouse_wheel
	event_handler_run_activation_behavior
	font_face_set_ready
	event_handler_show_context_menu
	html_element_get_the_text_steps
	html_element_offset_height
	html_element_offset_left
	html_element_offset_parent
	html_element_offset_top
	html_element_offset_width
	html_element_scroll_parent
	html_event_loop_rendering_update
	html_image_element_height
	html_image_element_width
	html_image_element_x
	html_image_element_y
	html_input_element_height
	html_input_element_width
	html_label_element_activation_behavior
	hosted_document_before_paint
	inspect_dom_tree
	internals_hit_test
	media_query_list_matches
	navigable_selected_text
	navigable_viewport_scroll
	node_name_or_description
	range_get_client_rects
	resolved_css_style_declaration_property
	svg_decoded_image_data_render
	scroll_cursor_into_view
	process_screenshot
	svg_graphics_element_get_bbox
	source_set_normalize_source_densities
	view_transition_capture
	window_scroll
}

pub enum PolicyControlledFeature as u8 {
	autoplay
	camera
	encrypted_media
	focus_without_user_activation
	fullscreen
	gamepad
	microphone
	window_management
}

pub struct SandboxingFlagSet {

	// SandboxingFlagSet is owned by LibWeb/HTML upstream. DOM cannot import the
	// html module in V, so retain its wire-compatible bitset at this boundary.
	// The named fields remain for DOM algorithms which consume individual flags.
pub mut:
	bits                      u32
	sandboxed_document_domain bool
	sandboxed_forms           bool
}

pub enum OpenerPolicyValue {
	unsafe_none
	same_origin_allow_popups
	same_origin
	same_origin_plus_coep
}

pub enum NavigationType {
	push
	replace
	reload
	traverse
}

pub enum CaseSensitivity {
	case_sensitive
	case_insensitive
}

pub enum EnvironmentVariable {
	preferred_text_scale
	safe_area_inset_bottom
	safe_area_inset_left
	safe_area_inset_right
	safe_area_inset_top
	safe_area_max_inset_bottom
	safe_area_max_inset_left
	safe_area_max_inset_right
	safe_area_max_inset_top
	viewport_segment_bottom
	viewport_segment_height
	viewport_segment_left
	viewport_segment_right
	viewport_segment_top
	viewport_segment_width
}

pub enum InjectionSink {
	document_write
	document_writeln
}

pub enum AddLineFeed {
	yes
	no
}

// Cycle-breaking representation of TrustedTypes::TrustedHTML at the DOM API
// boundary. TrustedTypes depends on DOM through its element/sink algorithms,
// so DOM cannot import the concrete TrustedHTML class. HTML bindings unwrap
// that class into this value while retaining its trusted identity.
pub struct TrustedHTMLValue {
pub:
	data string
}

pub type TrustedHTMLOrString = TrustedHTMLValue | string

// --- Supporting structs ---
pub struct DocumentLoadTimingInfo {
pub mut:
	navigation_start_time               f64
	dom_loading_time                    f64
	dom_interactive_time                f64
	dom_content_loaded_event_start_time f64
	dom_content_loaded_event_end_time   f64
	dom_complete_time                   f64
	load_event_start_time               f64
	load_event_end_time                 f64
}

pub struct DocumentUnloadTimingInfo {
pub mut:
	unload_event_start_time f64
	unload_event_end_time   f64
}

pub struct ElementCreationOptions {
pub mut:
	custom_element_registry ?voidptr
	is_                     ?string
}

struct RegistryAndIs {
	registry voidptr = unsafe { nil }
	is_value ?string
}

pub struct ImportNodeOptions {
pub mut:
	custom_element_registry voidptr = unsafe { nil }
	self_only               bool
}

pub struct PendingFullscreenEvent {
pub mut:
	type_   PendingFullscreenEventType
	element &Element = unsafe { nil }
}

pub enum PendingFullscreenEventType {
	change
	error
}

pub struct PendingScrollEvent {
pub mut:
	target  &Node = unsafe { nil }
	event_target ?&EventTarget
	type_   string
	bubbles bool
}

fn (event PendingScrollEvent) target_identity() voidptr {
	if target := event.event_target { return voidptr(target) }
	return voidptr(event.target)
}

pub struct PendingAnimationEvent {
pub mut:
	event                &Event = unsafe { nil }
	animation            &Animation = unsafe { nil }
	target               &EventTarget = unsafe { nil }
	scheduled_event_time ?f64
	// CSS events have no default action. Keep their small input record until
	// delivery and create an Event only when the current dispatch path has a
	// listener. Earlier events may install listeners for later queued events.
	event_factory fn (&PendingAnimationEvent) &Event = unsafe { nil }
	event_type string
	event_name string
	event_elapsed_time f64
	event_pseudo_element string
	event_time_stamp f64
}

pub struct OpenerPolicy {
pub mut:
	value OpenerPolicyValue = .unsafe_none
}

pub struct StepsToFireBeforeunloadResult {
pub mut:
	unload_prompt_shown    bool
	unload_prompt_canceled bool
}

pub struct VisualViewportState {
pub mut:
	scale  f64 = 1.0
	width  f64
	height f64
}

pub struct TopOfTheDocument {}

pub struct StyleInvalidationCounters {
pub mut:
	style_engine_reaction_batch_runs                    u64
	style_engine_reaction_elements                      u64
	style_engine_published_reactions                    u64
	style_engine_record_deltas_applied                  u64
	style_engine_materialized_gaps                      u64
	unchanged_style_record_deltas                       u64
	style_record_property_diffs_skipped                 u64
	style_record_property_damage_cache_hits             u64
	element_computed_style_changes                      u64
	committed_style_observer_consequences               u64
	element_style_shared_computations                   u64
	element_style_input_changed_by_parent_style         u64
	element_style_input_changed_by_parent_custom_properties u64
	element_style_input_reused                          u64
	engine_computed_style_records                       u64
	animated_style_reconstruction_fallbacks             u64
	animated_style_overlay_builds                       u64
	animated_style_full_builds                          u64
	animation_frame_pump_requests                       u64
	animation_style_skip_cache_hits                     u64
	animation_style_skip_cache_misses                   u64
	animation_timeline_synchronizations                 u64
	animation_timeline_associated_animation_updates     u64
	compositor_visual_animation_updates                 u64
	compositor_visual_animation_timing_anchor_updates   u64
	compositor_keyframe_value_resolutions               u64
	base_style_partial_builds                           u64
	base_style_full_builds                              u64
	computed_longhand_evaluations                       u64
	style_stabilization_epochs                          u64
	style_stabilization_feedback_epochs                 u64
	provisional_style_passes                            u64
	style_stabilization_round_guard_hits                u64
	style_update_pass_guard_hits                        u64
	exact_stabilization_passes                          u64
	style_stabilization_bound_failures                  u64
	provisional_animation_events                        u64
	committed_animation_events                          u64
	provisional_transition_decisions                    u64
	superseded_provisional_transition_decisions         u64
	committed_transition_actions                        u64
	committed_transitions_started                       u64
	media_rule_evaluations                              u64
	registered_properties_cache_rebuilds                u64
	scope_rule_cache_builds                             u64
	style_engine_transaction_setups                     u64
	style_engine_transaction_setup_microseconds         u64
	style_engine_planning_microseconds                  u64
	relayouts_performed                                 u64
	style_update_microseconds                           u64
	style_recompute_microseconds                        u64
	custom_property_resolutions                         u64
	custom_property_elements                            u64
	custom_property_value_computations                  u64
	custom_property_overlay_hits                        u64
	custom_property_cycle_participants                  u64
	style_cascade_microseconds                          u64
	style_values_microseconds                           u64
	scrollable_overflow_recalculations                  u64
	has_ancestor_walk_invocations               u64
	has_ancestor_walk_visits                    u64
	has_ancestor_sibling_element_checks         u64
	has_invalidation_metadata_candidates        u64
	has_match_invocations                       u64
	has_result_cache_hits                       u64
	has_result_cache_misses                     u64
	full_style_invalidations                    u64
	style_invalidations                         u64
	element_style_recomputations                u64
	element_style_noop_recomputations           u64
	element_inherited_style_recomputations      u64
	element_inherited_style_noop_recomputations u64
	previous_sibling_invalidation_walk_visits  u64
	style_query_container_scans                u64
	size_query_container_scan_visits           u64
}

// --- Main Document struct ---
@[heap]
pub struct Document {
	ParentNode

	// Core identity
pub mut:
	type_                      DocumentType_ = .xml
	content_type               string = 'application/xml'
	url                        URL = url_about_blank()
	origin_                    Origin = origin_create_opaque()
	referrer                   string
	custom_element_definitions []&CustomElementDefinition
	custom_element_registry_   voidptr = unsafe { nil }
	source                     string

	// Version tracking
	dom_tree_version                         u64
	// Local names are immutable. Keep a conservative history without retaining
	// elements, so an absent tag can rule out document-wide selector walks.
	seen_element_local_names_                map[string]u64
	seen_element_classes_ map[string]bool
	seen_element_classes_unknown_ bool
	seen_element_class_bytes_ int
	character_data_version                   u64
	option_selectedness_update_index_counter u64
	style_environment_version_               u64

	// Readiness
	readiness                 DocumentReadyState = .complete
	ready_for_post_load_tasks bool
	ready_to_run_scripts      bool
	deferred_parser_start     ?fn ()
	scripting_enabled_by_embedder_ bool = true
	font_size_keyword_policy_ FontSizeKeywordPolicy
	font_rendering_policy_ FontRenderingPolicy
	layout_coordinate_scale_ f64
	display_device_pixel_ratio_ f64
	embedder_window_inactive_ bool

	// Encoding
	encoding                    ?string
	pragma_set_default_language ?string
	http_content_language       ?string
	meta_referrer_policy_       string
	enforced_meta_csp_policies_ []string
	last_declarative_refresh_   ?string

	// Quirks mode
	quirks_mode                   QuirksMode = .no
	parser_cannot_change_the_mode bool

	// Navigation
	navigation_id          ?string
	about_base_url         ?URL
	is_initial_about_blank bool
	opener_policy          OpenerPolicy

	// Browsing context
	browsing_context &BrowsingContext = unsafe { nil }
	page_            &Page = unsafe { nil }

	// Style
	style_computer                      &StyleComputer = unsafe { nil }
	font_computer                       &FontComputer = unsafe { nil }
	style_sheets_                       &StyleSheetList = unsafe { nil }
	style_update_hook_                  ?DocumentStyleUpdateHook
	background_style_hook_              ?DocumentBackgroundStyleHook
	scroll_style_hook_                  ?DocumentScrollStyleHook
	viewport_scroll_snap_hook_          ?DocumentViewportScrollSnapHook
	viewport_snapped_areas_x_           []ScrollSnapAreaReference_
	viewport_snapped_areas_y_           []ScrollSnapAreaReference_
	css_animation_timeline_update_hook_ ?DocumentCSSAnimationTimelineUpdateHook
	css_animation_event_hook_           ?DocumentCSSAnimationEventHook
	animations_hook_                    ?DocumentAnimationsHook
	temporary_execution_context_hook_   ?DocumentTemporaryExecutionContextHook
	inline_event_handler_compiler_      ?InlineEventHandlerCompiler
	event_callback_exception_reporter_ ?EventCallbackExceptionReporter
	lifecycle_hook_                     ?DocumentLifecycleHook
	event_loop_registered_              bool
	// dom<->css bridge: opaque handle to the css-side holder of this document's author stylesheets, which
	// the real StyleComputer's author cascade origin reads. See css/dom_css_bridge.v.
	author_style_sheets_handle                     voidptr = unsafe { nil }
	needs_full_style_update                        bool
	needs_full_layout_tree_update                  bool
	is_running_update_layout_                      bool
	layout_stabilization_count_                     int = -1
	layout_stabilization_count_tree_version_        u64
	query_containers_needing_container_query_evaluation_after_layout []&Element
	needs_animated_style_update                    bool
	needs_accumulated_visual_contexts_update       bool
	needs_compositor_visual_contexts_update        bool
	needs_invalidation_of_elements_affected_by_has bool
	should_invalidate_styles_on_attribute_changes  bool = true
	style_invalidation_counters_                   StyleInvalidationCounters
	layout_update_hook_                            ?DocumentLayoutUpdateHook
	rendered_text_hook_                            ?DocumentRenderedTextHook
	accessibility_role_hook_                       ?DocumentAccessibilityRoleHook
	csp_hook_                                      ?DocumentCSPHook
	meta_element_metadata_callback_                DocumentMetaElementMetadataCallback = unsafe { nil }
	trusted_types_hook_                            ?DocumentTrustedTypesHook
	html_navigation_hook_                          ?DocumentHTMLNavigationHook
	fullscreen_hook_                               ?DocumentFullscreenHook
	media_element_state_query_                     ?MediaElementStateQuery
	media_element_resource_attribute_changed_hook_ ?MediaElementResourceAttributeChangedHook
	media_element_source_attribute_changed_hook_   ?MediaElementSourceAttributeChangedHook
	media_element_controls_attribute_changed_hook_ ?MediaElementControlsAttributeChangedHook
	layout_engine_handle_                          voidptr = unsafe { nil }
	// Rendering-update generations that tell the CSS animation sampler when
	// none of its retained sample storage can be reached any longer (see
	// css/animation_samples.v). Layout publishes the scene numbers.
	layout_pass_generation             u64
	paint_scene_generation             u64
	oldest_live_paint_scene_generation u64
	// A hosting document copies this document's display list into its own
	// paint data, which outlives this document's rendering updates.
	paint_borrowed_by_host bool
	// Native shell snapshots retain/release their contiguous paint-tree slots.
	recycle_native_paint_trees bool
	compact_native_svg_backgrounds bool
	native_storage_ &platform.RetainedArena = unsafe { nil }
	native_storage_borrowed_ bool

	// Layout
	layout_root &LayoutViewport = unsafe { nil }
	paintable_  &ViewportPaintable = unsafe { nil }
	// SVGDecodedImageData owns an isolated XML document whose root SVG uses
	// the decoded image destination as its viewport instead of its intrinsic
	// width/height presentation attributes.
	is_svg_image_document_  bool
	svg_image_color_scheme_ ?string
	// Standalone documents use 800x600 until a browser host supplies its content viewport.
	viewport_rect_ Rect = Rect{0, 0, 800, 600}

	// Window
	window &Window = unsafe { nil }

	// Nodes
	hovered_node               &Node = unsafe { nil }
	inspected_node             &Node = unsafe { nil }
	highlighted_node           &Node = unsafe { nil }
	highlighted_pseudo_element ?PseudoElement
	focused_area               &Node = unsafe { nil }
	active_element_            &Element = unsafe { nil }
	target_element_            &Element = unsafe { nil }
	autofocus_candidates_      []&Element
	autofocus_processed_flag_  bool
	active_favicon             &Node = unsafe { nil }

	// Colors
	normal_link_color_      ?Color
	active_link_color_      ?Color
	visited_link_color_     ?Color
	supported_color_schemes ?[]string
	supported_color_schemes_are_only_ bool
	theme_color_            ?string

	// Focus
	last_focus_trigger FocusTrigger = .other

	// Parser
	parser                                  &HTMLParser = unsafe { nil }
	active_parser_was_aborted               bool
	html_parser_end_state_target            voidptr = unsafe { nil }
	html_parser_end_state_schedule_callback HTMLParserEndStateScheduleCallback = unsafe { nil }

	// State flags
	has_been_destroyed                         bool
	has_fired_document_became_inactive         bool
	editable                                   bool
	page_showing                               bool
	salvageable                                bool = true
	will_declaratively_refresh                 bool
	allow_declarative_shadow_roots             bool
	design_mode_enabled                        bool
	needs_to_call_page_did_load                bool
	cursor_blink_state                         bool
	cursor_blink_suppressed_                   bool
	fired_dom_content_loaded                   bool
	pending_module_readiness_scripts           int
	fired_load_event                           bool
	inside_exec_command                        bool
	running_editing_command_action             bool
	preserve_selection_offsets_during_identical_character_data_replacement_ bool
	css_styling_flag                           bool
	rendering_suppression_for_view_transitions bool
	show_view_transition_tree                  bool
	has_scheduled_selectionchange_event        bool
	intersection_observer_task_queued          bool
	needs_media_query_evaluation               bool

	// Scripts
	pending_parsing_blocking_script                 &HTMLScriptElement = unsafe { nil }
	pending_parsing_blocking_svg_script             &SVGScriptElement = unsafe { nil }
	scripts_to_execute_when_parsing_has_finished    []&HTMLScriptElement
	scripts_to_execute_in_order_as_soon_as_possible []&HTMLScriptElement
	scripts_to_execute_as_soon_as_possible          []&HTMLScriptElement
	current_script                                  &HTMLScriptElement = unsafe { nil }
	custom_element_reaction_backup_queue            []&Element
	processing_custom_element_reaction_backup_queue bool
	mutation_observer_microtask_queued              bool
	pending_mutation_observers                      []&MutationObserver
	signal_slots                                    []&HTMLSlotElement

	// Counters
	ignore_destructive_writes_counter         u32
	unload_counter                            u32
	throw_on_dynamic_markup_insertion_counter u32
	number_of_pending_style_sheet_requests int
	number_of_things_delaying_the_load_event  int

	// Template
	created_for_appropriate_template_contents    bool
	associated_inert_template_document           &Document = unsafe { nil }
	appropriate_template_contents_owner_document &Document = unsafe { nil }

	// Timing
	load_timing_info                       DocumentLoadTimingInfo
	previous_document_unload_timing        DocumentUnloadTimingInfo
	was_created_via_cross_origin_redirects bool

	// Fullscreen
	pending_fullscreen_events []PendingFullscreenEvent

	// Top layer
	top_layer_elements         []&Element
	top_layer_pending_removals []&Element

	// Popover
	showing_auto_popover_list  []&HTMLElement
	showing_hint_popover_list  []&HTMLElement
	popover_pointerdown_target &HTMLElement = unsafe { nil }

	// Dialogs
	open_dialogs_list         []&HTMLDialogElement
	dialog_pointerdown_target &HTMLDialogElement = unsafe { nil }

	// Collections
	applets_ &HTMLCollection = unsafe { nil }
	anchors_ &HTMLCollection = unsafe { nil }
	images_  &HTMLCollection = unsafe { nil }
	embeds_  &HTMLCollection = unsafe { nil }
	links_   &HTMLCollection = unsafe { nil }
	forms_   &HTMLCollection = unsafe { nil }
	scripts_ &HTMLCollection = unsafe { nil }
	all_     &HTMLAllCollection = unsafe { nil }
	fonts_   ?FontFaceSet

	// Selection & Base
	selection_                                   &Selection = unsafe { nil }
	first_base_element_with_href_in_tree_order   &HTMLBaseElement = unsafe { nil }
	first_base_element_with_target_in_tree_order &HTMLBaseElement = unsafe { nil }

	// History & Navigation
	history_     &History = unsafe { nil }
	latest_entry &SessionHistoryEntry = unsafe { nil }

	// Policy & Sandboxing
	active_sandboxing_flag_set SandboxingFlagSet
	policy_container_          &PolicyContainer = unsafe { nil }

	// Visibility
	visibility_state VisibilityState = .hidden

	// Last modified
	last_modified_ ?string

	// Animations
	default_timeline               &DocumentTimeline = unsafe { nil }
	associated_animation_timelines []AnimationTimelineHandle
	last_animation_frame_timestamp ?f64
	pending_animation_event_queue  []PendingAnimationEvent
	// Reused copies of the two lists above for update_animations_and_send_events().
	animation_timeline_scratch_ []AnimationTimelineHandle
	animation_event_scratch_    []PendingAnimationEvent
	transition_generation          int

	// Images
	list_of_available_images &ListOfAvailableImages = unsafe { nil }

	// Intersection observer
	lazy_load_intersection_observer &IntersectionObserver = unsafe { nil }

	// View transitions
	active_view_transition              &ViewTransition = unsafe { nil }
	dynamic_view_transition_style_sheet &CSSStyleSheet = unsafe { nil }
	view_transition_document_           &viewtransition.TransitionDocument = unsafe { nil }
	view_transition_promise_context_    webidl.PromiseContext
	update_callback_queue               []&ViewTransition

	// Visual viewport
	visual_viewport_           ?VisualViewport
	last_viewport_size         ?[2]int
	last_visual_viewport_state ?VisualViewportState

	// Pending scroll events
	pending_scroll_events []PendingScrollEvent

	// Cookie cache
	cookie_version       int = -1
	cookie_version_index ?int
	cookie_cache         string
	cookie_client_hook_  ?DocumentCookieClientHook

	// Display list cache
	cached_display_list_ &DisplayList = unsafe { nil }
	cached_display_list_viewport_only_ bool
	recording_viewport_only_ bool
	paint_content_revision_ u64

	// Segmenters (lazy)
	grapheme_segmenter_ &Segmenter = unsafe { nil }
	line_segmenter_     &Segmenter = unsafe { nil }
	word_segmenter_     &Segmenter = unsafe { nil }

	// Editing
	editing_host_manager_              &EditingHostManager = unsafe { nil }
	is_input_method_composing_         bool
	default_single_line_container_name string = 'div'
	command_state_override             map[string]bool
	command_value_override             map[string]string

	// Storage
	session_storage_holder &Storage = unsafe { nil }
	local_storage_holder   &Storage = unsafe { nil }

	// Observers & iterators (not visited to avoid leaks)
	node_iterators         []&NodeIterator
	document_observers     []&DocumentObserver
	intersection_observers []&IntersectionObserver
	resize_observers       []&ResizeObserver
	viewport_clients       []ViewportClient

	// Form associated elements
	form_associated_elements_with_form_attribute []&FormAssociatedElement
	potentially_named_elements                   []&Element
	element_by_id_map_                           &ElementByIdMap = unsafe { nil }
	anchor_name_map_                             AnchorNameMap

	// Render blocking
	render_blocking_elements        []&Element
	script_blocking_style_sheet_set []&Element
	pending_css_import_rules        []&CSSImportRule

	// Shadow roots
	shadow_roots []&ShadowRoot

	// Style scope & invalidator
	style_invalidator_ &StyleInvalidator = unsafe { nil }
	style_scope_       StyleScope

	// Registered properties
	registered_property_set                              map[string]CustomPropertyRegistration
	cached_registered_properties_from_css_property_rules map[string]CustomPropertyRegistration
	custom_property_registration_generation_             u64
	registered_counter_styles                            map[string]&CounterStyle

	// CSS random caching
	element_shared_css_random_base_value_cache map[string]f64

	// Selector query cache
	selector_query_cache                       map[string]?SelectorList
	selector_query_hook_                       ?DocumentSelectorQueryHook
	html_fragment_parsing_hook_                ?DocumentHTMLFragmentParsingHook
	editing_command_hook_                      ?DocumentEditingCommandHook
	editing_history_hook_                      ?DocumentEditingHistoryHook
	form_control_selected_text_callback_       DocumentFormControlSelectedTextCallback = unsafe { nil }
	form_control_input_events_target_callback_ DocumentFormControlInputEventsTargetCallback = unsafe { nil }
	theme_color_hook_                          ?DocumentThemeColorHook
	update_style_for_element_hook_             ?DocumentUpdateStyleForElementHook

	// SVG roots needing relayout
	svg_roots_needing_relayout []&SVGSVGBox

	// Misc
	shared_resource_requests_               map[string]&SharedResourceRequest
	speculative_fetch_urls_                 map[string]bool
	preloaded_resource_entries_             map[string]voidptr
	adopted_style_sheets                    []&CSSStyleSheet
	adopted_css_style_sheets_handle         voidptr = unsafe { nil }
	console_client_                         &ConsoleClient = unsafe { nil }
	cursor_blink_timer                      &Timer = unsafe { nil }
	active_refresh_timer                    &Timer = unsafe { nil }
	navigable_                              &Navigable = unsafe { nil }
	temporary_document_for_fragment_parsing TemporaryDocumentForFragmentParsing = .no
	media_query_lists                       []&MediaQueryList
	document_observers_being_notified       []&DocumentObserver
	// Extra fields for implementations
	implementation_            &DOMImplementation = unsafe { nil }
	location_                  &Location = unsafe { nil }
	completely_loaded_time     bool
	completely_loaded_deferred bool
	pointer_lock_element       &Element = unsafe { nil }
	is_svg_document            bool
	onreadystatechange_handler &CallbackType = unsafe { nil }
	onvisibilitychange_handler &CallbackType = unsafe { nil }
	onfullscreenchange_handler &CallbackType = unsafe { nil }
	onfullscreenerror_handler  &CallbackType = unsafe { nil }
	needs_repaint              bool
mut:
	// Registry entries transfer after descendant document pointers during adoption.
	// Keep no-shadow scope shortcuts disabled until every adopting callback finishes.
	style_scope_adoption_depth_ u32
}

// --- Constructor / Factory methods ---

// create_and_initialize corresponds to Document::create_and_initialize
// https://html.spec.whatwg.org/multipage/browsing-the-web.html#initialise-the-document-object
// https://html.spec.whatwg.org/multipage/origin.html#obtain-browsing-context-navigation
pub fn obtain_a_browsing_context_to_use_for_a_navigation_response(navigation_params &NavigationParams) &BrowsingContext {
	// 1. Let browsingContext be navigationParams's navigable's active browsing context.
	context := navigation_params.browsing_context or { return &BrowsingContext{} }

	// 2. A child browsing context is never replaced by COOP processing.
	if !context.is_top_level_ {
		return context
	}

	// 3-8. The implementation-defined cross-site and single-context options do
	// not change swapGroup in upstream either; the COOP enforcement result is
	// therefore authoritative here.
	if active_document := context.active_document_ {
		_ = active_document.origin().is_same_site(navigation_params.origin)
	}

	// 9. Keep the current context when no group switch is required. Report-only
	// isolation would give it a new virtual group identity. Upstream currently
	// leaves that substep as a FIXME, so preserve that behavior here.
	if !navigation_params.needs_a_browsing_context_group_switch {
		return context
	}

	// 10. Creating a top-level HTML browsing context is an embedding boundary.
	// The callback is installed by HTML; the standalone DOM loader retains the
	// previous active document in a distinct context identity.
	mut new_context := if navigation_params.create_top_level_browsing_context_target != unsafe { nil } && navigation_params.create_top_level_browsing_context_callback != unsafe { nil } {
		navigation_params.create_top_level_browsing_context_callback(navigation_params.create_top_level_browsing_context_target, navigation_params, context)
	} else {
		&BrowsingContext{
			active_document_: context.active_document_
			is_top_level_: true
		}
	}

	// 11-14. Propagate the final sandbox flags to the replacement context. The
	// spec requires an unsafe-none COOP value whenever those flags are nonempty.
	if navigation_params.final_sandboxing_flag_bits != 0 {
		assert navigation_params.opener_policy.value == .unsafe_none
		new_context.popup_sandboxing_flag_bits_ = navigation_params.final_sandboxing_flag_bits
	}

	return new_context
}

pub fn Document.create_and_initialize(type_ DocumentType_, content_type string, navigation_params &NavigationParams) !&Document {
	browsing_context := obtain_a_browsing_context_to_use_for_a_navigation_response(navigation_params)
	creation_url := navigation_params.request_current_url or { navigation_params.response_url }
	mut doc := &Document{}
	doc.data.kind = .node
	doc.unique_id_ = allocate_unique_id(unsafe { &Node(doc) })
	doc.node_type = .document_node
	doc.document_ = doc
	doc.is_connected_ = true
	doc.type_ = type_
	doc.content_type = content_type
	doc.url = creation_url
	doc.origin_ = navigation_params.origin
	doc.was_created_via_cross_origin_redirects = navigation_params.was_created_via_cross_origin_redirects
	doc.load_timing_info = navigation_params.load_timing_info
	doc.browsing_context = browsing_context
	// Document.cpp: create_and_initialize, step 9. Install navigation state
	// before initialization and document CSP initialization can observe it.
	doc.set_active_sandboxing_flag_bits(navigation_params.final_sandboxing_flag_bits)
	if policy_container := navigation_params.policy_container {
		doc.set_policy_container(policy_container)
	}
	doc.about_base_url = navigation_params.about_base_url
	doc.navigation_id = navigation_params.id
	doc.readiness = .loading
	doc.allow_declarative_shadow_roots = true
	doc.window = &Window{
		associated_document_: doc
	}
	// NB: Upstream records the "loading" transition relative to navigation start, coarsened with the window's
	//     cross-origin isolated capability, which is still always "No".
	doc.load_timing_info.dom_loading_time = highresolutiontime.coarsen_time(highresolutiontime.unsafe_shared_current_time() - doc.load_timing_info.navigation_start_time,
		false)
	doc.html_fragment_parsing_hook_ = navigation_params.html_fragment_parsing_hook
	doc.initialize()
	// The HTML package owns the registry type and supplies its actual factory
	// through the same dependency-cycle boundary as registry lookup/adoption.
	if dom_global_custom_element_registry_factory != unsafe { nil } {
		doc.set_custom_element_registry(dom_global_custom_element_registry_factory(doc))
	}
	// 11. Run CSP initialization for the newly-created Document.
	doc.run_csp_initialization()
	return doc
}

// create corresponds to Document::create
pub fn Document.create(url URL) &Document {
	mut doc := &Document{}
	doc.data.kind = .node
	doc.unique_id_ = allocate_unique_id(unsafe { &Node(doc) })
	doc.node_type = .document_node
	doc.document_ = doc
	doc.is_connected_ = true
	doc.url = url
	doc.initialize()
	return doc
}

// Source Document::create(Page&, relevant_global_event_target, URL). HTML
// supplies the already-created actual Window and its module-cycle callbacks.
// Unlike the standalone constructor above, native document construction can
// eagerly allocate its FontFaceSet in the existing owner's realm.
pub fn Document.create_with_relevant_global(url URL, relevant_window &Window, lifecycle_hook DocumentLifecycleHook, temporary_context_hook DocumentTemporaryExecutionContextHook) &Document {
	return Document.create_with_optional_page_and_relevant_global(none, url, relevant_window, lifecycle_hook, temporary_context_hook)
}

// Source Document constructor retains its owning Page before fonts or DOM
// initialization run. The no-Page entry above is a standalone host adapter.
pub fn Document.create_with_page_and_relevant_global(page &Page, url URL, relevant_window &Window, lifecycle_hook DocumentLifecycleHook, temporary_context_hook DocumentTemporaryExecutionContextHook) &Document {
	return Document.create_with_optional_page_and_relevant_global(page, url, relevant_window, lifecycle_hook, temporary_context_hook)
}

fn Document.create_with_optional_page_and_relevant_global(page ?&Page, url URL, relevant_window &Window, lifecycle_hook DocumentLifecycleHook, temporary_context_hook DocumentTemporaryExecutionContextHook) &Document {
	mut doc := &Document{}
	doc.data.kind = .node
	doc.unique_id_ = allocate_unique_id(unsafe { &Node(doc) })
	doc.node_type = .document_node
	doc.document_ = doc
	doc.is_connected_ = true
	doc.url = url
	if owner := page { doc.page_ = owner }
	doc.window = relevant_window
	doc.lifecycle_hook_ = lifecycle_hook
	doc.temporary_execution_context_hook_ = temporary_context_hook
	assert doc.relevant_settings_object() != unsafe { nil }
	if factory := document_font_face_set_factory_ {
		context := doc.begin_temporary_execution_context()
		doc.fonts_ = factory(doc)
		doc.end_temporary_execution_context(context)
	} else {
		panic('Native Document construction requires the CSS FontFaceSet implementation')
	}
	doc.initialize()
	return doc
}

// create_for_fragment_parsing corresponds to Document::create_for_fragment_parsing
pub fn Document.create_for_fragment_parsing() &Document {
	mut doc := &Document{}
	doc.data.kind = .node
	doc.unique_id_ = allocate_unique_id(unsafe { &Node(doc) })
	doc.node_type = .document_node
	doc.document_ = doc
	doc.is_connected_ = true
	doc.url = url_about_blank()
	doc.temporary_document_for_fragment_parsing = .yes
	doc.initialize()
	return doc
}

// construct_impl corresponds to Document::construct_impl (DOM Document() constructor)
// https://dom.spec.whatwg.org/#dom-document-document
pub fn Document.construct_impl() &Document {
	mut doc := Document.create(url_about_blank())
	return doc
}

// --- GC visitor ---

// CellVisitor is the GC edge-visiting mechanism.
// In C++ this is GC::Cell::Visitor; here we stub it
// so the traversal structure is preserved.
pub struct CellVisitor {
mut:
	visited int
}

pub fn (mut v CellVisitor) visit(ptr voidptr) {
	_ = ptr
	v.visited++
}

pub fn (mut d Document) visit_edges(mut visitor CellVisitor) {
	// Base::visit_edges(visitor) — would call ParentNode.visit_edges
	// d.style_scope_.visit_edges(visitor)
	visitor.visit(d.pending_css_import_rules.data)
	visitor.visit(d.page_)
	visitor.visit(d.window)
	visitor.visit(d.layout_root)
	visitor.visit(d.style_sheets_)
	visitor.visit(d.hovered_node)
	visitor.visit(d.inspected_node)
	visitor.visit(d.highlighted_node)
	visitor.visit(d.active_favicon)
	visitor.visit(d.browsing_context)
	visitor.visit(d.focused_area)
	visitor.visit(d.active_element_)
	visitor.visit(d.target_element_)
	for candidate in d.autofocus_candidates_ {
		visitor.visit(candidate)
	}
	visitor.visit(d.implementation_)
	visitor.visit(d.current_script)
	visitor.visit(d.associated_inert_template_document)
	visitor.visit(d.appropriate_template_contents_owner_document)
	visitor.visit(d.pending_parsing_blocking_script)
	visitor.visit(d.pending_parsing_blocking_svg_script)
	visitor.visit(d.history_)
	visitor.visit(d.style_computer)
	visitor.visit(d.font_computer)
	visitor.visit(d.adopted_css_style_sheets_handle)

	// browsing_context visited again in C++ (intentional duplicate in original)
	visitor.visit(d.applets_)
	visitor.visit(d.anchors_)
	visitor.visit(d.images_)
	visitor.visit(d.embeds_)
	visitor.visit(d.links_)
	visitor.visit(d.forms_)
	visitor.visit(d.scripts_)
	visitor.visit(d.all_)
	if fonts := d.fonts_ {
		visitor.visit(fonts.font_face_set_record())
	}
	visitor.visit(d.selection_)
	visitor.visit(d.first_base_element_with_href_in_tree_order)
	visitor.visit(d.first_base_element_with_target_in_tree_order)
	visitor.visit(d.parser)
	visitor.visit(d.lazy_load_intersection_observer)
	if viewport := d.visual_viewport_ {
		visitor.visit(viewport.visual_viewport_record())
	}
	visitor.visit(d.latest_entry)
	visitor.visit(d.default_timeline)
	for timeline in d.associated_animation_timelines {
		visitor.visit(timeline.target)
	}

	for script in d.scripts_to_execute_when_parsing_has_finished {
		visitor.visit(script)
	}
	for script in d.scripts_to_execute_in_order_as_soon_as_possible {
		visitor.visit(script)
	}
	for script in d.scripts_to_execute_as_soon_as_possible {
		visitor.visit(script)
	}

	for ni in d.node_iterators {
		visitor.visit(ni)
	}
	for obs in d.document_observers_being_notified {
		visitor.visit(obs)
	}

	for pse in d.pending_scroll_events {
		visitor.visit(pse.target)
	}
	for ro in d.resize_observers {
		visitor.visit(ro)
	}

	for svg_root in d.svg_roots_needing_relayout {
		visitor.visit(svg_root)
	}

	for _, req in d.shared_resource_requests_ {
		visitor.visit(req)
	}
	for element in d.custom_element_reaction_backup_queue {
		visitor.visit(element)
	}
	for observer in d.pending_mutation_observers {
		visitor.visit(observer)
	}
	for slot in d.signal_slots {
		visitor.visit(slot)
	}

	visitor.visit(d.list_of_available_images)

	for fae in d.form_associated_elements_with_form_attribute {
		visitor.visit(fae)
	}

	for el in d.potentially_named_elements {
		visitor.visit(el)
	}
	visitor.visit(d.element_by_id_map_)

	for event in d.pending_animation_event_queue {
		visitor.visit(event.event)
		visitor.visit(event.animation)
		visitor.visit(event.target)
	}

	for event in d.pending_fullscreen_events {
		visitor.visit(event.element)
	}

	for sheet in d.adopted_style_sheets {
		visitor.visit(sheet)
	}
	for el in d.script_blocking_style_sheet_set {
		visitor.visit(el)
	}

	visitor.visit(d.active_view_transition)
	visitor.visit(d.dynamic_view_transition_style_sheet)

	for vt in d.update_callback_queue {
		visitor.visit(vt)
	}

	for el in d.top_layer_elements {
		visitor.visit(el)
	}
	for el in d.top_layer_pending_removals {
		visitor.visit(el)
	}
	for el in d.showing_auto_popover_list {
		visitor.visit(el)
	}
	for el in d.showing_hint_popover_list {
		visitor.visit(el)
	}
	visitor.visit(d.popover_pointerdown_target)

	for dlg in d.open_dialogs_list {
		visitor.visit(dlg)
	}
	visitor.visit(d.dialog_pointerdown_target)

	visitor.visit(d.console_client_)
	visitor.visit(d.editing_host_manager_)
	visitor.visit(d.local_storage_holder)
	visitor.visit(d.session_storage_holder)

	for el in d.render_blocking_elements {
		visitor.visit(el)
	}

	visitor.visit(d.policy_container_)
	visitor.visit(d.style_invalidator_)
}

// --- Lifecycle ---

// https://html.spec.whatwg.org/multipage/dom.html#dom-document
pub fn (mut d Document) finalize() {
	// Base::finalize()
	// Unregister from the main thread event loop.
	d.unregister_from_event_loop()
}

fn document_cursor_blink_callback(document_pointer voidptr) {
	mut document := unsafe { &Document(document_pointer) }
	if document.cursor_blink_suppressed_ { return }
	position := document.cursor_position() or { return }
	navigable := document.navigable() or { return }
	if !navigable.is_focused() {
		return
	}
	node := position.node() or { return }
	if node.unsafe_paintable() == none {
		return
	}
	document.cursor_blink_state = !document.cursor_blink_state
	mut mutable_node := unsafe { &Node(node) }
	// Cursor blink changes paint commands without changing caret geometry.
	mutable_node.set_needs_repaint(.paint_commands)
}

// https://html.spec.whatwg.org/multipage/dom.html#the-document-object
pub fn (mut d Document) initialize() {
	// Set up prototype, create selection, list of available images, etc.
	d.selection_ = Selection.create(d)
	d.editing_host_manager_ = EditingHostManager.create(mut d)
	d.list_of_available_images = &ListOfAvailableImages{}
	d.cursor_blink_timer = Timer.create_repeating_with_context(500, voidptr(&d), document_cursor_blink_callback)
	d.cursor_blink_timer.start()
	if d.page_ != unsafe { nil } {
		d.page_.client_page_did_create_new_document(d)
	}
	d.ensure_cookie_version_index(d.url)
}

// --- Core property accessors ---
pub fn (d &Document) dom_tree_version() u64 {
	return d.dom_tree_version
}

pub fn (mut d Document) bump_dom_tree_version() {
	d.dom_tree_version++
}

pub fn (mut d Document) note_element_local_name(local_name string) {
	d.seen_element_local_names_[local_name] |= u64(1)
}

// Removal may leave a positive entry; only a negative result is a proof.
// Callers use the same conservative case-folded bucket as CSS selector names.
pub fn (d &Document) has_seen_element_local_name(local_name string) bool {
	return d.seen_element_local_names_[local_name] != 0
}

// Attribute names use two bits in the existing per-tag history. Collisions
// retain the live selector walk; they can never exclude a matching element.
// Bit zero records tag presence. Fold only ASCII, just as attribute matching
// does for HTML names; preserving other bytes also keeps XML names conservative.
fn tag_attribute_history_mask(attribute_name string) u64 {
	mut hash := u32(2166136261)
	for raw in attribute_name {
		folded := if raw >= `A` && raw <= `Z` { raw + u8(32) } else { raw }
		hash = (hash ^ u32(folded)) * u32(16777619)
	}
	return (u64(1) << (u32(1) + hash % 63))
		| (u64(1) << (u32(1) + (hash >> 16) % 63))
}

pub fn (mut d Document) note_element_attribute_name(local_name string, attribute_name string) {
	key := local_name.to_lower()
	d.seen_element_local_names_[key] |= u64(1) | tag_attribute_history_mask(attribute_name)
}

pub fn (d &Document) may_have_tag_attribute(local_name string, attribute_name string) bool {
	mask := tag_attribute_history_mask(attribute_name)
	return d.seen_element_local_names_[local_name] & mask == mask
}

// This is a negative-query summary, never a live class index. Removed and
// disconnected classes may stay present. Stop retaining tokens at the bound;
// unknown means every class remains possible, including future additions.
pub fn (mut d Document) note_element_classes(classes []string) {
	if d.seen_element_classes_unknown_ { return }
	for token in classes {
		if token == '' { continue }
		key := token.to_lower()
		if key in d.seen_element_classes_ { continue }
		if d.seen_element_classes_.len >= 512 || key.len > 32768 - d.seen_element_class_bytes_ {
			d.seen_element_classes_unknown_ = true
			d.seen_element_classes_.clear()
			d.seen_element_class_bytes_ = 0
			return
		}
		// Own the token so a short substring cannot retain a large old attribute.
		d.seen_element_classes_[key.clone()] = true
		d.seen_element_class_bytes_ += key.len
	}
}

pub fn (d &Document) may_have_element_class(token string) bool {
	return d.seen_element_classes_unknown_ || d.seen_element_classes_[token.to_lower()]
}

// Process-local ordering is only compared between option elements belonging to the same
// document, so the translated HTML option algorithms keep the counter with their document.
pub fn (mut d Document) next_option_selectedness_update_index() u64 {
	d.option_selectedness_update_index_counter++
	return d.option_selectedness_update_index_counter
}

pub fn (d &Document) character_data_version() u64 {
	return d.character_data_version
}

pub fn (mut d Document) bump_character_data_version() {
	d.character_data_version++
}

pub fn (d &Document) node_name() string {
	return '#document'
}

pub fn (d &Document) url_string() string {
	return d.url.to_string()
}

pub fn (d &Document) document_uri() string {
	return d.url_string()
}

// --- URL & Origin ---

// C++: URL::Origin const& Document::origin() const
pub fn (d &Document) origin() Origin {
	return d.origin_
}

pub fn (d &Document) get_origin() Origin {
	return d.origin_
}

pub fn (mut d Document) set_origin(o Origin) {
	d.origin_ = o
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#set-the-url
pub fn (mut d Document) set_url(url URL) {
	if d.url == url {
		return
	}
	d.ensure_cookie_version_index(url)
	old_document_url := d.url
	old_base_url := d.base_url()
	d.url = url
	d.respond_to_base_url_changes(old_document_url, old_base_url)
}

// fallback_base_url - https://html.spec.whatwg.org/multipage/urls-and-fetching.html#fallback-base-url
pub fn (d &Document) fallback_base_url() URL {
	// 1. If document is an iframe srcdoc document, return about base URL.
	if url_matches_about_srcdoc(d.url) {
		if about_base := d.about_base_url {
			return about_base
		}
	}
	// 2. If document's URL matches about:blank and about base URL is non-null, return it.
	if url_matches_about_blank(d.url) {
		if about_base := d.about_base_url {
			return about_base
		}
	}
	// 3. Return document's URL.
	return d.url
}

// base_url - https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url
pub fn (d &Document) base_url() URL {
	// 1. If there is no base element with href, return fallback base URL.
	base_element := d.first_base_element_with_href_in_tree_order() or {
		return d.fallback_base_url()
	}
	// 2. Return the frozen base URL of the first base element with href.
	if base_element.frozen_base_url_initialized_ {
		return base_element.frozen_base_url_
	}
	if href := unsafe { &Element(base_element) }.get_attribute('href') {
		return dom_url_parse(href, d.fallback_base_url(), d.encoding_or_default()) or {
			d.fallback_base_url()
		}
	}
	return d.fallback_base_url()
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#encoding-parsing-a-url
pub fn (d &Document) encoding_parse_url(url_str string) ?URL {
	// 1. Let encoding be UTF-8.
	// 2. If environment is a Document object, then set encoding to environment's character encoding.
	encoding := d.encoding_or_default()

	// 3. Otherwise, if environment's relevant global object is a Window object, set encoding to environment's relevant
	//    global object's associated Document's character encoding.

	// 4. Let baseURL be environment's base URL, if environment is a Document object; otherwise environment's API base URL.
	base_url := d.base_url()

	// 5. Return the result of applying the URL parser to url, with baseURL and encoding.
	return dom_url_parse(url_str, base_url, encoding)
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#encoding-parsing-and-serializing-a-url
pub fn (d &Document) encoding_parse_and_serialize_url(url string) ?string {
	parsed := d.encoding_parse_url(url) or { return none }
	return parsed.serialize()
}

fn local_link_target_matches_document(target_url ?URL, document_url URL) bool {
	target := target_url or { return false }
	if target.fragment() != none {
		return target == document_url
	}
	mut target_without_fragment := target
	mut document_without_fragment := document_url
	target_without_fragment.set_fragment(none)
	document_without_fragment.set_fragment(none)
	return target_without_fragment == document_without_fragment
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#respond-to-base-url-changes
pub fn (mut d Document) respond_to_base_url_changes(old_document_url URL, old_base_url URL) {
	// Until visited-link tracking exists, only :local-link can change when the
	// document/base URL changes. Avoid even walking links when no active style
	// scope observes that pseudo-class.
	mut any_scope_has_local_link := d.style_scope().have_local_link_selectors()
	if !any_scope_has_local_link {
		search_result := d.for_each_shadow_including_descendant(fn (node &Node) TraversalDecision {
			element := node.as_element() or { return .@continue }
			shadow_root := element.shadow_root() or { return .@continue }
			if shadow_root.style_scope().have_local_link_selectors() {
				return .@break
			}
			return .@continue
		})
		any_scope_has_local_link = search_result == .@break
	}
	if !any_scope_has_local_link {
		return
	}

	new_document_url := d.url
	new_base_url := d.base_url()
	base_url_unchanged := old_base_url == new_base_url
	if base_url_unchanged && old_document_url == new_document_url {
		return
	}
	encoding := d.encoding_or_default()
	d.visit_shadow_including_descendants(fn [old_document_url, old_base_url, new_document_url, new_base_url, base_url_unchanged, encoding] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }
		if !element.matches_link_pseudo_class() {
			return .@continue
		}
		href := element.get_attribute_value('href')
		old_target_url := dom_url_parse(href, old_base_url, encoding)
		new_target_url := if base_url_unchanged {
			old_target_url
		} else {
			dom_url_parse(href, new_base_url, encoding)
		}
		if local_link_target_matches_document(old_target_url, old_document_url) != local_link_target_matches_document(new_target_url, new_document_url) {
			mut element_node := unsafe { &Node(element.as_node()) }
			element_node.invalidate_style_with_properties(.base_url_changed, [
				InvalidationProperty{
					type_: .pseudo_class
					pseudo_class_name: 'local-link'
				},
			], StyleInvalidationOptions{})
		}
		return .@continue
	})
}

pub fn (mut d Document) update_base_element() {
	// Scan tree for <base> elements and update cached first-with-href / first-with-target.
	document_node := unsafe { &Node(&d) }
	d.first_base_element_with_href_in_tree_order = first_base_element_with_attribute(document_node, 'href') or { unsafe { nil } }
	d.first_base_element_with_target_in_tree_order = first_base_element_with_attribute(document_node, 'target') or { unsafe { nil } }
}

fn first_base_element_with_attribute(root &Node, attribute_name string) ?&HTMLBaseElement {
	for child in root.children_as_vector() {
		if element := child.as_element() {
			if element.local_name() == 'base' && (element.namespace_uri() or { namespace_html_ }) == namespace_html_ && element.has_attribute(attribute_name) {
				return unsafe { &HTMLBaseElement(element) }
			}
		}
		if base := first_base_element_with_attribute(child, attribute_name) {
			return base
		}
	}
	return none
}

pub fn (d &Document) first_base_element_with_href_in_tree_order() ?&HTMLBaseElement {
	if d.first_base_element_with_href_in_tree_order == unsafe { nil } {
		return none
	}
	return d.first_base_element_with_href_in_tree_order
}

pub fn (d &Document) first_base_element_with_target_in_tree_order() ?&HTMLBaseElement {
	if d.first_base_element_with_target_in_tree_order == unsafe { nil } {
		return none
	}
	return d.first_base_element_with_target_in_tree_order
}

// --- Opener policy ---
pub fn (d &Document) opener_policy() OpenerPolicy {
	return d.opener_policy
}

pub fn (mut d Document) set_opener_policy(policy OpenerPolicy) {
	d.opener_policy = policy
}

// --- Document type & quirks ---
pub fn (d &Document) document_type() DocumentType_ {
	return d.type_
}

pub fn (mut d Document) set_document_type(t DocumentType_) {
	d.type_ = t
}

pub fn (d &Document) is_html_document() bool {
	return d.type_ == .html
}

pub fn (d &Document) is_xml_document() bool {
	return d.type_ == .xml
}

pub fn (d &Document) mode() QuirksMode {
	return d.quirks_mode
}

pub fn (d &Document) in_limited_quirks_mode() bool {
	return d.quirks_mode == .limited
}

pub fn (mut d Document) set_quirks_mode(mode QuirksMode) {
	d.quirks_mode = mode
}

// --- Readiness ---
pub fn (d &Document) ready_state() string {
	return match d.readiness {
		.loading { 'loading' }
		.interactive { 'interactive' }
		.complete { 'complete' }
	}
}

pub fn (d &Document) readiness() DocumentReadyState {
	return d.readiness
}

// https://html.spec.whatwg.org/multipage/dom.html#update-the-current-document-readiness
pub fn (mut d Document) update_readiness(readiness_value DocumentReadyState) {
	if d.readiness == readiness_value {
		return
	}
	d.readiness = readiness_value
	if readiness_value != .loading {
		d.request_frame()
	}

	// Update timing info based on new readiness state
	now := current_high_resolution_time(relevant_global_object_for_doc(d))
	match readiness_value {
		.interactive {
			d.load_timing_info.dom_interactive_time = now
		}
		.complete {
			d.load_timing_info.dom_complete_time = now
		}
		else {}
	}

	d.notify_each_document_observer_readiness()

	// Fire a readystatechange event at the document.
	d.dispatch_event_simple(event_readystatechange_, false)
}

pub fn (mut d Document) mark_dom_content_loaded_event_start() {
	d.load_timing_info.dom_content_loaded_event_start_time = current_high_resolution_time(relevant_global_object_for_doc(d))
}

pub fn (mut d Document) mark_dom_content_loaded_event_end() {
	d.load_timing_info.dom_content_loaded_event_end_time = current_high_resolution_time(relevant_global_object_for_doc(d))
}

pub fn (mut d Document) mark_load_event_start() {
	d.load_timing_info.load_event_start_time = current_high_resolution_time(relevant_global_object_for_doc(d))
}

pub fn (mut d Document) mark_load_event_end() {
	d.load_timing_info.load_event_end_time = current_high_resolution_time(relevant_global_object_for_doc(d))
}

// --- Selection ---

// https://w3c.github.io/selection-api/#dom-document-getselection
pub fn (d &Document) get_selection() ?&Selection {
	if d.browsing_context == unsafe { nil } {
		return none
	}
	if d.selection_ == unsafe { nil } {
		return none
	}
	return d.selection_
}

// --- Cookie ---

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
pub fn (mut d Document) cookie() !string {
	// On getting, if the document is a cookie-averse Document, return empty string.
	if d.is_cookie_averse() {
		return ''
	}
	// If Document's origin is opaque, throw SecurityError.
	if d.origin_.value == 'opaque' {
		return error('SecurityError: Document origin is opaque')
	}
	// Return the non-HTTP cookie-string for the document URL, reusing the
	// cached value only while PageClient's shared version is unchanged.
	hook := d.cookie_client_hook_ or { return '' }
	if index := d.cookie_version_index {
		if hook.request_document_version != unsafe { nil } {
			if version := hook.request_document_version(hook.target, index) {
				if d.cookie_version >= 0 && u64(d.cookie_version) == version {
					return d.cookie_cache
				}
			}
		}
	}
	record := d.url.parsed() or { return '' }
	if hook.request_cookie == unsafe { nil } {
		return ''
	}
	versioned_cookie := hook.request_cookie(hook.target, &record, httpcookie.Source.non_http)
	if version := versioned_cookie.cookie_version {
		d.cookie_version = int(version)
		d.cookie_cache = versioned_cookie.cookie
	}
	return versioned_cookie.cookie
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-cookie
pub fn (mut d Document) set_cookie(cookie_string string) ! {
	// On setting, if the document is a cookie-averse Document, do nothing.
	if d.is_cookie_averse() {
		return
	}
	// If Document's origin is opaque, throw SecurityError.
	if d.origin_.value == 'opaque' {
		return error('SecurityError: Document origin is opaque')
	}
	// Act as it would when receiving a set-cookie-string via a non-HTTP API.
	record := d.url.parsed() or { return }
	parsed_cookie := httpcookie.parse_cookie(&record, cookie_string) or { return }
	hook := d.cookie_client_hook_ or { return }
	if hook.set_cookie != unsafe { nil } {
		hook.set_cookie(hook.target, &record, parsed_cookie, httpcookie.Source.non_http)
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#cookie-averse-document-object
pub fn (d &Document) is_cookie_averse() bool {
	// A Document is cookie-averse if:
	// - its browsing context is null, OR
	// - its URL scheme is not HTTP(S)
	if d.browsing_context == unsafe { nil } {
		return true
	}
	scheme := d.url.value.all_before(':')
	if scheme != 'http' && scheme != 'https' {
		return true
	}
	return false
}

// --- Document element / body / head / title ---
fn is_html_element_with_local_name(element &Element, local_name string) bool {
	return element.namespace_uri() or { '' } == namespace_html_ && element.local_name() == local_name
}

fn element_as_html_element(element &Element) &HTMLElement {
	return unsafe { &HTMLElement(element) }
}

fn html_element_as_element(element &HTMLElement) &Element {
	return unsafe { &Element(element) }
}

fn strip_and_collapse_ascii_whitespace(value string) string {
	mut builder := strings.new_builder(value.len)
	mut wrote_non_whitespace := false
	mut pending_space := false
	for byte in value.bytes() {
		is_whitespace := byte == 0x09 || byte == 0x0a || byte == 0x0c || byte == 0x0d || byte == 0x20
		if is_whitespace {
			if wrote_non_whitespace {
				pending_space = true
			}
			continue
		}
		if pending_space {
			builder.write_u8(0x20)
			pending_space = false
		}
		builder.write_u8(byte)
		wrote_non_whitespace = true
	}
	return builder.str()
}

pub fn (d &Document) document_element() ?&Element {
	// The document element is the first child element of the document.
	for child in unsafe { &Node(d) }.children {
		if element := child.as_element() {
			return element
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/dom.html#the-html-element-2
pub fn (d &Document) html_element() ?&HTMLHtmlElement {
	// The html element is the document element, if it's an html element.
	element := d.document_element() or { return none }
	if is_html_element_with_local_name(element, 'html') {
		return unsafe { &HTMLHtmlElement(element) }
	}
	return none
}

// https://html.spec.whatwg.org/multipage/dom.html#the-head-element-2
pub fn (d &Document) head() ?&HTMLHeadElement {
	// The head element is the first head element child of the html element.
	html := d.html_element() or { return none }
	for child in unsafe { &Element(html) }.as_node().children {
		if element := child.as_element() {
			if is_html_element_with_local_name(element, 'head') {
				return unsafe { &HTMLHeadElement(element) }
			}
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/dom.html#the-title-element-2
pub fn (d &Document) title_element() ?&HTMLTitleElement {
	// The title element is the first title element in the document (in tree order).
	mut found := []&HTMLTitleElement{}
	found_ptr := &found
	document_node := unsafe { &Node(d) }
	document_node.visit_subtree(fn [found_ptr] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }
		if is_html_element_with_local_name(element, 'title') {
			dom_ptr_push(found_ptr, unsafe { &HTMLTitleElement(element) })
			return .@break
		}
		return .@continue
	})
	return if found.len > 0 { found[0] } else { none }
}

// https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2
pub fn (d &Document) body() ?&HTMLElement {
	// The body element is the first body or frameset child of the html element.
	html := d.html_element() or { return none }
	for child in unsafe { &Element(html) }.as_node().children {
		if element := child.as_element() {
			if is_html_element_with_local_name(element, 'body') || is_html_element_with_local_name(element, 'frameset') {
				return element_as_html_element(unsafe { &Element(element) })
			}
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-body
pub fn (mut d Document) set_body(new_body &HTMLElement) ! {
	// Per spec: if new_body is not body or frameset, throw HierarchyRequestError.
	// If there's an existing body, replace it. Otherwise append to html element.
	new_body_element := html_element_as_element(new_body)
	if !is_html_element_with_local_name(new_body_element, 'body') && !is_html_element_with_local_name(new_body_element, 'frameset') {
		return error("HierarchyRequestError: Invalid document body element, must be 'body' or 'frameset'")
	}
	new_body_node := new_body_element.as_node()
	if existing_body := d.body() {
		existing_body_node := html_element_as_element(existing_body).as_node()
		parent := existing_body_node.parent() or {
			return error('HierarchyRequestError: Existing body has no parent')
		}
		mut mutable_parent := unsafe { &Node(parent) }
		mutable_parent.replace_child(new_body_node, existing_body_node)!
		return
	}
	document_element := d.document_element() or {
		return error('HierarchyRequestError: Missing document element')
	}
	mut document_element_node := unsafe { &Node(document_element.as_node()) }
	document_element_node.append_child(new_body_node)!
}

// https://html.spec.whatwg.org/multipage/dom.html#document.title
pub fn (d &Document) title() string {
	mut value := ''
	mut used_svg_document_title_path := false

	// 1. If the document element is an SVG svg element, then let value be the child text content of the first SVG title
	//    element that is a child of the document element.
	if document_element := d.document_element() {
		if document_element.is_svg_svg_element() {
			used_svg_document_title_path = true
			for child in document_element.as_node().children {
				element := child.as_element() or { continue }
				if element.namespace_uri() or { '' } == namespace_svg_uri && element.local_name() == 'title' {
					value = child.child_text_content()
					break
				}
			}
		}
	}

	// 2. Otherwise, let value be the child text content of the title element, or the empty string if the title element
	//    is null.
	if !used_svg_document_title_path {
		if title_element := d.title_element() {
			value = unsafe { &Element(title_element) }.as_node().text_content() or { '' }
		}
	}

	// 3. Strip and collapse ASCII whitespace in value.
	// 4. Return value.
	return strip_and_collapse_ascii_whitespace(value)
}

// https://html.spec.whatwg.org/multipage/dom.html#document.title
pub fn (mut d Document) set_title(value string) ! {
	// Sets the document title by creating/updating the title element.
	// Different behavior for HTML vs SVG documents.
	document_element := d.document_element() or { return }
	if document_element.namespace_uri() or { '' } == namespace_svg_uri && document_element.local_name() == 'svg' {
		mut title_target := ?&Element(none)
		for child in document_element.as_node().children {
			if element := child.as_element() {
				if element.namespace_uri() or { '' } == namespace_svg_uri && element.local_name() == 'title' {
					title_target = unsafe { &Element(element) }
					break
				}
			}
		}
		target := if existing := title_target {
			unsafe { &Element(existing) }
		} else {
			new_title := create_element(&d, 'title', namespace_svg_uri, none, none, true)!
			mut document_element_node := unsafe { &Node(document_element.as_node()) }
			document_element_node.pre_insert(new_title.as_node(), document_element.as_node().first_child())!
			unsafe { &Element(new_title) }
		}
		mut target_node := unsafe { &Node(target.as_node()) }
		target_node.string_replace_all(value)
		return
	}

	if document_element.namespace_uri() or { '' } == namespace_html_ {
		title_target := d.title_element()
		head_element := d.head()
		if title_target == none && head_element == none {
			return
		}
		target := if existing := title_target {
			unsafe { &Element(existing) }
		} else {
			new_title := create_element(&d, 'title', namespace_html_, none, none, true)!
			head := head_element or { return }
			head_element_node := unsafe { &Element(head) }.as_node()
			mut head_node := unsafe { &Node(head_element_node) }
			head_node.append_child(new_title.as_node())!
			unsafe { &Element(new_title) }
		}
		mut target_node := unsafe { &Node(target.as_node()) }
		target_node.string_replace_all(value)
	}
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-dir
pub fn (d &Document) dir() string {
	// Returns the dir attribute of the html element, if any.
	html := d.html_element() or { return '' }
	dir := to_ascii_lowercase(unsafe { &Element(html) }.get_attribute_value('dir'))
	if dir in ['ltr', 'rtl', 'auto'] {
		return dir
	}
	return ''
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-dir
pub fn (mut d Document) set_dir(dir string) {
	// Sets the dir attribute of the html element.
	html := d.html_element() or { return }
	mut element := unsafe { &Element(html) }
	element.set_attribute_value('dir', dir)
}

// --- Browsing context ---
pub fn (d &Document) get_browsing_context() ?&BrowsingContext {
	if d.browsing_context == unsafe { nil } {
		return none
	}
	return d.browsing_context
}

pub fn (mut d Document) set_browsing_context(bc &BrowsingContext) {
	d.browsing_context = bc
}

// C++: Page& Document::page()
pub fn (d &Document) page() &Page {
	return d.page_
}

pub fn (d &Document) has_page() bool {
	return d.page_ != unsafe { nil }
}

pub fn (d &Document) get_page() &Page {
	return d.page_
}

pub fn (mut d Document) set_page(page &Page) {
	d.page_ = page
	page.client_page_did_create_new_document(d)
}

pub fn (d &Document) preferred_color_scheme() string {
	if scheme := d.svg_image_color_scheme_ {
		return scheme
	}
	// Force-dark presents a dark preference so pages with their own dark theme
	// can select it before paint-time filtering is considered.
	if navigable := d.navigable() {
		if navigable.force_dark_enabled() {
			return 'dark'
		}
	}
	if d.page_ == unsafe { nil } {
		return 'auto'
	}
	return d.page_.preferred_color_scheme()
}

pub fn (d &Document) svg_image_color_scheme() ?string {
	return d.svg_image_color_scheme_
}

pub fn (mut d Document) set_svg_image_color_scheme(color_scheme string) {
	if existing := d.svg_image_color_scheme_ {
		if existing == color_scheme {
			return
		}
	}
	d.svg_image_color_scheme_ = color_scheme
	d.needs_full_style_update = true
}

pub fn (d &Document) device_pixels_per_css_pixel() f64 {
	if d.page_ == unsafe { nil } {
		return 1.0
	}
	return d.page_.device_pixels_per_css_pixel()
}

// --- Colors ---
pub fn (d &Document) background_color() Color {
	hook := d.background_style_hook_ or { return color_transparent }
	if hook.background_color == unsafe { nil } {
		return color_transparent
	}
	// CSS2 says to use the HTML element's background unless it is
	// transparent, then the BODY element's background.
	if html := d.html_element() {
		element := unsafe { &Element(html) }
		if element.as_node().unsafe_layout_node() != none {
			color := hook.background_color(hook.target, element)
			if color.a != 0 {
				return color
			}
		}
	}
	if body := d.body() {
		element := html_element_as_element(body)
		if element.as_node().unsafe_layout_node() != none {
			return hook.background_color(hook.target, element)
		}
	}
	return color_transparent
}

pub fn (d &Document) normal_link_color() ?Color {
	return d.normal_link_color_
}

pub fn (mut d Document) set_normal_link_color(color Color) {
	d.normal_link_color_ = color
}

pub fn (d &Document) active_link_color() ?Color {
	return d.active_link_color_
}

pub fn (mut d Document) set_active_link_color(color Color) {
	d.active_link_color_ = color
}

pub fn (d &Document) visited_link_color() ?Color {
	return d.visited_link_color_
}

pub fn (mut d Document) set_visited_link_color(color Color) {
	d.visited_link_color_ = color
}

pub fn (d &Document) fg_color() string {
	// Returns body element's "text" attribute if body is not a frameset
	body_el := d.body() or { return '' }
	if is_html_frame_set_element(body_el) {
		return ''
	}
	return html_element_as_element(body_el).get_attribute_value('text')
}

pub fn (mut d Document) set_fg_color(value string) {
	mut body_el := d.body() or { return }
	if is_html_frame_set_element(body_el) {
		return
	}
	mut element := html_element_as_element(body_el)
	element.set_attribute_value('text', value)
}

pub fn (d &Document) link_color() string {
	body_el := d.body() or { return '' }
	if is_html_frame_set_element(body_el) {
		return ''
	}
	return html_element_as_element(body_el).get_attribute_value('link')
}

pub fn (mut d Document) set_link_color(value string) {
	mut body_el := d.body() or { return }
	if is_html_frame_set_element(body_el) {
		return
	}
	mut element := html_element_as_element(body_el)
	element.set_attribute_value('link', value)
}

pub fn (d &Document) vlink_color() string {
	body_el := d.body() or { return '' }
	if is_html_frame_set_element(body_el) {
		return ''
	}
	return html_element_as_element(body_el).get_attribute_value('vlink')
}

pub fn (mut d Document) set_vlink_color(value string) {
	mut body_el := d.body() or { return }
	if is_html_frame_set_element(body_el) {
		return
	}
	mut element := html_element_as_element(body_el)
	element.set_attribute_value('vlink', value)
}

pub fn (d &Document) alink_color() string {
	body_el := d.body() or { return '' }
	if is_html_frame_set_element(body_el) {
		return ''
	}
	return html_element_as_element(body_el).get_attribute_value('alink')
}

pub fn (mut d Document) set_alink_color(value string) {
	mut body_el := d.body() or { return }
	if is_html_frame_set_element(body_el) {
		return
	}
	mut element := html_element_as_element(body_el)
	element.set_attribute_value('alink', value)
}

pub fn (d &Document) bg_color() string {
	body_el := d.body() or { return '' }
	if is_html_frame_set_element(body_el) {
		return ''
	}
	return html_element_as_element(body_el).get_attribute_value('bgcolor')
}

pub fn (mut d Document) set_bg_color(value string) {
	mut body_el := d.body() or { return }
	if is_html_frame_set_element(body_el) {
		return
	}
	mut element := html_element_as_element(body_el)
	element.set_attribute_value('bgcolor', value)
}

pub fn (d &Document) supported_color_schemes() ?[]string {
	return d.supported_color_schemes
}

pub fn (d &Document) supported_color_schemes_are_only() bool {
	return d.supported_color_schemes_are_only_
}

pub fn (mut d Document) set_supported_color_schemes(schemes ?[]string, only bool) {
	mut schemes_equal := false
	if current := d.supported_color_schemes {
		if next := schemes {
			schemes_equal = current == next
		}
	} else {
		if _ := schemes {
		} else {
			schemes_equal = true
		}
	}
	if schemes_equal && d.supported_color_schemes_are_only_ == only {
		return
	}
	d.supported_color_schemes = schemes
	d.supported_color_schemes_are_only_ = only
	d.bump_style_environment_version()
	d.set_needs_media_query_evaluation()
	d.set_needs_full_style_update(true)
}

struct ParsedMetaColorScheme {
	schemes []string
	only    bool
}

// https://html.spec.whatwg.org/multipage/semantics.html#meta-color-scheme
pub fn (mut d Document) obtain_supported_color_schemes() {
	mut found := []ParsedMetaColorScheme{}
	found_ptr := &found
	document_node := unsafe { &Node(&d) }
	document_node.visit_subtree(fn [found_ptr] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }
		if !is_html_element_with_local_name(element, 'meta') || to_ascii_lowercase(element.get_attribute_value('name')) != 'color-scheme' {
			return .@continue
		}
		content := element.get_attribute('content') or { return .@continue }
		parsed := parse_meta_color_scheme(content) or { return .@continue }
		unsafe {
			*found_ptr = [parsed]
		}
		return .@break
	})
	if found.len > 0 {
		d.set_supported_color_schemes(found[0].schemes, found[0].only)
	} else {
		d.set_supported_color_schemes(none, false)
	}
}

fn parse_meta_color_scheme(content string) ?ParsedMetaColorScheme {
	mut tokens := content.fields().map(to_ascii_lowercase(it))
	if tokens.len == 1 && tokens[0] == 'normal' {
		return ParsedMetaColorScheme{}
	}
	if tokens.len == 0 {
		return none
	}
	mut only := false
	if tokens[0] == 'only' {
		only = true
		tokens.delete(0)
	} else if tokens.len > 0 && tokens[tokens.len - 1] == 'only' {
		only = true
		tokens.delete(tokens.len - 1)
	}
	if tokens.len == 0 {
		return none
	}
	css_wide_keywords := ['initial', 'inherit', 'unset', 'revert', 'revert-layer', 'default']
	for token in tokens {
		if token == 'normal' || token == 'only' || token in css_wide_keywords {
			return none
		}
		for ch in token.bytes() {
			if !(ch.is_alnum() || ch in [`-`, `_`] || ch >= 0x80) {
				return none
			}
		}
	}
	return ParsedMetaColorScheme{
		schemes: tokens
		only: only
	}
}

// https://html.spec.whatwg.org/multipage/semantics.html#meta-theme-color
pub fn (mut d Document) obtain_theme_color() {
	d.theme_color_ = none
	hook := d.theme_color_hook_ or { return }
	if hook.parse_color == unsafe { nil } {
		return
	}
	mut found := []string{}
	found_ptr := &found
	document_node := unsafe { &Node(&d) }
	document_node.visit_subtree(fn [hook, found_ptr] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }
		if !is_html_element_with_local_name(element, 'meta') || to_ascii_lowercase(element.get_attribute_value('name')) != 'theme-color' {
			return .@continue
		}
		content := element.get_attribute('content') or { return .@continue }
		if media := element.get_attribute('media') {
			if hook.media_matches == unsafe { nil } || !hook.media_matches(hook.target, media) {
				return .@continue
			}
		}
		color := hook.parse_color(hook.target, content.trim_space()) or { return .@continue }
		unsafe {
			*found_ptr = [color]
		}
		return .@break
	})
	if found.len > 0 {
		d.theme_color_ = found[0]
	}
}

pub fn (d &Document) theme_color() ?string {
	return d.theme_color_
}

pub fn (mut d Document) set_update_style_for_element_hook(hook DocumentUpdateStyleForElementHook) {
	d.update_style_for_element_hook_ = hook
}

// Document::update_style_for_element() with StyleUpdateMode::StopAtDisplayNone when stop_at_display_none is set.
pub fn (d &Document) update_style_for_element(element &Element, stop_at_display_none bool) bool {
	hook := d.update_style_for_element_hook_ or {
		// NB: Without the CSS module there is no style to compute, so treat a connected element as styled.
		return element.as_node().is_connected()
	}
	if hook.update_style_for_element == unsafe { nil } {
		return element.as_node().is_connected()
	}
	return hook.update_style_for_element(hook.target, element, stop_at_display_none)
}

pub fn (mut d Document) set_theme_color_hook(hook DocumentThemeColorHook) {
	d.theme_color_hook_ = hook
}

pub fn (mut d Document) set_pragma_set_default_language(value ?string) {
	d.pragma_set_default_language = value
	if document_element := d.document_element() {
		mut mutable_element := unsafe { &Element(document_element) }
		mutable_element.invalidate_lang_value()
	}
}

pub fn (d &Document) pragma_set_default_language_value() ?string {
	return d.pragma_set_default_language
}

pub fn (mut d Document) set_meta_referrer_policy(value string) {
	d.meta_referrer_policy_ = value
}

pub fn (d &Document) meta_referrer_policy() string {
	return d.meta_referrer_policy_
}

pub fn (mut d Document) enforce_meta_csp(policy string) {
	d.enforced_meta_csp_policies_ << policy
}

// HTMLMetaElement's actual inserted() method supplies unparsed Source input.
// HTML installs the translated parser/settings append across the module cycle.
pub fn (mut d Document) enforce_meta_csp_from_element(input string) {
	hook := d.csp_hook_ or { return }
	if hook.meta_enforce == unsafe { nil } {
		return
	}
	d.enforce_meta_csp(hook.meta_enforce(&d, input))
}

pub fn (mut d Document) set_meta_element_metadata_callback(callback DocumentMetaElementMetadataCallback) {
	d.meta_element_metadata_callback_ = callback
}

pub fn (d &Document) update_meta_element_metadata(meta &HTMLMetaElement, old_name ?string) {
	if d.meta_element_metadata_callback_ != unsafe { nil } {
		d.meta_element_metadata_callback_(meta, old_name)
	}
}

pub fn (d &Document) enforced_meta_csp_policies() []string {
	return d.enforced_meta_csp_policies_.clone()
}

// --- Style ---
pub fn (mut d Document) set_style_update_hook(hook DocumentStyleUpdateHook) {
	d.style_update_hook_ = hook
}

pub fn (mut d Document) set_background_style_hook(hook DocumentBackgroundStyleHook) {
	d.background_style_hook_ = hook
}

pub fn (mut d Document) set_scroll_style_hook(hook DocumentScrollStyleHook) {
	d.scroll_style_hook_ = hook
}

pub fn (mut d Document) set_viewport_scroll_snap_hook(hook DocumentViewportScrollSnapHook) {
	d.viewport_scroll_snap_hook_ = hook
}

pub fn (mut d Document) adjust_viewport_scroll_destination(destination CSSPixelPoint_,
	strategy ScrollSnapSelectionStrategy_) ScrollSnapDestination_ {
	hook := d.viewport_scroll_snap_hook_ or {
		return ScrollSnapDestination_{ position: destination }
	}
	if hook.adjust_destination == unsafe { nil } {
		return ScrollSnapDestination_{ position: destination }
	}
	result := hook.adjust_destination(hook.target, destination, strategy)
	d.record_viewport_scroll_snap_destination(result)
	return result
}

pub fn (d &Document) viewport_snapped_areas_x() []ScrollSnapAreaReference_ {
	return d.viewport_snapped_areas_x_.clone()
}

pub fn (d &Document) viewport_snapped_areas_y() []ScrollSnapAreaReference_ {
	return d.viewport_snapped_areas_y_.clone()
}

pub fn (mut d Document) record_viewport_scroll_snap_destination(result ScrollSnapDestination_) {
	if result.evaluated_x {
		d.viewport_snapped_areas_x_ = result.snapped_areas_x.clone()
	}
	if result.evaluated_y {
		d.viewport_snapped_areas_y_ = result.snapped_areas_y.clone()
	}
}

pub fn (d &Document) scroll_margin_for_element(element &Element) ScrollMarginData {
	hook := d.scroll_style_hook_ or { return ScrollMarginData{} }
	if hook.scroll_margin == unsafe { nil } {
		return ScrollMarginData{}
	}
	return hook.scroll_margin(hook.target, element)
}

pub fn (d &Document) scroll_padding_for_scrolling_box(scrolling_box &Node) ScrollMarginData {
	hook := d.scroll_style_hook_ or { return ScrollMarginData{} }
	if hook.scroll_padding == unsafe { nil } {
		return ScrollMarginData{}
	}
	return hook.scroll_padding(hook.target, scrolling_box)
}

pub fn (mut d Document) set_css_animation_timeline_update_hook(hook DocumentCSSAnimationTimelineUpdateHook) {
	d.css_animation_timeline_update_hook_ = hook
}

pub fn (mut d Document) set_css_animation_event_hook(hook DocumentCSSAnimationEventHook) {
	d.css_animation_event_hook_ = hook
}

pub fn (mut d Document) set_animations_hook(hook DocumentAnimationsHook) {
	d.animations_hook_ = hook
}

pub fn (mut d Document) set_temporary_execution_context_hook(hook DocumentTemporaryExecutionContextHook) {
	d.temporary_execution_context_hook_ = hook
}

pub fn (mut d Document) set_lifecycle_hook(hook DocumentLifecycleHook) {
	d.lifecycle_hook_ = hook
	if !d.event_loop_registered_ && hook.register_document != unsafe { nil } {
		hook.register_document(hook.target, d)
		d.event_loop_registered_ = true
	}
}

pub fn (mut d Document) set_cookie_client_hook(hook DocumentCookieClientHook) {
	d.cookie_client_hook_ = hook
}

fn (mut d Document) unregister_from_event_loop() {
	if !d.event_loop_registered_ {
		return
	}
	hook := d.lifecycle_hook_ or { return }
	if hook.unregister_document != unsafe { nil } {
		hook.unregister_document(hook.target, d)
	}
	d.event_loop_registered_ = false
}

fn (d &Document) run_lifecycle_callback(callback DocumentLifecycleCallback) {
	if callback == unsafe { nil } {
		return
	}
	hook := d.lifecycle_hook_ or { return }
	callback(hook.target, d)
}

fn (d &Document) increment_termination_nesting_level() {
	hook := d.lifecycle_hook_ or { return }
	d.run_lifecycle_callback(hook.increment_termination_nesting)
}

fn (d &Document) decrement_termination_nesting_level() {
	hook := d.lifecycle_hook_ or { return }
	d.run_lifecycle_callback(hook.decrement_termination_nesting)
}

fn (d &Document) remove_tasks_for_document() {
	hook := d.lifecycle_hook_ or { return }
	d.run_lifecycle_callback(hook.remove_tasks_for_document)
}

fn (d &Document) set_relevant_settings_object_execution_ready() {
	hook := d.lifecycle_hook_ or { return }
	d.run_lifecycle_callback(hook.set_execution_ready)
}

pub fn (d &Document) begin_temporary_execution_context() voidptr {
	hook := d.temporary_execution_context_hook_ or { return unsafe { nil } }
	if hook.begin == unsafe { nil } {
		return unsafe { nil }
	}
	return hook.begin(hook.target)
}

pub fn (d &Document) end_temporary_execution_context(context voidptr) {
	if context == unsafe { nil } {
		return
	}
	hook := d.temporary_execution_context_hook_ or { return }
	if hook.end != unsafe { nil } {
		hook.end(hook.target, context)
	}
}

pub fn (mut d Document) set_selector_query_hook(hook DocumentSelectorQueryHook) {
	d.selector_query_hook_ = hook
	// DOM's old cache contains placeholder parses produced without the CSS parser. Do not let those
	// survive installation of the real parser/matcher.
	d.selector_query_cache.clear()
}

pub fn (d &Document) selector_query_hook() ?DocumentSelectorQueryHook {
	return d.selector_query_hook_
}

pub fn (mut d Document) set_html_fragment_parsing_hook(hook DocumentHTMLFragmentParsingHook) {
	d.html_fragment_parsing_hook_ = hook
}

pub fn (mut d Document) set_editing_command_hook(hook DocumentEditingCommandHook) {
	d.editing_command_hook_ = hook
}

pub fn (d &Document) editing_command_hook() ?DocumentEditingCommandHook {
	return d.editing_command_hook_
}

pub fn (mut d Document) set_editing_history_hook(hook DocumentEditingHistoryHook) {
	d.editing_history_hook_ = hook
}

pub fn (d &Document) editing_history_hook() ?DocumentEditingHistoryHook {
	return d.editing_history_hook_
}

pub fn (d &Document) notify_editing_history_dom_mutation() {
	hook := d.editing_history_hook_ or { return }
	if hook.notify_dom_mutation != unsafe { nil } {
		hook.notify_dom_mutation(hook.target)
	}
}

pub fn (d &Document) notify_editing_history_selection_changed() {
	hook := d.editing_history_hook_ or { return }
	if hook.selection_changed != unsafe { nil } {
		hook.selection_changed(hook.target)
	}
}

pub fn (d &Document) editing_history_can_undo() bool {
	hook := d.editing_history_hook_ or { return false }
	if hook.can_undo == unsafe { nil } {
		return false
	}
	return hook.can_undo(hook.target)
}

pub fn (d &Document) editing_history_can_redo() bool {
	hook := d.editing_history_hook_ or { return false }
	if hook.can_redo == unsafe { nil } {
		return false
	}
	return hook.can_redo(hook.target)
}

pub fn (d &Document) html_fragment_parsing_hook() ?DocumentHTMLFragmentParsingHook {
	return d.html_fragment_parsing_hook_
}

pub fn (mut d Document) set_form_control_selected_text_callback(callback DocumentFormControlSelectedTextCallback) {
	d.form_control_selected_text_callback_ = callback
}

pub fn (mut d Document) set_form_control_input_events_target_callback(callback DocumentFormControlInputEventsTargetCallback) {
	d.form_control_input_events_target_callback_ = callback
}

pub fn (d &Document) selected_text_for_active_form_control() ?string {
	active_element := d.active_element() or { return none }
	if d.form_control_selected_text_callback_ == unsafe { nil } {
		return none
	}
	return d.form_control_selected_text_callback_(active_element)
}

fn (d &Document) create_html_parser_for_scripting() !&HTMLParser {
	hook := d.html_fragment_parsing_hook_ or {
		return error('InvalidStateError: the HTML parser hook is not installed for this document')
	}

	if hook.create_parser_for_scripting == unsafe { nil } {
		return error('InvalidStateError: the HTML parser hook cannot create a scripting parser')
	}
	return hook.create_parser_for_scripting(hook.target, d)
}

pub fn (mut d Document) update_style() {
	mut allocations := d.enter_native_storage()
	defer { allocations.finish() }
	phase_mark := platform.arena_phase_begin()
	defer {
		platform.arena_phase_end('style', phase_mark)
	}
	// A child document's viewport can change as a consequence of laying out its
	// container, so upstream updates the parent document first.
	if navigable := d.navigable() {
		if container := navigable.container() {
			container_document := container.document()
			if voidptr(container_document) != voidptr(&d) {
				mut mutable_container_document := unsafe { &Document(container_document) }
				mutable_container_document.update_layout(.child_document_style_update)
			}
		}
	}

	if d.browsing_context == unsafe { nil } {
		return
	}

	d.update_animated_style_if_needed()
	d.transition_generation++

	mut document_node := unsafe { &Node(&d) }
	has_pending_invalidations := d.style_invalidator_ != unsafe { nil } && d.style_invalidator_.has_pending_invalidations()
	if !has_pending_invalidations && !d.needs_full_style_update && !d.needs_invalidation_of_elements_affected_by_has && !document_node.needs_style_update() && !document_node.child_needs_style_update() {
		return
	}
	if d.style_invalidator_ != unsafe { nil } {
		mut invalidator := unsafe { &StyleInvalidator(d.style_invalidator_) }
		// A full cascade already visits every connected element and shadow tree.
		// Reuse subtree invalidation to drain pending plans and removed-attribute
		// state without matching selective rules that cannot enlarge that set.
		if d.needs_full_style_update {
			document_node.set_entire_subtree_needs_style_update(true)
		}
		invalidator.invalidate(mut document_node)
	}

	// Documents which only host <template> contents do not participate in style.
	if d.created_for_appropriate_template_contents {
		return
	}

	hook := d.style_update_hook_ or { return }
	if hook.callback == unsafe { nil } {
		return
	}
	invalidation := hook.callback(hook.target)
	if invalidation.repaint {
		d.set_needs_repaint_with_invalidation(if invalidation.invalidates_hit_test_display_list {
			.paint_commands_and_hit_test_list
		} else {
			.paint_commands
		})
	}
	if invalidation.rebuild_accumulated_visual_contexts {
		d.needs_accumulated_visual_contexts_update = true
	}
	if invalidation.rebuild_stacking_context_tree {
		d.invalidate_stacking_context_tree()
	}
	d.needs_full_style_update = false
	d.notify_layout_after_style_update()
}

pub fn (mut d Document) update_animated_style_if_needed() {
	if !d.needs_animated_style_update {
		return
	}
	did_update := d.style_computer != unsafe { nil }
		&& d.style_computer.update_animated_style_callback != unsafe { nil }
	if did_update {
		d.style_computer.update_animated_style_callback(d.style_computer.css_handle)
	}
	d.needs_animated_style_update = false
	if did_update {
		d.notify_layout_after_style_update()
	}
}

fn (d &Document) notify_layout_after_style_update() {
	hook := d.layout_update_hook_ or { return }
	if hook.style_did_update != unsafe { nil } {
		hook.style_did_update(hook.target, d)
	}
}

pub fn (mut d Document) update_paint_and_hit_testing_properties_if_needed() {
	if d.needs_accumulated_visual_contexts_update {
		d.needs_accumulated_visual_contexts_update = false
		d.needs_compositor_visual_contexts_update = false
		if paintable := d.unsafe_paintable() {
			paintable.assign_accumulated_visual_contexts()
		}
	} else if d.needs_compositor_visual_contexts_update {
		d.needs_compositor_visual_contexts_update = false
		if paintable := d.unsafe_paintable() {
			paintable.refresh_compositor_visual_contexts()
		}
	}
	// Scroll nodes are (re)created by the visual-context update above. Derive
	// offsets and publish the snapshot only after that structure is settled.
	if paintable := d.unsafe_paintable() {
		paintable.refresh_scroll_state()
	}
}

// --- Layout ---
fn layout_stabilization_element_count(node &Node) int {
	mut count := if node.is_element() { 1 } else { 0 }
	if element := node.as_element() {
		if shadow_root := element.shadow_root() {
			count += layout_stabilization_element_count(unsafe { &Node(shadow_root) })
		}
	}
	for child in node.children {
		count += layout_stabilization_element_count(child)
	}
	return count
}

fn (mut d Document) invalidate_layout_stabilization_count() {
	d.layout_stabilization_count_ = -1
}

fn (mut d Document) cached_layout_stabilization_element_count() int {
	if d.layout_stabilization_count_ < 0
		|| d.layout_stabilization_count_tree_version_ != d.dom_tree_version {
		d.layout_stabilization_count_ = layout_stabilization_element_count(unsafe { &Node(&d) })
		d.layout_stabilization_count_tree_version_ = d.dom_tree_version
	}
	return d.layout_stabilization_count_
}

pub fn (d &Document) needs_style_update_after_layout() bool {
	if d.needs_full_style_update
		|| d.query_containers_needing_container_query_evaluation_after_layout.len > 0
		|| d.needs_animated_style_update {
		return true
	}
	document_node := unsafe { &Node(d) }
	return document_node.needs_style_update() || document_node.child_needs_style_update()
}

fn (mut d Document) invalidate_pending_size_query_dependents() {
	if d.query_containers_needing_container_query_evaluation_after_layout.len == 0 {
		return
	}
	query_containers := d.query_containers_needing_container_query_evaluation_after_layout.clone()
	d.query_containers_needing_container_query_evaluation_after_layout.clear()
	hook := d.style_update_hook_ or { return }
	if hook.invalidate_size_dependents == unsafe { nil } {
		return
	}
	for query_container in query_containers {
		if query_container.is_connected() {
			hook.invalidate_size_dependents(hook.target, query_container)
		}
	}
}

pub fn (mut d Document) update_layout(reason UpdateLayoutReason) {
	mut allocations := d.enter_native_storage()
	defer { allocations.finish() }
	_ = reason

	// Document.cpp: Document::update_layout(). Only the active document of a
	// navigable participates in layout.
	navigable := d.navigable() or { return }
	active_document := navigable.active_document() or { return }
	if voidptr(active_document) != voidptr(&d) {
		return
	}

	// Upstream treats re-entering layout as an invariant violation. `defer`
	// mirrors its ScopeGuard, including every early-return path below.
	assert !d.is_running_update_layout_
	d.is_running_update_layout_ = true
	defer {
		d.is_running_update_layout_ = false
	}

	document_node := unsafe { &Node(&d) }
	// A size-query dependency points from a descendant to an ancestor, so one
	// pass per connected element is a conservative exact bound for nested query
	// containers, in addition to Ladybird's ordinary stabilization allowance.
	layout_pass_limit := 9 + d.cached_layout_stabilization_element_count()
	for _ in 0 .. layout_pass_limit {
		d.update_style()
		if d.layout_is_up_to_date() {
			d.invalidate_pending_size_query_dependents()
			if d.needs_style_update_after_layout() {
				continue
			}
			return
		}

		// move(m_svg_roots_needing_relayout)
		svg_roots_to_relayout := d.svg_roots_needing_relayout.clone()
		d.svg_roots_needing_relayout.clear()

		// Documents which only host <template> contents never get a layout tree.
		if d.created_for_appropriate_template_contents {
			return
		}

		needs_layout_tree_rebuild := d.layout_engine_handle_ == unsafe { nil } || document_node.needs_layout_tree_update_() || document_node.child_needs_layout_tree_update_() || d.needs_full_layout_tree_update

		// Current upstream can relayout isolated SVG roots without rebuilding the
		// document tree. The translated SVG box owns the same narrow callback at
		// the dom/layout module boundary.
		root_needs_layout := if layout_node := document_node.unsafe_layout_node() {
			layout_node.needs_layout_update()
		} else {
			false
		}
		if !needs_layout_tree_rebuild && svg_roots_to_relayout.len > 0 && !root_needs_layout {
			for svg_root in svg_roots_to_relayout {
				relayout_svg_root(svg_root)
			}
			d.invalidate_stacking_context_tree()
			d.invalidate_display_list()
			d.needs_accumulated_visual_contexts_update = true
			d.update_paint_and_hit_testing_properties_if_needed()
			d.set_needs_repaint()
			return
		}

		d.invalidate_display_list()

		// Layout::TreeBuilder, formatting-context layout and LayoutState::commit
		// live in the layout module. This callback returns its retained root/state
		// handle; no alternate DOM-side layout algorithm is used here.
		hook := d.layout_update_hook_ or { return }
		if hook.callback == unsafe { nil } {
			return
		}
		viewport := d.viewport_rect()
		new_layout := hook.callback(hook.target, &d, viewport.width, viewport.height, needs_layout_tree_rebuild)
		if new_layout == unsafe { nil } {
			// Keep every invalidation bit set when the layout boundary cannot
			// produce a tree, so a later call retries instead of declaring the
			// document clean.
			return
		}
		d.layout_engine_handle_ = new_layout
		d.layout_pass_generation++

		// TreeBuilder consumes these DOM invalidations while rebuilding the tree.
		document_node.for_each_shadow_including_inclusive_descendant(fn (node &Node) TraversalDecision {
			mut mutable_node := unsafe { &Node(node) }
			mutable_node.set_needs_layout_tree_update(false, .style_change)
			mutable_node.set_child_needs_layout_tree_update(false)
			return .@continue
		})
		d.needs_full_layout_tree_update = false

		d.set_needs_repaint()
		d.needs_accumulated_visual_contexts_update = true
		d.update_paint_and_hit_testing_properties_if_needed()
		if d.selection_ != unsafe { nil } && d.selection_.range_ != unsafe { nil } {
			if paintable := d.unsafe_paintable() {
				paintable.recompute_selection_states(d.selection_.range_)
			}
		}

		d.invalidate_pending_size_query_dependents()
		if d.needs_style_update_after_layout() {
			continue
		}
		return
	}

	assert !d.needs_style_update_after_layout() && d.layout_is_up_to_date()
}

pub fn (mut d Document) set_layout_update_hook(hook DocumentLayoutUpdateHook) {
	d.layout_update_hook_ = hook
}

pub fn (mut d Document) set_rendered_text_hook(hook DocumentRenderedTextHook) {
	d.rendered_text_hook_ = hook
}

pub fn (mut d Document) set_accessibility_role_hook(hook DocumentAccessibilityRoleHook) {
	d.accessibility_role_hook_ = hook
}

pub fn (mut d Document) set_csp_hook(hook DocumentCSPHook) {
	d.csp_hook_ = hook
}

// The real Window/Document/settings constructor supplies the Source CSP call
// before parsing. Preserve the independently installed inline/init callbacks.
pub fn (mut d Document) set_base_csp_check(callback DocumentBaseCSPCheckCallback) {
	hook := d.csp_hook_ or { DocumentCSPHook{} }
	d.csp_hook_ = DocumentCSPHook{
		...hook
		base_check: callback
	}
}

pub fn (mut d Document) set_meta_csp_enforce(callback DocumentMetaCSPEnforceCallback) {
	hook := d.csp_hook_ or { DocumentCSPHook{} }
	d.csp_hook_ = DocumentCSPHook{
		...hook
		meta_enforce: callback
	}
}

pub fn (d &Document) is_base_allowed_by_csp(base URL) bool {
	hook := d.csp_hook_ or { return true }
	if hook.base_check == unsafe { nil } {
		return true
	}
	return hook.base_check(d, base)
}

pub fn (mut d Document) set_trusted_types_hook(hook DocumentTrustedTypesHook) {
	d.trusted_types_hook_ = hook
}

pub fn (mut d Document) set_html_navigation_hook(hook DocumentHTMLNavigationHook) {
	d.html_navigation_hook_ = hook
}

pub fn (mut d Document) set_fullscreen_hook(hook DocumentFullscreenHook) {
	d.fullscreen_hook_ = hook
}

pub fn (d &Document) should_block_inline_content(element &Element, inline_type string, source string) bool {
	hook := d.csp_hook_ or { return false }
	if hook.inline_check == unsafe { nil } {
		return false
	}
	return hook.inline_check(hook.target, element, inline_type, source)
}

pub fn (d &Document) trusted_types_compliant_html(input string, sink string) !string {
	hook := d.trusted_types_hook_ or { return input }
	if hook.compliant_html == unsafe { nil } {
		return input
	}
	return hook.compliant_html(hook.target, d, input, sink)!
}

pub fn (d &Document) trusted_types_compliant_attribute_value(element &Element, local_name string, namespace_uri ?string, input string) !string {
	hook := d.trusted_types_hook_ or { return input }
	if hook.compliant_attribute == unsafe { nil } {
		return input
	}
	return hook.compliant_attribute(hook.target, element, local_name, namespace_uri, input)!
}

pub fn (d &Document) element_allows_accessible_name_from_content(element &Element, should_compute_role bool) ?bool {
	hook := d.accessibility_role_hook_ or { return none }
	if hook.element_allows_name_from_content == unsafe { nil } {
		return none
	}
	return hook.element_allows_name_from_content(hook.target, element, should_compute_role)
}

pub fn (d &Document) embedded_control_label_value(element &Element) ?string {
	hook := d.accessibility_role_hook_ or { return none }
	if hook.embedded_control_label_value == unsafe { nil } {
		return none
	}
	return hook.embedded_control_label_value(hook.target, element)
}

pub fn (d &Document) rendered_text(element &Element) ?string {
	hook := d.rendered_text_hook_ or { return none }
	if hook.callback == unsafe { nil } {
		return none
	}
	return hook.callback(hook.target, d, element)
}

pub fn (d &Document) layout_engine_handle() voidptr {
	return d.layout_engine_handle_
}

pub fn (d &Document) layout_is_up_to_date() bool {
	navigable := d.navigable() or { return true }
	active_document := navigable.active_document() or { return true }
	if voidptr(active_document) != voidptr(d) {
		return true
	}
	if d.layout_engine_handle_ == unsafe { nil } {
		return false
	}
	document_node := unsafe { &Node(d) }
	if layout_node := document_node.unsafe_layout_node() {
		if layout_node.needs_layout_update() {
			return false
		}
	}
	return !document_node.needs_layout_tree_update_() && !document_node.child_needs_layout_tree_update_() && !d.needs_full_layout_tree_update && d.svg_roots_needing_relayout.len == 0
}

pub fn (d &Document) is_running_update_layout() bool {
	return d.is_running_update_layout_
}

pub fn (mut d Document) set_needs_container_query_evaluation_after_layout(query_container &Element) {
	for existing in d.query_containers_needing_container_query_evaluation_after_layout {
		if voidptr(existing) == voidptr(query_container) {
			return
		}
	}
	d.query_containers_needing_container_query_evaluation_after_layout << query_container
}

pub fn (d &Document) needs_container_query_evaluation_after_layout(query_container &Element) bool {
	for existing in d.query_containers_needing_container_query_evaluation_after_layout {
		if voidptr(existing) == voidptr(query_container) {
			return true
		}
	}
	return false
}

pub fn (mut d Document) invalidate_layout_tree(reason InvalidateLayoutTreeReason) {
	_ = reason
	d.tear_down_layout_tree()
}

pub fn (mut d Document) invalidate_stacking_context_tree() {
	// NB: Called during stacking-context invalidation upstream.
	if paintable := d.unsafe_paintable() {
		paintable.invalidate_stacking_context()
	}
}

pub fn (mut d Document) tear_down_layout_tree() {
	d.layout_root = unsafe { nil }
	d.paintable_ = unsafe { nil }
	d.needs_full_layout_tree_update = true
}

pub fn (mut d Document) clear_layout_and_paintable_nodes_for_inactive_document() {
	root := unsafe { &Node(&d) }
	root.for_each_in_inclusive_subtree(fn (node &Node) TraversalDecision {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.clear_layout_node_and_paintable()
		if element := node.as_element() {
			mut mutable_element := unsafe { &Element(element) }
			mutable_element.clear_pseudo_element_layout_nodes()
		}
		return .@continue
	})
}

// --- Node creation ---

// https://dom.spec.whatwg.org/#dom-document-createelement
pub fn (d &Document) create_element(local_name string) !&Element {
	if !is_valid_element_local_name(local_name) {
		return error('InvalidCharacterError: Invalid character in tag name')
	}
	local_name_lower := if d.document_type() == .html {
		to_ascii_lowercase(local_name)
	} else {
		local_name
	}
	namespace_ := if d.document_type() == .html || d.content_type == 'application/xhtml+xml' {
		?string(namespace_html_)
	} else {
		?string(none)
	}
	return create_element_with_registry(d, local_name_lower, namespace_, none, none, true, d.custom_element_registry())!
}

pub fn (d &Document) create_element_with_options(local_name string, options ElementCreationOptions) !&Element {
	// 1. If localName is not a valid element local name, then throw an "InvalidCharacterError" DOMException.
	if !is_valid_element_local_name(local_name) {
		return error('InvalidCharacterError: Invalid character in tag name')
	}

	// 2. If this is an HTML document, then set localName to localName in ASCII lowercase.
	local_name_lower := if d.document_type() == .html {
		to_ascii_lowercase(local_name)
	} else {
		local_name
	}

	// 3. Let registry and is be the result of flattening element creation options.
	registry_and_is := d.flatten_element_creation_options(options)!

	// 5. Let namespace be the HTML namespace, if this is an HTML document or this's content type is "application/xhtml+xml"; otherwise null.
	namespace_ := if d.document_type() == .html || d.content_type == 'application/xhtml+xml' {
		?string(namespace_html_)
	} else {
		?string(none)
	}

	// 6. Return the result of creating an element given this, localName, namespace, null, is, and with the synchronous custom elements flag set.
	return create_element_with_registry(d, local_name_lower, namespace_, none, registry_and_is.is_value, true, registry_and_is.registry)!
}

// https://dom.spec.whatwg.org/#internal-createelementns-steps
pub fn (d &Document) create_element_ns(namespace_ ?string, qualified_name string) !&Element {
	extracted_qualified_name := validate_and_extract(namespace_, qualified_name, .element)!
	return create_element_with_registry(d, extracted_qualified_name.local_name, extracted_qualified_name.namespace_, extracted_qualified_name.prefix_, none, true, d.custom_element_registry())!
}

pub fn (d &Document) create_element_ns_with_options(namespace_ ?string, qualified_name string, options ElementCreationOptions) !&Element {
	// 1. Let (namespace, prefix, localName) be the result of validating and extracting namespace and qualifiedName given "element".
	extracted_qualified_name := validate_and_extract(namespace_, qualified_name, .element)!

	// 2. Let registry and is be the result of flattening element creation options.
	registry_and_is := d.flatten_element_creation_options(options)!

	// 3. Return the result of creating an element with the synchronous custom elements flag and registry.
	return create_element_with_registry(d, extracted_qualified_name.local_name, extracted_qualified_name.namespace_, extracted_qualified_name.prefix_, registry_and_is.is_value, true, registry_and_is.registry)!
}

// https://dom.spec.whatwg.org/#flatten-element-creation-options
fn (d &Document) flatten_element_creation_options(options ElementCreationOptions) !RegistryAndIs {
	mut registry := d.custom_element_registry()
	is_value := options.is_
	if options.custom_element_registry != none {
		if is_value != none {
			return error("NotSupportedError: cannot specify both 'is' and 'customElementRegistry'")
		}
		registry = options.custom_element_registry or { unsafe { nil } }
	}
	if registry != unsafe { nil } && !custom_element_registry_is_scoped(registry)
		&& registry != d.custom_element_registry() {
		return error("NotSupportedError: registry must be scoped or the document's registry")
	}
	return RegistryAndIs{
		registry: registry
		is_value: is_value
	}
}

pub fn (d &Document) create_document_fragment() &DocumentFragment {
	return new_document_fragment(d)
}

pub fn (d &Document) create_text_node(data string) &Text {
	return new_text_node(d, data)
}

// https://dom.spec.whatwg.org/#dom-document-createcdatasection
pub fn (d &Document) create_cdata_section(data string) !&CDATASection {
	if d.is_html_document() {
		return error('NotSupportedError: This operation is not supported for HTML documents')
	}
	// 2. If data contains the string "]]>", then throw an "InvalidCharacterError" DOMException.
	if data.contains(']]>') {
		return error("InvalidCharacterError: String may not contain ']]>'")
	}
	return assign_unique_node_id(&CDATASection{
		Text: Text{
			CharacterData: CharacterData{
				Node: Node{
					node_type: .cdata_section_node
					document_: d
					unique_id_: UniqueNodeID(0)
				}
				data_: data
			}
		}
	})
}

pub fn (d &Document) create_comment(data string) &Comment {
	return assign_unique_node_id(&Comment{
		CharacterData: CharacterData{
			Node: Node{
				node_type: .comment_node
				document_: d
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
	})
}

// https://dom.spec.whatwg.org/#dom-document-createprocessinginstruction
pub fn (d &Document) create_processing_instruction(target string, data string) !&ProcessingInstruction {
	// 1. If target does not match the Name production, then throw an "InvalidCharacterError" DOMException.
	if !is_valid_name(target) {
		return error('InvalidCharacterError: Invalid character in target name')
	}

	// 2. If data contains the string "?>", then throw an "InvalidCharacterError" DOMException.
	if data.contains('?>') {
		return error("InvalidCharacterError: String may not contain '?>'")
	}

	// 3. Return a new ProcessingInstruction node, with target set to target, data set to data, and node document set to this.
	return assign_unique_node_id(&ProcessingInstruction{
		CharacterData: CharacterData{
			Node: Node{
				node_type: .processing_instruction_node
				document_: d
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
		target_: target
	})
}

// https://dom.spec.whatwg.org/#dom-document-createattribute
pub fn (d &Document) create_attribute(local_name string) !&Attr {
	// 1. If localName is not a valid attribute local name, then throw an "InvalidCharacterError" DOMException.
	if !is_valid_attribute_local_name(local_name) {
		return error('InvalidCharacterError: Invalid character in attribute name')
	}

	// 2. If this is an HTML document, then set localName to localName in ASCII lowercase.
	// 3. Return a new attribute whose local name is localName and node document is this.
	normalized_local_name := if d.is_html_document() {
		to_ascii_lowercase(local_name)
	} else {
		local_name
	}
	return Attr.create_with_local_name(d, normalized_local_name, '', none)
}

// https://dom.spec.whatwg.org/#dom-document-createattributens
pub fn (d &Document) create_attribute_ns(namespace_ ?string, qualified_name string) !&Attr {
	// 1. Let (namespace, prefix, localName) be the result of validating and extracting namespace and qualifiedName given "attribute".
	extracted_qualified_name := validate_and_extract(namespace_, qualified_name, .attribute)!

	// 2. Return a new attribute whose namespace is namespace, namespace prefix is prefix, local name is localName, and node document is this.
	return Attr.create(d, extracted_qualified_name, '', none)
}

// https://dom.spec.whatwg.org/#dom-document-createevent
pub fn (d &Document) create_event(iface string) !&Event {
	_ = d
	interface_name := to_ascii_lowercase(iface)
	mut event := match interface_name {
		'customevent' {
			unsafe { &Event(CustomEvent.create('', CustomEventInit{})) }
		}
		'beforeunloadevent', 'compositionevent', 'devicemotionevent', 'deviceorientationevent', 'dragevent', 'event', 'events', 'focusevent', 'hashchangeevent', 'htmlevents', 'keyboardevent', 'messageevent', 'mouseevent', 'mouseevents', 'storageevent', 'svgevents', 'textevent', 'touchevent', 'uievent', 'uievents' {
			Event.new('')
		}
		else {
			return error('NotSupportedError: No constructor for interface found')
		}
	}

	// 8. Initialize event's isTrusted attribute to false.
	event.set_is_trusted(false)

	// 9. Unset event's initialized flag.
	event.set_initialized(false)

	// 10. Return event.
	return event
}

pub fn (d &Document) create_range() &Range {
	return Range.create(d)
}

// --- Node operations ---

// https://dom.spec.whatwg.org/#dom-document-importnode
pub fn (d &Document) import_node(node &Node, deep bool) !&Node {
	return d.import_node_with_options(node, ImportNodeOptions{ self_only: !deep })
}

pub fn (d &Document) import_node_with_options(node &Node, options ImportNodeOptions) !&Node {
	// 1. If node is a document or shadow root, then throw a "NotSupportedError" DOMException.
	if node.is_document() || node.is_shadow_root() {
		return error('NotSupportedError: Cannot import a document or shadow root')
	}

	mut registry := options.custom_element_registry
	if registry != unsafe { nil } && !custom_element_registry_is_scoped(registry)
		&& registry != d.custom_element_registry() {
		return error("NotSupportedError: registry must be scoped or the document's registry")
	}
	if registry == unsafe { nil } {
		registry = look_up_custom_element_registry(d.as_node())
	}
	return node.clone_node_with_registry(d, !options.self_only, none, registry)!
}

// https://dom.spec.whatwg.org/#concept-node-adopt
pub fn (mut d Document) adopt_node(node &Node) {
	// 1. Let oldDocument be node's node document.
	old_document := node.document()

	// 2. If node's parent is non-null, then remove node.
	if node.parent() != none {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.remove(false)
	}

	// 3. If document is not oldDocument, then:
	d_ptr := unsafe { &Document(d) }
	if voidptr(old_document) != voidptr(d_ptr) {
		mut storage := old_document.native_storage_
		if storage != unsafe { nil } && voidptr(storage) != voidptr(d.native_storage_)
			&& !storage.arena.contains(voidptr(d_ptr)) {
			storage.pin()
			mut source := unsafe { &Document(old_document) }
			source.paint_borrowed_by_host = true
		}
		d.style_scope_adoption_depth_++
		defer {
			d.style_scope_adoption_depth_--
		}
		// 1. For each inclusiveDescendant in node's shadow-including inclusive descendants:
		node.visit_shadow_including_inclusive_descendants(fn [d_ptr] (inclusive_descendant &Node) TraversalDecision {
			// 1. Set inclusiveDescendant's node document to document.
			mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
			mutable_descendant.set_document(d_ptr)

			if shadow_root := inclusive_descendant.as_shadow_root() {
				registry := shadow_root.custom_element_registry()
				if (registry == unsafe { nil } && !shadow_root.keep_custom_element_registry_null())
					|| is_a_global_custom_element_registry(registry) {
					mut mutable_shadow_root := unsafe { &ShadowRoot(shadow_root) }
					mutable_shadow_root.set_custom_element_registry(d_ptr.effective_global_custom_element_registry())
				}
			} else if element := inclusive_descendant.as_element() {
				registry := element.custom_element_registry()
				if registry == unsafe { nil } || is_a_global_custom_element_registry(registry) {
					mut mutable_element := unsafe { &Element(element) }
					mutable_element.set_custom_element_registry(d_ptr.effective_global_custom_element_registry())
				}
			}

			// Element attributes in this V port are not Node-backed yet.
			return .@continue
		})

		// 2. For each inclusiveDescendant in node's shadow-including inclusive descendants that is custom,
		//    enqueue a custom element callback reaction with inclusiveDescendant, callback name "adoptedCallback",
		//    and an argument list containing oldDocument and document.
		node.for_each_shadow_including_inclusive_descendant(fn (inclusive_descendant &Node) TraversalDecision {
			if element := inclusive_descendant.as_element() {
				if element.is_custom() {
					mut mutable_element := unsafe { &Element(element) }
					mutable_element.enqueue_a_custom_element_callback_reaction('adoptedCallback', [])
				}
			}
			return .@continue
		})

		// 3. For each inclusiveDescendant in node's shadow-including inclusive descendants, in shadow-including tree order,
		//    run the adopting steps with inclusiveDescendant and oldDocument.
		node.visit_shadow_including_inclusive_descendants(fn [old_document] (inclusive_descendant &Node) TraversalDecision {
			mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
			mutable_descendant.adopted_from(old_document)
			return .@continue
		})

		// Transfer NodeIterators rooted at `node` from old_document to this document.
		mut node_iterators_to_transfer := []&NodeIterator{}
		for node_iterator in old_document.node_iterators {
			if voidptr(node_iterator.root) == voidptr(node) {
				node_iterators_to_transfer << node_iterator
			}
		}
		mut mutable_old_document := unsafe { &Document(old_document) }
		for node_iterator in node_iterators_to_transfer {
			mutable_old_document.unregister_node_iterator(node_iterator)
			d.register_node_iterator(node_iterator)
		}
	}
}

// https://dom.spec.whatwg.org/#dom-document-adoptnode
pub fn (mut d Document) adopt_node_binding(node &Node) !&Node {
	if node.is_document() {
		return error('NotSupportedError: Cannot adopt a document into a document')
	}

	if node.is_shadow_root() {
		return error('HierarchyRequestError: Cannot adopt a shadow root into a document')
	}

	if fragment := node.as_document_fragment() {
		if fragment.host() != none {
			return node
		}
	}

	d.adopt_node(node)
	return node
}

// --- Doctype & compat ---
pub fn (d &Document) doctype() ?&DocumentType {
	for child in unsafe { &Node(d) }.children {
		if doctype := child.as_document_type() {
			return doctype
		}
	}
	return none
}

pub fn (d &Document) compat_mode() string {
	if d.quirks_mode == .yes {
		return 'BackCompat'
	}
	return 'CSS1Compat'
}

// --- Focus ---
pub fn (d &Document) focused_area() ?&Node {
	if d.focused_area == unsafe { nil } {
		return none
	}
	return d.focused_area
}

// Translated from Document.cpp's find_common_ancestor(). Pseudo-class state
// crosses shadow boundaries through parent_or_shadow_host(), just like the
// selectors whose match result is being invalidated.
fn find_common_ancestor(a ?&Node, b ?&Node) ?&Node {
	first := a or { return none }
	second := b or { return none }
	if first.is_same_node(second) {
		return first
	}

	mut ancestors := map[i64]bool{}
	mut current := ?&Node(first)
	for current != none {
		node := current or { break }
		ancestors[node.unique_id().value()] = true
		current = node.parent_or_shadow_host()
	}

	current = second
	for current != none {
		node := current or { break }
		if ancestors[node.unique_id().value()] {
			return node
		}
		current = node.parent_or_shadow_host()
	}
	return none
}

pub fn (mut d Document) set_focused_area(node ?&Node) {
	new_focused := node or { unsafe { nil } }
	if voidptr(d.focused_area) == voidptr(new_focused) {
		return
	}
	old_focused := d.focused_area

	if old_focused != unsafe { nil } {
		if old_focused_element := old_focused.as_element() {
			mut mutable_old_focused_element := unsafe { &Element(old_focused_element) }
			mutable_old_focused_element.did_lose_focus()
		}
	}

	old_focused_option := if old_focused == unsafe { nil } {
		?&Node(none)
	} else {
		?&Node(old_focused)
	}
	common_ancestor := find_common_ancestor(old_focused_option, node)
	old_root := if old_focused == unsafe { nil } {
		unsafe { nil }
	} else {
		old_focused.root()
	}
	new_root := if new_focused == unsafe { nil } {
		unsafe { nil }
	} else {
		new_focused.root()
	}
	if voidptr(old_root) != voidptr(new_root) {
		if old_root != unsafe { nil } {
			for pseudo_class in [PseudoClass.focus, .focus_within, .focus_visible] {
				d.invalidate_style_for_elements_affected_by_pseudo_class_change(pseudo_class, old_root, node)
			}
		}
		if new_root != unsafe { nil } {
			for pseudo_class in [PseudoClass.focus, .focus_within, .focus_visible] {
				d.invalidate_style_for_elements_affected_by_pseudo_class_change(pseudo_class, new_root, node)
			}
		}
	} else if ancestor := common_ancestor {
		for pseudo_class in [PseudoClass.focus, .focus_within, .focus_visible] {
			d.invalidate_style_for_elements_affected_by_pseudo_class_change(pseudo_class, ancestor, node)
		}
	}

	d.focused_area = new_focused
	if new_focused != unsafe { nil } {
		if new_focused_element := new_focused.as_element() {
			mut mutable_new_focused_element := unsafe { &Element(new_focused_element) }
			mutable_new_focused_element.did_receive_focus()
		}
	}
	d.reset_cursor_blink_cycle()
	d.set_needs_repaint_with_invalidation(.paint_commands)
	d.update_active_element()
}

pub fn (d &Document) last_focus_trigger_() FocusTrigger {
	return d.last_focus_trigger
}

pub fn (mut d Document) set_last_focus_trigger(trigger FocusTrigger) {
	d.last_focus_trigger = trigger
}

pub fn (d &Document) active_element() ?&Element {
	if d.active_element_ == unsafe { nil } {
		return if body := d.body() { html_element_as_element(body) } else { none }
	}
	return d.active_element_
}

pub fn (mut d Document) set_active_element(element ?&Element) {
	new_active_element := element or { unsafe { nil } }
	if voidptr(d.active_element_) == voidptr(new_active_element) {
		return
	}
	d.active_element_ = new_active_element
	d.set_needs_repaint_with_invalidation(.paint_commands)
}

pub fn (d &Document) target_element() ?&Element {
	if d.target_element_ == unsafe { nil } {
		return none
	}
	return d.target_element_
}

pub fn (mut d Document) set_target_element(element ?&Element) {
	new_target := element or { unsafe { nil } }
	if voidptr(d.target_element_) == voidptr(new_target) {
		return
	}
	old_target := d.target_element_
	old_target_node := if old_target == unsafe { nil } {
		?&Node(none)
	} else {
		?&Node(old_target.as_node())
	}
	new_target_node := if new_target == unsafe { nil } {
		?&Node(none)
	} else {
		?&Node(new_target.as_node())
	}
	common_ancestor := find_common_ancestor(old_target_node, new_target_node)
	old_root := if old_target == unsafe { nil } {
		unsafe { nil }
	} else {
		old_target.as_node().root()
	}
	new_root := if new_target == unsafe { nil } {
		unsafe { nil }
	} else {
		new_target.as_node().root()
	}
	new_node := new_target_node
	if voidptr(old_root) != voidptr(new_root) {
		if old_root != unsafe { nil } {
			d.invalidate_style_for_elements_affected_by_pseudo_class_change(.target, old_root, new_node)
		}
		if new_root != unsafe { nil } {
			d.invalidate_style_for_elements_affected_by_pseudo_class_change(.target, new_root, new_node)
		}
	} else if ancestor := common_ancestor {
		d.invalidate_style_for_elements_affected_by_pseudo_class_change(.target, ancestor, new_node)
	}
	d.target_element_ = new_target
	d.set_needs_repaint_with_invalidation(.paint_commands)
}

pub fn (d &Document) autofocus_candidates() []&Element {
	return d.autofocus_candidates_.clone()
}

pub fn (d &Document) autofocus_processed_flag() bool {
	return d.autofocus_processed_flag_
}

pub fn (mut d Document) add_autofocus_candidate(element &Element) {
	if d.autofocus_processed_flag_ {
		return
	}
	d.autofocus_candidates_ = d.autofocus_candidates_.filter(voidptr(it) != voidptr(element))
	d.autofocus_candidates_ << element
}

// https://html.spec.whatwg.org/multipage/interaction.html#flush-autofocus-candidates
// The HTML event loop runs the focusing steps for the returned target so this
// DOM-owned algorithm does not introduce a dom -> html import cycle.
pub fn (mut d Document) take_autofocus_candidate_to_focus() ?&Element {
	if d.autofocus_processed_flag_ || d.autofocus_candidates_.len == 0 {
		return none
	}
	if focused := d.focused_area() {
		if !focused.is_same_node(unsafe { &Node(d) }) {
			d.autofocus_candidates_.clear()
			d.autofocus_processed_flag_ = true
			return none
		}
	}
	if d.target_element() != none {
		d.autofocus_candidates_.clear()
		d.autofocus_processed_flag_ = true
		return none
	}

	for d.autofocus_candidates_.len > 0 {
		element := d.autofocus_candidates_[0]
		document := element.document()
		if !document.is_fully_active() {
			d.autofocus_candidates_.delete(0)
			continue
		}
		navigable := document.navigable() or {
			d.autofocus_candidates_.delete(0)
			continue
		}
		top_level_traversable := navigable.traversable_navigable() or {
			d.autofocus_candidates_.delete(0)
			continue
		}
		top_document_navigable := d.navigable() or {
			d.autofocus_candidates_.delete(0)
			continue
		}
		if voidptr(top_level_traversable) != voidptr(top_document_navigable) {
			d.autofocus_candidates_.delete(0)
			continue
		}
		if document.has_a_style_sheet_that_is_blocking_scripts() {
			return none
		}

		d.autofocus_candidates_.delete(0)
		mut ancestor_has_target := document.target_element() != none
		mut ancestor_navigable := navigable.parent()
		for !ancestor_has_target && ancestor_navigable != none {
			current_navigable := ancestor_navigable or { break }
			if ancestor_document := current_navigable.active_document() {
				ancestor_has_target = ancestor_document.target_element() != none
			}
			ancestor_navigable = current_navigable.parent()
		}
		if ancestor_has_target || !element.as_node().is_connected() || !element.is_focusable() {
			continue
		}

		d.autofocus_candidates_.clear()
		d.autofocus_processed_flag_ = true
		return element
	}
	return none
}

// --- Scroll / fragment ---

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#try-to-scroll-to-the-fragment
pub fn (mut d Document) try_to_scroll_to_the_fragment() {
	// FIXME: According to the spec we should only scroll here if document has no parser or parsing has stopped.
	//        It should be ok to remove this after we implement navigation events and scrolling will happen in
	//        "process scroll behavior".
	//  To try to scroll to the fragment for a Document document, perform the following steps in parallel:
	//  1. Wait for an implementation-defined amount of time. (This is intended to allow the user agent to
	//     optimize the user experience in the face of performance concerns.)
	//  2. Queue a global task on the navigation and traversal task source given document's relevant global
	//     object to run these steps:
	//      1. If document has no parser, or its parser has stopped parsing, or the user agent has reason to
	//         believe the user is no longer interested in scrolling to the fragment, then abort these steps.
	//      2. Scroll to the fragment given document.
	//      3. If document's indicated part is still null, then try to scroll to the fragment for document.
	d.scroll_to_the_fragment()
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#scroll-to-the-fragment-identifier
pub fn (mut d Document) scroll_to_the_fragment() {
	// To scroll to the fragment given a Document document:
	indicated_part := d.determine_the_indicated_part()

	// 1. If document's indicated part is null, then set document's target element to null.
	if indicated_part.type_ == .none_ {
		d.set_target_element(none)
		// 2. Otherwise, if document's indicated part is top of the document, then:
	} else if indicated_part.type_ == .top_of_document {
		// 1. Set document's target element to null.
		d.set_target_element(none)

		// 2. Scroll to the beginning of the document for document. [CSSOMVIEW]
		d.scroll_to_the_beginning_of_the_document()

		// 3. Return.
		return
	} else {
		// 3. Otherwise:
		// 1. Assert: document's indicated part is an element.
		// 2. Let target be document's indicated part.
		target := indicated_part.element
		if target == unsafe { nil } {
			return
		}

		// 3. Set document's target element to target.
		d.set_target_element(target)

		// FIXME: 4. Run the ancestor revealing algorithm on target.

		// 5. Scroll target into view, with behavior set to "auto", block set to "start", and inline set to "nearest". [CSSOMVIEW]
		mut mutable_target := unsafe { &Element(target) }
		_ = mutable_target.scroll_into_view()

		// 6. Run the focusing steps for target, with the Document's viewport as the fallback target.
		// FIXME: Pass the Document's viewport somehow.

		// FIXME: 7. Move the sequential focus navigation starting point to target.
	}
}

// https://drafts.csswg.org/cssom-view-1/#scroll-to-the-beginning-of-the-document
pub fn (mut d Document) scroll_to_the_beginning_of_the_document() {
	if navigable := d.navigable() {
		navigable.perform_scroll_of_viewport_scrolling_box(CSSPixelPoint_{})
	}
}

// --- Template ---
pub fn (d &Document) created_for_appropriate_template_contents() bool {
	return d.created_for_appropriate_template_contents
}

// https://html.spec.whatwg.org/multipage/scripting.html#appropriate-template-contents-owner-document
pub fn (mut d Document) appropriate_template_contents_owner_document() &Document {
	// 1. If document is not created by this algorithm:
	if !d.created_for_appropriate_template_contents {
		// 1. If document does not yet have an associated inert template document:
		if d.associated_inert_template_document == unsafe { nil } {
			// 1. Let newDocument be a new Document (whose browsing context is null). This is "a Document created by
			//    this algorithm" for the purposes of the step above.
			mut new_doc := Document.create(url_about_blank())
			new_doc.created_for_appropriate_template_contents = true
			// Inert template contents have a different DOM Document identity but
			// the containing native document owns their allocation lifetime.
			new_doc.borrow_native_storage(&d)

			// 2. If document is an HTML document, then mark newDocument as an HTML document also.
			if d.type_ == .html {
				new_doc.type_ = .html
			}

			// AD-HOC: Copy over the "allow declarative shadow roots" flag, otherwise no elements inside templates will
			//         be able to have declarative shadow roots.
			// Spec issue: https://github.com/whatwg/html/issues/11955
			new_doc.allow_declarative_shadow_roots = d.allow_declarative_shadow_roots

			// 3. Set document's associated inert template document to newDocument.
			d.associated_inert_template_document = new_doc
		}
		// 2. Set document to document's associated inert template document.
		return d.associated_inert_template_document
	}
	// 2. Return document.
	return d
}

// --- Window ---
pub fn (d &Document) get_window() ?&Window {
	if d.window == unsafe { nil } {
		return none
	}
	return d.window
}

pub fn (mut d Document) set_window(w &Window) {
	d.window = w
	mut window := unsafe { &Window(w) }
	window.set_associated_document(d)
}

// --- Dynamic markup insertion ---

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-write
pub fn (mut d Document) write(text []TrustedHTMLOrString) ! {
	// The document.write(...text) method steps are to run the document write steps with this, text, false, and
	// "Document write".
	d.run_the_document_write_steps(text, .no, .document_write)!
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-writeln
pub fn (mut d Document) writeln(text []TrustedHTMLOrString) ! {
	// The document.writeln(...text) method steps are to run the document write steps with this, text, true, and
	// "Document writeln".
	d.run_the_document_write_steps(text, .yes, .document_writeln)!
}

// Convenience adapters for callers which already know that every WebIDL
// argument is a string. The normative algorithm above still receives the
// tagged union and therefore handles mixed TrustedHTML/string vectors.
pub fn (mut d Document) write_strings(text []string) ! {
	mut values := []TrustedHTMLOrString{cap: text.len}
	for value in text {
		values << TrustedHTMLOrString(value)
	}
	d.write(values)!
}

pub fn (mut d Document) writeln_strings(text []string) ! {
	mut values := []TrustedHTMLOrString{cap: text.len}
	for value in text {
		values << TrustedHTMLOrString(value)
	}
	d.writeln(values)!
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-open
// C++: WebIDL::ExceptionOr<Document*> Document::open(Optional<String> const&, Optional<String> const&)
pub fn (mut d Document) open() !&Document {
	return d.open_document()
}

pub fn (mut d Document) open_document() !&Document {
	// 1. If document is XML, throw InvalidStateError.
	if d.is_xml_document() {
		return error('InvalidStateError: open() called on XML document')
	}
	// 2. If throw-on-dynamic-markup-insertion counter > 0, throw.
	if d.throw_on_dynamic_markup_insertion_counter > 0 {
		return error('InvalidStateError: throw-on-dynamic-markup-insertion-counter > 0')
	}

	// 3. Let entryDocument be the entry global object's associated Document.
	entry_document := html_entry_global_associated_document(d)

	// 4. If document's origin is not same origin to entryDocument's origin, then throw a "SecurityError" DOMException.
	if d.origin() != entry_document.origin() {
		return error("SecurityError: Document.origin() not the same as entryDocument's")
	}

	// 5. If parser and script nesting level > 0, return document.
	if d.parser != unsafe { nil } && d.parser.script_nesting_level() > 0 {
		return d
	}

	// 6. If unload counter > 0, return document.
	if d.unload_counter > 0 {
		return d
	}
	// 7. If active parser was aborted, return document.
	if d.active_parser_was_aborted {
		return d
	}
	// 8. Cancel pending attempts and stop an ongoing navigation without
	// spinning the navigation task source.
	if hook := d.html_navigation_hook_ {
		if hook.open_stop_loading != unsafe { nil } {
			hook.open_stop_loading(hook.target)
		}
	}
	// 11. Replace all with null (clear document).
	mut document_node := unsafe { &Node(&d) }
	document_node.replace_all(none)

	// Reset editing state
	d.css_styling_flag = false
	d.default_single_line_container_name = tag_div_
	d.command_state_override.clear()
	d.command_value_override.clear()

	// 12. If fully active, update URL and history.
	if d.is_fully_active() {
		// 1. Let newURL be a copy of entryDocument's URL.
		mut new_url := entry_document.url
		// 2. If entryDocument is not document, then set newURL's fragment to null.
		if entry_document != &d {
			new_url.set_fragment(none)
		}
		// 3. Run the URL and history update steps with document and newURL.
		html_perform_url_and_history_update_steps(d, new_url)!
	}

	// Keep Navigation API entries and events disabled after document.open()
	// clears the initial-about:blank marker.
	if d.is_initial_about_blank {
		if hook := d.html_navigation_hook_ {
			if hook.initial_about_blank_opened != unsafe { nil } {
				hook.initial_about_blank_opened(hook.target)
			}
		}
	}

	// 13. Set is_initial_about_blank to false.
	d.is_initial_about_blank = false

	// 15. Set to no-quirks mode.
	d.set_quirks_mode(.no)

	// 16. Create HTML parser for scripting.
	d.parser = d.create_html_parser_for_scripting()!

	// 17. Set the insertion point to point at just before the end of the input stream (which at this point will be empty).
	d.parser.update_insertion_point()

	// 18. Update readiness to loading.
	d.update_readiness(.loading)

	// 19. Return document.
	return d
}

pub fn (mut d Document) open_window(url string, name string, features string) ?&WindowProxy {
	// 1. If this is not fully active, throw InvalidAccessError.
	if !d.is_fully_active() {
		return none
	}
	// 2. Return result of running window open steps.
	hook := d.html_navigation_hook_ or { return none }
	if hook.open_window == unsafe { nil } {
		return none
	}
	return hook.open_window(hook.target, url, name, features)
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#closing-the-input-stream
pub fn (mut d Document) close() ! {
	// 1. If document is XML, throw InvalidStateError.
	if d.is_xml_document() {
		return error('InvalidStateError: close() called on XML document')
	}
	// 2. If throw-on-dynamic-markup-insertion counter > 0, throw.
	if d.throw_on_dynamic_markup_insertion_counter > 0 {
		return error('InvalidStateError: throw-on-dynamic-markup-insertion-counter > 0')
	}
	// 3. If no script-created parser, return.
	if d.parser == unsafe { nil } || !d.parser.is_script_created() {
		return
	}

	// 4. Insert an explicit "EOF" character at the end of the parser's input stream.
	d.parser.insert_eof()

	// 5. If there is a pending parsing-blocking script, then return.
	if d.has_pending_parsing_blocking_script() {
		d.parser.finish_loading_after_parse()
		return
	}

	// 6. Run the tokenizer, processing resulting tokens as they are emitted, and stopping when the tokenizer reaches
	// the explicit "EOF" character or pauses for a parser-blocking script.
	d.parser.run()
	if d.has_pending_parsing_blocking_script() {
		d.parser.finish_loading_after_parse()
		return
	}

	// AD-HOC: This ensures that a load event is fired if the node navigable's container is an iframe.
	d.completely_finish_loading()
}

// --- Default view ---

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-defaultview
pub fn (d &Document) default_view() ?&WindowProxy {
	// If this's browsing context is null, then return null.
	if d.browsing_context == unsafe { nil } {
		return none
	}
	// Return this's browsing context's WindowProxy object.
	return d.browsing_context.window_proxy()
}

// --- Content type & encoding ---
pub fn (d &Document) get_content_type() string {
	return d.content_type
}

pub fn (mut d Document) set_content_type(ct string) {
	d.content_type = ct
}

pub fn (d &Document) has_encoding() bool {
	return d.encoding != none
}

pub fn (d &Document) get_encoding() ?string {
	return d.encoding
}

pub fn (d &Document) encoding_or_default() string {
	return d.encoding or { 'UTF-8' }
}

pub fn (mut d Document) set_encoding(enc ?string) {
	d.encoding = enc
}

pub fn (d &Document) character_set() string {
	return d.encoding_or_default()
}

pub fn (d &Document) charset() string {
	return d.encoding_or_default()
}

pub fn (d &Document) input_encoding() string {
	return d.encoding_or_default()
}

// --- DOM Implementation ---
pub fn (mut d Document) implementation() &DOMImplementation {
	if d.implementation_ == unsafe { nil } {
		d.implementation_ = DOMImplementation.create(d)
	}
	return d.implementation_
}

// --- Scripting ---
pub fn (d &Document) current_script() ?&HTMLScriptElement {
	if d.current_script == unsafe { nil } {
		return none
	}
	return d.current_script
}

pub fn (mut d Document) set_pending_parsing_blocking_script(script &HTMLScriptElement) {
	d.pending_parsing_blocking_script = script
}

pub fn (d &Document) pending_parsing_blocking_script() ?&HTMLScriptElement {
	if d.pending_parsing_blocking_script == unsafe { nil } {
		return none
	}
	return d.pending_parsing_blocking_script
}

pub fn (mut d Document) set_pending_parsing_blocking_svg_script(script &SVGScriptElement) {
	d.pending_parsing_blocking_svg_script = script
}

pub fn (d &Document) pending_parsing_blocking_svg_script() ?&SVGScriptElement {
	if d.pending_parsing_blocking_svg_script == unsafe { nil } {
		return none
	}
	return d.pending_parsing_blocking_svg_script
}

pub fn (d &Document) has_pending_parsing_blocking_script() bool {
	return d.pending_parsing_blocking_script != unsafe { nil }
		|| d.pending_parsing_blocking_svg_script != unsafe { nil }
}

pub fn (mut d Document) add_script_to_execute_when_parsing_has_finished(script &HTMLScriptElement) {
	d.scripts_to_execute_when_parsing_has_finished << script
}

pub fn (mut d Document) add_script_to_execute_as_soon_as_possible(script &HTMLScriptElement) {
	d.scripts_to_execute_as_soon_as_possible << script
}

pub fn (mut d Document) add_script_to_execute_in_order_as_soon_as_possible(script &HTMLScriptElement) {
	d.scripts_to_execute_in_order_as_soon_as_possible << script
}

pub fn (d &Document) first_script_to_execute_when_parsing_has_finished() ?&HTMLScriptElement {
	if d.scripts_to_execute_when_parsing_has_finished.len == 0 {
		return none
	}
	return d.scripts_to_execute_when_parsing_has_finished[0]
}

pub fn (mut d Document) remove_first_script_to_execute_when_parsing_has_finished() {
	if d.scripts_to_execute_when_parsing_has_finished.len > 0 {
		d.scripts_to_execute_when_parsing_has_finished.delete(0)
	}
}

pub fn (d &Document) has_scripts_to_execute_as_soon_as_possible() bool {
	return d.scripts_to_execute_as_soon_as_possible.len > 0
		|| d.scripts_to_execute_in_order_as_soon_as_possible.len > 0
}

// --- Editable ---
pub fn (mut d Document) set_editable(editable bool) {
	d.editable = editable
}

// --- History ---
pub fn (mut d Document) history() &History {
	// Document::history() creates and retains the History object on first access.
	if d.history_ == unsafe { nil } {
		d.history_ = &History{}
	}
	return d.history_
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#dom-document-location
// C++: GC::Ptr<HTML::Location> Document::location()
// https://html.spec.whatwg.org/multipage/history.html#dom-document-location
pub fn (d &Document) location() ?&Location {
	// The Document object's location attribute's getter must return this Document object's
	// relevant global object's Location object, if this Document object is fully active,
	// and null otherwise.
	if !d.is_fully_active() {
		return none
	}
	if d.window == unsafe { nil } {
		return none
	}
	return d.window.location()
}

pub fn (d &Document) get_location() ?&Location {
	return d.location()
}

// --- Loading ---
pub fn (d &Document) anything_is_delaying_the_load_event() bool {
	if d.number_of_things_delaying_the_load_event > 0 {
		return true
	}

	for navigable in d.descendant_navigables() {
		container := navigable.container() or { continue }
		if container.currently_delays_the_load_event() {
			return true
		}
	}

	// FIXME: Track down anything else that is supposed to delay the load event.
	return false
}

pub fn (d &Document) has_pending_style_sheet_requests() bool {
	return d.number_of_pending_style_sheet_requests > 0 || d.pending_css_import_rules.len > 0
}

pub fn (mut d Document) increment_number_of_pending_style_sheet_requests() {
	d.number_of_pending_style_sheet_requests++
	d.request_frame()
}

pub fn (mut d Document) decrement_number_of_pending_style_sheet_requests() {
	assert d.number_of_pending_style_sheet_requests > 0
	d.number_of_pending_style_sheet_requests--
	d.request_frame()
}

pub fn (mut d Document) increment_number_of_things_delaying_the_load_event() {
	d.number_of_things_delaying_the_load_event++
	if d.page_ != unsafe { nil } {
		d.page_.client_page_did_update_resource_count(d.number_of_things_delaying_the_load_event)
	}
}

pub fn (mut d Document) decrement_number_of_things_delaying_the_load_event() {
	assert d.number_of_things_delaying_the_load_event > 0
	d.number_of_things_delaying_the_load_event--
	if d.page_ != unsafe { nil } {
		d.page_.client_page_did_update_resource_count(d.number_of_things_delaying_the_load_event)
	}
	d.schedule_html_parser_end_check()
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#completely-finish-loading
pub fn (mut d Document) completely_finish_loading() {
	// Population may complete before the new document is activated and gains a
	// navigable. Preserve that fact so activation can replay the container
	// notification steps without blocking history traversal.
	d.completely_loaded_time = true
	nav := d.navigable() or {
		d.completely_loaded_deferred = true
		return
	}
	d.completely_loaded_deferred = false

	// Notify document observers
	d.notify_each_document_observer_completely_loaded()

	// 1. Assert: document's browsing context is non-null.
	// 2. The completely loaded time was recorded above even when activation was
	// deferred.
	d.refresh_svg_use_shadow_trees()

	// NOTE: Start the active refresh timer if set.
	if d.active_refresh_timer != unsafe { nil } {
		d.active_refresh_timer.start()
	}

	// 3. Let container be document's browsing context's container.
	container := nav.container() or { return }

	// 4. If container is an iframe element, queue task to run iframe load event steps.
	// 5. Otherwise, if container is non-null, queue task to fire load event at container.
	if container.is_iframe_element() {
		// iframe load event steps
	} else {
		// fire load event at container
	}
	container.document().schedule_html_parser_end_check()
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#completely-loaded
pub fn (d &Document) is_completely_loaded() bool {
	return d.completely_loaded_time
}

pub fn (d &Document) document_completely_loaded_deferred() bool {
	return d.completely_loaded_deferred
}

// DOMContentLoaded and load fire once per document. The compact embedder fires
// them itself once its scripts have run, while the parser's end steps queue
// their own tasks; whichever runs first claims the event and the other skips it.
pub fn (mut d Document) claim_readiness_event(name string) bool {
	if name == 'DOMContentLoaded' {
		if d.pending_module_readiness_scripts > 0 { return false }
		if d.fired_dom_content_loaded {
			return false
		}
		d.fired_dom_content_loaded = true
		return true
	}
	if name == 'load' {
		if d.fired_load_event {
			return false
		}
		d.fired_load_event = true
		return true
	}
	return true
}

// --- Page showing / visibility ---
pub fn (mut d Document) set_page_showing(page_showing bool) {
	if d.page_showing == page_showing {
		return
	}
	d.page_showing = page_showing
	d.notify_each_document_observer_page_showing()
}

pub fn (d &Document) document_page_showing() bool {
	return d.page_showing
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hidden
pub fn (d &Document) hidden() bool {
	return d.visibility_state == .hidden
}

pub fn (d &Document) is_playing_audio() bool {
	if d.page_ == unsafe { nil } {
		return false
	}
	return d.page_.has_media_element_playing_audio(d)
}

pub fn (mut d Document) media_element_audio_play_state_changed(media_id UniqueNodeID, playing bool) {
	if d.page_ != unsafe { nil } {
		d.page_.media_element_audio_state_changed(d, media_id, playing)
	}
	d.audio_play_state_changed()
}

pub fn (mut d Document) audio_play_state_changed() {
	if hook := d.lifecycle_hook_ {
		d.run_lifecycle_callback(hook.timer_audio_play_state_changed)
	}
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-document-visibilitystate
// C++: StringView Document::visibility_state() const
pub fn (d &Document) visibility_state() string {
	return match d.visibility_state {
		.visible { 'visible' }
		.hidden { 'hidden' }
	}
}

pub fn (d &Document) visibility_state_string() string {
	return d.visibility_state()
}

pub fn (d &Document) visibility_state_value() VisibilityState {
	return d.visibility_state
}

// https://html.spec.whatwg.org/multipage/interaction.html#update-the-visibility-state
pub fn (mut d Document) update_the_visibility_state(state VisibilityState) {
	// 1. If document's visibility state equals visibilityState, then return.
	if d.visibility_state == state {
		return
	}
	// 2. Set document's visibility state to visibilityState.
	d.visibility_state = state

	// 5. Run the view transition page visibility change steps with document.
	d.view_transition_page_visibility_change_steps()

	// 6. Run any page visibility change steps defined in other specifications.
	d.notify_each_document_observer_visibility_state()
	if hook := d.lifecycle_hook_ {
		d.run_lifecycle_callback(hook.timer_visibility_state_changed)
	}

	// 7. Fire an event named visibilitychange at document, with its bubbles attribute initialized to true.
	d.dispatch_event_simple(event_visibilitychange_, true)
}

// https://html.spec.whatwg.org/multipage/interaction.html#set-the-initial-visibility-state
pub fn (mut d Document) set_initial_visibility_state(state VisibilityState) {
	// Initial visibility is installed without running the visibility-change steps.
	d.visibility_state = state
	if hook := d.lifecycle_hook_ {
		d.run_lifecycle_callback(hook.timer_visibility_state_changed)
	}
	// TODO: The pinned source still queues no initial VisibilityStateEntry.
	// Source AD-HOC: retain both initial snapshots before the first rendering
	// update, so an intervening viewport or scale change still fires resize.
	if d.last_viewport_size == none {
		viewport_size := d.current_layout_viewport_size_for_resize()
		d.last_viewport_size = [viewport_size[0], viewport_size[1]]!
		d.last_visual_viewport_state = d.current_visual_viewport_state()
	}
}

// --- Media queries ---

// https://drafts.csswg.org/cssom-view/#evaluate-media-queries-and-report-changes
pub fn (mut d Document) evaluate_media_queries_and_report_changes() {
	if !d.needs_media_query_evaluation {
		return
	}
	d.needs_media_query_evaluation = false

	// 1. For each MediaQueryList object target that has doc as its document,
	//    in the order they were created, oldest first, run these substeps:
	for mql in d.media_query_lists {
		if mql == unsafe { nil } {
			continue
		}
		did_match := mql.matches()
		now_matches := mql.evaluate()
		did_change_internally := mql.has_changed_state()
		mql.set_has_changed_state(false)
		if did_change_internally || did_match != now_matches {
			// Fire a change event at the MediaQueryList
			mql.dispatch_change_event(now_matches)
		}
	}
	// Also evaluate @media rules
	d.evaluate_media_rules()
}

pub fn (mut d Document) add_media_query_list(mql &MediaQueryList) {
	d.needs_media_query_evaluation = true
	d.media_query_lists << mql
}

// --- Resize / Scroll ---

// https://drafts.csswg.org/cssom-view/#document-run-the-resize-steps
pub fn (mut d Document) run_the_resize_steps() {
	// 1. If doc's viewport has had its width or height changed since the last time these steps were run,
	//    fire an event named resize at the Window object associated with doc.
	// 2. If its VisualViewport scale, width or height changed, fire resize at it.
	// Source viewport-size snapshots use CSSPixels::to_int(), while visual
	// viewport dimensions retain the source double-precision getter values.
	viewport_size := d.current_layout_viewport_size_for_resize()
	visual_state := d.current_visual_viewport_state()
	is_initial_size := d.last_viewport_size == none
	viewport_size_changed := if last := d.last_viewport_size {
		last[0] != viewport_size[0] || last[1] != viewport_size[1]
	} else {
		true
	}
	visual_state_changed := if current := visual_state {
		if last := d.last_visual_viewport_state { current != last } else { true }
	} else {
		false
	}

	if !viewport_size_changed && !visual_state_changed {
		return
	}
	d.last_viewport_size = [viewport_size[0], viewport_size[1]]!
	d.last_visual_viewport_state = visual_state

	if !is_initial_size {
		if viewport_size_changed {
			if window := d.get_window() {
				window.dispatch_event(d.create_resize_event())
			}
		}
		if visual_state_changed {
			viewport := d.visual_viewport()
			viewport.event_target().dispatch_event(d.create_resize_event())
		}
	}
}

fn (mut d Document) current_visual_viewport_state() ?VisualViewportState {
	if factory := document_visual_viewport_factory_ {
		_ = factory
		viewport := d.visual_viewport()
		return VisualViewportState{
			scale: viewport.scale()
			width: viewport.width()
			height: viewport.height()
		}
	}
	// Explicit preexisting DOM-only adapter: no concrete CSS viewport is
	// available. Keep its Window-only resize path rather than inventing data.
	return none
}

fn (mut d Document) current_layout_viewport_size_for_resize() [2]int {
	if factory := document_visual_viewport_factory_ {
		_ = factory
		// Retain CSSPixels::to_int() at the actual CSS-owned geometry boundary.
		return d.visual_viewport().layout_viewport_size_for_resize()
	}
	rect := d.viewport_rect()
	return [int(rect.width), int(rect.height)]!
}

fn (d &Document) create_resize_event() &Event {
	mut event := Event.create('resize', EventInit{})
	if window := d.get_window() {
		event.time_stamp_ = current_high_resolution_time(window)
	}
	return event
}

pub fn (mut d Document) append_pending_scroll_event(event PendingScrollEvent) bool {
	for pending in d.pending_scroll_events {
		if pending.type_ == event.type_ && pending.target_identity() == event.target_identity() {
			return false
		}
	}
	d.pending_scroll_events << event
	return true
}

// https://drafts.csswg.org/cssom-view-1/#document-run-the-scroll-steps
pub fn (mut d Document) run_the_scroll_steps() {
	// Process pending scroll events
	pending_scroll_events := d.pending_scroll_events.clone()
	d.pending_scroll_events.clear()
	for pse in pending_scroll_events {
		if mut event_target := pse.event_target {
			mut event := Event.create(pse.type_, EventInit{})
			event_target.dispatch_event(event)
			continue
		}
		if pse.target != unsafe { nil } {
			pse.target.dispatch_event_simple(pse.type_, pse.bubbles
				|| (pse.target.is_document() && pse.type_ in ['scroll', 'scrollend']))
		}
	}
}

// --- Focus state ---

// https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hasfocus
pub fn (d &Document) has_focus_for_bindings() bool {
	// The hasFocus() method steps are to return the result of running the has focus steps given this.
	return d.has_focus()
}

// https://html.spec.whatwg.org/multipage/interaction.html#has-focus-steps
pub fn (d &Document) has_focus() bool {
	// 1. If target's node navigable's top-level traversable does not have system focus, return false.
	nav := d.navigable() or { return false }
	traversable := nav.traversable_navigable() or { return false }
	if !traversable.is_focused() {
		return false
	}
	// 2. Let candidate be target's node navigable's top-level traversable's active document.
	mut candidate := traversable.active_document() or { return false }
	// 3. While true:
	for {
		// 3.1. If candidate is target, then return true.
		if voidptr(candidate) == voidptr(d) {
			return true
		}
		// 3.2. If the focused area of candidate is a navigable container with a non-null content navigable,
		//      set candidate to active document of that content navigable.
		focused := candidate.focused_area
		if focused == unsafe { nil } {
			return false
		}
		nc := as_navigable_container(focused) or { return false }
		content_nav := nc.content_navigable() or { return false }
		candidate = content_nav.active_document() or { return false }
	}
	return false
}

// https://html.spec.whatwg.org/multipage/interaction.html#allow-focus-steps
pub fn (d &Document) allow_focus() bool {
	// 1. If target is allowed to use "focus-without-user-activation", return true.
	if d.is_allowed_to_use_feature(.focus_without_user_activation) {
		return true
	}
	// 2. If target's relevant global object has transient activation, return true.
	if d.window != unsafe { nil } && d.window.has_transient_activation() {
		return true
	}
	// 3. Return false.
	return false
}

// --- Parser management ---
pub fn (mut d Document) set_parser(parser &HTMLParser) {
	d.parser = parser
}

pub fn (mut d Document) set_html_parser_end_state(target voidptr, schedule_callback HTMLParserEndStateScheduleCallback) {
	d.html_parser_end_state_target = target
	d.html_parser_end_state_schedule_callback = schedule_callback
}

pub fn (mut d Document) clear_html_parser_end_state(target voidptr) {
	if d.html_parser_end_state_target != target {
		return
	}
	d.html_parser_end_state_target = unsafe { nil }
	d.html_parser_end_state_schedule_callback = unsafe { nil }
}

pub fn (d &Document) has_html_parser_end_state() bool {
	return d.html_parser_end_state_target != unsafe { nil }
}

pub fn (d &Document) html_parser_end_state() voidptr {
	return d.html_parser_end_state_target
}

pub fn (d &Document) schedule_html_parser_end_check() {
	if d.html_parser_end_state_target != unsafe { nil }
		&& d.html_parser_end_state_schedule_callback != unsafe { nil } {
		d.html_parser_end_state_schedule_callback(d.html_parser_end_state_target)
	}
	if d.parser != unsafe { nil } && d.parser.schedule_resume_check_callback != unsafe { nil } {
		d.parser.schedule_resume_check_callback(d.parser.target)
	}
}

pub fn (mut d Document) detach_parser() {
	d.parser = unsafe { nil }
	d.active_parser_was_aborted = true
}

// https://html.spec.whatwg.org/multipage/dom.html#active-parser
pub fn (d &Document) active_parser() ?&HTMLParser {
	if d.parser == unsafe { nil } {
		return none
	}
	return d.parser
}

pub fn (d &Document) is_temporary_document_for_fragment_parsing() bool {
	return d.temporary_document_for_fragment_parsing == .yes
}

// --- Node iterators / tree walkers ---

// https://dom.spec.whatwg.org/#dom-document-createnodeiterator
pub fn (d &Document) create_node_iterator(root &Node, what_to_show u32, filter ?&NodeFilter) &NodeIterator {
	return NodeIterator.create(root, what_to_show, filter)
}

// https://dom.spec.whatwg.org/#dom-document-createtreewalker
pub fn (d &Document) create_tree_walker(root &Node, what_to_show u32, filter ?&NodeFilter) &TreeWalker {
	return TreeWalker.create(root, what_to_show, filter)
}

pub fn (mut d Document) register_node_iterator(node_iterator &NodeIterator) {
	if node_iterator in d.node_iterators {
		return
	}
	d.node_iterators << node_iterator
}

pub fn (mut d Document) unregister_node_iterator(node_iterator &NodeIterator) {
	d.node_iterators = d.node_iterators.filter(it != node_iterator)
}

// --- Document observers ---
pub fn (mut d Document) register_document_observer(observer &DocumentObserver) {
	for existing in d.document_observers {
		if existing == observer {
			return
		}
	}
	d.document_observers << observer
}

pub fn (mut d Document) unregister_document_observer(observer &DocumentObserver) {
	d.document_observers = d.document_observers.filter(it != observer)
}

// --- Style update flags ---
pub fn (d &Document) needs_full_style_update() bool {
	return d.needs_full_style_update
}

pub fn (d &Document) style_invalidation_counters() StyleInvalidationCounters {
	return d.style_invalidation_counters_
}

pub fn (d &Document) style_environment_version() u64 {
	return d.style_environment_version_
}

pub fn (mut d Document) bump_style_environment_version() {
	d.style_environment_version_++
}

pub fn (mut d Document) record_full_style_invalidation() {
	d.style_invalidation_counters_.full_style_invalidations++
}

pub fn (mut d Document) record_style_invalidation() {
	d.style_invalidation_counters_.style_invalidations++
}

pub fn (mut d Document) record_element_style_recomputation() {
	d.style_invalidation_counters_.element_style_recomputations++
}

pub fn (mut d Document) record_element_style_noop_recomputation() {
	d.style_invalidation_counters_.element_style_noop_recomputations++
}

pub fn (mut d Document) record_element_inherited_style_recomputation() {
	d.style_invalidation_counters_.element_inherited_style_recomputations++
}

pub fn (mut d Document) record_element_inherited_style_noop_recomputation() {
	d.style_invalidation_counters_.element_inherited_style_noop_recomputations++
}

pub fn (mut d Document) record_previous_sibling_invalidation_walk_visit() {
	d.style_invalidation_counters_.previous_sibling_invalidation_walk_visits++
}

pub fn (mut d Document) record_style_query_container_scan() {
	d.style_invalidation_counters_.style_query_container_scans++
}

pub fn (mut d Document) record_size_query_container_scan_visit() {
	d.style_invalidation_counters_.size_query_container_scan_visits++
}

pub fn (mut d Document) record_has_ancestor_walk_invocation() {
	d.style_invalidation_counters_.has_ancestor_walk_invocations++
}

pub fn (mut d Document) record_has_ancestor_walk_visit() {
	d.style_invalidation_counters_.has_ancestor_walk_visits++
}

pub fn (mut d Document) record_has_ancestor_sibling_element_check() {
	d.style_invalidation_counters_.has_ancestor_sibling_element_checks++
}

pub fn (mut d Document) reset_style_invalidation_counters() {
	d.style_invalidation_counters_ = StyleInvalidationCounters{}
}

pub fn (mut d Document) set_needs_full_style_update(b bool) {
	d.needs_full_style_update = b
}

pub fn (d &Document) needs_full_layout_tree_update() bool {
	return d.needs_full_layout_tree_update
}

pub fn (mut d Document) set_needs_full_layout_tree_update(b bool) {
	d.needs_full_layout_tree_update = b
}

pub fn (mut d Document) set_needs_animated_style_update() {
	if d.needs_animated_style_update {
		return
	}
	d.needs_animated_style_update = true
	d.request_frame()
}

pub fn (mut d Document) invalidate_scroll_state() {
	// Propagate scroll state invalidation to its retained painting owner.
	if paintable := d.unsafe_paintable() {
		paintable.invalidate_scroll_state()
	}
}

// --- Collections ---

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-getelementsbyname
pub fn (d &Document) get_elements_by_name(name string) &NodeList {
	return LiveNodeList.create(unsafe { &Node(d) }, .descendants, fn [name] (node &Node) bool {
		element := node.as_element() or { return false }
		if element.namespace_uri() or { '' } != namespace_html_ {
			return false
		}
		if attr := element.get_attribute('name') {
			return attr == name
		}
		return false
	})
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-applets
pub fn (mut d Document) applets() &HTMLCollection {
	if d.applets_ == unsafe { nil } {
		d.applets_ = HTMLCollection.create(unsafe { &ParentNode(&d) }, .descendants, fn (element &Element) bool {
			_ = element
			return false
		}, never_sort_elements)
	}
	return d.applets_
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-anchors
pub fn (mut d Document) anchors() &HTMLCollection {
	if d.anchors_ == unsafe { nil } {
		d.anchors_ = HTMLCollection.create(unsafe { &ParentNode(&d) }, .descendants, fn (element &Element) bool {
			return is_html_element_with_local_name(element, 'a') && element.has_attribute('name')
		}, never_sort_elements)
	}
	return d.anchors_
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-images
pub fn (mut d Document) images() &HTMLCollection {
	if d.images_ == unsafe { nil } {
		d.images_ = HTMLCollection.create(unsafe { &ParentNode(&d) }, .descendants, fn (element &Element) bool {
			return is_html_element_with_local_name(element, 'img')
		}, never_sort_elements)
	}
	return d.images_
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-embeds
pub fn (mut d Document) embeds() &HTMLCollection {
	if d.embeds_ == unsafe { nil } {
		d.embeds_ = HTMLCollection.create(unsafe { &ParentNode(&d) }, .descendants, fn (element &Element) bool {
			return is_html_element_with_local_name(element, 'embed')
		}, never_sort_elements)
	}
	return d.embeds_
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-plugins
pub fn (mut d Document) plugins() &HTMLCollection {
	return d.embeds()
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-links
pub fn (mut d Document) links() &HTMLCollection {
	if d.links_ == unsafe { nil } {
		d.links_ = HTMLCollection.create(unsafe { &ParentNode(&d) }, .descendants, fn (element &Element) bool {
			return (is_html_element_with_local_name(element, 'a') || is_html_element_with_local_name(element, 'area')) && element.has_attribute('href')
		}, never_sort_elements)
	}
	return d.links_
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-forms
pub fn (mut d Document) forms() &HTMLCollection {
	if d.forms_ == unsafe { nil } {
		d.forms_ = HTMLCollection.create(unsafe { &ParentNode(&d) }, .descendants, fn (element &Element) bool {
			return is_html_element_with_local_name(element, 'form')
		}, never_sort_elements)
	}
	return d.forms_
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-scripts
pub fn (mut d Document) scripts() &HTMLCollection {
	if d.scripts_ == unsafe { nil } {
		d.scripts_ = HTMLCollection.create(unsafe { &ParentNode(&d) }, .descendants, fn (element &Element) bool {
			return is_html_element_with_local_name(element, 'script')
		}, never_sort_elements)
	}
	return d.scripts_
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-all
pub fn (mut d Document) all() &HTMLAllCollection {
	if d.all_ == unsafe { nil } {
		d.all_ = HTMLAllCollection.create(unsafe { &ParentNode(&d) }, .descendants, always_accept_element)
	}
	return d.all_
}

// https://drafts.csswg.org/css-font-loading/#font-source
pub fn (mut d Document) fonts() FontFaceSet {
	if fonts := d.fonts_ {
		return fonts
	}
	if factory := document_font_face_set_factory_ {
		fonts := factory(&d)
		d.fonts_ = fonts
		return fonts
	}
	panic('Document.fonts requires the CSS FontFaceSet implementation')
}

pub fn (d &Document) existing_font_face_set() ?FontFaceSet {
	return d.fonts_
}

pub fn (mut d Document) set_font_face_set(fonts FontFaceSet) {
	if existing := d.fonts_ {
		assert existing.font_face_set_record() == fonts.font_face_set_record()
		return
	}
	d.fonts_ = fonts
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-clear
pub fn (mut d Document) clear() {
	// This obsolete operation intentionally performs no steps.
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-captureevents
pub fn (d &Document) capture_events() {
	// This obsolete operation intentionally performs no steps.
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-releaseevents
pub fn (d &Document) release_events() {
	// This obsolete operation intentionally performs no steps.
}

// --- Style sheets ---
pub fn (mut d Document) style_sheets() &StyleSheetList {
	if d.style_sheets_ == unsafe { nil } {
		d.style_sheets_ = &StyleSheetList{}
	}
	return d.style_sheets_
}

pub fn (mut d Document) for_each_active_css_style_sheet(callback fn (&CSSStyleSheet)) {
	if d.style_sheets_ != unsafe { nil } {
		for style_sheet in d.style_sheets_.sheets {
			if !(style_sheet.is_alternate && style_sheet.disabled) {
				callback(style_sheet)
			}
		}
	}
	// Also iterate adopted style sheets
	for style_sheet in d.adopted_style_sheets {
		if !style_sheet.disabled {
			callback(style_sheet)
		}
	}
}

// --- Referrer ---

// C++: String Document::referrer() const
pub fn (d &Document) referrer() string {
	return d.referrer
}

pub fn (d &Document) get_referrer() string {
	return d.referrer
}

pub fn (mut d Document) set_referrer(r string) {
	d.referrer = r
}

// --- Active state ---

// https://html.spec.whatwg.org/multipage/document-sequences.html#fully-active
pub fn (d &Document) is_fully_active() bool {
	// A Document d is said to be fully active when d is the active document of a navigable navigable,
	// and either navigable is a top-level traversable or navigable's parent has a fully active document.
	nav := d.navigable() or { return false }

	if nav.is_top_level_traversable() {
		return true
	}

	// The parent navigable's active document is the container document. Asking
	// the logical parent keeps this check valid when that parent is represented
	// by replicated state rather than a local container document.
	parent := nav.parent() or { return false }
	return parent.active_document_is_fully_active()
}

pub fn (d &Document) is_active() bool {
	navigable := d.navigable() or { return false }
	return navigable.active_document_is(d)
}

pub fn (d &Document) script_blocking_style_sheet_set_contains(element &Element) bool {
	for entry in d.script_blocking_style_sheet_set {
		if voidptr(entry) == voidptr(element) {
			return true
		}
	}
	return false
}

pub fn (mut d Document) append_to_script_blocking_style_sheet_set(element &Element) {
	if !d.script_blocking_style_sheet_set_contains(element) {
		d.script_blocking_style_sheet_set << element
	}
}

pub fn (mut d Document) remove_from_script_blocking_style_sheet_set(element &Element) {
	// NB: Removing from the set can unblock this document's parser or parser end state, both of which wait for the
	//     set to become empty. Always schedule the wake-up here so no removal site can forget it.
	d.script_blocking_style_sheet_set = d.script_blocking_style_sheet_set.filter(voidptr(it) != voidptr(element))
	d.schedule_html_parser_end_check()
}

// https://html.spec.whatwg.org/multipage/semantics.html#has-a-style-sheet-that-is-blocking-scripts
pub fn (d &Document) has_a_style_sheet_that_is_blocking_scripts() bool {
	return d.script_blocking_style_sheet_set.len > 0 || d.pending_css_import_rules.len > 0
}

// https://html.spec.whatwg.org/multipage/semantics.html#has-no-style-sheet-that-is-blocking-scripts
pub fn (d &Document) has_no_style_sheet_that_is_blocking_scripts() bool {
	return !d.has_a_style_sheet_that_is_blocking_scripts()
}

// --- Domain ---

// https://html.spec.whatwg.org/multipage/origin.html#dom-document-domain
pub fn (d &Document) domain() string {
	// 1. Let effectiveDomain be this's origin's effective domain.
	// 2. If effectiveDomain is null, return the empty string.
	effective_domain := d.origin_.effective_domain() or {
		return ''
	}
	// 3. Return effectiveDomain, serialized.
	return effective_domain
}

// https://html.spec.whatwg.org/multipage/browsers.html#dom-document-domain
pub fn (mut d Document) set_domain(value string) ! {
	// 1. If this's browsing context is null, throw a SecurityError.
	if d.browsing_context == unsafe { nil } {
		return error('SecurityError: Document.domain setter requires a browsing context')
	}
	// 2. If sandboxed document.domain flag is set, throw SecurityError.
	if d.active_sandboxing_flag_set.sandboxed_document_domain {
		return error('SecurityError: Document.domain setter is sandboxed')
	}
	// 3. Let effectiveDomain be this's origin's effective domain.
	// 4. If effectiveDomain is null, throw SecurityError.
	effective_domain := d.origin_.effective_domain() or {
		return error('SecurityError: Document.domain setter called on a Document with a null effective domain')
	}
	// 5. If given value is not a registrable domain suffix of or equal to effectiveDomain, throw SecurityError.
	if !is_a_registrable_domain_suffix_of_or_is_equal_to(value, effective_domain) {
		return error('SecurityError: Document.domain setter called for an invalid domain')
	}
}

// --- Sandboxing & Policy ---
pub fn (d &Document) active_sandboxing_flag_set() SandboxingFlagSet {
	return d.active_sandboxing_flag_set
}

pub fn (mut d Document) set_active_sandboxing_flag_set(flags SandboxingFlagSet) {
	d.active_sandboxing_flag_set = flags
}

// Cycle-safe HTML::SandboxingFlagSet representation used by the HTML bridge.
pub fn (d &Document) active_sandboxing_flag_bits() u32 {
	mut bits := d.active_sandboxing_flag_set.bits
	if d.active_sandboxing_flag_set.sandboxed_forms {
		bits |= u32(64)
	}
	if d.active_sandboxing_flag_set.sandboxed_document_domain {
		bits |= u32(1024)
	}
	return bits
}

pub fn (mut d Document) set_active_sandboxing_flag_bits(bits u32) {
	d.active_sandboxing_flag_set = SandboxingFlagSet{
		bits: bits
		sandboxed_forms: bits & u32(64) != 0
		sandboxed_document_domain: bits & u32(1024) != 0
	}
}

// Document.cpp:5508–5518 retains its lazily allocated actual container.
pub fn (d &Document) policy_container() &PolicyContainer {
	if d.policy_container_ == unsafe { nil } {
		mut mutable_document := unsafe { &Document(d) }
		mutable_document.policy_container_ = &PolicyContainer{}
	}
	return d.policy_container_
}

pub fn (mut d Document) set_policy_container(pc &PolicyContainer) {
	d.policy_container_ = pc
}

// --- Navigation ---
pub fn (d &Document) get_navigation_id() ?string {
	return d.navigation_id
}

pub fn (mut d Document) set_navigation_id(id ?string) {
	d.navigation_id = id
}

// --- Navigables ---

// https://html.spec.whatwg.org/multipage/document-sequences.html#descendant-navigables
pub fn (d &Document) descendant_navigables() []&Navigable {
	if !retain_descendant_navigable_scan && !d.may_have_registered_navigable_container() {
		report_empty_descendant_navigables(d)
		return []&Navigable{}
	}
	return d.collect_descendant_navigables()
}

fn (d &Document) collect_descendant_navigables() []&Navigable {
	// 1. Let navigables be new list.
	mut navigables := []&Navigable{}
	navigables_ptr := &navigables
	// 2-3. For each shadow-including descendant that is a navigable container:
	d.visit_shadow_including_descendants(fn [navigables_ptr] (node &Node) TraversalDecision {
		nc := as_navigable_container(node) or { return .@continue }
		content_nav := nc.content_navigable() or { return .@continue }
		active_doc := content_nav.active_document() or { return .@continue }
		// Extend navigables with active document's inclusive descendant navigables.
		unsafe {
			mut a := *navigables_ptr
			a << active_doc.inclusive_descendant_navigables()
			*navigables_ptr = a
		}
		return .@continue
	})
	// 4. Return navigables.
	return navigables
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#inclusive-descendant-navigables
pub fn (d &Document) inclusive_descendant_navigables() []&Navigable {
	document_node_navigable := d.navigable() or { return [] }
	// 1. Let navigables be « document's node navigable ».
	mut navigables := [document_node_navigable]
	// 2. Extend navigables with document's descendant navigables.
	navigables << d.descendant_navigables()
	// 3. Return navigables.
	return navigables
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#ancestor-navigables
pub fn (d &Document) ancestor_navigables() []&Navigable {
	document_node_navigable := d.navigable() or { return [] }
	// 1. Let navigable be document's node navigable's parent.
	mut current := document_node_navigable.parent() or { return [] }
	// 2. Let ancestors be an empty list.
	mut ancestors := []&Navigable{}
	// 3. While navigable is not null:
	for {
		// 1. Prepend navigable to ancestors.
		ancestors.prepend(current)
		// 2. Set navigable to navigable's parent.
		current = current.parent() or { break }
	}
	// 4. Return ancestors.
	return ancestors
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#inclusive-ancestor-navigables
pub fn (d &Document) inclusive_ancestor_navigables() []&Navigable {
	document_node_navigable := d.navigable() or { return [] }
	// 1. Let navigables be document's ancestor navigables.
	mut navigables := d.ancestor_navigables()
	// 2. Append document's node navigable to navigables.
	navigables << document_node_navigable
	// 3. Return navigables.
	return navigables
}

// https://html.spec.whatwg.org/multipage/document-sequences.html#document-tree-child-navigables
pub fn (d &Document) document_tree_child_navigables() []&Navigable {
	// 1. If document's node navigable is null, return the empty list.
	_ = d.navigable() or { return [] }
	// 2. Let navigables be new list.
	mut navigables := []&Navigable{}
	// 3-4. Iterate all registered navigables.
	for nav in all_navigables() {
		container := nav.container() or { continue }
		if !d.is_ancestor_of(container) {
			continue
		}
		mut insertion_index := navigables.len
		for index, existing_navigable in navigables {
			existing_container := existing_navigable.container() or { continue }
			if (container.compare_document_position(existing_container) & document_position_following) != 0 {
				insertion_index = index
				break
			}
		}
		navigables.insert(insertion_index, nav)
	}
	// 5. Return navigables.
	return navigables
}

// --- Document lifecycle ---
pub fn (d &Document) has_been_destroyed() bool {
	return d.has_been_destroyed
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#destroy-a-document
pub fn (mut d Document) destroy() {
	// 2. Abort document.
	d.abort()

	// Notify document observers that this document became inactive.
	if !d.has_fired_document_became_inactive {
		d.has_fired_document_became_inactive = true
		d.notify_each_document_observer_became_inactive()
	}

	// 3. Set document's salvageable state to false.
	d.salvageable = false

	// 4-5. Disentangle MessagePorts associated with this document.
	// Would disentangle MessagePorts associated with this document

	// 6. Run any unloading document cleanup steps.
	d.run_unloading_cleanup_steps()

	d.clear_layout_and_paintable_nodes_for_inactive_document()
	d.tear_down_layout_tree()

	$if vox_document_retention_diagnostics ? {
	teardown_value := C.getenv(c'VOX_TRACE_TEARDOWN')
	teardown := if teardown_value != unsafe { nil } { unsafe { cstring_to_vstring(teardown_value) }.int() } else { 0 }
	if teardown >= 1 {
		d.layout_engine_handle_ = unsafe { nil }
		d.cached_display_list_ = unsafe { nil }
	}
	if teardown >= 2 {
		mut pending := [unsafe { &Node(d) }]
		mut all := []&Node{}
		for pending.len > 0 {
			node := pending.pop()
			all << node
			if element := node.as_element() {
				if shadow_root := element.shadow_root() {
					pending << unsafe { &Node(shadow_root) }
				}
			}
			for child in node.children {
				pending << child
			}
		}
		for node in all {
			mut detached := unsafe { &Node(node) }
			detached.children = []&Node{}
			detached.parent_ = unsafe { nil }
			detached.index_in_parent_ = -1
			detached.child_nodes_ = unsafe { nil }
			detached.clear_registered_observers()
		}
	}
	if teardown >= 3 {
		d.element_by_id_map_ = unsafe { nil }
		d.style_sheets_ = unsafe { nil }
		d.shadow_roots = []
		d.potentially_named_elements = []
		d.selector_query_cache = map[string]?SelectorList{}
		d.list_of_available_images = unsafe { nil }
		d.shared_resource_requests_ = map[string]&SharedResourceRequest{}
		d.preloaded_resource_entries_ = map[string]voidptr{}
		d.applets_ = unsafe { nil }
		d.anchors_ = unsafe { nil }
		d.images_ = unsafe { nil }
		d.embeds_ = unsafe { nil }
		d.links_ = unsafe { nil }
		d.forms_ = unsafe { nil }
		d.scripts_ = unsafe { nil }
		d.all_ = unsafe { nil }
		d.parser = unsafe { nil }
		d.style_invalidator_ = unsafe { nil }
		d.adopted_style_sheets = []
		d.media_query_lists = []
		d.form_associated_elements_with_form_attribute = []
		d.render_blocking_elements = []
		d.script_blocking_style_sheet_set = []
		d.style_computer = unsafe { nil }
		d.font_computer = unsafe { nil }
		d.hovered_node = unsafe { nil }
		d.focused_area = unsafe { nil }
		d.active_element_ = unsafe { nil }
		d.selection_ = unsafe { nil }
		d.editing_host_manager_ = unsafe { nil }
	}

	}

	// 7. Remove any tasks whose document is document from any task queue.
	d.remove_tasks_for_document()

	// Mark this document as destroyed.
	d.has_been_destroyed = true
	// ResizeObserver holds its document weakly upstream. Tell each observer to
	// release its activity root before dropping the document-side weak list.
	for observer in d.resize_observers {
		if observer.document_was_destroyed != unsafe { nil } {
			observer.document_was_destroyed(observer.target)
		}
	}
	d.resize_observers.clear()

	// 8. Set document's browsing context to null.
	d.browsing_context = unsafe { nil }

	// 9. Set document's node navigable's active session history entry's document state's document to null.
	if nav := d.navigable() {
		mut mutable_navigable := unsafe { &Navigable(nav) }
		if mutable_navigable.active_document_is(&d) {
			mutable_navigable.set_active_document(none)
		}
	}

}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#abort-a-document
pub fn (mut d Document) abort() {
	// 3. If document's during-loading navigation ID for WebDriver BiDi is non-null:
	if d.navigation_id != none {
		// 2. Set document's during-loading navigation ID to null.
		d.navigation_id = none
	}

	// 4. If document has an active parser, then:
	if d.parser != unsafe { nil } {
		// 1. Set document's active parser was aborted to true.
		d.active_parser_was_aborted = true
		// 2. Abort that parser.
		d.parser.abort()
		// 3. Make document unsalvageable given document and "parser-aborted".
		d.make_unsalvageable('parser-aborted')
	}
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#unload-a-document
pub fn (mut d Document) unload() {
	d.unload_with_replacement(none)
}

// unload_with_replacement retains the optional new Document argument from the
// upstream algorithm while keeping unload() convenient for close operations.
pub fn (mut d Document) unload_with_replacement(new_document ?&Document) {
	mut unload_timing_info := ?DocumentUnloadTimingInfo(DocumentUnloadTimingInfo{})
	if new_document == none {
		unload_timing_info = none
	}

	// 5. Let intendToStoreInBfcache be false (simplification).

	// 7. Increase eventLoop's termination nesting level by 1.
	d.increment_termination_nesting_level()

	// 8. Increase document's unload counter by 1.
	d.unload_counter++

	// 9. Set document's salvageable state to false.
	d.salvageable = false

	// 10. If document's page showing is true:
	if d.page_showing {
		// 1. Set document's page showing to false.
		d.page_showing = false

		// 2. Fire a page transition event named pagehide.
		if d.window != unsafe { nil } {
			d.window.fire_a_page_transition_event(event_pagehide_, d.salvageable)
		}

		// 3. Update the visibility state of document to "hidden".
		d.update_the_visibility_state(.hidden)
	}

	// 12. If document's salvageable state is false, fire an event named unload.
	if !d.salvageable {
		if replacement := new_document {
			mut timing := unload_timing_info or { DocumentUnloadTimingInfo{} }
			timing.unload_event_start_time = current_high_resolution_time(relevant_global_object_for_doc(replacement))
			unload_timing_info = timing
		}
		// then fire an event named unload at document's relevant global object, with legacy target override flag set.
		if d.window != unsafe { nil } {
			event := Event.create(event_unload_, EventInit{})
			EventDispatcher.dispatch(unsafe { &EventTarget(d.window) }, event, true)
		}
		if replacement := new_document {
			mut timing := unload_timing_info or { DocumentUnloadTimingInfo{} }
			timing.unload_event_end_time = current_high_resolution_time(relevant_global_object_for_doc(replacement))
			unload_timing_info = timing
		}
	}

	// 14. Decrease eventLoop's termination nesting level by 1.
	d.decrement_termination_nesting_level()

	// 18. Run any unloading document cleanup steps defined by HTML and other
	// applicable specifications before deciding whether to destroy the document.
	d.run_unloading_cleanup_steps()

	// 19. If document's salvageable state is false, then destroy document.
	if !d.salvageable {
		d.destroy()
	}

	// 20. Decrease document's unload counter by 1.
	d.unload_counter--

	// Expose the previous document's unload interval only to a same-origin
	// replacement whose navigation did not pass through cross-origin redirects.
	if replacement := new_document {
		if !replacement.was_created_via_cross_origin_redirects
			&& replacement.origin().is_same_origin(d.origin()) {
			if timing := unload_timing_info {
				mut mutable_replacement := unsafe { &Document(replacement) }
				mutable_replacement.previous_document_unload_timing = timing
			}
		}
	}

	d.did_stop_being_active_document_in_navigable()
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#make-active
pub fn (mut d Document) make_active() {
	// 1. Let window be document's relevant global object.
	w := relevant_global_object_for_doc(d)
	d.set_window(w)

	// 2. Set document's browsing context's WindowProxy's [[Window]] internal slot value to window.
	if d.browsing_context != unsafe { nil } {
		d.browsing_context.window_proxy().set_window(w)
	}

	// 3. Set window's relevant settings object's execution ready flag.
	d.set_relevant_settings_object_execution_ready()

	d.notify_each_document_observer_became_active()
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#make-document-unsalvageable
pub fn (mut d Document) make_unsalvageable(reason string) {
	_ = reason
	// 3. Set document's salvageable state to false.
	d.salvageable = false
}

// --- Layout nodes ---
pub fn (d &Document) layout_node() ?&LayoutViewport {
	if d.layout_root == unsafe { nil } {
		return none
	}
	return d.layout_root
}

pub fn (d &Document) unsafe_layout_node() ?&LayoutViewport {
	if d.layout_root == unsafe { nil } {
		return none
	}
	return d.layout_root
}

pub fn (d &Document) paintable() ?&ViewportPaintable {
	if d.paintable_ == unsafe { nil } {
		return none
	}
	return d.paintable_
}

pub fn (d &Document) unsafe_paintable() ?&ViewportPaintable {
	if d.paintable_ == unsafe { nil } {
		return none
	}
	return d.paintable_
}

pub fn (mut d Document) set_viewport_paintable(paintable ?&ViewportPaintable) {
	d.paintable_ = paintable or { unsafe { nil } }
}

pub fn (mut d Document) set_layout_viewport(viewport ?&LayoutViewport) {
	d.layout_root = viewport or { unsafe { nil } }
}

// --- Inspection ---
pub fn (mut d Document) set_inspected_node(node ?&Node) {
	d.inspected_node = node or { unsafe { nil } }
}

pub fn (d &Document) get_inspected_node() ?&Node {
	if d.inspected_node == unsafe { nil } {
		return none
	}
	return d.inspected_node
}

fn optional_pseudo_elements_equal(left ?PseudoElement, right ?PseudoElement) bool {
	if left_value := left {
		if right_value := right {
			return left_value == right_value
		}
		return false
	}
	if _ := right {
		return false
	}
	return true
}

pub fn (mut d Document) set_highlighted_node(node ?&Node, pseudo ?PseudoElement) {
	new_node := node or { unsafe { nil } }
	if voidptr(d.highlighted_node) == voidptr(new_node)
		&& optional_pseudo_elements_equal(d.highlighted_pseudo_element, pseudo) {
		return
	}
	d.highlighted_node = new_node
	d.highlighted_pseudo_element = pseudo
	// The retained compatibility display list owns the inspector overlay outside
	// individual phase caches, so invalidating its assembled list covers both
	// the old and new highlighted paintables.
	d.set_needs_repaint_with_invalidation(.paint_commands)
}

pub fn (d &Document) get_highlighted_node() ?&Node {
	if d.highlighted_node == unsafe { nil } {
		return none
	}
	return d.highlighted_node
}

pub fn (mut d Document) set_hovered_node(node ?&Node) {
	d.set_hovered_node_with_data(node, none)
}

pub fn (d &Document) get_hovered_node() ?&Node {
	if d.hovered_node == unsafe { nil } {
		return none
	}
	return d.hovered_node
}

// --- Exec command ---
// Editing/ExecCommand.cpp defines these Document methods. The algorithms live in the editing package, which imports
// DOM; the installed editing command hook connects the two without a package cycle.
pub fn (mut d Document) exec_command(command string, show_ui bool, value string) !bool {
	return d.exec_command_internal(command, show_ui, value, '')
}

// An empty user input type means the command does not run on behalf of a user action.
pub fn (mut d Document) exec_command_internal(command string, show_ui bool, value string, user_input_type string) !bool {
	hook := d.editing_command_hook_ or {
		if !d.is_html_document() {
			return error('InvalidStateError: execCommand is only supported on HTML documents')
		}
		return false
	}
	return hook.exec_command(hook.target, d, command, show_ui, value, user_input_type)!
}

pub fn (d &Document) query_command_enabled(command string) !bool {
	hook := d.editing_command_hook_ or {
		if !d.is_html_document() {
			return error('InvalidStateError: queryCommandEnabled is only supported on HTML documents')
		}
		return false
	}
	return hook.query_command_enabled(hook.target, d, command)!
}

pub fn (d &Document) query_command_indeterm(command string) !bool {
	hook := d.editing_command_hook_ or {
		if !d.is_html_document() {
			return error('InvalidStateError: queryCommandIndeterm is only supported on HTML documents')
		}
		return false
	}
	return hook.query_command_indeterm(hook.target, d, command)!
}

pub fn (d &Document) query_command_state(command string) !bool {
	hook := d.editing_command_hook_ or {
		if !d.is_html_document() {
			return error('InvalidStateError: queryCommandState is only supported on HTML documents')
		}
		return false
	}
	return hook.query_command_state(hook.target, d, command)!
}

pub fn (d &Document) query_command_supported(command string) !bool {
	hook := d.editing_command_hook_ or {
		if !d.is_html_document() {
			return error('InvalidStateError: queryCommandSupported is only supported on HTML documents')
		}
		return false
	}
	return hook.query_command_supported(hook.target, d, command)!
}

pub fn (d &Document) query_command_value(command string) !string {
	hook := d.editing_command_hook_ or {
		if !d.is_html_document() {
			return error('InvalidStateError: queryCommandValue is only supported on HTML documents')
		}
		return ''
	}
	return hook.query_command_value(hook.target, d, command)!
}

// --- XPath (XPathEvaluatorBase, through the XPath package bridge) ---
pub fn (d &Document) create_expression(expression string, resolver ?&XPathNSResolver) !&XPathExpression {
	return xpath_create_expression(expression, resolver)
}

// https://dom.spec.whatwg.org/#dom-xpathevaluatorbase-evaluate
// C++: WebIDL::ExceptionOr<GC::Ref<XPath::XPathResult>> Document::evaluate(...)
pub fn (d &Document) evaluate(expression string, context_node &Node, resolver ?&XPathNSResolver, type_ u16, result ?&XPathResult) !&XPathResult {
	return xpath_evaluate(expression, context_node, resolver, type_, result)
}

pub fn (d &Document) evaluate_xpath(expression string, context_node &Node, resolver ?&XPathNSResolver, type_ u16, result ?&XPathResult) !&XPathResult {
	return d.evaluate(expression, context_node, resolver, type_, result)
}

pub fn (d &Document) create_ns_resolver(node_resolver &Node) &Node {
	return node_resolver
}

// --- Selection change ---
pub fn (d &Document) has_scheduled_selectionchange_event() bool {
	return d.has_scheduled_selectionchange_event
}

pub fn (mut d Document) set_scheduled_selectionchange_event(value bool) {
	d.has_scheduled_selectionchange_event = value
}

// --- Permissions ---

// https://html.spec.whatwg.org/multipage/iframe-embed-object.html#allowed-to-use
pub fn (d &Document) is_allowed_to_use_feature(feature PolicyControlledFeature) bool {
	// 1. If document's browsing context is null, return false.
	if d.browsing_context == unsafe { nil } {
		return false
	}
	// 2. If document is not fully active, return false.
	if !d.is_fully_active() {
		return false
	}
	// 3. If the result of running is feature enabled in document for origin on feature, document, and document's origin
	//    is "Enabled", then return true.
	// FIXME: This is ad-hoc. Implement the Permissions Policy specification.
	return match feature {
		// FIXME: Implement allowlist for this.
		.autoplay { true }
		// FIXME: Implement allowlist for this.
		.camera { true }
		// FIXME: Implement allowlist for this.
		.focus_without_user_activation, .encrypted_media { true }
		// FIXME: Implement allowlist for this.
		.fullscreen { true }
		// FIXME: Implement allowlist for this.
		.gamepad { true }
		// FIXME: Implement allowlist for this.
		.microphone { true }
		// FIXME: Implement allowlist for this.
		.window_management { true }
	}
}

// --- Accessibility ---
pub fn (d &Document) dump_accessibility_tree_as_json() string {
	// Build accessibility tree and serialize as JSON
	mut sb := strings.new_builder(256)
	sb.write_string('{"type":"element","role":"document"}')
	return sb.str()
}

pub fn (d &Document) dump_dom_tree_as_json() string {
	// Serialize DOM tree as JSON
	mut sb := strings.new_builder(256)
	sb.write_string('{')
	sb.write_string('"type":"document"')
	sb.write_string(',"url":"${d.url.serialize()}"')
	sb.write_string('}')
	return sb.str()
}

// --- Images ---
pub fn (mut d Document) list_of_available_images() &ListOfAvailableImages {
	if d.list_of_available_images == unsafe { nil } {
		d.list_of_available_images = &ListOfAvailableImages{}
	}
	return d.list_of_available_images
}

// --- Observers ---
pub fn (mut d Document) register_intersection_observer(observer &IntersectionObserver) {
	for registered_observer in d.intersection_observers {
		assert voidptr(registered_observer) != voidptr(observer)
	}
	d.intersection_observers << observer
}

pub fn (mut d Document) unregister_intersection_observer(observer &IntersectionObserver) {
	for index, registered_observer in d.intersection_observers {
		if voidptr(registered_observer) == voidptr(observer) {
			d.intersection_observers.delete(index)
			return
		}
	}
	assert false, 'IntersectionObserver was not registered with this document'
}

pub fn (d &Document) registered_intersection_observer_count() int {
	return d.intersection_observers.len
}

pub fn (mut d Document) register_resize_observer(observer &ResizeObserver) {
	for registered_observer in d.resize_observers {
		if voidptr(registered_observer) == voidptr(observer) {
			return
		}
	}
	d.resize_observers << observer
}

pub fn (mut d Document) unregister_resize_observer(observer &ResizeObserver) {
	for index, registered_observer in d.resize_observers {
		if voidptr(registered_observer) == voidptr(observer) {
			d.resize_observers.delete(index)
			return
		}
	}
	assert false, 'ResizeObserver was not registered with this document'
}

pub fn (d &Document) registered_resize_observer_count() int {
	return d.resize_observers.len
}

// --- Intersection observations ---
fn intersection_rect(first Rect, second Rect) Rect {
	left := if first.x > second.x { first.x } else { second.x }
	top := if first.y > second.y { first.y } else { second.y }
	right := if first.x + first.width < second.x + second.width {
		first.x + first.width
	} else {
		second.x + second.width
	}
	bottom := if first.y + first.height < second.y + second.height {
		first.y + first.height
	} else {
		second.y + second.height
	}
	if right <= left || bottom <= top {
		return Rect{ x: left, y: top }
	}
	return Rect{left, top, right - left, bottom - top}
}

fn edge_adjacent_intersects(first Rect, second Rect) bool {
	return first.x <= second.x + second.width && first.x + first.width >= second.x && first.y <= second.y + second.height && first.y + first.height >= second.y
}

fn resolve_intersection_observer_margin(value IntersectionObserverMarginValue, reference f64) f64 {
	return if value.is_percentage { value.value * reference / 100.0 } else { value.value }
}

// https://www.w3.org/TR/intersection-observer/#run-the-update-intersection-observations-steps
pub fn (mut d Document) run_the_update_intersection_observations_steps(time f64) {
	// 1-2. Copy the observer list so callbacks/GC finalizers cannot mutate the
	// registry while this rendering update walks it.
	observer_list := d.intersection_observers.clone()
	d.update_paint_and_hit_testing_properties_if_needed()
	for observer in observer_list {
		if observer.root_bounds == unsafe { nil } || observer.root_node == unsafe { nil } || observer.thresholds == unsafe { nil } {
			continue
		}
		root_bounds := observer.root_bounds(observer.target)
		root_node := observer.root_node(observer.target) or { continue }
		is_implicit_root := observer.is_implicit_root != unsafe { nil } && observer.is_implicit_root(observer.target)
		root_is_element := observer.root_is_element != unsafe { nil } && observer.root_is_element(observer.target)
		thresholds := observer.thresholds(observer.target)

		// 2. Process targets in the order observe() appended them.
		for target_index, observed_target in observer.observation_targets() {
			target := observed_target.target
			mut threshold_index := uint(0)
			mut is_intersecting := false
			mut target_rect := Rect{}
			mut intersection := Rect{}
			mut intersection_ratio := 0.0

			target_has_layout := target.document().layout_is_up_to_date()
				&& target.el_layout_node() != none
			same_document := voidptr(target.document()) == voidptr(root_node.document())
			inside_element_root := !root_is_element || target.as_node().is_descendant_of(root_node)
			if target_has_layout && (is_implicit_root || same_document) && inside_element_root {
				target_rect = target.bounding_client_rect_assuming_layout_clean()
				intersection = compute_intersection(target, target_rect, observer, none, root_bounds)
				target_area := target_rect.width * target_rect.height
				intersection_area := intersection.width * intersection.height
				intersection_geometry_intersects := edge_adjacent_intersects(target_rect,
					root_bounds)
				intersection_ratio = if target_area != 0 {
					intersection_area / target_area
				} else if intersection_geometry_intersects {
					1.0
				} else {
					0.0
				}
				if intersection_geometry_intersects {
					// upper_bound(thresholds, intersectionRatio)
					mut lower := 0
					mut upper := thresholds.len
					for lower < upper {
						middle := lower + (upper - lower) / 2
						if thresholds[middle] > intersection_ratio {
							upper = middle
						} else {
							lower = middle + 1
						}
					}
					threshold_index = uint(lower)
				}
				// Match the current interop behavior: geometry which intersects but
				// does not reach the first threshold is reported as non-intersecting.
				is_intersecting = threshold_index > 0
			}

			if observer.update_target_state == unsafe { nil } {
				continue
			}
			threshold_changed := if previous := observed_target.previous_threshold_index {
				previous != threshold_index
			} else {
				true
			}
			if threshold_changed || observed_target.previous_is_intersecting != is_intersecting {
				d.queue_an_intersection_observer_entry(observer, time, root_bounds, target_rect, intersection, is_intersecting, intersection_ratio, target)
			}
			observer.update_target_state(observer.target, uint(target_index), threshold_index,
				is_intersecting)
		}
	}
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#start-intersection-observing-a-lazy-loading-element
pub fn (mut d Document) start_intersection_observing_a_lazy_loading_element(element &Element) {
	// 2. If doc's lazy load intersection observer is null, set it to a new IntersectionObserver instance.
	if d.lazy_load_intersection_observer == unsafe { nil } {
		d.lazy_load_intersection_observer = &IntersectionObserver{}
	}
	// 3. Call doc's lazy load intersection observer's observe method with element.
	d.lazy_load_intersection_observer.observe(element)
}

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#stop-intersection-observing-a-lazy-loading-element
pub fn (mut d Document) stop_intersection_observing_a_lazy_loading_element(element &Element) {
	// 2. Assert: doc's lazy load intersection observer is not null.
	if d.lazy_load_intersection_observer == unsafe { nil } {
		return
	}
	// 3. Call doc's lazy load intersection observer unobserve method with element.
	d.lazy_load_intersection_observer.unobserve(element)
}

// --- Resize observations ---

// https://drafts.csswg.org/resize-observer-1/#gather-active-observations-h
pub fn (mut d Document) gather_active_observations_at_depth(depth int) {
	observers := d.resize_observers.clone()
	for observer in observers {
		observer.gather_active_observations_at_depth(depth)
	}
}

// https://drafts.csswg.org/resize-observer-1/#broadcast-active-resize-observations
pub fn (mut d Document) broadcast_active_resize_observations() int {
	// 1. Let shallowestTargetDepth be infinity.
	mut shallowest_target_depth := max_int
	// 2. For each observer in document's [[resizeObservers]]:
	observers := d.resize_observers.clone()
	for observer in observers {
		observer_depth := observer.broadcast_active_resize_observations()
		if observer_depth < shallowest_target_depth {
			shallowest_target_depth = observer_depth
		}
	}
	return shallowest_target_depth
}

// https://drafts.csswg.org/resize-observer-1/#has-active-observations-h
pub fn (d &Document) has_active_resize_observations() bool {
	for observer in d.resize_observers {
		if observer.has_active_observations() {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/resize-observer-1/#has-skipped-observations-h
pub fn (d &Document) has_skipped_resize_observations() bool {
	for observer in d.resize_observers {
		if observer.has_skipped_observations() {
			return true
		}
	}
	return false
}

// --- Adopted style sheets ---
pub fn (mut d Document) set_adopted_style_sheets(value []&CSSStyleSheet) ! {
	d.adopted_style_sheets = value.clone()
}

// --- Visual viewport ---
pub fn (mut d Document) visual_viewport() VisualViewport {
	if viewport := d.visual_viewport_ {
		return viewport
	}
	if factory := document_visual_viewport_factory_ {
		viewport := factory(&d)
		d.visual_viewport_ = viewport
		return viewport
	}
	panic('Document.visual_viewport requires the CSS VisualViewport implementation')
}

pub fn (mut d Document) register_viewport_client(client ViewportClient) {
	if client.target == unsafe { nil } || client.did_set_viewport_rect == unsafe { nil } {
		return
	}
	if client !in d.viewport_clients {
		d.viewport_clients << client
	}
}

pub fn (mut d Document) unregister_viewport_client(client ViewportClient) {
	d.viewport_clients = d.viewport_clients.filter(it != client)
}

pub fn (mut d Document) inform_all_viewport_clients_about_the_current_viewport_rect() {
	viewport := d.viewport_rect()
	for client in d.viewport_clients {
		client.did_set_viewport_rect(client.target, viewport)
	}
}

// --- Declarative refresh ---

// https://html.spec.whatwg.org/multipage/semantics.html#shared-declarative-refresh-steps
pub fn (mut d Document) shared_declarative_refresh_steps(input string) {
	d.shared_declarative_refresh_steps_impl(input, false)
}

// HTMLMetaElement supplies the additional insertion-time and sandbox checks
// from the shared declarative refresh steps without making DOM depend on HTML.
pub fn (mut d Document) shared_declarative_refresh_steps_for_meta(input string) {
	d.shared_declarative_refresh_steps_impl(input, true)
}

fn declarative_refresh_ascii_whitespace(byte u8) bool {
	return byte in [` `, `\t`, `\n`, `\r`, 0x0c]
}

fn declarative_refresh_ascii_case_equal(byte u8, expected u8) bool {
	return byte == expected || byte == expected + 0x20
}

fn (mut d Document) shared_declarative_refresh_steps_impl(input string, has_meta_element bool) {
	// 1. If document's will declaratively refresh is true, then return.
	if d.will_declaratively_refresh {
		return
	}

	// 2. Let position point at the first code point of input.
	mut pos := 0

	// 3. Skip ASCII whitespace.
	for pos < input.len && declarative_refresh_ascii_whitespace(input[pos]) {
		pos++
	}

	// 4-5. Collect the integer part of the delay.
	time_start := pos
	for pos < input.len && input[pos] >= `0` && input[pos] <= `9` {
		pos++
	}
	time_string := input[time_start..pos]

	// 6. An absent integer part is accepted only when followed by '.'.
	if time_string.len == 0 && (pos >= input.len || input[pos] != `.`) {
		return
	}

	// 7. Upstream defaults overflow to zero. Its Core::Timer interval is a
	// signed int, so reject values whose milliseconds would overflow i32.
	mut time_seconds := 0
	mut parsed_time := 0
	mut time_overflowed := false
	for byte in time_string.bytes() {
		digit := int(byte - `0`)
		if parsed_time > (2_147_483 - digit) / 10 {
			time_overflowed = true
			break
		}
		parsed_time = parsed_time * 10 + digit
	}
	if !time_overflowed {
		time_seconds = parsed_time
	}

	// 8. Ignore the fractional part and any additional full stops.
	for pos < input.len && (input[pos] == `.` || (input[pos] >= `0` && input[pos] <= `9`)) {
		pos++
	}

	// 9. Let urlRecord be document's URL (default).
	mut url_record := d.url

	// 10. Consume the permitted separator and surrounding whitespace.
	if pos < input.len {
		c := input[pos]
		if c != `;` && c != `,` && !declarative_refresh_ascii_whitespace(c) {
			return
		}
		for pos < input.len && declarative_refresh_ascii_whitespace(input[pos]) {
			pos++
		}
		if pos < input.len && (input[pos] == `;` || input[pos] == `,`) {
			pos++
		}
		for pos < input.len && declarative_refresh_ascii_whitespace(input[pos]) {
			pos++
		}
	}

	// 11. Parse an optional URL. Preserve the upstream lexer behavior: URL=
	// is stripped only when the complete token and '=' are present; otherwise
	// the original remaining substring is parsed verbatim.
	if pos < input.len {
		url_start := pos
		mut strip_url_prefix := false
		if declarative_refresh_ascii_case_equal(input[pos], `U`) {
			pos++
			if pos < input.len && declarative_refresh_ascii_case_equal(input[pos], `R`) {
				pos++
				if pos < input.len && declarative_refresh_ascii_case_equal(input[pos], `L`) {
					pos++
					for pos < input.len && declarative_refresh_ascii_whitespace(input[pos]) {
						pos++
					}
					if pos < input.len && input[pos] == `=` {
						pos++
						for pos < input.len && declarative_refresh_ascii_whitespace(input[pos]) {
							pos++
						}
						strip_url_prefix = true
					}
				}
			}
		}

		mut url_string := input[url_start..]
		if strip_url_prefix || !declarative_refresh_ascii_case_equal(input[url_start], `U`) {
			mut quote := u8(0)
			if pos < input.len && (input[pos] == `'` || input[pos] == `"`) {
				quote = input[pos]
				pos++
			}
			url_value_start := pos
			if quote != 0 {
				for pos < input.len && input[pos] != quote {
					pos++
				}
			} else {
				pos = input.len
			}
			url_string = input[url_value_start..pos]
		}

		url_record = d.encoding_parse_url(url_string) or { return }
		if url_record.scheme() == 'javascript' {
			return
		}
	}

	// 12. Set document's will declaratively refresh to true.
	d.will_declaratively_refresh = true
	d.last_declarative_refresh_ = input

	// 13. Navigate with replacement history handling once the refresh is due.
	document_pointer := voidptr(&d)
	hook := d.html_navigation_hook_
	d.active_refresh_timer = Timer.create_single_shot(time_seconds * 1000, fn [document_pointer, has_meta_element, hook, url_record] () {
		mut document := unsafe { &Document(document_pointer) }
		if has_meta_element && document.active_sandboxing_flag_bits() & u32(512) != 0 {
			return
		}
		if document.navigable() == none || document.has_been_destroyed() {
			return
		}
		if navigation_hook := hook {
			if navigation_hook.target != unsafe { nil } && navigation_hook.declarative_refresh_navigate != unsafe { nil } {
				navigation_hook.declarative_refresh_navigate(navigation_hook.target, document, url_record)
			}
		}
	})

	// Header refreshes begin at completely-finished-loading. A meta refresh
	// inserted after that point begins immediately.
	if has_meta_element && d.completely_loaded_time {
		d.active_refresh_timer.start()
	}
}

pub fn (d &Document) last_declarative_refresh_input() ?string {
	return d.last_declarative_refresh_
}

// --- Animations ---

// https://www.w3.org/TR/web-animations-1/#dom-document-timeline
pub fn (mut d Document) timeline() &DocumentTimeline {
	if d.default_timeline == unsafe { nil } {
		d.default_timeline = &DocumentTimeline{}
	}
	return d.default_timeline
}

pub fn (mut d Document) associate_with_timeline(timeline AnimationTimelineHandle) {
	if timeline.target == unsafe { nil } || timeline.update_current_time == unsafe { nil } {
		return
	}
	for existing in d.associated_animation_timelines {
		if existing.target == timeline.target {
			return
		}
	}
	d.associated_animation_timelines << timeline
}

pub fn (mut d Document) disassociate_with_timeline(timeline AnimationTimelineHandle) {
	d.associated_animation_timelines = d.associated_animation_timelines.filter(it.target != timeline.target)
}

pub fn (mut d Document) append_pending_animation_event(event PendingAnimationEvent) {
	// The record borrows immutable metadata from its document/animation just
	// like its target and animation pointers. Appending the named value makes
	// current V deep-clone every string; a fresh record preserves those borrows.
	d.pending_animation_event_queue << PendingAnimationEvent{...event}
}

// https://www.w3.org/TR/web-animations-1/#update-animations-and-send-events
pub fn (mut d Document) update_animations_and_send_events(timestamp f64) {
	d.last_animation_frame_timestamp = timestamp
	// Snapshot the set because updating a timeline can run animation logic that
	// changes timeline association. The copy reuses one buffer every frame; a
	// nested update finds it taken and makes its own.
	mut timelines_to_update := unsafe { d.animation_timeline_scratch_ }
	d.animation_timeline_scratch_ = []AnimationTimelineHandle{}
	timelines_to_update.clear()
	timelines_to_update << d.associated_animation_timelines
	for timeline in timelines_to_update {
		if timeline.target != unsafe { nil } && timeline.update_current_time != unsafe { nil } {
			timeline.update_current_time(timeline.target, timestamp)
		}
	}
	d.animation_timeline_scratch_ = timelines_to_update
	if hook := d.css_animation_timeline_update_hook_ {
		if hook.callback != unsafe { nil } {
			hook.callback(hook.target, timestamp)
		}
	}
	if hook := d.animations_hook_ {
		if hook.update_animations != unsafe { nil } {
			hook.update_animations(hook.target, unsafe { &Node(&d) }, timestamp)
		}
	}
	// 1. The animations bridge above updates each concrete timeline and its
	// associated animations without duplicating their state in DOM.
	// 2. Remove replaced animations for doc.
	d.remove_replaced_animations()

	if d.pending_animation_event_queue.len == 0 {
		return
	}
	// 4. Let events to dispatch be a copy of doc's pending animation event queue.
	mut events_to_dispatch := unsafe { d.animation_event_scratch_ }
	d.animation_event_scratch_ = []PendingAnimationEvent{}
	events_to_dispatch.clear()
	events_to_dispatch << d.pending_animation_event_queue
	// 5. Clear doc's pending animation event queue.
	d.pending_animation_event_queue.clear()
	defer {
		events_to_dispatch.clear()
		d.animation_event_scratch_ = events_to_dispatch
	}

	// 6. Stable-sort by scheduled event time, then by animation composite
	// order. Unresolved scheduled times sort before resolved times.
	for index := 1; index < events_to_dispatch.len; index++ {
		mut position := index
		for position > 0 && d.pending_animation_event_sorts_before(events_to_dispatch[position], events_to_dispatch[position - 1]) {
			temporary := events_to_dispatch[position - 1]
			events_to_dispatch[position - 1] = events_to_dispatch[position]
			events_to_dispatch[position] = temporary
			position--
		}
	}

	// 7. Dispatch each event.
	for index in 0 .. events_to_dispatch.len {
		event := unsafe { &events_to_dispatch[index] }
		if event.target != unsafe { nil } {
			if event.event_factory != unsafe { nil } {
				mut observed := should_dispatch_non_activation_event(event.target, event.event_type)
				if !observed {
					if legacy := legacy_prefixed_animation_or_transition_event_type(event.event_type) {
						observed = should_dispatch_non_activation_event(event.target, legacy)
					}
				}
				if observed { event.target.dispatch_event(event.event_factory(event)) }
			} else {
				event.target.dispatch_event(event.event)
			}
		}
	}
}

fn (d &Document) pending_animation_event_sorts_before(a PendingAnimationEvent, b PendingAnimationEvent) bool {
	if b_time := b.scheduled_event_time {
		a_time := a.scheduled_event_time or { return true }
		if a_time != b_time {
			return a_time < b_time
		}
	} else if a.scheduled_event_time != none {
		return false
	}
	if hook := d.animations_hook_ {
		if hook.compare_animations != unsafe { nil } && a.animation != unsafe { nil } && b.animation != unsafe { nil } {
			return hook.compare_animations(hook.target, a.animation, b.animation) < 0
		}
	}
	return false
}

pub fn (d &Document) last_animation_frame_timestamp_value() ?f64 {
	return d.last_animation_frame_timestamp
}

// https://www.w3.org/TR/web-animations-1/#remove-replaced-animations
pub fn (mut d Document) remove_replaced_animations() {
	if hook := d.animations_hook_ {
		if hook.remove_replaced_animations != unsafe { nil } {
			hook.remove_replaced_animations(hook.target, unsafe { &Node(&d) })
			return
		}
	}
}

// Header-template algorithm from DocumentOrShadowRoot.h. The concrete
// Animatable/KeyframeEffect types live in the animations module and install
// the callback used here, avoiding a dom -> animations import cycle.
pub fn calculate_get_animations(root &Node) ![]&Animation {
	document := root.document()
	hook := document.animations_hook_ or { return []&Animation{} }
	if hook.calculate_get_animations == unsafe { nil } {
		return []&Animation{}
	}
	return hook.calculate_get_animations(hook.target, root)
}

pub fn (d &Document) get_animations() ![]&Animation {
	mut mutable_document := unsafe { &Document(d) }
	mutable_document.update_style()
	return calculate_get_animations(unsafe { &Node(d) })
}

pub fn (d &Document) transition_generation() int {
	return d.transition_generation
}

// --- Element ID/Name tracking ---
pub fn (mut d Document) element_id_changed(element &Element, old_id ?string) {
	// Notify form-associated elements
	for fae in d.form_associated_elements_with_form_attribute {
		fae.element_id_changed()
	}
	// Update potentially named elements list
	if element.id() != none {
		d.insert_in_potentially_named_elements(element)
	} else if element.get_name() == none {
		d.remove_from_potentially_named_elements(element)
	}
	// Update element-by-id map
	if oid := old_id {
		d.remove_element_by_id(oid, element)
	}
	if new_id := element.id() {
		d.add_element_by_id(new_id, element)
	}
	d.note_svg_paint_resources_changed()
}

pub fn (mut d Document) element_with_id_was_added(element &Element) {
	for fae in d.form_associated_elements_with_form_attribute {
		fae.element_with_id_was_added_or_removed()
	}
	if is_potentially_named_element_by_id(element) {
		d.insert_in_potentially_named_elements(element)
	}
	if id := element.id() {
		d.add_element_by_id(id, element)
		d.note_svg_paint_resources_changed()
	}
}

pub fn (mut d Document) element_with_id_was_removed(element &Element) {
	for fae in d.form_associated_elements_with_form_attribute {
		fae.element_with_id_was_added_or_removed()
	}
	if is_potentially_named_element_by_id(element) {
		d.remove_from_potentially_named_elements(element)
	}
	if id := element.id() {
		d.remove_element_by_id(id, element)
		d.note_svg_paint_resources_changed()
	}
}

pub fn (mut d Document) element_name_changed(element &Element) {
	if element.get_name() != none {
		d.insert_in_potentially_named_elements(element)
	} else if element.id() == none {
		d.remove_from_potentially_named_elements(element)
	}
}

pub fn (mut d Document) element_with_name_was_added(element &Element) {
	if is_potentially_named_element(element) {
		d.insert_in_potentially_named_elements(element)
	}
}

pub fn (mut d Document) element_with_name_was_removed(element &Element) {
	if is_potentially_named_element(element) {
		if is_potentially_named_element_by_id(element) && element.id() != none {
			return
		}
		d.remove_from_potentially_named_elements(element)
	}
}

// --- Form elements ---
pub fn (mut d Document) add_form_associated_element_with_form_attribute(element &FormAssociatedElement) {
	for existing in d.form_associated_elements_with_form_attribute {
		if voidptr(existing) == voidptr(element) {
			return
		}
	}
	d.form_associated_elements_with_form_attribute << element
}

pub fn (mut d Document) remove_form_associated_element_with_form_attribute(element &FormAssociatedElement) {
	d.form_associated_elements_with_form_attribute = d.form_associated_elements_with_form_attribute.filter(it != element)
}

// --- Design mode ---
pub fn (d &Document) design_mode_enabled_state() bool {
	return d.design_mode_enabled
}

pub fn (mut d Document) set_design_mode_enabled_state(enabled bool) {
	if d.design_mode_enabled == enabled {
		return
	}
	states := previous_read_write_states(d.as_node())
	d.design_mode_enabled = enabled
	mut node := d.as_node()
	node.recompute_editable_subtree_flags_and_repaint()
	invalidate_previous_read_write_states(states)
}

// https://html.spec.whatwg.org/multipage/interaction.html#making-entire-documents-editable:-the-designmode-idl-attribute
pub fn (d &Document) design_mode() string {
	if d.design_mode_enabled {
		return 'on'
	}
	return 'off'
}

pub fn (mut d Document) set_design_mode(dm string) ! {
	value := to_ascii_lowercase(dm)
	if value == 'on' && !d.design_mode_enabled {
		d.set_design_mode_enabled_state(true)
		if mut selection := d.get_selection() {
			selection.collapse(d.as_node(), 0)!
			d.update_layout(.document_set_design_mode)
		}
		if root := d.document_element() {
			if dom_run_focusing_steps != unsafe { nil } {
				dom_run_focusing_steps(root.as_node(), none, .other)
			}
		}
	} else if value == 'off' {
		d.set_design_mode_enabled_state(false)
	}
}

// HTML owns the focusing algorithm; this callback is the DOM -> HTML boundary.
pub type RunFocusingStepsCallback = fn (&Node, ?&Node, FocusTrigger)

pub fn install_run_focusing_steps(callback RunFocusingStepsCallback) {
	dom_run_focusing_steps = callback
}

// --- Hit testing ---

// https://drafts.csswg.org/cssom-view/#dom-document-elementfrompoint
pub fn (mut d Document) element_from_point(x f64, y f64) ?&Element {
	// 1. If either argument is negative or beyond viewport, return null.
	viewport := d.viewport_rect()
	if x < 0 || y < 0 || x > viewport.width || y > viewport.height {
		return none
	}

	// Ensure the layout tree exists prior to hit testing.
	d.update_layout(.document_element_from_point)

	// 2. Hit test at coordinates x,y.
	if paintable_box := d.paintable_box() {
		if hit := paintable_box.hit_test(x, y, .exact) {
			if hit.element != unsafe { nil } {
				return retarget_from_ua_internal_shadow_root(hit.element)
			}
		}
	}
	// 3. If the document has a root element, return the root element.
	return d.document_element()
}

// https://drafts.csswg.org/cssom-view/#dom-document-elementsfrompoint
pub fn (mut d Document) elements_from_point(x f64, y f64) []&Element {
	// 1. Let sequence be a new empty sequence.
	mut sequence := []&Element{}
	// 2. Check viewport bounds.
	viewport := d.viewport_rect()
	if x < 0 || y < 0 || x > viewport.width || y > viewport.height {
		return sequence
	}

	// Ensure the layout tree exists prior to hit testing.
	d.update_layout(.document_elements_from_point)

	// 3. Hit test and collect all elements at the point.
	if paintable_box := d.paintable_box() {
		paintable_box.hit_test_all(x, y, mut sequence)
	}
	for i, element in sequence {
		sequence[i] = retarget_from_ua_internal_shadow_root(element)
	}
	mut deduplicated_sequence := []&Element{}
	mut seen := map[voidptr]bool{}
	for element in sequence {
		if !seen[voidptr(element)] {
			seen[voidptr(element)] = true
			deduplicated_sequence << element
		}
	}
	sequence = deduplicated_sequence.clone()

	// 4. If the last item is not the document's root element, append that root.
	if root := d.document_element() {
		if sequence.len == 0 || voidptr(sequence.last()) != voidptr(root) {
			sequence << root
		}
	}
	return sequence
}

// https://drafts.csswg.org/cssom-view/#dom-document-scrollingelement
pub fn (d &Document) scrolling_element() ?&Element {
	// 1. If the Document is in quirks mode:
	if d.in_quirks_mode() {
		// 1. If the body element exists and is not potentially scrollable, return it.
		if body_el := d.body() {
			body_element := html_element_as_element(body_el)
			if !body_element.is_potentially_scrollable_with_overflow_clip_treatment(.yes) {
				return &body_el.Element
			}
		}
		// 2. Return null.
		return none
	}
	// 2. If there is a root element, return the root element.
	return d.document_element()
}

// --- Named properties ---

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem-filter
pub fn is_potentially_named_element(element &Element) bool {
	return element.is_html_element() && element.local_name() in ['embed', 'form', 'iframe', 'img',
		'object']
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem-filter
pub fn is_potentially_named_element_by_id(element &Element) bool {
	return element.is_html_element() && element.local_name() in ['img', 'object']
}

pub fn insert_in_tree_order(mut elements []&Element, element &Element) {
	for existing in elements {
		if existing == element {
			return
		}
	}
	for index, existing in elements {
		if (existing.as_node().compare_document_position(element.as_node()) & document_position_following) != 0 {
			elements.insert(index, element)
			return
		}
	}
	elements << element
}

// This deliberately follows Ladybird's current FIXME-backed implementation:
// every embed/object reaching this helper is considered exposed.
pub fn is_exposed(element &Element) bool {
	return element.is_html_element() && element.local_name() in ['embed', 'object']
}

pub fn is_named_element_with_name(element &Element, name string) bool {
	if !element.is_html_element() {
		return false
	}
	local_name := element.local_name()
	if local_name in ['embed', 'form', 'iframe', 'img', 'object'] && (local_name !in [
		'embed',
		'object',
	] || is_exposed(element)) {
		if element.get_name() or { '' } == name {
			return true
		}
	}
	if local_name == 'object' && is_exposed(element) {
		if element.id() or { '' } == name {
			return true
		}
	}
	if local_name == 'img' && element.get_name() or { '' } != '' {
		return element.id() or { '' } == name
	}
	return false
}

pub fn named_elements_with_name(document &Document, name string) []&Element {
	mut result := []&Element{}
	for element in document.potentially_named_elements {
		if is_named_element_with_name(element, name) {
			result << element
		}
	}
	return result
}

// https://html.spec.whatwg.org/multipage/dom.html#dom-tree-accessors:supported-property-names
pub fn (d &Document) supported_property_names() []string {
	mut names := []string{}
	for element in d.potentially_named_elements {
		if !element.is_html_element() {
			continue
		}
		local_name := element.local_name()
		if local_name in ['embed', 'form', 'iframe', 'img', 'object'] && (local_name !in [
			'embed',
			'object',
		] || is_exposed(element)) {
			if name := element.get_name() {
				if name != '' && name !in names {
					names << name
				}
			}
		}
		if local_name == 'object' && is_exposed(element) {
			if id := element.id() {
				if id != '' && id !in names {
					names << id
				}
			}
		}
		if local_name == 'img' && element.get_name() or { '' } != '' {
			if id := element.id() {
				if id != '' && id !in names {
					names << id
				}
			}
		}
	}
	return names
}

// The HTML Window named-properties algorithm consumes this ordered list. The
// accessor keeps the DOM-owned cache encapsulated while preserving tree order.
pub fn (d &Document) potentially_named_elements() []&Element {
	return d.potentially_named_elements.clone()
}

// ElementByIdMap accessors used by Window's named-property algorithms. C++
// iterates this cache separately from potentially-named elements so every HTML
// element with an id participates, including ordinary div/span elements.
pub fn (d &Document) element_ids() []string {
	return d.element_by_id_map().elements_by_id.keys()
}

fn collect_elements_with_id(node &Node, id string, mut result []&Element) {
	if element := node.as_element() {
		if element.id() or { '' } == id {
			result << element
		}
	}
	for child in node.children_as_vector() {
		collect_elements_with_id(child, id, mut result)
	}
}

pub fn (d &Document) elements_with_id(id string) []&Element {
	if id !in d.element_by_id_map().elements_by_id {
		return []
	}
	mut result := []&Element{}
	collect_elements_with_id(unsafe { &Node(d) }, id, mut result)
	return result
}

fn collect_descendant_elements(node &Node, mut result []&Element) {
	for child in node.children_as_vector() {
		if element := child.as_element() {
			result << element
		}
		collect_descendant_elements(child, mut result)
	}
}

pub fn (d &Document) descendant_elements() []&Element {
	mut result := []&Element{}
	collect_descendant_elements(unsafe { &Node(d) }, mut result)
	return result
}

// --- Shadow roots ---
pub fn (d &Document) registered_shadow_roots() []&ShadowRoot {
	return d.shadow_roots.clone()
}

pub fn (mut d Document) register_shadow_root(shadow_root &ShadowRoot) {
	d.shadow_roots << shadow_root
}

pub fn (mut d Document) unregister_shadow_root(shadow_root &ShadowRoot) {
	d.shadow_roots = d.shadow_roots.filter(it != shadow_root)
}

// --- Top layer ---

// https://drafts.csswg.org/css-position-4/#add-an-element-to-the-top-layer
pub fn (mut d Document) add_an_element_to_the_top_layer(element &Element) {
	// Re-adding an element with a pending removal moves it to the top and cancels the removal.
	if element_pointer_in_list(d.top_layer_elements, element) {
		d.top_layer_elements = d.top_layer_elements.filter(voidptr(it) != voidptr(element))
		d.top_layer_pending_removals = d.top_layer_pending_removals.filter(voidptr(it) != voidptr(element))
	}
	d.top_layer_elements << element
	mut mutable_element := unsafe { &Element(element) }
	mutable_element.set_in_top_layer(true)
	mutable_element.set_rendered_in_top_layer(true)
	mutable_element.set_needs_style_update(true)
	d.invalidate_layout_tree(.document_add_an_element_to_the_top_layer)
}

// The layout tree builder traverses the document's top layer after the normal
// document tree, matching Layout::TreeBuilder::build().
pub fn (d &Document) top_layer_elements_for_layout() []&Element {
	return d.top_layer_elements.clone()
}

// https://drafts.csswg.org/css-position-4/#request-an-element-to-be-removed-from-the-top-layer
pub fn (mut d Document) request_an_element_to_be_remove_from_the_top_layer(element &Element) {
	if !element_pointer_in_list(d.top_layer_elements, element) || element_pointer_in_list(d.top_layer_pending_removals, element) {
		return
	}
	mut mutable_element := unsafe { &Element(element) }
	mutable_element.set_rendered_in_top_layer(false)
	mutable_element.set_in_top_layer(false)
	mutable_element.set_needs_style_update(true)
	d.top_layer_pending_removals << element
	d.invalidate_layout_tree(.document_request_an_element_to_be_removed_from_the_top_layer)
}

// https://drafts.csswg.org/css-position-4/#remove-an-element-from-the-top-layer-immediately
pub fn (mut d Document) remove_an_element_from_the_top_layer_immediately(element &Element) {
	d.top_layer_elements = d.top_layer_elements.filter(voidptr(it) != voidptr(element))
	d.top_layer_pending_removals = d.top_layer_pending_removals.filter(voidptr(it) != voidptr(element))
	mut mutable_element := unsafe { &Element(element) }
	mutable_element.set_in_top_layer(false)
	mutable_element.set_rendered_in_top_layer(false)
	mutable_element.set_needs_style_update(true)
	d.invalidate_layout_tree(.document_immediately_remove_element_from_the_top_layer)
}

fn element_pointer_in_list(elements []&Element, target &Element) bool {
	for element in elements {
		if voidptr(element) == voidptr(target) {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/css-position-4/#process-top-layer-removals
pub fn (mut d Document) process_top_layer_removals() {
	if d.top_layer_pending_removals.len == 0 {
		return
	}
	for element in d.top_layer_pending_removals {
		d.top_layer_elements = d.top_layer_elements.filter(voidptr(it) != voidptr(element))
	}
	d.top_layer_pending_removals.clear()
	d.invalidate_layout_tree(.document_pending_top_layer_removals_processed)
}

// --- Popover ---
pub fn (d &Document) showing_auto_popover_list() []&HTMLElement {
	return d.showing_auto_popover_list.clone()
}

pub fn (d &Document) showing_hint_popover_list() []&HTMLElement {
	return d.showing_hint_popover_list.clone()
}

pub fn (mut d Document) append_showing_auto_popover(element &HTMLElement) {
	if !html_element_pointer_in_list(d.showing_auto_popover_list, element) {
		d.showing_auto_popover_list << element
	}
}

pub fn (mut d Document) append_showing_hint_popover(element &HTMLElement) {
	if !html_element_pointer_in_list(d.showing_hint_popover_list, element) {
		d.showing_hint_popover_list << element
	}
}

pub fn (mut d Document) remove_showing_auto_popover(element &HTMLElement) {
	d.showing_auto_popover_list = d.showing_auto_popover_list.filter(voidptr(it) != voidptr(element))
}

pub fn (mut d Document) remove_showing_hint_popover(element &HTMLElement) {
	d.showing_hint_popover_list = d.showing_hint_popover_list.filter(voidptr(it) != voidptr(element))
}

fn html_element_pointer_in_list(elements []&HTMLElement, target &HTMLElement) bool {
	for element in elements {
		if voidptr(element) == voidptr(target) {
			return true
		}
	}
	return false
}

// https://html.spec.whatwg.org/multipage/popover.html#topmost-auto-popover
pub fn (d &Document) topmost_auto_or_hint_popover() ?&HTMLElement {
	if d.showing_hint_popover_list.len > 0 {
		return d.showing_hint_popover_list.last()
	}
	if d.showing_auto_popover_list.len > 0 {
		return d.showing_auto_popover_list.last()
	}
	return none
}

pub fn (mut d Document) set_popover_pointerdown_target(target ?&HTMLElement) {
	d.popover_pointerdown_target = target or { unsafe { nil } }
}

pub fn (d &Document) get_popover_pointerdown_target() ?&HTMLElement {
	if d.popover_pointerdown_target == unsafe { nil } {
		return none
	}
	return d.popover_pointerdown_target
}

// --- Text search ---
pub fn (d &Document) find_matching_text(query string, case_sensitivity CaseSensitivity) []&Range {
	mut document := unsafe { &Document(d) }
	document.update_layout(.document_find_matching_text)
	viewport := document.layout_node() or { return []&Range{} }
	root := viewport.root_layout_node() or { return []&Range{} }
	if root.bridge_callbacks().find_matching_text_callback == unsafe { nil } { return []&Range{} }
	return root.bridge_callbacks().find_matching_text_callback(root.layout_handle, query, case_sensitivity)
}

// --- HTML parsing ---

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#parse-html-from-a-string
pub fn (mut d Document) parse_html_from_a_string(markup string) {
	// 1. Set document's type to "html".
	d.type_ = .html
	if hook := d.html_fragment_parsing_hook_ {
		if hook.parse_document != unsafe { nil } {
			hook.parse_document(hook.target, &d, markup)
			return
		}
	}
	// The html module owns parser construction and installs parse_document above.
	// Reaching this point means the module-cycle bridge was not installed.
	panic('HTML parser hook has not been installed for Document.parse_html_from_a_string()')
}

// --- Cursor ---
pub fn (d &Document) cursor_position() ?&Position {
	focused := d.focused_area
	if focused == unsafe { nil } {
		return none
	}
	// If focused element is editable, return selection cursor position
	if focused.is_editable_or_editing_host() {
		if d.selection_ != unsafe { nil } {
			return d.selection_.cursor_position()
		}
	}
	if target := d.active_input_events_target(none) {
		return target.cursor_position()
	}
	return none
}

pub fn (mut d Document) reset_cursor_blink_cycle() {
	d.cursor_blink_state = true
	// Would restart the cursor blink timer
	if d.cursor_blink_timer != unsafe { nil } && !d.cursor_blink_suppressed_ {
		d.cursor_blink_timer.restart()
	}
}

// Deterministic rendering clients can hold a focused caret visible. This is
// independent of focus ownership and survives edits resetting the blink cycle.
pub fn (mut d Document) set_cursor_blink_suppressed(suppressed bool) {
	if d.cursor_blink_suppressed_ == suppressed { return }
	d.cursor_blink_suppressed_ = suppressed
	if suppressed {
		was_visible := d.cursor_blink_state
		d.cursor_blink_state = true
		if d.cursor_blink_timer != unsafe { nil } { d.cursor_blink_timer.stop() }
		if !was_visible {
			if position := d.cursor_position() {
				if node := position.node() {
					mut mutable_node := unsafe { &Node(node) }
					mutable_node.set_needs_repaint(.paint_commands)
				}
			}
		}
	} else {
		d.reset_cursor_blink_cycle()
	}
}

pub fn (d &Document) get_cursor_blink_state() bool {
	return d.cursor_blink_state
}

// --- Navigable back-pointer ---
pub fn (mut d Document) set_navigable(navigable ?&Navigable) {
	value := navigable or { unsafe { nil } }
	if voidptr(d.navigable_) == voidptr(value) {
		return
	}
	if value != unsafe { nil } {
		register_navigable(value)
	}
	d.navigable_ = value
	if hook := d.lifecycle_hook_ {
		d.run_lifecycle_callback(hook.document_navigable_did_change)
	}
}

// Compatibility aliases for translated callers predating the maintained
// back-pointer. New navigation code uses navigable()/set_navigable().
pub fn (d &Document) cached_navigable() ?&Navigable {
	return d.navigable()
}

pub fn (mut d Document) set_cached_navigable(navigable ?&Navigable) {
	d.set_navigable(navigable)
}

pub fn (mut d Document) invalidate_display_list() {
	d.cached_display_list_ = unsafe { nil }
	d.paint_content_revision_++
}

// Viewport scrolling replaces lowered commands without changing their source
// pixels. Every other paint invalidation advances this revision, including
// compositor-only changes which keep the display list.
pub fn (d &Document) paint_content_revision() u64 {
	return d.paint_content_revision_
}

pub fn (d &Document) cached_display_list() ?&DisplayList {
	if d.cached_display_list_ == unsafe { nil } {
		return none
	}
	return d.cached_display_list_
}

// --- Segmenters ---
pub fn (mut d Document) grapheme_segmenter() &Segmenter {
	if d.grapheme_segmenter_ == unsafe { nil } {
		d.grapheme_segmenter_ = &Segmenter{
			granularity: .grapheme
		}
	}
	return d.grapheme_segmenter_
}

pub fn (mut d Document) line_segmenter() &Segmenter {
	if d.line_segmenter_ == unsafe { nil } {
		d.line_segmenter_ = &Segmenter{
			granularity: .line
		}
	}
	return d.line_segmenter_
}

pub fn (mut d Document) word_segmenter() &Segmenter {
	if d.word_segmenter_ == unsafe { nil } {
		d.word_segmenter_ = &Segmenter{
			granularity: .word
		}
	}
	return d.word_segmenter_
}

// --- Beforeunload ---

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#steps-to-fire-beforeunload
pub fn (mut d Document) steps_to_fire_beforeunload(unload_prompt_shown bool) StepsToFireBeforeunloadResult {
	// 1. Let unloadPromptCanceled be false.
	mut unload_prompt_canceled := false
	mut prompt_shown := unload_prompt_shown

	// 2. Increase the document's unload counter by 1.
	d.unload_counter++

	// 3. Increase document's relevant agent's event loop's termination nesting level by 1.
	d.increment_termination_nesting_level()

	// 4. Let eventFiringResult be the result of firing an event named beforeunload at document's relevant global object,
	//    using BeforeUnloadEvent, with the cancelable attribute initialized to true.
	mut event_firing_result := true
	mut beforeunload_event := unsafe { &BeforeUnloadEvent(nil) }
	window := d.get_window()
	if relevant_window := window {
		beforeunload_event = BeforeUnloadEvent.create('beforeunload', EventInit{})
		beforeunload_event.time_stamp_ = current_high_resolution_time(relevant_window)
		beforeunload_event.set_cancelable(true)
		event_firing_result = relevant_window.dispatch_event(unsafe { &Event(beforeunload_event) })
	}

	// 5. Decrease document's relevant agent's event loop's termination nesting level by 1.
	d.decrement_termination_nesting_level()

	// 6. If all of the following are true:
	if relevant_window := window {
		if !prompt_shown
			// HTML::SandboxingFlagSet::SandboxedModals is bit 12 at the DOM/HTML boundary.
			&& d.active_sandboxing_flag_bits() & u32(1 << 12) == 0
			&& relevant_window.has_sticky_activation()
			&& (!event_firing_result || beforeunload_event.return_value() != '') {
			// FIXME: Showing an unload prompt is unlikely to be annoying, deceptive, or pointless.
			// 1. Set unloadPromptShown to true.
			prompt_shown = true

			// FIXME: 2. Invoke WebDriver BiDi user prompt opened.
			// FIXME: 3. Ask the user to confirm unloading and pause for the response.
			user_prompt_handler := webdriver.get_the_prompt_handler(.before_unload)
			// 4. If the user did not confirm the page navigation, set unloadPromptCanceled to true.
			if user_prompt_handler.handler == .dismiss {
				unload_prompt_canceled = true
			}
			// FIXME: 5. Invoke WebDriver BiDi user prompt closed.
		}
	}

	// 7. Decrease document's unload counter by 1.
	d.unload_counter--

	// 8. Return (unloadPromptShown, unloadPromptCanceled).
	return StepsToFireBeforeunloadResult{
		unload_prompt_shown: prompt_shown
		unload_prompt_canceled: unload_prompt_canceled
	}
}

// --- Event handlers ---
pub fn (d &Document) onreadystatechange() ?&CallbackType {
	return d.onreadystatechange_handler
}

pub fn (mut d Document) set_onreadystatechange(value ?&CallbackType) {
	d.onreadystatechange_handler = value or { unsafe { nil } }
}

pub fn (d &Document) onvisibilitychange() ?&CallbackType {
	return d.onvisibilitychange_handler
}

pub fn (mut d Document) set_onvisibilitychange(value ?&CallbackType) {
	d.onvisibilitychange_handler = value or { unsafe { nil } }
}

pub fn (d &Document) onfullscreenchange() ?&CallbackType {
	return unsafe { &EventTarget(d) }.event_handler_attribute('fullscreenchange')
}

pub fn (mut d Document) set_onfullscreenchange(value ?&CallbackType) {
	unsafe { &EventTarget(&d) }.set_event_handler_attribute('fullscreenchange', value)
}

pub fn (d &Document) onfullscreenerror() ?&CallbackType {
	return unsafe { &EventTarget(d) }.event_handler_attribute('fullscreenerror')
}

pub fn (mut d Document) set_onfullscreenerror(value ?&CallbackType) {
	unsafe { &EventTarget(&d) }.set_event_handler_attribute('fullscreenerror', value)
}

// --- View transitions ---

fn js_value_to_webidl_value(value JSValue) webidl.Value {
	return match value.kind {
		.undefined { webidl.undefined_value() }
		.null_ { webidl.null_value() }
		.boolean { webidl.boolean_value(value.boolean_data) }
		.number { webidl.number_value(value.number_data) }
		.string { webidl.string_value(value.string_data) }
		.object { webidl.platform_object_value() }
		.runtime_value { value.native_value_ or { webidl.undefined_value() } }
	}
}

// https://drafts.csswg.org/css-view-transitions-1/#dom-document-startviewtransition
pub fn (mut d Document) start_view_transition(update_callback ?&CallbackType) &ViewTransition {
	transition_document := d.ensure_view_transition_document()
	inner := viewtransition.ViewTransition.create_for_live_document(transition_document)
	if callback := update_callback {
		if call := callback.call_no_args_promise {
			mut mutable_inner := unsafe { &viewtransition.ViewTransition(inner) }
			mutable_inner.set_update_callback(call)
		} else if call := callback.call_no_args {
			mut mutable_inner := unsafe { &viewtransition.ViewTransition(inner) }
			context := transition_document.promise_context
			mutable_inner.set_update_callback(fn [call, context] () !&webidl.Promise {
				return webidl.create_resolved_promise_for(context, js_value_to_webidl_value(call()))
			})
		}
	}
	vt := &ViewTransition{
		transition_:          inner
		transition_document_: transition_document
		document_:            d
		transition_root_pseudo_element_: &PseudoElementTreeNode_{}
	}
	if d.visibility_state == .hidden {
		vt.skip_with_reason(webidl.string_value('InvalidStateError: The document visibility state is hidden'))
		return vt
	}
	if d.active_view_transition != unsafe { nil } {
		d.active_view_transition.skip_the_view_transition()
	}
	d.active_view_transition = vt
	mut mutable_transition_document := unsafe { &viewtransition.TransitionDocument(transition_document) }
	mutable_transition_document.active_transition = inner
	return vt
}

// https://drafts.csswg.org/css-view-transitions-1/#perform-pending-transition-operations
pub fn (mut d Document) perform_pending_transition_operations() {
	// 1. If document's active view transition is not null:
	if d.active_view_transition != unsafe { nil } {
		// 1. If phase is "pending-capture", setup the view transition.
		if d.active_view_transition.phase() == .pending_capture {
			d.active_view_transition.setup_view_transition()
		} else if d.active_view_transition.phase() == .animating {
			// 2. If phase is "animating", handle transition frame.
			d.active_view_transition.handle_transition_frame()
		}
	}
}

// https://drafts.csswg.org/css-view-transitions-1/#flush-the-update-callback-queue
pub fn (mut d Document) flush_the_update_callback_queue() {
	if d.view_transition_document_ != unsafe { nil } {
		mut context := d.view_transition_document_
		context.flush_the_update_callback_queue()
	}
	for transition in d.update_callback_queue.clone() {
		if transition.transition_ != unsafe { nil } {
			mut inner := transition.transition_
			inner.call_the_update_callback()
			transition.sync_document_state()
		}
	}
	d.update_callback_queue.clear()
}

// https://drafts.csswg.org/css-view-transitions-1/#view-transition-page-visibility-change-steps
pub fn (mut d Document) view_transition_page_visibility_change_steps() {
	document_pointer := voidptr(&d)
	steps := fn [document_pointer] () {
		document := unsafe { &Document(document_pointer) }
		if document.visibility_state == .hidden && document.active_view_transition != unsafe { nil } {
			document.active_view_transition.skip_with_reason(webidl.string_value('InvalidStateError: The document visibility state is hidden'))
		}
	}
	if !queue_view_transition_document_task(&d, steps) { steps() }
}

pub fn (d &Document) get_active_view_transition() ?&ViewTransition {
	if d.active_view_transition == unsafe { nil } {
		return none
	}
	return d.active_view_transition
}

pub fn (mut d Document) set_active_view_transition(vt ?&ViewTransition) {
	d.active_view_transition = vt or { unsafe { nil } }
}

// --- Fullscreen ---

// https://fullscreen.spec.whatwg.org/#run-the-fullscreen-steps
pub fn (mut d Document) run_fullscreen_steps() {
	// 1. Let pendingEvents be document's list of pending fullscreen events.
	pending_events := d.pending_fullscreen_events.clone()
	// 2. Empty document's list of pending fullscreen events.
	d.pending_fullscreen_events.clear()
	// 3. For each (type, element) in pendingEvents:
	for pe in pending_events {
		// Let target be element if element is connected, otherwise document.
		match pe.type_ {
			.change {
				if pe.element != unsafe { nil } && pe.element.is_connected() {
					pe.element.dispatch_event_simple('fullscreenchange', true)
				} else {
					d.dispatch_event_simple('fullscreenchange', true)
				}
			}
			.error {
				if pe.element != unsafe { nil } && pe.element.is_connected() {
					pe.element.dispatch_event_simple('fullscreenerror', true)
				} else {
					d.dispatch_event_simple('fullscreenerror', true)
				}
			}
		}
	}
}

pub fn (mut d Document) append_pending_fullscreen_change(type_ PendingFullscreenEventType, element &Element) {
	d.pending_fullscreen_events << PendingFullscreenEvent{
		type_: type_
		element: element
	}
	d.request_frame()
}

// https://fullscreen.spec.whatwg.org/#fullscreen-element
pub fn (d &Document) fullscreen_element() ?&Element {
	// The fullscreen element is the topmost element in the document's top layer
	// whose fullscreen flag is set, if any, and null otherwise.
	for i := d.top_layer_elements.len - 1; i >= 0; i-- {
		el := d.top_layer_elements[i]
		if el.is_fullscreen_element() {
			return el
		}
	}
	return none
}

// https://fullscreen.spec.whatwg.org/#dom-document-fullscreenelement
pub fn (d &Document) fullscreen_element_for_bindings() ?&Element {
	fullscreen_element := d.fullscreen_element() or { return none }

	// Retarget the fullscreen element against the document. A fullscreen element
	// inside a shadow tree is therefore exposed as the appropriate shadow host.
	candidate_target := retarget(unsafe { &EventTarget(fullscreen_element.as_node()) }, unsafe {
		&EventTarget(d)
	}) or { return none }
	candidate_node := event_target_as_node(candidate_target) or { return none }
	candidate := candidate_node.as_element() or { return none }

	// Only expose a retargeted candidate in this document's tree.
	if candidate.as_node().root() == unsafe { &Node(d) }.root() {
		return candidate
	}
	return none
}

// https://fullscreen.spec.whatwg.org/#dom-document-fullscreen
pub fn (d &Document) fullscreen() bool {
	return d.fullscreen_element() != none
}

// https://fullscreen.spec.whatwg.org/#dom-document-fullscreenenabled
pub fn (d &Document) fullscreen_enabled() bool {
	return d.is_allowed_to_use_feature(.fullscreen)
}

// https://fullscreen.spec.whatwg.org/#fully-exit-fullscreen
pub fn (mut d Document) fully_exit_fullscreen() {
	// 1. If document's fullscreen element is null, terminate.
	fullscreened := d.fullscreen_element() or { return }
	// 2. Unfullscreen elements whose fullscreen flag is set, except the fullscreen element.
	mut to_unfullscreen := []&Element{}
	for el in d.top_layer_elements {
		if el.is_fullscreen_element() && voidptr(el) != voidptr(fullscreened) {
			to_unfullscreen << el
		}
	}
	for mut el in to_unfullscreen {
		mut mutable_element := unsafe { &Element(el) }
		d.unfullscreen_element(mut mutable_element)
	}
	// 3. Exit fullscreen document.
	d.exit_fullscreen()
}

// https://fullscreen.spec.whatwg.org/#exit-fullscreen
pub fn (mut d Document) exit_fullscreen() &Promise {
	mut promise := Promise.create()
	// 2. If doc is not fully active or doc's fullscreen element is null, reject.
	if !d.is_fully_active() || d.fullscreen_element() == none {
		promise.reject(js_string('TypeError: Document not fully active or no fullscreen element.'))
		return promise
	}
	// Unfullscreen the fullscreen element
	if el := d.fullscreen_element() {
		d.append_pending_fullscreen_change(.change, el)
		mut mutable_element := unsafe { &Element(el) }
		d.unfullscreen_element(mut mutable_element)
	}
	d.run_fullscreen_steps()
	promise.resolve(js_undefined())
	return promise
}

// https://fullscreen.spec.whatwg.org/#unfullscreen-an-element
pub fn (mut d Document) unfullscreen_element(mut element Element) {
	// Unset element's fullscreen flag and remove from the top layer immediately.
	element.set_fullscreen_flag(false)
	d.remove_an_element_from_the_top_layer_immediately(element)
}

// https://fullscreen.spec.whatwg.org/#unfullscreen-a-document
pub fn (mut d Document) unfullscreen() {
	// Unfullscreen all elements within document's top layer whose fullscreen flag is set.
	mut fullscreen_elements := []&Element{}
	for el in d.top_layer_elements {
		if el.is_fullscreen_element() {
			fullscreen_elements << el
		}
	}
	for mut el in fullscreen_elements {
		d.unfullscreen_element(mut el)
	}
}

// https://fullscreen.spec.whatwg.org/#simple-fullscreen-document
pub fn (d &Document) is_simple_fullscreen_document() bool {
	// A document is a simple fullscreen document if there is exactly one element
	// in its top layer that has its fullscreen flag set.
	mut total := 0
	for el in d.top_layer_elements {
		if el.is_fullscreen_element() {
			total++
		}
		if total > 1 {
			return false
		}
	}
	return total == 1
}

// --- Render blocking ---

// https://html.spec.whatwg.org/multipage/dom.html#render-blocked
pub fn (d &Document) is_render_blocked() bool {
	if d.pending_css_import_rules.len > 0 || d.render_blocking_elements.len > 0 {
		return true
	}
	// A missing body only blocks the initial parser-driven render. Once parsing
	// has advanced the document beyond "loading", removing the body must not
	// suspend animation frames or screenshot completion again.
	return d.allows_adding_render_blocking_elements() && d.readiness == .loading
		&& d.active_parser() != none
}

// https://html.spec.whatwg.org/multipage/dom.html#allows-adding-render-blocking-elements
pub fn (d &Document) allows_adding_render_blocking_elements() bool {
	// A document allows adding render-blocking elements if document's content type is "text/html"
	// and the body element of document is null.
	return d.content_type == 'text/html' && d.body() == none
}

pub fn (mut d Document) add_render_blocking_element(element &Element) {
	d.render_blocking_elements << element
}

pub fn (mut d Document) remove_render_blocking_element(element &Element) {
	d.render_blocking_elements = d.render_blocking_elements.filter(it != element)
	if d.render_blocking_elements.len == 0 {
		d.request_frame()
	}
}

// --- CSS import rules ---
pub fn (mut d Document) add_pending_css_import_rule(rule &CSSImportRule) {
	d.pending_css_import_rules << rule
}

pub fn (mut d Document) remove_pending_css_import_rule(rule &CSSImportRule) {
	d.pending_css_import_rules = d.pending_css_import_rules.filter(it != rule)
	if d.pending_css_import_rules.len == 0 {
		d.request_frame()
	}
}

// --- Registered properties ---

// https://drafts.css-houdini.org/css-properties-values-api/#determining-registration
pub fn (d &Document) get_registered_custom_property(name string) ?CustomPropertyRegistration {
	if name in d.registered_property_set {
		return d.registered_property_set[name]
	}
	if name in d.cached_registered_properties_from_css_property_rules {
		return d.cached_registered_properties_from_css_property_rules[name]
	}
	return none
}

// --- Editing ---
pub fn (d &Document) get_default_single_line_container_name() string {
	return d.default_single_line_container_name
}

pub fn (mut d Document) set_default_single_line_container_name(name string) {
	d.default_single_line_container_name = name
}

pub fn (d &Document) get_css_styling_flag() bool {
	return d.css_styling_flag
}

pub fn (mut d Document) set_css_styling_flag(flag bool) {
	d.css_styling_flag = flag
}

pub fn (d &Document) command_state_override(command string) ?bool {
	if command in d.command_state_override {
		return d.command_state_override[command]
	}
	return none
}

pub fn (mut d Document) set_command_state_override(command string, state bool) {
	d.command_state_override[command] = state
}

pub fn (mut d Document) clear_command_state_override(command string) {
	d.command_state_override.delete(command)
}

pub fn (mut d Document) reset_command_state_overrides() {
	d.command_state_override.clear()
}

pub fn (d &Document) command_value_override(command string) ?string {
	if command in d.command_value_override {
		return d.command_value_override[command]
	}
	return none
}

// https://w3c.github.io/editing/docs/execCommand/#value-override
pub fn (mut d Document) set_command_value_override(command string, value string) {
	d.command_value_override[command] = value

	// The value override for the backColor command must be the same as the value override for the hiliteColor command,
	// such that setting one sets the other to the same thing and unsetting one unsets the other.
	if command == 'backColor' {
		d.command_value_override['hiliteColor'] = value
	} else if command == 'hiliteColor' {
		d.command_value_override['backColor'] = value
	}
}

// https://w3c.github.io/editing/docs/execCommand/#value-override
pub fn (mut d Document) clear_command_value_override(command string) {
	d.command_value_override.delete(command)

	// The value override for the backColor command must be the same as the value override for the hiliteColor command,
	// such that setting one sets the other to the same thing and unsetting one unsets the other.
	if command == 'backColor' {
		d.command_value_override.delete('hiliteColor')
	} else if command == 'hiliteColor' {
		d.command_value_override.delete('backColor')
	}
}

pub fn (d &Document) preserve_selection_offsets_during_identical_character_data_replacement() bool {
	return d.preserve_selection_offsets_during_identical_character_data_replacement_
}

pub fn (mut d Document) set_preserve_selection_offsets_during_identical_character_data_replacement(value bool) {
	d.preserve_selection_offsets_during_identical_character_data_replacement_ = value
}

pub fn (d &Document) running_editing_command_action() bool {
	return d.running_editing_command_action
}

pub fn (mut d Document) set_running_editing_command_action(value bool) {
	d.running_editing_command_action = value
}

pub fn (mut d Document) reset_command_value_overrides() {
	d.command_value_override.clear()
}

// --- Container document ---

// https://html.spec.whatwg.org/multipage/document-sequences.html#doc-container-document
pub fn (d &Document) container_document() ?&Document {
	// 1. If document's node navigable is null, then return null.
	node_navigable := d.navigable() or { return none }
	// 2. Return document's node navigable's container document.
	return node_navigable.container_document()
}

// --- Storage ---
pub fn (d &Document) session_storage_holder() ?&Storage {
	if d.session_storage_holder == unsafe { nil } {
		return none
	}
	return d.session_storage_holder
}

pub fn (mut d Document) set_session_storage_holder(storage ?&Storage) {
	d.session_storage_holder = storage or { unsafe { nil } }
}

pub fn (d &Document) local_storage_holder() ?&Storage {
	if d.local_storage_holder == unsafe { nil } {
		return none
	}
	return d.local_storage_holder
}

pub fn (mut d Document) set_local_storage_holder(storage ?&Storage) {
	d.local_storage_holder = storage or { unsafe { nil } }
}

// --- Decoded SVG ---
pub fn (d &Document) is_decoded_svg() bool {
	return d.is_svg_document
}

// --- Console ---
pub fn (mut d Document) set_console_client(client ?&ConsoleClient) {
	d.console_client_ = client or { unsafe { nil } }
}

pub fn (d &Document) console_client() ?&ConsoleClient {
	if d.console_client_ == unsafe { nil } {
		return none
	}
	return d.console_client_
}

// --- Input events ---
pub fn (d &Document) active_input_events_target(for_node ?&Node) ?&InputEventsTarget {
	focused := d.focused_area
	if focused == unsafe { nil } {
		return none
	}
	if focused.is_editable_or_editing_host() {
		manager := d.editing_host_manager()
		node := for_node or { return unsafe { &InputEventsTarget(manager) } }
		if manager.is_within_active_contenteditable(node) {
			return unsafe { &InputEventsTarget(manager) }
		}
	}
	if form_text_element := d.form_control_input_events_target(focused) {
		node := for_node or { return form_text_element }
		if focused.is_shadow_including_inclusive_ancestor_of(node) {
			return form_text_element
		}
	}
	return none
}

pub fn (d &Document) form_control_input_events_target(node &Node) ?&InputEventsTarget {
	if d.form_control_input_events_target_callback_ == unsafe { nil } {
		return none
	}
	return d.form_control_input_events_target_callback_(node)
}

// --- Pointer lock ---
pub fn (mut d Document) exit_pointer_lock() {
	// FIXME: Implement pointer lock exit
	d.pointer_lock_element = unsafe { nil }
}

// --- Selector query cache ---
pub fn (d &Document) cached_query_selector_result(selector_text string) ?SelectorList {
	if selector_text in d.selector_query_cache {
		return d.selector_query_cache[selector_text] or { return none }
	}
	return none
}

pub fn (mut d Document) cache_query_selector_result(selector_text string, result ?SelectorList) {
	if d.selector_query_cache.len >= 256 {
		d.selector_query_cache.clear()
	}
	d.selector_query_cache[selector_text] = result
}

// https://html.spec.whatwg.org/multipage/parsing.html#list-of-speculative-fetch-urls
pub fn (d &Document) has_speculative_fetch_url(url URL) bool {
	return d.speculative_fetch_urls_[url.serialize()]
}

pub fn (mut d Document) add_speculative_fetch_url(url URL) {
	d.speculative_fetch_urls_[url.serialize()] = true
}

// HTML owns PreloadEntry, so DOM retains document-lifetime entries through an
// opaque handle and a serialized PreloadKey to avoid a DOM -> HTML cycle.
pub fn (mut d Document) set_preloaded_resource_entry(key string, entry voidptr) {
	d.preloaded_resource_entries_[key] = entry
}

pub fn (mut d Document) take_preloaded_resource_entry(key string) ?voidptr {
	entry := d.preloaded_resource_entries_[key] or { return none }
	d.preloaded_resource_entries_.delete(key)
	return entry
}

pub fn (d &Document) preloaded_resource_entry_count() int {
	return d.preloaded_resource_entries_.len
}

// --- Shared resource requests ---
pub fn (mut d Document) shared_resource_requests() map[string]&SharedResourceRequest {
	return d.shared_resource_requests_
}

pub fn SharedResourceRequest.get_or_create(mut document Document, url URL) &SharedResourceRequest {
	key := url.to_string()
	if request := document.shared_resource_requests_[key] {
		return request
	}
	request := &SharedResourceRequest{
		url: url
		document: &document
	}
	document.shared_resource_requests_[key] = request
	return request
}

pub fn (request &SharedResourceRequest) image_data() ?SharedResourceImageData {
	return request.image_data_
}

pub fn (request &SharedResourceRequest) fetch_controller() voidptr {
	return request.fetch_controller
}

pub fn (mut request SharedResourceRequest) set_fetch_controller(controller voidptr) {
	request.fetch_controller = controller
}

pub fn (mut request SharedResourceRequest) set_decode_callback(callback ?SharedResourceDecodeCallback) {
	request.decode_callback = callback
}

pub fn (mut request SharedResourceRequest) fetch_resource(fetch SharedResourceFetchCallback) {
	if request.state_ != .new_ {
		return
	}
	request.state_ = .fetching
	request.load_event_delay = true
	fetch(request, request.url)
}

pub fn (mut request SharedResourceRequest) add_callbacks(on_finish ?SharedResourceRequestCallback, on_fail ?SharedResourceRequestCallback) {
	if request.state_ == .finished {
		if callback := on_finish {
			callback()
		}
		return
	}
	if request.state_ == .failed {
		if callback := on_fail {
			callback()
		}
		return
	}
	request.callbacks << SharedResourceCallbacks{
		on_finish: on_finish
		on_fail: on_fail
	}
}

pub fn (mut request SharedResourceRequest) handle_failed_fetch() {
	request.state_ = .failed
	request.load_event_delay = false
	for callbacks in request.callbacks {
		if callback := callbacks.on_fail {
			callback()
		}
	}
	request.callbacks.clear()
}

pub fn (mut request SharedResourceRequest) handle_successful_resource_load(image_data SharedDecodedImageData) {
	request.image_data_ = SharedResourceImageData{ data: image_data }
	request.state_ = .finished
	request.load_event_delay = false
	for callbacks in request.callbacks {
		if callback := callbacks.on_finish {
			callback()
		}
	}
	request.callbacks.clear()
}

pub fn (mut request SharedResourceRequest) handle_successful_fetch(url URL, mime_type string, data []u8) {
	decode := request.decode_callback or {
		request.handle_failed_fetch()
		return
	}
	effective_mime_type := shared_resource_effective_image_mime_type(url, mime_type)
	image_data := decode(url, effective_mime_type, data.clone()) or {
		request.handle_failed_fetch()
		return
	}
	request.handle_successful_resource_load(image_data)
}

pub fn shared_resource_effective_image_mime_type(url URL, mime_type string) string {
	if mime_type == '' && url.basename().ends_with('.svg') {
		return 'image/svg+xml'
	}
	return mime_type
}

pub fn (request &SharedResourceRequest) needs_fetching() bool {
	return request.state_ == .new_
}

pub fn (request &SharedResourceRequest) is_fetching() bool {
	return request.state_ == .fetching
}

pub fn (request &SharedResourceRequest) state() SharedResourceRequestState {
	return request.state_
}

// --- History ---
pub fn (d &Document) get_latest_entry() ?&SessionHistoryEntry {
	if d.latest_entry == unsafe { nil } {
		return none
	}
	return d.latest_entry
}

pub fn (mut d Document) set_latest_entry(e ?&SessionHistoryEntry) {
	d.latest_entry = e or { unsafe { nil } }
}

fn (mut d Document) set_history_state(state JSValue) {
	mut history := d.history()
	history.set_state(state)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#restore-the-history-object-state
pub fn (mut d Document) restore_the_history_object_state(entry &SessionHistoryEntry) {
	// 2. Let state be StructuredDeserialize(entry's classic history API state, targetRealm).
	// 3. Set document's history object's state to state.
	hook := d.lifecycle_hook_ or {
		d.set_history_state(js_null())
		return
	}
	if hook.structured_deserialize == unsafe { nil } {
		d.set_history_state(js_null())
		return
	}
	state := hook.structured_deserialize(hook.target, entry.classic_history_api_state) or {
		d.set_history_state(js_null())
		return
	}
	d.set_history_state(state)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#update-document-for-history-step-application
pub fn (mut d Document) update_for_history_step_application(entry &SessionHistoryEntry, do_not_reactivate bool, script_history_length int, script_history_index int, navigation_type ?NavigationType) {
	// 1. Let documentIsNew be true if document's latest entry is null; otherwise false.
	document_is_new := d.latest_entry == unsafe { nil }

	// 2. Let documentsEntryChanged be true if document's latest entry is not entry.
	documents_entry_changed := d.latest_entry != entry

	// 3. Set document's history object's index to scriptHistoryIndex.
	d.history().index = script_history_index

	// 4. Set document's history object's length to scriptHistoryLength.
	d.history().length = script_history_length

	// 6. If documentsEntryChanged is true:
	if documents_entry_changed {
		// 2. Set document's latest entry to entry.
		d.latest_entry = entry

		// 3. Restore the history object state given document and entry.
		d.restore_the_history_object_state(entry)

		// 4. If documentIsNew is false:
		if !document_is_new {
			// Update document URL
			d.url = entry.url

			// Fire popstate event at document's relevant global object
			if d.window != unsafe { nil } {
				d.window.dispatch_popstate_event(d.history().state)
			}

			// 5. If oldURL's fragment differs from entry's URL's fragment, fire hashchange event.
		}
	}
	_ = do_not_reactivate
	if document_is_new {
		d.set_ready_to_run_scripts()
	}
}

// --- Last modified ---

// https://html.spec.whatwg.org/multipage/dom.html#dom-document-lastmodified
pub fn (d &Document) last_modified() string {
	// The lastModified attribute returns the date and time of the Document's source file's
	// last modification, formatted as MM/DD/YYYY HH:MM:SS.
	if lm := d.last_modified_ {
		return lm
	}
	// If the last modification date and time are not known, return the current date and time.
	now := vtime.now()
	return '${now.month:02d}/${now.day:02d}/${now.year:04d} ${now.hour:02d}:${now.minute:02d}:${now.second:02d}'
}

// --- Populate ---

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#populate-with-html/head/body
pub fn (mut d Document) populate_with_html_head_and_body() ! {
	// 1. Let html be the result of creating an element given document, "html", HTML namespace.
	mut html_el := create_element(&d, tag_html_, namespace_html_, none, none, false)!
	// 2. Let head be the result of creating an element given document, "head", HTML namespace.
	head_el := create_element(&d, tag_head_, namespace_html_, none, none, false)!
	// 3. Let body be the result of creating an element given document, "body", HTML namespace.
	body_el := create_element(&d, tag_body_, namespace_html_, none, none, false)!
	// 4. Append html to document.
	mut document_node := unsafe { &Node(&d) }
	document_node.append_child(html_el.as_node())!
	// 5. Append head to html.
	mut html_node := unsafe { &Node(html_el.as_node()) }
	html_node.append_child(head_el.as_node())!
	// 6. Append body to html.
	html_node.append_child(body_el.as_node())!
}

// --- Allow declarative shadow roots ---
pub fn (d &Document) get_allow_declarative_shadow_roots() bool {
	return d.allow_declarative_shadow_roots
}

// https://dom.spec.whatwg.org/#document-allow-declarative-shadow-roots
pub fn (mut d Document) set_allow_declarative_shadow_roots(allow bool) {
	d.allow_declarative_shadow_roots = allow
}

// --- Ignore destructive writes ---
pub fn (d &Document) ignore_destructive_writes_counter() u32 {
	return d.ignore_destructive_writes_counter
}

pub fn (mut d Document) increment_ignore_destructive_writes_counter() {
	d.ignore_destructive_writes_counter++
}

pub fn (mut d Document) decrement_ignore_destructive_writes_counter() {
	d.ignore_destructive_writes_counter--
}

// --- Throw on dynamic markup insertion ---
pub fn (mut d Document) increment_throw_on_dynamic_markup_insertion_counter() {
	d.throw_on_dynamic_markup_insertion_counter++
}

pub fn (mut d Document) decrement_throw_on_dynamic_markup_insertion_counter() {
	d.throw_on_dynamic_markup_insertion_counter--
}

// --- Unload counter ---
pub fn (d &Document) get_unload_counter() u32 {
	return d.unload_counter
}

// --- Display list / stacking context dump ---
pub fn (mut d Document) dump_display_list() string {
	d.update_layout(.dump_display_list)
	paintable := d.paintable() or { return 'No paintable' }
	display_list := paintable.record_display_list() or { return 'No display list' }
	return display_list.dump()
}

pub fn (mut d Document) dump_stacking_context_tree() string {
	d.update_layout(.dump_display_list)
	paintable := d.paintable() or { return 'No paintable' }
	paintable.build_stacking_context_tree_if_needed()
	stacking_context := paintable.stacking_context() or { return 'No stacking context' }
	return stacking_context.dump()
}

// --- Style scope ---
pub fn (d &Document) get_style_sheet_source(identifier &StyleSheetIdentifier) ?string {
	if hook := d.style_update_hook_ {
		if hook.get_style_sheet_source != unsafe { nil } {
			return hook.get_style_sheet_source(hook.target, identifier)
		}
	}
	return match identifier.type_ {
		.style_element {
			// Would look up the <style> or <svg:style> element by unique ID
			// and return its sheet source text
			none
		}
		.link_element, .import_rule {
			// Would search through style sheets and adopted style sheets
			// for a matching URL
			url := identifier.url or { return none }
			if d.style_sheets_ != unsafe { nil } {
				for style_sheet in d.style_sheets_.sheets {
					if style_sheet.url == url {
						return style_sheet.source_text()
					}
				}
			}
			none
		}
		.user_agent {
			// The CSS bridge above owns the embedded user-agent sheets. A DOM-only
			// document has no CSS source to return.
			none
		}
		.user_style {
			none
		}
	}
}

pub fn (mut d Document) ensure_element_shared_css_random_base_value(key string) f64 {
	if key in d.element_shared_css_random_base_value_cache {
		return d.element_shared_css_random_base_value_cache[key]
	}
	value := rand.f64()
	d.element_shared_css_random_base_value_cache[key] = value
	return value
}

// --- is_child_allowed ---
pub fn (d &Document) is_child_allowed(node &Node) bool {
	return match node.node_type {
		.document_node, .text_node {
			false
		}
		.comment_node, .processing_instruction_node {
			true
		}
		.document_type_node {
			// Only one DocumentType child is allowed
			d.doctype() == none
		}
		.element_node {
			// Only one Element child (the document element) is allowed
			d.document_element() == none
		}
		else {
			false
		}
	}
}

// --- Editing host manager ---
pub fn (d &Document) editing_host_manager() &EditingHostManager {
	mut document := unsafe { &Document(d) }
	if document.editing_host_manager_ == unsafe { nil } {
		document.editing_host_manager_ = EditingHostManager.create(mut document)
	}
	return document.editing_host_manager_
}

// --- is_initial_about_blank ---
pub fn (d &Document) get_is_initial_about_blank() bool {
	return d.is_initial_about_blank
}

pub fn (mut d Document) set_is_initial_about_blank(b bool) {
	d.is_initial_about_blank = b
}

// --- about_base_url ---
pub fn (d &Document) get_about_base_url() ?URL {
	return d.about_base_url
}

pub fn (mut d Document) set_about_base_url(url ?URL) {
	d.about_base_url = url
}

// --- source ---
pub fn (d &Document) get_source() string {
	return d.source
}

pub fn (mut d Document) set_source(source string) {
	d.source = source
}

// --- did_stop_being_active_document_in_navigable ---
pub fn (mut d Document) did_stop_being_active_document_in_navigable() {
	d.clear_layout_and_paintable_nodes_for_inactive_document()
	d.tear_down_layout_tree()
	// The compact layout backend and scroll hook own the same retired tree.
	// Drop them with the viewport instead of retaining all old style/paint data.
	d.layout_engine_handle_ = unsafe { nil }
	d.viewport_scroll_snap_hook_ = none
	d.invalidate_display_list()
	d.schedule_html_parser_end_check()
	if !d.has_fired_document_became_inactive {
		d.has_fired_document_became_inactive = true
		d.notify_each_document_observer_became_inactive()
	}
}

// --- check_favicon ---
pub fn (d &Document) has_active_favicon() bool {
	return d.active_favicon != unsafe { nil }
}

pub fn (mut d Document) check_favicon_after_loading_link_resource() {
	head_element := d.head() or { return }
	mut favicon_link_elements := []&HTMLLinkElement{}
	collect_loaded_favicon_link_elements(unsafe { &Node(head_element) }, mut favicon_link_elements)
	for index := favicon_link_elements.len - 1; index >= 0; index-- {
		favicon_element := favicon_link_elements[index]
		if voidptr(favicon_element) == voidptr(d.active_element) {
			return
		}
		if favicon_element.load_favicon_and_use_if_window_is_active() {
			d.active_favicon = unsafe { &Node(favicon_element) }
			return
		}
	}
}

// https://dom.spec.whatwg.org/#dom-documentorshadowroot-customelementregistry
pub fn (d &Document) custom_element_registry() voidptr {
	return d.custom_element_registry_
}

pub fn (mut d Document) set_custom_element_registry(registry voidptr) {
	d.custom_element_registry_ = registry
}

// --- lookup_custom_element_definition ---

pub fn install_custom_element_definition_lookup(callback CustomElementDefinitionLookupCallback) {
	dom_custom_element_definition_lookup = callback
}

pub fn install_custom_element_registry_hooks(is_scoped CustomElementRegistryIsScopedCallback, append_document CustomElementRegistryAppendDocumentCallback) {
	dom_custom_element_registry_is_scoped = is_scoped
	dom_custom_element_registry_append_document = append_document
}

pub fn install_global_custom_element_registry_factory(factory GlobalCustomElementRegistryFactory) {
	dom_global_custom_element_registry_factory = factory
}

pub fn custom_element_registry_is_scoped(registry voidptr) bool {
	return registry != unsafe { nil } && dom_custom_element_registry_is_scoped != unsafe { nil }
		&& dom_custom_element_registry_is_scoped(registry)
}

pub fn is_a_global_custom_element_registry(registry voidptr) bool {
	return registry != unsafe { nil } && !custom_element_registry_is_scoped(registry)
}

pub fn custom_element_registry_append_document(registry voidptr, document &Document) {
	if registry != unsafe { nil } && dom_custom_element_registry_append_document != unsafe { nil } {
		dom_custom_element_registry_append_document(registry, document)
	}
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#look-up-a-custom-element-registry
pub fn look_up_custom_element_registry(node &Node) voidptr {
	if element := node.as_element() {
		return element.custom_element_registry()
	}
	if shadow_root := node.as_shadow_root() {
		return shadow_root.custom_element_registry()
	}
	if document := node.as_document() {
		return document.custom_element_registry()
	}
	return unsafe { nil }
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#look-up-a-custom-element-definition
pub fn look_up_custom_element_definition(registry voidptr, namespace_ ?string, local_name string, is_ ?string) ?&CustomElementDefinition {
	if registry == unsafe { nil } || dom_custom_element_definition_lookup == unsafe { nil } {
		return none
	}
	return dom_custom_element_definition_lookup(registry, namespace_, local_name, is_)
}

// https://html.spec.whatwg.org/multipage/custom-elements.html#look-up-a-custom-element-definition
pub fn (d &Document) lookup_custom_element_definition(namespace_ ?string, local_name string, is_ ?string) ?&CustomElementDefinition {
	return look_up_custom_element_definition(d.custom_element_registry(), namespace_, local_name, is_)
}

// https://dom.spec.whatwg.org/#effective-global-custom-element-registry
pub fn (d &Document) effective_global_custom_element_registry() voidptr {
	if is_a_global_custom_element_registry(d.custom_element_registry()) {
		return d.custom_element_registry()
	}
	return unsafe { nil }
}

pub fn (mut d Document) register_custom_element_definition(definition &CustomElementDefinition) {
	for index, existing in d.custom_element_definitions {
		if existing.name() == definition.name() && existing.local_name() == definition.local_name() {
			d.custom_element_definitions[index] = definition
			return
		}
	}
	d.custom_element_definitions << definition
}

// --- SVG root element ---

// https://www.w3.org/TR/SVG2/struct.html#InterfaceDocumentExtensions
pub fn (d &Document) root_element() ?&SVGSVGElement {
	// Returns SVG root element if document element is an SVGSVGElement.
	doc_el := d.document_element() or { return none }
	if doc_el.is_svg_svg_element() {
		return unsafe { &SVGSVGElement(doc_el) }
	}
	return none
}

// --- Enum to_string helpers ---
pub fn invalidate_layout_tree_reason_to_string(reason InvalidateLayoutTreeReason) string {
	return match reason {
		.document_add_an_element_to_the_top_layer {
			'DocumentAddAnElementToTheTopLayer'
		}
		.document_request_an_element_to_be_removed_from_the_top_layer {
			'DocumentRequestAnElementToBeRemovedFromTheTopLayer'
		}
		.document_immediately_remove_element_from_the_top_layer {
			'DocumentImmediatelyRemoveElementFromTheTopLayer'
		}
		.document_pending_top_layer_removals_processed {
			'DocumentPendingTopLayerRemovalsProcessed'
		}
	}
}

pub fn update_layout_reason_to_string(reason UpdateLayoutReason) string {
	return match reason {
		.auto_scroll_selection { 'AutoScrollSelection' }
		.child_document_style_update { 'ChildDocumentStyleUpdate' }
		.cursor_line_navigation { 'CursorLineNavigation' }
		.debugging { 'Debugging' }
		.document_caret_position_from_point { 'DocumentCaretPositionFromPoint' }
		.document_element_from_point { 'DocumentElementFromPoint' }
		.document_elements_from_point { 'DocumentElementsFromPoint' }
		.document_find_matching_text { 'DocumentFindMatchingText' }
		.document_readiness_complete { 'DocumentReadinessComplete' }
		.document_set_design_mode { 'DocumentSetDesignMode' }
		.dump_display_list { 'DumpDisplayList' }
		.element_check_visibility { 'ElementCheckVisibility' }
		.element_client_height { 'ElementClientHeight' }
		.element_client_width { 'ElementClientWidth' }
		.element_get_client_rects { 'ElementGetClientRects' }
		.element_is_potentially_scrollable { 'ElementIsPotentiallyScrollable' }
		.element_scroll { 'ElementScroll' }
		.element_scroll_height { 'ElementScrollHeight' }
		.element_scroll_into_view { 'ElementScrollIntoView' }
		.element_scroll_left { 'ElementScrollLeft' }
		.element_scroll_top { 'ElementScrollTop' }
		.element_scroll_width { 'ElementScrollWidth' }
		.element_set_scroll_left { 'ElementSetScrollLeft' }
		.element_set_scroll_top { 'ElementSetScrollTop' }
		.event_handler_dispatch_chrome_widget_event { 'EventHandlerDispatchChromeWidgetEvent' }
		.event_handler_handle_drag_and_drop { 'EventHandlerHandleDragAndDrop' }
		.event_handler_handle_mouse_down { 'EventHandlerHandleMouseDown' }
		.event_handler_handle_mouse_move { 'EventHandlerHandleMouseMove' }
		.event_handler_handle_mouse_up { 'EventHandlerHandleMouseUp' }
		.event_handler_handle_mouse_wheel { 'EventHandlerHandleMouseWheel' }
		.event_handler_run_activation_behavior { 'EventHandlerRunActivationBehavior' }
		.font_face_set_ready { 'FontFaceSetReady' }
		.event_handler_show_context_menu { 'EventHandlerShowContextMenu' }
		.html_element_get_the_text_steps { 'HTMLElementGetTheTextSteps' }
		.html_element_offset_height { 'HTMLElementOffsetHeight' }
		.html_element_offset_left { 'HTMLElementOffsetLeft' }
		.html_element_offset_parent { 'HTMLElementOffsetParent' }
		.html_element_offset_top { 'HTMLElementOffsetTop' }
		.html_element_offset_width { 'HTMLElementOffsetWidth' }
		.html_element_scroll_parent { 'HTMLElementScrollParent' }
		.html_event_loop_rendering_update { 'HTMLEventLoopRenderingUpdate' }
		.html_image_element_height { 'HTMLImageElementHeight' }
		.html_image_element_width { 'HTMLImageElementWidth' }
		.html_image_element_x { 'HTMLImageElementX' }
		.html_image_element_y { 'HTMLImageElementY' }
		.html_input_element_height { 'HTMLInputElementHeight' }
		.html_input_element_width { 'HTMLInputElementWidth' }
		.html_label_element_activation_behavior { 'HTMLLabelElementActivationBehavior' }
		.hosted_document_before_paint { 'HostedDocumentBeforePaint' }
		.inspect_dom_tree { 'InspectDOMTree' }
		.internals_hit_test { 'InternalsHitTest' }
		.media_query_list_matches { 'MediaQueryListMatches' }
		.navigable_selected_text { 'NavigableSelectedText' }
		.navigable_viewport_scroll { 'NavigableViewportScroll' }
		.node_name_or_description { 'NodeNameOrDescription' }
		.range_get_client_rects { 'RangeGetClientRects' }
		.resolved_css_style_declaration_property { 'ResolvedCSSStyleDeclarationProperty' }
		.svg_decoded_image_data_render { 'SVGDecodedImageDataRender' }
		.scroll_cursor_into_view { 'ScrollCursorIntoView' }
		.process_screenshot { 'ProcessScreenshot' }
		.svg_graphics_element_get_bbox { 'SVGGraphicsElementGetBBox' }
		.source_set_normalize_source_densities { 'SourceSetNormalizeSourceDensities' }
		.view_transition_capture { 'ViewTransitionCapture' }
		.window_scroll { 'WindowScroll' }
	}
}

// --- Missing methods translated from C++ ---

// https://html.spec.whatwg.org/multipage/webappapis.html#relevant-settings-object
// C++: HTML::EnvironmentSettingsObject& Document::relevant_settings_object() const
pub fn (d &Document) relevant_settings_object() voidptr {
	// The relevant settings object for a platform object o is the environment settings
	// object of the relevant Realm for o.
	hook := d.lifecycle_hook_ or { return unsafe { nil } }
	if hook.relevant_settings_object == unsafe { nil } {
		return unsafe { nil }
	}
	return hook.relevant_settings_object(hook.target, d)
}

// C++: Optional<String> Document::navigation_id() const
pub fn (d &Document) navigation_id() ?string {
	return d.navigation_id
}

// C++: bool Document::allow_declarative_shadow_roots() const
// https://dom.spec.whatwg.org/#document-allow-declarative-shadow-roots
pub fn (d &Document) allow_declarative_shadow_roots() bool {
	return d.allow_declarative_shadow_roots
}

// C++: EventTarget* Document::get_parent(Event const& event)
pub fn (d &Document) get_parent(event &Event) ?&Window {
	// If event type is "load", return null.
	if event.type_ == 'load' {
		return none
	}
	if d.window == unsafe { nil } {
		return none
	}
	// Otherwise return the window.
	return d.window
}

// C++: bool Document::is_render_blocking_element(GC::Ref<Element> element) const
pub fn (d &Document) is_render_blocking_element(element &Element) bool {
	for el in d.render_blocking_elements {
		if el == element {
			return true
		}
	}
	return false
}

// C++: bool Document::is_valid_name(String const& name)
pub fn Document.is_valid_name(name string) bool {
	if name.len == 0 {
		return false
	}
	runes := name.runes()
	// First character must be a valid name start character
	first := u32(runes[0])
	if !is_valid_name_start_character(first) {
		return false
	}
	// Remaining characters must be valid name characters
	for i := 1; i < runes.len; i++ {
		if !is_valid_name_character(u32(runes[i])) {
			return false
		}
	}
	return true
}

pub fn is_valid_name(name string) bool {
	return Document.is_valid_name(name)
}

fn is_valid_name_start_character(ch u32) bool {
	// https://www.w3.org/TR/xml/#NT-NameStartChar
	// ":" | [A-Z] | "_" | [a-z] | [#xC0-#xD6] | [#xD8-#xF6] | [#xF8-#x2FF]
	// | [#x370-#x37D] | [#x37F-#x1FFF] | [#x200C-#x200D] | [#x2070-#x218F]
	// | [#x2C00-#x2FEF] | [#x3001-#xD7FF] | [#xF900-#xFDCF] | [#xFDF0-#xFFFD]
	// | [#x10000-#xEFFFF]
	if ch == `:` || ch == `_` {
		return true
	}
	if ch >= `A` && ch <= `Z` {
		return true
	}
	if ch >= `a` && ch <= `z` {
		return true
	}
	if ch >= 0xC0 && ch <= 0xD6 {
		return true
	}
	if ch >= 0xD8 && ch <= 0xF6 {
		return true
	}
	if ch >= 0xF8 && ch <= 0x2FF {
		return true
	}
	if ch >= 0x370 && ch <= 0x37D {
		return true
	}
	if ch >= 0x37F && ch <= 0x1FFF {
		return true
	}
	if ch >= 0x200C && ch <= 0x200D {
		return true
	}
	if ch >= 0x2070 && ch <= 0x218F {
		return true
	}
	if ch >= 0x2C00 && ch <= 0x2FEF {
		return true
	}
	if ch >= 0x3001 && ch <= 0xD7FF {
		return true
	}
	if ch >= 0xF900 && ch <= 0xFDCF {
		return true
	}
	if ch >= 0xFDF0 && ch <= 0xFFFD {
		return true
	}
	if ch >= 0x10000 && ch <= 0xEFFFF {
		return true
	}
	return false
}

fn is_valid_name_character(ch u32) bool {
	// NameStartChar plus "-" | "." | [0-9] | #xB7 | [#x0300-#x036F] | [#x203F-#x2040]
	if is_valid_name_start_character(ch) {
		return true
	}
	if ch == `-` || ch == `.` {
		return true
	}
	if ch >= `0` && ch <= `9` {
		return true
	}
	if ch == 0xB7 {
		return true
	}
	if ch >= 0x0300 && ch <= 0x036F {
		return true
	}
	if ch >= 0x203F && ch <= 0x2040 {
		return true
	}
	return false
}

// C++: Vector<CSS::BackgroundLayerData> const* Document::background_layers() const
pub fn (d &Document) background_layers() ?[]BackgroundLayerData {
	body_el := d.body() or { return none }
	// NB: Called during painting inside update_layout().
	_ = body_el.unsafe_layout_node() or { return none }
	hook := d.background_style_hook_ or { return none }
	if hook.background_layers == unsafe { nil } {
		return none
	}
	return hook.background_layers(hook.target, html_element_as_element(body_el))
}

// C++: CSS::ImageRendering Document::background_image_rendering() const
pub fn (d &Document) background_image_rendering() ImageRendering {
	body_el := d.body() or { return .auto_ }
	_ = body_el.unsafe_layout_node() or { return .auto_ }
	hook := d.background_style_hook_ or { return .auto_ }
	if hook.background_image_rendering == unsafe { nil } {
		return .auto_
	}
	return hook.background_image_rendering(hook.target, html_element_as_element(body_el))
}

// C++: void Document::mark_svg_root_as_needing_relayout(Layout::SVGSVGBox& svg_root)
pub fn (mut d Document) mark_svg_root_as_needing_relayout(svg_root &SVGSVGBox) {
	d.svg_roots_needing_relayout << svg_root
}

// File-local Document.cpp helper used by Document::update_layout(). Layout
// supplies the concrete SVGFormattingContext/commit implementation through the
// cycle-breaking callback retained by SVGSVGBox.
pub fn relayout_svg_root(svg_root &SVGSVGBox) {
	if svg_root.relayout_callback != unsafe { nil } {
		svg_root.relayout_callback(svg_root)
	}
}

// C++: void Document::update_layout_if_needed_for_node(Node const& node, UpdateLayoutReason reason)
pub fn (mut d Document) update_layout_if_needed_for_node(node &Node, reason UpdateLayoutReason) {
	if node.is_connected() {
		d.update_layout(reason)
	}
}

// C++: void Document::update_style_if_needed_for_element(AbstractElement const& abstract_element)
pub fn (mut d Document) update_style_if_needed_for_element(element &Element) {
	if d.element_needs_style_update(element) {
		d.update_style()
	}
}

// C++: bool Document::element_needs_style_update(AbstractElement const& abstract_element) const
pub fn (d &Document) element_needs_style_update(element &Element) bool {
	// If there are document-level reasons to update style, we can't skip.
	if d.needs_full_style_update {
		return true
	}
	if d.needs_animated_style_update {
		return true
	}
	if d.needs_invalidation_of_elements_affected_by_has {
		return true
	}
	if d.style_invalidator_ != unsafe { nil } {
		if d.style_invalidator_.has_pending_invalidations() {
			return true
		}
	}
	// Check the element itself.
	if element.needs_style_update() || element.has_pending_font_input_update() {
		return true
	}
	if element.entire_subtree_needs_style_update() {
		return true
	}
	// Inheritance follows the flat tree (including assigned slots), so a dirty
	// inheritance ancestor makes this element stale even when its own bit is
	// clear.
	mut ancestor := element.element_to_inherit_style_from(none)
	for ancestor != none {
		current := ancestor or { break }
		if current.needs_style_update() || current.entire_subtree_needs_style_update()
			|| current.has_pending_font_input_update() {
			return true
		}
		ancestor = current.element_to_inherit_style_from(none)
	}
	// If the navigable has a container and that container needs a style update, then we need one
	// as well, since the container's style can affect this element (e.g. via media queries or
	// viewport units).
	if nav := d.navigable() {
		if container := nav.container() {
			if container_element := container.as_element() {
				container_document := container.document()
				if container_document != unsafe { nil } && container_document.element_needs_style_update(container_element) {
					return true
				}
			}
		}
	}
	return false
}

// C++: GC::Ptr<Layout::Node> Document::highlighted_layout_node()
pub fn (d &Document) highlighted_layout_node() ?&LayoutNode {
	if d.highlighted_node == unsafe { nil } {
		return none
	}
	// NB: Called during painting inside update_layout().
	if d.highlighted_pseudo_element == none || d.highlighted_node.node_type != .element_node {
		return d.highlighted_node.unsafe_layout_node()
	}
	element := d.highlighted_node.as_element() or { return none }
	pseudo_element := d.highlighted_pseudo_element or { return none }
	pseudo_layout := element.get_pseudo_element_node(int(pseudo_element)) or { return none }
	return pseudo_layout.layout_node_
}

// C++: void Document::update_active_element()
pub fn (mut d Document) update_active_element() {
	d.set_active_element(d.calculate_active_element())
}

fn (d &Document) calculate_active_element() ?&Element {
	mut candidate := d.focused_area()
	if candidate == none && d.browsing_context != unsafe { nil } && !unsafe { &Node(d) }.is_inert() {
		candidate = unsafe { &Node(d) }
	}
	candidate_node := candidate or { return none }
	retargeted := retarget(unsafe { &EventTarget(candidate_node) }, unsafe { &EventTarget(d) }) or {
		return none
	}
	retargeted_node := event_target_as_node(retargeted) or { return none }
	if voidptr(retargeted_node.root()) != voidptr(d) {
		return none
	}
	if !retargeted_node.is_document() {
		return retargeted_node.as_element()
	}
	body_el := d.body() or { return d.document_element() }
	return html_element_as_element(body_el)
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#the-indicated-part-of-the-document
// C++: Document::IndicatedPart Document::determine_the_indicated_part() const
pub fn (d &Document) determine_the_indicated_part() IndicatedPart {
	// 1. Let fragment be document's URL's fragment.
	// 2. If fragment is the empty string, return the special value top of the document.
	fragment := d.url.fragment() or {
		return IndicatedPart{.top_of_document, unsafe { nil }}
	}
	if fragment.len == 0 {
		return IndicatedPart{.top_of_document, unsafe { nil }}
	}

	// 3. Let potentialIndicatedElement be the result of finding a potential indicated element
	//    given document and fragment.
	potential := d.find_a_potential_indicated_element(fragment)
	// 4. If potentialIndicatedElement is not null, then return potentialIndicatedElement.
	if potential != unsafe { nil } {
		return IndicatedPart{.element, potential}
	}

	// 5-6. Let fragmentBytes be the result of percent-decoding fragment.
	//      Let decodedFragment be the result of running UTF-8 decode without BOM on fragmentBytes.
	decoded_fragment := url_percent_decode(fragment)

	// 7. Set potentialIndicatedElement to the result of finding a potential indicated element
	//    given document and decodedFragment.
	potential2 := d.find_a_potential_indicated_element(decoded_fragment)
	// 8. If potentialIndicatedElement is not null, then return potentialIndicatedElement.
	if potential2 != unsafe { nil } {
		return IndicatedPart{.element, potential2}
	}

	// 9. If decodedFragment is an ASCII case-insensitive match for the string top,
	//    then return the top of the document.
	if to_ascii_lowercase(decoded_fragment) == 'top' {
		return IndicatedPart{.top_of_document, unsafe { nil }}
	}

	// 10. Return null.
	return IndicatedPart{.none_, unsafe { nil }}
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#find-a-potential-indicated-element
// C++: Element* Document::find_a_potential_indicated_element(FlyString const& fragment) const
pub fn (d &Document) find_a_potential_indicated_element(fragment string) &Element {
	// 1. If there is an element in the document tree whose root is document and that
	//    has an ID equal to fragment, then return the first such element in tree order.
	if el := d.get_element_by_id(fragment) {
		return el
	}
	// 2. If there is an a element in the document tree whose root is document that has
	//    a name attribute whose value is equal to fragment, then return the first such
	//    element in tree order.
	if element_with_name := find_anchor_with_name_in_subtree(unsafe { &Node(d) }, fragment) {
		return element_with_name
	}

	// 3. Return null.
	return unsafe { nil }
}

fn find_anchor_with_name_in_subtree(node &Node, fragment string) ?&Element {
	for child in node.children {
		if element := child.as_element() {
			if is_html_element_with_local_name(element, 'a') {
				if name := element.get_attribute('name') {
					if name == fragment {
						return element
					}
				}
			}
		}
		if found := find_anchor_with_name_in_subtree(child, fragment) {
			return found
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#document-write-steps
// C++: WebIDL::ExceptionOr<void> Document::run_the_document_write_steps(...)
pub fn (mut d Document) run_the_document_write_steps(text []TrustedHTMLOrString, line_feed AddLineFeed, sink InjectionSink) ! {
	// 1. Let string be the empty string.
	mut sb := strings.new_builder(256)

	// 2. Let isTrusted be false if text contains a string; otherwise true.
	mut is_trusted := true
	for value in text {
		if value is string {
			is_trusted = false
			break
		}
	}

	// 3. For each value of text, append either the TrustedHTML object's
	// associated data or the string itself.
	for value in text {
		match value {
			TrustedHTMLValue { sb.write_string(value.data) }
			string { sb.write_string(value) }
		}
	}

	// 4. If isTrusted is false, set string to the result of invoking the Get Trusted Type compliant string algorithm
	//    with TrustedHTML, this's relevant global object, string, sink, and "script".
	if !is_trusted {
		compliant_string := d.trusted_types_compliant_html(sb.str(), match sink {
			.document_writeln { 'document-writeln' }
			.document_write { 'document-write' }
		})!
		sb = strings.new_builder(compliant_string.len + 1)
		sb.write_string(compliant_string)
	}

	// 5. If lineFeed is true, append U+000A LINE FEED to string.
	if line_feed == .yes {
		sb.write_u8(0x0A)
	}

	// 6. If document is an XML document, then throw an "InvalidStateError" DOMException.
	if d.type_ == .xml {
		return error('InvalidStateError: write() called on XML document')
	}

	// 7. If document's throw-on-dynamic-markup-insertion counter is greater than 0, throw.
	if d.throw_on_dynamic_markup_insertion_counter > 0 {
		return error('InvalidStateError: throw-on-dynamic-markup-insertion-counter > 0')
	}

	// 8. If document's active parser was aborted is true, then return.
	if d.active_parser_was_aborted {
		return
	}

	// 9. If the insertion point is undefined, then:
	if d.parser == unsafe { nil } || !d.parser.is_insertion_point_defined() {
		// 1. If document's unload counter > 0 or ignore-destructive-writes counter > 0, return.
		if d.unload_counter > 0 || d.ignore_destructive_writes_counter > 0 {
			return
		}
		// 2. Run the document open steps with document.
		d.open_document() or { return err }
	}

	// 10. Insert string into the input stream just before the insertion point.
	if d.parser != unsafe { nil } {
		d.parser.insert_input_at_insertion_point(sb.str())
	}

	// 11. If document's pending parsing-blocking script is null, have the HTML parser
	//     process string, one code point at a time, processing resulting tokens as they are emitted, and stopping when
	//     the tokenizer reaches the insertion point or when the processing of the tokenizer is aborted by the tree
	//     construction stage (this can happen if a script end tag token is emitted by the tokenizer).
	if !d.has_pending_parsing_blocking_script() {
		if d.parser != unsafe { nil } {
			d.parser.run_until_insertion_point()
		}
	}
}

// C++: GC::Ref<HTML::HTMLScriptElement> Document::take_pending_parsing_blocking_script(...)
pub fn (mut d Document) take_pending_parsing_blocking_script() &HTMLScriptElement {
	script := d.pending_parsing_blocking_script
	d.pending_parsing_blocking_script = unsafe { nil }
	return script
}

pub fn (mut d Document) take_pending_parsing_blocking_svg_script() &SVGScriptElement {
	script := d.pending_parsing_blocking_svg_script
	d.pending_parsing_blocking_svg_script = unsafe { nil }
	return script
}

// C++: Vector<...> Document::take_scripts_to_execute_when_parsing_has_finished(...)
pub fn (mut d Document) take_scripts_to_execute_when_parsing_has_finished() []&HTMLScriptElement {
	result := d.scripts_to_execute_when_parsing_has_finished.clone()
	d.scripts_to_execute_when_parsing_has_finished.clear()
	return result
}

// C++: Vector<...> Document::take_scripts_to_execute_as_soon_as_possible(...)
pub fn (mut d Document) take_scripts_to_execute_as_soon_as_possible() []&HTMLScriptElement {
	result := d.scripts_to_execute_as_soon_as_possible.clone()
	d.scripts_to_execute_as_soon_as_possible.clear()
	return result
}

// C++: Vector<...> Document::take_scripts_to_execute_in_order_as_soon_as_possible(...)
pub fn (mut d Document) take_scripts_to_execute_in_order_as_soon_as_possible() []&HTMLScriptElement {
	result := d.scripts_to_execute_in_order_as_soon_as_possible.clone()
	d.scripts_to_execute_in_order_as_soon_as_possible.clear()
	return result
}

// https://www.w3.org/TR/css-transitions-2/#event-dispatch
// C++: void Document::dispatch_events_for_transition(GC::Ref<CSS::CSSTransition> transition)
// https://drafts.csswg.org/css-transitions-2/#event-dispatch
pub fn (mut d Document) dispatch_events_for_transition(transition &Animation) {
	hook := d.css_animation_event_hook_ or { return }
	if hook.dispatch != unsafe { nil } {
		hook.dispatch(hook.target, &d, transition)
	}
}

// https://www.w3.org/TR/css-animations-2/#event-dispatch
// C++: void Document::dispatch_events_for_animation_if_necessary(GC::Ref<Animations::Animation> animation)
pub fn (mut d Document) dispatch_events_for_animation_if_necessary(animation &Animation) {
	if animation.concrete_kind_ == .css_transition {
		d.dispatch_events_for_transition(animation)
		return
	}
	hook := d.css_animation_event_hook_ or { return }
	if hook.dispatch != unsafe { nil } {
		hook.dispatch(hook.target, &d, animation)
	}
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#unload-a-document-and-its-descendants
// C++: void Document::unload_a_document_and_its_descendants(...)
pub fn (mut d Document) unload_a_document_and_its_descendants(new_document ?&Document) {
	// 2. Let childNavigables be document's child navigables.
	child_navigables := d.document_tree_child_navigables()

	// 4. For each childNavigable of childNavigables, queue a global task to:
	for child_nav in child_navigables {
		// 1-2. Unload the child's active document and its descendants, then increment counter.
		if active_doc := child_nav.active_document() {
			mut mutable_active_document := unsafe { &Document(active_doc) }
			mutable_active_document.unload_a_document_and_its_descendants(none)
		}
	}

	// 6. Queue a global task to:
	// 2. Unload document, passing along newDocument if it is not null.
	d.unload_with_replacement(new_document)
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#destroy-a-document-and-its-descendants
// C++: void Document::destroy_a_document_and_its_descendants(...)
pub fn (mut d Document) destroy_a_document_and_its_descendants() {
	// 1. If document is not fully active, then:
	if !d.is_fully_active() {
		// 2. Make document unsalvageable given document and reason.
		d.make_unsalvageable('masked')
	}

	// 2. Let childNavigables be document's child navigables.
	child_navigables := d.document_tree_child_navigables()

	// 4. For each childNavigable of childNavigables, queue a global task to:
	for child_nav in child_navigables {
		if active_doc := child_nav.active_document() {
			// 2. Destroy a document and its descendants given childNavigable's active document.
			mut mutable_active_document := unsafe { &Document(active_doc) }
			mutable_active_document.destroy_a_document_and_its_descendants()
		}
	}

	// 6. Queue a global task to:
	// 1. Destroy document.
	d.destroy()
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#abort-a-document-and-its-descendants
// C++: void Document::abort_a_document_and_its_descendants()
pub fn (mut d Document) abort_a_document_and_its_descendants() {
	// 2. Let descendantNavigables be document's descendant navigables.
	descendant_navigables := d.descendant_navigables()

	// 3. For each descendantNavigable of descendantNavigables, queue a global task to:
	for desc_nav in descendant_navigables {
		// 1. Abort descendantNavigable's active document.
		if active_doc := desc_nav.active_document() {
			mut mutable_active_document := unsafe { &Document(active_doc) }
			mutable_active_document.abort()
			// 2. If descendantNavigable's active document's salvageable is false,
			//    then set document's salvageable to false.
			if !active_doc.salvageable {
				d.salvageable = false
			}
		}
	}

	// 4. Abort document.
	d.abort()
}

// C++: void Document::queue_intersection_observer_task()
// https://www.w3.org/TR/intersection-observer/#queue-an-intersection-observer-task
pub fn (mut d Document) queue_intersection_observer_task() {
	if d.window == unsafe { nil } {
		return
	}
	// 1. If document's IntersectionObserverTaskQueued flag is set to true, return.
	if d.intersection_observer_task_queued {
		return
	}
	// 2. Set document's IntersectionObserverTaskQueued flag to true.
	d.intersection_observer_task_queued = true

	// 3. Queue a task on the IntersectionObserver task source associated with
	//    the document's event loop to notify intersection observers.
	hook := d.lifecycle_hook_ or {
		d.intersection_observer_task_queued = false
		return
	}
	if hook.queue_intersection_observer_task == unsafe { nil } {
		d.intersection_observer_task_queued = false
		return
	}
	hook.queue_intersection_observer_task(hook.target, d)
}

// https://www.w3.org/TR/intersection-observer/#notify-intersection-observers
pub fn (mut d Document) notify_intersection_observers() {
	// 1. Set document's IntersectionObserverTaskQueued flag to false.
	d.intersection_observer_task_queued = false

	// 2. Let notify list be a list of all IntersectionObservers whose root is
	// in the DOM tree of document. Construction registers each observer with
	// precisely that root document, so this registry is the notify list.
	notify_list := d.intersection_observers.clone()

	// 3. Notify each observer. The translated observer callback copies and
	// clears [[QueuedEntries]], skips an empty queue, and invokes its Web IDL
	// callback with (queue, observer).
	for observer in notify_list {
		if observer.notify != unsafe { nil } {
			observer.notify(observer.target)
		}
	}
}

// https://www.w3.org/TR/intersection-observer/#queue-an-intersectionobserverentry
// C++: void Document::queue_an_intersection_observer_entry(...)
pub fn (mut d Document) queue_an_intersection_observer_entry(observer &IntersectionObserver, time f64, root_bounds Rect, bounding_client_rect Rect, intersection_rect Rect, is_intersecting bool, intersection_ratio f64, target &Element) {
	// 1. Construct an IntersectionObserverEntry, passing in time, rootBounds,
	//    boundingClientRect, intersectionRect, isIntersecting, and target.
	// 2. Append it to observer's internal [[QueuedEntries]] slot.
	observer.queue_entry(time, root_bounds, bounding_client_rect, intersection_rect, is_intersecting, intersection_ratio, target)
	// 3. Queue an intersection observer task for document.
	d.queue_intersection_observer_task()
}

// C++: JS::Value Document::named_item_value(FlyString const& name) const
// https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem
pub fn (d &Document) named_item_value(name string) DocumentNamedItemResult {
	// 1. Let elements be the list of named elements with the name name that
	//    are in a document tree with the Document as their root.
	// NOTE: There will be at least one such element.
	elements := named_elements_with_name(d, name)

	// 2. If elements has only one element, and that element is an iframe element,
	//    and that iframe element's content navigable is not null, then return the
	//    active WindowProxy of the element's content navigable.
	if elements.len == 1 && elements[0].is_html_element() && elements[0].local_name() == 'iframe' {
		if proxy := elements[0].as_node().active_window_proxy() {
			return DocumentNamedItemResult{
				window_proxy: proxy
			}
		}
	}

	// 3. Otherwise, if elements has only one element, return that element.
	if elements.len == 1 {
		return DocumentNamedItemResult{
			element: elements[0]
		}
	}

	// 4. Otherwise return an HTMLCollection rooted at the Document node, whose filter matches only named elements with the name name.
	return DocumentNamedItemResult{
		collection: HTMLCollection.create(unsafe { &ParentNode(d) }, .descendants, fn [name] (element &Element) bool {
			return is_named_element_with_name(element, name)
		}, never_sort_elements)
	}
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-parsehtmlunsafe
// C++: WebIDL::ExceptionOr<GC::Root<DOM::Document>> Document::parse_html_unsafe(JS::VM& vm, ...)
//
// C++ obtains `associated_document` from the current realm's Window. V keeps
// that realm boundary explicit so this algorithm still uses the caller's
// Trusted Types policy, HTML parser, and origin.
pub fn Document.parse_html_unsafe(associated_document &Document, html string) !&Document {
	// FIXME: update description once https://github.com/whatwg/html/issues/11778 gets solved
	// 1. Let compliantHTML to the result of invoking the Get Trusted Type compliant string algorithm with
	//    TrustedHTML, this's relevant global object, html, "Document parseHTMLUnsafe", and "script".
	compliant_html := associated_document.trusted_types_compliant_html(html, 'document-parse-html-unsafe')!

	// 2. Let document be a new Document, whose content type is "text/html".
	mut doc := Document.create_for_fragment_parsing()
	doc.set_content_type('text/html')
	if hook := associated_document.html_fragment_parsing_hook() {
		doc.set_html_fragment_parsing_hook(hook)
	}

	// 3. Set document's allow declarative shadow roots to true.
	doc.set_allow_declarative_shadow_roots(true)

	// 4. Parse HTML from a string given document and compliantHTML.
	doc.parse_html_from_a_string(compliant_html)

	// AD-HOC: Setting the origin to match that of the associated document matches the behavior of existing browsers.
	doc.set_origin(associated_document.origin())

	// 5. Return document.
	return doc
}

pub fn parse_html_unsafe(associated_document &Document, html string) !&Document {
	return Document.parse_html_unsafe(associated_document, html)
}

// C++: GC::Ref<CSS::FontFaceSet> Document::adopted_style_sheets() const
pub fn (d &Document) adopted_style_sheets() []&CSSStyleSheet {
	return d.adopted_style_sheets
}

// https://fullscreen.spec.whatwg.org/#fullscreen-an-element
// C++: void Document::fullscreen_element_within_doc(GC::Ref<Element> element)
pub fn (mut d Document) fullscreen_element_within_doc(mut element Element) {
	// Steps 1-3 are HTML's popover algorithms. The HTML module installs the
	// callback because DOM cannot import HTMLElement's algorithm implementation.
	if hook := d.fullscreen_hook_ {
		if hook.hide_popovers != unsafe { nil } {
			hook.hide_popovers(hook.target, d, &element)
		}
	}

	// 4-6. Set the element's fullscreen flag, then move it to the top of the top layer.
	element.set_fullscreen_flag(true)
	d.remove_an_element_from_the_top_layer_immediately(element)
	d.add_an_element_to_the_top_layer(element)
}

// https://fullscreen.spec.whatwg.org/#collect-documents-to-unfullscreen
// C++: GC::Ref<GC::HeapVector<GC::Ref<Document>>> Document::collect_documents_to_unfullscreen()
pub fn (d &Document) collect_documents_to_unfullscreen() []&Document {
	// 1. Let docs be an ordered set consisting of doc.
	mut docs := [unsafe { &Document(d) }]

	// 2. While true:
	for {
		// 1. Let lastDoc be docs's last document.
		last_doc := docs.last()

		// 2. Assert: lastDoc's fullscreen element is not null.
		// 3. If lastDoc is not a simple fullscreen document, break.
		if !last_doc.is_simple_fullscreen_document() {
			break
		}

		// 4-5. Let container be lastDoc's node navigable's container; stop at the top level.
		nav := last_doc.navigable() or { break }
		container := nav.container() or { break }

		// 6. Stop when an iframe container's iframe fullscreen flag is set.
		if hook := last_doc.fullscreen_hook_ {
			if hook.container_iframe_fullscreen_flag != unsafe { nil } && hook.container_iframe_fullscreen_flag(hook.target, container) {
				break
			}
		}

		// 7. Append container's node document to docs.
		docs << container.document()
	}

	// 3. Return docs.
	return docs
}

// C++: RefPtr<Painting::DisplayList> Document::record_display_list(HTML::PaintConfig config)
pub fn (mut d Document) record_display_list() ?&DisplayList {
	phase_mark := platform.arena_phase_begin()
	defer {
		platform.arena_phase_end('display_list', phase_mark)
	}
	return d.record_display_list_for_viewport(false)
}

// Native windows consume only their current viewport. Ordinary callers keep
// the complete display list, including when they record after a native frame.
pub fn (mut d Document) record_viewport_display_list() ?&DisplayList {
	return d.record_display_list_for_viewport(true)
}

pub fn (d &Document) recording_viewport_only() bool {
	return d.recording_viewport_only_
}

fn (mut d Document) record_display_list_for_viewport(viewport_only bool) ?&DisplayList {
	mut allocations := d.enter_native_storage()
	defer { allocations.finish() }
	if d.cached_display_list_ != unsafe { nil }
		&& d.cached_display_list_viewport_only_ == viewport_only {
		return d.cached_display_list_
	}

	d.update_paint_and_hit_testing_properties_if_needed()

	paintable := d.paintable_box() or { return none }
	d.recording_viewport_only_ = viewport_only
	defer { d.recording_viewport_only_ = false }
	display_list := paintable.record_display_list() or { return none }
	d.cached_display_list_ = display_list
	d.cached_display_list_viewport_only_ = viewport_only
	return display_list
}

// C++: void Document::run_csp_initialization() const
// https://w3c.github.io/webappsec-csp/#run-document-csp-initialization
pub fn (d &Document) run_csp_initialization() {
	// 1. Execute every directive's initialization algorithm on this Document.
	hook := d.csp_hook_ or { return }
	if hook.initialize != unsafe { nil } {
		hook.initialize(hook.target, d)
	}
}

// C++: ElementByIdMap& Document::element_by_id() const
pub fn (d &Document) element_by_id_map() &ElementByIdMap {
	mut document := unsafe { &Document(d) }
	if document.element_by_id_map_ == unsafe { nil } {
		document.element_by_id_map_ = &ElementByIdMap{}
	}
	return document.element_by_id_map_
}

pub fn (d &Document) element_by_id(id string) ?&Element {
	document_node := unsafe { &Node(d) }
	if element := d.element_by_id_map().get(id, document_node) {
		return element
	}
	return none
}

// C++: Optional<Vector<CSS::Parser::ComponentValue>> Document::environment_variable_value(...)
pub fn (d &Document) environment_variable_value(variable EnvironmentVariable) ?string {
	return match variable {
		.safe_area_inset_top, .safe_area_inset_bottom, .safe_area_inset_left, .safe_area_inset_right, .safe_area_max_inset_top, .safe_area_max_inset_bottom, .safe_area_max_inset_left, .safe_area_max_inset_right {
			// Upstream returns a zero CSS-pixel dimension until display-shape safe areas are exposed.
			'0px'
		}
		.preferred_text_scale {
			// Upstream returns the number 1 until the user preference is exposed.
			'1'
		}

		// Viewport segment variables are currently undefined upstream unless the host exposes
		// multiple viewport segments. `none` keeps them on the substitution failure path.
		else {
			none
		}
	}
}

// C++: HashMap<FlyString, CSS::CustomPropertyRegistration>& Document::registered_property_set()
pub fn (d &Document) registered_property_set() map[string]CustomPropertyRegistration {
	return d.registered_property_set
}

// C++: NonnullRefPtr<CSS::StyleValue const> Document::custom_property_initial_value(FlyString const& name) const
pub fn (d &Document) custom_property_initial_value(name string) ?string {
	// Check if property is registered
	if reg := d.registered_property_set[name] {
		return reg.initial_value
	}
	// Check cached properties from CSS @property rules
	if reg := d.cached_registered_properties_from_css_property_rules[name] {
		return reg.initial_value
	}
	// For non-registered properties, the initial value is the guaranteed-invalid value.
	return none
}

pub fn (d &Document) custom_property_registration_generation() u64 {
	return d.custom_property_registration_generation_
}

pub fn (mut d Document) did_change_custom_property_registrations() {
	d.custom_property_registration_generation_++
	mut document_node := unsafe { &Node(&d) }
	document_node.invalidate_style(.other)
}

fn custom_property_registration_initial_values_equal(left ?string, right ?string) bool {
	if left_value := left {
		right_value := right or { return false }
		return left_value == right_value
	}
	return right == none
}

fn custom_property_registration_maps_equal(left map[string]CustomPropertyRegistration, right map[string]CustomPropertyRegistration) bool {
	if left.len != right.len {
		return false
	}
	for name, left_registration in left {
		right_registration := right[name] or { return false }
		if left_registration.syntax != right_registration.syntax
			|| left_registration.inherits != right_registration.inherits
			|| !custom_property_registration_initial_values_equal(left_registration.initial_value, right_registration.initial_value) {
			return false
		}
	}
	return true
}

// C++: void Document::build_registered_properties_cache()
pub fn (mut d Document) build_registered_properties_cache() {
	previous := d.cached_registered_properties_from_css_property_rules.clone()
	d.cached_registered_properties_from_css_property_rules.clear()
	if d.style_computer != unsafe { nil } && d.style_computer.build_registered_properties_cache_callback != unsafe { nil } {
		d.style_computer.build_registered_properties_cache_callback(d.style_computer.css_handle)
	}
	if !custom_property_registration_maps_equal(previous, d.cached_registered_properties_from_css_property_rules) {
		d.did_change_custom_property_registrations()
	}
}

// C++: void Document::build_counter_style_cache()
pub fn (mut d Document) build_counter_style_cache() {
	d.registered_counter_styles.clear()
	if d.style_computer != unsafe { nil } && d.style_computer.build_counter_style_cache_callback != unsafe { nil } {
		d.style_computer.build_counter_style_cache_callback(d.style_computer.css_handle)
	}
}

// C++: void Document::ensure_cookie_version_index(URL::URL const& new_url, URL::URL const& old_url)
pub fn (mut d Document) ensure_cookie_version_index(new_url URL) {
	record := new_url.parsed() or {
		d.cookie_version_index = none
		return
	}
	new_domain := httpcookie.canonicalize_domain(&record) or {
		d.cookie_version_index = none
		return
	}
	if d.cookie_version_index != none {
		if old_record := d.url.parsed() {
			if old_domain := httpcookie.canonicalize_domain(&old_record) {
				if new_domain == old_domain {
					return
				}
			}
		}
	}
	if hook := d.cookie_client_hook_ {
		if hook.request_document_version_index != unsafe { nil } {
			hook.request_document_version_index(hook.target, d.unique_id(), new_domain)
		}
	}
	d.cookie_version_index = none
}

// These two accessors expose Document.cpp's TemporaryChange target to the CSS
// bridge. They intentionally bypass invalidation; callers restore the old slot
// immediately after comparing selector matches under the candidate state.
pub fn (d &Document) pseudo_class_state_node(pseudo_class PseudoClass) ?&Node {
	match pseudo_class {
		.hover {
			return if d.hovered_node == unsafe { nil } { none } else { d.hovered_node }
		}
		.focus, .focus_within, .focus_visible {
			return if d.focused_area == unsafe { nil } { none } else { d.focused_area }
		}
		.target {
			return if d.target_element_ == unsafe { nil } {
				none
			} else {
				d.target_element_.as_node()
			}
		}
		else {}
	}
	return none
}

pub fn (mut d Document) set_pseudo_class_state_without_invalidation(pseudo_class PseudoClass, node ?&Node) {
	new_node := node or { unsafe { nil } }
	match pseudo_class {
		.hover {
			d.hovered_node = new_node
		}
		.focus, .focus_within, .focus_visible {
			d.focused_area = new_node
		}
		.target {
			d.target_element_ = if new_node == unsafe { nil } {
				unsafe { nil }
			} else {
				new_node.as_element() or { unsafe { nil } }
			}
		}
		else {}
	}
}

// C++: void Document::invalidate_style_for_elements_affected_by_pseudo_class_change(...)
pub fn (mut d Document) invalidate_style_for_elements_affected_by_pseudo_class_change(pseudo_class PseudoClass, common_ancestor &Node, node ?&Node) {
	if hook := d.style_update_hook_ {
		if hook.invalidate_for_pseudo_class != unsafe { nil } {
			hook.invalidate_for_pseudo_class(hook.target, pseudo_class, common_ancestor, node)
		}
	}
}

// https://html.spec.whatwg.org/multipage/interaction.html#currently-focused-area-of-a-top-level-traversable
// C++: void Document::evaluate (XPath - already exists as evaluate_xpath)

// --- IndicatedPart type ---
enum IndicatedPartType {
	none_
	top_of_document
	element
}

struct IndicatedPart {
	type_   IndicatedPartType
	element &Element = unsafe { nil }
}

// --- Supporting methods used by Document algorithms ---
pub fn (si &StyleInvalidator) has_pending_invalidations() bool {
	return si.pending_invalidations.len != 0
}

// Element.needs_style_update and entire_subtree_needs_style_update are in element.v
pub fn (he &HTMLElement) unsafe_layout_node() ?&LayoutNode {
	return html_element_as_element(he).as_node().unsafe_layout_node()
}

pub fn (w &Window) location() ?&Location {
	if w.location_ == unsafe { nil } {
		return none
	}
	return w.location_
}

pub fn (io &IntersectionObserver) queue_entry(time f64, root_bounds Rect, bounding_client_rect Rect, intersection_rect Rect, is_intersecting bool, intersection_ratio f64, target &Element) {
	if io.queue_entry_ != unsafe { nil } {
		io.queue_entry_(io.target, time, root_bounds, bounding_client_rect, intersection_rect, is_intersecting, intersection_ratio, target)
	}
}

pub fn (p &Page) client_page_did_create_new_document(d &Document) {
	if p.target != unsafe { nil } && p.did_create_document_callback != unsafe { nil } {
		p.did_create_document_callback(p.target, d)
	}
}

pub fn (p &Page) client_page_did_update_resource_count(count int) {
	if p.target != unsafe { nil } && p.did_update_resource_count_callback != unsafe { nil } {
		p.did_update_resource_count_callback(p.target, count)
	}
}

pub fn (mut p Page) client_page_did_change_title(title string) {
	p.last_changed_title_ = title
	p.title_change_count_++
	if p.target != unsafe { nil } && p.did_change_title_callback != unsafe { nil } {
		p.did_change_title_callback(p.target, title)
	}
}

pub fn (p &Page) device_pixels_per_css_pixel() f64 {
	if p.target != unsafe { nil } && p.device_pixel_scale_callback != unsafe { nil } {
		return p.device_pixel_scale_callback(p.target)
	}
	return 1.0
}

pub fn (p &Page) preferred_color_scheme() string {
	if p.target != unsafe { nil } && p.preferred_color_scheme_callback != unsafe { nil } {
		return p.preferred_color_scheme_callback(p.target)
	}
	return 'auto'
}

pub fn (p &Page) user_style() ?string {
	if p.target != unsafe { nil } && p.user_style_callback != unsafe { nil } {
		return p.user_style_callback(p.target)
	}
	return none
}

pub fn (p &Page) client_page_did_allocate_backing_stores(front_id int, back_id int) {
	if p.target != unsafe { nil } && p.did_allocate_backing_stores_callback != unsafe { nil } {
		p.did_allocate_backing_stores_callback(p.target, front_id, back_id)
	}
}

pub fn (p &Page) client_page_did_request_external_url(url string, initiator_origin string, has_transient_activation bool) {
	if p.target != unsafe { nil } && p.did_request_external_url_callback != unsafe { nil } {
		p.did_request_external_url_callback(p.target, url, initiator_origin, has_transient_activation)
	}
}

pub fn (p &Page) client_page_did_update_editing_history_state(can_undo bool, can_redo bool) {
	if p.target != unsafe { nil } && p.did_update_editing_history_callback != unsafe { nil } {
		p.did_update_editing_history_callback(p.target, can_undo, can_redo)
	}
}

pub fn (p &Page) client_request_frame() {
	if p.target != unsafe { nil } && p.request_frame_callback != unsafe { nil } {
		p.request_frame_callback(p.target)
	}
}

pub fn (p &Page) client_has_rendering_opportunity() bool {
	if p.has_rendering_opportunity_callback == unsafe { nil } {
		return false
	}
	return p.has_rendering_opportunity_callback(p.target)
}

pub fn (p &Page) client_will_begin_rendering_update() {
	if p.will_begin_rendering_update_callback != unsafe { nil } {
		p.will_begin_rendering_update_callback(p.target)
	}
}

pub fn (p &Page) client_did_finish_rendering_update() {
	if p.did_finish_rendering_update_callback != unsafe { nil } {
		p.did_finish_rendering_update_callback(p.target)
	}
}

pub fn (p &Page) local_root_navigable() ?&Navigable {
	if p.local_root_navigable_callback == unsafe { nil } {
		return none
	}
	return p.local_root_navigable_callback(p.target)
}

pub fn (p &Page) find_from_window(query string) bool {
	if p.find_from_window_callback == unsafe { nil } { return false }
	return p.find_from_window_callback(p.target, query)
}

pub fn (p &Page) has_media_element_playing_audio(document &Document) bool {
	if p.target == unsafe { nil } || p.has_media_element_playing_audio_callback == unsafe { nil } {
		return false
	}
	return p.has_media_element_playing_audio_callback(p.target, document)
}

pub fn (p &Page) media_element_audio_state_changed(document &Document, media_id UniqueNodeID, playing bool) {
	if p.target != unsafe { nil } && p.media_element_audio_state_changed_callback != unsafe { nil } {
		p.media_element_audio_state_changed_callback(p.target, document, media_id, playing)
	}
}

pub fn (p &Page) client_page_did_change_audio_play_state(playing bool) {
	if p.target != unsafe { nil } && p.did_change_audio_play_state_callback != unsafe { nil } {
		p.did_change_audio_play_state_callback(p.target, playing)
	}
}

pub fn (p &Page) is_audio_muted() ?bool {
	if p.target == unsafe { nil } || p.is_audio_muted_callback == unsafe { nil } { return none }
	return p.is_audio_muted_callback(p.target)
}

pub fn (p &Page) set_audio_muted(muted bool) bool {
	if p.target == unsafe { nil } || p.set_audio_muted_callback == unsafe { nil } { return false }
	p.set_audio_muted_callback(p.target, muted)
	return true
}

pub fn (p &Page) register_actual_media_element(document &Document, id UniqueNodeID, callbacks MediaElementPageCallbacks) {
	if p.target != unsafe { nil } && p.register_actual_media_element_callback != unsafe { nil } {
		p.register_actual_media_element_callback(p.target, document, id, callbacks)
	}
}

pub fn (p &Page) unregister_actual_media_element(id UniqueNodeID) {
	if p.target != unsafe { nil } && p.unregister_actual_media_element_callback != unsafe { nil } {
		p.unregister_actual_media_element_callback(p.target, id)
	}
}

// The concrete Page callback returns its actual Page::ScreenWakeLockHandle.
pub fn (p &Page) create_screen_wake_lock_handle() ?voidptr {
	if p.target == unsafe { nil } || p.create_screen_wake_lock_handle_callback == unsafe { nil } {
		return none
	}
	handle := p.create_screen_wake_lock_handle_callback(p.target)
	if handle == unsafe { nil } { return none }
	return handle
}

pub fn (p &Page) did_request_color_picker(input_target string, current_color string) {
	if p.target != unsafe { nil } && p.did_request_color_picker_callback != unsafe { nil } {
		p.did_request_color_picker_callback(p.target, input_target, current_color)
	}
}

pub fn (p &Page) did_request_file_picker(input_target string, filter string, multiple bool) {
	if p.target != unsafe { nil } && p.did_request_file_picker_callback != unsafe { nil } {
		p.did_request_file_picker_callback(p.target, input_target, filter, multiple)
	}
}

pub fn (p &Page) last_changed_title() string {
	return p.last_changed_title_
}

pub fn (p &Page) title_change_count() int {
	return p.title_change_count_
}

pub fn (d &Document) get_element_by_id(id string) ?&Element {
	return d.element_by_id(id)
}

fn url_percent_decode(s string) string {
	mut output := []u8{cap: s.len}
	mut index := 0
	for index < s.len {
		if s[index] == `%` && index + 2 < s.len {
			if high := hex_digit_value(s[index + 1]) {
				if low := hex_digit_value(s[index + 2]) {
					output << u8((high << 4) | low)
					index += 3
					continue
				}
			}
		}
		output << s[index]
		index++
	}
	return output.bytestr()
}

fn hex_digit_value(ch u8) ?u8 {
	if ch >= `0` && ch <= `9` {
		return u8(ch - `0`)
	}
	if ch >= `A` && ch <= `F` {
		return u8(ch - `A` + 10)
	}
	if ch >= `a` && ch <= `f` {
		return u8(ch - `a` + 10)
	}
	return none
}

// --- is_a_registrable_domain_suffix_of_or_is_equal_to (free function) ---
pub fn is_a_registrable_domain_suffix_of_or_is_equal_to(host_suffix_string string, original_host string) bool {
	if host_suffix_string == '' {
		return false
	}
	host_suffix := liburl.parse_host(host_suffix_string, false) or { return false }
	original := liburl.parse_host(original_host, false) or { return false }
	if host_suffix == original {
		return true
	}
	if !host_suffix.is_domain() || !original.is_domain() {
		return false
	}
	host_suffix_domain := host_suffix as string
	original_domain := original as string
	prefixed_host_suffix := '.' + host_suffix_domain
	if !original_domain.ends_with(prefixed_host_suffix) {
		return false
	}
	if host_suffix.public_suffix() or { '' } == host_suffix_domain {
		return false
	}
	original_public_suffix := original.public_suffix() or { return false }
	if original_public_suffix.ends_with(prefixed_host_suffix) {
		return false
	}
	return true
}
