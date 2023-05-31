defmodule Rivet.Email.Backend do
  @moduledoc false
  # exits just to abstract Swoosh, incase we want something different in the
  # future
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Swoosh.Mailer, otp_app: Keyword.get(opts, :otp_app)
    end
  end
end
