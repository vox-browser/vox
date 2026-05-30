// Copyright (c) 2018-2025, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2021-2023, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2021-2026, Sam Atkins <sam@ladybird.org>
// Copyright (c) 2023-2024, Shannon Booth <shannon@serenityos.org>
// Copyright (c) 2025, Jelle Raaijmakers <jelle@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause
//
// Translated from Libraries/LibWeb/DOM/Document.cpp

module dom

import strings
import time as vtime

// --- Stub types for untranslated dependencies ---

// Opaque pointer stub for types from other modules.
// In a full translation these would be proper imports.

type VoidPtr = voidptr

// Simple color representation
pub struct Color {
pub mut:
	r u8
	g u8
	b u8
	a u8
}

pub const color_transparent = Color{0, 0, 0, 0}

pub fn (c Color) alpha() u8 {
	return c.a
}

// URL stub
pub struct URL {
pub mut:
	value string
}

pub fn url_about_blank() URL {
	return URL{'about:blank'}
}

pub fn (u URL) to_string() string {
	return u.value
}

pub fn (u URL) serialize() string {
	return u.value
}

pub fn dom_url_parse(url string, base_url URL, encoding string) ?URL {
	_ = base_url
	_ = encoding
	// Stub for DOMURL::parse(url, base_url, encoding) until the URL module is ported.
	return URL{url}
}

pub fn (a URL) == (b URL) bool {
	return a.value == b.value
}

pub fn (u URL) fragment() ?string {
	// Stub: In a full implementation, this would parse and return the URL's fragment.
	// For now, return the part after '#' if present.
	idx := u.value.index_u8(`#`)
	if idx < 0 {
		return none
	}
	return u.value[idx + 1..]
}

pub fn (u URL) set_fragment(f ?string) {
	_ = f
}

// Origin stub
pub struct Origin {
pub mut:
	value string
}

pub fn origin_create_opaque() Origin {
	return Origin{'opaque'}
}

pub fn (a Origin) is_same_origin(b Origin) bool {
	return a.value == b.value
}

pub fn (a Origin) is_same_site(b Origin) bool {
	return a.value == b.value
}

pub fn (a Origin) == (b Origin) bool {
	return a.value == b.value
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
	node_type NodeType
	document_ &Document = unsafe { nil }
	parent_   &Node     = unsafe { nil }
	children  []&Node

	child_nodes_ &NodeList   = unsafe { nil }
	layout_node_ &LayoutNode = unsafe { nil }
	paintable_   &Paintable  = unsafe { nil }

	needs_layout_tree_update           bool
	child_needs_layout_tree_update     bool
	needs_style_update_                bool
	child_needs_style_update_          bool
	entire_subtree_needs_style_update_ bool
	in_editable_subtree_               bool

	unique_id_                UniqueNodeID
	registered_observer_list_ []&RegisteredObserver
	event_listener_types      []string
	assigned_slot_            ?&HTMLSlotElement
	manual_slot_assignment_   ?&HTMLSlotElement
}

// Stub for ParentNode
@[heap]
pub struct ParentNode {
	Node
pub mut:
	children_ &HTMLCollection = unsafe { nil }
}

// Element is defined in element.v

// Stub for various HTML element types
@[heap]
pub struct HTMLHtmlElement {
	Element
}

@[heap]
pub struct HTMLHeadElement {
	Element
}

@[heap]
pub struct HTMLTitleElement {
	Element
}

@[heap]
pub struct HTMLElement {
	Element
}

@[heap]
pub struct HTMLBodyElement {
	HTMLElement
}

@[heap]
pub struct HTMLBaseElement {
	HTMLElement
}

@[heap]
pub struct HTMLScriptElement {
	HTMLElement
}

@[heap]
pub struct HTMLDialogElement {
	HTMLElement
}

@[heap]
pub struct HTMLUnknownElement {
	HTMLElement
}

@[heap]
pub struct HTMLAreaElement {
	HTMLElement
}

@[heap]
pub struct HTMLAudioElement {
	HTMLElement
}

@[heap]
pub struct HTMLBRElement {
	HTMLElement
}

@[heap]
pub struct HTMLButtonElement {
	HTMLElement
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
}

@[heap]
pub struct HTMLDetailsElement {
	HTMLElement
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
}

@[heap]
pub struct HTMLFrameElement {
	HTMLElement
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
}

@[heap]
pub struct HTMLLabelElement {
	HTMLElement
}

@[heap]
pub struct HTMLLIElement {
	HTMLElement
}

@[heap]
pub struct HTMLLinkElement {
	HTMLElement
}

@[heap]
pub struct HTMLMapElement {
	HTMLElement
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
}

@[heap]
pub struct HTMLModElement {
	HTMLElement
}

@[heap]
pub struct HTMLObjectElement {
	HTMLElement
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
}

@[heap]
pub struct HTMLOutputElement {
	HTMLElement
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
}

@[heap]
pub struct HTMLQuoteElement {
	HTMLElement
}

@[heap]
pub struct HTMLSelectedContentElement {
	HTMLElement
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
}

@[heap]
pub struct HTMLTextAreaElement {
	HTMLElement
}

@[heap]
pub struct HTMLTimeElement {
	HTMLElement
}

@[heap]
pub struct HTMLTrackElement {
	HTMLElement
}

@[heap]
pub struct HTMLUListElement {
	HTMLElement
}

@[heap]
pub struct HTMLVideoElement {
	HTMLElement
}

@[heap]
pub struct SVGElement {
	Element
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
pub struct LayoutViewport {}

@[heap]
pub struct LayoutNode {}

@[heap]
pub struct SVGSVGBox {}

// Painting stubs
@[heap]
pub struct ViewportPaintable {}

@[heap]
pub struct DisplayList {}

// CSS stubs
@[heap]
pub struct StyleComputer {}

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
	is_alternate  bool
	disabled      bool
	url           string
	loading_state CSSStyleSheetLoadingState = .loaded
}

pub fn (sheet &CSSStyleSheet) loading_state_value() CSSStyleSheetLoadingState {
	return sheet.loading_state
}

@[heap]
pub struct FontFaceSet {}

@[heap]
pub struct VisualViewport {}

@[heap]
pub struct MediaQueryList {}

pub type CSSMediaQueryListMatchesCallback = fn (voidptr) bool

pub type CSSMediaQueryListEvaluateCallback = fn (voidptr) bool

pub type CSSMediaQueryListHasChangedStateCallback = fn (voidptr) bool

pub type CSSMediaQueryListSetHasChangedStateCallback = fn (voidptr, bool)

pub type CSSMediaQueryListDispatchChangeEventCallback = fn (voidptr, bool)

pub struct CSSMediaQueryListRegistration {
pub:
	target                voidptr
	matches               CSSMediaQueryListMatchesCallback             = unsafe { nil }
	evaluate              CSSMediaQueryListEvaluateCallback            = unsafe { nil }
	has_changed_state     CSSMediaQueryListHasChangedStateCallback     = unsafe { nil }
	set_has_changed_state CSSMediaQueryListSetHasChangedStateCallback  = unsafe { nil }
	dispatch_change_event CSSMediaQueryListDispatchChangeEventCallback = unsafe { nil }
}

pub struct BackgroundLayerData {}

pub struct CSSSelector {
pub mut:
	text string
}

pub struct SelectorList {
pub mut:
	selectors []CSSSelector
}

pub struct StyleScope {}

pub struct StyleValue {
pub mut:
	css_text string
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
	type_ StyleSheetIdentifierType
	url   ?string
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
	scroll_x_                 f64
	scroll_y_                 f64
	current_event_            &Event = unsafe { nil }
	last_activation_timestamp DOMHighResTimeStamp
	close_watcher_manager_    &CloseWatcherManager = unsafe { nil }
}

@[heap]
pub struct CloseWatcherManager {}

@[heap]
pub struct BrowsingContext {}

@[heap]
pub struct HTMLParser {}

@[heap]
pub struct History {
pub mut:
	index  int
	length int
	state  voidptr
}

@[heap]
pub struct Location {}

@[heap]
pub struct WindowProxy {}

@[heap]
pub struct NavigationParams {
pub mut:
	response_mime_type  string = 'text/html'
	response_body       []u8
	response_url        URL = url_about_blank()
	request_current_url ?URL
}

@[heap]
pub struct SessionHistoryEntry {
pub mut:
	url                       URL
	classic_history_api_state voidptr
}

@[heap]
pub struct SharedResourceRequest {}

@[heap]
pub struct ListOfAvailableImages {}

@[heap]
pub struct PolicyContainer {}

@[heap]
pub struct Storage {}

@[heap]
pub struct SourceSnapshotParams {}

@[heap]
pub struct Navigable {}

@[heap]
pub struct NavigableContainer {}

pub fn (nc &NavigableContainer) content_navigable() ?&Navigable {
	return none
}

// Animation stubs
@[heap]
pub struct AnimationTimeline {}

@[heap]
pub struct DocumentTimeline {}

@[heap]
pub struct Animation {}

pub struct PaintConfig {}

@[heap]
pub struct Selection {
pub mut:
	anchor_node_   &Node = unsafe { nil }
	focus_node_    &Node = unsafe { nil }
	anchor_offset_ int
	focus_offset_  int
}

// Intersection/Resize Observer stubs
@[heap]
pub struct IntersectionObserver {}

@[heap]
pub struct ResizeObserver {}

// Other stubs
@[heap]
pub struct DOMImplementation {
pub mut:
	document_ &Document = unsafe { nil }
}

@[heap]
pub struct HTMLCollection {
pub mut:
	root                    &ParentNode                  = unsafe { nil }
	scope                   HTMLCollectionScope          = .descendants
	filter                  fn (&Element) bool           = always_accept_element
	sort                    fn (&Element, &Element) bool = never_sort_elements
	cached_elements         []&Element
	cached_dom_tree_version u64
	cache_initialized       bool
}

@[heap]
pub struct HTMLAllCollection {}

@[heap]
pub struct NodeList {
pub mut:
	name_filter string
	root        &Document = unsafe { nil }
	node_root   &Node     = unsafe { nil }
	nodes       []&Node
	is_live     bool
	live_scope  LiveNodeListScope = .children
	live_filter fn (&Node) bool   = always_accept_node
}

@[heap]
pub struct NodeIterator {
pub mut:
	root                           &Node = unsafe { nil }
	reference_node_                &Node = unsafe { nil }
	pointer_before_reference_node_ bool  = true
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
	host_ &Element = unsafe { nil }
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
pub mut:
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
	mode                            ShadowRootMode
	declarative                     bool
	clonable_                       bool
	serializable_                   bool
	delegates_focus_                bool
	available_to_element_internals_ bool
	user_agent_internal_            bool
	uses_document_style_sheets_     bool
	slot_assignment_                SlotAssignmentMode = .named
	style_scope_                    StyleScope
	adopted_style_sheets_           []&CSSStyleSheet
	style_sheets_                   &StyleSheetList = unsafe { nil }
	element_by_id_                  &ElementByIdMap = unsafe { nil }
	onslotchange_                   ?&CallbackType
	slot_registry_                  &SlotRegistry = unsafe { nil }
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
	active_contenteditable_element_ &Node     = unsafe { nil }
}

@[heap]
pub struct StyleInvalidator {}

@[heap]
pub struct InputEventsTarget {}

@[heap]
pub struct Position {
pub mut:
	node_   &Node = unsafe { nil }
	offset_ int
}

@[heap]
pub struct CallbackType {
pub mut:
	handle_event      ?fn (&Event, ?&EventTarget) JSValue
	accept_node       ?fn (&Node) int
	mutation_callback ?fn ([]&MutationRecord, &MutationObserver)
}

@[heap]
pub struct ViewTransition {}

@[heap]
pub struct Page {}

@[heap]
pub struct ConsoleClient {}

@[heap]
pub struct FormAssociatedElement {}

@[heap]
pub struct ElementByIdMap {
pub mut:
	elements_by_id             map[string][]&Element
	cached_first_element_by_id map[string]&Element
}

@[heap]
pub struct Promise {}

@[heap]
pub struct AccessibilityTreeNode {
pub mut:
	value_    ?&Node
	children_ []&AccessibilityTreeNode
}

@[heap]
pub struct XPathExpression {}

@[heap]
pub struct XPathResult {}

@[heap]
pub struct XPathNSResolver {}

@[heap]
pub struct DOMRectReadOnly {}

@[heap]
pub struct Segmenter {
pub mut:
	segmented_text string
}

pub fn (s &Segmenter) clone() &Segmenter {
	return &Segmenter{
		segmented_text: s.segmented_text
	}
}

pub fn (mut s Segmenter) set_segmented_text(text string) {
	s.segmented_text = text
}

// Stub timer
@[heap]
pub struct Timer {}

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
	return &WindowProxy{}
}

// WindowProxy methods
pub fn (wp &WindowProxy) set_window(w &Window) {
	_ = w
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
	// PageTransitionEvent is not ported yet; dispatch a trusted Event with the same
	// bubbles/cancelable initialization and keep the persisted value local.
	_ = salvageable
	event := Event.create(event_name, EventInit{
		bubbles:    true
		cancelable: true
	})
	event_target_dispatch_event(unsafe { &EventTarget(w) }, event)
}

pub fn (w &Window) has_transient_activation() bool {
	return false
}

pub fn (w &Window) dispatch_popstate_event(state voidptr) {
	_ = state
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
	_ = manager
}

pub fn (w &Window) scroll_x() f64 {
	return w.scroll_x_
}

pub fn (w &Window) scroll_y() f64 {
	return w.scroll_y_
}

pub fn (mut w Window) scroll(x f64, y f64) &Promise {
	w.scroll_x_ = x
	w.scroll_y_ = y
	return &Promise{}
}

// Navigable methods
pub fn (n &Navigable) container() ?&Node {
	return none
}

pub fn (n &Node) currently_delays_the_load_event() bool {
	_ = n
	// Stub for HTML navigable container elements' load-event delaying hook.
	return false
}

pub fn (n &Navigable) active_document() ?&Document {
	return none
}

fn navigable_with_active_document(document &Document) ?&Navigable {
	_ = document
	// Stub for HTML::Navigable::navigable_with_active_document until navigables are ported.
	return none
}

pub fn (n &Navigable) parent() ?&Navigable {
	return none
}

pub fn (n &Navigable) traversable_navigable() ?&Navigable {
	return none
}

pub fn (n &Navigable) container_document() ?&Document {
	return none
}

pub fn (n &Navigable) is_top_level_traversable() bool {
	return false
}

pub fn (n &Navigable) is_focused() bool {
	return false
}

pub fn (n &Navigable) system_visibility_state() VisibilityState {
	return .visible
}

// History methods
pub fn (h &History) set_state(state voidptr) {
	_ = state
}

// SessionHistoryEntry methods/fields
pub fn (she &SessionHistoryEntry) get_classic_history_api_state() voidptr {
	return unsafe { nil }
}

// HTMLParser methods
pub fn (p &HTMLParser) abort() {}

pub fn (p &HTMLParser) feed(text string) {
	_ = text
}

pub fn (p &HTMLParser) run() {}

fn html_parser_script_nesting_level_stub(parser &HTMLParser) int {
	_ = parser
	// Stub for HTMLParser::script_nesting_level() until the parser nesting state is ported.
	return 0
}

fn html_parser_insertion_point_is_defined_stub(parser &HTMLParser) bool {
	_ = parser
	// Stub for HTMLParser::tokenizer().is_insertion_point_defined().
	return true
}

fn html_parser_update_insertion_point_stub(parser &HTMLParser) {
	_ = parser
	// Stub for HTMLParser::tokenizer().update_insertion_point().
}

fn html_parser_insert_input_at_insertion_point_stub(parser &HTMLParser, input string) {
	parser.feed(input)
}

fn html_parser_run_until_insertion_point_stub(parser &HTMLParser) {
	// Stub for HTMLParser::run(HTMLTokenizer::StopAtInsertionPoint::Yes).
	parser.run()
}

fn html_parser_insert_eof_stub(parser &HTMLParser) {
	_ = parser
	// Stub for HTMLParser::tokenizer().insert_eof().
}

// ViewTransition methods
pub fn (vt &ViewTransition) phase() ViewTransitionPhase {
	return .done
}

pub fn (vt &ViewTransition) setup_view_transition() {}

pub fn (vt &ViewTransition) handle_transition_frame() {}

pub fn (vt &ViewTransition) skip_the_view_transition() {}

pub enum ViewTransitionPhase {
	pending_capture
	animating
	done
}

// MediaQueryList methods
pub fn (mql &MediaQueryList) matches() bool {
	return false
}

pub fn (mql &MediaQueryList) evaluate() bool {
	return false
}

pub fn (mql &MediaQueryList) dispatch_change_event(matches bool) {
	_ = matches
}

// CSSStyleSheet methods
pub fn (ss &CSSStyleSheet) source_text() ?string {
	return none
}

// StyleSheetList methods
pub fn (ssl &StyleSheetList) get_sheets() []&CSSStyleSheet {
	return []
}

// ViewportPaintable methods
pub fn (vp &ViewportPaintable) set_needs_to_refresh_scroll_state(b bool) {
	_ = b
}

pub fn (vp &ViewportPaintable) recompute_selection_states(range &Range) {
	_ = vp
	_ = range
}

pub fn (vp &ViewportPaintable) set_needs_repaint() {
	_ = vp
}

pub fn (vp &ViewportPaintable) invalidate_all_paint_caches() {}

pub fn (vp &ViewportPaintable) record_display_list() ?&DisplayList {
	return none
}

pub fn (vp &ViewportPaintable) build_stacking_context_tree_if_needed() {}

pub fn (vp &ViewportPaintable) stacking_context() ?&StackingContext {
	return none
}

pub fn (vp &ViewportPaintable) hit_test(x f64, y f64, type_ HitTestType) ?HitTestResult {
	return none
}

pub fn (vp &ViewportPaintable) hit_test_all(x f64, y f64, mut results []&Element) {}

pub struct HitTestResult {
pub:
	element &Element = unsafe { nil }
}

fn layout_retarget_from_ua_internal_shadow_root_stub(element &Element) &Element {
	// Stub for retarget_from_ua_internal_shadow_root().
	return element
}

pub enum HitTestType {
	exact
	text_cursor
}

@[heap]
pub struct StackingContext {}

pub fn (sc &StackingContext) dump() string {
	return ''
}

// DisplayList methods
pub fn (dl &DisplayList) dump() string {
	return ''
}

// IntersectionObserver methods
pub fn (io &IntersectionObserver) observation_targets() []&Element {
	return []
}

pub fn (io &IntersectionObserver) observe(element &Element) {
	_ = element
}

pub fn (io &IntersectionObserver) unobserve(element &Element) {
	_ = element
}

// ResizeObserver methods
pub fn (ro &ResizeObserver) observation_targets() []&ResizeObservation {
	return []
}

pub fn (ro &ResizeObserver) active_targets() []&ResizeObservation {
	return []
}

pub fn (ro &ResizeObserver) skipped_targets() []&ResizeObservation {
	return []
}

pub fn (mut ro ResizeObserver) clear_active_targets() {}

pub fn (mut ro ResizeObserver) clear_skipped_targets() {}

pub fn (mut ro ResizeObserver) add_active_target(obs &ResizeObservation) {
	_ = obs
}

pub fn (mut ro ResizeObserver) add_skipped_target(obs &ResizeObservation) {
	_ = obs
}

pub fn (mut ro ResizeObserver) invoke_callback() {}

@[heap]
pub struct ResizeObservation {}

pub fn (ro &ResizeObservation) is_active() bool {
	return false
}

pub fn (ro &ResizeObservation) target_depth() int {
	return 0
}

// AnimationTimeline methods
pub fn (at &AnimationTimeline) update_current_time(timestamp f64) {
	_ = timestamp
}

pub fn (at &AnimationTimeline) associated_animations() []&Animation {
	return []
}

// Animation methods
pub fn (a &Animation) update() {}

pub fn (a &Animation) is_replaceable() bool {
	return false
}

pub fn (a &Animation) replace_state() AnimationReplaceState {
	return .active
}

pub fn (a &Animation) effect() ?&AnimationEffect {
	return none
}

pub enum AnimationReplaceState {
	active
	removed
	persisted
}

@[heap]
pub struct AnimationEffect {}

pub fn (ae &AnimationEffect) target() ?&Element {
	return none
}

// FormAssociatedElement methods
pub fn (fae &FormAssociatedElement) element_id_changed() {}

pub fn (fae &FormAssociatedElement) element_with_id_was_added_or_removed() {}

// Selection methods
pub fn (s &Selection) cursor_position() ?&Position {
	if s.focus_node_ == unsafe { nil } {
		return none
	}
	return Position.create(s.focus_node_, s.focus_offset_)
}

pub fn (s &Selection) is_collapsed() bool {
	return s.anchor_node_ == s.focus_node_ && s.anchor_offset_ == s.focus_offset_
}

pub fn (s &Selection) anchor_node() ?&Node {
	if s.anchor_node_ == unsafe { nil } {
		return none
	}
	return s.anchor_node_
}

pub fn (s &Selection) focus_node() ?&Node {
	if s.focus_node_ == unsafe { nil } {
		return none
	}
	return s.focus_node_
}

pub fn (s &Selection) anchor_offset() int {
	return s.anchor_offset_
}

pub fn (s &Selection) focus_offset() int {
	return s.focus_offset_
}

pub fn (mut s Selection) collapse(node &Node, offset int) ! {
	if offset < 0 || offset > node.length() {
		return error('IndexSizeError: Selection offset is out of range')
	}
	s.anchor_node_ = node
	s.focus_node_ = node
	s.anchor_offset_ = offset
	s.focus_offset_ = offset
}

pub fn (mut s Selection) set_base_and_extent(anchor_node &Node, anchor_offset int, focus_node &Node, focus_offset int) ! {
	if anchor_offset < 0 || anchor_offset > anchor_node.length() {
		return error('IndexSizeError: Selection anchor offset is out of range')
	}
	if focus_offset < 0 || focus_offset > focus_node.length() {
		return error('IndexSizeError: Selection focus offset is out of range')
	}
	s.anchor_node_ = anchor_node
	s.anchor_offset_ = anchor_offset
	s.focus_node_ = focus_node
	s.focus_offset_ = focus_offset
}

pub fn (mut s Selection) move_offset_by(delta int, collapse_to_focus bool) {
	if s.focus_node_ == unsafe { nil } {
		return
	}
	max_offset := s.focus_node_.length()
	mut new_offset := s.focus_offset_ + delta
	if new_offset < 0 {
		new_offset = 0
	}
	if new_offset > max_offset {
		new_offset = max_offset
	}
	s.focus_offset_ = new_offset
	if collapse_to_focus {
		s.anchor_node_ = s.focus_node_
		s.anchor_offset_ = s.focus_offset_
	}
}

pub fn (mut s Selection) move_offset_to_next_character(collapse_to_focus bool) {
	s.move_offset_by(1, collapse_to_focus)
}

pub fn (mut s Selection) move_offset_to_previous_character(collapse_to_focus bool) {
	s.move_offset_by(-1, collapse_to_focus)
}

pub fn (mut s Selection) move_offset_to_next_word(collapse_to_focus bool) {
	s.move_offset_to_next_character(collapse_to_focus)
}

pub fn (mut s Selection) move_offset_to_previous_word(collapse_to_focus bool) {
	s.move_offset_to_previous_character(collapse_to_focus)
}

pub fn (mut s Selection) move_offset_to_next_line(collapse_to_focus bool) {
	s.move_offset_to_next_character(collapse_to_focus)
}

pub fn (mut s Selection) move_offset_to_previous_line(collapse_to_focus bool) {
	s.move_offset_to_previous_character(collapse_to_focus)
}

pub fn (s &Selection) scroll_focus_into_view() {
	_ = s
}

// Timer methods
pub fn (t &Timer) start() {}

pub fn (t &Timer) restart() {}

// NodeList extra fields
pub fn (nl &NodeList) items() []&Node {
	return nl.collection()
}

// NodeIterator/TreeWalker extra fields (adding to constructors above)

// Origin methods
pub fn (o &Origin) effective_domain() ?string {
	if o.value == 'opaque' {
		return none
	}
	return o.value
}

// Document helper methods referenced by implementations
pub fn (d &Document) paintable_box() ?&ViewportPaintable {
	return d.paintable()
}

pub fn (d &Document) viewport_rect() Rect {
	return Rect{0, 0, 800, 600}
}

pub fn (d &Document) navigable() ?&Navigable {
	if d.cached_navigable_ == unsafe { nil } {
		return none
	}
	return d.cached_navigable_
}

pub fn (d &Document) in_quirks_mode() bool {
	return d.quirks_mode == .yes
}

pub fn (d &Document) for_each_shadow_including_descendant(callback fn (&Node) TraversalDecision) TraversalDecision {
	document_node := unsafe { &Node(d) }
	return document_node.for_each_shadow_including_descendant(callback)
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

pub fn (mut d Document) evaluate_media_rules() {}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#unloading-document-cleanup-steps
pub fn (mut d Document) run_unloading_cleanup_steps() {}

pub fn (mut d Document) set_needs_repaint() {
	d.needs_repaint = true
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

// Editing stub
pub fn editing_exec_command(d &Document, command string, value string) bool {
	_ = d
	_ = command
	_ = value
	return false
}

// XPath stubs
pub fn xpath_create_expression(expression string, resolver ?&XPathNSResolver) !&XPathExpression {
	_ = expression
	_ = resolver
	return &XPathExpression{}
}

pub fn xpath_evaluate(expression string, context_node &Node, resolver ?&XPathNSResolver, type_ u16, result ?&XPathResult) !&XPathResult {
	_ = expression
	_ = context_node
	_ = resolver
	_ = type_
	return result or { &XPathResult{} }
}

// Viewport client stub
pub fn viewport_client_did_set_viewport_rect(client VoidPtr, viewport Rect) {
	_ = client
	_ = viewport
}

pub const max_int = 2147483647

pub enum TraversalDecision {
	@continue
	@break
}

// --- Inline stubs for html/css module functions (avoiding circular imports) ---

// html module constants
const tag_html_ = 'html'
const tag_head_ = 'head'
const tag_body_ = 'body'
const tag_div_ = 'div'
const tag_title_ = 'title'

const event_load_ = 'load'
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
	return element.namespace_uri() or { '' } == namespace_html_
		&& element.local_name() == 'frameset'
}

fn current_high_resolution_time(global_obj &Window) f64 {
	_ = global_obj
	return 0.0
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

fn relevant_agent_for_doc(doc &Document) AgentStub {
	_ = doc
	return AgentStub{
		event_loop: &EventLoopStub{}
	}
}

fn relevant_settings_object_for_win(w &Window) &EnvironmentSettingsObjectStub {
	_ = w
	return &EnvironmentSettingsObjectStub{}
}

fn relevant_realm_for_doc(doc &Document) RealmStub {
	_ = doc
	return RealmStub{}
}

fn structured_deserialize_stub(serialized voidptr, realm RealmStub, memory voidptr) ?voidptr {
	_ = serialized
	_ = realm
	_ = memory
	return none
}

fn main_thread_event_loop_stub() &EventLoopStub {
	return &EventLoopStub{}
}

fn all_navigables_stub() []&Navigable {
	return []
}

fn message_port_for_each_stub(callback fn (voidptr)) {
	_ = callback
}

fn as_navigable_container_stub(node &Node) ?&NavigableContainer {
	_ = node
	return none
}

fn html_parser_create_for_scripting_stub(doc &Document) &HTMLParser {
	_ = doc
	return &HTMLParser{}
}

@[heap]
struct RealmStub {}

struct EnvironmentSettingsObjectStub {
mut:
	execution_ready bool
}

struct AgentStub {
mut:
	event_loop &EventLoopStub = unsafe { nil }
}

@[heap]
struct EventLoopStub {
mut:
	termination_nesting_level int
}

fn (mut el EventLoopStub) increment_termination_nesting_level() {
	el.termination_nesting_level++
}

fn (mut el EventLoopStub) decrement_termination_nesting_level() {
	el.termination_nesting_level--
}

fn (el &EventLoopStub) task_queue() &TaskQueueStub {
	return &TaskQueueStub{}
}

@[heap]
struct TaskQueueStub {}

fn (tq &TaskQueueStub) remove_tasks_matching(predicate fn (&TaskStub) bool) {
	_ = predicate
}

@[heap]
struct TaskStub {
mut:
	document_ &Document = unsafe { nil }
}

fn (t &TaskStub) document() &Document {
	return t.document_
}

// css module functions
fn css_invalidate_style(doc &Document, reason CssStyleInvalidationReason) {
	_ = doc
	_ = reason
}

fn html_entry_global_associated_document_stub(document &Document) &Document {
	// Stub for the entry global object's associated Document.
	return document
}

fn html_perform_url_and_history_update_steps_stub(mut document Document, url URL) {
	// Stub for HTML::perform_url_and_history_update_steps().
	document.set_url(url)
}

fn css_user_agent_style_sheet_source(url string) ?string {
	_ = url
	return none
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
	pixelated
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
	before
	after
	first_line
	first_letter
	marker
	placeholder
	selection
}

pub enum InvalidateLayoutTreeReason {
	document_add_an_element_to_the_top_layer
	document_request_an_element_to_be_removed_from_the_top_layer
	document_immediately_remove_element_from_the_top_layer
	document_pending_top_layer_removals_processed
	shadow_root_set_inner_html
}

pub enum UpdateLayoutReason {
	auto_scroll_selection
	child_document_style_update
	debugging
	document_element_from_point
	document_elements_from_point
	document_find_matching_text
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
	encrypted_media
	focus_without_user_activation
	fullscreen
	gamepad
	window_management
}

pub struct SandboxingFlagSet {
pub mut:
	sandboxed_document_domain bool
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

// --- Supporting structs ---

pub struct DocumentLoadTimingInfo {
pub mut:
	navigation_start_time               f64
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
	is_ ?string
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
	type_   string
	bubbles bool
}

pub struct PendingAnimationEvent {
pub mut:
	event                &Event       = unsafe { nil }
	animation            &Animation   = unsafe { nil }
	target               &EventTarget = unsafe { nil }
	scheduled_event_time ?f64
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

// --- Main Document struct ---

@[heap]
pub struct Document {
	ParentNode
pub mut:
	// Core identity
	type_                      DocumentType_ = .xml
	content_type               string        = 'application/xml'
	url                        URL           = url_about_blank()
	origin_                    Origin        = origin_create_opaque()
	referrer                   string
	live_ranges_               []&Range
	custom_element_definitions []&CustomElementDefinition
	source                     string

	// Version tracking
	dom_tree_version       u64
	character_data_version u64

	// Readiness
	readiness                 DocumentReadyState = .complete
	ready_for_post_load_tasks bool
	ready_to_run_scripts      bool

	// Encoding
	encoding                    ?string
	pragma_set_default_language ?string
	http_content_language       ?string

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
	page_            &Page            = unsafe { nil }

	// Style
	style_computer                                 &StyleComputer  = unsafe { nil }
	font_computer                                  &FontComputer   = unsafe { nil }
	style_sheets_                                  &StyleSheetList = unsafe { nil }
	needs_full_style_update                        bool
	needs_full_layout_tree_update                  bool
	is_running_update_layout                       bool
	needs_animated_style_update                    bool
	needs_accumulated_visual_contexts_update       bool
	needs_invalidation_of_elements_affected_by_has bool
	should_invalidate_styles_on_attribute_changes  bool = true

	// Layout
	layout_root &LayoutViewport    = unsafe { nil }
	paintable_  &ViewportPaintable = unsafe { nil }

	// Window
	window &Window = unsafe { nil }

	// Nodes
	hovered_node               &Node = unsafe { nil }
	inspected_node             &Node = unsafe { nil }
	highlighted_node           &Node = unsafe { nil }
	highlighted_pseudo_element ?PseudoElement
	focused_area               &Node    = unsafe { nil }
	active_element_            &Element = unsafe { nil }
	target_element_            &Element = unsafe { nil }
	active_favicon             &Node    = unsafe { nil }

	// Colors
	normal_link_color_      ?Color
	active_link_color_      ?Color
	visited_link_color_     ?Color
	supported_color_schemes ?[]string

	// Focus
	last_focus_trigger FocusTrigger = .other

	// Parser
	parser                    &HTMLParser = unsafe { nil }
	active_parser_was_aborted bool

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
	inside_exec_command                        bool
	css_styling_flag                           bool
	rendering_suppression_for_view_transitions bool
	show_view_transition_tree                  bool
	has_scheduled_selectionchange_event        bool
	intersection_observer_task_queued          bool
	needs_media_query_evaluation               bool

	// Scripts
	pending_parsing_blocking_script                 &HTMLScriptElement = unsafe { nil }
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
	number_of_things_delaying_the_load_event  int

	// Template
	created_for_appropriate_template_contents    bool
	associated_inert_template_document           &Document = unsafe { nil }
	appropriate_template_contents_owner_document &Document = unsafe { nil }

	// Timing
	load_timing_info                DocumentLoadTimingInfo
	previous_document_unload_timing DocumentUnloadTimingInfo

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
	applets_ &HTMLCollection    = unsafe { nil }
	anchors_ &HTMLCollection    = unsafe { nil }
	images_  &HTMLCollection    = unsafe { nil }
	embeds_  &HTMLCollection    = unsafe { nil }
	links_   &HTMLCollection    = unsafe { nil }
	forms_   &HTMLCollection    = unsafe { nil }
	scripts_ &HTMLCollection    = unsafe { nil }
	all_     &HTMLAllCollection = unsafe { nil }
	fonts_   &FontFaceSet       = unsafe { nil }

	// Selection & Base
	selection_                                   &Selection       = unsafe { nil }
	first_base_element_with_href_in_tree_order   &HTMLBaseElement = unsafe { nil }
	first_base_element_with_target_in_tree_order &HTMLBaseElement = unsafe { nil }

	// History & Navigation
	history_     &History             = unsafe { nil }
	latest_entry &SessionHistoryEntry = unsafe { nil }

	// Policy & Sandboxing
	active_sandboxing_flag_set SandboxingFlagSet
	policy_container_          &PolicyContainer = unsafe { nil }

	// Visibility
	visibility_state VisibilityState = .hidden

	// Last modified
	last_modified_ ?string

	// Animations
	associated_animation_timelines []&AnimationTimeline
	default_timeline               &DocumentTimeline = unsafe { nil }
	last_animation_frame_timestamp ?f64
	pending_animation_event_queue  []PendingAnimationEvent
	transition_generation          int

	// Images
	list_of_available_images &ListOfAvailableImages = unsafe { nil }

	// Intersection observer
	lazy_load_intersection_observer &IntersectionObserver = unsafe { nil }

	// View transitions
	active_view_transition              &ViewTransition = unsafe { nil }
	dynamic_view_transition_style_sheet &CSSStyleSheet  = unsafe { nil }
	update_callback_queue               []&ViewTransition

	// Visual viewport
	visual_viewport_           &VisualViewport = unsafe { nil }
	last_viewport_size         ?[2]f64
	last_visual_viewport_state ?VisualViewportState

	// Pending scroll events
	pending_scroll_events []PendingScrollEvent

	// Cookie cache
	cookie_version       int = -1
	cookie_version_index ?int
	cookie_cache         string

	// Display list cache
	cached_display_list_ &DisplayList = unsafe { nil }

	// Segmenters (lazy)
	grapheme_segmenter_ &Segmenter = unsafe { nil }
	line_segmenter_     &Segmenter = unsafe { nil }
	word_segmenter_     &Segmenter = unsafe { nil }

	// Editing
	editing_host_manager_              &EditingHostManager = unsafe { nil }
	default_single_line_container_name string              = 'div'
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
	viewport_clients       []VoidPtr

	// Form associated elements
	form_associated_elements_with_form_attribute []&FormAssociatedElement
	potentially_named_elements                   []&Element
	element_by_id_map_                           &ElementByIdMap = unsafe { nil }

	// Render blocking
	render_blocking_elements        []&Element
	script_blocking_style_sheet_set []&Element
	pending_css_import_rules        []VoidPtr

	// Shadow roots
	shadow_roots []&ShadowRoot

	// Style scope & invalidator
	style_invalidator_ &StyleInvalidator = unsafe { nil }
	style_scope_       StyleScope

	// Registered properties
	registered_property_set                              map[string]CustomPropertyRegistration
	cached_registered_properties_from_css_property_rules map[string]CustomPropertyRegistration
	registered_counter_styles                            map[string]&CounterStyle

	// CSS random caching
	element_shared_css_random_base_value_cache map[string]f64

	// Selector query cache
	selector_query_cache map[string]?SelectorList

	// SVG roots needing relayout
	svg_roots_needing_relayout []&SVGSVGBox

	// Misc
	shared_resource_requests_               map[string]&SharedResourceRequest
	adopted_style_sheets                    []&CSSStyleSheet
	console_client_                         &ConsoleClient                      = unsafe { nil }
	cursor_blink_timer                      &Timer                              = unsafe { nil }
	active_refresh_timer                    &Timer                              = unsafe { nil }
	cached_navigable_                       &Navigable                          = unsafe { nil }
	temporary_document_for_fragment_parsing TemporaryDocumentForFragmentParsing = .no
	media_query_lists                       []&MediaQueryList
	css_media_query_lists                   []CSSMediaQueryListRegistration
	document_observers_being_notified       []&DocumentObserver
	// Extra fields for implementations
	implementation_            &DOMImplementation = unsafe { nil }
	location_                  &Location          = unsafe { nil }
	completely_loaded_time     bool
	pointer_lock_element       &Element = unsafe { nil }
	is_svg_document            bool
	onreadystatechange_handler &CallbackType = unsafe { nil }
	onvisibilitychange_handler &CallbackType = unsafe { nil }
	onfullscreenchange_handler &CallbackType = unsafe { nil }
	onfullscreenerror_handler  &CallbackType = unsafe { nil }
	needs_repaint              bool
}

// --- Constructor / Factory methods ---

// create_and_initialize corresponds to Document::create_and_initialize
// https://html.spec.whatwg.org/multipage/browsing-the-web.html#initialise-the-document-object
pub fn Document.create_and_initialize(type_ DocumentType_, content_type string, navigation_params &NavigationParams) !&Document {
	// Stub: in full implementation would set up browsing context, window, etc.
	_ = navigation_params
	mut doc := &Document{}
	doc.node_type = .document_node
	doc.document_ = doc
	doc.type_ = type_
	doc.content_type = content_type
	doc.readiness = .loading
	doc.initialize()
	return doc
}

// create corresponds to Document::create
pub fn Document.create(url URL) &Document {
	mut doc := &Document{}
	doc.node_type = .document_node
	doc.document_ = doc
	doc.url = url
	doc.initialize()
	return doc
}

// create_for_fragment_parsing corresponds to Document::create_for_fragment_parsing
pub fn Document.create_for_fragment_parsing() &Document {
	mut doc := &Document{}
	doc.node_type = .document_node
	doc.document_ = doc
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
	visitor.visit(d.implementation_)
	visitor.visit(d.current_script)
	visitor.visit(d.associated_inert_template_document)
	visitor.visit(d.appropriate_template_contents_owner_document)
	visitor.visit(d.pending_parsing_blocking_script)
	visitor.visit(d.history_)
	visitor.visit(d.style_computer)
	visitor.visit(d.font_computer)
	// browsing_context visited again in C++ (intentional duplicate in original)

	visitor.visit(d.applets_)
	visitor.visit(d.anchors_)
	visitor.visit(d.images_)
	visitor.visit(d.embeds_)
	visitor.visit(d.links_)
	visitor.visit(d.forms_)
	visitor.visit(d.scripts_)
	visitor.visit(d.all_)
	visitor.visit(d.fonts_)
	visitor.visit(d.selection_)
	visitor.visit(d.first_base_element_with_href_in_tree_order)
	visitor.visit(d.first_base_element_with_target_in_tree_order)
	visitor.visit(d.parser)
	visitor.visit(d.lazy_load_intersection_observer)
	visitor.visit(d.visual_viewport_)
	visitor.visit(d.latest_entry)
	visitor.visit(d.default_timeline)

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

	for tl in d.associated_animation_timelines {
		visitor.visit(tl)
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
	main_thread_event_loop_stub().unregister_document(d)
}

// https://html.spec.whatwg.org/multipage/dom.html#the-document-object
pub fn (mut d Document) initialize() {
	// Set up prototype, create selection, list of available images, etc.
	d.selection_ = &Selection{}
	d.editing_host_manager_ = EditingHostManager.create(mut d)
	d.list_of_available_images = &ListOfAvailableImages{}
	d.page_.client_page_did_create_new_document(d)
	d.ensure_cookie_version_index(d.url)
}

// --- Core property accessors ---

pub fn (d &Document) dom_tree_version() u64 {
	return d.dom_tree_version
}

pub fn (mut d Document) bump_dom_tree_version() {
	d.dom_tree_version++
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
	d.url = url
	d.respond_to_base_url_changes()
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
	if href := unsafe { &Element(base_element) }.get_attribute('href') {
		if href.len > 0 {
			return URL{href}
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

// https://html.spec.whatwg.org/multipage/urls-and-fetching.html#respond-to-base-url-changes
pub fn (mut d Document) respond_to_base_url_changes() {
	// Ensure that CSS :link/:visited pseudo-classes are updated.
	css_invalidate_style(d, .base_url_changed)
}

pub fn (mut d Document) update_base_element() {
	// Scan tree for <base> elements and update cached first-with-href / first-with-target.
	d.first_base_element_with_href_in_tree_order = unsafe { nil }
	d.first_base_element_with_target_in_tree_order = unsafe { nil }
	document_node := unsafe { &Node(&d) }
	document_node.for_each_in_subtree(fn [mut d] (node &Node) TraversalDecision {
		element := node.as_element() or { return .@continue }
		if !is_html_element_with_local_name(element, 'base') {
			return .@continue
		}
		base_element := unsafe { &HTMLBaseElement(element) }
		if d.first_base_element_with_href_in_tree_order == unsafe { nil }
			&& element.has_attribute('href') {
			d.first_base_element_with_href_in_tree_order = base_element
			if d.first_base_element_with_target_in_tree_order != unsafe { nil } {
				return .@break
			}
		}
		if d.first_base_element_with_target_in_tree_order == unsafe { nil }
			&& element.has_attribute('target') {
			d.first_base_element_with_target_in_tree_order = base_element
			if d.first_base_element_with_href_in_tree_order != unsafe { nil } {
				return .@break
			}
		}
		return .@continue
	})
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
pub fn (d &Document) cookie() !string {
	// On getting, if the document is a cookie-averse Document, return empty string.
	if d.is_cookie_averse() {
		return ''
	}
	// If Document's origin is opaque, throw SecurityError.
	if d.origin_.value == 'opaque' {
		return error('SecurityError: Document origin is opaque')
	}
	// Return the cookie-string for the document's URL.
	// Use cached version if available.
	return d.cookie_cache
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
	// Stub: in full implementation would parse cookie and send to page client
	d.cookie_cache = cookie_string
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
	return element.namespace_uri() or { '' } == namespace_html_
		&& element.local_name() == local_name
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
		is_whitespace := byte == 0x09 || byte == 0x0a || byte == 0x0c || byte == 0x0d
			|| byte == 0x20
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
	mut found := ?&HTMLTitleElement(none)
	document_node := unsafe { &Node(d) }
	document_node.for_each_in_subtree(fn [mut found] (node &Node) TraversalDecision {
		if found != none {
			return .@break
		}
		element := node.as_element() or { return .@continue }
		if is_html_element_with_local_name(element, 'title') {
			found = unsafe { &HTMLTitleElement(element) }
			return .@break
		}
		return .@continue
	})
	return found
}

// https://html.spec.whatwg.org/multipage/dom.html#the-body-element-2
pub fn (d &Document) body() ?&HTMLElement {
	// The body element is the first body or frameset child of the html element.
	html := d.html_element() or { return none }
	for child in unsafe { &Element(html) }.as_node().children {
		if element := child.as_element() {
			if is_html_element_with_local_name(element, 'body')
				|| is_html_element_with_local_name(element, 'frameset') {
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
	if !is_html_element_with_local_name(new_body_element, 'body')
		&& !is_html_element_with_local_name(new_body_element, 'frameset') {
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
				if element.namespace_uri() or { '' } == namespace_svg_uri
					&& element.local_name() == 'title' {
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
	if document_element.namespace_uri() or { '' } == namespace_svg_uri
		&& document_element.local_name() == 'svg' {
		mut title_target := ?&Element(none)
		for child in document_element.as_node().children {
			if element := child.as_element() {
				if element.namespace_uri() or { '' } == namespace_svg_uri
					&& element.local_name() == 'title' {
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
			document_element_node.pre_insert(new_title.as_node(),
				document_element.as_node().first_child())!
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

pub fn (d &Document) get_page() &Page {
	return d.page_
}

// --- Colors ---

pub fn (d &Document) background_color() Color {
	// CSS2: use HTML element background, fallback to body, then transparent
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

// https://html.spec.whatwg.org/multipage/semantics.html#meta-color-scheme
pub fn (mut d Document) obtain_supported_color_schemes() {
	d.supported_color_schemes = none
	// Scan <meta name="color-scheme"> elements and parse their content attribute.
	// Stub: in full implementation would iterate subtree for HTMLMetaElement,
	// check name/content attributes, and parse CSS color-scheme value.
}

// https://html.spec.whatwg.org/multipage/semantics.html#meta-theme-color
pub fn (mut d Document) obtain_theme_color() {
	// Scan <meta name="theme-color"> elements and parse their content attribute.
	// Stub: in full implementation would iterate subtree for HTMLMetaElement,
	// check name/content/media attributes, parse CSS color value,
	// and call page().client().page_did_change_theme_color(color).
}

// --- Style ---

pub fn (mut d Document) update_style() {
	// In the C++ implementation, this runs style computation recursively through
	// the DOM tree, updating computed styles for all elements that need it.
	// It also handles style invalidation, recomputing inherited styles, and
	// tracking whether the stacking context tree needs to be rebuilt.
	if !d.needs_full_style_update && !d.needs_animated_style_update {
		return
	}
	// Stub: would call update_style_recursively on document tree,
	// then clear needs_full_style_update flag.
	d.needs_full_style_update = false
}

pub fn (mut d Document) update_animated_style_if_needed() {
	if !d.needs_animated_style_update {
		return
	}
	// Update computed properties for all animations on all timelines.
	for tl in d.associated_animation_timelines {
		// Stub: would iterate timeline's associated_animations and update effects
		_ = tl
	}
	d.needs_animated_style_update = false
}

pub fn (mut d Document) update_paint_and_hit_testing_properties_if_needed() {
	// Refresh scroll state on the paintable.
	if d.paintable_ != unsafe { nil } {
		// Stub: would call paintable_.refresh_scroll_state()
	}
	if d.needs_accumulated_visual_contexts_update {
		d.needs_accumulated_visual_contexts_update = false
		// Stub: would call paintable_.assign_accumulated_visual_contexts()
	}
}

// --- Layout ---

pub fn (mut d Document) update_layout(reason UpdateLayoutReason) {
	// This is a massive function in C++ (~200 lines) that triggers full layout computation.
	// Key steps: ensure navigable is active, update parent document layout if nested,
	// update style, build/update layout tree, perform layout, assign scroll frames,
	// update paint/hit-testing properties, recompute selection states.
	_ = reason

	if d.is_running_update_layout {
		return
	}
	d.is_running_update_layout = true

	// 1. Update style if needed
	d.update_style()
	d.update_animated_style_if_needed()

	// 2. Build/update layout tree if needed
	if d.needs_full_layout_tree_update {
		// Stub: would call build_layout_tree() or update_layout_tree()
		d.needs_full_layout_tree_update = false
	}

	// 3. Perform actual layout computation
	// Stub: would run layout algorithms on layout_root

	// 4. Update paint/hit-testing properties
	d.update_paint_and_hit_testing_properties_if_needed()

	d.is_running_update_layout = false
}

pub fn (d &Document) layout_is_up_to_date() bool {
	return !d.needs_full_style_update && !d.needs_full_layout_tree_update
}

pub fn (mut d Document) invalidate_layout_tree(reason InvalidateLayoutTreeReason) {
	_ = reason
	d.needs_full_layout_tree_update = true
}

pub fn (mut d Document) invalidate_stacking_context_tree() {
	// Invalidate the stacking context on the viewport paintable.
	// Stub: in full implementation would call paintable_box.invalidate_stacking_context()
	if d.paintable_ != unsafe { nil } {
		// paintable_.invalidate_stacking_context()
	}
}

pub fn (mut d Document) tear_down_layout_tree() {
	d.layout_root = unsafe { nil }
	d.paintable_ = unsafe { nil }
	d.needs_full_layout_tree_update = true
}

// --- Node creation ---

// https://dom.spec.whatwg.org/#dom-document-createelement
pub fn (d &Document) create_element(local_name string) !&Element {
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

	// 3. Let is be null.
	// 4. If options is a dictionary and options["is"] exists, then set is to it.
	// NOTE: This V binding does not expose ElementCreationOptions yet.

	// 5. Let namespace be the HTML namespace, if this is an HTML document or this's content type is "application/xhtml+xml"; otherwise null.
	namespace_ := if d.document_type() == .html || d.content_type == 'application/xhtml+xml' {
		?string(namespace_html_)
	} else {
		?string(none)
	}

	// 6. Return the result of creating an element given this, localName, namespace, null, is, and with the synchronous custom elements flag set.
	return create_element(d, local_name_lower, namespace_, none, none, true)!
}

// https://dom.spec.whatwg.org/#internal-createelementns-steps
pub fn (d &Document) create_element_ns(namespace_ ?string, qualified_name string) !&Element {
	// 1. Let (namespace, prefix, localName) be the result of validating and extracting namespace and qualifiedName given "element".
	extracted_qualified_name := validate_and_extract(namespace_, qualified_name, .element)!

	// 2. Let is be null.
	// 3. If options is a dictionary and options["is"] exists, then set is to it.
	// NOTE: This V binding does not expose ElementCreationOptions yet.

	// 4. Return the result of creating an element given document, localName, namespace, prefix, is, and with the synchronous custom elements flag set.
	return create_element(d, extracted_qualified_name.local_name,
		extracted_qualified_name.namespace_, extracted_qualified_name.prefix_, none, true)!
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
	return &CDATASection{
		Text: Text{
			CharacterData: CharacterData{
				Node:  Node{
					node_type:  .cdata_section_node
					document_:  d
					unique_id_: UniqueNodeID(0)
				}
				data_: data
			}
		}
	}
}

pub fn (d &Document) create_comment(data string) &Comment {
	return &Comment{
		CharacterData: CharacterData{
			Node:  Node{
				node_type:  .comment_node
				document_:  d
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
	}
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
	return &ProcessingInstruction{
		CharacterData: CharacterData{
			Node:  Node{
				node_type:  .processing_instruction_node
				document_:  d
				unique_id_: UniqueNodeID(0)
			}
			data_: data
		}
		target_:       target
	}
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
		'beforeunloadevent', 'compositionevent', 'devicemotionevent', 'deviceorientationevent',
		'dragevent', 'event', 'events', 'focusevent', 'hashchangeevent', 'htmlevents',
		'keyboardevent', 'messageevent', 'mouseevent', 'mouseevents', 'storageevent', 'svgevents',
		'textevent', 'touchevent', 'uievent', 'uievents' {
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
	// 1. If node is a document or shadow root, then throw a "NotSupportedError" DOMException.
	if node.is_document() || node.is_shadow_root() {
		return error('NotSupportedError: Cannot import a document or shadow root')
	}

	// 2. Return a clone of node, with this and the clone children flag set if deep is true.
	return node.clone_node(d, deep, none)!
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
	if old_document != &d {
		// 1. For each inclusiveDescendant in node's shadow-including inclusive descendants:
		node.for_each_shadow_including_inclusive_descendant(fn [mut d] (inclusive_descendant &Node) TraversalDecision {
			// 1. Set inclusiveDescendant's node document to document.
			mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
			mutable_descendant.set_document(&d)

			// 2. If inclusiveDescendant is an element, then set the node document of each attribute in inclusiveDescendant's attribute list to document.
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
					mutable_element.enqueue_a_custom_element_callback_reaction('adoptedCallback',
						[])
				}
			}
			return .@continue
		})

		// 3. For each inclusiveDescendant in node's shadow-including inclusive descendants, in shadow-including tree order,
		//    run the adopting steps with inclusiveDescendant and oldDocument.
		node.for_each_shadow_including_inclusive_descendant(fn [old_document] (inclusive_descendant &Node) TraversalDecision {
			mut mutable_descendant := unsafe { &Node(inclusive_descendant) }
			mutable_descendant.adopted_from(old_document)
			return .@continue
		})

		// Transfer NodeIterators rooted at `node` from old_document to this document.
		mut node_iterators_to_transfer := []&NodeIterator{}
		for node_iterator in old_document.node_iterators {
			if node_iterator.root == node {
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

pub fn (mut d Document) set_focused_area(node ?&Node) {
	old_focused := d.focused_area
	d.focused_area = node or { unsafe { nil } }
	// Stub: in full implementation would fire blur on old focused element
	// and focus on new focused element, with appropriate events
	_ = old_focused
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
	if d.active_element_ == new_active_element {
		return
	}
	d.active_element_ = new_active_element
	d.set_needs_repaint()
}

pub fn (d &Document) target_element() ?&Element {
	if d.target_element_ == unsafe { nil } {
		return none
	}
	return d.target_element_
}

pub fn (mut d Document) set_target_element(element ?&Element) {
	d.target_element_ = element or { unsafe { nil } }
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
	}
	// 2. Otherwise, if document's indicated part is top of the document, then:
	else if indicated_part.type_ == .top_of_document {
		// 1. Set document's target element to null.
		d.set_target_element(none)

		// 2. Scroll to the beginning of the document for document. [CSSOMVIEW]
		d.scroll_to_the_beginning_of_the_document()

		// 3. Return.
		return
	}
	// 3. Otherwise:
	else {
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
	// FIXME: Actually implement this algorithm.
	_ = d.navigable()
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
pub fn (mut d Document) write(text []string) ! {
	// The document.write(...text) method steps are to run the document write steps with this, text, false, and
	// "Document write".
	d.run_the_document_write_steps(text, false)!
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-writeln
pub fn (mut d Document) writeln(text []string) ! {
	// The document.writeln(...text) method steps are to run the document write steps with this, text, true, and
	// "Document writeln".
	d.run_the_document_write_steps(text, true)!
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-document-open
// C++: WebIDL::ExceptionOr<Document*> Document::open(Optional<String> const&, Optional<String> const&)
pub fn (mut d Document) open() !&Document {
	return d.open_document()
}

pub fn (mut d Document) open_document() !&Document {
	// If document belongs to a child navigable, the C++ implementation spins the navigation task source until the
	// initial navigation is ready. That requires the full navigable/session-history subsystem.

	// 1. If document is XML, throw InvalidStateError.
	if d.is_xml_document() {
		return error('InvalidStateError: open() called on XML document')
	}
	// 2. If throw-on-dynamic-markup-insertion counter > 0, throw.
	if d.throw_on_dynamic_markup_insertion_counter > 0 {
		return error('InvalidStateError: throw-on-dynamic-markup-insertion-counter > 0')
	}

	// 3. Let entryDocument be the entry global object's associated Document.
	entry_document := html_entry_global_associated_document_stub(d)

	// 4. If document's origin is not same origin to entryDocument's origin, then throw a "SecurityError" DOMException.
	if d.origin() != entry_document.origin() {
		return error("SecurityError: Document.origin() not the same as entryDocument's")
	}

	// 5. If parser and script nesting level > 0, return document.
	if d.parser != unsafe { nil } && html_parser_script_nesting_level_stub(d.parser) > 0 {
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
		html_perform_url_and_history_update_steps_stub(mut d, new_url)
	}

	// 13. Set is_initial_about_blank to false.
	d.is_initial_about_blank = false

	// 15. Set to no-quirks mode.
	d.set_quirks_mode(.no)

	// 16. Create HTML parser for scripting.
	d.parser = html_parser_create_for_scripting_stub(d)

	// 17. Set the insertion point to point at just before the end of the input stream (which at this point will be empty).
	html_parser_update_insertion_point_stub(d.parser)

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
	// Stub: would call window.window_open_steps(url, name, features)
	return none
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
	if d.parser == unsafe { nil } {
		return
	}

	// 4. Insert an explicit "EOF" character at the end of the parser's input stream.
	html_parser_insert_eof_stub(d.parser)

	// 5. If there is a pending parsing-blocking script, then return.
	if d.pending_parsing_blocking_script != unsafe { nil } {
		return
	}

	// 6. Run the tokenizer, processing resulting tokens as they are emitted, and stopping when the tokenizer reaches
	// the explicit "EOF" character or spins the event loop.
	d.parser.run()

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

pub fn (mut d Document) add_script_to_execute_when_parsing_has_finished(script &HTMLScriptElement) {
	d.scripts_to_execute_when_parsing_has_finished << script
}

pub fn (mut d Document) add_script_to_execute_as_soon_as_possible(script &HTMLScriptElement) {
	d.scripts_to_execute_as_soon_as_possible << script
}

pub fn (mut d Document) add_script_to_execute_in_order_as_soon_as_possible(script &HTMLScriptElement) {
	d.scripts_to_execute_in_order_as_soon_as_possible << script
}

// --- Editable ---

pub fn (mut d Document) set_editable(editable bool) {
	d.editable = editable
}

// --- History ---

pub fn (mut d Document) history() &History {
	// Stub: lazy-init
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
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#completely-finish-loading
pub fn (mut d Document) completely_finish_loading() {
	nav := d.navigable() or { return }

	// Notify document observers
	d.notify_each_document_observer_completely_loaded()

	// 1. Assert: document's browsing context is non-null.
	// 2. Set document's completely loaded time to the current time.
	d.completely_loaded_time = true

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
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#completely-loaded
pub fn (d &Document) is_completely_loaded() bool {
	return d.completely_loaded_time
}

// --- Page showing / visibility ---

pub fn (mut d Document) set_page_showing(page_showing bool) {
	if d.page_showing == page_showing {
		return
	}
	d.page_showing = page_showing
	d.notify_each_document_observer_page_showing()
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-document-hidden
pub fn (d &Document) hidden() bool {
	return d.visibility_state == .hidden
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

	// 7. Fire an event named visibilitychange at document, with its bubbles attribute initialized to true.
	d.dispatch_event_simple(event_visibilitychange_, true)
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
		if did_match != now_matches {
			// Fire a change event at the MediaQueryList
			mql.dispatch_change_event(now_matches)
		}
	}

	// Boundary: DOM cannot import css without creating a module cycle, so real
	// CSS::MediaQueryList objects register opaque callbacks here. This keeps the
	// C++ Document algorithm in DOM while allowing css/media_queries.v to own the
	// translated MediaQueryList implementation.
	for registration in d.css_media_query_lists {
		if registration.target == unsafe { nil } {
			continue
		}
		did_match := registration.matches(registration.target)
		now_matches := registration.evaluate(registration.target)

		did_change_internally := registration.has_changed_state(registration.target)
		registration.set_has_changed_state(registration.target, false)

		if did_change_internally || did_match != now_matches {
			registration.dispatch_change_event(registration.target, now_matches)
		}
	}
	// Also evaluate @media rules
	d.evaluate_media_rules()
}

pub fn (mut d Document) add_media_query_list(mql &MediaQueryList) {
	d.needs_media_query_evaluation = true
	d.media_query_lists << mql
}

pub fn (mut d Document) add_css_media_query_list(registration CSSMediaQueryListRegistration) {
	d.needs_media_query_evaluation = true
	d.css_media_query_lists << registration
}

// --- Resize / Scroll ---

// https://drafts.csswg.org/cssom-view/#document-run-the-resize-steps
pub fn (mut d Document) run_the_resize_steps() {
	// 1. If doc's viewport has had its width or height changed since the last time these steps were run,
	//    fire an event named resize at the Window object associated with doc.
	viewport_size := d.viewport_rect().size()
	is_initial_size := d.last_viewport_size == none
	viewport_size_changed := if last := d.last_viewport_size {
		last[0] != viewport_size[0] || last[1] != viewport_size[1]
	} else {
		true
	}

	if !viewport_size_changed {
		return
	}
	d.last_viewport_size = [viewport_size[0], viewport_size[1]]!

	if !is_initial_size {
		if viewport_size_changed {
			if d.window != unsafe { nil } {
				d.window.dispatch_event_simple('resize', false)
			}
		}
	}
}

// https://drafts.csswg.org/cssom-view-1/#document-run-the-scroll-steps
pub fn (mut d Document) run_the_scroll_steps() {
	// Process pending scroll events
	pending_scroll_events := d.pending_scroll_events.clone()
	d.pending_scroll_events.clear()
	for pse in pending_scroll_events {
		// Fire scroll events at targets
		if pse.target != unsafe { nil } {
			pse.target.dispatch_event_simple(pse.type_, pse.bubbles)
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
		if candidate == d {
			return true
		}
		// 3.2. If the focused area of candidate is a navigable container with a non-null content navigable,
		//      set candidate to active document of that content navigable.
		focused := candidate.focused_area
		if focused == unsafe { nil } {
			return false
		}
		nc := as_navigable_container_stub(focused) or { return false }
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
	d.needs_animated_style_update = true
}

pub fn (mut d Document) set_needs_to_refresh_scroll_state(b bool) {
	// Propagating scroll state invalidation.
	if paintable := d.unsafe_paintable() {
		paintable.set_needs_to_refresh_scroll_state(b)
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
			return (is_html_element_with_local_name(element, 'a')
				|| is_html_element_with_local_name(element, 'area'))
				&& element.has_attribute('href')
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
		d.all_ = &HTMLAllCollection{}
	}
	return d.all_
}

// https://drafts.csswg.org/css-font-loading/#font-source
pub fn (mut d Document) fonts() &FontFaceSet {
	return d.fonts_
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-clear
pub fn (mut d Document) clear() {
	// Stub: does nothing per spec
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-captureevents
pub fn (d &Document) capture_events() {
	// Stub: does nothing per spec
}

// https://html.spec.whatwg.org/multipage/obsolete.html#dom-document-releaseevents
pub fn (d &Document) release_events() {
	// Stub: does nothing per spec
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
	// and either navigable is a top-level traversable or navigable's container document is fully active.
	nav := d.navigable() or { return false }

	traversable := nav.traversable_navigable() or { return false }
	if nav == traversable && traversable.is_top_level_traversable() {
		return true
	}

	container_doc := nav.container_document() or { return false }
	if container_doc != d && container_doc.is_fully_active() {
		return true
	}
	return false
}

pub fn (d &Document) is_active() bool {
	return d.browsing_context != unsafe { nil }
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
	effective_domain := d.origin_.effective_domain() or {
		// 2. If effectiveDomain is null, return the empty string.
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
	effective_domain := d.origin_.effective_domain() or {
		// 4. If effectiveDomain is null, throw SecurityError.
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

pub fn (d &Document) policy_container() &PolicyContainer {
	if d.policy_container_ == unsafe { nil } {
		return &PolicyContainer{}
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
	// 1. Let navigables be new list.
	mut navigables := []&Navigable{}
	// 2-3. For each shadow-including descendant that is a navigable container:
	d.for_each_shadow_including_descendant(fn [mut navigables] (node &Node) TraversalDecision {
		nc := as_navigable_container_stub(node) or { return .@continue }
		content_nav := nc.content_navigable() or { return .@continue }
		active_doc := content_nav.active_document() or { return .@continue }
		// Extend navigables with active document's inclusive descendant navigables.
		navigables << active_doc.inclusive_descendant_navigables()
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
	for nav in all_navigables_stub() {
		container := nav.container() or { continue }
		if !d.is_ancestor_of(container) {
			continue
		}
		navigables << nav
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

	// 7. Remove any tasks whose document is document from any task queue.
	// Would remove any tasks from the task queue whose document is this document

	// Mark this document as destroyed.
	d.has_been_destroyed = true

	// 8. Set document's browsing context to null.
	d.browsing_context = unsafe { nil }

	// 9. Set document's node navigable's active session history entry's document state's document to null.
	if nav := d.navigable() {
		_ = nav
		// Clear navigable association
	}

	d.tear_down_layout_tree()
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
	// 5. Let intendToStoreInBfcache be false (simplification).

	// 6. Let eventLoop be document's relevant agent's event loop.
	mut event_loop := relevant_agent_for_doc(d).event_loop

	// 7. Increase eventLoop's termination nesting level by 1.
	event_loop.increment_termination_nesting_level()

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
		// then fire an event named unload at document's relevant global object, with legacy target override flag set.
		if d.window != unsafe { nil } {
			event := Event.create(event_unload_, EventInit{})
			EventDispatcher.dispatch(unsafe { &EventTarget(d.window) }, event, true)
		}
	}

	// 14. Decrease eventLoop's termination nesting level by 1.
	event_loop.decrement_termination_nesting_level()

	// 19. If document's salvageable state is false, then destroy document.
	if !d.salvageable {
		d.destroy()
	}

	// 20. Decrease document's unload counter by 1.
	d.unload_counter--

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

	// 3. Set document's visibility state to document's node navigable's traversable navigable's system visibility state.
	if nav := d.navigable() {
		if traversable := nav.traversable_navigable() {
			d.visibility_state = traversable.system_visibility_state()
		}
	}

	// 5. Set window's relevant settings object's execution ready flag.
	mut settings := relevant_settings_object_for_win(w)
	settings.execution_ready = true

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

pub fn (mut d Document) set_highlighted_node(node ?&Node, pseudo ?PseudoElement) {
	d.highlighted_node = node or { unsafe { nil } }
	d.highlighted_pseudo_element = pseudo
}

pub fn (d &Document) get_highlighted_node() ?&Node {
	if d.highlighted_node == unsafe { nil } {
		return none
	}
	return d.highlighted_node
}

pub fn (mut d Document) set_hovered_node(node ?&Node) {
	new_node := node or { unsafe { nil } }
	if d.hovered_node == new_node {
		return
	}
	old_hovered_node := d.hovered_node
	d.hovered_node = new_node

	// Invalidate style for :hover affected elements
	css_invalidate_style(d, .hover_changed)

	// Fire pointer/mouse out/leave events on old hovered node
	if old_hovered_node != unsafe { nil } && old_hovered_node != d.hovered_node {
		old_hovered_node.dispatch_event_simple('pointerout', true)
		old_hovered_node.dispatch_event_simple('mouseout', true)
	}

	// Fire pointer/mouse leave events up the ancestor chain
	if old_hovered_node != unsafe { nil } {
		if d.hovered_node == unsafe { nil } || !d.hovered_node.is_descendant_of(old_hovered_node) {
			// Walk up the ancestor chain from old hovered node dispatching leave events
			mut target := unsafe { &Node(old_hovered_node) }
			for target != unsafe { nil } {
				target.dispatch_event_simple('pointerleave', false)
				target.dispatch_event_simple('mouseleave', false)
				target = target.parent_or_shadow_host() or { break }
			}
		}
	}

	// Fire pointer/mouse over/enter events on new hovered node
	if d.hovered_node != unsafe { nil } && d.hovered_node != old_hovered_node {
		d.hovered_node.dispatch_event_simple('pointerover', true)
		d.hovered_node.dispatch_event_simple('mouseover', true)
	}

	// Fire pointer/mouse enter events from ancestor to descendant
	if d.hovered_node != unsafe { nil } {
		if old_hovered_node == unsafe { nil } || !d.hovered_node.is_ancestor_of(old_hovered_node) {
			mut entered := []&Node{}
			mut target2 := d.hovered_node
			for target2 != unsafe { nil } {
				entered.prepend(target2)
				target2 = target2.parent_or_shadow_host() or { break }
			}
			for t in entered {
				t.dispatch_event_simple('pointerenter', false)
				t.dispatch_event_simple('mouseenter', false)
			}
		}
	}
}

pub fn (d &Document) get_hovered_node() ?&Node {
	if d.hovered_node == unsafe { nil } {
		return none
	}
	return d.hovered_node
}

// --- Exec command (stubs) ---

pub fn (mut d Document) exec_command(command string, show_ui bool, value string) !bool {
	// AD-HOC: Not supported on non-HTML documents
	if !d.is_html_document() {
		return error('InvalidStateError: execCommand is only supported on HTML documents')
	}
	// Prevent recursive execCommand
	if d.inside_exec_command {
		return false
	}
	d.inside_exec_command = true
	defer {
		d.inside_exec_command = false
	}
	// 3. If command is not supported or not enabled, return false.
	if !(d.query_command_enabled(command)!) {
		return false
	}
	// 5. Take the action for command. Delegate to editing module.
	command_result := editing_exec_command(d, command, value)
	// 6. If the previous step returned false, return false.
	if !command_result {
		return false
	}
	// 8. Return true.
	return true
}

pub fn (d &Document) query_command_enabled(command string) !bool {
	if !d.is_html_document() {
		return error('InvalidStateError: queryCommandEnabled is only supported on HTML documents')
	}
	if !(d.query_command_supported(command)!) {
		return false
	}
	// Simplified: miscellaneous commands are always enabled
	if command in ['defaultParagraphSeparator', 'redo', 'styleWithCSS', 'undo', 'useCSS'] {
		return true
	}
	if command == 'selectAll' {
		return d.selection_ != unsafe { nil }
	}
	return d.editable
}

pub fn (d &Document) query_command_indeterm(command string) !bool {
	if !d.is_html_document() {
		return error('InvalidStateError: queryCommandIndeterm is only supported on HTML documents')
	}
	// Simplified: check if command definition has indeterminacy
	_ = command
	return false
}

pub fn (d &Document) query_command_state(command string) !bool {
	if !d.is_html_document() {
		return error('InvalidStateError: queryCommandState is only supported on HTML documents')
	}
	// Check state override
	if override_val := d.command_state_override(command) {
		return override_val
	}
	return false
}

pub fn (d &Document) query_command_supported(command string) !bool {
	if !d.is_html_document() {
		return error('InvalidStateError: queryCommandSupported is only supported on HTML documents')
	}
	// Return true if command is known/supported
	return command in [
		'bold',
		'italic',
		'underline',
		'strikethrough',
		'subscript',
		'superscript',
		'foreColor',
		'backColor',
		'hiliteColor',
		'createLink',
		'unlink',
		'insertText',
		'insertParagraph',
		'insertLineBreak',
		'insertOrderedList',
		'insertUnorderedList',
		'insertHorizontalRule',
		'insertImage',
		'formatBlock',
		'indent',
		'outdent',
		'removeFormat',
		'selectAll',
		'copy',
		'cut',
		'paste',
		'undo',
		'redo',
		'delete',
		'forwardDelete',
		'defaultParagraphSeparator',
		'styleWithCSS',
		'useCSS',
		'fontSize',
		'fontName',
		'justifyCenter',
		'justifyFull',
		'justifyLeft',
		'justifyRight',
	]
}

pub fn (d &Document) query_command_value(command string) !string {
	if !d.is_html_document() {
		return error('InvalidStateError: queryCommandValue is only supported on HTML documents')
	}
	// Check value override
	if override_val := d.command_value_override(command) {
		return override_val
	}
	return ''
}

// --- XPath (stubs) ---

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
	// 3. Check the feature. For now, allow all features.
	return match feature {
		.autoplay { true }
		.focus_without_user_activation { true }
		.encrypted_media { true }
		.fullscreen { true }
		.gamepad { true }
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
	d.intersection_observers << observer
}

pub fn (mut d Document) unregister_intersection_observer(observer &IntersectionObserver) {
	d.intersection_observers = d.intersection_observers.filter(it != observer)
}

pub fn (mut d Document) register_resize_observer(observer &ResizeObserver) {
	d.resize_observers << observer
}

pub fn (mut d Document) unregister_resize_observer(observer &ResizeObserver) {
	d.resize_observers = d.resize_observers.filter(it != observer)
}

// --- Intersection observations ---

// https://www.w3.org/TR/intersection-observer/#run-the-update-intersection-observations-steps
pub fn (mut d Document) run_the_update_intersection_observations_steps(time f64) {
	// For each observer in the list of IntersectionObservers:
	for observer in d.intersection_observers {
		// For each target in observer's observation targets:
		for target in observer.observation_targets() {
			// Compute intersection, check thresholds, queue entries.
			target_rect := target.get_bounding_client_rect()
			is_intersecting := target_rect.width > 0 && target_rect.height > 0
			_ = is_intersecting
			// Would queue IntersectionObserverEntry if thresholds changed
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
	// For each observer in [[resizeObservers]]:
	for mut observer in d.resize_observers {
		// 1. Clear observer's activeTargets and skippedTargets.
		observer.clear_active_targets()
		observer.clear_skipped_targets()
		// 2. For each observation in observer's observationTargets:
		for observation in observer.observation_targets() {
			if observation.is_active() {
				target_depth := observation.target_depth()
				if target_depth > depth {
					observer.add_active_target(observation)
				} else {
					observer.add_skipped_target(observation)
				}
			}
		}
	}
}

// https://drafts.csswg.org/resize-observer-1/#broadcast-active-resize-observations
pub fn (mut d Document) broadcast_active_resize_observations() int {
	// 1. Let shallowestTargetDepth be infinity.
	mut shallowest_target_depth := max_int
	// 2. For each observer in document's [[resizeObservers]]:
	for mut observer in d.resize_observers {
		if observer.active_targets().len == 0 {
			continue
		}
		// 3. For each observation in activeTargets:
		for observation in observer.active_targets() {
			target_depth := observation.target_depth()
			if target_depth < shallowest_target_depth {
				shallowest_target_depth = target_depth
			}
		}
		// 4. Invoke observer callback.
		observer.invoke_callback()
		// 5. Clear observer's activeTargets.
		observer.clear_active_targets()
	}
	return shallowest_target_depth
}

// https://drafts.csswg.org/resize-observer-1/#has-active-observations-h
pub fn (d &Document) has_active_resize_observations() bool {
	for observer in d.resize_observers {
		if observer.active_targets().len > 0 {
			return true
		}
	}
	return false
}

// https://drafts.csswg.org/resize-observer-1/#has-skipped-observations-h
pub fn (d &Document) has_skipped_resize_observations() bool {
	for observer in d.resize_observers {
		if observer.skipped_targets().len > 0 {
			return true
		}
	}
	return false
}

// --- Adopted style sheets ---

pub fn (mut d Document) set_adopted_style_sheets(value VoidPtr) ! {
	// Clear and repopulate adopted style sheets from the new value.
	d.adopted_style_sheets.clear()
	// Would iterate over the JS array value and append each CSSStyleSheet
	_ = value
}

// --- Visual viewport ---

pub fn (mut d Document) visual_viewport() &VisualViewport {
	if d.visual_viewport_ == unsafe { nil } {
		d.visual_viewport_ = &VisualViewport{}
	}
	return d.visual_viewport_
}

pub fn (mut d Document) register_viewport_client(client VoidPtr) {
	d.viewport_clients << client
}

pub fn (mut d Document) unregister_viewport_client(client VoidPtr) {
	d.viewport_clients = d.viewport_clients.filter(it != client)
}

pub fn (mut d Document) inform_all_viewport_clients_about_the_current_viewport_rect() {
	viewport := d.viewport_rect()
	for client in d.viewport_clients {
		// Notify each viewport client about the current viewport rect.
		viewport_client_did_set_viewport_rect(client, viewport)
	}
}

// --- Declarative refresh ---

// https://html.spec.whatwg.org/multipage/semantics.html#shared-declarative-refresh-steps
pub fn (mut d Document) shared_declarative_refresh_steps(input string) {
	// 1. If document's will declaratively refresh is true, then return.
	if d.will_declaratively_refresh {
		return
	}

	// 2-9. Parse the input to extract time and URL.
	mut pos := 0
	// Skip ASCII whitespace
	for pos < input.len && input[pos] in [` `, `\t`, `\n`, `\r`, 0x0c] {
		pos++
	}
	// Collect digits for time
	time_start := pos
	for pos < input.len && input[pos] >= `0` && input[pos] <= `9` {
		pos++
	}
	time_string := input[time_start..pos]
	if time_string.len == 0 && (pos >= input.len || input[pos] != `.`) {
		return
	}
	time := time_string.int()

	// Skip fractional digits and periods
	for pos < input.len && (input[pos] == `.` || (input[pos] >= `0` && input[pos] <= `9`)) {
		pos++
	}

	// 9. Let urlRecord be document's URL (default).
	mut url_record := d.url

	// 10-11. Parse URL if present after separator.
	if pos < input.len {
		c := input[pos]
		if c != `;` && c != `,` && c != ` ` && c != `\t` && c != `\n` && c != `\r` {
			return
		}
		// Skip whitespace
		for pos < input.len && input[pos] in [` `, `\t`, `\n`, `\r`, 0x0c] {
			pos++
		}
		if pos < input.len && (input[pos] == `;` || input[pos] == `,`) {
			pos++
		}
		for pos < input.len && input[pos] in [` `, `\t`, `\n`, `\r`, 0x0c] {
			pos++
		}

		if pos < input.len {
			remaining := input[pos..]
			// Try to parse URL from remaining text
			if parsed := d.encoding_parse_url(remaining) {
				url_record = parsed
			}
		}
	}

	// 12. Set document's will declaratively refresh to true.
	d.will_declaratively_refresh = true
	_ = time
	_ = url_record
	// Would set up a timer to navigate after `time` seconds
}

// --- Animations ---

// https://www.w3.org/TR/web-animations-1/#dom-document-timeline
pub fn (mut d Document) timeline() &DocumentTimeline {
	if d.default_timeline == unsafe { nil } {
		d.default_timeline = &DocumentTimeline{}
	}
	return d.default_timeline
}

pub fn (mut d Document) associate_with_timeline(tl &AnimationTimeline) {
	d.associated_animation_timelines << tl
}

pub fn (mut d Document) disassociate_with_timeline(tl &AnimationTimeline) {
	d.associated_animation_timelines = d.associated_animation_timelines.filter(it != tl)
}

pub fn (mut d Document) append_pending_animation_event(event PendingAnimationEvent) {
	d.pending_animation_event_queue << event
}

// https://www.w3.org/TR/web-animations-1/#update-animations-and-send-events
pub fn (mut d Document) update_animations_and_send_events(timestamp f64) {
	d.last_animation_frame_timestamp = timestamp
	// 1. Update the current time of all timelines associated with doc.
	for tl in d.associated_animation_timelines {
		tl.update_current_time(timestamp)
		for anim in tl.associated_animations() {
			anim.update()
		}
	}
	// 2. Remove replaced animations for doc.
	d.remove_replaced_animations()

	// 4. Let events to dispatch be a copy of doc's pending animation event queue.
	events_to_dispatch := d.pending_animation_event_queue.clone()
	// 5. Clear doc's pending animation event queue.
	d.pending_animation_event_queue.clear()

	// 7. Dispatch each event.
	for event in events_to_dispatch {
		if event.target != unsafe { nil } {
			event.target.dispatch_event(event.event)
		}
	}
}

// https://www.w3.org/TR/web-animations-1/#remove-replaced-animations
pub fn (mut d Document) remove_replaced_animations() {
	// For every animation that is replaceable and has replace state of active,
	// check if there exists a higher-composite-order replaceable animation
	// that covers all the same target properties.
	for tl in d.associated_animation_timelines {
		for anim in tl.associated_animations() {
			if anim.is_replaceable() && anim.replace_state() == .active {
				// Would check target properties and set replace state to removed
				// if all properties are covered by a higher-priority animation
			}
		}
	}
}

pub fn (d &Document) get_animations() ![]&Animation {
	mut result := []&Animation{}
	for tl in d.associated_animation_timelines {
		for anim in tl.associated_animations() {
			effect := anim.effect() or { continue }
			target := effect.target() or { continue }
			target_doc := target.document()
			if target_doc == d {
				result << anim
			}
		}
	}
	return result
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
}

pub fn (mut d Document) element_with_id_was_added(element &Element) {
	for fae in d.form_associated_elements_with_form_attribute {
		fae.element_with_id_was_added_or_removed()
	}
	d.insert_in_potentially_named_elements(element)
	if id := element.id() {
		d.add_element_by_id(id, element)
	}
}

pub fn (mut d Document) element_with_id_was_removed(element &Element) {
	for fae in d.form_associated_elements_with_form_attribute {
		fae.element_with_id_was_added_or_removed()
	}
	d.remove_from_potentially_named_elements(element)
	if id := element.id() {
		d.remove_element_by_id(id, element)
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
	d.insert_in_potentially_named_elements(element)
}

pub fn (mut d Document) element_with_name_was_removed(element &Element) {
	if element.id() != none {
		return
	}
	d.remove_from_potentially_named_elements(element)
}

// --- Form elements ---

pub fn (mut d Document) add_form_associated_element_with_form_attribute(element &FormAssociatedElement) {
	d.form_associated_elements_with_form_attribute << element
}

pub fn (mut d Document) remove_form_associated_element_with_form_attribute(element &FormAssociatedElement) {
	d.form_associated_elements_with_form_attribute =
		d.form_associated_elements_with_form_attribute.filter(it != element)
}

// --- Design mode ---

pub fn (d &Document) design_mode_enabled_state() bool {
	return d.design_mode_enabled
}

pub fn (mut d Document) set_design_mode_enabled_state(enabled bool) {
	d.design_mode_enabled = enabled
}

// https://html.spec.whatwg.org/multipage/interaction.html#making-entire-documents-editable:-the-designmode-idl-attribute
pub fn (d &Document) design_mode() string {
	if d.design_mode_enabled {
		return 'on'
	}
	return 'off'
}

pub fn (mut d Document) set_design_mode(dm string) ! {
	if dm.to_lower() == 'on' {
		d.design_mode_enabled = true
	}
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
				return layout_retarget_from_ua_internal_shadow_root_stub(hit.element)
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
		sequence[i] = layout_retarget_from_ua_internal_shadow_root_stub(element)
	}
	mut deduplicated_sequence := []&Element{}
	for element in sequence {
		if deduplicated_sequence.len == 0 || deduplicated_sequence.last() != element {
			deduplicated_sequence << element
		}
	}
	sequence = deduplicated_sequence.clone()

	// 4. If the document has a root element and it's not in the sequence, append it.
	if root := d.document_element() {
		if sequence.len == 0 || sequence.last() != root {
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

// https://html.spec.whatwg.org/multipage/dom.html#dom-tree-accessors:supported-property-names
pub fn (d &Document) supported_property_names() []string {
	// The supported property names consist of name/id attributes from
	// exposed embed, form, iframe, img, and exposed object elements.
	mut names := []string{}
	for element in d.potentially_named_elements {
		if n := element.get_name() {
			if n !in names {
				names << n
			}
		}
		if id := element.id() {
			if id !in names {
				names << id
			}
		}
	}
	return names
}

// --- Shadow roots ---

pub fn (mut d Document) register_shadow_root(shadow_root &ShadowRoot) {
	d.shadow_roots << shadow_root
}

pub fn (mut d Document) unregister_shadow_root(shadow_root &ShadowRoot) {
	d.shadow_roots = d.shadow_roots.filter(it != shadow_root)
}

// --- Top layer ---

// https://drafts.csswg.org/css-position-4/#add-an-element-to-the-top-layer
pub fn (mut d Document) add_an_element_to_the_top_layer(element &Element) {
	d.top_layer_elements << element
	d.invalidate_layout_tree(.document_add_an_element_to_the_top_layer)
}

// https://drafts.csswg.org/css-position-4/#request-an-element-to-be-removed-from-the-top-layer
pub fn (mut d Document) request_an_element_to_be_remove_from_the_top_layer(element &Element) {
	d.top_layer_pending_removals << element
	d.invalidate_layout_tree(.document_request_an_element_to_be_removed_from_the_top_layer)
}

// https://drafts.csswg.org/css-position-4/#remove-an-element-from-the-top-layer-immediately
pub fn (mut d Document) remove_an_element_from_the_top_layer_immediately(element &Element) {
	d.top_layer_elements = d.top_layer_elements.filter(it != element)
	d.top_layer_pending_removals = d.top_layer_pending_removals.filter(it != element)
	d.invalidate_layout_tree(.document_immediately_remove_element_from_the_top_layer)
}

// https://drafts.csswg.org/css-position-4/#process-top-layer-removals
pub fn (mut d Document) process_top_layer_removals() {
	if d.top_layer_pending_removals.len == 0 {
		return
	}
	for element in d.top_layer_pending_removals {
		d.top_layer_elements = d.top_layer_elements.filter(it != element)
	}
	d.top_layer_pending_removals.clear()
	d.invalidate_layout_tree(.document_pending_top_layer_removals_processed)
}

// --- Popover ---

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
	if query.len == 0 {
		return []
	}
	// Collect all text content from the document tree and search for matches.
	mut matches := []&Range{}
	text_content := d.text_content() or { return matches }
	search_text := if case_sensitivity == .case_insensitive {
		text_content.to_lower()
	} else {
		text_content
	}
	search_query := if case_sensitivity == .case_insensitive {
		query.to_lower()
	} else {
		query
	}
	mut offset := 0
	for {
		idx := search_text.index_after(search_query, offset) or { break }
		matches << &Range{
			start_offset_: idx
			end_offset_:   idx + search_query.len
		}
		offset = idx + search_query.len
		if offset >= search_text.len {
			break
		}
	}
	return matches
}

// --- HTML parsing ---

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#parse-html-from-a-string
pub fn (mut d Document) parse_html_from_a_string(markup string) {
	// 1. Set document's type to "html".
	d.type_ = .html
	// 2-4. Create an HTML parser, feed it the markup, and run it.
	parser := html_parser_create_for_scripting_stub(d)
	parser.feed(markup)
	parser.run()
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
	return none
}

pub fn (mut d Document) reset_cursor_blink_cycle() {
	d.cursor_blink_state = true
	// Would restart the cursor blink timer
	if d.cursor_blink_timer != unsafe { nil } {
		d.cursor_blink_timer.restart()
	}
}

pub fn (d &Document) get_cursor_blink_state() bool {
	return d.cursor_blink_state
}

// --- Navigable cache ---

pub fn (d &Document) cached_navigable() ?&Navigable {
	if d.cached_navigable_ == unsafe { nil } {
		return none
	}
	return d.cached_navigable_
}

pub fn (mut d Document) set_cached_navigable(navigable ?&Navigable) {
	d.cached_navigable_ = navigable or { unsafe { nil } }
}

// --- Repaint ---

pub fn (mut d Document) notify_css_background_image_loaded() {
	// Invalidate paint caches on all paintable boxes
	if paintable := d.unsafe_paintable() {
		paintable.invalidate_all_paint_caches()
	}
	d.set_needs_repaint()
}

pub fn (mut d Document) invalidate_display_list() {
	d.cached_display_list_ = unsafe { nil }
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
		d.grapheme_segmenter_ = &Segmenter{}
	}
	return d.grapheme_segmenter_
}

pub fn (mut d Document) line_segmenter() &Segmenter {
	if d.line_segmenter_ == unsafe { nil } {
		d.line_segmenter_ = &Segmenter{}
	}
	return d.line_segmenter_
}

pub fn (mut d Document) word_segmenter() &Segmenter {
	if d.word_segmenter_ == unsafe { nil } {
		d.word_segmenter_ = &Segmenter{}
	}
	return d.word_segmenter_
}

// --- Beforeunload ---

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#steps-to-fire-beforeunload
pub fn (mut d Document) steps_to_fire_beforeunload(unload_prompt_shown bool) StepsToFireBeforeunloadResult {
	// 1. Let unloadPromptCanceled be false.
	mut unload_prompt_canceled := false

	// 2. Increase the document's unload counter by 1.
	d.unload_counter++

	// 3. Increase document's relevant agent's event loop's termination nesting level by 1.
	mut event_loop := relevant_agent_for_doc(d).event_loop
	event_loop.increment_termination_nesting_level()

	// 4. Let eventFiringResult be the result of firing an event named beforeunload at document's relevant global object,
	//    using BeforeUnloadEvent, with the cancelable attribute initialized to true.
	mut event_firing_result := true
	if d.window != unsafe { nil } {
		beforeunload_event := Event.create('beforeunload', EventInit{
			cancelable: true
		})
		event_firing_result = EventDispatcher.dispatch(unsafe { &EventTarget(d.window) },
			beforeunload_event, false)
	}

	// 5. Decrease document's relevant agent's event loop's termination nesting level by 1.
	event_loop.decrement_termination_nesting_level()

	// FIXME: 6. If all of the following are true:
	_ = event_firing_result

	// 7. Decrease document's unload counter by 1.
	d.unload_counter--

	// 8. Return (unloadPromptShown, unloadPromptCanceled).
	_ = unload_prompt_canceled
	return StepsToFireBeforeunloadResult{
		unload_prompt_shown:    unload_prompt_shown
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
	return d.onfullscreenchange_handler
}

pub fn (mut d Document) set_onfullscreenchange(value ?&CallbackType) {
	d.onfullscreenchange_handler = value or { unsafe { nil } }
}

pub fn (d &Document) onfullscreenerror() ?&CallbackType {
	return d.onfullscreenerror_handler
}

pub fn (mut d Document) set_onfullscreenerror(value ?&CallbackType) {
	d.onfullscreenerror_handler = value or { unsafe { nil } }
}

// --- View transitions ---

// https://drafts.csswg.org/css-view-transitions-1/#dom-document-startviewtransition
pub fn (mut d Document) start_view_transition(update_callback ?&CallbackType) &ViewTransition {
	vt := &ViewTransition{}
	d.active_view_transition = vt
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
	d.update_callback_queue.clear()
}

// https://drafts.csswg.org/css-view-transitions-1/#view-transition-page-visibility-change-steps
pub fn (mut d Document) view_transition_page_visibility_change_steps() {
	// Queue a global task on the DOM manipulation task source:
	// If document's visibility state is "hidden" and active view transition is not null,
	// skip the view transition with InvalidStateError.
	if d.visibility_state == .hidden {
		if d.active_view_transition != unsafe { nil } {
			d.active_view_transition.skip_the_view_transition()
		}
	}
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
		type_:   type_
		element: element
	}
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
	return d.fullscreen_element()
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
		if el.is_fullscreen_element() && el != fullscreened {
			to_unfullscreen << el
		}
	}
	for mut el in to_unfullscreen {
		d.unfullscreen_element(mut el)
	}
	// 3. Exit fullscreen document.
	d.exit_fullscreen()
}

// https://fullscreen.spec.whatwg.org/#exit-fullscreen
pub fn (mut d Document) exit_fullscreen() &Promise {
	promise := &Promise{}
	// 2. If doc is not fully active or doc's fullscreen element is null, reject.
	if !d.is_fully_active() || d.fullscreen_element() == none {
		return promise
	}
	// Unfullscreen the fullscreen element
	if mut el := d.fullscreen_element() {
		d.append_pending_fullscreen_change(.change, el)
		d.unfullscreen_element(mut el)
	}
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
	return d.render_blocking_elements.len > 0
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
}

// --- CSS import rules ---

pub fn (mut d Document) add_pending_css_import_rule(rule VoidPtr) {
	d.pending_css_import_rules << rule
}

pub fn (mut d Document) remove_pending_css_import_rule(rule VoidPtr) {
	d.pending_css_import_rules = d.pending_css_import_rules.filter(it != rule)
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

pub fn (mut d Document) set_command_value_override(command string, value string) {
	d.command_value_override[command] = value
}

pub fn (mut d Document) clear_command_value_override(command string) {
	d.command_value_override.delete(command)
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
	if form_text_element := form_associated_text_control_input_events_target(focused) {
		node := for_node or { return form_text_element }
		if focused.is_shadow_including_inclusive_ancestor_of(node) {
			return form_text_element
		}
	}
	return none
}

fn form_associated_text_control_input_events_target(node &Node) ?&InputEventsTarget {
	// C++: as_if<HTML::FormAssociatedTextControlElement>(*focused_area).
	// The HTML form text-control hierarchy is outside the current DOM file set.
	_ = node
	return none
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

// --- Shared resource requests ---

pub fn (mut d Document) shared_resource_requests() map[string]&SharedResourceRequest {
	return d.shared_resource_requests_
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

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#restore-the-history-object-state
pub fn (mut d Document) restore_the_history_object_state(entry &SessionHistoryEntry) {
	// 1. Let targetRealm be document's relevant realm.
	realm := relevant_realm_for_doc(d)

	// 2. Let state be StructuredDeserialize(entry's classic history API state, targetRealm).
	// 3. Set document's history object's state to state.
	state := structured_deserialize_stub(entry.classic_history_api_state, realm, unsafe { nil }) or {
		d.history().set_state(unsafe { nil })
		return
	}
	d.history().set_state(state)
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
}

// https://html.spec.whatwg.org/multipage/browsing-the-web.html#snapshotting-source-snapshot-params
pub fn (mut d Document) snapshot_source_snapshot_params() &SourceSnapshotParams {
	return &SourceSnapshotParams{}
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
			url := identifier.url or { return none }
			css_user_agent_style_sheet_source(url)
		}
		.user_style {
			// Would return page().user_style()
			none
		}
	}
}

pub fn (mut d Document) ensure_element_shared_css_random_base_value(key string) f64 {
	if key in d.element_shared_css_random_base_value_cache {
		return d.element_shared_css_random_base_value_cache[key]
	}
	// Generate a pseudo-random value based on key hash
	mut h := u64(0)
	for b in key.bytes() {
		h = h * 31 + u64(b)
	}
	value := f64(h % 10000) / 10000.0
	d.element_shared_css_random_base_value_cache[key] = value
	return value
}

// --- is_child_allowed ---

pub fn (d &Document) is_child_allowed(node &Node) bool {
	return match node.node_type {
		.document_node, .text_node {
			false
		}
		.comment_node {
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
	d.tear_down_layout_tree()
	if !d.has_fired_document_became_inactive {
		d.has_fired_document_became_inactive = true
		d.notify_each_document_observer_became_inactive()
	}
}

// --- check_favicon ---

pub fn (mut d Document) check_favicon_after_loading_link_resource() {
	// Check for favicon link elements in the head
	_ = d.head() or { return }
	// Stub: In a full implementation, would iterate over head's descendants
	// to find link elements with rel="icon" and use the last one in tree order.
	// This requires HTMLLinkElement type checks and favicon loading infrastructure.
}

// --- lookup_custom_element_definition ---

// https://html.spec.whatwg.org/multipage/custom-elements.html#look-up-a-custom-element-definition
pub fn (d &Document) lookup_custom_element_definition(namespace_ ?string, local_name string, is_ ?string) ?&CustomElementDefinition {
	// 1. If namespace is not the HTML namespace, then return null.
	ns := namespace_ or { return none }
	if ns != namespace_html_ {
		return none
	}
	// 2. If document's browsing context is null, then return null.
	if d.browsing_context == unsafe { nil } {
		return none
	}
	// 3. Let registry be document's relevant global object's custom element registry.
	// The V port keeps the translated definition set on Document until Window's
	// CustomElementRegistry is available.

	// 4. If registry's custom element definition set contains an item with name and local name both equal to localName, then return that item.
	for definition in d.custom_element_definitions {
		if definition.name() == local_name && definition.local_name() == local_name {
			return definition
		}
	}

	// 5. If registry's custom element definition set contains an item with name equal to is and local name equal to localName, then return that item.
	// 6. Return null.
	is_value := is_ or { return none }
	for definition in d.custom_element_definitions {
		if definition.name() == is_value && definition.local_name() == local_name {
			return definition
		}
	}
	return none
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
pub fn (d &Document) root_element() ?VoidPtr {
	// Returns SVG root element if document element is an SVGSVGElement.
	doc_el := d.document_element() or { return none }
	if doc_el.is_svg_svg_element() {
		return voidptr(doc_el)
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
		.shadow_root_set_inner_html {
			'ShadowRootSetInnerHTML'
		}
	}
}

pub fn update_layout_reason_to_string(reason UpdateLayoutReason) string {
	return match reason {
		.auto_scroll_selection { 'AutoScrollSelection' }
		.child_document_style_update { 'ChildDocumentStyleUpdate' }
		.debugging { 'Debugging' }
		.document_element_from_point { 'DocumentElementFromPoint' }
		.document_elements_from_point { 'DocumentElementsFromPoint' }
		.document_find_matching_text { 'DocumentFindMatchingText' }
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
pub fn (d &Document) relevant_settings_object() &EnvironmentSettingsObjectStub {
	// The relevant settings object for a platform object o is the environment settings
	// object of the relevant Realm for o.
	return &EnvironmentSettingsObjectStub{}
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
	layout := body_el.unsafe_layout_node() or { return none }
	_ = layout
	// Stub: would return layout.background_layers()
	return none
}

// C++: CSS::ImageRendering Document::background_image_rendering() const
pub fn (d &Document) background_image_rendering() ImageRendering {
	body_el := d.body() or { return .auto_ }
	layout := body_el.unsafe_layout_node() or { return .auto_ }
	_ = layout
	// Stub: would return layout.computed_values().image_rendering()
	return .auto_
}

// C++: void Document::mark_svg_root_as_needing_relayout(Layout::SVGSVGBox& svg_root)
pub fn (mut d Document) mark_svg_root_as_needing_relayout(svg_root &SVGSVGBox) {
	d.svg_roots_needing_relayout << svg_root
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
	if element.needs_style_update() {
		return true
	}
	if element.entire_subtree_needs_style_update() {
		return true
	}
	// If the navigable has a container and that container needs a style update, then we need one
	// as well, since the container's style can affect this element (e.g. via media queries or
	// viewport units).
	if nav := d.navigable() {
		if container := nav.container() {
			_ = container
			// Stub: would check container.document().element_needs_style_update(container)
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
	// Stub: would call element.get_pseudo_element_node(pseudo_element)
	return d.highlighted_node.unsafe_layout_node()
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
	if retargeted_node.root() != unsafe { &Node(d) } {
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
	fragment := d.url.fragment() or {
		// 2. If fragment is the empty string, return the special value top of the document.
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
pub fn (mut d Document) run_the_document_write_steps(text []string, add_line_feed bool) ! {
	// 1. Let string be the empty string.
	mut sb := strings.new_builder(256)

	// 2. Let isTrusted be false if text contains a string; otherwise true.
	// NOTE: This V binding receives strings directly; TrustedHTML is not ported yet.

	// 3. For each value of text: append it to string.
	for val in text {
		sb.write_string(val)
	}

	// 4. If isTrusted is false, set string to the result of invoking the Get Trusted Type compliant string algorithm
	//    with TrustedHTML, this's relevant global object, string, sink, and "script".
	// Stub: Trusted Types is not ported in this DOM translation.

	// 5. If lineFeed is true, append U+000A LINE FEED to string.
	if add_line_feed {
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
	if d.parser == unsafe { nil } || !html_parser_insertion_point_is_defined_stub(d.parser) {
		// 1. If document's unload counter > 0 or ignore-destructive-writes counter > 0, return.
		if d.unload_counter > 0 || d.ignore_destructive_writes_counter > 0 {
			return
		}
		// 2. Run the document open steps with document.
		d.open_document() or { return err }
	}

	// 10. Insert string into the input stream just before the insertion point.
	if d.parser != unsafe { nil } {
		html_parser_insert_input_at_insertion_point_stub(d.parser, sb.str())
	}

	// 11. If document's pending parsing-blocking script is null, have the HTML parser
	//     process string, one code point at a time, processing resulting tokens as they are emitted, and stopping when
	//     the tokenizer reaches the insertion point or when the processing of the tokenizer is aborted by the tree
	//     construction stage (this can happen if a script end tag token is emitted by the tokenizer).
	if d.pending_parsing_blocking_script == unsafe { nil } {
		if d.parser != unsafe { nil } {
			html_parser_run_until_insertion_point_stub(d.parser)
		}
	}
}

// C++: GC::Ref<HTML::HTMLScriptElement> Document::take_pending_parsing_blocking_script(...)
pub fn (mut d Document) take_pending_parsing_blocking_script() &HTMLScriptElement {
	script := d.pending_parsing_blocking_script
	d.pending_parsing_blocking_script = unsafe { nil }
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
	_ = transition
	// Stub: In the full implementation, this determines the transition phase
	// (idle, pending, before, active, after) by comparing the animation's
	// current time against its effect's timing, then dispatches transitionrun,
	// transitionstart, transitionend, and transitioncancel events to the
	// owning element based on phase transitions.
}

// https://www.w3.org/TR/css-animations-2/#event-dispatch
// C++: void Document::dispatch_events_for_animation_if_necessary(GC::Ref<Animations::Animation> animation)
pub fn (mut d Document) dispatch_events_for_animation_if_necessary(animation &Animation) {
	_ = animation
	// Stub: In the full implementation, if the animation is a CSS transition,
	// delegates to dispatch_events_for_transition. Otherwise, for CSS
	// animations, compares the previous phase with the current phase and
	// dispatches animationstart, animationiteration, animationend, and
	// animationcancel events as appropriate.
}

// https://html.spec.whatwg.org/multipage/document-lifecycle.html#unload-a-document-and-its-descendants
// C++: void Document::unload_a_document_and_its_descendants(...)
pub fn (mut d Document) unload_a_document_and_its_descendants(new_document ?&Document) {
	// 2. Let childNavigables be document's child navigables.
	child_navigables := d.document_tree_child_navigables()

	// 4. For each childNavigable of childNavigables, queue a global task to:
	for child_nav in child_navigables {
		// 1-2. Unload the child's active document and its descendants, then increment counter.
		if mut active_doc := child_nav.active_document() {
			active_doc.unload_a_document_and_its_descendants(none)
		}
	}

	// 6. Queue a global task to:
	// 2. Unload document, passing along newDocument if it is not null.
	_ = new_document
	d.unload()
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
		if mut active_doc := child_nav.active_document() {
			// 2. Destroy a document and its descendants given childNavigable's active document.
			active_doc.destroy_a_document_and_its_descendants()
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
		if mut active_doc := desc_nav.active_document() {
			active_doc.abort()
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
	// Stub: In full implementation, this would:
	//   - Set IntersectionObserverTaskQueued to false
	//   - For each IntersectionObserver whose root is in the DOM tree:
	//     - Take queued entries
	//     - Invoke callback with queue and observer
}

// https://www.w3.org/TR/intersection-observer/#queue-an-intersectionobserverentry
// C++: void Document::queue_an_intersection_observer_entry(...)
pub fn (mut d Document) queue_an_intersection_observer_entry(observer &IntersectionObserver, time f64, root_bounds Rect, bounding_client_rect Rect, intersection_rect Rect, is_intersecting bool, intersection_ratio f64, target &Element) {
	_ = time
	_ = root_bounds
	_ = bounding_client_rect
	_ = intersection_rect
	_ = is_intersecting
	_ = intersection_ratio
	_ = target
	// 1. Construct an IntersectionObserverEntry, passing in time, rootBounds,
	//    boundingClientRect, intersectionRect, isIntersecting, and target.
	// 2. Append it to observer's internal [[QueuedEntries]] slot.
	observer.queue_entry()
	// 3. Queue an intersection observer task for document.
	d.queue_intersection_observer_task()
}

// C++: JS::Value Document::named_item_value(FlyString const& name) const
// https://html.spec.whatwg.org/multipage/dom.html#dom-document-nameditem
pub fn (d &Document) named_item_value(name string) ?&Element {
	// 1. Let elements be the list of named elements with the name name that
	//    are in a document tree with the Document as their root.
	// NOTE: There will be at least one such element.
	mut elements := []&Element{}
	for element in d.potentially_named_elements {
		if element.root().is_document() && element.root().document() == d {
			if element_name := element.get_name() {
				if element_name == name {
					elements << element
					continue
				}
			}
			if element_id := element.id() {
				if element_id == name {
					elements << element
				}
			}
		}
	}

	// 2. If elements has only one element, and that element is an iframe element,
	//    and that iframe element's content navigable is not null, then return the
	//    active WindowProxy of the element's content navigable.
	// The V binding returns DOM elements, so WindowProxy is not representable here.

	// 3. Otherwise, if elements has only one element, return that element.
	if elements.len == 1 {
		return elements[0]
	}

	// 4. Otherwise return an HTMLCollection rooted at the Document node, whose filter matches only named elements with the name name.
	// This method's current V signature returns an optional Element, so multiple matches are represented as null until JS values/HTMLCollection returns are ported.
	return none
}

// https://html.spec.whatwg.org/multipage/dynamic-markup-insertion.html#dom-parsehtmlunsafe
// C++: WebIDL::ExceptionOr<GC::Root<DOM::Document>> Document::parse_html_unsafe(JS::VM& vm, ...)
pub fn Document.parse_html_unsafe(html string) !&Document {
	// FIXME: update description once https://github.com/whatwg/html/issues/11778 gets solved
	// 1. Let compliantHTML to the result of invoking the Get Trusted Type compliant string algorithm with
	//    TrustedHTML, this's relevant global object, html, "Document parseHTMLUnsafe", and "script".
	compliant_html := trusted_type_compliant_html_for_document_parse_html_unsafe_stub(html)!

	// 2. Let document be a new Document, whose content type is "text/html".
	mut doc := Document.create_for_fragment_parsing()
	doc.set_content_type('text/html')

	// 3. Set document's allow declarative shadow roots to true.
	doc.set_allow_declarative_shadow_roots(true)

	// 4. Parse HTML from a string given document and compliantHTML.
	doc.parse_html_from_a_string(compliant_html)

	// AD-HOC: Setting the origin to match that of the associated document matches the behavior of existing browsers.
	if origin := associated_document_origin_for_parse_html_unsafe_stub() {
		doc.set_origin(origin)
	}

	// 5. Return document.
	return doc
}

pub fn parse_html_unsafe(html string) !&Document {
	return Document.parse_html_unsafe(html)
}

fn trusted_type_compliant_html_for_document_parse_html_unsafe_stub(html string) !string {
	// Trusted Types are not ported yet; preserve the algorithm boundary explicitly.
	return html
}

fn associated_document_origin_for_parse_html_unsafe_stub() ?Origin {
	// The JS realm/global object model is outside this DOM-only translation for now.
	return none
}

// C++: GC::Ref<CSS::FontFaceSet> Document::adopted_style_sheets() const
pub fn (d &Document) adopted_style_sheets() []&CSSStyleSheet {
	return d.adopted_style_sheets
}

// https://fullscreen.spec.whatwg.org/#fullscreen-an-element
// C++: void Document::fullscreen_element_within_doc(GC::Ref<Element> element)
pub fn (mut d Document) fullscreen_element_within_doc(mut element Element) {
	// 1. Let hideUntil be the result of running topmost popover ancestor given element.
	// Stub: would compute hide_until from popover lists

	// 2. If hideUntil is not null, then:
	//    1. Run hide all popovers until given hideUntil, false, and true.
	// (Stub: would call hide_all_popovers_until)

	// 3. Set element's fullscreen flag to true.
	element.set_fullscreen_flag(true)

	// 4-7. Handle iframe fullscreen flag, add to top layer, etc.
	// Stub: would add element to top layer

	// 8. Append (fullscreenchange, element) to document's list of pending fullscreen events.
	d.pending_fullscreen_events << PendingFullscreenEvent{
		element: element
	}
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

		// 4. Let container be lastDoc's node navigable's container.
		nav := last_doc.navigable() or { break }
		container := nav.container() or { break }
		_ = container

		// 5. If container is null, then break.
		// 6. If container's iframe fullscreen flag is set, break.
		// 7. Append container's node document to docs.
		// Stub: would walk up navigable containers
		break
	}

	// 3. Return docs.
	return docs
}

// C++: RefPtr<Painting::DisplayList> Document::record_display_list(HTML::PaintConfig config)
pub fn (mut d Document) record_display_list() ?&DisplayList {
	if d.cached_display_list_ != unsafe { nil } {
		return d.cached_display_list_
	}

	d.update_paint_and_hit_testing_properties_if_needed()

	pb := d.paintable_box() or { return none }
	_ = pb
	// Stub: In the full implementation, this would:
	//   - Create a DisplayList from the paintable's visual context tree
	//   - Set up a DisplayListRecorder
	//   - Determine color scheme from html element
	//   - Fill with canvas color and background color
	//   - Paint all phases
	//   - Paint inspector overlay if highlighted
	//   - Cache the result
	display_list := &DisplayList{}
	d.cached_display_list_ = display_list
	return display_list
}

// C++: void Document::run_csp_initialization() const
// https://w3c.github.io/webappsec-csp/#run-document-csp-initialization
pub fn (d &Document) run_csp_initialization() {
	// 1. For each policy of document's policy container's CSP list:
	//    1. For each directive of policy:
	//       1. Execute directive's initialization algorithm on document.
	// Stub: Content Security Policy initialization requires full CSP implementation
	if d.policy_container_ != unsafe { nil } {
		// Would iterate CSP list policies and directives
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
	// Stub: Returns CSS environment variable values
	return match variable {
		.safe_area_inset_top, .safe_area_inset_bottom, .safe_area_inset_left,
		.safe_area_inset_right {
			'0px'
		}
		.preferred_text_scale {
			'1'
		}
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

// C++: void Document::build_registered_properties_cache()
pub fn (mut d Document) build_registered_properties_cache() {
	d.cached_registered_properties_from_css_property_rules.clear()
	d.for_each_active_css_style_sheet(fn [mut d] (sheet &CSSStyleSheet) {
		// Stub: In the full implementation, this would iterate through
		// each effective CSS rule in the stylesheet (preorder traversal),
		// and for each CSSPropertyRule, add its registration to the cache.
		_ = sheet
		_ = d
	})
}

// C++: void Document::build_counter_style_cache()
pub fn (mut d Document) build_counter_style_cache() {
	d.registered_counter_styles.clear()
	// Stub: In the full implementation, this would:
	// 1. Define complex predefined counter styles (ethiopic-numeric, CJK styles, etc.)
	// 2. Walk all active stylesheets for @counter-style rules
	// 3. Build CounterStyle objects from definitions
}

// C++: void Document::ensure_cookie_version_index(URL::URL const& new_url, URL::URL const& old_url)
pub fn (mut d Document) ensure_cookie_version_index(new_url URL) {
	// Stub: In the full implementation, this would canonicalize the domain
	// and request a cookie version index from the page client.
	_ = new_url
	d.cookie_version_index = none
}

// C++: void Document::invalidate_style_for_elements_affected_by_pseudo_class_change(...)
pub fn (mut d Document) invalidate_style_for_elements_affected_by_pseudo_class_change(pseudo_class PseudoClass, common_ancestor &Node) {
	_ = pseudo_class
	_ = common_ancestor
	// Stub: In the full implementation, this would:
	// 1. Get the pseudo class rule cache from the style scope
	// 2. For each element under common_ancestor, check if it's affected by the pseudo class
	// 3. Temporarily swap the element slot (old/new value) and check if different rules match
	// 4. If different rules match, set_needs_style_update(true) on the element
	// This is a performance optimization to avoid full style recalculation when only
	// :hover, :focus, :active etc. change.
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

// --- Stub methods on supporting types needed by new methods ---

pub fn (si &StyleInvalidator) has_pending_invalidations() bool {
	return false
}

// Element.needs_style_update and entire_subtree_needs_style_update are in element.v

pub fn (he &HTMLElement) unsafe_layout_node() ?&LayoutNode {
	return none
}

pub fn (w &Window) location() ?&Location {
	return none
}

pub fn (io &IntersectionObserver) queue_entry() {}

pub fn (p &Page) client_page_did_create_new_document(d &Document) {
	_ = d
}

pub fn (p &Page) client_page_did_update_resource_count(count int) {
	_ = p
	_ = count
}

pub fn (el &EventLoopStub) unregister_document(d &Document) {
	_ = d
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
	// Stub
	return host_suffix_string == original_host
}
