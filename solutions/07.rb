class LazyMode
  def self.create_file(file_name, &block)
    file = File.new(file_name)
    file.instance_eval(&block)

    file
  end


  class Date
    PERIOD_TABLE = {"d" => 1, "w" => 7, "m" => 30}

    attr_accessor :year, :month, :day

    def self.to_date(days)
      the_day = days % 30 == 0 ? 30 : days % 30
      the_month = sprintf('%02d', (((days - the_day) / 30) + 1) % 12)
      the_year = sprintf('%04d', ((days - the_day) / 360 + 1))
      the_month = "12" if the_month == "00"

      Date.new("#{the_year}-#{the_month}-#{sprintf('%02d', the_day)}")
    end

    def initialize(date_string)
      @year, @month, @day, @repetition = date_string.split(/[-, +]/, 4)
      @year, @month, @day = [@year, @month, @day].map { |time| time.to_i }
      @date_string = date_string[0..9]
    end

    def to_s
      @date_string
    end

    def ===(date)
      difference = date.to_days - self.to_days
      return false if difference < 0

      period ? difference % period == 0 : difference == 0
    end

    def period
      return nil if @repetition == nil
      jump = @repetition.scan(/\d*/).join("").to_i
      type = @repetition.match(/[dwm]/).to_s

      jump * PERIOD_TABLE[type]
    end

    def to_days
      (year - 1) * 360 + (month - 1) * 30 + day
    end

    def within_week(date)
      occurs_on = [0,1,2,3,4,5,6].map { |day| date.to_days + day }
                                 .map{ |days| Date.to_date(days) }
                                 .delete_if { |date| !(self === date) }
      occurs_on
    end
  end


  class File
    attr_accessor :name, :notes

    def initialize(name)
      @name = name
      @notes = []
    end

    def note(header, *tags, &block)
       new_note = Note.new(self, header)
       new_note.tags = tags
       new_note.instance_eval(&block)
       @notes.push(new_note)

       new_note
    end

    def daily_agenda(date)
      agenda = File.new("daily_agenda_'#{date.to_s}'")
      agenda.notes = notes.map { |note| note.dup }
      agenda.notes.delete_if { |note| !(note.date === date) }
      agenda.notes.each { |note| note.date = date }

      agenda
    end


    def weekly_agenda(date)
      agenda = File.new("weekly_agenda_'#{date.to_s}'")
      agenda.notes = notes.map { |note| note.weekly_occurrence(date) }
      agenda.notes.flatten!

      agenda
    end

    def filter_notes(tag: nil, text: nil, status: nil)
      filter = notes.reject { |note| !note.tags.include?(tag) and tag  }
      filter.delete_if { |note| note.status != status and status }
      filter.delete_if do |note|
        (note.body =~ text) == nil and (note.header =~ text) == nil and text
      end

      filter
    end

    def where(tag: nil, text: nil, status: nil)
      filter = File.new("filter")
      filter.notes = filter_notes(tag: tag, text: text, status: status)

      filter
    end
  end

  class Note
    attr_accessor :tags, :file, :header, :date

    def initialize(file, header)
      @file = file
      @header = header
      @status = :topostpone
      @body = ""
    end

    def body(new_body = nil)
      @body = new_body if new_body

      @body
    end

    def file_name
      @file.name
    end

    def status(new_status = nil)
      @status = new_status if new_status

      @status
    end

    def note(header, *tags, &block)
       new_note = Note.new(@file, header)
       new_note.tags = tags
       new_note.instance_eval(&block)
       @file.notes.push(new_note)

       new_note
    end

    def weekly_occurrence(date)
      occurrence = self.date.within_week(date)
      note_array = occurrence.map { |date| self.schedule_on(date) }

      note_array
    end

    def schedule_on(date)
      new_note = self.dup
      new_note.date = date

      new_note
    end

    def scheduled(date)
      @date = Date.new(date)
    end
  end
end