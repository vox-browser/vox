module platform

#include "@DIR/layout_font_policy.h"

fn C.vox_layout_font_policy_cached() i32
fn C.vox_layout_font_policy_push(i32)
fn C.vox_layout_font_policy_pop()

pub struct LayoutFontPolicyScope {
mut:
	active bool
}

// Font-test configuration is an embedder setting, not a document mutation.
// Snapshot it only for synchronous layout, including nested layout work. Each
// new outer pass observes environment changes and newly created/deleted files.
// Unscoped font queries retain their live policy checks.
pub fn begin_layout_font_policy_scope() LayoutFontPolicyScope {
	configured := layout_test_font_is_configured()
	C.vox_layout_font_policy_push(if configured { 1 } else { 0 })
	return LayoutFontPolicyScope{active: true}
}

pub fn (mut scope LayoutFontPolicyScope) finish() {
	if scope.active {
		C.vox_layout_font_policy_pop()
		scope.active = false
	}
}
