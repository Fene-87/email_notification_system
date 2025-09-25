defmodule EmailNotificationSystem.Contacts.Contact do
  use Ecto.Schema
  import Ecto.Changeset
  alias EmailNotificationSystem.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field :first_name, :string
    field :last_name, :string
    field :email_address, :string
    field :phone_number, :string
    field :is_active, :boolean, default: true
    field :tags, {:array, :string}, default: []

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [:first_name, :last_name, :email_address, :phone_number, :is_active, :tags, :user_id])
    |> validate_required([:first_name, :last_name, :email_address, :user_id])
    |> validate_format(:email_address, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_length(:first_name, min: 2, max: 100)
    |> validate_length(:last_name, min: 2, max: 100)
    |> unique_constraint([:user_id, :email_address])
  end

  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end
end
