#typed: strict

require_relative("../lib/binner")
require "json"
require "pp"

# class User # V0
#   extend(T::Sig)

#   sig { returns(String) }
#   attr_reader(:name)
#
#   sig { params(name: String).void }
#   def initialize(name)
#     @name = name
#   end
# end

# class User # V1
#   extend(T::Sig)

#   sig { returns(String) }
#   attr_reader(:name)

#   sig { returns(T.nilable(Integer))}
#   attr_reader(:age)

#   sig { params(name: String, age: T.nilable(Integer)).void }
#   def initialize(name, age)
#     @name = name
#     @age = age
#   end
# end

class Company
  extend(T::Sig)

  sig { returns(Symbol) }
  attr_reader(:title)

  sig { params(title: Symbol).void }
  def initialize(title)
    @title = title
  end
end

class User # V2
  extend(T::Sig)

  sig { returns(String) }
  attr_reader(:name)

  sig { returns(T.nilable(Integer))}
  attr_reader(:age)

  sig { returns(Company) }
  attr_accessor(:company)

  sig { params(name: String, age: T.nilable(Integer), company: Company).void }
  def initialize(name, age, company)
    @name = name
    @age = age
    @company = company
  end
end

binner = Binner.new()

user_type = Binner::Type[User].new(User, 2) do |fields|
  # This is type safe now.
  User.new(fields["name"], fields["age"], fields["company"])
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

user_company_field = Binner::Field[Company].new(
  name: "company",
  from_version: 2,
  to_version: nil,
  missing_default: Company.new(:acme),
  encoder: ->(o) { binner.encode(o.company) },
)
user_company_field.add_decoder(Binner::FieldDecoder[Company].new(2) do |raw|
  binner.decode(raw)
end)

user_type.add_field(user_name_field)
user_type.add_field(user_age_field)
user_type.add_field(user_company_field)

company_type = Binner::Type[Company].new(Company, 0) do |fields|
  Company.new(fields["title"])
end

binner_title = Binner::Field[Symbol].new(
  name: "title",
  from_version: 0,
  to_version: nil,
  missing_default: nil,
  encoder: ->(o) { o.title.to_s },
)
binner_title.add_decoder(Binner::FieldDecoder[Symbol].new(0) do |raw|
  raw.to_sym
end)

company_type.add_field(binner_title)

binner.add_type(user_type)
binner.add_type(company_type)

encoded = binner.encode(User.new("Steve", 35, Company.new(:microsoft)))
pp encoded
pp encoded.serialize.to_json
pp Binner::TypeWrapper.from_hash(encoded.serialize)

decoded = binner.decode(encoded)
pp decoded

pp binner.decode(binner.encode(Company.new(:president)))

encoded_v0 = Binner::TypeWrapper.from_hash(JSON.parse("{\"version\":0,\"klass\":\"User\",\"data\":{\"name\":{\"version\":0,\"data\":\"Steve\"}}}"))
pp encoded_v0
decoded_v0 = binner.decode(encoded_v0)
pp decoded_v0

encoded_v1 = Binner::TypeWrapper.from_hash(JSON.parse("{\"version\":1,\"klass\":\"User\",\"data\":{\"name\":{\"version\":1,\"data\":\"Steve\"},\"age\":{\"version\":1,\"data\":35}}}"))
pp encoded_v1
decoded_v1 = binner.decode(encoded_v1)
pp decoded_v1
