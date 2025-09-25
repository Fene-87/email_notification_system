defmodule EmailNotificationSystem.Accounts do
  import Ecto.Query
  alias Ecto.Multi
  alias EmailNotificationSystem.Repo
  alias EmailNotificationSystem.Accounts.User
  alias EmailNotificationSystem.Contacts.Contact
  alias EmailNotificationSystem.Groups.Group
  alias EmailNotificationSystem.Emails.{Email, EmailRecipient}

  def list_users do
    Repo.all(User)
  end

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email_address: email)
  end

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def delete_user_and_data(%User{} = user) do
    email_ids_q = from(e in Email, where: e.user_id == ^user.id, select: e.id)

    Multi.new()
    |> Multi.delete_all(:email_recipients, from(er in EmailRecipient, where: er.email_id in subquery(email_ids_q)))
    |> Multi.delete_all(:emails, from(e in Email, where: e.user_id == ^user.id))
    |> Multi.delete_all(:groups, from(g in Group, where: g.user_id == ^user.id))
    |> Multi.delete_all(:contacts, from(c in Contact, where: c.user_id == ^user.id))
    |> Multi.delete(:user, user)
    |> Repo.transaction()
  end

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && User.valid_password?(user, password) ->
        update_last_login(user)
        {:ok, user}
      user ->
        {:error, :invalid_password}
      true ->
        {:error, :not_found}
    end
  end

  defp update_last_login(user) do
    update_user(user, %{last_login_at: DateTime.utc_now()})
  end

  def upgrade_to_gold(%User{} = user) do
    update_user(user, %{plan_type: "gold"})
  end

  def grant_admin_access(%User{} = user) do
    update_user(user, %{access_level: "admin"})
  end

  def revoke_admin_access(%User{} = user) do
    update_user(user, %{access_level: "frontend"})
  end

  def downgrade_to_basic(%User{} = user) do
    update_user(user, %{plan_type: "basic"})
  end

  def grant_superuser_access(%User{} = user) do
    update_user(user, %{access_level: "superuser"})
  end

  def revoke_superuser_access(%User{} = user) do
    update_user(user, %{access_level: "admin"})
  end

  def list_admin_users do
    from(u in User, where: u.access_level in ["admin", "superuser"])
    |> Repo.all()
  end

  def update_user_plan(actor, user_id, plan) when plan in ["basic", "gold"] do
    with :ok <- authorize_admin(actor),
        %User{} = user <- Repo.get(User, user_id) do
      user |> User.changeset(%{plan_type: plan}) |> Repo.update()
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  def grant_admin(actor, user_id) do
    with :ok <- authorize_admin(actor),
        %User{} = user <- Repo.get(User, user_id) do
      user |> User.changeset(%{access_level: "admin"}) |> Repo.update()
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  def revoke_admin(actor, user_id) do
    with :ok <- authorize_admin(actor),
        %User{} = user <- Repo.get(User, user_id),
        :ok <- cannot_act_on_self(actor, user),
        :ok <- ensure_not_last_admin(user) do
      user |> User.changeset(%{access_level: "frontend"}) |> Repo.update()
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  def grant_superuser(actor, user_id) do
    with :ok <- authorize_superuser(actor),
        %User{} = user <- Repo.get(User, user_id) do
      user |> User.changeset(%{access_level: "superuser"}) |> Repo.update()
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  def revoke_superuser(actor, user_id) do
    with :ok <- authorize_superuser(actor),
        %User{} = user <- Repo.get(User, user_id),
        :ok <- cannot_act_on_self(actor, user) do
      # On revoke, fall back to admin (not frontend)
      user |> User.changeset(%{access_level: "admin"}) |> Repo.update()
    else
      nil -> {:error, :not_found}
      err -> err
    end
  end

  # --- Guards & counts ---

  defp authorize_admin(%User{access_level: lvl}) when lvl in ["admin", "superuser"], do: :ok
  defp authorize_admin(_), do: {:error, :forbidden}

  defp authorize_superuser(%User{access_level: "superuser"}), do: :ok
  defp authorize_superuser(_), do: {:error, :forbidden}

  defp cannot_act_on_self(%User{id: id}, %User{id: id}), do: {:error, :cannot_modify_self}
  defp cannot_act_on_self(_actor, _target), do: :ok

  defp ensure_not_last_admin(%User{} = target) do
    admins_count =
      from(u in User, where: u.access_level in ["admin", "superuser"], select: count(u.id))
      |> Repo.one()

    cond do
      admins_count > 1 -> :ok
      admins_count == 1 and target.access_level in ["admin", "superuser"] ->
        {:error, :last_admin}
      true -> :ok
    end
  end
end
