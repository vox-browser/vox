module main

import browserjs
import html

fn navigation_cache_walk_script() string {
	return '(()=>{const seen=[];for(let node=document.getElementById("host").firstChild;node;node=node.nextSibling)seen.push(node.nodeType===1?node.id:node.data);return seen.join(",");})()'
}

// React's hydration walks server text, comments and elements with firstChild
// and nextSibling. Text and comment nodes reuse their answers like elements
// while the tree is unchanged, and any tree edit, made by script or natively,
// invalidates them.
fn test_compact_node_navigation_reuses_answers_until_the_tree_changes() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="host">one<b id="bold">two</b>three<!--c--></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://github.com/vlang/v', [
		r'
const walk=()=>{const seen=[];for(let node=host.firstChild;node;node=node.nextSibling)seen.push(node.nodeType===1?node.id:node.data);return seen.join(",");};
const first=host.firstChild;
const before=walk();
const cache=first.__state.__navigation;
const again=walk();
host.insertBefore(document.createTextNode("zero"),first);
const inserted=walk();
globalThis.result=[before,again,inserted,!!cache&&Object.prototype.hasOwnProperty.call(cache.values,"nextSibling"),
	first.__state.__navigation!==cache,typeof globalThis.__ladybirdTreeVersionCell].join("|");
',
	], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'one,bold,three,c|one,bold,three,c|zero,one,bold,three,c|true|true|undefined'
	// A native edit the facade did not make changes the version it reads.
	host := document.get_element_by_id('host') or { panic('missing host') }
	mut host_node := host.as_node()
	host_node.append_child(document.create_text_node('native').as_node()) or { panic(err) }
	assert runtime.evaluate_host(navigation_cache_walk_script())! == 'zero,one,bold,three,c,native'
	mut bold := document.get_element_by_id('bold') or { panic('missing bold') }
	mut bold_node := bold.as_node()
	bold_node.remove(false)
	assert runtime.evaluate_host(navigation_cache_walk_script())! == 'zero,one,three,c,native'
	assert messages == []string{}
}

// A walk along a parent's children (firstChild, then nextSibling) asks the
// native DOM once: the first navigation fetches the children and records the
// siblings of each.
fn test_compact_first_navigation_prefetches_the_children_a_walk_needs() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><div id="host">a<b id="b1">x</b>c<!--d--><i id="i1"></i>e</div><div id="empty"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	before := compact_navigation_query_counts
	run_document_javascript(document, 'https://github.com/vlang/v', [
		r'
const seen=[];for(let node=host.firstChild;node;node=node.nextSibling)seen.push(node.nodeType===1?node.id:node.data);
const back=[];for(let node=host.lastChild;node;node=node.previousSibling)back.push(node.nodeType===1?node.id:node.data);
globalThis.result=[seen.join(","),back.join(","),empty.firstChild===null,empty.lastChild===null,
	host.firstChild===host.firstChild].join("|");
',
	], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'a,b1,c,d,i1,e|e,i1,d,c,b1,a|true|true|true'
	// One child list for each parent; no navigation asked separately.
	assert compact_navigation_query_counts[1] - before[1] == 2
	assert compact_navigation_query_counts[0] - before[0] == 0
	assert messages == []string{}
}
