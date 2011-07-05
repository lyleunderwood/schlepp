require 'rexml/document'

module Schlepp
  module Format
    class Xml < Base

      def parse(resource)
        REXML::Document.new(resource)
      end

      def use(&block)
        @use = block
      end

      def apply_use(data)
        @use.call(data)
      end

      def process_file(data)
        data = parse(data)
        apply_use(data)
      end

    end
  end
end
