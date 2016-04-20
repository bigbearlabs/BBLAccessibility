/*      
    WebKitSystemInterface.h
    Copyright (C) 2005, 2006, 2007 Apple Inc. All rights reserved.    

    Public header file.
*/

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

@class QTMovie;

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    WKCertificateParseResultSucceeded  = 0,
    WKCertificateParseResultFailed     = 1,
    WKCertificateParseResultPKCS7      = 2,
} WKCertificateParseResult;

CFStringRef WKCopyCFLocalizationPreferredName(CFStringRef localization);
CFStringRef WKSignedPublicKeyAndChallengeString(unsigned keySize, CFStringRef challenge, CFStringRef keyDescription);
WKCertificateParseResult WKAddCertificatesToKeychainFromData(const void *bytes, unsigned length);

NSString *WKGetPreferredExtensionForMIMEType(NSString *type);
NSArray *WKGetExtensionsForMIMEType(NSString *type);
NSString *WKGetMIMETypeForExtension(NSString *extension);

NSDate *WKGetNSURLResponseLastModifiedDate(NSURLResponse *response);
NSTimeInterval WKGetNSURLResponseFreshnessLifetime(NSURLResponse *response);
NSTimeInterval WKGetNSURLResponseCalculatedExpiration(NSURLResponse *response);
BOOL WKGetNSURLResponseMustRevalidate(NSURLResponse *response);

CFStringEncoding WKGetWebDefaultCFStringEncoding(void);

float WKSecondsSinceLastInputEvent(void);
CFStringRef WKPreferRGB32Key(void);

void WKSetNSURLConnectionDefersCallbacks(NSURLConnection *connection, BOOL defers);
float WKSecondsSinceLastInputEvent(void);

void WKShowKeyAndMain(void);
#ifndef __LP64__
OSStatus WKSyncWindowWithCGAfterMove(WindowRef);
unsigned WKCarbonWindowMask(void);
void *WKGetNativeWindowFromWindowRef(WindowRef);
OSType WKCarbonWindowPropertyCreator(void);
OSType WKCarbonWindowPropertyTag(void);
#endif

typedef id WKNSURLConnectionDelegateProxyPtr;

WKNSURLConnectionDelegateProxyPtr WKCreateNSURLConnectionDelegateProxy(void);

void WKDisableCGDeferredUpdates(void);

Class WKNSURLProtocolClassForReqest(NSURLRequest *request);
void WKSetNSURLRequestShouldContentSniff(NSMutableURLRequest *request, BOOL shouldContentSniff);

unsigned WKGetNSAutoreleasePoolCount(void);

NSString *WKMouseMovedNotification(void);
void WKSetNSWindowShouldPostEventNotifications(NSWindow *window, BOOL post);

CFTypeID WKGetAXTextMarkerTypeID(void);
CFTypeID WKGetAXTextMarkerRangeTypeID(void);
CFTypeRef WKCreateAXTextMarker(const void *bytes, size_t len);
BOOL WKGetBytesFromAXTextMarker(CFTypeRef textMarker, void *bytes, size_t length);
CFTypeRef WKCreateAXTextMarkerRange(CFTypeRef start, CFTypeRef end);
CFTypeRef WKCopyAXTextMarkerRangeStart(CFTypeRef range);
CFTypeRef WKCopyAXTextMarkerRangeEnd(CFTypeRef range);
void WKAccessibilityHandleFocusChanged(void);
AXUIElementRef WKCreateAXUIElementRef(id element);
void WKUnregisterUniqueIdForElement(id element);

BOOL WKFontSmoothingModeIsLCD(int mode);
void WKSetUpFontCache(size_t s);

void WKSignalCFReadStreamEnd(CFReadStreamRef stream);
void WKSignalCFReadStreamHasBytes(CFReadStreamRef stream);
void WKSignalCFReadStreamError(CFReadStreamRef stream, CFStreamError *error);

CFReadStreamRef WKCreateCustomCFReadStream(void *(*formCreate)(CFReadStreamRef, void *), 
    void (*formFinalize)(CFReadStreamRef, void *), 
    Boolean (*formOpen)(CFReadStreamRef, CFStreamError *, Boolean *, void *), 
    CFIndex (*formRead)(CFReadStreamRef, UInt8 *, CFIndex, CFStreamError *, Boolean *, void *), 
    Boolean (*formCanRead)(CFReadStreamRef, void *), 
    void (*formClose)(CFReadStreamRef, void *), 
    void (*formSchedule)(CFReadStreamRef, CFRunLoopRef, CFStringRef, void *), 
    void (*formUnschedule)(CFReadStreamRef, CFRunLoopRef, CFStringRef, void *),
    void *context);

void WKDrawFocusRing(CGContextRef context, CGRect clipRect, CGColorRef color, int radius);
    // Ignore the context's clipping.
    // The CG context's current path is the focus ring's path.
    // A color of 0 means "use system focus ring color".
    // A radius of 0 means "use default focus ring radius".

void WKSetDragImage(NSImage *image, NSPoint offset);

void WKDrawBezeledTextFieldCell(NSRect, BOOL enabled);
void WKDrawTextFieldCellFocusRing(NSTextFieldCell*, NSRect);
void WKDrawBezeledTextArea(NSRect, BOOL enabled);
void WKPopupMenu(NSMenu*, NSPoint location, float width, NSView*, int selectedItem, NSFont*);

void WKSendUserChangeNotifications(void);
#ifndef __LP64__    
BOOL WKConvertNSEventToCarbonEvent(EventRecord *carbonEvent, NSEvent *cocoaEvent);
void WKSendKeyEventToTSM(NSEvent *theEvent);
void WKCallDrawingNotification(CGrafPtr port, Rect *bounds);
#endif

BOOL WKGetGlyphTransformedAdvances(CGFontRef, NSFont*, CGAffineTransform *m, ATSGlyphRef *glyph, CGSize *advance);
CGFontRef WKGetCGFontFromNSFont(NSFont *font);
void WKGetFontMetrics(CGFontRef font, int *ascent, int *descent, int *lineGap, unsigned *unitsPerEm);
NSFont *WKGetFontInLanguageForRange(NSFont *font, NSString *string, NSRange range);
NSFont *WKGetFontInLanguageForCharacter(NSFont *font, UniChar ch);
void WKSetCGFontRenderingMode(CGContextRef cgContext, NSFont *font);
ATSUFontID WKGetNSFontATSUFontId(NSFont *font);
void WKReleaseStyleGroup(void *group);
BOOL WKCGContextGetShouldSmoothFonts(CGContextRef cgContext);

void WKSetPatternPhaseInUserSpace(CGContextRef, CGPoint);

typedef void *WKGlyphVectorRef;
OSStatus WKConvertCharToGlyphs(void *styleGroup, const UniChar *characters, unsigned numCharacters, WKGlyphVectorRef glyphs);
OSStatus WKGetATSStyleGroup(ATSUStyle fontStyle, void **styleGroup);
OSStatus WKInitializeGlyphVector(int count, WKGlyphVectorRef glyphs);
void WKClearGlyphVector(WKGlyphVectorRef glyphs);

int WKGetGlyphVectorNumGlyphs(WKGlyphVectorRef glyphVector);
ATSLayoutRecord *WKGetGlyphVectorFirstRecord(WKGlyphVectorRef glyphVector);
size_t WKGetGlyphVectorRecordSize(WKGlyphVectorRef glyphVector);
ATSGlyphRef WKGetDefaultGlyphForChar(NSFont *font, UniChar c);

#ifndef __LP64__
NSEvent *WKCreateNSEventWithCarbonEvent(EventRef eventRef);
NSEvent *WKCreateNSEventWithCarbonMouseMoveEvent(EventRef inEvent, NSWindow *window);
NSEvent *WKCreateNSEventWithCarbonClickEvent(EventRef inEvent, WindowRef windowRef);
#endif

CGContextRef WKNSWindowOverrideCGContext(NSWindow *, CGContextRef);
void WKNSWindowRestoreCGContext(NSWindow *, CGContextRef);

BOOL WKSupportsMultipartXMixedReplace(NSMutableURLRequest *request);
NSString* WKPathFromFont(NSFont *font);

BOOL WKCGContextIsBitmapContext(CGContextRef context);

void WKGetWheelEventDeltas(NSEvent *, float *deltaX, float *deltaY, BOOL *continuous);

BOOL WKAppVersionCheckLessThan(NSString *, int, double);

int WKQTMovieDataRate(QTMovie* movie);
float WKQTMovieMaxTimeLoaded(QTMovie* movie);

CFStringRef WKCopyFoundationCacheDirectory(void);

#ifdef __cplusplus
}
#endif
