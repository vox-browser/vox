module main

import browserjs
import css
import dom
import os
import platform
import sync.stdatomic

const retain_compact_first_query = os.getenv('VOX_RETAIN_COMPACT_FIRST_QUERY') != ''
// Same-binary control: validate the selector by matching it against the root.
const retain_compact_first_validation_match = os.getenv('VOX_RETAIN_COMPACT_FIRST_VALIDATION_MATCH') != ''
const compact_first_diagnostics = os.getenv('VOX_COMPACT_FIRST_DIAGNOSTICS') != ''
__global compact_first_reported stdatomic.AtomicVal[bool]

// Same-binary control: ask the native DOM for every querySelector, without the
// facade's record of selectors that the local name history rules out.
const disable_selector_absence_cache = os.getenv('VOX_DISABLE_SELECTOR_ABSENCE_CACHE') != ''

fn install_compact_first_query(binding &CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	if retain_compact_first_query { return }
	runtime.install_selector_first_query(fn [binding] (key string, selector string) !browserjs.SelectorMatchReply {
		mut owner := unsafe { &CompactElementQueryBinding(binding) }
		return owner.selector_first(key, selector, false, false)
	})!
	if disable_selector_absence_cache || retain_tree_version_host_calls || retain_navigation_queries { return }
	runtime.install_selector_first_state_query(fn [binding] (key string, selector string, check_names bool) !browserjs.SelectorMatchReply {
		mut owner := unsafe { &CompactElementQueryBinding(binding) }
		return owner.selector_first(key, selector, true, check_names)
	})!
	mut document := unsafe { &dom.Document(binding.document) }
	runtime.install_native_word_view('__ladybirdLocalNameGenerationCell',
		voidptr(document.seen_element_local_name_generation_cell()), 2)!
}

// `state`: also report whether the root is the document or connected, and with
// `check_names`, whether the document's local name history proves the selector
// has no match below such a root. The facade reuses the first fact until the
// tree changes and the second until the history gains a name
// (compact_selector_first_bootstrap).
fn (mut binding CompactElementQueryBinding) selector_first(key string, selector string, state bool, check_names bool) !browserjs.SelectorMatchReply {
	root := if key == '' { binding.document.as_node() } else {
		// Host arguments are borrowed scratch strings. node_for_key() also
		// registers keys, which would publish this temporary buffer into the
		// retained identity map. Only probe owners already registered here.
		binding.nodes[key] or {
			element := binding.elements[key] or { return browserjs.SelectorMatchReply{} }
			element.as_node()
		}
	}
	if voidptr(root.document()) != voidptr(binding.document)
		|| (!root.is_element() && !root.is_document() && !root.is_document_fragment()) {
		return browserjs.SelectorMatchReply{}
	}
	mut scope := platform.RetainedArenaScope{}
	storage := binding.document.native_storage()
	if storage != unsafe { nil } { scope = storage.enter_nested() }
	persistent := platform.enter_persistent_if(storage == unsafe { nil } && platform.transient_arena_entered())
	defer { platform.leave_persistent(persistent); scope.finish() }
	mut messages := []string{}
	settle_compact_dom_reactions(binding.document, binding.runtime, mut messages)!
	if messages.len != 0 { return error(messages.join('\n')) }
	css.install_document_selector_query_hook(binding.document)
	validation := root.as_element() or {
		binding.document.document_element() or { return browserjs.SelectorMatchReply{} }
	}
	// Preserve SyntaxError even when the receiver has no descendants. Parsed
	// selectors may enter the document cache, beyond the argument scratch scope.
	owned_selector := selector.clone()
	if retain_compact_first_validation_match {
		_ = validation.matches(owned_selector)!
	} else {
		css.require_document_selector(binding.document, owned_selector)!
	}
	parent := unsafe { &dom.ParentNode(root) }
	matched := parent.query_selector(owned_selector) != none
	if !matched && compact_first_diagnostics && compact_first_reported.compare_and_swap(false, true) {
		eprintln('Vox selector first: absent native query without JSON transport')
	}
	if !state {
		return browserjs.SelectorMatchReply{handled: true, matched: matched}
	}
	// The verdict concerns the document, whichever root asked; the facade uses
	// it only for the document and roots it has seen connected.
	connected_root := root.is_document() || root.is_connected()
	absent := check_names && css.document_selector_absent_by_name_history(binding.document, owned_selector)
	return browserjs.SelectorMatchReply{
		handled:           true
		matched:           matched
		connected_root:    connected_root
		absent_by_names:   absent
		unproven_by_names: check_names && !absent
	}
}

fn compact_selector_first_bootstrap() string {
	if retain_compact_first_query { return '' }
	return r'
const __compactSelectorFirst=globalThis.__ladybirdSelectorFirst;
const __compactSelectorFirstFallback=__queryElements;
// The lazy custom element loader of GitHub asks every added node for every
// pending element name, which the document has never seen. Its local name
// history proves such a query empty below the document or any connected root
// (independent_query_tags_are_absent) until the history gains a name. Record
// that verdict per selector and history generation, and connected roots per
// tree version: one native query per root and per selector instead of one per
// pair, while no facade edit is pending.
const __compactSelectorFirstState=typeof globalThis.__ladybirdSelectorFirstState==="function"?globalThis.__ladybirdSelectorFirstState:null;
const __compactLocalNameWords=globalThis.__ladybirdLocalNameGenerationCell instanceof Uint32Array?globalThis.__ladybirdLocalNameGenerationCell:null;
if(__compactLocalNameWords!==null)delete globalThis.__ladybirdLocalNameGenerationCell;
const __compactNameFacts={names:-1,tree:-1,absent:new Set(),unproven:new Set(),roots:new Set()};
function __compactNameFactsCurrent(){
 if(__compactSelectorFirstState===null||__compactLocalNameWords===null||typeof __compactTreeVersion!=="function"||__compactTreeVersion===null)return false;
 const tree=__compactTreeVersion(),high=__compactLocalNameWords[1];
 if(tree<0||high>=2097152)return false;
 const names=__compactLocalNameWords[0]+high*4294967296,facts=__compactNameFacts;
 if(facts.names!==names){facts.names=names;facts.absent.clear();facts.unproven.clear();}
 if(facts.tree!==tree){facts.tree=tree;facts.roots.clear();}
 return true;
}
__queryElements=function(key,action,selector,raw){
 if(action==="querySelector"&&typeof __compactSelectorFirst==="function"&&typeof key==="string"&&typeof selector==="string"&&!__compactHasPendingDOMState()){
  if(__compactNameFactsCurrent()&&!__compactNameFacts.unproven.has(selector)){
   const facts=__compactNameFacts,absent=facts.absent.has(selector);
   if(absent&&(key===""||facts.roots.has(key)))return null;
   let bits;
   try{bits=__compactSelectorFirstState(key,selector,!absent);}
   catch(error){throw __compactNativeError(error);}
   if(typeof bits==="number"){
    // The query may have settled DOM reactions: record the facts against the
    // versions it left, unless a reaction left facade edits pending.
    if(!__compactHasPendingDOMState()&&__compactNameFactsCurrent()){
     if(bits&2)facts.roots.add(key);
     if(bits&4)facts.absent.add(selector);else if(bits&8)facts.unproven.add(selector);
    }
    if(!(bits&1))return null;
    return __compactSelectorFirstFallback(key,action,selector,raw);
   }
  }
  try{if(__compactSelectorFirst(key,selector)===false)return null;}
  catch(error){throw __compactNativeError(error);}
 }
 return __compactSelectorFirstFallback(key,action,selector,raw);
};
'
}
