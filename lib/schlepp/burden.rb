module Schlepp
  class Burden
    attr_accessor :label

    attr_accessor :files, :globs

    attr_accessor :cwd

    @all = []

    class << self
      attr_accessor :all
    end

    def initialize(label, &block)
      @label = label
      @files = []
      @globs = []
      @cwd   = './'

      instance_eval(&block)
      Schlepp::Burden.all << self
    end

    def file(format, &block)
      @files << Schlepp::Format.const_get(format).new(&block)
    end

    def glob(path, &block)
      @globs << {:path => path, :block => block}
    end

    def cd(path)
      @cwd = path
      Schlepp::Format.cwd = path
    end

    def before(&block)
      @before = block
    end

    def after(&block)
      @after = block
    end

    def before_each(&block)
      @before_each = block
    end

    def after_each(&block)
      @after_each = block
    end

    def process!
      @before.call(self) if @before
      if files.any?
        files.each do |file|
          process_job(file)
        end
      end
      @after.call(self) if @after
    end

    def process_job job
      @before_each.call(job) if @before_each
      result = job.process!
      @after_each.call(result, job) if @after_each
      result
    end

    def process_glob glob
      Dir.glob(@cwd + glob[:path]).each do |path|
        glob[:block].call(path)
      end
    end
  end
end
