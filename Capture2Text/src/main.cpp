/*
Copyright (C) 2010-2017 Christopher Brochtrup

This file is part of Capture2Text.

Capture2Text is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Capture2Text is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Capture2Text.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "CommandLine.h"
#include <QGuiApplication>
#include <QtGlobal>
#include <QtDebug>
#include <QTextStream>
#include <QLocale>
#include <QTime>
#include <QFile>

const QString logFilePath = "log.txt";
bool logToFile = false;

void customMessageOutput(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    QHash<QtMsgType, QString> msgLevelHash({{QtDebugMsg, "Debug"}, {QtInfoMsg, "Info"}, {QtWarningMsg, "Warning"}, {QtCriticalMsg, "Critical"}, {QtFatalMsg, "Fatal"}});
    QByteArray localMsg = msg.toLocal8Bit();
    QTime time = QTime::currentTime();
    QString formattedTime = time.toString("hh:mm:ss.zzz");
    QByteArray formattedTimeMsg = formattedTime.toLocal8Bit();
    QString logLevelName = msgLevelHash[type];
    QByteArray logLevelMsg = logLevelName.toLocal8Bit();

    if (logToFile) {
        QString txt = QString("%1 %2: %3 (%4)").arg(formattedTime, logLevelName, msg,  context.file);
        QFile outFile(logFilePath);
        outFile.open(QIODevice::WriteOnly | QIODevice::Append);
        QTextStream ts(&outFile);
        ts << txt << Qt::endl;
        outFile.close();
    } else {
        fprintf(stderr, "%s %s: %s (%s:%u, %s)\n", formattedTimeMsg.constData(), logLevelMsg.constData(), localMsg.constData(), context.file, context.line, context.function);
        fflush(stderr);
    }

    if (type == QtFatalMsg)
        abort();
}

int main(int argc, char *argv[])
{
    QByteArray envVar = qgetenv("QTDIR");       //  check if the app is ran in Qt Creator

    if (envVar.isEmpty())
        logToFile = true;

    qInstallMessageHandler(customMessageOutput); // custom message handler for debugging

    /* From http://www.qtcentre.org/threads/60203-QApplication-QGuiApplication-and-QCoreApplication:
       "QCoreApplication is the base class, QGuiApplication extends the base class with functionality
       related to handling windows and GUI stuff (non-widget related, e.g. OpenGL or QtQuick),
       QApplication extends QGuiApplication with functionality related to handling widgets." */
    QGuiApplication  app(argc, argv);

    QCoreApplication::setOrganizationName("Capture2Text");
    QCoreApplication::setOrganizationDomain("Capture2Text.com");
    QCoreApplication::setApplicationName("Capture2Text");
    QCoreApplication::setApplicationVersion("4.6.2");

    CommandLine cmdLine;
    bool success = cmdLine.process(app);
    return (int)(!success);
}
