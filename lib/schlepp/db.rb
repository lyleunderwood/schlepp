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

      attr_accessor :primary_key

      attr_accessor :mapping

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

      def model_class_name
        prefix = UserModels.name + '::'
        single_name = ActiveSupport::Inflector.singularize(name.to_s)
        prefix + ActiveSupport::Inflector.camelize(single_name)
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

        unless UserModels.const_defined?(class_name, false)
          # setting up the model
          klass = Class::new(ActiveRecord::Base)
          klass.table_name = name.to_s
          klass.inheritance_column = :ruby_type
          klass.primary_key = primary_key || 'id'
          build_mapping(klass) if @mapping
          # this is because it needs to have a class name
          UserModels.const_set(class_name.intern, klass)
        end

        @model = UserModels.const_get(class_name)

        # apply the default_scope
        if @default_scope
          scoper = @default_scope
          reference = @model.class_eval(&@default_scope)
          @model.send(:default_scope, reference)
        end

        @model
      end

      def build_mapping(model)
        @mapping.each_pair do |source, target|
          model.alias_attribute(target, source)
        end
      end

      def build_associations
        @associations[:has_many].each do |assoc|
          build_has_many(assoc, build_subtable(assoc))
        end
        @associations[:has_one].each do |assoc|
          build_has_one(assoc, build_subtable(assoc))
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

        opts = {class_name: subtable.model.name}
        opts.merge!(assoc[:options]) if assoc[:options]

        single_name = ActiveSupport::Inflector.singularize(name).to_sym

        @model.has_many assoc[:id], opts
        subtable.model.belongs_to single_name, :class_name => @model.name
      end

      def build_has_one(assoc, subtable)
        assoc[:block].call(subtable) if assoc[:block]
        subtable.init

        opts = {class_name: subtable.model.name}
        opts.merge!(assoc[:options]) if assoc[:options]

        single_id = ActiveSupport::Inflector.singularize(assoc[:id]).to_sym
        single_name = ActiveSupport::Inflector.singularize(name).to_sym

        @model.has_one single_id, opts
        subtable.model.belongs_to single_name, :class_name => @model.name
      end

      def build_belongs_to(assoc, subtable)
        assoc[:block].call(subtable) if assoc[:block]
        subtable.init

        opts = {class_name: subtable.model.name}
        opts.merge!(assoc[:options]) if assoc[:options]

        single_id = ActiveSupport::Inflector.singularize(assoc[:id]).to_sym
        @model.belongs_to single_id, opts
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

      def has_many(subtable_name, opts = nil, &block)
        @associations[:has_many] << {
          id: subtable_name,
          block: block,
          options: opts
        }
      end

      def has_one(subtable_name, opts = nil, &block)
        @associations[:has_one] << {
          id: subtable_name,
          block: block,
          options: opts
        }
      end

      def belongs_to(subtable_name, opts = nil, &block)
        @associations[:belongs_to] << {
          id: subtable_name,
          block: block,
          options: opts
        }
      end

      def records
        return @records if @records

        self.init

        # Order by id as lowest priority so batching works
        @records = @record_fetch ? @record_fetch.call(@model).order('id') : @model.order('id')
      end

      def process!
        @before.call(self) if @before
        total_records = records.count
        batch = 10000
        (0..total_records).step(batch) do |start|
          records.offset(start).limit(batch).each {|record| @each.call(record) } if @each
        end
        @after.call(self) if @after
      end
    end
  end

end