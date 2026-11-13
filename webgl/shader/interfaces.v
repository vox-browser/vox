// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

struct LocationQualifier {
 location int
 end int
}

fn location_qualifier(tokens []string, start int) !LocationQualifier {
 if start+5 >= tokens.len || tokens[start+1] != '(' || tokens[start+2] != 'location' || tokens[start+3] != '=' { return error('Only layout(location=...) is supported here') }
 mut end := start+4
 mut depth := 0
 for end < tokens.len {
  if tokens[end] == ')' && depth == 0 { break }
  if tokens[end] == '(' { depth++ }
  if tokens[end] == ')' { depth-- }
  // Macro expansion has already run. Named const expressions need semantic
  // resolution and are deliberately rejected rather than treated as zero.
  if identifier(tokens[end]) { return error('Unresolved identifier in layout location') }
  end++
 }
 if end >= tokens.len || end == start+4 || end-start > 256 { return error('Invalid layout location expression') }
 mut parser := PPExpression{tokens:tokens[start+4..end]}
 value := parser.expression(0,true)!
 if parser.at != parser.tokens.len || value < 0 || value > 15 { return error('Layout location out of range') }
 return LocationQualifier{location:int(value),end:end+1}
}

fn interface_dimensions(typ string) (int,int) {
 if typ.starts_with('mat') { columns:=int(typ[3]-`0`); return if typ.len == 6 {int(typ[5]-`0`)} else {columns},columns }
 return if typ.contains('vec') {int(typ[typ.len-1]-`0`)} else {1},1
}

fn assign_interface_locations(fields []Interface, bindings map[string]int, limit int) ![]Interface {
 mut result := fields.clone()
 mut occupied := u32(0)
 // Reserve explicit and API-bound spans before assigning any automatic input.
 for i,field in result {
  location := if field.explicit_location {field.location} else {bindings[field.name] or {-1}}
  if location < 0 { continue }
  span := field.columns
  if location+span > limit { return error('Interface location span exceeds limit: ${field.name}') }
  mask := ((u32(1)<<u32(span))-1)<<u32(location)
  if occupied & mask != 0 { return error('Interface locations overlap: ${field.name}') }
  occupied |= mask
  result[i] = Interface{...field,location:location}
 }
 for i,field in result {
  if field.location >= 0 { continue }
  mut location := 0
  span := field.columns
  mask := (u32(1)<<u32(span))-1
  for location+span <= limit && occupied & (mask<<u32(location)) != 0 { location++ }
  if location+span > limit { return error('No contiguous interface locations for ${field.name}') }
  occupied |= mask<<u32(location)
  result[i] = Interface{...field,location:location}
 }
 return result
}

fn vertex_input_members(fields []Interface) ![]string {
 mut result := []string{}
 for field in fields {
  if field.columns == 1 { result << '${metal_type(field.typ)!} ${field.name} [[attribute(${field.location})]];' }
  else {
   for column in 0..field.columns { result << 'float${field.rows} _vox_attribute_${field.name}_${column} [[attribute(${field.location+column})]];' }
  }
 }
 return result
}

fn vertex_input_loads(fields []Interface) ![]string {
 mut result := []string{}
 for field in fields {
  if field.columns == 1 { result << 'state.${field.name} = input.${field.name};' }
  else {
   mut columns := []string{}
   for column in 0..field.columns { columns << 'input._vox_attribute_${field.name}_${column}' }
   result << 'state.${field.name} = ${metal_type(field.typ)!}(${columns.join(', ')});'
  }
 }
 return result
}
