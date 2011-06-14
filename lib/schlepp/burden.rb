module Schlepp
  class Burden
    # how we can access a specific Burden later
    attr_accessor :label

    attr_accessor :files, :globs, :dbs

    attr_accessor :cwd

    # holds onto each new Burden instance
    @all = []

    class << self
      attr_accessor :all

      # find task for given label
      def find(needle)
        all.each {|b| return b if b.label == needle}
        nil
      end

      # process all tasks or task for given label
      def process(label = nil)
        processed = false
        if label
          burden = find(label)
          return false unless burden
          burden.process!
          return true
        else
          all.each do |burden|
            processed = true
            burden.process!
          end
        end
        processed
      end
    end

    # takes a config block
    def initialize(label, &block)
      @label = label
      @files = []
      @dbs   = []
      @globs = []
      @cwd   = './'

      # call our config block
      instance_eval(&block)

      #hold onto our new Burden
      Schlepp::Burden.all << self
    end

    def db(&block)
      @dbs << Schlepp::Db.new(&block)
    end

    # takes a Schlepp::Format class name as a string and a config block
    def file(format, &block)
      @files << Schlepp::Format.const_get(format).new(&block)
    end

    # takes a glob string and a block. the block is called for every item 
    # in the globbed path.
    def glob(path, &block)
      @globs << {:path => path, :block => block}
    end

    # change the working directory. doesn't actually change cwd, just holds
    # onto this as a path prefix used for filenames and globbing
    def cd(path)
      @cwd = path
      Schlepp::Format.cwd = path
    end

    # before starting
    def before(&block)
      @before = block
    end

    # after finishing
    def after(&block)
      @after = block
    end

    # before each job
    def before_each(&block)
      @before_each = block
    end

    # after each job
    def after_each(&block)
      @after_each = block
    end

    # run all jobs
    def process!
      @before.call(self) if @before
      globs.each {|glob| process_glob(glob)}
      files.each {|file| process_job(file)}
      dbs.each {|db| process_job(db)}
      @after.call(self) if @after
    end

    def process_job job
      @before_each.call(job) if @before_each
      result = job.process!
      @after_each.call(result, job) if @after_each
      result
    end

    # globs are basically used for making new jobs based on globbed files in a 
    # directory
    def process_glob glob
      Dir.glob(File.join(@cwd, glob[:path])).each do |path|
        path.sub!(@cwd, '')
        instance_exec(path, &glob[:block])
      end
    end
  end
end
