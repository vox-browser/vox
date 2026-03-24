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

pub fn (a URL) == (b URL) bool {
	return a.value == b.value
}

pub fn (u URL) set_fragment(f ?string) {
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

// Stub for Node base
@[heap]
pub struct Node {
pub mut:
	node_type NodeType
}

// Stub for ParentNode
@[heap]
pub struct ParentNode {
	Node
}

// Stub for Element
@[heap]
pub struct Element {
	Node
pub mut:
	namespace_uri string
}

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

// DocumentType stub
@[heap]
pub struct DocumentType {
	Node
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
pub struct StyleSheetList {}

@[heap]
pub struct CSSStyleSheet {}

@[heap]
pub struct FontFaceSet {}

@[heap]
pub struct VisualViewport {}

@[heap]
pub struct MediaQueryList {}

pub struct BackgroundLayerData {}

pub struct SelectorList {}

pub struct StyleScope {}

pub struct StyleValue {}

pub struct CustomPropertyRegistration {}

@[heap]
pub struct CounterStyle {}

pub struct RandomCachingKey {}

pub struct ComponentValue {}

pub struct StyleSheetIdentifier {}

// HTML stubs
@[heap]
pub struct Window {}

@[heap]
pub struct BrowsingContext {}

@[heap]
pub struct HTMLParser {}

@[heap]
pub struct History {}

@[heap]
pub struct Location {}

@[heap]
pub struct WindowProxy {}

@[heap]
pub struct NavigationParams {}

@[heap]
pub struct SessionHistoryEntry {}

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

// Animation stubs
@[heap]
pub struct AnimationTimeline {}

@[heap]
pub struct DocumentTimeline {}

@[heap]
pub struct Animation {}

pub struct PaintConfig {}

// Selection stub
@[heap]
pub struct Selection {}

// Intersection/Resize Observer stubs
@[heap]
pub struct IntersectionObserver {}

@[heap]
pub struct ResizeObserver {}

// Other stubs
@[heap]
pub struct DOMImplementation {}

@[heap]
pub struct HTMLCollection {}

@[heap]
pub struct HTMLAllCollection {}

@[heap]
pub struct NodeList {}

@[heap]
pub struct NodeIterator {}

@[heap]
pub struct TreeWalker {}

@[heap]
pub struct NodeFilter {}

@[heap]
pub struct DocumentFragment {}

@[heap]
pub struct Text {}

@[heap]
pub struct CDATASection {}

@[heap]
pub struct Comment {}

@[heap]
pub struct ProcessingInstruction {}

@[heap]
pub struct Attr {}

@[heap]
pub struct Event {}

@[heap]
pub struct EventTarget {}

@[heap]
pub struct Range {}

@[heap]
pub struct ShadowRoot {}

@[heap]
pub struct DocumentObserver {}

@[heap]
pub struct EditingHostManager {}

@[heap]
pub struct StyleInvalidator {}

@[heap]
pub struct InputEventsTarget {}

@[heap]
pub struct Position {}

@[heap]
pub struct CallbackType {}

@[heap]
pub struct ViewTransition {}

@[heap]
pub struct Page {}

@[heap]
pub struct ConsoleClient {}

@[heap]
pub struct FormAssociatedElement {}

@[heap]
pub struct ElementByIdMap {}

@[heap]
pub struct Promise {}

@[heap]
pub struct AccessibilityTreeNode {}

@[heap]
pub struct XPathExpression {}

@[heap]
pub struct XPathResult {}

@[heap]
pub struct XPathNSResolver {}

@[heap]
pub struct DOMRectReadOnly {}

@[heap]
pub struct Segmenter {}

// Stub timer
@[heap]
pub struct Timer {}

// --- Enums ---

pub enum NodeType {
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

pub enum SandboxingFlagSet {
	none_
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
	event_target &EventTarget = unsafe { nil }
	event_type   string
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
	type_        DocumentType_ = .xml
	content_type string        = 'application/xml'
	url          URL           = url_about_blank()
	origin_      Origin        = origin_create_opaque()
	referrer     string
	source       string

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
	active_sandboxing_flag_set SandboxingFlagSet = .none_
	policy_container_          &PolicyContainer  = unsafe { nil }

	// Visibility
	visibility_state VisibilityState = .hidden

	// Last modified
	last_modified_ ?i64

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
	last_viewport_size         ?[2]int
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
	adopted_style_sheets_                   VoidPtr
	console_client_                         &ConsoleClient                      = unsafe { nil }
	cursor_blink_timer                      &Timer                              = unsafe { nil }
	active_refresh_timer                    &Timer                              = unsafe { nil }
	cached_navigable_                       &Navigable                          = unsafe { nil }
	temporary_document_for_fragment_parsing TemporaryDocumentForFragmentParsing = .no
	media_query_lists                       []&MediaQueryList
	document_observers_being_notified       []&DocumentObserver
}

// --- Constructor / Factory methods ---

// create_and_initialize corresponds to Document::create_and_initialize
pub fn Document.create_and_initialize(type_ DocumentType_, content_type string, navigation_params &NavigationParams) !&Document {
	// Stub: in full implementation would set up browsing context, window, etc.
	mut doc := &Document{}
	doc.type_ = type_
	doc.content_type = content_type
	doc.readiness = .loading
	return doc
}

// create corresponds to Document::create
pub fn Document.create(url URL) &Document {
	mut doc := &Document{}
	doc.url = url
	return doc
}

// create_for_fragment_parsing corresponds to Document::create_for_fragment_parsing
pub fn Document.create_for_fragment_parsing() &Document {
	mut doc := &Document{}
	doc.temporary_document_for_fragment_parsing = .yes
	return doc
}

// construct_impl corresponds to Document::construct_impl (DOM Document() constructor)
pub fn Document.construct_impl() &Document {
	mut doc := Document.create(url_about_blank())
	return doc
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

pub fn (d &Document) get_origin() Origin {
	return d.origin_
}

pub fn (mut d Document) set_origin(o Origin) {
	d.origin_ = o
}

pub fn (mut d Document) set_url(url URL) {
	if d.url == url {
		return
	}
	d.url = url
	d.respond_to_base_url_changes()
}

// fallback_base_url - https://html.spec.whatwg.org/multipage/urls-and-fetching.html#fallback-base-url
pub fn (d &Document) fallback_base_url() URL {
	// Stub: simplified - returns document URL
	return d.url
}

// base_url - https://html.spec.whatwg.org/multipage/urls-and-fetching.html#document-base-url
pub fn (d &Document) base_url() URL {
	// Stub: in full implementation checks first <base> element
	return d.fallback_base_url()
}

pub fn (d &Document) encoding_parse_url(url string) ?URL {
	// Stub
	return URL{url}
}

pub fn (d &Document) encoding_parse_and_serialize_url(url string) ?string {
	parsed := d.encoding_parse_url(url) or { return none }
	return parsed.serialize()
}

pub fn (mut d Document) respond_to_base_url_changes() {
	// Stub: would invalidate style for :link/:visited pseudo-classes
}

pub fn (mut d Document) update_base_element() {
	// Stub: scans tree for <base> elements
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

pub fn (d &Document) in_quirks_mode() bool {
	return d.quirks_mode == .yes
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

pub fn (mut d Document) update_readiness(readiness_value DocumentReadyState) {
	if d.readiness == readiness_value {
		return
	}
	d.readiness = readiness_value
	// Stub: would fire readystatechange event and update timing info
}

// --- Selection ---

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

pub fn (d &Document) cookie() !string {
	if d.is_cookie_averse() {
		return ''
	}
	// Stub: would query the cookie jar
	return d.cookie_cache
}

pub fn (mut d Document) set_cookie(cookie_string string) ! {
	if d.is_cookie_averse() {
		return
	}
	// Stub: would parse and store cookie
	d.cookie_cache = cookie_string
}

pub fn (d &Document) is_cookie_averse() bool {
	// A Document is cookie-averse if it has no browsing context and is not a cookie-averse Document
	return d.browsing_context == unsafe { nil }
}

// --- Document element / body / head / title ---

pub fn (d &Document) document_element() ?&Element {
	// Stub: returns first child Element
	return none
}

pub fn (d &Document) html_element() ?&HTMLHtmlElement {
	// Stub
	return none
}

pub fn (d &Document) head() ?&HTMLHeadElement {
	// Stub
	return none
}

pub fn (d &Document) title_element() ?&HTMLTitleElement {
	// Stub
	return none
}

pub fn (d &Document) body() ?&HTMLElement {
	// Stub: first body or frameset child of html element
	return none
}

pub fn (mut d Document) set_body(new_body &HTMLElement) ! {
	// Stub
}

pub fn (d &Document) title() string {
	// Stub: would return stripped/collapsed whitespace title text
	return ''
}

pub fn (mut d Document) set_title(title string) ! {
	// Stub: would create/update title element
}

pub fn (d &Document) dir() string {
	// Stub
	return ''
}

pub fn (mut d Document) set_dir(dir string) {
	// Stub
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
	// Stub: would read from body element
	return ''
}

pub fn (mut d Document) set_fg_color(value string) {
	// Stub
}

pub fn (d &Document) link_color() string {
	return ''
}

pub fn (mut d Document) set_link_color(value string) {
	// Stub
}

pub fn (d &Document) vlink_color() string {
	return ''
}

pub fn (mut d Document) set_vlink_color(value string) {
	// Stub
}

pub fn (d &Document) alink_color() string {
	return ''
}

pub fn (mut d Document) set_alink_color(value string) {
	// Stub
}

pub fn (d &Document) bg_color() string {
	return ''
}

pub fn (mut d Document) set_bg_color(value string) {
	// Stub
}

pub fn (d &Document) supported_color_schemes() ?[]string {
	return d.supported_color_schemes
}

pub fn (mut d Document) obtain_supported_color_schemes() {
	// Stub
}

pub fn (mut d Document) obtain_theme_color() {
	// Stub
}

// --- Style ---

pub fn (mut d Document) update_style() {
	// Stub: would run style computation
}

pub fn (mut d Document) update_animated_style_if_needed() {
	if !d.needs_animated_style_update {
		return
	}
	d.needs_animated_style_update = false
	// Stub
}

pub fn (mut d Document) update_paint_and_hit_testing_properties_if_needed() {
	// Stub
}

// --- Layout ---

pub fn (mut d Document) update_layout(reason UpdateLayoutReason) {
	_ = reason
	// Stub: massive function that triggers full layout computation
}

pub fn (d &Document) layout_is_up_to_date() bool {
	return !d.needs_full_style_update && !d.needs_full_layout_tree_update
}

pub fn (mut d Document) invalidate_layout_tree(reason InvalidateLayoutTreeReason) {
	_ = reason
	d.needs_full_layout_tree_update = true
}

pub fn (mut d Document) invalidate_stacking_context_tree() {
	// Stub
}

pub fn (mut d Document) tear_down_layout_tree() {
	d.layout_root = unsafe { nil }
	d.paintable_ = unsafe { nil }
	d.needs_full_layout_tree_update = true
}

// --- Node creation ---

pub fn (d &Document) create_element(local_name string) !&Element {
	// Stub
	return &Element{}
}

pub fn (d &Document) create_element_ns(namespace_ ?string, qualified_name string) !&Element {
	// Stub
	return &Element{}
}

pub fn (d &Document) create_document_fragment() &DocumentFragment {
	return &DocumentFragment{}
}

pub fn (d &Document) create_text_node(data string) &Text {
	return &Text{}
}

pub fn (d &Document) create_cdata_section(data string) !&CDATASection {
	if d.is_html_document() {
		return error('InvalidStateError: createCDATASection on HTML document')
	}
	return &CDATASection{}
}

pub fn (d &Document) create_comment(data string) &Comment {
	return &Comment{}
}

pub fn (d &Document) create_processing_instruction(target string, data string) !&ProcessingInstruction {
	// Stub: would validate target
	return &ProcessingInstruction{}
}

pub fn (d &Document) create_attribute(local_name string) !&Attr {
	// Stub: would validate name
	return &Attr{}
}

pub fn (d &Document) create_attribute_ns(namespace_ ?string, qualified_name string) !&Attr {
	// Stub
	return &Attr{}
}

pub fn (d &Document) create_event(iface string) !&Event {
	// Stub: legacy createEvent
	return &Event{}
}

pub fn (d &Document) create_range() &Range {
	return &Range{}
}

// --- Node operations ---

pub fn (d &Document) import_node(node &Node, deep bool) !&Node {
	// Stub
	return &Node{}
}

pub fn (mut d Document) adopt_node(node &Node) {
	// Stub: would re-parent node into this document
}

pub fn (mut d Document) adopt_node_binding(node &Node) !&Node {
	// Stub
	return node
}

// --- Doctype & compat ---

pub fn (d &Document) doctype() ?&DocumentType {
	// Stub: find first DocumentType child
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
	d.focused_area = node or { unsafe { nil } }
	// Stub: would fire focus/blur events
}

pub fn (d &Document) last_focus_trigger_() FocusTrigger {
	return d.last_focus_trigger
}

pub fn (mut d Document) set_last_focus_trigger(trigger FocusTrigger) {
	d.last_focus_trigger = trigger
}

pub fn (d &Document) active_element() ?&Element {
	if d.active_element_ == unsafe { nil } {
		return none
	}
	return d.active_element_
}

pub fn (mut d Document) set_active_element(element ?&Element) {
	d.active_element_ = element or { unsafe { nil } }
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

pub fn (mut d Document) try_to_scroll_to_the_fragment() {
	// Stub
}

pub fn (mut d Document) scroll_to_the_fragment() {
	// Stub
}

pub fn (mut d Document) scroll_to_the_beginning_of_the_document() {
	// Stub
}

// --- Template ---

pub fn (d &Document) created_for_appropriate_template_contents() bool {
	return d.created_for_appropriate_template_contents
}

pub fn (mut d Document) appropriate_template_contents_owner_document() &Document {
	// Stub
	if d.appropriate_template_contents_owner_document != unsafe { nil } {
		return d.appropriate_template_contents_owner_document
	}
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
}

// --- Dynamic markup insertion ---

pub fn (mut d Document) write(text []string) ! {
	// Stub
}

pub fn (mut d Document) writeln(text []string) ! {
	// Stub
}

pub fn (mut d Document) open_document() !&Document {
	if d.is_xml_document() {
		return error('InvalidStateError: open() called on XML document')
	}
	if d.throw_on_dynamic_markup_insertion_counter > 0 {
		return error('InvalidStateError: throw-on-dynamic-markup-insertion-counter > 0')
	}
	// Stub: would clear document, create parser, etc.
	d.set_quirks_mode(.no)
	d.update_readiness(.loading)
	return d
}

pub fn (mut d Document) open_window(url string, name string, features string) ?&WindowProxy {
	// Stub
	return none
}

pub fn (mut d Document) close() ! {
	if d.is_xml_document() {
		return error('InvalidStateError: close() called on XML document')
	}
	if d.throw_on_dynamic_markup_insertion_counter > 0 {
		return error('InvalidStateError: throw-on-dynamic-markup-insertion-counter > 0')
	}
	// Stub
}

// --- Default view ---

pub fn (d &Document) default_view() ?&WindowProxy {
	if d.browsing_context == unsafe { nil } {
		return none
	}
	// Stub: would return browsing context's WindowProxy
	return none
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

pub fn (mut d Document) implementation() ?&DOMImplementation {
	// Stub: lazy-init
	return none
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

pub fn (d &Document) get_location() ?&Location {
	// Stub
	return none
}

// --- Loading ---

pub fn (d &Document) anything_is_delaying_the_load_event() bool {
	return d.number_of_things_delaying_the_load_event > 0
}

pub fn (mut d Document) increment_number_of_things_delaying_the_load_event() {
	d.number_of_things_delaying_the_load_event++
}

pub fn (mut d Document) decrement_number_of_things_delaying_the_load_event() {
	d.number_of_things_delaying_the_load_event--
}

pub fn (mut d Document) completely_finish_loading() {
	// Stub
}

pub fn (d &Document) is_completely_loaded() bool {
	return d.last_modified_ != none
}

// --- Page showing / visibility ---

pub fn (mut d Document) set_page_showing(page_showing bool) {
	d.page_showing = page_showing
}

pub fn (d &Document) hidden() bool {
	return d.visibility_state == .hidden
}

pub fn (d &Document) visibility_state_string() string {
	return match d.visibility_state {
		.visible { 'visible' }
		.hidden { 'hidden' }
	}
}

pub fn (d &Document) visibility_state_value() VisibilityState {
	return d.visibility_state
}

pub fn (mut d Document) update_the_visibility_state(state VisibilityState) {
	if d.visibility_state == state {
		return
	}
	d.visibility_state = state
	// Stub: would fire visibilitychange event
}

// --- Media queries ---

pub fn (mut d Document) evaluate_media_queries_and_report_changes() {
	// Stub
}

pub fn (mut d Document) add_media_query_list(mql &MediaQueryList) {
	d.media_query_lists << mql
}

// --- Resize / Scroll ---

pub fn (mut d Document) run_the_resize_steps() {
	// Stub
}

pub fn (mut d Document) run_the_scroll_steps() {
	// Stub
}

// --- Focus state ---

pub fn (d &Document) has_focus_for_bindings() bool {
	// Stub
	return false
}

pub fn (d &Document) has_focus() bool {
	// Stub
	return false
}

pub fn (d &Document) allow_focus() bool {
	// Stub
	return true
}

// --- Parser management ---

pub fn (mut d Document) set_parser(parser &HTMLParser) {
	d.parser = parser
}

pub fn (mut d Document) detach_parser() {
	d.parser = unsafe { nil }
	d.active_parser_was_aborted = true
}

pub fn (d &Document) active_parser() ?&HTMLParser {
	if d.parser == unsafe { nil } {
		return none
	}
	return d.parser
}

pub fn (d &Document) is_temporary_document_for_fragment_parsing() bool {
	return d.temporary_document_for_fragment_parsing == .yes
}

// --- Name validation ---

pub fn is_valid_name(name string) bool {
	if name.len == 0 {
		return false
	}
	// Stub: simplified validation
	first := name[0]
	if !is_valid_name_start_character(first) {
		return false
	}
	for i := 1; i < name.len; i++ {
		if !is_valid_name_character(name[i]) {
			return false
		}
	}
	return true
}

fn is_valid_name_start_character(c u8) bool {
	return c == `:` || (c >= `A` && c <= `Z`) || c == `_` || (c >= `a` && c <= `z`)
}

fn is_valid_name_character(c u8) bool {
	return is_valid_name_start_character(c) || c == `-` || c == `.` || (c >= `0` && c <= `9`)
}

// --- Node iterators / tree walkers ---

pub fn (d &Document) create_node_iterator(root &Node, what_to_show u32, filter ?&NodeFilter) &NodeIterator {
	// Stub
	return &NodeIterator{}
}

pub fn (d &Document) create_tree_walker(root &Node, what_to_show u32, filter ?&NodeFilter) &TreeWalker {
	// Stub
	return &TreeWalker{}
}

pub fn (mut d Document) register_node_iterator(node_iterator &NodeIterator) {
	d.node_iterators << node_iterator
}

pub fn (mut d Document) unregister_node_iterator(node_iterator &NodeIterator) {
	d.node_iterators = d.node_iterators.filter(it != node_iterator)
}

// --- Document observers ---

pub fn (mut d Document) register_document_observer(observer &DocumentObserver) {
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
	_ = b
	// Stub
}

// --- Collections ---

pub fn (d &Document) get_elements_by_name(name string) &NodeList {
	// Stub
	return &NodeList{}
}

pub fn (mut d Document) applets() &HTMLCollection {
	if d.applets_ == unsafe { nil } {
		d.applets_ = &HTMLCollection{}
	}
	return d.applets_
}

pub fn (mut d Document) anchors() &HTMLCollection {
	if d.anchors_ == unsafe { nil } {
		d.anchors_ = &HTMLCollection{}
	}
	return d.anchors_
}

pub fn (mut d Document) images() &HTMLCollection {
	if d.images_ == unsafe { nil } {
		d.images_ = &HTMLCollection{}
	}
	return d.images_
}

pub fn (mut d Document) embeds() &HTMLCollection {
	if d.embeds_ == unsafe { nil } {
		d.embeds_ = &HTMLCollection{}
	}
	return d.embeds_
}

pub fn (mut d Document) plugins() &HTMLCollection {
	return d.embeds()
}

pub fn (mut d Document) links() &HTMLCollection {
	if d.links_ == unsafe { nil } {
		d.links_ = &HTMLCollection{}
	}
	return d.links_
}

pub fn (mut d Document) forms() &HTMLCollection {
	if d.forms_ == unsafe { nil } {
		d.forms_ = &HTMLCollection{}
	}
	return d.forms_
}

pub fn (mut d Document) scripts() &HTMLCollection {
	if d.scripts_ == unsafe { nil } {
		d.scripts_ = &HTMLCollection{}
	}
	return d.scripts_
}

pub fn (mut d Document) all() &HTMLAllCollection {
	if d.all_ == unsafe { nil } {
		d.all_ = &HTMLAllCollection{}
	}
	return d.all_
}

pub fn (mut d Document) fonts() &FontFaceSet {
	return d.fonts_
}

pub fn (mut d Document) clear() {
	// Stub: does nothing per spec
}

pub fn (d &Document) capture_events() {
	// Stub: does nothing per spec
}

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
	// Stub
}

// --- Referrer ---

pub fn (d &Document) get_referrer() string {
	return d.referrer
}

pub fn (mut d Document) set_referrer(referrer string) {
	d.referrer = referrer
}

// --- Active state ---

pub fn (d &Document) is_fully_active() bool {
	// Stub: simplified check
	return d.browsing_context != unsafe { nil }
}

pub fn (d &Document) is_active() bool {
	return d.browsing_context != unsafe { nil }
}

pub fn (d &Document) has_a_style_sheet_that_is_blocking_scripts() bool {
	return d.script_blocking_style_sheet_set.len > 0 || d.pending_css_import_rules.len > 0
}

pub fn (d &Document) has_no_style_sheet_that_is_blocking_scripts() bool {
	return !d.has_a_style_sheet_that_is_blocking_scripts()
}

// --- Domain ---

pub fn (d &Document) domain() string {
	// Stub
	return ''
}

pub fn (mut d Document) set_domain(domain string) ! {
	// Stub
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

pub fn (d &Document) descendant_navigables() []&Navigable {
	// Stub
	return []
}

pub fn (d &Document) inclusive_descendant_navigables() []&Navigable {
	// Stub
	return []
}

pub fn (d &Document) ancestor_navigables() []&Navigable {
	// Stub
	return []
}

pub fn (d &Document) inclusive_ancestor_navigables() []&Navigable {
	// Stub
	return []
}

pub fn (d &Document) document_tree_child_navigables() []&Navigable {
	// Stub
	return []
}

// --- Document lifecycle ---

pub fn (d &Document) has_been_destroyed() bool {
	return d.has_been_destroyed
}

pub fn (mut d Document) destroy() {
	d.has_been_destroyed = true
	// Stub: would tear down layout, abort loads, etc.
	d.tear_down_layout_tree()
}

pub fn (mut d Document) abort() {
	// Stub: would abort active parser, remove pending events, etc.
	if d.parser != unsafe { nil } {
		d.active_parser_was_aborted = true
	}
}

pub fn (mut d Document) unload() {
	// Stub
	d.unload_counter++
	// ... would run unloading cleanup steps
	d.unload_counter--
}

pub fn (mut d Document) make_active() {
	// Stub
}

pub fn (mut d Document) make_unsalvageable(reason string) {
	d.salvageable = false
	// Stub: would propagate to descendant navigables
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
	d.hovered_node = node or { unsafe { nil } }
	// Stub: would invalidate style for :hover affected elements
}

pub fn (d &Document) get_hovered_node() ?&Node {
	if d.hovered_node == unsafe { nil } {
		return none
	}
	return d.hovered_node
}

// --- Exec command (stubs) ---

pub fn (mut d Document) exec_command(command string, show_ui bool, value string) !bool {
	// Stub
	return false
}

pub fn (d &Document) query_command_enabled(command string) !bool {
	// Stub
	return false
}

pub fn (d &Document) query_command_indeterm(command string) !bool {
	// Stub
	return false
}

pub fn (d &Document) query_command_state(command string) !bool {
	// Stub
	return false
}

pub fn (d &Document) query_command_supported(command string) !bool {
	// Stub
	return false
}

pub fn (d &Document) query_command_value(command string) !string {
	// Stub
	return ''
}

// --- XPath (stubs) ---

pub fn (d &Document) create_expression(expression string, resolver ?&XPathNSResolver) !&XPathExpression {
	// Stub
	return &XPathExpression{}
}

pub fn (d &Document) evaluate_xpath(expression string, context_node &Node, resolver ?&XPathNSResolver, type_ u16, result ?&XPathResult) !&XPathResult {
	// Stub
	return &XPathResult{}
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

pub fn (d &Document) is_allowed_to_use_feature(feature PolicyControlledFeature) bool {
	_ = feature
	// Stub
	return true
}

// --- Accessibility ---

pub fn (d &Document) dump_accessibility_tree_as_json() string {
	// Stub
	return '{}'
}

pub fn (d &Document) dump_dom_tree_as_json() string {
	// Stub
	return '{}'
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

pub fn (mut d Document) run_the_update_intersection_observations_steps(time f64) {
	_ = time
	// Stub
}

pub fn (mut d Document) start_intersection_observing_a_lazy_loading_element(element &Element) {
	_ = element
	// Stub
}

pub fn (mut d Document) stop_intersection_observing_a_lazy_loading_element(element &Element) {
	_ = element
	// Stub
}

// --- Resize observations ---

pub fn (mut d Document) gather_active_observations_at_depth(depth int) {
	_ = depth
	// Stub
}

pub fn (mut d Document) broadcast_active_resize_observations() int {
	// Stub
	return 0
}

pub fn (d &Document) has_active_resize_observations() bool {
	// Stub
	return false
}

pub fn (d &Document) has_skipped_resize_observations() bool {
	// Stub
	return false
}

// --- Adopted style sheets ---

pub fn (mut d Document) set_adopted_style_sheets(value VoidPtr) ! {
	// Stub
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
	// Stub
}

// --- Declarative refresh ---

pub fn (mut d Document) shared_declarative_refresh_steps(input string) {
	_ = input
	// Stub: would parse meta refresh content
}

// --- Animations ---

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

pub fn (mut d Document) update_animations_and_send_events(timestamp f64) {
	_ = timestamp
	// Stub
}

pub fn (mut d Document) remove_replaced_animations() {
	// Stub
}

pub fn (d &Document) get_animations() ![]&Animation {
	// Stub
	return []
}

pub fn (d &Document) transition_generation() int {
	return d.transition_generation
}

// --- Element ID/Name tracking ---

pub fn (mut d Document) element_id_changed(element &Element, old_id ?string) {
	_ = element
	_ = old_id
	// Stub
}

pub fn (mut d Document) element_with_id_was_added(element &Element) {
	_ = element
	// Stub
}

pub fn (mut d Document) element_with_id_was_removed(element &Element) {
	_ = element
	// Stub
}

pub fn (mut d Document) element_name_changed(element &Element) {
	_ = element
	// Stub
}

pub fn (mut d Document) element_with_name_was_added(element &Element) {
	_ = element
	// Stub
}

pub fn (mut d Document) element_with_name_was_removed(element &Element) {
	_ = element
	// Stub
}

// --- Form elements ---

pub fn (mut d Document) add_form_associated_element_with_form_attribute(element &FormAssociatedElement) {
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
	d.design_mode_enabled = enabled
}

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

pub fn (d &Document) element_from_point(x f64, y f64) ?&Element {
	// Stub
	return none
}

pub fn (d &Document) elements_from_point(x f64, y f64) []&Element {
	// Stub
	return []
}

pub fn (d &Document) scrolling_element() ?&Element {
	// Stub
	return none
}

// --- Named properties ---

pub fn (d &Document) supported_property_names() []string {
	// Stub
	return []
}

// --- Shadow roots ---

pub fn (mut d Document) register_shadow_root(shadow_root &ShadowRoot) {
	d.shadow_roots << shadow_root
}

pub fn (mut d Document) unregister_shadow_root(shadow_root &ShadowRoot) {
	d.shadow_roots = d.shadow_roots.filter(it != shadow_root)
}

// --- Top layer ---

pub fn (mut d Document) add_an_element_to_the_top_layer(element &Element) {
	d.top_layer_elements << element
	d.invalidate_layout_tree(.document_add_an_element_to_the_top_layer)
}

pub fn (mut d Document) request_an_element_to_be_remove_from_the_top_layer(element &Element) {
	d.top_layer_pending_removals << element
	d.invalidate_layout_tree(.document_request_an_element_to_be_removed_from_the_top_layer)
}

pub fn (mut d Document) remove_an_element_from_the_top_layer_immediately(element &Element) {
	d.top_layer_elements = d.top_layer_elements.filter(it != element)
	d.top_layer_pending_removals = d.top_layer_pending_removals.filter(it != element)
	d.invalidate_layout_tree(.document_immediately_remove_element_from_the_top_layer)
}

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
	_ = query
	_ = case_sensitivity
	// Stub
	return []
}

// --- HTML parsing ---

pub fn (mut d Document) parse_html_from_a_string(html string) {
	_ = html
	// Stub
}

// --- Cursor ---

pub fn (d &Document) cursor_position() ?&Position {
	// Stub
	return none
}

pub fn (mut d Document) reset_cursor_blink_cycle() {
	d.cursor_blink_state = true
	// Stub: would restart timer
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
	// Stub
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

pub fn (mut d Document) steps_to_fire_beforeunload(unload_prompt_shown bool) StepsToFireBeforeunloadResult {
	_ = unload_prompt_shown
	// Stub
	return StepsToFireBeforeunloadResult{}
}

// --- Event handlers ---

pub fn (d &Document) onreadystatechange() ?&CallbackType {
	// Stub
	return none
}

pub fn (mut d Document) set_onreadystatechange(value ?&CallbackType) {
	// Stub
}

pub fn (d &Document) onvisibilitychange() ?&CallbackType {
	// Stub
	return none
}

pub fn (mut d Document) set_onvisibilitychange(value ?&CallbackType) {
	// Stub
}

pub fn (d &Document) onfullscreenchange() ?&CallbackType {
	// Stub
	return none
}

pub fn (mut d Document) set_onfullscreenchange(value ?&CallbackType) {
	// Stub
}

pub fn (d &Document) onfullscreenerror() ?&CallbackType {
	// Stub
	return none
}

pub fn (mut d Document) set_onfullscreenerror(value ?&CallbackType) {
	// Stub
}

// --- View transitions ---

pub fn (mut d Document) start_view_transition(update_callback ?&CallbackType) &ViewTransition {
	vt := &ViewTransition{}
	d.active_view_transition = vt
	return vt
}

pub fn (mut d Document) perform_pending_transition_operations() {
	// Stub
}

pub fn (mut d Document) flush_the_update_callback_queue() {
	d.update_callback_queue.clear()
}

pub fn (mut d Document) view_transition_page_visibility_change_steps() {
	// Stub
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

pub fn (mut d Document) run_fullscreen_steps() {
	// Stub
}

pub fn (mut d Document) append_pending_fullscreen_change(type_ PendingFullscreenEventType, element &Element) {
	d.pending_fullscreen_events << PendingFullscreenEvent{
		type_:   type_
		element: element
	}
}

pub fn (d &Document) fullscreen_element() ?&Element {
	// Stub: last element in top layer that has fullscreen flag
	return none
}

pub fn (d &Document) fullscreen_element_for_bindings() ?&Element {
	// Stub
	return d.fullscreen_element()
}

pub fn (d &Document) fullscreen() bool {
	return d.fullscreen_element() != none
}

pub fn (d &Document) fullscreen_enabled() bool {
	// Stub
	return true
}

pub fn (mut d Document) fully_exit_fullscreen() {
	// Stub
}

pub fn (mut d Document) exit_fullscreen() &Promise {
	// Stub
	return &Promise{}
}

pub fn (mut d Document) unfullscreen_element(element &Element) {
	_ = element
	// Stub
}

pub fn (mut d Document) unfullscreen() {
	// Stub
}

pub fn (d &Document) is_simple_fullscreen_document() bool {
	// Stub
	return false
}

// --- Render blocking ---

pub fn (d &Document) is_render_blocked() bool {
	return d.render_blocking_elements.len > 0
}

pub fn (d &Document) allows_adding_render_blocking_elements() bool {
	// Stub
	return true
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

pub fn (d &Document) container_document() ?&Document {
	// Stub
	return none
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
	// Stub
	return false
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
	_ = for_node
	// Stub
	return none
}

// --- Pointer lock ---

pub fn (mut d Document) exit_pointer_lock() {
	// Stub
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

pub fn (mut d Document) restore_the_history_object_state(entry &SessionHistoryEntry) {
	// Stub
}

pub fn (mut d Document) update_for_history_step_application(entry &SessionHistoryEntry, do_not_reactivate bool, script_history_length int, script_history_index int, navigation_type ?NavigationType) {
	// Stub
}

pub fn (mut d Document) snapshot_source_snapshot_params() &SourceSnapshotParams {
	return &SourceSnapshotParams{}
}

// --- Last modified ---

pub fn (d &Document) last_modified() string {
	// Stub: would format the date
	return ''
}

// --- Populate ---

pub fn (mut d Document) populate_with_html_head_and_body() ! {
	// Stub: would create html, head, body elements and append them
}

// --- Allow declarative shadow roots ---

pub fn (d &Document) get_allow_declarative_shadow_roots() bool {
	return d.allow_declarative_shadow_roots
}

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
	// Stub
	return 'No display list'
}

pub fn (mut d Document) dump_stacking_context_tree() string {
	// Stub
	return 'No stacking context'
}

// --- Style scope ---

pub fn (d &Document) get_style_sheet_source(identifier &StyleSheetIdentifier) ?string {
	_ = identifier
	// Stub
	return none
}

pub fn (mut d Document) ensure_element_shared_css_random_base_value(key string) f64 {
	if key in d.element_shared_css_random_base_value_cache {
		return d.element_shared_css_random_base_value_cache[key]
	}
	// Stub: would generate random value
	d.element_shared_css_random_base_value_cache[key] = 0.5
	return 0.5
}

// --- is_child_allowed ---

pub fn (d &Document) is_child_allowed(node &Node) bool {
	return match node.node_type {
		.document_node, .text_node { false }
		.comment_node { true }
		.document_type_node { true } // Stub: should check if already has one
		.element_node { true } // Stub: should check if already has one
		else { false }
	}
}

// --- Editing host manager ---

pub fn (d &Document) editing_host_manager() &EditingHostManager {
	if d.editing_host_manager_ == unsafe { nil } {
		return &EditingHostManager{}
	}
	return d.editing_host_manager_
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
	// Stub
}

// --- check_favicon ---

pub fn (mut d Document) check_favicon_after_loading_link_resource() {
	// Stub
}

// --- lookup_custom_element_definition ---

pub fn (d &Document) lookup_custom_element_definition(namespace_ ?string, local_name string, is_ ?string) ?VoidPtr {
	// Stub
	return none
}

// --- SVG root element ---

pub fn (d &Document) root_element() ?VoidPtr {
	// Stub: returns SVG root element if document element is SVG
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

// --- is_a_registrable_domain_suffix_of_or_is_equal_to (free function) ---

pub fn is_a_registrable_domain_suffix_of_or_is_equal_to(host_suffix_string string, original_host string) bool {
	// Stub
	return host_suffix_string == original_host
}
