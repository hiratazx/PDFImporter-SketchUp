# FreePDFImport - Import Options Dialog
# Copyright (C) 2026 hiratazx
# License: GPL-3.0
#
# Provides UI dialogs for import configuration:
# - Page selection for multi-page PDFs
# - Scale and quality settings

require_relative 'utils'
require_relative 'drawing'

module FreePDFImport
  module ImportDialog
    # Show page selection dialog for multi-page PDFs
    # Returns the selected page number (1-indexed), or nil if cancelled
    def self.show_page_selector(pdf_info)
      total_pages = pdf_info[:pages] || 1

      if total_pages <= 0
        UI.messagebox("Error: Could not determine page count for this PDF.", MB_OK)
        return nil
      end

      # Build page list for dropdown
      page_options = (1..total_pages).map { |n| "Page #{n}" }
      page_list = page_options.join('|')

      # Show input dialog
      prompts = ['Select Page:', 'Scale:', 'Import As:', 'Curve Quality:']
      defaults = [page_options[0], '1.0', 'Edges + Faces', 'Medium']
      list = [page_list, '', 'Edges Only|Edges + Faces', 'Low|Medium|High']

      title = "Free PDF Import — #{total_pages} page(s) | #{pdf_info[:width].round(1)}×#{pdf_info[:height].round(1)} pts"

      result = UI.inputbox(prompts, defaults, list, title)
      return nil unless result

      # Parse results
      page_str = result[0]
      page_num = page_str.scan(/\d+/).first.to_i

      scale = result[1].to_f
      scale = 1.0 if scale <= 0

      create_faces = (result[2] == 'Edges + Faces')

      quality = case result[3]
                when 'High' then :high
                when 'Low' then :low
                else :medium
                end

      options = Drawing::ImportOptions.new(
        scale,
        create_faces,
        quality,
        true,  # merge_coplanar
        true   # place_on_ground
      )

      { page: page_num, options: options }
    end

    # Show a simple progress notification
    def self.show_progress(message)
      Sketchup.status_text = "[Free PDF Import] #{message}"
      Utils.log(message)
    end

    # Show completion summary
    def self.show_summary(result)
      msg = "PDF Import Complete!\n\n" \
            "Paths drawn: #{result[:paths]}\n" \
            "Edges created: #{result[:edges]}\n" \
            "Faces created: #{result[:faces]}"
      UI.messagebox(msg, MB_OK)
    end

    # Show error dialog
    def self.show_error(message)
      UI.messagebox("PDF Import Error:\n\n#{message}", MB_OK)
      Utils.log("ERROR: #{message}")
    end
  end
end
