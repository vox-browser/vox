module main

import browserjs
import html

fn test_linear_gradient_animated_length_defaults_preserve_percentage_units() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><body><svg><linearGradient id="gradient" /></svg></body>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
const gradient=document.getElementById("gradient");
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
for(const name of ["x1","y1","x2","y2"]){
 const expected=name==="x2"?100:0;
 const animated=gradient[name];
 for(const attribute of [null,"invalid"]){
  if(attribute===null)gradient.removeAttribute(name);else gradient.setAttribute(name,attribute);
  for(const value of [animated.baseVal,animated.animVal]){
   check(value.unitType,SVGLength.SVG_LENGTHTYPE_PERCENTAGE);
   check(value.valueInSpecifiedUnits,expected);
   check(value.valueAsString,String(expected)+"%");
  }
 }
 gradient.setAttribute(name,"4px");
 check(animated.baseVal.unitType,SVGLength.SVG_LENGTHTYPE_PX);
 check(animated.animVal.valueAsString,"4px");
 gradient.removeAttribute(name);
 check(animated.baseVal.valueAsString,String(expected)+"%");
}
console.log("gradient length defaults passed");
'], runtime, mut messages)
	assert messages == ['gradient length defaults passed'], messages.str()
}
