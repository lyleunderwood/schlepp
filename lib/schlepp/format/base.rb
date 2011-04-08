module Schlepp
  module Format
    class Base
      @cwd = ''

      class << self
        attr_accessor :cwd
      end

    end
  end
end
