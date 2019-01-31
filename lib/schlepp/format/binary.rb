module Schlepp
  module Format
    # the point of Binary is to just be able to manipulate arbitrary files on
    # the filesystem and whatnot. it's sort of just a rough sketch for now.
    class Binary < Base
      attr_accessor :globs

      def initialize
        @globs = []

        super
      end

      def glob(path, &block)
        @globs << {path: path, block: block}
      end

      def process!
        @before.call(self) if @before

        globs.each {|glob| process_glob(glob)}
        @after.call(self) if @after
      end

      def copy_s3_to_tmp(path)
        tmp_path = File.join('tmp/schlepp/binary', path)
        FileUtils.mkdir_p(File.dirname(tmp_path))

        File.open(tmp_path, 'wb') do |file|
          data_bucket.objects[path].read { |chunk| file.write(chunk) }
          tmp_path
        end
      end

      def process_glob glob
        path = pathify_file(glob[:path])
        paths = data_bucket ? object_glob([ path ]) : Dir.glob(path)

        paths.each do |path|
          path = copy_s3_to_tmp(path) if data_bucket && !ENV['NOIMAGES']

          glob[:block].call(path)

          File.delete(path) if data_bucket && !ENV['NOIMAGES']
        end
      end
    end
  end
end
