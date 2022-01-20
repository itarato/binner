# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"

class Binner
  #
  # Binner is the starting point that owns all type-codec information.
  # It's not a root - but more a registry for types.
  #

  extend(T::Sig)

  class MissingCodecError < StandardError; end

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

  class TypeVersionedCodec
    #
    # Knows how to encode/decode a specific state (version) of that type.
    #

    extend(T::Sig)
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
      @versioned_codecs = T.let([], T::Array[TypeVersionedCodec])
    end

    sig do
      params(
        obj: TargetT,
      ).returns(PrimitiveT)
    end
    def encode(obj)
      raise(NotImplementedError)
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
