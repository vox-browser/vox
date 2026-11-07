module main

import browserjs
import html

fn test_compact_css_rule_interfaces_expose_grouping_media_and_declarations() {
	mut document := html.parse_document('<!doctype html><style id="s">@media screen and (min-width: 10px) { a { color: red } } @font-face { font-family: X; src: url(x.woff) } @keyframes spin { from { opacity: 0 } to { opacity: 1 } } @supports (display: grid) { b { color: blue } }</style>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'
const fail=message=>{throw new Error(message);};
const rules=document.getElementById("s").sheet.cssRules;
const media=rules[0],face=rules[1],frames=rules[2],supports=rules[3];
if(!(media instanceof CSSMediaRule)||!(media instanceof CSSConditionRule)||!(media instanceof CSSGroupingRule)||!(media instanceof CSSRule))fail("media chain");
if(media.media.mediaText!=="screen and (min-width: 10px)"||media.conditionText!=="screen and (min-width: 10px)")fail("media text "+media.media.mediaText);
if(media.cssRules.length!==1||media.cssRules[0].selectorText!=="a")fail("media rules");
media.insertRule("i { color: green }",1);
if(media.cssRules.length!==2||!media.cssRules[1].cssText.includes("color: green"))fail("insertRule");
media.deleteRule(0);
if(media.cssRules.length!==1)fail("deleteRule");
if(!(face instanceof CSSFontFaceRule))fail("font-face");
if(!(frames instanceof CSSKeyframesRule)||frames.name!=="spin"||frames.cssRules.length!==2)fail("keyframes");
const key=frames.cssRules[0];
if(!(key instanceof CSSKeyframeRule)||key.keyText!=="0%"||key.style.getPropertyValue("opacity")!=="0")fail("keyframe "+key.keyText);
if(!(supports instanceof CSSSupportsRule)||supports.conditionText!=="(display: grid)")fail("supports "+supports.conditionText);
console.log("rules passed");
'], runtime, mut messages)
	assert messages == ['rules passed']
}
