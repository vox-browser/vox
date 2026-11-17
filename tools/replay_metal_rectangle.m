// Replay one decode_metal_capture.py --export-rectangle-draw snapshot on macOS.
// This is a selected-draw diagnostic over a uniform backdrop, not a page replay.
// Compile under the memory guard with clang -framework Foundation -framework Metal.
// Supports unclipped Dawn vertex-pulled rectangles (28/108-byte strides,
// float4 paint slots, inline slot 30), BGRA8 four-sample targets and the observed
// v225 relaxed-math options/default stencil. The viewport defines target size.
// OUTPUT is premultiplied BGRA8, top row first; --background is premultiplied RGBA8.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <CommonCrypto/CommonDigest.h>
#include <sys/stat.h>
#include <unistd.h>
#include <math.h>
#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void require(BOOL condition, NSString *message) {
    if (!condition) @throw [NSException exceptionWithName:@"ReplayInput" reason:message userInfo:nil];
}

static NSString *sha256(NSData *data) {
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    NSMutableString *result = [NSMutableString string];
    for (NSUInteger i = 0; i < sizeof(bytes); i++) [result appendFormat:@"%02x", bytes[i]];
    return result;
}

static NSData *read_file(NSString *path) {
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    require(attributes != nil && [attributes fileSize] <= 128 * 1024 * 1024, @"Missing or oversized input");
    NSData *data = [NSData dataWithContentsOfFile:path];
    require(data != nil, @"Cannot read input");
    return data;
}

static NSUInteger integer(NSDictionary *object, NSString *key) {
    id value = object[key];
    require([value isKindOfClass:[NSNumber class]] && [value doubleValue] >= 0
        && [value doubleValue] <= UINT32_MAX && floor([value doubleValue]) == [value doubleValue],
        [@"Invalid integer: " stringByAppendingString:key]);
    return [value unsignedIntegerValue];
}

static id<MTLBuffer> buffer(id<MTLDevice> device, NSData *data) {
    id<MTLBuffer> result = [device newBufferWithBytes:data.bytes length:data.length
        options:MTLResourceStorageModeShared];
    require(result != nil, @"Cannot allocate Metal buffer");
    return result;
}

static void validate_depth(NSDictionary *depth) {
    // v225 serializes the ordinary depth state and two always/keep stencil faces.
    // Reject other stencil policies instead of silently replacing them.
    NSString *hex = depth[@"raw_hex"];
    require([hex isKindOfClass:[NSString class]] && hex.length == 288
        && strspn(hex.UTF8String, "0123456789abcdefABCDEF") == 288, @"Unsupported serialized depth state");
    uint64_t words[18] = {0};
    unsigned char *bytes = (unsigned char *)words;
    for (NSUInteger i = 0; i < sizeof(words); i++) {
        char pair[3] = {hex.UTF8String[i * 2], hex.UTF8String[i * 2 + 1], 0};
        bytes[i] = (unsigned char)strtoul(pair, NULL, 16);
    }
    uint64_t expected[18] = {225, integer(depth, @"compare"), [depth[@"write_enabled"] boolValue],
        0, 0, 7, 0, 0, 0, UINT32_MAX, UINT32_MAX, 0, 7, 0, 0, 0, UINT32_MAX, UINT32_MAX};
    require(expected[1] <= 7 && !memcmp(words, expected, sizeof(words)), @"Unsupported depth/stencil policy");
}

static void publish(NSData *pixels, NSString *output) {
    // Publish atomically without replacing an existing receipt or image.
    NSString *template = [output stringByAppendingString:@".XXXXXX"];
    char *temporary = strdup(template.fileSystemRepresentation);
    int fd = mkstemp(temporary);
    require(fd >= 0, @"Cannot create output temporary file");
    BOOL success = YES;
    const char *bytes = pixels.bytes;
    size_t remaining = pixels.length;
    while (remaining) {
        ssize_t count = write(fd, bytes, remaining);
        if (count <= 0) { success = NO; break; }
        bytes += count; remaining -= (size_t)count;
    }
    if (success) success = fsync(fd) == 0;
    if (close(fd) != 0) success = NO;
    if (success) success = link(temporary, output.fileSystemRepresentation) == 0;
    unlink(temporary);
    free(temporary);
    require(success, @"Cannot publish output without overwriting");
}

int main(int argc, char **argv) { @autoreleasepool { @try {
    if (argc < 3) {
        fprintf(stderr, "usage: replay_metal_rectangle SNAPSHOT OUTPUT.bgra [--split-instances] [--background RRGGBBAA]\n");
        return 2;
    }
    BOOL split = NO;
    unsigned long background = 0xffffffff;
    for (int i = 3; i < argc; i++) {
        if (!strcmp(argv[i], "--split-instances")) split = YES;
        else if (!strcmp(argv[i], "--background") && i + 1 < argc) {
            const char *color = argv[++i]; char *end;
            require(strlen(color) == 8 && strspn(color, "0123456789abcdefABCDEF") == 8,
                @"Background must be eight hexadecimal RGBA digits");
            background = strtoul(color, &end, 16);
            require(!*end, @"Invalid background");
        } else require(NO, @"Unknown or incomplete option");
    }
    NSString *directory = [[NSString stringWithUTF8String:argv[1]] stringByStandardizingPath];
    NSString *output = [[NSString stringWithUTF8String:argv[2]] stringByStandardizingPath];
    struct stat existing;
    require(lstat(output.fileSystemRepresentation, &existing) != 0 && errno == ENOENT,
        @"Output already exists or cannot be inspected");
    NSData *metadata_bytes = read_file([directory stringByAppendingPathComponent:@"draw.json"]);
    NSDictionary *metadata = [NSJSONSerialization JSONObjectWithData:metadata_bytes options:0 error:NULL];
    require([metadata isKindOfClass:[NSDictionary class]], @"Invalid snapshot JSON");
    NSDictionary *files = metadata[@"files"];
    require([files isKindOfClass:[NSDictionary class]] && files.count > 0 && files.count <= 64,
        @"Invalid snapshot file manifest");
    NSMutableDictionary *data = [NSMutableDictionary dictionary], *pins = [NSMutableDictionary dictionary];
    pins[@"draw.json"] = sha256(metadata_bytes);
    for (NSString *name in files) {
        require([name isKindOfClass:[NSString class]] && [name.lastPathComponent isEqual:name]
            && ![name isEqual:@".."] && ![name isEqual:@"draw.json"], @"Invalid snapshot filename");
        NSData *bytes = read_file([directory stringByAppendingPathComponent:name]);
        NSDictionary *identity = files[name];
        require(bytes.length == integer(identity, @"size") && [sha256(bytes) isEqual:identity[@"sha256"]],
            @"Snapshot input hash mismatch");
        data[name] = bytes; pins[name] = sha256(bytes);
    }
    for (NSString *name in @[@"vertices.bin", @"instances.bin", @"indices.bin", @"uniforms.bin",
        @"vertex.metal", @"fragment.metal", @"vertex-options.bin", @"fragment-options.bin"])
        require(data[name] != nil, @"Missing rectangle resource");
    NSDictionary *draw = metadata[@"draw"], *state = metadata[@"pipeline"];
    NSUInteger draw_offset = integer(draw, @"offset");
    validate_depth(draw[@"depth"]);
    NSArray *viewport = draw[@"viewport"], *scissor = draw[@"scissor"];
    require(viewport.count == 6 && scissor.count == 4, @"Invalid viewport or scissor");
    double width_value = [viewport[2] doubleValue], height_value = [viewport[3] doubleValue];
    require([viewport[0] doubleValue] == 0 && [viewport[1] doubleValue] == 0
        && isfinite(width_value) && isfinite(height_value)
        && width_value >= 1 && height_value >= 1 && width_value <= 8192 && height_value <= 8192
        && floor(width_value) == width_value && floor(height_value) == height_value
        && width_value * height_value <= 16 * 1024 * 1024, @"Unsupported viewport dimensions");
    NSUInteger width = width_value, height = height_value;
    double near = [viewport[4] doubleValue], far = [viewport[5] doubleValue];
    require(isfinite(near) && isfinite(far) && near >= 0 && far <= 1 && near <= far,
        @"Unsupported viewport depth range");
    NSUInteger primitive = integer(draw, @"primitive"), count = integer(draw, @"index_count");
    NSUInteger instances = integer(draw, @"instance_count"), first = integer(draw, @"base_instance");
    NSUInteger base_vertex = integer(draw, @"base_vertex");
    require((primitive == MTLPrimitiveTypeTriangle || primitive == MTLPrimitiveTypeTriangleStrip)
        && integer(draw, @"index_type") == MTLIndexTypeUInt16 && count >= 3 && count <= 65535
        && instances > 0 && instances <= 65535, @"Unsupported rectangle draw");
    NSData *indices_data = data[@"indices.bin"], *vertex_data = data[@"vertices.bin"];
    NSData *instance_data = data[@"instances.bin"], *uniform_data = data[@"uniforms.bin"];
    require(indices_data.length == count * 2 && vertex_data.length % 28 == 0
        && instance_data.length % 108 == 0 && uniform_data.length % 16 == 0
        && first + instances <= instance_data.length / 108, @"Invalid rectangle buffer range");
    const uint16_t *indices_bytes = indices_data.bytes;
    for (NSUInteger i = 0; i < count; i++)
        require(base_vertex + indices_bytes[i] < vertex_data.length / 28, @"Vertex range exceeds snapshot");
    for (NSUInteger i = first; i < first + instances; i++) {
        uint32_t slot; memcpy(&slot, (const char *)instance_data.bytes + i * 108 + 68, 4);
        require((uint64_t)slot * 16 + 16 <= uniform_data.length, @"Uniform range exceeds snapshot");
    }
    require([state[@"sample_mask"] isEqual:@"0xffffffffffffffff"]
        && [state[@"sample_coverage"] doubleValue] == 1
        && [state[@"rasterization_enabled"] boolValue], @"Unsupported sample policy");
    NSUInteger samples = integer(state, @"samples");
    require(samples == 4, @"This diagnostic requires four-sample rectangles");
    NSDictionary *color = state[@"color_attachments"][0];
    require(integer(color, @"pixel_format") == MTLPixelFormatBGRA8Unorm
        && integer(state, @"depth_format") == MTLPixelFormatDepth32Float_Stencil8
        && integer(state, @"stencil_format") == MTLPixelFormatDepth32Float_Stencil8,
        @"Unsupported attachment formats");
    for (NSUInteger i = 1; i < [state[@"color_attachments"] count]; i++)
        require(integer(state[@"color_attachments"][i], @"pixel_format") == MTLPixelFormatInvalid,
            @"Multiple color attachments are unsupported");

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    require(device != nil && [device supportsTextureSampleCount:samples], @"No compatible Metal device");
    id<MTLFunction> functions[2]; NSError *error = nil;
    NSArray *stages = @[@"vertex", @"fragment"];
    for (NSUInteger i = 0; i < 2; i++) {
        NSString *stage = stages[i]; NSDictionary *info = metadata[@"functions"][stage];
        NSData *serialized = data[[stage stringByAppendingString:@"-options.bin"]];
        uint64_t expected_options[17] = {225, 0, 1, 0, integer(info, @"language_version")};
        expected_options[16] = 2;
        require(serialized.length == sizeof(expected_options)
            && !memcmp(serialized.bytes, expected_options, sizeof(expected_options)),
            @"Unsupported serialized compiler options");
        MTLCompileOptions *options = [MTLCompileOptions new];
        // The retained Dawn shaders use relaxed math. Opaque serialized options
        // are hash-pinned; this helper does not implement arbitrary compiler options.
        options.fastMathEnabled = YES;
        options.languageVersion = integer(info, @"language_version");
        NSString *source = [[NSString alloc] initWithData:data[[stage stringByAppendingString:@".metal"]]
            encoding:NSUTF8StringEncoding];
        require(source != nil && [info[@"entry_point"] isKindOfClass:[NSString class]], @"Invalid shader source or entry point");
        id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
        require(library != nil, [@"Metal library compilation failed: " stringByAppendingString:error.description ?: @""]);
        functions[i] = [library newFunctionWithName:info[@"entry_point"]];
        require(functions[i] != nil, @"Missing shader entry point");
    }
    MTLRenderPipelineDescriptor *pipeline = [MTLRenderPipelineDescriptor new];
    pipeline.vertexFunction = functions[0]; pipeline.fragmentFunction = functions[1];
    pipeline.rasterSampleCount = samples;
    pipeline.alphaToCoverageEnabled = [state[@"alpha_to_coverage"] boolValue];
    pipeline.alphaToOneEnabled = [state[@"alpha_to_one"] boolValue];
    pipeline.depthAttachmentPixelFormat = integer(state, @"depth_format");
    pipeline.stencilAttachmentPixelFormat = integer(state, @"stencil_format");
    MTLRenderPipelineColorAttachmentDescriptor *attachment = pipeline.colorAttachments[0];
    attachment.pixelFormat = MTLPixelFormatBGRA8Unorm;
    attachment.blendingEnabled = [color[@"blend_enabled"] boolValue];
    attachment.sourceRGBBlendFactor = integer(color, @"source_rgb");
    attachment.destinationRGBBlendFactor = integer(color, @"destination_rgb");
    attachment.rgbBlendOperation = integer(color, @"operation_rgb");
    attachment.sourceAlphaBlendFactor = integer(color, @"source_alpha");
    attachment.destinationAlphaBlendFactor = integer(color, @"destination_alpha");
    attachment.alphaBlendOperation = integer(color, @"operation_alpha");
    attachment.writeMask = integer(color, @"write_mask");
    id<MTLRenderPipelineState> render = [device newRenderPipelineStateWithDescriptor:pipeline error:&error];
    require(render != nil, [@"Metal pipeline creation failed: " stringByAppendingString:error.description ?: @""]);
    MTLDepthStencilDescriptor *depth = [MTLDepthStencilDescriptor new];
    depth.depthCompareFunction = integer(draw[@"depth"], @"compare");
    depth.depthWriteEnabled = [draw[@"depth"][@"write_enabled"] boolValue];
    id<MTLDepthStencilState> depth_state = [device newDepthStencilStateWithDescriptor:depth];
    MTLTextureDescriptor *texture = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:attachment.pixelFormat
        width:width height:height mipmapped:NO];
    texture.storageMode = MTLStorageModeShared; texture.usage = MTLTextureUsageRenderTarget;
    id<MTLTexture> resolved = [device newTextureWithDescriptor:texture];
    texture.storageMode = MTLStorageModePrivate; texture.textureType = MTLTextureType2DMultisample;
    texture.sampleCount = samples;
    id<MTLTexture> msaa = [device newTextureWithDescriptor:texture];
    texture.pixelFormat = pipeline.depthAttachmentPixelFormat;
    id<MTLTexture> depth_texture = [device newTextureWithDescriptor:texture];
    require(resolved && msaa && depth_texture && depth_state, @"Cannot allocate replay targets");
    MTLRenderPassDescriptor *pass = [MTLRenderPassDescriptor renderPassDescriptor];
    pass.colorAttachments[0].texture = msaa; pass.colorAttachments[0].resolveTexture = resolved;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(((background >> 24) & 255) / 255.0,
        ((background >> 16) & 255) / 255.0, ((background >> 8) & 255) / 255.0, (background & 255) / 255.0);
    pass.depthAttachment.texture = depth_texture; pass.depthAttachment.loadAction = MTLLoadActionClear;
    pass.depthAttachment.clearDepth = 1; pass.depthAttachment.storeAction = MTLStoreActionDontCare;
    pass.stencilAttachment.texture = depth_texture; pass.stencilAttachment.loadAction = MTLLoadActionClear;
    pass.stencilAttachment.clearStencil = 0; pass.stencilAttachment.storeAction = MTLStoreActionDontCare;
    id<MTLCommandQueue> queue = [device newCommandQueue];
    id<MTLCommandBuffer> command = [queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [command renderCommandEncoderWithDescriptor:pass];
    require(encoder != nil, @"Cannot create render encoder");
    [encoder setRenderPipelineState:render]; [encoder setDepthStencilState:depth_state];
    [encoder setViewport:(MTLViewport){0, 0, width, height, near, far}];
    NSUInteger sx = [scissor[0] unsignedIntegerValue], sy = [scissor[1] unsignedIntegerValue];
    NSUInteger sw = [scissor[2] unsignedIntegerValue], sh = [scissor[3] unsignedIntegerValue];
    require(sx < width && sy < height && sw <= width - sx && sh <= height - sy && sw && sh,
        @"Scissor exceeds replay target");
    [encoder setScissorRect:(MTLScissorRect){sx, sy, sw, sh}];
    [encoder setVertexBuffer:buffer(device, uniform_data) offset:0 atIndex:1];
    [encoder setVertexBuffer:buffer(device, vertex_data) offset:0 atIndex:2];
    [encoder setVertexBuffer:buffer(device, instance_data) offset:0 atIndex:3];
    id<MTLBuffer> indices = buffer(device, indices_data);
    for (NSString *stage in stages) {
        NSDictionary *bindings = draw[[stage stringByAppendingString:@"_inline_bytes"]];
        require(bindings.count > 0 && bindings.count <= 31, @"Invalid inline bindings");
        for (NSString *slot in bindings) {
            NSScanner *scanner = [NSScanner scannerWithString:slot]; int index;
            require([scanner scanInt:&index] && scanner.isAtEnd && index == 30,
                @"Invalid inline binding index");
            NSString *name = [NSString stringWithFormat:@"%@-bytes-%@.bin", stage, slot];
            NSData *bytes = data[name];
            require(bytes != nil && bytes.length > 0 && bytes.length <= 4096, @"Invalid inline binding bytes");
            if ([stage isEqual:@"vertex"]) [encoder setVertexBytes:bytes.bytes length:bytes.length atIndex:index];
            else [encoder setFragmentBytes:bytes.bytes length:bytes.length atIndex:index];
        }
    }
    NSUInteger stride = split ? 1 : instances;
    for (NSUInteger i = 0; i < instances; i += stride)
        [encoder drawIndexedPrimitives:primitive indexCount:count indexType:MTLIndexTypeUInt16
            indexBuffer:indices indexBufferOffset:0 instanceCount:stride baseVertex:base_vertex baseInstance:first + i];
    [encoder endEncoding]; [command commit]; [command waitUntilCompleted];
    require(command.status == MTLCommandBufferStatusCompleted,
        [@"Metal replay failed: " stringByAppendingString:command.error.description ?: @""]);
    NSMutableData *pixels = [NSMutableData dataWithLength:width * height * 4];
    [resolved getBytes:pixels.mutableBytes bytesPerRow:width * 4
        fromRegion:MTLRegionMake2D(0, 0, width, height) mipmapLevel:0];
    for (NSString *name in pins)
        require([sha256(read_file([directory stringByAppendingPathComponent:name])) isEqual:pins[name]],
            @"Snapshot changed during replay");
    publish(pixels, output);
    NSDictionary *receipt = @{@"width":@(width), @"height":@(height), @"draw_offset":@(draw_offset),
        @"split_instances":@(split), @"instances":@(instances), @"output_sha256":sha256(pixels),
        @"input_sha256":pins, @"background_rgba":@(background), @"gpu_status":@(command.status),
        @"scope":@"Selected captured rectangle draw; uniform backdrop, relaxed math, default stencil; omits other passes and publication"};
    NSData *encoded = [NSJSONSerialization dataWithJSONObject:receipt options:NSJSONWritingSortedKeys error:NULL];
    printf("%s\n", [[NSString alloc] initWithData:encoded encoding:NSUTF8StringEncoding].UTF8String);
    return 0;
} @catch (NSException *error) {
    fprintf(stderr, "replay_metal_rectangle: %s\n", error.reason.UTF8String);
    return 1;
}}}
