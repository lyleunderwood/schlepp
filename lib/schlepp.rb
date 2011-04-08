require 'schlepp/burden'

module Schlepp
  @formats = ['Csv']

  class << self
    attr_accessor :formats
  end

  autoload :Format, File.join('schlepp', 'format', 'base')

  module Format
    Schlepp.formats.each do |format|
      autoload format.to_sym, File.join('schlepp', 'format', format.downcase)
    end
  end
end
