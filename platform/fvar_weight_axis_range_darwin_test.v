// vtest build: macos
module platform

import os
import time

// The wght axis range read from the 'fvar' table matches CoreText's own
// answer, and the system UI font no longer asks CoreText for its axes.
fn test_weight_axis_range_from_the_fvar_table_matches_coretext() {
	$if macos {
		directory := os.join_path(os.temp_dir(), 'vox-fvar-range-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(directory) or { panic(err) }
		defer { os.rmdir_all(directory) or {} }
		binary := os.join_path(directory, 'fvar-range')
		fixture := os.join_path(@VMODROOT, 'platform/fixtures/fvar_weight_axis_range.c')
		compiled := os.exec(['clang', '-std=c11', '-framework', 'CoreText', '-framework',
			'CoreFoundation', fixture, '-o', binary])
		assert compiled.exit_code == 0, compiled.output
		for environment in ['X=1', 'VOX_DISABLE_FVAR_WEIGHT_AXIS_RANGE=1'] {
			result := os.exec(['env', environment, binary])
			assert result.exit_code == 0, result.output
		}
	}
}
