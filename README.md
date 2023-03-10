# Rivet Email

A simple to use templated email system as part of the [Rivets Framework](https://docs.google.com/document/d/1ntoTA9YRE7KvKpmwZRtfzKwTZNgo2CY6YfJnDNQAlBc). Key things to using this:

* `Backend` — this is what we use for the actual heavy lifting. For now, using Bamboo mailer.
* `Mailer` — the entrypoint/API used in other apps
* *templates* — templates to handle messages
* *config* — where you specify the Mailer module
* *data structs* — uses Rivet.Ident.Email and Rivet.Ident.User, but anything can be subbed in

Usage steps (see examples that follow for more detail):

1. Configure Rivet Email (see `config/config.exs` for an example of supported configurations).
2. Create Mailer and Email modules as well as one or more templates (see `lib/email/examples`).
3. Send email, where `recips` can be a single or list of `user_model`, `email_model` or an ID for a `user_model`:

```elixir
MyEmail.send(recips, MyEmailTemplate)
```

## Rivet Mailer and Email modules

```elixir
defmodule MyEmailBackend do
  use Rivet.Email.Mailer, otp_app: :app_name_here
end
```

```elixir
defmodule MyEmail do
  use Rivet.Email,
    otp_app: :app_name_here,
    backend: MyEmailBackend,
    user_model: Ident.User, # optional; shown with default
    email_model: Ident.Email # optional; shown with default
end
```

Config:

```elixir
config :rivet_email,
  enabled: true,
  mailer: MyEmail
```

## Template

The template defines a generate() function, which accepts the recipient as a UserEmailStruct,
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
    # gather attributes and do things here
    # then send:
    Rivet.Email.mailer().send(recip, __MODULE__, attrib1: value, ...)
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
