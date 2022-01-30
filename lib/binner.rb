# frozen_string_literal: true
# typed: strict

require("sorbet-runtime")
require("pry")

require_relative("binner/field_decoder")
require_relative("binner/structs")
require_relative("binner/field")
require_relative("binner/type")
require_relative("binner/packer")
require_relative("binner/errors")

#
# Missing:
# - final codecs (msgpack, protobuf, etc)
# - reference tracking
#
# Need:
# - more test
#

class Binner
  #
  # Binner is the starting point that owns all type-codec information.
  # It's not a root - but more a registry for types.
  #

  extend(T::Sig)

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
      version: T.nilable(Integer),
    ).returns(TypeWrapper)
  end
  def encode(obj, version: nil)
    t = @types.find do |t|
      obj.is_a?(t.klass)
    end

    raise(MissingCodecError, "Cannot find codec for: #{obj}") unless t

    t.encode(obj, encoding_version: version)
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
    @types.find { |t| klass == t.klass } || raise(MissingCodecError, "Missing codec for #{klass}")
  end
end

require_relative("packer/json/json_packer")
require_relative("packer/msgpack/msgpack_packer")
