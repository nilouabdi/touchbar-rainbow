// Touch Bar Rainbow
// Copyright (C) 2026 nilouabdi
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Thin, defensive wrappers around the private macOS APIs that let a background app put its own
// Touch Bar on screen on top of the frontmost app's Touch Bar ("system-modal" Touch Bar).
// The same APIs are used by MTMR and Pock. Every function checks availability at runtime and
// becomes a no-op if the API is missing, so a future macOS cannot crash the app.

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// YES if this macOS exposes the system-modal Touch Bar API.
BOOL TBRSystemModalTouchBarAvailable(void);

/// Presents `touchBar` above the frontmost app's Touch Bar.
/// `fullWidth` hides the Control Strip so the bar spans the whole Touch Bar.
void TBRPresentSystemModalTouchBar(NSTouchBar *touchBar, BOOL fullWidth, NSTouchBarItemIdentifier _Nullable trayIdentifier);

/// Removes a Touch Bar previously shown with `TBRPresentSystemModalTouchBar`.
void TBRDismissSystemModalTouchBar(NSTouchBar *touchBar);

/// Hides the little "x" close box the system draws next to a system-modal Touch Bar.
void TBRSetShowsCloseBox(BOOL shows);

NS_ASSUME_NONNULL_END
