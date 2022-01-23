# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require "pry"
require "json"

class JsonPacker
  extend(T::Sig)

  include(Binner::Packer)

  sig do
    override
      .params(type_wrapper: Binner::TypeWrapper)
      .returns(T.untyped)
  end
  def pack(type_wrapper)
    type_wrapper.serialize.to_json
  end

  sig do
    override
      .params(packed: T.untyped)
      .returns(Binner::TypeWrapper)
  end
  def unpack(packed)
    Binner::TypeWrapper.from_hash(JSON.parse(packed))
  end
end
