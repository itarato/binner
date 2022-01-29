# frozen_string_literal: true
# typed: strict

class Binner
  # TODO: Basic decoder could be simple property access from source object? We could save some boilerplate code.
  class FieldDecoder
    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    # TODO: version here might not be useful, we only need it for the Field for selection.
    sig { returns(Integer) }
    attr_reader(:from_version)

    sig { returns(T.proc.params(obj: T.untyped).returns(TargetT)) }
    attr_reader(:decoder)

    # TODO: we should make version a kwarg - to make it readable
    sig do
      params(
        from_version: Integer,
        decoder: T.proc.params(obj: T.untyped).returns(TargetT),
      ).void
    end
    def initialize(from_version, &decoder)
      @from_version = from_version
      @decoder = decoder
    end
  end
end