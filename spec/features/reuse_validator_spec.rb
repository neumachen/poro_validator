require 'spec_helper'

RSpec.describe "Allows initialized validations to be reused", type: :feature do
  it "allows reuse of the validation class" do
    widget = Struct.new(:name, :size)
    validator = Class.new do
      include PoroValidator.validator

      validates :name, inclusion: 'c'..'d'
      validates :size, numeric: 2..3
    end

    widgets = ('a'..'d').map.with_index(1) do |n, s|
      widget.new(n, s)
    end

    wv = validator.new
    errors = widgets.map { |w| wv.valid?(w); wv.errors }
    expect(
      errors.map(&:empty?)
    ).to eq([false, false, true, false])
  end

  # Story:
  # @pid
  # Widget = Struct.new(:name, :size)
  #
  # class WV
  #   include PoroValidator.validator
  #   validates :name, inclusion: 'c'..'d'
  #   validates :size, numeric: 2..3
  # end
  #
  # widgets = ('a'..'d').map.with_index(1) do |n, s|
  #   Widget.new(n, s)
  # end
  #
  # # actual validity:
  # aaa = widgets.map { |w| WV.new.valid?(w) }
  # puts aaa.join(" ")
  # #=> [false, false, true, false]
  #
  # # but when reusing a validator instance:
  # wv = WV.new
  # errors = widgets.map { |w| wv.valid?(w); wv.errors }
  # puts (errors.map(&:empty?)).join(" ")
  # #=> [false, false, false, false]
  #
  # require 'pry'; binding.pry
  # # because:
  # widgets.map { |w| wv.valid?(w); wv.errors.object_id }.uniq.size
  # #=> 1
end
