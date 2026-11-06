module renderbackend

import os

fn test_process_environment_selects_the_default_and_legacy_override() {
	keys := ['VOX_USE_SKIA', 'VOX_GG_TEXT', 'VOX_GG_SHAPES', 'VOX_GG_PATHS']
	previous := keys.map(os.getenv(it))
	defer {
		for i, key in keys {
			if previous[i] == '' {
				os.unsetenv(key)
			} else {
				os.setenv(key, previous[i], true)
			}
		}
	}
	for key in keys {
		os.unsetenv(key)
	}
	default_selection := from_environment()
	assert default_selection.text && default_selection.shapes && default_selection.paths
	for key in keys {
		os.setenv(key, '1', true)
	}
	legacy := from_environment()
	assert !legacy.text && !legacy.shapes && !legacy.paths
}

fn test_gg_is_the_default_without_environment_switches() {
	selected := select('', '', '', '')
	assert selected.text && selected.shapes && selected.paths
}

fn test_explicit_legacy_request_overrides_every_adapter_combination() {
	for text in ['', '0', '1'] {
		for shapes in ['', '0', '1'] {
			for paths in ['', '0', '1'] {
				selected := select('1', text, shapes, paths)
				assert !selected.text && !selected.shapes && !selected.paths
			}
		}
	}
}

fn test_differential_checks_can_isolate_adapters() {
	text := select('0', '1', '0', '0')
	assert text.text && !text.shapes && !text.paths
	shapes := select('', '0', '', '0')
	assert !shapes.text && shapes.shapes && !shapes.paths
	paths := select('', '0', '0', '1')
	assert !paths.text && !paths.shapes && paths.paths
}
