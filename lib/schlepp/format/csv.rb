require 'yaml'
require 'csv'

module Schlepp
  module Format
    class Csv < Base

      class Item < Hash
        attr_accessor :children

        def initialize(*opts)
          @children = []
          super
        end
      end

      attr_accessor :mapping, :groups

      def initialize(&block)

        super
      end

      def load_mapping(path)
        @mapping = YAML.load_file(path)
      end

      def reject_lines(&block)
        @reject_lines = block
      end

      def before_line(&block)
        @before_line = block
      end

      def after_line(&block)
        @after_line = block
      end

      def map(&block)
        @map = block
      end

      def parse(data)
        CSV.parse(data)
      end

      def apply_reject_lines(lines)
        lines.reject(&@reject_lines)
      end

      def apply_mapping(line, group = nil)
        item = {}
        map_group = mapping
        map_group = map_group[group] unless group.nil?
        map_group.each_pair {|k,v| item[k] = line[v]}
        item
      end

      def line_changed?(line, pieces)
        groups.each_with_index do |key, i|
          current = pieces[i]
          return i if current.nil?
          return i if current[key].nil?
          return i unless line[key] == current[key]
        end
        nil
      end

      def build_items(line, group = 0)
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

      def apply_groups(data)
        items, pieces, final = [], [], []
        data.each do |line|
          changed = line_changed?(line, pieces)
          new_items = build_items(line, changed)
          changed = groups.size if changed.nil?

          if changed and changed.zero?
            final << new_items.first
            items = new_items
            pieces = []
            new_items.count.times { pieces << line }
          elsif
            items = items.slice(0, changed)
            items = items + new_items
            pieces = pieces.slice(0, changed)
            new_items.count.times { pieces << line }
          end

          items[changed..-1].each_with_index do |item,i|
            offset = changed + i - 1
            items[offset].children << item if offset > -1
          end
        end
        
        final
      end

      def process_file(data)
        data = parse(data)
        data = apply_reject_lines(data) if @reject_lines

      end

    end
  end
end
