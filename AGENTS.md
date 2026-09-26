# nix-lib - AGENTS.md

## Overview

`nix-lib` is a collection of Nix utility functions and modules designed to streamline Nix-based development. It provides a structured approach to common tasks, making Nix expressions more organized and reusable.

## Structure

The project is organized into a `lib/` directory, which contains various modules, each with a `default.nix` file. This structure allows for logical grouping of related functions and makes it easy to import specific utilities into your Nix projects.

```
lib/
├── builders/             # Functions for building derivations
├── builtins/             # Wrappers or extensions for Nix built-in functions
├── debug/                # Utilities for debugging Nix expressions
├── fetchers/             # Functions for fetching external resources
├── system/               # System-related utilities (e.g., path manipulation)
├── utility/              # General-purpose utility functions
└── windows/              # Windows-specific Nix utilities
```

## Development Guidelines

- When adding a new utility, place it in the appropriate subdirectory under `lib/`.
- Each subdirectory should have a `default.nix` that exports the functions in that category.
- The top-level `lib/default.nix` aggregates all the submodules.
- Follow the Nix techniques used in the project: Flakes, callPackage, derivations, and overlays (where applicable).
- Write tests for new functions in the `tests/` directory.

## Critical Notes

- This submodule is used as an input in the main flake (nixos-reactor) via `nix-lib.url = "git+file:./submodules/nix-lib";`.
- Changes to this submodule may require updating the flake.lock in the main repository and any dependent submodules.
