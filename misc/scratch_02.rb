#typed: strict

require_relative("../lib/binner")
require "json"
require "pp"

# class User
#   extend(T::Sig)

#   sig { returns(String) }
#   attr_reader(:name)
#
#   sig { params(name: String).void }
#   def initialize(name)
#     @name = name
#   end
# end

class User
  extend(T::Sig)

  sig { returns(String) }
  attr_reader(:name)

  sig { returns(T.nilable(Integer))}
  attr_reader(:age)

  sig { params(name: String, age: T.nilable(Integer)).void }
  def initialize(name, age)
    @name = name
    @age = age
  end
end

binner = Binner.new()

user_type = Binner::Type[User].new(User, 1) do |fields|
  # This is type safe now.
  User.new(fields["name"], fields["age"])
end

user_name_field = Binner::Field[String].new(
  name: "name",
  from_version: 0,
  to_version: nil,
  missing_default: nil,
  encoder: ->(o) { o.name },
)
user_name_field.add_decoder(Binner::FieldDecoder[String].new(0) do |raw|
  # Output is type safe now.
  raw
end)

user_age_field = Binner::Field[Integer].new(
  name: "age",
  from_version: 1,
  to_version: nil,
  missing_default: nil,
  encoder: ->(o) { o.age },
)
user_age_field.add_decoder(Binner::FieldDecoder[Integer].new(1) do |raw|
  raw
end)

user_type.add_field(user_name_field)
user_type.add_field(user_age_field)

binner.add_type(user_type)

encoded = binner.encode(User.new("Steve", 35))
pp encoded.serialize.to_json
pp Binner::TypeWrapper.from_hash(encoded.serialize)

decoded = binner.decode(encoded)
pp decoded

encoded_v0 = Binner::TypeWrapper.from_hash(JSON.parse("{\"version\":0,\"klass\":\"User\",\"data\":{\"name\":{\"version\":0,\"data\":\"Steve\"}}}"))
pp encoded_v0
decoded_v0 = binner.decode(encoded_v0)
pp decoded_v0
