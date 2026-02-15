TEMPLATE = app
TARGET = crt-sessiond
CONFIG += console c++17
CONFIG -= app_bundle  # no .app bundle on macOS
QT -= gui core        # pure POSIX, no Qt at all

DESTDIR = $$OUT_PWD/../

HEADERS += log.h protocol.h uuid.h ring_buffer.h session.h server.h event_loop.h
SOURCES += main.cpp uuid.cpp ring_buffer.cpp session.cpp server.cpp event_loop.cpp

macx: LIBS += -lutil   # for openpty() on macOS
linux: LIBS += -lutil   # for openpty() on Linux
