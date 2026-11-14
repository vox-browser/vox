// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

pub struct FeedbackField {
pub:
 name string
 offset int
 rows int
 columns int
 matrix_stride int
 scalar_type u32
}
struct FeedbackTranslation {
 source string
 fields []FeedbackField
 stride int
}

// Capture shader values before viewport Y/depth conversion. Records are tightly
// packed 32-bit scalars; matrices retain column-major order without std140 padding.
fn feedback_translation(prefix string, arguments []string, initialization []string, outputs []Interface) !FeedbackTranslation {
 mut fields := []FeedbackField{}
 mut stride := 0
 mut values := outputs.clone()
 values << Interface{name:'gl_Position',typ:'vec4',rows:4,columns:1}
 for field in values {
  scalar_type := if field.typ == 'int' || field.typ.starts_with('ivec') {u32(7)} else if field.typ == 'uint' || field.typ.starts_with('uvec') {u32(8)} else {u32(13)}
  fields << FeedbackField{name:field.name,offset:stride,rows:field.rows,columns:field.columns,matrix_stride:if field.columns>1 {field.rows*4} else {0},scalar_type:scalar_type}
  stride += field.rows*field.columns*4
 }
 mut args := arguments.clone()
 args << 'device uint* _vox_feedback [[buffer(13)]]'
 args << 'constant uint* _vox_capture_params [[buffer(14)]]'
 mut lines := [prefix,'vertex void vox_capture(${args.join(', ')}) {']
 lines << 'uint _vox_first = _vox_capture_params[0], _vox_count = _vox_capture_params[1], _vox_instance_first = _vox_capture_params[2], _vox_instances = _vox_capture_params[3], _vox_capacity = _vox_capture_params[4];'
 lines << 'if (vertex_id < _vox_first || vertex_id - _vox_first >= _vox_count || instance_id < _vox_instance_first || instance_id - _vox_instance_first >= _vox_instances) return;'
 // Division guards precede multiplication, including when a draw has no work.
 lines << 'if (_vox_count == 0u || _vox_instances == 0u || _vox_count > _vox_capacity / ${stride/4}u || _vox_instances > (_vox_capacity / ${stride/4}u) / _vox_count) return;'
 lines << 'uint _vox_base = ((instance_id - _vox_instance_first) * _vox_count + vertex_id - _vox_first) * ${stride/4}u;'
 lines << initialization
 lines << 'state.gl_VertexID = int(vertex_id); state.gl_InstanceID = int(instance_id - _vox_instance_first); state.run();'
 for field in fields {
  for column in 0..field.columns {
   for row in 0..field.rows {
    access := 'state.${field.name}'+if field.columns>1 {'[${column}]'} else {''}+if field.rows>1 {'[${row}]'} else {''}
    word := field.offset/4+column*field.rows+row
    lines << '_vox_feedback[_vox_base + ${word}u] = as_type<uint>(${access});'
   }
  }
 }
 lines << '}'
 return FeedbackTranslation{source:lines.join('\n'),fields:fields,stride:stride}
}
