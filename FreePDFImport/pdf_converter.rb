# FreePDFImport - PDF Converter (Poppler wrapper)
# Copyright (C) 2026 hiratazx
# License: GPL-3.0

require_relative 'utils'

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

      cmd = "#{Utils.shell_quote(Utils::PDFINFO)} #{Utils.shell_quote(pdf_path)}"
      output = run_command(cmd)

      if output.nil? || output.strip.empty? || output =~ /^Error:/i
        raise "pdfinfo failed or returned error: #{output}"
      end

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
        cmd = "#{Utils.shell_quote(Utils::PDFINFO)} -f #{page_num} -l #{page_num} #{Utils.shell_quote(pdf_path)}"
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

      cmd = "#{Utils.shell_quote(Utils::PDFTOCAIRO)} -svg " \
            "-f #{page_num} -l #{page_num} " \
            "#{Utils.shell_quote(pdf_path)} #{Utils.shell_quote(output_path)}"

      Utils.log("Converting page #{page_num} to SVG...")
      output = run_command(cmd)

      unless File.exist?(output_path) && File.size(output_path) > 0
        raise "SVG conversion failed — output file not created. Output: #{output}"
      end

      Utils.log("SVG created: #{output_path} (#{File.size(output_path)} bytes)")
      output_path
    end

    private

    # Run a shell command and return stdout using backticks.
    # We write the command to a temporary .bat file to bypass Windows/Ruby shell quoting bugs,
    # as SketchUp's Ruby interpreter struggles with nested quotes in backticks.
    #
    # CRITICAL: We prepend the bin directory to PATH inside the .bat file.
    # Without this, pdfinfo.exe/pdftocairo.exe silently crash on startup because
    # Windows cannot find their DLL dependencies (e.g. Lerc.dll, poppler.dll).
    # The DLLs live next to the .exe in bin/, but when SketchUp's Ruby launches
    # the process, the working directory is SketchUp's own install dir — not bin/.
    # Windows' DLL search order checks CWD and PATH, but NOT the directory of the
    # .exe being invoked, so we must explicitly add it.
    def self.run_command(cmd)
      Utils.log("Running: #{cmd}")

      result = nil
      bat_path = File.join(Utils::TMP_DIR, "run_poppler.bat").tr('/', '\\')
      bin_dir = Utils::BIN_DIR.tr('/', '\\')
      begin
        # Ensure tmp dir exists
        Dir.mkdir(Utils::TMP_DIR) unless Dir.exist?(Utils::TMP_DIR)

        # Build bat file contents:
        # 1. @echo off — suppress command echo
        # 2. set PATH=<bin_dir>;%PATH% — so DLLs next to pdfinfo.exe are found
        # 3. The actual command
        bat_content = "@echo off\r\n" \
                      "set \"PATH=#{bin_dir};%PATH%\"\r\n" \
                      "#{cmd}\r\n"

        File.write(bat_path, bat_content)

        Utils.log("Bat file: #{bat_path}")
        Utils.log("Bat content: #{bat_content.inspect}")

        # Execute the .bat file via cmd /c to ensure proper quote handling
        result = `cmd /c "#{bat_path}" 2>&1`
      rescue StandardError => e
        raise "Could not execute Poppler command: #{e.message}"
      ensure
        # Cleanup
        begin
          File.delete(bat_path) if File.exist?(bat_path)
        rescue
          # Ignore cleanup errors
        end
      end

      Utils.log("Command output (#{result.nil? ? 'nil' : result.length} chars): #{result.to_s[0..200]}")
      result
    end
  end
end
