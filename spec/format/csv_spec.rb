require 'spec_helper'

describe Schlepp::Format::Csv do
  before :each do
    @csv = Schlepp::Format::Csv.new {}
  end

  it "should have a @groups attribute" do
    @csv.groups = :test
    @csv.groups.should eql :test
  end

  it "should have a @mapping attribute" do
    @csv.mapping = :test
    @csv.mapping.should eql :test
  end

  describe '#initialize' do
    it "should call super" do
      f = Schlepp::Format::Csv.new {}
      f.required.should eql false
    end
  end

  describe '#load_mapping' do
    it "should load our yaml file" do
      YAML.should_receive(:load_file).with('test').and_return(:test)
      @csv.load_mapping('test')
      @csv.mapping.should eql :test
    end
  end

  describe '#reject_lines' do
    it "should set our @reject_lines block" do
      reject = proc {|line| false}
      @csv.reject_lines(&reject)
      @csv.instance_variable_get(:@reject_lines).should eql reject
    end
  end

  describe '#before_line' do
    it "should set our @before_line block" do
      before_proc = proc {|line| line}
      @csv.before_line(&before_proc)
      @csv.instance_variable_get(:@before_line).should eql before_proc
    end
  end

  describe '#after_line' do
    it "should set our @after_line block" do 
      after_proc = proc {|line| line}
      @csv.after_line(&after_proc)
      @csv.instance_variable_get(:@after_line).should eql after_proc
    end
  end

  describe '#map' do
    it "should set our @map" do
      mapper = proc {|line| line}
      @csv.map(&mapper)
      @csv.instance_variable_get(:@map).should eql mapper
    end
  end

  describe '#parse' do
    it "should parse the data using CSV" do
      CSV.should_receive(:parse).with(:data).and_return(:result)
      @csv.parse(:data).should eql :result
    end

    it "should use @csv_options if defined" do
      path = 'spec/fixtures/data/season_1/products.csv'
      data = File.open(path).read.gsub(",", "\t")
      options = {:col_sep => "\t"}
      CSV.should_receive(:parse).with(data, options)
      @csv.csv_options = options
      @csv.parse(data)
    end
  end

  describe '#apply_reject_lines' do
    it "should call #reject on our data " do
      reject = proc {|line| false}
      data = mock
      data.should_receive(:reject).with(&reject).and_return(:test)
      @csv.reject_lines(&reject)
      @csv.apply_reject_lines(data)
    end

    it "should correctly reject lines" do
      @csv.reject_lines {|line| line.nil?}
      data = [nil, 2, nil, 1]
      @csv.apply_reject_lines(data).should eql [2, 1]
    end
  end

  describe '#apply_mapping' do
    it "should map arrays to hashes according to @mapping" do
      @csv.mapping = {:name => 1, :number => 0}
      result = @csv.apply_mapping(['0001', 'Item 1'])
      result.should eql(:name => 'Item 1', :number => '0001')
    end

    it "should be able to map a specific group" do
      @csv.mapping = [{}, {:name => 1, :number => 0}]
      result = @csv.apply_mapping(['0001', 'Item 1'], 1)
      result.should eql(:name => 'Item 1', :number => '0001')
    end
  end

  describe '#line_changed?' do
    it "should detect based on groups if a group changed" do
      @csv.groups = [1]
      pieces = [[:a, :b, :c], [:a, :b, :d]]
      @csv.line_changed?([:a, :e, :a], pieces).should eql 0
    end

    it "should return nil if no grouping has changed" do
      @csv.groups = [1]
      pieces = [[:a, :b, :c], [:a, :b, :d]]
      @csv.line_changed?([:a, :b, :a], pieces).should eql nil
    end

    it "should return a deeper group if the change is nested" do
      @csv.groups = [0, 2, 4]
      pieces = [
        [:a, :s, :c, :z, :e],
        [:a, :t, :g, :y, :h],
        [:a, :u, :g, :x, :j],
        [:a, :v, :g, :w, :k]
      ]

      line = [:a, :f, :i, :e]
      @csv.line_changed?(line, pieces).should eql 1
    end
  end

  describe '#build_items' do
    it "should build items based on mapping" do
      line = ['01', 'product 1', 'red', 'small']
      @csv.mapping = [
        {:number => 0, :name => 1}, 
        {:color_name => 2}, 
        {:size_name => 3}
      ]
      result = @csv.build_items(line)
      result.should be_a Array
      result.count.should eql 3
      result.first[:name].should eql 'product 1'
      result.first[:color_name].should eql nil
      result[1][:color_name].should eql 'red'
      result[2][:size_name].should eql 'small'
    end

    it "should be able to conditionally build by group" do
      line = ['01', 'product 1', 'red', 'small']
      @csv.mapping = [
        {:number => 0, :name => 1}, 
        {:color_name => 2}, 
        {:size_name => 3}
      ]
      result = @csv.build_items(line, 1)
      result.count.should eql 2
      result.first[:color_name].should eql 'red'
    end


  end

  describe '#apply_groups' do
    it "should normalize the data according to @groups and @mapping" do
      data = [
        ['001', 'product 1', 'red', 'color 1', 'small'],
        ['001', 'product 1', 'red', 'color 1', 'medium'],
        ['001', 'product 1', 'red', 'color 1', 'large'],
        ['001', 'product 1', 'green', 'color 2', 'small'],
        ['001', 'product 1', 'green', 'color 2', 'medium'],
        ['001', 'product 1', 'green', 'color 2', 'large'],
        ['002', 'product 2', 'red', 'color 1', 'small'],
        ['002', 'product 2', 'red', 'color 1', 'medium'],
        ['002', 'product 2', 'red', 'color 1', 'large'],
        ['002', 'product 2', 'green', 'color 2', 'small'],
        ['002', 'product 2', 'green', 'color 2', 'medium'],
        ['002', 'product 2', 'green', 'color 2', 'large'],
      ]

      @csv.groups = [0, 3]
      @csv.mapping = [
        {:number => 0, :name => 1},
        {:name   => 2, :code => 3},
        {:name   => 4}
      ]
      result = @csv.apply_groups(data)
      result.count.should eql 2
      result.first[:name].should eql 'product 1'
      result.last.children.count.should eql 2
      result.first.children.last[:code].should eql 'color 2'
      result.last.children.last.children.count.should eql 3
      result.first.children.last.children.first[:name].should eql 'small'
    end
  end

  describe '#process_file' do
    before :each do
      @csv = Schlepp::Format::Csv.new {}
      @csv.stub(:parse) {|arg| arg}
      @csv.stub(:apply_reject_lines) {|arg| arg}
      @csv.stub(:apply_groups) {|arg| arg}
      @csv.stub(:apply_map) {|arg| arg}
    end

    it "should parse the data" do
      @csv.should_receive(:parse).with(:test).and_return(nil)
      @csv.process_file(:test)
    end

    it "should call #apply_reject_lines if set" do
      @csv.should_receive(:apply_reject_lines).with(:test).and_return(:test)
      @csv.reject_lines {}
      @csv.process_file(:test)
    end

    it "should call #apply_groups" do
      @csv.groups = [1]
      @csv.should_receive(:apply_groups).with(:test)
      @csv.process_file(:test)
    end

    it "should call #apply_map if set" do
      @csv.map {}
      @csv.should_receive(:apply_map)
      @csv.process_file(:test)
    end
  end

end
