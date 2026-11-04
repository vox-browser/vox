module css

import dom
import os

const retain_unevaluated_following_sheet = os.getenv('VOX_RETAIN_UNEVALUATED_FOLLOWING_SHEET') != ''
const fresh_following_sheet_diagnostics = os.getenv('VOX_FRESH_FOLLOWING_SHEET_DIAGNOSTICS') != ''

__global fresh_following_sheet_reported bool

fn following_media_query_texts_equal(left &MediaList, right &MediaList) bool {
	if left.media.len != right.media.len { return false }
	for i, entry in left.media {
		if entry.text != right.media[i].text { return false }
	}
	return true
}

// A newly parsed replacement has no match history. Evaluate a separate entry
// vector, preserving its cached matches, did_evaluate bits and sheet did_match.
// The removed sheet's cached result must still agree with the current viewport.
fn following_media_snapshot_matches(media &MediaList, document &dom.Document) bool {
	mut snapshot := MediaList{media: media.media.clone()}
	return snapshot.evaluate(document)
}

fn report_fresh_following_sheet_media(document &dom.Document) {
	if !fresh_following_sheet_diagnostics || fresh_following_sheet_reported { return }
	fresh_following_sheet_reported = true
	eprintln('Vox stylesheet removal: proved fresh following media snapshot; document=${document.url.serialize()}')
}
