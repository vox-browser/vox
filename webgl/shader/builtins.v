// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

fn mapped_builtin(name string) bool {
 return name in ['mod','inversesqrt','atan','matrixCompMult','outerProduct','determinant','inverse','floatBitsToInt','floatBitsToUint','intBitsToFloat','uintBitsToFloat','roundEven','modf','frexp','mix','packUnorm2x16','packSnorm2x16','packHalf2x16','unpackUnorm2x16','unpackSnorm2x16','unpackHalf2x16']
}

fn builtin_methods(tokens []string, version int) []string {
 mut result:=[]string{}
 for width in 1..5 {
  typ:=if width==1 {'float'} else {'float${width}'}
  integer:=if width==1 {'int'} else {'int${width}'}
  unsigned:=if width==1 {'uint'} else {'uint${width}'}
  boolean:=if width==1 {'bool'} else {'bool${width}'}
  if 'mod' in tokens {
   result << '${typ} _vox_mod(${typ} x,${typ} y){return x-y*floor(x/y);}'
   if width>1 {result << '${typ} _vox_mod(${typ} x,float y){return x-y*floor(x/y);}'}
  }
  if 'inversesqrt' in tokens {result << '${typ} _vox_inversesqrt(${typ} x){return rsqrt(x);}'}
  if 'atan' in tokens {
   result << '${typ} _vox_atan(${typ} x){return atan(x);}'
   result << '${typ} _vox_atan(${typ} y,${typ} x){return atan2(y,x);}'
  }
  if 'mix' in tokens {
   result << '${typ} _vox_mix(${typ} x,${typ} y,${typ} a){return mix(x,y,a);}'
   if width>1 {result << '${typ} _vox_mix(${typ} x,${typ} y,float a){return mix(x,y,a);}'}
   if version==300 {
    for value_type in [typ,integer,unsigned,boolean] {result << '${value_type} _vox_mix(${value_type} x,${value_type} y,${boolean} a){return select(x,y,a);}'}
   }
  }
  if version==300 {
   for conversion in [['floatBitsToInt',typ,integer],['floatBitsToUint',typ,unsigned],['intBitsToFloat',integer,typ],['uintBitsToFloat',unsigned,typ]] {
    name:=conversion[0];value_type:=conversion[1];converted:=conversion[2]
    if name in tokens {result << '${converted} _vox_${name}(${value_type} x){return as_type<${converted}>(x);}'}
   }
   if 'roundEven' in tokens {result << '${typ} _vox_roundEven(${typ} x){return rint(x);}'}
   if 'modf' in tokens {result << '${typ} _vox_modf(${typ} x,thread ${typ}& integral){integral=trunc(x);return copysign(abs(x-integral),x);}'}
   if 'frexp' in tokens {result << '${typ} _vox_frexp(${typ} x,thread ${integer}& exponent){return frexp(x,exponent);}'}
  }
 }
 if 'matrixCompMult' in tokens || (version==300 && 'outerProduct' in tokens) {
  for columns in 2..5 {for rows in 2..5 {
   if version==100 && columns!=rows {continue}
   typ:='float${columns}x${rows}'
   if 'matrixCompMult' in tokens {
    mut values:=[]string{}
    for c in 0..columns {values << 'a[${c}]*b[${c}]'}
    result << '${typ} _vox_matrixCompMult(${typ} a,${typ} b){return ${typ}(${values.join(',')});}'
   }
   if version==300 && 'outerProduct' in tokens {
    mut values:=[]string{}
    for c in 0..columns {values << 'c*r[${c}]'}
    result << '${typ} _vox_outerProduct(float${rows} c,float${columns} r){return ${typ}(${values.join(',')});}'
   }
  }}
 }
 if version==300 && ('determinant' in tokens || 'inverse' in tokens) {
  result << 'float _vox_determinant(float2x2 m){return m[0][0]*m[1][1]-m[1][0]*m[0][1];}'
  for n in 3..5 {
   mut terms:=[]string{}
   for column in 0..n {
    minor:=matrix_minor(n,column,0)
    terms << (if column%2==0 {''} else {'-'})+'m[${column}][0]*_vox_determinant(${minor})'
   }
   result << 'float _vox_determinant(float${n}x${n} m){return '+terms.join('+')+';}'
  }
  if 'inverse' in tokens {
   for n in 2..5 {
    mut columns:=[]string{}
    for column in 0..n {
     mut values:=[]string{}
     for row in 0..n {
      minor:=if n==2 {'m[${1-row}][${1-column}]'} else {'_vox_determinant(${matrix_minor(n,row,column)})'}
      values << (if (column+row)%2==0 {''} else {'-'})+minor+'/d'
     }
     columns << 'float${n}('+values.join(',')+')'
    }
    result << 'float${n}x${n} _vox_inverse(float${n}x${n} m){float d=_vox_determinant(m);return float${n}x${n}('+columns.join(',')+');}'
   }
  }
 }
 if version==300 {
  if 'packHalf2x16' in tokens {result << 'uint _vox_packHalf2x16(float2 v){return as_type<uint>(half2(v));}'}
  if 'unpackHalf2x16' in tokens {result << 'float2 _vox_unpackHalf2x16(uint v){return float2(as_type<half2>(v));}'}
  if 'packUnorm2x16' in tokens {result << 'uint _vox_packUnorm2x16(float2 v){uint2 p=uint2(round(clamp(v,0.0,1.0)*65535.0));return p.x|(p.y<<16);}'}
  if 'unpackUnorm2x16' in tokens {result << 'float2 _vox_unpackUnorm2x16(uint v){return float2(v&65535u,v>>16)/65535.0;}'}
  if 'packSnorm2x16' in tokens {result << 'uint _vox_packSnorm2x16(float2 v){int2 p=int2(round(clamp(v,-1.0,1.0)*32767.0));return (uint(p.x)&65535u)|(uint(p.y)<<16);}'}
  if 'unpackSnorm2x16' in tokens {result << 'float2 _vox_unpackSnorm2x16(uint v){return max(float2(int(v<<16)>>16,int(v)>>16)/32767.0,-1.0);}'}
 }
 return result
}

fn matrix_minor(n int, excluded_column int, excluded_row int) string {
 mut columns:=[]string{}
 for column in 0..n {
  if column==excluded_column {continue}
  mut values:=[]string{}
  for row in 0..n {if row!=excluded_row {values << 'm[${column}][${row}]'}}
  columns << 'float${n-1}('+values.join(',')+')'
 }
 return 'float${n-1}x${n-1}('+columns.join(',')+')'
}

fn equality_methods(structures []ShaderStruct) []string {
 mut result:=[]string{}
 for scalar in ['float','int','uint','bool'] {
  result << 'bool _vox_same(${scalar} a,${scalar} b){return a==b;}'
  for width in 2..5 {result << 'bool _vox_same(${scalar}${width} a,${scalar}${width} b){return all(a==b);}'}
 }
 for c in 2..5 {for r in 2..5 {
  mut terms:=[]string{}
  for column in 0..c {terms << '_vox_same(a[${column}],b[${column}])'}
  result << 'bool _vox_same(float${c}x${r} a,float${c}x${r} b){return '+terms.join('&&')+';}'
 }}
 result << 'template<typename T,size_t N> bool _vox_same(array<T,N> a,array<T,N> b){for(uint i=0;i<N;i++){if(!_vox_same(a[i],b[i]))return false;}return true;}'
 for definition in structures {
  mut terms:=[]string{}
  for field in definition.fields {terms << '_vox_same(a.${field.name},b.${field.name})'}
  result << 'bool _vox_same(_vox_Struct_${definition.name} a,_vox_Struct_${definition.name} b){return '+terms.join('&&')+';}'
 }
 return result
}
