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
for(const node of [drawing,group,document.createElementNS("http://www.w3.org/2000/svg","svg:g"),drawing.cloneNode(true)]){
 if(!(node instanceof SVGElement)||!(node instanceof Element)||!(node instanceof EventTarget)||node instanceof HTMLElement)throw new Error("SVG classification");
 if(Object.prototype.toString.call(node)!=="[object SVGElement]")throw new Error("SVG interface tag");
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
