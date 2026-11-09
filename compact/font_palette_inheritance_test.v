module main

import browserjs
import dom

fn test_paused_inherit_keyframes_follow_parent_style_changes() {
	mut document := parse_browser_navigation_document('<!doctype html><style>.light{font-palette:light}.dark{font-palette:dark}#target{font-palette:normal}</style><div id="parent" class="light"><div id="target">Text</div></div>',dom.URL{value:'https://palette-inheritance.test/'},none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close(); document.finalize() }
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[r'
const target=document.getElementById("target"),parent=document.getElementById("parent");
const animation=target.animate({fontPalette:["normal","inherit"]},1000);animation.pause();animation.currentTime=500;
if(getComputedStyle(target).fontPalette!=="palette-mix(in oklab, normal, light)")throw new Error("initial endpoint");
parent.className="dark";
if(getComputedStyle(target).fontPalette!=="palette-mix(in oklab, normal, dark)")throw new Error("changed endpoint: "+getComputedStyle(target).fontPalette);
globalThis.paletteInheritancePassed=true;
'],runtime,mut messages)
	assert messages == []string{},messages.str()
	assert runtime.evaluate_host('paletteInheritancePassed')! == 'true'
}
