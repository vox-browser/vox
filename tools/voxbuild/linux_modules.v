module main

import crypto.sha256
import os

fn staging_word_character(c u8) bool {
	return c.is_alnum() || c == `_`
}

fn staging_pointer_casts(source string) string {
	mut text := source
	marker := 'u64(usize(voidptr('
	mut offset := 0
	for offset < text.len {
		start := text.index_after(marker, offset) or { break }
		end := text.index_after(')))', start + marker.len) or { break }
		inside := text[start + marker.len..end]
		if !inside.contains('(') && !inside.contains(')') {
			replacement := 'u64(voidptr(' + inside + '))'
			text = text[..start] + replacement + text[end + 3..]
			offset = start + replacement.len
		} else {
			offset = start + marker.len
		}
	}
	mut result := ''
	offset = 0
	mut previous := 0
	for offset < text.len {
		start := text.index_after('usize(', offset) or { break }
		offset = start + 6
		if start == 0 || !staging_word_character(text[start - 1]) {
			result += text[previous..start] + 'uint('
			previous = offset
		}
	}
	return result + text[previous..]
}

fn condition_private_helpers(source string, names []string, condition string) !string {
	mut text := source
	for name in names {
		prefix := 'fn ${name}('
		mut offset := 0
		for offset < text.len {
			start := text.index_after(prefix, offset) or { break }
			offset = start + prefix.len
			if start > 0 && text[start - 1] != `\n` {
				continue
			}
			line_end := text.index_after('\n', start) or { text.len }
			if !text[start..line_end].contains('{') {
				continue
			}
			closing := text.index_after('\n}', start) or { continue }
			function := text[start..closing + 2]
			replacement := r'$if ' + condition + ' {\n\t' + function.replace('\n', '\n\t') + '\n}'
			text = text[..start] + replacement + text[closing + 2..]
			offset = start + replacement.len
		}
	}
	return text
}

fn staging_openssl_pointer_copy(source string) string {
	mut result := ''
	mut offset := 0
	mut search := 0
	for search < source.len {
		start := source.index_after('unsafe {\n', search) or { break }
		search = start + 'unsafe {\n'.len
		mut line_start := start
		for line_start > offset && source[line_start - 1] != `\n` {
			line_start--
		}
		if source[line_start..start].trim_space() != '' {
			continue
		}
		// The old multiline expression included adjacent blank lines in \s*.
		for line_start > offset {
			mut previous := line_start - 1
			for previous > offset && source[previous - 1] != `\n` {
				previous--
			}
			if source[previous..line_start].trim_space() != '' {
				break
			}
			line_start = previous
		}
		mut statement := search
		for statement < source.len && source[statement].is_space() {
			statement++
		}
		marker := 'mut ptr_base := bytes\n'
		if !source[statement..].starts_with(marker) {
			continue
		}
		indent := source[line_start..start]
		result += source[offset..line_start] + indent + 'mut ptr_base := unsafe { bytes }\n' + indent + 'unsafe {\n'
		offset = statement + marker.len
		search = offset
	}
	return result + source[offset..]
}

fn patch_linux_module(package string, source string) !string {
	mut text := source
	if package == 'stbi' {
		text = text.replace('import os\n', r'$if windows && clang {' + '\n\timport os\n}\n')
	}
	if package in ['gg', 'net/openssl'] {
		text = staging_pointer_casts(text)
	}
	if package == 'gg' {
		text = text.replace('\tdesc := sapp.create_desc()\n',
			'\tmut desc := sapp.create_desc()\n\tif desc.sampler_pool_size < desc.image_pool_size {\n\t\tdesc.sampler_pool_size = desc.image_pool_size\n\t}\n')
		text = remove_unused_private_helper(text, 'gg_fail_fn')!
		text = condition_private_helpers(text, ['gg_poison_gfx_render_owner'], 'gg_multiwindow ? || test')!
		mut lines := text.split('\n')
		for index, line in lines {
			if line.starts_with('const err_multiwindow_render_') && line.contains(' = ') {
				name := line['const '.len..].all_before(' = ')
				if name != 'err_multiwindow_render_device_lost' && name.len > 'err_multiwindow_render_'.len && name.bytes().all(staging_word_character(it)) && line.all_after(' = ').len > 0 {
					lines[index] = r'$if gg_multiwindow ? || test {' + '\n\t' + line + '\n}'
				}
			}
		}
		text = lines.join('\n')
		recorder_helpers := ['screenshot_stdout_payload', 'emit_recorded_frame_to_stdout',
			'new_gg_recorder_settings', 'parse_screenshot_frames', 'parse_screenshot_output',
			'recorder_env_value', 'new_gg_recorder_settings_from_env']
		mut has_recorder := false
		for name in recorder_helpers {
			if text.contains('fn ' + name + '(') {
				has_recorder = true
			}
		}
		if has_recorder {
			text = condition_private_helpers(text, recorder_helpers, 'gg_record ? || test')!
			lines = text.split('\n')
			for index, line in lines {
				if line.starts_with('import ') {
					name := line['import '.len..]
					if name.len > 0 && name.bytes().all(staging_word_character(it) || it == `.`) {
						lines[index] = r'$if gg_record ? || test {' + '\n\t' + line + '\n}'
					}
				}
			}
			text = lines.join('\n')
		}
		lines = text.split('\n')
		for index, line in lines {
			if (line.starts_with('const recorder_settings = ') || line.starts_with('const gg_record_stdout_prefix = ')) && line.all_after(' = ').len > 0 {
				lines[index] = r'$if gg_record ? || test {' + '\n\t' + line + '\n}'
			}
		}
		text = lines.join('\n')
	}
	if package == 'net/openssl' {
		text = staging_openssl_pointer_copy(text)
	}
	return text
}

fn staging_fontstash_assignments(source string) (string, int) {
	lines := source.split('\n')
	mut output := []string{}
	mut count := 0
	mut index := 0
	for index < lines.len {
		line := lines[index]
		indent := line.len - line.trim_left('\t').len
		if indent > 0 && line[indent..] == 'params.renderUpdate = fons_render_update' && index + 1 < lines.len && lines[index + 1] == line[..indent] + 'params.renderDraw = fons_render_draw' {
			output << line[..indent] + 'C.vox_gg_fontstash_callbacks(&params)'
			count++
			index += 2
		} else {
			output << line
			index++
		}
	}
	return output.join('\n'), count
}

fn patch_fontstash_callbacks(source string) !string {
	declarations := {
		'fn fons_render_update(uptr voidptr, rect &i32, data &u8) {':                             "@[export: 'vox_gg_fontstash_render_update']"
		'fn fons_render_draw(uptr voidptr, verts &f32, tcoords &f32, colors &u32, nverts i32) {': "@[export: 'vox_gg_fontstash_render_draw']"
	}
	marker := '#include "@DIR/vox_fontstash_callbacks.h"'
	mut text, count := staging_fontstash_assignments(source)
	if source.contains(marker) {
		if source.count(marker) != 1 || source.count('C.vox_gg_fontstash_callbacks(&params)') != 2 || count != 0 {
			return error('Incomplete GG Fontstash callback adapter')
		}
		for annotation in declarations.values() {
			if source.count(annotation) != 1 {
				return error('Incomplete GG Fontstash callback adapter')
			}
		}
		return source
	}
	if source.count('module gg\n') != 1 {
		return error('Unsupported GG Fontstash callback signatures')
	}
	for signature in declarations.keys() {
		if source.count(signature) != 1 {
			return error('Unsupported GG Fontstash callback signatures')
		}
	}
	if count != 2 {
		return error('Expected two GG Fontstash callback assignments, found ${count}')
	}
	for signature, annotation in declarations {
		text = text.replace_once(signature, annotation + '\n' + signature)
	}
	return text.replace_once('module gg\n', 'module gg\n\n' + marker + '\n') + '\nfn C.vox_gg_fontstash_callbacks(params &C.FONSparams)\n'
}

fn stage_linux_module(repo string, source string, target string, package string) ! {
	if os.is_link(target) {
		os.rm(target)!
	}
	make_directory(target)!
	mut expected := map[string]bool{}
	mut fontstash_adapter := false
	for path in staging_tree_paths(source)! {
		if !os.is_file(path) || path.ends_with('_test.v') {
			continue
		}
		relative := path[source.len + 1..]
		expected[relative] = true
		destination := os.join_path(target, relative)
		mut parent := target
		parts := relative.split(os.path_separator)
		for part in parts[..parts.len - 1] {
			parent = os.join_path(parent, part)
			if os.is_link(parent) {
				os.rm(parent)!
			}
			make_directory(parent)!
		}
		if path.ends_with('.v') {
			mut text := patch_linux_module(package, os.read_file(path)!)!
			if package == 'gg' && relative == 'text_rendering.c.v' {
				text = patch_fontstash_callbacks(text)!
				fontstash_adapter = true
			}
			write_if_changed(destination, text)!
		} else if !os.is_link(destination) || os.real_path(destination) != os.real_path(path) {
			if os.exists(destination) || os.is_link(destination) {
				os.rm(destination)!
			}
			os.symlink(os.real_path(path), destination)!
		}
	}
	if fontstash_adapter {
		header := 'vox_fontstash_callbacks.h'
		expected[header] = true
		write_if_changed(os.join_path(target, header), os.read_file(os.join_path(repo, 'tools/linux_fontstash_callbacks.h'))!)!
	}
	mut stale := staging_tree_paths(target)!
	stale.sort(a > b)
	for path in stale {
		if os.is_dir(path) && !os.is_link(path) {
			if os.ls(path)!.len == 0 {
				os.rmdir(path)!
			}
		} else if path[target.len + 1..] !in expected {
			os.rm(path)!
		}
	}
}

fn prepare_linux_modules(repo string, compiler string) !string {
	work := os.join_path(repo, 'Build/linux/native')
	make_directory(work)!
	vlib := compiler_vlib(compiler, work)!
	cc := os.getenv_opt('CC') or { 'cc' }
	modules := os.join_path(repo, 'Build/linux/modules')
	for package_info in [['stbi', 'stb_image', 'stbi'], ['json', 'cJSON', 'cJSON']] {
		package, directory, name := package_info[0], package_info[1], package_info[2]
		thirdparty := os.join_path(os.dir(vlib), 'thirdparty', directory)
		if !os.is_dir(os.join_path(vlib, package)) || !os.is_file(os.join_path(thirdparty, name + '.c')) {
			os.rmdir_all(os.join_path(modules, package)) or {}
			continue
		}
		mut digest := sha256.new()
		digest.write(capture_command([cc, '--version'])!.bytes())!
		digest.write(os.read_bytes(os.join_path(repo, 'tools/voxbuild/linux_modules.v'))!)!
		mut headers := []string{}
		for entry in os.ls(thirdparty)! {
			if entry.ends_with('.h') {
				headers << os.join_path(thirdparty, entry)
			}
		}
		headers.sort()
		headers << os.join_path(thirdparty, name + '.c')
		for path in headers {
			digest.write(os.read_bytes(path)!)!
		}
		hash := digest.sum([]u8{}).hex()
		archive := os.join_path(work, name + '.a')
		stamp := os.join_path(work, name + '.sha256')
		if !os.is_file(archive) || !os.is_file(stamp) || os.read_file(stamp)! != hash {
			object_file := os.join_path(work, name + '.o')
			run_command([cc, '-O2', '-fPIC', '-c', os.join_path(thirdparty, name + '.c'), '-o',
				object_file])!
			run_command(['ar', 'rcs', archive, object_file])!
			os.write_file(stamp, hash)!
		}
		source_root := os.join_path(vlib, package)
		for source in staging_tree_paths(source_root)! {
			if !os.is_file(source) || !source.ends_with('.v') || source.ends_with('_test.v') {
				continue
			}
			text := patch_linux_module(package, os.read_file(source)!)!.replace('#flag @VEXEROOT/thirdparty/${directory}/${name}.o', '#flag ${archive}')
			target := os.join_path(modules, package, source[source_root.len + 1..])
			make_directory(os.dir(target))!
			write_if_changed(target, text)!
		}
	}
	for package in ['gg', 'net/openssl'] {
		stage_linux_module(repo, os.join_path(vlib, package), os.join_path(modules, package), package)!
	}
	return modules
}
