# frozen_string_literal: true
# typed: strict

class Binner
  class FieldDecoder
    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    sig { returns(T.proc.params(obj: T.untyped).returns(TargetT)) }
    attr_reader(:decoder)

    sig do
      params(
        decoder: T.proc.params(obj: T.untyped).returns(TargetT),
      ).void
    end
    def initialize(&decoder)
      @decoder = decoder
    end
  end
end