require 'spec_helper'

describe Schlepp do
  it "should at least load up correctly" do
    defined?(Schlepp::Burden).should be_true
  end

  it "should autoload default formats" do
    defined?(Schlepp::Format::Csv).should be_true
  end

  it "should actually work" do
    items = []
    b = Schlepp::Burden.new :test do
      cd File.join('spec', 'fixtures', 'data')
      glob 'season_*' do |dir|
        file 'Csv' do |csv|
          csv.name = File.join(dir, 'products.csv')
          csv.required = true
          csv.groups = [0, 4]
          csv.load_mapping File.join('spec', 'fixtures', 'products.yml')
          csv.reject_lines do |line|
            line.first.nil? || line.first =~ /\s/
          end
  
          csv.map do |item|
            items << item
          end
        end
      end
    end

    b.process!

    items.size.should eql 4

    b.cd ''
  end

  it "shouldn't break on multiple sources" do
    items = []

    b = Schlepp::Burden.new :test do

      cd File.join('spec', 'fixtures', 'data')
      glob 'season_*' do |dir|
        file 'Csv' do |csv|
          csv.name = File.join(dir, 'products.csv')
          csv.required = true
          csv.groups = [0, 4]
          csv.load_mapping File.join('spec', 'fixtures', 'products.yml')
          csv.reject_lines do |line|
            line.first.nil? || line.first =~ /\s/
          end
  
          csv.map do |item|
            #items << item
          end
        end
      end

      db do |test_db|
        test_db.config = {
          adapter: 'sqlite3',
          database: File.join('spec', 'fixtures', 'test.db'),
          pool: 5,
          timeout: 5000
        }

        test_db.table :products do |products|
          products.has_many :product_colors do |product_colors|
            product_colors.has_many :product_sizes
          end

          products.each do |product|
            items << product
          end
        end
      end

    end

    b.process!

    items.count.should eql 2

    b.cd ''
  end


end
