// Clipboard/ClipboardEvent.{idl,h,cpp}: synthetic and native events share the
// same native DataTransfer identity and EventTarget dispatch.
module browserjs

import clipboard
import dom
import highresolutiontime
import html

fn (mut runtime Runtime) install_clipboard_event_binding() ! {
	owner := voidptr(&runtime)
	mut binding := runtime.event_binding()!
	if binding.clipboard_event_prototype != unsafe { nil } { return }
	runtime.install_data_transfer_identity()!
	construct := runtime.make_native_value_host_function('ClipboardEvent', 1, fn [owner] (receiver voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.clipboard_event_binding_call('construct', receiver, args)
	})!
	get_data := runtime.make_native_value_host_function('get clipboardData', 0, fn [owner] (receiver voidptr, _ []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.clipboard_event_binding_call('get', receiver, [])
	})!
	factory := runtime.evaluate_host_value(clipboard_event_bootstrap())!
	defer { runtime.release_javascript_value(factory) }
	binding.clipboard_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context), [binding.event_constructor,
		C.JSContextGetGlobalObject(runtime.context), construct, get_data])!)!
}

fn (mut runtime Runtime) clipboard_event_binding_call(method string, receiver voidptr, args []voidptr) !voidptr {
	if method == 'construct' {
		if args.len < 2 { return runtime.event_binding_type_error('Missing internal ClipboardEvent constructor arguments') }
		type_ := runtime.binding_dom_string(args[0])!
		options := args[1]
		if !C.JSValueIsUndefined(runtime.context, options) && !C.JSValueIsNull(runtime.context, options)
			&& !C.JSValueIsObject(runtime.context, options) {
			return runtime.event_binding_type_error('ClipboardEvent options must be a dictionary')
		}
		// Inherited EventInit members precede ClipboardEventInit's own member.
		bubbles := runtime.event_binding_bool_property(options, 'bubbles', false)!
		cancelable := runtime.event_binding_bool_property(options, 'cancelable', false)!
		composed := runtime.event_binding_bool_property(options, 'composed', false)!
		value := runtime.ui_event_dictionary_member(options, 'clipboardData')!
		mut transfer := ?&html.DataTransfer(none)
		if !C.JSValueIsUndefined(runtime.context, value) && !C.JSValueIsNull(runtime.context, value) {
			transfer = runtime.native_data_transfer(value)!
		}
		mut event := clipboard.ClipboardEvent.construct_impl(type_, clipboard.ClipboardEventInit{
			EventInit: dom.EventInit{bubbles: bubbles, cancelable: cancelable, composed: composed}
			clipboard_data: transfer
		})!
		if settings := runtime.scripting_settings_ {
			event.set_time_stamp(highresolutiontime.current_high_resolution_time(highresolutiontime.TimeOriginContext{
				time_origin: settings.time_origin()
				cross_origin_isolated_capability: settings.cross_origin_isolated_capability() == .yes
			}))
		}
		runtime.bind_event(receiver, unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	event := runtime.native_event(receiver)!
	if event.interface_ != .clipboard_event { return runtime.event_binding_type_error('Illegal ClipboardEvent receiver') }
	copy_event := unsafe { &clipboard.ClipboardEvent(event) }
	if transfer := copy_event.clipboard_data() { return runtime.javascript_data_transfer(transfer)! }
	return C.vox_jsc_JSValueMakeNull(runtime.context)
}
