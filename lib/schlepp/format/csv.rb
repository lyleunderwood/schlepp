require 'yaml'
require 'csv'

module Schlepp
  module Format
    # Uses CSV from the standard library to parse a CSV file. Handles mapping
    # CSV lines to field names and nesting data based on grouping columns.
    class Csv < Base

      # This is literally just a hash which can have children, accessible from
      # #children.
      class Item < Hash
        # child Item objects
        attr_accessor :children

        def initialize(*opts) # :nodoc:
          @children = []
          super
        end
      end

      attr_accessor :mapping # :nodoc:

      # should be an array of column numbers to group on, ex: [3, 6, 4] in
      # order of trunk to leaves
      attr_accessor :groups

      # should be an option (:all, :only, :except) followed by an array of column numbers to strip whitespace from
      # ex :only => [5, 2, 6, 3]
      attr_accessor :strip

      # array of columns to sort on before grouping
      attr_accessor :sort_on

      # options hash to be passed to CSV#parse
      attr_accessor :csv_options

      # true causes schlepp to skip the first row of headers
      attr_accessor :has_headers

      # takes a config block which gets run through +instance_eval+.
      def initialize(&block)
        @has_headers = false
        @mapping = nil
        @csv_options = nil
        @strip = {}
        super
      end

      # load our mapping YAML config into #mapping.
      def load_mapping(path)
        @mapping = YAML.load_file(path)
      end

      # specify a block to be run for every line in the file. if the block
      # returns true, reject the line. if false, keep the line.
      def reject_lines(&block)
        @reject_lines = block
      end

      # block to be run before each line. only parameter is the line before
      # mapping in array form.
      # TODO: figure out if i'm actually going to implement this
      def before_line(&block) # :nodoc:
        @before_line = block
      end

      # block to be run after each line. only parameter is the unmapped line.
      # TODO: figure out if i'm actually going to implement this
      def after_line(&block) # :nodoc:
        @after_line = block
      end

      # block to be run once for each top level mapped Item. only parameter is
      # the item.
      def map(&block)
        @map = block
      end

      # runs a string through the CSV parser.
      def parse(data) # :nodoc:
        if @csv_options.nil?
          CSV.parse(data).to_a
        else
          CSV.parse(data, @csv_options).to_a
        end
      end

      def strip_headers(data)
        data.slice!(0)
      end

      # runs through the parsed data and strips whitespace off the columns
      def strip_columns(data)
        data.each do |line|
          if strip.class == Array
            strip.each {|column| line[column].strip! if line[column]}
          elsif strip[:all]
            line.each {|value| value.strip! if value}
          elsif strip[:except]
            line.each_with_index do |value, index|
              if value
                value.strip! unless strip[:except].include?(index)
              end
            end
          end
        end
      end

      def apply_reject_lines(lines) # :nodoc:
        lines.reject(&@reject_lines)
      end

      # takes a line and our @mapping, returns a hash of the map keys to the
      # values from the line. +group+ specifies a specific group to map the
      # line to. +group+ = nil assumes that the root of @mapping is a valid
      # group.
      def apply_mapping(line, group = nil) # :nodoc:
        item = {}
        map_group = mapping
        map_group = map_group[group] unless group.nil?
        map_group.each_pair {|k,v| item[k] = line[v]}
        item
      end

      # find which group if any has changed from what's in +pieces+.
      def line_changed?(line, pieces) # :nodoc:
        groups.each_with_index do |key, i|
          current = pieces[i]
          return i if current.nil?
          return i if current[key].nil?
          return i unless line[key] == current[key]
        end
        nil
      end

      # return an array of Item objects for each group after +group+ given
      # +line+.
      def build_items(line, group = 0) # :nodoc:
        items = []
        group = -1 if group.nil?
        @mapping[group..-1].each do |item_map|
          item = Item.new
          items << item
          item_map.each_pair do |k,v|
            item[k] = line[v]
          end
        end
        items
      end

      # this is the most convoluted method in schlepp, haven't decided how i
      # want to break it up yet.
      #
      # data is an array of arrays representing the lines in the file.
      # #apply_groups takes the data, maps the fields, and nests it based on
      # groups. It returns an Array of top-level Item objects with nested
      # +children+.
      def apply_groups(data) # :nodoc:
        items, pieces, final = [], [], []
        data.each do |line|
          changed = line_changed?(line, pieces)
          new_items = build_items(line, changed)
          changed = groups.size if changed.nil?

          final << new_items.first if changed.zero?

          items = items.slice(0, changed)
          items = items + new_items
          pieces = pieces.slice(0, changed)
          new_items.count.times { pieces << line }

          items[changed..-1].each_with_index do |item,i|
            offset = changed + i - 1
            items[offset].children << item if offset > -1
          end
        end

        final
      end

      def sort_columns(data)
        data.sort_by! {|obj| obj.values_at(*sort_on)}
      end

      def apply_map(items) # :nodoc:
        items.each {|i| @map.call(i)}
      end

      # run #parse, #apply_reject_lines, #apply_grouping, #strip_columns, and #apply_map
      def process_file(data)
        data = parse(data)
        data = strip_headers(data) if @has_headers
        data = apply_reject_lines(data) if @reject_lines
        data = strip_columns(data) if @strip
        data = sort_columns(data) if @sort_on
        data = apply_groups(data) if @groups
        apply_map(data) if @map
      end

    end
  end
end
