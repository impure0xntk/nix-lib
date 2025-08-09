{ pkgs, lib }:

let
  windows = import ../lib/windows/default.nix { inherit pkgs lib; };

  # Mock configs
  wslConfig = { my.system.machine.type = "wsl"; };
  nonWslConfig = { my = { system = { machine = { type = "non-wsl"; }; }; }; };
  wslHomeConfig = { my.home.platform.type = "wsl"; };

  # inWsl tests
  inWslTest1 = windows.inWsl wslConfig;
  inWslTest2 = windows.inWsl nonWslConfig;
  inWslTest3 = windows.inWsl wslHomeConfig;

  # openCommand tests
  openCommandTest1 = windows.openCommand wslConfig;
  openCommandTest2 = windows.openCommand nonWslConfig;

  # writeBatApplicationAttr tests
  batAttr1 = windows.writeBatApplicationAttr {
    name = "test.bat";
    text = "echo Hello";
  };
  batAttr2 = windows.writeBatApplicationAttr {
    name = "test_opts.bat";
    text = "echo With Options";
    echo = true;
    pause = true;
    privilege = true;
  };

  # writePowershellApplicationAttrs tests
  psAttrs1 = windows.writePowershellApplicationAttrs {
    name = "test.ps1";
    text = "Write-Host 'Hello'";
  };
  psAttrs2 = windows.writePowershellApplicationAttrs {
    name = "test_opts.ps1";
    text = "Write-Host 'With Options'";
    pause = true;
    privilege = true;
    generateBatFile = true;
  };

  # createSynchronizedWindowsBinFile tests
  syncFile = windows.createSynchronizedWindowsBinFile [
    (windows.writeBatApplicationAttr { name = "sync.bat"; text = "sync"; })
  ];

  # writeNoWindowApplicationAttr tests
  noWindowAttr = windows.writeNoWindowApplicationAttr {
    name = "nowindow.vbs";
    command = "my-command --arg";
  };

  # writeNoWindowBatApplicationAttr tests
  noWindowBatAttr = windows.writeNoWindowBatApplicationAttr {
    name = "nowindow_bat.vbs";
    command = "my-command.bat";
  };

in
  # Assertions
  assert inWslTest1 == true;
  assert inWslTest2 == false;
  assert inWslTest3 == true;

  assert lib.hasSuffix "/bin/wsl-open" openCommandTest1;
  assert openCommandTest2 == "${pkgs.xdg-utils}/bin/xdg-open";

  assert batAttr1.name == "test.bat";
  assert lib.strings.hasInfix "@echo off" batAttr1.text;
  assert lib.strings.hasInfix "echo Hello" batAttr1.text;
  assert batAttr2.name == "test_opts.bat";
  assert !lib.strings.hasInfix "@echo off" batAttr2.text;
  assert lib.strings.hasInfix "pause" batAttr2.text;
  assert lib.strings.hasInfix "SeDebugPrivilege" batAttr2.text;

  assert (lib.head psAttrs1).name == "test.ps1";
  assert lib.strings.hasInfix "Write-Host 'Hello'" (lib.head psAttrs1).text;
  assert (lib.length psAttrs2) == 2;
  assert (lib.head psAttrs2).name == "test_opts.ps1";
  assert lib.strings.hasInfix "Read-Host" (lib.head psAttrs2).text;
  assert lib.strings.hasInfix "RunAs" (lib.head psAttrs2).text;
  assert (lib.last psAttrs2).name == "test_opts.ps1.bat";
  assert lib.strings.hasInfix "powershell -ExecutionPolicy Bypass -file test_opts.ps1" (lib.last psAttrs2).text;

  assert syncFile ? "windows/sync.bat";
  assert lib.strings.hasInfix "sync" syncFile."windows/sync.bat".text;
  assert lib.strings.hasInfix "cp " syncFile."windows/sync.bat".onChange;

  assert noWindowAttr.name == "nowindow.vbs";
  assert lib.strings.hasInfix ''strArgs = "my-command --arg"'' noWindowAttr.text;
  assert lib.strings.hasInfix ''oShell.Run strArgs, 0, false'' noWindowAttr.text;

  assert noWindowBatAttr.name == "nowindow_bat.vbs";
  assert lib.strings.hasInfix ''strArgs = "cmd /c my-command.bat"'' noWindowBatAttr.text;
  assert lib.strings.hasInfix ''oShell.Run strArgs, 0, false'' noWindowBatAttr.text;

  # Final derivation for nix flake check
  pkgs.runCommand "windows-lib-tests" { } ''
    touch $out
  ''