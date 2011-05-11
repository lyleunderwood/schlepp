require 'active_record'
require 'active_support/inflector/inflections'

module Schlepp
  class Db
    attr_reader :tables

    attr_accessor :config

    def initialize(&block)
      @tables = []

      block.call(self) if block
    end

    def table(name)
      table = Table.new(name, config)
      @tables << table
      table
    end

    class Table
      attr_accessor :db_config, :model

      attr_accessor :name

      attr_accessor :models, :associations

      # hooks
      attr_accessor :before, :after, :reject, :record_fetch

      def initialize(name, config)
        @models = []
        @associations = {has_many: [], has_one: [], has_many_through: []} #etc.
        @name = name

        @db_config = config
      end

      module UserModels; end;

      def init
        raise 'A database config must be set for Schlepp::Db::Table' unless db_config
        build_model
        build_associations
      end

      def build_model
        ActiveRecord::Base.establish_connection(db_config)
        table_model = Class::new(ActiveRecord::Base)
        model_name = ActiveSupport::Inflector.singularize(name.to_s)
        table_model.set_table_name(model_name)
        class_name = ActiveSupport::Inflector.camelize(model_name)
        klass = Class::new(ActiveRecord::Base)
        @model = self.class::UserModels.const_set(class_name.intern, klass)
      end

      def build_associations
        @associations[:has_many].each do |assoc|
          build_has_many(assoc, build_subtable(assoc))
        end
      end

      def build_subtable(assoc)
        subtable = self.class.new(assoc[:id], db_config)
        @models << subtable
        subtable
      end

      def build_has_many(assoc, subtable)
        assoc[:block].call(subtable) if assoc[:block]
        subtable.init
        @model.has_many assoc[:id], :class_name => subtable.model.name
        subtable.model.belongs_to name, :class_name => @model.name
      end

      def build_has_one(assoc, subtable)
        assoc[:block].call(subtable) if assoc[:block]
        subtable.init
        @model.has_one assoc[:id], :class_name => subtable.model.name
        subtable.model.belongs_to name, :class_name => @model.name
      end

      def before(&block)
        @before = block if block
        @before
      end

      def after(&block)
        @after = block if block
        @after
      end

      def reject(&block)
        @reject = block if block
        @reject
      end

      def record_fetch(&block)
        @record_fetch = block if block
        @record_fetch
      end

      def has_many(subtable_name, &block)
        @associations[:has_many] << {
          id: subtable_name,
          block: block
        }
      end

      def records
        return @records if @records

        self.init
        @records = @record_fetch ? @record_fetch.call(@model) : @model.all
      end

      def each
        result_records = records

        @before.call(self) if @before

        result_records.each {|record| yield record }

        @after.call(self) if @after
      end
    end
  end

end