defmodule EmailNotificationSystem.Emails.EmailRecipient do
  use Ecto.Schema
  import Ecto.Changeset
  alias EmailNotificationSystem.{Emails.Email, Contacts.Contact}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending sent delivered opened clicked bounced failed)

  schema "email_recipients" do
    field :recipient_email, :string
    field :recipient_name, :string
    field :status, :string, default: "pending"
    field :sent_at, :utc_datetime
    field :delivered_at, :utc_datetime
    field :opened_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :bounced_at, :utc_datetime
    field :error_message, :string
    field :retry_count, :integer, default: 0

    belongs_to :email, Email
    belongs_to :contact, Contact

    timestamps(type: :utc_datetime)
  end

  def changeset(email_recipient, attrs) do
    email_recipient
    |> cast(attrs, [:recipient_email, :recipient_name, :status, :sent_at,
                    :delivered_at, :opened_at, :clicked_at, :bounced_at,
                    :error_message, :retry_count, :email_id, :contact_id])
    |> validate_required([:recipient_email, :email_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_format(:recipient_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_number(:retry_count, greater_than_or_equal_to: 0)
  end
end
