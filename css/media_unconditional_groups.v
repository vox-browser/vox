module css

import os
import sync.stdatomic

const retain_media_group_recursion = os.getenv('VOX_RETAIN_MEDIA_GROUP_RECURSION') != ''
const media_group_evaluation_diagnostics = os.getenv('VOX_MEDIA_GROUP_EVALUATION_DIAGNOSTICS') != ''
__global media_group_evaluation_reported stdatomic.AtomicVal[bool]

fn report_media_group_evaluation(list &CSSRuleList) {
	if media_group_evaluation_diagnostics && !disable_media_rule_candidates
		&& !retain_media_group_recursion && list.media_evaluation_flattened_groups_
		&& media_group_evaluation_reported.compare_and_swap(false, true) {
		eprintln('Vox media evaluation: consumed flattened unconditional groups')
	}
}
