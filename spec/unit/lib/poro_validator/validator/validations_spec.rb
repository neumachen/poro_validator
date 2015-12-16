require 'spec_helper'

RSpec.describe PoroValidator::Validator::Validations do
  describe ".build" do
    subject do
      klass = described_class.new
      klass.build(:foo_attr, presence: true,
                   format: /[a-z]/, if: true, unless: true)
      klass
    end

    it "can build multiple validators" do
      expect(subject.validations.size).to eq(2)
    end

    context "if there are nested conditions within the validator's options" do
      subject do
        klass = described_class.new
        klass.build(:foo_attr, presence: { message: "hello", if: true })
        klass
      end

      let(:validation) { subject.validations.first }

      it "can select then nested condition" do
        expect(validation[:conditions]).to eq([{ if: true }])
      end

      it "removes the nested condition from the validator options" do
        expect(validation[:validator].options).to_not have_key(:if)
      end
    end
  end
end
