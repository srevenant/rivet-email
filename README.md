# Rivet Email

A simple to use templated email system as part of the [Rivets Framework](https://docs.google.com/document/d/1ntoTA9YRE7KvKpmwZRtfzKwTZNgo2CY6YfJnDNQAlBc), using Bamboo mailer on the backend

Usage steps (see examples that follow for more detail):

1. Configure Rivet Email (see `config/config.exs` for an example of supported configurations).
2. Create Mailer and Email modules as well as one or more templates
3. Send email, where `recips` can be a single or list of
   `user_model`, `email_model` or an ID for a `user_model`:

```elixir
MyEmail.send(recips, MyEmailTemplate)
```

## Rivet Mailer and Email modules

```elixir
defmodule MyMailer do
  use Rivet.Email.Mailer, otp_app: :app_name_here
end
```

```elixir
defmodule MyEmail do
  use Rivet.Email,
    otp_app: :app_name_here,
    user_model: UserStruct,
    email_model: UserEmailStruct,
    mailer: MyMailer
end
```

## Template

The template is a generate() function, which accepts the recipient as a UserEmailStruct,
and attributes as a map. Attributes come from the configuration

```elixir
defmodule Myapp.Email.AuthErrorTemplate do
  @behaviour Rivet.Email.Template

  @impl Rivet.Email.Template
  def generate(recip, attrs) do
    {:ok, "failed", "<p>Sorry #{recip.user.name}<p>This didn't work"}
  end

  # create a "send" function (optional), and then call it as:
  #   AuthErrorTemplate.send(recipients)
  def send(recip) do
    # gather attributes
    @sender.send(recip, __MODULE__, attrib1: value, ...)
  end
end
```

## Rivet User and Email structs

The included structures should at least support:

```elixir
  %UserStruct{
    id: String.t(),
    emails: list(UserEmailStruct.t()),
  }
  %UserEmailStruct{
    id: String.t(),
    address: String.t()
    user: UserStruct.t()
  }
```

And, each structure should have a `one/1` function that accepts an `id: ID`
keyword pair, as well as a `preload/2` function that accepts the relevant
struct and a list of atoms for fields to preload (per Ecto's preload).
