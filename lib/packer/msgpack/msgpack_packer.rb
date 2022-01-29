# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require "pry"
require "msgpack"

class MsgpackPacker
  extend(T::Sig)

  include(Binner::Packer)

  sig do
    override
      .params(type_wrapper: Binner::TypeWrapper)
      .returns(String)
  end
  def pack(type_wrapper)
    MessagePack.pack(type_wrapper.to_packed_ir)
  end

  sig do
    override
      .params(packed: String)
      .returns(Binner::TypeWrapper)
  end
  def unpack(packed)
    Binner::TypeWrapper.from_packed_ir(MessagePack.unpack(packed))
  end
end
