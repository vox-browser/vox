// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

fn comparison_methods(names []string) []string {
 mut result:=[]string{}
 for typ in ['float','int','uint','bool'] {
  for size in 2..5 {
   for name,op in {'equal':'==','notEqual':'!=','lessThan':'<','lessThanEqual':'<=','greaterThan':'>','greaterThanEqual':'>='} {
    if name !in names {continue}
    if typ=='bool' && name !in ['equal','notEqual'] {continue}
    result << 'bool${size} _vox_${name}(${typ}${size} a, ${typ}${size} b) {return a ${op} b;}'
   }
  }
 }
 if 'not' in names {for size in 2..5 {result << 'bool${size} _vox_not(bool${size} value) {return !value;}'}}
 return result
}
