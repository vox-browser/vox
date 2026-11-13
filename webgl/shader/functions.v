// Copyright (c) 2026, Vox contributors
// SPDX-License-Identifier: BSD-2-Clause
module shader

fn function_signature(function ShaderFunction, structures map[string]ShaderStruct) !string {
 return_type:=if function.typ in structures {'_vox_Struct_'+function.typ} else {metal_type(function.typ)!}
 mut parameters:=[]string{}
 mut setup:=[]string{}
 for i,parameter in function.parameters {
  if parameter.name=='' {return error('Function definition needs parameter names')}
  typ:=if parameter.typ in structures {'_vox_Struct_'+parameter.typ} else if parameter.typ.contains('sampler') {sampler_type(parameter.typ)!} else {metal_type(parameter.typ)!}
  value_type:=if parameter.array_length>0 {'array<${typ}, ${parameter.array_length}>'} else {typ}
  if parameter.direction in ['out','inout'] {
   if parameter.typ.contains('sampler') {return error('Sampler parameters must be inputs')}
   parameters << 'thread ${value_type}& _vox_destination${i}'
   initial:=if parameter.direction=='inout' {'_vox_destination${i}'} else {'${value_type}{}'}
   setup << '_vox_CopyOut<${value_type}> _vox_copy${i}(_vox_destination${i},${initial}); thread ${value_type}& ${parameter.name}=_vox_copy${i}.value;'
  } else if parameter.array_length>0 {
   // ESSL input arrays are passed by value; mutations stay local to the callee.
   parameters << '${value_type} ${parameter.name}'
  } else {parameters << '${typ} ${parameter.name}'}
 }
 name:=if function.name=='main' {'run'} else if texture_call(function.name,300) || texture_call(function.name,100) {'_vox_'+function.name} else {function.name}
 return '${return_type} ${name}(${parameters.join(', ')})'+if setup.len>0 {'\n'+setup.join('\n')} else {''}
}

fn copy_out_source() string {
 return 'template<typename T> struct _vox_CopyOut { thread T& destination; T value; _vox_CopyOut(thread T& d,T v):destination(d),value(v){} ~_vox_CopyOut(){destination=value;} };'
}
