defmodule Rivet.Email.Test.Mailer do
  @moduledoc """
  This is an example of how to deploy Rivet Email, and is included so other
  projects may include it in their tests.
  """
  alias Rivet.Email.Test.Mailer

  use Rivet.Email,
    otp_app: :rivet_email,
    backend: Mailer.Backend,
    # using something besides Ident.User/Email
    user_model: Mailer.User,
    email_model: Mailer.Email
end
