# frozen_string_literal: true
# typed: strict

class Binner
  class BinnerError < StandardError; end
  class BadIRTypeError < BinnerError; end
  class MissingCodecError < BinnerError; end
  class NonSupportedVersionError < BinnerError; end
  class VersionNotFoundError < BinnerError; end
  class DecoderNotFoundError < BinnerError; end
  class EncoderNotFoundError < BinnerError; end
end
