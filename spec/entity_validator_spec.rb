require 'spec_helper'

RSpec.describe EntityValidator do
  it "has a version number" do
    expect(EntityValidator::VERSION).not_to be_nil
  end
end
