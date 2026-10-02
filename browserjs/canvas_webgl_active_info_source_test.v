// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import html

fn test_actual_active_info_records_follow_source_name_capacity_and_invalid_index_result() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<canvas></canvas>')
	mut host := CanvasWebGLHost.create(document)
	mut runtime := Runtime.create()
	defer { runtime.close() }
	host.install(mut runtime)!
	runtime.evaluate_host('const __canvases=Object.create(null);function __canvasFor(s){return __canvases[s.bridgeKey]||(__canvases[s.bridgeKey]={state:s});}function __canvasDimension(s,key){return s[key];}function __element(s){return {state:s};}')!
	runtime.evaluate_host(webgl_bootstrap())!
	result := runtime.evaluate_host(r'
 (function(){const gl=__webglContext({bridgeKey:"__created_active_source",width:2,height:2},"webgl2",null),other=__webglContext({bridgeKey:"__created_active_other",width:2,height:2},"webgl2",null),attribute="position_"+"a".repeat(300),uniform="tint_"+"b".repeat(300),vertex=gl.createShader(gl.VERTEX_SHADER),fragment=gl.createShader(gl.FRAGMENT_SHADER),program=gl.createProgram();
 gl.shaderSource(vertex,"#version 300 es\nin vec2 "+attribute+";void main(){gl_Position=vec4("+attribute+",0,1);}");gl.shaderSource(fragment,"#version 300 es\nprecision mediump float;uniform vec4 "+uniform+";out vec4 color;void main(){color="+uniform+";}");gl.compileShader(vertex);gl.compileShader(fragment);gl.attachShader(program,vertex);gl.attachShader(program,fragment);gl.linkProgram(program);
 if(!gl.getProgramParameter(program,gl.LINK_STATUS))return false;
 const attrib=gl.getActiveAttrib(program,0),active=gl.getActiveUniform(program,0);
 if(!(attrib instanceof WebGLActiveInfo)||!(active instanceof WebGLActiveInfo)||attrib.name!==attribute.slice(0,255)||active.name!==uniform.slice(0,255)||attrib.type!==gl.FLOAT_VEC2||active.type!==gl.FLOAT_VEC4||attrib.size!==1||active.size!==1||gl.getError()!==gl.NO_ERROR)return false;
 const invalidAttrib=gl.getActiveAttrib(program,1),attribError=gl.getError(),invalidUniform=gl.getActiveUniform(program,1),uniformError=gl.getError();
 if(!(invalidAttrib instanceof WebGLActiveInfo)||!(invalidUniform instanceof WebGLActiveInfo)||invalidAttrib===invalidUniform||invalidAttrib.name!==""||invalidAttrib.size!==0||invalidAttrib.type!==0||invalidUniform.name!==""||invalidUniform.size!==0||invalidUniform.type!==0||attribError!==gl.INVALID_VALUE||uniformError!==gl.INVALID_VALUE)return false;
 return other.getActiveAttrib(program,0)===null&&other.getError()===other.INVALID_OPERATION&&other.getActiveUniform(program,0)===null&&other.getError()===other.INVALID_OPERATION&&other.getError()===other.NO_ERROR&&gl.getError()===gl.NO_ERROR;
 })()
 ')!
	assert result == 'true'
}
