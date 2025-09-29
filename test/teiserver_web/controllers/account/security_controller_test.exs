defmodule TeiserverWeb.Account.SecurityControllerTest do
  use TeiserverWeb.ConnCase

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures

  test "redirected to edit password once logged in" do
    {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
    {:ok, conn} = Keyword.fetch(kw, :conn)
    {:ok, user} = Keyword.fetch(kw, :user)

    conn = get(conn, ~p"/teiserver/account/security/edit_password")
    assert redirected_to(conn) == ~p"/login"
    conn = GeneralTestLib.login(conn, user.email)
    assert redirected_to(conn) == ~p"/teiserver/account/security/edit_password"
  end

  describe "OAuth application revocation" do
    setup do
      {:ok, kw} =
        GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
        |> Teiserver.TeiserverTestLib.conn_setup()

      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, user} = Keyword.fetch(kw, :user)

      # Create an OAuth application
      {:ok, app} =
        OAuth.create_application(%{
          name: "Test App",
          uid: "test_app",
          owner_id: user.id,
          scopes: ["tachyon.lobby"],
          redirect_uris: ["http://localhost/callback"]
        })

      # Create tokens and codes for the app
      token = OAuthFixtures.token_attrs(user.id, app) |> OAuthFixtures.create_token()
      code = OAuthFixtures.code_attrs(user.id, app) |> OAuthFixtures.create_code()

      {:ok, conn: conn, user: user, app: app, token: token, code: code}
    end

    test "successfully revokes OAuth application access", %{
      conn: conn,
      app: app,
      token: token,
      code: code
    } do
      # Verify tokens and codes exist
      assert Teiserver.OAuth.TokenQueries.get_token(token.value)
      assert Teiserver.OAuth.CodeQueries.get_code(code.value)

      # Revoke access
      conn = delete(conn, ~p"/teiserver/account/security/revoke_oauth/#{app.id}")

      # Should redirect back to security page
      assert redirected_to(conn) == ~p"/teiserver/account/security"

      # Should show success message
      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "OAuth application access revoked successfully."

      # Verify tokens and codes are deleted
      refute Teiserver.OAuth.TokenQueries.get_token(token.value)
      refute Teiserver.OAuth.CodeQueries.get_code(code.value)
    end

    test "handles revocation when no tokens or codes exist", %{conn: conn, user: user} do
      # Create an app with no tokens or codes
      {:ok, app} =
        OAuth.create_application(%{
          name: "Empty App",
          uid: "empty_app",
          owner_id: user.id,
          scopes: ["tachyon.lobby"],
          redirect_uris: ["http://localhost/callback"]
        })

      # Revoke access (should still succeed)
      conn = delete(conn, ~p"/teiserver/account/security/revoke_oauth/#{app.id}")

      # Should redirect back to security page
      assert redirected_to(conn) == ~p"/teiserver/account/security"

      # Should show success message
      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "OAuth application access revoked successfully."
    end
  end
end
