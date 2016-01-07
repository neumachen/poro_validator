require 'spec_helper'

RSpec.describe PoroValidator::Validators::BaseClass do
  describe "#validate" do
    it "raises NotImplementedEror" do
      klass = described_class.new(:foo)
      expect { klass.validate(nil, nil, nil) }.
        to raise_error(::PoroValidator::OverloadriddenRequired)
    end
  end
end
