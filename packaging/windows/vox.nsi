; Vox Windows installer (NSIS 3.x).
;
; Produces Vox-<version>-setup.exe from the portable zip built by
; `v run build_browser.vsh package-zip` (Build/windows/vox-portable.zip).
; Run from the repository root:  makensis packaging/windows/vox.nsi
;
; Requirements: NSIS 3.x. The zip is embedded into the installer at
; compile time (see package-installer flow); the setup EXE needs no
; sidecar files at install time.

!define APPNAME "Vox"
!define APPVERSION "0.1.3"
!define PUBLISHER "vox-browser"
!define URL "https://vox-browser.org"
!define ZIPFILE "vox-portable.zip"

Name "${APPNAME} ${APPVERSION}"
OutFile "..\..\Build\windows\Vox-${APPVERSION}-setup.exe"
InstallDir "$LOCALAPPDATA\${APPNAME}"
InstallDirRegKey HKCU "Software\${APPNAME}" "InstallDir"
RequestExecutionLevel user

!include "MUI2.nsh"
!include "LogicLib.nsh"

!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "..\..\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Install"
	; Stage the embedded portable zip, then extract it into $INSTDIR.
	; A missing zip fails here at compile time, not silently at install.
	SetOutPath "$PLUGINSDIR"
	File "Build\windows\vox-portable.zip"
	SetOutPath "$INSTDIR"
	DetailPrint "Extracting ${ZIPFILE}..."
	nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath ''$PLUGINSDIR\${ZIPFILE}'' -DestinationPath ''$INSTDIR'' -Force"'
	Pop $0
	${If} $0 != 0
		MessageBox MB_ICONSTOP "Extraction failed (exit code $0). The installation cannot continue."
		Abort
	${EndIf}
	; File and protocol associations (per-user). This registers Vox as
	; available for documents and links; it does not steal defaults,
	; which Windows guards behind the Settings app.
	WriteRegStr HKCU "Software\Classes\.html" "" "VoxHTML"
	WriteRegStr HKCU "Software\Classes\.htm" "" "VoxHTML"
	WriteRegStr HKCU "Software\Classes\.xhtml" "" "VoxHTML"
	WriteRegStr HKCU "Software\Classes\VoxHTML" "" "Vox HTML Document"
	WriteRegStr HKCU "Software\Classes\VoxHTML\shell\open\command" "" '"$INSTDIR\vox.exe" "%1"'
	WriteRegStr HKCU "Software\Classes\http" "" "URL:HyperText Transfer Protocol"
	WriteRegStr HKCU "Software\Classes\http" "URL Protocol" ""
	WriteRegStr HKCU "Software\Classes\http\shell\open\command" "" '"$INSTDIR\vox.exe" "%1"'
	WriteRegStr HKCU "Software\Classes\https" "" "URL:HyperText Transfer Protocol Secure"
	WriteRegStr HKCU "Software\Classes\https" "URL Protocol" ""
	WriteRegStr HKCU "Software\Classes\https\shell\open\command" "" '"$INSTDIR\vox.exe" "%1"'
	; App Paths so `vox` resolves from Run and the command line.
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\App Paths\vox.exe" "" "$INSTDIR\vox.exe"
	; Shortcuts
	CreateDirectory "$SMPROGRAMS\${APPNAME}"
	CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\vox.exe"
	CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\vox.exe"
	; Uninstaller registration
	WriteUninstaller "$INSTDIR\Uninstall.exe"
	WriteRegStr HKCU "Software\${APPNAME}" "InstallDir" "$INSTDIR"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayName" "${APPNAME}"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "UninstallString" "$\"$INSTDIR\Uninstall.exe$\""
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "DisplayVersion" "${APPVERSION}"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "Publisher" "${PUBLISHER}"
	WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}" "URLInfoAbout" "${URL}"
SectionEnd

Section "Uninstall"
	Delete "$INSTDIR\Uninstall.exe"
	RMDir /r "$INSTDIR"
	Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
	RMDir "$SMPROGRAMS\${APPNAME}"
	Delete "$DESKTOP\${APPNAME}.lnk"
	DeleteRegKey HKCU "Software\Classes\VoxHTML"
	DeleteRegKey HKCU "Software\Classes\.html"
	DeleteRegKey HKCU "Software\Classes\.htm"
	DeleteRegKey HKCU "Software\Classes\.xhtml"
	DeleteRegKey HKCU "Software\Classes\http\shell\open\command"
	DeleteRegKey HKCU "Software\Classes\https\shell\open\command"
	DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\App Paths\vox.exe"
	DeleteRegKey HKCU "Software\${APPNAME}"
	DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
SectionEnd
