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
