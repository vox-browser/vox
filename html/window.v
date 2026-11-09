// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Literal translation of Libraries/LibWeb/HTML/Window.{h,cpp}. Browser chrome
// operations cross explicit host callbacks because the V workspace does not
// embed Ladybird's PageClient or LibJS realm.
@[has_globals]
module html

import css
import dom
import math
import requestidlecallback
import speech
import time

__global (
	html_all_window_models              = []&WindowModel{}
	html_window_test_mode               bool
	html_window_internals_exposed       bool
	html_window_local_storage_bottles   = map[string]&StorageBottle{}
	html_window_session_storage_bottles = map[string]&StorageBottle{}
	html_window_storage_hub             &StorageHub
)

pub enum WindowIterationDecision {
	continue_
	@break
}

pub enum WindowType {
	existing_or_none
	new_and_unrestricted
	new_with_no_opener
}

pub struct OpenedWindow {
pub:
	navigable   ?&BrowsingContextModel
	no_opener   TokenizedFeature
	window_type WindowType
}

pub struct WindowOpenResult {
pub:
	window_proxy ?&WindowProxyModel
}

pub enum WindowScrollBehavior {
	auto_
	smooth
	instant
}

pub struct ScrollToOptions {
pub:
	behavior WindowScrollBehavior
	left     ?f64
	top      ?f64
}

pub struct SpecifierResolution {
pub:
	serialized_base_url                           ?string
	specifier                                     string
	specifier_is_null_or_url_like_that_is_special bool
}

pub type WindowAlertHook = fn(string)

pub type WindowConfirmHook = fn(string) bool

pub type WindowPromptHook = fn(string, string) ?string

pub type WindowCookieStoreFactory = fn() voidptr

pub struct WindowHostConfiguration {
pub:
	screen_width            f64 = 800
	screen_height           f64 = 600
	available_screen_width  f64 = 800
	available_screen_height f64 = 600
	window_x                int
	window_y                int
	outer_width             int = 800
	outer_height            int = 600
	device_pixel_ratio      f64 = 1.0
	preferred_color_scheme  string = 'light'
	preferred_contrast      string = 'no-preference'
	preferred_motion        string = 'no-preference'
	alert_hook              ?WindowAlertHook
	confirm_hook            ?WindowConfirmHook
	prompt_hook             ?WindowPromptHook
	cookie_store_factory    ?WindowCookieStoreFactory
}

pub type WindowIdleCallbackHandler = fn(requestidlecallback.IdleDeadline) !

@[heap]
pub struct WindowIdleCallback {
pub:
	handler WindowIdleCallbackHandler = unsafe { nil }
	handle  u32
pub mut:
	timeout_timer_id ?i32
}

pub struct WindowNamedObjects {
pub:
	navigables []&BrowsingContextModel
	elements   []&dom.Element
}

@[heap]
pub struct WindowNamedCollection {
pub:
	root     &dom.Document
	name     string
	elements []&dom.Element
}

fn register_window_model(window &WindowModel) {
	for existing in html_all_window_models {
		if existing == window {
			return
		}
	}
	html_all_window_models << window
}

pub fn all_windows() []&WindowModel {
	return html_all_window_models.clone()
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#get-noopener-for-window-open
fn get_noopener_for_window_open(source_document &dom.Document, tokenized_features map[string]string, url ?dom.URL) TokenizedFeature {
	// Blob URL entries belong to the URL-store layer, which is outside the
	// compact DOM URL boundary. Ordinary feature parsing is otherwise exact.
	_ = source_document
	_ = url
	if value := tokenized_features['noopener'] {
		return parse_boolean_feature(value)
	}
	return .no
}

fn window_storage_hub() &StorageHub {
	if html_window_storage_hub == unsafe { nil } {
		html_window_storage_hub = StorageHub.create()
	}
	return html_window_storage_hub
}

fn window_current_time_ms() f64 {
	return f64(time.sys_mono_now()) / 1_000_000.0
}

fn normalize_window_scroll_value(value f64) f64 {
	if math.is_nan(value) || math.is_inf(value, 0) {
		return 0
	}
	return value
}

// Window::for_each_active
pub fn WindowModel.for_each_active(callback fn(&WindowModel) WindowIterationDecision) {
	windows := html_all_window_models.clone()
	for window in windows {
		if !window.associated_document().is_fully_active() {
			continue
		}
		if callback(window) == .@break {
			break
		}
	}
}

pub fn (mut window WindowModel) set_host_configuration(configuration WindowHostConfiguration) {
	window.host_configuration_ = configuration
	window.window_x_ = configuration.window_x
	window.window_y_ = configuration.window_y
	window.outer_width_ = configuration.outer_width
	window.outer_height_ = configuration.outer_height
	window.device_pixel_ratio_ = configuration.device_pixel_ratio
}

pub fn (window &WindowModel) host_configuration() WindowHostConfiguration {
	return window.host_configuration_
}

// Window::set_associated_document
pub fn (mut window WindowModel) set_associated_document(document &dom.Document) {
	window.Window.set_associated_document(document)
}

// Window::set_current_event
pub fn (mut window WindowModel) set_current_event(event ?&dom.Event) {
	window.Window.set_current_event(event)
}

pub fn (window &WindowModel) current_event() ?&dom.Event {
	return window.Window.current_event()
}

// https://dom.spec.whatwg.org/#dom-window-event
pub fn (window &WindowModel) event() ?&dom.Event {
	return window.current_event()
}

// https://html.spec.whatwg.org/multipage/window-object.html#window-open-steps
pub fn (mut window WindowModel) window_open_steps(url string, target string, features string) !WindowOpenResult {
	opened := window.window_open_steps_internal(url, target, features)!
	target_context := opened.navigable or { return WindowOpenResult{} }
	if opened.no_opener == .yes || opened.window_type == .new_with_no_opener {
		return WindowOpenResult{}
	}
	return WindowOpenResult{
		window_proxy: target_context.window_proxy()
	}
}

// https://html.spec.whatwg.org/multipage/window-object.html#window-open-steps
pub fn (mut window WindowModel) window_open_steps_internal(url string, target_ string, features string) !OpenedWindow {
	if main_thread_event_loop().termination_nesting_level != 0 {
		return OpenedWindow{
			no_opener: .no
			window_type: .existing_or_none
		}
	}

	source_document := window.associated_document()
	mut url_record := ?dom.URL(none)
	if url != '' {
		url_record = source_document.encoding_parse_url(url) or {
			return error("SyntaxError: Invalid URL '${url}'")
		}
	}

	mut target := target_
	if target == '' {
		target = '_blank'
	}
	mut tokenized_features := tokenize_open_features(features)
	mut no_referrer := TokenizedFeature.no
	if value := tokenized_features['noreferrer'] {
		no_referrer = parse_boolean_feature(value)
	}
	mut no_opener := get_noopener_for_window_open(source_document, tokenized_features, url_record)
	tokenized_features.delete('noopener')
	tokenized_features.delete('noreferrer')
	if no_referrer == .yes {
		no_opener = .yes
	}

	mut target_context := window.browsing_context().choose_a_browsing_context(target)
	mut window_type := WindowType.existing_or_none
	if target_context == none {
		mut opener_context := window.browsing_context()
		mut group := opener_context.group() or {
			page := if source_document.page() == unsafe { nil } {
				&dom.Page{}
			} else {
				source_document.page()
			}
			mut new_group := BrowsingContextGroup.create(page)
			new_group.append_model(opener_context)
			new_group
		}
		created := BrowsingContextModel.create_a_new_auxiliary_browsing_context_and_document(if source_document.page() == unsafe { nil } {
			&dom.Page{}
		} else {
			source_document.page()
		}, opener_context)!
		_ = group
		target_context = created.browsing_context
		window_type = if no_opener == .yes {
			.new_with_no_opener
		} else {
			.new_and_unrestricted
		}
	}

	mut chosen := target_context or {
		return OpenedWindow{
			no_opener: no_opener
			window_type: window_type
		}
	}
	if record := url_record {
		if record.scheme() == 'javascript' && javascript_url_is_blocked_by_csp(source_document,record) {
			return OpenedWindow{navigable:chosen,no_opener:no_opener,window_type:window_type}
		}
	}
	if window_type in [.new_and_unrestricted, .new_with_no_opener] {
		chosen.set_popup(check_if_a_popup_window_is_requested(tokenized_features) == .yes)
		mut target_document := chosen.active_document() or {
			return OpenedWindow{
				navigable: chosen
				no_opener: no_opener
				window_type: window_type
			}
		}
		// Declare the captured URL before optional selection. The old V C
		// generator otherwise assigns its heap local before declaring it.
		mut navigation_url := dom.url_about_blank()
		if value := url_record { navigation_url = value }
		target_document.set_url(navigation_url)
		if no_opener == .yes {
			chosen.set_opener(none)
		}
	} else {
		if record := url_record {
			if mut target_document := chosen.active_document() {
				target_document.set_url(record)
			}
		}
		if no_opener == .no {
			chosen.set_opener(window.browsing_context())
		}
	}

	return OpenedWindow{
		navigable: chosen
		no_opener: no_opener
		window_type: window_type
	}
}

// Window overrides EventTarget dispatch with the legacy target override flag.
pub fn (window &WindowModel) dispatch_event(event &dom.Event) bool {
	return window.Window.EventTarget.dispatch_event(event)
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#fire-a-page-transition-event
pub fn (window &WindowModel) fire_a_page_transition_event(event_name string, persisted bool) {
	mut event := dom.PageTransitionEvent.create(event_name, dom.PageTransitionEventInit{
		EventInit: dom.EventInit{
			bubbles: true
			cancelable: true
		}
		persisted: persisted
	})
	mut base_event := unsafe { &dom.Event(event) }
	base_event.set_is_trusted(true)
	window.dispatch_event(base_event)
}

pub fn (window &WindowModel) page() &dom.Page {
	return window.associated_document().page()
}

pub fn (window &WindowModel) query_media_feature(media_feature css.MediaFeatureID) ?css.MediaFeatureValue {
	inner_width := window.inner_width()
	inner_height := window.inner_height()
	configuration := window.host_configuration_
	return match media_feature {
		.any_hover, .hover { css.MediaFeatureValue.from_ident('hover') }
		.any_pointer, .pointer { css.MediaFeatureValue.from_ident('fine') }
		.aspect_ratio {
			css.MediaFeatureValue.from_ratio(css.Ratio.new(f64(inner_width), f64(inner_height)))
		}
		.color { css.MediaFeatureValue.from_integer(8) }
		.color_gamut, .video_color_gamut { css.MediaFeatureValue.from_ident('srgb') }
		.color_index, .grid, .monochrome { css.MediaFeatureValue.from_integer(0) }
		.device_aspect_ratio {
			css.MediaFeatureValue.from_ratio(css.Ratio.new(configuration.screen_width, configuration.screen_height))
		}
		.device_height {
			css.MediaFeatureValue.from_length(css.Length.make_px(configuration.screen_height))
		}
		.device_width {
			css.MediaFeatureValue.from_length(css.Length.make_px(configuration.screen_width))
		}
		.display_mode { css.MediaFeatureValue.from_ident('browser') }
		.dynamic_range, .video_dynamic_range { css.MediaFeatureValue.from_ident('standard') }
		.environment_blending { css.MediaFeatureValue.from_ident('opaque') }
		.forced_colors, .inverted_colors, .scan { css.MediaFeatureValue.from_ident('none') }
		.height { css.MediaFeatureValue.from_length(css.Length.make_px(f64(inner_height))) }
		.horizontal_viewport_segments, .vertical_viewport_segments {
			css.MediaFeatureValue.from_integer(1)
		}
		.nav_controls { css.MediaFeatureValue.from_ident('back') }
		.orientation {
			css.MediaFeatureValue.from_ident(if inner_height >= inner_width {
				'portrait'
			} else {
				'landscape'
			})
		}
		.overflow_block, .overflow_inline { css.MediaFeatureValue.from_ident('scroll') }
		.prefers_color_scheme {
			css.MediaFeatureValue.from_ident(configuration.preferred_color_scheme)
		}
		.prefers_contrast { css.MediaFeatureValue.from_ident(configuration.preferred_contrast) }
		.prefers_reduced_transparency {
			css.MediaFeatureValue.from_ident(if window.associated_document().prefers_reduced_transparency() {
				'reduce'
			} else { 'no-preference' })
		}
		.prefers_reduced_data {
			css.MediaFeatureValue.from_ident('no-preference')
		}
		.prefers_reduced_motion {
			document := window.associated_document()
			page := document.page()
			preference := if page != unsafe { nil }
				&& page.prefers_reduced_motion_callback != unsafe { nil } {
				if document.prefers_reduced_motion() { 'reduce' } else { 'no-preference' }
			} else { configuration.preferred_motion }
			css.MediaFeatureValue.from_ident(preference)
		}
		.resolution {
			css.MediaFeatureValue.from_resolution(css.Resolution.make_dots_per_pixel(window.device_pixel_ratio()))
		}
		.scripting {
			document_node := unsafe { &dom.Node(window.associated_document()) }
			css.MediaFeatureValue.from_ident(if document_node.is_scripting_enabled() {
				'enabled'
			} else {
				'none'
			})
		}
		.update { css.MediaFeatureValue.from_ident('fast') }
		.width { css.MediaFeatureValue.from_length(css.Length.make_px(f64(inner_width))) }
	}
}

// https://html.spec.whatwg.org/multipage/webstorage.html#dom-localstorage
pub fn (mut window WindowModel) local_storage() !&Storage {
	if storage := window.local_storage_ {
		return storage
	}
	key := window.associated_document().origin().serialize()
	bottle := html_window_local_storage_bottles[key] or {
		created := StorageBottle.create(5 * 1024 * 1024)
		html_window_local_storage_bottles[key] = created
		created
	}
	mut hub := window_storage_hub()
	storage := Storage.create(.local, bottle, mut hub, window.associated_document().origin(), window.storage_traversable_id(), window.associated_document().url)
	window.local_storage_bottle_ = bottle
	window.storage_hub_ = hub
	window.local_storage_ = storage
	return storage
}

// https://html.spec.whatwg.org/multipage/webstorage.html#dom-sessionstorage
pub fn (mut window WindowModel) session_storage() !&Storage {
	if storage := window.session_storage_ {
		return storage
	}
	key := '${window.storage_traversable_id()}|${window.associated_document().origin().serialize()}'
	bottle := html_window_session_storage_bottles[key] or {
		created := StorageBottle.create(5 * 1024 * 1024)
		html_window_session_storage_bottles[key] = created
		created
	}
	mut hub := window_storage_hub()
	storage := Storage.create(.session, bottle, mut hub, window.associated_document().origin(), window.storage_traversable_id(), window.associated_document().url)
	window.session_storage_bottle_ = bottle
	window.storage_hub_ = hub
	window.session_storage_ = storage
	return storage
}

fn (window &WindowModel) storage_traversable_id() string {
	top := window.browsing_context().top_level_browsing_context() or { window.browsing_context() }
	return '${voidptr(top)}'
}

pub fn (window &WindowModel) has_sticky_activation() bool {
	return window.Window.has_sticky_activation()
}

pub fn (window &WindowModel) has_transient_activation() bool {
	return window.Window.has_transient_activation()
}

// https://html.spec.whatwg.org/multipage/interaction.html#consume-user-activation
pub fn (mut window WindowModel) consume_user_activation() {
	window.Window.consume_user_activation()
}

// https://w3c.github.io/requestidlecallback/#start-an-idle-period-algorithm
pub fn (mut window WindowModel) start_an_idle_period() {
	if window.associated_document().hidden() {
		return
	}
	for handle in window.idle_request_callback_order_ {
		if callback := window.idle_request_callbacks_[handle] {
			window.runnable_idle_callbacks_[handle] = callback
			window.runnable_idle_callback_order_ << handle
		}
	}
	window.idle_request_callbacks_.clear()
	window.idle_request_callback_order_.clear()
	if window.runnable_idle_callbacks_.len == 0 {
		return
	}
	window_pointer := unsafe { &window }
	queue_a_task(.idle_task, main_thread_event_loop(), window.associated_document(), fn [window_pointer] () {
		mut callback_window := unsafe { window_pointer }
		callback_window.invoke_idle_callbacks()
	})
}

pub fn (window &WindowModel) has_idle_callbacks() bool {
	return window.idle_request_callbacks_.len > 0 || window.runnable_idle_callbacks_.len > 0
}

// https://w3c.github.io/requestidlecallback/#invoke-idle-callbacks-algorithm
pub fn (mut window WindowModel) invoke_idle_callbacks() {
	if window_current_time_ms() >= main_thread_event_loop().compute_deadline() || window.runnable_idle_callbacks_.len == 0 {
		return
	}
	if window.runnable_idle_callback_order_.len == 0 {
		return
	}
	handle := window.runnable_idle_callback_order_[0]
	window.runnable_idle_callback_order_.delete(0)
	mut callback := window.runnable_idle_callbacks_[handle] or { return }
	window.runnable_idle_callbacks_.delete(handle)
	if timer_id := callback.timeout_timer_id {
		mut scope := window.global_scope_
		scope.clear_timeout(timer_id)
		callback.timeout_timer_id = none
	}
	callback.handler(requestidlecallback.IdleDeadline.create(false)) or {}
	if window.runnable_idle_callbacks_.len > 0 {
		window_pointer := unsafe { &window }
		queue_a_task(.idle_task, main_thread_event_loop(), window.associated_document(), fn [window_pointer] () {
			mut callback_window := unsafe { window_pointer }
			callback_window.invoke_idle_callbacks()
		})
	}
}

// https://w3c.github.io/requestidlecallback/#invoke-idle-callback-timeout-algorithm
fn (mut window WindowModel) invoke_idle_callback_timeout(handle u32) {
	mut callback := if pending := window.idle_request_callbacks_[handle] {
		window.idle_request_callbacks_.delete(handle)
		window.idle_request_callback_order_ = window.idle_request_callback_order_.filter(it != handle)
		pending
	} else if runnable := window.runnable_idle_callbacks_[handle] {
		window.runnable_idle_callbacks_.delete(handle)
		window.runnable_idle_callback_order_ = window.runnable_idle_callback_order_.filter(it != handle)
		runnable
	} else {
		return
	}
	if timer_id := callback.timeout_timer_id {
		mut scope := window.global_scope_
		scope.clear_timeout(timer_id)
		callback.timeout_timer_id = none
	}
	callback.handler(requestidlecallback.IdleDeadline.create(true)) or {}
}

pub fn (window &WindowModel) navigable() ?&dom.Navigable {
	return window.associated_document().navigable()
}

pub fn (window &WindowModel) navigable_model() &NavigableModel {
	host := window.navigable() or { panic('WindowModel has no associated navigable') }
	return navigable_model_for_host(host) or { panic('WindowModel navigable has no HTML model') }
}

pub fn (mut window WindowModel) pdf_viewer_plugin_objects() []&Plugin {
	if !window.navigator().pdf_viewer_enabled() {
		return []
	}
	if window.pdf_viewer_plugin_objects_.len == 0 {
		for name in pdf_viewer_plugin_names {
			window.pdf_viewer_plugin_objects_ << &Plugin{
				name_: name
			}
		}
	}
	return window.pdf_viewer_plugin_objects_.clone()
}

pub fn (mut window WindowModel) pdf_viewer_mime_type_objects() []&MimeType {
	if !window.navigator().pdf_viewer_enabled() {
		return []
	}
	if window.pdf_viewer_mime_type_objects_.len == 0 {
		for type_ in pdf_viewer_mime_types {
			window.pdf_viewer_mime_type_objects_ << &MimeType{
				type_: type_
			}
		}
	}
	return window.pdf_viewer_mime_type_objects_.clone()
}

pub fn WindowModel.in_test_mode() bool {
	return html_window_test_mode
}

pub fn WindowModel.set_enable_test_mode(exposed bool) {
	html_window_test_mode = exposed
}

pub fn WindowModel.set_internals_object_exposed(exposed bool) {
	html_window_internals_exposed = exposed
}

pub fn WindowModel.is_internals_object_exposed() bool {
	return html_window_internals_exposed
}

pub fn (mut window WindowModel) initialize_web_interfaces(_ &WindowEnvironmentSettingsObject) ! {
	window.interfaces_initialized_ = true
}

pub fn (window &WindowModel) interfaces_initialized() bool {
	return window.interfaces_initialized_
}

// https://webidl.spec.whatwg.org/#platform-object-setprototypeof
pub fn (mut window WindowModel) internal_set_prototype_of(prototype dom.JSValue) bool {
	return js_values_are_same(window.prototype_, prototype)
}

pub fn (mut window WindowModel) set_opener(value dom.JSValue) ! {
	if value.kind == .null_ {
		mut context := window.browsing_context()
		context.set_opener(none)
		window.opener_disowned_ = true
		return
	}
	window.named_properties_['opener'] = value
}

pub fn (window &WindowModel) frame_element() ?&dom.Element {
	container := window.browsing_context().container() or { return none }
	if !container.document().origin().is_same_origin(window.associated_document().origin()) {
		return none
	}
	return container
}

pub fn (mut window WindowModel) open(url ?string, target ?string, features ?string) !WindowOpenResult {
	return window.window_open_steps(url or { '' }, target or { '_blank' }, features or { '' })!
}

pub fn (mut window WindowModel) cookie_store() voidptr {
	if window.cookie_store_created_ {
		return window.cookie_store_
	}
	window.cookie_store_created_ = true
	if factory := window.host_configuration_.cookie_store_factory {
		window.cookie_store_ = factory()
	}
	return window.cookie_store_
}

pub fn (mut window WindowModel) speech_synthesis() &speech.SpeechSynthesis {
	if synthesis := window.speech_synthesis_ {
		return synthesis
	}
	synthesis := speech.SpeechSynthesis.create()
	window.speech_synthesis_ = synthesis
	return synthesis
}

pub fn (window &WindowModel) alert(message string) {
	if hook := window.host_configuration_.alert_hook {
		hook(message)
	}
}

pub fn (window &WindowModel) confirm(message ?string) bool {
	if hook := window.host_configuration_.confirm_hook {
		return hook(message or { '' })
	}
	return false
}

pub fn (window &WindowModel) prompt(message ?string, default_ ?string) ?string {
	if hook := window.host_configuration_.prompt_hook {
		return hook(message or { '' }, default_ or { '' })
	}
	return none
}

fn window_pseudo_element_from_string(value string) ?dom.PseudoElement {
	name := value.trim_left(':').to_lower()
	return match name {
		'before' { dom.PseudoElement.before }
		'after' { dom.PseudoElement.after }
		'first-line' { dom.PseudoElement.first_line }
		'first-letter' { dom.PseudoElement.first_letter }
		'marker' { dom.PseudoElement.marker }
		'placeholder' { dom.PseudoElement.placeholder }
		'selection' { dom.PseudoElement.selection }
		'backdrop' { dom.PseudoElement.backdrop }
		else { none }
	}
}

// https://drafts.csswg.org/cssom/#dom-window-getcomputedstyle
pub fn (window &WindowModel) get_computed_style(element &dom.Element, pseudo_element ?string) &css.CSSStyleProperties {
	_ = window
	mut object := ?dom.AbstractElement(dom.AbstractElement.new(element, none))
	if pseudo := pseudo_element {
		if pseudo.starts_with(':') {
			if parsed := window_pseudo_element_from_string(pseudo) {
				object = dom.AbstractElement.new(element, parsed)
			} else {
				object = none
			}
		}
	}
	return css.CSSStyleProperties.create_resolved_style(object)
}

// https://w3c.github.io/csswg-drafts/cssom-view/#dom-window-matchmedia
pub fn (window &WindowModel) match_media(query string) &css.MediaQueryList {
	queries := css.parse_css_media_query_list_value_logic(query)
	mut list := css.MediaQueryList.create(window.associated_document(), queries)
	list.register_with_document()
	return list
}

// https://w3c.github.io/csswg-drafts/cssom-view/#dom-window-screen
pub fn (mut window WindowModel) screen() &css.Screen {
	if screen := window.screen_ {
		return screen
	}
	configuration := window.host_configuration_
	mut screen := css.Screen.create()
	screen.web_exposed_screen_area = css.CSSPixelRect.new(0, 0, configuration.screen_width, configuration.screen_height)
	screen.web_exposed_available_screen_area = css.CSSPixelRect.new(0, 0, configuration.available_screen_width, configuration.available_screen_height)
	screen.initialize()
	window.screen_ = screen
	return screen
}

pub fn (mut window WindowModel) visual_viewport() ?&css.VisualViewport {
	if !window.associated_document().is_fully_active() {
		return none
	}
	mut document := unsafe { &dom.Document(window.associated_document()) }
	viewport := document.visual_viewport()
	return unsafe { &css.VisualViewport(viewport.visual_viewport_record()) }
}

// https://w3c.github.io/csswg-drafts/cssom-view/#dom-window-innerwidth
pub fn (window &WindowModel) inner_width() int {
	// The document viewport is the concrete viewport owned by the translated
	// Navigable. A detached document has no cached navigable and therefore no
	// viewport, matching the upstream zero result.
	if window.associated_document().cached_navigable() == none {
		return 0
	}
	return int(window.associated_document().viewport_rect().width)
}

// https://w3c.github.io/csswg-drafts/cssom-view/#dom-window-innerheight
pub fn (window &WindowModel) inner_height() int {
	if window.associated_document().cached_navigable() == none {
		return 0
	}
	return int(window.associated_document().viewport_rect().height)
}

// https://w3c.github.io/csswg-drafts/cssom-view/#dom-window-devicepixelratio
pub fn (window &WindowModel) device_pixel_ratio() f64 {
	return window.device_pixel_ratio_
}

// The upstream implementation takes the CSSOM View optional early return for
// these four APIs, so they deliberately perform no host operation.
pub fn (window &WindowModel) move_to(_x int, _y int) {}

pub fn (window &WindowModel) move_by(_x int, _y int) {}

pub fn (window &WindowModel) resize_to(_width int, _height int) {}

pub fn (window &WindowModel) resize_by(_width int, _height int) {}

pub fn (window &WindowModel) scroll_x() f64 {
	if window.associated_document().cached_navigable() == none {
		return 0
	}
	return window.associated_document().viewport_rect().x
}

pub fn (window &WindowModel) scroll_y() f64 {
	if window.associated_document().cached_navigable() == none {
		return 0
	}
	return window.associated_document().viewport_rect().y
}

// https://drafts.csswg.org/cssom-view/#dom-window-scroll
pub fn (mut window WindowModel) scroll(options ScrollToOptions) &dom.Promise {
	return window.scroll_with_snap_strategy(options, none)
}

fn (mut window WindowModel) scroll_with_snap_strategy(options ScrollToOptions,
	strategy ?dom.ScrollSnapSelectionStrategy_) &dom.Promise {
	if window.associated_document().cached_navigable() == none {
		return dom.Promise.resolved(dom.js_undefined())
	}
	viewport := window.associated_document().viewport_rect()
	x := normalize_window_scroll_value(options.left or { viewport.x })
	y := normalize_window_scroll_value(options.top or { viewport.y })
	mut host := unsafe { &dom.Window(window.associated_document().window) }
	behavior := match options.behavior { .auto_ { dom.ScrollBehavior.auto_ } .smooth { dom.ScrollBehavior.smooth } .instant { dom.ScrollBehavior.instant } }
	selection_strategy := strategy or { dom.ScrollSnapSelectionStrategy_{} }
	return host.scroll_with_options(x, y, behavior, selection_strategy)
}

pub fn (mut window WindowModel) scroll_xy(x f64, y f64) &dom.Promise {
	return window.scroll(ScrollToOptions{
		left: x
		top: y
	})
}

// https://drafts.csswg.org/cssom-view/#dom-window-scrollby
pub fn (mut window WindowModel) scroll_by(options ScrollToOptions) &dom.Promise {
	delta_x := normalize_window_scroll_value(options.left or { 0 })
	delta_y := normalize_window_scroll_value(options.top or { 0 })
	start := dom.CSSPixelPoint_{ x_: window.scroll_x(), y_: window.scroll_y() }
	return window.scroll_with_snap_strategy(ScrollToOptions{
		behavior: options.behavior
		left: delta_x + start.x()
		top: delta_y + start.y()
	}, dom.ScrollSnapSelectionStrategy_{
		type_: .end_position_and_direction
		start_offset: start
		displacement: dom.CSSPixelPoint_{ x_: delta_x, y_: delta_y }
	})
}

pub fn (mut window WindowModel) scroll_by_xy(x f64, y f64) &dom.Promise {
	return window.scroll_by(ScrollToOptions{
		left: x
		top: y
	})
}

pub fn (window &WindowModel) screen_x() int {
	return window.window_x_
}

pub fn (window &WindowModel) screen_y() int {
	return window.window_y_
}

pub fn (window &WindowModel) outer_width() int {
	return window.outer_width_
}

pub fn (window &WindowModel) outer_height() int {
	return window.outer_height_
}

pub fn (window &WindowModel) animation_frame_callback_driver() &AnimationFrameCallbackDriver {
	return window.animation_driver_
}

// https://w3c.github.io/requestidlecallback/#dom-window-requestidlecallback
pub fn (mut window WindowModel) request_idle_callback(handler WindowIdleCallbackHandler, options requestidlecallback.IdleRequestOptions) u32 {
	window.idle_callback_identifier_++
	handle := window.idle_callback_identifier_
	mut callback := &WindowIdleCallback{
		handler: handler
		handle: handle
	}
	window.idle_request_callbacks_[handle] = callback
	window.idle_request_callback_order_ << handle
	if timeout := options.timeout {
		if timeout > 0 {
			window_pointer := unsafe { &window }
			mut scope := window.global_scope_
			timer_id := scope.run_steps_after_a_timeout(if timeout > u32(2_147_483_647) {
				2_147_483_647
			} else {
				int(timeout)
			}, fn [window_pointer, handle] () {
				queue_a_task(.idle_task, main_thread_event_loop(), window_pointer.associated_document(), fn [window_pointer, handle] () {
					mut callback_window := unsafe { window_pointer }
					callback_window.invoke_idle_callback_timeout(handle)
				})
			})
			callback.timeout_timer_id = timer_id
		}
	}
	return handle
}

pub fn (mut window WindowModel) cancel_idle_callback(handle u32) {
	mut callback := window.idle_request_callbacks_[handle] or {
		window.runnable_idle_callbacks_[handle] or { return }
	}
	window.idle_request_callbacks_.delete(handle)
	window.runnable_idle_callbacks_.delete(handle)
	window.idle_request_callback_order_ = window.idle_request_callback_order_.filter(it != handle)
	window.runnable_idle_callback_order_ = window.runnable_idle_callback_order_.filter(it != handle)
	if timer_id := callback.timeout_timer_id {
		mut scope := window.global_scope_
		scope.clear_timeout(timer_id)
		callback.timeout_timer_id = none
	}
}

pub fn (window &WindowModel) get_selection() ?&dom.Selection {
	return window.associated_document().get_selection()
}

pub fn (window &WindowModel) capture_events() {}

pub fn (window &WindowModel) release_events() {}

pub fn (mut window WindowModel) external() &External {
	if external := window.external_ {
		return external
	}
	external := External.create()
	window.external_ = external
	return external
}

// https://html.spec.whatwg.org/multipage/nav-history-apis.html#document-tree-child-navigable-target-name-property-set
pub fn (window &WindowModel) document_tree_child_navigable_target_name_property_set() map[string]&BrowsingContextModel {
	mut names := map[string]&BrowsingContextModel{}
	for child in window.browsing_context().children() {
		name := child.target_name()
		if name == '' || name in names {
			continue
		}
		document := child.active_document() or { continue }
		if document.origin().is_same_origin(window.associated_document().origin()) {
			names[name] = child
		}
	}
	return names
}

pub fn (window &WindowModel) named_objects(name string) WindowNamedObjects {
	mut navigables := []&BrowsingContextModel{}
	for child in window.browsing_context().children() {
		if child.target_name() == name {
			navigables << child
		}
	}
	mut elements := []&dom.Element{}
	for element in window.associated_document().potentially_named_elements() {
		if _ := element.id() {
			// Elements with an id are appended from ElementByIdMap below, in
			// document order, exactly as in Window::named_objects().
			continue
		}
		if element_name := element.get_name() {
			if element_name == name {
				elements << element
			}
		}
	}
	elements << window.associated_document().elements_with_id(name)
	return WindowNamedObjects{
		navigables: navigables
		elements: elements
	}
}

fn window_named_collection_elements(collection &WindowNamedCollection) []&dom.Element {
	mut elements := []&dom.Element{}
	for element in collection.root.descendant_elements() {
		local_name := element.local_name()
		mut name_matches := false
		if element_name := element.get_name() {
			name_matches = local_name in ['embed', 'form', 'img', 'object'] && element_name == collection.name
		}
		mut id_matches := false
		if id := element.id() {
			id_matches = id == collection.name
		}
		if name_matches || id_matches {
			elements << element
		}
	}
	return elements
}

pub fn (collection &WindowNamedCollection) length() int {
	return window_named_collection_elements(collection).len
}

pub fn (collection &WindowNamedCollection) item(index int) ?&dom.Element {
	elements := window_named_collection_elements(collection)
	if index < 0 || index >= elements.len {
		return none
	}
	return elements[index]
}

pub fn (window &WindowModel) named_item_value(name string) dom.JSValue {
	objects := window.named_objects(name)
	if objects.navigables.len > 0 {
		if proxy := objects.navigables[0].window_proxy() {
			return dom.js_object(voidptr(proxy))
		}
	}
	if objects.elements.len == 1 {
		return dom.js_object(voidptr(objects.elements[0]))
	}
	collection := &WindowNamedCollection{
		root: window.associated_document()
		name: name
		elements: objects.elements
	}
	mut mutable_window := unsafe { &WindowModel(window) }
	mutable_window.named_collections_ << collection
	return dom.js_object(voidptr(collection))
}

pub fn (mut window WindowModel) find(query string) bool {
	if query == '' {
		return false
	}
	return window.page().find_from_window(query)
}
