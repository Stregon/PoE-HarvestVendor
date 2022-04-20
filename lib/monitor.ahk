getDpiForWindow(hwnd) {
    osv := StrSplit(A_OSVersion, ".")
    ;10.0.14393
    if (osv[1] >= 10 and osv[3] >= 14393) {
        return DllCall("User32.dll\GetDpiForWindow", "Ptr", hwnd)
    }
    hMonitor := getMonitorFromWindow(hwnd)
    dpi := getDpiForMonitor(hMonitor)
    return dpi ? dpi.X : 96
}

getMonitorFromWindow(Hwnd := 0) {
    ; Retrieve the identifier to the monitor that is closest to the specified window.
     ; Parameters:
         ; Hwnd:
             ; The identifier of the window of interest. If it is zero, it retrieves the identifier of the primary monitor.
    ; MonitorFromWindow function
    ; https://docs.microsoft.com/es-es/windows/desktop/api/winuser/nf-winuser-monitorfromwindow
    return DllCall("User32.dll\MonitorFromWindow", "Ptr", Hwnd, "UInt", Hwnd ? 2 : 1)
}

getDpiForMonitor(hMonitor, Type := 0) {
    ; Retrieve the dots per inch (dpi) of the specified monitor.
    ; Parameters:
        ; Type:
            ; The type of DPI that is consulted. Possible values ​​are as follows. This parameter is ignored in WIN_8 or earlier.
            ; 0 (MDT_EFFECTIVE_DPI)   = The effective DPI. This value should be used when determining the correct scale factor to scale UI elements. This incorporates the scale factor set by the user for this specific screen.
            ; 1 (MDT_ANGULAR_DPI) = The angular DPI. This DPI guarantees playback with a compatible angular resolution on the screen. This does not include the scale factor set by the user for this specific screen.
            ; 2 (MDT_RAW_DPI)             = The raw DPI. This value is the linear DPI of the screen measured on the screen. Use this value when you want to read the pixel density and not the recommended scaling settings.
                                                        ; This does not include the scale factor set by the user for this specific screen and is not guaranteed to be a supported PPP value.
    ; Return:
        ; If successful it returns an object with the keys X and Y, or zero otherwise.
    ; Observations:
        ; This function is not DPI Aware and should not be used if the call thread is compatible with DPI per monitor. For the version of this function that takes into account the DPI, see GetDpiForWindow.
    ; Example:
        ; MsgBox(GetDpiForMonitor(MonitorFromWindow()).X)

    osv := StrSplit(A_OSVersion, ".")    ; https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/content/wdm/ns-wdm-_osversioninfoexw
    if (osv[1] < 6 || (osv[1] == 6 && osv[2] < 3))    ; WIN_8-
    {
        hDC := 0, info := getMonitorInfo(hMonitor)
        if (!info || !(hDC := DllCall("Gdi32.dll\CreateDC", "Str", info.name, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr")))
            return FALSE    ; LOGPIXELSX = 88 | LOGPIXELSY = 90
        return {X:DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "Int", 88), Y:DllCall("Gdi32.dll\GetDeviceCaps", "Ptr", hDC, "Int", 90)+0*DllCall("Gdi32.dll\DeleteDC", "Ptr", hDC)}
    }
    ; GetDpiForMonitor function
    ; https://docs.microsoft.com/en-us/windows/desktop/api/shellscalingapi/nf-shellscalingapi-getdpiformonitor
    dpiX := 0, dpiY := 0
    return DllCall("Shcore.dll\GetDpiForMonitor", "Ptr", hMonitor, "Int", Type, "UIntP", dpiX, "UIntP", dpiY, "UInt") ? 0 : {X:dpiX,Y:dpiY}
}

getMonitorInfo(hMonitor) {
    ; Retrieve information from the specified monitor.
     ; Return:
         ; Returns an object with the following keys.
         ; L / T / R / B = Monitor rectangle, expressed in virtual screen coordinates. Note that if the monitor is not the main one, some of the coordinates may be negative.
         ; WL / W T / W R / WB = Rectangle of the work area of the monitor. //
         ; Flags = A set of values that represent attributes of the display monitor.
             ; 1 (MONITORINFOF_PRIMARY) = This is the main display monitor.
         ; Name = A string that specifies the name of the monitor device being used.

    ; GetMonitorInfo function
    ; https://docs.microsoft.com/es-es/windows/desktop/api/winuser/nf-winuser-getmonitorinfoa
    MONITORINFOEX := ""
    VarSetCapacity(MONITORINFOEX, 104)
    NumPut(104, &MONITORINFOEX, "UInt")
    if (!DllCall("User32.dll\GetMonitorInfoW", "Ptr", hMonitor, "UPtr", &MONITORINFOEX))
        return FALSE
    return {  L:          NumGet(&MONITORINFOEX+ 4  , "Int")
                , T:          NumGet(&MONITORINFOEX+ 8  , "Int")
                , R:      NumGet(&MONITORINFOEX+12  , "Int")
                , B:          NumGet(&MONITORINFOEX+16  , "Int")
                , WL:     NumGet(&MONITORINFOEX+20  , "Int")
                , WT:     NumGet(&MONITORINFOEX+24  , "Int")
                , WR:     NumGet(&MONITORINFOEX+28  , "Int")
                , WB:     NumGet(&MONITORINFOEX+32  , "Int")
                , Flags:   NumGet(&MONITORINFOEX+36 , "UInt")
                , Name: StrGet(&MONITORINFOEX+40,64 , "UTF-16") }
}
