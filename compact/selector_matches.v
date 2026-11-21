module main

import browserjs
import css
import dom
import os
import platform
import sync.stdatomic

const retain_compact_matches_query = os.getenv('VOX_RETAIN_COMPACT_MATCHES_QUERY') != ''
// Same-binary control: tag name selectors also cross into native matching.
const retain_tag_matches_query = os.getenv('VOX_RETAIN_TAG_MATCHES_QUERY') != ''
const compact_matches_diagnostics = os.getenv('VOX_COMPACT_MATCHES_DIAGNOSTICS') != ''
__global compact_matches_reported stdatomic.AtomicVal[bool]

fn install_compact_matches_query(binding &CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	if retain_compact_matches_query { return }
	runtime.install_selector_match_query(fn [binding] (key string, selector string) !browserjs.SelectorMatchReply {
		mut owner := unsafe { &CompactElementQueryBinding(binding) }
		return owner.selector_matches(key, selector)
	})!
}

fn (mut binding CompactElementQueryBinding) selector_matches(key string, selector string) !browserjs.SelectorMatchReply {
	node := binding.nodes[key] or {
		element := binding.elements[key] or { return browserjs.SelectorMatchReply{} }
		element.as_node()
	}
	element := node.as_element() or { return browserjs.SelectorMatchReply{} }
	if voidptr(element.document()) != voidptr(binding.document) { return browserjs.SelectorMatchReply{} }
	mut scope := platform.RetainedArenaScope{}
	storage := binding.document.native_storage()
	if storage != unsafe { nil } { scope = storage.enter_nested() }
	persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent); scope.finish() }
	mut messages := []string{}
	settle_compact_dom_reactions(binding.document, binding.runtime, mut messages)!
	if messages.len != 0 { return error(messages.join('\n')) }
	css.install_document_selector_query_hook(binding.document)
	// Selector parsing may publish a cached AST. Its source must outlive the
	// value bridge's temporary argument buffers, just as in the JSON transport.
	matched := element.matches(selector.clone())!
	if compact_matches_diagnostics && compact_matches_reported.compare_and_swap(false, true) {
		eprintln('Vox selector matches: direct native boolean query')
	}
	return browserjs.SelectorMatchReply{handled: true, matched: matched}
}

// A selector that is one ASCII-lowercase type selector matches an element
// exactly when it equals the element's local name: HTML elements in HTML
// documents compare the lowercased selector with their local name, and other
// elements compare its own case. GitHub's lazy custom element loader asks
// node.matches(tag) for every added node and pending tag (~49,000 calls per
// load); the record answers without a native call.
fn compact_tag_matches_bootstrap() string {
	if retain_tag_matches_query { return '' }
	return r'
const __compactTagSelector=/^[a-z][a-z0-9_-]*$/;
const __compactTagMatchesFallback=__queryElements;
__queryElements=function(key,action,selector,raw){
 if(action==="matches"&&typeof key==="string"&&typeof selector==="string"&&__compactTagSelector.test(selector)){
  const record=__state.elements[key];
  const tag=record&&record.tagName;
  if(typeof tag==="string"&&tag.length!==0&&tag.charCodeAt(0)!==35){
   const colon=tag.indexOf(":");
   return (colon<0?tag:tag.slice(colon+1))===selector;
  }
 }
 return __compactTagMatchesFallback(key,action,selector,raw);
};
'
}

fn compact_selector_matches_bootstrap() string {
	if retain_compact_matches_query { return compact_tag_matches_bootstrap() }
	return r'
const __compactSelectorMatches=globalThis.__ladybirdSelectorMatches;
const __compactSelectorMatchesFallback=__queryElements;
__queryElements=function(key,action,selector,raw){
 if(action==="matches"&&typeof __compactSelectorMatches==="function"&&typeof key==="string"&&typeof selector==="string"&&!__compactHasPendingDOMState()){
  try{const result=__compactSelectorMatches(key,selector);if(result!==undefined)return result;}
  catch(error){throw __compactNativeError(error);}
 }
 return __compactSelectorMatchesFallback(key,action,selector,raw);
};
' + compact_tag_matches_bootstrap()
}
