# Free PDF Import for SketchUp

A free, open-source SketchUp extension that imports PDF files as vector geometry (edges and faces).

## Features

- **PDF to Vector Geometry** — Converts PDF vector paths into SketchUp edges and faces
- **Multi-page Support** — Choose which page to import from multi-page PDFs
- **Full SVG Path Support** — Lines, curves (cubic/quadratic Bézier), arcs, and all SVG primitives
- **Configurable Quality** — Low, Medium, or High curve subdivision for Bézier curves
- **Scale Control** — Import at any scale factor
- **Undoable** — Full undo/redo support via SketchUp operations
- **Auto Zoom** — Automatically zooms to imported geometry

## How It Works

```
PDF File → [Poppler pdftocairo] → SVG → [REXML Parser] → [Path Parser] → SketchUp Geometry
```

1. Select a PDF file via the import dialog
2. Choose page number, scale, and quality settings
3. The extension converts the PDF page to SVG using bundled [Poppler](https://poppler.freedesktop.org/) tools
4. SVG vector data is parsed and converted into SketchUp edges and faces

## Installation

### Install via Extension Manager (Recommended)
1. Download the latest `.rbz` file from [Releases](https://github.com/hiratazx/PDFImporter-SketchUp/releases)
2. Open SketchUp
3. Go to **Window → Extension Manager** (or **Window → Preferences → Extensions** in older versions)
4. Click **Install Extension**
5. Select the downloaded `.rbz` file
6. Restart SketchUp

### Manual Installation
1. Download the latest `.rbz` file from [Releases](https://github.com/hiratazx/PDFImporter-SketchUp/releases)
2. Rename `.rbz` to `.zip` and extract it
3. Copy `FreePDFImport.rb` and the `FreePDFImport/` folder into your SketchUp Plugins directory:
   - **Windows**: `C:\Users\<username>\AppData\Roaming\SketchUp\SketchUp <version>\SketchUp\Plugins`
4. Restart SketchUp

## Usage

1. Open SketchUp
2. Go to **Extensions → Free PDF Import → Import PDF...**
3. Select your PDF file
4. Choose the page, scale, import mode, and curve quality
5. Click OK — geometry is created in a named group

## Requirements

- SketchUp 2017 or later (Ruby 2.2+)
- Windows (Poppler binaries are Windows-only in this release)

## Building from Source

The GitHub Actions workflow automatically packages the extension with Poppler binaries. See `.github/workflows/build.yml`.

## Credits

- **Poppler** — PDF rendering library (GPL-licensed), used for PDF → SVG conversion
- **REXML** — Built-in Ruby XML parser, used for SVG parsing

## License

GPL-3.0 — See [LICENSE](LICENSE) for details.

The bundled Poppler binaries are separately licensed under GPL-2.0+.

## Author

**hiratazx**
