module css

import os
import sync.stdatomic

const disable_font_rule_presence = os.getenv('VOX_DISABLE_FONT_RULE_PRESENCE') != ''
const font_rule_presence_diagnostics = os.getenv('VOX_FONT_RULE_PRESENCE_DIAGNOSTICS') != ''
__global font_rule_presence_reported bool

// Structural presence ignores conditions: a media/supports change can activate
// an existing face without changing this proof. Imports remain possible before
// their sheet has loaded. The shared rule-structure epoch also covers mutations
// of detached or nested lists which have no parent link.
fn (mut list CSSRuleList) may_contain_font_rules() bool {
	generation := stdatomic.load_u64(&media_rule_structure_generation)
	if list.font_presence_generation_ == generation { return list.font_presence_ }
	mut present := false
	for rule in list.rules {
		if rule.type_ in [.font_face, .font_feature_values, .import_rule] { present = true; break }
		if mut children := rule.rules {
			if children.may_contain_font_rules() { present = true; break }
		}
	}
	list.font_presence_ = present
	list.font_presence_generation_ = generation
	return present
}

fn report_font_rule_presence_skip() {
	if font_rule_presence_diagnostics && !font_rule_presence_reported {
		font_rule_presence_reported = true
		eprintln('Vox font rules: skipped synchronization for a sheet without possible font faces')
	}
}
