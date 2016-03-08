module Schlepp
  # a Format is a class which handles reading, parsing, mapping, and grouping a
  # file type (like CSV).
  module Format
    @cwd = ''

    class << self
      attr_accessor :cwd
    end

    class Base

      # the filename/array (globbed later)
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
        return nil unless file && File.exists?(file)

        @encoding ||= 'utf-8'
        io = File.open(file)
        io = io.read.encode('utf-8', @encoding, :invalid => :replace, :undef => :replace, :universal_newline => true)
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

        if files == [] && required
          raise "Required file(s) not found: #{pathify_file(name)}"
        end

        @before.call if @before

        files.each do |file|
          process_file(read(file))
        end

        @after.call if @after
      end

      # Glob support to pull file list for processing.
      def retrieve_file_list
        Dir.glob(Array(name).map {|filename| pathify_file(filename)})
      end

      def pathify_file(file)
        if Format.cwd != ""
          File.join(Format.cwd, file)
        else
          file
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
