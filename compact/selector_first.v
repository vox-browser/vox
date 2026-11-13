module main

import browserjs
import css
import dom
import os
import platform
import sync.stdatomic

const retain_compact_first_query = os.getenv('VOX_RETAIN_COMPACT_FIRST_QUERY') != ''
const compact_first_diagnostics = os.getenv('VOX_COMPACT_FIRST_DIAGNOSTICS') != ''
__global compact_first_reported stdatomic.AtomicVal[bool]

fn install_compact_first_query(binding &CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	if retain_compact_first_query { return }
	runtime.install_selector_first_query(fn [binding] (key string, selector string) !browserjs.SelectorMatchReply {
		mut owner := unsafe { &CompactElementQueryBinding(binding) }
		return owner.selector_first(key, selector)
	})!
}

fn (mut binding CompactElementQueryBinding) selector_first(key string, selector string) !browserjs.SelectorMatchReply {
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
	_ = validation.matches(owned_selector)!
	parent := unsafe { &dom.ParentNode(root) }
	matched := parent.query_selector(owned_selector) != none
	if !matched && compact_first_diagnostics && compact_first_reported.compare_and_swap(false, true) {
		eprintln('Vox selector first: absent native query without JSON transport')
	}
	return browserjs.SelectorMatchReply{handled: true, matched: matched}
}

fn compact_selector_first_bootstrap() string {
	if retain_compact_first_query { return '' }
	return r'
const __compactSelectorFirst=globalThis.__ladybirdSelectorFirst;
const __compactSelectorFirstFallback=__queryElements;
__queryElements=function(key,action,selector,raw){
 if(action==="querySelector"&&typeof __compactSelectorFirst==="function"&&typeof key==="string"&&typeof selector==="string"&&!__compactHasPendingDOMState()){
  try{if(__compactSelectorFirst(key,selector)===false)return null;}
  catch(error){throw __compactNativeError(error);}
 }
 return __compactSelectorFirstFallback(key,action,selector,raw);
};
'
}
