require 'spec_helper'

describe Schlepp::Format::Base do
  before :each do
    @format = Schlepp::Format::Base.new {}
  end

  describe '#initialize' do
    it "should run our block" do
      f = Schlepp::Format::Base.new {|format| format.name = 'test' }
      f.name.should eql 'test'
    end

    it "should initialize our variables" do
      # exactly equals
      @format.required.should eql false
    end
  end

  describe '#name=' do
    it "should set the filename" do
      @format.name = 'test'
      @format.name.should eql 'test'
    end
  end

  describe '#read' do
    before(:each) do
      data = 'A long string here'
      io = double
      File.stub(:open).and_return(io)
      io.stub(:read).and_return(data)
    end

    it "should get the file data" do
      File.stub(:exists?) { true }
      @format.name = 'test.csv'

      @format.read.should eql 'A long string here'
    end

    it "should return nil when it can't find the file" do
      @format.read.should eql nil
    end

    it "should apply our encoding" do
      File.stub(:exists?) { true }
      @format.name = 'test.csv'
      @format.encoding = 'ISO-8859-1'
      @format.read.encoding.to_s.should eq('UTF-8')
    end
  end

  describe '#process!' do
    it "should call #read" do
      @format.should_receive(:read).and_return(nil)
      @format.process!
    end

    it "should call #retrieve_file_list" do
      @format.should_receive(:retrieve_file_list).and_return(['test'])
      @format.process!
    end

    it "should handle globbed file list" do
      @format.should_receive(:retrieve_file_list).and_return(['test1', 'test2'])
      @format.process!
    end

    it "should send the data to process_file" do
      @format.should_receive(:process_file).with(:test).and_return(nil)
      @format.stub(:read) { :test }
      @format.process!
    end

    it "should throw an error when a required file is not found" do
      @format.name = 'i do not exist'
      @format.required = true
      expect { @format.process! }.to raise_error
    end

    it "should not throw an error when an optional file is not found" do
      @format.name = 'i do not exist'
      expect { @format.process! }.to_not raise_error
    end

    it "should call our before" do
      processed = false
      success = double
      success.should_receive(:called)
      @format.stub(:process_file) { processed = true }
      @format.before { success.called unless processed }
      @format.stub(:read) { :true }
      @format.process!
    end

    it "should call our after" do
      processed = false
      success = double
      success.should_receive(:called)
      @format.stub(:process_file) { processed = true }
      @format.after { success.called if processed }
      @format.stub(:read) { :test }
      @format.process!
    end

  end

  describe '#retrieve_file_list' do
    it "globs dir if sent an array" do
      @format.name = ['test*']
      Dir.stub(:glob) {['test1', 'test2']}
      expect(@format.retrieve_file_list).to eq (['test1', 'test2'])
    end

    it "returns a single file as an array" do
      @format.name = 'test.txt'
      Schlepp::Format.cwd = ''

      expect(@format.retrieve_file_list).to eq(['test.txt'])
    end

    it "should use Format.cwd" do
      @format.name = 'test.csv'
      Schlepp::Format.cwd = 'data'

      expect(@format.retrieve_file_list).to eq(['data/test.csv'])
    end


  end

  describe '#encoding=' do
    it "should default to nil" do
      @format.encoding.should eql nil
    end

    it "should set our encoding" do
      @format.encoding = 'latin1'
      @format.encoding.should eql 'latin1'
    end
  end

end
