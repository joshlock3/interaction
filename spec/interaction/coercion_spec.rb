require "spec_helper"
require "interaction/coercion"

RSpec.describe Interaction::Coercion do
  describe ".coerce" do
    context "string type" do
      it "via :string symbol" do
        expect(described_class.coerce(42, :string)).to eq("42")
      end

      it "via String class" do
        expect(described_class.coerce(42, String)).to eq("42")
      end
    end

    context "integer type" do
      it "coerces numeric string to integer via :integer symbol" do
        expect(described_class.coerce("42", :integer)).to eq(42)
      end

      it "coerces numeric string to integer via Integer class" do
        expect(described_class.coerce("42", Integer)).to eq(42)
      end

      it "passes through an integer unchanged" do
        expect(described_class.coerce(42, Integer)).to eq(42)
      end

      it "returns original value on malformed input" do
        expect(described_class.coerce("not a number", Integer)).to eq("not a number")
      end
    end

    context "boolean type" do
      it "coerces truthy strings to true" do
        %w[true 1 yes y TRUE Y].each do |v|
          expect(described_class.coerce(v, :boolean)).to eq(true)
        end
      end

      it "coerces falsy strings to false" do
        %w[false 0 no n FALSE N].each do |v|
          expect(described_class.coerce(v, :boolean)).to eq(false)
        end
      end

      it "passes through literal booleans" do
        expect(described_class.coerce(true, :boolean)).to eq(true)
        expect(described_class.coerce(false, :boolean)).to eq(false)
      end
    end

    context "date type" do
      it "parses string date via :date symbol" do
        expect(described_class.coerce("2026-04-09", :date)).to eq(Date.new(2026, 4, 9))
      end

      it "parses string date via Date class" do
        expect(described_class.coerce("2026-04-09", Date)).to eq(Date.new(2026, 4, 9))
      end

      it "passes through Date objects unchanged" do
        d = Date.new(2026, 1, 1)
        expect(described_class.coerce(d, Date)).to eq(d)
      end

      it "returns original on unparseable input" do
        expect(described_class.coerce("not a date", Date)).to eq("not a date")
      end
    end

    context "hash type" do
      it "passes through a hash" do
        expect(described_class.coerce({a: 1}, :hash)).to eq({a: 1})
      end
    end

    context "array type" do
      it "wraps a single value in an array" do
        expect(described_class.coerce("x", :array)).to eq(["x"])
      end

      it "passes through an array" do
        expect(described_class.coerce([1, 2], :array)).to eq([1, 2])
      end
    end

    context "unknown type" do
      it "passes through unchanged" do
        expect(described_class.coerce("x", :unknown_type)).to eq("x")
      end

      it "passes through for an unknown class" do
        klass = Class.new
        expect(described_class.coerce("x", klass)).to eq("x")
      end
    end
  end
end
