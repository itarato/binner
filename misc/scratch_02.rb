#typed: strict

require_relative("../lib/binner")
require "pp"

class User
  extend(T::Sig)

  sig { returns(String) }
  attr_reader(:name)

  sig { params(name: String).void }
  def initialize(name)
    @name = name
  end
end

binner = Binner.new()

user_type = Binner::Type[User].new(User, 0) do |fields|
  # This is type safe now.
  User.new(fields[:name])
end

user_name_field = Binner::Field[String].new(
  name: :name,
  from_version: 0,
  to_version: nil,
  encoder: ->(s) { s.name },
)

user_name_decoder = Binner::FieldDecoder[String].new(0) do |raw|
  # Output is type safe now.
  raw
end

user_name_field.add_decoder(user_name_decoder)

user_type.add_field(user_name_field)

binner.add_type(user_type)

encoded = binner.encode(User.new("Steve"))
pp encoded

decoded = binner.decode(encoded)
pp decoded
