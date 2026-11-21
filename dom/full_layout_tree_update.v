module dom

// Request a complete rebuild of the document's layout tree: no box of the
// committed tree is kept or updated in place. With
// VOX_DOCUMENT_LAYOUT_DIAGNOSTICS each first request before the rebuild is
// reported with its reason.
pub fn (mut d Document) request_full_layout_tree_update(reason string) {
	if document_layout_diagnostics && !d.needs_full_layout_tree_update {
		eprintln('VOX_FULL_LAYOUT_TREE_UPDATE reason=${reason}')
	}
	d.set_needs_full_layout_tree_update(true)
}
