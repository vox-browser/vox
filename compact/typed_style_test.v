module main

import browserjs
import html

fn test_computed_typed_style_reifies_keywords_units_and_position_options() {
	mut document := html.parse_document('<!doctype html><style>@position-try --p{left:30px;top:50px;width:20px;height:40px}#cb{position:relative;width:100px;height:100px}#target{position:absolute;left:9999px;position-try-fallbacks:--p}#auto{position:absolute;position-area:span-all}</style><div id="cb"><div id="target"></div><div id="auto"></div></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'https://typed.test/',[r'
const target=document.getElementById("target"),auto=document.getElementById("auto");
const map=target.computedStyleMap();if(map!==target.computedStyleMap()||!(map instanceof StylePropertyMapReadOnly))throw new Error("identity");
for(const [name,value] of [["left",30],["top",50],["width",20],["height",40]]){const unit=map.get(name);if(!(unit instanceof CSSUnitValue)||unit.value!==value||unit.unit!=="px")throw new Error(name+" "+unit);}
for(const name of ["left","top","right","bottom"]){const value=auto.computedStyleMap().get(name);if(!(value instanceof CSSKeywordValue)||value.value!=="auto")throw new Error("keyword "+name+" "+value);}
if(auto.computedStyleMap().get("position-area").toString()!=="span-all"||CSS.px(3).toString()!=="3px")throw new Error("serialize");
console.log("typed style passed");
'],runtime,mut messages)
	assert messages == ['typed style passed']
}
