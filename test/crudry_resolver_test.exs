defmodule CrudryResolverTest do
  use ExUnit.Case
  doctest Crudry.Resolver

  alias CrudryTest.Test

  defmodule Context do
    alias CrudryTest.Repo
    alias CrudryTest.Test
    require Crudry.Context

    Crudry.Context.generate_functions(Test)
  end

  @info %{}

  test "creates the CRUD functions" do
    defmodule Resolver do
      Crudry.Resolver.generate_functions(Context, Test)
    end

    assert Resolver.get_test(%{id: 1}, @info) == {:ok, %Test{x: "123"}}
    assert Resolver.get_test(%{id: 0}, @info) == {:error, "Test not found."}
    assert Resolver.list_tests(%{}, @info) == {:ok, [1, 2, 3]}
    assert Resolver.create_test(%{test: %{x: 2}}, @info) == {:ok, %Test{x: 2}}
    assert Resolver.update_test(%{id: 3, test: %{x: 3}}, @info) == {:ok, %Test{x: 3}}
    assert Resolver.update_test(%{id: 0, test: %{x: 3}}, @info) == {:error, "Test not found."}
    assert Resolver.delete_test(%{id: 2}, @info) == {:ok, :deleted}
    assert Resolver.delete_test(%{id: 0}, @info) == {:error, "Test not found."}
  end

  test "choose which CRUD functions are to be generated" do
    defmodule ResolverOnly do
      Crudry.Resolver.generate_functions(Context, CrudryTest.Test, only: [:create, :list])
    end

    assert ResolverOnly.create_test(%{test: %{x: 2}}, @info) == {:ok, %Test{x: 2}}
    assert ResolverOnly.list_tests(%{}, @info) == {:ok, [1, 2, 3]}
    assert length(ResolverOnly.__info__(:functions)) == 3

    defmodule ResolverExcept do
      Crudry.Resolver.generate_functions(Context, CrudryTest.Test, except: [:list, :delete])
    end

    assert ResolverExcept.create_test(%{test: %{x: 2}}, @info) == {:ok, %Test{x: 2}}
    assert ResolverExcept.update_test(%{id: 3, test: %{x: 3}}, @info) == {:ok, %Test{x: 3}}
    assert length(ResolverExcept.__info__(:functions)) == 4
  end

  test "choose which CRUD functions are to be generated by default" do
    defmodule ResolverOnlyDefault do
      Crudry.Resolver.default(only: [:create, :list])
      Crudry.Resolver.generate_functions(Context, CrudryTest.Test)
    end

    assert ResolverOnlyDefault.create_test(%{test: %{x: 2}}, @info) == {:ok, %Test{x: 2}}
    assert ResolverOnlyDefault.list_tests(%{}, @info) == {:ok, [1, 2, 3]}
    assert length(ResolverOnlyDefault.__info__(:functions)) == 3

    defmodule ResolverExceptDefault do
      Crudry.Resolver.default(except: [:list, :delete])
      Crudry.Resolver.generate_functions(Context, CrudryTest.Test)
    end

    assert ResolverExceptDefault.create_test(%{test: %{x: 2}}, @info) == {:ok, %Test{x: 2}}
    assert ResolverExceptDefault.update_test(%{id: 3, test: %{x: 3}}, @info) == {:ok, %Test{x: 3}}
    assert length(ResolverExceptDefault.__info__(:functions)) == 4
  end

  test "create custom update using nil_to_error" do
    defmodule ResolverExceptUpdate do
      Crudry.Resolver.default(except: [:update])
      Crudry.Resolver.generate_functions(Context, CrudryTest.Test)

      def update_test(%{id: id, test: params}, _info) do
        Context.get_test(id)
        |> nil_to_error(fn record -> Context.update_test_with_assocs(record, params, [:assoc]) end)
      end
    end

    assert ResolverExceptUpdate.update_test(%{id: 3, test: %{x: 3}}, @info) == {:ok, %Test{x: 3, assocs: [:assoc]}}
    assert ResolverExceptUpdate.update_test(%{id: 0, test: %{x: 3}}, @info) == {:error, "Test not found."}
  end

  test "Camelized name in error message" do
    defmodule CamelizedContext do
      alias CrudryTest.Repo
      alias CrudryTest.CamelizedSchemaName
      require Crudry.Context

      Crudry.Context.generate_functions(CamelizedSchemaName)
    end

    defmodule CamelizedResolver do
      Crudry.Resolver.generate_functions(CamelizedContext, CrudryTest.CamelizedSchemaName)
    end

    assert CamelizedResolver.get_camelized_schema_name(%{id: 0}, @info) == {:error, "CamelizedSchemaName not found."}

  end
end
