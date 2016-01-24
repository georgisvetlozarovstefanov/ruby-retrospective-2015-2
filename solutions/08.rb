class Spreadsheet
  attr_accessor :grid, :cells
  def initialize(grid = nil)
    return initialize_empty if grid == nil
    @grid = Spreadsheet.cells(grid)
    @cells = @grid.flatten.each_with_index.
                   map { |cell, index| Cell.new(cell, index, self) }
    @cells.each {|cell| cell.sheet = self}
  end

  def initialize_empty
    @grid = ""
    @cells = []
    @grid
  end

  def empty?
    @grid.size == 0
  end

  def cell_at(cell_index)
    raise  Error, "Invalid cell index '#{ cell_index }'" \
                  if not Index.valid_index?(cell_index)
    cell = @cells.find { |target| target.index_string == cell_index }
    raise Error, "Cell '#{ cell_index }' does not exist" if cell == nil
    cell.content if cell
  end

  def [](cell_index)
    raise  Error, "Invalid cell index '#{ cell_index }'" \
                   if not Index.valid_index?(cell_index)
    cell = @cells.find { |target| target.index_string == cell_index }
    raise Error, "Cell '#{ cell_index }' does not exist" if cell == nil
    Formula.beautify_s(cell.evaluate) if cell
  end

  def self.cells(grid)
    rows = grid.strip.split(/[\n]/)
    rows.map! { |row| row.split(/\s{2,}|\t/) }
    rows.map{ |row| row.delete_if { |cell| cell =~ /^\s*$/ } }
    rows
  end

  def to_s
    return @grid if @grid == ""
    sheet = @cells.map { |cell| cell.evaluate }
    sheet = sheet.each_slice(@grid[0].size).to_a
    sheet.map! { |row| row.join("\t") }
    sheet.join("\n")
  end

  class Error < Exception
  end

  class Index
    attr_accessor :column, :row

    def self.column(number)
      return "" if number == 0
      number % 26 != 0 ? remainder = number % 26 : remainder =  26
      number -= 26 if remainder == 26
      number /= 26
      return "#{ self.column(number) }" + "#{ self.to_letter(remainder) }"
    end

    def self.to_letter(number)
      letters = [*"A".."Z"]
      letter = letters.find { |letter| letter.ord - 64 == number }

      return letter
    end

    def self.is_number?(number_string)
      not number_string.match(/\A[-]?\d+(\.\d+)?\Z/) == nil
    end

    def self.row(number)
      number.to_s
    end

    def self.valid_index?(string)
       string.match(/\A[A-Z]+[1-9]+[0-9]*\z/) != nil
    end

    def initialize(number, rows, columns)
      @column = Index.column(number % columns + 1)
      @row = Index.row(number / columns + 1)
    end
  end

class Expressions
    attr_accessor :cell, :sheet, :expression
    def initialize(expression, cell)
      @cell = cell
      @sheet = @cell.sheet
      @expression = expression[1...expression.size].strip
    end

    def evaluate
      return Formula.beautify_s(cell.sheet[find_key]) if is_cell?
      return Formula.beautify(find_key.to_f) if is_number?
      raise Error, "Invalid expression '#{ expression }'"  if not is_valid?
      raise Error, "Unknown function '#{ find_key }'"  if formula? == nil
      Formula.new(sheet, arguments).method(formula?.downcase).call
    end

    def is_cell?
      expression =~ (/\A *[A-Z]+[0-9]+ *\z/)
    end

    def is_number?
      expression =~ (/\A *[-]?\d+(\.\d+)?\Z/)
    end
    def is_valid?
      (expression.match(%r{\A\ *[A-Z]+\ *\(\ *(([-]?\d+(\.\d+)?)|
                       ([A-Z]+[0-9]+))?\ *\)\z}x) != nil) || \
      (expression.match(%r{\A\ *[A-Z]+\ *\(\ *((([-]?\d+(\.\d+)?)|
                           ([A-Z]+[0-9]+))\ *,\ *)+\ *(([-]?\d+(\.\d+)?)
                           |([A-Z]+[0-9]+))\ *\)\ *\z}x) != nil)
    end



    def formula?
      name = Formula.class_eval("@@names").
                     find { |formula| formula == find_key }
    end
    def arguments
      arguments = expression.split(/[()]/)[1]
      arguments = arguments == nil ? "" : arguments.strip
    end
    def find_key
      key = expression.match(/[A-Z]+[0-9]+/).to_s if is_cell?
      key = expression.match(/[-]?\d+(\.\d+)?/).to_s if is_number?
      key = expression.match(/[A-Z]+/).to_s if not (is_cell? or is_number?) \
                                               and is_valid?
      key
    end
  end

  class Cell
    attr_accessor :content, :index, :sheet, :expression
    def initialize(content, index, sheet)
      @sheet = sheet
      @content = content
      @index = Index.new(index, sheet.grid.size, sheet.grid[0].size)
      @expression = Expressions.new(content, self) if is_expression?
    end

    def is_expression?
      content[0] == "="
    end

    def evaluate
      return content if not is_expression?
      @expression.evaluate
    end

    def index_string
      @index.column + @index.row
    end
  end


  class Formula
    @@names = ["ADD", "MULTIPLY", "SUBTRACT", "DIVIDE", "MOD"]
    attr_accessor :sheet, :arguments
    def add
      raise Error, "Wrong number of arguments for 'ADD': " \
                   "expected at least 2, got #{ arguments.size }" \
                    if arguments.size < 2
      sum = arguments.map { |argument| argument.to_f }.reduce(:+)
      Formula.beautify(sum)
    end

    def multiply
      raise Error, "Wrong number of arguments for 'MULTIPLY': " \
                   "expected at least 2, got #{ arguments.size }" \
                    if arguments.size < 2
      product = arguments.map { |argument| argument.to_f }.reduce(:*)
      Formula.beautify(product)
    end

    def subtract
      raise Error, "Wrong number of arguments for 'SUBTRACT': " \
                   "expected 2, got #{ arguments.size }" \
                    if arguments.size != 2
      difference = arguments[0].to_f - arguments[1].to_f
      Formula.beautify(difference)
    end

    def divide
     raise Error, "Wrong number of arguments for 'DIVIDE': " \
                  "expected 2, got #{ arguments.size }" \
                  if arguments.size != 2
      ratio = arguments[0].to_f / arguments[1].to_f
      Formula.beautify(ratio)
    end

    def mod
      raise Error, "Wrong number of arguments for 'MOD'" \
                   ": expected 2, got #{arguments.size}" \
                    if arguments.size != 2
      remainder = arguments[0].to_f % arguments[1].to_f
      Formula.beautify(remainder)
    end

    def initialize(sheet, arguments)
      @sheet = sheet
      @arguments = arguments.split(",").each { |argument| argument.strip! }
      @arguments.map! do |argument|
        Index.is_number?(argument) ? argument : sheet[argument]
      end
    end

    def self.beautify(number)
      number_s = number.round(2)
      return "#{ number_s.to_i }" if number_s == number_s.to_i
      number_s = number_s.to_s.split(/[.]/)
      number_s[1] = number_s[1] + "0" * (2 - number_s[1].size)
      number_s.join(".")
    end
    def self.beautify_s(string)
      output = string.strip
      is_number = Index.is_number?(output)

      is_number ? Formula.beautify(output.to_f) : output
    end
  end
end