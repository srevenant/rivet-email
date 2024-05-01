defmodule Rivet.Email.Example.Mailer do
  @moduledoc """
  This is an example of how to deploy Rivet Email, and is included so other
  projects may include it in their tests.
  """
  alias Rivet.Email.Example.Mailer

  use Rivet.Email,
    otp_app: :rivet_email,
    backend: Mailer.Backend,
    configurator: Mailer.Configurator,
    # using something besides Ident.User/Email
    user_model: Mailer.User,
    email_model: Mailer.Email
end
