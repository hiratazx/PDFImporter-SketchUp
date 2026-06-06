# FreePDFImport - PDF Converter (Poppler wrapper)
# Copyright (C) 2026 hiratazx
# License: GPL-3.0

require_relative 'utils'
require 'open3'

module FreePDFImport
  module PDFConverter
    # Get PDF metadata using pdfinfo
    # Returns a Hash with :pages, :width, :height (in PDF points), :title, etc.
    def self.get_pdf_info(pdf_path)
      unless Utils.poppler_available?
        raise "Poppler binaries not found in #{Utils.BIN_DIR}"
      end

      unless File.exist?(pdf_path)
        raise "PDF file not found: #{pdf_path}"
      end

      cmd = [Utils::PDFINFO, pdf_path]
      output = run_command(cmd)

      info = {}
      output.each_line do |line|
        line = line.strip
        if line =~ /^Pages:\s+(\d+)/
          info[:pages] = $1.to_i
        elsif line =~ /^Page size:\s+([\d.]+)\s+x\s+([\d.]+)\s+pts/
          info[:width] = $1.to_f
          info[:height] = $2.to_f
        elsif line =~ /^Title:\s+(.+)/
          info[:title] = $1.strip
        elsif line =~ /^Author:\s+(.+)/
          info[:author] = $1.strip
        elsif line =~ /^Creator:\s+(.+)/
          info[:creator_tool] = $1.strip
        end
      end

      # Default to 1 page if not found
      info[:pages] ||= 1
      # Default to letter size if dimensions not detected
      info[:width] ||= 612.0  # 8.5 inches
      info[:height] ||= 792.0 # 11 inches

      Utils.log("PDF info: #{info[:pages]} page(s), #{info[:width]}x#{info[:height]} pts")
      info
    end

    # Get per-page info for multi-page PDFs
    # Returns array of hashes with :page, :width, :height
    def self.get_page_dimensions(pdf_path, total_pages)
      pages = []
      (1..total_pages).each do |page_num|
        cmd = [Utils::PDFINFO, '-f', page_num.to_s, '-l', page_num.to_s, pdf_path]
        output = run_command(cmd)

        width = nil
        height = nil
        output.each_line do |line|
          if line =~ /^Page\s+\d+\s+size:\s+([\d.]+)\s+x\s+([\d.]+)\s+pts/ ||
             line =~ /^Page size:\s+([\d.]+)\s+x\s+([\d.]+)\s+pts/
            width = $1.to_f
            height = $2.to_f
          end
        end

        pages << {
          page: page_num,
          width: width || 612.0,
          height: height || 792.0
        }
      end
      pages
    end

    # Convert a PDF page to SVG using pdftocairo
    # Returns the path to the generated SVG file
    def self.convert_to_svg(pdf_path, page_num = 1, output_path = nil)
      unless Utils.poppler_available?
        raise "Poppler binaries not found in #{Utils.BIN_DIR}"
      end

      unless File.exist?(pdf_path)
        raise "PDF file not found: #{pdf_path}"
      end

      output_path ||= Utils.temp_svg_path("page#{page_num}")

      cmd = [
        Utils::PDFTOCAIRO,
        '-svg',
        '-f', page_num.to_s,
        '-l', page_num.to_s,
        pdf_path,
        output_path
      ]

      Utils.log("Converting page #{page_num} to SVG...")
      run_command(cmd)

      unless File.exist?(output_path)
        raise "SVG conversion failed — output file not created: #{output_path}"
      end

      Utils.log("SVG created: #{output_path} (#{File.size(output_path)} bytes)")
      output_path
    end

    private

    # Run a command using Open3 and return stdout/stderr
    # Raises on non-zero exit code
    def self.run_command(cmd_array)
      Utils.log("Running: #{cmd_array.join(' ')}")

      result = nil
      begin
        result, status = Open3.capture2e(*cmd_array)
        exit_code = status.exitstatus

        if exit_code != 0
          Utils.log("Command failed (exit #{exit_code.inspect}): #{result}")
          raise "Poppler command failed (exit #{exit_code.inspect}): #{result.strip}"
        end
      rescue StandardError => e
        raise "Could not execute Poppler command: #{e.message}"
      end

      result
    end
  end
end
