module Schlepp
  module Format
    # the point of Binary is to just be able to manipulate arbitrary files on
    # the filesystem and whatnot. it's sort of just a rough sketch for now.
    class Binary < Base
      attr_accessor :globs

      def initialize
        super

        @globs = []
      end

      def glob(path, &block)
        @globs << {path: path, block: block}
      end

      def process!
        @before.call(data) if @before

        globs.each {|glob| process_glob(glob)}
        @after.call(result) if @after
      end

      def process_glob glob
        Dir.glob(File.join(Format.cwd, glob[:path])).each do |path|
          instance_exec(path, &glob[:block])
        end
      end

    end
  end
end