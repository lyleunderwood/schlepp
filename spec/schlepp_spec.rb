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

end
