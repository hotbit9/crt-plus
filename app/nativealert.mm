// Copyright (c) 2026 Alex Fabri
// https://crtplus.fromhelloworld.com
// https://github.com/hotbit9

#include "nativealert.h"
#import <AppKit/AppKit.h>

void NativeAlert::message(const QString &title, const QString &text)
{
    @autoreleasepool {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleInformational;
        alert.messageText = title.toNSString();
        alert.informativeText = text.toNSString();
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
    }
}

bool NativeAlert::confirm(const QString &title, const QString &text,
                           const QString &okLabel)
{
    @autoreleasepool {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleWarning;
        alert.messageText = title.toNSString();
        alert.informativeText = text.toNSString();
        [alert addButtonWithTitle:okLabel.toNSString()];
        [alert addButtonWithTitle:@"Cancel"];
        return [alert runModal] == NSAlertFirstButtonReturn;
    }
}

QString NativeAlert::prompt(const QString &title, const QString &label,
                             const QString &defaultValue)
{
    @autoreleasepool {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.alertStyle = NSAlertStyleInformational;
        alert.messageText = title.toNSString();
        alert.informativeText = label.toNSString();
        [alert addButtonWithTitle:@"OK"];
        [alert addButtonWithTitle:@"Cancel"];

        NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 280, 24)];
        input.stringValue = defaultValue.toNSString();
        alert.accessoryView = input;

        [alert layout];
        [alert.window makeFirstResponder:input];
        [input selectText:nil];

        if ([alert runModal] == NSAlertFirstButtonReturn) {
            return QString::fromNSString(input.stringValue);
        }
        return QString();
    }
}
