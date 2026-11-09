module browserjs

import contentsecuritypolicy as csp
import dom
import webidl

fn (mut runtime Runtime) install_security_policy_violation_event_binding() ! {
	mut binding := runtime.event_binding()!
	if binding.security_policy_violation_event_prototype != unsafe { nil } { return }
	owner := voidptr(&runtime)
	construct := runtime.make_native_value_host_function('SecurityPolicyViolationEvent',1,fn [owner] (receiver voidptr, arguments []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.security_policy_violation_event_call('construct',receiver,arguments)
	})!
	mut getters := []voidptr{}
	for name in ['documentURI','referrer','blockedURI','violatedDirective','effectiveDirective','originalPolicy','sourceFile','sample','disposition','statusCode','lineNumber','columnNumber'] {
		getters << runtime.make_native_value_host_function('get '+name,0,fn [owner,name] (receiver voidptr, _ []voidptr) !voidptr {
			mut runtime := unsafe { &Runtime(owner) }
			return runtime.security_policy_violation_event_call(name,receiver,[])
		})!
	}
	mut exception := unsafe { nil }
	array := C.vox_jsc_JSObjectMakeArray(runtime.context,uint(getters.len),getters.data,&exception)
	if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
	runtime.retain_javascript_value(array)!
	defer { runtime.release_javascript_value(array) }
	factory := runtime.evaluate_host_value(r'(function(parent,global,construct,getters){
 const apply=Reflect.apply,create=Object.create,define=Object.defineProperty,T=TypeError,prototype=create(parent.prototype);
 const SecurityPolicyViolationEvent=new Proxy(function SecurityPolicyViolationEvent(type,eventInitDict={}){throw new T("SecurityPolicyViolationEvent requires new")},{construct(target,args,newTarget){
  const requested=newTarget.prototype,receiver=create(requested!==null&&(typeof requested==="object"||typeof requested==="function")?requested:prototype);
  if(args.length<1)throw new T("Missing event type");apply(construct,receiver,[args[0],args.length>1?args[1]:void 0]);return receiver;
 }});
 Object.setPrototypeOf(SecurityPolicyViolationEvent,parent);define(SecurityPolicyViolationEvent,"prototype",{value:prototype,writable:false});
 define(prototype,"constructor",{value:SecurityPolicyViolationEvent,writable:true,configurable:true});
 const names=["documentURI","referrer","blockedURI","violatedDirective","effectiveDirective","originalPolicy","sourceFile","sample","disposition","statusCode","lineNumber","columnNumber"];
 names.forEach((name,index)=>define(prototype,name,{get:getters[index],enumerable:true,configurable:true}));
 define(prototype,Symbol.toStringTag,{value:"SecurityPolicyViolationEvent",configurable:true});define(global,"SecurityPolicyViolationEvent",{value:SecurityPolicyViolationEvent,writable:true,configurable:true});return prototype;
})')!
	defer { runtime.release_javascript_value(factory) }
	binding.security_policy_violation_event_prototype = runtime.retain_javascript_value(runtime.call_javascript_function(factory,
		C.vox_jsc_JSValueMakeUndefined(runtime.context),[binding.event_constructor,C.JSContextGetGlobalObject(runtime.context),construct,array])!)!
}

fn (runtime &Runtime) csp_event_string_member(options voidptr, name string) !string {
	value := runtime.ui_event_dictionary_member(options,name)!
	if C.JSValueIsUndefined(runtime.context,value) { return '' }
	return runtime.binding_dom_utf16(value)!.str()
}

fn (mut runtime Runtime) security_policy_violation_event_call(method string, receiver voidptr, arguments []voidptr) !voidptr {
	if method == 'construct' {
		type_ := runtime.binding_dom_utf16(arguments[0])!.str()
		options := arguments[1]
		bubbles := runtime.event_binding_bool_property(options,'bubbles',false)!
		cancelable := runtime.event_binding_bool_property(options,'cancelable',false)!
		composed := runtime.event_binding_bool_property(options,'composed',false)!
		mut strings := map[string]string{}
		mut numbers := map[string]i64{}
		for name in ['blockedURI','columnNumber','disposition','documentURI','effectiveDirective','lineNumber','originalPolicy','referrer','sample','sourceFile','statusCode','violatedDirective'] {
			if name in ['columnNumber','lineNumber','statusCode'] {
				value := runtime.ui_event_dictionary_member(options,name)!
				numbers[name] = if C.JSValueIsUndefined(runtime.context,value) { i64(0) } else { webidl.convert_to_int(runtime.webidl_value(value)!,if name == 'statusCode' { 16 } else { 32 },false,.no,.no)! }
			} else if name == 'disposition' {
				value := runtime.ui_event_dictionary_member(options,name)!
				strings[name] = if C.JSValueIsUndefined(runtime.context,value) { 'enforce' } else { runtime.binding_dom_utf16(value)!.str() }
			} else { strings[name] = runtime.csp_event_string_member(options,name)! }
		}
		if strings['disposition'] !in ['enforce','report'] { return runtime.event_binding_type_error('Invalid SecurityPolicyViolationEventDisposition') }
		mut event := csp.SecurityPolicyViolationEvent.create(type_,csp.SecurityPolicyViolationEventInit{
			EventInit:dom.EventInit{bubbles:bubbles,cancelable:cancelable,composed:composed}
			document_uri:strings['documentURI'],referrer:strings['referrer'],blocked_uri:strings['blockedURI'],violated_directive:strings['violatedDirective'],effective_directive:strings['effectiveDirective'],original_policy:strings['originalPolicy'],source_file:strings['sourceFile'],sample:strings['sample']
			disposition:if strings['disposition'] == 'report' { .report } else { .enforce }
			status_code:u16(numbers['statusCode']),line_number:u32(numbers['lineNumber']),column_number:u32(numbers['columnNumber'])
		})
		runtime.bind_event(receiver,unsafe { &dom.Event(event) })!
		return C.vox_jsc_JSValueMakeUndefined(runtime.context)
	}
	event := runtime.native_event(receiver)!
	if event.interface_ != .security_policy_violation_event { return runtime.event_binding_type_error('Illegal SecurityPolicyViolationEvent receiver') }
	violation := unsafe { &csp.SecurityPolicyViolationEvent(event) }
	match method {
		'statusCode' { return C.vox_jsc_JSValueMakeNumber(runtime.context,violation.status_code()) }
		'lineNumber' { return C.vox_jsc_JSValueMakeNumber(runtime.context,violation.line_number()) }
		'columnNumber' { return C.vox_jsc_JSValueMakeNumber(runtime.context,violation.column_number()) }
		else {}
	}
	return runtime.binding_string(match method {
		'documentURI' { violation.document_uri() } 'referrer' { violation.referrer() }
		'blockedURI' { violation.blocked_uri() } 'violatedDirective' { violation.violated_directive() }
		'effectiveDirective' { violation.effective_directive() } 'originalPolicy' { violation.original_policy() }
		'sourceFile' { violation.source_file() } 'sample' { violation.sample() }
		'disposition' { if violation.disposition() == .report { 'report' } else { 'enforce' } }
		else { '' }
	})
}
