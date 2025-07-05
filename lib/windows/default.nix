# Windows bat/powershell application generators.
# "~ApplicationAttr[s]" outputs the list of "name" and "text" attrsets
# to input as "home.file" attrs: copying from wsl to windows filesystems.
{ pkgs, lib, ... }:
# assert builtins.pathExists "${builtins.getEnv "XDG_DATA_HOME"}";
let
  _wslMarkerFilePath = "/proc/sys/fs/binfmt_misc/WSLInterop";
  # WIN_USERNAME is defined by machines/wsl.nix
  # When run "onChange", cannot use nix commands.
  # TODO: resolve interdependence.
  _userBinDir = ''/mnt/c/Users/''${WIN_USERNAME:?Check env val in machines/wsl.nix}/bin'';
  binCreateCommand = (scriptName:
    ''
      mkdir -p ${_userBinDir}
      rm -f ${_userBinDir}/${scriptName}
      cp $XDG_DATA_HOME/windows/${scriptName} ${_userBinDir}
    ''
    );
in rec {
  # Check whether the config has wsl settings.
  # It depends my.system/home.machine (see machine-config module).
  inWsl = config: (config.my ? "system" && config.my.system.machine.type == "wsl")
    || (config.my ? "home" &&  config.my.home.platform.type == "wsl");

  ifInWsl = "test -e ${_wslMarkerFilePath} &&";

  openCommand = config:
      if inWsl config then lib.getExe pkgs.wsl-open
      else "${pkgs.xdg-utils}/bin/xdg-open";

  userBinDir = _userBinDir;

  writeBatApplicationAttr = {
    name,
    text,
    echo ? false,
    pause ? false,
    privilege ? false,
    ...}:
    let
      echoText = if echo then "" else "@echo off";
      pauseText = if pause then "pause" else "";
      privilegeText = if privilege then ''
whoami /priv | find "SeDebugPrivilege" > nul
if %errorlevel% neq 0 (
  @powershell start-process %~0 -verb runas
  exit
)
''  else "";
    in {
      name = name;
      text = ''
${echoText}
${privilegeText}

${text}

${pauseText}
    '';
    };

  writePowershellApplicationAttrs = {
    name,
    text,
    pause ? false,
    privilege ? false,

    generateBatFile ? false,
    ...}:
    let
      pauseText = if pause then "Read-Host -Prompt 'Press any key to continue or CTRL+C to quit' | Out-Null" else "";
      # Some error check causes failure of escalation. So do this on first.
      privilegeText = if privilege then ''
$Loc = Get-Location
"Security.Principal.Windows" | % { IEX "( [ $_`Principal ] [$_`Identity ]::GetCurrent() ).IsInRole( 'Administrator' )" } | ? {
    $True | % { $Arguments =  @('-NoProfile','-ExecutionPolicy Bypass','-NoExit','-File',"`"$($MyInvocation.MyCommand.Path)`"","\`"$Loc\`"");
    Start-Process -FilePath PowerShell.exe -Verb RunAs -ArgumentList $Arguments; } }
'' else "";
    in [{
      name = name;
      text = ''
${privilegeText}

$ErrorActionPreference='Stop' # set -e
Set-StrictMode -Version 2.0 # set -u

${text}

${pauseText}
    '';
    }] ++ (
      if generateBatFile then [
        (writeBatApplicationAttr {
          name = name + ".bat";
          text = ''
            powershell -ExecutionPolicy Bypass -file ${name}
          '';
        })
      ] else []
    );

  createSynchronizedWindowsBinFile = windowsScripts:
    # copy bat/ps1 scripts to Windows
    lib.attrsets.mergeAttrsList (
      (builtins.map (element:
        {
          "windows/${element.name}" = {
            onChange = binCreateCommand element.name;
            text = element.text;
          };
        } )
        windowsScripts)
    );

  writeNoWindowApplicationAttr = {
    name,
    command,
    ...}: {
      name = name;
      text = ''
Set oShell = CreateObject ("Wscript.Shell")
Dim strArgs
strArgs = "${command}"

oShell.Run strArgs, 0, false
'';
  };
  writeNoWindowBatApplicationAttr = {
    name,
    command,
    ...}: writeNoWindowApplicationAttr {
      inherit name;
      command = "cmd /c ${command}";
    };
}
