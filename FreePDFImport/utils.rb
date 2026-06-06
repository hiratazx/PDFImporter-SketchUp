# FreePDFImport - Utility functions
# Copyright (C) 2026 hiratazx
# License: GPL-3.0

module FreePDFImport
  module Utils
    # PDF points to inches (1 point = 1/72 inch)
    PT_TO_INCH = 1.0 / 72.0

    # SketchUp internally works in inches
    # So PDF points → SketchUp units = pt * PT_TO_INCH
    MM_TO_INCH = 1.0 / 25.4
    CM_TO_INCH = 1.0 / 2.54

    # Path to bundled binaries
    BIN_DIR = File.join(File.dirname(__FILE__), 'bin').freeze
    TMP_DIR = File.join(File.dirname(__FILE__), 'tmp').freeze

    # Path to Poppler executables
    PDFTOCAIRO = File.join(BIN_DIR, 'pdftocairo.exe').freeze
    PDFINFO = File.join(BIN_DIR, 'pdfinfo.exe').freeze

    # Bézier curve subdivision tolerance (in PDF points)
    # Lower = smoother curves but more edges
    CURVE_TOLERANCE_HIGH = 0.25
    CURVE_TOLERANCE_MEDIUM = 0.5
    CURVE_TOLERANCE_LOW = 1.0

    # Ensure temp directory exists
    def self.ensure_tmp_dir
      Dir.mkdir(TMP_DIR) unless File.directory?(TMP_DIR)
      TMP_DIR
    end

    # Clean up temp files
    def self.cleanup_tmp
      return unless File.directory?(TMP_DIR)
      Dir.glob(File.join(TMP_DIR, '*.svg')).each do |f|
        begin
          File.delete(f)
        rescue StandardError => e
          log("Warning: Could not delete temp file #{f}: #{e.message}")
        end
      end
    end

    # Generate a unique temp file path
    def self.temp_svg_path(base_name = 'pdf_import')
      ensure_tmp_dir
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S_%L')
      File.join(TMP_DIR, "#{base_name}_#{timestamp}.svg")
    end

    # Log messages to SketchUp's Ruby console
    def self.log(message)
      puts "[FreePDFImport] #{message}"
    end

    # Check if Poppler binaries are available
    def self.poppler_available?
      File.exist?(PDFTOCAIRO) && File.exist?(PDFINFO)
    end

    # Convert PDF points to SketchUp's internal unit (inches)
    def self.pt_to_inches(pt)
      pt * PT_TO_INCH
    end

    # Quote a file path for shell command usage
    def self.shell_quote(path)
      "\"#{path}\""
    end

    # Get scale factor based on user's chosen unit
    def self.scale_factor_for_unit(unit_name)
      case unit_name
      when 'Inches'
        PT_TO_INCH
      when 'Millimeters'
        PT_TO_INCH  # SketchUp handles mm via Length, we always work in inches internally
      when 'Centimeters'
        PT_TO_INCH
      when 'Points'
        PT_TO_INCH
      else
        PT_TO_INCH
      end
    end
  end
end
