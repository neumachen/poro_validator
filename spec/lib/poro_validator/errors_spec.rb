require 'spec_helper'

RSpec.describe PoroValidator::Errors do
  subject(:errors) { described_class.new }

  describe "#add" do
    it "adds a message stored in an array for an attribute" do
      errors.add(:foo, "manbearpig")
      expect(errors.on(:foo)).to eq(["manbearpig"])
    end

    it "adds additional messages for an attribute if it's already been set" do
      errors.add(:foo, "manbearpig")
      errors.add(:foo, "excelsior")
      expect(errors.on(:foo)).to eq(["manbearpig", "excelsior"])
    end
  end

  describe "#count" do
    it "counts the messages assigned for an attribute" do
      errors.add(:presence, "manbearpig")
      errors.add(:presence, "magiclife")
      errors.add(:foo, "excelsior")
      expect(errors.count).to eq(3)
    end
  end

  describe "#empty?" do
    it "returns true if count is zero" do
      expect(errors.count).to eq(0)
      expect(errors.empty?).to be_truthy
    end

    it "returns false if count is not zero" do
      errors.add(:presence, "manbearpig")
      expect(errors.count).to eq(1)
      expect(errors.empty?).to be_falsey
    end
  end

  describe "#full_messages" do
    before(:each) do
      errors.add(:foo, "manbearpig")
    end

    it "returns an array" do
      expect(errors.full_messages).to be_a(::Array)
    end

    it "returns an array of messages" do
      expect(errors.full_messages).to eq(["foo manbearpig"])
    end
  end

  describe "#on" do
    context "if the key has an existing value" do
      it "returns the message associated with the key" do
        errors.add(:foo, "manbearpig")
        expect(errors.on(:foo)).to eq(["manbearpig"])
      end

    end

    context "if the key has no existing value" do
      it "returns nil" do
        expect(errors.on(:batman)).to be_nil
      end
    end
  end

  describe "#clear_errors" do
    it "clears the stored error messages" do
      errors.add(:foo, "manbearpig")
      expect(errors.count).to eq(1)
      errors.clear_errors
      expect(errors.empty?).to be_truthy
    end
  end
end
