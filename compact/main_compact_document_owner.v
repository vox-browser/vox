module main

import browserjs
import os
import sync.stdatomic

const retain_document_owner_query = os.getenv('VOX_RETAIN_DOCUMENT_OWNER_QUERY') != ''
const document_owner_diagnostics = os.getenv('VOX_DOCUMENT_OWNER_DIAGNOSTICS') != ''
__global document_owner_reported stdatomic.AtomicVal[bool]

fn install_compact_document_owner_query(binding &CompactElementQueryBinding, mut runtime browserjs.Runtime) ! {
	if retain_document_owner_query { return }
	runtime.install_document_owner_query(fn [binding] (key string) bool {
		return binding.has_root_document_owner(key)
	})!
}

fn (binding &CompactElementQueryBinding) has_root_document_owner(key string) bool {
	if key == '' { return false }
	// Read only already registered identities. The normal query handles lazy
	// nodes, foreign owners and any registration or document-storage writes.
	node := binding.nodes[key] or {
		element := binding.elements[key] or { return false }
		element.as_node()
	}
	if node.is_document() || voidptr(node.document()) != voidptr(binding.document) { return false }
	if document_owner_diagnostics && document_owner_reported.compare_and_swap(false, true) {
		eprintln('Vox document owner: read live root ownership without a JSON query')
	}
	return true
}

fn compact_document_owner_bootstrap() string {
	return r'
const __rootDocumentOwner=globalThis.__ladybirdRootDocumentOwner;
const __ownerDirtySize=Object.getOwnPropertyDescriptor(Set.prototype,"size").get;
function __compactOwnerDocument(object){
 const key=__compactNodeState(object).bridgeKey;
 if(typeof __rootDocumentOwner==="function"&&typeof key==="string"&&!__state.operations.length&&__elementApply(__ownerDirtySize,__dirtyElementStates,[])===0&&__rootDocumentOwner(key)===true)return document;
 return __queryElements(key,"ownerDocument","");
}'
}
