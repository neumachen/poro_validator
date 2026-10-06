[ActiveModel::Validations]: http://api.rubyonrails.org/classes/ActiveModel/Validations.html
[ActiveRecord]: http://guides.rubyonrails.org/active_record_validations.html
[S.O.L.I.D]: https://en.wikipedia.org/wiki/SOLID_(object-oriented_design)
[Single Responsibility Principle]: https://en.wikipedia.org/wiki/Single_responsibility_principle
[Ruby on Rails]: http://rubyonrails.org/
[PoroValidator]: https://github.com/magicalbanana/poro_validator
[WIKI]: https://github.com/magicalbanana/poro_validator/wiki

# PORO Validator #

PoroValidator is a lightweight validation library for your
**P**lain **O**ld **R**uby **O**bjects (hence PoroValidator).

Based on the [Single Responsibility Principle] approach.

This validator library implements the single responsibility approach from the
[S.O.L.I.D] principle.

By using this approach we can create validations for our object that can be
easily tested, maintained and scaled.

##TL;DR

- [Features](#features)
- [Installation](#installation)
- [Synopsis](#synopsis)
- [Validators](#validators)
- [WIKI]

### Author's POV
I always believed an object's validation is a separate concern, and should
not be embedded in the object whose validity is in question.

The library I created is framework agnostic and can be used on any plain
old Ruby object (as long as the object responds to the attribute that
requires validation it will validate it, this includes **Hash Objects**).

Here's an example scenario:

A common pattern with [Ruby on Rails] and [ActiveRecord] is to only
validate an object after an ActiveRecord record has been constructed from
incoming parameters. With this library you can instead validate the
incoming parameters directly, at the boundary of your application, without
first constructing an ActiveRecord object. (Constructing an in-memory
record is a separate concern from reading or writing it to a database.
PoroValidator itself does not require a database or perform persistence;
however, a custom validator, a condition, or an attribute method invoked
during validation is ordinary Ruby code, and any of them may still read
from or write to a database or other external state.)

How you handle the state of that validation (whether it's valid or not) is up
to you (e.g, return the object so the user's form is still filled and not blank).

#### ActiveRecord/ActiveModel::Validations
[ActiveModel::Validations] is not exclusive to [ActiveRecord] -- it can be
included in any Ruby class. (Rails' own [ActiveModel::Validations] API
documentation for the 4.2 series demonstrates this with a plain Ruby
`Person` class that isn't backed by ActiveRecord or a database; see
https://api.rubyonrails.org/v4.2.11.3/classes/ActiveModel/Validations.html.
This shows a historical capability of the library, not a claim about any
particular Rails version in use elsewhere.)

As your application grows you want to have more complex validations (think
of normalized tables where your application has numerous join tables) when
processing incoming parameters which are most likely going to be nested; we
would need a validator that can handle nested objects and return the
associated errors for the invalid attributes properly. Another scenario is
that throughout the life cycle of an object we would also want different
validations, e.g. if the validation is dependent on the state of an
object. So we need a validator that's more flexible, enter [PoroValidator].

PoroValidator keeps this preference: instead of the object validating
itself by defining the validation within the object, you create separate
validation classes, which gives more flexibility while adhering to the
[Single Responsibility Principle]. PoroValidator decouples your validation
logic from your object structure, and lets you define different
validation rules for different contexts. PoroValidator itself does not
require a database and does not perform persistence; it does not
guarantee that a passing `valid?` result means the data satisfies
database integrity, since conditions, custom validators and the
attribute accessors it invokes may themselves perform database or other
external I/O. What you do with the validation result (for example,
whether invalid data is still persisted) remains entirely up to the
caller.

## Features ##
- **Familiar, simple and consistent API.**
- **Framework agnostic, all you need is a PORO**.
- **No magic, caller is in control, invalid validations does not necessitate
inability to persist to database**.
- [**Conditional Validations**](#conditional-validations)
- [**Nested validations**](#nested-validations)
- [**Composable/DRY validations**](#composable-validations)
- [**Custom validators.**](#custom-validators)
- **Configurable messages**
- **SpecHelper for testing validation classes [WIP]
(https://github.com/magicalbanana/poro_validator/issues/25)**

Feel free the peruse the [WIKI] pages for more information!

## Installation ##

Add this line to your application's Gemfile:

```ruby
gem 'poro_validator'
```

And then execute:

```sh
$ bundle install
```

Or install it yourself as:

```sh
$ gem install poro_validator
```

### Ruby support ###

Requires Ruby ≥ 3.4. Tested on Ruby 4.0.7 and 3.4.11. See
[DEVELOPMENT.md](DEVELOPMENT.md) for the container-based workflow and
supported versions.

## Synopsis ##

### Creating and using a validator ###
```ruby
Address = Struct.new(:line1, :line2, :city, :zip_code)
Customer = Struct.new(:first_name, :last_name, :age, :address)

class CustomerValidator
  include PoroValidator.validator

  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :age, numeric: { min: 18 }
  validates :address do
    validates :line1, presence: true
    validates :line2, presence: true
    validates :city, presence: true
    validates :zip_code, format: /\A[0-9]+\z/
  end
end

validator = CustomerValidator.new

# A valid Ruby object
valid_customer = Customer.new("Ada", "Lovelace", 36,
  Address.new("221B Baker St", "Flat 2", "London", "90210"))
validator.valid?(valid_customer) # => true
validator.errors.full_messages   # => []

# An invalid Ruby object -- several rules fail at once, including a nested one
invalid_customer = Customer.new(nil, nil, 10,
  Address.new(nil, nil, nil, "abc"))
validator.valid?(invalid_customer) # => false
validator.errors.full_messages
# => ["last_name is not present", "first_name is not present",
#     "age does not match the numeric options: {:min=>18}",
#     "{:address=>:line1} is not present", "{:address=>:line2} is not present",
#     "{:address=>:city} is not present",
#     "{:address=>:zip_code} does not match the pattern: /\\A[0-9]+\\z/"]

# A Hash works the same way -- here only :first_name is missing
hash_customer = {
  first_name: nil,
  last_name: "Lovelace",
  age: 36,
  address: { line1: "221B Baker St", line2: "Flat 2", city: "London", zip_code: "90210" }
}
validator.valid?(hash_customer)  # => false
validator.errors.full_messages   # => ["first_name is not present"]
```

### Hash input ###

A Hash passed as the root entity to `valid?` is normalized before
validation: every key of that Hash, and every key of a Hash found as a
*direct* value inside it (recursively through nested Hash values only),
is converted to a Symbol where possible (a key that does not respond
usably to `#to_sym` is kept as-is). This works the same for a frozen Hash
as for a mutable one, and for frozen nested Hashes too.

An arbitrary Hash found several levels down inside a non-Hash Ruby
object's attribute graph is not covered by this normalization -- only the
Hash actually passed to `valid?`, and Hashes directly nested inside it,
are converted.

```ruby
class NameValidator
  include PoroValidator.validator
  validates :name, presence: true
end

validator = NameValidator.new
frozen_input = { "name" => nil }.freeze
validator.valid?(frozen_input) # => false
validator.errors.full_messages # => ["name is not present"]
frozen_input.frozen?           # => true, unchanged
```

Normalizing a frozen Hash for this String-vs-Symbol-key conversion does
not itself prevent validation from running or raising for unrelated
reasons (for example a nested rule that cannot find an expected key).
This example only shows that the key-normalization step itself does not
raise and does not mutate the caller's frozen Hash.

Only the Hash itself (and Hashes nested directly inside it) are copied and
key-converted. An Array, and any Hash found inside an Array, is passed
through unchanged -- this is not a full deep copy. When a String-keyed and
a Symbol-keyed form of the same logical key are both present, the later
one in the source Hash's insertion order wins, silently.

**Compatibility:** requiring `poro_validator` does not add or replace any
method on Ruby's built-in `Hash` class. The previous implementation
defined `Hash#deep_symbolize_keys` and `Hash#deep_transform_keys` globally
on every Hash in the process; this gem no longer defines them. If another
library in your application supplies methods of the same name, they are
unaffected and remain available. If your application relied on calling
them directly (outside of this gem), add your own implementation or a
library that provides them.

## Validators ##

### Default Validators ###
- [exclusion_validator](#exclusion-validator)
- [float_validator](#float-validator)
- [format_validator](#format-validator)
- [inclusion_validator](#inclusion-validator)
- [integer_validator](#integer-validator)
- [length_validator](#length-validator)
- [numeric_validator](#numeric-validator)
- [presence_validator](#presence-validator)
- [with_validator](#with-validator)

#### Exclusion Validator ####
##### Option:
- `in:` responds to an Array, Range or Set

```
  validates :foo, exclusion: 5..10
  validates :boo, exclusion: [1,2,3,4,5]
  validates :zoo, exclusion: { in: [1,2,3,4,5] }
  validates :moo, exclusion: 5..10, if: proc { false }
```

#### Float Validator ####
```
  validates :foo, float: true
  validates :boo, float: true, if: proc { false }
```

##### Compatibility notes
`float` checks the value's shape, not a numeric range. If a `min:`,
`max:`, `in:` or `extremum:` option is also given, the rule raises
`PoroValidator::InvalidValidator` when it executes against a non-nil
value -- these options are not supported by `float`. A `nil` value
returns before options are checked, and a failing `:if`/`:unless`
condition skips execution entirely, so either of those avoids the raise.
Use [numeric](#numeric-validator) for range/bound comparisons.

#### Format Validator ####
##### Option
- `with` pass in regex or string

```
  validates :foo, format: /[a-z]/
  validates :boo, format: { with: /[a-z]/ }
```

#### Inclusion Validator ####
##### Option
```
  validates :foo, inclusion: 1..10
  validates :boo, inclusion: { in: [1,2,3,4,5] }
  validates :zoo, inclusion: { in: 1..10 }
```

#### Integer Validator ####
```
  validates :foo, integer: true
  validates :boo, integer: true, if: proc { false }
```

##### Compatibility notes
Same as `float` above: `integer` checks the value's shape, not a numeric
range. A `min:`, `max:`, `in:` or `extremum:` option raises
`PoroValidator::InvalidValidator` when the rule executes against a
non-nil value; `nil` input returns before options are checked, and a
skipped (`:if`/`:unless`) condition avoids the raise entirely. Use
[numeric](#numeric-validator) for range/bound comparisons.

#### Length Validator ####
##### Value must be either a string or can be casted as one
##### Options:
- `extremum:` min and max
- `min:` minimum
- `max:` maximum

```
  validates :foo, length: 1..10
  validates :boo, length: { extremum: 1 }
  validates :zoo, length: { min: 10, max: 20 }
  validates :moo, length: { min: 10 }
  validates :goo, length: { max: 10 }
  validates :loo, length: 1..10, if: proc { false }
```

#### Numeric Validator ####
##### Value must be a numeric-looking Integer, Float or String
Accepted inputs: native Integers, finite Floats whose `to_s` does not use
exponent notation, or Strings whose spelling matches an integer or decimal
number (optional sign, comma-grouped thousands, decimal point with fractional
digits). Decimal Strings denote their exact base-10 value; `"010"` → 10,
`"08"` → 8. Finite Floats retain their actual stored numeric value.

##### Options:
- `extremum:` exact value
- `min:` minimum (inclusive)
- `max:` maximum (inclusive)
- `in:` a built-in `Range` (inclusive/exclusive, beginless/endless, mixed
  Integer/Float endpoints) or a built-in `Array` of Integers and finite
  Floats (including mixed members; empty Array matches nothing)

```
  validates :foo, numeric: 1..10
  validates :boo, numeric: { extremum: 5 }
  validates :zoo, numeric: { min: 10, max: 20 }
  validates :moo, numeric: { min: 10 }
  validates :goo, numeric: { max: 20 }
  validates :loo, numeric: 1..10, if: proc { false }
```

##### Custom Messages
You can override the default `:numeric` error with `message:`:

```ruby
validates :foo, numeric: { min: 1, max: 10, message: "is not within the range" }
```

##### Float bound comparison

Because `"0.1"` denotes the exact decimal 1/10 and `Float 0.1` is slightly
larger (≈ 0.10000000000000000555), `"0.1"` passes `max: 0.1` but fails
`min: 0.1` and `extremum: 0.1`. Native `Float 0.1` values satisfy all three:

```ruby
# "0.1" denotes exact 1/10; Float 0.1 is slightly larger
Class.new do
  include PoroValidator.validator
  validates :v, numeric: { max: 0.1 }
end.new.valid?(v: "0.1")  # => true

Class.new do
  include PoroValidator.validator
  validates :v, numeric: { min: 0.1 }
end.new.valid?(v: "0.1")  # => false

# Native Float 0.1 still satisfies exact equality
Class.new do
  include PoroValidator.validator
  validates :v, numeric: { extremum: 0.1 }
end.new.valid?(v: 0.1)    # => true
```

##### Compatibility notes

- Native finite Floats whose `to_s` uses exponent notation (e.g. `1.0e20`)
  are still rejected by the recognition gate.
- `in:` accepts **built-in** `Range` and `Array`, not subclasses.
- `Rational`, `Float::INFINITY` and `Float::NAN` are rejected as bounds.
- Invalid configuration is checked during validation, not at declaration
  time. `nil` input and malformed text skip configuration checks.
- Custom messages are metadata keys and do not add numeric constraints.

- Recognized String input is parsed only for internal numeric comparisons.
  Caller values are never replaced or mutated. Custom objects are not
  universally coerced through `to_s`. Only native Integers, finite Floats
  (without exponent notation) and Strings are supported for exact numeric
  comparison.

#### Presence Validator ####
```
  validates :foo, presence: true
  validates :boo, presence: true, if: proc { false }
```

#### With Validator ####
Options:
- `:with` requires an existing validator class to be passed

```
  validates :foo, with: ExistingValidator
```

### Custom Validators ###
Creating validators is easy! Just follow the example below!

```ruby
module PoroValidator
  module Validators
    class CustomValidator < BaseClass

      def validate(attribute, value, options)
        message = options[:message] || "custom validator message"
        # your validation logic code goes here..

        # add error message if validation fails
        errors.add(attribute, message, options)
      end
    end
  end
end
```

#### Note when creating custom validators
You can either define the error message in your validator like shown above or
define it via the [PoroValidator.configuration](#error-messages)

Each `validates` declaration creates one instance of your validator, which
every instance of the declaring class, and of its subclasses, reuses. Keep
per-call state out of its instance variables. On the thread or fiber that runs
`validate`, the `context`, `errors` and `value` helpers refer to that call,
even while another validator instance is validating. Reading `@context`,
`@errors` or `@value` directly, or calling the helpers from a thread or fiber
that `validate` starts, doesn't get that isolation: it gives the most recent
call's state, which another validator instance may have replaced.

### Error Messages ###

#### #configure
The `message` configuration object, allows you to change the default error
message produced by each validator. The message must be in the form of a `lambda`
or `Proc`, and may or may not receive an argument. Use the example below for
reference when customizing messages.

Because `configure` changes global, process-wide message defaults, run
this in its own process (or restore the previous messages afterward) if
other code in the same process depends on the default messages.

```ruby
PoroValidator.configure do |config|
  config.message.set(:numeric, lambda { "is not a number" })
  config.message.set(:presence, lambda { "cannot be blank" })
  config.message.set(:inclusion, lambda { |set| "not in the set: #{set.inspect}" })
end

class ItemValidator
  include PoroValidator.validator
  validates :sku, presence: true
end

validator = ItemValidator.new
validator.valid?(sku: nil)     # => false
validator.errors.full_messages # => ["sku cannot be blank"]
```

#### #on method
The `on` method is used to acccess the error messages related to a key or
attribute/method. The examples below assume `validator` is an instance that
has already called `valid?` on some entity, as in the Synopsis above.

##### unnested validations
Pass in either a symbol or a string

```ruby
validator.errors.on(:attribute) || validator.errors.on("attribute")
```

##### nested validations
Pass in a nested hash structure reflective of the object that was validated

```ruby
validator.errors.on({address: :line1})
validator.errors.on({address: {city: :locality}})
validator.errors.on({address: {country: {coordinates: {planent: :name}}}})
```

## Conditional Validations ##
Pass `if:` or `unless:` a Proc, a lambda, a String, or a Symbol. `if:` runs the
rule when the condition's result is true, and `unless:` when it is false. As in
Ruby, `nil` and `false` count as false; any other result, including `0`, `""` and
`[]`, counts as true.

A Symbol is called on the **validating instance** (the validator object that
included `PoroValidator.validator`), receiving exactly one argument: the entity
being validated. This means Symbol conditions can use private or protected
methods, inherited methods, and subclass overrides through ordinary Ruby method
lookup — they are not evaluated on the entity or the Context.

```ruby
Customer = Struct.new(:first_name, :last_name, :email, :registered, :guest,
                      keyword_init: true)

class CustomerValidator
  include PoroValidator.validator

  def self.strict?
    true
  end

  # A lambda without parameters is called without arguments; `self` in it is
  # still the class it was written in.
  validates :last_name, presence: { if: -> { strict? } }

  # Any other Proc or lambda gets one argument, the validation context:
  # context.entity is the object being validated.
  validates :first_name, presence: { if: ->(context) { context.entity.registered } }

  # A String is evaluated on the entity.
  validates :email, presence: { unless: 'guest' }
end

validator = CustomerValidator.new
validator.valid?(Customer.new(guest: true)) # => false
validator.errors.full_messages # => ["last_name is not present"]

validator.valid?(Customer.new(registered: true, guest: false)) # => false
validator.errors.full_messages
# => ["last_name is not present", "first_name is not present", "email is not present"]

# A Symbol calls a method on the validating instance, passing the entity.
# Private/protected methods work via send-style dispatch.
class EntityValidator
  include PoroValidator.validator

  validates :name, presence: { if: :check_name? }

  private

  def check_name?(entity)
    entity.respond_to?(:name)
  end
end

validator = EntityValidator.new

# When the entity has a name field, the rule runs (and fails for nil name)
validator.valid?(OpenStruct.new(name: nil))  # => false, errors: ["name is not present"]

# When the entity lacks a name field, the condition fails and the rule is skipped
validator.valid?(OpenStruct.new(other: "value"))  # => true, no errors
```

Conditions given to `validates` itself apply to every rule in that
declaration; conditions inside one rule's options apply to that rule only.

```ruby
class ReferenceValidator
  include PoroValidator.validator

  # Both rules run only for submitted entities.
  validates :code, presence: true, length: { min: 5 },
    if: ->(context) { context.entity.submitted? }

  # Only the length rule depends on its condition; the format rule always runs.
  validates :reference, length: { min: 5, unless: ->(context) { context.entity.draft? } },
    format: { with: /\A[A-Z0-9]+\z/ }
end
```


Conditions on a nested `validates :attr, if: ..., do ... end` block apply to
every rule inside that block, at every nesting depth, combined with each
rule's own declaration/rule-local conditions (all must pass). Evaluation
order per rule is: outermost block condition, successively inner block
conditions, the rule's own declaration condition, then its rule-local
condition. Every condition uses the same root entity and the actual
validating instance -- not the nested value and not a temporary internal
class -- so a Symbol condition inside a block still calls a method on the
top-level validator, and a String condition still evaluates on the
top-level entity. A false/nil outer condition skips every rule in the
block and, because the skip happens before fetching any nested value, it
never dereferences a missing nested object.

```ruby
class OrderValidator
  include PoroValidator.validator

  # When :submitted? is false, the entire address block is skipped --
  # including both nested rules -- without reading entity.address at all.
  validates :address, if: ->(context) { context.entity.submitted? } do
    validates :line1, presence: true
    validates :country, presence: true
  end
end

validator = OrderValidator.new
unsubmitted = Struct.new(:submitted?, :address).new(false, nil)
validator.valid?(unsubmitted) # => true (block skipped, entity.address never read)

submitted_incomplete = Struct.new(:submitted?, :address).new(true, Struct.new(:line1, :country).new(nil, nil))
validator.valid?(submitted_incomplete) # => false
validator.errors.full_messages
# => ["{:address=>:line1} is not present", "{:address=>:country} is not present"]
```

Non-condition options passed alongside a block declaration (for example a
custom `:message`) are not forwarded to the rules inside that block and
have no effect, the same as before this behavior was added; only `:if` and
`:unless` are read from a block declaration's options.

## Nested Validations ##
```ruby
# validator
class CustomerDetailValidator
  include PoroValidator.validator

  validates :customer_id, presence: true

  validates :customer do
    validates :first_name, presence: true
    validates :last_name,  presence: true
  end

  validates :address do
    validates :line1, presence: true
    validates :coordinates do
      validates :longtitude, presence: true
      validates :latitude,   presence: true
      validates :planet do
        validates :name, presence: true
      end
    end
  end
end

validator = CustomerDetailValidator.new

# A complete, passing fixture -- every required leaf is present.
valid_entity = {
  customer_id: "C-100",
  customer: { first_name: "Ada", last_name: "Lovelace" },
  address: {
    line1: "221B Baker St",
    coordinates: {
      longtitude: 0.0,
      latitude: 51.5,
      planet: { name: "Earth" }
    }
  }
}
validator.valid?(valid_entity) # => true
validator.errors.full_messages # => []

# A self-contained Hash fixture -- no entity classes required.
entity = {
  customer_id: nil,
  customer: { first_name: "Ada", last_name: nil },
  address: {
    line1: "221B Baker St",
    coordinates: {
      longtitude: 0.0,
      latitude: nil,
      planet: { name: nil }
    }
  }
}

validator.valid?(entity) # => false
validator.errors.full_messages
# => ["customer_id is not present",
#     "{:customer=>:last_name} is not present",
#     "{:address=>{:coordinates=>:latitude}} is not present",
#     "{:address=>{:coordinates=>{:planet=>:name}}} is not present"]
```

## Composable Validations ##

```ruby
# Create validators for each sub-object
class PersonValidator
  include PoroValidator.validator

  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :age, numeric: { min: 18 }
end

class AddressValidator
  include PoroValidator.validator

  validates :line1, presence: true
  validates :line2, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip_code, format: /[0-9]/
end

# Compose them into a separate validator class using the existing
# validator classes as :with options.
class CustomerCompositeValidator
  include PoroValidator.validator

  validates :customer, with: PersonValidator
  validates :address, with: AddressValidator
end

# Self-contained entity fixtures
CustomerDetail = Struct.new(:customer, :address)
Person = Struct.new(:first_name, :last_name, :age)
Address = Struct.new(:line1, :line2, :city, :state, :zip_code)

validator = CustomerCompositeValidator.new

valid_entity = CustomerDetail.new(
  Person.new("Ada", "Lovelace", 36),
  Address.new("221B Baker St", "Flat 2", "London", "LDN", "90210")
)
validator.valid?(valid_entity) # => true
validator.errors.full_messages # => []

invalid_entity = CustomerDetail.new(
  Person.new(nil, nil, 10),
  Address.new(nil, nil, nil, nil, "abc")
)
validator.valid?(invalid_entity) # => false
validator.errors.full_messages
# => ["{:customer=>:last_name} is not present", "{:customer=>:first_name} is not present",
#     "{:customer=>:age} does not match the numeric options: {:min=>18}",
#     "{:address=>:line1} is not present", "{:address=>:line2} is not present",
#     "{:address=>:city} is not present", "{:address=>:state} is not present",
#     "{:address=>:zip_code} does not match the pattern: /[0-9]/"]
```

## Composed nested paths

When a composed validator validates a nested attribute, errors reported by
the child are now placed under the complete path, so `errors.on` with an
Array path finds them:

```ruby
class CodeValidator
  include PoroValidator.validator

  validates :country do
    validates :code, length: { min: 2 }, format: { with: /\AUS\z/ }
  end
end

class OrderValidator
  include PoroValidator.validator

  validates :address, with: CodeValidator
end

validator = OrderValidator.new
validator.valid?(address: { country: { code: "x" } })

validator.errors.on([:address, :country, :code])
# => ["does not match the length options: {:min=>2}",
#     "does not match the pattern: /\AUS\z/"]

validator.errors.full_messages
# => ["{:address=>{:country=>:code}} does not match the length options: {:min=>2}",
#     "{:address=>{:country=>:code}} does not match the pattern: /\AUS\z/"]
```

A literal attribute whose name looks like a Ruby Hash, such as
`:'{:country=>:code}'`, remains a single segment and is not reinterpreted
as nested keys.

**Compatibility:** `full_messages` grouping is Hash insertion order.
When a child's errors merge into a path the parent already wrote to, the
existing messages come first, and all messages stay in their original order
within that path. The total message count is unchanged. The old serialized
leaf-key format (`{:address=>:"{:country=>:code}"}`) is no longer produced
for recorded paths; entries without recorded metadata keep the previous
fallback.


## Maintainers

- [magicalbanana](https://github.com/magicalbanana)

## Contributing

Bug reports and pull requests are welcome on GitHub at [PoroValidator].
This project is intended to be a safe, welcoming space for collaboration, and
contributors are expected to adhere to the [Contributor Covenant]
(contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License]
(http://opensource.org/licenses/MIT).

## Copyright

Copyright (c) 2015-2016 Kareem Gan
