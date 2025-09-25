defmodule EmailNotificationSystem.Groups.Group do
  use Ecto.Schema
  import Ecto.Changeset
  alias EmailNotificationSystem.{Accounts.User, Contacts.Contact, Groups.GroupContact}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "groups" do
    field :name, :string
    field :description, :string
    field :is_active, :boolean, default: true

    belongs_to :user, User
    has_many :group_contacts, GroupContact
    many_to_many :contacts, Contact, join_through: GroupContact

    timestamps(type: :utc_datetime)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:name, :description, :is_active, :user_id])
    |> validate_required([:name, :user_id])
    |> validate_length(:name, min: 2, max: 200)
    |> validate_length(:description, max: 1000)
    |> unique_constraint([:user_id, :name])
  end
end
