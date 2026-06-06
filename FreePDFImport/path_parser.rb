# FreePDFImport - SVG Path Data Parser
# Copyright (C) 2026 hiratazx
# License: GPL-3.0
#
# Parses SVG path `d` attribute strings into arrays of drawing commands.
# Supports all SVG path commands: M, L, H, V, C, S, Q, T, A, Z
# Handles both absolute (uppercase) and relative (lowercase) commands.
# Bézier curves are subdivided into line segments.

module FreePDFImport
  module PathParser
    # A single drawing command with absolute coordinates
    DrawCommand = Struct.new(:type, :points)
    # :type is one of :move, :line, :close
    # :points is array of [x, y] pairs

    # Parse an SVG path `d` attribute string
    # Returns an array of subpaths, where each subpath is an array of [x, y] points
    # curve_tolerance controls Bézier subdivision quality
    def self.parse(d_string, curve_tolerance = 0.5)
      return [] if d_string.nil? || d_string.strip.empty?

      tokens = tokenize(d_string)
      return [] if tokens.empty?

      subpaths = []
      current_path = []
      current_x = 0.0
      current_y = 0.0
      subpath_start_x = 0.0
      subpath_start_y = 0.0
      last_control_x = nil
      last_control_y = nil
      last_command = nil

      i = 0
      while i < tokens.length
        token = tokens[i]

        if is_command?(token)
          cmd = token
          i += 1
        elsif last_command
          # Implicit repeat of the last command
          # After M, implicit repeats become L; after m, implicit repeats become l
          cmd = last_command
          if cmd == 'M'
            cmd = 'L'
          elsif cmd == 'm'
            cmd = 'l'
          end
        else
          i += 1
          next
        end

        case cmd
        when 'M' # Absolute move to
          # Save current subpath if it has points
          if current_path.length > 0
            subpaths << current_path
          end
          current_x = tokens[i].to_f
          current_y = tokens[i + 1].to_f
          current_path = [[current_x, current_y]]
          subpath_start_x = current_x
          subpath_start_y = current_y
          last_control_x = nil
          last_control_y = nil
          i += 2

        when 'm' # Relative move to
          if current_path.length > 0
            subpaths << current_path
          end
          current_x += tokens[i].to_f
          current_y += tokens[i + 1].to_f
          current_path = [[current_x, current_y]]
          subpath_start_x = current_x
          subpath_start_y = current_y
          last_control_x = nil
          last_control_y = nil
          i += 2

        when 'L' # Absolute line to
          current_x = tokens[i].to_f
          current_y = tokens[i + 1].to_f
          current_path << [current_x, current_y]
          last_control_x = nil
          last_control_y = nil
          i += 2

        when 'l' # Relative line to
          current_x += tokens[i].to_f
          current_y += tokens[i + 1].to_f
          current_path << [current_x, current_y]
          last_control_x = nil
          last_control_y = nil
          i += 2

        when 'H' # Absolute horizontal line
          current_x = tokens[i].to_f
          current_path << [current_x, current_y]
          last_control_x = nil
          last_control_y = nil
          i += 1

        when 'h' # Relative horizontal line
          current_x += tokens[i].to_f
          current_path << [current_x, current_y]
          last_control_x = nil
          last_control_y = nil
          i += 1

        when 'V' # Absolute vertical line
          current_y = tokens[i].to_f
          current_path << [current_x, current_y]
          last_control_x = nil
          last_control_y = nil
          i += 1

        when 'v' # Relative vertical line
          current_y += tokens[i].to_f
          current_path << [current_x, current_y]
          last_control_x = nil
          last_control_y = nil
          i += 1

        when 'C' # Absolute cubic Bézier
          x1 = tokens[i].to_f
          y1 = tokens[i + 1].to_f
          x2 = tokens[i + 2].to_f
          y2 = tokens[i + 3].to_f
          x  = tokens[i + 4].to_f
          y  = tokens[i + 5].to_f
          points = subdivide_cubic(current_x, current_y, x1, y1, x2, y2, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = x2
          last_control_y = y2
          current_x = x
          current_y = y
          i += 6

        when 'c' # Relative cubic Bézier
          x1 = current_x + tokens[i].to_f
          y1 = current_y + tokens[i + 1].to_f
          x2 = current_x + tokens[i + 2].to_f
          y2 = current_y + tokens[i + 3].to_f
          x  = current_x + tokens[i + 4].to_f
          y  = current_y + tokens[i + 5].to_f
          points = subdivide_cubic(current_x, current_y, x1, y1, x2, y2, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = x2
          last_control_y = y2
          current_x = x
          current_y = y
          i += 6

        when 'S' # Absolute smooth cubic Bézier
          # First control point is reflection of the last control point
          if last_control_x && (last_command == 'C' || last_command == 'c' || last_command == 'S' || last_command == 's')
            x1 = 2 * current_x - last_control_x
            y1 = 2 * current_y - last_control_y
          else
            x1 = current_x
            y1 = current_y
          end
          x2 = tokens[i].to_f
          y2 = tokens[i + 1].to_f
          x  = tokens[i + 2].to_f
          y  = tokens[i + 3].to_f
          points = subdivide_cubic(current_x, current_y, x1, y1, x2, y2, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = x2
          last_control_y = y2
          current_x = x
          current_y = y
          i += 4

        when 's' # Relative smooth cubic Bézier
          if last_control_x && (last_command == 'C' || last_command == 'c' || last_command == 'S' || last_command == 's')
            x1 = 2 * current_x - last_control_x
            y1 = 2 * current_y - last_control_y
          else
            x1 = current_x
            y1 = current_y
          end
          x2 = current_x + tokens[i].to_f
          y2 = current_y + tokens[i + 1].to_f
          x  = current_x + tokens[i + 2].to_f
          y  = current_y + tokens[i + 3].to_f
          points = subdivide_cubic(current_x, current_y, x1, y1, x2, y2, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = x2
          last_control_y = y2
          current_x = x
          current_y = y
          i += 4

        when 'Q' # Absolute quadratic Bézier
          cx = tokens[i].to_f
          cy = tokens[i + 1].to_f
          x  = tokens[i + 2].to_f
          y  = tokens[i + 3].to_f
          points = subdivide_quadratic(current_x, current_y, cx, cy, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = cx
          last_control_y = cy
          current_x = x
          current_y = y
          i += 4

        when 'q' # Relative quadratic Bézier
          cx = current_x + tokens[i].to_f
          cy = current_y + tokens[i + 1].to_f
          x  = current_x + tokens[i + 2].to_f
          y  = current_y + tokens[i + 3].to_f
          points = subdivide_quadratic(current_x, current_y, cx, cy, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = cx
          last_control_y = cy
          current_x = x
          current_y = y
          i += 4

        when 'T' # Absolute smooth quadratic Bézier
          if last_control_x && (last_command == 'Q' || last_command == 'q' || last_command == 'T' || last_command == 't')
            cx = 2 * current_x - last_control_x
            cy = 2 * current_y - last_control_y
          else
            cx = current_x
            cy = current_y
          end
          x = tokens[i].to_f
          y = tokens[i + 1].to_f
          points = subdivide_quadratic(current_x, current_y, cx, cy, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = cx
          last_control_y = cy
          current_x = x
          current_y = y
          i += 2

        when 't' # Relative smooth quadratic Bézier
          if last_control_x && (last_command == 'Q' || last_command == 'q' || last_command == 'T' || last_command == 't')
            cx = 2 * current_x - last_control_x
            cy = 2 * current_y - last_control_y
          else
            cx = current_x
            cy = current_y
          end
          x = current_x + tokens[i].to_f
          y = current_y + tokens[i + 1].to_f
          points = subdivide_quadratic(current_x, current_y, cx, cy, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          last_control_x = cx
          last_control_y = cy
          current_x = x
          current_y = y
          i += 2

        when 'A' # Absolute elliptical arc
          rx = tokens[i].to_f
          ry = tokens[i + 1].to_f
          x_rotation = tokens[i + 2].to_f
          large_arc = tokens[i + 3].to_f.to_i
          sweep = tokens[i + 4].to_f.to_i
          x = tokens[i + 5].to_f
          y = tokens[i + 6].to_f
          points = arc_to_lines(current_x, current_y, rx, ry, x_rotation, large_arc, sweep, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          current_x = x
          current_y = y
          last_control_x = nil
          last_control_y = nil
          i += 7

        when 'a' # Relative elliptical arc
          rx = tokens[i].to_f
          ry = tokens[i + 1].to_f
          x_rotation = tokens[i + 2].to_f
          large_arc = tokens[i + 3].to_f.to_i
          sweep = tokens[i + 4].to_f.to_i
          x = current_x + tokens[i + 5].to_f
          y = current_y + tokens[i + 6].to_f
          points = arc_to_lines(current_x, current_y, rx, ry, x_rotation, large_arc, sweep, x, y, curve_tolerance)
          points.each { |pt| current_path << pt }
          current_x = x
          current_y = y
          last_control_x = nil
          last_control_y = nil
          i += 7

        when 'Z', 'z' # Close path
          # Close back to the subpath start
          if current_path.length > 0
            first = current_path.first
            # Only add closing point if we're not already there
            unless (current_x - first[0]).abs < 0.001 && (current_y - first[1]).abs < 0.001
              current_path << [subpath_start_x, subpath_start_y]
            end
            current_path.instance_variable_set(:@closed, true)
            # Define a singleton method to check if path is closed
            def current_path.closed?
              @closed == true
            end
            subpaths << current_path
            current_path = []
          end
          current_x = subpath_start_x
          current_y = subpath_start_y
          last_control_x = nil
          last_control_y = nil

        else
          # Unknown command, skip
          Utils.log("Warning: Unknown SVG path command '#{cmd}', skipping")
          i += 1
        end

        last_command = cmd
      end

      # Don't forget the last subpath if it wasn't closed
      if current_path.length > 0
        subpaths << current_path
      end

      subpaths
    end

    private

    # Check if a token is a command letter
    def self.is_command?(token)
      token.is_a?(String) && token =~ /^[a-zA-Z]$/ && token != 'e' && token != 'E'
    end

    # Tokenize an SVG path d-string into commands and numbers
    def self.tokenize(d_string)
      tokens = []
      # Split the d string: separate command letters from numbers
      # Handle negative numbers, decimal points, and comma separators
      scanner = d_string.scan(/([a-df-zA-DF-Z])|([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)/i)

      scanner.each do |match|
        if match[0]
          # It's a command letter
          tokens << match[0]
        elsif match[1]
          # It's a number
          tokens << match[1]
        end
      end

      tokens
    end

    # Subdivide a cubic Bézier curve into line segments
    # Uses recursive de Casteljau subdivision
    def self.subdivide_cubic(x0, y0, x1, y1, x2, y2, x3, y3, tolerance, depth = 0)
      # Check if the curve is flat enough to approximate with a line
      if depth > 10 || cubic_is_flat?(x0, y0, x1, y1, x2, y2, x3, y3, tolerance)
        return [[x3, y3]]
      end

      # De Casteljau subdivision at t = 0.5
      mx01 = (x0 + x1) / 2.0; my01 = (y0 + y1) / 2.0
      mx12 = (x1 + x2) / 2.0; my12 = (y1 + y2) / 2.0
      mx23 = (x2 + x3) / 2.0; my23 = (y2 + y3) / 2.0

      mx012 = (mx01 + mx12) / 2.0; my012 = (my01 + my12) / 2.0
      mx123 = (mx12 + mx23) / 2.0; my123 = (my12 + my23) / 2.0

      mx0123 = (mx012 + mx123) / 2.0; my0123 = (my012 + my123) / 2.0

      left = subdivide_cubic(x0, y0, mx01, my01, mx012, my012, mx0123, my0123, tolerance, depth + 1)
      right = subdivide_cubic(mx0123, my0123, mx123, my123, mx23, my23, x3, y3, tolerance, depth + 1)

      left + right
    end

    # Check if a cubic Bézier is flat enough to approximate as a line
    def self.cubic_is_flat?(x0, y0, x1, y1, x2, y2, x3, y3, tolerance)
      # Calculate the maximum deviation of control points from the line P0-P3
      ux = 3.0 * x1 - 2.0 * x0 - x3; ux *= ux
      uy = 3.0 * y1 - 2.0 * y0 - y3; uy *= uy
      vx = 3.0 * x2 - 2.0 * x3 - x0; vx *= vx
      vy = 3.0 * y2 - 2.0 * y3 - y0; vy *= vy

      ux = vx if vx > ux
      uy = vy if vy > uy

      (ux + uy) <= (16.0 * tolerance * tolerance)
    end

    # Subdivide a quadratic Bézier curve into line segments
    def self.subdivide_quadratic(x0, y0, cx, cy, x1, y1, tolerance, depth = 0)
      # Convert quadratic to cubic for uniform handling
      # Cubic control points from quadratic: CP1 = P0 + 2/3*(CP-P0), CP2 = P1 + 2/3*(CP-P1)
      c1x = x0 + 2.0/3.0 * (cx - x0)
      c1y = y0 + 2.0/3.0 * (cy - y0)
      c2x = x1 + 2.0/3.0 * (cx - x1)
      c2y = y1 + 2.0/3.0 * (cy - y1)

      subdivide_cubic(x0, y0, c1x, c1y, c2x, c2y, x1, y1, tolerance, depth)
    end

    # Convert an elliptical arc to line segments
    # Implementation of the SVG arc parameterization algorithm
    def self.arc_to_lines(x0, y0, rx, ry, x_rotation_deg, large_arc_flag, sweep_flag, x1, y1, tolerance)
      # Handle degenerate cases
      if (x0 - x1).abs < 0.001 && (y0 - y1).abs < 0.001
        return []
      end

      rx = rx.abs
      ry = ry.abs

      if rx < 0.001 || ry < 0.001
        # Degenerate to line
        return [[x1, y1]]
      end

      # Convert rotation to radians
      phi = x_rotation_deg * Math::PI / 180.0
      cos_phi = Math.cos(phi)
      sin_phi = Math.sin(phi)

      # Step 1: Compute (x1', y1') — translated/rotated midpoint
      dx2 = (x0 - x1) / 2.0
      dy2 = (y0 - y1) / 2.0
      x1p = cos_phi * dx2 + sin_phi * dy2
      y1p = -sin_phi * dx2 + cos_phi * dy2

      # Step 2: Compute (cx', cy') — center in transformed coords
      x1p_sq = x1p * x1p
      y1p_sq = y1p * y1p
      rx_sq = rx * rx
      ry_sq = ry * ry

      # Check if radii are large enough
      lambda = x1p_sq / rx_sq + y1p_sq / ry_sq
      if lambda > 1.0
        lambda_sqrt = Math.sqrt(lambda)
        rx *= lambda_sqrt
        ry *= lambda_sqrt
        rx_sq = rx * rx
        ry_sq = ry * ry
      end

      num = rx_sq * ry_sq - rx_sq * y1p_sq - ry_sq * x1p_sq
      den = rx_sq * y1p_sq + ry_sq * x1p_sq

      if den < 0.0001
        sq = 0.0
      else
        sq = [num / den, 0.0].max
        sq = Math.sqrt(sq)
      end

      sq = -sq if large_arc_flag == sweep_flag

      cxp = sq * rx * y1p / ry
      cyp = -sq * ry * x1p / rx

      # Step 3: Compute (cx, cy) from (cx', cy')
      cx = cos_phi * cxp - sin_phi * cyp + (x0 + x1) / 2.0
      cy = sin_phi * cxp + cos_phi * cyp + (y0 + y1) / 2.0

      # Step 4: Compute theta1 and dtheta
      theta1 = angle_between(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
      dtheta = angle_between((x1p - cxp) / rx, (y1p - cyp) / ry,
                             (-x1p - cxp) / rx, (-y1p - cyp) / ry)

      if sweep_flag == 0 && dtheta > 0
        dtheta -= 2 * Math::PI
      elsif sweep_flag == 1 && dtheta < 0
        dtheta += 2 * Math::PI
      end

      # Step 5: Generate points along the arc
      # Number of segments based on arc length and tolerance
      n_segs = [((dtheta.abs / (Math::PI / 4.0)).ceil), 1].max
      n_segs = [n_segs, 64].min  # Cap at 64 segments

      points = []
      (1..n_segs).each do |seg|
        t = theta1 + dtheta * seg.to_f / n_segs.to_f
        px = cos_phi * rx * Math.cos(t) - sin_phi * ry * Math.sin(t) + cx
        py = sin_phi * rx * Math.cos(t) + cos_phi * ry * Math.sin(t) + cy
        points << [px, py]
      end

      points
    end

    # Calculate angle between two vectors
    def self.angle_between(ux, uy, vx, vy)
      n = Math.sqrt(ux * ux + uy * uy) * Math.sqrt(vx * vx + vy * vy)
      return 0.0 if n < 0.0001

      c = (ux * vx + uy * vy) / n
      c = [[-1.0, c].max, 1.0].min  # Clamp to [-1, 1]

      angle = Math.acos(c)
      angle = -angle if (ux * vy - uy * vx) < 0
      angle
    end
  end
end
