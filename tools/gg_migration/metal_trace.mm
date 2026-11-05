// Records the Metal work issued by an unmodified GPU backend, so a gg port can
// reproduce the same shaders, pipeline state, buffers and draws exactly.
// Compile without ARC: every intercepted method forwards its original return
// value unchanged, preserving the caller's ownership conventions.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <objc/runtime.h>
#include "metal_trace.h"
#include <CommonCrypto/CommonDigest.h>
#include <cstdio>
#include <map>
#include <mutex>
#include <string>
#include <vector>

namespace {

std::recursive_mutex trace_mutex;
FILE* trace_file = nullptr;
// Pipelines and states are cached across cases; keep their definitions in one
// persistent file as well as in the trace that first created them.
FILE* definitions_file = nullptr;
std::string trace_directory;
std::string shader_directory;

struct LibraryInfo { std::string hash; };
struct FunctionInfo { std::string library_hash, name; };
struct PipelineInfo {
    unsigned id;
    std::string vertex, fragment;
    // Per buffer index: stride and step function (0 vertex, 1 instance, -1 none).
    std::map<unsigned, std::pair<unsigned, int>> layouts;
};
std::map<void const*, LibraryInfo> libraries;
std::map<void const*, FunctionInfo> functions;
std::map<void const*, PipelineInfo> pipelines;
std::map<void const*, unsigned> depth_states, samplers, textures, buffers;
unsigned next_pipeline = 1, next_depth = 1, next_sampler = 1, next_texture = 1, next_buffer = 1;

struct Binding { id buffer = nil; NSUInteger offset = 0; std::vector<uint8_t> bytes; bool inline_bytes = false; };
struct EncoderState {
    void const* pipeline = nullptr;
    std::map<NSUInteger, Binding> vertex, fragment;
};
std::map<void const*, EncoderState> encoders;

std::string sha256(void const* data, size_t size)
{
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data, CC_LONG(size), digest);
    char text[CC_SHA256_DIGEST_LENGTH * 2 + 1];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; ++i) std::snprintf(text + i * 2, 3, "%02x", digest[i]);
    return std::string(text, 16);
}

void emit(char const* format, ...) __attribute__((format(printf, 1, 2)));
void emit(char const* format, ...)
{
    if (!trace_file) return;
    va_list arguments;
    va_start(arguments, format);
    std::vfprintf(trace_file, format, arguments);
    va_end(arguments);
    std::fputc('\n', trace_file);
}

void define(char const* format, ...) __attribute__((format(printf, 1, 2)));
void define(char const* format, ...)
{
    for (FILE* file : {trace_file, definitions_file}) {
        if (!file) continue;
        va_list arguments;
        va_start(arguments, format);
        std::vfprintf(file, format, arguments);
        va_end(arguments);
        std::fputc('\n', file);
        std::fflush(file);
    }
}

std::string hex(uint8_t const* data, size_t size)
{
    static char const digits[] = "0123456789abcdef";
    std::string text;
    text.reserve(size * 2);
    for (size_t i = 0; i < size; ++i) {
        text.push_back(digits[data[i] >> 4]);
        text.push_back(digits[data[i] & 15]);
    }
    return text;
}

unsigned texture_id(id texture)
{
    if (!texture) return 0;
    auto found = textures.find((__bridge void const*)texture);
    if (found != textures.end()) return found->second;
    unsigned identifier = next_texture++;
    textures[(__bridge void const*)texture] = identifier;
    id<MTLTexture> t = texture;
    emit("texture id=%u format=%lu width=%lu height=%lu samples=%lu usage=%lu storage=%lu mipmaps=%lu",
        identifier, (unsigned long)t.pixelFormat, (unsigned long)t.width, (unsigned long)t.height,
        (unsigned long)t.sampleCount, (unsigned long)t.usage, (unsigned long)t.storageMode,
        (unsigned long)t.mipmapLevelCount);
    return identifier;
}

unsigned buffer_id(id buffer)
{
    if (!buffer) return 0;
    auto found = buffers.find((__bridge void const*)buffer);
    if (found != buffers.end()) return found->second;
    unsigned identifier = next_buffer++;
    buffers[(__bridge void const*)buffer] = identifier;
    return identifier;
}

template<typename T> T original(IMP imp) { return reinterpret_cast<T>(imp); }

#define HOOK(cls, selector_text, function, storage) do { \
    Method method = class_getInstanceMethod(cls, sel_registerName(selector_text)); \
    if (method) storage = method_setImplementation(method, (IMP)function); \
    else std::fprintf(stderr, "metal_trace: %s lacks %s\n", class_getName(cls), selector_text); \
} while (0)

// Device -------------------------------------------------------------------

IMP o_new_library;
id h_new_library(id self, SEL cmd, NSString* source, MTLCompileOptions* options, NSError** error)
{
    id result = original<id (*)(id, SEL, NSString*, MTLCompileOptions*, NSError**)>(o_new_library)(
        self, cmd, source, options, error);
    std::lock_guard lock(trace_mutex);
    char const* utf8 = source.UTF8String;
    std::string hash = sha256(utf8, std::strlen(utf8));
    if (!shader_directory.empty()) {
        std::string path = shader_directory + "/" + hash + ".metal";
        if (FILE* file = std::fopen(path.c_str(), "wx")) { std::fputs(utf8, file); std::fclose(file); }
    }
    if (result) libraries[(__bridge void const*)result] = {hash};
    define("library hash=%s fast_math=%d language=%lu ok=%d", hash.c_str(),
        options ? int(options.fastMathEnabled) : -1, options ? (unsigned long)options.languageVersion : 0UL,
        result != nil);
    return result;
}

IMP o_new_function;
id h_new_function(id self, SEL cmd, NSString* name)
{
    id result = original<id (*)(id, SEL, NSString*)>(o_new_function)(self, cmd, name);
    std::lock_guard lock(trace_mutex);
    auto library = libraries.find((__bridge void const*)self);
    if (result) functions[(__bridge void const*)result] = {
        library == libraries.end() ? "?" : library->second.hash, name.UTF8String};
    return result;
}

IMP o_new_function_constants;
id h_new_function_constants(id self, SEL cmd, NSString* name, MTLFunctionConstantValues* values, NSError** error)
{
    id result = original<id (*)(id, SEL, NSString*, MTLFunctionConstantValues*, NSError**)>(
        o_new_function_constants)(self, cmd, name, values, error);
    std::lock_guard lock(trace_mutex);
    auto library = libraries.find((__bridge void const*)self);
    if (result) functions[(__bridge void const*)result] = {
        library == libraries.end() ? "?" : library->second.hash, std::string(name.UTF8String) + "+constants"};
    return result;
}

std::string function_text(id function)
{
    if (!function) return "-";
    auto found = functions.find((__bridge void const*)function);
    if (found == functions.end()) return "unknown";
    return found->second.library_hash + ":" + found->second.name;
}

void record_pipeline(id result, MTLRenderPipelineDescriptor* descriptor)
{
    std::lock_guard lock(trace_mutex);
    PipelineInfo info;
    info.id = next_pipeline++;
    info.vertex = function_text(descriptor.vertexFunction);
    info.fragment = function_text(descriptor.fragmentFunction);
    define("pipeline id=%u vertex=%s fragment=%s samples=%lu depth=%lu stencil=%lu alpha_to_coverage=%d",
        info.id, info.vertex.c_str(), info.fragment.c_str(), (unsigned long)descriptor.rasterSampleCount,
        (unsigned long)descriptor.depthAttachmentPixelFormat, (unsigned long)descriptor.stencilAttachmentPixelFormat,
        int(descriptor.alphaToCoverageEnabled));
    auto* color = descriptor.colorAttachments[0];
    define("pipeline_color id=%u format=%lu blend=%d rgb=%lu,%lu,%lu alpha=%lu,%lu,%lu mask=%lu", info.id,
        (unsigned long)color.pixelFormat, int(color.blendingEnabled), (unsigned long)color.rgbBlendOperation,
        (unsigned long)color.sourceRGBBlendFactor, (unsigned long)color.destinationRGBBlendFactor,
        (unsigned long)color.alphaBlendOperation, (unsigned long)color.sourceAlphaBlendFactor,
        (unsigned long)color.destinationAlphaBlendFactor, (unsigned long)color.writeMask);
    MTLVertexDescriptor* vertex = descriptor.vertexDescriptor;
    for (NSUInteger i = 0; vertex && i < 31; ++i) {
        auto* attribute = vertex.attributes[i];
        if (attribute.format == MTLVertexFormatInvalid) continue;
        define("pipeline_attribute id=%u index=%lu format=%lu offset=%lu buffer=%lu", info.id,
            (unsigned long)i, (unsigned long)attribute.format, (unsigned long)attribute.offset,
            (unsigned long)attribute.bufferIndex);
    }
    for (NSUInteger i = 0; vertex && i < 31; ++i) {
        auto* layout = vertex.layouts[i];
        if (!layout.stride) continue;
        info.layouts[unsigned(i)] = {unsigned(layout.stride),
            layout.stepFunction == MTLVertexStepFunctionPerInstance ? 1 : 0};
        define("pipeline_layout id=%u buffer=%lu stride=%lu step=%lu rate=%lu", info.id, (unsigned long)i,
            (unsigned long)layout.stride, (unsigned long)layout.stepFunction, (unsigned long)layout.stepRate);
    }
    if (result) pipelines[(__bridge void const*)result] = info;
}

IMP o_new_pipeline;
id h_new_pipeline(id self, SEL cmd, MTLRenderPipelineDescriptor* descriptor, NSError** error)
{
    id result = original<id (*)(id, SEL, MTLRenderPipelineDescriptor*, NSError**)>(o_new_pipeline)(
        self, cmd, descriptor, error);
    record_pipeline(result, descriptor);
    return result;
}

IMP o_new_pipeline_reflection;
id h_new_pipeline_reflection(id self, SEL cmd, MTLRenderPipelineDescriptor* descriptor,
    MTLPipelineOption options, MTLAutoreleasedRenderPipelineReflection* reflection, NSError** error)
{
    id result = original<id (*)(id, SEL, MTLRenderPipelineDescriptor*, MTLPipelineOption,
        MTLAutoreleasedRenderPipelineReflection*, NSError**)>(o_new_pipeline_reflection)(
        self, cmd, descriptor, options, reflection, error);
    record_pipeline(result, descriptor);
    return result;
}

IMP o_new_pipeline_async;
void h_new_pipeline_async(id self, SEL cmd, MTLRenderPipelineDescriptor* descriptor,
    MTLNewRenderPipelineStateCompletionHandler handler)
{
    MTLRenderPipelineDescriptor* copy = [descriptor copy];
    MTLNewRenderPipelineStateCompletionHandler wrapped = ^(id<MTLRenderPipelineState> state, NSError* error) {
        record_pipeline(state, copy);
        [copy release];
        handler(state, error);
    };
    original<void (*)(id, SEL, MTLRenderPipelineDescriptor*, MTLNewRenderPipelineStateCompletionHandler)>(
        o_new_pipeline_async)(self, cmd, descriptor, wrapped);
}

char const* compare_name(MTLCompareFunction function)
{
    static char const* names[] = {"never", "less", "equal", "less_equal", "greater", "not_equal",
        "greater_equal", "always"};
    return function <= 7 ? names[function] : "?";
}

void stencil_text(char* text, size_t size, MTLStencilDescriptor* stencil)
{
    if (!stencil) { std::snprintf(text, size, "-"); return; }
    std::snprintf(text, size, "%s,fail=%lu,depth_fail=%lu,pass=%lu,read=%x,write=%x",
        compare_name(stencil.stencilCompareFunction), (unsigned long)stencil.stencilFailureOperation,
        (unsigned long)stencil.depthFailureOperation, (unsigned long)stencil.depthStencilPassOperation,
        stencil.readMask, stencil.writeMask);
}

IMP o_new_depth;
id h_new_depth(id self, SEL cmd, MTLDepthStencilDescriptor* descriptor)
{
    id result = original<id (*)(id, SEL, MTLDepthStencilDescriptor*)>(o_new_depth)(self, cmd, descriptor);
    std::lock_guard lock(trace_mutex);
    unsigned identifier = next_depth++;
    if (result) depth_states[(__bridge void const*)result] = identifier;
    char front[128], back[128];
    stencil_text(front, sizeof front, descriptor.frontFaceStencil);
    stencil_text(back, sizeof back, descriptor.backFaceStencil);
    define("depth_state id=%u compare=%s write=%d front=%s back=%s", identifier,
        compare_name(descriptor.depthCompareFunction), int(descriptor.depthWriteEnabled), front, back);
    return result;
}

IMP o_new_sampler;
id h_new_sampler(id self, SEL cmd, MTLSamplerDescriptor* descriptor)
{
    id result = original<id (*)(id, SEL, MTLSamplerDescriptor*)>(o_new_sampler)(self, cmd, descriptor);
    std::lock_guard lock(trace_mutex);
    unsigned identifier = next_sampler++;
    if (result) samplers[(__bridge void const*)result] = identifier;
    define("sampler id=%u min=%lu mag=%lu mip=%lu s=%lu t=%lu", identifier, (unsigned long)descriptor.minFilter,
        (unsigned long)descriptor.magFilter, (unsigned long)descriptor.mipFilter,
        (unsigned long)descriptor.sAddressMode, (unsigned long)descriptor.tAddressMode);
    return result;
}

// Command buffer ----------------------------------------------------------

void attachment_text(char const* kind, MTLRenderPassAttachmentDescriptor* attachment, char const* extra)
{
    if (!attachment.texture) return;
    unsigned texture = texture_id(attachment.texture);
    unsigned resolve = texture_id(attachment.resolveTexture);
    emit("pass_%s texture=%u resolve=%u load=%lu store=%lu%s", kind, texture, resolve,
        (unsigned long)attachment.loadAction, (unsigned long)attachment.storeAction, extra);
}

IMP o_render_encoder;
id h_render_encoder(id self, SEL cmd, MTLRenderPassDescriptor* descriptor)
{
    id result = original<id (*)(id, SEL, MTLRenderPassDescriptor*)>(o_render_encoder)(self, cmd, descriptor);
    std::lock_guard lock(trace_mutex);
    encoders[(__bridge void const*)result] = {};
    emit("render_pass begin");
    auto* color = descriptor.colorAttachments[0];
    char clear[160];
    std::snprintf(clear, sizeof clear, " clear=%.9g,%.9g,%.9g,%.9g", color.clearColor.red,
        color.clearColor.green, color.clearColor.blue, color.clearColor.alpha);
    attachment_text("color", color, clear);
    std::snprintf(clear, sizeof clear, " clear=%.9g", descriptor.depthAttachment.clearDepth);
    attachment_text("depth", descriptor.depthAttachment, clear);
    std::snprintf(clear, sizeof clear, " clear=%u", descriptor.stencilAttachment.clearStencil);
    attachment_text("stencil", descriptor.stencilAttachment, clear);
    return result;
}

IMP o_commit;
void h_commit(id self, SEL cmd)
{
    {
        std::lock_guard lock(trace_mutex);
        emit("commit");
    }
    original<void (*)(id, SEL)>(o_commit)(self, cmd);
}

// Render encoder -----------------------------------------------------------

EncoderState& encoder(id self) { return encoders[(__bridge void const*)self]; }

IMP o_set_pipeline;
void h_set_pipeline(id self, SEL cmd, id pipeline)
{
    {
        std::lock_guard lock(trace_mutex);
        encoder(self).pipeline = (__bridge void const*)pipeline;
        auto found = pipelines.find((__bridge void const*)pipeline);
        emit("set_pipeline id=%u", found == pipelines.end() ? 0 : found->second.id);
    }
    original<void (*)(id, SEL, id)>(o_set_pipeline)(self, cmd, pipeline);
}

IMP o_set_vertex_buffer, o_set_fragment_buffer;
void h_set_vertex_buffer(id self, SEL cmd, id buffer, NSUInteger offset, NSUInteger index)
{
    { std::lock_guard lock(trace_mutex); encoder(self).vertex[index] = {buffer, offset, {}, false}; }
    original<void (*)(id, SEL, id, NSUInteger, NSUInteger)>(o_set_vertex_buffer)(self, cmd, buffer, offset, index);
}
void h_set_fragment_buffer(id self, SEL cmd, id buffer, NSUInteger offset, NSUInteger index)
{
    { std::lock_guard lock(trace_mutex); encoder(self).fragment[index] = {buffer, offset, {}, false}; }
    original<void (*)(id, SEL, id, NSUInteger, NSUInteger)>(o_set_fragment_buffer)(self, cmd, buffer, offset, index);
}

IMP o_set_vertex_offset, o_set_fragment_offset;
void h_set_vertex_offset(id self, SEL cmd, NSUInteger offset, NSUInteger index)
{
    { std::lock_guard lock(trace_mutex); encoder(self).vertex[index].offset = offset; }
    original<void (*)(id, SEL, NSUInteger, NSUInteger)>(o_set_vertex_offset)(self, cmd, offset, index);
}
void h_set_fragment_offset(id self, SEL cmd, NSUInteger offset, NSUInteger index)
{
    { std::lock_guard lock(trace_mutex); encoder(self).fragment[index].offset = offset; }
    original<void (*)(id, SEL, NSUInteger, NSUInteger)>(o_set_fragment_offset)(self, cmd, offset, index);
}

IMP o_set_vertex_bytes, o_set_fragment_bytes;
void h_set_vertex_bytes(id self, SEL cmd, void const* bytes, NSUInteger length, NSUInteger index)
{
    {
        std::lock_guard lock(trace_mutex);
        auto& binding = encoder(self).vertex[index];
        binding = {};
        binding.inline_bytes = true;
        binding.bytes.assign(static_cast<uint8_t const*>(bytes), static_cast<uint8_t const*>(bytes) + length);
    }
    original<void (*)(id, SEL, void const*, NSUInteger, NSUInteger)>(o_set_vertex_bytes)(self, cmd, bytes, length, index);
}
void h_set_fragment_bytes(id self, SEL cmd, void const* bytes, NSUInteger length, NSUInteger index)
{
    {
        std::lock_guard lock(trace_mutex);
        auto& binding = encoder(self).fragment[index];
        binding = {};
        binding.inline_bytes = true;
        binding.bytes.assign(static_cast<uint8_t const*>(bytes), static_cast<uint8_t const*>(bytes) + length);
    }
    original<void (*)(id, SEL, void const*, NSUInteger, NSUInteger)>(o_set_fragment_bytes)(self, cmd, bytes, length, index);
}

IMP o_set_fragment_texture;
void h_set_fragment_texture(id self, SEL cmd, id texture, NSUInteger index)
{
    { std::lock_guard lock(trace_mutex); emit("fragment_texture index=%lu texture=%u", (unsigned long)index, texture_id(texture)); }
    original<void (*)(id, SEL, id, NSUInteger)>(o_set_fragment_texture)(self, cmd, texture, index);
}

IMP o_set_fragment_sampler;
void h_set_fragment_sampler(id self, SEL cmd, id sampler, NSUInteger index)
{
    {
        std::lock_guard lock(trace_mutex);
        auto found = samplers.find((__bridge void const*)sampler);
        emit("fragment_sampler index=%lu sampler=%u", (unsigned long)index, found == samplers.end() ? 0 : found->second);
    }
    original<void (*)(id, SEL, id, NSUInteger)>(o_set_fragment_sampler)(self, cmd, sampler, index);
}

IMP o_set_depth_state;
void h_set_depth_state(id self, SEL cmd, id state)
{
    {
        std::lock_guard lock(trace_mutex);
        auto found = depth_states.find((__bridge void const*)state);
        emit("set_depth_state id=%u", found == depth_states.end() ? 0 : found->second);
    }
    original<void (*)(id, SEL, id)>(o_set_depth_state)(self, cmd, state);
}

IMP o_set_stencil_reference;
void h_set_stencil_reference(id self, SEL cmd, uint32_t value)
{
    { std::lock_guard lock(trace_mutex); emit("stencil_reference value=%u", value); }
    original<void (*)(id, SEL, uint32_t)>(o_set_stencil_reference)(self, cmd, value);
}

IMP o_set_scissor;
void h_set_scissor(id self, SEL cmd, MTLScissorRect rect)
{
    { std::lock_guard lock(trace_mutex); emit("scissor x=%lu y=%lu width=%lu height=%lu", (unsigned long)rect.x,
        (unsigned long)rect.y, (unsigned long)rect.width, (unsigned long)rect.height); }
    original<void (*)(id, SEL, MTLScissorRect)>(o_set_scissor)(self, cmd, rect);
}

IMP o_set_viewport;
void h_set_viewport(id self, SEL cmd, MTLViewport viewport)
{
    { std::lock_guard lock(trace_mutex); emit("viewport x=%.9g y=%.9g width=%.9g height=%.9g near=%.9g far=%.9g",
        viewport.originX, viewport.originY, viewport.width, viewport.height, viewport.znear, viewport.zfar); }
    original<void (*)(id, SEL, MTLViewport)>(o_set_viewport)(self, cmd, viewport);
}

IMP o_set_cull, o_set_winding, o_set_fill;
void h_set_cull(id self, SEL cmd, MTLCullMode mode)
{
    { std::lock_guard lock(trace_mutex); emit("cull mode=%lu", (unsigned long)mode); }
    original<void (*)(id, SEL, MTLCullMode)>(o_set_cull)(self, cmd, mode);
}
void h_set_winding(id self, SEL cmd, MTLWinding winding)
{
    { std::lock_guard lock(trace_mutex); emit("winding value=%lu", (unsigned long)winding); }
    original<void (*)(id, SEL, MTLWinding)>(o_set_winding)(self, cmd, winding);
}
void h_set_fill(id self, SEL cmd, MTLTriangleFillMode mode)
{
    { std::lock_guard lock(trace_mutex); emit("fill_mode value=%lu", (unsigned long)mode); }
    original<void (*)(id, SEL, MTLTriangleFillMode)>(o_set_fill)(self, cmd, mode);
}

IMP o_set_blend_color;
void h_set_blend_color(id self, SEL cmd, float red, float green, float blue, float alpha)
{
    { std::lock_guard lock(trace_mutex); emit("blend_color %.9g,%.9g,%.9g,%.9g", red, green, blue, alpha); }
    original<void (*)(id, SEL, float, float, float, float)>(o_set_blend_color)(self, cmd, red, green, blue, alpha);
}

void dump_bindings(char const* stage, std::map<NSUInteger, Binding> const& bindings,
    PipelineInfo const* pipeline, NSUInteger first_vertex, NSUInteger vertices,
    NSUInteger first_instance, NSUInteger instances)
{
    for (auto const& [index, binding] : bindings) {
        if (binding.inline_bytes) {
            emit("  %s_bytes index=%lu data=%s", stage, (unsigned long)index,
                hex(binding.bytes.data(), binding.bytes.size()).c_str());
            continue;
        }
        if (!binding.buffer) continue;
        id<MTLBuffer> buffer = binding.buffer;
        size_t start = binding.offset, size = 0;
        auto layout = pipeline ? pipeline->layouts.find(unsigned(index)) : decltype(pipeline->layouts.end()){};
        if (pipeline && std::strcmp(stage, "vertex") == 0 && layout != pipeline->layouts.end()) {
            auto [stride, step] = layout->second;
            NSUInteger first = step ? first_instance : first_vertex;
            NSUInteger count = step ? instances : vertices;
            start += size_t(stride) * first;
            size = size_t(stride) * count;
        } else {
            size = std::min<size_t>(buffer.length > start ? buffer.length - start : 0, 1024);
        }
        if (start + size > buffer.length) size = buffer.length > start ? buffer.length - start : 0;
        uint8_t const* contents = buffer.storageMode == MTLStorageModePrivate ? nullptr
            : static_cast<uint8_t const*>(buffer.contents);
        emit("  %s_buffer index=%lu buffer=%u offset=%lu data=%s", stage, (unsigned long)index,
            buffer_id(binding.buffer), (unsigned long)start,
            contents ? hex(contents + start, size).c_str() : "private");
    }
}

void record_draw(id self, char const* kind, MTLPrimitiveType primitive, NSUInteger first_vertex,
    NSUInteger vertices, NSUInteger first_instance, NSUInteger instances, char const* extra)
{
    std::lock_guard lock(trace_mutex);
    auto& state = encoder(self);
    auto found = pipelines.find(state.pipeline);
    PipelineInfo const* pipeline = found == pipelines.end() ? nullptr : &found->second;
    emit("%s primitive=%lu first=%lu count=%lu first_instance=%lu instances=%lu%s", kind,
        (unsigned long)primitive, (unsigned long)first_vertex, (unsigned long)vertices,
        (unsigned long)first_instance, (unsigned long)instances, extra);
    dump_bindings("vertex", state.vertex, pipeline, first_vertex, vertices, first_instance, instances);
    dump_bindings("fragment", state.fragment, pipeline, 0, 0, 0, 0);
}

IMP o_draw, o_draw_instances, o_draw_base_instance;
void h_draw(id self, SEL cmd, MTLPrimitiveType primitive, NSUInteger start, NSUInteger count)
{
    record_draw(self, "draw", primitive, start, count, 0, 1, "");
    original<void (*)(id, SEL, MTLPrimitiveType, NSUInteger, NSUInteger)>(o_draw)(self, cmd, primitive, start, count);
}
void h_draw_instances(id self, SEL cmd, MTLPrimitiveType primitive, NSUInteger start, NSUInteger count,
    NSUInteger instances)
{
    record_draw(self, "draw", primitive, start, count, 0, instances, "");
    original<void (*)(id, SEL, MTLPrimitiveType, NSUInteger, NSUInteger, NSUInteger)>(o_draw_instances)(
        self, cmd, primitive, start, count, instances);
}
void h_draw_base_instance(id self, SEL cmd, MTLPrimitiveType primitive, NSUInteger start, NSUInteger count,
    NSUInteger instances, NSUInteger base_instance)
{
    record_draw(self, "draw", primitive, start, count, base_instance, instances, "");
    original<void (*)(id, SEL, MTLPrimitiveType, NSUInteger, NSUInteger, NSUInteger, NSUInteger)>(
        o_draw_base_instance)(self, cmd, primitive, start, count, instances, base_instance);
}

IMP o_draw_indexed, o_draw_indexed_instances, o_draw_indexed_base;
std::string index_text(MTLIndexType type, id buffer, NSUInteger offset, NSUInteger count, NSInteger base_vertex)
{
    id<MTLBuffer> indices = buffer;
    size_t size = count * (type == MTLIndexTypeUInt16 ? 2 : 4);
    uint8_t const* contents = indices.storageMode == MTLStorageModePrivate ? nullptr
        : static_cast<uint8_t const*>(indices.contents);
    return " index_type=" + std::to_string(type) + " base_vertex=" + std::to_string(base_vertex)
        + " indices=" + (contents && offset + size <= indices.length ? hex(contents + offset, size) : "private");
}
NSUInteger max_index(MTLIndexType type, id buffer, NSUInteger offset, NSUInteger count)
{
    id<MTLBuffer> indices = buffer;
    if (indices.storageMode == MTLStorageModePrivate) return 0;
    uint8_t const* contents = static_cast<uint8_t const*>(indices.contents) + offset;
    NSUInteger result = 0;
    for (NSUInteger i = 0; i < count; ++i) {
        NSUInteger value = type == MTLIndexTypeUInt16 ? reinterpret_cast<uint16_t const*>(contents)[i]
                                                     : reinterpret_cast<uint32_t const*>(contents)[i];
        if (value != 0xffff && value != 0xffffffff) result = std::max(result, value);
    }
    return result;
}

void h_draw_indexed(id self, SEL cmd, MTLPrimitiveType primitive, NSUInteger count, MTLIndexType type,
    id buffer, NSUInteger offset)
{
    record_draw(self, "draw_indexed", primitive, 0, max_index(type, buffer, offset, count) + 1, 0, 1,
        index_text(type, buffer, offset, count, 0).c_str());
    original<void (*)(id, SEL, MTLPrimitiveType, NSUInteger, MTLIndexType, id, NSUInteger)>(o_draw_indexed)(
        self, cmd, primitive, count, type, buffer, offset);
}
void h_draw_indexed_instances(id self, SEL cmd, MTLPrimitiveType primitive, NSUInteger count,
    MTLIndexType type, id buffer, NSUInteger offset, NSUInteger instances)
{
    record_draw(self, "draw_indexed", primitive, 0, max_index(type, buffer, offset, count) + 1, 0, instances,
        index_text(type, buffer, offset, count, 0).c_str());
    original<void (*)(id, SEL, MTLPrimitiveType, NSUInteger, MTLIndexType, id, NSUInteger, NSUInteger)>(
        o_draw_indexed_instances)(self, cmd, primitive, count, type, buffer, offset, instances);
}
void h_draw_indexed_base(id self, SEL cmd, MTLPrimitiveType primitive, NSUInteger count,
    MTLIndexType type, id buffer, NSUInteger offset, NSUInteger instances, NSInteger base_vertex,
    NSUInteger base_instance)
{
    // Vertex data for a base vertex is not dumped from its exact range; the
    // index text retains base_vertex for the reader.
    record_draw(self, "draw_indexed", primitive, NSUInteger(std::max<NSInteger>(base_vertex, 0)),
        max_index(type, buffer, offset, count) + 1, base_instance, instances,
        index_text(type, buffer, offset, count, base_vertex).c_str());
    original<void (*)(id, SEL, MTLPrimitiveType, NSUInteger, MTLIndexType, id, NSUInteger, NSUInteger,
        NSInteger, NSUInteger)>(o_draw_indexed_base)(self, cmd, primitive, count, type, buffer, offset,
        instances, base_vertex, base_instance);
}

IMP o_end_encoding;
void h_end_encoding(id self, SEL cmd)
{
    {
        std::lock_guard lock(trace_mutex);
        if (encoders.erase((__bridge void const*)self)) emit("render_pass end");
    }
    original<void (*)(id, SEL)>(o_end_encoding)(self, cmd);
}

// Blit encoder --------------------------------------------------------------

IMP o_copy_buffer_texture;
void h_copy_buffer_texture(id self, SEL cmd, id buffer, NSUInteger offset, NSUInteger row_bytes,
    NSUInteger image_bytes, MTLSize size, id texture, NSUInteger slice, NSUInteger level, MTLOrigin origin)
{
    {
        std::lock_guard lock(trace_mutex);
        id<MTLBuffer> source = buffer;
        size_t length = row_bytes * size.height;
        std::string digest = source.storageMode != MTLStorageModePrivate && offset + length <= source.length
            ? sha256(static_cast<uint8_t const*>(source.contents) + offset, length) : "private";
        emit("upload texture=%u x=%lu y=%lu width=%lu height=%lu row_bytes=%lu sha=%s", texture_id(texture),
            (unsigned long)origin.x, (unsigned long)origin.y, (unsigned long)size.width,
            (unsigned long)size.height, (unsigned long)row_bytes, digest.c_str());
    }
    original<void (*)(id, SEL, id, NSUInteger, NSUInteger, NSUInteger, MTLSize, id, NSUInteger, NSUInteger,
        MTLOrigin)>(o_copy_buffer_texture)(self, cmd, buffer, offset, row_bytes, image_bytes, size, texture,
        slice, level, origin);
}

IMP o_copy_texture_buffer;
void h_copy_texture_buffer(id self, SEL cmd, id texture, NSUInteger slice, NSUInteger level, MTLOrigin origin,
    MTLSize size, id buffer, NSUInteger offset, NSUInteger row_bytes, NSUInteger image_bytes)
{
    {
        std::lock_guard lock(trace_mutex);
        emit("readback texture=%u x=%lu y=%lu width=%lu height=%lu", texture_id(texture),
            (unsigned long)origin.x, (unsigned long)origin.y, (unsigned long)size.width, (unsigned long)size.height);
    }
    original<void (*)(id, SEL, id, NSUInteger, NSUInteger, MTLOrigin, MTLSize, id, NSUInteger, NSUInteger,
        NSUInteger)>(o_copy_texture_buffer)(self, cmd, texture, slice, level, origin, size, buffer, offset,
        row_bytes, image_bytes);
}

IMP o_copy_texture_texture;
void h_copy_texture_texture(id self, SEL cmd, id source, NSUInteger source_slice, NSUInteger source_level,
    MTLOrigin source_origin, MTLSize size, id destination, NSUInteger destination_slice,
    NSUInteger destination_level, MTLOrigin destination_origin)
{
    {
        std::lock_guard lock(trace_mutex);
        emit("copy_texture source=%u destination=%u x=%lu y=%lu width=%lu height=%lu to=%lu,%lu",
            texture_id(source), texture_id(destination), (unsigned long)source_origin.x,
            (unsigned long)source_origin.y, (unsigned long)size.width, (unsigned long)size.height,
            (unsigned long)destination_origin.x, (unsigned long)destination_origin.y);
    }
    original<void (*)(id, SEL, id, NSUInteger, NSUInteger, MTLOrigin, MTLSize, id, NSUInteger, NSUInteger,
        MTLOrigin)>(o_copy_texture_texture)(self, cmd, source, source_slice, source_level, source_origin, size,
        destination, destination_slice, destination_level, destination_origin);
}

} // namespace

extern "C" void vox_metal_trace_install(char const* directory)
{
    static bool installed = false;
    if (installed) return;
    installed = true;
    shader_directory = std::string(directory) + "/shaders";
    [[NSFileManager defaultManager] createDirectoryAtPath:@(shader_directory.c_str())
        withIntermediateDirectories:YES attributes:nil error:nil];
    definitions_file = std::fopen((std::string(directory) + "/definitions.trace").c_str(), "w");
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        Class device_class = object_getClass(device);
        HOOK(device_class, "newLibraryWithSource:options:error:", h_new_library, o_new_library);
        HOOK(device_class, "newRenderPipelineStateWithDescriptor:error:", h_new_pipeline, o_new_pipeline);
        HOOK(device_class, "newRenderPipelineStateWithDescriptor:options:reflection:error:",
            h_new_pipeline_reflection, o_new_pipeline_reflection);
        HOOK(device_class, "newRenderPipelineStateWithDescriptor:completionHandler:", h_new_pipeline_async,
            o_new_pipeline_async);
        HOOK(device_class, "newDepthStencilStateWithDescriptor:", h_new_depth, o_new_depth);
        HOOK(device_class, "newSamplerStateWithDescriptor:", h_new_sampler, o_new_sampler);
        id<MTLLibrary> library = [device newLibraryWithSource:
            @"#include <metal_stdlib>\nusing namespace metal;\nvertex float4 v(){return float4(0);}\n"
            options:nil error:nil];
        Class library_class = object_getClass(library);
        HOOK(library_class, "newFunctionWithName:", h_new_function, o_new_function);
        HOOK(library_class, "newFunctionWithName:constantValues:error:", h_new_function_constants,
            o_new_function_constants);
        id<MTLCommandQueue> queue = [device newCommandQueue];
        id<MTLCommandBuffer> buffer = [queue commandBuffer];
        Class buffer_class = object_getClass(buffer);
        HOOK(buffer_class, "renderCommandEncoderWithDescriptor:", h_render_encoder, o_render_encoder);
        HOOK(buffer_class, "commit", h_commit, o_commit);
        MTLTextureDescriptor* texture_descriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1 height:1 mipmapped:NO];
        texture_descriptor.usage = MTLTextureUsageRenderTarget;
        id<MTLTexture> texture = [device newTextureWithDescriptor:texture_descriptor];
        MTLRenderPassDescriptor* pass = [MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture = texture;
        id<MTLRenderCommandEncoder> render = [buffer renderCommandEncoderWithDescriptor:pass];
        Class render_class = object_getClass(render);
        HOOK(render_class, "setRenderPipelineState:", h_set_pipeline, o_set_pipeline);
        HOOK(render_class, "setVertexBuffer:offset:atIndex:", h_set_vertex_buffer, o_set_vertex_buffer);
        HOOK(render_class, "setFragmentBuffer:offset:atIndex:", h_set_fragment_buffer, o_set_fragment_buffer);
        HOOK(render_class, "setVertexBufferOffset:atIndex:", h_set_vertex_offset, o_set_vertex_offset);
        HOOK(render_class, "setFragmentBufferOffset:atIndex:", h_set_fragment_offset, o_set_fragment_offset);
        HOOK(render_class, "setVertexBytes:length:atIndex:", h_set_vertex_bytes, o_set_vertex_bytes);
        HOOK(render_class, "setFragmentBytes:length:atIndex:", h_set_fragment_bytes, o_set_fragment_bytes);
        HOOK(render_class, "setFragmentTexture:atIndex:", h_set_fragment_texture, o_set_fragment_texture);
        HOOK(render_class, "setFragmentSamplerState:atIndex:", h_set_fragment_sampler, o_set_fragment_sampler);
        HOOK(render_class, "setDepthStencilState:", h_set_depth_state, o_set_depth_state);
        HOOK(render_class, "setStencilReferenceValue:", h_set_stencil_reference, o_set_stencil_reference);
        HOOK(render_class, "setScissorRect:", h_set_scissor, o_set_scissor);
        HOOK(render_class, "setViewport:", h_set_viewport, o_set_viewport);
        HOOK(render_class, "setCullMode:", h_set_cull, o_set_cull);
        HOOK(render_class, "setFrontFacingWinding:", h_set_winding, o_set_winding);
        HOOK(render_class, "setTriangleFillMode:", h_set_fill, o_set_fill);
        HOOK(render_class, "setBlendColorRed:green:blue:alpha:", h_set_blend_color, o_set_blend_color);
        HOOK(render_class, "drawPrimitives:vertexStart:vertexCount:", h_draw, o_draw);
        HOOK(render_class, "drawPrimitives:vertexStart:vertexCount:instanceCount:", h_draw_instances,
            o_draw_instances);
        HOOK(render_class, "drawPrimitives:vertexStart:vertexCount:instanceCount:baseInstance:",
            h_draw_base_instance, o_draw_base_instance);
        HOOK(render_class, "drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:",
            h_draw_indexed, o_draw_indexed);
        HOOK(render_class, "drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:",
            h_draw_indexed_instances, o_draw_indexed_instances);
        HOOK(render_class,
            "drawIndexedPrimitives:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:baseVertex:baseInstance:",
            h_draw_indexed_base, o_draw_indexed_base);
        HOOK(render_class, "endEncoding", h_end_encoding, o_end_encoding);
        [render endEncoding];
        id<MTLBlitCommandEncoder> blit = [buffer blitCommandEncoder];
        Class blit_class = object_getClass(blit);
        HOOK(blit_class,
            "copyFromBuffer:sourceOffset:sourceBytesPerRow:sourceBytesPerImage:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:",
            h_copy_buffer_texture, o_copy_buffer_texture);
        HOOK(blit_class,
            "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toBuffer:destinationOffset:destinationBytesPerRow:destinationBytesPerImage:",
            h_copy_texture_buffer, o_copy_texture_buffer);
        HOOK(blit_class,
            "copyFromTexture:sourceSlice:sourceLevel:sourceOrigin:sourceSize:toTexture:destinationSlice:destinationLevel:destinationOrigin:",
            h_copy_texture_texture, o_copy_texture_texture);
        [blit endEncoding];
        [texture release];
        [queue release];
        [library release];
        // Keep the device alive: its class must remain the one Graphite receives.
    }
}

extern "C" void vox_metal_trace_begin(char const* directory, char const* name)
{
    std::lock_guard lock(trace_mutex);
    trace_directory = directory;
    std::string path = trace_directory + "/" + name + ".trace";
    trace_file = std::fopen(path.c_str(), "w");
    textures.clear();
    next_texture = 1;
}

extern "C" void vox_metal_trace_end(void)
{
    std::lock_guard lock(trace_mutex);
    if (trace_file) std::fclose(trace_file);
    trace_file = nullptr;
}
