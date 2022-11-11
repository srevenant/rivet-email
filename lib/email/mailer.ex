defmodule Rivet.Email.Mailer do
  @moduledoc false
  # exits just to abstract Bamboo, incase we want something differeint in the
  # future
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      use Bamboo.Mailer, otp_app: Keyword.get(opts, :otp_app)
    end
  end
end
