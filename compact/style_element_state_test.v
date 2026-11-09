module main

import browserjs
import html

fn test_style_element_disabled_and_media_change_the_associated_sheet() {
	mut document := html.parse_document('<!doctype html><style id="initial">#target{width:10px}</style><style id="media" media="print">#target{height:20px}</style><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,'https://style-state.test/',[r'
const initial=document.getElementById("initial"),media=document.getElementById("media"),target=document.getElementById("target");
if(initial.disabled||initial.sheet.disabled||getComputedStyle(target).width!=="10px")throw new Error("initial");
initial.disabled=true;
if(!initial.disabled||!initial.sheet.disabled||initial.hasAttribute("disabled")||getComputedStyle(target).width==="10px")throw new Error("disabled");
initial.disabled=false;if(getComputedStyle(target).width!=="10px")throw new Error("enabled");
media.media="";if(media.getAttribute("media")!==""||getComputedStyle(target).height!=="20px")throw new Error("media");
console.log("style state passed");
'],runtime,mut messages)
	assert messages == ['style state passed']
}
