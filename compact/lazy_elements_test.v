module main

import browserjs
import css
import dom
import html
import x.json2

fn test_native_initial_metadata_leaves_anonymous_owners_for_queries_and_preserves_full_adapter() {
	mut document := html.parse_document('<!doctype html><div id="named">named</div>' +
		'<span class="unused">unread</span>'.repeat(1000))
	defer { document.finalize() }
	full := javascript_initial_state(document, 'about:blank', [])
	sparse := javascript_initial_state_with_policy(document, 'about:blank', [], .roots_and_ids)
	assert full['elements']!.as_map().len > 1000
	assert sparse['elements']!.as_map().len == 4
	assert json2.encode(sparse).len < json2.encode(full).len / 20
}

fn test_native_queries_materialize_complete_controls_and_anonymous_parent_identity() {
	mut document :=
		html.parse_document('<!doctype html><div id="named"><section class="parent"><span class="child" data-state="before">Word</span><input type="checkbox" value="start" checked><textarea>seed</textarea></section></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
 const child=document.querySelector(".child"),parent=child.parentElement;
 if(child.localName!=="span"||child.getAttribute("data-state")!=="before"||child.textContent!=="Word")throw new Error("anonymous metadata");
 if(parent!==document.querySelector(".parent")||parent!==named.firstChild||child.parentNode!==parent)throw new Error("parent identity");
 if(child.firstChild.parentNode!==child||child.firstChild.nodeValue!=="Word")throw new Error("text parent identity");
 if(document.documentElement.parentNode!==document||document.body.parentElement!==document.documentElement)throw new Error("root identity");
 const input=parent.querySelector("input"),area=parent.querySelector("textarea");
 if(!input.checked||input.value!=="start"||area.value!=="seed")throw new Error("control metadata");
 input.checked=false;input.value="changed";child.textContent="Updated";
 if(document.getElementsByTagName("span")[0]!==child)throw new Error("collection identity");
 console.log("lazy owners passed");
 ',
	], runtime, mut messages)
	assert messages == ['lazy owners passed']
	assert css.query_selector(document.as_node(), '.child')?.as_node().text_content()? == 'Updated'
	input := css.query_selector(document.as_node(), 'input')?
	model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	assert !model.checked()
	assert runtime.evaluate_host('document.querySelector("input").value')! == 'changed'
}

fn test_first_lazy_control_query_reads_native_edits_made_after_bootstrap() {
	mut document :=
		html.parse_document('<!doctype html><input value="start"><textarea>seed</textarea>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', ['globalThis.bootstrapped=true'], runtime, mut
		messages)
	assert messages == []string{}
	input := css.query_selector(document.as_node(), 'input')?
	mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(input) })
	model.set_value('live')!
	textarea := css.query_selector(document.as_node(), 'textarea')?
	mut area :=
		html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(textarea) })
	area.set_value('late')
	assert runtime.evaluate_host('document.querySelector("input").value+"|"+document.querySelector("textarea").value')! == 'live|late'
}

fn test_native_text_metadata_does_not_mark_its_unseen_parent_as_already_sent() {
	mut document :=
		html.parse_document('<!doctype html><section><span class="child">Word</span></section>')
	all := css.query_selector_all(document.as_node(), '*')
	child := css.query_selector(document.as_node(), '.child')?
	mut key := ''
	for index, element in all {
		if voidptr(element) == voidptr(child) { key = '__element_${index}' }
	}
	assert key != ''
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
			'const nativeText=JSON.parse(__ladybirdElementQuery(JSON.stringify({key:"${key}",action:"firstChild",selector:""})));' +
			r'
  if(nativeText.nodeType!==3)throw new Error("native text");
  const owner=document.querySelector(".child");
  if(owner.localName!=="span"||owner.className!=="child"||owner.firstChild.parentNode!==owner)throw new Error("unseen parent metadata");
  console.log("unseen parent passed");',
	], runtime, mut messages)
	assert messages == ['unseen parent passed']
}
