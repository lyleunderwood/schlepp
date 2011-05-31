require 'spec_helper'

describe Schlepp::Format::Binary do
  before(:each) do
    @binary = Schlepp::Format::Binary.new {}
    Schlepp::Format.cwd = ''
  end

  describe '#glob' do
    it "should add a path to @globs" do
      blk = lambda {}
      @binary.glob File.join('anything') do |something|
      end
      @binary.globs.count.should eql 1
    end
  end

  describe '#process!' do
    it "should run globs" do
      processed = false
      blk = lambda {|path| processed = true }
      @binary.globs << {path: 'test', block: blk}
      Dir.should_receive(:glob).with('/test').and_return(['one'])
      @binary.process!
      processed.should be_true
    end
  end

end