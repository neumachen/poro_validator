require 'spec_helper'

# A validator composed with `with:` copies the errors of the child validator it
# runs: every message, in order, while the child's own errors stay as they were.
RSpec.describe "Errors of composed validators", :aggregate_failures, type: :feature do
  let(:length_error) { "does not match the length options: {:min=>2}" }
  let(:format_error) { "does not match the pattern: /\\AOK\\z/" }

  # A child validator class for `with:`. Its instances record themselves and,
  # right after their ordinary #valid? call, which message Arrays their errors
  # held and what those contained. `after_valid` can then adjust the errors,
  # and `freeze` freezes the store's Hash and message Arrays.
  def child_class(freeze: false, after_valid: nil, &declarations)
    Class.new do
      include PoroValidator.validator

      singleton_class.attr_accessor :instances
      self.instances = []
      attr_reader :arrays_after_valid, :contents_after_valid

      define_method(:initialize) { self.class.instances << self }

      define_method(:valid?) do |entity|
        result = super(entity)
        after_valid.call(errors) if after_valid
        data = errors.store.data
        if freeze
          data.each_value(&:freeze)
          data.freeze
        end
        @arrays_after_valid = data.values
        @contents_after_valid = data.map { |key, messages| [key, messages.dup] }
        result
      end

      class_eval(&declarations)
    end
  end

  def parent_for(attribute, child)
    Class.new do
      include PoroValidator.validator

      validates attribute, with: child
    end.new
  end

  # The child's errors hold the same keys, Arrays and messages as right after
  # its own validation.
  def expect_unchanged(child)
    data = child.errors.store.data
    expect(data.map { |key, messages| [key, messages] }).to eq(child.contents_after_valid)
    expect(data.values.size).to eq(child.arrays_after_valid.size)
    data.values.zip(child.arrays_after_valid) do |now, before|
      expect(now).to be(before)
    end
  end

  let(:line1_child) do
    child_class { validates :line1, length: { min: 2 }, format: { with: /\AOK\z/ } }
  end

  context "with a child attribute of another name" do
    it "copies every message for a Hash entity, in order, under the prefixed path" do
      parent = parent_for(:address, line1_child)

      expect(parent.valid?(address: { line1: "x" })).to be(false)
      expect(parent.errors.on([:address, :line1])).to eq([length_error, format_error])
      expect(parent.errors.full_messages).to eq([
        "{:address=>:line1} #{length_error}", "{:address=>:line1} #{format_error}"
      ])
      expect_unchanged(line1_child.instances.last)
    end

    it "does the same for a Ruby object entity" do
      address = Struct.new(:line1)
      customer = Struct.new(:address)
      parent = parent_for(:address, line1_child)

      expect(parent.valid?(customer.new(address.new("x")))).to be(false)
      expect(parent.errors.on([:address, :line1])).to eq([length_error, format_error])
      expect_unchanged(line1_child.instances.last)
    end
  end

  context "with a child attribute of the same name" do
    it "copies every message under the parent's own attribute" do
      name_child = child_class { validates :name, length: { min: 2 }, format: { with: /\AOK\z/ } }
      parent = parent_for(:name, name_child)

      expect(parent.valid?(name: "x")).to be(false)
      expect(parent.errors.on(:name)).to eq([length_error, format_error])
      expect(parent.errors.full_messages).to eq(["name #{length_error}", "name #{format_error}"])
      expect_unchanged(name_child.instances.last)
    end
  end

  it "copies several attributes, repeated and custom messages, after the parent's own" do
    child = child_class do
      validates :line1, format: { with: /\AO/, message: "is wrong" }
      validates :line1, format: { with: /K\z/, message: "is wrong" }
      validates :city, presence: { message: "is required" }
    end
    parent = Class.new do
      include PoroValidator.validator

      validates :address do
        validates :line1, length: { min: 3, message: "is too short for the parent" }
      end
      validates :address, with: child
    end.new

    expect(parent.valid?(address: { line1: "x" })).to be(false)
    expect(parent.errors.on([:address, :line1])).
      to eq(["is too short for the parent", "is wrong", "is wrong"])
    expect(parent.errors.on([:address, :city])).to eq(["is required"])
    expect(parent.errors.full_messages).to eq([
      "{:address=>:line1} is too short for the parent",
      "{:address=>:line1} is wrong",
      "{:address=>:line1} is wrong",
      "{:address=>:city} is required"
    ])
    expect_unchanged(child.instances.last)
  end

  it "reads a child's frozen errors without changing them" do
    frozen_child = child_class(freeze: true) do
      validates :line1, length: { min: 2 }, format: { with: /\AOK\z/ }
    end
    parent = parent_for(:address, frozen_child)

    expect(parent.valid?(address: { line1: "x" })).to be(false)
    expect(parent.errors.on([:address, :line1])).to eq([length_error, format_error])
    child = frozen_child.instances.last
    expect(child.errors.store.data).to be_frozen
    expect(child.errors.store.data.values).to all(be_frozen)
    expect_unchanged(child)
  end

  it "gives the parent its own message Array holding the same message objects" do
    parent = parent_for(:address, line1_child)
    parent.valid?(address: { line1: "x" })
    child = line1_child.instances.last
    child_messages = child.errors.store.data.fetch("line1")
    copied = parent.errors.on([:address, :line1])

    expect(copied).not_to be(child_messages)
    expect(copied.map(&:object_id)).to eq(child_messages.map(&:object_id))

    copied << "added to the parent"
    copied.delete_at(0)
    parent.errors.clear_errors

    expect(child_messages).to eq([length_error, format_error])
    expect_unchanged(child)
  end

  context "when the child has no messages" do
    let(:empty_array_child) do
      child_class(after_valid: ->(errors) { errors.store.set(:line1, []) }) do
        validates :line1, presence: true
      end
    end

    it "copies nothing from an empty error store" do
      parent = parent_for(:address, line1_child)

      expect(parent.valid?(address: { line1: "OK" })).to be(true)
      expect(parent.errors.store.data).to eq({})
    end

    it "copies nothing from an empty message Array, so the parent stays valid" do
      parent = parent_for(:address, empty_array_child)

      expect(parent.valid?(address: { line1: "OK" })).to be(true)
      expect(parent.errors.store.data).to eq({})
      expect(parent.errors.count).to eq(0)
      child = empty_array_child.instances.last
      expect(child.errors.store.data).to eq("line1" => [])
      expect_unchanged(child)
    end

    it "keeps the parent's unrelated failures" do
      child = empty_array_child
      parent = Class.new do
        include PoroValidator.validator

        validates :name, presence: true
        validates :address, with: child
      end.new

      expect(parent.valid?(name: nil, address: { line1: "OK" })).to be(false)
      expect(parent.errors.full_messages).to eq(["name is not present"])
    end
  end

  it "leaves each earlier child's errors unchanged when the parent is reused" do
    parent = parent_for(:address, line1_child)

    results = [{ line1: "x" }, { line1: "OK" }, { line1: "x" }].map do |address|
      [parent.valid?(address: address), parent.errors.on([:address, :line1])]
    end

    expect(results).to eq([
      [false, [length_error, format_error]], [true, nil], [false, [length_error, format_error]]
    ])
    expect(line1_child.instances.size).to eq(3)
    line1_child.instances.each { |child| expect_unchanged(child) }
    expect(line1_child.instances.first.errors.store.data).
      to eq("line1" => [length_error, format_error])
  end

  it "lets an exception from the child's validation through" do
    error = ArgumentError.new("line1 failed")
    address = Object.new
    address.define_singleton_method(:line1) { raise error }
    parent = parent_for(:address, line1_child)

    expect { parent.valid?(address: address) }.
      to raise_error(ArgumentError) { |raised| expect(raised).to be(error) }
  end
end
