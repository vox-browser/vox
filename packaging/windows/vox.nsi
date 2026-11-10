; Vox Windows installer (NSIS 3.x).
;
; Produces Vox-<version>-setup.exe from the portable zip built by
; `v run build_browser.vsh package-zip` (Build/windows/vox-portable.zip).
; Run:  makensis packaging/windows/vox.nsi
;
; Requirements: NSIS 3.x. The zip must exist next to this script's
; parent packaging/ directory at build time (see package-installer flow).

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

!define MUI_ABORTWARNING

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Install"
	SetOutPath "$INSTDIR"
	; Extract the portable zip that sits next to this installer.
	DetailPrint "Extracting ${ZIPFILE}..."
	nsExec::ExecToLog 'powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath ''$EXEDIR\${ZIPFILE}'' -DestinationPath ''$INSTDIR'' -Force"'
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
	DeleteRegKey HKCU "Software\${APPNAME}"
	DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"
SectionEnd
