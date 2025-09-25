defmodule EmailNotificationSystem.Emails do
  import Ecto.Query
  alias EmailNotificationSystem.Repo
  alias EmailNotificationSystem.Emails.{Email, EmailRecipient}
  alias EmailNotificationSystem.Workers.EmailWorker

  def list_emails(user_id) do
    from(e in Email,
      where: e.user_id == ^user_id,
      order_by: [desc: e.inserted_at],
      preload: [:email_recipients, :group]
    )
    |> Repo.all()
  end

  def get_email!(id) do
    Repo.get!(Email, id)
    |> Repo.preload([:email_recipients, :group, :user])
  end

  def create_email(attrs \\ %{}) do
    %Email{}
    |> Email.changeset(attrs)
    |> Repo.insert()
  end

  def update_email(%Email{} = email, attrs) do
    email
    |> Email.changeset(attrs)
    |> Repo.update()
  end

  def delete_email(%Email{} = email) do
    Repo.delete(email)
  end

  defp notify(user_id, event, email_id) do
    Phoenix.PubSub.broadcast(
      EmailNotificationSystem.PubSub,
      "emails:#{user_id}",
      {:email_event, event, email_id}
    )
  end

  def send_email(%Email{} = email, recipients) do
    with {:ok, email} <- update_email(email, %{status: "queued"}) do
      # Create recipients
      create_recipients(email.id, recipients)

      notify(email.user_id, :queued, email.id)

      # Queue email job based on priority
      %{email_id: email.id}
      |> EmailWorker.new(priority: email.priority)
      |> Oban.insert()

      {:ok, email}
    end
  end

  defp create_recipients(email_id, recipients) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    recipients
    |> Enum.map(fn recipient ->
      %{
        email_id: email_id,
        recipient_email: recipient.email_address,
        recipient_name: EmailNotificationSystem.Contacts.Contact.full_name(recipient),
        contact_id: recipient.id,
        inserted_at: now,
        updated_at: now
      }
    end)
    |> then(&Repo.insert_all(EmailRecipient, &1))
  end

  def get_email_stats(email_id) do
    from(er in EmailRecipient,
      where: er.email_id == ^email_id,
      group_by: er.status,
      select: {er.status, count(er.id)}
    )
    |> Repo.all()
    |> Enum.into(%{})
  end

  def retry_failed_email(%Email{} = email, %EmailNotificationSystem.Accounts.User{} = actor) do
    require Logger

    if actor.plan_type != "gold" do
      {:error, :not_gold}
    else
      base_q =
        from(er in EmailRecipient,
          where: er.email_id == ^email.id and er.status in ["failed", "bounced", "pending"]
        )

      count = Repo.aggregate(base_q, :count)
      Logger.debug("retry_failed_email: email_id=#{email.id} candidates=#{count}")

      if count == 0 do
        # (Optional) repair: if there are only "sent" recipients but email shows "failed", fix it
        sent_cnt =
          Repo.aggregate(
            from(er in EmailRecipient, where: er.email_id == ^email.id and er.status == "sent"),
            :count
          )

        if sent_cnt > 0 and email.status != "sent" do
          _ = update_email(email, %{status: "sent"})
        end

        {:error, :no_failed_recipients}
      else
        now = DateTime.truncate(DateTime.utc_now(), :second)

        from(er in EmailRecipient,
          where: er.email_id == ^email.id and er.status in ["failed", "bounced", "pending"]
        )
        |> Repo.update_all(
          set: [
            status: "pending",
            retry_count: 0,
            error_message: nil,
            sent_at: nil,
            delivered_at: nil,
            opened_at: nil,
            clicked_at: nil,
            bounced_at: nil,
            updated_at: now
          ]
        )

        # show immediate progress in UI
        _ = update_email(email, %{status: "queued", sent_at: nil})

        %{email_id: email.id, retry: true}
        |> EmailNotificationSystem.Workers.EmailWorker.new(priority: 1)
        |> Oban.insert()

        {:ok, email}
      end
    end
  end


  def list_failed_recipients(email_id) do
    from(er in EmailRecipient,
      where: er.email_id == ^email_id and er.status in ["failed", "bounced"]
    )
    |> Repo.all()
  end
end
