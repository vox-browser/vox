module browserjs

import dom
import html

@[heap]
struct PromiseSettlementEnvironmentCalls {
mut:
	order []string
}

fn test_native_promise_settlement_keeps_the_owning_realm_through_jsc_reactions() {
	$if !darwin && !linux { return }
	address := dom.URL{value: 'https://promise-settlement.example.test/'}
	mut document := dom.Document.create(address)
	document.origin_ = address.origin()
	_ = html.WindowModel.create_top_level(document, none, 'promise-settlement')!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut readable := ReadableStreamHost.create(document)!
	readable.install(mut runtime)!
	mut blobs := BlobHost.create(document)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut queries := URLSearchParamsHost.create(document)!
	queries.install(mut runtime)!
	mut urls := URLHost.create(document)!
	urls.install(mut runtime)!
	mut seen := &PromiseSettlementEnvironmentCalls{}
	owner_handle := voidptr(runtime)
	runtime.define_value_host_function('__settlementOwner', fn [settings, owner_handle, mut seen] (_ voidptr, _ []voidptr) !voidptr {
		owner := unsafe { &Runtime(owner_handle) }
		assert voidptr(html.current_principal_settings_object()) == voidptr(settings)
		assert owner.libjs_vm().has_running_execution_context()
		assert settings.realm().script_execution_depth > 0
		seen.order << 'reaction'
		mut event_loop := unsafe { &html.EventLoop(settings.responsible_event_loop()) }
		event_loop.enqueue_microtask(html.Task.create(.microtask, none, fn [settings, owner_handle, mut seen] () {
			owner := unsafe { &Runtime(owner_handle) }
			assert !owner.libjs_vm().has_running_execution_context()
			assert settings.realm().script_execution_depth == 0
			seen.order << 'checkpoint'
		}))
		return C.vox_jsc_JSValueMakeUndefined(owner.context)
	})!
	for rejected in [false, true] {
		capability := runtime.create_javascript_promise()!
		runtime.define_value_host_function('__settlementPromise', fn [capability] (_ voidptr, _ []voidptr) !voidptr { return capability.promise })!
		runtime.evaluate_host(r'{globalThis.settlementResult="pending";const reaction=value=>{const address=URL.createObjectURL(new Blob(["settled"]));__settlementOwner();URL.revokeObjectURL(address);settlementResult=address.startsWith("blob:https://promise-settlement.example.test/")&&value===42};__settlementPromise().then(reaction,reaction);}')!
		assert !runtime.libjs_vm().has_running_execution_context()
		value := C.vox_jsc_JSValueMakeNumber(runtime.context, 42)
		if rejected { runtime.reject_javascript_promise(capability, value)! }
		else { runtime.resolve_javascript_promise(capability, value)! }
		assert !runtime.libjs_vm().has_running_execution_context()
		assert settings.realm().script_execution_depth == 0
		assert runtime.evaluate_host('settlementResult')! == 'true'
		runtime.release_javascript_promise(capability)
	}
	assert seen.order == ['reaction', 'checkpoint', 'reaction', 'checkpoint']
}
