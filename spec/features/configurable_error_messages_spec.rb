require 'spec_helper'

RSpec.describe "Allow configuration for error messages", type: :feature do
  let(:custom_message) { proc { "manbearpig" } }

  before(:each) do
    ::PoroValidator.configure do |config|
      config.message.set(:integer, custom_message)
    end
  end

  it "customize existing validator messages" do
    validator = Class.new do
      include PoroValidator.validator

      validates :amount, integer: true
    end.new

    entity = OpenStruct.new(amount: 'abc')
    validator.valid?(entity)
    expect(validator.errors.on(:amount)).to eq(
      [custom_message.call]
    )
  end

  it "passes the original option object to a custom message" do
    received = nil
    ::PoroValidator.configure do |config|
      config.message.set(:inclusion, lambda { |choices|
        received = choices
        "is not allowed"
      })
    end
    choices = [1]
    choices << choices

    validator = Class.new do
      include PoroValidator.validator

      validates :tier, inclusion: { in: choices }
    end.new

    validator.valid?(OpenStruct.new(tier: 2))
    expect(received).to be(choices)
    expect(validator.errors.on(:tier)).to eq(["is not allowed"])
  end

  after(:each) do
    # reset the custom messages
    # if this is not done, there will be flapping test wherever
    # the integer validator is used and it's default error message
    # matched
    ::PoroValidator.configure do |config|
      config.message.instance_variable_set(:@messages, {})
    end
  end
end
