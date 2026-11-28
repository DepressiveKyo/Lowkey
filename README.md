# Lowkey

Scripts for GamingOnSteroids (League of Legends). Ships its own orbwalker,
a per-champion quirks layer, a smite helper and champion scripts for Akali,
Draven, Lillia, Thresh and Yasuo.

## Requirements

- Windows, with GamingOnSteroids installed and its League module (`LOLEXT`) present.
- `GGPrediction.lua` in `LOLEXT\Scripts\Common\`. It ships with GoS; the loader
  will also pick it up from disk if `require` cannot find it.
- Nothing else. The loader pulls every script from this repository on launch.

## Install

Open PowerShell and run:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/DepressiveKyo/Lowkey/main/install.ps1)))
```

The installer finds your GamingOnSteroids folder, downloads three files and
switches the script on. Close GoS first if it is running, then start it.

If the download itself fails on an older PowerShell, force TLS 1.2 first:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; & ([scriptblock]::Create((irm https://raw.githubusercontent.com/DepressiveKyo/Lowkey/main/install.ps1)))
```

### If it cannot find GamingOnSteroids

Point it at the folder yourself. Pass the folder that contains `LOLEXT`:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/DepressiveKyo/Lowkey/main/install.ps1))) -Path 'C:\Users\you\Desktop\GamingOnSteroids'
```

### Installer options

| Option | What it does |
| --- | --- |
| `-Path <folder>` | Use this GamingOnSteroids folder instead of searching for it. |
| `-Branch <name>` | Install from another branch. Default `main`. |
| `-Repo <owner/name>` | Install from a fork. Default `DepressiveKyo/Lowkey`. |
| `-NoActivate` | Download everything but leave the script switched off, so you can tick it in the GoS menu yourself. |

## What the installer puts where

```
LOLEXT\
  Scripts\
    Lowkey.lua                       the entry GoS loads
    Common\
      Lowkey\
        bootstrap.lua                the loader
        manifest.lua                 the file list with sizes and hashes
        scripts\                     every script, downloaded on launch
  LocalScriptDB.ini                  gets [Lowkey.lua] ACTIVE = 1
```

## First launch

Start GoS and load into a game. The loader reads `manifest.lua`, downloads
anything missing or out of date into `Scripts\Common\Lowkey\scripts\`, and
loads the core before the champion scripts. Every fresh download is checked
against its recorded SHA-256 before it is kept, and every file is checked
against its recorded size before it is loaded. The console prints one summary
line, for example:

```
[Lowkey] DepressiveKyo/Lowkey@2026.11.28.1322 ready | 3 loaded | 0 failed | pred on
```

Files downloaded during that launch are not loaded until you restart GoS, and
the loader says so when it happens. A champion script only loads when you are
playing that champion, so `3 loaded` on a champion with no script here is
normal.

Lowkey brings its own orbwalker. Turn off any other orbwalker or AIO in the
GoS script list, or the two will fight over your attacks and movement.

## Updating

Every launch the loader fetches the remote manifest, keeps it only if its
version is newer than the one you are running, and then downloads the files
that changed. So you update by restarting GoS; nothing else to do.

`bootstrap.lua` is not in the manifest and so never updates itself. Re-run the
installer to update the loader.

## Menus

Everything lives in the GoS menu under its own entry: `Lowkey Orbwalker`,
`Lowkey Smite`, `Lowkey Champions` and one per champion, such as `Lowkey Yasuo`.

## When something breaks

Errors are caught and written to `LOLEXT\Scripts\Common\Lowkey\crash.log`, and
the repeat count is drawn on screen so a callback that fails every frame is
visible instead of silent. If a script refuses to load, the console line names
it and why, for example `rejected: size mismatch`, which means the download did
not match the manifest and will be retried on the next launch.

To reinstall from scratch, delete `LOLEXT\Scripts\Common\Lowkey` and
`LOLEXT\Scripts\Lowkey.lua`, then run the installer again.
