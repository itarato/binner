# frozen_string_literal: true
#typed: true

require_relative("../lib/binner")
require "json"
require "pp"

class User4
  attr_reader(:name)
  def initialize(name)
    @name = name
  end
end

binner = Binner.new
binner.add_type(Binner::Type[User4].new(User4, 0) do
  T.bind(self, Binner::Type[User4])

  set_factory { |fields| User4.new(fields['name']) }

  add_field(Binner::Field[User4, String, String].new(
    name: "name",
    from_version: 0,
  ).with_primitive_default)
end)