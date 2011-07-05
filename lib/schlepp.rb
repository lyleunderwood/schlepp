# schlepp makes it easy to normalize data from various sources like CSV. Need 
# to go from flattened CSV to relational tables? Schlepp provides a 
# simple DSL for mapping, grouping and importing data from and to various 
# formats.
#
# At least that's the plan. Currently handles access to CSV files.
require 'schlepp/burden'

require 'schlepp/railtie' if defined?(Rails)

module Schlepp
  @formats = ['Csv', 'Binary', 'Xml']

  class << self
    attr_accessor :formats
  end

  autoload :Format, File.join('schlepp', 'format', 'base')
  autoload :Db,     File.join('schlepp', 'db')

  module Format
    Schlepp.formats.each do |format|
      autoload format.to_sym, File.join('schlepp', 'format', format.downcase)
    end
  end
end
