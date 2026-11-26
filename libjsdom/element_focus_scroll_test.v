module libjsdom

import dom
import html
import layout
import libjs

fn focus_scroll_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'focus-scroll.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 100000 })
}

fn test_focus_keeps_visible_targets_still_and_does_not_reveal_a_redirected_target() {
	address := dom.URL{ value: 'https://focus-scroll.test/' }
	mut document := html.parse_navigation_document('<!doctype html><style>body{margin:0;height:2000px}button{position:absolute;top:261px;left:32px}</style><button id="first">first</button><button id="second" style="top:350px">second</button>', address, address.origin(), none)!
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	mut navigable := &dom.Navigable{ active_document_: document, is_top_level_traversable_: true }
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	layout.install_document_layout_hook(document)
	document.needs_full_layout_tree_update = true
	document.update_layout(.debugging)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert focus_scroll_eval(mut vm, 'var first=document.getElementById("first"),second=document.getElementById("second");first.focus();document.activeElement===first&&scrollY===0')!.as_bool()
	assert focus_scroll_eval(mut vm, 'first.addEventListener("focus",()=>second.focus({preventScroll:true}));first.blur();first.focus();document.activeElement===second&&scrollY===0')!.as_bool()
}
