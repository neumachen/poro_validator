require 'spec_helper'

# Several rules failing for one nested attribute each keep their message, and
# the attribute's errors can be read by its Array path or the equivalent Hash.
RSpec.describe "Errors for nested attributes", :aggregate_failures, type: :feature do
  let(:length_error) { "does not match the length options: {:min=>2}" }
  let(:format_error) { "does not match the pattern: /\\AOK\\z/" }
  let(:line1_errors) { [length_error, format_error] }
  let(:validator_class) do
    Class.new do
      include PoroValidator.validator

      validates :address do
        validates :line1, length: { min: 2 }, format: { with: /\AOK\z/ }
        validates :city, presence: true
      end
    end
  end

  def expect_line1_errors(errors)
    expect(errors.on([:address, :line1])).to eq(line1_errors)
    expect(errors.on({ address: :line1 })).to eq(line1_errors)
  end

  it "keeps every failure for a nested attribute of a Hash" do
    validator = validator_class.new

    expect(validator.valid?(address: { line1: "x", city: "Paris" })).to be(false)
    expect(validator.errors.count).to eq(2)
    expect_line1_errors(validator.errors)
    expect(validator.errors.full_messages).
      to eq(line1_errors.map { |message| "{:address=>:line1} #{message}" })
  end

  it "keeps every failure for a nested attribute of a Ruby object" do
    address = Struct.new(:line1, :city)
    customer = Struct.new(:address)
    validator = validator_class.new

    expect(validator.valid?(customer.new(address.new("x", "Paris")))).to be(false)
    expect(validator.errors.count).to eq(2)
    expect_line1_errors(validator.errors)
  end

  it "keeps separate nested attributes separate" do
    validator = validator_class.new

    expect(validator.valid?(address: { line1: "x" })).to be(false)
    expect(validator.errors.count).to eq(3)
    expect_line1_errors(validator.errors)
    expect(validator.errors.on([:address, :city])).to eq(["is not present"])
    expect(validator.errors.full_messages).to eq([
      "{:address=>:line1} #{length_error}",
      "{:address=>:line1} #{format_error}",
      "{:address=>:city} is not present"
    ])
  end

  it "keeps every failure further down" do
    validator = Class.new do
      include PoroValidator.validator

      validates :address do
        validates :country do
          validates :code, length: { min: 2 }, format: { with: /\AOK\z/ }
        end
      end
    end.new

    expect(validator.valid?(address: { country: { code: "x" } })).to be(false)
    expect(validator.errors.count).to eq(2)
    expect(validator.errors.on([:address, [:country, :code]])).to eq(line1_errors)
    expect(validator.errors.on([:address, :country, :code])).to eq(line1_errors)
    expect(validator.errors.on({ address: { country: :code } })).to eq(line1_errors)
    expect(validator.errors.full_messages).
      to eq(line1_errors.map { |message| "{:address=>{:country=>:code}} #{message}" })
  end

  it "starts over on each validation when reused" do
    validator = validator_class.new
    invalid = { address: { line1: "x", city: "Paris" } }
    valid = { address: { line1: "OK", city: "Paris" } }

    results = [invalid, valid, invalid].map do |entity|
      [validator.valid?(entity), validator.errors.on([:address, :line1]), validator.errors.count]
    end

    expect(results).to eq([[false, line1_errors, 2], [true, nil, 0], [false, line1_errors, 2]])
  end
end
