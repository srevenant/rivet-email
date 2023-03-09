defmodule Rivet.Email.Example do
  @moduledoc """
  This is an example of how to deploy Rivet Email, and is included so other
  projects may include it in their tests.
  """
  alias Rivet.Email.Example

  use Rivet.Email,
    otp_app: :rivet_email,
    backend: Example.Backend,
    # using something besides Ident.User/Email
    user_model: Example.User,
    email_model: Example.Email
end
