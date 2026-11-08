module main

import browserjs
import html

fn test_compact_svg_interface_preserves_namespace_and_vue_mount_classification() {
	mut document := html.parse_document('<!doctype html><div id="host"></div><svg id="drawing"><g id="group"/></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://svg-interface.test/', [r'
if(Object.getPrototypeOf(SVGElement)!==Element||Object.getPrototypeOf(SVGElement.prototype)!==Element.prototype)throw new Error("SVG inheritance");
for(const [node,name] of [[drawing,"SVGSVGElement"],[group,"SVGGElement"],[document.createElementNS("http://www.w3.org/2000/svg","svg:g"),"SVGGElement"],[drawing.cloneNode(true),"SVGSVGElement"]]){
 if(!(node instanceof SVGElement)||!(node instanceof Element)||!(node instanceof EventTarget)||node instanceof HTMLElement)throw new Error("SVG classification");
 if(Object.prototype.toString.call(node)!=="[object "+name+"]")throw new Error("SVG interface tag");
}
for(const node of [host,document.createElement("svg"),document.createElementNS("urn:foreign","svg"),document.createDocumentFragment()]){
 if(node instanceof SVGElement)throw new Error("namespace classification");
}
// Vue checks this global even when mounting into a DocumentFragment.
const namespace=node=>node instanceof SVGElement?"svg":undefined;
if(namespace(drawing)!=="svg"||namespace(new DocumentFragment())!==undefined)throw new Error("Vue mount namespace");
let rejected=0;for(const construct of [()=>SVGElement(),()=>new SVGElement()])try{construct()}catch(error){if(error instanceof TypeError)rejected++;}
if(rejected!==2)throw new Error("SVG constructor");
globalThis.svgInterfacePassed=true;
'], runtime, mut messages)
	assert messages == []string{}
	assert runtime.evaluate_host('svgInterfacePassed')! == 'true'
}

fn test_compact_svg_animated_attributes_reflect_their_content_attributes() {
	mut document := html.parse_document('<!doctype html><svg id="drawing" width="200" height="100" viewBox="0 0 20 10"><rect id="box" x="5" width="2cm"/></svg>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://svg-interface.test/', [r'
const svg="http://www.w3.org/2000/svg",entries=[];
const circle=document.createElementNS(svg,"circle");
entries.push(circle.cx instanceof SVGAnimatedLength,circle.cx===circle.cx,circle.cx.baseVal===circle.cx.baseVal,circle.cx.baseVal instanceof SVGLength,circle.cx.baseVal.valueAsString);
circle.setAttribute("cx","42");entries.push(circle.cx.baseVal.valueAsString,circle.cx.baseVal.value);
circle.setAttribute("cx","foobar");entries.push(circle.cx.baseVal.valueAsString);
const filter=document.createElementNS(svg,"filter");entries.push(filter.x.baseVal.valueAsString,filter.width.baseVal.valueAsString,filter.width.baseVal.unitType===SVGLength.SVG_LENGTHTYPE_PERCENTAGE);
entries.push(document.createElementNS(svg,"feBlend").height.baseVal.valueAsString,document.createElementNS(svg,"marker").markerWidth.baseVal.valueAsString);
const box=document.getElementById("box");
entries.push(box.width.baseVal.unitType,Math.round(box.width.baseVal.value*100)/100);
box.width.baseVal.convertToSpecifiedUnits(SVGLength.SVG_LENGTHTYPE_MM);entries.push(box.getAttribute("width"));
box.x.baseVal.value=7;entries.push(box.getAttribute("x"));
let threw="";try{box.x.animVal.value=1;}catch(error){threw=error.name;}entries.push(threw);
threw="";try{box.x.baseVal.valueAsString="bad";}catch(error){threw=error.name;}entries.push(threw);
const blend=document.createElementNS(svg,"feBlend");entries.push(blend.mode.baseVal,blend.in1.baseVal);blend.mode.baseVal=SVGFEBlendElement.SVG_FEBLEND_MODE_SCREEN;blend.in1.baseVal="SourceGraphic";entries.push(blend.getAttribute("mode"),blend.getAttribute("in"));
const transfer=document.createElementNS(svg,"feFuncA");entries.push(transfer.slope.baseVal,transfer.intercept.baseVal);
const blur=document.createElementNS(svg,"feGaussianBlur");blur.setAttribute("stdDeviation","3 4");entries.push(blur.stdDeviationX.baseVal,blur.stdDeviationY.baseVal);
const drawing=document.getElementById("drawing");entries.push(drawing.viewBox.baseVal.width,drawing.preserveAspectRatio.baseVal.align,box.ownerSVGElement===drawing,drawing.ownerSVGElement);
const created=drawing.createSVGLength();created.valueAsString="3in";entries.push(created.value,created instanceof SVGLength);
entries.push(document.createElementNS(svg,"rect").className instanceof SVGAnimatedString);
threw="";try{Object.getOwnPropertyDescriptor(SVGCircleElement.prototype,"cx").get.call(SVGCircleElement.prototype);}catch(error){threw=error.constructor.name;}entries.push(threw);
console.log(entries.join("|"));
'], runtime, mut messages)
	assert messages == ['true|true|true|true|0|42|42|0|-10%|120%|true|100%|3|6|75.59|20mm|7|NoModificationAllowedError|SyntaxError|1||screen|SourceGraphic|1|0|3|4|20|6|true||288|true|true|TypeError'], messages.join('\n')
}
