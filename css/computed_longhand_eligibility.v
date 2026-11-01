module css

import os

const disable_longhand_eligibility_first = os.getenv('VOX_DISABLE_LONGHAND_ELIGIBILITY_FIRST') != ''
const longhand_eligibility_diagnostics = os.getenv('VOX_LONGHAND_ELIGIBILITY_DIAGNOSTICS') != ''
__global longhand_eligibility_rejection_reported bool

fn report_longhand_eligibility_rejection() {
	if longhand_eligibility_diagnostics && !longhand_eligibility_rejection_reported {
		longhand_eligibility_rejection_reported = true
		eprintln('Vox longhand eligibility: rejected cascade before inherited hashing')
	}
}
