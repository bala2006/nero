!include "LogicLib.nsh"

Var neroFinalDirectory
Var neroNewDirectory
Var neroOldDirectory
Var neroOldMoved
Var neroNewMoved

!macro neroExtractPayload FILE
  !ifmacrodef customInstallerExtract
    !insertmacro customInstallerExtract "${FILE}"
  !else
    nsExec::ExecToStack '"$PLUGINSDIR\nero-7za.exe" x -y -bd -bb0 "-o$INSTDIR" "${FILE}"'
    Pop $R0
    Pop $R1
  !endif
  ${If} $R0 != 0
    DetailPrint $R1
    Call neroRollbackDirectories
    !ifmacrodef customInstallerExtractFailed
      !insertmacro customInstallerExtractFailed "${FILE}"
    !else
      MessageBox MB_OK|MB_ICONEXCLAMATION "$(decompressionFailed)" /SD IDOK
    !endif
    SetErrorLevel 2
    Quit
  ${EndIf}
!macroend

!macro neroStageApplication
  StrCpy $neroFinalDirectory $INSTDIR
  System::Call 'ole32::CoCreateGuid(g .r0) i .r1'
  ${If} $1 != 0
    SetErrorLevel 2
    Quit
  ${EndIf}
  StrCpy $neroNewDirectory "$INSTDIR.new-$0"
  StrCpy $neroOldDirectory "$INSTDIR.old-$0"
  StrCpy $neroOldMoved ""
  StrCpy $neroNewMoved ""
  ClearErrors
  CreateDirectory $neroNewDirectory
  ${If} ${Errors}
    SetErrorLevel 2
    Quit
  ${EndIf}
  File /oname=$PLUGINSDIR\nero-7za.exe "${NERO_SEVENZIP_PATH}"
  StrCpy $INSTDIR $neroNewDirectory
  SetOutPath $INSTDIR
  !insertmacro installApplicationFiles
  !ifdef NERO_SEVENZIP_LICENSE_DIR
    File /oname=7zip-installer-LICENSE.txt "${NERO_SEVENZIP_LICENSE_DIR}\LICENSE.txt"
    File /oname=7zip-installer-COPYING.txt "${NERO_SEVENZIP_LICENSE_DIR}\COPYING"
  !endif
  !ifdef UNINSTALLER_ICON
    File /oname=uninstallerIcon.ico "${UNINSTALLER_ICON}"
  !endif
  StrCpy $INSTDIR $neroFinalDirectory
  SetOutPath $PLUGINSDIR
!macroend

Function .onGUIEnd
  Call neroCleanupDirectories
FunctionEnd

Function neroCleanupDirectories
  ${If} $neroFinalDirectory != ""
    Call neroRollbackDirectories
  ${EndIf}
FunctionEnd

; Only directories created or renamed by this installer are removed during rollback.
Function neroRollbackDirectories
  SetOutPath $PLUGINSDIR
  ${If} $neroNewMoved == "1"
    RMDir /r "\\?\$neroFinalDirectory"
    StrCpy $neroNewMoved ""
  ${EndIf}
  ${If} $neroOldMoved == "1"
    ClearErrors
    Rename $neroOldDirectory $neroFinalDirectory
    ${If} ${Errors}
      ; Leave the complete backup in place if another process prevents restoration.
      DetailPrint $neroOldDirectory
      Return
    ${EndIf}
    StrCpy $neroOldMoved ""
  ${EndIf}
  ${If} $neroNewDirectory != ""
    RMDir /r "\\?\$neroNewDirectory"
  ${EndIf}
  StrCpy $INSTDIR $neroFinalDirectory
FunctionEnd

Function neroPromoteDirectories
  !ifmacrodef InstallerPublishStage
    !insertmacro InstallerPublishStage 2
  !endif
  ; SetOutPath opens a directory handle; release it before either rename.
  SetOutPath $PLUGINSDIR
  ClearErrors
  ${If} ${FileExists} "$neroFinalDirectory\*.*"
    Rename $neroFinalDirectory $neroOldDirectory
    ${If} ${Errors}
      Call neroRollbackDirectories
      SetErrors
      Return
    ${EndIf}
    StrCpy $neroOldMoved "1"
  ${Else}
    ; NSIS can create the destination before the install section starts.
    RMDir $neroFinalDirectory
  ${EndIf}
  ClearErrors
  Rename $neroNewDirectory $neroFinalDirectory
  ${If} ${Errors}
    Call neroRollbackDirectories
    SetErrors
    Return
  ${EndIf}
  StrCpy $neroNewMoved "1"
  SetOutPath $neroFinalDirectory
  !ifmacrodef InstallerPublishStage
    !insertmacro InstallerPublishStage 3
  !endif
  ClearErrors
FunctionEnd

!macro neroFinishDirectories
  StrCpy $neroNewMoved ""
  ${If} $neroOldMoved == "1"
    RMDir /r "\\?\$neroOldDirectory"
    StrCpy $neroOldMoved ""
  ${EndIf}
!macroend
