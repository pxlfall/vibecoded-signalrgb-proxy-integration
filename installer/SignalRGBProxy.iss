#define AppVersion "0.1"
#define ProjectURL "https://github.com/pxlfall/vibecoded-signalrgb-proxy-integration"

[Setup]
AppId={{1A783A09-88B4-4D6F-B97F-584EA5A6E2E9}
AppName=SignalRGB Proxy Integration
AppVersion={#AppVersion}
AppPublisher=pxlfall and upstream contributors
AppPublisherURL={#ProjectURL}
AppSupportURL={#ProjectURL}/issues
AppUpdatesURL={#ProjectURL}/releases
DefaultDirName={autopf}\SignalRGBProxy
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\release
OutputBaseFilename=SignalRGBProxyInstaller-v0.1-win-x64
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
InfoBeforeFile=..\CREDITS.txt
UninstallDisplayName=SignalRGB Proxy Integration
UninstallDisplayIcon={sys}\imageres.dll
CloseApplications=no
RestartApplications=no

[Files]
Source: "..\payload\DWrite.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\payload\force-proxy.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\SignalRGBProxy.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Start.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Install.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Uninstall.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\BUILD.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\docs\*"; DestDir: "{app}\docs"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\CREDITS.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\CREDITS.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\licenses\*"; DestDir: "{app}\licenses"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\SignalRGB Proxy Integration\Start SignalRGB"; Filename: "{app}\Start.cmd"; WorkingDir: "{app}"
Name: "{autoprograms}\SignalRGB Proxy Integration\Setup instructions"; Filename: "{app}\README.md"
Name: "{autoprograms}\SignalRGB Proxy Integration\Uninstall"; Filename: "{uninstallexe}"

[Code]
var
  SignalPage: TInputDirWizardPage;
  ProxyPage: TInputQueryWizardPage;

procedure InitializeWizard();
var value: String;
begin
  SignalPage := CreateInputDirPage(wpSelectDir, 'Choose your SignalRGB installation',
    'Select the VortxEngine folder', 'This folder must contain SignalRgbLauncher.exe and an app-*\Signal-x64 folder. Running SignalRGB processes in this folder will be stopped during installation.', False, '');
  SignalPage.Add('SignalRGB installation:');
  value := ExpandConstant('{param:SIGNALROOT|}');
  if value = '' then value := ExpandConstant('{localappdata}\VortxEngine');
  SignalPage.Values[0] := value;
  ProxyPage := CreateInputQueryPage(SignalPage.ID, 'SOCKS5 proxy',
    'Where is your proxy listening?', 'Use a numeric IPv4 address and an unauthenticated SOCKS5 listener. Clash normally uses 127.0.0.1:7897.');
  ProxyPage.Add('Proxy address:', False);
  ProxyPage.Add('Proxy port:', False);
  ProxyPage.Values[0] := ExpandConstant('{param:PROXYADDRESS|127.0.0.1}');
  ProxyPage.Values[1] := ExpandConstant('{param:PROXYPORT|7897}');
end;

function ValidateSettings(): String;
var remaining, part: String; i, value, dot: Integer; found: Boolean; entry: TFindRec;
begin
  Result := '';
  if not FileExists(AddBackslash(SignalPage.Values[0]) + 'SignalRgbLauncher.exe') then begin
    Result := 'SignalRgbLauncher.exe was not found in the selected folder.'; Exit;
  end;
  found := False;
  if FindFirst(AddBackslash(SignalPage.Values[0]) + 'app-*', entry) then begin
    repeat
      if FileExists(AddBackslash(SignalPage.Values[0]) + entry.Name + '\Signal-x64\SignalRgb.exe') then found := True;
    until not FindNext(entry);
    FindClose(entry);
  end;
  if not found then begin Result := 'No SignalRGB x64 app folder was found.'; Exit; end;
  remaining := Trim(ProxyPage.Values[0]);
  for i := 0 to 3 do begin
    if i < 3 then begin
      dot := Pos('.', remaining);
      if dot = 0 then begin Result := 'Use a numeric IPv4 proxy address.'; Exit; end;
      part := Copy(remaining, 1, dot - 1);
      Delete(remaining, 1, dot);
    end else part := remaining;
    value := StrToIntDef(part, -1);
    if (value < 0) or (value > 255) or (IntToStr(value) <> part) then begin Result := 'Use a numeric IPv4 proxy address.'; Exit; end;
  end;
  value := StrToIntDef(Trim(ProxyPage.Values[1]), -1);
  if (value < 1) or (value > 65535) then Result := 'Proxy port must be between 1 and 65535.';
end;

function NextButtonClick(CurPageID: Integer): Boolean;
var error: String;
begin
  Result := True;
  if CurPageID = ProxyPage.ID then begin
    error := ValidateSettings();
    if error <> '' then begin MsgBox(error, mbError, MB_OK); Result := False; end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin Result := ValidateSettings(); end;

function RunPatch(Action: String): Boolean;
var code: Integer; arguments: String;
begin
  arguments := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\SignalRGBProxy.ps1') + '" -Action ' + Action;
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), arguments,
    ExpandConstant('{app}'), SW_HIDE, ewWaitUntilTerminated, code);
  if Result then Result := code = 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var config: String; lines: TArrayOfString;
begin
  if CurStep = ssPostInstall then begin
    SetArrayLength(lines, 1);
    lines[0] := SignalPage.Values[0];
    if not SaveStringsToUTF8File(ExpandConstant('{app}\signal-installation.txt'), lines, False) then RaiseException('Cannot save SignalRGB installation path.');
    config := 'SOCKS5_PROXY_ADDRESS=' + Trim(ProxyPage.Values[0]) + #13#10 +
      'SOCKS5_PROXY_PORT=' + Trim(ProxyPage.Values[1]) + #13#10 +
      'SOCKS5_PROXY_TIMEOUT=5' + #13#10 + 'SOCKS5_PROXY_DNS=1' + #13#10 + 'SOCKS5_DNS_LOG=1' + #13#10;
    if not SaveStringToFile(ExpandConstant('{app}\proxy.txt'), config, False) then RaiseException('Cannot save proxy settings.');
    if not RunPatch('Install') then RaiseException('SignalRGB proxy installation failed. Original files and backups are preserved. Check the launcher.log in your local SignalRGBProxy folder.');
    SaveStringToFile(ExpandConstant('{app}\task-action.txt'), 'Program: powershell.exe' + #13#10 + 'Arguments: -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + ExpandConstant('{app}\SignalRGBProxy.ps1') + '" -Action Start' + #13#10 + 'Keep your user account, Run with highest privileges, and Run only when user is logged on.' + #13#10, False);
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := RunPatch('Uninstall');
  if not Result then MsgBox('Could not safely restore SignalRGB. Uninstall has stopped so the package and backups remain available. Quit SignalRGB and inspect launcher.log before retrying.', mbError, MB_OK);
end;
