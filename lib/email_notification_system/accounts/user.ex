defmodule EmailNotificationSystem.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias EmailNotificationSystem.{Contacts.Contact, Groups.Group, Emails.Email}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @access_levels ~w(frontend admin superuser)
  @plan_types ~w(basic gold)

  schema "users" do
    field :first_name, :string
    field :last_name, :string
    field :email_address, :string
    field :msisdn, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :access_level, :string, default: "frontend"
    field :plan_type, :string, default: "basic"
    field :is_active, :boolean, default: true
    field :last_login_at, :utc_datetime
    field :email_verified, :boolean, default: false
    field :phone_verified, :boolean, default: false

    has_many :contacts, Contact, foreign_key: :user_id
    has_many :groups, Group, foreign_key: :user_id
    has_many :emails, Email, foreign_key: :user_id

    timestamps(type: :utc_datetime)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :email_address, :msisdn, :password])
    |> update_change(:msisdn, &normalize_msisdn/1)
    |> validate_required([:first_name, :last_name, :email_address, :msisdn, :password])
    |> validate_format(:email_address, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_format(:msisdn, ~r/^\+?[1-9]\d{1,14}$/)
    |> validate_length(:password, min: 8)
    |> validate_length(:first_name, min: 2, max: 100)
    |> validate_length(:last_name,  min: 2, max: 100)
    |> unique_constraint(:email_address)
    |> unique_constraint(:msisdn)
    |> hash_password()
  end

  defp normalize_msisdn(nil), do: nil
  defp normalize_msisdn(msisdn) do
    digits = String.replace(msisdn, ~r/\D/, "")
    cond do
      String.starts_with?(digits, "254") -> "+" <> digits
      String.starts_with?(digits, "0")   -> "+254" <> binary_part(digits, 1, byte_size(digits)-1)
      true                               -> "+" <> digits
    end
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:first_name, :last_name, :email_address, :msisdn,
                    :access_level, :plan_type, :is_active, :email_verified, :phone_verified])
    |> validate_required([:first_name, :last_name, :email_address, :msisdn])
    |> validate_inclusion(:access_level, @access_levels)
    |> validate_inclusion(:plan_type, @plan_types)
    |> validate_format(:email_address, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_format(:msisdn, ~r/^\+?[1-9]\d{1,14}$/)
    |> unique_constraint(:email_address)
    |> unique_constraint(:msisdn)
  end

  defp hash_password(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
      _ ->
        changeset
    end
  end

  def valid_password?(%__MODULE__{password_hash: hash}, password)
      when is_binary(hash) and byte_size(password) > 0 do
    Bcrypt.verify_pass(password, hash)
  end

  def valid_password?(_, _) do
    Bcrypt.no_user_verify()
    false
  end

  def full_name(%__MODULE__{first_name: first_name, last_name: last_name}) do
    "#{first_name} #{last_name}"
  end

  def can_access_admin?(%__MODULE__{access_level: level}) when level in ["admin", "superuser"], do: true
  def can_access_admin?(_), do: false

  def is_superuser?(%__MODULE__{access_level: "superuser"}), do: true
  def is_superuser?(_), do: false

  def has_gold_plan?(%__MODULE__{plan_type: "gold"}), do: true
  def has_gold_plan?(_), do: false
end
