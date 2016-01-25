class TurtleGraphics
  class TurtleGraphics::Turtle
    MOVEMENT = { :right => [1, 0],
                   :up => [0, -1],
                   :left => [-1, 0],
                   :down => [0, 1] }

    attr_accessor :canvas, :position, :orientation, :max_opacity

    def initialize(rows, columns)
      @canvas = []
      for i in 1..rows
        @canvas << Array.new(columns, 0)
      end
      @position, @canvas[0][0], @orientation, @max_opacity = [0, 0], 1, :right, 1
    end

    def draw(palette = nil, &block)
      instance_eval(&block) if block_given?
      palette == nil ? canvas : palette.paint(canvas, max_opacity)
    end

    def move
      @position[1] += MOVEMENT[orientation][0]
      @position[1] %= canvas[0].size
      @position[0] += MOVEMENT[orientation][1]
      @position[0] %= canvas.size
      @canvas[position[0]][position[1]] += 1
      @max_opacity += 1 if max_opacity < canvas[position[0]][position[1]]
    end

    def turn_left
     @orientation = case orientation
                    when :right then :up
                    when :up then :left
                    when :left then :down
                    when :down then :right
                    end
    end

    def turn_right
      3.times { turn_left }
    end

    def spawn_at(row, column)
      canvas[0][0], position[0], position[1] = 0, row, column

      canvas[row][column] = 1
    end

    def look(orientation)
      @orientation = orientation
    end
  end

  class TurtleGraphics::Canvas

    class TurtleGraphics::Canvas::ASCII
      attr_accessor :spectrum

      def initialize(spectrum)
        @spectrum = spectrum
      end

      def brush(number, max_opacity)
        color = 0
        until(number.fdiv(max_opacity)) <= color * (1.0) / (spectrum.size - 1)
          color += 1
        end
        spectrum[color]
      end

      def paint(array, max_opacity)
        array.map { |row| row.map { |number| brush(number, max_opacity) } }.
              map { |x| x.join("") }.join("\n")
      end
    end

    class TurtleGraphics::Canvas::HTML
      attr_accessor :pixel_size

      TD = "\t\s\s<td style=\"opacity: "
      TD_END = "\"></td>"
      BODY_START = "\n<body>\n\s\s<table>\n\t<tr>\n"
      BODY_END = "\n\t</tr>\n\s\s</table>\n</body>\n</html>"

      def initialize(pixel_size)
        @pixel_size = pixel_size

        @head = "<!DOCTYPE html>\n<html>\n<head>\n\s\s<title>Turtle "\
                "graphics</title>\n\n\n\s\s<style>\n\ttable {\n\t\s\s"\
                "border-spacing: 0;\n\t}\n\n\n\ttr {\n\t\s\spadding: 0"\
                ";\n\t}\n\n\n\ttd {\n\t\s\swidth: #{@pixel_size}px;\n\t"\
                "\s\sheight: #{pixel_size}px;\n\n\n\t\s\sbackground-colo"\
                "r: black;\n\t\s\spadding: 0;\n\t}\n\s\s</style>\n</head>"
      end

      def brush(number, max_opacity)
        format('%.2f', number.fdiv(max_opacity))
      end

      def paint_row(row, max_opacity)
        row.map { |number| TD + "#{brush(number, max_opacity)}" + TD_END }
      end

      def combine_rows(array, max_opacity)
        array.map { |row| paint_row(row, max_opacity) }.
              map { |row| row.join("\n") }.
              join("\n\t</tr>\n\t<tr>\n")
      end

      def paint(array, max_opacity)
        message = combine_rows(array, max_opacity)

        @head + BODY_START + "#{message}" + BODY_END
      end
    end
  end
end