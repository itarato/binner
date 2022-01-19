# frozen_string_literal: true
# typed: strict

class Binner
  #
  # Binner is the starting point that owns all type-codec information.
  # It's not a root - but more a registry for types.
  #

  extend(T::Sig)

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
  end

  sig do
    void
  end
  def initialize
    @types = T.let([], T::Array[Type])
  end
end
