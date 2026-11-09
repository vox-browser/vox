module main

import browserjs
import html

fn test_typed_style_maps_share_live_inline_and_rule_declarations() {
	mut document := html.parse_document('<!doctype html><style id="sheet">#target{}</style><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://typed.test/', [r'
const target=document.getElementById("target"),rule=sheet.sheet.cssRules[0];
for(const map of [target.attributeStyleMap,rule.styleMap]){
 if(!(map instanceof StylePropertyMap)||!(map instanceof StylePropertyMapReadOnly))throw new Error("map interface");
 map.set("--tokens",CSSStyleValue.parse("--other","10px var(--fallback, red)"));
 const value=map.get("--tokens");if(!(value instanceof CSSUnparsedValue)||!String(value).includes("var(--fallback"))throw new Error("unparsed value "+value);
 if(map.getAll("--tokens").length!==1||!map.has("--tokens")||map.size!==1)throw new Error("map contents");
 const entries=Array.from(map);if(entries.length!==1||entries[0][0]!=="--tokens"||!(entries[0][1][0] instanceof CSSUnparsedValue))throw new Error("map iteration");
 for(const value of [CSS.px(10),new CSSKeywordValue("foo"),CSSStyleValue.parse("background-image","url(a)")]){let rejected=false;try{map.set("--typed",value)}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("typed custom write accepted");}
 let rejected=false;try{map.append("--tokens","extra")}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("custom append accepted");
 map.set("width",CSS.px(24));if(map.get("width").value!==24)throw new Error("typed width");
 map.delete("--tokens");if(map.has("--tokens"))throw new Error("delete");map.clear();if(map.size!==0)throw new Error("clear");
}
if(target.attributeStyleMap!==target.attributeStyleMap||rule.styleMap!==rule.styleMap)throw new Error("map identity");
target.attributeStyleMap.set("width",CSS.px(31));if(target.style.width!=="31px")throw new Error("inline sharing");
rule.styleMap.set("height",CSS.px(29));if(rule.style.height!=="29px"||getComputedStyle(target).height!=="29px")throw new Error("rule sharing");
console.log("mutable typed maps passed");
'], runtime, mut messages)
	assert messages == ['mutable typed maps passed']
}

fn test_computed_typed_maps_reify_registered_syntax_and_complete_lists() {
	mut document := html.parse_document('<!doctype html><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://typed.test/', [r'
const target=document.getElementById("target");
for(const [name,syntax,value] of [["--length","<length>","10px"],["--list","<length>#","10px, 20px"],["--ident","<custom-ident>","thing"],["--math","<length-percentage>","calc(10px + 10%)"],["--image","<image>","url(https://typed.test/a.png)"],["--tokens","*","thing()"]])CSS.registerProperty({name,syntax,initialValue:value,inherits:false});
const map=target.computedStyleMap();
if(!(map.get("--length") instanceof CSSUnitValue)||map.get("--length").value!==10)throw new Error("registered length");
if(map.getAll("--list").length!==2||!map.getAll("--list").every(value=>value instanceof CSSUnitValue))throw new Error("registered list");
if(!(map.get("--ident") instanceof CSSKeywordValue)||String(map.get("--ident"))!=="thing")throw new Error("registered ident");
if(!(map.get("--math") instanceof CSSMathSum)||map.get("--math").values.length!==2)throw new Error("registered calculation");
if(!(map.get("--image") instanceof CSSImageValue)||!(map.get("--tokens") instanceof CSSUnparsedValue))throw new Error("registered image/tokens");
if(!Array.from(map).some(([name,values])=>name==="--length"&&values[0] instanceof CSSUnitValue))throw new Error("computed iteration");
const unparsed=new CSSUnparsedValue(["before ",new CSSVariableReferenceValue("--x",new CSSUnparsedValue(["red"]))]);
if(unparsed.length!==2||Array.from(unparsed).length!==2||String(unparsed)!=="before var(--x, red)")throw new Error("unparsed segments");
if(!(CSSNumericValue.parse("calc(10px + 20%)") instanceof CSSMathSum))throw new Error("numeric parsing");
console.log("computed typed maps passed");
'], runtime, mut messages)
	assert messages == ['computed typed maps passed']
}
