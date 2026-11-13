// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

fn varying_members(fields []Interface) ![]string {
 mut result := []string{}
 for field in fields {
  interpolation := if field.flat {', flat'} else {''}
  if field.columns == 1 { result << '${metal_type(field.typ)!} ${field.name} [[user(v_${field.name})${interpolation}]];' }
  else {
   for column in 0..field.columns {
    result << 'float${field.rows} _vox_varying_${field.name}_${column} [[user(v_${field.name}_${column})${interpolation}]];'
   }
  }
 }
 return result
}

fn varying_loads(fields []Interface) ![]string {
 mut result := []string{}
 for field in fields {
  if field.columns == 1 { result << 'state.${field.name} = input.${field.name};' }
  else {
   mut columns := []string{}
   for column in 0..field.columns { columns << 'input._vox_varying_${field.name}_${column}' }
   result << 'state.${field.name} = ${metal_type(field.typ)!}(${columns.join(', ')});'
  }
 }
 return result
}

fn varying_stores(fields []Interface) []string {
 mut result := []string{}
 for field in fields {
  if field.columns == 1 { result << 'result.${field.name} = state.${field.name};' }
  else { for column in 0..field.columns { result << 'result._vox_varying_${field.name}_${column} = state.${field.name}[${column}];' } }
 }
 return result
}
