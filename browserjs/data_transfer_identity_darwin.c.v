// Bounded actual DataTransfer receiver identity for nullable DragEvent fields.
// The public DataTransfer constructor and operations are separate translations.
module browserjs

import html

fn (mut runtime Runtime) install_data_transfer_identity() ! {
	mut binding := runtime.event_binding()!
	if binding.data_transfer_factory != unsafe { nil } { return }
	binding.data_transfer_factory = runtime.retain_javascript_value(runtime.evaluate_host_value(r'(function(){
 const create=Object.create,define=Object.defineProperty,prototype=create(Object.prototype);
 define(prototype,Symbol.toStringTag,{value:"DataTransfer",configurable:true});
 return function(){return create(prototype)};
})()')!)!
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
		C.JSValueMakeUndefined(runtime.context), [])!
	runtime.retain_javascript_value(wrapper)!
	binding.data_transfers[wrapper] = transfer
	binding.data_transfer_wrappers[voidptr(transfer)] = wrapper
	return wrapper
}

pub fn (runtime &Runtime) native_data_transfer(wrapper voidptr) !&html.DataTransfer {
	binding := runtime.event_binding()!
	return binding.data_transfers[wrapper] or {
		return runtime.event_binding_type_error('Not an object of type DataTransfer')
	}
}
