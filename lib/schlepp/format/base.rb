require 'iconv'

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
      def read(name)
        return nil unless name
        path = Format.cwd == '' ? name : File.join(Format.cwd, name)
        return nil unless File.exists? path
        io = File.open(path)
        io = Iconv.conv('utf-8', @encoding, io.read) if @encoding
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
        datas = Array(name).map do |name|
          data = read(name)
          if data.nil?
            raise "Required file not found: #{File.join(Format.cwd, name)}" if required
            return
          end

          data
        end

        @before.call(*datas) if @before
        results = datas.map {|data| process_file(data)}
        @after.call(*results) if @after
        end

        # should be implemented by subclasses. handles parsing, mapping, and
        # grouping. returns the grouped data.
        def process_file(data)
          raise "Implement process_file in Schlepp::Format::Base #{__FILE__}"
        end

    end
  end
end
