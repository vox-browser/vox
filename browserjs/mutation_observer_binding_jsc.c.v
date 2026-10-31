@[has_globals]
module browserjs

import dom
import html
import platform
import x.json2

@[heap]
struct MutationObserverBinding {
	document &dom.Document
	resolve  MutationObserverNodeResolver
	encode   MutationObserverRecordEncoder
mut:
	queue        &dom.MutationObserverDeliveryQueue = unsafe { nil }
	notify       voidptr
	make_records voidptr
	observers    map[voidptr]&dom.MutationObserver
	closed       bool
}

__global mutation_observer_bindings_ = map[voidptr]&MutationObserverBinding{}

pub fn (mut runtime Runtime) install_mutation_observer_binding(resolve MutationObserverNodeResolver, encode MutationObserverRecordEncoder) ! {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in mutation_observer_bindings_ { return }
	settings := runtime.scripting_settings_ or { return error('MutationObserver requires an owning environment') }
	if settings.global_object().data.kind != .window {
		return error('MutationObserver requires a Window')
	}
	document := settings.responsible_document() or { return error('MutationObserver requires a Document') }
	runtime.install_microtask_binding()!
	runtime.owned_closures_ << voidptr(resolve)
	runtime.owned_closures_ << voidptr(encode)
	mut binding := &MutationObserverBinding{ document: document, resolve: resolve, encode: encode }
	binding.notify = runtime.make_value_host_function(fn [owner, mut binding] (_ voidptr, _ []voidptr) !voidptr {
		if !binding.closed { binding.queue.notify() }
		runtime := unsafe { &Runtime(owner) }
		return C.JSValueMakeUndefined(runtime.context)
	})!
	binding.queue = dom.MutationObserverDeliveryQueue.create(fn [owner, mut binding] () {
		if binding.closed { return }
		mut runtime := unsafe { &Runtime(owner) }
		runtime.enqueue_javascript_microtask(binding.notify) or { runtime.report_event_callback_exception(err) }
	})
	runtime.define_value_host_function('__ladybirdMutationObserver', fn [owner, mut binding] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		if binding.closed { return C.JSValueMakeUndefined(runtime.context) }
		mut storage := binding.document.native_storage()
		mut scope := platform.RetainedArenaScope{}
		if storage != unsafe { nil } { scope = storage.enter_nested() }
		persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
		defer {
			platform.leave_persistent(persistent)
			scope.finish()
		}
		return runtime.mutation_observer_operation(mut binding, args) or {
			if err is JavaScriptValueException { return err }
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	mutation_observer_bindings_[owner] = binding
	runtime.add_close_handler(fn [owner, mut binding] () {
		binding.closed = true
		binding.queue.retire()
		for _, mut observer in binding.observers {
			observer.disconnect()
			if record := observer.callback_ {
				if callback := record.mutation_callback {
					platform.release_closure(voidptr(callback))
				}
			}
			observer.callback_ = none
		}
		binding.observers = {}
		mutation_observer_bindings_.delete(owner)
	})
}

fn (mut runtime Runtime) mutation_observer_operation(mut binding MutationObserverBinding, args []voidptr) !voidptr {
	if args.len < 2 {
		return runtime.event_binding_type_error('Missing MutationObserver operation')
	}
	method := runtime.binding_dom_string(args[0])!
	receiver := args[1]
	undefined := C.JSValueMakeUndefined(runtime.context)
	if method == 'records' {
		binding.make_records = runtime.retain_javascript_value(receiver)!
		return undefined
	}
	if method == 'construct' {
		if args.len != 3 || !C.JSValueIsObject(runtime.context, args[2]) || !C.JSObjectIsFunction(runtime.context, args[2]) {
			return runtime.event_binding_type_error('MutationObserver requires a callback function')
		}
		callback := runtime.retain_javascript_value(args[2])!
		runtime.retain_javascript_value(receiver)!
		owner := voidptr(&runtime)
		callback_settings := runtime.callback_settings()
		mut observer := dom.MutationObserver.construct_impl(&dom.CallbackType{
			mutation_callback: fn [owner, mut binding, callback, receiver, callback_settings] (records []&dom.MutationRecord, _ &dom.MutationObserver) {
				if binding.closed { return }
				mut runtime := unsafe { &Runtime(owner) }
				if settings := runtime.scripting_settings_ {
					if html.can_run_script_for_settings(settings) == .do_not_run { return }
				}
				runtime.prepare_html_callback(callback_settings)
				defer {
					runtime.clean_up_html_callback(callback_settings)
					runtime.mark_document_state_dirty()
				}
				source := binding.encode(records) or {
					runtime.report_event_callback_exception(err)
					return
				}
				values := runtime.call_javascript_function(binding.make_records, C.JSValueMakeUndefined(runtime.context), [runtime.binding_string(source)]) or {
					runtime.report_event_callback_exception(err)
					return
				}
				runtime.call_javascript_function(callback, receiver, [values, receiver]) or { runtime.report_event_callback_exception(err) }
			}
		})!
		observer.delivery_queue_ = binding.queue
		binding.observers[receiver] = observer
		return undefined
	}
	mut observer := binding.observers[receiver] or { return runtime.event_binding_type_error('Illegal MutationObserver receiver') }
	if method == 'brand' { return undefined }
	if method == 'disconnect' {
		observer.disconnect()
		return undefined
	}
	if method == 'takeRecords' {
		return runtime.binding_string(binding.encode(observer.take_records())!)
	}
	if method == 'observe' {
		if args.len != 4 {
			return runtime.event_binding_type_error('observe requires a target and options')
		}
		node := binding.resolve(runtime.binding_dom_string(args[2])!)!
		values := json2.decode[map[string]json2.Any](runtime.binding_dom_string(args[3])!)!
		mut options := dom.MutationObserverOptions{}
		if value := values['attributes'] {
			if value is bool { options.attributes = value }
		}
		if value := values['attributeOldValue'] {
			if value is bool { options.attribute_old_value = value }
		}
		if value := values['characterData'] {
			if value is bool { options.character_data = value }
		}
		if value := values['characterDataOldValue'] {
			if value is bool { options.character_data_old_value = value }
		}
		if value := values['childList'] {
			if value is bool { options.child_list = value }
		}
		if value := values['subtree'] {
			if value is bool { options.subtree = value }
		}
		if value := values['attributeFilter'] {
			if value is []json2.Any {
				mut filter := []string{}
				for name in value { if name is string { filter << name.clone() } }
				options.attribute_filter = filter
			}
		}
		observer.observe(node, mut options)!
		return undefined
	}
	return error('Unknown MutationObserver operation')
}
