QT += qml quick widgets sql quickcontrols2 network
TARGET = crt-plus
APP_VERSION = $$system(git -C \"$$PWD/..\" describe --tags --abbrev=0 2>/dev/null)
isEmpty(APP_VERSION): APP_VERSION = "unknown"
DEFINES += APP_VERSION=\\\"$$APP_VERSION\\\"

DESTDIR = $$OUT_PWD/../

INCLUDEPATH += $$PWD/../qmltermwidget/lib
INCLUDEPATH += $$PWD/../daemon
LIBS += -L$$OUT_PWD/../qmltermwidget/QMLTermWidget -lqmltermwidget

HEADERS += \
    fileio.h \
    fontmanager.h \
    fontlistmodel.h \
    daemonlauncher.h \
    sessionmanagerbackend.h

SOURCES += main.cpp \
    fileio.cpp \
    fontmanager.cpp \
    fontlistmodel.cpp \
    daemonlauncher.cpp \
    sessionmanagerbackend.cpp

macx {
    HEADERS += macutils.h badgehelper.h
    OBJECTIVE_SOURCES += macutils.mm
    LIBS += -framework AppKit
    # Set display name to "CRT Plus" (Finder shows this instead of the binary name)
    QMAKE_POST_LINK += /usr/libexec/PlistBuddy -c \"Set :CFBundleDisplayName 'CRT Plus'\" \"$$DESTDIR/crt-plus.app/Contents/Info.plist\" 2>/dev/null || /usr/libexec/PlistBuddy -c \"Add :CFBundleDisplayName string 'CRT Plus'\" \"$$DESTDIR/crt-plus.app/Contents/Info.plist\" ;
    QMAKE_POST_LINK += /usr/libexec/PlistBuddy -c \"Set :CFBundleName 'CRT Plus'\" \"$$DESTDIR/crt-plus.app/Contents/Info.plist\" 2>/dev/null || /usr/libexec/PlistBuddy -c \"Add :CFBundleName string 'CRT Plus'\" \"$$DESTDIR/crt-plus.app/Contents/Info.plist\" ;
    # Dev bundle identifier so it can run alongside the stable version
    QMAKE_POST_LINK += /usr/libexec/PlistBuddy -c \"Set :CFBundleIdentifier com.crt-plus-dev\" \"$$DESTDIR/crt-plus.app/Contents/Info.plist\" ;
    # Start as LSUIElement (no dock icon). Primary instance promotes itself to Regular.
    QMAKE_POST_LINK += /usr/libexec/PlistBuddy -c \"Add :LSUIElement bool true\" \"$$DESTDIR/crt-plus.app/Contents/Info.plist\" 2>/dev/null || /usr/libexec/PlistBuddy -c \"Set :LSUIElement true\" \"$$DESTDIR/crt-plus.app/Contents/Info.plist\" ;
    # Accept folder drops on dock icon (opens new window in that directory)
    PLIST = $$DESTDIR/crt-plus.app/Contents/Info.plist
    QMAKE_POST_LINK += /usr/libexec/PlistBuddy -c \"Delete :CFBundleDocumentTypes\" \"$$PLIST\" 2>/dev/null ; /usr/libexec/PlistBuddy -c \"Add :CFBundleDocumentTypes array\" \"$$PLIST\" && /usr/libexec/PlistBuddy -c \"Add :CFBundleDocumentTypes:0 dict\" \"$$PLIST\" && /usr/libexec/PlistBuddy -c \"Add :CFBundleDocumentTypes:0:CFBundleTypeRole string Viewer\" \"$$PLIST\" && /usr/libexec/PlistBuddy -c \"Add :CFBundleDocumentTypes:0:LSItemContentTypes array\" \"$$PLIST\" && /usr/libexec/PlistBuddy -c \"Add :CFBundleDocumentTypes:0:LSItemContentTypes:0 string public.folder\" \"$$PLIST\" ;
    # Register as Finder Services provider (right-click folder menu)
    QMAKE_POST_LINK += /usr/libexec/PlistBuddy -c \"Delete :NSServices\" \"$$PLIST\" 2>/dev/null ; \
        /usr/libexec/PlistBuddy -c \"Add :NSServices array\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0 dict\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0:NSMessage string openFolderInTerminal\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0:NSPortName string crt-plus\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0:NSMenuItem dict\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0:NSMenuItem:default string 'New CRT Plus at Folder'\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0:NSSendFileTypes array\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0:NSSendFileTypes:0 string public.folder\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:0:NSRequiredContext dict\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1 dict\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1:NSMessage string openFolderInTab\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1:NSPortName string crt-plus\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1:NSMenuItem dict\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1:NSMenuItem:default string 'New CRT Plus Tab at Folder'\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1:NSSendFileTypes array\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1:NSSendFileTypes:0 string public.folder\" \"$$PLIST\" && \
        /usr/libexec/PlistBuddy -c \"Add :NSServices:1:NSRequiredContext dict\" \"$$PLIST\" ;
}

macx:ICON = icons/crt-plus.icns

RESOURCES += qml/resources.qrc

# Shader compilation (Qt Shader Baker)
QSB_BIN = $$[QT_HOST_BINS]/qsb
isEmpty(QSB_BIN): QSB_BIN = $$[QT_INSTALL_BINS]/qsb

SHADERS_DIR = $${_PRO_FILE_PWD_}/shaders
SHADERS += $$files($$SHADERS_DIR/*.frag) $$files($$SHADERS_DIR/*.vert)
SHADERS -= $$SHADERS_DIR/terminal_dynamic.frag
SHADERS -= $$SHADERS_DIR/terminal_static.frag
SHADERS -= $$SHADERS_DIR/passthrough.vert

qsb.input = SHADERS
qsb.output = ../../app/shaders/${QMAKE_FILE_NAME}.qsb
qsb.commands = $$QSB_BIN --glsl \"100 es,120,150\" --hlsl 50 --msl 12 --qt6 -o ${QMAKE_FILE_OUT} ${QMAKE_FILE_IN}
qsb.clean = $$qsb.output
qsb.name = qsb ${QMAKE_FILE_IN}
qsb.variable_out = QSB_FILES
QMAKE_EXTRA_COMPILERS += qsb
PRE_TARGETDEPS += $$QSB_FILES
OTHER_FILES += $$SHADERS $$QSB_FILES

DYNAMIC_SHADER = $$SHADERS_DIR/terminal_dynamic.frag
STATIC_SHADER = $$SHADERS_DIR/terminal_static.frag

RASTER_MODES = 0 1 2 3 4
BINARY_FLAGS = 0 1
VARIANT_SHADER_DIR = $$relative_path($$PWD/shaders, $$OUT_PWD)
VARIANT_OUTPUTS =

for(raster_mode, RASTER_MODES) {
    for(burn_in, BINARY_FLAGS) {
        for(display_frame, BINARY_FLAGS) {
            for(chroma_on, BINARY_FLAGS) {
                dynamic_variant = terminal_dynamic_raster$${raster_mode}_burn$${burn_in}_frame$${display_frame}_chroma$${chroma_on}
                dynamic_output = $${VARIANT_SHADER_DIR}/$${dynamic_variant}.frag.qsb
                dynamic_target = shader_variant_$${dynamic_variant}
                $${dynamic_target}.target = $${dynamic_output}
                $${dynamic_target}.depends = $$DYNAMIC_SHADER
                $${dynamic_target}.commands = $$QSB_BIN --glsl \"100 es,120,150\" --hlsl 50 --msl 12 --qt6 -DCRT_RASTER_MODE=$${raster_mode} -DCRT_BURN_IN=$${burn_in} -DCRT_DISPLAY_FRAME=$${display_frame} -DCRT_CHROMA=$${chroma_on} -o $${dynamic_output} $$DYNAMIC_SHADER
                QMAKE_EXTRA_TARGETS += $${dynamic_target}
                VARIANT_OUTPUTS += $${dynamic_output}
            }
        }
    }
}

for(rgb_shift, BINARY_FLAGS) {
    for(bloom_on, BINARY_FLAGS) {
        for(curve_on, BINARY_FLAGS) {
            for(shine_on, BINARY_FLAGS) {
                static_variant = terminal_static_rgb$${rgb_shift}_bloom$${bloom_on}_curve$${curve_on}_shine$${shine_on}
                static_output = $${VARIANT_SHADER_DIR}/$${static_variant}.frag.qsb
                static_target = shader_variant_$${static_variant}
                $${static_target}.target = $${static_output}
                $${static_target}.depends = $$STATIC_SHADER
                $${static_target}.commands = $$QSB_BIN --glsl \"100 es,120,150\" --hlsl 50 --msl 12 --qt6 -DCRT_RGB_SHIFT=$${rgb_shift} -DCRT_BLOOM=$${bloom_on} -DCRT_CURVATURE=$${curve_on} -DCRT_FRAME_SHININESS=$${shine_on} -o $${static_output} $$STATIC_SHADER
                QMAKE_EXTRA_TARGETS += $${static_target}
                VARIANT_OUTPUTS += $${static_output}
            }
        }
    }
}
PRE_TARGETDEPS += $${VARIANT_OUTPUTS}

#########################################
##              INTALLS
#########################################

target.path += /usr/bin/

INSTALLS += target

# Install icons
unix {
    icon32.files = icons/32x32/crt-plus.png
    icon32.path = /usr/share/icons/hicolor/32x32/apps
    icon64.files = icons/64x64/crt-plus.png
    icon64.path = /usr/share/icons/hicolor/64x64/apps
    icon128.files = icons/128x128/crt-plus.png
    icon128.path = /usr/share/icons/hicolor/128x128/apps
    icon256.files = icons/256x256/crt-plus.png
    icon256.path = /usr/share/icons/hicolor/256x256/apps

    INSTALLS += icon32 icon64 icon128 icon256
}
