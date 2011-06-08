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

      def process_glob glob
        Dir.glob(File.join(Format.cwd, glob[:path])).each do |path|
          glob[:block].call(path)
        end
      end

    end
  end
end