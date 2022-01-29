#typed: ignore

require_relative("../lib/binner")
require "json"
require "pp"

class Link
  def initialize()
  end
end

"""
Reference types:

#1: Outside reference

user = User.new
company = Company.new(user)

binner.encode(company)

#2: Cross reference

a = A.new
b = B.new

a.b = b
b.a = a

"""

binner = Binner.new
json_packer = JsonPacker.new
