require File.dirname(__FILE__) + '/spec_helper'

describe Schlepp::Burden do
  before :each do
    @klass = Schlepp::Burden
    @burden = init_burden
    @klass.all = []
  end

  before(:all) { @original_db = Schlepp::Db }

  after(:all) { suppress_warnings { Schlepp::Db = @original_db } }

  def suppress_warnings
    return unless block_given?
    # quiet, you !
    # TODO: maybe i can just turn off the autoloader or something?
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    yield
    $VERBOSE = original_verbosity
    # as long as i don't do this in lib/ right? ToT
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

  describe '#on_error' do
    it "should set @on_error callback" do
      cb = proc { true }
      @burden.on_error(&cb)
      @burden.instance_variable_get(:@on_error).should eql cb
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

    it "should process globs" do
      b = init_burden
      job = proc {|format| :test}
      b.globs << {:path => 'cat*', :block => proc do |dir|
        file('Nothing', &job)
        files << :test
      end}
      Dir.should_receive(:glob).with('./cat*').and_return(['cat1'])
      b.should_receive(:file).with('Nothing', &job).and_return(:wat)
      b.should_receive(:process_job).with(:test).and_return(:test)
      b.process!
    end

    it "should process dbs" do
      b = init_burden
      db = mock
      b.dbs << db
      b.should_receive(:process_job).with(db).and_return(nil)
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

    it "should rescue with our @on_error" do
      success = mock
      success.should_receive(:called)
      file = mock
      file.stub(:process!) {raise Exception.new}
      @burden.files << file
      @burden.on_error { success.called }
      expect { @burden.process! }.to raise_error
    end

    it "should send proper params to @on_error" do
      the_error = Exception.new
      file = mock
      file.stub(:process!) {raise the_error}
      @burden.files << file
      @burden.on_error do |error, job, burden|
        error.should eql the_error
        job.should eql file
        burden.should eql @burden
        true
      end

      @burden.process!
    end

    it "should continue if @on_error returns true" do
      the_error = Exception.new
      file = mock
      file.stub(:process!) {raise the_error}
      @burden.files << file
      @burden.on_error do |error, job, burden|
        error.should eql the_error
        job.should eql file
        burden.should eql @burden
        true
      end

      expect { @burden.process! }.to_not raise_error
    end

    it "should not continue if @on_error returns false" do
      the_error = Exception.new
      file = mock
      file.stub(:process!) {raise the_error}
      @burden.files << file
      @burden.on_error do |error, job, burden|
        error.should eql the_error
        job.should eql file
        burden.should eql @burden
        false
      end

      expect { @burden.process! }.to raise_error
    end
  end

  context "batch jobs" do
    before(:each) do
      Schlepp::Burden.all = []
      @jobs = [mock, mock]
      Schlepp::Burden.all = @jobs
    end

    describe '.find' do
      it "should find the job given the label" do
        @jobs.each_with_index {|j,i| j.stub(:label) { i.to_s.to_sym }}
        Schlepp::Burden.find(:"1").should eql @jobs.last
      end
    end

    describe '.process' do
      it "should run process! on all jobs by default" do
        @jobs.each {|j| j.should_receive(:process!)}
        Schlepp::Burden.process
      end

      it "should call process on the correct job when given a label" do
        @jobs.each_with_index {|j,i| j.stub(:label) { i.to_s.to_sym }}
        @jobs.first.should_receive(:process!).exactly(0).times
        @jobs.last.should_receive(:process!).once
        Schlepp::Burden.process(:"1")
      end
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

  describe '#db' do
    before do
      suppress_warnings { Schlepp::Db = double }
    end

    it "should create a db" do
      test = double
      Schlepp::Db.stub(:new) {test}
      @burden.db
      @burden.dbs.first.should eql test
      @burden.dbs.count.should eql 1
    end

    it "should pass a config block to the db" do
      config = lambda {}
      Schlepp::Db.should_receive(:new) {|&block| block.should eql config }
      @burden.db &config
    end
  end

end
