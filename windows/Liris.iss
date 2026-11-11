#ifndef BundleDir
  #error Set BundleDir to a complete Windows build
#endif
#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif

#define AppId "id.local.liris.Windows"

[Setup]
AppId={#AppId}
AppName=Liris
AppVersion={#AppVersion}
AppPublisher=Liris
AppPublisherURL=https://github.com/Fikriazrbni/Liris
DefaultDirName={localappdata}\Programs\Liris
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.22000
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\Liris.exe
SetupIconFile=assets\liris.ico
OutputDir=dist
OutputBaseFilename=Liris-Setup-Windows-x64
Compression=lzma2/fast
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
CloseApplicationsFilter=Liris.exe,LirisBridge.exe,LirisWorker.exe
RestartApplications=no

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Liris"; Filename: "{app}\Liris.exe"; WorkingDir: "{app}"; AppUserModelID: "{#AppId}"
Name: "{autodesktop}\Liris"; Filename: "{app}\Liris.exe"; WorkingDir: "{app}"; AppUserModelID: "{#AppId}"; Tasks: desktopicon
