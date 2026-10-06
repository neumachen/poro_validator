require 'spec_helper'

# Errors#add appends to an existing entry through the store's public #get:
# after #set? finds the key it calls #get once, appends the message to
# whatever #get returns and returns what #<< returns. The stores below are
# plain ErrorStore subclasses, used through an Errors subclass. Holds for the
# unmodified gem and for the corrected store prototype.
RSpec.describe PoroValidator::Errors, "appending through ErrorStore#get", :aggregate_failures do
  # An Errors whose store is a new instance of store_class.
  def errors_with(store_class)
    store = store_class.new
    errors_class = Class.new(PoroValidator::Errors) do
      define_method(:initialize) { @store = store }
    end
    [errors_class.new, store]
  end

  def with_messages(messages)
    PoroValidator.configure do |config|
      messages.each { |name, message| config.message.set(name, message) }
    end
    yield
  ensure
    PoroValidator.configure { |config| config.message.instance_variable_set(:@messages, {}) }
  end

  let(:recording_store) do
    Class.new(PoroValidator::ErrorStore) do
      def gets
        @gets ||= []
      end

      def get(key)
        gets << key
        super
      end
    end
  end

  let(:redirecting_store) do
    Class.new(PoroValidator::ErrorStore) do
      def gets
        @gets ||= []
      end

      def destination
        @destination ||= ["get-owned"]
      end

      def get(key)
        gets << key
        destination
      end
    end
  end

  let(:failing_store) do
    Class.new(PoroValidator::ErrorStore) do
      def get(key)
        raise KeyError, "get failed"
      end
    end
  end

  it "calls #get once for an existing entry and appends to the Array it returns" do
    errors, store = errors_with(recording_store)
    errors.add([:a, :b], "first")
    expect(store.gets).to eq([])

    returned = errors.add([:a, :b], "second")

    expect(store.gets).to eq([[:a, :b]])
    expect(returned).to eq(["first", "second"])
    expect(returned).to be(store.data["{:a=>:b}"])
  end

  it "appends to a different destination #get returns, and returns it" do
    errors, store = errors_with(redirecting_store)
    errors.add([:a, :b], "stored")

    returned = errors.add([:a, :b], "next")

    expect(store.gets).to eq([[:a, :b]])
    expect(returned).to be(store.destination)
    expect(store.destination).to eq(["get-owned", "next"])
    expect(store.data).to eq("{:a=>:b}" => ["stored"])
  end

  it "does not build the message when #get raises" do
    errors, store = errors_with(failing_store)
    errors.add([:a, :b], "stored")
    built = []

    with_messages(dispatch_probe: -> { built << :message; "next" }) do
      expect { errors.add([:a, :b], :dispatch_probe) }.to raise_error(KeyError, "get failed")
    end

    expect(built).to eq([])
    expect(store.data).to eq("{:a=>:b}" => ["stored"])
  end

  it "reads the store and renders the key for #set?, then again for #get, then builds the message" do
    log = []
    segment = Object.new
    segment.define_singleton_method(:inspect) { log << [:segment, :inspect]; ":seg" }
    store = Class.new(PoroValidator::ErrorStore) do
      define_method(:get) do |key|
        log << [:get, :call]
        super(key)
      end
    end.new
    errors = Class.new(PoroValidator::Errors) do
      define_method(:initialize) { @store = store }
      define_method(:store) do
        log << [:store, :call]
        super()
      end
    end.new
    store.set([:a, segment], ["first"])
    log.clear

    returned = with_messages(dispatch_second: -> { log << [:message, :call]; "second" }) do
      errors.add([:a, segment], :dispatch_second)
    end

    expect(log).to eq([[:store, :call], [:segment, :inspect], [:store, :call], [:get, :call],
                       [:segment, :inspect], [:message, :call]])
    expect(returned).to eq(["first", "second"])
    expect(returned).to be(store.data["{:a=>:seg}"])
  end

  it "returns what #<< returns when #get's result is not an Array" do
    returned_by_append = Object.new
    appended = []
    recipient = Object.new
    recipient.define_singleton_method(:<<) { |message| appended << message; returned_by_append }
    errors, store = errors_with(Class.new(PoroValidator::ErrorStore) { define_method(:get) { |_key| recipient } })
    errors.add([:a, :b], "stored")

    returned = errors.add([:a, :b], "next")

    expect(returned).to be(returned_by_append)
    expect(appended).to eq(["next"])
    expect(store.data).to eq("{:a=>:b}" => ["stored"])
  end
end
