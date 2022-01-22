# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"

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
    const(:data, T.untyped)
  end

  class TypeWrapper < T::Struct
    const(:version, Integer)
    const(:type, Class)
    const(:data, T::Hash[Symbol, FieldWrapper])
  end

  class FieldDecoder
    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    sig { returns(Integer) }
    attr_reader(:version)

    sig { returns(T.proc.params(obj: FieldWrapper).returns(TargetT)) }
    attr_reader(:decoder)

    sig do
      params(
        version: Integer,
        decoder: T.proc.params(obj: FieldWrapper).returns(TargetT),
      ).void
    end
    def initialize(version, decoder)
      @version = version
      @decoder = decoder
    end
  end

  class Field
    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    sig { returns(Symbol) }
    attr_reader(:name)

    sig do
      params(
        name: Symbol,
        from_version: Integer,
        to_version: T.nilable(Integer),
        encoder: T.proc.params(obj: TargetT).returns(FieldWrapper),
      ).void
    end
    def initialize(name:, from_version:, to_version:, encoder:)
      @name = name
      @from_version = from_version
      @to_version = to_version
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

      decoder = @decoders[version]
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
  end

  # module FieldReader
  #   extend(T::Sig)
  #   extend(T::Helpers)

  #   interface!

  #   sig do
  #     abstract
  #       .params(
  #         name: Symbol,
  #       ).returns(T.untyped)
  #   end
  #   def get_field_value(name); end
  # end

  class Type
    #
    # Contains information about one type.
    #

    extend(T::Sig)
    extend(T::Generic)

    # include(FieldReader)

    TargetT = type_member

    sig { returns(Object) }
    attr_reader(:klass)

    sig do
      params(
        klass: Class,
        # Represents the version currently at (encoding version).
        version: Integer,
        factory: T.proc.params(fields: T::Hash[Symbol, T.untyped]).returns(TargetT),
      ).void
    end
    def initialize(klass, version, factory)
      @klass = klass
      @version = version
      @factory = factory

      @fields = T.let({}, T::Hash[Symbol, Field[T.untyped]])
    end

    sig do
      params(
        field: Field[T.untyped],
      ).void
    end
    def add_field(field)
      @fields[field.name] = field
    end

    # sig do
    #   override
    #     .params(
    #       name: Symbol,
    #     ).returns(T.untyped)
    # end
    # def get_field_value(name)

    # end

    sig do
      params(
        obj: TargetT,
      ).returns(TypeWrapper)
    end
    def encode(obj)
      out = TypeWrapper.new(
        version: @version,
        type: @klass,
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
      field_values = T.let({}, T::Hash[Symbol, T.untyped])

      @fields.filter_map do |name, field|
        next unless field.part_of_version?(@version)
        field_values[field.name] = field.decode(T.must(raw.data[field.name]))
      end

      @factory.call(field_values)
    end
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
    klass = raw.type
    type_for(klass).decode(raw)
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
