# FreePDFImport - Free & Open Source PDF Importer for SketchUp
# Copyright (C) 2026 hiratazx
# License: GPL-3.0 (see LICENSE file)
#
# This extension imports PDF files as vector geometry into SketchUp.
# It uses Poppler (open-source) for PDF-to-SVG conversion and
# SketchUp's Ruby API for geometry creation.

require 'sketchup.rb'
require 'extensions.rb'

module FreePDFImport
  PLUGIN_DIR = File.dirname(__FILE__).freeze
  PLUGIN_NAME = 'Free PDF Import'.freeze
  PLUGIN_VERSION = '1.0.0'.freeze
  PLUGIN_DESCRIPTION = 'Import PDF files as vector geometry — Free & Open Source'.freeze
  PLUGIN_CREATOR = 'hiratazx'.freeze

  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new(PLUGIN_NAME, 'FreePDFImport/core')
    ext.version = PLUGIN_VERSION
    ext.description = PLUGIN_DESCRIPTION
    ext.creator = PLUGIN_CREATOR
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
