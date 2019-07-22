defmodule TranslateErrorsTest do
  use ExUnit.Case

  alias Ecto.Changeset
  alias Crudry.Middlewares.TranslateErrors
  alias Crudry.{Like, Post, User}

  defmodule PortugeuseTranslator do
    use Gettext, otp_app: :crudry, default_locale: "pt_BR"

    def errors_domain, do: "errors"

    def schema_fields_domain, do: "schema_fields"
  end

  test "translate errors that aren't changeset to portuguese" do
    resolution = build_resolution("Not logged in", %{locale: "pt_BR"})

    assert TranslateErrors.call(resolution, :_)[:errors] == ["Não está logado"]
  end

  test "translate can't be blank changeset error to portuguese" do
    changeset = User.changeset(%User{}, %{})
    resolution = build_resolution(changeset, %{translator: PortugeuseTranslator})

    assert TranslateErrors.call(resolution, :_)[:errors] == ["nome de usuário não pode estar vazio"]
  end

  test "translate length changeset error" do
    changeset = User.changeset(%User{}, %{username: "a"})
    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution("username should be at least 2 character(s)")
  end

  test "translate validate_number changeset error" do
    changeset = User.changeset(%User{}, %{username: "name", age: -5})
    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution("age must be greater than 0")
  end

  test "translate multiple changeset errors" do
    changeset = Post.changeset(%Post{}, %{})
    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution(["title can't be blank", "user_id can't be blank"])
  end

  test "translate nested changeset errors for has_many association" do
    changeset =
      %User{}
      |> User.changeset(%{posts: [%{}]})
      |> Changeset.cast_assoc(:posts, with: &Post.changeset/2)

    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution([
               "posts: title can't be blank",
               "posts: user_id can't be blank",
               "username can't be blank"
             ])
  end

  test "translate nested changeset errors for has_one association" do
    changeset =
      %Post{}
      |> Post.nested_comment_changeset(%{comment: %{}})

    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution([
               "comment: content can't be blank",
               "comment: post_id can't be blank",
               "title can't be blank",
               "user_id can't be blank"
             ])
  end

  test "translate deeply nested changeset errors for has_many association" do
    changeset =
      %User{}
      |> User.changeset(%{posts: [%{likes: [%{}]}]})
      |> Changeset.cast_assoc(:posts, with: &Post.nested_likes_changeset/2)

    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution([
               "likes: post_id can't be blank",
               "likes: user_id can't be blank",
               "posts: title can't be blank",
               "posts: user_id can't be blank",
               "username can't be blank"
             ])
  end

  test "translate deeply nested changeset errors for has_one association" do
    changeset =
      %User{}
      |> User.changeset(%{
        posts: [
          %{
            comment: %{}
          }
        ]
      })
      |> Changeset.cast_assoc(:posts, with: &Post.nested_comment_changeset/2)

    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution([
               "comment: content can't be blank",
               "comment: post_id can't be blank",
               "posts: title can't be blank",
               "posts: user_id can't be blank",
               "username can't be blank"
             ])
  end

  test "translate multiple nested changeset errors" do
    changeset =
      %User{}
      |> User.changeset(%{posts: [%{}], likes: [%{}]})
      |> Changeset.cast_assoc(:posts, with: &Post.changeset/2)
      |> Changeset.cast_assoc(:likes, with: &Like.changeset/2)

    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution([
               "likes: post_id can't be blank",
               "likes: user_id can't be blank",
               "posts: title can't be blank",
               "posts: user_id can't be blank",
               "username can't be blank"
             ])
  end

  test "translate multiple nested changeset errors when one doesn't have errors" do
    changeset =
      %User{}
      |> User.changeset(%{posts: [%{}], likes: [%{post_id: 1, user_id: 1}]})
      |> Changeset.cast_assoc(:posts, with: &Post.changeset/2)
      |> Changeset.cast_assoc(:likes, with: &Like.changeset/2)

    resolution = build_resolution(changeset)

    assert TranslateErrors.call(resolution, :_) ==
             build_resolution([
               "posts: title can't be blank",
               "posts: user_id can't be blank",
               "username can't be blank"
             ])
  end

  defp build_resolution(errors, context \\ %{})

  defp build_resolution(errors, context) when is_list(errors) do
    %{errors: errors, state: :resolved, context: context}
  end

  defp build_resolution(errors, context) do
    build_resolution([errors], context)
  end
end
