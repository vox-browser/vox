module main

import browserjs
import html

fn test_aria_and_html_element_attributes_reflect_their_content_attributes() {
	$if !darwin { return }
	document := html.parse_document('<!doctype html><div id="box" role="button" aria-label="Go" dir="RTL" tabindex=" 7x" translate="no"><a id="link" href="#">l</a><span id="inner"></span></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		'console.log(box.role,box.ariaLabel,String(box.ariaHidden),box.dir,box.tabIndex,link.tabIndex,inner.tabIndex,inner.translate,link.draggable,inner.draggable,String(box.popover),box.contentEditable);box.ariaHidden="true";box.ariaLabel=undefined;box.popover="";box.inert=true;console.log(box.getAttribute("aria-hidden"),box.hasAttribute("aria-label"),box.popover,box.hasAttribute("inert"));try{box.contentEditable="maybe"}catch(e){console.log(e.name)}box.contentEditable="PLAINTEXT-ONLY";console.log(box.getAttribute("contenteditable"),box.contentEditable,inner.slot,box.enterKeyHint);const made=document.createElement("p");made.className="x y";console.log(Object.prototype.toString.call(made.classList),made.classList instanceof DOMTokenList,Object.prototype.toString.call(document.body.classList));',
	], runtime, mut messages)
	assert messages == ['button Go null rtl 7 0 -1 false true false null inherit',
		'true false auto true', 'SyntaxError', 'plaintext-only plaintext-only  ', '[object DOMTokenList] true [object DOMTokenList]']
}

// Form control IDL attributes reflect their content attributes, which
// constraint validation then reads.
fn test_form_control_attributes_reflect_into_constraint_validation() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><body><form id=f></form></body>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
const fail=message=>{throw new Error(message);};
const input=document.createElement("input");
input.pattern="[A-Z]";input.value="abc";
if(input.getAttribute("pattern")!=="[A-Z]"||input.checkValidity()||!input.validity.patternMismatch)fail("pattern");
input.pattern="";input.required=true;input.value="";
if(!input.hasAttribute("required")||input.checkValidity()||!input.validity.valueMissing)fail("required");
if(input.maxLength!==-1||input.size!==20)fail("defaults");
input.maxLength=4;if(input.getAttribute("maxlength")!=="4")fail("maxLength");
let threw=false;try{input.maxLength=-1;}catch(error){threw=error instanceof DOMException&&error.name==="IndexSizeError";}
if(!threw)fail("negative maxLength");
const area=document.createElement("textarea");
if(area.rows!==2||area.cols!==20)fail("textarea defaults");
area.readOnly=true;if(!area.hasAttribute("readonly"))fail("readOnly");
const form=document.getElementById("f");form.noValidate=true;if(!form.hasAttribute("novalidate"))fail("noValidate");
console.log("form reflections passed");
'], runtime, mut messages)
	assert messages == ['form reflections passed'], messages.str()
}
