# FreePDFImport - Drawing Module (SketchUp Geometry Creation)
# Copyright (C) 2026 hiratazx
# License: GPL-3.0
#
# Converts parsed SVG paths into SketchUp edges and faces.
# Handles coordinate system transformation (SVG Y-down → SketchUp Y-up on ground plane).

require_relative 'utils'

module FreePDFImport
  module Drawing
    # Import options struct
    ImportOptions = Struct.new(:scale, :create_faces, :curve_quality, :merge_coplanar, :place_on_ground)

    DEFAULT_OPTIONS = ImportOptions.new(
      1.0,      # scale: 1:1
      true,     # create_faces: fill closed paths
      :medium,  # curve_quality: :low, :medium, :high
      true,     # merge_coplanar: merge coplanar faces
      true      # place_on_ground: place geometry on ground plane (Z=0)
    ).freeze

    # Draw parsed SVG data into the SketchUp model
    # svg_data: SVGParser::SVGData
    # options: ImportOptions
    # Returns the group containing all imported geometry
    def self.draw(svg_data, options = nil, pdf_name = 'PDF Import')
      options ||= DEFAULT_OPTIONS.dup
      model = Sketchup.active_model

      # Determine curve tolerance from quality setting
      curve_tolerance = case options.curve_quality
                        when :high then Utils::CURVE_TOLERANCE_HIGH
                        when :low then Utils::CURVE_TOLERANCE_LOW
                        else Utils::CURVE_TOLERANCE_MEDIUM
                        end

      # Calculate scale factor
      # SVG coordinates from pdftocairo are in PDF points
      # SketchUp works in inches internally
      # 1 PDF point = 1/72 inch
      scale = Utils::PT_TO_INCH * options.scale

      # Get SVG dimensions for coordinate flipping
      svg_height = svg_data.height

      # If viewBox is present, use it for coordinate mapping
      if svg_data.view_box
        svg_height = svg_data.view_box[:height]
      end

      model.start_operation("Import PDF: #{pdf_name}", true)

      begin
        # Create a group to contain all imported geometry
        group = model.active_entities.add_group
        group.name = pdf_name
        entities = group.entities

        paths_drawn = 0
        edges_created = 0
        faces_created = 0

        svg_data.paths.each do |parsed_path|
          next if parsed_path.points.nil? || parsed_path.points.length < 2

          # Convert SVG coordinates to SketchUp coordinates
          # SVG: origin at top-left, Y increases downward
          # SketchUp: origin at bottom-left, Y increases to the right (we draw on X-Y plane, Z up)
          # We'll map SVG X → SketchUp X, SVG Y (flipped) → SketchUp Y, Z = 0
          su_points = parsed_path.points.map do |pt|
            x = pt[0] * scale
            y = (svg_height - pt[1]) * scale  # Flip Y axis
            z = 0.0
            Geom::Point3d.new(x, y, z)
          end

          # Remove duplicate consecutive points
          cleaned_points = [su_points.first]
          (1...su_points.length).each do |i|
            prev = cleaned_points.last
            curr = su_points[i]
            dist = prev.distance(curr)
            # SketchUp has a minimum edge length (~0.001 inches)
            if dist > 0.001
              cleaned_points << curr
            end
          end

          next if cleaned_points.length < 2

          begin
            if parsed_path.closed && options.create_faces && cleaned_points.length >= 3
              # Create a face from the closed path
              face = entities.add_face(cleaned_points)
              if face
                faces_created += 1
                edges_created += face.edges.length
              else
                # Face creation failed, fall back to edges
                edges = entities.add_edges(cleaned_points)
                edges_created += edges.length if edges
              end
            else
              # Create edges only
              edges = entities.add_edges(cleaned_points)
              if edges
                edges_created += edges.length
                # Try to find faces from the created edges
                if options.create_faces
                  edges.each do |edge|
                    found = edge.find_faces
                    faces_created += found if found && found > 0
                  end
                end
              end
            end
            paths_drawn += 1
          rescue StandardError => e
            Utils.log("Warning: Failed to draw path: #{e.message}")
          end
        end

        model.commit_operation

        Utils.log("Drawing complete: #{paths_drawn} paths, #{edges_created} edges, #{faces_created} faces")
        { group: group, paths: paths_drawn, edges: edges_created, faces: faces_created }

      rescue StandardError => e
        model.abort_operation
        Utils.log("Error during drawing: #{e.message}")
        raise
      end
    end

    # Get curve tolerance from quality setting
    def self.tolerance_for_quality(quality)
      case quality
      when :high then Utils::CURVE_TOLERANCE_HIGH
      when :low then Utils::CURVE_TOLERANCE_LOW
      else Utils::CURVE_TOLERANCE_MEDIUM
      end
    end
  end
end
