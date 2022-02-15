#NoEnv
#SingleInstance Force
SetBatchLines -1
;SetWinDelay, -1
;SetMouseDelay, -1
SetWorkingDir %A_ScriptDir% 
global version := "0.8.4"
#include <class_iAutoComplete>
#include <sortby>
#include <JSON>
; === some global variables ===
global settingsApp := {"GuiKey": ""
    , "ScanKey": ""
    , "ScanLastAreaKey": ""
    , "outStyle": 1
    , "canStream": 0
    , "CustomTextCB": 0
    , "customText": ""
    , "nick": ""
    , "selectedLeague": ""
    , "seenInstructions": 0
    , "MaxRowsCraftTable": 20
    , "monitor": 1
    , "scale": 1
    , "gui_position_x": 0
    , "gui_position_y": 0
    , "Language": "English"
    , "LeagueList": []}
global outArray := {}
global canRescan := false
global x_start := 0
global y_start := 0
global x_end := 0
global y_end := 0
global firstGuiOpen := True
global outStyle := 1
global langDDL := ""
global Vivid_Scalefruit := 0
global MonitorsDDL := ""
global ScaleEdit := ""
global GuiKeyHotkey := ""
global ScanKeyHotkey := ""
global ScanLastAreaHotkey := ""
global maxLengths := {}
global sessionLoading := False
global CraftTable := []
global needToChangeModel := True
global isLoading := True
global PID := DllCall("Kernel32\GetCurrentProcessId")

EnvGet, dir, USERPROFILE
global RoamingDir := dir . "\AppData\Roaming\PoE-HarvestVendor"

if !FileExist(RoamingDir) {
    FileCreateDir, %RoamingDir%
}

global SettingsPath := RoamingDir . "\settings.ini"
global PricesPath := RoamingDir . "\prices.ini"
global LogPath := RoamingDir . "\log.csv"
global TempPath := RoamingDir . "\temp.txt"
global tftPrices := RoamingDir . "\tftprices.json"

FileEncoding, UTF-8
;global Language := ""
global LanguageDictionary := {}
global EnglishDictionary := {}
global LanguageList := {"English": "English", "Russian": "Русский", "Korean": "한국어"}
global LanguageReverseList := {}
for k,v in LanguageList {
    LanguageReverseList[v] := k
}
global Messages := {"Korean": "사전을 찾을수 없습니다: "
    , "English": "Cant found the dictionary: "
    , "Russian": "Не могу найти словарь: "}
global IAutoComplete_Crafts := []
global CraftList := []

global TessFile := A_ScriptDir . "\Capture2Text\tessdata\configs\poe"
whitelist := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-+%,. "
global Capture2TextExe := "Capture2Text\Capture2Text_CLI.exe"
global Capture2TextOptions := " -o """ . TempPath . """" 
    . " -l English" 
    . " --whitelist """ . whitelist . """" 
    ;. " --trim-capture" 
    . " --tess-config-file """ . TessFile . """"
    ; . " --scale-factor " . scale_factor
    ;. " -d --debug-timestamp" 

global CraftNames := [["Reforge", "Reforge "]
    , ["Change", "Change "]
    , ["Reroll", "Reroll "]
    , ["Enchant", "Enchant "]
    , ["Set", "Set "]
    , ["Upgrade", "Upgrade "]
    , ["Sacrifice", "Sacrifice a|Sacrifice up"]
    , ["Randomise", "Randomise "]
    , ["Remove", "Remove "]
    , ["Fracture", "Fracture "]
    , ["Augment", "Augment "]
    , ["Synthesise", "Synthesise "]
    , ["Attempt", "Attempt "]
    , ["Improves", "Improves "]
    , ["Add", "Add a random "]
    , ["Corrupt", "Corrupt "]
    , ["Exchange", "Exchange "]
    , ["Split", "Split "]]
global TemplateForCrafts := "("
for k, v in CraftNames {
    template := v[2]
    TemplateForCrafts .= template . "|"
}
TemplateForCrafts := RTrim(TemplateForCrafts, "|") . ")"
global TemplateForLevel := "L[BEeOo][vy][BEeOo][lI1]"
OnExit("ExitFunc")

initSettings()
tooltip, % translate("loading... Initializing Settings")
sleep, 250
checkfiles()
winCheck()

tooltip, % translate("loading... Checking AHK version")
sleep, 250
; == check for ahk version ==
if (A_AhkVersion < 1.1.27.00) {
    MsgBox, % translate("Please update your AHK") . "`r`n" . translate("Your version:") . A_AhkVersion . "`r`n" . translate("Required: 1.1.27.00 or more")
    ExitApp
}

tooltip, % translate("loading... Grabbing active leagues")
getLeagues()

menu, Tray, Icon, resources\Vivid_Scalefruit_inventory_icon.png
Menu, Tray, NoStandard
Menu, Tray, Add, Harvest Vendor, OpenGui
Menu, Tray, Default, Harvest Vendor
Menu, Tray, Standard

; == preload pictures that are used more than once, for performance
count_pic := LoadPicture("resources\count.png")
up_pic := LoadPicture("resources\up.png")
dn_pic := LoadPicture("resources\dn.png")
craft_pic := LoadPicture("resources\craft.png")
lvl_pic := LoadPicture("resources\lvl.png")
price_pic := LoadPicture("resources\price.png")
del_pic := LoadPicture("resources\del.png")
; =================================================================

tooltip, % translate("loading... building GUI")
sleep, 250
newGUI()
isLoading := False
tooltip, % translate("ready")
sleep, 500
Tooltip

if (settingsApp.seenInstructions == 0) {
    ShowHelpUI()
}
;OpenGui()
return

loadLanguageDictionary(Lang, byRef langdict) {
    langfile := A_ScriptDir . "\resources\" . settingsApp["Language"] . "\" . Lang . ".dict"
    if (!FileExist(langfile)) {
        MsgBox, % Messages[settingsApp.Language] . langfile
        ExitApp
        return
    }
    ;StringCaseSense, On
    Loop, read, %langfile%
    {
        line := A_LoopReadLine
        if (line == "") {
            continue
        }
        obj := StrSplit(line, "=")
        value := obj[2]
        key := obj[1]
        langdict[key] := value
    }
}

loadCraftListFrom(byRef langdict) {
    for k, v in langdict {
        CraftList.push(k)
    }
    for k, v in langdict {
        CraftList.push(v)
    }
}

; === Hotkey actions ===
;ctrl+shift+g opens the gui, yo go from there
OpenGui() { 
    if (isLoading) {
        MsgBox, % translate("Please wait until the program is fully loaded")
        return
    }
    loadLastSession()
    if (version != getVersion()) {
        guicontrol, HarvestUI:Show, versionText
        guicontrol, HarvestUI:Show, versionLink
    }
    showGUI()
    OnMessage(0x200, "WM_MOUSEMOVE")
}

;ctrl+g launches straight into the capture, opens gui afterwards
Scan() {
    if (isLoading) {
        MsgBox, % translate("Please wait until the program is fully loaded")
        return
    }
    _wasVisible := IsGuiVisible("HarvestUI")
    if (_wasVisible) {
        hideGUI()
    }
    if (setScreenRect() and processCrafts(TempPath)) {
        canRescan := True
        loadLastSession()
        showGUI()
        OnMessage(0x200, "WM_MOUSEMOVE") ;activates tooltip function
        updateCraftTable(outArray)
    } else {
        ; If processCrafts failed (e.g. the user pressed Escape), we should show the
        ; HarvestUI only if it was visible to the user before they pressed Ctrl+G
        if (_wasVisible) {
            loadLastSession()
            showGUI()
        }
    }
}
;ctrl+F scan from last area
ScanLastArea() {
    if (isLoading) {
        MsgBox, % translate("Please wait until the program is fully loaded")
        return
    }
    if (!canRescan) {
        text := translate("Before using ""Scan Recent Area"", use the ""Scan shortcut (Ctrl+G)"" or press the ""Scan"" button")
        MsgBox, % text
        return
    }
    _wasVisible := IsGuiVisible("HarvestUI")
    if (_wasVisible) {
        hideGUI()
    }
    if (processCrafts(TempPath)) {
        showGUI()
        OnMessage(0x200, "WM_MOUSEMOVE") ;activates tooltip function
        updateCraftTable(outArray)
    } else {
        if (_wasVisible) {
            showGUI()
        }
    }
}
; === Button actions ===
Up_Click() {
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    CraftTable[tempRow].count := CraftTable[tempRow].count + 1
    updateUIRow(tempRow, "count")
    sumTypes()
    sumPrices()
}

Dn_Click() {
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    tempCount := CraftTable[tempRow].count
    if (tempCount > 0) {
        CraftTable[tempRow].count := tempCount - 1
        updateUIRow(tempRow, "count")
        sumTypes()
        sumPrices()
    }
}

setScreenRect() {
    coordTemp := SelectArea("cffc555 t50 ms")
    if (!coordTemp or coordTemp.Length() == 0)
        return false
    x_start := coordTemp[1]
    y_start := coordTemp[3]
    x_end := coordTemp[2]
    y_end := coordTemp[4]
    return true
}

AddCrafts_Click() { 
    buttonHold("addCrafts", "resources\" . settingsApp["Language"] . "\addCrafts")
    hideGUI()
    if (!setScreenRect()) {
        showGUI()
        return
    }
    canRescan := True
    if (processCrafts(TempPath)) {
        updateCraftTable(outArray)
    }
    showGUI()
}

LastArea_Click() {
    buttonHold("rescanButton", "resources\" . settingsApp["Language"] . "\lastArea")
    if (!canRescan) {
        text := translate("Before using ""Scan Recent Area"", use the ""Scan shortcut (Ctrl+G)"" or press the ""Scan"" button")
        MsgBox, % text
        return
    }
    hideGUI()
    if (processCrafts(TempPath)) {
        updateCraftTable(outArray)
    }
    showGUI()
}

ClearAll_Click() {
    buttonHold("clearAll", "resources\" . settingsApp["Language"] . "\clear")
    clearAll()
    sumTypes()
    sumPrices()
}

Count_Changed() {
    if (!needToChangeModel) {
        return
    }
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    oldCount := CraftTable[tempRow].count
    guiControlGet, newCount,, count_%tempRow%, value
    if (oldCount == newCount) {
        return
    }
    CraftTable[tempRow].count := newCount
    sumTypes()
    sumPrices()
}

isKorean(text) {
    pattern := "[\x{1100}-\x{11FF}\x{302E}\x{302F}\x{3131}-\x{318E}\x{3200}-\x{321E}\x{3260}-\x{327E}\x{A960}-\x{A97C}\x{AC00}-\x{D7A3}\x{D7B0}-\x{D7C6}\x{D7CB}-\x{D7FB}\x{FFA0}-\x{FFBE}\x{FFC2}-\x{FFC7}\x{FFCA}-\x{FFCF}\x{FFD2}-\x{FFD7}\x{FFDA}-\x{FFDC}]+"
    ;"[\x{AC00}-\x{D7A3}]+"
    return RegExMatch(text, pattern) > 0
}

isRussian(text) {
    pattern := "[а-яА-Я]+"
    return RegExMatch(text, pattern) > 0
}

isEnglish(text) {
    return false
    ;pattern := "[a-zA-Z]+"
    ;return RegExMatch(text, pattern) > 0
}

removeNonEnglishChars(text) {
    return RegExReplace(text, "[^a-zA-Z0-9\.\+-_,:\*# \\]+")
}

SetTextCursorToEnd(control, caretpos) {
    GuiControlGet, hcontrol, Hwnd, %control%
    ;restore carret position after mark and copy
    SendMessage, 0xB1, caretpos, caretpos,,ahk_id %hcontrol%
}

Craft_Changed() {
    if (!needToChangeModel) {
        return
    }
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    oldCraft := CraftTable[tempRow].craft
    guiControlGet, newCraft,, craft_%tempRow%, value
    lang := settingsApp.Language
    if (is%lang%(newCraft)) {
        englishCraft := translateToEnglish(newCraft)
        if (englishCraft == "") {
            return
        }
        newCraft := englishCraft
        CraftTable[tempRow].craft := newCraft
        updateUIRow(tempRow, "craft")
        SetTextCursorToEnd(cntrl, StrLen(newCraft))
    }
    if (oldCraft == newCraft) {
        return
    }
    
    CraftTable[tempRow].craft := newCraft
    CraftTable[tempRow].Price := getPriceFor(newCraft)
    CraftTable[tempRow].type := getTypeFor(newCraft)
    updateUIRow(tempRow, "price")
    updateUIRow(tempRow, "type")
    
    sumTypes()
    sumPrices()
}

Level_Changed() {
   if (!needToChangeModel) {
        return
    }
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    oldLvl := CraftTable[tempRow].lvl
    guiControlGet, newLvl,, lvl_%tempRow%, value
    if (oldLvl == newLvl) {
        return
    }
    CraftTable[tempRow].lvl := newLvl
}

Price_Changed() {
    if (!needToChangeModel) {
        return
    }
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    oldPrice := CraftTable[tempRow].price
    guiControlGet, newPrice,, price_%tempRow%, value
    ;newPrice := removeNonEnglishChars(newPrice)
    if (oldPrice == newPrice) {
        return
    }
    CraftTable[tempRow].price := newPrice
    craftName := CraftTable[tempRow].craft
    if (craftName != "") {
        iniWrite, %newPrice%, %PricesPath%, Prices, %craftName%
    }
    sumPrices()
}

CanStream_Changed() {
    guiControlGet, strim,,canStream, value
    settingsApp.canStream := strim 
}

IGN_Changed() {
    guiControlGet, lastIGN,,IGN, value
    settingsApp.nick := lastIGN
}

CustomText_Changed() {
    guiControlGet, cust,,customText, value
    settingsApp.customText := cust
    GuiControl,HarvestUI:, customText_cb, 1
}

CustomTextCB_Changed() {
    guiControlGet, custCB,,customText_cb, value
    settingsApp.customTextCB := custCB
}

ClearRow_Click() {
    GuiControlGet, cntrl, name, %A_GuiControl%
    tempRow := getRow(cntrl)
    if GetKeyState("Shift") {
        row := CraftTable[tempRow]
        league := settingsApp.selectedLeague
        fileLine := A_YYYY . "-" . A_MM . "-" . A_DD . ";" . A_Hour . ":" . A_Min . ";" . league . ";" . row.craft . ";" . row.price . "`r`n"

        FileAppend, %fileLine%, %LogPath%
        if (row.count > 1) {
            CraftTable[tempRow].count := row.count - 1
        } else {
            clearRowData(tempRow)
            sortCraftTable()
        }
    } else {
        clearRowData(tempRow)
        sortCraftTable()
    }
    updateUIRow(tempRow)
    sumTypes()
    sumPrices()
}

updatePricesForUI() {
    for k, row in CraftTable {
        craftInGui := row.craft
        if (row.craft == "") {
            continue
        }
        oldPrice := row.price
        iniRead, newPrice, %PricesPath%, Prices, % row.craft
        if (newPrice == "ERROR" or newPrice == oldPrice) {
            continue
        }
        CraftTable[k].price := newPrice
        updateUIRow(k, "price")
    }
    sumPrices()
}

GithubPriceUpdate_Click() {
    option := (262144 | 4) ;Always-on-top and Yes/No
    text := translate("This will update all local prices with TFT discord prices(Only those which are high confidence, if there is no high confidence price for certain Harvest, they will be kept as it is in local file.), are you sure you want to continue?")
    MsgBox, % option,, %text%
    IfMsgBox, Yes
    {
        leagueCheck := settingsApp.selectedLeague
        ToolTip, % translate("Updating for") " " leagueCheck
        sleep, 1000
        Tooltip
        mapLeagues := [["Standard", "std"], ["SC", "lsc"], ["Hardcore", "lhc"]]
        url := "https://raw.githubusercontent.com/The-Forbidden-Trove/tft-data-prices/master/{league}/harvest.json"
        for k, league in mapLeagues {
            if InStr(leagueCheck, league[1]) {
                url := StrReplace(url, "{league}", league[2])
                UrlDownloadToFile, %url%, %tftPrices%
                break
            }
        }
        if (!FileExist(tftPrices)) {
            ToolTip, % translate("Prices NOT Updated")
            sleep, 1000
            Tooltip
            return
        }
        FileRead, tftData, %tftPrices%
        parsed := JSON.Load(tftData)
        for k, v in parsed.data {
            lowConfidence := v.lowConfidence
            if (lowConfidence) {
                continue
            }
            exalt := v.exalt
            craftName := v.name
            iniRead, CheckLocalPrice, %PricesPath%, Prices, %craftName%
            if (exalt >= 1) {
                template := "Oi)^(\d*[\.,]{0,1}?\d+) *(ex|exa|exalt)$"
                type := "ex"
                craftPrice := exalt
            } else {
                template := "Oi)^(\d+) *(c|chaos)$"
                craftPrice := v.chaos
                type := "c"
            }
            if (RegExMatch(CheckLocalPrice, template, matchObj) > 0) {
                CheckLocalPrice := matchObj[1]
            }
            if (CheckLocalPrice != craftPrice) {
                craftPrice .= type
                iniWrite, %craftPrice%, %PricesPath%, Prices, %craftName%
            }
        }
        FileDelete, %tftPrices%
        updatePricesForUI()
        ToolTip, % translate("Prices Updated")
        sleep, 1000
        Tooltip
        return
    }
    ToolTip, % translate("Prices NOT Updated")
    sleep, 1000
    Tooltip
}

createPost_Click() {
    buttonHold("postAll", "resources\" . settingsApp["Language"] . "\createPost")
    createPost("All")
}

League_Changed() {
    guiControlGet, selectedLeague,,League, value
    settingsApp.selectedLeague := selectedLeague
}

AlwaysOnTop_Changed() {
    guiControlGet, onTop,,alwaysOnTop, value
    settingsApp.alwaysOnTop := onTop
    setWindowState(settingsApp.alwaysOnTop)
}

;====================================================
Settings_Click() { 
    buttonHold("settings", "resources\" . settingsApp["Language"] . "\settings")
    hotkey, % settingsApp["GuiKey"], off
    hotkey, % settingsApp["ScanKey"], off
    hotkey, % settingsApp["ScanLastAreaKey"], off
    ShowSettingsUI()
}
; === Settings UI ===================================
ShowSettingsUI() {
    static OpenSettingsFolder
    static mf_Groupbox
    static ms_Groupbox
    static lastText1
    static lastText2
    static lang_Groupbox
    static lastText3
    width := 400
    gui Settings:new,, % "PoE-HarvestVendor fork -" . translate("Settings")
    gui, add, Groupbox, x5 y5 w%width% Section vmf_Groupbox, % translate("Message formatting")
        Gui, add, text, xs+5 yp+20, % translate("Output message style:")
        Gui, add, dropdownList, x+10 yp+0 w30 voutStyle gOutStyle_Changed, 1|2
        guicontrol, choose, outStyle, % settingsApp.outStyle
        widthT := width - 20
        Gui, add, text, xs+15 y+5 w%widthT%, % "1 - " . translate("No Colors, No codeblock - Words are highlighted when using discord search")
        Gui, add, text, xs+15 y+5 wp+0 vlastText1, % "2 - " . translate("Codeblock, Colors - Words aren't highlighetd when using discord search")
    ;calculate a new height for Groupbox
    guiControlGet, mf_Groupbox, Settings:Pos
    guiControlGet, lastText1, Settings:Pos
    newheight := (lastText1Y + lastText1H) - mf_GroupboxY + 5
    guiControl, Settings:Move, mf_Groupbox, H%newheight%
    
    gui, add, Groupbox, x5 y+10 w%width% vms_GroupBox, % translate("Monitor Settings")
        monitors := getMonCount()
        Gui add, text, xp+5 yp+20, % translate("Select monitor:")
        Gui add, dropdownList, x+10 yp+0 w30 Section vMonitorsDDL gMonitors_Changed, %monitors%
            global MonitorsDDL_TT := translate("For when you aren't running PoE on main monitor")
        guicontrol, choose, MonitorsDDL, % settingsApp.monitor

        gui, add, text, x10 y+5, % translate("Scale") 
        gui, add, edit, xs yp+0 w30 vScaleEdit gScale_Changed, % settingsApp.scale
        text := translate("use this when you are using Other than 100% scale in windows display settings")
        Gui, add, text, x20 y+5 w%widthT%, % "- " . text
        Gui, add, text, xp+0 y+5 wp+0 vlastText2, % "- 100`% = 1, 150`% = 1.5 " . translate("and so on")
    ;calculate a new height for Groupbox
    guiControlGet, ms_GroupBox, Settings:Pos
    guiControlGet, lastText2, Settings:Pos
    newheight := (lastText2Y + lastText2H) - ms_GroupBoxY + 5
    guiControl, Settings:Move, ms_GroupBox, H%newheight%
    
    gui, add, Groupbox, x5 y+10 w%width% Section vlang_Groupbox, % translate("Localization")
        Gui, add, text, xs+5 yp+20, % translate("Language:")
        listDDL := ""
        for k, v in LanguageList {
            listDDL .= v . "|"
        }
        Gui, add, dropdownList, x+10 yp+0 w80 vlangDDL glangDDL_Changed, % listDDL
        guicontrol, choose, langDDL, % LanguageList[settingsApp.Language]
        Gui, add, text, xs+15 y+5 w%widthT% vlastText3 , % translate("Need to restart the program for using a new language!")
    ;calculate a new height for Groupbox
    guiControlGet, lang_Groupbox, Settings:Pos
    guiControlGet, lastText3, Settings:Pos
    newheight := (lastText3Y + lastText3H) - lang_GroupboxY + 5
    guiControl, Settings:Move, lang_Groupbox, H%newheight%
    
    gui, add, groupbox, x5 y+10 w%width% R4.3, % translate("Hotkeys")
        Gui, add, text, xp+5 yp+20, % translate("Open Harvest vendor:")
        gui,add, hotkey, x+10 yp+0 Section vGuiKeyHotkey, % settingsApp.GuiKey
        
        Gui, add, text, x10 y+5, % translate("Add crafts:")
        gui, add, hotkey, xs yp+0 vScanKeyHotkey, % settingsApp.ScanKey
        
        Gui, add, text, x10 y+5, % translate("Add from last area:")
        gui, add, hotkey, xs yp+0 vScanLastAreaHotkey, % settingsApp.ScanLastAreaKey

    ;width := width - 10
    gui, add, button, x5 y+10 h30 w%width% gOpenSettingsFolder_Click vOpenSettingsFolder, % translate("Open Settings Folder")
    gui, add, button, xp+0 y+5 hp+0 wp+0 gSettingsOK_Click, % translate("Save")
    gui, Settings:Show ;, w410 h370
    return
    
    SettingsGuiClose:
        hotkey, % settingsApp["GuiKey"], on
        hotkey, % settingsApp["ScanKey"], on
        hotkey, % settingsApp["ScanLastAreaKey"], on
        Gui, Settings:Destroy
        Gui, HarvestUI:Default
    return
}

OpenSettingsFolder_Click() {
    explorerpath := "explorer " . RoamingDir
    Run, %explorerpath%
}

OutStyle_Changed() {
    guiControlGet, os,,outStyle, value
    settingsApp.outStyle := os
}

langDDL_Changed() {
    guiControlGet, lang,, langDDL, value
    settingsApp.Language := LanguageReverseList[lang]
}

Monitors_Changed() {
    guiControlGet, mon,,MonitorsDDL, value
    settingsApp.monitor := mon
}

Scale_Changed() {
    guiControlGet, sc,,ScaleEdit, value
    settingsApp.scale := sc
}

SettingsOK_Click() {
    guiControlGet, gk,, GuiKeyHotkey, value
    guiControlGet, sk,, ScanKeyHotkey, value
    guiControlGet, slak,, ScanLastAreaHotKey, value

    if (settingsApp.GuiKey != gk and gk != "ERROR" and gk != "") {
        hotkey, % settingsApp["GuiKey"], off
        settingsApp.GuiKey := gk
        hotkey, % settingsApp["GuiKey"], OpenGui
    } 
            
    if (settingsApp.ScanKey != sk and sk != "ERROR" and sk != "") {
        hotkey, % settingsApp["ScanKey"], off
        settingsApp.ScanKey := sk
        hotkey, % settingsApp["ScanKey"], Scan
    }
    
     if (settingsApp.ScanLastAreaKey != slak and slak != "ERROR" and slak != "") {
        hotkey, % settingsApp["ScanLastAreaKey"], off
        settingsApp.ScanLastAreaKey := slak
        hotkey, % settingsApp["ScanLastAreaKey"], ScanLastArea
    } 

    if (gk != "ERROR" and gk != "") {
        hotkey, %gk%, on
    } else {
        hotkey, % settingsApp["GuiKey"], on
    }

    if (sk != "ERROR" and sk != "") {
        hotkey, %sk%, on
    } else {
        hotkey, % settingsApp["ScanKey"], on
    }
    
    if (slak != "ERROR" and slak != "") {
        hotkey, %slak%, on
    } else {
        hotkey, % settingsApp["ScanLastAreaKey"], on
    }

    Gui, Settings:Destroy
    Gui, HarvestUI:Default
}
;====================================================
; === Help UI =======================================
Help_Click() {
    buttonHold("help", "resources\" . settingsApp["Language"] . "\help")
    ShowHelpUI()
}

ShowHelpUI() {
    settingsApp.seenInstructions := 1
    static Area
    ;static Static4
    columnWidth := 400
    gui Help:new,, % "PoE-HarvestVendor fork -" translate("Help")
;step 1
gui, font, s14 wBold
    Gui, add, text, x5 y5 w%columnWidth%, % translate("Step 1")
gui, font, s10 wNorm 
    gui, add, text, xp+10 y+5 wp-10, % translate("Default Hotkey to open the UI - Ctrl + Shift + G") "`r`n" translate("Default Hotkey to start capture - Ctrl + G") "`r`n" translate("Hotkeys can be changed in settings")

;step 2 
gui, font, s14 wBold
    gui, add, text, xp-10 y+5 wp+10, % translate("Step 2")
gui, font, s10 wNorm
    gui, add, text, xp+10 y+5 wp-10, % translate("Start the capture by either clicking Add Crafts button, ") "`r`n" translate("or pressing the Capture hotkey.") "`r`n" translate("Select the area with crafts:")
    Gui, Add, ActiveX, xp+0 y+5 w250 h233 vArea, Shell2.Explorer
    Area.document.body.style.overflow := "hidden"
    Edit := WebPic(Area, "https://raw.githubusercontent.com/Stregon/PoE-HarvestVendor/master/examples/snapshotArea_s.png", "w250 h233 cFFFFFF")
    relwidth := columnWidth - 250
    gui, add, text, xp+0 y+5 wp+%relwidth%, % translate("this can be done repeatedly to add crafts to the list")

;step 3     
gui, font, s14 wBold
    gui, add, text, xp-10 y+5 wp+10, % translate("Step 3")
gui, font, s10 wNorm
    gui, add, text, xp+10 y+5 wp-10, % translate("Fill in the prices (they will be remembered)") "`r`n" translate("and other info like: Can stream, IGN and so on if you wish to")
    ;Gui, Add, ActiveX, x5 y430 w350 h100 vPricepic, Shell2.Explorer
    ;Pricepic.document.body.style.overflow := "hidden"
    ;Edit := WebPic(Pricepic, "https://github.com/esge/PoE-HarvestVendor/blob/master/examples/price.png?raw=true", "w298 h94 cFFFFFF")

;step 4    
gui, font, s14 wBold
    Gui, add, text, xp-10 y+5 wp+10, % translate("Step 4")
gui, font, s10 wNorm
    gui, add, text, xp+10 y+5 wp-10, % translate("click: Post Augments/Removes... for the set you want to post") "`r`n" translate("Now your message is in clipboard") "`r`n" translate("Careful about Post All on TFT discord, it has separate channels for different craft types.")
gui, font, s14 cRed wBold
    Gui, Add, text, xp-10 y+5 wp+10, % translate("Important:")
gui, font, s10 wNorm
    text := translate("If you are using Big resolution (more than 1080p) and have scaling for display set in windows to more than 100% (in Display settings)") . "`r`n" . translate("You need to go into Settings in HarvestVendor and set Scale to match whats set in windows")
    if (settingsApp.Language == "Korean") {
        text .= "`r`n" . translate("auto-completion function") . "`r`n  " . translate("1. For accuracy. [Recommended] Please enter one letter") . "`r`n  " . translate("2. Type it and press the space bar.")
    }
    gui, add, text, xp+10 y+5 wp-10, % text
    
gui, font, s14 cBlack wBold
    gui, add, text, xp-10 y+5 wp+10, % translate("Hidden features")
gui, font, s10 wNorm
    gui, add, text, xp+10 y+5 wp-10, % translate("- Holding shift while clicking the X in a row will reduce the count by 1 and also write the craft and price into log.csv (you can find it through the Settings folder button in Settings)")
gui, font
    Gui, Help:Show ;, w800 ;h610
    return
    
    HelpGuiClose:
        Gui, Help:Destroy
        Gui, HarvestUI:Default
    return
}

initSettings() {
    iniRead, Language,  %SettingsPath%, Other, Language
    if (Language == "ERROR" or Language == "" 
        or !LanguageList.HasKey(Language)) {
        Language := "English"
    }
    settingsApp.Language := Language
    if (settingsApp.Language != "English") {
        loadLanguageDictionary(settingsApp.Language, LanguageDictionary)
    }
    loadLanguageDictionary(settingsApp.Language . "_English", EnglishDictionary)
    loadCraftListFrom(EnglishDictionary)
    
    iniRead, MaxRowsCraftTable,  %SettingsPath%, Other, MaxRowsCraftTable
    if (MaxRowsCraftTable == "ERROR" or MaxRowsCraftTable == ""
        or MaxRowsCraftTable < 20 or MaxRowsCraftTable > 40) {
        MaxRowsCraftTable := 20
    }
    settingsApp.MaxRowsCraftTable := MaxRowsCraftTable
    loop, % settingsApp.MaxRowsCraftTable {
        CraftTable.push({"count": 0, "craft": "", "price": ""
            , "lvl": "", "type": ""})
    }

    iniRead, seenInstructions,  %SettingsPath%, Other, seenInstructions
    if (seenInstructions == "ERROR" or seenInstructions == "") {
        seenInstructions := 0
        IniWrite, % seenInstructions, %SettingsPath%, Other, seenInstructions
    }
    settingsApp.seenInstructions := seenInstructions

    IniRead, GuiKey, %SettingsPath%, Other, GuiKey
    checkNoValidChars := RegExMatch(GuiKey, "[^a-zA-Z\+\^!]+") > 0
    if (GuiKey == "ERROR" or GuiKey == "" or checkNoValidChars) {
        GuiKey := "^+g"
        if (checkNoValidChars) {
            msgBox, % translate("Open GUI hotkey was set to a non latin letter or number, it was reset to ctrl+shift+g")
        }
    }
    settingsApp.GuiKey := GuiKey
    hotkey, % settingsApp["GuiKey"], OpenGui

    IniRead, ScanKey, %SettingsPath%, Other, ScanKey
    checkNoValidChars := RegExMatch(ScanKey, "[^a-zA-Z\+\^!]+") > 0
    if (ScanKey == "ERROR" or ScanKey == "" or checkNoValidChars) {
        ScanKey := "^g"
        if (checkNoValidChars) {
            msgBox, % translate("Scan hotkey was set to a non latin letter or number, it was reset to ctrl+g")
        }
    }
    settingsApp.ScanKey := ScanKey
    hotkey, % settingsApp["ScanKey"], Scan
    
    IniRead, ScanLastAreaKey, %SettingsPath%, Other, ScanLastAreaKey
    checkNoValidChars := RegExMatch(ScanLastAreaKey, "[^a-zA-Z\+\^!]+") > 0
    if (ScanLastAreaKey == "ERROR" or ScanLastAreaKey == "" or checkNoValidChars) {
        ScanLastAreaKey := "^+f"
        if (checkNoValidChars) {
            msgBox, % translate("Scan from last area hotkey was set to a non latin letter or number, it was reset to ctrl+shift+f")
        }
    }
    settingsApp.ScanLastAreaKey := ScanLastAreaKey
    hotkey, % settingsApp["ScanLastAreaKey"], ScanLastArea

    IniRead, outStyle, %SettingsPath%, Other, outStyle
    if (outStyle == "ERROR") {
        outStyle := 1
    }
    settingsApp.outStyle := outStyle

    iniRead tempMon, %SettingsPath%, Other, mon
    if (tempMon == "ERROR" or tempMon == "") { 
        tempMon := 1
    }
    settingsApp.monitor := tempMon

    iniRead, sc, %SettingsPath%, Other, scale
    if (sc == "ERROR") {
        sc := 1
    }
    settingsApp.scale := sc
    
    iniRead tempOnTop, %SettingsPath%, Other, alwaysOnTop
    if (tempOnTop == "ERROR") { 
        tempOnTop := 0 
    }
    settingsApp.alwaysOnTop := tempOnTop
    
    IniRead, NewX, %SettingsPath%, window position, gui_position_x
    IniRead, NewY, %SettingsPath%, window position, gui_position_y
    if (NewX == "ERROR" or NewY == "ERROR")
        or (NewX == -32000 or NewY == -32000) {
         NewX := 0
         NewY := 0
    }
    settingsApp.gui_position_x := NewX
    settingsApp.gui_position_y := NewY
    
    iniRead tempStream, %SettingsPath%, Other, canStream
    if (tempStream == "ERROR") { 
        tempStream := 0 
    }
    settingsApp.canStream := tempStream
    
    IniRead, name, %SettingsPath%, IGN, n
    if (name == "ERROR") {
        name := ""
    }
    settingsApp.nick := name
    
    iniRead tempCustomTextCB, %SettingsPath%, Other, customTextCB
    if (tempCustomTextCB == "ERROR") { 
        tempCustomTextCB := 0 
    }
    settingsApp.customTextCB := tempCustomTextCB
    
    iniRead tempCustomText, %SettingsPath%, Other, customText
    if (tempCustomText == "ERROR") { 
        tempCustomText := "" 
    }
    settingsApp.customText := StrReplace(tempCustomText, "||", "`n") ;support multilines in custom text
    iniRead, selectedLeague, %SettingsPath%, selectedLeague, s
    if (selectedLeague == "ERROR") {
        selectedLeague := ""
    }
    settingsApp.selectedLeague := selectedLeague
}

saveSettings() {
    if (sessionLoading or isLoading) {
        return
    }
    IniWrite, % settingsApp.Language, %SettingsPath%, Other, Language
    IniWrite, % settingsApp.seenInstructions, %SettingsPath%, Other, seenInstructions 
    iniWrite, % settingsApp.canStream, %SettingsPath%, Other, canStream
    cust := StrReplace(settingsApp.customText, "`n", "||") ;support multilines in custom text
    iniWrite, %cust%, %SettingsPath%, Other, customText
    iniWrite, % settingsApp.customTextCB, %SettingsPath%, Other, CustomTextCB
    iniWrite, % settingsApp.selectedLeague, %SettingsPath%, selectedLeague, s
    iniWrite, % settingsApp.alwaysOnTop, %SettingsPath%, Other, alwaysOnTop
    iniWrite, % settingsApp.scale, %SettingsPath%, Other, scale
    iniWrite, % settingsApp.outStyle, %SettingsPath%, Other, outStyle
    iniWrite, % settingsApp.nick, %SettingsPath%, IGN, n
    iniWrite, % settingsApp.monitor, %SettingsPath%, Other, mon

    IniWrite, % settingsApp.gui_position_x, %SettingsPath%, window position, gui_position_x
    IniWrite, % settingsApp.gui_position_y, %SettingsPath%, window position, gui_position_y
    
    IniWrite, % settingsApp.ScanKey, %SettingsPath%, Other, ScanKey
    IniWrite, % settingsApp.GuiKey, %SettingsPath%, Other, GuiKey
    IniWrite, % settingsApp.ScanLastAreaKey, %SettingsPath%, Other, ScanLastAreaKey
    
    rememberSession()
}

ExitFunc(ExitReason, ExitCode) {
    for k, v in IAutoComplete_Crafts {
        v.Disable()
        IAutoComplete_Crafts[k] := ""
    }
    saveWindowPosition()
    saveSettings()
    return 0
}

WinGetPosPlus(winTitle, ByRef xPos, ByRef yPos) {
   hwnd := WinExist(winTitle)
   VarSetCapacity(WP, 44, 0), NumPut(44, WP, "UInt")
   DllCall("User32.dll\GetWindowPlacement", "Ptr", hwnd, "Ptr", &WP)
   xPos := NumGet(WP, 28, "Int") ; X coordinate of the upper-left corner of the window in its original restored state
   yPos := NumGet(WP, 32, "Int") ; Y coordinate of the upper-left corner of the window in its original restored state
}

saveWindowPosition() {
    if (firstGuiOpen) { ;wrong window pos(0,0) if dont show gui before
        return
    }
    winTitle := "PoE-HarvestVendor fork v" . version
    DetectHiddenWindows, On
    if WinExist(winTitle) {
        ;save window position
        WinGetPosPlus(winTitle, gui_x, gui_y)
        settingsApp.gui_position_x := gui_x
        settingsApp.gui_position_y := gui_y
    }
    DetectHiddenWindows, Off
}

showGUI() {
    if (firstGuiOpen) {
        firstGuiOpen := False
        NewX := settingsApp.gui_position_x
        NewY := settingsApp.gui_position_y
        DetectHiddenWindows, On
        Gui, HarvestUI:Show, Hide
        WinTitle := "PoE-HarvestVendor fork v" . version
        WinMove, %WinTitle%,, %NewX%, %NewY%
        DetectHiddenWindows, Off
    } 
    Gui, HarvestUI:Show
}

hideGUI() {
    Gui, HarvestUI:Hide
}

newGUI() {
    Global
    Gui, HarvestUI:New,, PoE-HarvestVendor fork v%version% 
    ;Gui -DPIScale      ;this will turn off scaling on big screens, which is nice for keeping layout but doesn't solve the font size, and fact that it would be tiny on big screens
    Gui, Color, 0x0d0d0d, 0x1A1B1B
    gui, Font, s11 cFFC555
; === Title and icon ===
    title_icon := getImgWidth(A_ScriptDir . "\resources\Vivid_Scalefruit_inventory_icon.png")
    gui add, picture, x10 y10 w%title_icon% h-1 vVivid_Scalefruit, resources\Vivid_Scalefruit_inventory_icon.png
    title := getImgWidth(A_ScriptDir . "\resources\title.png")
    gui add, picture, x+5 yp+0 w%title% h-1 Section, resources\title.png
    gui add, text, x+5 yp+2, fork v%version%
    
    gui Font, s12
    gui add, text, x+10 yp+0 cGreen vversionText Right, % translate("! New Version Available !")
;gui, Font, s11 cFFC555
    gui add, Link, xp+0 yp+20 vversionLink c0x0d0d0d Right, <a href="http://github.com/Stregon/PoE-HarvestVendor/releases/latest">Github Link</a>
        
    GuiControl, Hide, versionText
    GuiControl, Hide, versionLink
    
    GuiControlGet, Vivid_Scalefruit, HarvestUI:Pos
    header_Y := Vivid_ScalefruitY + Vivid_ScalefruitH + 5
    Header_X := Vivid_ScalefruitX
    borderRight_width := 1
    borderLeft_width := 1
    border_width := borderLeft_width + borderRight_width
    borderTop_height := 1
    borderBottom_height := 1
    border_height := borderTop_height + borderBottom_height
    Row_height := 18 + borderTop_height + borderBottom_height ; 18
    Type_width := Vivid_ScalefruitW ;60
    Craft_width := 300 + border_width ; 296
    Count_width := 36 + border_width
    Level_width := 44 + border_width
    Price_width := 44 + border_width 
; ======================
; === Text stuff ===
value_width := 50
gui, Font, s11 cA38D6D
        gui add, text, xs yp+5 vValue +BackgroundTrans, % translate("You have:") 
        gui, Font, s11 cFFC555
        gui add, text, x+10 yp+0 w%value_width% right +BackgroundTrans vsumEx, 0
        gui, Font, s11 cA38D6D
        gui add, text, x+2 yp+0 +BackgroundTrans, % translate("ex") 
        gui, Font, s11 cFFC555
        gui add, text, x+10 yp+0 w%value_width% right +BackgroundTrans vsumChaos, 0
        gui, Font, s11 cA38D6D
        gui add, text, x+2 yp+0 +BackgroundTrans, % translate("c") 

        gui add, text, x+40 yp+0 vcrafts +BackgroundTrans, % translate("Total Crafts:")     
        gui, Font, s11 cFFC555
        gui add, text, x+10 yp+0 w%value_width% vCraftsSum, 0
        gui, Font, s11 cA38D6D

        gui add, text, xs y+5 +BackgroundTrans, % translate("Augs:")  
        gui, Font, s11 cFFC555
        gui add, text, x+10 yp+0 w%value_width% +BackgroundTrans vAcount,0
        gui, Font, s11 cA38D6D

        gui add, text, x+20 yp+0 +BackgroundTrans, % translate("Reforges:") 
        gui, Font, s11 cFFC555
        gui add, text, x+10 yp+0 w%value_width% +BackgroundTrans vRefcount,0
        gui, Font, s11 cA38D6D
        gui add, text, x+20 yp+0 +BackgroundTrans, % translate("Rem/Adds:") 
        gui, Font, s11 cFFC555
        gui add, text, x+10 yp+0 w%value_width% +BackgroundTrans vRAcount,0
        gui, Font, s11 cA38D6D
        gui add, text, x+20 yp+0 +BackgroundTrans, % translate("Other:") 
        gui, Font, s11 cFFC555
        gui add, text, x+10 yp+0 w%value_width% +BackgroundTrans vOcount,0
        gui, Font, s11 cA38D6D
; ==================
; === table headers ===
    offsetColumn := 4
    offsetFirstColumn := 4 
    offsetColumn_Craft := offsetColumn + border_width
    
    offsetNRow := offsetColumn + borderTop_height
    offsetFirstRow := 0
    offsetRow := offsetFirst
    gui add, text, x%Header_X% y%header_Y% w%Type_width% h%Row_height% +Right, % translate("Type")
    gui add, text, x+%offsetFirstColumn% yp+0 w%Count_width% h%Row_height% +Center, % translate("#")
    gui add, text, x+%offsetFirstColumn% yp+0 w%Craft_width% h%Row_height% +Center, % translate("Crafts")
    gui add, text, x+%offsetFirstColumn% yp+0 w%Level_width% h%Row_height% +Center, % translate("LvL")
    gui add, text, x+%offsetFirstColumn% yp+0 w%Price_width% h%Row_height% +Center, % translate("Price")

; === table ===
    del_ := getImgWidth(A_ScriptDir . "\resources\del.png")
    up_pic_width := getImgWidth(A_ScriptDir . "\resources\up.png")
    dn_pic_width := up_pic_width
    dp_pic_height := 9
    dp_pic_relX := Row_height - dp_pic_height
    
    loop, % settingsApp.MaxRowsCraftTable {
        if (A_Index != 1) {
            offsetRow := offsetNRow + borderTop_height
        }
        gui, Font, s11 cA38D6D
            gui add, text, x%Header_X% y+%offsetRow% vtype_%A_Index% w%Type_width% h%Row_height% Right,
        gui, Font, s11 cFFC555
        
        gui add, picture, x+%offsetColumn% yp+0 w%Count_width% h%Row_height% Section AltSubmit , % "HBITMAP:*" count_pic
            Gui Add, Edit, xp+%borderRight_width% yp+%borderTop_height% wp-%border_width% hp-%border_height% vcount_%A_Index% gCount_Changed -E0x200 +BackgroundTrans Center
                Gui Add, UpDown, Range0-20 hp+0 vupDown_%A_Index%, 0
                GuiControlGet, upDown_%A_Index%, HarvestUI:Pos
                guicontrol, hide, upDown_%A_Index%
                upDown_W := upDown_%A_Index%W
                upDown_X := upDown_%A_Index%X + (upDown_W - up_pic_width - border_width)
            gui add, picture, x%upDown_X% yp+0 w%up_pic_width% gUp_Click vUp_%A_Index%, % "HBITMAP:*" up_pic
            gui add, picture, xp+0 yp+%dp_pic_relX% wp+0 hp+0 gDn_Click vDn_%A_Index%, % "HBITMAP:*" dn_pic
        
        gui add, picture, x+%offsetColumn_Craft% ys+0 w%Craft_width% h%Row_height% Section AltSubmit , % "HBITMAP:*" craft_pic
            gui add, edit, xp+%borderRight_width% yp+%borderTop_height% wp-%border_width% hp-%border_height% -E0x200 +BackgroundTrans vcraft_%A_Index% gCraft_Changed HwndhCraft_%A_Index%
            ia_craft := IAutoComplete_Create(hCraft_%A_Index%, CraftList
                , ["UPDOWNKEYDROPSLIST", "AUTOSUGGEST", "WORD_FILTER"], True)
            IAutoComplete_Crafts.push(ia_craft) ;, "AUTOSUGGEST" "WORD_FILTER"

        gui add, picture, x+%offsetColumn% ys+0 w%Level_width% h%Row_height% Section AltSubmit , % "HBITMAP:*" lvl_pic
            gui add, edit, xp+%borderRight_width% yp+%borderTop_height% wp-%border_width% hp-%border_height% -E0x200 +BackgroundTrans Center vlvl_%A_Index% gLevel_Changed

        gui add, picture, x+%offsetColumn% ys+0 w%Price_width% h%Row_height% Section AltSubmit , % "HBITMAP:*" price_pic
            gui add, edit, xp+%borderRight_width% yp+%borderTop_height% wp-%border_width% hp-%border_height% -E0x200 +BackgroundTrans Center vprice_%A_Index% gPrice_Changed

        gui add, picture, x+%offsetColumn% ys+0  w-1 hp+0 vdel_%A_Index% gClearRow_Click AltSubmit , % "HBITMAP:*" del_pic ;resources\del.png 
    }
; === Right side ===
    GuiControlGet, del_1, HarvestUI:Pos
    RightSide_X := del_1X + del_1W + 10
    leagueDDL_width := 113 + 2
    offsetForbuttons := 4
    gui Font, s11
    gui add, checkbox, x%RightSide_X% y%header_Y% valwaysOnTop gAlwaysOnTop_Changed, % translate("Always on top")
    guicontrol,,alwaysOnTop, % settingsApp.alwaysOnTop
    setWindowState(settingsApp.alwaysOnTop)
    
    addCrafts_ := getImgWidth(A_ScriptDir . "\resources\" . settingsApp["Language"] . "\addCrafts.png")
    gui add, picture, xp+0 y+%offsetForbuttons% w%addCrafts_% h-1 gAddCrafts_Click vaddCrafts, % "resources\" . settingsApp["Language"] . "\addCrafts.png"
    lastArea_ := getImgWidth(A_ScriptDir . "\resources\" . settingsApp["Language"] . "\lastArea.png")
    gui add, picture, xp+0 y+%offsetForbuttons% w%lastArea_% h-1 gLastArea_Click vrescanButton, % "resources\" settingsApp["Language"] "\lastArea.png"
    clear_ := getImgWidth(A_ScriptDir . "\resources\" . settingsApp["Language"] . "\clear.png")
    gui add, picture, xp+0 y+%offsetForbuttons% w%clear_% h-1 gClearAll_Click vclearAll, % "resources\" settingsApp["Language"] "\clear.png"
    settings_ := getImgWidth(A_ScriptDir . "\resources\" . settingsApp["Language"] . "\settings.png")
    gui add, picture, xp+0 y+%offsetForbuttons% w%settings_% h-1 gSettings_Click vsettings, % "resources\" settingsApp["Language"] "\settings.png"
    help_ := getImgWidth(A_ScriptDir . "\resources\" . settingsApp["Language"] . "\help.png")
    gui add, picture, xp+0 y+%offsetForbuttons% w%help_% h-1 gHelp_Click vhelp, % "resources\" settingsApp["Language"] "\help.png"
    githubpriceupdate_ := getImgWidth(A_ScriptDir . "\resources\" . settingsApp["Language"] . "\UpdatePrices.png")
    gui add, picture, xp+0 y+%offsetForbuttons% w%githubpriceupdate_% h-1 gGithubPriceUpdate_Click vgithubpriceupdate, % "resources\" . settingsApp["Language"] . "\UpdatePrices.png"
    ; === Post buttons ===
    createPost_ := getImgWidth(A_ScriptDir . "\resources\" . settingsApp["Language"] . "\createPost.png")
    gui add, picture, xp+0 y+%offsetForbuttons% w%createPost_% h-1 vpostAll gcreatePost_Click, % "resources\" settingsApp["Language"] "\createPost.png"

    ; === League dropdown ===
    leagueString := getLeagueList()
    gui add, text, xp+0 y+10, % translate("League:")
    gui add, dropdownList, xp+0 y+%offsetForbuttons% w%leagueDDL_width% -E0x200 +BackgroundTrans vleague gLeague_Changed, % leagueString
    guicontrol, choose, league, % settingsApp.selectedLeague

    ; === can stream ===
    gui add, checkbox, xp+0 y+%offsetForbuttons% vcanStream gCanStream_Changed, % translate("Can stream")
    guicontrol,,canStream, % settingsApp.canStream

    ; === IGN ===
    ign_width := 113 + 2
    ign_height := 18 + 2
    gui add, text, xp+0 y+%offsetForbuttons%, % translate("IGN:") 
        ;ign := getImgWidth(A_ScriptDir . "\resources\ign.png")
        gui add, picture, xp+0 y+%offsetForbuttons% w%ign_width% h%ign_height%, resources\ign.png
        gui, Font, s11 cA38D6D
            Gui Add, Edit, xp+1 yp+1 wp-2 hp-2 -E0x200 +BackgroundTrans vign gIGN_Changed, % settingsApp.nick
        gui, Font, s11 cFFC555

    ; === custom text checkbox ===
    gui add, checkbox, xp-1 y+%offsetForbuttons% vcustomText_cb gCustomTextCB_Changed, % translate("Custom Text:")
        guicontrol,,customText_cb, % settingsApp.customTextCB
    ; ============================
    ; === custom text input ===
    customText_width := 113  + 2
    customText_height := 65 + 2
    ;text := getImgWidth(A_ScriptDir . "\resources\text.png")
    gui add, picture,  xp+0 y+%offsetForbuttons% w%customText_width% h%customText_height%, resources\text.png
    gui, Font, s11 cA38D6D
        Gui Add, Edit, xp+1 yp+1 wp-2 hp-2 -E0x200 +BackgroundTrans vcustomText gCustomText_Changed -VScroll, % settingsApp.customText
    gui, Font, s11 cFFC555
    ; ============================
    GuiControlGet, postAll, HarvestUI:Pos
    GuiControlGet, versionLink, HarvestUI:Pos
    newX_versionLink := (postAllX + postAllW) - versionLinkW
    GuiControl, Move, versionLink, x%newX_versionLink%
    GuiControlGet, versionText, HarvestUI:Pos
    newX_versionText := (postAllX + postAllW) - versionTextW 
    GuiControl, Move, versionText, x%newX_versionText%
; ===============================================================================
    gui, font    
    ;gui temp:hide
    return
    
    HarvestUIGuiEscape:
    HarvestUIGuiClose:
        ;rememberSession()
        saveWindowPosition()
        hideGUI()
    return
}

setWindowState(onTop) {
    mod := (onTop == 1) ? "+" : "-"
    Gui, HarvestUI:%mod%AlwaysOnTop
}

; === my functions ===
translate(keyword) {
    newKeyword := ""
    if (LanguageDictionary.HasKey(keyword)) {
        newKeyword := LanguageDictionary[keyword]
    }
    return newKeyword == "" ? keyword : newKeyword
}

translateToEnglish(text) {
    if (EnglishDictionary.HasKey(text)) {
        return EnglishDictionary[text]
    }
    return ""
}

TagExist(text, tag) {
    return InStr(text, tag) > 0
}

TemplateExist(text, template) {
    return RegExMatch(text, template) > 0
}

Handle_Augment(craftText, ByRef out) {
    if TagExist(craftText, "Influenced") {
        augments := [["Caster", "Caster"], ["Physical", "Physical"], ["Fire", "Fire"]
        , ["Attack", "Attack"], ["Life", "Life"], ["Cold", "Cold"]
        , ["Speed", "Speed"], ["Defence", "Defence"], ["Lightning", "Lightning"]
        , ["Chaos", "Chaos"], ["Critical", "Critical"], ["a new modifier", "Non-Influence"]]
        for k, v in augments {
            if TagExist(craftText, v[1]) {
                mod := TagExist(craftText, "Lucky") ? " Lucky" : ""
                out.push(["Augment " . v[2] . mod
                    , getLVL(craftText)
                    , "Aug"])
                return
            }
        }
        return
    }
    if TagExist(craftText, "Lucky"){
        out.push(["Augment Influence Lucky"
            , getLVL(craftText)
            , "Aug"])
    } else {
        out.push(["Augment Influence"
            , getLVL(craftText)
            , "Aug"])
    }
}

Handle_Remove(craftText, ByRef out) {
    if (TagExist(craftText, "Influenced") or TagExist(craftText, "influenced")) {
        if TagExist(craftText, "add") {
            removes := ["Caster", "Physical", "Fire", "Attack", "Life", "Cold"
                , "Speed", "Defence", "Lightning", "Chaos", "Critical"]
            mod := TagExist(craftText, "non") ? "Non-" : ""
            for k, v in removes {
                if TagExist(craftText, v) {
                    out.push(["Remove " . mod . v . " Add " . v
                        , getLVL(craftText)
                        , "Rem/Add"])
                    return
                }
            }
        } else {
            augments := ["Caster", "Physical", "Fire", "Attack", "Life", "Cold"
                , "Speed", "Defence", "Lightning", "Chaos", "Critical", "a new modifier"]
            for k, v in augments {
                if TagExist(craftText, v) {
                    out.push(["Remove " . v
                        , getLVL(craftText)
                        , "Rem"])
                    return
                }
            }
        }
        return
    }
    if TagExist(craftText, "add") {
        mod := TagExist(craftText, "non") ? "Non-" : ""
        out.push(["Remove " . mod . "Influence Add Influence"
            , getLVL(craftText)
            , "Rem/Add"])
    } else {
        out.push(["Remove Influence"
            , getLVL(craftText)
            , "Rem"])
    }
}

Handle_Reforge(craftText, ByRef out) {
    ;prefixes
    if TagExist(craftText, "Prefixes") {
        mod := TagExist(craftText, "Lucky") ? " Lucky" : ""
        out.push(["Reforge keep Prefix" . mod 
            , getLVL(craftText)
            , "Ref"])
        return
    }
    ;suffixes
    if TagExist(craftText, "Suffixes") {
        mod := TagExist(craftText, "Lucky") ? " Lucky" : ""
        out.push(["Reforge keep Suffix" . mod
            , getLVL(craftText)
            , "Ref"])
        return
    }
    ; reforge rares
    remAddsClean := ["Caster", "Physical", "Fire", "Attack", "Life", "Cold"
        , "Speed", "Defence", "Lightning", "Chaos", "Critical", "Influence"]
    if TagExist(craftText, "including") { ; 'including' text appears only in reforge rares
        for k, v in remAddsClean {
            if TagExist(craftText, v) {
                mod := TagExist(craftText, "more") ? " More Common" : ""
                out.push(["Reforge " . v . mod
                    , getLVL(craftText)
                    , "Ref"])
                return
            }
        }
        return
    } 
    ;reforge same mod
    if TemplateExist(craftText, "less.+likely") {
        out.push(["Reforge Rare Less Likely"
            , getLVL(craftText)
            , "Ref"])
        return
    }
    if TemplateExist(craftText, "more.+likely") {
        out.push(["Reforge Rare More Likely"
            , getLVL(craftText)
            , "Ref"])
        return
    }
    if TagExist(craftText, "times") {
        ;Reforge the links between sockets/links on an item 10 times
        return
    }
    ;links
    if TagExist(craftText, "links") {
        if TagExist(craftText,"six") {
            out.push(["Six Links"
                , getLVL(craftText)
                , "Other"])
        } else if TagExist(craftText, "five") {
            out.push(["Five Links"
                , getLVL(craftText)
                , "Other"])
        }
        return
    }
    ;colour
    if TagExist(craftText, "colour") {
        reforgeNonColor := {"Red": "non.+Red"
            , "Blue": "non.+Blue"
            , "Green": "non.+Green"}
        for color, v in reforgeNonColor {
            if TemplateExist(craftText, v) {
                out.push(["Non-" . color . " into " . color . " Socket"
                    , getLVL(craftText)
                    , "Other"])
                return
            } 
        }
        reforge2color := [["Red, Blue and Green", "Red.+Blue.+and.+Green"]
            , ["Red and Green", "Red.+and.+Green"]
            , ["Blue and Green", "them.+Blue.+and.+Green"]
            , ["Red and Blue", "Red.+and.+Blue"]
            , ["White", "White"]]
        for color, colortemp in reforge2color {
            if TemplateExist(craftText, colortemp[2]) {
                out.push(["Reforge into " . colortemp[1] . " Socket"
                    , getLVL(craftText)
                    , "Ref"])
                return
            }
        }
        return
    }
    if TagExist(craftText, "Influence") {
        out.push(["Reforge with Influence mod more common"
            , getLVL(craftText)
            , "Ref"])
        return
    }
}

Handle_Enchant(craftText, ByRef out) {
    ;weapon
    if TagExist(craftText, "Weapon") {
        weapEnchants := {"Critical Strike Chance": "Critical.+Strike.+Chance"
            , "Accuracy": "Accuracy"
            , "Attack Speed": "Attack.+Speed"
            , "Weapon Range": "Weapon.+Range"
            , "Elemental Damage": "Elemental"
            , "Area of Effect": "Area.+of.+Effect"}
        for enchant, enchanttemp in weapEnchants {
            if TemplateExist(craftText, enchanttemp) {
                out.push(["Enchant Weapon, " . enchant
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
    ;body armour
    if TagExist(craftText, "Armour") { 
        bodyEnchants := {"Maximum Life": "Maximum.+L[il]fe"
            , "Maximum Mana": "Maximum.+Mana"
            , "Strength": "Strength"
            , "Dexterity": "Dexterity"
            , "Intelligence": "Intelligence"
            , "Fire Resist": "Fire.+Resistance"
            , "Cold Resist": "Cold.+Resistance"
            , "Lightning Resist": "Lightning.+Resistance"}
        for enchant, enchanttemp in bodyEnchants {
            if TemplateExist(craftText, enchanttemp) {
                out.push(["Enchant Body, " . enchant
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
    ;Map
    if TagExist(craftText, "Sextant") {
        out.push(["Enchant Map, Doesn't Consume Sextant"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TagExist(craftText, "Tormented") {
        out.push(["Enchant Map, surrounded by Tormented Spirits"
            , getLVL(craftText)
            , "Other"])
        return
    }
    ;flask
    if TagExist(craftText, "Flask") {
        flaskEnchants := {"inc Duration": "Duration"
            , "inc Effect": "Effect"
            , "inc Maximum Charges": "Maximum.+Charges"
            , "reduced Charges used": "Charges.+used"}
        for flaskEnchant, flasktemp in flaskEnchants {
            if TemplateExist(craftText, flasktemp) {
                out.push(["Enchant Flask, " . flaskEnchant
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
}

Handle_Attempt(craftText, ByRef out) {
    ;awaken
    if TagExist(craftText, "Awaken") {
        out.push(["Awaken Level 20 Support Gem"
            , getLVL(craftText)
            , "Other"])
        return
    }
    ;scarab upgrade
    if TagExist(craftText, "Scarab") { 
        out.push(["Attempt to upgrade a Scarab"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Change(craftText, ByRef out) {
    ; res mods
    if TagExist(craftText, "Resistance") {
        firePos := InStr(craftText, "Fire")
        coldPos := InStr(craftText, "Cold")
        lightPos := InStr(craftText, "Lightning")

        rightMostPos := max(firePos, coldPos, lightPos)
        if (rightMostPos == firePos) {
            if (coldPos > 0) {
                out.push(["Cold to Fire Resist"
                    , getLVL(craftText)
                    , "Other"])
            } else if (lightPos > 0) {
                out.push(["Lightning to Fire Resist"
                    , getLVL(craftText)
                    , "Other"])
            }
        } else if (rightMostPos == coldPos) {
            if (firePos > 0) {
                out.push(["Fire to Cold Resist"
                    , getLVL(craftText)
                    , "Other"])
            } else if (lightPos > 0) {
                out.push(["Lightning to Cold Resist"
                    , getLVL(craftText)
                    , "Other"])
            }
        } else if (rightMostPos == lightPos) {
            if (firePos > 0) {
                out.push(["Fire to Lightning Resist"
                    , getLVL(craftText)
                    , "Other"])
            } else if (coldPos > 0) {
                out.push(["Cold to Lightning Resist"
                    , getLVL(craftText)
                    , "Other"])
            }
        }
        return
    }
    if TemplateExist(craftText, "(Bestiary|Lures)") {
        out.push(["Change Unique Bestiary item or item with Aspect into Lures"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TagExist(craftText, "Delirium") {
        out.push(["Change a stack of Delirium Orbs"
            , getLVL(craftText)
            , "Other"])
        return
    } 
    ; ignore others ?
}

Handle_Sacrifice(craftText, ByRef out) {
    ;gem for gcp/xp
    if TagExist(craftText, "Gem") {
        gemPerc := ["20%", "30%", "40%", "50%"]
        for k, v in gemPerc {
            if TagExist(craftText, v) {
                if TagExist(craftText, "quality") {
                    out.push(["Sacrifice Gem, " . v . " Quality As GCP"
                        , getLVL(craftText)
                        , "Other"])
                } else if TagExist(craftText, "experience") {
                    out.push(["Sacrifice Gem, " . v . " XP As Facetor Lens"
                        , getLVL(craftText)
                        , "Other"])
                }
                return
            }
        }
        return
    }
    ;div cards gambling
    if TagExist(craftText, "Divination") { 
        if TemplateExist(craftText, "half.+a.+stack") {
            out.push(["Sacrifice Divination Card 0-2x"
                , getLVL(craftText)
                , "Other"])
        }
        return
        ;skipping this:
        ;   Sacrifice a stack of Divination Cards for that many different Divination Cards
    }
    ;ignores the rest of sacrifice crafts:
        ;Sacrifice or Mortal Fragment into another random Fragment of that type
        ;Sacrificie Maps for same or lower tier stuff
        ;Sacrifice maps for missions
        ;Sacrifice maps for map device infusions
        ;Sacrifice maps for fragments
        ;Sacrifice maps for map currency
        ;Sacrifice maps for scarabs
        ;sacrifice t14+ map for elder/shaper/synth map
        ;sacrifice weap/ar to make similiar belt/ring/amulet/jewel
   
}

Handle_Improves(craftText, ByRef out) {
    if TagExist(craftText, "Gem") {
        out.push(["Improves the Quality of a Gem"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TagExist(craftText, "Flask") {
        out.push(["Improves the Quality of a Flask"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Fracture(craftText, ByRef out) {
    fracture := {"modifier": "1/5", "Suffix": "1/3 Suffix", "Prefix": "1/3 Prefix"}
    for k, v in fracture {
        if TagExist(craftText, k) {
            out.push(["Fracture " . v
                , getLVL(craftText)
                , "Other"])
            return
        }
    }
}

Handle_Reroll(craftText, ByRef out) {
    if TagExist(craftText, "Implicit") {
        out.push(["Reroll All Lucky"
            , getLVL(craftText)
            , "Other"])
        return  
    }
    if TagExist(craftText, "Prefix") {
        out.push(["Reroll Prefix Lucky"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TagExist(craftText, "Suffix") {
        out.push(["Reroll Suffix Lucky"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Randomise(craftText, ByRef out) {
    if TagExist(craftText, "Influence") { 
        addInfluence := ["Weapon", "Armour", "Jewellery"]
        for k, v in addInfluence {
            if TagExist(craftText, v) {
                out.push(["Randomise Influence " . v
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
    if TagExist(craftText, "numeric") {
        augments := ["Caster", "Physical", "Fire", "Attack", "Life", "Cold"
            , "Speed", "Defence", "Lightning", "Chaos", "Critical", "a new modifier"]
        for k, v in augments {
            if TagExist(craftText, v) {
                out.push(["Randomise values of " . v . " mods"
                    , getLVL(craftText)
                    , "Other"])
                return
            }
        }
        return
    }
}

Handle_Add(craftText, ByRef out) {
    addInfluence := ["Weapon", "Armour", "Jewellery"]
    for k, v in addInfluence {
        if TagExist(craftText, v) {
            out.push(["Add Influence to " . v
                , getLVL(craftText)
                , "Other"])
            return
        }
    }
}

Handle_Set(craftText, ByRef out) {
    if TagExist(craftText, "Prismatic") {
        out.push(["Set Implicit, Basic Jewel"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TemplateExist(craftText, "(Timeless|Abyss)") {
        out.push(["Set Implicit, Abyss/Timeless Jewel"
            , getLVL(craftText)
            , "Other"])
        return
    }
    if TagExist(craftText, "Cluster") {
        out.push(["Set Implicit, Cluster Jewel"
            , getLVL(craftText)
            , "Other"])
        return
    }
}

Handle_Synthesise(craftText, ByRef out) {
    out.push(["Synthesise an item"
        , getLVL(craftText)
        , "Other"])
}

Handle_Corrupt(craftText, ByRef out) {
    ;Corrupt an item 10 times, or until getting a corrupted implicit modifier
}

Handle_Exchange(craftText, ByRef out) {
    ;skipping all exchange crafts assuming anybody would just use them for themselfs
}

Handle_Upgrade(craftText, ByRef out) {
    if TagExist(craftText, "Rare") {
        if TemplateExist(craftText, "two.+random.+high-tier.+modifiers") {
            out.push(["Upgrade Magic to Rare adding 2 high-tier mods"
                , getLVL(craftText)
                , "Other"])
        } else if TemplateExist(craftText, "two.+random.+modifiers") {
            out.push(["Upgrade Magic to Rare adding 2 mods"
                , getLVL(craftText)
                , "Other"])
        } else if TemplateExist(craftText, "three.+random.+high-tier.+modifiers") {
            out.push(["Upgrade Magic to Rare adding 3 high-tier mods"
                , getLVL(craftText)
                , "Other"])
        } else if TemplateExist(craftText, "three.+random.+modifiers") {
            out.push(["Upgrade Magic to Rare adding 3 mods"
                , getLVL(craftText)
                , "Other"])
        } else if TemplateExist(craftText, "four.+random.+high-tier.+modifiers") {
                    out.push(["Upgrade Magic to Rare adding 4 high-tier mods"
                        , getLVL(craftText)
                        , "Other"])
        } else if TemplateExist(craftText, "four.+random.+modifiers") {
            out.push(["Upgrade Magic to Rare adding 4 mods"
                , getLVL(craftText)
                , "Other"])
        }
        return
    }
    if TagExist(craftText, "Normal") {
        if TemplateExist(craftText, "one.+random") {
            out.push(["Upgrade Normal to Magic adding 1 high-tier mod"
                , getLVL(craftText)
                , "Other"])
        } else if TemplateExist(craftText, "two.+random") {
            out.push(["Upgrade Normal to Magic adding 2 high-tier mods"
                , getLVL(craftText)
                , "Other"])
        }
        return
    }
    ;skipping upgrade crafts
}

Handle_Split(craftText, ByRef out) {
    ;skipping Split scarab craft
}

; === my functions ===
;function for "tessedit_pageseg_mode 3" or "tessedit_pageseg_mode 4"
;3 = Fully automatic page segmentation, but no OSD(Orientation and script detection).
getCraftsPlus(craftsText, levelsText) {
    tempLevels := RegExReplace(levelsText, "(" . TemplateForLevel . ")", "#$1")
    tempLevels := SubStr(tempLevels, inStr(tempLevels, "#") + 1)
    ArrayedLevels := StrSplit(tempLevels, "#")
    
    craftsText := RegExReplace(craftsText, "[\.\,]+", " ") ;remove all "," and "."
    craftsText := RegExReplace(craftsText, " +?[^a1234567890] +?", " ") ;remove all single symbols except "a" and digits
    craftsText := Trim(RegExReplace(craftsText, " +", " ")) ;remove possible double spaces    
    NewLined := RegExReplace(craftsText, TemplateForCrafts, "#$1")
    NewLined := SubStr(NewLined, inStr(NewLined, "#") + 1) ; remove all before "#" and "#" too
    
    arr := {}
    arr := StrSplit(NewLined, "#")
    for index in arr {
        level := ArrayedLevels.HasKey(index) ? " " . ArrayedLevels[index] : ""
        arr[index] := arr[index] . level
    }
    return arr
}

;function for "tessedit_pageseg_mode 6" by default in Capture2Text.exe
;6 = Assume a single uniform block of text.
getCrafts(temp) {
    NewLined := RegExReplace(temp, TemplateForCrafts, "#$1")
    NewLined := SubStr(NewLined, inStr(NewLined, "#") + 1) ; remove all before "#" and "#" too
    
    arr := {}
    arr := StrSplit(NewLined, "#")
    return arr
}

processCrafts(file) {
    ; the file parameter is just for the purpose of running a test script with different input files of crafts instead of doing scans
    WinActivate, Path of Exile
    sleep, 500
    Tooltip, % translate("Please Wait"), x_end, y_end
    
    ; screen_rect := " -s """ . x_start . " " . y_start . " " 
        ; . x_end . " " . y_end . """"
    aspectRatioForLevel := 0.18
    areaWidthLevel := Floor(aspectRatioForLevel * (x_end - x_start)) ; area width "Level"
    x_areaLevelStart := x_end - areaWidthLevel ; starting X-position "Level"
    screen_rect_Craft := " -s """ . x_start . " " . y_start . " " 
        . x_areaLevelStart . " " . y_end . """" ; 82% of the area for "Craft"
    screen_rect_Level := " -s """ . x_areaLevelStart . " " . y_start . " " 
    . x_end . " " . y_end . """" ;  18% of the area for "Level"
    temp := {}
    for k, v in [screen_rect_Craft, screen_rect_Level] {
        command := Capture2TextExe . v . Capture2TextOptions
        RunWait, %command%,,Hide
        
        if !FileExist(TempPath) {
            MsgBox, % translate("- We were unable to create temp.txt to store text recognition results.") . "`r`n" . translate("- The tool most likely doesnt have permission to write where it is.") . "`r`n" . translate("- Moving it into a location that isnt write protected, or running as admin will fix this.")
            return false
        }
        FileRead, curtemp, %file%
        temp.push(curtemp)
    }
    WinActivate, ahk_pid %PID%
    Tooltip
    ;add craftsText and levelsText in temp.txt
    FileDelete, %file%
    FileAppend, % temp[1] . temp[2], %file%
    ;FileRead, temp, test2.txt

    Arrayed := getCraftsPlus(temp[1], temp[2])
    outArray := {}
    ;outArrayCount := 0
    for index in Arrayed {  
        craftText := Trim(Arrayed[index])
        ;StrLen("Set an item to six sockets") = 26. its min length for craft
        if (craftText == "" or StrLen(craftText) < 26) {
            continue ;skip empty or short fields
        } 
        for k, v in CraftNames {
            craftName := v[1]
            if TagExist(craftText, v[2]) {
                if IsFunc("Handle_" . craftName) {
                    Handle_%craftName%(craftText, outArray)
                }
                break
            }
        }
    }
    for iFinal, v in outArray {
        craftName := v[1]
        outArray[iFinal, 1] := Trim(RegExReplace(craftName , " +", " ")) 
    }   
    ;this bit is for testing purposes, it should never trigger for normal user cos processCrafts is always run with temp.txt 
    if (file != TempPath) {
        for s in outArray {
            str .= outArray[s, 1] . "`r`n"
        }
        path := "results\out-" . file
        FileAppend, %str%, %path%
    }
    return true
}

updateCraftTable(ar) { 
    tempC := ""
    isNeedSort := False
    uiRows := []
    for k, v in ar {
        tempC := v[1]
        tempLvl := v[2] 
        tempType := v[3]
        for k, row in CraftTable {
            if (row.craft == tempC and row.lvl == tempLvl) {
                CraftTable[k].count := row.count + 1
                uiRows.push(k)
                break
            }
            if (row.craft == "") {
                insertIntoRow(k, tempC, tempLvl, tempType)
                isNeedSort := True
                break
            }
        }
    }
    if (isNeedSort) {
        sortCraftTable()
    } else {
        for k, v in uiRows {
            updateUIRow(v, "count")
        }
    }
    sumTypes()
    sumPrices()
}

sortCraftTable() {
    craftsArr := []
    for k, row in CraftTable {
        if (row.craft != "") { ;not empty crafts
            craftsArr.push(row)
        }
    }
    craftsArr := sortBy(craftsArr, "craft")
    ;insert a new sorted crafts
    for k in CraftTable {
        if (craftsArr.HasKey(k)) {
            CraftTable[k] := craftsArr[k]
        } else {
            ;clear old crafts
            clearRowData(k)
        }
        updateUIRow(k)
    }
}

insertIntoRow(rowCounter, craft, lvl, type) {
    tempP := getPriceFor(craft)
    CraftTable[rowCounter] := {"count": 1, "craft": craft, "price": tempP
            , "lvl": lvl, "type": type}
}

updateUIRow(rowCounter, parameter:="All") {
    row := CraftTable[rowCounter]
    needToChangeModel := False
    if (parameter == "All") {
        GuiControl,HarvestUI:, craft_%rowCounter%, % row.craft
        GuiControl,HarvestUI:, count_%rowCounter%, % row.count
        GuiControl,HarvestUI:, lvl_%rowCounter%, % row.lvl
        GuiControl,HarvestUI:, type_%rowCounter%, % translate(row.type)
        GuiControl,HarvestUI:, price_%rowCounter%, % row.price
    } else {
        if (row.HasKey(parameter)) {
            value := row[parameter]
            value := (parameter == "type") ? translate(value) : value
            GuiControl,HarvestUI:, %parameter%_%rowCounter%, % value
        }
    }
    needToChangeModel := True
}

;added by Stregon#3347
;=============================================================================
getPadding(width, maxWidth) {
    spaces := ""
    loop, % (maxWidth - width) {
        spaces .= " "
    }
    return spaces
}

; no colors, no codeblock, but highlighted
getNoColorStyleRow(count, craft, price, lvl) {
    spaces_count_craft := getPadding(StrLen(count), maxLengths.count + 1)
    spaces_craft_lvl := getPadding(StrLen(craft), maxLengths.craft + 1)
    spaces_lvl_price := getPadding(StrLen(lvl), maxLengths.lvl + 2)
    
    postRowString := "   ``" . count . "x" . spaces_count_craft . "``**``" . craft . "``**``" . spaces_craft_lvl . "[" . lvl . "]" 
    if (price != " ") {
        postRowString .= spaces_lvl_price . "<``**``" . price . "``**``>"
    }
    
    return postRowString . "```r`n"
}

; message style with colors, in codeblock but text isnt highlighted in discord search
getColorStyleRow(count, craft, price, lvl) {
    spaces_count_craft := getPadding(StrLen(count), maxLengths.count + 1)
    spaces_craft_lvl := getPadding(StrLen(craft), maxLengths.craft + 1)
    spaces_lvl_price := getPadding(StrLen(lvl), maxLengths.lvl + 2)

    postRowString := "  " . count . "x" . spaces_count_craft . "[" . craft . spaces_craft_lvl . "]" . "[" . lvl . "]" 
    if (price != " ") {
        postRowString .= spaces_lvl_price . "< " . price . " >"
    }
    return postRowString . "`r`n"
}

getPostRow(count, craft, price, group, lvl) {
    price := (price == "") ? " " : price
    ; no colors, no codeblock, but highlighted
    if (settingsApp.outStyle == 1) { 
        return getNoColorStyleRow(count, craft, price, lvl)
    }
    ; message style with colors, in codeblock but text isnt highlighted in discord search
    if (settingsApp.outStyle == 2) { 
        return getColorStyleRow(count, craft, price, lvl)
    }
    return ""
}

getSortedPosts(type) {
    posts := ""
    postsArr := []
    for k, row in CraftTable {
        if ((row.count != "" and row.count > 0)
            and (row.type == type or type == "All")) {
            postsArr.push(row)
        }
    }
    postsArr := sortBy(postsArr, ["count", "craft"])
    for Index, row in postsArr {
        posts .= getPostRow(row.count, row.craft, row.price
            , row.type, row.lvl)
    }
    return posts
}

getPosts(type) {
    posts := ""
    for k, row in CraftTable {
        if ((row.count != "" and row.count > 0)
            and (row.type == type or type == "All")) {
            posts .= getPostRow(row.count, row.craft, row.price
                , row.type, row.lvl)
        }
    }
    return posts
}

codeblockWrap(text) {
    if (settingsApp.outStyle == 1) {
        return text
    }
    if (settingsApp.outStyle == 2) {
        return "``````md`r`n" . text . "``````"
    }
}

getNoColorStyleHeader() {
    tempName := settingsApp.nick
    tempLeague := RegExReplace(settingsApp.selectedLeague, "SC", "Softcore")
    tempLeague := RegExReplace(tempLeague, "HC", "Hardcore")
    
    outString := "**WTS " . tempLeague . "**"
    if (tempName != "") {
        tempName := RegExReplace(tempName, "\\*?_", "\_") ;fix for discord
        outString .= " - IGN: **" . tempName . "**" 
    }
    outString .= " ``|  generated by HarvestVendor fork```r`n"
    if (settingsApp.CustomTextCB == 1 and settingsApp.customText != "") {
        outString .= "   " . settingsApp.customText . "`r`n"
    }
    if (settingsApp.canStream == 1) {
        outString .= "   *Can stream if requested*`r`n"
    }
    return outString
}

getColorStyleHeader() {
    tempName := settingsApp.nick
    tempLeague := RegExReplace(settingsApp.selectedLeague, "SC", "Softcore")
    tempLeague := RegExReplace(tempLeague, "HC", "Hardcore")
    
    outString := "#WTS " . tempLeague
    if (tempName != "") {
        outString .= " - IGN: " . tempName
    }
    outString .= " |  generated by HarvestVendor fork`r`n"
    if (settingsApp.CustomTextCB == 1 and settingsApp.customText != "") {
        outString .= "  " . settingsApp.customText . "`r`n"
    }
    if (settingsApp.canStream == 1) {
        outString .= "  Can stream if requested `r`n"
    }
    return outString
}

;puts together the whole message that ends up in clipboard
createPost(type) {
    maxLengths := {}
    maxLengths.count := getMaxLenghtColunm("count")
    maxLengths.craft := getMaxLenghtColunm("craft")
    maxLengths.lvl := getMaxLenghtColunm("lvl")
    header := ""
    if (settingsApp.outStyle == 1) {
        header := getNoColorStyleHeader()
    }
    if (settingsApp.outStyle == 2) {
        header := getColorStyleHeader()
    }
    Clipboard := codeblockWrap(header . getSortedPosts(type))
    readyTT()
}

readyTT() {
    ClipWait
    ToolTip, % translate("Paste Ready"),,,1
    sleep, 2000
    Tooltip,,,,1
}

getMaxLenghtColunm(column) {
    MaxLen_column := 0
    for k, row in CraftTable {
        if (row.count <= 0) {
            continue
        }
        columnValue := row[column]
        if (StrLen(columnValue) > MaxLen_column) {
            MaxLen_column := StrLen(columnValue)
        }
    }
    return MaxLen_column
}
;============================================================
getPriceFor(craft) {
    if (craft == "") {
        return ""
    }
    while (True) {
        iniRead, tempP, %PricesPath%, Prices, %craft%
        if (tempP == "ERROR") {
            return ""
        }
        if (tempP != "") {
            return tempP
        }
        ;Delete craft with blank price
        iniDelete, %PricesPath%, Prices, %craft%
    }
}

getTypeFor(craft) {
    if (craft == "") {
        return ""
    }
    if (inStr(craft, "Reforge") == 1) {
        return "Ref"
    }
    if (inStr(craft, "Augment") == 1) {
        return "Aug"
    } 
    ; if (InStr(craft, "Remove") == 1 and instr(craft, "add") == 0) {
        ; return "Rem"
    ; } 
    if (inStr(craft, "Remove") == 1 and instr(craft, "add") > 0) {
        return "Rem/Add"
    }
    return "Other"
}

getRow(elementVariable) {
    temp := StrSplit(elementVariable, "_")
    return temp[temp.Length()]
}

getLVL(craft) {
    map_levels := {"S1": "81", "Sz": "82", "SQ": "80", "8i": "81", "6g": "68"}
    lvlpos := RegExMatch(craft, "O)" . TemplateForLevel . " *(\w\w).*$", matchObj)
    lv := matchObj[1]
    if RegExMatch(lv, "\d\d") > 0 {
        if (lv < 37) { ;ppl wouldn't sell lv 30 crafts, but sometimes OCR mistakes 8 for a 3 this just bumps it up for the 76+ rule
            lv += 50
        }
        return lv > 86 ? "" : lv
    } else {
        for k, v in map_levels {
            if (k == lv) {
                return v
            }
        }
        return ""
    }
}

sumPrices() {
    tempSumChaos := 0
    tempSumEx := 0
    exaltTemplate := "Oi)^(\d*[\.,]{0,1}?\d+) *(ex|exa|exalt)$"
    chaosTemplate := "Oi)^(\d+) *(c|chaos)$"
    for k, row in CraftTable {
        if (row.craft == "" or row.price == "") {
           continue
        }
        priceCraft := Trim(row.price)
        countCraft := row.count
        matchObj := []
        if (RegExMatch(priceCraft, chaosTemplate, matchObj) > 0) {
            priceCraft := strReplace(matchObj[1], ",", ".")
            tempSumChaos +=  priceCraft * countCraft
        } else if (RegExMatch(priceCraft, exaltTemplate, matchObj) > 0) {
            priceCraft := strReplace(matchObj[1], ",", ".")
            tempSumEx += priceCraft * countCraft
        }
    }
    tempSumEx := round(tempSumEx, 1)
    GuiControl,HarvestUI:, sumChaos, %tempSumChaos%
    GuiControl,HarvestUI:, sumEx, %tempSumEx%
}

sumTypes() {
    stats := {"Aug": 0, "Ref": 0, "Rem/Add": 0, "Other": 0, "All": 0}
    for k, row in CraftTable {
        tempAmount := row.count
        if (tempAmount == "") {
            continue
        }
        tempType := row.type
        if (stats.HasKey(tempType)) {
            stats[tempType] := stats[tempType] + tempAmount
            stats["All"] := stats["All"] + tempAmount
        }   
    }
    GuiControl,HarvestUI:, Acount, % stats["Aug"]
    GuiControl,HarvestUI:, Refcount, % stats["Ref"]
    GuiControl,HarvestUI:, RAcount, % stats["Rem/Add"]
    GuiControl,HarvestUI:, Ocount, % stats["Other"]
    GuiControl,HarvestUI:, CraftsSum, % stats["All"]
}

buttonHold(buttonV, picture) {
    while GetKeyState("LButton", "P") {
        guiControl,, %buttonV%, %picture%_i.png 
        sleep, 25
    }
    guiControl,, %buttonV%, %picture%.png
}

rememberSession() { 
    if (sessionLoading or isLoading or firstGuiOpen) {
        return
    }
    for k, row in CraftTable {
        line := ""
        if (row.craft != "") {
            line := row.craft . "|" . row.lvl . "|" . row.count . "|" . row.type
        }
        IniWrite, %line%, %SettingsPath%, LastSession, craft_%k%
    }
}

loadLastSession() {
    if (!firstGuiOpen) {
        return
    }
    sessionLoading := True
    for k in CraftTable {
        IniRead, lastCraft, %SettingsPath%, LastSession, craft_%k% 
        if (lastCraft == "ERROR" or lastCraft == "") {
            continue
        }
        split := StrSplit(lastCraft, "|")
        craft := split[1]
        tempP := getPriceFor(craft)
        type := getTypeFor(craft)
        CraftTable[k] := {"count": split[3], "craft": craft, "price": tempP
            , "lvl": split[2], "type": type}
        updateUIRow(k)
    }
    sessionLoading := False
    sumTypes()
    sumPrices()
}

clearRowData(rowIndex) {
    CraftTable[rowIndex] := {"count": 0, "craft": "", "price": ""
        , "lvl": "", "type": ""}
}

clearAll() {
    loop, % settingsApp.MaxRowsCraftTable {
        clearRowData(A_Index)
        updateUIRow(A_Index)
    }
    outArray := {}
}
; === technical stuff i guess ===
getLeagues() {
    leagueAPIurl := "http://api.pathofexile.com/leagues?type=main&compact=1"
    if FileExist("curl.exe") {
        ; Hack for people with outdated certificates
        shell := ComObjCreate("WScript.Shell")
        exec := shell.Exec("curl.exe -k " . leagueAPIurl)
        response := exec.StdOut.ReadAll()
    } else {
        oWhr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        oWhr.Open("GET", leagueAPIurl, false)
        oWhr.SetRequestHeader("Content-Type", "application/json")
        oWhr.Send()
        response := oWhr.ResponseText
    }
    if (oWhr.Status == "200" or FileExist("curl.exe")) {
        if InStr(response, "Standard") > 0 {
            parsed := JSON.Load(response)
            maxCount := 8
            for k, v in parsed {
                if (k > maxCount) { ;take first 8
                    break
                }
                settingsApp.LeagueList[k] := v["id"]
            }
        } else {
            IniRead, lc, %SettingsPath%, Leagues, 1
            if (lc == "ERROR" or lc == "") {
                msgbox, % translate("Unable to get list of leagues from GGG API") . "`r`n" . translate("You will need to copy [Leagues] and [selectedLeague] sections from the example settings.ini on github")
            }
        }

        if !FileExist(SettingsPath) {
            MsgBox, % translate("Looks like AHK was unable to create settings.ini") . "`r`n" . translate("This might be because the place you have the script is write protected by Windows") . "`r`n" . translate("You will need to place this somewhere else")
        }
    } else {
        Msgbox, % translate("Unable to get active leagues from GGG API, using placeholder names")
        settingsApp.LeagueList[1] := "Temp"
        settingsApp.LeagueList[2] := "Hardcore Temp"
        settingsApp.LeagueList[3] := "Standard"
        settingsApp.LeagueList[4] := "Hardcore"
    }
}

getLeagueList() {
    leagueString := ""
    defaultLeague := "Standard SC"
    for k, v in settingsApp.LeagueList {
        tempList := v
        if (templist == "" or InStr(tempList, "SSF") > 0) {
            continue
        }
        if !InStr(tempList, "Hardcore") and !InStr(tempList, "HC") {
            tempList .= " SC"
            if !InStr(tempList, "Standard", true) {
                defaultLeague := templist
            }
        } else if (tempList == "Hardcore") {
            tempList := "Standard HC"
        }
        leagueString .= tempList . "|"
    }
    if (settingsApp.selectedLeague == "" 
        or !InStr(leagueString, settingsApp.selectedLeague)) {
        settingsApp.selectedLeague := defaultLeague
    }
    return leagueString
}

getVersion() {
    versionUrl := "https://raw.githubusercontent.com/Stregon/PoE-HarvestVendor/master/version.txt"
    if FileExist("curl.exe") {
        ; Hack for people with outdated certificates
        shell := ComObjCreate("WScript.Shell")
        exec := shell.Exec("curl.exe -k " . versionUrl)
        response := exec.StdOut.ReadAll()
    } else {
        ver := ComObjCreate("WinHttp.WinHttpRequest.5.1")
        ver.Open("GET", versionUrl, false)
        ver.SetRequestHeader("Content-Type", "application/json")
        ver.Send()
        response := ver.ResponseText
    }
    return StrReplace(StrReplace(response, "`r"), "`n")
}

IsGuiVisible(guiName) {
    Gui, %guiName%: +HwndguiHwnd
    return DllCall("User32\IsWindowVisible", "Ptr", guiHwnd)
}

checkFiles() {
    if !FileExist("Capture2Text") {
        if FileExist("Capture2Text.exe") {
            msgbox, % translate("Looks like you put PoE-HarvestVendor.ahk into the Capture2Text folder") . "`r`n" . translate("This is wrong") . "`r`n" . translate("Take the file out of this folder")
        } else {
            msgbox, % translate("I don't see the Capture2Text folder, did you download the tool ?") . "`r`n" . translate("Link is in the GitHub readme under Getting started section")
        }
        ExitApp
    }   
    
    if !FileExist(SettingsPath) {
        msgbox, % translate("Looks like you put PoE-HarvestVendor in a write protected place on your PC.") . "`r`n" . translate("It needs to be able to create and write into a few text files in its directory.")
        ExitApp
    }
}

winCheck() {
    if (SubStr(A_OSVersion,1,2) != "10" and !FileExist("curl.exe")) {
         msgbox, % translate("Looks like you aren't running win10. There might be a problem with WinHttpRequest(outdated Certificates).") . "`r`n" . translate("You need to download curl, and place the curl.exe (just this 1 file) into the same directory as Harvest Vendor.") . "`r`n" . translate("Link in the FAQ section in readme on github")
    }
}

monitorInfo(num) {
   SysGet, Mon2, monitor, %num%
  
   x := Mon2Left
   y := Mon2Top
   height := abs(Mon2Top - Mon2Bottom)
   width := abs(Mon2Left - Mon2Right)

   return [x, y, height, width]
}

getMonCount() {
   monOut := ""
   sysGet, monCount, MonitorCount
   loop, %monCount% {
      monOut .= A_Index . "|"
   }
   return monOut
}

getImgWidth(img) {
    SplitPath, img, fn, dir
    objShell := ComObjCreate("Shell.Application")
    objFolder := objShell.NameSpace(dir)
    objFolderItem := objFolder.ParseName(fn)
    scale := StrSplit(RegExReplace(objFolder.GetDetailsOf(objFolderItem, 31), ".(.+).", "$1"), " x ")
    return scale.1 ; {w: scale.1, h: scale.2}
}

; ========================================================================
; ======================== stuff i copied from internet ==================
; ========================================================================

global SelectAreaEscapePressed := false
SelectAreaEscape:
    SelectAreaEscapePressed := true
return

SelectArea(Options="") { ; by Learning one
/*
Returns selected area. Return example: 22|13|243|543
Options: (White space separated)
- c color. Default: Blue.
- t transparency. Default: 50.
- g GUI number. Default: 99.
- m CoordMode. Default: s. s = Screen, r = Relative
*/
;full screen overlay
;press Escape to cancel

    scale := settingsApp.scale
    cover := monitorInfo(settingsApp.monitor)
    coverX := cover[1]
    coverY := cover[2]
    coverH := cover[3] / scale
    coverW := cover[4] / scale
    Gui, Select:New
    Gui, Color, 141414
    Gui, +LastFound +ToolWindow -Caption +AlwaysOnTop
    WinSet, Transparent, 120
    Gui, Select:Show, x%coverX% y%coverY% h%coverH% w%coverW%, "AutoHotkeySnapshotApp"


    isLButtonDown := false
    SelectAreaEscapePressed := false
    Hotkey, Escape, SelectAreaEscape, On
    while (!isLButtonDown and !SelectAreaEscapePressed) {
        ; Per documentation new hotkey threads can be launched while KeyWait-ing, so SelectAreaEscapePressed
        ; will eventually be set in the SelectAreaEscape hotkey thread above when the user presses ESC.

        KeyWait, LButton, D T0.1  ; 100ms timeout
        isLButtonDown := (ErrorLevel == 0)
    }

    areaRect := []
    if (!SelectAreaEscapePressed) {
        CoordMode, Mouse, Screen
        MouseGetPos, MX, MY
        CoordMode, Mouse, Relative
        MouseGetPos, rMX, rMY
        CoordMode, Mouse, Screen

        loop, parse, Options, %A_Space% 
        {
            Field := A_LoopField
            FirstChar := SubStr(Field, 1, 1)
            if (FirstChar contains c,t,g,m) {
                StringTrimLeft, Field, Field, 1
                %FirstChar% := Field
            }
        }
        c := (c == "") ? "Blue" : c
        t := (t == "") ? "50" : t
        g := (g == "") ? "99" : g
        m := (m == "") ? "s" : m

        Gui %g%: Destroy
        Gui %g%: +AlwaysOnTop -Caption +Border +ToolWindow +LastFound
        WinSet, Transparent, %t%
        Gui %g%: Color, %c%
        ;Hotkey := RegExReplace(A_ThisHotkey,"^(\w* & |\W*)")

        While (GetKeyState("LButton") and !SelectAreaEscapePressed)
        {
            Sleep, 10
            MouseGetPos, MXend, MYend        
            w := abs((MX / scale) - (MXend / scale)), h := abs((MY / scale) - (MYend / scale))
            X := (MX < MXend) ? MX : MXend
            Y := (MY < MYend) ? MY : MYend
            Gui %g%: Show, x%X% y%Y% w%w% h%h% NA
        }

        Gui %g%: Destroy

        if (!SelectAreaEscapePressed) {
            if (m == "s") { ; Screen
                MouseGetPos, MXend, MYend
                if (MX > MXend)
                    temp := MX, MX := MXend, MXend := temp ;* scale
                if (MY > MYend)
                    temp := MY, MY := MYend, MYend := temp ;* scale
                areaRect := [MX, MXend, MY, MYend]
            } else { ; Relative
                CoordMode, Mouse, Relative
                MouseGetPos, rMXend, rMYend
                if (rMX > rMXend)
                    temp := rMX, rMX := rMXend, rMXend := temp
                if (rMY > rMYend)
                    temp := rMY, rMY := rMYend, rMYend := temp
                areaRect := [rMX, rMXend, rMY, rMYend]
            }
        }
    }

    Hotkey, Escape, SelectAreaEscape, Off

    Gui, Select:Destroy
    Gui, HarvestUI:Default
    return areaRect
}

WM_MOUSEMOVE() {
    static CurrControl, PrevControl, _TT  ; _TT is kept blank for use by the ToolTip command below.
    CurrControl := A_GuiControl
    
    if (CurrControl != PrevControl and !InStr(CurrControl, " ")) {
        ToolTip,,,,2  ; Turn off any previous tooltip.
        SetTimer, DisplayToolTip, 500
        PrevControl := CurrControl
    }
    return

    DisplayToolTip:
    SetTimer, DisplayToolTip, Off
    ToolTip % %CurrControl%_TT,,,2  ; The leading percent sign tell it to use an expression.
    SetTimer, RemoveToolTip, 7000
    return

    RemoveToolTip:
    SetTimer, RemoveToolTip, Off
    ToolTip,,,,2
    return
}

WebPic(WB, url, Options := "") {
    RegExMatch(Options, "i)w\K\d+", W), (W = "") ? W := 50 :
    RegExMatch(Options, "i)h\K\d+", H), (H = "") ? H := 50 :
    RegExMatch(Options, "i)c\K\d+", C), (C = "") ? C := "EEEEEE" :
    WB.Silent := True
    HTML_Page :=
    (RTRIM
    "<!DOCTYPE html>
        <html>
            <head
                <meta http-equiv='X-UA-Compatible' content='IE=edge'>
                <style>
                    html, body {
                        height: 100%;
                        margin: 0;
                        padding: 0;
                        background-color: #" C ";
                    }
                    img {
                        max-width: 100%;
                        max-height: 100vh;
                        width: auto;
                        margin: auto;
                    }
                    .bg {
                        background-image: url(""" url """);
                        background-repeat: no-repeat;
                        background-size: cover;
                        background-position: center;
                        height: 100vh;
                        width: 100vw;
                    }
                </style>
            </head>
            <body>
                <div class=""bg"">
            </body>
        </html>"
    )
    While (WB.Busy)
        Sleep 10
    WB.Navigate("about:" HTML_Page)
    Return HTML_Page
}