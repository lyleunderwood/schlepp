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

      def read_disk(file)
        file && File.exists?(file) ? File.open(file).read : nil
      end

      def read_s3(file)
        s3 = AWS::S3.new(region: ENV['AWS_DATA_BUCKET_REGION'])
        bucket = s3.buckets[ENV['AWS_DATA_BUCKET']]

        file && bucket.exists? && bucket.objects[file].exists? ? bucket.objects[file].read : nil
      end

      # read the file. uses +cwd+ set by Schlepp::Burden#cd. Returns nil if no
      # file is found.
      def read(file = name)
        @encoding ||= 'utf-8'
        data = ENV['AWS_DATA_BUCKET'] ? read_s3(file) : read_disk(file)
        return nil if data.nil?

        data.encode('utf-8', @encoding, :invalid => :replace, :undef => :replace, :universal_newline => true)
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

      def glob_to_regexp(glob)
        escaped = Regexp.escape(glob)
          .sub('\*\*', '.*')
          .sub('\*', '(?:(?!\\/).)*')

        Regexp.new("#{escaped}$")
      end

      def list_objects(bucket, prefix, regexp)
        bucket.objects.with_prefix(prefix)
          .select { |o| regexp.match(o.key) }
          .map(&:key)
      end

      def object_glob(globs)
        s3 = AWS::S3.new(region: ENV['AWS_DATA_BUCKET_REGION'])
        bucket = s3.buckets[ENV['AWS_DATA_BUCKET']]

        globs.flat_map { |g| list_objects(bucket, g.split('*').first, glob_to_regexp(g)) }
      end

      # Glob support for objects stored in s3
      def retrieve_object_list(paths)
        object_list = paths.reject { |n| n.include?('*') }
        globs = paths.select { |n| n.include?('*') }

        object_list.concat(object_glob(globs))
      end

      # Glob support to pull file list for processing.
      def retrieve_file_list
        paths = Array(name).map { |filename| pathify_file(filename) }
        ENV['AWS_DATA_BUCKET'] ? retrieve_object_list(paths) : Dir.glob(paths)
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
