# frozen_string_literal: true
# typed: strict

class Binner
  class Field
    extend(T::Sig)
    extend(T::Generic)

    OwnerT = type_member
    FieldT = type_member
    SerializedT = type_member

    sig { returns(String) }
    attr_reader(:name)

    sig { returns(T.nilable(FieldT)) }
    attr_reader(:missing_default)

    sig do
      params(
        name: String,
        from_version: Integer,
        to_version: T.nilable(Integer),
        missing_default: T.nilable(FieldT),
      ).void
    end
    def initialize(name:, from_version:, to_version: nil, missing_default: nil)
      @name = name
      @from_version = from_version
      @to_version = to_version
      @missing_default = missing_default
      # TODO: we could add a new generic for the parent type
      @encoder = T.let(
        nil,
        T.nilable(T.proc.params(obj: OwnerT).returns(SerializedT)),
      )

      # TODO: Are we really don't know the type?
      @decoders = T.let({}, T::Hash[Integer, FieldDecoder[T.untyped]])
    end

    sig do
      params(
        builder: T.proc.void,
      ).returns(T.self_type)
    end
    def with(&builder)
      instance_eval(&builder)
      self
    end

    sig do
      returns(T.self_type)
    end
    def with_primitive_default
      set_encoder { |parent| parent.public_send(@name) }
      add_decoder(Binner::FieldDecoder[FieldT].new(&:itself), from_version: @from_version)
      self
    end

    sig do
      params(
        binner: Binner,
      ).returns(T.self_type)
    end
    def with_typed_codec(binner)
      set_encoder do |parent|
        T.cast(binner.encode(parent.public_send(@name)), SerializedT)
      end

      add_decoder(Binner::FieldDecoder[FieldT].new { |raw| binner.decode(raw) }, from_version: @from_version)

      self
    end

    sig do
      params(
        encoder: T.proc.params(obj: OwnerT).returns(SerializedT),
      ).void
    end
    def set_encoder(&encoder)
      @encoder = encoder
    end

    sig do
      params(
        decoder: FieldDecoder[FieldT],
        from_version: Integer,
      ).returns(T.self_type)
    end
    def add_decoder(decoder, from_version:)
      @decoders[from_version] = decoder
      self
    end

    sig do
      params(
        obj: OwnerT,
        version: Integer, # Coming from the parent type codec.
      ).returns(FieldWrapper)
    end
    def encode(obj, version)
      raise(EncoderNotFoundError, "Field #{@name} missing an encoder") unless @encoder

      FieldWrapper.new(
        version: version,
        data: @encoder.call(obj),
      )
    end

    sig do
      params(
        raw: FieldWrapper,
      ).returns(FieldT)
    end
    def decode(raw)
      version = raw.version
      raise(NonSupportedVersionError, "Field #{@name} does not support decoding for version #{version}") unless part_of_version?(version)

      latest_decoder_version = @decoders.keys.sort.reverse.detect { |decoder_version| decoder_version <= version }
      raise(DecoderNotFoundError, "Field #{@name} does not find decoder definition for version #{version}") unless latest_decoder_version

      decoder = @decoders[latest_decoder_version]
      raise(DecoderNotFoundError, "Field #{@name} does not find decoder for version #{version}") unless decoder

      data = raw.data
      decoder.decoder.call(data)
    end

    sig do
      params(
        version: Integer,
      ).returns(T::Boolean)
    end
    def part_of_version?(version)
      @from_version <= version && (@to_version.nil? || version <= @to_version)
    end

    sig do
      params(
        version: Integer,
      ).returns(T::Boolean)
    end
    def introduced_after?(version)
      version < @from_version
    end
  end
end
