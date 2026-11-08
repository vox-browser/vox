#ifndef VOX_NATIVE_DOCUMENT_SUBMISSION_DARWIN_H
#define VOX_NATIVE_DOCUMENT_SUBMISSION_DARWIN_H
#import <Cocoa/Cocoa.h>
#include <stdint.h>

typedef void (*NativeDocumentSubmitted)(void *, int64_t, uint64_t, uint64_t);
typedef struct {
    CGContextRef bitmap;
    uint64_t token;
    NativeDocumentSubmitted callback;
    void *target;
    int64_t navigation;
    uint64_t installation;
} NativeDocumentSubmissionFrame;

// Main-thread, synchronous frame stack. Nested rasterization restores its
// caller's claim; neither an unrelated draw context nor a cached image can claim.
static NativeDocumentSubmissionFrame *native_document_submission_current;
static uint64_t native_document_submission_sequence;

static uint64_t vox_browser_stage_document_submission(NativeDocumentSubmitted callback,
    void *target, int64_t navigation, uint64_t installation) {
    NativeDocumentSubmissionFrame *frame = native_document_submission_current;
    if (!frame || !frame->bitmap || !frame->token || frame->callback
        || !callback || !target || !installation
        || NSGraphicsContext.currentContext.CGContext != frame->bitmap) return 0;
    frame->callback = callback;
    frame->target = target;
    frame->navigation = navigation;
    frame->installation = installation;
    return frame->token;
}

static void native_document_submission_acknowledge(NativeDocumentSubmissionFrame *frame) {
    NativeDocumentSubmitted callback = frame->callback;
    frame->callback = NULL;
    if (callback) callback(frame->target, frame->navigation, frame->installation, frame->token);
}
#endif
