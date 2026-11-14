module libjsdom

import dom
import html
import libjs

const hacker_news_script = $embed_file('@VMODROOT/Tests/Browser/Brave/hn-home-instructions/bodies/2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0').to_string()

const hacker_news_discussion = $embed_file('@VMODROOT/Tests/Browser/Brave/input/hacker-news-item-50231722-complete.html').to_string()

const comment_fixture = $embed_file('@VMODROOT/Tests/Browser/LibJS/hacker-news-comments.html').to_string()

fn run_host_source(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'https://news.ycombinator.com/hn.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{ max_instructions: 1000000 }) or { return error(exception_message(err)) }
}

fn click_toggle(document &dom.Document, id string) &dom.Event {
	row := document.get_element_by_id(id) or { panic('Missing row') }
	mut parent := unsafe { &dom.ParentNode(row.as_node()) }
	toggle := parent.get_elements_by_class_name('togg').item(0) or { panic('Missing toggle') }
	event := dom.Event.create('click', dom.EventInit{ bubbles: true, cancelable: true })
	target := unsafe { &dom.EventTarget(toggle) }
	target.dispatch_event(event)
	return event
}

fn test_unmodified_hacker_news_script_collapses_and_restores_native_nested_comments() {
	mut document := html.parse_document(comment_fixture)
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.url = dom.URL{ value: 'https://news.ycombinator.com/item?id=100' }
	html.install_document_fragment_parsing_hook(document)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut failures := []string{}
	mut host := Host.create(vm, vm.realm(), document, Hooks{
		exception: fn [mut failures] (message string) {
			failures << message
		}
	})!
	defer { host.close() }
	run_host_source(mut vm, hacker_news_script)!
	assert failures.len == 0
	assert click_toggle(document, '101').default_prevented()
	assert run_host_source(mut vm, 'hasClass($("101"),"coll") && hasClass($("102"),"noshow")')!.to_boolean()
	assert click_toggle(document, '100').default_prevented()
	assert run_host_source(mut vm, 'hasClass($("100"),"coll") && hasClass($("101"),"noshow") && hasClass($("103"),"noshow") && !hasClass($("104"),"noshow")')!.to_boolean()
	assert run_host_source(mut vm, 'byClass($("100"),"togg")[0].innerHTML')!.as_string().str() == '[3 more]'
	assert click_toggle(document, '100').default_prevented()
	assert run_host_source(mut vm, '!hasClass($("100"),"coll") && !hasClass($("101"),"noshow") && hasClass($("102"),"noshow") && !hasClass($("103"),"noshow")')!.to_boolean()
	assert click_toggle(document, '101').default_prevented()
	assert run_host_source(mut vm, '!hasClass($("101"),"coll") && !hasClass($("102"),"noshow")')!.to_boolean()
	assert failures.len == 0
	assert vm.execution_context_stack().len == 1
	assert vm.interpreter_stack().depth() == 0
	println('LibJS Hacker News nested collapse/expand: passed')
}

fn test_unmodified_hacker_news_script_runs_on_the_complete_archived_discussion() {
	mut document := html.parse_document(hacker_news_discussion)
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.url = dom.URL{ value: 'https://news.ycombinator.com/item?id=50231722' }
	html.install_document_fragment_parsing_hook(document)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	run_host_source(mut vm, hacker_news_script)!
	mut parent := unsafe { &dom.ParentNode(document) }
	rows := parent.get_elements_by_class_name('comtr')
	assert rows.length() > 100
	mut before := []string{}
	for index in 0 .. rows.length() { before << rows.item(index)?.get_attribute_value('class') }
	first := rows.item(0)?
	id := first.get_attribute_value('id')
	assert click_toggle(document, id).default_prevented()
	assert first.get_attribute_value('class').split(' ').contains('coll')
	assert parent.get_elements_by_class_name('noshow').length() > 1
	assert click_toggle(document, id).default_prevented()
	for index in 0 .. rows.length() {
		assert rows.item(index)?.get_attribute_value('class') == before[index]
	}
	println('LibJS Hacker News archived discussion: ${rows.length()} comment rows restored')
}

fn test_libjs_dom_collections_follow_native_mutations_and_keep_node_identity() {
	mut document := html.parse_document('<body><div id="a" class="x">a</div><div id="b">b</div></body>')
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.url = dom.URL{ value: 'https://news.ycombinator.com/' }
	html.install_document_fragment_parsing_hook(document)
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	assert run_host_source(mut vm, 'var a=document.getElementById("a");var b=document.getElementById("b");var xs=document.getElementsByClassName("x");xs.length===1 && xs[0]===a')!.to_boolean()
	assert run_host_source(mut vm, 'b.className="x";xs.length===2 && xs[1]===b && xs.item(1)===b')!.to_boolean()
	assert run_host_source(mut vm, 'a.className="";xs.length===1 && xs[0]===b && xs[1]===undefined')!.to_boolean()
	assert run_host_source(mut vm, 'b.innerHTML="<span id=c>new</span>";document.getElementById("c").parentNode===b')!.to_boolean()
	assert run_host_source(mut vm, 'var u=new URL("/item?id=100","https://news.ycombinator.com/");u instanceof URL && u.pathname==="/item" && u.searchParams.get("id")==="100" && !(location instanceof URL)')!.to_boolean()
	host.close()
	println('LibJS live DOM collections and node identity: passed')
}

fn test_libjs_native_event_identity_once_removal_and_default_cancellation() {
	mut document := html.parse_document('<body><button id="a">a</button></body>')
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.url = dom.URL{ value: 'https://news.ycombinator.com/' }
	mut vm := libjs.VM.create()
	libjs.create_simple_execution_context(mut vm)
	mut host := Host.create(vm, vm.realm(), document, Hooks{})!
	defer { host.close() }
	run_host_source(mut vm, 'var a=document.getElementById("a"),calls=0,identity=false;function once(e){calls++;identity=e.target===a && e.currentTarget===a && this===a;e.preventDefault()} a.addEventListener("click",once,{once:true});a.addEventListener("click",once,{once:true})')!
	target := unsafe { &dom.EventTarget(document.get_element_by_id('a')?) }
	first := dom.Event.create('click', dom.EventInit{ bubbles: true, cancelable: true })
	target.dispatch_event(first)
	assert first.default_prevented()
	assert run_host_source(mut vm, 'calls===1 && identity')!.to_boolean()
	second := dom.Event.create('click', dom.EventInit{ bubbles: true, cancelable: true })
	target.dispatch_event(second)
	assert !second.default_prevented()
	run_host_source(mut vm, 'a.addEventListener("click",once);a.removeEventListener("click",once);a.onclick=function(e){calls++;return false}')!
	third := dom.Event.create('click', dom.EventInit{ bubbles: true, cancelable: true })
	target.dispatch_event(third)
	assert third.default_prevented()
	assert run_host_source(mut vm, 'calls')!.number == 2
	host.close()
	fourth := dom.Event.create('click', dom.EventInit{ bubbles: true, cancelable: true })
	target.dispatch_event(fourth)
	assert !fourth.default_prevented()
	println('LibJS native event identity, once, removal and cancellation: passed')
}
