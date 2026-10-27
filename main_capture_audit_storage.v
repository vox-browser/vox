module main

import json2
import os
import platform

fn capture_audit_optional_value[T](value ?T) T {
	return value or { T{} }
}

// Audit DTOs contain plain fields only. Encode their reflection as JSON values:
// json2's struct encoder otherwise publishes its first-use field cache from
// inside this temporary arena, leaving later encodes with retired metadata.
fn capture_audit_json_value[T](value T) json2.Any {
	$if T is $option {
		if value == none { return json2.null }
		return capture_audit_json_value(capture_audit_optional_value(value))
	} $else $if T is $struct {
		mut fields := map[string]json2.Any{}
		$for field in T.fields {
			$if field.typ is $option {
				if value.$(field.name) != none {
					fields[field.name] = capture_audit_json_value(capture_audit_optional_value(value.$(field.name)))
				}
			} $else {
				fields[field.name] = capture_audit_json_value(value.$(field.name))
			}
		}
		return fields
	} $else $if T is $array || T is $array_fixed {
		mut items := []json2.Any{cap: value.len}
		for item in value { items << capture_audit_json_value(item) }
		return items
	} $else $if T is $map {
		mut fields := map[string]json2.Any{}
		for key, item in value { fields[key] = capture_audit_json_value(item) }
		return fields
	} $else {
		return json2.Any(value)
	}
}

// The snapshot remains owned by its caller; encoding publishes no V allocations.
fn write_capture_audit_json[T](path string, audit T) ! {
	scratch := platform.begin_thread_scratch('capture audit encoding')
	defer { scratch.finish() }
	os.write_file(path, json2.encode(capture_audit_json_value(audit), escape_unicode: true)) or {
		// The OS error can also belong to the workspace. Copy it after restoring
		// the caller's allocation target and before retiring the temporary bytes.
		scratch.leave()
		return error_with_code(err.msg().clone(), err.code())
	}
}
