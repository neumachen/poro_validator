module PoroValidator
  module Utils
    # Searches a deeply nested datastructure for a key path, and returns
    # the associated value.
    #
    # @param args [Array] collection of keys/attributes
    # @param block [Proc] block to set value if nil
    #
    # @return associated value or if nil value from passed block.
    #
    # @example fetches a value from a hash or deeply nested hash
    #  options = { user: { location: { address: '123 Street' } } }
    #  options.deep_fetch(:user, :location, :address) #=> '123 Street'
    #
    #  options.deep_fetch(:user, :non_existent_key) do
    #   'a value'
    #  end #=> 'a value'
    module DeepFetch
      class UndefinedPathError < StandardError; end

      def deep_fetch(*args, &block)
        args.reduce(self) do |obj, arg|
          begin
            arg = Integer(arg) if obj.is_a?(Array)
            obj.fetch(arg)
          rescue ArgumentError, IndexError, NoMethodError => e
            break block.call(arg) if block
            raise(
              UndefinedPathError,
              "Could not fetch path (#{args.join(' > ')}) at #{arg}",
              e.backtrace
            )
          end
        end
      end
    end
  end
end
