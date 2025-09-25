defmodule EmailNotificationSystem.Groups do
  import Ecto.Query
  alias EmailNotificationSystem.Repo
  alias EmailNotificationSystem.Groups.{Group, GroupContact}
  alias EmailNotificationSystem.Accounts

  def list_groups(user_id) do
    from(g in Group,
      where: g.user_id == ^user_id and g.is_active == true,
      preload: [:contacts]
    )
    |> Repo.all()
  end

  def get_group!(id) do
    Repo.get!(Group, id)
    |> Repo.preload([:contacts])
  end

  def create_group(attrs) do
    with user_id when is_binary(user_id) <- Map.get(attrs, "user_id") || Map.get(attrs, :user_id),
        user <- Accounts.get_user!(user_id),
        true <- user.plan_type == "gold" do
      %Group{} |> Group.changeset(attrs) |> Repo.insert()
    else
      false -> {:error, :not_gold}
      _ -> {:error, :invalid_user}
    end
  end

  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  def add_contact_to_group(group_id, contact_id) do
    %GroupContact{}
    |> GroupContact.changeset(%{group_id: group_id, contact_id: contact_id})
    |> Repo.insert()
  end

  def remove_contact_from_group(group_id, contact_id) do
    from(gc in GroupContact,
      where: gc.group_id == ^group_id and gc.contact_id == ^contact_id
    )
    |> Repo.delete_all()
  end
end
