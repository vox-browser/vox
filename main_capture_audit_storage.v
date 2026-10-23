module main

import json2
import os
import platform

// The snapshot remains owned by its caller. Encoding and synchronous file I/O
// publish no V allocations, so their growing buffers can retire together.
fn write_capture_audit_json[T](path string, audit T) ! {
	scratch := platform.begin_thread_scratch('capture audit encoding')
	defer { scratch.finish() }
	os.write_file(path, json2.encode(audit, escape_unicode: true)) or {
		// The OS error can also belong to the workspace. Copy it after restoring
		// the caller's allocation target and before retiring the temporary bytes.
		scratch.leave()
		return error_with_code(err.msg().clone(), err.code())
	}
}
