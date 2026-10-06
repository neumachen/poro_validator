module PoroValidator
  module Validators
    class NumericValidator < BaseClass
      INTEGER_MATCHER = /\A[-+]?(\d+|\d{1,3}(,\d{3})*)\z/.freeze
      FLOAT_MATCHER   = /\A[-+]?(\d+|\d{1,3}(,\d{3})*)(\.\d+)\z/.freeze

      VALID_OPTIONS = [
        :extremum, :max, :min, :in
      ].freeze

      def validate(attribute, value, options)
        return if value.nil?

        unless is_numeric?(value.to_s, INTEGER_MATCHER) ||
            is_numeric?(value.to_s, FLOAT_MATCHER)
          errors.add(attribute, :integer_or_float)
          return
        end

        message = options[:message] || :numeric

        validate_numeric_options(options.keys)

        cmp = cmp_value(value)
        pb  = policy_b_native?(cmp)

        options.each do |k, v|
          next if k == :message

          case k
          when :min, :max, :extremum
            unless valid_scalar_bound?(v)
              raise ::PoroValidator::InvalidValidator.new(
                "Invalid option: #{k} => #{v.inspect}"
              )
            end
            ok = if pb
              case k
              when :min      then cmp_op(cmp, v, :>=)
              when :max      then cmp_op(cmp, v, :<=)
              when :extremum then cmp_op(cmp, v, :==)
              end
            else
              case k
              when :min      then cmp >= v
              when :max      then cmp <= v
              when :extremum then cmp == v
              end
            end
            errors.add(attribute, message, k => v) unless ok
          when :in
            ok = if v.instance_of?(::Range)
              unless valid_range_bound?(v)
                raise ::PoroValidator::InvalidValidator.new(
                  "Invalid option: #{k} => #{v.inspect}"
                )
              end
              if pb
                range_covers?(cmp, v)
              else
                v.cover?(cmp)
              end
            elsif v.instance_of?(::Array)
              unless valid_array_bound?(v)
                raise ::PoroValidator::InvalidValidator.new(
                  "Invalid option: #{k} => #{v.inspect}"
                )
              end
              if pb
                array_includes?(cmp, v)
              else
                v.include?(cmp)
              end
            else
              raise ::PoroValidator::InvalidValidator.new(
                "Invalid option: #{k} => #{v.inspect}"
              )
            end
            errors.add(attribute, message, k => v) unless ok
          end
        end
      end

      private

      # Finite Float predicate
      FINITE_FLOAT = ->(v) { v.is_a?(::Float) && v.finite? }

      # Only built-in Integer or finite Float: no subclasses.
      def valid_scalar_bound?(v)
        (v.instance_of?(::Integer) || v.instance_of?(::Float)) && v.finite?
      end

      # Built-in Range with Integer/finite-Float or nil endpoints.
      def valid_range_bound?(v)
        v.instance_of?(::Range) &&
          (v.begin.nil? || valid_scalar_bound?(v.begin)) &&
          (v.end.nil?   || valid_scalar_bound?(v.end))
      end

      # Built-in Array of Integer/finite-Float elements.
      def valid_array_bound?(v)
        v.instance_of?(::Array) && v.all? { |e| valid_scalar_bound?(e) }
      end

      # Policy B applies to native numbers and parsed results:
      # Integer, Float, Rational.
      def policy_b_native?(v)
        v.instance_of?(::Integer) || v.instance_of?(::Float) || v.instance_of?(::Rational)
      end

      # Parse a recognised numeric String to its internal comparison value.
      # Policy B: Integer text → base-10 Integer; decimal text → exact Rational.
      # Native Integer and Float pass through unchanged.
      def cmp_value(value)
        if value.is_a?(::String)
          s = value.delete(',')
          if s =~ INTEGER_MATCHER
            Integer(s, 10)
          else
            Rational(s)
          end
        else
          value
        end
      end

      # Compare two numeric values under Policy B:
      # each Float operand is converted to its exact Rational representation
      # via Float#to_r before the operation.
      def cmp_op(a, b, op)
        a = a.to_r if a.instance_of?(::Float)
        b = b.to_r if b.instance_of?(::Float)
        a.send(op, b)
      end

      # Range membership under Policy B: check both endpoints with cmp_op.
      def range_covers?(value, range)
        lower = range.begin
        upper = range.end
        excl  = range.exclude_end?

        ok_lower = lower.nil? || cmp_op(value, lower, :>=)
        ok_upper = upper.nil? || (excl ? cmp_op(value, upper, :<) : cmp_op(value, upper, :<=))
        ok_lower && ok_upper
      end

      # Array membership under Policy B: any element compares equal.
      def array_includes?(value, array)
        array.any? { |elem| cmp_op(value, elem, :==) }
      end

      def validate_numeric_options(options_keys)
        opts = options_keys - VALID_OPTIONS - [:message]

        return if opts.length <= 0

        unless VALID_OPTIONS.include?(opts)
          raise ::PoroValidator::InvalidValidator.new(
            "Invalid options: #{opts.inspect} passed for numeric validator."
          )
        end
      end

      def is_numeric?(v, regex_match)
        v =~ regex_match
      end
    end
  end
end