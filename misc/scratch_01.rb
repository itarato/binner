#typed: false

require_relative("../lib/binner")

class Name
  def initialize(name, age); end
end

class User
  attr_reader(:name)

  def initialize(name, weight)
    @name = name
    @weight = weight
  end
end

binner = Binner.new

binner.register(type: User, version: 2) do
  field(:name, from_version: 0) do
    # Always only 1 latest encoder is needed.
    encode do |obj, encoder|
      encoder.set(:name, obj.name)
      encoder.set(:age, obj.age)
    end

    add_decoder(0) do |decoder|
      Name.new(decoder.get(:name), -1)
    end

    add_decoder(1) do |decoder|
      Name.new(decoder.get(:name), decoder.get(:age))
    end
  end

  field(:age, from_version: 0, until_version: 0) do
    # ...
  end

  field(:weight, from_version: 2) do

  end

  # Return:
  # - represented object
  decode do |decoder|
    raw_name = decoder.read(name)
    User.new(raw_name)
  end
end

encoded = binner.encode()
