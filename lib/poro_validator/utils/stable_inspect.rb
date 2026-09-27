module PoroValidator
  module Utils
    # Renders a value the way Hash#inspect did before Ruby 3.4
    # ({:key=>value}), so error messages and nested error keys read the same
    # on every Ruby version. Values other than hashes and arrays use their own
    # #inspect.
    #
    # @param value [Object] value to render
    #
    # @return [String]
    #
    # @example
    #  StableInspect.call({ in: 1..10 }) #=> "{:in=>1..10}"
    #  StableInspect.call({ address: { country: :code } })
    #  #=> "{:address=>{:country=>:code}}"
    module StableInspect
      def self.call(value)
        case value
        when ::Hash
          pairs = value.map { |key, val| "#{call(key)}=>#{call(val)}" }
          "{#{pairs.join(', ')}}"
        when ::Array
          "[#{value.map { |item| call(item) }.join(', ')}]"
        else
          value.inspect
        end
      end
    end
  end
end
