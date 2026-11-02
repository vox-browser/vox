// Actual DataTransfer receiver identity shared by DragEvent and its public binding.
module browserjs

import html


fn (mut runtime Runtime) install_data_transfer_identity() ! {
	mut binding := runtime.event_binding()!
	if binding.data_transfer_factory != unsafe { nil } { return }
	binding.data_transfer_factory = runtime.retain_javascript_value(runtime.evaluate_host_value(r'(function(){
 const create=Object.create,define=Object.defineProperty,prototype=create(Object.prototype);
 define(prototype,Symbol.toStringTag,{value:"DataTransfer",configurable:true});
 function wrap(){return create(prototype)};
 define(wrap,"prototype",{value:prototype,writable:false});return wrap;
})()')!)!
	binding.data_transfer_prototype = runtime.retain_javascript_value(runtime.binding_property(binding.data_transfer_factory,
		'prototype')!)!
}

fn (mut runtime Runtime) bind_data_transfer(wrapper voidptr, transfer &html.DataTransfer) ! {
	mut binding := runtime.event_binding()!
	runtime.retain_javascript_value(wrapper)!
	binding.data_transfers[wrapper] = transfer
	binding.data_transfer_wrappers[voidptr(transfer)] = wrapper
}

pub fn (mut runtime Runtime) javascript_data_transfer(transfer &html.DataTransfer) !voidptr {
	runtime.require_javascript_value_context()!
	if transfer == unsafe { nil } {
		return runtime.event_binding_type_error('Missing native DataTransfer record')
	}
	mut binding := runtime.event_binding()!
	if wrapper := binding.data_transfer_wrappers[voidptr(transfer)] { return wrapper }
	runtime.install_data_transfer_identity()!
	wrapper := runtime.call_javascript_function(binding.data_transfer_factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [])!
	runtime.bind_data_transfer(wrapper, transfer)!
	return wrapper
}

pub fn (runtime &Runtime) native_data_transfer(wrapper voidptr) !&html.DataTransfer {
	binding := runtime.event_binding()!
	return binding.data_transfers[wrapper] or {
		return runtime.event_binding_type_error('Not an object of type DataTransfer')
	}
}
