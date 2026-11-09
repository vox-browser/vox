module main

import browserjs
import html
import dom
import page

fn test_logical_transitions_remove_the_previous_physical_sample_on_direction_changes() {
	mut document := html.parse_document('<!doctype html><style>#target{margin-inline-start:0;margin-right:0;transition:margin-inline-start 10s linear -5s}#target.on{margin-inline-start:100px}</style><div id="target"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'try{getComputedStyle(target).marginLeft;target.className="on";if(getComputedStyle(target).marginLeft!=="50px")throw Error("initial sample");target.style.direction="rtl";const style=getComputedStyle(target);if(style.marginLeft!=="0px"||style.marginRight!=="50px")throw Error(style.marginLeft+" "+style.marginRight);globalThis.remapped=true}catch(error){globalThis.remapError=String(error)}'], runtime, mut messages)
	assert messages == []string{}
	result := runtime.evaluate_host('globalThis.remapError||String(globalThis.remapped)')!
	assert result == 'true', result
}

fn test_logical_transition_remapping_preserves_other_css_animation_values() {
	url := dom.URL{ value: 'https://transition-restore.test/' }
	mut owner := page.Page.create(1)!
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_viewport_rect(dom.Rect{0, 0, 320, 200})
	html.parse_html_from_a_string(document, '<!doctype html><style>@keyframes a{from,to{width:20px}}#target{animation:a 100s linear;margin-inline-start:0;margin-right:0;transition:margin-inline-start 10s linear -5s}#target.on{margin-inline-start:100px}</style><div id="target"></div>')
	owner.set_local_root_navigable(document.navigable() or { panic('navigable') })!
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [r'try{if(getComputedStyle(target).width!=="20px")throw Error("initial animation");target.className="on";if(getComputedStyle(target).marginLeft!=="50px")throw Error("transition");target.style.direction="rtl";const style=getComputedStyle(target);if(style.marginLeft!=="0px"||style.marginRight!=="50px"||style.width!=="20px")throw Error(style.marginLeft+" "+style.marginRight+" "+style.width);globalThis.restored=true}catch(error){globalThis.restoreError=String(error)}'], runtime, mut messages)
	assert messages == []string{}
	result := runtime.evaluate_host('globalThis.restoreError||String(globalThis.restored)')!
	assert result == 'true', result
}
