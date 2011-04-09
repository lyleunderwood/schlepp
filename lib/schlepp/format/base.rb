module Schlepp
  module Format
    @cwd = ''

    class << self
      attr_accessor :cwd
    end

    class Base

      attr_accessor :name, :required

      def initialize(&block)
        self.required = false

        block.call(self)
      end

      def read
        begin
          path = Format.cwd == '' ? name : File.join(Format.cwd, name)
          File.open(path)
        rescue
          nil
        end
      end

      def before(&block)
        @before = block
      end

      def after(&block)
        @after = block
      end

      def process!
        data = read
        if data.nil?
          raise "Required file not found: #{name}" if required
          return
        end

        @before.call(data) if @before

        result = process_file(data)

        @after.call(result) if @after
      end

      def process_file(data)
        raise "Implement process_file in Schlepp::Format::Base #{__FILE__}"
      end

    end
  end
end
