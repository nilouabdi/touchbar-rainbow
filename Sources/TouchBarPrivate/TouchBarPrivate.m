// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later

#import "TouchBarPrivate.h"
#import <dlfcn.h>

// Private class methods on NSTouchBar. They are dispatched dynamically, so declaring them is enough;
// nothing has to be linked. 10.14+ uses the "TouchBar" spelling, 10.13 the "FunctionBar" one.
NS_ASSUME_NONNULL_BEGIN
@interface NSTouchBar (TBRPrivate)
+ (void)presentSystemModalTouchBar:(NSTouchBar *)touchBar
                         placement:(long long)placement
          systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)presentSystemModalFunctionBar:(NSTouchBar *)touchBar
                            placement:(long long)placement
             systemTrayItemIdentifier:(nullable NSTouchBarItemIdentifier)identifier;
+ (void)dismissSystemModalTouchBar:(NSTouchBar *)touchBar;
+ (void)dismissSystemModalFunctionBar:(NSTouchBar *)touchBar;
@end
NS_ASSUME_NONNULL_END

static SEL TBRPresentSelector(void) {
    if ([NSTouchBar respondsToSelector:@selector(presentSystemModalTouchBar:placement:systemTrayItemIdentifier:)]) {
        return @selector(presentSystemModalTouchBar:placement:systemTrayItemIdentifier:);
    }
    if ([NSTouchBar respondsToSelector:@selector(presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:)]) {
        return @selector(presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:);
    }
    return NULL;
}

BOOL TBRSystemModalTouchBarAvailable(void) {
    return TBRPresentSelector() != NULL;
}

void TBRPresentSystemModalTouchBar(NSTouchBar *touchBar, BOOL fullWidth, NSTouchBarItemIdentifier trayIdentifier) {
    long long placement = fullWidth ? 1 : 0;
    if ([NSTouchBar respondsToSelector:@selector(presentSystemModalTouchBar:placement:systemTrayItemIdentifier:)]) {
        [NSTouchBar presentSystemModalTouchBar:touchBar placement:placement systemTrayItemIdentifier:trayIdentifier];
    } else if ([NSTouchBar respondsToSelector:@selector(presentSystemModalFunctionBar:placement:systemTrayItemIdentifier:)]) {
        [NSTouchBar presentSystemModalFunctionBar:touchBar placement:placement systemTrayItemIdentifier:trayIdentifier];
    }
}

void TBRDismissSystemModalTouchBar(NSTouchBar *touchBar) {
    if ([NSTouchBar respondsToSelector:@selector(dismissSystemModalTouchBar:)]) {
        [NSTouchBar dismissSystemModalTouchBar:touchBar];
    } else if ([NSTouchBar respondsToSelector:@selector(dismissSystemModalFunctionBar:)]) {
        [NSTouchBar dismissSystemModalFunctionBar:touchBar];
    }
}

// DFRFoundation is a private framework. Loading it with dlopen avoids a link-time dependency
// (the public SDK has no stub for it).
typedef void (*TBRShowsCloseBoxFn)(BOOL);

void TBRSetShowsCloseBox(BOOL shows) {
    static TBRShowsCloseBoxFn fn = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation", RTLD_LAZY);
        if (handle != NULL) {
            fn = (TBRShowsCloseBoxFn)dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost");
        }
    });
    if (fn != NULL) {
        fn(shows);
    }
}
