module main

import browserjs
import dom
import html

fn test_engine_string_compilation_policy_preserves_direct_eval_scope_and_blocks_later_eval() {
	url := dom.URL{value:'https://eval-policy.test/'}
	mut document := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	assert runtime.evaluate_host('(function(){let local=1;eval("local+=2");return local})()')! == '3'
	settings.set_policy_container(&html.PolicyContainer{csp_list:[html.parse_response_csp_policy("script-src 'self'",.enforce,settings.origin())]})
	assert runtime.evaluate_host('(()=>{try{eval("globalThis.executed=true");return false}catch(e){return e instanceof EvalError&&globalThis.executed!==true}})()')! == 'true'
	assert runtime.evaluate_host('(()=>{try{new Function("return 1");return false}catch(e){return e instanceof EvalError}})()')! == 'true'
	settings.set_policy_container(&html.PolicyContainer{csp_list:[html.parse_response_csp_policy("script-src 'self' 'unsafe-eval'",.enforce,settings.origin())]})
	assert runtime.evaluate_host('eval("2+2")')! == '4'
}
