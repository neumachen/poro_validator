require 'spec_helper'
require 'open3'
require 'rbconfig'

# Hash root/nested input normalization: converts String (and other) keys to
# Symbols for direct keys and direct nested Hash values, without reopening
# or extending ::Hash and without requiring the input to be mutable. See
# lib/poro_validator/utils/deep_symbolize_keys.rb for the implementation and
# spec/lib/poro_validator/utils/deep_symbolize_keys_spec.rb for its unit
# coverage. This file exercises the same contract through the public
# #valid? API, plus the fresh-process guarantee that requiring the gem does
# not add or replace any global Hash method.
RSpec.describe "Hash input normalization", :aggregate_failures, type: :feature do
  let(:lib) { File.expand_path('../../lib', __dir__) }

  context "mutable, frozen root, and frozen nested Hash input" do
    it "produces the same valid/invalid result and messages for mutable and frozen root Hashes" do
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      mutable_result = klass.new.tap { |v| v.valid?({ "name" => nil }) }
      frozen_result  = klass.new.tap { |v| v.valid?({ "name" => nil }.freeze) }

      expect(mutable_result.valid?({ "name" => nil })).to be(false)
      expect(frozen_result.valid?({ "name" => nil }.freeze)).to be(false)
      expect(mutable_result.errors.full_messages).to eq(frozen_result.errors.full_messages)
    end

    it "produces the same result for mutable and frozen nested Hashes" do
      klass = Class.new do
        include PoroValidator.validator
        validates :address do
          validates :line1, presence: true
        end
      end

      mutable = { "address" => { "line1" => nil } }
      frozen  = { "address" => { "line1" => nil }.freeze }.freeze

      v1 = klass.new
      v2 = klass.new
      expect(v1.valid?(mutable)).to be(false)
      expect(v2.valid?(frozen)).to be(false)
      expect(v1.errors.on([:address, :line1])).to eq(v2.errors.on([:address, :line1]))
    end

    it "accepts both String- and Symbol-keyed valid input with equivalent outcomes" do
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      expect(klass.new.valid?({ "name" => "Ada" })).to be(true)
      expect(klass.new.valid?({ name: "Ada" })).to be(true)
    end

    it "previously-rejected frozen root input now succeeds instead of raising FrozenError" do
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      expect { klass.new.valid?({ name: "Ada" }.freeze) }.not_to raise_error
    end
  end

  context "caller preservation" do
    it "does not mutate the caller's Hash contents" do
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      h = { "name" => "Ada" }
      klass.new.valid?(h)
      expect(h).to eq({ "name" => "Ada" })
    end

    it "does not add singleton-class ancestors or methods to the caller's Hash, even across repeated validation" do
      # singleton_methods alone would not catch an empty module extension
      # (DeepSymbolizeKeys defines no methods of its own when it reopened
      # ::Hash); checking singleton_class.ancestors catches that case too.
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      h = { "name" => "Ada" }
      before_ancestors = h.singleton_class.ancestors.dup
      before_methods = h.singleton_methods

      validator = klass.new
      2.times { validator.valid?(h) }

      expect(h.singleton_class.ancestors).to eq(before_ancestors)
      expect(h.singleton_methods).to eq(before_methods)
    end

    it "leaves the caller's Array values exactly as given (same object, not copied)" do
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      array = ["a", "b"]
      h = { "name" => "Ada", "tags" => array }
      klass.new.valid?(h)
      expect(h["tags"]).to be(array)
    end
  end

  context "fresh subprocess: no global Hash pollution" do
    it "adds neither #deep_symbolize_keys nor #deep_transform_keys to Hash when requiring the gem" do
      script = <<-'RUBY'
        require 'poro_validator'
        puts Hash.instance_methods(false).include?(:deep_symbolize_keys)
        puts Hash.instance_methods(false).include?(:deep_transform_keys)
        puts({}.respond_to?(:deep_symbolize_keys))
        puts({}.respond_to?(:deep_transform_keys))
      RUBY
      out, err, status = Open3.capture3(
        {}, RbConfig.ruby, '-I', lib, '-e', script, unsetenv_others: true
      )
      expect(status).to be_success, "exit #{status.exitstatus}: #{err}"
      expect(out.lines.map(&:chomp)).to eq(%w[false false false false])
    end

    it "does not invoke a pre-existing Hash#deep_symbolize_keys/#deep_transform_keys sentinel, and leaves its implementation unchanged" do
      script = <<-'RUBY'
        $sentinel_calls = 0
        class Hash
          def deep_symbolize_keys
            $sentinel_calls += 1
            :sentinel
          end

          def deep_transform_keys(&block)
            $sentinel_calls += 1
            :sentinel_transform
          end
        end
        owner_before = Hash.instance_method(:deep_symbolize_keys).owner
        source_before = Hash.instance_method(:deep_symbolize_keys).source_location

        require 'poro_validator'

        validator = Class.new { include PoroValidator.validator; validates :name, presence: true }.new
        result = validator.valid?({ "name" => "Ada" })

        owner_after = Hash.instance_method(:deep_symbolize_keys).owner
        source_after = Hash.instance_method(:deep_symbolize_keys).source_location

        puts result
        puts $sentinel_calls
        puts(owner_before == owner_after)
        puts(source_before == source_after)
      RUBY
      out, err, status = Open3.capture3(
        {}, RbConfig.ruby, '-I', lib, '-e', script, unsetenv_others: true
      )
      expect(status).to be_success, "exit #{status.exitstatus}: #{err}"
      lines = out.lines.map(&:chomp)
      expect(lines[0]).to eq("true")  # normalization succeeded via the gem's own code
      expect(lines[1]).to eq("0")     # sentinel never invoked
      expect(lines[2]).to eq("true")  # owner unchanged
      expect(lines[3]).to eq("true")  # source_location unchanged
    end
  end

  context "collision order, key conversion fallback, recursion, and Array-of-Hash behavior through the public API" do
    it "keeps the later key's value on a String/Symbol collision, following source insertion order" do
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }

      string_then_symbol = klass.new
      expect(string_then_symbol.valid?({ "name" => nil, name: "Ada" })).to be(true)

      symbol_then_string = klass.new
      expect(symbol_then_string.valid?({ name: "Ada", "name" => nil })).to be(false)
    end

    it "leaves a key unchanged, through the public API, when #to_sym raises" do
      key = Object.new
      def key.to_sym
        raise NoMethodError, "no to_sym"
      end

      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      validator = klass.new
      # The unconvertible key is simply carried through unchanged; it does
      # not satisfy :name, so presence still fails as it would for any
      # entity lacking a usable :name key.
      expect(validator.valid?({ key => "value" })).to be(false)
    end

    it "recurses into nested Hashes for nested validation lookups" do
      klass = Class.new do
        include PoroValidator.validator
        validates :address do
          validates :country do
            validates :code, presence: true
          end
        end
      end
      entity = { "address" => { "country" => { "code" => nil } } }
      validator = klass.new
      expect(validator.valid?(entity)).to be(false)
      expect(validator.errors.on([:address, :country, :code])).to eq(["is not present"])
    end

    it "does not normalize String keys inside an Array of Hashes (unchanged from before this increment)" do
      klass = Class.new { include PoroValidator.validator; validates :name, presence: true }
      entity = { "name" => "Ada", "tags" => [{ "a" => 1 }] }
      validator = klass.new
      expect(validator.valid?(entity)).to be(true)
      # Content-level confirmation that the inner Array-of-Hash keys remain
      # untouched is in the unit spec; here we only confirm the public call
      # path is unaffected by that Array's content.
    end
  end
end
