#import "SPKWhatsNewViewController.h"
#import "../Tweak.h"
#import "../Utils.h"

@implementation SPKWhatsNewViewController

// Release notes are curated from the conventional-commit log for the release range
// (see whats-new.sh). Feature rows carry a per-surface IG catalog glyph; fix rows
// share the `subtract` bullet so they read as one clean list. Icon names are
// SPKAssetUtils override keys — never SF Symbols. Keep in sync with README/FEATURES.
- (NSArray<SPKPagedSheetPage *> *)buildPages {
    return @[
        [SPKPagedSheetPage pageWithTitle:SPKLocalizedString(@"New Features")
                                    body:[NSString stringWithFormat:SPKLocalizedString(@"What's new in %@"), SPKVersionString]
                                    rows:@[
                                        @{ @"icon": @"action", @"text": SPKLocalizedString(@"Action button for media shared in chats") },
                                        @{ @"icon": @"clock", @"text": SPKLocalizedString(@"Last-active timestamps in chats with smart formatting") },
                                        @{ @"icon": @"eye", @"text": SPKLocalizedString(@"Auto-mark seen when you start typing") },
                                        @{ @"icon": @"sort", @"text": SPKLocalizedString(@"Choose where the Seen button sits, and nudge it aside to peek") },
                                        @{ @"icon": @"search", @"text": SPKLocalizedString(@"Search your story viewer list") },
                                        @{ @"icon": @"story_preview", @"text": SPKLocalizedString(@"Peek at stories without appearing on the viewer list") },
                                        @{ @"icon": @"feed", @"text": SPKLocalizedString(@"Feed header shortcut to Gallery, Profile Analyzer & more") },
                                        @{ @"icon": @"user_check", @"text": SPKLocalizedString(@"Subtle following indicator on profiles") },
                                        @{ @"icon": @"users", @"text": SPKLocalizedString(@"Clear visited profiles in Profile Analyzer") },
                                        @{ @"icon": @"info", @"text": SPKLocalizedString(@"Metadata overlay on expanded photos") },
                                        @{ @"icon": @"interface", @"text": SPKLocalizedString(@"Pill-shaped tab bar on iOS 18 and earlier") },
                                        @{ @"icon": @"haptics", @"text": SPKLocalizedString(@"Optional haptics when opening settings") },
                                        @{ @"icon": @"arrow_ccw", @"text": SPKLocalizedString(@"Reset any configurable settings group to its defaults") },
                                    ]],
        [SPKPagedSheetPage pageWithTitle:SPKLocalizedString(@"Fixes & Improvements")
                                    body:@""
                                    rows:@[
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"Sharper video downloads on the default encoding preset") },
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"Cleaned-up links no longer escape special characters") },
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"No more duplicate comment-like confirmations") },
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"Clearing download history reclaims its storage") },
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"Action buttons & enhanced media resolution are now on by default") },
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"TestFlight popup hidden by default") },
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"Reset All Settings is now scoped per account") },
                                        @{ @"icon": @"subtract", @"text": SPKLocalizedString(@"Other bug fixes & UI improvements") },
                                    ]],
    ];
}

- (NSString *)finishButtonTitle {
    return SPKLocalizedString(@"Done");
}

- (BOOL)allowsInteractiveDismiss {
    return YES;
}

@end
