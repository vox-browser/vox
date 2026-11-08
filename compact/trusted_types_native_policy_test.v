module main

import browserjs
import dom
import html
import platform
import webidl

fn native_trusted_policy_document(markup string) !&dom.Document {
	url := dom.URL{value: 'https://trusted-types.test/'}
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, markup)
	allocations.finish()
	return document
}

fn test_javascript_default_policy_is_shared_with_native_attribute_and_html_sinks() {
	mut document := native_trusted_policy_document('<!doctype html><meta http-equiv="Content-Security-Policy" content="require-trusted-types-for &apos;script&apos;; trusted-types default safe"><body><div id="target"></div></body>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize(); document.release_native_storage() }
	mut messages := []string{}
	run_document_javascript(document, 'https://trusted-types.test/', [r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
check(globalThis.__ladybirdCreateTrustedTypePolicy,undefined);
let count=0;
const policy=trustedTypes.createPolicy("default",{
 createScript(input,type,sink){"use strict";check(this,undefined);check(type,"TrustedScript");check(sink,"Element onclick");count++;target.setAttributeNS(null,"data-callback","ran");return "safe:"+input;},
 createHTML(input,type,sink){check(type,"TrustedHTML");check(sink,"Element innerHTML");return "<b id=filtered>filtered</b>";}
});
check(trustedTypes.defaultPolicy,policy);
target.setAttributeNS(null,"onclick","unsafe");
check(target.getAttributeNS(null,"onclick"),"safe:unsafe");check(target.getAttribute("data-callback"),"ran");check(count,1);
target.innerHTML="<i>unfiltered</i>";
check(target.firstChild.id,"filtered");
let denied=false;try{trustedTypes.createPolicy("forbidden",{});}catch(error){denied=error instanceof TypeError;}
check(denied,true);trustedTypes.createPolicy("safe",{});
console.log("shared native policy passed");
'], runtime, mut messages)
	assert messages == ['shared native policy passed'], messages.join('\n')
	assert document.get_element_by_id('target')?.get_attribute_value('onclick') == 'safe:unsafe'
	assert document.get_element_by_id('filtered') != none
}

fn test_default_policy_return_conversion_and_original_exception_values() {
	mut document := native_trusted_policy_document('<!doctype html><meta http-equiv="Content-Security-Policy" content="require-trusted-types-for &apos;script&apos;"><body><div id="target"></div></body>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize(); document.release_native_storage() }
	mut messages := []string{}
	run_document_javascript(document, 'https://trusted-types.test/', [r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const reason={original:true};let resultMode="string";
trustedTypes.createPolicy("default",{createScript(input){
 if(resultMode==="throw"){target.setAttributeNS(null,"data-threw","yes");throw reason;}
 if(resultMode==="null")return null;
 if(resultMode==="undefined")return undefined;
 if(resultMode==="symbol")return Symbol("invalid result");
 return {[Symbol.toPrimitive](hint){check(hint,"string");return "converted";}};
}});
target.setAttributeNS(null,"onclick","unsafe");check(target.getAttributeNS(null,"onclick"),"converted");
for(const mode of ["null","undefined","symbol"]){
 resultMode=mode;let rejected=false;try{target.setAttributeNS(null,"onclick","blocked");}catch(error){rejected=error instanceof TypeError;}
 check(rejected,true);check(target.getAttributeNS(null,"onclick"),"converted");
}
resultMode="throw";let caught;try{target.setAttributeNS(null,"onclick","throwing");}catch(error){caught=error;}
check(caught,reason);check(target.getAttributeNS(null,"data-threw"),"yes");check(target.getAttributeNS(null,"onclick"),"converted");
console.log("native callback results passed");
'], runtime, mut messages)
	assert messages == ['native callback results passed'], messages.join('\n')
}

fn test_default_policy_callback_options_are_snapshotted_and_conversion_errors_stay_original() {
	mut document := native_trusted_policy_document('<!doctype html><meta http-equiv="Content-Security-Policy" content="require-trusted-types-for &apos;script&apos;"><body><div id="target"></div></body>')!
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize(); document.release_native_storage() }
	mut messages := []string{}
	run_document_javascript(document, 'https://trusted-types.test/', [r'
const reason={conversion:true};
const options={createScript:()=>({toString(){throw reason;}})};
trustedTypes.createPolicy("default",options);options.createScript=()=>"replacement";
let caught;try{target.setAttributeNS(null,"onclick","input");}catch(error){caught=error;}
if(caught!==reason||target.hasAttributeNS(null,"onclick"))throw new Error("policy conversion error or options snapshot changed");
console.log("native policy options passed");
'], runtime, mut messages)
	assert messages == ['native policy options passed'], messages.join('\n')
}

fn test_closed_native_policy_callback_outlives_document_payload_without_entering_javascript() {
	mut document := native_trusted_policy_document('<!doctype html><body><div id="target"></div></body>')!
	mut runtime := browserjs.Runtime.create()
	mut allocations := document.enter_native_storage()
	mut messages := []string{}
	run_document_javascript(document, 'https://trusted-types.test/', [
		'trustedTypes.createPolicy("default", {createScript: input => input});',
	], runtime, mut messages)
	allocations.finish()
	assert messages == []string{}, messages.join('\n')
	factory := html.trusted_types_factory_for_document(document)
	policy := factory.default_policy()?
	runtime.close()
	document.finalize()
	document.release_native_storage()
	churn := platform.begin_thread_scratch('retired trusted policy owner')
	_ = []u8{len: 2 * 1024 * 1024, init: u8(0xa5)}
	churn.finish()
	if _ := policy.create_script('unsafe', []webidl.Value{}) {
		assert false
	} else {
		assert err.msg().contains('Trusted Types realm is closed')
	}
}
