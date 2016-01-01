require 'spec_helper'

RSpec.describe PoroValidator do
  it "has a version number" do
    expect(PoroValidator::VERSION).not_to be_nil
  end

  describe ".validator" do
    context "it allows access to the anonymous validator module" do
      let(:klass) do
        Class.new do
          include PoroValidator.validator
        end.new
      end

      it "has a .validates class method" do
        expect(klass.class).to respond_to(:validates)
      end

      it "has #valid? in on instance" do
        expect(klass).to respond_to(:valid?)
      end
    end
  end
end
