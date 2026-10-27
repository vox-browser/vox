module main

import json2
import os
import platform

struct CaptureAuditStorageSample {
	text       string
	attributes map[string]string
	counts     []int
}

struct CaptureAuditStorageColdLeaf {
	label string
	count int
}

struct CaptureAuditStorageColdSample {
	leaf  ?CaptureAuditStorageColdLeaf
	items []CaptureAuditStorageColdLeaf
}

fn test_capture_audit_first_encoding_does_not_publish_retired_struct_metadata() {
	path := os.join_path(os.temp_dir(), 'vox-audit-cold-storage-${os.getpid()}.json')
	defer { os.rm(path) or {} }
	leaf := CaptureAuditStorageColdLeaf{ label: '日本語😀', count: 17 }
	sample := CaptureAuditStorageColdSample{ leaf: leaf, items: [leaf] }
	// Do not warm json2's generic struct cache before the temporary encoding.
	write_capture_audit_json(path, sample)!
	reuse := platform.begin_thread_scratch('reuse first capture audit encoding')
	_ = []u8{len: 128 * 1024, init: 0xa5}
	reuse.finish()
	expected := json2.encode(sample, escape_unicode: true)
	assert json2.decode[json2.Any](os.read_file(path)!)! == json2.decode[json2.Any](expected)!
	write_capture_audit_json(path, CaptureAuditStorageColdSample{})!
	assert json2.decode[json2.Any](os.read_file(path)!)! == json2.decode[json2.Any](json2.encode(CaptureAuditStorageColdSample{}))!
}

fn test_capture_audit_encoding_retires_buffers_and_preserves_snapshot_and_output() {
	path := os.join_path(os.temp_dir(), 'vox-audit-storage-${os.getpid()}.json')
	defer { os.rm(path) or {} }
	sample := CaptureAuditStorageSample{
		text:       '日本語😀 retained audit text'.repeat(4096)
		attributes: {
			'data-label': 'Первый'
			'quoted':     'a"b\\c\n'
		}
		counts:     [1, 2, 3]
	}
	expected := json2.encode(sample, escape_unicode: true)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 3 { write_capture_audit_json(path, sample)! }
	after := platform.thread_arena_usage().used
	$if prealloc {
		assert after - before < 4096
	}
	reuse := platform.begin_thread_scratch('reuse capture audit encoding')
	_ = []u8{len: expected.len * 2, init: 0xa5}
	reuse.finish()
	assert json2.decode[json2.Any](os.read_file(path)!)! == json2.decode[json2.Any](expected)!
	decoded := json2.decode[CaptureAuditStorageSample](os.read_file(path)!)!
	assert decoded.text == sample.text
	assert decoded.attributes == sample.attributes
	assert decoded.counts == sample.counts
	assert sample.text.starts_with('日本語😀 retained audit text')
}

fn test_capture_audit_encoding_owns_write_error_after_workspace_retirement() {
	missing := os.join_path(os.temp_dir(), 'vox-audit-missing-${os.getpid()}', 'audit.json')
	assert !os.exists(os.dir(missing))
	sample := CaptureAuditStorageSample{ text: 'unwritten audit' }
	mut failed := false
	write_capture_audit_json(missing, sample) or {
		failed = true
		expected_message := err.msg().clone()
		expected_code := err.code()
		reuse := platform.begin_thread_scratch('reuse capture audit error')
		_ = []u8{len: 256 * 1024, init: 0xa5}
		reuse.finish()
		assert expected_message != ''
		assert err.msg() == expected_message
		assert err.code() == expected_code
	}
	assert failed, 'writing under a missing directory succeeded'
}
