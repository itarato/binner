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

  def initialize(*)
    super
  end

  def test_encode_decode_gets_the_input_back
    example = Example.new(ExampleComplexProperty.new(true, 12, "hello"), "world")

    binner = Binner.new
    binner.add_type(Binner::Type[Example].new(Example, 0) do
      T.bind(self, Binner::Type[Example])

      set_factory do |fields|
        Example.new(fields['complex'], fields['str'])
      end

      add_field(Binner::Field[Example, ExampleComplexProperty, Binner::Type[ExampleComplexProperty]].new(
        name: "complex",
        from_version: 0,
        to_version: nil,
        missing_default: nil,
      ) do
        T.bind(self, Binner::Field[Example, ExampleComplexProperty, Binner::TypeWrapper])

        set_encoder do |example|
          binner.encode(example.complex)
        end

        add_decoder(Binner::FieldDecoder[ExampleComplexProperty].new(0) do |raw|
          binner.decode(raw)
        end)
      end)

      add_field(Binner::Field[Example, String, String].new(
        name: "str",
        from_version: 0,
        to_version: nil,
        missing_default: nil,
      ) do
        T.bind(self, Binner::Field[Example, String, String])

        set_encoder do |example|
          example.str
        end

        add_decoder(Binner::FieldDecoder[String].new(0) do |raw|
          raw
        end)
      end)
    end)

    re_coded_example = binner.decode(binner.encode(example))
  end
end
