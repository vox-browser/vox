module main

import browserjs
import html

fn test_compact_svg_elements_take_their_interface_prototypes() {
	$if !darwin {
		return
	}
	document := html.parse_document('<!doctype html><body><svg id=root><rect id=box /><linearGradient id=paint /><unknown id=other /></svg></body>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://example.test/', [r'
const fail=message=>{throw new Error(message);};
const svg="http://www.w3.org/2000/svg";
const rect=document.getElementById("box");
if(Object.getPrototypeOf(rect)!==SVGRectElement.prototype||!(rect instanceof SVGGeometryElement)||!(rect instanceof SVGGraphicsElement)||!(rect instanceof SVGElement)||!(rect instanceof Element))fail("rect chain");
if(String(rect)!=="[object SVGRectElement]")fail("stringification "+String(rect));
if(!(document.getElementById("root") instanceof SVGSVGElement)||!(document.getElementById("paint") instanceof SVGLinearGradientElement))fail("parsed interfaces");
if(Object.getPrototypeOf(document.getElementById("other"))!==SVGElement.prototype)fail("unknown element");
if(!(document.createElementNS(svg,"circle") instanceof SVGCircleElement)||!(document.createElementNS(svg,"feFuncR") instanceof SVGComponentTransferFunctionElement))fail("created interfaces");
if(SVGLength.SVG_LENGTHTYPE_PX!==5||SVGLength.prototype.SVG_LENGTHTYPE_PX!==5||SVGTransform.SVG_TRANSFORM_ROTATE!==4)fail("constants");
if(SVGRectElement.name!=="SVGRectElement"||SVGRectElement.length!==0||Object.getPrototypeOf(SVGRectElement)!==SVGGeometryElement)fail("interface object");
for(const call of [()=>SVGRectElement(),()=>new SVGRectElement()]){let threw=false;try{call();}catch(error){threw=error instanceof TypeError;}if(!threw)fail("constructor");}
console.log("svg interfaces passed");
'], runtime, mut messages)
	assert messages == ['svg interfaces passed'], messages.str()
}
