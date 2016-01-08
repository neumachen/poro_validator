require 'spec_helper'

RSpec.describe PoroValidator::Validators::LengthValidator do
  include SpecHelpers::ValidatorTestMacros

  def gen_random_char(range)
    (0..range).map { ('a'..'z').to_a[rand(26)] }.first(range).join
  end

  describe "#validate" do
    subject(:validator) do
      Class.new do
        include PoroValidator.validator

        validates :title,   length: 1..10
        validates :subject, length: { extremum: 1 }
        validates :comment, length: { min: 10, max: 20 }
        validates :info,    length: { min: 10 }
        validates :status,  length: { max: 10 }
        validates :detail,  length: 1..10, if: proc { false }
      end.new
    end

    expect_validator_to_be_invalid do
      let(:entity) do
        OpenStruct.new(
          title:   gen_random_char(rand(11..15)),
          subject: gen_random_char(rand(2..10)),
          comment: gen_random_char(rand(21..25)),
          info:    gen_random_char(rand(1..9)),
          status:  gen_random_char(rand(11..15)),
          detail:  gen_random_char(rand(11..15))
        )
      end

      let(:expected_errors) do
        {
          "title"   => ["does not match the length options: {:in=>1..10}"],
          "subject" => ["does not match the length options: {:extremum=>1}"],
          "comment" => ["does not match the length options: {:max=>20}"],
          "info"    => ["does not match the length options: {:min=>10}"],
          "status"  => ["does not match the length options: {:max=>10}"],
        }
      end

      skip_attr_unmet_condition do
        let(:attr) { :detail }
      end
    end

    expect_validator_to_be_valid do
      let(:entity) do
        OpenStruct.new(
          title:   gen_random_char(rand(1..10)),
          subject: gen_random_char(rand(1..1)),
          comment: gen_random_char(rand(11..20)),
          info:    gen_random_char(rand(10..15)),
          status:  gen_random_char(rand(1..10)),
          detail:  gen_random_char(rand(11..15))
        )
      end
    end
  end
end
