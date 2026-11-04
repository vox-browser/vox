module css

import os

const retain_empty_deleted_conditional_targets = os.getenv('VOX_RETAIN_EMPTY_DELETED_CONDITIONAL_TARGETS') != ''
const empty_deleted_conditional_diagnostics = os.getenv('VOX_EMPTY_DELETED_CONDITIONAL_DIAGNOSTICS') != ''

__global empty_deleted_conditional_reported bool

// The caller has already excluded nested style rules and global registrations.
// Materialize deferred declarations before proving that this leaf contributes
// no ordinary or custom declaration. Rule-cache and CSSOM updates still run.
fn deleted_conditional_leaf_has_no_declarations(rule &CSSRule) bool {
	if retain_empty_deleted_conditional_targets { return false }
	declaration := rule.style() or { return false }
	if declaration.length() != 0 { return false }
	if empty_deleted_conditional_diagnostics && !empty_deleted_conditional_reported {
		if sheet := rule.parent_style_sheet {
			if document := sheet.owning_document() {
				empty_deleted_conditional_reported = true
				eprintln('Vox deleted conditional rule: skipped declaration-free leaf; document=${document.url.serialize()}')
			}
		}
	}
	return true
}
