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

    context "if several validators have their own conditions" do
      let(:declaration_condition) { ->(_context) { true } }
      let(:length_condition) { ->(_context) { false } }
      let(:presence_condition) { ->(_context) { true } }

      it "gives each validator the declaration's conditions and only its own" do
        klass = described_class.new
        klass.build(:foo_attr, length: { min: 5, if: length_condition },
                    format: { with: /x/ },
                    presence: { unless: presence_condition },
                    if: declaration_condition)

        expect(klass.validations.map { |validation| validation[:conditions] }).to eq([
          [{ if: declaration_condition }, { if: length_condition }],
          [{ if: declaration_condition }],
          [{ if: declaration_condition }, { unless: presence_condition }]
        ])
      end
    end

    context "with the caller's validator options" do
      it "leaves them unchanged and passes their other values to the validator" do
        message = "hello"
        condition = ->(_context) { true }
        options = { message: message, if: condition }
        klass = described_class.new
        klass.build(:foo_attr, presence: options)
        validation = klass.validations.first

        expect(options.keys).to eq([:message, :if])
        expect(options[:if]).to be(condition)
        expect(validation[:conditions]).to eq([{ if: condition }])
        expect(validation[:validator].options).to eq(message: message)
        expect(validation[:validator].options[:message]).to be(message)
      end

      it "accepts them frozen" do
        options = { message: "hello", if: ->(_context) { true } }.freeze
        klass = described_class.new

        expect { klass.build(:foo_attr, presence: options) }.not_to raise_error
        expect(klass.validations.first[:validator].options).to eq(message: "hello")
      end

      it "passes options without conditions through as the same object" do
        options = { message: "hello" }
        klass = described_class.new
        klass.build(:foo_attr, presence: options)

        expect(klass.validations.first[:validator].options).to be(options)
      end

      it "keeps condition keys out of #validators" do
        klass = described_class.new
        klass.build(:foo_attr, presence: { message: "hello", if: ->(_context) { true } },
                    format: /x/)

        expect(klass.validators).to eq(presence: { message: "hello" }, format: /x/)
      end
    end

    context "with conditional options that have a default or are a Hash subclass" do
      let(:condition) { ->(_context) { true } }

      def built_options(options)
        klass = described_class.new
        klass.build(:foo_attr, presence: options)
        klass.validations.first[:validator].options
      end

      it "keeps the other keys in order, their values and the default value" do
        default = []
        message = "hello"
        options = Hash.new(default)
        options[:message] = message
        options[:if] = condition
        options[:allow_blank] = true

        rule_options = built_options(options)

        expect(rule_options.keys).to eq([:message, :allow_blank])
        expect(rule_options[:message]).to be(message)
        expect(rule_options.default).to be(default)
        expect(rule_options[:missing]).to be(default)
        expect(options.keys).to eq([:message, :if, :allow_blank])
      end

      it "keeps the default Proc, which receives and caches into the rule's options" do
        receivers = []
        default_proc = lambda do |hash, key|
          receivers << hash
          hash[key] = "cached #{key}"
        end
        options = {}
        options.default_proc = default_proc
        options[:if] = condition

        rule_options = built_options(options)
        value = rule_options[:minimum]

        expect(rule_options.default_proc).to be(default_proc)
        expect(value).to eq("cached minimum")
        expect(receivers.size).to eq(1)
        expect(receivers.first).to be(rule_options)
        expect(rule_options).to have_key(:minimum)
        expect(options.keys).to eq([:if])
      end

      it "keeps a Hash subclass and its instance state" do
        options_class = Class.new(::Hash) do
          attr_accessor :floor
        end
        options = options_class.new
        options.floor = 10
        options[:if] = condition

        rule_options = built_options(options)

        expect(rule_options).to be_a(options_class)
        expect(rule_options.floor).to eq(10)
        expect(rule_options).not_to be(options)
        expect(rule_options).not_to have_key(:if)
        expect(options).to have_key(:if)
      end
    end
  end
end
