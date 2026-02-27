// Copyright (c) 2026 Alex Fabri
// https://crtplus.fromhelloworld.com
// https://github.com/hotbit9

#ifndef NATIVEALERT_H
#define NATIVEALERT_H

#include <QObject>
#include <QString>

class NativeAlert : public QObject {
    Q_OBJECT
public:
    explicit NativeAlert(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE void message(const QString &title, const QString &text);
    Q_INVOKABLE bool confirm(const QString &title, const QString &text,
                              const QString &okLabel = QStringLiteral("OK"));
    Q_INVOKABLE QString prompt(const QString &title, const QString &label,
                                const QString &defaultValue = QString());
};

#endif // NATIVEALERT_H
