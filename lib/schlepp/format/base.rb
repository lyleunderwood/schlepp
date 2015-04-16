module Schlepp
  # a Format is a class which handles reading, parsing, mapping, and grouping a
  # file type (like CSV).
  module Format
    @cwd = ''

    class << self
      attr_accessor :cwd
    end

    class Base

      # the filename
      # TODO: support filename glob like format.name = :glob => 'data*.csv'
      attr_accessor :name

      # defaults to false
      attr_accessor :required

      # encoding of original file; we are going to convert this to utf-8
      attr_accessor :encoding

      # takes a config block which receives self as parameter
      def initialize(&block)
        self.name = nil
        self.required = false

        block.call(self)
      end

      # read the file. uses +cwd+ set by Schlepp::Burden#cd. Returns nil if no
      # file is found.
      def read(file = name)
        return nil unless file
        @encoding ||= 'utf-8'
        path = Format.cwd == '' ? file : File.join(Format.cwd, file)
        return nil unless File.exists? path
        io = File.open(path)
        io = io.read.encode('utf-8', @encoding, :invalid => :replace, :undef => :replace, :universal_newline => true) if @encoding
        io
      end

      # block to run before file is processed
      def before(&block)
        @before = block
      end

      # block to run after file is processed
      def after(&block)
        @after = block
      end

      # throws an error if a required file is not found. runs our before,
      # then process_file, then our after.
      def process!
       files = retrieve_file_list
        @before.call if @before
        files.each do |file|
          data = read(file)
          if data.nil?
            raise "Required file not found: #{File.join(Format.cwd, name)}" if required
            return
          end

          result = process_file(data)
        end
        @after.call if @after
      end

      # Glob support to pull file list for processing.
      def retrieve_file_list
        if name.is_a?(Hash)
          return nil unless name[:glob]
          Dir.glob(name[:glob])
        else
          [name]
        end
      end

      # should be implemented by subclasses. handles parsing, mapping, and
      # grouping. returns the grouped data.
      def process_file(data)
        raise "Implement process_file in Schlepp::Format::Base #{__FILE__}"
      end

    end
  end
end
