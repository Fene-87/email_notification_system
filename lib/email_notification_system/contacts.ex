defmodule EmailNotificationSystem.Contacts do
  import Ecto.Query
  alias EmailNotificationSystem.Repo
  alias EmailNotificationSystem.Contacts.Contact

  def list_contacts(user_id, opts \\ []) do
    base = from c in Contact, where: c.user_id == ^user_id
    base =
      if Keyword.get(opts, :include_inactive, false),
        do: base,
        else: (from c in base, where: c.is_active == true)

    Repo.all(base)
  end

  def get_contact!(id), do: Repo.get!(Contact, id)

  def create_contact(attrs \\ %{}) do
    %Contact{}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
  end

  def soft_delete_contact(user_id, contact_id) do
    case Repo.get_by(Contact, id: contact_id, user_id: user_id, is_active: true) do
      nil -> {:error, :not_found}
      contact -> update_contact(contact, %{is_active: false})
    end
  end

  def delete_contact(%Contact{} = contact) do
    Repo.delete(contact)
  end

  def search_contacts(user_id, search_term) do
    search = "%#{search_term}%"

    from(c in Contact,
      where: c.user_id == ^user_id and c.is_active == true,
      where: ilike(c.first_name, ^search) or
             ilike(c.last_name, ^search) or
             ilike(c.email_address, ^search)
    )
    |> Repo.all()
  end
end
