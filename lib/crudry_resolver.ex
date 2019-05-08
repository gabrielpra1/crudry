defmodule Crudry.Resolver do
  @moduledoc """
  Generates CRUD functions to DRY Absinthe Resolvers.

  Requires a previously generated Context.

  ## Usage

  To generate CRUD functions for a given schema resolver, simply do

      defmodule MyApp.MyResolver do
        alias MyApp.Repo
        alias MyApp.MyContext
        alias MyApp.MySchema
        require Crudry.Resolver

        Crudry.Resolver.generate_functions MyContext, MySchema
      end

  And the resolver will become

      defmodule MyApp.MyResolver do
        alias MyApp.Repo
        alias MyApp.MyContext
        alias MyApp.MySchema
        require Crudry.Resolver

        def get_my_schema(%{id: id}, _info) do
          MyContext.get_my_schema(id)
          |> nil_to_error("my_schema", fn record -> {:ok, record} end)
        end

        def list_my_schemas(_args, _info) do
          {:ok, MyContext.list_my_schemas()}
        end

        def create_my_schema(%{params: params}, _info) do
          MyContext.create_my_schema(params)
        end

        def update_my_schema(%{id: id, params: params}, _info) do
          MyContext.get_my_schema(id)
          |> nil_to_error("my_schema", fn record -> MyContext.update_my_schema(record, params) end)
        end

        def delete_my_schema(%{id: id}, _info) do
          MyContext.get_my_schema(id)
          |> nil_to_error("my_schema", fn record -> MyContext.delete_my_schema(record) end)
        end

        # If `result` is `nil`, return an error. Otherwise, apply `func` to the `result`.
        def nil_to_error(result, name, func) do
          case result do
            nil -> {:error, "\#{Macro.camelize(name)} not found."}
            %{} = record -> func.(record)
          end
        end
      end

  Now, suppose the update resolver for our schema should update not only the schema but also some of its associations.

      defmodule MyApp.Resolver do
        alias MyApp.Repo
        alias MyApp.MyContext
        alias MyApp.MySchema
        require Crudry.Resolver

        Crudry.Resolver.generate_functions MyContext, MySchema, except: [:update]

        def update_my_schema(%{id: id, params: params}, _info) do
          MyContext.get_my_schema(id)
          |> nil_to_error("My Schema", fn record -> MyContext.update_my_schema_with_assocs(record, params, [:assoc]) end)
        end
      end

  By using the `nil_to_error` function, we DRY the nil checking and also ensure the error message is the same as the other auto-generated functions.
  """

  @doc """
  Sets default options for the resolver.

  ## Options

    * `:only` - list of functions to be generated. If not empty, functions not
    specified in this list are not generated. Default to `[]`.

    * `:except` - list of functions to not be generated. If not empty, only functions not specified
    in this list will be generated. Default to `[]`.

    * `list_opts` - options for the `list` function. See available options in `Crudry.Query.list/2`. Default to `[]`.

    * `create_resolver` - custom `create` resolver function with arity 4. Receives the following arguments: [Context, schema_name, args, info]. Default to `nil`.

    Note: in list_opts, custom_query will receive absinthe's info as the second argument and, therefore, must have arity 2. See example below.

    The accepted values for `:only` and `:except` are: `[:get, :list, :create, :update, :delete]`.

  ## Examples

      iex> Crudry.Resolver.default only: [:create, :list]
      :ok

      iex> Crudry.Resolver.default except: [:get!, :list, :delete]
      :ok

      iex> Crudry.Resolver.default list_opts: [order_by: :id]
      :ok

      def scope_list(Post, info) do
        current_user = info.context.current_user

        where(Post, [p], p.user_id == ^current_user.id)
      end

      def scope_list(initial_query, _info), do: initial_query

      iex> Crudry.Resolver.default list_opts: [custom_query: &scope_list/2]
      :ok
  """
  defmacro default(opts) do
    Module.put_attribute(__CALLER__.module, :only, opts[:only])
    Module.put_attribute(__CALLER__.module, :except, opts[:except])
    Module.put_attribute(__CALLER__.module, :list_opts, opts[:list_opts])

    create_resolver_fun = opts[:create_resolver]
    case create_resolver_fun && :erlang.fun_info(create_resolver_fun)[:arity] do
      nil -> :ok
      4 -> Module.put_attribute(__CALLER__.module, :create_resolver, create_resolver_fun)
      _ -> raise "Create generator function must have arity 4"
    end
  end

  @doc """
  Generates CRUD functions for the `schema_module` resolver.

  Custom options can be given. To see the available options, refer to the documenation of `Crudry.Resolver.default/1`.

  ## Examples

    Suppose we want to implement basic CRUD functionality for a User resolver,
    assuming there is an Accounts context which already implements CRUD functions for User.

      defmodule MyApp.AccountsResolver do
        require Crudry.Resolver

        Crudry.Resolver.generate_functions Accounts, Accounts.User
      end

    Now, all this functionality is available:

      AccountsResolver.get_user(%{id: id}, info)
      AccountsResolver.list_users(_args, info)
      AccountsResolver.crete_user(%{params: params}, info)
      AccountsResolver.update_user(%{id: id, params: params}, info)
      AccountsResolver.delete_user(%{id: id}, info)
      AccountsResolver.nil_to_error(result, name, func)
  """

  # Always generate helper functions since they are used in the other generated functions
  @helper_functions ~w(nil_to_error add_info_to_custom_query)a

  defmacro generate_functions(context, schema_module, opts \\ []) do
    opts = Keyword.merge(load_default(__CALLER__.module), opts)
    name = Helper.get_underscored_name(schema_module)
    _ = String.to_atom(name)

    for func <- get_functions_to_be_generated(__CALLER__.module) do
      if Enum.member?(@helper_functions, func) || Helper.define_function?(func, opts[:only], opts[:except]) do
        ResolverFunctionsGenerator.generate_function(func, name, context, opts)
      end
    end
  end

  # Use an attribute in the caller's module to make sure helper functions are only generated once per module.
  defp get_functions_to_be_generated(module) do
    functions = [:get, :list, :create, :update, :delete]

    if Module.get_attribute(module, :called) do
      functions
    else
      Module.put_attribute(module, :called, true)
      @helper_functions ++ functions
    end
  end

  # Load user-defined defaults or fall back to the library's default.
  defp load_default(module) do
    only = Module.get_attribute(module, :only)
    except = Module.get_attribute(module, :except)
    list_opts = Module.get_attribute(module, :list_opts)
    create_resolver = Module.get_attribute(module, :create_resolver)

    [
      only: only || [],
      except: except || [],
      list_opts: list_opts || [],
      create_resolver: create_resolver || nil
    ]
  end
end
