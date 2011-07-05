require 'spec_helper'

describe Schlepp::Format::Xml do
  before(:each) do
    @xml = Schlepp::Format::Xml.new {}
    @xml_string = <<EOF
      <mydoc>
        <someelement attribute="nanoo">Text, text, text</someelement>
      </mydoc>
EOF
  end

  describe "#parse" do
    it "should parse with rexml" do
      @xml.parse(@xml_string).elements.should_not be_nil
    end
  end

  describe "#use" do
    it "should set our @use" do
      use = proc {|okay| :nice}
      @xml.use(&use)
      @xml.instance_variable_get(:@use).should eql use
    end
  end

  describe "#apply_use" do
    it "should call our @use" do
      processed = false
      use = proc {|something| processed = true}
      @xml.use(&use)
      @xml.apply_use(:anything)
    end
  end

  describe "#process_file" do
    before(:each) do
      @xml.stub(:parse) {:parse_out}
      @xml.stub(:apply_use) {:use_out}
    end

    it "should call #parse on the data" do
      @xml.should_receive(:parse).with(@xml_string)
      @xml.process_file(@xml_string)
    end

    it "should call #apply_use on the data" do
      @xml.should_receive(:apply_use).with(:parse_out)
      @xml.process_file(@xml_string)
    end
  end
end
