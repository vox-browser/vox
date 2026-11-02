module browserjs

import html

fn identity_transfer_runtime() &Runtime {
	mut runtime := Runtime.create()
	runtime.install_event_target_binding() or { panic(err) }
	return runtime
}

fn identity_transfer_export(mut runtime Runtime, name string, value voidptr) ! {
	runtime.define_value_host_function(name, fn [value] (_ voidptr, _ []voidptr) !voidptr {
		return value
	})!
}

fn test_native_data_transfer_identity_cache_tag_and_live_implementation_record() {
	$if !darwin { return }
	mut runtime := identity_transfer_runtime()
	defer { runtime.close() }
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text/plain', 'native before wrapping')
	transfer.set_drop_effect('copy')
	wrapper := runtime.javascript_data_transfer(transfer)!
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	mut native := runtime.native_data_transfer(wrapper)!
	assert native == transfer && native.get_data('text/plain') == 'native before wrapping'
	assert native.drop_effect() == 'copy' && native.length() == 1
	other := html.DataTransfer.construct()
	other_wrapper := runtime.javascript_data_transfer(other)!
	assert other_wrapper != wrapper
	assert runtime.native_data_transfer(other_wrapper)! == other
	identity_transfer_export(mut runtime, '__identityTransfer', wrapper)!
	identity_transfer_export(mut runtime, '__identityOtherTransfer', other_wrapper)!
	assert runtime.evaluate_host(r'(()=>{
 const first=__identityTransfer(),second=__identityOtherTransfer(),prototype=Object.getPrototypeOf(first),tag=Object.getOwnPropertyDescriptor(prototype,Symbol.toStringTag);
 return first===__identityTransfer()&&second===__identityOtherTransfer()&&first!==second&&Object.getPrototypeOf(second)===prototype&&Object.getPrototypeOf(prototype)===Object.prototype&&Object.prototype.toString.call(first)==="[object DataTransfer]"&&Object.prototype.toString.call(second)==="[object DataTransfer]"&&tag.value==="DataTransfer"&&!tag.writable&&!tag.enumerable&&tag.configurable&&Object.getOwnPropertyNames(first).length===0;
})()')! == 'true'
	// This adapter exposes implementation identity, not the public DataTransfer
	// methods. Both native references therefore observe mutations of one store.
	native.set_data('text/plain', 'changed through native lookup')
	assert transfer.get_data('text/plain') == 'changed through native lookup'
	transfer.set_data('text/html', '<b>changed through original owner</b>')
	assert native.get_data('text/html') == '<b>changed through original owner</b>'
	assert native.length() == 2
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	assert runtime.native_data_transfer(runtime.evaluate_host_value('__identityTransfer()')!)! == transfer
	transfer.disassociate_with_drag_data_store()
	assert native.mode() == none && native.get_data('text/plain') == ''
	assert runtime.native_data_transfer(wrapper)! == transfer
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	assert runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert voidptr(runtime.libjs_vm().running_execution_context()) == voidptr(runtime.realm_context)
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_data_transfer_identity_brands_reject_forged_proxy_and_foreign_wrappers_without_traps() {
	$if !darwin { return }
	mut runtime := identity_transfer_runtime()
	defer { runtime.close() }
	transfer := html.DataTransfer.construct()
	wrapper := runtime.javascript_data_transfer(transfer)!
	identity_transfer_export(mut runtime, '__identityBrandedTransfer', wrapper)!
	runtime.define_value_host_function('__identityRequireTransfer', fn [mut runtime] (_ voidptr, args []voidptr) !voidptr {
		_ = runtime.native_data_transfer(args[0])!
		return C.vox_jsc_JSValueMakeBoolean(runtime.context, true)
	})!
	assert runtime.evaluate_host(r'(()=>{
 const transfer=__identityBrandedTransfer(),marker={};let traps=0,authorGets=0;
 const proxy=new Proxy(transfer,{get(){traps++;throw marker},getPrototypeOf(){traps++;throw marker},has(){traps++;throw marker},ownKeys(){traps++;throw marker}}),forged=Object.create(Object.getPrototypeOf(transfer));
 for(const name of ["constructor","dropEffect","effectAllowed","items","types","files","valueOf","toString"])Object.defineProperty(transfer,name,{get(){authorGets++;throw marker},configurable:true});Object.defineProperty(transfer,Symbol.toPrimitive,{get(){authorGets++;throw marker},configurable:true});
 for(const value of [forged,proxy,{},[],new Event("ordinary"),Object.create(null),null,undefined,1,true,"transfer",1n,Symbol("transfer")]){let rejected=false;try{__identityRequireTransfer(value)}catch(error){rejected=error instanceof TypeError&&error.message==="Not an object of type DataTransfer"}if(!rejected)return false}
 globalThis.DataTransfer=function ReplacementDataTransfer(){throw marker};Object.setPrototypeOf(transfer,null);transfer.__implementationId="forged author ID";
 return __identityRequireTransfer(transfer)&&__identityBrandedTransfer()===transfer&&traps===0&&authorGets===0;
})()')! == 'true'
	assert runtime.native_data_transfer(wrapper)! == transfer
	assert runtime.javascript_data_transfer(transfer)! == wrapper
	mut foreign := identity_transfer_runtime()
	defer { foreign.close() }
	foreign_wrapper := foreign.javascript_data_transfer(transfer)!
	assert foreign.native_data_transfer(foreign_wrapper)! == transfer
	// JSC values never enter a foreign engine call. These native map lookups
	// reject the other runtime's opaque wrapper without inspecting its object.
	if _ := runtime.native_data_transfer(foreign_wrapper) {
		assert false, 'accepted the foreign DataTransfer wrapper'
	}
	if _ := foreign.native_data_transfer(wrapper) {
		assert false, 'foreign runtime accepted this DataTransfer wrapper'
	}
	assert runtime.libjs_vm().has_running_execution_context()
	assert runtime.libjs_vm().execution_context_stack().len == 1
	assert voidptr(runtime.libjs_vm().running_execution_context()) == voidptr(runtime.realm_context)
	assert runtime.libjs_vm().interpreter_stack().depth() == 0
	assert foreign.libjs_vm().has_running_execution_context()
	assert foreign.libjs_vm().execution_context_stack().len == 1
	assert voidptr(foreign.libjs_vm().running_execution_context()) == voidptr(foreign.realm_context)
	assert foreign.libjs_vm().interpreter_stack().depth() == 0
}

fn test_native_data_transfer_identity_nil_input_does_not_create_factory_and_close_clears_registry() {
	$if !darwin { return }
	mut runtime := identity_transfer_runtime()
	binding := runtime.event_binding()!
	assert binding.data_transfer_factory == unsafe { nil }
	assert binding.data_transfers.len == 0 && binding.data_transfer_wrappers.len == 0
	runtime.define_value_host_function('__identityMissingTransfer', fn [mut runtime] (_ voidptr, _ []voidptr) !voidptr {
		return runtime.javascript_data_transfer(unsafe { &html.DataTransfer(nil) })
	})!
	assert runtime.evaluate_host('(()=>{try{__identityMissingTransfer();return false}catch(error){return error instanceof TypeError&&error.message==="Missing native DataTransfer record"}})()')! == 'true'
	assert binding.data_transfer_factory == unsafe { nil }
	assert binding.data_transfers.len == 0 && binding.data_transfer_wrappers.len == 0
	mut transfer := html.DataTransfer.construct()
	transfer.set_data('text/plain', 'record survives runtime close')
	wrapper := runtime.javascript_data_transfer(transfer)!
	assert binding.data_transfer_factory != unsafe { nil }
	assert binding.data_transfers.len == 1 && binding.data_transfer_wrappers.len == 1
	assert runtime.native_data_transfer(wrapper)! == transfer
	runtime.close()
	assert binding.closed && binding.data_transfers.len == 0
		&& binding.data_transfer_wrappers.len == 0
	if _ := runtime.native_data_transfer(wrapper) {
		assert false, 'closed runtime retained a DataTransfer brand'
	}
	if _ := runtime.javascript_data_transfer(transfer) {
		assert false, 'closed runtime created a DataTransfer wrapper'
	}
	assert transfer.get_data('text/plain') == 'record survives runtime close'
	transfer.set_data('text/plain', 'still independently usable')
	assert transfer.get_data('text/plain') == 'still independently usable'
	runtime.close()
	assert binding.closed && binding.data_transfers.len == 0
		&& binding.data_transfer_wrappers.len == 0
}
