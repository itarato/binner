# frozen_string_literal: true
# typed: strict

require("sorbet-runtime")
require("pry")

#
# Missing:
# - deployment switch mechanism -> The type encoder might just do that.
# - missing tests
# - nested objects
# - final codecs (json, msgpack, etc)
# - dsl
#

class Binner
  #
  # Binner is the starting point that owns all type-codec information.
  # It's not a root - but more a registry for types.
  #

  extend(T::Sig)

  class BinnerError < StandardError; end
  class MissingCodecError < BinnerError; end
  class NonSupportedVersionError < BinnerError; end
  class VersionNotFoundError < BinnerError; end
  class DecoderNotFoundError < BinnerError; end

  class FieldWrapper < T::Struct
    const(:version, Integer)
    const(:data, T.nilable(T.untyped))
  end

  class TypeWrapper < T::Struct
    const(:version, Integer)
    const(:klass, String)
    const(:data, T::Hash[String, FieldWrapper])
  end

  class FieldDecoder
    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    # TODO: version here might not be useful, we only need it for the Field for selection.
    sig { returns(Integer) }
    attr_reader(:version)

    sig { returns(T.proc.params(obj: T.untyped).returns(TargetT)) }
    attr_reader(:decoder)

    sig do
      params(
        version: Integer,
        decoder: T.proc.params(obj: T.untyped).returns(TargetT),
      ).void
    end
    def initialize(version, &decoder)
      @version = version
      @decoder = decoder
    end
  end

  class Field
    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    sig { returns(String) }
    attr_reader(:name)

    sig { returns(T.nilable(TargetT)) }
    attr_reader(:missing_default)

    sig do
      params(
        name: String,
        from_version: Integer,
        to_version: T.nilable(Integer),
        missing_default: T.nilable(TargetT),
        encoder: T.proc.params(obj: TargetT).returns(T.untyped),
      ).void
    end
    def initialize(name:, from_version:, to_version:, missing_default:, encoder:)
      @name = name
      @from_version = from_version
      @to_version = to_version
      @missing_default = missing_default
      @encoder = encoder

      @decoders = T.let({}, T::Hash[Integer, FieldDecoder[T.untyped]])
    end

    sig do
      params(
        decoder: FieldDecoder[T.untyped],
      ).void
    end
    def add_decoder(decoder)
      @decoders[decoder.version] = decoder
    end

    sig do
      params(
        obj: TargetT,
        version: Integer, # Coming from the parent type codec.
      ).returns(FieldWrapper)
    end
    def encode(obj, version)
      FieldWrapper.new(
        version: version,
        data: @encoder.call(obj),
      )
    end

    sig do
      params(
        raw: FieldWrapper,
      ).returns(TargetT)
    end
    def decode(raw)
      version = raw.version
      raise(NonSupportedVersionError) unless part_of_version?(version)

      latest_decoder_version = @decoders.keys.sort.reverse.detect { |decoder_version| decoder_version <= version }
      raise(DecoderNotFoundError) unless latest_decoder_version

      decoder = @decoders[latest_decoder_version]
      raise(DecoderNotFoundError) unless decoder

      data = raw.data
      decoder.decoder.call(data)
    end

    sig do
      params(
        version: Integer,
      ).returns(T::Boolean)
    end
    def part_of_version?(version)
      @from_version <= version && (@to_version.nil? || version <= @to_version)
    end

    sig do
      params(
        version: Integer,
      ).returns(T::Boolean)
    end
    def introduced_after?(version)
      version < @from_version
    end
  end

  class Type
    #
    # Contains information about one type.
    #

    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    sig { returns(Object) }
    attr_reader(:klass)

    sig do
      params(
        klass: Class,
        # Represents the version currently at (encoding version).
        version: Integer,
        factory: T.proc.params(fields: T::Hash[String, T.untyped]).returns(TargetT),
      ).void
    end
    def initialize(klass, version, &factory)
      @klass = klass
      @version = version
      @factory = factory

      @fields = T.let({}, T::Hash[String, Field[T.untyped]])
    end

    sig do
      params(
        field: Field[T.untyped],
      ).void
    end
    def add_field(field)
      @fields[field.name] = field
    end

    sig do
      params(
        obj: TargetT,
      ).returns(TypeWrapper)
    end
    def encode(obj)
      out = TypeWrapper.new(
        version: @version,
        klass: T.must(@klass.name),
        data: {},
      )

      @fields.values.each do |field|
        if field.part_of_version?(@version)
          out.data[field.name] = field.encode(obj, @version)
        end
      end

      out
    end

    sig do
      params(
        raw: TypeWrapper,
      ).returns(TargetT)
    end
    def decode(raw)
      #
      # Here decoding for Type-@version.
      #
      field_values = T.let({}, T::Hash[String, T.untyped])

      @fields.filter_map do |name, field|
        if field.part_of_version?(@version)
          raw_data = raw.data[field.name]

          field_values[field.name] = raw_data ? field.decode(raw_data) : field.missing_default
        elsif field.introduced_after?(@version)
          field_values[field.name] = field.missing_default
        end
      end

      @factory.call(field_values)
    end
  end

  module Packer
    extend(T::Sig)
    extend(T::Helpers)

    interface!

    sig do
      abstract
        .params(type_wrapper: TypeWrapper)
        .returns(T.untyped)
    end
    def pack(type_wrapper); end

    sig do
      abstract
        .params(packed: T.untyped)
        .returns(TypeWrapper)
    end
    def unpack(packed); end
  end

  sig do
    void
  end
  def initialize
    @types = T.let([], T::Array[Type[T.untyped]])
  end

  sig do
    params(
      type: Type[T.untyped],
    ).void
  end
  def add_type(type)
    @types << type
  end

  sig do
    params(
      obj: T.untyped,
    ).returns(TypeWrapper)
  end
  def encode(obj)
    t = @types.find do |t|
      obj.is_a?(t.klass)
    end

    raise(MissingCodecError) unless t

    t.encode(obj)
  end

  sig do
    params(
      raw: TypeWrapper,
    ).returns(T.untyped)
  end
  def decode(raw)
    klass = raw.klass
    type_for(Kernel.const_get(klass)).decode(raw)
  end

  private

  sig do
    params(
      klass: Class,
    ).returns(Type[T.untyped])
  end
  def type_for(klass)
    @types.find { |t| klass == t.klass } || raise(MissingCodecError)
  end
end

require_relative("packer/json/json_packer")
