#typed: false

require_relative("../lib/binner")

class User
  attr_reader(:name)

  def initialize(name)
    @name
  end
end

binner = Binner.new

binner.register(type: User, version: 0) do
  field(:name) do
    # Return:
    # - one object
    # - can only contain primitive
    encode do |obj|
      obj.name
    end

    # # Input:
    # # - same as return of encoder
    # # Return:
    # # -
    # decode do |value|
    # end
  end

  # Return:
  # - represented object
  decode do |decoder|
    raw_name = decoder.read(name)
    User.new(raw_name)
  end
end

encoded = binner.encode()