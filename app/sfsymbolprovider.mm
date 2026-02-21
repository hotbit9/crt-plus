/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://crtplus.fromhelloworld.com
* https://github.com/hotbit9
*
* This file is part of CRT Plus.
*
* CRT Plus is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*******************************************************************************/
#include "sfsymbolprovider.h"

#import <Cocoa/Cocoa.h>
#include <QPixmap>
#include <QUrlQuery>

SFSymbolProvider::SFSymbolProvider()
    : QQuickImageProvider(QQuickImageProvider::Pixmap)
{
}

QPixmap SFSymbolProvider::requestPixmap(const QString &id, QSize *size, const QSize &requestedSize)
{
    // Parse "symbolName?size=16"
    QString symbolName = id;
    int pointSize = 16;

    bool dark = false;

    int queryIdx = id.indexOf('?');
    if (queryIdx != -1) {
        symbolName = id.left(queryIdx);
        QUrlQuery query(id.mid(queryIdx + 1));
        if (query.hasQueryItem("size"))
            pointSize = query.queryItemValue("size").toInt();
        if (query.hasQueryItem("dark"))
            dark = query.queryItemValue("dark").toInt() != 0;
    }

    if (requestedSize.width() > 0)
        pointSize = requestedSize.width();

    @autoreleasepool {
        NSString *name = symbolName.toNSString();
        NSImage *symbol = [NSImage imageWithSystemSymbolName:name
                                    accessibilityDescription:nil];
        if (!symbol) {
            if (size) *size = QSize(pointSize, pointSize);
            return QPixmap(pointSize, pointSize);
        }

        // Set appearance so palette rendering matches the current theme
        NSAppearance *savedAppearance = [NSAppearance currentAppearance];
        NSAppearance *targetAppearance = [NSAppearance appearanceNamed:
            dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
        [NSAppearance setCurrentAppearance:targetAppearance];

        // Palette config: two-color palette for bell.badge.fill —
        // red for the badge dot, theme-adapted gray for the bell body.
        NSColor *bellColor = dark
            ? [NSColor colorWithWhite:0.9 alpha:1.0]
            : [NSColor colorWithWhite:0.45 alpha:1.0];
        NSImageSymbolConfiguration *config =
            [NSImageSymbolConfiguration configurationWithPointSize:pointSize
                                                            weight:NSFontWeightRegular
                                                             scale:NSImageSymbolScaleMedium];
        config = [config configurationByApplyingConfiguration:
            [NSImageSymbolConfiguration configurationWithPaletteColors:
                @[[NSColor systemRedColor], bellColor]]];
        symbol = [symbol imageWithSymbolConfiguration:config];

        // Render at 2x for Retina. CGBitmapContext gives us full control
        // over coordinate flipping and color space on all display types.
        NSSize imgSize = symbol.size;
        CGFloat scale = 2.0;  // Retina
        int pw = (int)ceil(imgSize.width * scale);
        int ph = (int)ceil(imgSize.height * scale);
        if (pw <= 0 || ph <= 0) {
            [NSAppearance setCurrentAppearance:savedAppearance];
            if (size) *size = QSize(pointSize, pointSize);
            return QPixmap(pointSize, pointSize);
        }

        // Draw into a CGBitmapContext (flipped for top-left origin)
        CGColorSpaceRef cs = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef ctx = CGBitmapContextCreate(NULL, pw, ph, 8, pw * 4,
            cs, kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(cs);
        if (!ctx) {
            [NSAppearance setCurrentAppearance:savedAppearance];
            if (size) *size = QSize(pointSize, pointSize);
            return QPixmap(pointSize, pointSize);
        }

        // NSGraphicsContext from CGContext for NSImage drawing
        NSGraphicsContext *nsCtx = [NSGraphicsContext graphicsContextWithCGContext:ctx flipped:YES];
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:nsCtx];

        // Scale transform for Retina (context is already flipped via graphicsContextWithCGContext:flipped:YES)
        NSAffineTransform *xform = [NSAffineTransform transform];
        [xform scaleXBy:scale yBy:scale];
        [xform concat];

        [symbol drawInRect:NSMakeRect(0, 0, imgSize.width, imgSize.height)
                  fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
                  fraction:1.0];

        [NSGraphicsContext restoreGraphicsState];
        [NSAppearance setCurrentAppearance:savedAppearance];

        CGImageRef cgImage = CGBitmapContextCreateImage(ctx);
        CGContextRelease(ctx);

        QImage qImage(pw, ph, QImage::Format_RGBA8888_Premultiplied);
        qImage.fill(Qt::transparent);

        // Draw CGImage into QImage via a temporary CGContext backed by QImage data
        CGColorSpaceRef cs2 = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef drawCtx = CGBitmapContextCreate(
            qImage.bits(), pw, ph, 8, qImage.bytesPerLine(),
            cs2, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
        CGColorSpaceRelease(cs2);

        if (drawCtx) {
            CGContextDrawImage(drawCtx, CGRectMake(0, 0, pw, ph), cgImage);
            CGContextRelease(drawCtx);
        }
        CGImageRelease(cgImage);

        QPixmap pixmap = QPixmap::fromImage(qImage);
        pixmap.setDevicePixelRatio(scale);

        QSize logicalSize(qRound(imgSize.width), qRound(imgSize.height));
        if (size) *size = logicalSize;
        return pixmap;
    }
}
