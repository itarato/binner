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

binner = Binner.new
json_packer = JsonPacker.new

user_type = Binner::Type[User].new(User, 2) do
  T.bind(self, Binner::Type[User])

  set_factory do |fields|
    # This is type safe now.
    User.new(fields["name"], fields["age"], fields["company"])
  end

  add_field(Binner::Field[User, String, String].new(
    name: "name",
    from_version: 0,
    to_version: nil,
    missing_default: nil,
  ) do
    T.bind(self, Binner::Field[User, String, String])

    set_encoder { |obj| obj.name }

    add_decoder(Binner::FieldDecoder[String].new(0) do |raw|
      # Output is type safe now.
      raw
    end)
  end)

  add_field(Binner::Field[User, Integer, Integer].new(
    name: "age",
    from_version: 1,
    to_version: nil,
    missing_default: nil,
  ) do
    T.bind(self, Binner::Field[User, Integer, Integer])

    set_encoder { |obj| obj.age || 0 }

    add_decoder(Binner::FieldDecoder[Integer].new(1) do |raw|
      raw
    end)
  end)

  add_field(Binner::Field[User, Company, Binner::TypeWrapper].new(
    name: "company",
    from_version: 2,
    to_version: nil,
    missing_default: Company.new(:acme),
  ) do
    T.bind(self, Binner::Field[User, Company, Binner::TypeWrapper])

    set_encoder { |obj| binner.encode(obj.company) }

    add_decoder(Binner::FieldDecoder[Company].new(2) do |raw|
      binner.decode(raw)
    end)
  end)
end

company_type = Binner::Type[Company].new(Company, 0) do
  T.bind(self, Binner::Type[Company])

  set_factory do |fields|
    Company.new(fields["title"])
  end

  add_field(Binner::Field[Company, Symbol, String].new(
    name: "title",
    from_version: 0,
    to_version: nil,
    missing_default: nil,
  ) do
    T.bind(self, Binner::Field[Company, Symbol, String])

    set_encoder { |obj| obj.title.to_s }

    add_decoder(Binner::FieldDecoder[Symbol].new(0) do |raw|
      raw.to_sym
    end)
  end)
end

binner.add_type(user_type)
binner.add_type(company_type)

encoded = binner.encode(User.new("Steve", 35, Company.new(:microsoft)))
# pp encoded
# pp encoded.serialize.to_json
# pp Binner::TypeWrapper.from_hash(encoded.serialize)

pp "JSON PACKED"
pp json_packer.pack(encoded)
pp "JSON UNPACKED"
pp json_packer.unpack(json_packer.pack(encoded))
pp encoded

# pp packed_ir = encoded.to_packed_ir
# pp Binner::TypeWrapper.from_packed_ir(packed_ir)
# pp encoded

# decoded = binner.decode(encoded)
# pp decoded

# pp binner.decode(binner.encode(Company.new(:president)))

# encoded_v0 = Binner::TypeWrapper.from_hash(JSON.parse("{\"version\":0,\"klass\":\"User\",\"data\":{\"name\":{\"version\":0,\"data\":\"Steve\"}}}"))
# pp encoded_v0
# decoded_v0 = binner.decode(encoded_v0)
# pp decoded_v0

# encoded_v1 = Binner::TypeWrapper.from_hash(JSON.parse("{\"version\":1,\"klass\":\"User\",\"data\":{\"name\":{\"version\":1,\"data\":\"Steve\"},\"age\":{\"version\":1,\"data\":35}}}"))
# pp encoded_v1
# decoded_v1 = binner.decode(encoded_v1)
# pp decoded_v1
