#typed: true

require_relative("../lib/binner")
require "pp"

class User
  attr_reader(:name)

  def initialize(name)
    @name = name
  end
end

binner = Binner.new()

user_type = Binner::Type[User].new(User, 0, ->(fields) {
  User.new(fields[:name])
})

user_name_field = Binner::Field[String].new(
  name: :name,
  from_version: 0,
  to_version: nil,
  encoder: ->(s) { s.name },
)

user_type.add_field(user_name_field)

binner.add_type(user_type)

encoded = binner.encode(User.new("Steve"))
pp encoded

decoded = binner.decode(encoded)
pp decoded