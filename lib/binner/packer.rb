# frozen_string_literal: true
# typed: strict

class Binner
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
end
