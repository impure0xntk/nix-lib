# nix-lib - AGENTS.md

Instructions for coding agents working in this repository. Follow them exactly; they encode
invariants that are easy to break and hard to debug.

## 1. What this repository is

`nix-lib` is a **function library only**. It ships no packages and no NixOS/Home Manager modules.
It extends `pkgs.lib` with the custom namespace `my`, so every consumer sees the helpers as
`lib.my.*` (equivalently `pkgs.lib.my.*`).

Consumer contract (this is the public API — never rename or move it):

| Output | Shape | Consumer |
| --- | --- | --- |
| `lib.<system>` | `pkgs.lib` extended with `my` | `nix-pkgs`, `nixos-base`, `home-manager-base`, `nixos-reactor` |
| `checks.<system>.lib-extend` | derivation | CI / `nix flake check` |
| `checks.<system>.utility` | derivation | CI / `nix flake check` |
| `checks.<system>.builtins` | derivation | CI / `nix flake check` |
| `checks.<system>.builders` | derivation | CI / `nix flake check` |
| `checks.<system>.fetchers` | derivation | CI / `nix flake check` (currently broken, see §7) |
| `checks.<system>.windows` | derivation | CI / `nix flake check` |

Consumers reference it as:

```nix
inputs.nix-lib.lib.${system}          # -> { my = { ... }; }
inputs.nix-lib.lib.${system}.my       # -> the raw helper set
```

## 2. Repository map

```
flake.nix              # outputs: lib.<system>, checks.<system>.*
flake.lock
lib/
  default.nix          # auto-loader + path helpers (listDirs, listDefaultNixDirs, importDirs, listImportLocs)
  builders/default.nix # writeOilApplication, writeOvmApplication, shellApplication
  builtins/default.nix # remarshal, toYaml, toToml, fromYaml, fromDotenv, set, kV, toSessionVariables, isExistAndEnable
  debug/default.nix    # traceSeqWith, traceValSeqWith
  fetchers/
    default.nix                    # fetchurlBinary, fetchurlBinaryLegacy
    fetchurlBinary-builder.sh      # builder script referenced by fetchurlBinary
  system/default.nix   # genOverlayPackages (callPackage-over-a-directory helper)
  utility/default.nix  # genSshKeyPair, removeShebang, removeDesktopIcon(s), genJavaOpts,
                       # genJavaProxyOptsAttr, separateHostAndPort, formatEnvLines,
                       # deepMerge, indentLines, hasTrailingNewline
  windows/default.nix  # inWsl, ifInWsl, openCommand, userBinDir,
                       # writeBatApplicationAttr, writeNoWindowBatApplicationAttr,
                       # writeNoWindowApplicationAttr, writePowershellApplicationAttrs,
                       # binCreateCommand, createSynchronizedWindowsBinFile
tests/
  default.nix     # imported as checks.<system>.lib-extend
  utility.nix     # checks.<system>.utility
  builtins.nix    # checks.<system>.builtins
  builders.nix    # checks.<system>.builders
  fetchers.nix    # checks.<system>.fetchers
  windows.nix     # checks.<system>.windows
```

## 3. The auto-loader invariant (read this before adding a file)

`lib/default.nix` merges every **direct child directory of `lib/` that contains a `default.nix`**.
It does **not** recurse. Consequences:

- A new category is one directory: `lib/<category>/default.nix`. Nothing else needs registering.
- A **nested** helper (e.g. `lib/fetchers/fetchurlBinary-builder.sh`) is invisible to the loader.
  Reference it by relative path (`./*.sh`) from its owning `default.nix`, or add the
  containing directory to `excludeDirPaths` if it should not be auto-imported.
- Attribute names collide silently: later merges win. Two categories exporting the same name is a
  bug, not an override. Check with `nix eval` (see §7) before adding a name.
- `lib/default.nix` is also the definition site of the four path helpers. Extend them there, never
  redefine them in a category module.

## 4. Writing a new helper

Every category module has the same shape. `lib` inside `lib/` is the **plain nixpkgs lib** (`prev`),
not the extended one.

```nix
# lib/<category>/default.nix
{ pkgs, lib, ... }:

rec {
  # One-line `description` comment above every exported name. Explain *why* when non-obvious.
  myHelper = arg: lib.mkOption { ... };
}
```

Hard rules:

- Module arguments are `{ pkgs, lib, ... }`. `pkgs` and `lib` are always supplied by
  `pkgs.lib.extend`; the `...` is mandatory.
- **Never call `lib.my.*` from inside `lib/`.** `lib.my` is built by merging these very modules;
  referencing it here is an infinite recursion (this is the same class of bug documented in
  `nixos-base/modules/core/default.nix`). Use plain nixpkgs `lib` inside this repository.
- Prefer `pkgs.runCommand` / `pkgs.writeShellApplication` for anything that produces a store path.
  Tests do not execute the produced binaries, only evaluate them.
- Use `rec { ... }` for mutually recursive helpers; otherwise use a plain attribute set.
- `debug/default.nix` uses `builtins.unsafeGetAttrPos` to print `file:line` in traces. Only use
  that pattern in `lib/debug/`; elsewhere it is fragile under `nixfmt`.

## 5. Tests

Each `tests/<category>.nix` is a function of `{ pkgs, lib }` returning a single derivation. The
established pattern is a `runCommand` whose `''...''` script is the assertion body; non-obvious
facts are asserted with `assert` at evaluation time.

```nix
# tests/<category>.nix
{ pkgs, lib }:

let
  helpers = import ../lib/<category>/default.nix { inherit pkgs lib; };
  result = helpers.myHelper { ... };
in
assert result == <expected>;      # evaluation-time assertion
pkgs.runCommand "<category>-tests" { } ''
  echo "ran ${result}"
  touch $out
''
```

Rules:

- Add a new test file **and** register it in `flake.nix` `checks`, otherwise it never runs.
- A new category with no test file is an incomplete change.
- Prefer `assert` over a shell `test`: it fails at eval time with a readable location.
- Tests must not require network access. Use `pkgs.runCommand` without fetching anything.

## 6. Cross-repository impact

- `nix-pkgs`, `nixos-base`, `home-manager-base`, and `nixos-reactor` all consume `lib.my.*`.
  **Any rename or signature change here is a breaking change for four repositories.** Search
  consumers before touching a name:
  ```bash
  rtk grep -rn "lib\.my\.<name>" ../nix-pkgs ../nixos-base ../home-manager-base ../machines ../home ../profiles
  ```
- `nix-pkgs/pkgs/default.nix` and `lib/system/default.nix` both define `genOverlayPackages`. The
  duplication is intentional (nix-pkgs passes an overlay-specific argument set). If you fix one,
  check whether the other still needs its local copy.
- This repository is consumed as `git+file:./submodules/nix-lib` by the parent flake. Commit here
  first, then update the submodule pointer in `nixos-reactor`; the parent `flake.lock` changes as a
  separate, reviewable diff.

## 7. Validation

Run these from the repository root. Verified on `x86_64-linux`.

```bash
# Full check (builds every derivation; several minutes on a cold cache)
nix flake check

# Single check — the fast inner loop
nix build --no-link ".#checks.x86_64-linux.utility"
nix build --no-link ".#checks.x86_64-linux.builtins"
nix build --no-link ".#checks.x86_64-linux.lib-extend"

# List the public API without building
nix eval --json '.#lib.x86_64-linux.my' --apply builtins.attrNames

# Format (required: the tree is nixfmt-formatted)
nix fmt
```

Status of each check at the time of writing:

| Check | Status |
| --- | --- |
| `lib-extend` | pass |
| `utility` | pass |
| `builtins` | pass |
| `builders` | pass |
| `windows` | pass |
| `fetchers` | **known failure — pre-existing, not caused by your change** |

`checks.x86_64-linux.fetchers` fails with
`error: cannot coerce a list to a string: [ "-fsSL" "-H" "Accept: application/octet-stream" ]`.
Cause: `tests/fetchers.nix` calls `lib.strings.hasInfix` on `drvAttrs.curlOptsList`, which is a
*list*, not a string. The fix is to test the list with `builtins.any`/`lib.elem` instead. Do not
assume a `fetchers` failure means your change is broken; confirm the other five checks still pass.

## 8. Definition of done

A change to this repository is complete when:

1. The new helper lives under the correct `lib/<category>/` and is reachable at `lib.my.<name>`.
2. `nix eval '.#lib.x86_64-linux.my' --apply builtins.attrNames` lists the new name.
3. A test exists in `tests/` **and** is registered in `flake.nix` `checks`.
4. `nix flake check` fails only on the pre-existing `fetchers` check.
5. `nix fmt` has been run; the diff contains no unrelated reformatting.
6. No hardcoded secrets, no `fetchurl` hashes invented by hand in this repo (hashes live in
   `nix-pkgs`), no new dependencies added to `flake.nix` without a stated reason.
