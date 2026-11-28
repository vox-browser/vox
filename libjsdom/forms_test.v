// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import platform
import rand

@[heap]
struct NativeFormSubmissionRecord {
mut:
	submissions []html.FormSubmission
	targets []string
	elements []voidptr
}

fn (record &NativeFormSubmissionRecord) submit_form(element &dom.Element, target string, submission html.FormSubmission) ! {
	mut owner := unsafe { &NativeFormSubmissionRecord(record) }
	owner.submissions << submission; owner.targets << target; owner.elements << voidptr(element)
}

fn native_forms_fixture() !(&Host, &libjs.VM, &NativeFormSubmissionRecord) {
	mut host, mut vm := text_encoding_fixture()!
	mut document := unsafe { &dom.Document(host.document) }
	mut navigable := &dom.Navigable{active_document_: document, is_top_level_traversable_: true}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	record := &NativeFormSubmissionRecord{}
	host.set_form_submission_host(record)
	return host, vm, record
}

fn test_native_form_action_enumerations_and_raw_reflected_attributes() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f></form>";var f=document.getElementById("f"),defaults=f.action===document.URL&&f.method==="get"&&f.enctype==="application/x-www-form-urlencoded"&&f.encoding===f.enctype&&f.autocomplete==="on";f.action="/save";f.method="POST";f.enctype="MULTIPART/FORM-DATA";f.autocomplete="OFF";var edited=f.action==="https://libjs-encoding.test/save"&&f.method==="post"&&f.getAttribute("method")==="POST"&&f.enctype==="multipart/form-data"&&f.autocomplete==="off";f.method="invalid";f.encoding="text/plain";f.noValidate=true;defaults&&edited&&f.method==="get"&&f.enctype==="text/plain"&&f.noValidate&&f.hasAttribute("novalidate")')!.as_bool()
}

fn test_native_form_length_and_rel_list_are_live_without_eager_control_wrappers() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input><input type=image><fieldset></fieldset></form><input form=f>";var f=document.getElementById("f"),before=f.length,list=f.relList;f.relList="nofollow noopener";var same=list===f.relList&&list.contains("nofollow")&&f.rel==="nofollow noopener";var e=document.createElement("input");f.appendChild(e);var after=f.length;e.remove();before===3&&after===4&&f.length===3&&same')!.as_bool()
}

fn test_native_submitter_overrides_distinguish_absent_and_invalid_enumerations() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var b=document.createElement("button"),i=document.createElement("input"),empty=b.formMethod===""&&b.formEnctype===""&&i.formMethod==="";b.formAction="/post";b.formMethod="POST";b.formEnctype="TEXT/PLAIN";b.formTarget="result";b.formNoValidate=true;i.formMethod="invalid";empty&&b.formAction==="https://libjs-encoding.test/post"&&b.formMethod==="post"&&b.formEnctype==="text/plain"&&b.formTarget==="result"&&b.formNoValidate&&i.formMethod==="get"&&b.getAttribute("formmethod")==="POST"')!.as_bool()
}

fn test_native_form_rel_list_put_forwards_observes_author_replacements_before_coercion() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var f=document.createElement("form"),setter=Object.getOwnPropertyDescriptor(HTMLFormElement.prototype,"relList").set,marker={},seen,coerced=0;Object.defineProperty(f,"relList",{get(){return {set value(v){seen=v}}},configurable:true});setter.call(f,marker);var raw=seen===marker;Object.defineProperty(f,"relList",{get(){return 1}});var bad=false;try{setter.call(f,{toString(){coerced++;return "x"}})}catch(e){bad=e instanceof TypeError}raw&&bad&&coerced===0')!.as_bool()
}

fn test_native_form_reset_restores_control_defaults_and_can_be_canceled() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input id=i value=initial><input id=c type=checkbox checked><textarea id=t>original</textarea><select id=s><option value=a selected>A</option><option value=b>B</option></select></form>";var f=document.getElementById("f"),i=document.getElementById("i"),c=document.getElementById("c"),t=document.getElementById("t"),s=document.getElementById("s");i.value="edited";c.checked=false;t.value="new";s.value="b";f.reset();var restored=i.value==="initial"&&c.checked&&t.value==="original"&&s.value==="a";f.addEventListener("reset",e=>e.preventDefault());i.value="keep";f.reset();restored&&i.value==="keep"')!.as_bool()
}

fn test_native_request_submit_uses_real_submit_event_and_original_button_identity() {
	mut host, mut vm, record := native_forms_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><button id=b name=button value=go>Go</button></form>";var f=document.getElementById("f"),b=document.getElementById("b"),seen=[];f.addEventListener("submit",e=>{if(!(e instanceof SubmitEvent)||!e.isTrusted||!e.bubbles||!e.cancelable||e.target!==f)throw 1;seen.push(e.submitter);e.preventDefault()});f.requestSubmit(b);f.requestSubmit();f.requestSubmit(null);seen.length===3&&seen[0]===b&&seen[1]===null&&seen[2]===null')!.as_bool()
	assert record.submissions.len == 0
}

fn test_native_form_no_validate_bypasses_constraint_validation_without_submitter() {
	mut host, mut vm, record := native_forms_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input required></form>";var f=document.getElementById("f"),submits=0;f.addEventListener("submit",e=>{submits++;e.preventDefault()});var invalid=!f.checkValidity();f.requestSubmit();var blocked=submits===0;f.noValidate=true;f.requestSubmit();invalid&&blocked&&submits===1')!.as_bool()
	assert record.submissions.len == 0
}

fn test_native_form_submission_service_receives_post_bytes_target_and_no_submit_event_for_submit() {
	mut host, mut vm, record := native_forms_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f method=post action=/save target=result><input id=i name=a required></form>";var f=document.getElementById("f"),i=document.getElementById("i"),events=0;f.addEventListener("submit",()=>events++);i.value="edited";f.submit();events===0')!.as_bool()
	assert record.submissions.len == 1 && record.targets == ['result']
	assert record.submissions[0].method == .post
	assert record.submissions[0].url.serialize() == 'https://libjs-encoding.test/save'
	assert record.submissions[0].body.bytestr() == 'a=edited'
	assert record.submissions[0].content_type == 'application/x-www-form-urlencoded'
}

fn test_native_request_submit_service_receives_submitter_target_and_method_overrides() {
	mut host, mut vm, record := native_forms_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'document.body.innerHTML="<form id=f action=/default><input name=a value=1><button id=b name=choice value=go formmethod=post formaction=/override formtarget=frame formenctype=text/plain></button></form>";document.getElementById("f").requestSubmit(document.getElementById("b"))')!
	assert record.submissions.len == 1 && record.targets == ['frame']
	assert record.submissions[0].method == .post && record.submissions[0].encoding == .plain_text
	assert record.submissions[0].url.serialize() == 'https://libjs-encoding.test/override'
	assert record.submissions[0].body.bytestr().contains('choice=go')
}

fn test_native_form_request_submit_brand_and_submitter_failures_preserve_errors() {
	mut host, mut vm, _ := native_forms_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'document.body.innerHTML="<form id=f><input id=i><button type=button id=n></button></form><form><button id=other></button></form>";var f=document.getElementById("f"),bad=0,missing=false;for(var run of [()=>HTMLFormElement.prototype.reset.call({}),()=>f.requestSubmit({}),()=>f.requestSubmit(document.body),()=>f.requestSubmit(document.getElementById("i")),()=>f.requestSubmit(document.getElementById("n"))])try{run()}catch(e){if(e instanceof TypeError)bad++}try{f.requestSubmit(document.getElementById("other"))}catch(e){missing=e instanceof DOMException&&e.name==="NotFoundError"}bad===5&&missing')!.as_bool()
}

fn test_native_submission_target_is_read_after_submit_handler_mutations() {
	mut host, mut vm, record := native_forms_fixture()!
	defer { host.close() }
	stream_eval(mut vm, 'document.body.innerHTML="<form id=f action=/save><button id=b formtarget=before></button></form>";var form=document.getElementById("f"),button=document.getElementById("b");form.addEventListener("submit",()=>button.formTarget="after");form.requestSubmit(button)')!
	assert record.targets == ['after']
}

fn test_native_submit_event_constructor_and_conversion_order() {
	mut host, mut vm := text_encoding_fixture()!
	defer { host.close() }
	assert stream_eval(mut vm, 'var button=document.createElement("button"),order=[],target=new Proxy(function(){},{get(t,k){if(k==="prototype"){order.push("prototype");return SubmitEvent.prototype}return Reflect.get(t,k)}});var e=Reflect.construct(SubmitEvent,[{toString(){order.push("type");return "submit"}},{get bubbles(){order.push("bubbles");return true},get cancelable(){order.push("cancelable");return true},get composed(){order.push("composed");return false},get submitter(){order.push("submitter");return button}}],target);var bad=0;for(var run of [()=>SubmitEvent("x"),()=>new SubmitEvent(),()=>new SubmitEvent("x",1),()=>new SubmitEvent("x",{submitter:{}}),()=>Object.getOwnPropertyDescriptor(SubmitEvent.prototype,"submitter").get.call(new Event("x"))])try{run()}catch(e){if(e instanceof TypeError)bad++}bad===5&&order.join()==="type,bubbles,cancelable,composed,submitter,prototype"&&e instanceof SubmitEvent&&e instanceof Event&&e.submitter===button&&e.bubbles&&e.cancelable&&!e.isTrusted&&Object.getPrototypeOf(SubmitEvent)===Event&&SubmitEvent.length===1')!.as_bool()
}

fn test_native_form_preserves_preexisting_submission_hook_and_clears_host_service_on_close() {
	mut host, mut vm, record := native_forms_fixture()!
	stream_eval(mut vm, 'document.body.innerHTML="<form id=f action=/save></form>"')!
	element := host.document.get_element_by_id('f') or { panic('Missing native form') }
	mut model := html.HTMLFormElementModel.create(unsafe { &dom.HTMLFormElement(element) })
	mut calls := []int{len: 1}
	callback := fn [mut calls] (_ html.FormSubmission) ! { calls[0]++ }
	model.set_submission_hook(callback)
	defer { model.set_submission_hook(none); platform.release_closure(voidptr(callback)) }
	stream_eval(mut vm, 'document.getElementById("f").submit()')!
	assert calls[0] == 1 && model.has_submission_hook() && record.submissions.len == 0
	host.close()
	assert host.form_submission_host == none
}

fn test_cached_native_form_properties_revisit_without_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-native-form-actions-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut host, mut vm := text_encoding_fixture()!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert stream_eval(mut vm, 'function configure(form){form.action="/save";form.method="POST";return form.action+":"+form.method}var form=document.createElement("form");configure(form)==="https://libjs-encoding.test/save:post"')!.as_bool()
		activity := vm.diagnose_native_code(false)!; stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits >= 1 && stats.compiler_invocations == 0 && activity.entries >= 1 }
		vm.close_native_code()!
		host.close()
	}
}
