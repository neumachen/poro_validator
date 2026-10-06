require 'spec_helper'

# Errors#add with a store that is not a PoroValidator::ErrorStore. The store
# is a test fixture that an Errors subclass puts in @store; the gem documents
# no way to supply a store. It answers set?, get and set over a Hash and logs
# them, and logs any reflection call it receives. For an existing entry
# Errors#add reads the store and calls set?, reads the store and calls get
# once, builds the message, then appends it with the #<< of what get
# returned, and returns what #<< returns. Holds for the unmodified gem.
RSpec.describe PoroValidator::Errors, "with a store that is not an ErrorStore", :aggregate_failures do
  # A store over entries (a Hash) that is not an ErrorStore. It logs set?,
  # get and set, and every reflection call, to log; get runs get_entry.
  def foreign_store(log, entries, get_entry = ->(key) { entries.fetch(key) })
    Class.new do
      define_method(:set?) { |key| log << [:set?, key]; entries.key?(key) }
      define_method(:get) { |key| log << [:get, key]; get_entry.call(key) }
      define_method(:set) { |key, value| log << [:set, key, value]; entries[key] = value }
      %i[respond_to? is_a? kind_of? instance_of? class].each do |reflection|
        define_method(reflection) { |*args| log << [reflection, *args]; super(*args) }
      end
      define_method(:respond_to_missing?) { |*args| log << [:respond_to_missing?, *args]; super(*args) }
      define_method(:method_missing) do |name, *args, &block|
        log << [:method_missing, name]
        super(name, *args, &block)
      end
      private :respond_to_missing?, :method_missing
    end.new
  end

  # An Errors whose store is store; each read of the store is logged.
  def errors_with(log, store)
    Class.new(PoroValidator::Errors) do
      define_method(:initialize) { @store = store }
      define_method(:store) do
        log << [:store]
        super()
      end
    end.new
  end

  # Configures one message for the block only, then restores the message
  # table it found.
  def with_message(name, builder)
    table = PoroValidator.configuration.message.instance_variable_get(:@messages)
    previous = table.dup
    PoroValidator.configure { |config| config.message.set(name, builder) }
    yield
  ensure
    table.replace(previous)
  end

  it "reads the store, calls #set? and #get once, builds the message, then appends to what #get returned" do
    log = []
    messages = ["first"]
    errors = errors_with(log, foreign_store(log, { name: messages }))

    returned = with_message(:foreign_second, -> { log << [:message]; "second" }) do
      errors.add(:name, :foreign_second)
    end

    expect(log).to eq([[:store], [:set?, :name], [:store], [:get, :name], [:message]])
    expect(returned).to be(messages)
    expect(messages).to eq(["first", "second"])
  end

  it "returns what the #<< of #get's result returns, even when it is not an Array" do
    log = []
    returned_by_append = Object.new
    recipient = Object.new
    recipient.define_singleton_method(:<<) { |message| log << [:<<, message]; returned_by_append }
    errors = errors_with(log, foreign_store(log, { name: recipient }))

    returned = with_message(:foreign_second, -> { log << [:message]; "second" }) do
      errors.add(:name, :foreign_second)
    end

    expect(log).to eq([[:store], [:set?, :name], [:store], [:get, :name], [:message], [:<<, "second"]])
    expect(returned).to be(returned_by_append)
  end

  it "builds no message when #get raises" do
    log = []
    entries = { name: ["first"] }
    errors = errors_with(log, foreign_store(log, entries, ->(_key) { raise KeyError, "get failed" }))

    with_message(:foreign_second, -> { log << [:message]; "second" }) do
      expect { errors.add(:name, :foreign_second) }.to raise_error(KeyError, "get failed")
    end

    expect(log).to eq([[:store], [:set?, :name], [:store], [:get, :name]])
    expect(entries).to eq(name: ["first"])
  end

  it "appends nothing when building the message raises" do
    log = []
    messages = ["first"]
    errors = errors_with(log, foreign_store(log, { name: messages }))

    with_message(:foreign_failing, -> { log << [:message]; raise ArgumentError, "message failed" }) do
      expect { errors.add(:name, :foreign_failing) }.to raise_error(ArgumentError, "message failed")
    end

    expect(log).to eq([[:store], [:set?, :name], [:store], [:get, :name], [:message]])
    expect(messages).to eq(["first"])
  end

  it "lets an exception from #<< through, after building the message" do
    log = []
    recipient = Object.new
    recipient.define_singleton_method(:<<) { |message| log << [:<<, message]; raise IOError, "append failed" }
    errors = errors_with(log, foreign_store(log, { name: recipient }))

    with_message(:foreign_second, -> { log << [:message]; "second" }) do
      expect { errors.add(:name, :foreign_second) }.to raise_error(IOError, "append failed")
    end

    expect(log).to eq([[:store], [:set?, :name], [:store], [:get, :name], [:message], [:<<, "second"]])
  end

  it "builds the message and sets a new entry when the store has none" do
    log = []
    entries = {}
    errors = errors_with(log, foreign_store(log, entries))

    returned = with_message(:foreign_first, -> { log << [:message]; "first" }) do
      errors.add(:name, :foreign_first)
    end

    expect(log).to eq([[:store], [:set?, :name], [:store], [:message], [:set, :name, ["first"]]])
    expect(returned).to eq(["first"])
    expect(returned).to be(entries[:name])
  end

  it "does not call a #__append__ the store happens to define" do
    log = []
    messages = ["first"]
    store = foreign_store(log, { name: messages })
    store.define_singleton_method(:__append__) { |*| log << [:__append__]; raise "__append__ called" }
    errors = errors_with(log, store)

    returned = with_message(:foreign_second, -> { log << [:message]; "second" }) do
      errors.add(:name, :foreign_second)
    end

    expect(log).to eq([[:store], [:set?, :name], [:store], [:get, :name], [:message]])
    expect(returned).to be(messages)
    expect(messages).to eq(["first", "second"])
  end
end
