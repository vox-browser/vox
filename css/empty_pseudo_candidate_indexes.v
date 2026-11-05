module css

import dom
import os

const retain_empty_pseudo_candidate_lookups = os.getenv('VOX_RETAIN_EMPTY_PSEUDO_CANDIDATE_LOOKUPS') != ''
const empty_pseudo_candidate_diagnostics = os.getenv('VOX_EMPTY_PSEUDO_CANDIDATE_DIAGNOSTICS') != ''

__global empty_pseudo_candidate_reported bool

// Read the current index sizes on every query: a cache can gain or lose rules
// after an earlier empty result. Only metadata reads for empty indexes vanish;
// candidate order, mutable rule hints and full selector matching stay intact.
fn report_empty_pseudo_candidate_indexes(cache &RuleCache, element &dom.Element) {
	if empty_pseudo_candidate_diagnostics && !empty_pseudo_candidate_reported
		&& !retain_empty_pseudo_candidate_lookups && cache.rules_by_class.len == 0
		&& element.classes.len > 0 {
		empty_pseudo_candidate_reported = true
		eprintln('Vox pseudo candidates: skipped class lookups for an empty index')
	}
}
