# frozen_string_literal: true
# typed: true

require('minitest/autorun')

require_relative('../lib/binner')

class BinnerTest < Minitest::Test
  class ExampleComplexProperty
    attr_reader(:bool)
    attr_reader(:num)
    attr_reader(:str)

    def initialize(bool, num, str)
      @bool = bool
      @num = num
      @str = str
    end

    def ==(other)
      @bool == other.bool
      @num == other.num
      @str == other.str
    end
  end

  class Example
    attr_reader(:complex)
    attr_reader(:str)

    def initialize(complex, str)
      @complex = complex
      @str = str
    end

    def ==(other)
      @complex == other.complex
      @str == other.str
    end
  end

  class ExampleSimple
    attr_reader(:value)

    def initialize(value)
      @value = value
    end
  end

  def initialize(*)
    super
  end

  def test_encode_decode_gets_the_input_back
    example = Example.new(ExampleComplexProperty.new(true, 12, "hello"), "world")

    binner = Binner.new

    binner.add_type(Binner::Type[ExampleComplexProperty].new(ExampleComplexProperty, 0) do
      T.bind(self, Binner::Type[ExampleComplexProperty])

      set_factory do |fields|
        ExampleComplexProperty.new(fields['bool'], fields['num'], fields['str'])
      end

      add_field(Binner::Field[ExampleComplexProperty, T::Boolean, T::Boolean].new(
        name: 'bool',
        from_version: 0,
      ).with_primitive_default)

      add_field(Binner::Field[ExampleComplexProperty, Integer, Integer].new(
        name: 'num',
        from_version: 0,
      ).with_primitive_default)

      add_field(Binner::Field[ExampleComplexProperty, String, String].new(
        name: 'str',
        from_version: 0,
      ).with_primitive_default)
    end)

    binner.add_type(Binner::Type[Example].new(Example, 0) do
      T.bind(self, Binner::Type[Example])

      set_factory do |fields|
        Example.new(fields['complex'], fields['str'])
      end

      add_field(Binner::Field[Example, ExampleComplexProperty, Binner::Type[ExampleComplexProperty]].new(
        name: "complex",
        from_version: 0,
      ).with_typed_codec(binner))

      add_field(Binner::Field[Example, String, String].new(
        name: "str",
        from_version: 0,
      ).with_primitive_default)
    end)

    re_coded_example = binner.decode(binner.encode(example))
    assert_equal(example, re_coded_example)
  end

  def test_missing_value_is_fulfilled_before_field_exist
    binner = Binner.new
    binner.add_type(Binner::Type[ExampleSimple].new(ExampleSimple, 0) do
      T.bind(self, Binner::Type[ExampleSimple])

      set_factory { |fields| ExampleSimple.new(fields["value"]) }

      add_field(Binner::Field[ExampleSimple, T.untyped, T.untyped].new(
        name: "value",
        from_version: 1,
        missing_default: :missing_value,
      ).with_primitive_default)
    end)


    o = ExampleSimple.new(:real)
    assert_equal(:real, o.value)

    o_decoded = binner.decode(binner.encode(o))
    assert_equal(:missing_value, o_decoded.value)
  end

  def test_missing_value_is_fulfilled_when_decoded_from_old_version

  end
end
