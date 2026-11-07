module main

import browserjs
import css
import dom

fn test_compact_computed_style_reads_native_cascade_and_stays_live_after_mutations() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><style>
		.shell .target { height:24px; margin-left:7px; color:rgb(1,2,3); --label: hello; }
		.shell.changed .target { height:42px; color:rgb(4,5,6); }
		.target::before { content:"badge"; color:rgb(7,8,9); }
	</style><section id="parent" class="shell"><div id="target" class="target">Content</div></section>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const styledElement=document.getElementById("target");
const nativeStyle=getComputedStyle(styledElement);
if(!(nativeStyle instanceof CSSStyleProperties)||!(nativeStyle instanceof CSSStyleDeclaration))throw new Error("computed declaration brand");
if(nativeStyle.height!=="24px"||nativeStyle.marginLeft!=="7px")throw new Error("author rule values were not resolved");
if(nativeStyle.color!=="rgb(1, 2, 3)"||nativeStyle.getPropertyValue("--label")!=="hello")throw new Error("native cascade values were lost");
if(nativeStyle.getPropertyValue("margin-left")!=="7px"||nativeStyle.getPropertyValue("marginLeft")!=="")throw new Error("CSS property name conversion");
if(nativeStyle.unknownProperty!==undefined||nativeStyle.getPropertyValue("unknown-property")!=="")throw new Error("unknown property result");
if(nativeStyle.cssText!==""||nativeStyle.parentRule!==null||nativeStyle.getPropertyPriority("color")!=="")throw new Error("computed declaration metadata");
if(nativeStyle.length===0||nativeStyle.item(0)!==nativeStyle[0]||nativeStyle.item(99999)!=="")throw new Error("computed declaration enumeration");
if(getComputedStyle(styledElement,"::before").color!=="rgb(7, 8, 9)")throw new Error("pseudo-element cascade");
document.getElementById("parent").className="shell changed";
if(nativeStyle.height!=="42px"||nativeStyle.color!=="rgb(4, 5, 6)")throw new Error("saved declaration missed class mutation");
styledElement.style.height="31px";
if(nativeStyle.height!=="31px")throw new Error("computed read missed pending style mutation");
console.log("native computed style passed");
'], runtime, mut messages)
	assert messages == ['native computed style passed']
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	target.set_attribute_value('style', 'height:59px')
	assert runtime.evaluate_host('nativeStyle.height')! == '59px'
	css.set_document_user_style_sheet(document, '#target { height:65px!important; }')
	assert runtime.evaluate_host('nativeStyle.height')! == '65px'
}

fn test_compact_computed_style_validates_receivers_and_preserves_native_pseudo_results() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><style>#target {height:24px}</style><div id="target"></div>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const element=document.getElementById("target"),style=getComputedStyle(element);
function requiresTypeError(callback){try{callback()}catch(error){if(error instanceof TypeError)return;throw error}throw new Error("missing TypeError");}
for(const value of [undefined,null,{},document])requiresTypeError(()=>getComputedStyle(value));
requiresTypeError(()=>getComputedStyle.call({},element));
requiresTypeError(()=>getComputedStyle(element,Symbol("pseudo")));
requiresTypeError(()=>style.getPropertyValue.call({},"height"));
requiresTypeError(()=>style.getPropertyValue());
requiresTypeError(()=>style.getPropertyValue(Symbol("property")));
requiresTypeError(()=>style.item());
for(const callback of [()=>{style.height="10px"},()=>style.setProperty("height","10px"),()=>style.removeProperty("height"),()=>{style.cssText="height:10px"}]){
 try{callback();throw new Error("computed declaration accepted mutation")}catch(error){if(error.name!=="NoModificationAllowedError")throw error;}
}
for(const pseudo of ["::unknown-pseudo","::part(label)","::slotted(*)"]){
 const empty=getComputedStyle(element,pseudo);
 if(empty.height!==""||empty.getPropertyValue("height")!==""||empty.length!==0)throw new Error("invalid pseudo did not retain native empty declaration");
}
if(getComputedStyle(element,null).height!=="24px"||getComputedStyle(element,"").height!=="24px")throw new Error("empty pseudo changed element style");
console.log("computed style validation passed");
'], runtime, mut messages)
	assert messages == ['computed style validation passed']
}

fn test_compact_computed_style_reports_supported_properties_with_in() {
	$if !darwin {
		return
	}
	mut document := parse_browser_navigation_document('<!doctype html><div id="target"></div>',
		dom.URL{ value: 'https://example.test/' }, none)
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [r'
const declaration=getComputedStyle(document.getElementById("target"));
for(const name of ["color","backgroundImage","background-image","cssFloat","gridTemplateColumns"])if(!(name in declaration))throw new Error(name+" is not reported as supported");
for(const name of ["notAProperty","--custom","9999"])if(name in declaration)throw new Error(name+" is reported as supported");
if(!("0" in declaration)||!("getPropertyValue" in declaration))throw new Error("indexed and prototype members");
console.log("computed in passed");
'], runtime, mut messages)
	assert messages == ['computed in passed']
}
