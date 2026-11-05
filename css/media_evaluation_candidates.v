module css

import os
import platform
import sync.stdatomic

const disable_media_rule_candidates = os.getenv('VOX_DISABLE_MEDIA_RULE_CANDIDATES') != ''
const media_rule_candidate_diagnostics = os.getenv('VOX_MEDIA_RULE_CANDIDATE_DIAGNOSTICS') != ''

__global media_rule_structure_generation u64 = 1
__global media_rule_candidate_reported bool

fn invalidate_media_evaluation_candidates() {
	// Use one structural epoch so detached and shared grouping lists do not need
	// parent links to invalidate an ancestor's summary. Match results aren't cached.
	stdatomic.add_u64(&media_rule_structure_generation, 1)
}

fn (mut rule_list CSSRuleList) media_evaluation_candidates() []&CSSRule {
	if disable_media_rule_candidates { return rule_list.rules }
	generation := stdatomic.load_u64(&media_rule_structure_generation)
	if generation == rule_list.media_evaluation_generation_ {
		return rule_list.media_evaluation_candidates_
	}
	// Publish beyond a caller's scratch scope. UA summaries also outlive document
	// arenas; author summaries use the current retained owner, like rule kind data.
	process_lifetime := if sheet := rule_list.owner_style_sheet {
		sheet.process_lifetime
	} else { false }
	use_persistent := process_lifetime || platform.current_retained_arena() == unsafe { nil }
	persistent := platform.enter_persistent_if(use_persistent)
	mut retained := if use_persistent { platform.RetainedAllocationScope{} }
		else { platform.enter_retained_allocations() }
	defer {
		retained.finish()
		platform.leave_persistent(persistent)
	}
	// Reuse the buffer across revisions, including for process-lifetime UA lists.
	// Clear old references so removed subtrees aren't kept alive in spare capacity.
	for i in 0 .. rule_list.media_evaluation_candidates_.len {
		rule_list.media_evaluation_candidates_[i] = unsafe { nil }
	}
	rule_list.media_evaluation_candidates_.clear()
	rule_list.media_evaluation_flattened_groups_ = false
	for rule in rule_list.rules {
		match rule.type_ {
			.media, .import_rule {
				// Keep imports even before loading: the imported sheet can arrive later.
				rule_list.media_evaluation_candidates_ << rule
			}
			.container_rule, .function_rule, .layer_block, .scope, .style {
				if mut children := rule.rules {
					child_candidates := children.media_evaluation_candidates()
					if child_candidates.len != 0 {
						if retain_media_group_recursion || child_candidates.len != 1 {
							rule_list.media_evaluation_candidates_ << rule
						} else {
							// Evaluation traverses these groups unconditionally.
							// Replace a one-candidate chain with its live descendant;
							// never expand a vector or copy a wider child summary.
							rule_list.media_evaluation_candidates_ << child_candidates[0]
							rule_list.media_evaluation_flattened_groups_ = true
						}
					}
				}
			}
			.supports {
				if mut children := rule.rules {
					// Preserve the live supports gate and its delayed first evaluation.
					if children.media_evaluation_candidates().len != 0 {
						rule_list.media_evaluation_candidates_ << rule
					}
				}
			}
			else {}
		}
	}
	rule_list.media_evaluation_generation_ = generation
	kept := rule_list.media_evaluation_candidates_.len
	if media_rule_candidate_diagnostics && !media_rule_candidate_reported
		&& rule_list.rules.len >= 100 && kept < rule_list.rules.len {
		media_rule_candidate_reported = true
		eprintln('Vox media candidates: total=${rule_list.rules.len} kept=${kept} pruned=${rule_list.rules.len - kept}')
	}
	return rule_list.media_evaluation_candidates_
}
