module platform

// Opt-in instrumentation for identifying base-arena growth in prealloc builds.
@[inline]
pub fn arena_phase_begin() i64 {
	$if vox_phase_diagnostics ? {
		$if prealloc {
			return thread_arena_usage().used
		}
	}
	return 0
}

@[inline]
pub fn arena_phase_end(label string, before i64) {
	$if vox_phase_diagnostics ? {
		$if prealloc {
			after := thread_arena_usage().used
			eprintln('PHASE ${label} ${(after - before) / 1024} KB total ${after / 1048576} MB')
		}
	}
}
