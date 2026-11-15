module libjsdom

import dom
import domurl
import css
import fetch
import geometry
import html
import intersectionobserver
import libjs
import platform
import resizeobserver
import webidl

pub struct Hooks {
pub:
	before_callback  ?fn ()
	after_callback   ?fn ()
	can_run_callback ?fn () bool
	changed          ?fn ()
	console          ?fn (string)
	exception        ?fn (string)
}

@[heap]
pub struct Host {
	vm       &libjs.VM
	realm    &libjs.Realm
	document &dom.Document
	hooks    Hooks
mut:
	node_prototype       &libjs.Object = unsafe { nil }
	element_prototype    &libjs.Object = unsafe { nil }
	html_element_prototype &libjs.Object = unsafe { nil }
	html_element_prototypes map[string]&libjs.Object
	html_element_tags map[string]string
	document_prototype   &libjs.Object = unsafe { nil }
	fragment_prototype   &libjs.Object = unsafe { nil }
	character_data_prototype &libjs.Object = unsafe { nil }
	text_prototype &libjs.Object = unsafe { nil }
	comment_prototype &libjs.Object = unsafe { nil }
	cdata_prototype &libjs.Object = unsafe { nil }
	collection_prototype &libjs.Object = unsafe { nil }
	node_list_prototype &libjs.Object = unsafe { nil }
	node_list_wrappers map[voidptr]&libjs.Object
	token_list_prototype &libjs.Object = unsafe { nil }
	token_list_wrappers map[voidptr]&libjs.Object
	event_prototype      &libjs.Object = unsafe { nil }
	event_target_prototype &libjs.Object = unsafe { nil }
	event_target_constructor &libjs.Object = unsafe { nil }
	event_targets map[voidptr]&dom.EventTarget
	event_target_wrappers map[voidptr]&libjs.Object
	read_only_rect_prototype &libjs.Object = unsafe { nil }
	read_only_rects map[voidptr]&geometry.DOMRectReadOnly
	read_only_rect_wrappers map[voidptr]&libjs.Object
	intersection_observer_prototype &libjs.Object = unsafe { nil }
	intersection_entry_prototype &libjs.Object = unsafe { nil }
	intersection_observers map[voidptr]&IntersectionBinding
	intersection_entries map[voidptr]&intersectionobserver.IntersectionObserverEntry
	intersection_entry_wrappers map[voidptr]&libjs.Object
	resize_observer_prototype &libjs.Object = unsafe { nil }
	resize_entry_prototype &libjs.Object = unsafe { nil }
	resize_size_prototype &libjs.Object = unsafe { nil }
	resize_observers map[voidptr]&resizeobserver.ResizeObserver
	resize_targets map[u32]&resizeobserver.ResizeTarget
	resize_entries map[voidptr]&ResizeEntryBinding
	resize_entry_wrappers map[voidptr]&libjs.Object
	resize_sizes map[voidptr]resizeobserver.ResizeObserverSize
	url_prototype        &libjs.Object = unsafe { nil }
	location_url &domurl.DOMURL = unsafe { nil }
	history_object &libjs.Object = unsafe { nil }
	history_binding ?&HistoryBinding
	query_prototype &libjs.Object = unsafe { nil }
	query_iterator_prototype &libjs.Object = unsafe { nil }
	queries map[voidptr]&domurl.URLSearchParams
	query_wrappers map[voidptr]&libjs.Object
	query_iterators map[voidptr]&QueryIteratorBinding
	style_prototype      &libjs.Object = unsafe { nil }
	headers_prototype &libjs.Object = unsafe { nil }
	headers_iterator_prototype &libjs.Object = unsafe { nil }
	headers map[voidptr]&fetch.Headers
	headers_wrappers map[voidptr]&libjs.Object
	headers_iterators map[voidptr]&HeadersIteratorState
	fetch_client ?fetch.RequestClient
	fetch_transport &fetch.FetchHost = unsafe { nil }
	request_prototype &libjs.Object = unsafe { nil }
	response_prototype &libjs.Object = unsafe { nil }
	fetch_requests map[voidptr]&fetch.RequestObject
	fetch_responses map[voidptr]&fetch.ResponseObject
	fetch_wrappers map[voidptr]&libjs.Object
	fetch_operations []&DocumentFetchOperation
	fetch_json_parse libjs.Value
	style_wrappers       map[u32]&libjs.Object
	style_elements       map[voidptr]&dom.Element
	wrappers             map[u32]&libjs.Object
	nodes                map[voidptr]&dom.Node
	events               map[voidptr]&dom.Event
	event_wrappers       map[voidptr]&libjs.Object
	listeners            []Listener
	closures             []voidptr
	closed               bool
	animation_frames map[u32]&AnimationFrameBinding
	retired_frame_closures []voidptr
	idle_callbacks map[u32]&IdleCallbackBinding
	retired_idle_closures []voidptr
	idle_deadline_prototype &libjs.Object = unsafe { nil }
	idle_deadlines map[voidptr]&IdleDeadlineBinding
	microtasks map[u64]&QueuedMicrotaskBinding
	timer_scope_ ?&html.WindowOrWorkerGlobalScopeMixin
	timers map[i32]&TimerBinding
	timer_callback_depth int
	retired_timer_closures []voidptr
	media_query_prototype &libjs.Object = unsafe { nil }
	media_event_prototype &libjs.Object = unsafe { nil }
	media_queries map[voidptr]&css.MediaQueryList
	abort_controller_prototype &libjs.Object = unsafe { nil }
	abort_signal_prototype &libjs.Object = unsafe { nil }
	abort_controllers map[voidptr]&dom.AbortController
	abort_signals map[voidptr]&dom.AbortSignal
	abort_signal_wrappers map[voidptr]&libjs.Object
	owned_documents []&dom.Document
	dom_exception_prototype &libjs.Object = unsafe { nil }
	dom_exceptions map[voidptr]&webidl.DOMException
	dom_exception_wrappers map[voidptr]&libjs.Object
	registry_prototype &libjs.Object = unsafe { nil }
	registries map[voidptr]&RegistryBinding
	active_registries map[u64]voidptr
	navigator_prototype &libjs.Object = unsafe { nil }
	navigator_object &libjs.Object = unsafe { nil }
	navigator_native &html.Navigator = unsafe { nil }
	navigator_languages []string
	navigator_frozen_languages &libjs.Object = unsafe { nil }
	mutation_observer_prototype &libjs.Object = unsafe { nil }
	mutation_record_prototype &libjs.Object = unsafe { nil }
	mutation_queue &dom.MutationObserverDeliveryQueue = unsafe { nil }
	mutation_observers map[voidptr]&ObserverBinding
	mutation_records map[voidptr]&MutationRecordBinding
	mutation_record_wrappers map[voidptr]&libjs.Object
}

pub fn Host.create(vm &libjs.VM, realm &libjs.Realm, document &dom.Document, hooks Hooks) !&Host {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut host := &Host{ vm: vm, realm: realm, document: document, hooks: hooks }
	host.install_nodes()!
	host.install_node_interfaces()!
	host.install_character_data()!
	host.install_node_utilities()
	host.install_document_state()
	host.install_element_selectors()
	host.install_html_element_interfaces()!
	host.install_template_elements()!
	host.install_node_lists()!
	host.install_token_lists()!
	host.install_dom_exceptions()!
	host.install_abort_signals()!
	host.install_custom_elements()!
	host.install_navigator()!
	host.install_mutation_observers()!
	host.install_read_only_rects()
	host.install_intersection_observers()
	host.install_resize_observers()
	host.install_animation_frames()
	host.install_timers()
	host.install_microtasks()
	host.install_idle_callbacks()
	host.install_media_queries()!
	host.install_styles()
	host.install_css_namespace()
	host.install_query_params()!
	host.install_urls()!
	host.install_history()
	host.install_headers()!
	mut global := realm.global_object_record()
	global.define_direct_property(libjs.PropertyName.from_str('document'), host.wrap_node(document.as_node()), libjs.attribute_enumerable)
	for name in ['window', 'self'] {
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(global), libjs.attribute_writable | libjs.attribute_configurable)
	}
	mut console := libjs.Object.create(realm, realm.object_prototype)
	for name in ['log', 'warn', 'error', 'info', 'debug'] {
		host.method(mut console, name, 0, fn [host] (mut vm libjs.VM) !libjs.Value {
			mut messages := []string{}
			for index in 0 .. vm.argument_count() {
				messages << vm.argument(index).to_primitive_string(mut vm)!.str()
			}
			if callback := host.hooks.console { callback(messages.join(' ')) }
			return libjs.js_undefined()
		})
	}
	global.define_direct_property(libjs.PropertyName.from_str('console'), libjs.Value.from_object(console), libjs.attribute_writable | libjs.attribute_configurable)
	return host
}

fn (mut host Host) method(mut object libjs.Object, name string, length int, callback libjs.NativeFunctionPointer) {
	host.method_attributes(mut object, name, length, callback, libjs.attribute_writable | libjs.attribute_configurable)
}

fn (mut host Host) method_attributes(mut object libjs.Object, name string, length int, callback libjs.NativeFunctionPointer, attributes u8) {
	mut vm := host.vm
	method := libjs.NativeFunction.create(mut vm, host.realm, host.realm.function_prototype, callback, f64(length), libjs.PropertyName.from_str(name), none)
	object.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(method.object), attributes)
	host.closures << voidptr(callback)
}

fn (mut host Host) accessor(mut object libjs.Object, name string, getter libjs.NativeFunctionPointer, setter libjs.NativeFunctionPointer) {
	host.accessor_attributes(mut object, name, getter, setter, libjs.attribute_enumerable | libjs.attribute_configurable)
}

fn (mut host Host) accessor_attributes(mut object libjs.Object, name string, getter libjs.NativeFunctionPointer, setter libjs.NativeFunctionPointer, attributes u8) {
	mut vm := host.vm
	get := libjs.NativeFunction.create(mut vm, host.realm, host.realm.function_prototype, getter, 0, libjs.PropertyName.from_str(name), 'get')
	host.closures << voidptr(getter)
	mut set := ?&libjs.Object(none)
	if setter != unsafe { nil } {
		set = libjs.NativeFunction.create(mut vm, host.realm, host.realm.function_prototype, setter, 1, libjs.PropertyName.from_str(name), 'set').object
		host.closures << voidptr(setter)
	}
	object.define_direct_accessor(libjs.PropertyName.from_str(name), get.object, set, attributes)
}

fn (host &Host) require_open(mut vm libjs.VM) ! {
	if host.closed || host.document.has_been_destroyed() {
		return vm.throw_error(.type_error, 'Document runtime is closed')
	}
}

fn (mut host Host) changed() {
	if callback := host.hooks.changed { callback() }
	host.document.request_frame()
}

// Retire bindings together with their owning VM. The embedding must stop VM
// entry before this releases callable closure storage (Runtime.close does so).
pub fn (mut host Host) close() {
	if host.closed { return }
	host.closed = true
	host.close_idle_callbacks()
	host.close_microtasks()
	host.close_timers()
	host.close_animation_frames()
	host.close_mutation_observers()
	host.close_intersection_observers()
	host.close_resize_observers()
	mut owner_document := unsafe { &dom.Document(host.document) }
	owner_document.clear_custom_element_construction_hook(voidptr(&host))
	host.registries.clear()
	host.active_registries.clear()
	host.html_element_prototypes.clear()
	host.html_element_tags.clear()
	host.navigator_object = unsafe { nil }
	host.navigator_native = unsafe { nil }
	host.navigator_frozen_languages = unsafe { nil }
	host.navigator_languages = []
	if mut binding := host.history_binding {
		binding.state = libjs.js_undefined()
		binding.state_cached = false
	}
	host.history_binding = none
	host.history_object = unsafe { nil }
	host.location_url = unsafe { nil }
	host.close_fetch()
	for listener in host.listeners {
		if signal := listener.abort_signal {
			if id := listener.abort_algorithm { mut owner := unsafe { &dom.AbortSignal(signal) }; owner.remove_abort_algorithm(id) }
		}
		if listener.attribute {
			listener.target.set_event_handler_attribute(listener.type_, none)
		} else {
			listener.target.remove_event_listener(listener.type_, listener.native, dom.EventListenerOptions{ capture: listener.capture })
		}
	}
	host.listeners = []
	for mut document in host.owned_documents {
		document.destroy()
		document.finalize()
	}
	host.owned_documents = []
	for callback in host.closures { platform.release_closure(callback) }
	host.closures = []
	host.nodes.clear()
	host.wrappers.clear()
	host.node_list_wrappers.clear()
	host.token_list_wrappers.clear()
	host.events.clear()
	host.event_wrappers.clear()
	host.event_targets.clear()
	host.media_queries.clear()
	host.abort_controllers.clear()
	host.abort_signals.clear()
	host.abort_signal_wrappers.clear()
	host.dom_exception_wrappers.clear()
	host.event_target_wrappers.clear()
	host.read_only_rects.clear()
	host.read_only_rect_wrappers.clear()
	host.style_wrappers.clear()
	host.style_elements.clear()
	host.headers.clear()
	host.headers_wrappers.clear()
	host.headers_iterators.clear()
	host.queries.clear()
	host.query_wrappers.clear()
	host.query_iterators.clear()
	host.dom_exceptions.clear()
	for callback in [host.hooks.before_callback, host.hooks.after_callback, host.hooks.changed] {
		if function := callback { platform.release_closure(voidptr(function)) }
	}
	if callback := host.hooks.console { platform.release_closure(voidptr(callback)) }
	if callback := host.hooks.exception { platform.release_closure(voidptr(callback)) }
	if callback := host.hooks.can_run_callback { platform.release_closure(voidptr(callback)) }
}

pub fn exception_message(err IError) string {
	if libjs.is_throw_completion(err) {
		value := libjs.thrown_value(err)
		if value.is_object() {
			object := value.as_object()
			if kind := object.error_kind() {
				return kind.name() + ': ' + (object.error_message() or { '' })
			}
		}
		return value.str()
	}
	return err.msg()
}
