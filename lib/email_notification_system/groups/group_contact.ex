defmodule EmailNotificationSystem.Groups.GroupContact do
  use Ecto.Schema
  import Ecto.Changeset
  alias EmailNotificationSystem.{Groups.Group, Contacts.Contact}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "group_contacts" do
    belongs_to :group, Group
    belongs_to :contact, Contact

    timestamps(type: :utc_datetime)
  end

  def changeset(group_contact, attrs) do
    group_contact
    |> cast(attrs, [:group_id, :contact_id])
    |> validate_required([:group_id, :contact_id])
    |> unique_constraint([:group_id, :contact_id])
  end
end
