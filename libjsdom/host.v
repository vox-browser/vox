module libjsdom

import dom
import fetch
import html
import libjs
import platform
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
	collection_prototype &libjs.Object = unsafe { nil }
	event_prototype      &libjs.Object = unsafe { nil }
	url_prototype        &libjs.Object = unsafe { nil }
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
	owned_documents []&dom.Document
	dom_exception_prototype &libjs.Object = unsafe { nil }
	dom_exceptions map[voidptr]&webidl.DOMException
	registry_prototype &libjs.Object = unsafe { nil }
	registries map[voidptr]&RegistryBinding
	active_registries map[u64]voidptr
	navigator_prototype &libjs.Object = unsafe { nil }
	navigator_object &libjs.Object = unsafe { nil }
	navigator_native &html.Navigator = unsafe { nil }
	navigator_languages []string
	navigator_frozen_languages &libjs.Object = unsafe { nil }
}

pub fn Host.create(vm &libjs.VM, realm &libjs.Realm, document &dom.Document, hooks Hooks) !&Host {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut host := &Host{ vm: vm, realm: realm, document: document, hooks: hooks }
	host.install_nodes()!
	host.install_node_interfaces()!
	host.install_html_element_interfaces()!
	host.install_dom_exceptions()!
	host.install_custom_elements()!
	host.install_navigator()!
	host.install_styles()
	host.install_urls()!
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
	host.close_fetch()
	for listener in host.listeners {
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
	host.events.clear()
	host.event_wrappers.clear()
	host.style_wrappers.clear()
	host.style_elements.clear()
	host.headers.clear()
	host.headers_wrappers.clear()
	host.headers_iterators.clear()
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
