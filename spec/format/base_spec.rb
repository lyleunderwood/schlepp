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
    it "should get the file data" do
      File.stub(:exists?) { true }
      @format.name = 'test.csv'
      File.should_receive(:open).with('test.csv').and_return(:true)
      @format.read.should eql :true
    end

    it "should use Format.cwd" do
      File.stub(:exists?) { true }
      @format.name = 'test'
      Schlepp::Format.cwd = 'data/'
      File.should_receive(:open).with('data/test').and_return(:true)
      @format.read
    end

    it "should return nil when it can't find the file" do
      @format.read.should eql nil
    end

    it "should apply our encoding" do
      File.stub(:exists?) { true }
      @format.name = 'test'
      @format.encoding = 'latin1'
      File.stub(:open) {:true}
      Iconv.should_receive(:conv).with('utf-8', 'latin1', :true).and_return(:text)
      @format.read.should eql :text
    end

    it "should not bother converting if no encoding specified" do
      File.stub(:exists?) { true }
      @format.name = 'test'
      File.stub(:open) {:true}
      Iconv.should_receive(:conv).exactly(0).times
      @format.read.should eql :true
    end
  end

  describe '#process!' do
    it "should call #read" do
      @format.should_receive(:read).and_return(nil)
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
      success = mock
      success.should_receive(:called)
      @format.stub(:process_file) { processed = true }
      @format.before { success.called unless processed }
      @format.stub(:read) { :true }
      @format.process!
    end

    it "should call our after" do
      processed = false
      success = mock
      success.should_receive(:called)
      @format.stub(:process_file) { processed = true }
      @format.after { success.called if processed }
      @format.stub(:read) { :test }
      @format.process!
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
