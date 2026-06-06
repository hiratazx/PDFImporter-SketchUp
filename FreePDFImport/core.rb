# FreePDFImport - Core Module
# Copyright (C) 2026 hiratazx
# License: GPL-3.0
#
# Main entry point for the extension. Sets up menus, toolbar,
# and orchestrates the PDF import workflow.

require_relative 'utils'
require_relative 'pdf_converter'
require_relative 'svg_parser'
require_relative 'path_parser'
require_relative 'drawing'
require_relative 'import_dialog'

module FreePDFImport
  # Store last used directory for convenience
  @last_directory = nil

  # Main import workflow
  def self.import_pdf
    # Step 1: Check Poppler availability
    unless Utils.poppler_available?
      ImportDialog.show_error(
        "Poppler binaries not found!\n\n" \
        "Expected location:\n#{Utils::BIN_DIR}\n\n" \
        "Please ensure pdftocairo.exe and pdfinfo.exe are in the bin directory."
      )
      return
    end

    # Step 2: Select PDF file
    filter = 'PDF Files (*.pdf)|*.pdf||'
    title = 'Select PDF to Import'

    pdf_path = UI.openpanel(title, @last_directory || '', filter)
    return unless pdf_path  # User cancelled

    # Remember directory for next time
    @last_directory = File.dirname(pdf_path)
    pdf_name = File.basename(pdf_path, '.pdf')

    ImportDialog.show_progress("Reading PDF info...")

    # Step 3: Get PDF metadata
    begin
      pdf_info = PDFConverter.get_pdf_info(pdf_path)
    rescue StandardError => e
      ImportDialog.show_error("Could not read PDF:\n#{e.message}")
      return
    end

    # Step 4: Show page selector dialog (always prompt)
    result = ImportDialog.show_page_selector(pdf_info)
    return unless result  # User cancelled

    page_num = result[:page]
    options = result[:options]

    ImportDialog.show_progress("Converting page #{page_num} to SVG...")

    # Step 5: Convert PDF page to SVG
    svg_path = nil
    begin
      svg_path = PDFConverter.convert_to_svg(pdf_path, page_num)
    rescue StandardError => e
      ImportDialog.show_error("PDF conversion failed:\n#{e.message}")
      return
    end

    ImportDialog.show_progress("Parsing SVG vector data...")

    # Step 6: Parse SVG
    curve_tolerance = Drawing.tolerance_for_quality(options.curve_quality)
    svg_data = nil
    begin
      svg_data = SVGParser.parse_file(svg_path, curve_tolerance)
    rescue StandardError => e
      ImportDialog.show_error("SVG parsing failed:\n#{e.message}")
      cleanup_temp(svg_path)
      return
    end

    if svg_data.paths.empty?
      ImportDialog.show_error(
        "No vector paths found in this PDF page.\n\n" \
        "This may happen if the PDF contains only raster images or text without outlines."
      )
      cleanup_temp(svg_path)
      return
    end

    ImportDialog.show_progress("Creating #{svg_data.paths.length} path(s) in SketchUp...")

    # Step 7: Draw geometry
    draw_result = nil
    begin
      group_name = "#{pdf_name} (p#{page_num})"
      draw_result = Drawing.draw(svg_data, options, group_name)
    rescue StandardError => e
      ImportDialog.show_error("Drawing failed:\n#{e.message}")
      cleanup_temp(svg_path)
      return
    end

    # Step 8: Cleanup and show results
    cleanup_temp(svg_path)
    ImportDialog.show_progress("Import complete!")

    # Zoom to the imported group
    if draw_result[:group] && draw_result[:group].valid?
      Sketchup.active_model.active_view.zoom(draw_result[:group])
    end

    ImportDialog.show_summary(draw_result)
  end

  # Clean up a specific temp file
  def self.cleanup_temp(svg_path)
    begin
      File.delete(svg_path) if svg_path && File.exist?(svg_path)
    rescue StandardError => e
      Utils.log("Warning: Could not clean up temp file: #{e.message}")
    end
  end

  # ─── Menu & Toolbar Setup ──────────────────────────────────────────────

  unless file_loaded?(File.join(__dir__, 'core.rb'))
    # Add to Extensions menu
    menu = UI.menu('Extensions')
    submenu = menu.add_submenu('Free PDF Import')

    submenu.add_item('Import PDF...') { import_pdf }
    submenu.add_separator
    submenu.add_item('Clean Temp Files') do
      Utils.cleanup_tmp
      UI.messagebox("Temporary files cleaned.", MB_OK)
    end
    submenu.add_item('About') do
      UI.messagebox(
        "Free PDF Import v#{PLUGIN_VERSION}\n\n" \
        "A free, open-source PDF importer for SketchUp.\n" \
        "Converts PDF vector graphics to SketchUp geometry.\n\n" \
        "Uses Poppler (GPL) for PDF processing.\n" \
        "Author: hiratazx\n" \
        "License: GPL-3.0\n\n" \
        "https://github.com/hiratazx/PDFImporter-SketchUp",
        MB_OK
      )
    end

    # Create toolbar
    toolbar = UI::Toolbar.new('Free PDF Import')

    import_cmd = UI::Command.new('Import PDF') { import_pdf }
    import_cmd.tooltip = 'Import a PDF file as vector geometry'
    import_cmd.status_bar_text = 'Import PDF as vector graphics into the current model'
    import_cmd.menu_text = 'Import PDF'

    # Use a simple SVG icon embedded as a small icon
    # SketchUp supports PNG icons; we'll set a placeholder that works
    icon_path = File.join(File.dirname(__FILE__), 'icon')
    if File.exist?("#{icon_path}.png")
      import_cmd.small_icon = "#{icon_path}.png"
      import_cmd.large_icon = "#{icon_path}.png"
    elsif File.exist?("#{icon_path}_24.png")
      import_cmd.small_icon = "#{icon_path}_24.png"
      import_cmd.large_icon = "#{icon_path}_24.png"
    end

    toolbar.add_item(import_cmd)
    toolbar.show

    file_loaded(File.join(__dir__, 'core.rb'))
  end
end
