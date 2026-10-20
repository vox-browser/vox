module layout

import dom
import platform

__global (
	document_geometry_depth    int
	geometry_measurement_depth int
)

struct DocumentGeometryScope {
mut:
	scratch &platform.ThreadScratchScope = unsafe { nil }
}

fn begin_document_geometry_scratch(document &dom.Document) DocumentGeometryScope {
	$if prealloc {
		if document.native_storage() != unsafe { nil }
			&& platform.current_retained_arena() != unsafe { nil } {
			document_geometry_depth++
			return DocumentGeometryScope{ scratch: platform.begin_thread_scratch('document geometry') }
		}
	}
	return DocumentGeometryScope{}
}

fn (mut scope DocumentGeometryScope) finish() {
	if scope.scratch == unsafe { nil } { return }
	scope.scratch.finish()
	document_geometry_depth--
	scope.scratch = unsafe { nil }
}

// Algorithm workspaces retire at the geometry boundary; published geometry
// still belongs to the document. Intrinsic probes keep their independent,
// shorter lifetime even when nested in an ordinary layout calculation.
fn retain_geometry_allocations() platform.RetainedAllocationScope {
	$if prealloc {
		if document_geometry_depth > 0 && geometry_measurement_depth == 0 {
			return platform.enter_retained_allocations()
		}
	}
	return platform.RetainedAllocationScope{}
}
