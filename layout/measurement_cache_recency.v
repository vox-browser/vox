module layout

import dom
import os

const retain_fifo_measurement_eviction = os.getenv('VOX_RETAIN_FIFO_MEASUREMENT_EVICTION') != ''
const measurement_recency_diagnostics = os.getenv('VOX_MEASUREMENT_RECENCY_DIAGNOSTICS') != ''

__global measurement_recency_reported_document dom.UniqueNodeID

// The shared pool owns these four-entry vectors. Refresh a successful probe's
// position without changing its payload, capacity or validation. Final layout
// does not change the disposable probes' eviction order.
fn retain_recent_measurement[T](mut entries []&T, index int, root &Node) {
	if retain_fifo_measurement_eviction || index < 0 || index >= entries.len - 1 { return }
	entry := entries[index]
	for slot in index .. entries.len - 1 { entries[slot] = entries[slot + 1] }
	entries[entries.len - 1] = entry
	if measurement_recency_diagnostics {
		document := root.document()
		identity := document.as_node().unique_id()
		if measurement_recency_reported_document != identity {
			measurement_recency_reported_document = identity
			eprintln('Vox measurement cache: kept a reused question in four entries; document=${document.url.serialize()}')
		}
	}
}
