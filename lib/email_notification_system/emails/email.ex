defmodule EmailNotificationSystem.Emails.Email do
  use Ecto.Schema
  import Ecto.Changeset
  alias EmailNotificationSystem.{Accounts.User, Groups.Group, Emails.EmailRecipient}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @email_types ~w(single bulk group)
  @statuses ~w(draft queued sending sent failed cancelled)

  schema "emails" do
    field :subject, :string
    field :body, :string
    field :from_email, :string
    field :reply_to, :string
    field :email_type, :string, default: "single"
    field :priority, :integer, default: 5
    field :status, :string, default: "draft"
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime

    belongs_to :user, User
    belongs_to :group, Group
    has_many :email_recipients, EmailRecipient

    timestamps(type: :utc_datetime)
  end

  def changeset(email, attrs) do
    email
    |> cast(attrs, [:subject, :body, :from_email, :reply_to, :email_type,
                    :priority, :status, :scheduled_at, :user_id, :group_id])
    |> validate_required([:subject, :body, :from_email, :user_id])
    |> validate_inclusion(:email_type, @email_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:priority, 1..10)
    |> validate_format(:from_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
    |> validate_format(:reply_to, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
  end
end
