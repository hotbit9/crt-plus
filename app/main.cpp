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
#include <stdlib.h>

#include <QLoggingCategory>

#include <fileio.h>
#include <fontlistmodel.h>
#include <fontmanager.h>
#include "daemonlauncher.h"
#include "sessionmanagerbackend.h"

#if defined(Q_OS_MAC)
#include <CoreFoundation/CoreFoundation.h>
#include <QFileOpenEvent>
#include <QStyleFactory>
#include <QMenu>
#include <macutils.h>
#include "badgehelper.h"
#endif

// App-level event filter for two purposes:
// 1. QEvent::Quit: calls markQuitting() to set _isQuitting and save state
//    before tryCloseAllWindows() fires onClosing on each window.
// 2. QEvent::FileOpen (macOS): opens a new window when a folder is dragged
//    onto the dock icon.
class AppEventFilter : public QObject {
public:
    AppEventFilter(QObject *rootObject, QObject *parent = nullptr)
        : QObject(parent), m_rootObject(rootObject), m_quitHandled(false) {}
protected:
    bool eventFilter(QObject *obj, QEvent *event) override {
#if defined(Q_OS_MAC)
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
#endif
        if (event->type() == QEvent::Quit && !m_quitHandled) {
            m_quitHandled = true;
            QMetaObject::invokeMethod(m_rootObject, "markQuitting");
        }
        return QObject::eventFilter(obj, event);
    }
private:
    QObject *m_rootObject;
    bool m_quitHandled;
};

QString getNamedArgument(QStringList args, QString name, QString defaultName)
{
    int index = args.indexOf(name);
    return (index != -1 && index + 1 < args.size()) ? args[index + 1] : QString(defaultName);
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

    // Ensure daemon is running before we create any terminals
    DaemonLauncher::ensureDaemonRunning();

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

    SessionManagerBackend sessionMgr;
    engine.rootContext()->setContextProperty("sessionManager", &sessionMgr);

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

    // Session persistence on quit:
    // - AppEventFilter intercepts QEvent::Quit to call markQuitting()
    // - aboutToQuit calls saveSessionState() as a fallback
    // - closeWindow() preserves last-window sessions independently
    {
        QObject *rootObj = engine.rootObjects().first();
        // Install quit interceptor as app-level event filter
        auto *quitFilter = new AppEventFilter(rootObj, &app);
        app.installEventFilter(quitFilter);
        QObject::connect(&app, &QCoreApplication::aboutToQuit, [rootObj]() {
            QMetaObject::invokeMethod(rootObj, "saveSessionState");
        });
    }

#if defined(Q_OS_MAC)
    {
        QObject *rootObject = engine.rootObjects().first();
        QMenu *dockMenu = new QMenu(nullptr);
        dockMenu->addAction(QObject::tr("New Window"), [rootObject]() {
            QMetaObject::invokeMethod(rootObject, "createWindow",
                                      Q_ARG(QVariant, QString()),
                                      Q_ARG(QVariant, QString()));
        });

        // "New Pane" splits the focused pane below. Holding Option shows
        // "New Pane Right" via native macOS alternate menu item (splits right).
        dockMenu->addAction(QObject::tr("New Pane"), [rootObject]() {
            QMetaObject::invokeMethod(rootObject, "splitFocusedPane",
                                      Q_ARG(QVariant, (int)Qt::Vertical));
        });
        QAction *newPaneRightAction = dockMenu->addAction(QObject::tr("New Pane Right"), [rootObject]() {
            QMetaObject::invokeMethod(rootObject, "splitFocusedPane",
                                      Q_ARG(QVariant, (int)Qt::Horizontal));
        });

        dockMenu->addSeparator();
        QAction *renameWindowAction = dockMenu->addAction(QObject::tr("Rename Window…"), [rootObject]() {
            QMetaObject::invokeMethod(rootObject, "renameActiveWindow");
        });
        QAction *resetWindowNameAction = dockMenu->addAction(QObject::tr("Reset Window Name"), [rootObject]() {
            QMetaObject::invokeMethod(rootObject, "resetActiveWindowTitle");
        });

        // Dynamically enable/disable based on active window state
        QObject::connect(dockMenu, &QMenu::aboutToShow, [rootObject, renameWindowAction, resetWindowNameAction]() {
            QVariant hasTabs, hasCustomTitle;
            QMetaObject::invokeMethod(rootObject, "activeWindowHasTabs",
                                      Q_RETURN_ARG(QVariant, hasTabs));
            QMetaObject::invokeMethod(rootObject, "activeWindowHasCustomTitle",
                                      Q_RETURN_ARG(QVariant, hasCustomTitle));
            renameWindowAction->setEnabled(hasTabs.toBool());
            resetWindowNameAction->setEnabled(hasCustomTitle.toBool());
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
                                          Q_ARG(QVariant, profileString),
                                          Q_ARG(QVariant, QString()));
            });
        }

        dockMenu->setAsDockMenu();
        markAsAlternate(dockMenu, newPaneRightAction);

        // Register as a Finder Services provider ("New CRT Plus Window Here")
        registerServiceProvider(rootObject);
    }
#endif

    return app.exec();
}
