# Rivet Email

A simple to use templated email system as part of
the [Rivets Framework](https://docs.google.com/document/d/1ntoTA9YRE7KvKpmwZRtfzKwTZNgo2CY6YfJnDNQAlBc). Key things to using this:

* `Backend` — this is what we use for the actual heavy lifting (Swoosh).
* `Mailer` — the entrypoint/API used if you don't want to directly address a template.
* *templates* — templates as Modules to handle messages.
* *config* — where you specify the Mailer module
* *data structs* — uses Rivet.Ident.Email and Rivet.Ident.User, but anything can be subbed in.

Usage steps (see examples that follow for more detail):

1. Configure Rivet Email (see `config/config.exs` for an example of supported configurations).
2. Create Mailer and Email modules as well as one or more templates (see `lib/email/examples`).
3. Create Template Modules, which load an EEX template from the database and
   evaluate it for each recipient.
3. Send email by calling `sendto` as shown below.

`YourTemplateModule.sendto(recips, assigns \\ %{}, configs \\ [])`

Returns a tuple of :ok or :error with a list of results from each send.

- `recips` can be one or list of: user id, a `user_model`, or a `email_model`
- `assigns` (optional) is a dictionary with key/value attributes used in the
  eex template processing.
- `configs` (optional) is a list of configs to load, as either a config name string,
  or as a tuple of {configname, sitename} if it is site specific (the latter
  will fall back to just configname if no sitename is found in configs).

It will stop at the first error, however, and not continue.

Configs are stored in the templates table with a keyword of `//CONFIG/{name}/{sitename}`
or `//CONFIG/{name}` — the default config name is `site` but you can add any others
as you desire, and include them with the template as an option on template creation,
example:

  ```use Rivet.Email.Template, configs: ["name"]```

Additionally you can include configs at runtime as an option to the sendto() call.

## Rivet Mailer and Email modules

These are stock modules to configure the backend.

```elixir
defmodule MyEmail.Backend do
  use Rivet.Email.Backend, otp_app: :your_otp_app
end

defmodule MyEmail.Configurator do
  use Rivet.Email.Configurator, otp_app: :your_otp_app
end
```

and in application.ex:
```elixir
  Supervisor.start_link([MyEmail.Configurator])
```

```elixir
defmodule MyEmail do
  use Rivet.Email,
    otp_app: :your_otp_app,
    backend: MyEmail.Backend,
    configurator: MyEmail.Configurator
    user_model: Ident.User, # optional; shown with default
    email_model: Ident.Email # optional; shown with default
end
```

Config:

```elixir
config :rivet_email,
  mailer: MyEmail,
  ecto_repos: [Rivet.Email.Repo], # required now that we have Db templates
  enabled: true, # false will just log sent messages rather than sending them
  site: [
    # everything here is free-form and up to your templates. It is put into
    # the template assigns as @site.{...}
    name: "anything you want"
  ]

```

## Template

The template may override a `generate` and `send` function, or just accept the
defaults. The generate function is called once for each recipient (to allow
personalization), where the send function is the entrypoint (called from other
code). Send is asynchronous.

```elixir
defmodule Myapp.Email.AuthErrorTemplate do
  @behaviour Rivet.Email.Template

  @impl Rivet.Email.Template
  def generate(recip, attrs) do
    # if you didn't want to use the DB templating
    {:ok, "failed", "<p>Sorry #{recip.user.name}<p>This didn't work"}
  end

  def sendto(recip) do
    Rivet.Email.mailer().sendto(recip, __MODULE__, attrib1: value, ...)
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
