require 'spec_helper'

RSpec.describe PoroValidator::Utils::StableInspect, type: :utils do
  describe ".call" do
    it "renders a hash with the pre-3.4 Hash#inspect syntax" do
      expect(described_class.call({ in: 1..10 })).to eq("{:in=>1..10}")
    end

    it "renders nested hashes" do
      expect(described_class.call({ address: { country: :code } })).to eq(
        "{:address=>{:country=>:code}}"
      )
    end

    it "renders string keys and several pairs" do
      expect(described_class.call({ "min" => 1, max: 2**64 })).to eq(
        "{\"min\"=>1, :max=>18446744073709551616}"
      )
    end

    it "renders hashes inside arrays" do
      expect(described_class.call([:a, { b: 1 }])).to eq("[:a, {:b=>1}]")
    end

    it "uses #inspect for other values" do
      expect(described_class.call(1...10)).to eq("1...10")
      expect(described_class.call(/\d+/)).to eq("/\\d+/")
      expect(described_class.call("text")).to eq("\"text\"")
    end

    it "keeps insertion order and empty nested values" do
      expect(described_class.call({ z: [], a: {}, m: [{ n: nil }] })).to eq(
        "{:z=>[], :a=>{}, :m=>[{:n=>nil}]}"
      )
    end

    context "when a value contains itself" do
      it "renders an array that contains itself" do
        array = []
        array << array

        expect(described_class.call(array)).to eq("[[...]]")
      end

      it "renders a hash that contains itself" do
        hash = {}
        hash[:self] = hash

        expect(described_class.call(hash)).to eq("{:self=>{...}}")
      end

      it "renders arrays that contain each other" do
        first = [1]
        second = [first]
        first << second

        expect(described_class.call(first)).to eq("[1, [[...]]]")
        expect(described_class.call(second)).to eq("[[1, [...]]]")
      end

      it "renders an array and a hash that contain each other" do
        list = [:a]
        map = { list: list }
        list << map

        expect(described_class.call(list)).to eq("[:a, {:list=>[...]}]")
        expect(described_class.call(map)).to eq("{:list=>[:a, {...}]}")
      end

      it "renders a hash that is one of its own keys" do
        hash = {}
        hash[hash] = :value

        expect(described_class.call(hash)).to eq("{{...}=>:value}")
      end
    end

    context "when a value appears more than once without a cycle" do
      it "renders it in full each time" do
        shared = [1, { a: 2 }]

        expect(described_class.call([shared, shared])).to eq(
          "[[1, {:a=>2}], [1, {:a=>2}]]"
        )
        expect(described_class.call({ first: shared, second: [shared] })).to eq(
          "{:first=>[1, {:a=>2}], :second=>[[1, {:a=>2}]]}"
        )
      end

      it "renders a shared cyclic array in full in each branch" do
        cycle = []
        cycle << cycle

        expect(described_class.call([cycle, cycle])).to eq("[[[...]], [[...]]]")
      end
    end

    context "when an array or hash defines its own #inspect" do
      let(:custom_array) do
        Class.new(::Array) do
          def inspect
            "<custom choices>"
          end
        end
      end

      it "uses an Array subclass's #inspect" do
        expect(described_class.call(custom_array.new([1]))).to eq(
          "<custom choices>"
        )
        expect(described_class.call([custom_array.new, 2])).to eq(
          "[<custom choices>, 2]"
        )
      end

      it "uses a Hash subclass's #inspect" do
        custom_hash = Class.new(::Hash) do
          def inspect
            "<custom hash>"
          end
        end

        expect(described_class.call({ key: custom_hash.new })).to eq(
          "{:key=><custom hash>}"
        )
      end

      it "uses #inspect defined on a single object" do
        list = [1]
        def list.inspect
          "<one list>"
        end
        map = { a: 1 }
        def map.inspect
          "<one map>"
        end

        expect(described_class.call([list, map])).to eq("[<one list>, <one map>]")
      end

      it "uses #inspect inherited from a parent class or a module" do
        child = Class.new(custom_array)
        from_module = Class.new(::Hash) do
          include(Module.new do
            def inspect
              "<from a module>"
            end
          end)
        end

        expect(described_class.call(child.new)).to eq("<custom choices>")
        expect(described_class.call(from_module.new)).to eq("<from a module>")
      end

      it "returns the custom text unchanged" do
        modern = Class.new(::Hash) do
          def inspect
            "{key: :value}"
          end
        end

        expect(described_class.call([modern.new])).to eq("[{key: :value}]")
      end

      it "renders subclasses without their own #inspect like arrays and hashes" do
        map = Class.new(::Hash).new
        map[:list] = Class.new(::Array).new([{ a: 1 }])

        expect(described_class.call(map)).to eq("{:list=>[{:a=>1}]}")
      end

      it "lets an exception from a custom #inspect through" do
        failing = Class.new(::Array) do
          def inspect
            raise ArgumentError, "inspect failed"
          end
        end

        expect { described_class.call([failing.new]) }.to raise_error(
          ArgumentError, "inspect failed"
        )
      end
    end

    context "across calls" do
      it "keeps no traversal state after a custom #inspect raises" do
        flaky = Class.new(::Array) do
          attr_accessor :broken

          def inspect
            raise ArgumentError, "inspect failed" if broken
            "<flaky>"
          end
        end.new
        flaky.broken = true
        outer = [flaky]

        expect { described_class.call(outer) }.to raise_error(
          ArgumentError, "inspect failed"
        )

        flaky.broken = false
        expect(described_class.call(outer)).to eq("[<flaky>]")
        expect(described_class.call([outer, outer])).to eq(
          "[[<flaky>], [<flaky>]]"
        )
      end

      it "renders the same cyclic value the same way every time" do
        array = [1]
        array << array

        results = Array.new(3) { described_class.call(array) }

        expect(results).to eq(["[1, [...]]"] * 3)
      end

      it "does not modify the values it renders" do
        array = [1]
        array << array
        hash = { list: array }
        hash[:self] = hash
        array.freeze
        hash.freeze

        expect(described_class.call(hash)).to eq(
          "{:list=>[1, [...]], :self=>{...}}"
        )
      end
    end
  end
end
