# Alpha Merge Watch Folder

Automatically combines a **color image** and its **black & white matte** into a single
**transparent PNG** (RGBA). You can also resize and compress the output.

It works on **macOS** and **Windows**. It processes everything that's already in the folder,
then keeps watching for new or updated files.

```
01.png  (color)   +   01_alpha.png  (matte)   →   output/01.png  (transparent)
```

---

## Table of Contents

1. [Features](#features)
2. [Quick Start](#quick-start)
3. [Requirements](#requirements)
4. [Installation](#installation)
5. [Folder Structure](#folder-structure)
6. [File Naming Rules](#file-naming-rules)
7. [How to Prepare the Matte](#how-to-prepare-the-matte)
8. [Running the Script](#running-the-script)
9. [Settings](#settings)
10. [Output Size & Quality](#output-size--quality)
11. [How It Works](#how-it-works)
12. [Troubleshooting](#troubleshooting)
13. [FAQ](#faq)

---

## Features

- **Batch processing:** processes every image pair in the `assets` folder.
- **Watch folder:** keeps running and handles new or replaced files automatically.
- **Waits for copies to finish:** files that are still being copied are never processed half-finished.
- **No duplicate work:** images that are already up to date are skipped.
- **Parallel processing:** several images are processed at the same time.
- **Resizing:** output can be scaled, for example to 50%.
- **Compression control:** fast lossless PNG, or much smaller files with optional pngquant.
- **Safe:** your original files are never changed. Results go into `assets/output`.

---

## Quick Start

| | macOS | Windows |
|---|---|---|
| 1. Install FFmpeg | `brew install ffmpeg` | `winget install --id Gyan.FFmpeg` |
| 2. Put your images in | `assets/` | `assets\` |
| 3. Run the script | Double-click `watch_alpha.command` | Double-click `watch_alpha.bat` |
| 4. Get the results | `assets/output/` | `assets\output\` |
| 5. Stop | `Ctrl + C` or close the window | `Ctrl + C`, then `Y`, or close the window |

---

## Requirements

| Tool | Required? | Purpose |
|---|---|---|
| [FFmpeg](https://ffmpeg.org) | ✅ Yes | Merges the images, resizes them and saves the PNG |
| [pngquant](https://pngquant.org) | ⬜ Optional | Lossy compression for much smaller files |

---

## Installation

### macOS

1. Open **Terminal** (press `Cmd + Space`, type *Terminal*, press Enter).
2. Install [Homebrew](https://brew.sh) if you don't have it:
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Install FFmpeg, and pngquant if you want it:
   ```bash
   brew install ffmpeg
   brew install pngquant     # optional
   ```
4. Make the script runnable. You only need to do this once:
   ```bash
   cd /path/to/your_project
   chmod +x watch_alpha.command
   ```

### Windows

1. Open **Command Prompt** and install FFmpeg:
   ```bat
   winget install --id Gyan.FFmpeg
   ```
   Then close Command Prompt and open it again.

   If `winget` isn't available, download FFmpeg from
   [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) and put `ffmpeg.exe` in the same
   folder as `watch_alpha.bat`.
2. Optional: download pngquant from [pngquant.org](https://pngquant.org) and put
   `pngquant.exe` next to `watch_alpha.bat`.
3. Check that FFmpeg works:
   ```bat
   ffmpeg -version
   ```

---

## Folder Structure

```
your_project/
├── README.md
├── watch_alpha.command      ← macOS script
├── watch_alpha.bat          ← Windows script
└── assets/                  ← put your input images here (the watch folder)
    ├── 01.png
    ├── 01_alpha.png
    ├── 02.png
    ├── 02_alpha.png
    ├── ...
    └── output/              ← created automatically
        ├── 01.png           ← final transparent images
        ├── 02.png
        └── _state/          ← Windows only: the script's bookkeeping (don't edit)
```

> The scripts always run from their own folder. Keep the script next to the `assets` folder.

---

## File Naming Rules

Each image needs a **matching matte** with the same name plus `_alpha`:

| Color image | Matte | Output |
|---|---|---|
| `01.png` | `01_alpha.png` | `output/01.png` |
| `02.png` | `02_alpha.png` | `output/02.png` |
| `hero.png` | `hero_alpha.png` | `output/hero.png` |

Rules:

- Both files must be **PNG** and use a **lowercase `.png`** extension. On macOS, `.PNG` is not picked up.
- The names must match **exactly**. For example, `01.png` and `1_alpha.png` won't pair.
- An image with **no matte** is ignored until its matte arrives.
- Any name works (`01`, `shot_A`, `logo`), not only numbers.
- **Windows:** don't use `!` or `%` in file names. Batch files can't handle these characters reliably.

---

## How to Prepare the Matte

The matte (`*_alpha.png`) is a grayscale image that sets how transparent each pixel is:

| Matte color | Result in output |
|---|---|
| ⬜ White | Fully visible (opaque) |
| ⬛ Black | Fully transparent |
| ▫️ Gray | Partly transparent (soft edges, shadows, glass) |

Requirements:

- The matte must be **exactly the same width and height** as the color image.
- It can be saved as grayscale or as RGB. The script converts it to grayscale automatically.

**Is your matte inverted?** (The background stays visible and the subject disappears.)
See [Troubleshooting](#troubleshooting).

---

## Running the Script

### macOS
- Double-click `watch_alpha.command` in Finder, **or**
- Run it from Terminal: `./watch_alpha.command`

The first time, macOS may block it. Right-click the file, choose **Open**, then click **Open** again.

### Windows
- Double-click `watch_alpha.bat`.

If you see **"Windows protected your PC"**, click **More info**, then **Run anyway**.

### What you'll see

```
Watching 'assets'  |  scale=0.5  compression=3  jobs=4  pngquant=0
Press Ctrl+C to stop.
14:02:11  ⏳ 01 ...
14:02:11  ⏳ 02 ...
14:02:12  ✅ 01  (412K)
14:02:12  ✅ 02  (398K)
14:02:13  ❌ 03 failed (are both images the same size?)
```

On Windows the symbols are shown as `[..]`, `[OK]` and `[FAIL]`.

**Leave the window open** while you work. Any pair you add or replace in `assets` is processed
automatically.

---

## Settings

Open the script in a text editor and change the **Settings** block at the top.
The setting names are the same in both versions.

| Setting | Default | Description |
|---|---|---|
| `WATCH` | `assets` | The folder to watch for input images |
| `OUT` | `assets/output` | Where results are saved |
| `INTERVAL` | `1` | Seconds between folder checks |
| `JOBS` | `4` | How many images are processed at the same time |
| `SCALE` | `0.5` | Output size: `1` = 100%, `0.5` = 50%, `0.25` = 25% |
| `COMPRESSION` | `3` | PNG compression, `0` to `9` (see below) |
| `PRED` | `none` | PNG filter: `none` = faster, `mixed` = smaller files |
| `USE_PNGQUANT` | `0` | `1` = turn on lossy compression (needs pngquant) |
| `QUALITY` | `65-85` | pngquant quality range, min-max (0 to 100) |
| `FFMPEG` | `ffmpeg` | *Windows only:* path to `ffmpeg.exe` |
| `PNGQUANT` | `pngquant` | *Windows only:* path to `pngquant.exe` |

### Choosing `JOBS`
Set it to the number of CPU cores on your computer, or a little lower:

- macOS: `sysctl -n hw.ncpu`
- Windows: `echo %NUMBER_OF_PROCESSORS%`

> ⚠️ **Changing settings doesn't redo images that are already finished.**
> To process everything again with new settings, delete the `output` folder and restart the script.

---

## Output Size & Quality

### Resizing (`SCALE`)
- `SCALE=0.5` halves the width and height, so the image has **¼ of the pixels**.
  Files are roughly 4× smaller, and processing is faster.
- Resizing uses the high-quality **Lanczos** filter.
- The transparency is resized together with the color, so edges stay lined up.

### PNG compression (`COMPRESSION` + `PRED`)
PNG is **lossless**: the image looks exactly the same at every compression level.
The level only changes **file size** and **speed**.

| Pre