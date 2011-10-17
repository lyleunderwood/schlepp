require 'spec_helper'

describe Schlepp::Db do
  before(:each) do
    @db = Schlepp::Db.new
    Schlepp::Db::Table.send :remove_const, :UserModels
    Schlepp::Db::Table.const_set :UserModels, Module.new
  end

  describe '#initialize' do
    it "should pass self to the config block" do
      executed = false
      Schlepp::Db.new do |config|
        executed = true
        config.should be_a Schlepp::Db
      end

      executed.should be_true
    end
  end

  describe '#table' do
    it "should add a new table" do
      @db.table :products
      @db.tables.count.should eql 1
    end
  end

  describe '#config=' do
    it "should be configurable" do
      conf = {something: :okay}
      @db.config = conf
      @db.config.should eql conf
    end
  end

  describe '#process!' do
    it "should process all the tables" do
      table = double
      table.should_receive(:process!)
      @db.tables << table
      @db.process!
    end
  end

  describe Schlepp::Db::Table do
    before(:each) do
      @table = @db.table :products
      @table.db_config = {
        adapter: 'sqlite3',
        database: File.join('spec', 'fixtures', 'test.db'),
        pool: 5,
        timeout: 5000
      }
    end

    describe '#initialize' do
      it "should build an AR model" do
        #@db.table
      end
    end

    describe '#init' do
      it "should create the connection" do
        @table.init
        ActiveRecord::Base.connection.should be
        @table.model.superclass.should eql ActiveRecord::Base
      end
    end

    describe '#primary_key' do
      it "should set @primary_key" do
        @table.primary_key = 'some_key_column'
        @table.instance_variable_get(:@primary_key).should eql 'some_key_column'
      end
    end

    describe '#model_class_name' do
      it "should guess the proper name of the @model to be" do
        @table.model_class_name.should eql 'Schlepp::Db::Table::UserModels::Product'
      end
    end

    describe '#after' do
      it "should set @after" do
        @table.after do; end;
        @table.after.should eql(proc {})
      end
    end

    describe '#before' do
      it "should set @before" do
        @table.before do; end;
        @table.before.should eql(proc {})
      end
    end

    describe '#each' do
      it "should set @each" do
        @table.each do; end;
        @table.each.should eql(proc {})
      end
    end

    describe '#reject' do
      it "should set @reject" do
        @table.reject do; end;
        @table.reject.should eql(proc {})
      end
    end

    describe '#record_fetch' do
      it "should set @record_fetch" do
        @table.record_fetch do; end;
        @table.record_fetch.should eql(proc {})
      end
    end

    describe '#default_scope' do
      it "should set @default_scope" do
        @table.default_scope do
          limit(1)
        end
      end
    end

    describe '#records' do
      before(:each) do
        @table.stub(:init)
        @table.model = double
        @result_records = [:record1, :record2]
        @table.model.stub(:all) { @result_records }
      end

      it "should init the table" do
        @table.should_receive(:init)
        @table.records
      end

      it "should grab the records" do
        @table.records.should eql @result_records
      end

      it "should use @record_fetch if given" do
        custom_result = [:custom_record]
        @table.record_fetch do |model|
          custom_result
        end

        @table.records.should eql custom_result
      end
    end

    describe '#has_many' do
      it "should add a has_many association" do
        @table.has_many :product_colors
        @table.associations[:has_many].count.should eql 1
      end

      it "should take arbitrary options" do
        opts = {is_true: true}
        @table.has_many :product_colors, opts
        @table.associations[:has_many].first[:options].should eql opts
      end
    end

    describe '#has_one' do
      it "should add a has_one association" do
        @table.has_one :anything
        @table.associations[:has_one].count.should eql 1
      end

      it "should take arbitrary options" do
        opts = {is_true: true}
        @table.has_one :product_colors, opts
        @table.associations[:has_one].first[:options].should eql opts
      end
    end

    describe '#belongs_to' do
      it "should add a belongs_to association" do
        @table.belongs_to :something
        @table.associations[:belongs_to].count.should eql 1
      end

      it "should take arbitrary options" do
        opts = {is_true: true}
        @table.belongs_to :product_colors, opts
        @table.associations[:belongs_to].first[:options].should eql opts
      end
    end

    describe '#build_model' do
      it "should build a valid AR model" do
        @table.init
        model = @table.build_model
        model.name.should_not eql 'Class'
        model.respond_to?(:arel_table).should be_true
      end

      it "should set the primary key" do
        @table.primary_key = 'some_key_column'
        @table.init
        model = @table.build_model
        model.primary_key.should eql 'some_key_column'
      end
    end

    describe '#build_associations' do
      it "should build has_manys" do
        @table.build_model
        assoc = {id: :product_colors}
        @table.associations[:has_many] << assoc

        @table.should_receive(:build_has_many)
        @table.build_associations
      end

      it "should build belongs_tos" do
        @table.build_model
        assoc = {id: :product_colors}
        @table.associations[:belongs_to] << assoc

        @table.should_receive(:build_belongs_to)
        @table.build_associations
      end

      it "should build has_ones" do
        @table.build_model
        assoc = {id: :product_colors}
        @table.associations[:has_one] << assoc

        @table.should_receive(:build_has_one)
        @table.build_associations
      end
    end

    context 'relations' do
      before(:each) do
        @table.model = double
        @table.model.stub(:belongs_to)
        @table.model.stub(:has_many)
        @table.model.stub(:has_one)
        @table.model.stub(:name) {:source}
        @subtable = double
        @subtable.stub(:init)
        sub_model = double
        @subtable.stub(:model) {sub_model}
        sub_model.stub(:belongs_to)
        sub_model.stub(:name) {:target}
      end

      describe '#build_has_many' do
        it "should setup a has_many on the model" do
          opts = {class_name: :target}
          @table.model.should_receive(:has_many).with(:colors, opts)
          @table.build_has_many({id: :colors}, @subtable)
        end

        it "should init the submodel" do
          @subtable.should_receive(:init)
          @table.build_has_many({id: :colors}, @subtable)
        end

        it "should pass the subtable to the association config block" do
          executed = false
          assoc = {
            id: :colors,
            block: proc do |subtable|
              subtable.should eql @subtable
              executed = true
            end
          }

          @table.build_has_many(assoc, @subtable)
          executed.should be_true
        end

        it "should setup a belongs_to on the target" do
          opts = {class_name: :source}
          @subtable.model.should_receive(:belongs_to).with(:product, opts)
          @table.build_has_many({id: :colors}, @subtable)
        end

        it "should pass options to the relation" do
          assoc_options = {is_true: true, class_name: :target}
          assoc = {
            id: :colors,
            options: {is_true: true}
          }
          @table.model.should_receive(:has_many).with(:colors, assoc_options)
          @table.build_has_many(assoc, @subtable)
        end
      end

      describe '#build_has_one' do
        it "should setup a has_one on the model" do
          opts = {class_name: :target}
          @table.model.should_receive(:has_one).with(:color, opts)
          @table.build_has_one({id: :colors}, @subtable)
        end

        it "should init the submodel" do
          @subtable.should_receive(:init)
          @table.build_has_one({id: :colors}, @subtable)
        end

        it "should pass the subtable to the association config block" do
          executed = false
          assoc = {
            id: :colors,
            block: proc do |subtable|
              subtable.should eql @subtable
              executed = true
            end
          }

          @table.build_has_one(assoc, @subtable)
          executed.should be_true
        end

        it "should setup a belongs_to on the target" do
          opts = {class_name: :source}
          @subtable.model.should_receive(:belongs_to).with(:product, opts)
          @table.build_has_one({id: :colors}, @subtable)
        end

        it "should pass options to the relation" do
          assoc_options = {is_true: true, class_name: :target}
          assoc = {
            id: :colors,
            options: {is_true: true}
          }
          @table.model.should_receive(:has_one).with(:color, assoc_options)
          @table.build_has_one(assoc, @subtable)
        end
      end

      describe '#build_belongs_to' do
        it "should setup a belongs_to on the model" do
          opts = {class_name: :target}
          @table.model.should_receive(:belongs_to).with(:color, opts)
          @table.build_belongs_to({id: :colors}, @subtable)
        end

        it "should init the submodel" do
          @subtable.should_receive(:init)
          @table.build_belongs_to({id: :colors}, @subtable)
        end

        it "should pass the subtable to the association config block" do
          executed = false
          assoc = {
            id: :colors,
            block: proc do |subtable|
              subtable.should eql @subtable
              executed = true
            end
          }

          @table.build_belongs_to(assoc, @subtable)
          executed.should be_true
        end

        it "should pass options to the relation" do
          assoc_options = {is_true: true, class_name: :target}
          assoc = {
            id: :colors,
            options: {is_true: true}
          }
          @table.model.should_receive(:belongs_to).with(:color, assoc_options)
          @table.build_belongs_to(assoc, @subtable)
        end
      end
    end

    describe '#process!' do
      it "should call @each with rows" do
        executed = 0
        @table.each do |row|
          executed = executed.next
          row.should be_a @table.model
        end

        @table.process!

        executed.should eql 2
      end

      it "should call our before" do
        executed = false
        @table.before { executed = true }
        @table.process!
        executed.should eql true
      end

      it "should call our after" do
        executed = false
        @table.after { executed = true }
        @table.process!
        executed.should eql true
      end

      it "should not ask for records without an @each" do
        @table.should_not_receive :records
        @table.process!
      end
    end

    it "should work" do
      @table.default_scope do
        limit(2)
      end

      @table.has_many :product_colors do |product_colors|
        product_colors.has_many :product_sizes
      end

      rows = []
      @table.each do |row|
        rows << row
      end

      @table.process!

      rows.count.should eql 2
      rows.first.product_colors.count.should eql 2
      rows.first.product_colors.first.product_sizes.count.should eql 3
    end
  end

end