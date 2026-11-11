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

fn test_typed_om_transform_components_construct_serialize_and_validate() {
	mut document := html.parse_document('<!doctype html><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://typed.test/', [r'
const value=new CSSTransformValue([new CSSTranslate(CSS.px(0),CSS.px(1),CSS.px(2)),new CSSTranslate(CSS.percent(50),CSS.px(1)),new CSSRotate(1,2,3,CSS.deg(45)),new CSSRotate(CSS.deg(45)),new CSSScale(1,2,3),new CSSScale(1,2),new CSSSkew(CSS.deg(1),CSS.deg(0)),new CSSSkewX(CSS.deg(1)),new CSSSkewY(CSS.deg(45)),new CSSPerspective(CSS.px(1)),new CSSMatrixComponent(new DOMMatrixReadOnly([1,2,3,4,5,6]))]);
const text="translate3d(0px, 1px, 2px) translate(50%, 1px) rotate3d(1, 2, 3, 45deg) rotate(45deg) scale3d(1, 2, 3) scale(1, 2) skew(1deg) skewX(1deg) skewY(45deg) perspective(1px) matrix(1, 2, 3, 4, 5, 6)";
if(String(value)!==text)throw new Error("serialization "+value);
if(value.length!==11||value.is2D||!(value[0] instanceof CSSTranslate)||value[0].is2D||!value[1].is2D||value[2].x.value!==1)throw new Error("components");
if(!(value instanceof CSSStyleValue)||Object.prototype.toString.call(value[9])!=="[object CSSPerspective]")throw new Error("interfaces");
for(const make of [()=>new CSSTranslate(CSS.deg(1),CSS.px(1)),()=>new CSSRotate(CSS.px(1)),()=>new CSSSkew(CSS.px(1),CSS.deg(1)),()=>new CSSTransformValue([]),()=>new CSSTransformValue([CSS.px(1)])]){let rejected=false;try{make()}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("invalid component accepted");}
const matrix=new CSSMatrixComponent(new DOMMatrixReadOnly([1,2,3,4,5,6])),copy=matrix.toMatrix();copy.m41=100;
if(copy===matrix.matrix||matrix.matrix.m41!==5||String(matrix)!=="matrix(1, 2, 3, 4, 5, 6)")throw new Error("matrix copy");
const sum=new CSSMathSum(CSS.px(1),CSS.em(2)).type();if(sum.length!==1||sum.percent!==undefined||CSS.percent(1).type().percent!==1||Object.keys(CSS.number(1).type()).length!==0)throw new Error("numeric type");
const target=document.getElementById("target");let rejected=false;try{target.attributeStyleMap.set("opacity",value)}catch(error){rejected=error instanceof TypeError}if(!rejected)throw new Error("transform accepted for opacity");
target.attributeStyleMap.set("transform",new CSSTransformValue([new CSSTranslate(CSS.px(3),CSS.px(4))]));
const specified=target.attributeStyleMap.get("transform");if(!(specified instanceof CSSTransformValue)||!(specified[0] instanceof CSSTranslate)||specified[0].x.value!==3)throw new Error("transform round trip "+specified);
console.log("transform components passed");
'], runtime, mut messages)
	assert messages == ['transform components passed']
}

fn test_style_map_mutations_queue_one_style_attribute_reaction() {
	mut document := html.parse_document('<!doctype html><body></body>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document, 'https://typed.test/', [r'
class TestElement extends HTMLElement{static observedAttributes=["style"];constructor(){super();this.calls=[];}attributeChangedCallback(name,oldValue,newValue){this.calls.push([name,oldValue,newValue]);}}
customElements.define("test-el",TestElement);
const el=document.createElement("test-el");document.body.appendChild(el);
el.attributeStyleMap.set("color","red");
if(el.calls.length!==1||el.calls[0][1]!==null||el.calls[0][2]!=="color: red;")throw new Error("set "+JSON.stringify(el.calls));
el.calls.length=0;el.attributeStyleMap.set("color","blue");
if(el.calls.length!==1||el.calls[0][1]!=="color: red;"||el.calls[0][2]!=="color: blue;")throw new Error("replace "+JSON.stringify(el.calls));
el.calls.length=0;el.style.setProperty("display","none");
if(el.calls.length!==1||el.calls[0][2]!=="color: blue; display: none;")throw new Error("inline style "+JSON.stringify(el.calls));
el.calls.length=0;el.attributeStyleMap.set("transition-duration","1s");el.calls.length=0;el.attributeStyleMap.append("transition-duration");
if(el.calls.length!==0)throw new Error("empty append "+JSON.stringify(el.calls));
console.log("style reactions passed");
'], runtime, mut messages)
	assert messages == ['style reactions passed']
}
