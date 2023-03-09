defmodule Rivet.Email.Backend do
  @moduledoc false
  # exits just to abstract Bamboo, incase we want something different in the
  # future
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Bamboo.Mailer, otp_app: Keyword.get(opts, :otp_app)
    end
  end
end
