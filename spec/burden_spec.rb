require File.dirname(__FILE__) + '/spec_helper'

describe Schlepp::Burden do
  before :each do
    @klass = Schlepp::Burden
    @burden = init_burden
    @klass.all = []
  end

  def init_burden(&block)
    block ||= proc {}
    Schlepp::Burden.new(:test, &block)
  end

  describe '#initialize' do
    it "should run our config block" do
      obj = nil
      b = @klass.new :test do
        obj = self
      end

      obj.should eql b
    end

    it "should keep track of the burdens created" do
      @klass.all.count.should eql 0
      @klass.new :test do; end;
      @klass.all.count.should eql 1
    end
  end

  describe '#file' do
    it "should instantiate a file with the block" do
      format = mock
      format.should_receive(:new).and_return(format)
      Schlepp::Format.should_receive(:const_get).with('Nothing').and_return(format)
      init_burden.file('Nothing') {}
    end

    it "should add the file to the list of files" do
      format = mock
      format.stub(:new) { :file }
      Schlepp::Format.stub(:const_get) { format }

      b = init_burden
      b.file('Nothing') {}

      b.files.count.should eql 1
      b.files.first.should eql :file
    end
  end

  describe '#glob' do
    it "should add a glob to be processed" do
      b = init_burden
      b.glob('data/*') {}
      b.globs.count.should eql 1
    end
  end

  describe '#process_job' do
    it "should call process! on the job" do
      job = mock
      job.should_receive(:process!)
      @burden.process_job(job)
    end

    it "should call our @before_each with job" do
      success = mock
      job = mock
      processed = false
      job.stub(:process!) { processed = true }

      success.should_receive(:called).with(job)

      b = init_burden do 
        before_each do |job| 
          success.called(job) unless processed 
        end
      end

      b.process_job(job)
    end

    it "should call our @after_each" do
      success = mock
      job = mock

      processed = false
      job.stub(:process!) { processed = true; job }

      success.should_receive(:called)

      b = init_burden { after_each {|job| success.called if processed }}

      b.process_job(job)
    end
  end

  describe '#process_job' do
    it "should process files" do
      b = init_burden
      file = mock
      b.files << file
      b.should_receive(:process_job).with(file).and_return(nil)
      b.process!
    end

    it "should call our @before" do
      processed = false
      success = mock
      success.should_receive(:called)
      file = mock
      file.stub(:process!) {processed = true}
      @burden.files << file
      @burden.before {|job| success.called unless processed}
      @burden.process!
    end

    it "should call our @after" do
      processed = false
      success = mock
      success.should_receive(:called)
      file = mock
      file.stub(:process!) {processed = true}
      @burden.files << file
      @burden.after {|job| success.called if processed}
      @burden.process!
    end
  end

  describe '#cd' do
    it "should set the @cwd" do
      Schlepp::Format.stub(:cwd=)
      @burden.cd "test"
      @burden.instance_variable_get(:@cwd).should eql "test"
    end

    it "should set the @cwd for formats" do
      Schlepp::Format.should_receive(:cwd=).with('test')
      @burden.cd "test"
    end
  end

end
