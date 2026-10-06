require 'spec_helper'

# `with:` inside a nested declaration validates the value at the nested path
# and reports the child's errors under that complete path.
RSpec.describe "Composition inside nested declarations", :aggregate_failures, type: :feature do
  let(:country_class) { Struct.new(:code) }
  let(:address_class) { Struct.new(:country) }
  let(:root_class) { Struct.new(:address) }
  let(:missing) { ["is not present"] }

  # A child validator class for `with:`. It records every entity it receives
  # and every instance and, right after its ordinary #valid? call, which
  # message Arrays its errors held and what they contained; with `freeze`, it
  # then freezes its store's Hash and message Arrays.
  def child_class(freeze: false, &declarations)
    Class.new do
      include PoroValidator.validator

      singleton_class.attr_accessor :payloads, :instances
      self.payloads = []
      self.instances = []
      attr_reader :arrays_after_valid, :contents_after_valid

      define_method(:valid?) do |entity|
        self.class.payloads << entity
        self.class.instances << self
        result = super(entity)
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

  # validates :address do
  #   validates :country, with: child
  # end
  def nested_parent(child)
    Class.new do
      include PoroValidator.validator

      validates :address do
        validates :country, with: child
      end
    end.new
  end

  def expect_unchanged(child)
    data = child.errors.store.data
    expect(data.map { |key, messages| [key, messages] }).to eq(child.contents_after_valid)
    data.values.zip(child.arrays_after_valid) { |now, before| expect(now).to be(before) }
  end

  let(:code_child) { child_class { validates :code, presence: true } }
  let(:country_child) { child_class { validates :country, presence: true } }

  context "with a child validating the nested value's attributes" do
    it "accepts valid Hash input with Symbol or String keys, passing the nested Hash" do
      parent = nested_parent(code_child)

      expect(parent.valid?(address: { country: { code: "US" } })).to be(true)
      expect(parent.errors.store.data).to eq({})
      expect(parent.valid?("address" => { "country" => { "code" => "US" } })).to be(true)
      expect(parent.errors.store.data).to eq({})
      expect(code_child.payloads).to eq([{ code: "US" }, { code: "US" }])
    end

    it "accepts valid object input, passing the nested object" do
      country = country_class.new("US")
      parent = nested_parent(code_child)

      expect(parent.valid?(root_class.new(address_class.new(country)))).to be(true)
      expect(parent.errors.store.data).to eq({})
      expect(code_child.payloads.size).to eq(1)
      expect(code_child.payloads.first).to be(country)
    end

    it "reports the child's errors for Hash or object input under the complete path" do
      parent = nested_parent(code_child)

      [{ address: { country: { code: nil } } },
       root_class.new(address_class.new(country_class.new(nil)))].each do |entity|
        expect(parent.valid?(entity)).to be(false)
        expect(parent.errors.on([:address, :country, :code])).to eq(missing)
        expect(parent.errors.on([:address, :country])).to be_nil
        expect(parent.errors.full_messages).to eq(["{:address=>{:country=>:code}} is not present"])
      end
      expect(code_child.payloads.first).to eq(code: nil)
      expect(code_child.payloads.last.code).to be_nil
    end
  end

  context "with a child validating the nested value itself" do
    it "wraps a String, Symbol or nil under the last name of the path" do
      parent = nested_parent(country_child)

      results = [
        { address: { country: "US" } }, { address: { country: :us } },
        { address: {} }, root_class.new(address_class.new("US"))
      ].map { |entity| parent.valid?(entity) }

      expect(results).to eq([true, true, false, true])
      expect(country_child.payloads).
        to eq([{ country: "US" }, { country: :us }, { country: nil }, { country: "US" }])
    end

    it "reports a failure once under the complete path" do
      parent = nested_parent(country_child)

      [{ address: { country: "" } }, { address: {} }].each do |entity|
        expect(parent.valid?(entity)).to be(false)
        expect(parent.errors.store.data.keys).to eq(["{:address=>:country}"])
        expect(parent.errors.on([:address, :country])).to eq(missing)
        expect(parent.errors.full_messages).to eq(["{:address=>:country} is not present"])
      end
    end
  end

  it "leaves flat composition as it was" do
    child = code_child
    flat = Class.new do
      include PoroValidator.validator

      validates :country, with: child
    end.new

    expect(flat.valid?(country: { code: "US" })).to be(true)
    expect(flat.valid?(country: { code: nil })).to be(false)
    expect(flat.errors.on([:country, :code])).to eq(missing)
    expect(code_child.payloads).to eq([{ code: "US" }, { code: nil }])
  end

  it "finds the value and reports the path two levels down" do
    child = code_child
    parent_class = Class.new do
      include PoroValidator.validator

      validates :customer do
        validates :address do
          validates :country, with: child
        end
      end
    end
    parent = parent_class.new
    customer_root = Struct.new(:customer)
    by_object = lambda do |code|
      customer_root.new(root_class.new(address_class.new(country_class.new(code))))
    end

    expect(parent_class.validations.validations.first[:validator].attribute).
      to eq([:customer, [:address, :country]])
    [{ customer: { address: { country: { code: "US" } } } }, by_object.("US")].each do |entity|
      expect(parent.valid?(entity)).to be(true)
    end
    [{ customer: { address: { country: { code: nil } } } }, by_object.(nil)].each do |entity|
      expect(parent.valid?(entity)).to be(false)
      expect(parent.errors.on([:customer, :address, :country, :code])).to eq(missing)
      expect(parent.errors.full_messages).
        to eq(["{:customer=>{:address=>{:country=>:code}}} is not present"])
    end
  end

  it "copies every child message, after the parent's own, and keeps unrelated failures" do
    upper = /\A[A-Z]+\z/
    child = child_class do
      validates :code, length: { min: 2 }, format: { with: upper }
      validates :code, format: { with: upper, message: "must be upper case" }
      validates :code, format: { with: upper, message: "must be upper case" }
    end
    parent = Class.new do
      include PoroValidator.validator

      validates :name, presence: true
      validates :address do
        validates :country do
          validates :code, length: { min: 3, message: "is too short for the parent" }
        end
      end
      validates :address do
        validates :country, with: child
      end
    end.new

    expect(parent.valid?(name: nil, address: { country: { code: "x" } })).to be(false)
    expect(parent.errors.on(:name)).to eq(missing)
    expect(parent.errors.on([:address, :country, :code])).to eq([
      "is too short for the parent",
      "does not match the length options: {:min=>2}",
      "does not match the pattern: #{upper.inspect}",
      "must be upper case",
      "must be upper case"
    ])
    expect(parent.errors.store.data.keys).to eq(["name", "{:address=>{:country=>:code}}"])
    expect_unchanged(child.instances.last)
  end

  it "reads frozen child errors, leaving every child's errors unchanged across reuse" do
    child = child_class(freeze: true) { validates :code, presence: true }
    parent = nested_parent(child)

    results = [nil, "US", nil].map do |code|
      [parent.valid?(address: { country: { code: code } }), parent.errors.on([:address, :country, :code])]
    end

    expect(results).to eq([[false, missing], [true, nil], [false, missing]])
    expect(child.instances.size).to eq(3)
    child.instances.each do |instance|
      expect(instance.errors.store.data).to be_frozen
      expect_unchanged(instance)
    end
  end

  context "when reading the nested value or validating it raises" do
    it "lets a nested reader's exception through without running the child" do
      error = ArgumentError.new("country failed")
      address = Object.new
      address.define_singleton_method(:country) { raise error }

      expect { nested_parent(code_child).valid?(root_class.new(address)) }.
        to raise_error(ArgumentError) { |raised| expect(raised).to be(error) }
      expect(code_child.payloads).to eq([])
    end

    it "still fails normally when an intermediate object is nil" do
      expect { nested_parent(code_child).valid?(root_class.new(nil)) }.
        to raise_error(NoMethodError, /undefined method 'country' for nil/)
    end

    it "lets the child's validation exception through" do
      error = KeyError.new("code failed")
      country = Object.new
      country.define_singleton_method(:code) { raise error }

      expect { nested_parent(code_child).valid?(root_class.new(address_class.new(country))) }.
        to raise_error(KeyError) { |raised| expect(raised).to be(error) }
    end
  end

  context "with reader objects" do
    it "reads each object on a nested path once" do
      reads = Hash.new(0)
      country = country_class.new("US")
      address = Object.new
      address.define_singleton_method(:country) { reads[:country] += 1; country }
      root = Object.new
      root.define_singleton_method(:address) { reads[:address] += 1; address }

      expect(nested_parent(code_child).valid?(root)).to be(true)
      expect(reads).to eq(address: 1, country: 1)
      expect(code_child.payloads.first).to be(country)
    end

    it "still reads a flat attribute twice, as before" do
      child = code_child
      reads = 0
      country = country_class.new("US")
      entity = Object.new
      entity.define_singleton_method(:country) { reads += 1; country }
      parent = Class.new do
        include PoroValidator.validator

        validates :country, with: child
      end.new

      expect(parent.valid?(entity)).to be(true)
      expect(reads).to eq(2)
    end
  end

  it "leaves declaration paths and the input unchanged" do
    child = code_child
    parent_class = Class.new do
      include PoroValidator.validator

      validates :customer do
        validates :address do
          validates :country, with: child
        end
      end
    end
    paths = -> { parent_class.validations.validations.map { |rule| rule[:validator].attribute } }
    paths_before = Marshal.load(Marshal.dump(paths.call))
    payload = { customer: { address: { country: { code: nil } } } }
    payload_before = Marshal.load(Marshal.dump(payload))

    parent_class.new.valid?(payload)

    expect(paths.call).to eq(paths_before)
    expect(paths.call).to eq([[:customer, [:address, :country]]])
    expect(payload).to eq(payload_before)
  end
end
