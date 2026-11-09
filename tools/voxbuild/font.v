module main

import crypto.sha256
import json2
import os
import time

struct FontRuntimeIdentity {
	compiler string
	vlib     string
	sha256   string
	files    map[string]string
}

fn widen_short_loca_offsets(source string) !string {
	entries := ['offset = tf.get_u16() << 1', 'next = tf.get_u16() << 1']
	mut counts := []int{}
	for entry in entries {
		counts << source.count(entry)
	}
	if counts == [0, 0] {
		return source
	}
	if counts != [1, 1] {
		return error('Unsupported x.ttf loca reader: expected one offset and one next entry')
	}
	mut text := source
	for entry in entries {
		text = text.replace(entry, entry.replace('tf.get_u16() << 1', 'u32(tf.get_u16()) << 1'))
	}
	return text
}

fn glyph_index_initializer(source string) !string {
	_, opening, closing := staging_function_range(source, 'pub fn (mut tf TTF_File) init()') or {
		return error('Unsupported x.ttf initializer: expected one explicit cmap-table read')
	}
	mut body := source[opening + 1..closing]
	if body.count('tf.read_cmap_table()') != 1 || body.count('tf.read_offset_tables()') != 1 {
		return error('Unsupported x.ttf initializer: expected one explicit cmap-table read')
	}
	body = body.replace('tf.read_cmap_table()', '// Unicode lookup belongs to the caller.')
	body = body.replace('tf.read_offset_tables()', 'tf.read_normalized_offset_tables()')
	_, tables_start, tables_end := staging_function_range(source, 'fn (mut tf TTF_File) read_offset_tables()') or {
		return error('Unsupported x.ttf directory: expected one table-checksum assertion')
	}
	tables := source[tables_start + 1..tables_end]
	lines := tables.split('\n')
	mut directory := []string{}
	mut count := 0
	mut index := 0
	for index < lines.len {
		if index + 2 < lines.len && lines[index].trim_left('\t ') == "if tag != 'head' {"
			&& lines[index + 1].trim_left('\t ') == 'assert tf.calc_checksum(tf.tables[tag].offset, tf.tables[tag].length) == tf.tables[tag].checksum' && lines[index + 2].trim_left('\t ') == '}' {
			count++
			index += 3
		} else {
			directory << lines[index]
			index++
		}
	}
	if count != 1 || tables.count('tf.calc_checksum(') != 1 {
		return error('Unsupported x.ttf directory: expected one table-checksum assertion')
	}
	return 'module ttf\n\n' +
		'// For bounds-checked sfnt buffers normalized by decode_outline_face().\n' +
		'// Preserve metadata, outlines and kerning; omit dense Unicode caches\n' +
		'// and the immediate recheck of the checksums the caller just computed.\n' +
		'pub fn (mut tf TTF_File) init_for_glyph_indices() {' + body + '}\n\n' +
		'fn (mut tf TTF_File) read_normalized_offset_tables() {' + directory.join('\n') + '}\n'
}

fn staging_write_font_file(path string, data []u8) ! {
	make_directory(os.dir(path))!
	if os.is_file(path) && os.read_bytes(path)! == data {
		return
	}
	temporary := make_temp_directory(os.dir(path), '.font-write-')!
	defer { os.rmdir_all(temporary) or {} }
	file := os.join_path(temporary, 'data')
	os.write_file(file, data.bytestr())!
	os.chmod(file, 0o600)!
	os.rename(file, path)!
}

fn prepare_font(repo string, compiler string) !string {
	probe_work := make_temp_directory(os.temp_dir(), 'vox-font-root-')!
	defer { os.rmdir_all(probe_work) or {} }
	vlib := compiler_vlib(compiler, probe_work)!
	source := os.join_path(vlib, 'x/ttf')
	if !os.is_file(os.join_path(source, 'ttf.v')) {
		return error('The active V library has no x.ttf reader')
	}
	mut inputs := map[string][]u8{}
	for path in staging_tree_paths(source)! {
		if os.is_file(path) {
			inputs[path[source.len + 1..].replace(os.path_separator, '/')] = os.read_bytes(path)!
		}
	}
	inputs['ttf.v'] = widen_short_loca_offsets(inputs['ttf.v'].bytestr())!.bytes()
	inputs['vox_glyph_index_init.v'] = glyph_index_initializer(inputs['ttf.v'].bytestr())!.bytes()
	mut digest := sha256.new()
	digest.write(os.read_bytes(os.join_path(repo, 'tools/voxbuild/font.v'))!)!
	mut hashes := map[string]string{}
	mut names := inputs.keys()
	names.sort()
	for name in names {
		data := inputs[name]
		digest.write(name.bytes())!
		digest.write([u8(0)])!
		digest.write(data)!
		hashes[name] = sha256.sum(data).hex()
	}
	hash := digest.sum([]u8{}).hex()
	identity := FontRuntimeIdentity{ compiler: os.real_path(compiler), vlib: vlib, sha256: hash, files: hashes }
	root := os.join_path(repo, 'Build/v/font-runtime', hash)
	manifest := os.join_path(root, 'manifest.json')
	if os.is_file(manifest) {
		recorded := json2.decode[FontRuntimeIdentity](os.read_file(manifest)!)!
		if recorded.compiler == identity.compiler && recorded.vlib == identity.vlib && recorded.sha256 == identity.sha256 && staging_same_hashes(recorded.files, identity.files) {
			now := time.now().unix()
			os.utime(root, now, now)!
			return root
		}
	}
	for name, data in inputs {
		staging_write_font_file(os.join_path(root, 'x/ttf', name), data)!
	}
	atomic_write_json_text(manifest, json2.encode(identity, prettify: true) + '\n')!
	return root
}
