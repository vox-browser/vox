module main

import browserjs
import dom
import html

fn run_trusted_attribute_check(source string) {
	url := dom.URL{value: 'https://trusted-attributes.test/'}
	mut document := html.create_navigation_document(url, url.origin(), none) or { panic(err) }
	document.enable_native_storage()
	mut allocation := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><meta http-equiv="Content-Security-Policy" content="require-trusted-types-for &apos;script&apos;"><body><div id="target"></div><div id="other"></div></body>')
	allocation.finish()
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize(); document.release_native_storage() }
	mut messages := []string{}
	run_document_javascript(document, url.serialize(), [source], runtime, mut messages)
	assert messages == ['trusted attribute passed'], messages.join('\n')
}

fn test_trusted_attribute_setters_preserve_brands_and_enforce_before_returning() {
	run_trusted_attribute_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const policy=trustedTypes.createPolicy("safe",{createScript:value=>value,createHTML:value=>value,createScriptURL:value=>value});
const script=policy.createScript("trusted script"),html=policy.createHTML("<b>trusted</b>"),url=policy.createScriptURL("trusted.js");
TrustedScript.prototype.toString=function(){throw new Error("coerced a trusted script");};
TrustedHTML.prototype.toString=function(){throw new Error("coerced trusted HTML");};
TrustedScriptURL.prototype.toString=function(){throw new Error("coerced a trusted URL");};
for(const set of [(element,name,value)=>element.setAttribute(name,value),(element,name,value)=>element.setAttributeNS(null,name,value)]){
 set(target,"onclick",script);check(target.getAttribute("onclick"),"trusted script");
 for(const invalid of ["unsafe",html,url]){let rejected=false;try{set(target,"onclick",invalid);}catch(error){rejected=error instanceof TypeError;}check(rejected,true);check(target.getAttribute("onclick"),"trusted script");}
 const iframe=document.createElement("iframe");set(iframe,"srcdoc",html);check(iframe.getAttribute("srcdoc"),"<b>trusted</b>");
 const element=document.createElement("script");set(element,"src",url);check(element.getAttribute("src"),"trusted.js");
 set(target,"data-value",html);check(target.getAttribute("data-value"),"<b>trusted</b>");
}
check(globalThis.__ladybirdSetTrustedAttribute,undefined);
console.log("trusted attribute passed");
')
}

fn test_default_attribute_policy_runs_once_with_the_actual_sink_and_refreshes_mutations() {
	run_trusted_attribute_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const calls=[];
const policy=trustedTypes.createPolicy("default",{createScript(value,type,sink){
 "use strict";check(this,undefined);calls.push([value,type,sink].join("|"));
 target.setAttribute("data-callback","ran");return "safe:"+value;
}});
for(const set of [(name,value)=>target.setAttribute(name,value),(name,value)=>target.setAttributeNS(null,name,value)]){
 const before=calls.length;set("onclick","input");check(calls.length,before+1);
 check(calls[before],"input|TrustedScript|Element onclick");check(target.getAttribute("onclick"),"safe:input");check(target.getAttribute("data-callback"),"ran");
}
const trusted=policy.createScript("explicit","TrustedScript","explicit creation"),before=calls.length;
target.setAttribute("onclick",trusted);check(calls.length,before);check(target.getAttribute("onclick"),"safe:explicit");
const svg=document.createElementNS("http://www.w3.org/2000/svg","g");
svg.setAttributeNS(null,"onclick","svg input");check(svg.getAttribute("onclick"),"safe:svg input");
svg.setAttributeNS("urn:ordinary","a:onclick","plain");check(svg.getAttributeNS("urn:ordinary","onclick"),"plain");
console.log("trusted attribute passed");
')
}

fn test_attribute_setters_validate_receivers_names_and_preserve_conversion_exceptions() {
	run_trusted_attribute_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const set=Element.prototype.setAttribute,setNS=Element.prototype.setAttributeNS;
check(set.length,2);check(setNS.length,3);check(set.name,"setAttribute");check(setNS.name,"setAttributeNS");
let conversions=0;const value={toString(){conversions++;return "value";}};
for(const receiver of [null,undefined,{},Object.create(target)]){
 for(const operation of [()=>set.call(receiver,"data-value",value),()=>setNS.call(receiver,null,"data-value",value)]){
  let rejected=false;try{operation();}catch(error){rejected=error instanceof TypeError;}check(rejected,true);
 }
}
check(conversions,0);set.call(other,"data-value",value);check(other.getAttribute("data-value"),"value");check(target.getAttribute("data-value"),null);
let callbacks=0;const reason=new Error("NamespaceError: original callback error");
trustedTypes.createPolicy("default",{createScript(){callbacks++;throw reason;}});
for(const [operation,name] of [[()=>set.call(target,"bad name","input"),"InvalidCharacterError"],[()=>setNS.call(target,null,"prefix:onclick","input"),"NamespaceError"]]){
 let caught;try{operation();}catch(error){caught=error;}check(caught instanceof DOMException,true);check(caught.name,name);
}
check(callbacks,0);
let caught;try{target.setAttribute("onclick","input");}catch(error){caught=error;}check(caught,reason);
const conversion={original:true};try{target.setAttribute("title",{[Symbol.toPrimitive](hint){check(hint,"string");throw conversion;}});}catch(error){caught=error;}check(caught,conversion);
let symbolRejected=false;try{target.setAttribute("title",Symbol());}catch(error){symbolRejected=error instanceof TypeError;}check(symbolRejected,true);
console.log("trusted attribute passed");
')
}

fn test_attribute_setters_retain_native_state_custom_element_reactions_and_captured_apply() {
	run_trusted_attribute_check(r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const originalApply=Reflect.apply;
Reflect.apply=function(){throw new Error("mutable apply should not be consulted");};
try{const policy=trustedTypes.createPolicy("safe",{createScript:value=>value});target.setAttribute("onclick",policy.createScript("safe"));}finally{Reflect.apply=originalApply;}
const events=[];
class Observed extends HTMLElement{static get observedAttributes(){return ["data-value"];}attributeChangedCallback(name,old,value){events.push([name,old,value,this.getAttribute(name)].join("|"));}}
customElements.define("x-trusted-observed",Observed);const element=new Observed();
element.setAttribute("data-value","first");element.setAttributeNS(null,"data-value","second");
check(events.join(","),"data-value||first|first,data-value|first|second|second");
const canvas=document.createElement("canvas");canvas.setAttribute("width","12");canvas.setAttributeNS(null,"height","9");check(canvas.width,12);check(canvas.height,9);
target.setAttribute("ID","renamed");check(target.id,"renamed");check(document.getElementById("renamed"),target);
target.setAttribute("class","changed");check(target.className,"changed");
console.log("trusted attribute passed");
')
}
