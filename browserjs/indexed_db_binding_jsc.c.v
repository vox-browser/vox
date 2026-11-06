@[has_globals]
module browserjs

import dom
import html
import indexeddb
import math
import platform
import webidl

enum IndexedDBBindingKind {
	factory
	request
	open_request
	database
	transaction
	object_store
	index
	cursor
}

@[heap]
struct IndexedDBBindingEntry {
	kind   IndexedDBBindingKind
	target &dom.EventTarget = dom.EventTarget.new()
mut:
	factory     &html.GlobalScopeIndexedDBFactory = unsafe { nil }
	request     &indexeddb.IDBRequest             = unsafe { nil }
	open        &indexeddb.IDBOpenDBRequest       = unsafe { nil }
	database    &indexeddb.IDBDatabase            = unsafe { nil }
	transaction &indexeddb.IDBTransaction         = unsafe { nil }
	store       &indexeddb.IDBObjectStore         = unsafe { nil }
	index       &indexeddb.IDBIndex               = unsafe { nil }
	source      voidptr
	result      voidptr
	error_value voidptr
}

@[heap]
struct IndexedDBBinding {
	clone &StructuredCloneBridge
mut:
	prototypes     []voidptr
	make_list      voidptr
	sequence       voidptr
	key_path       voidptr
	entries        map[voidptr]&IndexedDBBindingEntry
	wrappers       map[voidptr]voidptr
	stores         map[string]voidptr
	version_events map[voidptr]indexeddb.IDBVersionChangeEvent
	closed         bool
}

__global indexed_db_bindings_ = map[voidptr]&IndexedDBBinding{}

pub fn (mut runtime Runtime) install_indexed_db_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in indexed_db_bindings_ { return }
	runtime.install_window_event_handler_binding()!
	mut binding := &IndexedDBBinding{ clone: StructuredCloneBridge.create(&runtime)! }
	operation := runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		settings := runtime.scripting_settings_ or { return error('IndexedDB requires an owning environment') }
		if settings.responsible_document() == none { return error('IndexedDB requires an owning document') }
		// Databases and connection queues are shared across navigations. Their
		// records and later mutations must outlive this Window's DOM payload.
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		return runtime.indexed_db_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			value := webidl.exception_value(err)
			if value.dom_exception_ != none {
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(value)!)
			}
			message := err.msg()
			if message.contains(':') {
				name := message.all_before(':')
				if name in ['AbortError', 'ConstraintError', 'DataError', 'DataCloneError',
					'InvalidAccessError', 'InvalidStateError', 'NotFoundError', 'ReadOnlyError',
					'SecurityError', 'SyntaxError', 'TransactionInactiveError', 'VersionError'] {
					return runtime.actual_javascript_exception(runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create(name, message.all_after(':').trim_space())))!)
				}
			}
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(indexed_db_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	values := runtime.retain_javascript_value(runtime.call_javascript_function(factory, global, [
		operation,
		global,
	])!)!
	defer { runtime.release_javascript_value(values) }
	mut exception := unsafe { nil }
	for index in 0 .. 9 {
		binding.prototypes << runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, values, u32(index), &exception))!
	}
	binding.make_list = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, values, 9, &exception))!
	binding.sequence = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, values, 10, &exception))!
	binding.key_path = runtime.retain_javascript_value(C.vox_jsc_JSObjectGetPropertyAtIndex(runtime.context, values, 11, &exception))!
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.install_event_wrapper_provider(EventWrapperProvider{
		owner:  voidptr(binding)
		create: fn [owner, binding] (event &dom.Event) !voidptr {
			if voidptr(event) !in binding.version_events { return unsafe { nil } }
			mut runtime := unsafe { &Runtime(owner) }
			events := runtime.event_binding()!
			return runtime.call_javascript_function(events.factory, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
				runtime.binding_string('event'),
				binding.prototypes[8],
			])
		}
	})!
	indexed_db_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		binding.closed = true
		for _, mut entry in binding.entries {
			if entry.kind == .database { entry.database.close() }
		}
		binding.entries = {}
		binding.wrappers = {}
		binding.stores = {}
		binding.version_events = {}
		indexed_db_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) indexed_db_wrap(mut binding IndexedDBBinding, identity voidptr, entry &IndexedDBBindingEntry) !voidptr {
	if wrapper := binding.wrappers[identity] { return wrapper }
	wrapper := runtime.javascript_event_target(entry.target, binding.prototypes[int(entry.kind)])!
	binding.wrappers[identity] = wrapper
	binding.entries[wrapper] = entry
	return wrapper
}

fn (mut runtime Runtime) indexed_db_dispatch(mut binding IndexedDBBinding, entry &IndexedDBBindingEntry, name string, version ?indexeddb.IDBVersionChangeEvent) bool {
	if binding.closed { return true }
	event := dom.Event.create(name, dom.EventInit{ bubbles: name in ['error', 'abort'], cancelable: name == 'error' })
	if record := version { binding.version_events[voidptr(event)] = record }
	mut legacy := dom.LegacyListenerExceptionFlag{}
	accepted := dom.EventDispatcher.dispatch_with_legacy_output(entry.target, event, false, mut legacy)
	if entry.kind in [.request, .open_request] {
		mut request := entry.request
		request.event_listener_threw_ = legacy.did_listeners_throw
	}
	return accepted
}

fn (mut runtime Runtime) indexed_db_request(mut binding IndexedDBBinding, request &indexeddb.IDBRequest, open ?&indexeddb.IDBOpenDBRequest, source voidptr) !voidptr {
	mut entry := &IndexedDBBindingEntry{ kind: if open != none { .open_request } else { .request }, request: request, source: source }
	if value := open { entry.open = value }
	wrapper := runtime.indexed_db_wrap(mut binding, voidptr(request), entry)!
	owner := voidptr(&runtime)
	mut pending := unsafe { &indexeddb.IDBRequest(request) }
	pending.onsucceed_ = fn [owner, mut binding, entry] () {
		if binding.closed {
			if !isnil(entry.request.database) { entry.request.database.close() }
			return
		}
		mut runtime := unsafe { &Runtime(owner) }
		runtime.indexed_db_dispatch(mut binding, entry, 'success', none)
	}
	pending.onerror_ = fn [owner, mut binding, entry] () {
		if binding.closed { return }
		mut runtime := unsafe { &Runtime(owner) }
		mut failed := entry.request
		failed.error_event_canceled_ = !runtime.indexed_db_dispatch(mut binding, entry, 'error', none)
	}
	if mut opening := open {
		opening.onblocked_ = fn [owner, mut binding, entry] () {
			if binding.closed { return }
			mut runtime := unsafe { &Runtime(owner) }
			opening := entry.open
			runtime.indexed_db_dispatch(mut binding, entry, 'blocked', indexeddb.IDBVersionChangeEvent.create('blocked', opening.old_version, opening.new_version))
		}
		opening.onupgradeneeded_ = fn [owner, mut binding, entry] () {
			mut opening := entry.open
			if binding.closed {
				opening.abort_upgrade('AbortError: environment closed') or {}
				return
			}
			mut runtime := unsafe { &Runtime(owner) }
			opening.prepare_upgrade_completion() or {
				opening.abort_upgrade(err.msg()) or {}
				return
			}
			opening.request.ready_state = .done
			runtime.indexed_db_transaction(mut binding, opening.upgrade_transaction) or {
				opening.abort_upgrade(err.msg()) or {}
				return
			}
			event := dom.Event.create('upgradeneeded', dom.EventInit{})
			binding.version_events[voidptr(event)] = indexeddb.IDBVersionChangeEvent.create('upgradeneeded', opening.old_version, opening.new_version)
			mut legacy := dom.LegacyListenerExceptionFlag{}
			dom.EventDispatcher.dispatch_with_legacy_output(entry.target, event, false, mut legacy)
			mut transaction := opening.upgrade_transaction
			if legacy.did_listeners_throw && transaction.state !in [.aborted, .finished] {
				opening.abort_upgrade('AbortError: upgrade listener threw') or {}
			}
			transaction.deactivate()
			if transaction.state == .inactive && transaction.request_list_.is_empty() {
				indexeddb.commit_a_transaction(mut transaction) or { opening.abort_upgrade(err.msg()) or {} }
			}
		}
	}
	return wrapper
}

fn (mut runtime Runtime) indexed_db_database(mut binding IndexedDBBinding, database &indexeddb.IDBDatabase) !voidptr {
	if wrapper := binding.wrappers[voidptr(database)] { return wrapper }
	entry := &IndexedDBBindingEntry{ kind: .database, database: database }
	wrapper := runtime.indexed_db_wrap(mut binding, voidptr(database), entry)!
	owner := voidptr(&runtime)
	mut connection := unsafe { &indexeddb.IDBDatabase(database) }
	connection.onversionchange_ = fn [owner, mut binding, entry] () {
		if binding.closed { return }
		mut runtime := unsafe { &Runtime(owner) }
		records := entry.database.version_change_events
		if records.len > 0 {
			runtime.indexed_db_dispatch(mut binding, entry, 'versionchange', records.last())
		}
	}
	return wrapper
}

fn (mut runtime Runtime) indexed_db_transaction(mut binding IndexedDBBinding, transaction &indexeddb.IDBTransaction) !voidptr {
	if wrapper := binding.wrappers[voidptr(transaction)] { return wrapper }
	entry := &IndexedDBBindingEntry{ kind: .transaction, transaction: transaction }
	wrapper := runtime.indexed_db_wrap(mut binding, voidptr(transaction), entry)!
	owner := voidptr(&runtime)
	mut actual := unsafe { &indexeddb.IDBTransaction(transaction) }
	actual.oncomplete_ = fn [owner, mut binding, entry] () {
		if binding.closed { return }
		mut runtime := unsafe { &Runtime(owner) }
		runtime.indexed_db_dispatch(mut binding, entry, 'complete', none)
	}
	actual.onabort_ = fn [owner, mut binding, entry] () {
		if binding.closed { return }
		mut runtime := unsafe { &Runtime(owner) }
		runtime.indexed_db_dispatch(mut binding, entry, 'abort', none)
	}
	return wrapper
}

fn (mut runtime Runtime) indexed_db_store(mut binding IndexedDBBinding, input indexeddb.IDBObjectStore) !voidptr {
	key := '${uint(input.transaction)}:${input.name()}'
	if wrapper := binding.stores[key] { return wrapper }
	store := &indexeddb.IDBObjectStore{ ...input }
	entry := &IndexedDBBindingEntry{ kind: .object_store, store: store }
	wrapper := runtime.indexed_db_wrap(mut binding, voidptr(store), entry)!
	binding.stores[key] = wrapper
	return wrapper
}

fn (runtime &Runtime) indexed_db_integer(value voidptr) !u64 {
	mut exception := unsafe { nil }
	number := C.vox_jsc_JSValueToNumber(runtime.context, value, &exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	if math.is_nan(number) || math.is_inf(number, 0) || number < 0 || number >= 18446744073709551616.0 {
		return runtime.event_binding_type_error('Value is outside the unsigned long long range')
	}
	return u64(number)
}

fn (mut runtime Runtime) indexed_db_operation(mut binding IndexedDBBinding, args []voidptr) !voidptr {
	if args.len < 2 { return runtime.event_binding_type_error('Missing IndexedDB receiver') }
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	undefined := C.vox_jsc_JSValueMakeUndefined(runtime.context)
	if method in ['globalBrand', 'factory'] {
		target := runtime.native_event_target(receiver)!
		settings := runtime.scripting_settings_ or { return error('Missing IndexedDB environment') }
		if target.data.kind != .window || voidptr(target) != voidptr(settings.global_object()) {
			return runtime.event_binding_type_error('IndexedDB requires its owning Window')
		}
		if method == 'globalBrand' { return undefined }
		mut window := unsafe { &html.WindowModel(target) }
		mut scope := window.window_or_worker_global_scope()
		factory := scope.indexed_db()
		return runtime.indexed_db_wrap(mut binding, voidptr(factory), &IndexedDBBindingEntry{ kind: .factory, factory: factory })
	}
	if method == 'constructVersionEvent' {
		type_ := runtime.binding_dom_string(args[2])!
		dictionary := runtime.ui_event_argument(args, 3)
		bubbles := runtime.event_binding_bool_property(dictionary, 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(dictionary, 'cancelable', false)!
		composed := runtime.event_binding_bool_property(dictionary, 'composed', false)!
		new_value := runtime.ui_event_dictionary_member(dictionary, 'newVersion')!
		new_version := if C.JSValueIsNull(runtime.context, new_value) || C.JSValueIsUndefined(runtime.context, new_value) {
			?u64(none)
		} else {
			?u64(runtime.indexed_db_integer(new_value)!)
		}
		old_value := runtime.ui_event_dictionary_member(dictionary, 'oldVersion')!
		old_version := if C.JSValueIsUndefined(runtime.context, old_value) {
			u64(0)
		} else {
			runtime.indexed_db_integer(old_value)!
		}
		event := dom.Event.new_with_init(type_, dom.EventInit{ bubbles: bubbles, cancelable: cancelable, composed: composed })
		binding.version_events[voidptr(event)] = indexeddb.IDBVersionChangeEvent.create(type_, old_version, new_version)
		runtime.bind_event(receiver, event)!
		return undefined
	}
	if method in ['oldVersion', 'newVersion'] {
		event := runtime.native_event(receiver)!
		version := binding.version_events[voidptr(event)] or { return runtime.event_binding_type_error('Illegal IDBVersionChangeEvent receiver') }
		if method == 'oldVersion' {
			return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(version.old_version))
		}
		return if value := version.new_version {
			C.vox_jsc_JSValueMakeNumber(runtime.context, f64(value))
		} else {
			C.vox_jsc_JSValueMakeNull(runtime.context)
		}
	}
	mut entry := binding.entries[receiver] or { return runtime.event_binding_type_error('Illegal IndexedDB receiver') }
	if method == 'brand' {
		name := runtime.binding_dom_string(args[2])!
		expected := ['IDBFactory', 'IDBRequest', 'IDBOpenDBRequest', 'IDBDatabase', 'IDBTransaction',
			'IDBObjectStore', 'IDBIndex', 'IDBCursor'][int(entry.kind)]
		if name != expected && !(name == 'IDBRequest' && entry.kind == .open_request) {
			return runtime.event_binding_type_error('Illegal ${name} receiver')
		}
		return undefined
	}
	if method == 'getHandler' {
		return runtime.javascript_event_handler(entry.target, runtime.binding_dom_string(args[2])!)
	}
	if method == 'setHandler' {
		runtime.set_javascript_event_handler(entry.target, runtime.binding_dom_string(args[2])!, args[3])!
		return undefined
	}
	if method in ['listLength', 'listItem', 'listContains'] {
		kind := runtime.binding_dom_string(args[2])!
		list := match entry.kind {
			.database { entry.database.object_store_names() }
			.transaction { entry.transaction.object_store_names() }
			.object_store {
				if kind == 'indexNames' { entry.store.index_names() } else { []string{} }
			}
			else { return runtime.event_binding_type_error('Illegal DOMStringList owner') }
		}
		if method == 'listLength' { return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(list.len)) }
		if method == 'listContains' {
			return C.vox_jsc_JSValueMakeBoolean(runtime.context, runtime.binding_dom_string(args[3])! in list)
		}
		index := runtime.indexed_db_integer(args[3])!
		return if index < u64(list.len) {
			runtime.binding_string(list[int(index)])
		} else {
			C.vox_jsc_JSValueMakeNull(runtime.context)
		}
	}
	if method in ['objectStoreNames', 'indexNames'] {
		if entry.kind !in [.database, .transaction, .object_store] {
			return runtime.event_binding_type_error('Illegal name-list receiver')
		}
		return runtime.call_javascript_function(binding.make_list, undefined, [
			receiver,
			args[0],
		])
	}
	match entry.kind {
		.factory {
			if method in ['open', 'deleteDatabase'] {
				name := runtime.binding_dom_string(args[2])!
				if method == 'deleteDatabase' {
					opening := entry.factory.delete_database(name)!
					return runtime.indexed_db_request(mut binding, opening.request, opening, C.vox_jsc_JSValueMakeNull(runtime.context))
				}
				version := if args.len > 3 && !C.JSValueIsUndefined(runtime.context, args[3]) {
					?u64(runtime.indexed_db_integer(args[3])!)
				} else {
					none
				}
				opening := entry.factory.open(name, version)!
				return runtime.indexed_db_request(mut binding, opening.request, opening, C.vox_jsc_JSValueMakeNull(runtime.context))
			}
			if method == 'cmp' {
				first := runtime.indexed_db_key(args[2])!
				second := runtime.indexed_db_key(args[3])!
				return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(entry.factory.cmp(first, second)!))
			}
		}
		.request, .open_request {
			request := entry.request
			if method == 'readyState' { return runtime.binding_string(request.ready_state.str()) }
			if method == 'source' { return entry.source }
			if method == 'transaction' {
				if transaction := request.transaction_ {
					return runtime.indexed_db_transaction(mut binding, transaction)
				}
				return C.vox_jsc_JSValueMakeNull(runtime.context)
			}
			if method in ['error', 'result'] {
				if request.ready_state != .done && !(entry.kind == .open_request && request.result_kind == .database) {
					return error('InvalidStateError: request is pending')
				}
				if method == 'error' {
					if request.error_message == '' { return C.vox_jsc_JSValueMakeNull(runtime.context) }
					if entry.error_value == unsafe { nil } {
						entry.error_value = runtime.retain_javascript_value(runtime.indexed_db_error(request.error_message)!)!
					}
					return entry.error_value
				}
				if request.error_message != '' { return undefined }
				if entry.result != unsafe { nil } { return entry.result }
				result := match request.result_kind {
					.database { runtime.indexed_db_database(mut binding, request.database)! }
					.value { runtime.indexed_db_output(request.value)! }
					.key {
						if key := request.key {
							runtime.indexed_db_output(indexeddb.key_to_value(key)!)!
						} else {
							undefined
						}
					}
					else { undefined }
				}
				entry.result = runtime.retain_javascript_value(result)!
				return result
			}
		}
		.database {
			mut database := entry.database
			if method == 'name' { return runtime.binding_string(database.name()) }
			if method == 'version' {
				return C.vox_jsc_JSValueMakeNumber(runtime.context, f64(database.version()))
			}
			if method == 'close' {
				database.close()
				return undefined
			}
			if method in ['createObjectStore', 'deleteObjectStore'] {
				name := runtime.binding_dom_string(args[2])!
				mut transaction := database.data.upgrade_transaction or { return error('InvalidStateError: no upgrade transaction') }
				if method == 'deleteObjectStore' {
					database.delete_object_store(mut transaction, name)!
					return undefined
				}
				dictionary := runtime.ui_event_argument(args, 3)
				auto_increment := runtime.event_binding_bool_property(dictionary, 'autoIncrement', false)!
				value := runtime.ui_event_dictionary_member(dictionary, 'keyPath')!
				path := if C.JSValueIsNull(runtime.context, value) || C.JSValueIsUndefined(runtime.context, value) {
					?indexeddb.KeyPath(none)
				} else {
					?indexeddb.KeyPath(runtime.indexed_db_key_path(value)!)
				}
				store := database.create_object_store(mut transaction, name, indexeddb.IDBObjectStoreParameters{ key_path: path, auto_increment: auto_increment })!
				return runtime.indexed_db_store(mut binding, store)
			}
			if method == 'transaction' {
				names := runtime.indexed_db_names(args[2])!
				mode_text := if args.len > 3 && !C.JSValueIsUndefined(runtime.context, args[3]) {
					runtime.binding_dom_string(args[3])!
				} else {
					'readonly'
				}
				mode := match mode_text {
					'readonly' { indexeddb.IDBTransactionMode.readonly }
					'readwrite' { indexeddb.IDBTransactionMode.readwrite }
					else { return runtime.event_binding_type_error('Invalid transaction mode') }
				}
				dictionary := runtime.ui_event_argument(args, 4)
				durability_value := runtime.ui_event_dictionary_member(dictionary, 'durability')!
				durability_text := if C.JSValueIsUndefined(runtime.context, durability_value) {
					'default'
				} else {
					runtime.binding_dom_string(durability_value)!
				}
				durability := match durability_text {
					'default' { indexeddb.IDBTransactionDurability.default_ }
					'strict' { indexeddb.IDBTransactionDurability.strict }
					'relaxed' { indexeddb.IDBTransactionDurability.relaxed }
					else {
						return runtime.event_binding_type_error('Invalid transaction durability')
					}
				}
				transaction := database.transaction(names, mode, indexeddb.IDBTransactionOptions{ durability: durability })!
				return runtime.indexed_db_transaction(mut binding, transaction)
			}
		}
		.transaction {
			mut transaction := entry.transaction
			if method == 'db' {
				return runtime.indexed_db_database(mut binding, transaction.database)
			}
			if method == 'mode' { return runtime.binding_string(transaction.mode.str()) }
			if method == 'durability' {
				return runtime.binding_string(transaction.durability.str().trim_right('_'))
			}
			if method == 'error' { return runtime.indexed_db_error(transaction.error_message) }
			if method == 'objectStore' {
				return runtime.indexed_db_store(mut binding, transaction.object_store(runtime.binding_dom_string(args[2])!)!)
			}
			if method == 'abort' {
				transaction.abort('')!
				return undefined
			}
			if method == 'commit' {
				transaction.commit()!
				return undefined
			}
		}
		.object_store {
			mut store := entry.store
			if method == 'name' { return runtime.binding_string(store.name()) }
			if method == 'keyPath' { return runtime.indexed_db_output(store.key_path_value()) }
			if method == 'autoIncrement' {
				return C.vox_jsc_JSValueMakeBoolean(runtime.context, store.auto_increment())
			}
			if method == 'transaction' {
				return runtime.indexed_db_transaction(mut binding, store.transaction)
			}
			if method == 'createIndex' {
				name := runtime.binding_dom_string(args[2])!
				path := runtime.indexed_db_key_path(args[3])!
				dictionary := runtime.ui_event_argument(args, 4)
				multi_entry := runtime.event_binding_bool_property(dictionary, 'multiEntry', false)!
				unique := runtime.event_binding_bool_property(dictionary, 'unique', false)!
				// WebIDL converts all arguments before the native transaction checks.
				created := store.create_index(name, path, indexeddb.IDBIndexParameters{ unique: unique, multi_entry: multi_entry })!
				index := &indexeddb.IDBIndex{ ...created }
				return runtime.indexed_db_wrap(mut binding, voidptr(index), &IndexedDBBindingEntry{ kind: .index, index: index, source: receiver })
			}
			if method == 'get' {
				store.transaction.require_active()!
				key := runtime.indexed_db_key(args[2])!
				request := store.get_async(indexeddb.IDBKeyRange.only(key)!)!
				return runtime.indexed_db_request(mut binding, request, none, receiver)
			}
			if method in ['put', 'add'] {
				store.transaction.require_writable()!
				key := if args.len > 3 && !C.JSValueIsUndefined(runtime.context, args[3]) {
					?indexeddb.Key(runtime.indexed_db_key(args[3])!)
				} else {
					none
				}
				value := runtime.indexed_db_input(args[2])!
				request := store.put_async(value, key, method == 'add')!
				return runtime.indexed_db_request(mut binding, request, none, receiver)
			}
		}
		.index {
			mut index := entry.index
			if method == 'name' { return runtime.binding_string(index.name()) }
			if method == 'setName' {
				index.rename(runtime.binding_dom_string(args[2])!)!
				return undefined
			}
			if method == 'objectStore' { return entry.source }
			if method == 'keyPath' { return runtime.indexed_db_output(index.key_path_value()!) }
			if method == 'multiEntry' {
				return C.vox_jsc_JSValueMakeBoolean(runtime.context, index.multi_entry())
			}
			if method == 'unique' {
				return C.vox_jsc_JSValueMakeBoolean(runtime.context, index.unique())
			}
		}
		else {}
	}
	return runtime.event_binding_type_error('Illegal IndexedDB operation ${method}')
}

fn (mut runtime Runtime) indexed_db_error(message string) !voidptr {
	if message == '' { return C.vox_jsc_JSValueMakeNull(runtime.context) }
	return runtime.javascript_dom_exception(webidl.dom_exception_value(webidl.DOMException.create(message.all_before(':'), message.all_after(':').trim_space())))
}

fn (mut runtime Runtime) indexed_db_names(value voidptr) ![]string {
	if C.JSValueIsString(runtime.context, value) { return [runtime.binding_dom_string(value)!] }
	binding := indexed_db_bindings_[voidptr(&runtime)] or { return error('Missing IndexedDB binding') }
	array := runtime.retain_javascript_value(runtime.call_javascript_function(binding.sequence, C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!)!
	defer { runtime.release_javascript_value(array) }
	length := int(C.vox_jsc_JSValueToNumber(runtime.context, runtime.binding_property(array, 'length')!, unsafe { nil }))
	mut names := []string{cap: length}
	for index in 0 .. length {
		names << runtime.binding_dom_string(runtime.binding_property(array, index.str())!)!
	}
	return names
}

fn (mut runtime Runtime) indexed_db_key_path(value voidptr) !indexeddb.KeyPath {
	binding := indexed_db_bindings_[voidptr(&runtime)] or { return error('Missing IndexedDB binding') }
	converted := runtime.retain_javascript_value(runtime.call_javascript_function(binding.key_path, C.vox_jsc_JSValueMakeUndefined(runtime.context), [value])!)!
	defer { runtime.release_javascript_value(converted) }
	if C.JSValueIsArray(runtime.context, converted) {
		length := int(C.vox_jsc_JSValueToNumber(runtime.context, runtime.binding_property(converted, 'length')!, unsafe { nil }))
		mut path := []string{cap: length}
		for index in 0 .. length {
			path << runtime.binding_dom_string(runtime.binding_property(converted, index.str())!)!
		}
		return indexeddb.KeyPath(path)
	}
	return indexeddb.KeyPath(runtime.binding_dom_string(converted)!)
}

fn (mut runtime Runtime) indexed_db_key(value voidptr) !indexeddb.Key {
	input := runtime.indexed_db_input(value)!
	key := indexeddb.value_to_key(input)
	if !key.is_valid() { return error('DataError: invalid IndexedDB key') }
	return key
}
