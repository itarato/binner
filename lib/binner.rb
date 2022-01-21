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

  PrimitiveT = T.type_alias do
    T.any(
      T::Boolean,
      Numeric,
      String,
      NilClass,
      # Sorbet does not allow type recursion yet.
      T::Array[Object],
      T::Hash[Object, Object],
    )
  end

  class FieldDecoder
    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    sig { returns(Integer) }
    attr_reader(:version)

    sig { returns(T.proc.params(obj: PrimitiveT).returns(TargetT)) }
    attr_reader(:decoder)

    sig do
      params(
        version: Integer,
        decoder: T.proc.params(obj: PrimitiveT).returns(TargetT),
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

    sig do
      params(
        name: Symbol,
        from_version: Integer,
        to_version: Integer,
        encoder: T.proc.params(obj: TargetT).returns(PrimitiveT),
      ).void
    end
    def initialize(name:, from_version:, to_version:, encoder:)
      @name = name
      @from_version = from_version
      @to_version = to_version
      @encoder = encoder
      @decoders = T.let([], T::Array[FieldDecoder[TargetT]])
    end

    sig do
      params(
        obj: TargetT,
        version: Integer, # Coming from the parent type codec.
      ).returns(PrimitiveT)
    end
    def encode(obj, version)
      {
        version: version,
        data: @encoder.call(obj),
      }
    end

    sig do
      params(
        raw: { version: Integer, data: PrimitiveT },
      ).returns(TargetT)
    end
    def decode(raw)
      version = raw[:version]
      raise(VersionNotFoundError) unless version
      raise(NonSupportedVersionError) unless part_of_version?(version)

      decoder = @decoders.find { |d| d.version == version }
      raise(DecoderNotFoundError) unless decoder

      data = raw[:data]
      decoder.decoder.call(data)
    end

    sig do
      params(
        version: Integer,
      ).returns(T::Boolean)
    end
    def part_of_version?(version)
      @from_version <= version && version <= @to_version
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
        klass: Object,
      ).void
    end
    def initialize(klass)
      @klass = klass
      @fields = T.let([], T::Array[Field[T.untyped]])
    end

    sig do
      params(
        obj: TargetT,
      ).returns(PrimitiveT)
    end
    def encode(obj)
      # raise(NotImplementedError)


    end

    sig do
      params(
        raw: PrimitiveT,
      ).returns(TargetT)
    end
    def decode(raw)
      raise(NotImplementedError)
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
      obj: T.untyped,
    ).returns(PrimitiveT)
  end
  def encode(obj)
    t = @types.find do |t|
      obj.is_a?(t.klass)
    end

    raise(MissingCodecError) unless t

    t.encode(obj)
  end
end
