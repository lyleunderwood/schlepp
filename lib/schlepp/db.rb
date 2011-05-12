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
      yield table if block_given?
      table
    end

    def process!
      @tables.each {|table| table.process! }
    end

    class Table
      attr_accessor :db_config, :model

      attr_accessor :name

      attr_accessor :models, :associations

      # hooks
      attr_accessor :before, :after, :reject, :record_fetch, :default_scope

      def initialize(name, config)
        @models = []
        @associations = {
          has_many: [], 
          belongs_to: [], 
          has_one: [], 
          has_many_through: []
        } #etc.
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
        # connect
        ActiveRecord::Base.establish_connection(db_config)

        # build some names
        model_name = ActiveSupport::Inflector.singularize(name.to_s)
        class_name = ActiveSupport::Inflector.camelize(model_name)

        # setting up the model
        klass = Class::new(ActiveRecord::Base)
        klass.set_table_name(name.to_s)
        # this is because it needs to have a class name
        UserModels.const_set(class_name.intern, klass)
        @model = UserModels.const_get(class_name)

        # apply the default_scope
        if @default_scope
          scoper = @default_scope
          reference = klass.class_eval(&@default_scope)
          klass.send(:default_scope, reference)
        end

        @model
      end

      def build_associations
        @associations[:has_many].each do |assoc|
          build_has_many(assoc, build_subtable(assoc))
        end
        @associations[:belongs_to].each do |assoc|
          build_belongs_to(assoc, build_subtable(assoc))
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

      def build_belongs_to(assoc, subtable)
        assoc[:block].call(subtable) if assoc[:block]
        subtable.init
        @model.belongs_to assoc[:id], :class_name => subtable.model.name
        #subtable.model.belongs_to name, :class_name => @model.name
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

      def each(&block)
        @each = block if block
        @each
      end

      def reject(&block)
        @reject = block if block
        @reject
      end

      def record_fetch(&block)
        @record_fetch = block if block
        @record_fetch
      end

      def default_scope(&block)
        @default_scope = block if block
        @default_scope
      end

      def has_many(subtable_name, &block)
        @associations[:has_many] << {
          id: subtable_name,
          block: block
        }
      end

      def belongs_to(subtable_name, &block)
        @associations[:belongs_to] << {
          id: subtable_name,
          block: block
        }
      end

      def records
        return @records if @records

        self.init
        @records = @record_fetch ? @record_fetch.call(@model) : @model.all
      end
      
      def process!
        result_records = records

        @before.call(self) if @before
        result_records.each {|record| @each.call(record) } if @each
        @after.call(self) if @after
      end
    end
  end

end