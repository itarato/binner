# frozen_string_literal: true
# typed: strict

class Binner

  class FieldWrapper < T::Struct
    extend(T::Sig)

    const(:version, Integer)
    const(:data, T.nilable(T.untyped))

    sig do
      returns(T::Hash[String, T.untyped])
    end
    def to_packed_ir
      {
        "version" => version,
        "data" => case data
          when String, Numeric, Symbol, NilClass, TrueClass, FalseClass then data
          when TypeWrapper then data.to_packed_ir
          else raise(BadIRTypeError, "Unexpected primitive serializable data type")
          end,
      }
    end

    sig do
      params(
        packed_ir: T::Hash[String, T.untyped],
      ).returns(FieldWrapper)
    end
    def self.from_packed_ir(packed_ir)
      data = if Hash === packed_ir["data"] && packed_ir["data"]["pack_type"] == TypeWrapper::PACKED_MARKER
        TypeWrapper.from_packed_ir(packed_ir["data"])
      else
        packed_ir["data"]
      end

      FieldWrapper.new(
        version: packed_ir["version"],
        data: data,
      )
    end
  end

  class TypeWrapper < T::Struct
    extend(T::Sig)

    PACKED_MARKER = T.let("__type_wrapper__", String)

    const(:version, Integer)
    const(:klass, String)
    const(:data, T::Hash[String, FieldWrapper])

    sig do
      returns(T::Hash[String, T.untyped])
    end
    def to_packed_ir
      {
        "pack_type" => PACKED_MARKER,
        "version" => version,
        "klass" => klass,
        "data" => data.transform_values(&:to_packed_ir),
      }
    end

    sig do
      params(
        packed_ir: T::Hash[String, T.untyped],
      ).returns(TypeWrapper)
    end
    def self.from_packed_ir(packed_ir)
      TypeWrapper.new(
        version: packed_ir["version"],
        klass: packed_ir["klass"],
        data: packed_ir["data"].transform_values { |field_packed_ir| FieldWrapper.from_packed_ir(field_packed_ir) },
      )
    end
  end
end
