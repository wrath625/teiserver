defmodule Teiserver.OAuth.User do
  @moduledoc """
  User-specific OAuth operations for managing authorized applications and tokens.

  This module provides functions for users to manage their OAuth application authorizations.
  Database queries are delegated to Teiserver.OAuth.ApplicationQueries.
  """

  alias Teiserver.Repo
  alias Teiserver.OAuth.{ApplicationQueries}
  alias Teiserver.Data.Types, as: T

  # Delegate query functions to ApplicationQueries
  defdelegate list_authorized_applications(user_id), to: ApplicationQueries
  defdelegate get_application_token_counts(user_id), to: ApplicationQueries

  @doc """
  Revokes all tokens and codes for a specific application for a user.
  This includes access tokens, refresh tokens, and authorization codes.
  """
  @spec revoke_application_access(T.userid(), Teiserver.OAuth.Application.id()) ::
          :ok | {:error, term()}
  def revoke_application_access(user_id, application_id) do
    Repo.transaction(fn ->
      {_token_count, _} =
        ApplicationQueries.delete_user_application_tokens(user_id, application_id)

      {_code_count, _} = ApplicationQueries.delete_user_application_codes(user_id, application_id)

      :ok
    end)
    |> case do
      {:ok, result} -> result
      {:error, reason} -> {:error, reason}
    end
  end
end
