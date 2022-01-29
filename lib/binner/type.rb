# frozen_string_literal: true
# typed: strict

class Binner
  class Type
    #
    # Contains information about one type.
    #

    extend(T::Sig)
    extend(T::Generic)

    TargetT = type_member

    sig { returns(Object) }
    attr_reader(:klass)

    sig do
      params(
        klass: Class,
        # Represents the version currently at (encoding version).
        version: Integer,
        builder: T.proc.void,
      ).void
    end
    def initialize(klass, version, &builder)
      @klass = klass
      @version = version
      @factory = T.let(
        nil,
        T.nilable(T.proc.params(fields: T::Hash[String, T.untyped]).returns(TargetT)),
      )

      # TODO: Can we do better typing here?
      @fields = T.let({}, T::Hash[String, Field[T.untyped, T.untyped, T.untyped]])

      instance_eval(&builder)
    end

    sig do
      params(
        factory: T.proc.params(fields: T::Hash[String, T.untyped]).returns(TargetT),
      ).void
    end
    def set_factory(&factory)
      @factory = factory
    end

    sig do
      params(
        field: Field[T.untyped, T.untyped, T.untyped],
      ).returns(T.self_type)
    end
    def add_field(field)
      @fields[field.name] = field
      self
    end

    sig do
      params(
        obj: TargetT,
      ).returns(TypeWrapper)
    end
    def encode(obj)
      out = TypeWrapper.new(
        version: @version,
        klass: T.must(@klass.name),
        data: {},
      )

      @fields.values.each do |field|
        if field.part_of_version?(@version)
          out.data[field.name] = field.encode(obj, @version)
        end
      end

      out
    end

    sig do
      params(
        raw: TypeWrapper,
      ).returns(TargetT)
    end
    def decode(raw)
      #
      # Here decoding for Type-@version.
      #
      raise(DecoderNotFoundError, "Missing factory on type #{@klass}") unless @factory

      field_values = T.let({}, T::Hash[String, T.untyped])

      @fields.filter_map do |name, field|
        if field.part_of_version?(@version)
          raw_data = raw.data[field.name]

          field_values[field.name] = raw_data ? field.decode(raw_data) : field.missing_default
        elsif field.introduced_after?(@version)
          field_values[field.name] = field.missing_default
        end
      end

      @factory.call(field_values)
    end
  end
end
