
QT += core gui
QT += concurrent

TARGET = Capture2Text_CLI

TEMPLATE = app

#CONFIG += console
# The following define makes your compiler emit warnings if you use
# any feature of Qt which as been marked as deprecated (the exact warnings
# depend on your compiler). Please consult the documentation of the
# deprecated API in order to know how to port your code away from it.
DEFINES += QT_DEPRECATED_WARNINGS

# Disable warning: C4305: 'initializing': truncation from 'double' to 'l_float32'
#QMAKE_CXXFLAGS += /wd4305

# Disable warning: C4099: 'ETEXT_DESC': type name first seen using 'class' now seen using 'struct'
#QMAKE_CXXFLAGS += /wd4099

#DEFINES += CLI_BUILD

# You can also make your code fail to compile if you use deprecated APIs.
# In order to do so, uncomment the following line.
# You can also select to disable deprecated APIs only up to a certain version of Qt.
#DEFINES += QT_DISABLE_DEPRECATED_BEFORE=0x060000    # disables all the APIs deprecated before Qt 6.0.0

SOURCES += main.cpp\
    Furigana.cpp \
    BoundingTextRect.cpp \
    #RunGuard.cpp \
    CommandLine.cpp \
    UtilsLang.cpp \
    UtilsImg.cpp \
    PostProcess.cpp \
    PreProcess.cpp \
    OcrEngine.cpp \
    UtilsCommon.cpp


HEADERS  += \
    Furigana.h \
    BoundingTextRect.h \
    CommandLine.h \
    UtilsLang.h \
    UtilsImg.h \
    PostProcess.h \
    PreProcess.h \
    PreProcessCommon.h \
    OcrEngine.h \
    UtilsCommon.h

INCLUDEPATH += C:\msys64\mingw64\include\tesseract
#INCLUDEPATH += C:\Alex\Private\Development\tesseract-5.0.1\src\ccmain
#INCLUDEPATH += C:\Alex\Private\Development\tesseract-5.0.1\src\ccstruct
#INCLUDEPATH += C:\Alex\Private\Development\tesseract-5.0.1\src\ccutil
INCLUDEPATH += C:\msys64\mingw64\include\leptonica

# Tesseract and Leptonica
bits32 {
    # 32-bit
    win32:CONFIG(release, debug|release): LIBS += -LC:\msys64\mingw64\bin \
        -LC:\msys64\mingw64\bin \
        -llibtesseract-0
    else:win32:CONFIG(debug, debug|release): LIBS += -LC:\msys64\mingw64\bin \
        -LC:\msys64\mingw64\bin \
        -llibtesseract-0

} else {
    # 64-bit
    win32:CONFIG(release, debug|release): LIBS += -LC:\msys64\mingw64\bin \
        -LC:\msys64\mingw64\bin \
        -llibtesseract-0
    else:win32:CONFIG(debug, debug|release): LIBS += -LC:\msys64\mingw64\bin \
        -LC:\msys64\mingw64\bin  \
        -llibtesseract-0
}


LIBS += -lliblept-5
LIBS += -luser32

# Needed for the icon
RC_FILE = Capture2Text.rc
