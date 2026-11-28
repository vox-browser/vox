// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

fn test_document_name_lookup_is_a_live_exact_html_name_nodelist() {
	mut host, mut vm, _ := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'var matches=document.getElementsByName("target"),a=document.createElement("input"),b=document.createElement("div"),svg=document.createElementNS("http://www.w3.org/2000/svg","svg");a.name="target";b.setAttribute("name","Target");svg.setAttribute("name","target");document.body.append(a,b,svg);var initial=matches instanceof NodeList&&matches.length===1&&matches[0]===a;b.setAttribute("name","target");a.remove();initial&&matches.length===1&&matches[0]===b&&document.getElementsByName("Target").length===0')!.as_bool()
	assert document_state_eval(mut vm, 'var empty=document.getElementsByName(""),node=document.createElement("a"),before=empty.length;node.setAttribute("name","");document.body.append(node);var added=empty.length===before+1;node.removeAttribute("name");added&&empty.length===before')!.as_bool()
}

fn test_document_name_lookup_checks_receiver_required_argument_and_conversion() {
	mut host, mut vm, _ := document_state_fixture()!
	defer { host.close() }
	assert document_state_eval(mut vm, 'var n=0,converted=0,arg={toString(){converted++;return "field"}};try{Document.prototype.getElementsByName.call({},arg)}catch(e){if(e instanceof TypeError)n++}try{document.getElementsByName()}catch(e){if(e instanceof TypeError)n++}var sentinel={};try{document.getElementsByName({toString(){throw sentinel}})}catch(e){if(e===sentinel)n++}n===3&&converted===0&&document.getElementsByName.length===1')!.as_bool()
}
