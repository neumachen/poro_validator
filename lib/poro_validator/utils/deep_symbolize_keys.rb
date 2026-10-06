module PoroValidator
  module Utils
    # Returns a plain Hash copy of a Hash with every direct key converted to
    # a Symbol, applied recursively to any direct Hash values. Does not
    # reopen or extend ::Hash: the caller's object (and any nested Hash
    # inside it) is only ever read, never mutated or given new singleton
    # ancestors, so a frozen root or nested Hash works the same as a mutable
    # one. Arrays, and Hashes found inside Arrays, are left exactly as given
    # (not copied, not key-converted) -- this is not a full deep copy.
    #
    # A key that raises when #to_sym is called on it keeps its original
    # value, as before. Hash iteration order is preserved, so when a
    # String-keyed and Symbol-keyed form of the same logical key are both
    # present, the later one (in the source Hash's insertion order) wins.
    #
    # @param hash [Hash] the Hash to convert
    #
    # @return [Hash] a new Hash with Symbol keys where conversion succeeded
    #
    # @example
    #  DeepSymbolizeKeys.call({ "name" => "Ada" }) #=> { name: "Ada" }
    #  DeepSymbolizeKeys.call({ "address" => { "line1" => "x" } })
    #  #=> { address: { line1: "x" } }
    module DeepSymbolizeKeys
      def self.call(hash)
        result = {}
        hash.each do |key, value|
          sym_key = begin
            key.to_sym
          rescue
            key
          end
          result[sym_key] = value.is_a?(::Hash) ? call(value) : value
        end
        result
      end
    end
  end
end
