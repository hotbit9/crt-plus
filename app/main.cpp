#include <QtQml/QQmlApplicationEngine>
#include <QtGui/QGuiApplication>

#include <QQmlContext>
#include <QStringList>

#include <QtWidgets/QApplication>
#include <QIcon>
#include <QQuickStyle>
#include <QtQml/qqml.h>

#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QFileOpenEvent>
#include <stdlib.h>

#include <QLoggingCategory>

#include <fileio.h>
#include <fontlistmodel.h>
#include <fontmanager.h>

#if defined(Q_OS_MAC)
#include <CoreFoundation/CoreFoundation.h>
#include <QStyleFactory>
#include <QMenu>
#include <macutils.h>
#include "badgehelper.h"
#endif

class FileOpenHandler : public QObject {
public:
    FileOpenHandler(QObject *rootObject, QObject *parent = nullptr)
        : QObject(parent), m_rootObject(rootObject) {}
protected:
    bool eventFilter(QObject *, QEvent *event) override {
        if (event->type() == QEvent::FileOpen) {
            auto *fileEvent = static_cast<QFileOpenEvent *>(event);
            QFileInfo info(fileEvent->file());
            if (info.isDir()) {
                QMetaObject::invokeMethod(m_rootObject, "createWindow",
                    Q_ARG(QVariant, QString("")),
                    Q_ARG(QVariant, info.absoluteFilePath()));
                return true;
            }
        }
        return false;
    }
private:
    QObject *m_rootObject;
};

QString getNamedArgument(QStringList args, QString name, QString defaultName)
{
    int index = args.indexOf(name);
    return (index != -1) ? args[index + 1] : QString(defaultName);
}

QString getNamedArgument(QStringList args, QString name)
{
    return getNamedArgument(args, name, "");
}

int main(int argc, char *argv[])
{
    // Some environmental variable are necessary on certain platforms.
    // Disable Connections slot warnings
    QLoggingCategory::setFilterRules("qt.qml.connections.warning=false");
    QGuiApplication::setHighDpiScaleFactorRoundingPolicy(Qt::HighDpiScaleFactorRoundingPolicy::Round);

// #if defined (Q_OS_LINUX)
//     setenv("QSG_RENDER_LOOP", "threaded", 0);
// #endif

#if defined(Q_OS_MAC)
    // This allows UTF-8 characters usage in OSX.
    setenv("LC_CTYPE", "UTF-8", 1);

    // Ensure key repeat works for letter keys (disable macOS press-and-hold for this app).
    CFPreferencesSetAppValue(CFSTR("ApplePressAndHoldEnabled"), kCFBooleanFalse, kCFPreferencesCurrentApplication);
    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);

    // Qt6 macOS default look is still lacking, so let's force Fusion for now
    QQuickStyle::setStyle(QStringLiteral("Fusion"));
#endif

    if (argc>1 && (!strcmp(argv[1],"-h") || !strcmp(argv[1],"--help"))) {
        QTextStream cout(stdout, QIODevice::WriteOnly);
        cout << "Usage: " << argv[0] << " [--default-settings] [--workdir <dir>] [--program <prog>] [-p|--profile <prof>] [--fullscreen] [-h|--help]" << Qt::endl;
        cout << "  --default-settings  Run cool-retro-term with the default settings" << Qt::endl;
        cout << "  --workdir <dir>     Change working directory to 'dir'" << Qt::endl;
        cout << "  -e <cmd>            Command to execute. This option will catch all following arguments, so use it as the last option." << Qt::endl;
        cout << "  --fullscreen        Run cool-retro-term in fullscreen." << Qt::endl;
        cout << "  -p|--profile <prof> Run cool-retro-term with the given profile." << Qt::endl;
        cout << "  -h|--help           Print this help." << Qt::endl;
        cout << "  --verbose           Print additional information such as profiles and settings." << Qt::endl;
        return 0;
    }

    QString appVersion(QStringLiteral(APP_VERSION));

    if (argc>1 && (!strcmp(argv[1],"-v") || !strcmp(argv[1],"--version"))) {
        QTextStream cout(stdout, QIODevice::WriteOnly);
        cout << "cool-retro-term " << appVersion << Qt::endl;
        return 0;
    }

    QApplication app(argc, argv);
    app.setAttribute(Qt::AA_MacDontSwapCtrlAndMeta, true);

#if defined(Q_OS_MAC)
    setRegularApp();
#endif

    app.setApplicationName(QStringLiteral("crt-plus"));
    app.setOrganizationName(QStringLiteral("crt-plus"));
    app.setOrganizationDomain(QStringLiteral("crt-plus"));
    app.setApplicationVersion(appVersion);

    QQmlApplicationEngine engine;
    FileIO fileIO;

    qmlRegisterType<FontManager>("CoolRetroTerm", 1, 0, "FontManager");
    qmlRegisterUncreatableType<FontListModel>("CoolRetroTerm", 1, 0, "FontListModel", "FontListModel is created by FontManager");

#if !defined(Q_OS_MAC)
    app.setWindowIcon(QIcon::fromTheme("crt-plus", QIcon(":../icons/32x32/crt-plus.png")));
#if defined(Q_OS_LINUX)
    QGuiApplication::setDesktopFileName(QStringLiteral("crt-plus"));
#endif
#else
    app.setWindowIcon(QIcon(":../icons/32x32/crt-plus.png"));
#endif

    // Manage command line arguments from the cpp side
    QStringList args = app.arguments();

    // Manage default command
    QStringList cmdList;
    if (args.contains("-e")) {
        cmdList << args.mid(args.indexOf("-e") + 1);
    }
    QVariant command(cmdList.empty() ? QVariant() : cmdList[0]);
    QVariant commandArgs(cmdList.size() <= 1 ? QVariant() : QVariant(cmdList.mid(1)));
    engine.rootContext()->setContextProperty("appVersion", appVersion);
    engine.rootContext()->setContextProperty("defaultCmd", command);
    engine.rootContext()->setContextProperty("defaultCmdArgs", commandArgs);

    engine.rootContext()->setContextProperty("workdir", getNamedArgument(args, "--workdir", "$HOME"));
    engine.rootContext()->setContextProperty("homeDir", QDir::homePath());
    engine.rootContext()->setContextProperty("fileIO", &fileIO);

#if defined(Q_OS_MAC)
    BadgeHelper badgeHelper;
    engine.rootContext()->setContextProperty("badgeHelper", &badgeHelper);
#endif

    // Manage import paths for Linux and OSX.
    QStringList importPathList = engine.importPathList();
    importPathList.append(QCoreApplication::applicationDirPath() + "/qmltermwidget");
    importPathList.append(QCoreApplication::applicationDirPath() + "/../PlugIns");
    importPathList.append(QCoreApplication::applicationDirPath() + "/../../../qmltermwidget");
    engine.setImportPathList(importPathList);

    engine.load(QUrl(QStringLiteral ("qrc:/main.qml")));

    if (engine.rootObjects().isEmpty()) {
        qDebug() << "Cannot load QML interface";
        return EXIT_FAILURE;
    }

    // Quit the application when the engine closes.
    QObject::connect((QObject*) &engine, SIGNAL(quit()), (QObject*) &app, SLOT(quit()));

#if defined(Q_OS_MAC)
    {
        QObject *rootObject = engine.rootObjects().first();
        QMenu *dockMenu = new QMenu(nullptr);
        dockMenu->addAction(QObject::tr("New Window"), [rootObject]() {
            QMetaObject::invokeMethod(rootObject, "createWindow", Q_ARG(QVariant, QString()));
        });

        QMenu *profilesMenu = dockMenu->addMenu(QObject::tr("New Window with Profile"));
        QVariant returnValue;
        QMetaObject::invokeMethod(rootObject, "getProfileList",
                                  Q_RETURN_ARG(QVariant, returnValue));
        QVariantList profiles = returnValue.toList();
        for (const QVariant &item : profiles) {
            QVariantMap profile = item.toMap();
            QString name = profile["name"].toString();
            QString profileString = profile["profileString"].toString();
            profilesMenu->addAction(name, [rootObject, profileString]() {
                QMetaObject::invokeMethod(rootObject, "createWindow",
                                          Q_ARG(QVariant, profileString));
            });
        }

        dockMenu->setAsDockMenu();

        // Handle folder drag-and-drop onto the dock icon
        app.installEventFilter(new FileOpenHandler(rootObject, &app));
    }
#endif

    return app.exec();
}
