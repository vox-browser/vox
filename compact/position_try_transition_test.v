module main

import browserjs
import css
import dom

fn test_position_try_transition_can_be_sampled_canceled_and_started_again() {
	mut document := parse_browser_navigation_document('<!doctype html><style>#cb{display:inline-block;position:relative;width:400px;height:250px}#cb.shrink{width:300px}#target{position:absolute;left:300px;width:50px;height:50px}#target.fallback{position-try-fallbacks:--a}#target.anim{transition:left 1000s steps(2,start)}@position-try --a{left:200px}</style><div id="cb"><div id="target"></div></div>',dom.URL{value:'https://try-transition.test/'},none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close();document.finalize() }
	mut computer := css.css_style_computer_for(document)
	computer.set_animation_time_ms(0)
	mut messages := []string{}
	run_document_javascript(document,document.url.serialize(),[r'
 if(target.offsetLeft!==300)throw Error("initial position");
 cb.classList.add("shrink");target.classList.add("fallback","anim");
 if(target.offsetLeft!==250)throw Error("fallback transition sample: "+target.offsetLeft);
 target.className="";cb.className="";
 try{target.getAnimations().forEach(a=>a.cancel())}catch(e){throw Error("cleanup: "+e.message+" "+e.stack)}
 cb.classList.add("shrink");target.classList.add("fallback");
 if(target.offsetLeft!==200)throw Error("fallback without transition");
 cb.classList.remove("shrink");target.classList.remove("fallback");target.classList.add("anim");
 if(target.offsetLeft!==250)throw Error("unapplied transition sample: "+target.offsetLeft);
 '],runtime,mut messages)
	assert messages == []string{},messages.str()
}
