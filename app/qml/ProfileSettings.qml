/*******************************************************************************
* Copyright (c) 2026 "Alex Fabri"
* https://fromhelloworld.com
* https://github.com/hotbit9/cool-retro-term
*
* This file is part of cool-retro-term.
*
* cool-retro-term is free software: you can redistribute it and/or modify
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
import QtQuick 2.2
import CoolRetroTerm 1.0

import "utils.js" as Utils

QtObject {
    id: profileSettings

    property bool _syncing: false

    // RAW PROFILE PROPERTIES (same names/defaults as appSettings)
    property string _backgroundColor: "#000000"
    property string _fontColor: "#ff8100"
    property string _frameColor: "#ffffff"
    property real flickering: 0.1
    property real horizontalSync: 0.08
    property real staticNoise: 0.12
    property real chromaColor: 0.25
    property real saturationColor: 0.25
    property real screenCurvature: 0.3
    property real glowingLine: 0.2
    property real burnIn: 0.25
    property real bloom: 0.55
    property real jitter: 0.2
    property real rgbShift: 0.0
    property real brightness: 0.5
    property real contrast: 0.80
    property bool highImpedance: false
    property real ambientLight: 0.2
    property real windowOpacity: 1.0
    property real _margin: 0.5
    property real _frameSize: 0.2
    property real _screenRadius: 0.2
    property real _frameShininess: 0.2
    property bool solidFrameColor: false  // Use frame color directly instead of mixing with font/background
    property bool flatFrame: false  // Flat solid color without 3D bevel shading
    property bool blinkingCursor: false
    property int currentProfileIndex: -1

    // Font properties aliased to own FontManager
    property alias rasterization: fontManager.rasterization
    property alias fontSource: fontManager.fontSource
    property alias fontName: fontManager.fontName
    property alias fontWidth: fontManager.fontWidth
    property alias lineSpacing: fontManager.lineSpacing

    // COMPUTED PROPERTIES (replicated from ApplicationSettings)
    property string saturatedColor: Utils.mix(Utils.strToColor(_fontColor), Utils.strToColor("#FFFFFF"), (saturationColor * 0.5))
    readonly property real effectiveBrightness: highImpedance ? Math.min(1.0, brightness + 0.35) : brightness
    readonly property real effectiveBloom: highImpedance ? Math.min(1.0, bloom + 0.3) : bloom
    property color fontColor: Utils.mix(Utils.strToColor(_backgroundColor), Utils.strToColor(saturatedColor), (0.7 + (contrast * 0.3)))
    property color backgroundColor: Utils.mix(Utils.strToColor(saturatedColor), Utils.strToColor(_backgroundColor), (0.7 + (contrast * 0.3)))

    property color frameColor: Utils.strToColor(_frameColor)

    property real frameShininess: _frameShininess * 0.5
    property real frameSize: _frameSize * 0.075
    property real screenRadius: Utils.lint(4.0, 120.0, _screenRadius)
    property real margin: Utils.lint(1.0, 40.0, _margin) + (1.0 - Math.SQRT1_2) * screenRadius
    readonly property bool frameEnabled: ambientLight > 0 || _frameSize > 0 || screenCurvature > 0

    // OWN FONT MANAGER
    property FontManager fontManager: FontManager {
        id: fontManager
        baseFontScaling: appSettings.baseFontScaling
        fontScaling: appSettings.fontScaling
    }

    signal profileChanged()

    function stringify(obj) {
        var replacer = function (key, val) {
            return val.toFixed ? Number(val.toFixed(4)) : val
        }
        return JSON.stringify(obj, replacer, 2)
    }

    function composeProfileObject() {
        var profile = {
            "backgroundColor": _backgroundColor,
            "fontColor": _fontColor,
            "flickering": flickering,
            "horizontalSync": horizontalSync,
            "staticNoise": staticNoise,
            "chromaColor": chromaColor,
            "saturationColor": saturationColor,
            "screenCurvature": screenCurvature,
            "glowingLine": glowingLine,
            "burnIn": burnIn,
            "bloom": bloom,
            "rasterization": rasterization,
            "jitter": jitter,
            "rgbShift": rgbShift,
            "brightness": brightness,
            "contrast": contrast,
            "highImpedance": highImpedance,
            "ambientLight": ambientLight,
            "windowOpacity": windowOpacity,
            "fontName": fontName,
            "fontSource": fontSource,
            "fontWidth": fontWidth,
            "lineSpacing": lineSpacing,
            "margin": _margin,
            "blinkingCursor": blinkingCursor,
            "frameSize": _frameSize,
            "screenRadius": _screenRadius,
            "frameColor": _frameColor,
            "frameShininess": _frameShininess,
            "solidFrameColor": solidFrameColor,
            "flatFrame": flatFrame
        }
        return profile
    }

    function composeProfileString() {
        return stringify(composeProfileObject())
    }

    function loadFromString(profileString) {
        if (!profileString || profileString === "") return
        var s = JSON.parse(profileString)

        _backgroundColor = s.backgroundColor !== undefined ? s.backgroundColor : _backgroundColor
        _fontColor = s.fontColor !== undefined ? s.fontColor : _fontColor
        horizontalSync = s.horizontalSync !== undefined ? s.horizontalSync : horizontalSync
        flickering = s.flickering !== undefined ? s.flickering : flickering
        staticNoise = s.staticNoise !== undefined ? s.staticNoise : staticNoise
        chromaColor = s.chromaColor !== undefined ? s.chromaColor : chromaColor
        saturationColor = s.saturationColor !== undefined ? s.saturationColor : saturationColor
        screenCurvature = s.screenCurvature !== undefined ? s.screenCurvature : screenCurvature
        glowingLine = s.glowingLine !== undefined ? s.glowingLine : glowingLine
        burnIn = s.burnIn !== undefined ? s.burnIn : burnIn
        bloom = s.bloom !== undefined ? s.bloom : bloom
        rasterization = s.rasterization !== undefined ? s.rasterization : rasterization
        jitter = s.jitter !== undefined ? s.jitter : jitter
        rgbShift = s.rgbShift !== undefined ? s.rgbShift : rgbShift
        ambientLight = s.ambientLight !== undefined ? s.ambientLight : ambientLight
        contrast = s.contrast !== undefined ? s.contrast : contrast
        brightness = s.brightness !== undefined ? s.brightness : brightness
        highImpedance = s.highImpedance !== undefined ? s.highImpedance : highImpedance
        windowOpacity = s.windowOpacity !== undefined ? s.windowOpacity : windowOpacity
        fontSource = s.fontSource !== undefined ? s.fontSource : fontSource
        fontName = s.fontName !== undefined ? s.fontName : fontName
        fontWidth = s.fontWidth !== undefined ? s.fontWidth : fontWidth
        lineSpacing = s.lineSpacing !== undefined ? s.lineSpacing : lineSpacing
        _margin = s.margin !== undefined ? s.margin : _margin
        _frameSize = s.frameSize !== undefined ? s.frameSize : _frameSize
        _screenRadius = s.screenRadius !== undefined ? s.screenRadius : _screenRadius
        _frameColor = s.frameColor !== undefined ? s.frameColor : _frameColor
        _frameShininess = s.frameShininess !== undefined ? s.frameShininess : _frameShininess
        solidFrameColor = s.solidFrameColor !== undefined ? s.solidFrameColor : false
        flatFrame = s.flatFrame !== undefined ? s.flatFrame : false
        blinkingCursor = s.blinkingCursor !== undefined ? s.blinkingCursor : blinkingCursor

        profileChanged()
    }

    function syncFromAppSettings() {
        _syncing = true

        _backgroundColor = appSettings._backgroundColor
        _fontColor = appSettings._fontColor
        _frameColor = appSettings._frameColor
        flickering = appSettings.flickering
        horizontalSync = appSettings.horizontalSync
        staticNoise = appSettings.staticNoise
        chromaColor = appSettings.chromaColor
        saturationColor = appSettings.saturationColor
        screenCurvature = appSettings.screenCurvature
        glowingLine = appSettings.glowingLine
        burnIn = appSettings.burnIn
        bloom = appSettings.bloom
        jitter = appSettings.jitter
        rgbShift = appSettings.rgbShift
        brightness = appSettings.brightness
        contrast = appSettings.contrast
        highImpedance = appSettings.highImpedance
        ambientLight = appSettings.ambientLight
        windowOpacity = appSettings.windowOpacity
        _margin = appSettings._margin
        _frameSize = appSettings._frameSize
        _screenRadius = appSettings._screenRadius
        _frameShininess = appSettings._frameShininess
        solidFrameColor = appSettings.solidFrameColor
        flatFrame = appSettings.flatFrame
        blinkingCursor = appSettings.blinkingCursor
        fontSource = appSettings.fontSource
        fontName = appSettings.fontName
        fontWidth = appSettings.fontWidth
        lineSpacing = appSettings.lineSpacing
        rasterization = appSettings.rasterization
        currentProfileIndex = appSettings.currentProfileIndex

        _syncing = false
        profileChanged()
    }

    function syncToAppSettings() {
        _syncing = true

        appSettings._backgroundColor = _backgroundColor
        appSettings._fontColor = _fontColor
        appSettings._frameColor = _frameColor
        appSettings.flickering = flickering
        appSettings.horizontalSync = horizontalSync
        appSettings.staticNoise = staticNoise
        appSettings.chromaColor = chromaColor
        appSettings.saturationColor = saturationColor
        appSettings.screenCurvature = screenCurvature
        appSettings.glowingLine = glowingLine
        appSettings.burnIn = burnIn
        appSettings.bloom = bloom
        appSettings.jitter = jitter
        appSettings.rgbShift = rgbShift
        appSettings.brightness = brightness
        appSettings.contrast = contrast
        appSettings.highImpedance = highImpedance
        appSettings.ambientLight = ambientLight
        appSettings.windowOpacity = windowOpacity
        appSettings._margin = _margin
        appSettings._frameSize = _frameSize
        appSettings._screenRadius = _screenRadius
        appSettings._frameShininess = _frameShininess
        appSettings.solidFrameColor = solidFrameColor
        appSettings.flatFrame = flatFrame
        appSettings.blinkingCursor = blinkingCursor
        appSettings.fontSource = fontSource
        appSettings.fontName = fontName
        appSettings.fontWidth = fontWidth
        appSettings.lineSpacing = lineSpacing
        appSettings.rasterization = rasterization
        appSettings.currentProfileIndex = currentProfileIndex

        appSettings.profileChanged()
        _syncing = false
    }
}
