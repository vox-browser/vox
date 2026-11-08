module main

import browserjs
import html

fn test_position_try_cssom_descriptors_keep_identity_and_restrict_properties() {
	mut document := html.parse_document('<!doctype html><style id="s">@position-try --fallback {top:10px;color:red}</style>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'about:blank',[r'
const rule=document.getElementById("s").sheet.cssRules[0];
if(!(rule instanceof CSSPositionTryRule)||!(rule instanceof CSSRule)||rule.name!=="--fallback")throw new Error("rule");
const style=rule.style;
if(style!==rule.style||!(style instanceof CSSPositionTryDescriptors)||!(style instanceof CSSStyleDeclaration)||style.top!=="10px"||style.color!==undefined)throw new Error("descriptors");
style.setProperty("color","green");style.setProperty("top","30px","important");
if(style.length!==1||style.getPropertyValue("top")!=="10px"||style.getPropertyValue("color")!=="")throw new Error("restriction");
style.insetBlockStart="20px";if(style.getPropertyValue("inset-block-start")!=="20px")throw new Error("logical descriptor");
style.cssText="position:fixed;left:2px";if(style.length!==1||rule.cssText!=="@position-try --fallback { left: 2px; }")throw new Error(rule.cssText);
console.log("position try rules passed");
'],runtime,mut messages)
	assert messages == ['position try rules passed']
}
