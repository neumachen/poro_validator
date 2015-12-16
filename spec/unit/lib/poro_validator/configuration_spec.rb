require 'spec_helper'

RSpec.describe PoroValidator::Configuration do
  describe described_class::Message do
    let(:message) { described_class.new }

    describe "#get" do
      context "if the validator has a preset mesasge" do
        it "gets the message for that validator" do
          expect(message.get(:presence)).to eq("is not present")
        end
      end

      context "if the validator does not have a preset message" do
        it "gets the default message" do
          expect(message.get(:man_bear_pig)).to eq("is not valid")
        end
      end
    end

    describe "#set" do
      context "if a non proc class is passed in for the message" do
        it "raises an exception of PoroValidator::ValidatorException" do
          expect { message.set(:presence, "no message") }.
            to raise_error(PoroValidator::ConfigError)
        end
      end

      context "if a proc class is passed in for the message" do
        it "sets the message for that validator" do
          message.set(:presence, lambda { "custom message" })
          expect(message.get(:presence)).to eq("custom message")
        end
      end
    end
  end
end
