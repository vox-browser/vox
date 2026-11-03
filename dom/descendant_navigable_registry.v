module dom

import os

const retain_descendant_navigable_scan = os.getenv('VOX_RETAIN_DESCENDANT_NAVIGABLE_SCAN') != ''
const descendant_navigable_registry_diagnostics = os.getenv('VOX_DESCENDANT_NAVIGABLE_REGISTRY_DIAGNOSTICS') != ''

__global empty_descendant_navigables_reported_document UniqueNodeID

// as_navigable_container() discovers containers exclusively through this same
// registry. Without a container owned by this document its shadow-including
// traversal cannot find a first child navigable, or any nested descendants.
// A detached container is a conservative positive. Read live owner documents
// so adoption, registration and navigation need no additional invalidation.
fn (d &Document) may_have_registered_navigable_container() bool {
	for navigable in dom_all_navigables {
		if container := navigable.container() {
			if voidptr(container.document()) == voidptr(d) { return true }
		}
	}
	return false
}

fn report_empty_descendant_navigables(document &Document) {
	if !descendant_navigable_registry_diagnostics { return }
	identity := document.unique_id()
	if empty_descendant_navigables_reported_document != identity {
		empty_descendant_navigables_reported_document = identity
		eprintln('Vox descendant navigables: registry proves no owned containers; document=${document.url.serialize()}')
	}
}
