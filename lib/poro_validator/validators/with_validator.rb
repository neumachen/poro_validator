module PoroValidator
  module Validators
    class WithValidator < BaseClass
      def validate(attribute, value, options)
        validator_class = options.fetch(:with)
        case validator_class
        when Class
          klass = validator_class.new
          name = attribute
          wrapped = false

          if nested? && !attribute.flatten.empty?
            # Inside a nested declaration the attribute is a path, and value
            # is what the framework already found there. Route it as below,
            # wrapping a scalar under the path's last name.
            name = attribute.flatten.last
            if value.nil? || value.is_a?(::Symbol) || value.is_a?(::String)
              klass.valid?(name => value)
              wrapped = true
            elsif context.entity.is_a?(::Hash)
              klass.valid?(value || {})
            else
              klass.valid?(value)
            end
          elsif context.entity.is_a?(::Hash)
            entity = context.entity[attribute]

            if entity.nil? || entity.is_a?(::Symbol) || entity.is_a?(::String)
              klass.valid?(attribute => entity)
              wrapped = true
            else
              klass.valid?(context.entity[attribute] || {})
            end
          else
            entity = context.entity.public_send(attribute)
            if entity.nil? || entity.is_a?(::Symbol) || entity.is_a?(::String)
              klass.valid?(attribute => entity)
              wrapped = true
            else
              klass.valid?(entity)
            end
          end

          # Copy every message of the child's, in order, reading the child's
          # errors without changing them. When the child's store is an
          # ErrorStore with a recorded path for a key, use those real name
          # segments; otherwise keep the existing fallback.
          child_store = klass.errors.public_send(:store)
          child_store.data.each do |k,v|
            if ::PoroValidator::ErrorStore === child_store && (recorded = child_store.__path__(k))
              segments = recorded
              segments = segments.drop(1) if wrapped && segments.first.to_s == name.to_s
              key = if attribute.is_a?(::Array)
                attribute + segments
              else
                [attribute] + segments
              end
              v.each { |message| errors.add(key, message) }
            else
              key = k.to_s == name.to_s ? attribute : [attribute, k.to_sym]
              v.each { |message| errors.add(key, message) }
            end
          end
        else
          raise ::PoroValidator::InvalidValidator.new(
            "Requires a class object for this validator."
          )
        end
      end
    end
  end
end
