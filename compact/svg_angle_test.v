module main

import browserjs
import html

fn test_svg_angles_convert_units_and_reflect_marker_orientation() {
	mut document := html.parse_document('<!doctype html><svg id="drawing"><marker id="marker"/></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://svg-angle.test/', [r'
const check=(actual,expected)=>{if(actual!==expected)throw new Error(String(actual)+" != "+String(expected));};
const near=(actual,expected)=>{if(Math.abs(actual-expected)>0.0001)throw new Error(actual+" != "+expected);};
const throws=(name,callback)=>{let result;try{callback();}catch(error){result=error.name;}check(result,name);};
const drawing=document.getElementById("drawing"),marker=document.getElementById("marker");
const angle=drawing.createSVGAngle();
check(angle instanceof SVGAngle,true);check(angle.unitType,SVGAngle.SVG_ANGLETYPE_UNSPECIFIED);check(angle.value,0);check(angle.valueAsString,"0");
angle.newValueSpecifiedUnits(SVGAngle.SVG_ANGLETYPE_GRAD,100);near(angle.value,90);check(angle.valueAsString,"100grad");
angle.convertToSpecifiedUnits(SVGAngle.SVG_ANGLETYPE_RAD);near(angle.valueInSpecifiedUnits,Math.PI/2);near(angle.value,90);
angle.convertToSpecifiedUnits(SVGAngle.SVG_ANGLETYPE_DEG);near(angle.valueInSpecifiedUnits,90);
angle.valueAsString=".5TURN";check(angle.unitType,SVGAngle.SVG_ANGLETYPE_UNKNOWN);check(angle.value,180);check(angle.valueAsString,"0.5turn");
angle.valueInSpecifiedUnits=0.25;check(angle.value,90);check(angle.valueAsString,"0.25turn");
angle.value=45;check(angle.valueAsString,"45");check(angle.unitType,SVGAngle.SVG_ANGLETYPE_UNSPECIFIED);
for(const text of ["bad","1px","1 2deg","Infinity","1e100deg"])throws("SyntaxError",()=>{angle.valueAsString=text;});
for(const value of [NaN,Infinity,1e100,1n,Symbol()])throws("TypeError",()=>{angle.value=value;});
throws("TypeError",()=>{angle.valueAsString=Symbol();});
throws("NotSupportedError",()=>angle.convertToSpecifiedUnits(0));throws("NotSupportedError",()=>angle.newValueSpecifiedUnits(5,1));
check(marker.orientAngle,marker.orientAngle);check(marker.orientType,marker.orientType);
const base=marker.orientAngle.baseVal,anim=marker.orientAngle.animVal;
check(base,marker.orientAngle.baseVal);check(anim,marker.orientAngle.animVal);check(base instanceof SVGAngle,true);check(base===anim,false);
check(marker.orientType.baseVal,SVGMarkerElement.SVG_MARKER_ORIENT_ANGLE);
marker.orient="100grad";check(base.valueAsString,"100grad");near(anim.value,90);
base.valueInSpecifiedUnits=50;check(marker.getAttribute("orient"),"50grad");near(anim.value,45);
marker.setOrientToAuto();check(marker.orient,"auto");check(marker.orientType.animVal,SVGMarkerElement.SVG_MARKER_ORIENT_AUTO);check(base.value,0);
marker.orientType.baseVal=SVGMarkerElement.SVG_MARKER_ORIENT_AUTO_START_REVERSE;check(marker.orient,"auto-start-reverse");check(marker.orientType.baseVal,3);
marker.orientType.baseVal=SVGMarkerElement.SVG_MARKER_ORIENT_ANGLE;check(marker.orient,"0");
angle.valueAsString="1rad";marker.setOrientToAngle(angle);check(marker.orient,"1rad");angle.value=10;check(marker.orient,"1rad");
throws("TypeError",()=>{marker.orientType.baseVal=0;});
for(const mutate of [()=>{anim.value=1;},()=>{anim.valueInSpecifiedUnits=1;},()=>{anim.valueAsString="2deg";},()=>anim.newValueSpecifiedUnits(2,3),()=>anim.convertToSpecifiedUnits(2)])throws("NoModificationAllowedError",mutate);
for(const [object,name,length] of [[SVGAngle.prototype,"newValueSpecifiedUnits",2],[SVGAngle.prototype,"convertToSpecifiedUnits",1],[SVGMarkerElement.prototype,"setOrientToAuto",0],[SVGMarkerElement.prototype,"setOrientToAngle",1],[SVGSVGElement.prototype,"createSVGAngle",0]]){
 const method=object[name];check(method.length,length);check(method.name,name);check(Object.hasOwn(method,"prototype"),false);throws("TypeError",()=>new method());throws("TypeError",()=>method.call({}));
}
for(const name of ["createSVGLength","createSVGNumber","createSVGPoint","createSVGMatrix","createSVGRect"]){
 const method=SVGSVGElement.prototype[name];check(Object.hasOwn(method,"prototype"),false);throws("TypeError",()=>method.call({}));
}
for(const name of ["ownerSVGElement","viewportElement"])throws("TypeError",()=>Object.getOwnPropertyDescriptor(SVGElement.prototype,name).get.call(SVGElement.prototype));
throws("TypeError",()=>angle.newValueSpecifiedUnits(2));throws("TypeError",()=>angle.convertToSpecifiedUnits());throws("TypeError",()=>marker.setOrientToAngle());throws("TypeError",()=>marker.setOrientToAngle({valueAsString:"1deg"}));
for(const name of ["unitType","value","valueInSpecifiedUnits","valueAsString"])throws("TypeError",()=>Object.getOwnPropertyDescriptor(SVGAngle.prototype,name).get.call(SVGAngle.prototype));
console.log("SVG angles and marker orientation passed");
'], runtime, mut messages)
	assert messages == ['SVG angles and marker orientation passed'], messages.join('\n')
}
