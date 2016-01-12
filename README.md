# PORO Validator #

[![Gem Version][GV img]][Gem Version]
[![Build Status][BS img]][Build Status]
[![Dependency Status][DS img]][Dependency Status]
[![Code Climate][CC img]][Code Climate]
[![Coverage Status][CS img]][Coverage Status]

PoroValidator is a lightweight validation library for your
**P**lain **O**ld **R**uby **O**bjects (hence PoroValidator).

I always believed that validation is a seperate concern and should not be defined in the object
that you are going to be validating. This validator library aims to seperate the validation to a
seperate concern giving it great flexibility and scalability.

It is framework agnostic and can be used on any plain old ruby object/entities.

#### ActiveRecord/ActiveModel::Validations
While [ActiveModel::Validations] is great if you've got simple validation logic,
it doesn't cut it for complex validations needs. When you have different validation
for the same object at each point in it's life cycle, you need something more flexible.

The problem with [ActiveModel::Validations] is that it hooks pretty deep into [ActiveRecord].
The main use case for [ActiveModel::Validations] is to prevent bad data hitting your
database - which isn't always the case (sometimes we want to allow bad data to go through).
PoroValidator decouples your validation logic from your object structure. With
PoroValidator you can define different validation rules for different contexts.
So instead of *objective* validation where the validation is defined in the object
you want to validate we define it in a seperate class making it *subjective*.

## Features ##
- **Familiar, simple and consistent API.**
- **Framework agnostic, all you need is a PORO**.
- **Validate Hash objects! Good for params, json objects what have you!**
- **Validation logic is decoupled from business logic by creating seperate *validator* classes
  which allows easy testing for the validator class**.
- **No magic, caller is in control.**
- **Invalid validations does not necessitate inability to persist to database**.
- [**Conditional Validations via `:if` and `:unless`.**](#conditional-validations)
- [**Nested validations for nested object structures - nicely handling nested errors.**](#nested-validations)
- [**Composable validations by reusing existing validators.**](#composable-validations)
- [**Create custom validators.**](#custom-validators)
- **Overrideable messages either via the ```:message``` option or through the configuration.**
- **Easily test validator classes.**

## Installation ##

Add this line to your application's Gemfile:

```ruby
gem 'poro_validator'
```

And then execute:

```ruby
$ bundle install
```

Or install it yourself as:

```ruby
$ gem install poro_validator
```

## Usage ##

### Creating and using a validator ###
```ruby
# Create a validator
class CustomerValidator
  include PoroValidator.validator

  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :age, numeric: { min: 18 }
end

validator = CustomerValidator.new

# Validate entity
customer = CustomerDetail.new
validator.valid?(customer) # => false
validator.errors.full_messages # => ["last name is not present", "..."]

# Validate hash
customer = {}
validator.valid?(customer) # => false
validator.errors.full_messages # => ["last name is not present", "..."]
```

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
##### Value must be either an integer or can be casted as one
##### Options:
- `extremum:` min and max
- `min:` minimum
- `max:` maximum

```
  validates :foo, numeric: 1..10
  validates :boo, numeric: { extremum: 5 }
  validates :zoo, numeric: { min: 10, max: 20 }
  validates :moo, numeric: { min: 10 }
  validates :goo, numeric: { max: 20 }
  validates :loo, numeric: 1..10, if: proc { false }
```

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

### Error Messages ###

#### #configure
The ```message``` configuration object, allows you to change the default error message produced by each validator. The message must be in the form of a lambda or Proc, and may or may not receive an argument. Use the example below for reference when customizing messages.

```ruby
PoroValidator.configure do |config|
    config.message.set(:numeric, lambda { "is not a number" })
    config.message.set(:presence, lambda { "is not present" })
    config.message.set(:inclusion, lambda { |set| "not in the set: #{set.inspect}")
    ...
end
```

#### #on method
The `on` method is used to acccess the error messages related to a key or attribute/method.

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
You can pass in conditional

```ruby
class CustomerValidator
  include PoroValidator.validator

  validates :last_name, presence: { unless: :foo_condition }
  validates :first_name, presence: { if: lambda { true } }
  validates :dob, presence: { if: :method_in_the_validator_class }
  validates :age, presence: { if: :entity_method }
  validates :address do
    validates :line1, presence: { if: 'entity.nested_entity.method' }
  end
```

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
    validates :line2, presence: true
    validates :city,  presence: true
    validates :country do
      validates :iso_code,   presence: true
      validates :short_name, presence: true
      validates :coordinates do
        validates :longtitude, presence: true
        validates :latitude,   presence:true
        validates :planet do
          validates :name, presence: true
        end
      end
    end
  end
end

entity = CustomerDetailEntity.new
validator = CustomerDetailValidator.new
validator.valid?(entity)
validator.errors.full_messages # => [
  "customer_id is not present",
  "{:customer=>:first_name} is not present",
  "{:customer=>:last_name} is not present",
  "{:address=>{:country=>{:coordinates=>:longtitude}}} is not present",
  "{:address=>{:country=>{:coordinates=>:latitude}}} is not present",
  "{:address=>{:country=>{:coordinates=>{:planet=>:name}}}} is not present"
]
```

## Composable Validations ##

```ruby
# Create a validators
class CustomerValidator
  include PoroValidator.validator

  validates :last_name, presence: true
  validates :first_name, presence: true
  validates :age, numeric: { min: 18 }
end

class AddressValidator
  include PoroValidator.validator

  validates :line1, presence: true
  validates :lin2, presence: true
  validates :city, presence: true
  validates :state, presence: true
  validates :zip_code, format: /[0-9]/
end

# Create another validator and use the existing validator class as an option

class CustomerValidator
  include PoroValidator.validator

  validates :customer, with: CustomerValidator
  validates :address, with: AddressValidator
end

# Create an entities
class CustomerDetailEntity
  attr_accessor :customer
  attr_accessor :address
end

customer_detail = CustomerDetailEntity.new

# Validate entity

validator = CustomerValidator.new
validator.valid?(customer_detail) # => false
validator.errors.full_messages # => [
  "customer" => "last name is not present", ".."
  "address" => "line1 is not present", ".."
]
```

## Maintainers

- [magicalbanana](https://github.com/magicalbanana)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/magicalbanana/poro_validator. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## Copyright

Copyright (c) 2015 Kareem Gan

[Gem Version]: https://badge.fury.io/rb/poro_validator
[Build Status]: https://travis-ci.org/magicalbanana/poro_validator
[travis pull requests]: https://travis-ci.org/magicalbanana/poro_validator/pull_requests
[Dependency Status]: https://gemnasium.com/magicalbanana/poro_validator
[Code Climate]: https://codeclimate.com/github/magicalbanana/poro_validator
[Coverage Status]: https://coveralls.io/r/magicalbanana/poro_validator

[GV img]: https://badge.fury.io/rb/poro_validator.svg
[BS img]: https://travis-ci.org/magicalbanana/poro_validator.svg
[DS img]: https://gemnasium.com/magicalbanana/poro_validator.svg
[CC img]: https://codeclimate.com/github/magicalbanana/poro_validator.svg
[CS img]: https://coveralls.io/repos/magicalbanana/poro_validator/badge.svg?branch=master&service=github

[ActiveModel::Validations]: http://api.rubyonrails.org/classes/ActiveModel/Validations.html
[ActiveRecord]: http://guides.rubyonrails.org/active_record_validations.html
