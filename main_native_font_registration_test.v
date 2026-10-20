module main

import platform

fn test_native_font_registration_cache_outlives_replay_scratch() {
	$if !macos {
		return
	}
	previous := native_registered_system_faces.clone()
	native_registered_system_faces = map[string]bool{}
	defer { native_registered_system_faces = previous.clone() }
	font := &platform.Font{
		family:                'SystemUi'
		point_size:            16
		font_rendering_policy: .chromium
	}
	face := font.system_face() or { panic('missing system font') }
	mut expected_key := 'vox-system-face:${face.path}#${face.face_index}|${face.postscript_name}'
	for axis in face.variations {
		expected_key += '|${axis.tag}=${axis.value}'
	}
	mut scratch := platform.new_arena('font registration replay')
	defer { scratch.release() }
	entry := scratch.enter()
	path := native_replay_font_path(font)
	scratch.leave(entry)
	assert expected_key in native_registered_system_faces
	expected_path := if native_registered_system_faces[expected_key] {
		expected_key
	} else {
		face.path
	}
	assert path == expected_path
	$if prealloc {
		for key, _ in native_registered_system_faces {
			assert !scratch.contains(key.str)
		}
	}
	scratch.reset()
	for _ in 0 .. 3 {
		next := scratch.enter()
		cached := native_replay_font_path(font)
		scratch.leave(next)
		assert cached == expected_path
		assert expected_key in native_registered_system_faces
		scratch.reset()
	}
}

fn test_failed_native_font_registrations_survive_replay_and_cache_growth() {
	$if !macos {
		return
	}
	previous := native_registered_system_faces.clone()
	native_registered_system_faces = map[string]bool{}
	defer { native_registered_system_faces = previous.clone() }
	mut scratch := platform.new_arena('failed font registration replay')
	defer { scratch.release() }
	for index in 0 .. 32 {
		font := &platform.Font{
			system_face_override: platform.SystemFontFace{
				path:            '/missing/replay-font-${index}.ttf'
				postscript_name: 'MissingReplayFace'
			}
		}
		entry := scratch.enter()
		path := native_replay_font_path(font)
		scratch.leave(entry)
		assert path == '/missing/replay-font-${index}.ttf'
		scratch.reset()
		assert native_registered_system_faces.len == index + 1
		for key, registered in native_registered_system_faces {
			assert key.starts_with('vox-system-face:/missing/replay-font-')
			assert !registered
		}
	}
}
