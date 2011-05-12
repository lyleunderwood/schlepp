require 'spec_helper'

describe Schlepp::Db do
  before(:each) { @db = Schlepp::Db.new }

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

    end

    describe '#build_model' do
      it "should build a valid AR model" do
        @table.init
        model = @table.build_model
        model.name.should_not eql 'Class'
        model.respond_to?(:arel_table).should be_true
      end
    end

    describe '#build_associations' do
      it "should build has_manys" do
        @table.build_model
        @table.associations[:has_many] << {
          id: :product_colors
        }

        @table.build_associations
        @table.model.first.product_colors.should be
      end
    end

    describe '#process' do
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
    end

    it "should work" do
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