module main

import browserjs
import contentsecuritypolicy as csp
import dom
import html

fn test_native_security_policy_violation_event_fields_brands_and_identity() {
	url := dom.URL{value:'https://csp-event.test/'}
	mut document := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_event_target_binding()!
	event := csp.SecurityPolicyViolationEvent.create('securitypolicyviolation',csp.SecurityPolicyViolationEventInit{document_uri:url.value,blocked_uri:'eval',effective_directive:'script-src',source_file:'https://csp-event.test/test.js',line_number:17,column_number:4,disposition:.report})
	wrapper := runtime.javascript_event(unsafe { &dom.Event(event) })!
	runtime.define_value_host_function('__violation',fn [wrapper] (_ voidptr, _ []voidptr) !voidptr { return wrapper })!
	assert runtime.evaluate_host(r'(()=>{const e=__violation();if(!(e instanceof SecurityPolicyViolationEvent)||!(e instanceof Event)||e.effectiveDirective!=="script-src"||e.blockedURI!=="eval"||e.disposition!=="report"||e.lineNumber!==17||e.columnNumber!==4)throw new Error("fields");const constructed=new SecurityPolicyViolationEvent("x",{sample:"source",statusCode:204});if(constructed.sample!=="source"||constructed.statusCode!==204||constructed.disposition!=="enforce")throw new Error("constructor");try{Object.getOwnPropertyDescriptor(SecurityPolicyViolationEvent.prototype,"sample").get.call(new Event("x"));return false}catch(error){return error instanceof TypeError}})()')! == 'true'
}

